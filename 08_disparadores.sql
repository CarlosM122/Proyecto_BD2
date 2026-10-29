-- Script 8: Disparadores (Entrega 2)
-- Parte A: auditoria de cambios en TARIFA a nivel de sentencia.
-- Parte B: disparador a nivel de fila que impide solapes de reservas en una
--          misma habitacion, mas otras validaciones de fila.
-- Se corre despues del 07.

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
  FOR o IN (SELECT 'TABLE' tipo, table_name nombre, ' CASCADE CONSTRAINTS PURGE' extra
              FROM user_tables WHERE table_name = 'AUDITORIA_TARIFA'
            UNION ALL
            SELECT 'SEQUENCE', sequence_name, NULL
              FROM user_sequences WHERE sequence_name = 'SEQ_AUD_SENTENCIA'
            UNION ALL
            SELECT 'INDEX', index_name, NULL
              FROM user_indexes WHERE index_name = 'IX_RH_HAB_FECHAS') LOOP
    EXECUTE IMMEDIATE 'DROP ' || o.tipo || ' ' || o.nombre || o.extra;
  END LOOP;
END;
/

-- ===========================================================================
-- PARTE A. AUDITORIA DE TARIFA (disparador a nivel de sentencia)
--
-- Se quiere guardar quien cambio la tarifa, cuando, y el valor anterior y el
-- nuevo. Problema: un disparador de sentencia se ejecuta una sola vez por
-- INSERT/UPDATE/DELETE y NO tiene acceso a :OLD y :NEW (eso solo existe por
-- fila). La solucion clasica es dividir el trabajo:
--   1. BEFORE de sentencia : limpia una lista en memoria (paquete).
--   2. AFTER de fila       : por cada fila cambiada guarda en la lista el
--                            valor anterior (:OLD) y el nuevo (:NEW).
--   3. AFTER de sentencia  : al terminar la sentencia escribe toda la lista en
--                            AUDITORIA_TARIFA con un mismo numero de sentencia,
--                            el usuario y la fecha/hora (se toman una sola vez).
-- Asi un UPDATE que sube 50 tarifas deja 50 filas de detalle agrupadas bajo un
-- solo id_sentencia, y se puede ver que cambio cada sentencia.
-- ===========================================================================

CREATE SEQUENCE seq_aud_sentencia START WITH 1 INCREMENT BY 1 NOCACHE;

CREATE TABLE auditoria_tarifa (
  id_auditoria     NUMBER(12)     GENERATED ALWAYS AS IDENTITY,
  id_sentencia     NUMBER(12)     NOT NULL,
  operacion        VARCHAR2(6)    NOT NULL,
  id_tarifa        NUMBER(10)     NOT NULL,
  id_habitacion    NUMBER(10),
  id_temporada     NUMBER(10),
  precio_anterior  NUMBER(10,2),
  precio_nuevo     NUMBER(10,2),
  usuario_bd       VARCHAR2(128)  NOT NULL,
  usuario_so       VARCHAR2(128),
  equipo           VARCHAR2(128),
  fecha            TIMESTAMP      NOT NULL,
  CONSTRAINT pk_auditoria_tarifa PRIMARY KEY (id_auditoria),
  CONSTRAINT ck_aud_operacion    CHECK (operacion IN ('INSERT', 'UPDATE', 'DELETE'))
);

COMMENT ON TABLE auditoria_tarifa IS 'Cambios en TARIFA: quien, cuando, valor anterior y nuevo. La llena trg_tarifa_aud_sentencia.';

-- Lista en memoria compartida por los tres disparadores (vive en la sesion)
CREATE OR REPLACE PACKAGE pkg_aud_tarifa AS
  TYPE t_cambio IS RECORD (
    operacion        VARCHAR2(6),
    id_tarifa        NUMBER,
    id_habitacion    NUMBER,
    id_temporada     NUMBER,
    precio_anterior  NUMBER,
    precio_nuevo     NUMBER
  );
  TYPE t_cambios IS TABLE OF t_cambio INDEX BY PLS_INTEGER;
  g_cambios t_cambios;
END pkg_aud_tarifa;
/

-- 1. Antes de la sentencia: lista vacia (por si una sentencia anterior fallo a la mitad)
CREATE OR REPLACE TRIGGER trg_tarifa_aud_inicio
BEFORE INSERT OR UPDATE OR DELETE ON tarifa
BEGIN
  pkg_aud_tarifa.g_cambios.DELETE;
END;
/

-- 2. Por cada fila: se guarda el valor anterior y el nuevo
CREATE OR REPLACE TRIGGER trg_tarifa_aud_fila
AFTER INSERT OR UPDATE OR DELETE ON tarifa
FOR EACH ROW
DECLARE
  v_cambio pkg_aud_tarifa.t_cambio;
BEGIN
  -- un UPDATE que deja el mismo precio no es un cambio
  IF UPDATING AND :OLD.precio_noche = :NEW.precio_noche
              AND :OLD.id_habitacion = :NEW.id_habitacion
              AND :OLD.id_temporada = :NEW.id_temporada THEN
    NULL;
  ELSE
    IF INSERTING THEN
      v_cambio.operacion := 'INSERT';
    ELSIF UPDATING THEN
      v_cambio.operacion := 'UPDATE';
    ELSE
      v_cambio.operacion := 'DELETE';
    END IF;
    v_cambio.id_tarifa       := NVL(:NEW.id_tarifa, :OLD.id_tarifa);
    v_cambio.id_habitacion   := NVL(:NEW.id_habitacion, :OLD.id_habitacion);
    v_cambio.id_temporada    := NVL(:NEW.id_temporada, :OLD.id_temporada);
    v_cambio.precio_anterior := :OLD.precio_noche;     -- NULL en un INSERT
    v_cambio.precio_nuevo    := :NEW.precio_noche;     -- NULL en un DELETE
    pkg_aud_tarifa.g_cambios(pkg_aud_tarifa.g_cambios.COUNT + 1) := v_cambio;
  END IF;
END;
/

-- 3. Disparador de SENTENCIA: escribe la auditoria una vez termina la sentencia
CREATE OR REPLACE TRIGGER trg_tarifa_aud_sentencia
AFTER INSERT OR UPDATE OR DELETE ON tarifa
DECLARE
  v_sentencia  NUMBER;
  v_usuario    VARCHAR2(128) := USER;
  v_usuario_so VARCHAR2(128) := SYS_CONTEXT('USERENV', 'OS_USER');
  v_equipo     VARCHAR2(128) := SYS_CONTEXT('USERENV', 'HOST');
  v_fecha      TIMESTAMP     := SYSTIMESTAMP;
BEGIN
  IF pkg_aud_tarifa.g_cambios.COUNT > 0 THEN
    v_sentencia := seq_aud_sentencia.NEXTVAL;
    FOR i IN 1 .. pkg_aud_tarifa.g_cambios.COUNT LOOP
      INSERT INTO auditoria_tarifa (id_sentencia, operacion, id_tarifa, id_habitacion, id_temporada,
                                    precio_anterior, precio_nuevo, usuario_bd, usuario_so, equipo, fecha)
      VALUES (v_sentencia,
              pkg_aud_tarifa.g_cambios(i).operacion,
              pkg_aud_tarifa.g_cambios(i).id_tarifa,
              pkg_aud_tarifa.g_cambios(i).id_habitacion,
              pkg_aud_tarifa.g_cambios(i).id_temporada,
              pkg_aud_tarifa.g_cambios(i).precio_anterior,
              pkg_aud_tarifa.g_cambios(i).precio_nuevo,
              v_usuario, v_usuario_so, v_equipo, v_fecha);
    END LOOP;
    pkg_aud_tarifa.g_cambios.DELETE;
  END IF;
END;
/

-- ===========================================================================
-- PARTE B. DISPARADORES DE FILA SOBRE RESERVA_HABITACION Y RESENA
-- ===========================================================================

-- Indice para que la busqueda de solapes no recorra toda la tabla en cada
-- insercion (sin el, cada linea nueva revisaria las 32.000 lineas).
CREATE INDEX ix_rh_hab_fechas ON reserva_habitacion (id_habitacion, fecha_checkin, fecha_checkout);

-- ---------------------------------------------------------------------------
-- trg_rh_no_solape (FILA): impide registrar una linea si la misma habitacion
-- ya esta ocupada en alguna de esas noches por OTRA reserva CONFIRMADA o
-- COMPLETADA. Dos estadias [a,b) y [c,d) se cruzan si a < d y c < b (el dia
-- de salida de una puede ser el de llegada de la otra).
-- Es la ultima linea de defensa: aunque alguien inserte directo en la tabla
-- sin pasar por sp_crear_reserva, el motor no deja guardar el solape.
--
-- Nota: el disparador consulta la misma tabla que se esta insertando. Oracle
-- lo permite en un INSERT ... VALUES de una fila (que es como insertan los
-- procedimientos del paquete). Con un INSERT ... SELECT o un UPDATE daria el
-- error de tabla mutante (ORA-04091); por eso las fechas y la habitacion de
-- una linea no se pueden modificar (ver trg_rh_sin_cambios).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_rh_no_solape
BEFORE INSERT ON reserva_habitacion
FOR EACH ROW
DECLARE
  v_cruces      NUMBER;
  v_otra        NUMBER;
  v_otra_in     DATE;
  v_otra_out    DATE;
BEGIN
  SELECT COUNT(*), MIN(rh.id_reserva), MIN(rh.fecha_checkin), MIN(rh.fecha_checkout)
    INTO v_cruces, v_otra, v_otra_in, v_otra_out
    FROM reserva_habitacion rh
    JOIN reserva r ON r.id_reserva = rh.id_reserva
   WHERE rh.id_habitacion = :NEW.id_habitacion
     AND rh.id_reserva   <> :NEW.id_reserva
     AND r.estado IN ('CONFIRMADA', 'COMPLETADA')
     AND rh.fecha_checkin < :NEW.fecha_checkout
     AND :NEW.fecha_checkin < rh.fecha_checkout;

  IF v_cruces > 0 THEN
    RAISE_APPLICATION_ERROR(-20005,
      'Solape: la habitacion ' || :NEW.id_habitacion || ' ya esta ocupada por la reserva '
      || v_otra || ' (' || TO_CHAR(v_otra_in, 'YYYY-MM-DD') || ' a '
      || TO_CHAR(v_otra_out, 'YYYY-MM-DD') || ')');
  END IF;
END;
/

-- ---------------------------------------------------------------------------
-- trg_rh_valida_linea (FILA): las fechas de la linea deben quedar dentro del
-- rango de la reserva y los huespedes no pueden pasar la capacidad. Son dos
-- reglas que el DDL no podia declarar con CHECK porque comparan con otras tablas.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_rh_valida_linea
BEFORE INSERT OR UPDATE OF num_huespedes ON reserva_habitacion
FOR EACH ROW
DECLARE
  v_in   reserva.fecha_checkin%TYPE;
  v_out  reserva.fecha_checkout%TYPE;
  v_cap  habitacion.capacidad%TYPE;
BEGIN
  SELECT fecha_checkin, fecha_checkout INTO v_in, v_out
    FROM reserva WHERE id_reserva = :NEW.id_reserva;

  IF :NEW.fecha_checkin < v_in OR :NEW.fecha_checkout > v_out THEN
    RAISE_APPLICATION_ERROR(-20008, 'La linea (' || TO_CHAR(:NEW.fecha_checkin, 'YYYY-MM-DD') || ' a '
                            || TO_CHAR(:NEW.fecha_checkout, 'YYYY-MM-DD')
                            || ') se sale del rango de la reserva ' || :NEW.id_reserva);
  END IF;

  SELECT capacidad INTO v_cap FROM habitacion WHERE id_habitacion = :NEW.id_habitacion;
  IF :NEW.num_huespedes > v_cap THEN
    RAISE_APPLICATION_ERROR(-20004, 'Capacidad excedida: la habitacion ' || :NEW.id_habitacion
                            || ' admite ' || v_cap || ' huespedes');
  END IF;
END;
/

-- ---------------------------------------------------------------------------
-- trg_rh_sin_cambios (FILA): no se cambian la habitacion ni las fechas de una
-- linea ya creada. Para cambiar fechas se cancela y se crea otra reserva; asi
-- toda linea pasa por la validacion de solape al insertarse.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_rh_sin_cambios
BEFORE UPDATE OF id_reserva, id_habitacion, fecha_checkin, fecha_checkout ON reserva_habitacion
FOR EACH ROW
BEGIN
  RAISE_APPLICATION_ERROR(-20009, 'No se puede cambiar la habitacion o las fechas de una linea; '
                          || 'cancele la reserva y cree una nueva');
END;
/

-- ---------------------------------------------------------------------------
-- trg_resena_valida (FILA): solo se resena una reserva COMPLETADA y despues
-- del checkout (regla de la seccion 1.6 y regla R7 del documento).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_resena_valida
BEFORE INSERT ON resena
FOR EACH ROW
DECLARE
  v_estado reserva.estado%TYPE;
  v_out    reserva.fecha_checkout%TYPE;
BEGIN
  SELECT estado, fecha_checkout INTO v_estado, v_out
    FROM reserva WHERE id_reserva = :NEW.id_reserva;

  IF v_estado <> 'COMPLETADA' THEN
    RAISE_APPLICATION_ERROR(-20010, 'Solo se puede resenar una reserva COMPLETADA (la reserva '
                            || :NEW.id_reserva || ' esta ' || v_estado || ')');
  END IF;
  IF :NEW.fecha_resena < v_out THEN
    RAISE_APPLICATION_ERROR(-20010, 'La resena no puede ser anterior al checkout ('
                            || TO_CHAR(v_out, 'YYYY-MM-DD') || ')');
  END IF;
END;
/

-- Verificacion
SELECT trigger_name, trigger_type, triggering_event, table_name, status
  FROM user_triggers
 WHERE table_name IN ('TARIFA', 'RESERVA_HABITACION', 'RESENA')
 ORDER BY table_name, trigger_name;
