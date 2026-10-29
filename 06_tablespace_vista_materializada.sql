-- Script 6: Tablespace del historico y vista materializada (Entrega 2)
-- Se corre con el usuario del proyecto, despues del 05 (que corre SYSTEM).

-- El script se detiene si se corre como SYS o SYSTEM (debe ser el usuario del proyecto)
WHENEVER SQLERROR EXIT FAILURE ROLLBACK
BEGIN
  IF USER IN ('SYS', 'SYSTEM') THEN
    RAISE_APPLICATION_ERROR(-20000, 'Esta conectado como ' || USER
      || '. Cambie a la conexion del usuario del proyecto y ejecute de nuevo.');
  END IF;
END;
/
WHENEVER SQLERROR CONTINUE

SET SERVEROUTPUT ON
SET DEFINE OFF
SET SQLBLANKLINES ON

-- Limpieza para poder correrlo varias veces
BEGIN
  FOR o IN (SELECT 'MATERIALIZED VIEW' tipo, mview_name nombre FROM user_mviews
             WHERE mview_name = 'MV_OCUPACION_MENSUAL'
            UNION ALL
            SELECT 'TABLE', table_name FROM user_tables
             WHERE table_name = 'RESERVA_HISTORICO') LOOP
    EXECUTE IMMEDIATE 'DROP ' || o.tipo || ' ' || o.nombre;
  END LOOP;
END;
/

-- ---------------------------------------------------------------------------
-- 1. TABLA RESERVA_HISTORICO en el tablespace TS_HISTORICO
--
-- Por que un tablespace aparte para el historico:
--  - Las reservas cerradas (COMPLETADA o CANCELADA de periodos anteriores) casi
--    no se modifican, solo se consultan para reportes. Las reservas activas se
--    insertan y actualizan todo el tiempo. Separarlas evita que el historico,
--    que crece cada mes, llene el tablespace USERS donde trabaja la operacion.
--  - Se puede respaldar con otra frecuencia (el historico no cambia, basta un
--    backup mensual) e incluso ponerlo en READ ONLY despues de cada cierre.
--  - En un servidor real el datafile puede ir en un disco mas barato o lento,
--    porque no esta en el camino de las transacciones del dia a dia.
--  - Si el historico se llena (MAXSIZE 1G) no se detienen las reservas nuevas.
--
-- La tabla es una "foto" desnormalizada de cada reserva cerrada: guarda nombres
-- y totales ya calculados para que los reportes no tengan que recalcular la
-- estadia noche a noche. Se llena con pkg_turismouq.sp_archivar_historico.
-- ---------------------------------------------------------------------------
CREATE TABLE reserva_historico (
  id_reserva         NUMBER(10)          NOT NULL,
  id_cliente         NUMBER(10)          NOT NULL,
  cliente            VARCHAR2(170 CHAR)  NOT NULL,
  id_alojamiento     NUMBER(10)          NOT NULL,
  alojamiento        VARCHAR2(120 CHAR)  NOT NULL,
  municipio          VARCHAR2(60 CHAR)   NOT NULL,
  estado             VARCHAR2(10)        NOT NULL,
  fecha_creacion     DATE                NOT NULL,
  fecha_checkin      DATE                NOT NULL,
  fecha_checkout     DATE                NOT NULL,
  fecha_cancelacion  DATE,
  habitaciones       NUMBER(3)           NOT NULL,
  huespedes          NUMBER(4)           NOT NULL,
  noches_habitacion  NUMBER(5)           NOT NULL,
  valor_estadia      NUMBER(14,2)        NOT NULL,
  valor_servicios    NUMBER(14,2)        NOT NULL,
  pagado_neto        NUMBER(14,2)        NOT NULL,
  fecha_archivo      DATE                DEFAULT SYSDATE NOT NULL,
  CONSTRAINT pk_reserva_historico PRIMARY KEY (id_reserva)
    USING INDEX TABLESPACE ts_historico,
  CONSTRAINT ck_hist_estado CHECK (estado IN ('COMPLETADA', 'CANCELADA'))
) TABLESPACE ts_historico;

COMMENT ON TABLE reserva_historico IS 'Foto de reservas cerradas (completadas o canceladas), guardada en TS_HISTORICO.';

-- ---------------------------------------------------------------------------
-- 2. VISTA MATERIALIZADA MV_OCUPACION_MENSUAL
--
-- Una fila por alojamiento y mes (2024-01 a 2026-12) con:
--   noches ocupadas, noches disponibles (habitaciones x dias del mes),
--   porcentaje de ocupacion, reservas que llegaron en el mes y huespedes-noche.
-- Ocupada = linea de reserva CONFIRMADA o COMPLETADA (igual que la consulta C1).
-- Cada linea se parte en noches con la tabla de numeros k (0..30).
-- Por municipio o por tipo se obtiene sumando sus filas.
--
-- Politica de refresco: COMPLETE, automatico todos los dias a las 2:00 a.m.
--  - FAST (incremental) no es posible: la consulta parte cada reserva en noches
--    con CONNECT BY y usa subconsultas agrupadas; Oracle no puede aplicar solo
--    los cambios del log a ese tipo de consulta.
--  - ON COMMIT tampoco conviene: cada reserva nueva tendria que recalcular toda
--    la vista dentro de la misma transaccion y la volveria lenta.
--  - La ocupacion es un indicador de gerencia que se revisa por mes; tener los
--    datos con hasta un dia de atraso no afecta ninguna decision.
--  - A las 2:00 a.m. casi no hay reservas en la plataforma, asi que el
--    recalculo completo (unos segundos) no compite con la operacion.
--  - Si se necesita al instante (por ejemplo para una reunion) se puede forzar:
--      EXEC DBMS_MVIEW.REFRESH('MV_OCUPACION_MENSUAL', 'C');
-- ---------------------------------------------------------------------------
CREATE MATERIALIZED VIEW mv_ocupacion_mensual
  BUILD IMMEDIATE
  REFRESH COMPLETE
  START WITH TRUNC(SYSDATE) + 1 + 2/24
  NEXT TRUNC(SYSDATE) + 1 + 2/24
AS
SELECT a.id_alojamiento,
       a.nombre_comercial                                   AS alojamiento,
       mu.nombre                                            AS municipio,
       tp.nombre                                            AS tipo,
       me.mes,
       h.n_hab                                              AS habitaciones,
       h.n_hab * me.dias                                    AS noches_disponibles,
       NVL(o.noches, 0)                                     AS noches_ocupadas,
       ROUND(100 * NVL(o.noches, 0) / (h.n_hab * me.dias), 2) AS pct_ocupacion,
       NVL(o.huespedes_noche, 0)                            AS huespedes_noche,
       NVL(ll.reservas, 0)                                  AS reservas_llegadas
  FROM alojamiento a
  JOIN municipio mu        ON mu.id_municipio = a.id_municipio
  JOIN tipo_alojamiento tp ON tp.id_tipo      = a.id_tipo
  JOIN (SELECT id_alojamiento, COUNT(*) AS n_hab
          FROM habitacion GROUP BY id_alojamiento) h
       ON h.id_alojamiento = a.id_alojamiento
 CROSS JOIN (SELECT ADD_MONTHS(DATE '2024-01-01', LEVEL - 1) AS mes,
                    ADD_MONTHS(DATE '2024-01-01', LEVEL) - ADD_MONTHS(DATE '2024-01-01', LEVEL - 1) AS dias
               FROM dual CONNECT BY LEVEL <= 36) me
  LEFT JOIN (SELECT rh.id_alojamiento,
                    TRUNC(rh.fecha_checkin + k.n, 'MM') AS mes,
                    COUNT(*)                          AS noches,
                    SUM(rh.num_huespedes)             AS huespedes_noche
               FROM reserva_habitacion rh
               JOIN reserva r ON r.id_reserva = rh.id_reserva
               JOIN (SELECT LEVEL - 1 AS n FROM dual CONNECT BY LEVEL <= 31) k
                 ON k.n < rh.fecha_checkout - rh.fecha_checkin
              WHERE r.estado IN ('CONFIRMADA', 'COMPLETADA')
              GROUP BY rh.id_alojamiento, TRUNC(rh.fecha_checkin + k.n, 'MM')) o
       ON o.id_alojamiento = a.id_alojamiento AND o.mes = me.mes
  LEFT JOIN (SELECT id_alojamiento, TRUNC(fecha_checkin, 'MM') AS mes, COUNT(*) AS reservas
               FROM reserva
              WHERE estado IN ('CONFIRMADA', 'COMPLETADA')
              GROUP BY id_alojamiento, TRUNC(fecha_checkin, 'MM')) ll
       ON ll.id_alojamiento = a.id_alojamiento AND ll.mes = me.mes;

CREATE INDEX ix_mv_ocup_aloj_mes ON mv_ocupacion_mensual (id_alojamiento, mes);

COMMENT ON MATERIALIZED VIEW mv_ocupacion_mensual IS 'Ocupacion mensual por alojamiento; refresco completo diario a las 2 a.m.';

-- Verificacion
SELECT mview_name, refresh_method, refresh_mode, build_mode, last_refresh_date
  FROM user_mviews WHERE mview_name = 'MV_OCUPACION_MENSUAL';

SELECT table_name, tablespace_name FROM user_tables WHERE table_name = 'RESERVA_HISTORICO';

-- Ejemplo de uso: ocupacion de 2025 por municipio a partir de la vista
SELECT municipio,
       ROUND(100 * SUM(noches_ocupadas) / SUM(noches_disponibles), 1) AS pct_ocupacion_2025
  FROM mv_ocupacion_mensual
 WHERE mes >= DATE '2025-01-01' AND mes < DATE '2026-01-01'
 GROUP BY municipio
 ORDER BY 2 DESC;
