-- Script 9: Pruebas de la Entrega 2 (evidencia)
-- Se corre con F5 despues del 08. Cada prueba imprime lo que se espera y lo
-- que paso. Al final borra las reservas de prueba para dejar la base como
-- estaba (la auditoria, la liquidacion y el historico si se quedan).
--
-- Las fechas de las pruebas se calculan desde hoy (SYSDATE + n dias). Las
-- temporadas cargadas llegan hasta el 11-ene-2027, asi que este script debe
-- correrse antes del 15 de diciembre de 2026 (despues hay que cargar las
-- temporadas de 2027).

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

SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF
SET SQLBLANKLINES ON
SET LINESIZE 200
SET PAGESIZE 100
ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD';

COLUMN temporada      FORMAT A40
COLUMN nivel          FORMAT A6
COLUMN alojamiento    FORMAT A34
COLUMN municipio      FORMAT A14
COLUMN estado         FORMAT A11
COLUMN metodo         FORMAT A15
COLUMN operacion      FORMAT A9
COLUMN usuario_bd     FORMAT A15
COLUMN usuario_so     FORMAT A15
COLUMN equipo         FORMAT A18
COLUMN fecha_hora     FORMAT A23
COLUMN segment_name   FORMAT A22
COLUMN tablespace_name FORMAT A15

VARIABLE v_max_res NUMBER
VARIABLE v_hab     NUMBER
VARIABLE v_hab2    NUMBER
VARIABLE v_hab3    NUMBER
VARIABLE v_res     NUMBER
VARIABLE v_res_a   NUMBER
VARIABLE v_res_b   NUMBER
VARIABLE v_tmp     NUMBER
VARIABLE v_noches_antes NUMBER

-- id mas alto antes de las pruebas (para borrar lo de prueba al final)
EXEC SELECT NVL(MAX(id_reserva), 0) INTO :v_max_res FROM reserva;

-- El paquete y los disparadores deben estar VALID / ENABLED
SELECT object_name, object_type, status FROM user_objects
 WHERE object_name IN ('PKG_TURISMOUQ', 'PKG_AUD_TARIFA') ORDER BY 1, 2;


-- ===========================================================================
-- PRUEBA 1. fn_valor_estadia con una estadia que cruza dos temporadas
-- Habitacion 101 del Hotel Torre Quimbaya Centro, del 12 al 17 de dic de 2026:
-- las noches 12, 13 y 14 son temporada MEDIA y 15 y 16 son ALTA (el 17 es la
-- salida y no se cobra). El valor de la funcion debe ser la suma del detalle.
-- ===========================================================================
EXEC SELECT MIN(id_habitacion) INTO :v_hab FROM habitacion WHERE id_alojamiento = 1;

SELECT TO_CHAR(DATE '2026-12-12' + k.n, 'YYYY-MM-DD') AS noche,
       te.nombre AS temporada, te.nivel, t.precio_noche
  FROM (SELECT LEVEL - 1 AS n FROM dual CONNECT BY LEVEL <= 5) k
  JOIN temporada te ON DATE '2026-12-12' + k.n BETWEEN te.fecha_inicio AND te.fecha_fin
  JOIN tarifa t     ON t.id_temporada = te.id_temporada AND t.id_habitacion = :v_hab
 ORDER BY 1;

SELECT pkg_turismouq.fn_valor_estadia(:v_hab, DATE '2026-12-12', DATE '2026-12-17') AS valor_funcion,
       (SELECT SUM(t.precio_noche)
          FROM (SELECT LEVEL - 1 AS n FROM dual CONNECT BY LEVEL <= 5) k
          JOIN temporada te ON DATE '2026-12-12' + k.n BETWEEN te.fecha_inicio AND te.fecha_fin
          JOIN tarifa t     ON t.id_temporada = te.id_temporada AND t.id_habitacion = :v_hab) AS suma_detalle
  FROM dual;


-- ===========================================================================
-- PRUEBA 2. sp_crear_reserva (caso exitoso) y reserva de grupo
-- Se busca una habitacion libre del alojamiento 1 entre hoy+20 y hoy+23.
-- Luego se agrega otra habitacion del mismo grupo que llega un dia despues.
-- ===========================================================================
BEGIN
  SELECT MIN(h.id_habitacion) INTO :v_hab2
    FROM habitacion h
   WHERE h.id_alojamiento = 1 AND h.capacidad >= 2
     AND NOT EXISTS (SELECT 1 FROM reserva_habitacion rh JOIN reserva r ON r.id_reserva = rh.id_reserva
                      WHERE rh.id_habitacion = h.id_habitacion AND r.estado <> 'CANCELADA'
                        AND rh.fecha_checkin < TRUNC(SYSDATE) + 23 AND TRUNC(SYSDATE) + 20 < rh.fecha_checkout);
  SELECT MIN(h.id_habitacion) INTO :v_hab3
    FROM habitacion h
   WHERE h.id_alojamiento = 1 AND h.id_habitacion <> :v_hab2
     AND NOT EXISTS (SELECT 1 FROM reserva_habitacion rh JOIN reserva r ON r.id_reserva = rh.id_reserva
                      WHERE rh.id_habitacion = h.id_habitacion AND r.estado <> 'CANCELADA'
                        AND rh.fecha_checkin < TRUNC(SYSDATE) + 23 AND TRUNC(SYSDATE) + 21 < rh.fecha_checkout);

  DBMS_OUTPUT.PUT_LINE('--- Prueba 2: crear reserva ---');
  pkg_turismouq.sp_crear_reserva(p_id_cliente    => 1,
                                 p_id_habitacion => :v_hab2,
                                 p_fecha_in      => TRUNC(SYSDATE) + 20,
                                 p_fecha_out     => TRUNC(SYSDATE) + 23,
                                 p_num_huespedes => 2,
                                 p_id_reserva    => :v_res);
  pkg_turismouq.sp_agregar_habitacion(:v_res, :v_hab3, TRUNC(SYSDATE) + 21, TRUNC(SYSDATE) + 23, 1);
  DBMS_OUTPUT.PUT_LINE('Valor total de la reserva: '
                       || TO_CHAR(pkg_turismouq.fn_valor_reserva(:v_res), 'FM999G999G990'));
END;
/

SELECT r.id_reserva, r.estado, r.fecha_checkin, r.fecha_checkout,
       rh.id_habitacion, rh.fecha_checkin AS linea_in, rh.fecha_checkout AS linea_out, rh.num_huespedes
  FROM reserva r JOIN reserva_habitacion rh ON rh.id_reserva = r.id_reserva
 WHERE r.id_reserva = :v_res;


-- ===========================================================================
-- PRUEBA 3. Excepciones propias de sp_crear_reserva
-- Cada bloque DEBE fallar con su codigo; si no falla, imprime "ERROR".
-- ===========================================================================

-- 3a. checkout igual al checkin -> -20001
BEGIN
  pkg_turismouq.sp_crear_reserva(1, :v_hab2, TRUNC(SYSDATE) + 30, TRUNC(SYSDATE) + 30, 1, :v_tmp);
  DBMS_OUTPUT.PUT_LINE('3a ERROR: no se rechazo');
EXCEPTION
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('3a OK (fechas) -> ' || SQLERRM);
END;
/

-- 3b. checkout ANTES del checkin -> -20001
BEGIN
  pkg_turismouq.sp_crear_reserva(1, :v_hab2, TRUNC(SYSDATE) + 30, TRUNC(SYSDATE) + 27, 1, :v_tmp);
  DBMS_OUTPUT.PUT_LINE('3b ERROR: no se rechazo');
EXCEPTION
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('3b OK (fechas) -> ' || SQLERRM);
END;
/

-- 3c. mas huespedes que la capacidad -> -20004
BEGIN
  pkg_turismouq.sp_crear_reserva(1, :v_hab2, TRUNC(SYSDATE) + 30, TRUNC(SYSDATE) + 32, 25, :v_tmp);
  DBMS_OUTPUT.PUT_LINE('3c ERROR: no se rechazo');
EXCEPTION
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('3c OK (capacidad) -> ' || SQLERRM);
END;
/

-- 3d. habitacion ya ocupada por una reserva CONFIRMADA de la carga -> -20005
DECLARE
  v_h   NUMBER;
  v_in  DATE;
  v_out DATE;
BEGIN
  SELECT rh.id_habitacion, rh.fecha_checkin, rh.fecha_checkout
    INTO v_h, v_in, v_out
    FROM reserva_habitacion rh JOIN reserva r ON r.id_reserva = rh.id_reserva
   WHERE r.estado = 'CONFIRMADA' AND rh.fecha_checkin > TRUNC(SYSDATE)
     AND r.id_reserva <= :v_max_res
   ORDER BY rh.fecha_checkin, rh.id_reserva
   FETCH FIRST 1 ROWS ONLY;
  DBMS_OUTPUT.PUT_LINE('3d habitacion ' || v_h || ' ocupada del ' || v_in || ' al ' || v_out);
  pkg_turismouq.sp_crear_reserva(2, v_h, v_in, v_out, 1, :v_tmp);
  DBMS_OUTPUT.PUT_LINE('3d ERROR: no se rechazo');
EXCEPTION
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('3d OK (no disponible) -> ' || SQLERRM);
END;
/

-- 3e. fechas sin temporada cargada (marzo de 2027) -> -20006
BEGIN
  pkg_turismouq.sp_crear_reserva(1, :v_hab2, DATE '2027-03-01', DATE '2027-03-03', 1, :v_tmp);
  DBMS_OUTPUT.PUT_LINE('3e ERROR: no se rechazo');
EXCEPTION
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('3e OK (sin tarifa) -> ' || SQLERRM);
END;
/

-- 3f. check-in en el pasado -> -20002
BEGIN
  pkg_turismouq.sp_crear_reserva(1, :v_hab2, DATE '2025-01-10', DATE '2025-01-12', 1, :v_tmp);
  DBMS_OUTPUT.PUT_LINE('3f ERROR: no se rechazo');
EXCEPTION
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('3f OK (pasado) -> ' || SQLERRM);
END;
/


-- ===========================================================================
-- PRUEBA 4. Pago: con el anticipo la reserva pasa de PENDIENTE a CONFIRMADA
-- y un pago mayor al saldo se rechaza (-20011).
-- ===========================================================================
DECLARE
  v_total NUMBER;
BEGIN
  v_total := pkg_turismouq.fn_valor_reserva(:v_res);
  pkg_turismouq.sp_registrar_pago(:v_res, ROUND(v_total * 0.4, -2), 'TARJETA_CREDITO');
  BEGIN
    pkg_turismouq.sp_registrar_pago(:v_res, v_total, 'PSE');
    DBMS_OUTPUT.PUT_LINE('4 ERROR: se acepto un pago mayor al saldo');
  EXCEPTION
    WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('4 OK (pago mayor al saldo) -> ' || SQLERRM);
  END;
END;
/

SELECT id_reserva, estado FROM reserva WHERE id_reserva = :v_res;


-- ===========================================================================
-- PRUEBA 5. Disparador de FILA trg_rh_no_solape con un caso real
-- Se salta el paquete e inserta DIRECTO en la tabla una linea sobre una
-- habitacion que ya tiene una reserva COMPLETADA en diciembre de 2025.
-- El disparador debe rechazarla (-20005) y la base no debe cambiar.
-- ===========================================================================
DECLARE
  v_h     NUMBER;
  v_aloj  NUMBER;
  v_in    DATE;
  v_out   DATE;
  v_otra  NUMBER;
  v_cab   NUMBER;
BEGIN
  SAVEPOINT antes_prueba5;
  SELECT rh.id_habitacion, rh.id_alojamiento, rh.fecha_checkin, rh.fecha_checkout, rh.id_reserva
    INTO v_h, v_aloj, v_in, v_out, v_otra
    FROM reserva_habitacion rh JOIN reserva r ON r.id_reserva = rh.id_reserva
   WHERE r.estado = 'COMPLETADA' AND rh.fecha_checkin >= DATE '2025-12-20'
   ORDER BY rh.fecha_checkin, rh.id_reserva
   FETCH FIRST 1 ROWS ONLY;
  DBMS_OUTPUT.PUT_LINE('5 la reserva ' || v_otra || ' ocupa la habitacion ' || v_h
                       || ' del ' || v_in || ' al ' || v_out);

  INSERT INTO reserva (id_cliente, id_alojamiento, fecha_checkin, fecha_checkout, estado)
  VALUES (3, v_aloj, v_in, v_out, 'PENDIENTE')
  RETURNING id_reserva INTO v_cab;

  -- misma habitacion y mismas fechas que la reserva completada
  INSERT INTO reserva_habitacion (id_reserva, id_habitacion, id_alojamiento, fecha_checkin, fecha_checkout, num_huespedes)
  VALUES (v_cab, v_h, v_aloj, v_in, v_out, 1);

  DBMS_OUTPUT.PUT_LINE('5 ERROR: el disparador dejo pasar el solape');
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK TO antes_prueba5;
    DBMS_OUTPUT.PUT_LINE('5 OK (disparador de fila) -> ' || SQLERRM);
END;
/

-- 5b. Caso de borde: llegar el MISMO dia que la otra sale SI se permite
DECLARE
  v_h     NUMBER;
  v_aloj  NUMBER;
  v_out   DATE;
  v_cab   NUMBER;
BEGIN
  SAVEPOINT antes_prueba5b;
  SELECT rh.id_habitacion, rh.id_alojamiento, rh.fecha_checkout
    INTO v_h, v_aloj, v_out
    FROM reserva_habitacion rh JOIN reserva r ON r.id_reserva = rh.id_reserva
   WHERE r.estado = 'CONFIRMADA' AND rh.fecha_checkin > TRUNC(SYSDATE)
     AND r.id_reserva <= :v_max_res
     AND NOT EXISTS (SELECT 1 FROM reserva_habitacion x JOIN reserva y ON y.id_reserva = x.id_reserva
                      WHERE x.id_habitacion = rh.id_habitacion AND y.estado <> 'CANCELADA'
                        AND x.fecha_checkin < rh.fecha_checkout + 1 AND rh.fecha_checkout < x.fecha_checkout
                        AND x.id_reserva <> rh.id_reserva)
   ORDER BY rh.fecha_checkin, rh.id_reserva
   FETCH FIRST 1 ROWS ONLY;

  INSERT INTO reserva (id_cliente, id_alojamiento, fecha_checkin, fecha_checkout, estado)
  VALUES (3, v_aloj, v_out, v_out + 1, 'PENDIENTE')
  RETURNING id_reserva INTO v_cab;
  INSERT INTO reserva_habitacion (id_reserva, id_habitacion, id_alojamiento, fecha_checkin, fecha_checkout, num_huespedes)
  VALUES (v_cab, v_h, v_aloj, v_out, v_out + 1, 1);
  DBMS_OUTPUT.PUT_LINE('5b OK: se acepto la llegada el ' || v_out || ' (el mismo dia que sale la otra reserva)');
  ROLLBACK TO antes_prueba5b;
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK TO antes_prueba5b;
    DBMS_OUTPUT.PUT_LINE('5b ERROR -> ' || SQLERRM);
END;
/

-- 5c. trg_rh_sin_cambios: no se pueden mover las fechas de una linea -> -20009
BEGIN
  UPDATE reserva_habitacion SET fecha_checkout = fecha_checkout + 1 WHERE id_reserva = :v_res;
  DBMS_OUTPUT.PUT_LINE('5c ERROR: se permitio cambiar fechas');
EXCEPTION
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('5c OK -> ' || SQLERRM);
END;
/

-- 5d. trg_resena_valida: no se puede resenar una reserva que no esta COMPLETADA -> -20010
BEGIN
  INSERT INTO resena (id_reserva, id_alojamiento, calificacion, comentario)
  SELECT id_reserva, id_alojamiento, 5, 'Prueba' FROM reserva WHERE id_reserva = :v_res;
  DBMS_OUTPUT.PUT_LINE('5d ERROR: se acepto la resena');
EXCEPTION
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('5d OK -> ' || SQLERRM);
END;
/


-- ===========================================================================
-- PRUEBA 6. Cancelacion y regla de reembolso
-- 6a: llega en 12 dias, pago el 50 % y cancela hoy -> se le devuelve el 80 %
-- 6b: llega en 3 dias, pago el 50 % y cancela hoy  -> no hay devolucion
-- ===========================================================================
DECLARE
  FUNCTION hab_libre (p_in DATE, p_out DATE) RETURN NUMBER IS
    v NUMBER;
  BEGIN
    SELECT MIN(h.id_habitacion) INTO v
      FROM habitacion h
     WHERE h.id_alojamiento = 1 AND h.capacidad >= 2
       AND NOT EXISTS (SELECT 1 FROM reserva_habitacion rh JOIN reserva r ON r.id_reserva = rh.id_reserva
                        WHERE rh.id_habitacion = h.id_habitacion AND r.estado <> 'CANCELADA'
                          AND rh.fecha_checkin < p_out AND p_in < rh.fecha_checkout);
    RETURN v;
  END;
BEGIN
  DBMS_OUTPUT.PUT_LINE('--- Prueba 6a: cancelacion con 12 dias ---');
  pkg_turismouq.sp_crear_reserva(4, hab_libre(TRUNC(SYSDATE) + 12, TRUNC(SYSDATE) + 14),
                                 TRUNC(SYSDATE) + 12, TRUNC(SYSDATE) + 14, 2, :v_res_a);
  pkg_turismouq.sp_registrar_pago(:v_res_a, ROUND(pkg_turismouq.fn_valor_reserva(:v_res_a) * 0.5, -2), 'PSE');
  pkg_turismouq.sp_cancelar_reserva(:v_res_a);

  DBMS_OUTPUT.PUT_LINE('--- Prueba 6b: cancelacion con 3 dias ---');
  pkg_turismouq.sp_crear_reserva(5, hab_libre(TRUNC(SYSDATE) + 3, TRUNC(SYSDATE) + 4),
                                 TRUNC(SYSDATE) + 3, TRUNC(SYSDATE) + 4, 2, :v_res_b);
  pkg_turismouq.sp_registrar_pago(:v_res_b, ROUND(pkg_turismouq.fn_valor_reserva(:v_res_b) * 0.5, -2), 'TARJETA_DEBITO');
  pkg_turismouq.sp_cancelar_reserva(:v_res_b);
END;
/

SELECT p.id_reserva, r.estado, r.fecha_checkin, TRUNC(r.fecha_cancelacion) AS cancelada,
       r.fecha_checkin - TRUNC(r.fecha_cancelacion) AS dias_antes, p.estado AS estado_pago, p.monto
  FROM pago p JOIN reserva r ON r.id_reserva = p.id_reserva
 WHERE p.id_reserva IN (:v_res_a, :v_res_b)
 ORDER BY p.id_reserva, p.id_pago;


-- ===========================================================================
-- PRUEBA 7. Disparador de SENTENCIA: auditoria de TARIFA
-- Sentencia 1: sube 10.000 las tarifas de diciembre de 2026 de la habitacion
--              101 (3 filas en una sola sentencia).
-- Sentencia 2: un UPDATE que deja el mismo precio (no debe auditar nada).
-- Sentencia 3: devuelve los precios a como estaban (3 filas).
-- Se espera: 2 numeros de sentencia con 3 filas cada uno, con usuario, equipo,
-- fecha/hora y precio anterior y nuevo.
-- ===========================================================================
UPDATE tarifa SET precio_noche = precio_noche + 10000
 WHERE id_habitacion = :v_hab
   AND id_temporada IN (SELECT id_temporada FROM temporada
                         WHERE fecha_inicio >= DATE '2026-12-01' AND fecha_inicio < DATE '2027-01-01');

UPDATE tarifa SET precio_noche = precio_noche WHERE id_habitacion = :v_hab;

UPDATE tarifa SET precio_noche = precio_noche - 10000
 WHERE id_habitacion = :v_hab
   AND id_temporada IN (SELECT id_temporada FROM temporada
                         WHERE fecha_inicio >= DATE '2026-12-01' AND fecha_inicio < DATE '2027-01-01');

COMMIT;

SELECT a.id_sentencia, a.operacion, a.id_tarifa, te.nombre AS temporada,
       a.precio_anterior, a.precio_nuevo, a.usuario_bd, a.usuario_so, a.equipo,
       TO_CHAR(a.fecha, 'YYYY-MM-DD HH24:MI:SS.FF3') AS fecha_hora
  FROM auditoria_tarifa a
  JOIN temporada te ON te.id_temporada = a.id_temporada
 WHERE a.id_habitacion = :v_hab
 ORDER BY a.id_auditoria;

SELECT id_sentencia, MIN(operacion) AS operacion, COUNT(*) AS filas_afectadas,
       MIN(usuario_bd) AS usuario_bd, TO_CHAR(MIN(fecha), 'YYYY-MM-DD HH24:MI:SS') AS fecha_hora
  FROM auditoria_tarifa
 GROUP BY id_sentencia
 ORDER BY id_sentencia;


-- ===========================================================================
-- PRUEBA 8. Cursor con parametros: liquidacion mensual
-- 8a: diciembre de 2025 para todos los alojamientos (60 filas).
-- 8b: julio de 2026 solo para el alojamiento 21 (mismo cursor, otro parametro).
-- Se vuelve a correr 8b para mostrar que no duplica (MERGE).
-- ===========================================================================
EXEC pkg_turismouq.sp_liquidacion_mensual(2025, 12);
EXEC pkg_turismouq.sp_liquidacion_mensual(2026, 7, 21);
EXEC pkg_turismouq.sp_liquidacion_mensual(2026, 7, 21);

SELECT l.anio, l.mes, a.nombre_comercial AS alojamiento, l.reservas_completadas, l.noches_vendidas,
       l.recaudo, l.reembolsos, l.ingreso_neto, l.comision, l.valor_a_pagar
  FROM liquidacion_mensual l JOIN alojamiento a ON a.id_alojamiento = l.id_alojamiento
 WHERE (l.anio = 2025 AND l.mes = 12) OR (l.anio = 2026 AND l.mes = 7)
 ORDER BY l.anio, l.mes, l.valor_a_pagar DESC
 FETCH FIRST 8 ROWS ONLY;

SELECT COUNT(*) AS filas_julio_2026_aloj21 FROM liquidacion_mensual
 WHERE anio = 2026 AND mes = 7 AND id_alojamiento = 21;

-- Excepcion del proceso: mes invalido -> -20012
BEGIN
  pkg_turismouq.sp_liquidacion_mensual(2025, 13);
EXCEPTION
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('8 OK (mes invalido) -> ' || SQLERRM);
END;
/


-- ===========================================================================
-- PRUEBA 9. Tablespace TS_HISTORICO
-- Se archivan las reservas cerradas de 2024. La segunda corrida no debe
-- archivar nada nuevo. La tabla y su indice deben estar en TS_HISTORICO.
-- ===========================================================================
EXEC pkg_turismouq.sp_archivar_historico(DATE '2025-01-01');
EXEC pkg_turismouq.sp_archivar_historico(DATE '2025-01-01');

SELECT segment_name, segment_type, tablespace_name, ROUND(bytes / 1024 / 1024, 2) AS mb
  FROM user_segments
 WHERE segment_name IN ('RESERVA_HISTORICO', 'PK_RESERVA_HISTORICO', 'RESERVA')
 ORDER BY segment_name;

SELECT estado, COUNT(*) AS reservas, SUM(noches_habitacion) AS noches,
       TO_CHAR(SUM(pagado_neto), '999G999G999G990') AS pagado_neto
  FROM reserva_historico GROUP BY estado;


-- ===========================================================================
-- PRUEBA 10. Vista materializada y su refresco
-- La reserva de la prueba 2 ya esta CONFIRMADA y guardada (la liquidacion
-- hizo COMMIT), pero la vista no la ve hasta que se refresque: los datos de
-- la vista son una foto. Se refresca a mano y las noches del mes aumentan
-- (3 noches de la primera habitacion + 2 de la segunda = 5, salvo que la
-- estadia quede partida entre dos meses).
-- ===========================================================================
SELECT mview_name, refresh_method, last_refresh_date, staleness
  FROM user_mviews WHERE mview_name = 'MV_OCUPACION_MENSUAL';

EXEC SELECT NVL(SUM(noches_ocupadas), 0) INTO :v_noches_antes FROM mv_ocupacion_mensual WHERE id_alojamiento = 1 AND mes IN (TRUNC(SYSDATE + 20, 'MM'), TRUNC(SYSDATE + 22, 'MM'));

EXEC DBMS_MVIEW.REFRESH('MV_OCUPACION_MENSUAL', 'C');

SELECT :v_noches_antes AS noches_antes_refresco,
       NVL(SUM(noches_ocupadas), 0) AS noches_despues_refresco,
       NVL(SUM(noches_ocupadas), 0) - :v_noches_antes AS diferencia
  FROM mv_ocupacion_mensual
 WHERE id_alojamiento = 1 AND mes IN (TRUNC(SYSDATE + 20, 'MM'), TRUNC(SYSDATE + 22, 'MM'));

SELECT mview_name, last_refresh_date, staleness FROM user_mviews WHERE mview_name = 'MV_OCUPACION_MENSUAL';

-- Proximo refresco automatico programado (2:00 a.m.)
SELECT job_name, enabled, TO_CHAR(next_run_date, 'YYYY-MM-DD HH24:MI') AS proximo
  FROM user_scheduler_jobs;


-- ===========================================================================
-- LIMPIEZA: se borran las reservas creadas por las pruebas
-- ===========================================================================
DELETE FROM pago               WHERE id_reserva > :v_max_res;
DELETE FROM reserva_servicio   WHERE id_reserva > :v_max_res;
DELETE FROM resena             WHERE id_reserva > :v_max_res;
DELETE FROM reserva_habitacion WHERE id_reserva > :v_max_res;
DELETE FROM reserva            WHERE id_reserva > :v_max_res;
COMMIT;

EXEC DBMS_MVIEW.REFRESH('MV_OCUPACION_MENSUAL', 'C');

SELECT COUNT(*) AS reservas_de_prueba_que_quedan FROM reserva WHERE id_reserva > :v_max_res;
