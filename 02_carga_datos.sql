-- Script 2: Carga de datos asimetricos (Entrega 1)
-- Se usa PL/SQL y DBMS_RANDOM para generar el volumen de datos exigido.

SET SERVEROUTPUT ON;
SET DEFINE OFF;

-- Limpieza de datos
BEGIN
  DELETE FROM usuario_sistema;
  DELETE FROM resena;
  DELETE FROM reserva_servicio;
  DELETE FROM servicio;
  DELETE FROM pago;
  DELETE FROM reserva_habitacion;
  DELETE FROM reserva;
  DELETE FROM cliente;
  DELETE FROM tarifa;
  DELETE FROM temporada;
  DELETE FROM habitacion;
  DELETE FROM alojamiento;
  DELETE FROM tipo_alojamiento;
  DELETE FROM municipio;
  COMMIT;
END;
/

-- 1. Llenar los catálogos básicos (Forzando los IDs para evitar descuadres de secuencias)
INSERT INTO municipio (id_municipio, nombre) VALUES (1, 'Armenia');
INSERT INTO municipio (id_municipio, nombre) VALUES (2, 'Calarcá');
INSERT INTO municipio (id_municipio, nombre) VALUES (3, 'Salento');
INSERT INTO municipio (id_municipio, nombre) VALUES (4, 'Filandia');
INSERT INTO municipio (id_municipio, nombre) VALUES (5, 'Quimbaya');
INSERT INTO municipio (id_municipio, nombre) VALUES (6, 'Montenegro');
INSERT INTO municipio (id_municipio, nombre) VALUES (7, 'Circasia');
INSERT INTO municipio (id_municipio, nombre) VALUES (8, 'La Tebaida');
INSERT INTO municipio (id_municipio, nombre) VALUES (9, 'Buenavista');
INSERT INTO municipio (id_municipio, nombre) VALUES (10, 'Pijao');
INSERT INTO municipio (id_municipio, nombre) VALUES (11, 'Génova');
INSERT INTO municipio (id_municipio, nombre) VALUES (12, 'Córdoba');

INSERT INTO tipo_alojamiento (id_tipo, nombre) VALUES (1, 'Hotel');
INSERT INTO tipo_alojamiento (id_tipo, nombre) VALUES (2, 'Finca Cafetera');
INSERT INTO tipo_alojamiento (id_tipo, nombre) VALUES (3, 'Glamping');
INSERT INTO tipo_alojamiento (id_tipo, nombre) VALUES (4, 'Hostal');

INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) 
VALUES (1, 'Semana Santa 2025', 'ALTA', 2025, TO_DATE('13/04/2025','DD/MM/YYYY'), TO_DATE('20/04/2025','DD/MM/YYYY'));
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) 
VALUES (2, 'Mitad de Año 2025', 'MEDIA', 2025, TO_DATE('01/06/2025','DD/MM/YYYY'), TO_DATE('15/07/2025','DD/MM/YYYY'));
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) 
VALUES (3, 'Baja 2025', 'BAJA', 2025, TO_DATE('21/04/2025','DD/MM/YYYY'), TO_DATE('31/05/2025','DD/MM/YYYY'));
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) 
VALUES (4, 'Semana Santa 2026', 'ALTA', 2026, TO_DATE('29/03/2026','DD/MM/YYYY'), TO_DATE('05/04/2026','DD/MM/YYYY'));
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) 
VALUES (5, 'Mitad de Año 2026', 'MEDIA', 2026, TO_DATE('01/06/2026','DD/MM/YYYY'), TO_DATE('15/07/2026','DD/MM/YYYY'));
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) 
VALUES (6, 'Fin de Año 2026', 'ALTA', 2026, TO_DATE('15/12/2026','DD/MM/YYYY'), TO_DATE('15/01/2027','DD/MM/YYYY'));
COMMIT;

-- 2. Cargar 60 alojamientos y habitaciones asimetricas
DECLARE
   v_tipo_aloj     NUMBER;
   v_num_habs      NUMBER;
   v_id_aloj       NUMBER;
   v_tipo_hab_str  VARCHAR2(10);
   v_id_hab        NUMBER;
BEGIN
   FOR i IN 1..60 LOOP
      v_tipo_aloj := TRUNC(DBMS_RANDOM.VALUE(1, 5));
      v_id_aloj := i; -- Forzamos el ID para que coincida con el rango de las reservas
      
      INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo)
      VALUES (
         v_id_aloj, TRUNC(DBMS_RANDOM.VALUE(1, 13)), v_tipo_aloj, 
         'Alojamiento ' || i || ' ' || DBMS_RANDOM.STRING('U',3), 
         'Calle ' || i, TRUNC(DBMS_RANDOM.VALUE(1, 6)), '300' || LPAD(i,7,'0'), 
         'contacto' || i || '@alojamiento.com'
      );

      IF v_tipo_aloj = 1 THEN v_num_habs := TRUNC(DBMS_RANDOM.VALUE(30, 41));
      ELSIF v_tipo_aloj = 2 THEN v_num_habs := TRUNC(DBMS_RANDOM.VALUE(3, 6));
      ELSE v_num_habs := TRUNC(DBMS_RANDOM.VALUE(5, 11));
      END IF;

      FOR j IN 1..v_num_habs LOOP
         IF j <= 2 THEN v_tipo_hab_str := 'SUITE';
         ELSIF j <= 10 THEN v_tipo_hab_str := 'DOBLE';
         ELSE v_tipo_hab_str := 'SENCILLA'; END IF;
         
         -- La habitacion usa RETURNING porque en la base se busca dinámicamente
         INSERT INTO habitacion (id_alojamiento, numero, capacidad, tipo)
         VALUES (v_id_aloj, TO_CHAR(j), TRUNC(DBMS_RANDOM.VALUE(1, 6)), v_tipo_hab_str)
         RETURNING id_habitacion INTO v_id_hab;
         
         FOR t IN 1..6 LOOP
            INSERT INTO tarifa (id_habitacion, id_temporada, precio_noche)
            VALUES (v_id_hab, t, ROUND(DBMS_RANDOM.VALUE(80000, 450000), -3));
         END LOOP;
      END LOOP;

      FOR s IN 1..TRUNC(DBMS_RANDOM.VALUE(1, 4)) LOOP
         INSERT INTO servicio (id_alojamiento, nombre, precio)
         VALUES (v_id_aloj, 'Servicio Extra ' || s || ' de Aloj ' || v_id_aloj, ROUND(DBMS_RANDOM.VALUE(15000, 80000), -2));
      END LOOP;
   END LOOP;
   COMMIT;
END;
/

-- 3. Cargar 3.000 clientes
DECLARE
   v_tipo_doc VARCHAR2(3);
BEGIN
   FOR i IN 1..3000 LOOP
      v_tipo_doc := CASE TRUNC(DBMS_RANDOM.VALUE(1,5)) 
                       WHEN 1 THEN 'CC' WHEN 2 THEN 'CE' WHEN 3 THEN 'TI' ELSE 'PAS' END;
      
      -- Forzamos el id_cliente = i
      INSERT INTO cliente (id_cliente, tipo_documento, numero_documento, nombre, apellido, correo, telefono, ciudad_origen)
      VALUES (
         i, v_tipo_doc, TO_CHAR(1000000 + i), 'ClienteNombre ' || i, 'Apellido ' || i,
         'cliente' || i || '@correo.com', '310' || LPAD(i,7,'0'), 'Ciudad ' || TRUNC(DBMS_RANDOM.VALUE(1, 100))
      );
   END LOOP;
   COMMIT;
END;
/

-- 4. Generar 25.000 reservas con pagos y reseñas
DECLARE
   v_id_reserva     NUMBER;
   v_id_aloj        NUMBER;
   v_id_hab         NUMBER;
   v_cin            DATE;
   v_cout           DATE;
   v_estado         VARCHAR2(10);
   v_fecha_can      DATE;
   v_metodo_pago    VARCHAR2(16);
   
   TYPE t_habs IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
   v_habs_hotel t_habs;
BEGIN
   FOR i IN 1..25000 LOOP
      v_id_aloj := TRUNC(DBMS_RANDOM.VALUE(1, 61)); -- Como forzamos los alojamientos a 1-60, esto ya no fallará
      v_cin := TRUNC(TO_DATE('01/01/2024','DD/MM/YYYY') + TRUNC(DBMS_RANDOM.VALUE(0, 1090)));
      v_cout := v_cin + TRUNC(DBMS_RANDOM.VALUE(1, 6)); 
      
      v_estado := CASE 
                     WHEN DBMS_RANDOM.VALUE(1,100) <= 70 THEN 'COMPLETADA'
                     WHEN DBMS_RANDOM.VALUE(1,100) <= 85 THEN 'CANCELADA'
                     WHEN DBMS_RANDOM.VALUE(1,100) <= 95 THEN 'CONFIRMADA'
                     ELSE 'PENDIENTE'
                  END;
                  
      v_fecha_can := CASE WHEN v_estado = 'CANCELADA' THEN v_cin - TRUNC(DBMS_RANDOM.VALUE(1, 10)) ELSE NULL END;

      INSERT INTO reserva (id_cliente, id_alojamiento, fecha_checkin, fecha_checkout, estado, fecha_cancelacion)
      VALUES (TRUNC(DBMS_RANDOM.VALUE(1, 3001)), v_id_aloj, v_cin, v_cout, v_estado, v_fecha_can)
      RETURNING id_reserva INTO v_id_reserva;

      SELECT id_habitacion BULK COLLECT INTO v_habs_hotel
      FROM habitacion WHERE id_alojamiento = v_id_aloj;
      
      IF v_habs_hotel.COUNT > 0 THEN
         v_id_hab := v_habs_hotel(TRUNC(DBMS_RANDOM.VALUE(1, v_habs_hotel.COUNT + 1)));
         INSERT INTO reserva_habitacion (id_reserva, id_habitacion, id_alojamiento, fecha_checkin, fecha_checkout, num_huespedes)
         VALUES (v_id_reserva, v_id_hab, v_id_aloj, v_cin, v_cout, 1);
      END IF;

      v_metodo_pago := CASE TRUNC(DBMS_RANDOM.VALUE(1,6))
                          WHEN 1 THEN 'TARJETA_CREDITO' WHEN 2 THEN 'TARJETA_DEBITO'
                          WHEN 3 THEN 'PSE' WHEN 4 THEN 'TRANSFERENCIA' ELSE 'EFECTIVO' END;
                          
      INSERT INTO pago (id_reserva, fecha_pago, monto, metodo, estado)
      VALUES (v_id_reserva, v_cin - 1, ROUND(DBMS_RANDOM.VALUE(100000, 900000), -2), v_metodo_pago, 'EXITOSO');

      IF v_estado = 'COMPLETADA' AND DBMS_RANDOM.VALUE(1,100) <= 40 THEN
         INSERT INTO resena (id_reserva, id_alojamiento, calificacion, comentario)
         VALUES (v_id_reserva, v_id_aloj, TRUNC(DBMS_RANDOM.VALUE(1, 6)), 'Reseña de estadia ' || i);
      END IF;

   END LOOP;
   COMMIT;
END;
/

-- 5. Crear 10 usuarios para el sistema
BEGIN
   -- Usamos alojamiento 1 y 2 que sabemos que existen por obligación
   INSERT INTO usuario_sistema (nombre_usuario, nombre_completo, correo, rol, id_alojamiento)
   VALUES ('admin1', 'Admin Principal', 'admin1@plataforma.com', 'ADMIN_PLATAFORMA', NULL);
   
   INSERT INTO usuario_sistema (nombre_usuario, nombre_completo, correo, rol, id_alojamiento)
   VALUES ('admin2', 'Admin Secundario', 'admin2@plataforma.com', 'ADMIN_PLATAFORMA', NULL);

   FOR i IN 1..8 LOOP
      INSERT INTO usuario_sistema (nombre_usuario, nombre_completo, correo, rol, id_alojamiento)
      VALUES ('encargado'||i, 'Encargado '||i, 'encargado'||i||'@hotel.com', 'ENCARGADO', i);
   END LOOP;
   COMMIT;
END;
/