-- Script 3: Consultas de analisis (Entrega 1, corregido)
-- Ejecutar con F5 despues del 01 y el 02.
-- En las consultas de dinero se usa el ingreso neto: pagos EXITOSO - REEMBOLSADO.

SET PAGESIZE 200
SET LINESIZE 250
SET DEFINE OFF
SET SQLBLANKLINES ON
ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD';

-- formato de columnas
COLUMN municipio         FORMAT A22
COLUMN alojamiento       FORMAT A34
COLUMN tipo              FORMAT A15
COLUMN tipo_alojamiento  FORMAT A22
COLUMN temporada         FORMAT A16
COLUMN cliente           FORMAT A32
COLUMN estado            FORMAT A10
COLUMN evento            FORMAT A14
COLUMN diagnostico       FORMAT A14

-- C1. Ocupacion por municipio y mes (PIVOT)
-- ocupacion % = noches-habitacion ocupadas / noches-habitacion disponibles.
-- Cada linea de reserva se parte en noches (tabla k) y cada noche cuenta en su mes.
-- Solo cuentan CONFIRMADA y COMPLETADA.
WITH k AS (
  SELECT LEVEL - 1 AS n FROM dual CONNECT BY LEVEL <= 31
),
dias AS (
  SELECT DATE '2024-01-01' + LEVEL - 1 AS dia
    FROM dual CONNECT BY LEVEL <= DATE '2026-12-31' - DATE '2024-01-01' + 1
),
meses AS (
  SELECT TRUNC(dia, 'MM') AS mes, COUNT(*) AS dias_mes FROM dias GROUP BY TRUNC(dia, 'MM')
),
habs AS (
  SELECT a.id_municipio, COUNT(*) AS n_hab
    FROM habitacion h JOIN alojamiento a ON a.id_alojamiento = h.id_alojamiento
   GROUP BY a.id_municipio
),
ocupadas AS (
  SELECT a.id_municipio,
         TRUNC(rh.fecha_checkin + k.n, 'MM') AS mes,
         COUNT(*)                            AS noches
    FROM reserva_habitacion rh
    JOIN reserva     r ON r.id_reserva     = rh.id_reserva
    JOIN alojamiento a ON a.id_alojamiento = rh.id_alojamiento
    JOIN k             ON k.n < rh.fecha_checkout - rh.fecha_checkin
   WHERE r.estado IN ('CONFIRMADA', 'COMPLETADA')
   GROUP BY a.id_municipio, TRUNC(rh.fecha_checkin + k.n, 'MM')
),
base AS (
  SELECT mu.nombre                                   AS municipio,
         EXTRACT(YEAR FROM me.mes)                   AS anio,
         TO_CHAR(me.mes, 'MM')                       AS mes,
         ROUND(100 * NVL(o.noches, 0) / (h.n_hab * me.dias_mes), 1) AS pct
    FROM habs h
    JOIN municipio mu ON mu.id_municipio = h.id_municipio
   CROSS JOIN meses me
    LEFT JOIN ocupadas o ON o.id_municipio = h.id_municipio AND o.mes = me.mes
)
SELECT *
  FROM base
 PIVOT (MAX(pct) FOR mes IN ('01' AS ene, '02' AS feb, '03' AS mar, '04' AS abr,
                             '05' AS may, '06' AS jun, '07' AS jul, '08' AS ago,
                             '09' AS sep, '10' AS oct, '11' AS nov, '12' AS dic))
 ORDER BY municipio, anio;

-- C2. Ingresos por municipio, tipo de alojamiento y temporada (ROLLUP + GROUPING)
-- Si una estadia cruza temporadas, su ingreso se reparte segun el valor de las noches
-- que cayeron en cada nivel. GROUPING = 1 marca las filas de subtotal.
WITH k AS (
  SELECT LEVEL - 1 AS n FROM dual CONNECT BY LEVEL <= 31
),
neto AS (
  SELECT id_reserva,
         SUM(CASE estado WHEN 'EXITOSO' THEN monto WHEN 'REEMBOLSADO' THEN -monto ELSE 0 END) AS ingreso
    FROM pago
   GROUP BY id_reserva
),
noches AS (
  SELECT rh.id_reserva, te.nivel, SUM(tf.precio_noche) AS valor
    FROM reserva_habitacion rh
    JOIN k            ON k.n < rh.fecha_checkout - rh.fecha_checkin
    JOIN temporada te ON rh.fecha_checkin + k.n BETWEEN te.fecha_inicio AND te.fecha_fin
    JOIN tarifa    tf ON tf.id_habitacion = rh.id_habitacion AND tf.id_temporada = te.id_temporada
   GROUP BY rh.id_reserva, te.nivel
),
reparto AS (
  SELECT id_reserva, nivel, valor / SUM(valor) OVER (PARTITION BY id_reserva) AS peso
    FROM noches
)
SELECT CASE WHEN GROUPING(mu.nombre) = 1 THEN '*** TOTAL GENERAL ***' ELSE mu.nombre END AS municipio,
       CASE WHEN GROUPING(mu.nombre) = 1 THEN ' '
            WHEN GROUPING(tp.nombre) = 1 THEN '** Subtotal municipio' ELSE tp.nombre END  AS tipo_alojamiento,
       CASE WHEN GROUPING(tp.nombre) = 1 THEN ' '
            WHEN GROUPING(rp.nivel)  = 1 THEN '* Subtotal tipo'       ELSE rp.nivel  END  AS temporada,
       TO_CHAR(ROUND(SUM(ne.ingreso * rp.peso)), '999G999G999G990')                     AS ingreso_neto_cop
  FROM reparto rp
  JOIN neto             ne ON ne.id_reserva     = rp.id_reserva
  JOIN reserva          r  ON r.id_reserva      = rp.id_reserva
  JOIN alojamiento      a  ON a.id_alojamiento  = r.id_alojamiento
  JOIN municipio        mu ON mu.id_municipio   = a.id_municipio
  JOIN tipo_alojamiento tp ON tp.id_tipo        = a.id_tipo
 GROUP BY ROLLUP (mu.nombre, tp.nombre, rp.nivel)
 ORDER BY GROUPING(mu.nombre), mu.nombre,
          GROUPING(tp.nombre), tp.nombre,
          GROUPING(rp.nivel),
          DECODE(rp.nivel, 'ALTA', 1, 'MEDIA', 2, 'BAJA', 3);

-- C3. Top 3 alojamientos por ingreso dentro de cada municipio (RANK + PARTITION BY)
-- participacion_pct = parte del ingreso del municipio que tiene ese alojamiento.
WITH neto AS (
  SELECT id_reserva,
         SUM(CASE estado WHEN 'EXITOSO' THEN monto WHEN 'REEMBOLSADO' THEN -monto ELSE 0 END) AS ingreso
    FROM pago
   GROUP BY id_reserva
)
SELECT municipio, puesto, alojamiento, tipo,
       TO_CHAR(ingreso, '999G999G999G990') AS ingreso_neto_cop,
       participacion_pct
  FROM (SELECT mu.nombre         AS municipio,
               a.nombre_comercial AS alojamiento,
               tp.nombre         AS tipo,
               SUM(ne.ingreso)   AS ingreso,
               RANK() OVER (PARTITION BY mu.id_municipio ORDER BY SUM(ne.ingreso) DESC) AS puesto,
               ROUND(100 * RATIO_TO_REPORT(SUM(ne.ingreso)) OVER (PARTITION BY mu.id_municipio), 1)
                                 AS participacion_pct
          FROM neto ne
          JOIN reserva          r  ON r.id_reserva     = ne.id_reserva
          JOIN alojamiento      a  ON a.id_alojamiento = r.id_alojamiento
          JOIN municipio        mu ON mu.id_municipio  = a.id_municipio
          JOIN tipo_alojamiento tp ON tp.id_tipo       = a.id_tipo
         GROUP BY mu.id_municipio, mu.nombre, a.id_alojamiento, a.nombre_comercial, tp.nombre)
 WHERE puesto <= 3
 ORDER BY municipio, puesto;

-- C4. Variacion de ingresos mes contra mes (LAG)
-- Tambien se compara con el mismo mes del año anterior (LAG de 12).
SELECT mes,
       TO_CHAR(ingreso, '999G999G999G990')                                   AS ingreso_neto,
       TO_CHAR(LAG(ingreso, 1) OVER (ORDER BY mes), '999G999G999G990')       AS mes_anterior,
       TO_CHAR(ingreso - LAG(ingreso, 1) OVER (ORDER BY mes), 'S99G999G999G990') AS variacion,
       ROUND(100 * (ingreso - LAG(ingreso, 1) OVER (ORDER BY mes))
                 / NULLIF(LAG(ingreso, 1) OVER (ORDER BY mes), 0), 1)        AS var_mensual_pct,
       ROUND(100 * (ingreso - LAG(ingreso, 12) OVER (ORDER BY mes))
                 / NULLIF(LAG(ingreso, 12) OVER (ORDER BY mes), 0), 1)       AS var_anual_pct
  FROM (SELECT TO_CHAR(fecha_pago, 'YYYY-MM') AS mes,
               SUM(CASE estado WHEN 'EXITOSO' THEN monto WHEN 'REEMBOLSADO' THEN -monto END) AS ingreso
          FROM pago
         WHERE estado IN ('EXITOSO', 'REEMBOLSADO')
           AND fecha_pago >= DATE '2024-01-01'
         GROUP BY TO_CHAR(fecha_pago, 'YYYY-MM'))
 ORDER BY mes;

-- C5. Consulta parametrizada con variables de enlace
-- Reservas que tienen huespedes dentro del rango :v_desde - :v_hasta.
-- :v_municipio = NULL trae todos los municipios. Cambiar los EXEC para otro rango.
VARIABLE v_desde     VARCHAR2(10)
VARIABLE v_hasta     VARCHAR2(10)
VARIABLE v_municipio VARCHAR2(60)

EXEC :v_desde     := '2025-12-20';
EXEC :v_hasta     := '2025-12-31';
EXEC :v_municipio := 'Salento';

SELECT r.id_reserva,
       c.nombre || ' ' || c.apellido                    AS cliente,
       mu.nombre                                        AS municipio,
       a.nombre_comercial                               AS alojamiento,
       r.fecha_checkin,
       r.fecha_checkout,
       r.fecha_checkout - r.fecha_checkin               AS noches,
       (SELECT COUNT(*) FROM reserva_habitacion rh WHERE rh.id_reserva = r.id_reserva) AS habitaciones,
       r.estado,
       NVL((SELECT SUM(CASE p.estado WHEN 'EXITOSO' THEN p.monto WHEN 'REEMBOLSADO' THEN -p.monto ELSE 0 END)
              FROM pago p WHERE p.id_reserva = r.id_reserva), 0) AS pagado_neto
  FROM reserva r
  JOIN cliente     c  ON c.id_cliente      = r.id_cliente
  JOIN alojamiento a  ON a.id_alojamiento  = r.id_alojamiento
  JOIN municipio   mu ON mu.id_municipio   = a.id_municipio
 WHERE r.fecha_checkin  <= TO_DATE(:v_hasta, 'YYYY-MM-DD')
   AND r.fecha_checkout >  TO_DATE(:v_desde, 'YYYY-MM-DD')
   AND (:v_municipio IS NULL OR mu.nombre = :v_municipio)
 ORDER BY r.fecha_checkin, alojamiento, r.id_reserva;

-- C6. Actividad por mes (UNPIVOT)
-- Las 4 fechas de RESERVA (creacion, check-in, check-out, cancelacion) pasan a filas.
-- UNPIVOT no incluye los NULL, por eso las no canceladas no cuentan como cancelacion.
SELECT TO_CHAR(fecha, 'YYYY-MM') AS mes,
       evento,
       COUNT(*)                  AS cantidad
  FROM (SELECT id_reserva,
               TRUNC(fecha_creacion)    AS creada,
               fecha_checkin            AS llegada,
               fecha_checkout           AS salida,
               TRUNC(fecha_cancelacion) AS cancelada
          FROM reserva)
UNPIVOT (fecha FOR evento IN (creada    AS '1-CREACION',
                              llegada   AS '2-CHECK-IN',
                              salida    AS '3-CHECK-OUT',
                              cancelada AS '4-CANCELACION'))
 WHERE fecha >= DATE '2025-01-01' AND fecha < DATE '2026-01-01'
 GROUP BY TO_CHAR(fecha, 'YYYY-MM'), evento
 ORDER BY mes, evento;

-- C7. Consulta libre: las estrellas que se pone cada alojamiento vs. las reseñas
-- brecha = promedio de reseñas - estrellas. Solo alojamientos con 20 reseñas o mas.
SELECT municipio, puesto_municipio, alojamiento, estrellas, promedio_clientes,
       brecha, n_resenas, tasa_resena_pct,
       CASE WHEN brecha <= -0.75 THEN 'SOBREVALORADO'
            WHEN brecha >=  0.75 THEN 'SUBVALORADO'
            ELSE 'COHERENTE' END AS diagnostico
  FROM (SELECT mu.nombre                               AS municipio,
               a.nombre_comercial                      AS alojamiento,
               a.estrellas,
               ROUND(AVG(re.calificacion), 2)          AS promedio_clientes,
               ROUND(AVG(re.calificacion) - a.estrellas, 2) AS brecha,
               COUNT(re.id_resena)                     AS n_resenas,
               ROUND(100 * COUNT(re.id_resena) / COUNT(*), 1) AS tasa_resena_pct,
               DENSE_RANK() OVER (PARTITION BY mu.id_municipio
                                  ORDER BY AVG(re.calificacion) DESC NULLS LAST) AS puesto_municipio
          FROM reserva r
          JOIN alojamiento a  ON a.id_alojamiento = r.id_alojamiento
          JOIN municipio   mu ON mu.id_municipio  = a.id_municipio
          LEFT JOIN resena re ON re.id_reserva    = r.id_reserva
         WHERE r.estado = 'COMPLETADA'
         GROUP BY mu.id_municipio, mu.nombre, a.id_alojamiento, a.nombre_comercial, a.estrellas
        HAVING COUNT(re.id_resena) >= 20)
 ORDER BY municipio, puesto_municipio;
