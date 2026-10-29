-- Script 7: Paquete PKG_TURISMOUQ (Entrega 2)
-- Funcion fn_valor_estadia, procedimiento sp_crear_reserva, cursor con
-- parametros para la liquidacion mensual y los demas procesos del negocio,
-- todo agrupado en un paquete. Se corre despues del 06.
--
-- Codigos de error propios (RAISE_APPLICATION_ERROR):
--   -20001  checkout anterior o igual al checkin
--   -20002  check-in en el pasado
--   -20003  no existe el cliente, la habitacion o la reserva
--   -20004  capacidad de la habitacion excedida
--   -20005  habitacion no disponible (ya ocupada en esas fechas)
--   -20006  noche sin temporada o sin tarifa
--   -20007  el estado de la reserva no permite la operacion
--   -20008  linea fuera del rango de la reserva o de otro alojamiento
--   -20011  monto de pago invalido
--   -20012  mes invalido en la liquidacion
-- (-20009 y -20010 los usan los disparadores del script 08)
--
-- Los procedimientos de reservas y pagos NO hacen COMMIT: lo decide quien los
-- llama (asi en la Entrega 3 se pueden juntar en una transaccion con SAVEPOINT).
-- Los procesos masivos (liquidacion e historico) si hacen COMMIT al terminar.

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

-- Tabla donde queda el resultado de la liquidacion mensual
BEGIN
  FOR t IN (SELECT table_name FROM user_tables WHERE table_name = 'LIQUIDACION_MENSUAL') LOOP
    EXECUTE IMMEDIATE 'DROP TABLE liquidacion_mensual PURGE';
  END LOOP;
END;
/

CREATE TABLE liquidacion_mensual (
  id_liquidacion        NUMBER(10)    GENERATED ALWAYS AS IDENTITY,
  id_alojamiento        NUMBER(10)    NOT NULL,
  anio                  NUMBER(4)     NOT NULL,
  mes                   NUMBER(2)     NOT NULL,
  reservas_completadas  NUMBER(6)     NOT NULL,
  noches_vendidas       NUMBER(7)     NOT NULL,
  recaudo               NUMBER(14,2)  NOT NULL,
  reembolsos            NUMBER(14,2)  NOT NULL,
  ingreso_neto          NUMBER(14,2)  NOT NULL,
  comision              NUMBER(14,2)  NOT NULL,
  valor_a_pagar         NUMBER(14,2)  NOT NULL,
  fecha_generacion      DATE          DEFAULT SYSDATE NOT NULL,
  CONSTRAINT pk_liquidacion      PRIMARY KEY (id_liquidacion),
  CONSTRAINT fk_liq_alojamiento  FOREIGN KEY (id_alojamiento) REFERENCES alojamiento (id_alojamiento)
                                 ON DELETE CASCADE,  -- para que el 02 pueda recargar los datos
  CONSTRAINT uq_liq_aloj_periodo UNIQUE (id_alojamiento, anio, mes),
  CONSTRAINT ck_liq_mes          CHECK (mes BETWEEN 1 AND 12)
);

COMMENT ON TABLE liquidacion_mensual IS 'Resultado de la liquidacion mensual: lo que la plataforma le gira a cada alojamiento.';

-- ===========================================================================
-- ESPECIFICACION
-- ===========================================================================
CREATE OR REPLACE PACKAGE pkg_turismouq AS

  -- parametros del negocio
  c_comision        CONSTANT NUMBER      := 0.12;  -- comision de la plataforma sobre el ingreso neto
  c_pct_reembolso   CONSTANT NUMBER      := 0.80;  -- reembolso si cancela con mas de 5 dias
  c_dias_reembolso  CONSTANT PLS_INTEGER := 5;

  -- Valor de una estadia en una habitacion, noche por noche con la tarifa de
  -- la temporada de cada noche. fecha_out es el dia de salida (no se cobra).
  FUNCTION fn_valor_estadia (p_id_habitacion IN NUMBER,
                             p_fecha_in      IN DATE,
                             p_fecha_out     IN DATE) RETURN NUMBER;

  -- Valor total de una reserva: estadia de todas sus lineas + servicios
  FUNCTION fn_valor_reserva (p_id_reserva IN NUMBER) RETURN NUMBER;

  -- 1 si la habitacion esta libre en el rango (no la ocupa otra reserva
  -- CONFIRMADA o COMPLETADA), 0 si no. p_excluir_reserva sirve para no
  -- compararse contra la misma reserva.
  FUNCTION fn_disponible (p_id_habitacion   IN NUMBER,
                          p_fecha_in        IN DATE,
                          p_fecha_out       IN DATE,
                          p_excluir_reserva IN NUMBER DEFAULT NULL) RETURN NUMBER;

  -- Crea la reserva (estado PENDIENTE) con su primera habitacion
  PROCEDURE sp_crear_reserva (p_id_cliente    IN  NUMBER,
                              p_id_habitacion IN  NUMBER,
                              p_fecha_in      IN  DATE,
                              p_fecha_out     IN  DATE,
                              p_num_huespedes IN  NUMBER,
                              p_id_reserva    OUT NUMBER);

  -- Agrega otra habitacion a una reserva (reservas de grupo)
  PROCEDURE sp_agregar_habitacion (p_id_reserva    IN NUMBER,
                                   p_id_habitacion IN NUMBER,
                                   p_fecha_in      IN DATE,
                                   p_fecha_out     IN DATE,
                                   p_num_huespedes IN NUMBER);

  -- Registra un pago exitoso; si la reserva estaba PENDIENTE la confirma
  PROCEDURE sp_registrar_pago (p_id_reserva IN NUMBER,
                               p_monto      IN NUMBER,
                               p_metodo     IN VARCHAR2);

  -- Cancela la reserva y aplica la regla de reembolso
  PROCEDURE sp_cancelar_reserva (p_id_reserva IN NUMBER,
                                 p_fecha      IN DATE DEFAULT SYSDATE);

  -- Liquidacion mensual por alojamiento (usa el cursor con parametros)
  PROCEDURE sp_liquidacion_mensual (p_anio           IN NUMBER,
                                    p_mes            IN NUMBER,
                                    p_id_alojamiento IN NUMBER DEFAULT NULL);

  -- Copia a RESERVA_HISTORICO las reservas cerradas antes de p_hasta
  PROCEDURE sp_archivar_historico (p_hasta IN DATE);

END pkg_turismouq;
/

-- ===========================================================================
-- CUERPO
-- ===========================================================================
CREATE OR REPLACE PACKAGE BODY pkg_turismouq AS

  -- -------------------------------------------------------------------------
  -- fn_valor_estadia
  -- Recorre la estadia noche por noche (desde fecha_in hasta el dia anterior a
  -- fecha_out). Para cada noche busca la temporada cuyo rango la contiene y la
  -- tarifa de la habitacion en esa temporada, y la suma. Asi, si la estadia
  -- cruza de temporada media a alta, cada noche se cobra con su propia tarifa.
  -- -------------------------------------------------------------------------
  FUNCTION fn_valor_estadia (p_id_habitacion IN NUMBER,
                             p_fecha_in      IN DATE,
                             p_fecha_out     IN DATE) RETURN NUMBER IS
    v_dia     DATE := TRUNC(p_fecha_in);
    v_salida  DATE := TRUNC(p_fecha_out);
    v_precio  tarifa.precio_noche%TYPE;
    v_total   NUMBER := 0;
    v_existe  NUMBER;
  BEGIN
    IF p_fecha_in IS NULL OR p_fecha_out IS NULL OR v_salida <= v_dia THEN
      RAISE_APPLICATION_ERROR(-20001, 'La fecha de salida debe ser posterior a la de llegada');
    END IF;

    SELECT COUNT(*) INTO v_existe FROM habitacion WHERE id_habitacion = p_id_habitacion;
    IF v_existe = 0 THEN
      RAISE_APPLICATION_ERROR(-20003, 'No existe la habitacion ' || p_id_habitacion);
    END IF;

    WHILE v_dia < v_salida LOOP
      BEGIN
        SELECT t.precio_noche
          INTO v_precio
          FROM tarifa t
          JOIN temporada te ON te.id_temporada = t.id_temporada
         WHERE t.id_habitacion = p_id_habitacion
           AND v_dia BETWEEN te.fecha_inicio AND te.fecha_fin;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          RAISE_APPLICATION_ERROR(-20006, 'No hay temporada o tarifa para la noche del '
                                          || TO_CHAR(v_dia, 'YYYY-MM-DD'));
        WHEN TOO_MANY_ROWS THEN
          RAISE_APPLICATION_ERROR(-20006, 'La noche del ' || TO_CHAR(v_dia, 'YYYY-MM-DD')
                                          || ' esta en dos temporadas');
      END;
      v_total := v_total + v_precio;
      v_dia   := v_dia + 1;
    END LOOP;

    RETURN v_total;
  END fn_valor_estadia;

  -- -------------------------------------------------------------------------
  -- fn_valor_reserva: estadia de cada linea (con sus propias fechas) + servicios
  -- -------------------------------------------------------------------------
  FUNCTION fn_valor_reserva (p_id_reserva IN NUMBER) RETURN NUMBER IS
    v_total     NUMBER := 0;
    v_servicios NUMBER;
  BEGIN
    FOR l IN (SELECT id_habitacion, fecha_checkin, fecha_checkout
                FROM reserva_habitacion WHERE id_reserva = p_id_reserva) LOOP
      v_total := v_total + fn_valor_estadia(l.id_habitacion, l.fecha_checkin, l.fecha_checkout);
    END LOOP;

    SELECT NVL(SUM(cantidad * precio_unitario), 0)
      INTO v_servicios
      FROM reserva_servicio WHERE id_reserva = p_id_reserva;

    RETURN v_total + v_servicios;
  END fn_valor_reserva;

  -- -------------------------------------------------------------------------
  -- fn_disponible: dos rangos [a,b) y [c,d) se cruzan si a < d y c < b
  -- -------------------------------------------------------------------------
  FUNCTION fn_disponible (p_id_habitacion   IN NUMBER,
                          p_fecha_in        IN DATE,
                          p_fecha_out       IN DATE,
                          p_excluir_reserva IN NUMBER DEFAULT NULL) RETURN NUMBER IS
    v_cruces NUMBER;
  BEGIN
    SELECT COUNT(*)
      INTO v_cruces
      FROM reserva_habitacion rh
      JOIN reserva r ON r.id_reserva = rh.id_reserva
     WHERE rh.id_habitacion = p_id_habitacion
       AND r.estado IN ('CONFIRMADA', 'COMPLETADA')
       AND r.id_reserva <> NVL(p_excluir_reserva, -1)
       AND rh.fecha_checkin < TRUNC(p_fecha_out)
       AND TRUNC(p_fecha_in) < rh.fecha_checkout;

    RETURN CASE WHEN v_cruces = 0 THEN 1 ELSE 0 END;
  END fn_disponible;

  -- -------------------------------------------------------------------------
  -- Validaciones comunes de una linea (habitacion, capacidad, disponibilidad y
  -- tarifa). Devuelve el alojamiento de la habitacion. Es privada del paquete.
  -- -------------------------------------------------------------------------
  FUNCTION validar_linea (p_id_habitacion   IN NUMBER,
                          p_fecha_in        IN DATE,
                          p_fecha_out       IN DATE,
                          p_num_huespedes   IN NUMBER,
                          p_excluir_reserva IN NUMBER DEFAULT NULL) RETURN NUMBER IS
    v_capacidad habitacion.capacidad%TYPE;
    v_aloj      habitacion.id_alojamiento%TYPE;
    v_valor     NUMBER;
  BEGIN
    IF p_fecha_in IS NULL OR p_fecha_out IS NULL OR TRUNC(p_fecha_out) <= TRUNC(p_fecha_in) THEN
      RAISE_APPLICATION_ERROR(-20001, 'El checkout (' || TO_CHAR(p_fecha_out, 'YYYY-MM-DD')
                              || ') debe ser posterior al checkin (' || TO_CHAR(p_fecha_in, 'YYYY-MM-DD') || ')');
    END IF;

    IF TRUNC(p_fecha_in) < TRUNC(SYSDATE) THEN
      RAISE_APPLICATION_ERROR(-20002, 'No se puede reservar con check-in en el pasado ('
                              || TO_CHAR(p_fecha_in, 'YYYY-MM-DD') || ')');
    END IF;

    BEGIN
      SELECT capacidad, id_alojamiento INTO v_capacidad, v_aloj
        FROM habitacion WHERE id_habitacion = p_id_habitacion;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20003, 'No existe la habitacion ' || p_id_habitacion);
    END;

    IF p_num_huespedes IS NULL OR p_num_huespedes < 1 OR p_num_huespedes > v_capacidad THEN
      RAISE_APPLICATION_ERROR(-20004, 'Capacidad excedida: la habitacion ' || p_id_habitacion
                              || ' admite ' || v_capacidad || ' huespedes y se pidieron '
                              || NVL(TO_CHAR(p_num_huespedes), 'ninguno'));
    END IF;

    IF fn_disponible(p_id_habitacion, p_fecha_in, p_fecha_out, p_excluir_reserva) = 0 THEN
      RAISE_APPLICATION_ERROR(-20005, 'Habitacion ' || p_id_habitacion || ' no disponible del '
                              || TO_CHAR(p_fecha_in, 'YYYY-MM-DD') || ' al '
                              || TO_CHAR(p_fecha_out, 'YYYY-MM-DD') || ': ya tiene una reserva confirmada');
    END IF;

    -- si alguna noche no tiene tarifa, fn_valor_estadia lanza -20006
    v_valor := fn_valor_estadia(p_id_habitacion, p_fecha_in, p_fecha_out);

    RETURN v_aloj;
  END validar_linea;

  -- -------------------------------------------------------------------------
  -- sp_crear_reserva
  -- Valida fechas, capacidad, disponibilidad y tarifa ANTES de insertar; si
  -- algo falla lanza el error propio y no queda nada a medias.
  -- -------------------------------------------------------------------------
  PROCEDURE sp_crear_reserva (p_id_cliente    IN  NUMBER,
                              p_id_habitacion IN  NUMBER,
                              p_fecha_in      IN  DATE,
                              p_fecha_out     IN  DATE,
                              p_num_huespedes IN  NUMBER,
                              p_id_reserva    OUT NUMBER) IS
    v_existe NUMBER;
    v_aloj   NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v_existe FROM cliente WHERE id_cliente = p_id_cliente;
    IF v_existe = 0 THEN
      RAISE_APPLICATION_ERROR(-20003, 'No existe el cliente ' || p_id_cliente);
    END IF;

    v_aloj := validar_linea(p_id_habitacion, p_fecha_in, p_fecha_out, p_num_huespedes);

    INSERT INTO reserva (id_cliente, id_alojamiento, fecha_checkin, fecha_checkout, estado, fecha_creacion)
    VALUES (p_id_cliente, v_aloj, TRUNC(p_fecha_in), TRUNC(p_fecha_out), 'PENDIENTE', SYSDATE)
    RETURNING id_reserva INTO p_id_reserva;

    INSERT INTO reserva_habitacion (id_reserva, id_habitacion, id_alojamiento,
                                    fecha_checkin, fecha_checkout, num_huespedes)
    VALUES (p_id_reserva, p_id_habitacion, v_aloj, TRUNC(p_fecha_in), TRUNC(p_fecha_out), p_num_huespedes);

    DBMS_OUTPUT.PUT_LINE('Reserva ' || p_id_reserva || ' creada (PENDIENTE). Valor estadia: '
                         || TO_CHAR(fn_valor_estadia(p_id_habitacion, p_fecha_in, p_fecha_out), 'FM999G999G990'));
  END sp_crear_reserva;

  -- -------------------------------------------------------------------------
  -- sp_agregar_habitacion: la linea debe quedar dentro del rango de la reserva
  -- y la habitacion debe ser del mismo alojamiento.
  -- -------------------------------------------------------------------------
  PROCEDURE sp_agregar_habitacion (p_id_reserva    IN NUMBER,
                                   p_id_habitacion IN NUMBER,
                                   p_fecha_in      IN DATE,
                                   p_fecha_out     IN DATE,
                                   p_num_huespedes IN NUMBER) IS
    v_res  reserva%ROWTYPE;
    v_aloj NUMBER;
  BEGIN
    BEGIN
      SELECT * INTO v_res FROM reserva WHERE id_reserva = p_id_reserva;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20003, 'No existe la reserva ' || p_id_reserva);
    END;

    IF v_res.estado NOT IN ('PENDIENTE', 'CONFIRMADA') THEN
      RAISE_APPLICATION_ERROR(-20007, 'La reserva ' || p_id_reserva || ' esta ' || v_res.estado
                              || ' y no admite mas habitaciones');
    END IF;

    IF TRUNC(p_fecha_in) < v_res.fecha_checkin OR TRUNC(p_fecha_out) > v_res.fecha_checkout THEN
      RAISE_APPLICATION_ERROR(-20008, 'Las fechas de la habitacion deben estar dentro del rango de la reserva ('
                              || TO_CHAR(v_res.fecha_checkin, 'YYYY-MM-DD') || ' a '
                              || TO_CHAR(v_res.fecha_checkout, 'YYYY-MM-DD') || ')');
    END IF;

    v_aloj := validar_linea(p_id_habitacion, p_fecha_in, p_fecha_out, p_num_huespedes, p_id_reserva);

    IF v_aloj <> v_res.id_alojamiento THEN
      RAISE_APPLICATION_ERROR(-20008, 'La habitacion ' || p_id_habitacion
                              || ' no pertenece al alojamiento de la reserva');
    END IF;

    INSERT INTO reserva_habitacion (id_reserva, id_habitacion, id_alojamiento,
                                    fecha_checkin, fecha_checkout, num_huespedes)
    VALUES (p_id_reserva, p_id_habitacion, v_aloj, TRUNC(p_fecha_in), TRUNC(p_fecha_out), p_num_huespedes);

    DBMS_OUTPUT.PUT_LINE('Habitacion ' || p_id_habitacion || ' agregada a la reserva ' || p_id_reserva);
  END sp_agregar_habitacion;

  -- -------------------------------------------------------------------------
  -- sp_registrar_pago
  -- El pago no puede superar el saldo. Si la reserva estaba PENDIENTE, con el
  -- primer pago exitoso pasa a CONFIRMADA (regla R4), pero antes se revisa que
  -- ninguna de sus habitaciones la haya tomado otra reserva confirmada.
  -- -------------------------------------------------------------------------
  PROCEDURE sp_registrar_pago (p_id_reserva IN NUMBER,
                               p_monto      IN NUMBER,
                               p_metodo     IN VARCHAR2) IS
    v_estado reserva.estado%TYPE;
    v_total  NUMBER;
    v_pagado NUMBER;
  BEGIN
    BEGIN
      SELECT estado INTO v_estado FROM reserva WHERE id_reserva = p_id_reserva;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20003, 'No existe la reserva ' || p_id_reserva);
    END;

    IF v_estado NOT IN ('PENDIENTE', 'CONFIRMADA') THEN
      RAISE_APPLICATION_ERROR(-20007, 'La reserva ' || p_id_reserva || ' esta ' || v_estado
                              || ' y no recibe pagos');
    END IF;

    v_total := fn_valor_reserva(p_id_reserva);
    SELECT NVL(SUM(CASE estado WHEN 'EXITOSO' THEN monto WHEN 'REEMBOLSADO' THEN -monto ELSE 0 END), 0)
      INTO v_pagado
      FROM pago WHERE id_reserva = p_id_reserva;

    IF p_monto IS NULL OR p_monto <= 0 OR p_monto > v_total - v_pagado THEN
      RAISE_APPLICATION_ERROR(-20011, 'Monto invalido. Saldo pendiente: '
                              || TO_CHAR(v_total - v_pagado, 'FM999G999G990'));
    END IF;

    IF v_estado = 'PENDIENTE' THEN
      FOR l IN (SELECT id_habitacion, fecha_checkin, fecha_checkout
                  FROM reserva_habitacion WHERE id_reserva = p_id_reserva) LOOP
        IF fn_disponible(l.id_habitacion, l.fecha_checkin, l.fecha_checkout, p_id_reserva) = 0 THEN
          RAISE_APPLICATION_ERROR(-20005, 'No se puede confirmar: la habitacion ' || l.id_habitacion
                                  || ' ya fue confirmada por otra reserva en esas fechas');
        END IF;
      END LOOP;
    END IF;

    INSERT INTO pago (id_reserva, fecha_pago, monto, metodo, estado)
    VALUES (p_id_reserva, SYSDATE, p_monto, p_metodo, 'EXITOSO');

    IF v_estado = 'PENDIENTE' THEN
      UPDATE reserva SET estado = 'CONFIRMADA' WHERE id_reserva = p_id_reserva;
      DBMS_OUTPUT.PUT_LINE('Reserva ' || p_id_reserva || ' CONFIRMADA con el pago');
    END IF;

    DBMS_OUTPUT.PUT_LINE('Pago registrado. Total: ' || TO_CHAR(v_total, 'FM999G999G990')
                         || ' | Pagado: ' || TO_CHAR(v_pagado + p_monto, 'FM999G999G990')
                         || ' | Saldo: ' || TO_CHAR(v_total - v_pagado - p_monto, 'FM999G999G990'));
  END sp_registrar_pago;

  -- -------------------------------------------------------------------------
  -- sp_cancelar_reserva
  -- Con MAS de 5 dias de anticipacion al check-in se devuelve el 80 % de lo
  -- pagado (se registra como un pago REEMBOLSADO); con 5 o menos no hay
  -- devolucion. Solo se cancelan reservas PENDIENTE o CONFIRMADA antes de llegar.
  -- -------------------------------------------------------------------------
  PROCEDURE sp_cancelar_reserva (p_id_reserva IN NUMBER,
                                 p_fecha      IN DATE DEFAULT SYSDATE) IS
    v_res        reserva%ROWTYPE;
    v_pagado     NUMBER;
    v_dias       NUMBER;
    v_reembolso  NUMBER := 0;
  BEGIN
    BEGIN
      SELECT * INTO v_res FROM reserva WHERE id_reserva = p_id_reserva;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20003, 'No existe la reserva ' || p_id_reserva);
    END;

    IF v_res.estado NOT IN ('PENDIENTE', 'CONFIRMADA') THEN
      RAISE_APPLICATION_ERROR(-20007, 'La reserva ' || p_id_reserva || ' esta ' || v_res.estado
                              || ' y no se puede cancelar');
    END IF;

    v_dias := v_res.fecha_checkin - TRUNC(p_fecha);
    IF v_dias <= 0 THEN
      RAISE_APPLICATION_ERROR(-20007, 'La estadia ya empezo; no se puede cancelar');
    END IF;

    SELECT NVL(SUM(CASE estado WHEN 'EXITOSO' THEN monto WHEN 'REEMBOLSADO' THEN -monto ELSE 0 END), 0)
      INTO v_pagado
      FROM pago WHERE id_reserva = p_id_reserva;

    IF v_dias > c_dias_reembolso AND v_pagado > 0 THEN
      v_reembolso := ROUND(v_pagado * c_pct_reembolso, 2);
      INSERT INTO pago (id_reserva, fecha_pago, monto, metodo, estado)
      VALUES (p_id_reserva, p_fecha, v_reembolso, 'TRANSFERENCIA', 'REEMBOLSADO');
    END IF;

    UPDATE reserva
       SET estado = 'CANCELADA', fecha_cancelacion = p_fecha
     WHERE id_reserva = p_id_reserva;

    DBMS_OUTPUT.PUT_LINE('Reserva ' || p_id_reserva || ' cancelada con ' || v_dias
                         || ' dias de anticipacion. Pagado: ' || TO_CHAR(v_pagado, 'FM999G999G990')
                         || ' | Reembolso: ' || TO_CHAR(v_reembolso, 'FM999G999G990')
                         || ' | Retenido: ' || TO_CHAR(v_pagado - v_reembolso, 'FM999G999G990'));
  END sp_cancelar_reserva;

  -- -------------------------------------------------------------------------
  -- sp_liquidacion_mensual
  -- La plataforma recauda los pagos y cada mes le gira a cada alojamiento lo
  -- que le corresponde: recaudo del mes - reembolsos del mes - comision (12 %).
  -- Usa un cursor explicito con parametros (inicio y fin del mes y alojamiento,
  -- NULL = todos) que se abre, se recorre con FETCH y se cierra a mano.
  -- El resultado se guarda en LIQUIDACION_MENSUAL (si se vuelve a correr el
  -- mismo mes, se actualiza con MERGE en vez de duplicar).
  -- -------------------------------------------------------------------------
  PROCEDURE sp_liquidacion_mensual (p_anio           IN NUMBER,
                                    p_mes            IN NUMBER,
                                    p_id_alojamiento IN NUMBER DEFAULT NULL) IS

    CURSOR c_liquidacion (cp_inicio DATE, cp_fin DATE, cp_aloj NUMBER) IS
      SELECT a.id_alojamiento,
             a.nombre_comercial,
             (SELECT COUNT(*)
                FROM reserva r
               WHERE r.id_alojamiento = a.id_alojamiento
                 AND r.estado = 'COMPLETADA'
                 AND r.fecha_checkout >= cp_inicio AND r.fecha_checkout < cp_fin) AS reservas,
             (SELECT COUNT(*)
                FROM reserva_habitacion rh
                JOIN reserva r ON r.id_reserva = rh.id_reserva
                JOIN (SELECT LEVEL - 1 AS n FROM dual CONNECT BY LEVEL <= 31) k
                  ON k.n < rh.fecha_checkout - rh.fecha_checkin
               WHERE rh.id_alojamiento = a.id_alojamiento
                 AND r.estado IN ('CONFIRMADA', 'COMPLETADA')
                 AND rh.fecha_checkin + k.n >= cp_inicio
                 AND rh.fecha_checkin + k.n <  cp_fin) AS noches,
             (SELECT NVL(SUM(p.monto), 0)
                FROM pago p JOIN reserva r ON r.id_reserva = p.id_reserva
               WHERE r.id_alojamiento = a.id_alojamiento
                 AND p.estado = 'EXITOSO'
                 AND p.fecha_pago >= cp_inicio AND p.fecha_pago < cp_fin) AS recaudo,
             (SELECT NVL(SUM(p.monto), 0)
                FROM pago p JOIN reserva r ON r.id_reserva = p.id_reserva
               WHERE r.id_alojamiento = a.id_alojamiento
                 AND p.estado = 'REEMBOLSADO'
                 AND p.fecha_pago >= cp_inicio AND p.fecha_pago < cp_fin) AS reembolsos
        FROM alojamiento a
       WHERE cp_aloj IS NULL OR a.id_alojamiento = cp_aloj
       ORDER BY a.id_alojamiento;

    v_reg        c_liquidacion%ROWTYPE;
    v_inicio     DATE;
    v_fin        DATE;
    v_neto       NUMBER;
    v_comision   NUMBER;
    v_pagar      NUMBER;
    v_cuenta     PLS_INTEGER := 0;
    v_tot_neto   NUMBER := 0;
    v_tot_com    NUMBER := 0;
    v_tot_pagar  NUMBER := 0;
  BEGIN
    IF p_mes IS NULL OR p_mes NOT BETWEEN 1 AND 12 OR p_anio IS NULL THEN
      RAISE_APPLICATION_ERROR(-20012, 'Periodo invalido: ' || p_anio || '-' || p_mes);
    END IF;

    v_inicio := TO_DATE(p_anio || '-' || LPAD(p_mes, 2, '0') || '-01', 'YYYY-MM-DD');
    v_fin    := ADD_MONTHS(v_inicio, 1);

    DBMS_OUTPUT.PUT_LINE('LIQUIDACION ' || TO_CHAR(v_inicio, 'YYYY-MM')
                         || ' (comision ' || c_comision * 100 || ' %)');
    DBMS_OUTPUT.PUT_LINE(RPAD('Alojamiento', 36) || LPAD('Reservas', 9) || LPAD('Noches', 8)
                         || LPAD('Neto', 15) || LPAD('Comision', 14) || LPAD('A pagar', 15));

    OPEN c_liquidacion(v_inicio, v_fin, p_id_alojamiento);
    LOOP
      FETCH c_liquidacion INTO v_reg;
      EXIT WHEN c_liquidacion%NOTFOUND;

      v_neto     := v_reg.recaudo - v_reg.reembolsos;
      v_comision := ROUND(GREATEST(v_neto, 0) * c_comision, 2);   -- no se cobra comision sobre saldo negativo
      v_pagar    := v_neto - v_comision;

      MERGE INTO liquidacion_mensual l
      USING (SELECT v_reg.id_alojamiento AS id_alojamiento, p_anio AS anio, p_mes AS mes FROM dual) s
         ON (l.id_alojamiento = s.id_alojamiento AND l.anio = s.anio AND l.mes = s.mes)
      WHEN MATCHED THEN UPDATE SET
           reservas_completadas = v_reg.reservas, noches_vendidas = v_reg.noches,
           recaudo = v_reg.recaudo, reembolsos = v_reg.reembolsos, ingreso_neto = v_neto,
           comision = v_comision, valor_a_pagar = v_pagar, fecha_generacion = SYSDATE
      WHEN NOT MATCHED THEN INSERT
           (id_alojamiento, anio, mes, reservas_completadas, noches_vendidas, recaudo,
            reembolsos, ingreso_neto, comision, valor_a_pagar)
           VALUES (v_reg.id_alojamiento, p_anio, p_mes, v_reg.reservas, v_reg.noches, v_reg.recaudo,
                   v_reg.reembolsos, v_neto, v_comision, v_pagar);

      DBMS_OUTPUT.PUT_LINE(RPAD(SUBSTR(v_reg.nombre_comercial, 1, 35), 36)
                           || LPAD(v_reg.reservas, 9) || LPAD(v_reg.noches, 8)
                           || LPAD(TO_CHAR(v_neto, 'FM999G999G990'), 15)
                           || LPAD(TO_CHAR(v_comision, 'FM999G999G990'), 14)
                           || LPAD(TO_CHAR(v_pagar, 'FM999G999G990'), 15));

      v_cuenta    := v_cuenta + 1;
      v_tot_neto  := v_tot_neto + v_neto;
      v_tot_com   := v_tot_com + v_comision;
      v_tot_pagar := v_tot_pagar + v_pagar;
    END LOOP;
    CLOSE c_liquidacion;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Alojamientos liquidados: ' || v_cuenta
                         || ' | Neto: ' || TO_CHAR(v_tot_neto, 'FM999G999G999G990')
                         || ' | Comision plataforma: ' || TO_CHAR(v_tot_com, 'FM999G999G999G990')
                         || ' | Total a girar: ' || TO_CHAR(v_tot_pagar, 'FM999G999G999G990'));
  EXCEPTION
    WHEN OTHERS THEN
      IF c_liquidacion%ISOPEN THEN
        CLOSE c_liquidacion;
      END IF;
      ROLLBACK;
      RAISE;
  END sp_liquidacion_mensual;

  -- -------------------------------------------------------------------------
  -- sp_archivar_historico
  -- Copia a RESERVA_HISTORICO (tablespace TS_HISTORICO) las reservas cerradas
  -- con checkout antes de p_hasta que no se hayan archivado. Los valores se
  -- calculan en una sola consulta (noche a noche con la tabla k) en vez de
  -- llamar fn_valor_estadia miles de veces.
  -- -------------------------------------------------------------------------
  PROCEDURE sp_archivar_historico (p_hasta IN DATE) IS
    v_filas NUMBER;
  BEGIN
    INSERT INTO reserva_historico
          (id_reserva, id_cliente, cliente, id_alojamiento, alojamiento, municipio, estado,
           fecha_creacion, fecha_checkin, fecha_checkout, fecha_cancelacion, habitaciones,
           huespedes, noches_habitacion, valor_estadia, valor_servicios, pagado_neto)
    SELECT r.id_reserva, r.id_cliente, c.nombre || ' ' || c.apellido,
           a.id_alojamiento, a.nombre_comercial, mu.nombre, r.estado,
           r.fecha_creacion, r.fecha_checkin, r.fecha_checkout, r.fecha_cancelacion,
           NVL(l.habitaciones, 0), NVL(l.huespedes, 0), NVL(e.noches, 0), NVL(e.valor, 0),
           NVL(s.valor, 0), NVL(p.neto, 0)
      FROM reserva r
      JOIN cliente     c  ON c.id_cliente     = r.id_cliente
      JOIN alojamiento a  ON a.id_alojamiento = r.id_alojamiento
      JOIN municipio   mu ON mu.id_municipio  = a.id_municipio
      LEFT JOIN (SELECT id_reserva, COUNT(*) habitaciones, SUM(num_huespedes) huespedes
                   FROM reserva_habitacion GROUP BY id_reserva) l ON l.id_reserva = r.id_reserva
      LEFT JOIN (SELECT rh.id_reserva, COUNT(*) noches, SUM(t.precio_noche) valor
                   FROM reserva_habitacion rh
                   JOIN (SELECT LEVEL - 1 AS n FROM dual CONNECT BY LEVEL <= 31) k
                     ON k.n < rh.fecha_checkout - rh.fecha_checkin
                   JOIN temporada te ON rh.fecha_checkin + k.n BETWEEN te.fecha_inicio AND te.fecha_fin
                   JOIN tarifa t ON t.id_habitacion = rh.id_habitacion AND t.id_temporada = te.id_temporada
                  GROUP BY rh.id_reserva) e ON e.id_reserva = r.id_reserva
      LEFT JOIN (SELECT id_reserva, SUM(cantidad * precio_unitario) valor
                   FROM reserva_servicio GROUP BY id_reserva) s ON s.id_reserva = r.id_reserva
      LEFT JOIN (SELECT id_reserva,
                        SUM(CASE estado WHEN 'EXITOSO' THEN monto WHEN 'REEMBOLSADO' THEN -monto ELSE 0 END) neto
                   FROM pago GROUP BY id_reserva) p ON p.id_reserva = r.id_reserva
     WHERE r.estado IN ('COMPLETADA', 'CANCELADA')
       AND r.fecha_checkout < p_hasta
       AND NOT EXISTS (SELECT 1 FROM reserva_historico h WHERE h.id_reserva = r.id_reserva);

    v_filas := SQL%ROWCOUNT;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Reservas archivadas en TS_HISTORICO: ' || v_filas);
  END sp_archivar_historico;

END pkg_turismouq;
/

SHOW ERRORS PACKAGE pkg_turismouq
SHOW ERRORS PACKAGE BODY pkg_turismouq

SELECT object_name, object_type, status
  FROM user_objects
 WHERE object_name = 'PKG_TURISMOUQ';
