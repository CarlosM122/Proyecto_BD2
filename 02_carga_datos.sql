-- Script 2: Carga de datos (Entrega 1, corregido)
-- Se ejecuta despues del 01. Demora 1-3 minutos.
-- Se usa PL/SQL con DBMS_RANDOM (con semilla fija para que siempre salgan los mismos datos).
-- Fecha de corte de los datos: 20/10/2026. Antes de esa fecha las reservas quedan
-- COMPLETADA o CANCELADA y despues PENDIENTE, CONFIRMADA o CANCELADA.
-- Los reembolsos se guardan como un pago aparte con estado REEMBOLSADO (80% de lo pagado),
-- el pago original queda EXITOSO. Ingreso neto = EXITOSO - REEMBOLSADO.

SET SERVEROUTPUT ON SIZE UNLIMITED
SET SQLBLANKLINES ON
SET DEFINE OFF
WHENEVER SQLERROR EXIT FAILURE ROLLBACK

-- 0. Limpieza de las tablas (de hijas a padres por las FK)
BEGIN
  DELETE FROM usuario_sistema;
  DELETE FROM resena;
  DELETE FROM reserva_servicio;
  DELETE FROM pago;
  DELETE FROM reserva_habitacion;
  DELETE FROM reserva;
  DELETE FROM servicio;
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

-- 1. Catalogos: 12 municipios del Quindio y 4 tipos de alojamiento
INSERT INTO municipio (id_municipio, nombre) VALUES ( 1, 'Armenia');
INSERT INTO municipio (id_municipio, nombre) VALUES ( 2, 'Calarcá');
INSERT INTO municipio (id_municipio, nombre) VALUES ( 3, 'Salento');
INSERT INTO municipio (id_municipio, nombre) VALUES ( 4, 'Filandia');
INSERT INTO municipio (id_municipio, nombre) VALUES ( 5, 'Quimbaya');
INSERT INTO municipio (id_municipio, nombre) VALUES ( 6, 'Montenegro');
INSERT INTO municipio (id_municipio, nombre) VALUES ( 7, 'Circasia');
INSERT INTO municipio (id_municipio, nombre) VALUES ( 8, 'La Tebaida');
INSERT INTO municipio (id_municipio, nombre) VALUES ( 9, 'Buenavista');
INSERT INTO municipio (id_municipio, nombre) VALUES (10, 'Pijao');
INSERT INTO municipio (id_municipio, nombre) VALUES (11, 'Génova');
INSERT INTO municipio (id_municipio, nombre) VALUES (12, 'Córdoba');

INSERT INTO tipo_alojamiento (id_tipo, nombre, descripcion) VALUES (1, 'Hotel',
  'Establecimiento urbano o campestre con recepción 24 h y muchas habitaciones (15 a 40).');
INSERT INTO tipo_alojamiento (id_tipo, nombre, descripcion) VALUES (2, 'Finca cafetera',
  'Casa de hacienda en zona rural, con pocas habitaciones (3 a 5) y experiencia del café.');
INSERT INTO tipo_alojamiento (id_tipo, nombre, descripcion) VALUES (3, 'Glamping',
  'Cabañas o domos en la naturaleza con comodidades de hotel; pocas unidades.');
INSERT INTO tipo_alojamiento (id_tipo, nombre, descripcion) VALUES (4, 'Hostal',
  'Alojamiento económico con habitaciones privadas y compartidas.');
COMMIT;

-- 2. Temporadas 2024-2026
-- Cubren todos los dias desde 2024-01-01 hasta 2027-01-11 sin huecos ni solapes.
-- ALTA: fin de año, Semana Santa, mitad de año (15 jun - 15 jul) y puentes festivos.
-- MEDIA: receso de octubre, 16 jul - 31 ago y 20 nov - 14 dic. BAJA: el resto.
-- anio = año de fecha_inicio (por el CHECK ck_temp_anio_inicio).
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (  1, 'Vacaciones de inicio de año 2024', 'ALTA', 2024, DATE '2024-01-01', DATE '2024-01-08');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (  2, 'Temporada baja 9-ene a 22-mar 2024', 'BAJA', 2024, DATE '2024-01-09', DATE '2024-03-22');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (  3, 'Semana Santa 2024', 'ALTA', 2024, DATE '2024-03-23', DATE '2024-03-31');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (  4, 'Temporada baja 1-abr a 10-may 2024', 'BAJA', 2024, DATE '2024-04-01', DATE '2024-05-10');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (  5, 'Puente festivo Ascensión 2024', 'ALTA', 2024, DATE '2024-05-11', DATE '2024-05-13');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (  6, 'Temporada baja 14-may a 31-may 2024', 'BAJA', 2024, DATE '2024-05-14', DATE '2024-05-31');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (  7, 'Puente festivo Corpus Christi 2024', 'ALTA', 2024, DATE '2024-06-01', DATE '2024-06-03');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (  8, 'Temporada baja 4-jun a 7-jun 2024', 'BAJA', 2024, DATE '2024-06-04', DATE '2024-06-07');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES (  9, 'Puente festivo Sagrado Corazón 2024', 'ALTA', 2024, DATE '2024-06-08', DATE '2024-06-10');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 10, 'Temporada baja 11-jun a 14-jun 2024', 'BAJA', 2024, DATE '2024-06-11', DATE '2024-06-14');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 11, 'Vacaciones de mitad de año 2024', 'ALTA', 2024, DATE '2024-06-15', DATE '2024-07-15');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 12, 'Temporada media 16-jul a 16-ago 2024', 'MEDIA', 2024, DATE '2024-07-16', DATE '2024-08-16');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 13, 'Puente festivo Asunción 2024', 'ALTA', 2024, DATE '2024-08-17', DATE '2024-08-19');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 14, 'Temporada media 20-ago a 31-ago 2024', 'MEDIA', 2024, DATE '2024-08-20', DATE '2024-08-31');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 15, 'Temporada baja 1-sep a 4-oct 2024', 'BAJA', 2024, DATE '2024-09-01', DATE '2024-10-04');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 16, 'Receso escolar de octubre 2024', 'MEDIA', 2024, DATE '2024-10-05', DATE '2024-10-11');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 17, 'Puente festivo Día de la Raza 2024', 'ALTA', 2024, DATE '2024-10-12', DATE '2024-10-14');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 18, 'Temporada baja 15-oct a 1-nov 2024', 'BAJA', 2024, DATE '2024-10-15', DATE '2024-11-01');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 19, 'Puente festivo Todos los Santos 2024', 'ALTA', 2024, DATE '2024-11-02', DATE '2024-11-04');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 20, 'Temporada baja 5-nov a 8-nov 2024', 'BAJA', 2024, DATE '2024-11-05', DATE '2024-11-08');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 21, 'Puente festivo Independencia de Cartagena 2024', 'ALTA', 2024, DATE '2024-11-09', DATE '2024-11-11');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 22, 'Temporada baja 12-nov a 19-nov 2024', 'BAJA', 2024, DATE '2024-11-12', DATE '2024-11-19');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 23, 'Temporada media 20-nov a 14-dic 2024', 'MEDIA', 2024, DATE '2024-11-20', DATE '2024-12-14');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 24, 'Vacaciones de fin de año 2024', 'ALTA', 2024, DATE '2024-12-15', DATE '2025-01-06');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 25, 'Temporada baja 7-ene a 21-mar 2025', 'BAJA', 2025, DATE '2025-01-07', DATE '2025-03-21');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 26, 'Puente festivo San José 2025', 'ALTA', 2025, DATE '2025-03-22', DATE '2025-03-24');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 27, 'Temporada baja 25-mar a 11-abr 2025', 'BAJA', 2025, DATE '2025-03-25', DATE '2025-04-11');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 28, 'Semana Santa 2025', 'ALTA', 2025, DATE '2025-04-12', DATE '2025-04-20');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 29, 'Temporada baja 21-abr a 30-abr 2025', 'BAJA', 2025, DATE '2025-04-21', DATE '2025-04-30');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 30, 'Puente festivo Día del Trabajo 2025', 'ALTA', 2025, DATE '2025-05-01', DATE '2025-05-04');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 31, 'Temporada baja 5-may a 30-may 2025', 'BAJA', 2025, DATE '2025-05-05', DATE '2025-05-30');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 32, 'Puente festivo Ascensión 2025', 'ALTA', 2025, DATE '2025-05-31', DATE '2025-06-02');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 33, 'Temporada baja 3-jun a 14-jun 2025', 'BAJA', 2025, DATE '2025-06-03', DATE '2025-06-14');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 34, 'Vacaciones de mitad de año 2025', 'ALTA', 2025, DATE '2025-06-15', DATE '2025-07-15');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 35, 'Temporada media 16-jul a 6-ago 2025', 'MEDIA', 2025, DATE '2025-07-16', DATE '2025-08-06');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 36, 'Puente festivo Batalla de Boyacá 2025', 'ALTA', 2025, DATE '2025-08-07', DATE '2025-08-10');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 37, 'Temporada media 11-ago a 15-ago 2025', 'MEDIA', 2025, DATE '2025-08-11', DATE '2025-08-15');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 38, 'Puente festivo Asunción 2025', 'ALTA', 2025, DATE '2025-08-16', DATE '2025-08-18');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 39, 'Temporada media 19-ago a 31-ago 2025', 'MEDIA', 2025, DATE '2025-08-19', DATE '2025-08-31');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 40, 'Temporada baja 1-sep a 3-oct 2025', 'BAJA', 2025, DATE '2025-09-01', DATE '2025-10-03');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 41, 'Receso escolar de octubre 2025', 'MEDIA', 2025, DATE '2025-10-04', DATE '2025-10-10');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 42, 'Puente festivo Día de la Raza 2025', 'ALTA', 2025, DATE '2025-10-11', DATE '2025-10-13');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 43, 'Temporada baja 14-oct a 31-oct 2025', 'BAJA', 2025, DATE '2025-10-14', DATE '2025-10-31');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 44, 'Puente festivo Todos los Santos 2025', 'ALTA', 2025, DATE '2025-11-01', DATE '2025-11-03');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 45, 'Temporada baja 4-nov a 14-nov 2025', 'BAJA', 2025, DATE '2025-11-04', DATE '2025-11-14');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 46, 'Puente festivo Independencia de Cartagena 2025', 'ALTA', 2025, DATE '2025-11-15', DATE '2025-11-17');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 47, 'Temporada baja 18-nov a 19-nov 2025', 'BAJA', 2025, DATE '2025-11-18', DATE '2025-11-19');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 48, 'Temporada media 20-nov a 5-dic 2025', 'MEDIA', 2025, DATE '2025-11-20', DATE '2025-12-05');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 49, 'Puente festivo Inmaculada Concepción 2025', 'ALTA', 2025, DATE '2025-12-06', DATE '2025-12-08');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 50, 'Temporada media 9-dic a 14-dic 2025', 'MEDIA', 2025, DATE '2025-12-09', DATE '2025-12-14');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 51, 'Vacaciones de fin de año 2025', 'ALTA', 2025, DATE '2025-12-15', DATE '2026-01-12');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 52, 'Temporada baja 13-ene a 20-mar 2026', 'BAJA', 2026, DATE '2026-01-13', DATE '2026-03-20');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 53, 'Puente festivo San José 2026', 'ALTA', 2026, DATE '2026-03-21', DATE '2026-03-23');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 54, 'Temporada baja 24-mar a 27-mar 2026', 'BAJA', 2026, DATE '2026-03-24', DATE '2026-03-27');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 55, 'Semana Santa 2026', 'ALTA', 2026, DATE '2026-03-28', DATE '2026-04-05');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 56, 'Temporada baja 6-abr a 30-abr 2026', 'BAJA', 2026, DATE '2026-04-06', DATE '2026-04-30');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 57, 'Puente festivo Día del Trabajo 2026', 'ALTA', 2026, DATE '2026-05-01', DATE '2026-05-03');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 58, 'Temporada baja 4-may a 15-may 2026', 'BAJA', 2026, DATE '2026-05-04', DATE '2026-05-15');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 59, 'Puente festivo Ascensión 2026', 'ALTA', 2026, DATE '2026-05-16', DATE '2026-05-18');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 60, 'Temporada baja 19-may a 5-jun 2026', 'BAJA', 2026, DATE '2026-05-19', DATE '2026-06-05');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 61, 'Puente festivo Corpus Christi 2026', 'ALTA', 2026, DATE '2026-06-06', DATE '2026-06-08');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 62, 'Temporada baja 9-jun a 12-jun 2026', 'BAJA', 2026, DATE '2026-06-09', DATE '2026-06-12');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 63, 'Puente festivo Sagrado Corazón 2026', 'ALTA', 2026, DATE '2026-06-13', DATE '2026-06-14');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 64, 'Vacaciones de mitad de año 2026', 'ALTA', 2026, DATE '2026-06-15', DATE '2026-07-15');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 65, 'Temporada media 16-jul a 17-jul 2026', 'MEDIA', 2026, DATE '2026-07-16', DATE '2026-07-17');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 66, 'Puente festivo Independencia 2026', 'ALTA', 2026, DATE '2026-07-18', DATE '2026-07-20');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 67, 'Temporada media 21-jul a 6-ago 2026', 'MEDIA', 2026, DATE '2026-07-21', DATE '2026-08-06');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 68, 'Puente festivo Batalla de Boyacá 2026', 'ALTA', 2026, DATE '2026-08-07', DATE '2026-08-09');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 69, 'Temporada media 10-ago a 14-ago 2026', 'MEDIA', 2026, DATE '2026-08-10', DATE '2026-08-14');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 70, 'Puente festivo Asunción 2026', 'ALTA', 2026, DATE '2026-08-15', DATE '2026-08-17');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 71, 'Temporada media 18-ago a 31-ago 2026', 'MEDIA', 2026, DATE '2026-08-18', DATE '2026-08-31');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 72, 'Temporada baja 1-sep a 2-oct 2026', 'BAJA', 2026, DATE '2026-09-01', DATE '2026-10-02');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 73, 'Receso escolar de octubre 2026', 'MEDIA', 2026, DATE '2026-10-03', DATE '2026-10-09');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 74, 'Puente festivo Día de la Raza 2026', 'ALTA', 2026, DATE '2026-10-10', DATE '2026-10-12');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 75, 'Temporada baja 13-oct a 30-oct 2026', 'BAJA', 2026, DATE '2026-10-13', DATE '2026-10-30');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 76, 'Puente festivo Todos los Santos 2026', 'ALTA', 2026, DATE '2026-10-31', DATE '2026-11-02');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 77, 'Temporada baja 3-nov a 13-nov 2026', 'BAJA', 2026, DATE '2026-11-03', DATE '2026-11-13');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 78, 'Puente festivo Independencia de Cartagena 2026', 'ALTA', 2026, DATE '2026-11-14', DATE '2026-11-16');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 79, 'Temporada baja 17-nov a 19-nov 2026', 'BAJA', 2026, DATE '2026-11-17', DATE '2026-11-19');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 80, 'Temporada media 20-nov a 4-dic 2026', 'MEDIA', 2026, DATE '2026-11-20', DATE '2026-12-04');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 81, 'Puente festivo Inmaculada Concepción 2026', 'ALTA', 2026, DATE '2026-12-05', DATE '2026-12-08');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 82, 'Temporada media 9-dic a 14-dic 2026', 'MEDIA', 2026, DATE '2026-12-09', DATE '2026-12-14');
INSERT INTO temporada (id_temporada, nombre, nivel, anio, fecha_inicio, fecha_fin) VALUES ( 83, 'Vacaciones de fin de año 2026', 'ALTA', 2026, DATE '2026-12-15', DATE '2027-01-11');
COMMIT;

-- revisa que cada dia tenga una sola temporada
DECLARE
  v_malos PLS_INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_malos
    FROM (SELECT d.dia, COUNT(t.id_temporada) n
            FROM (SELECT DATE '2024-01-01' + LEVEL - 1 AS dia FROM dual
                  CONNECT BY LEVEL <= DATE '2027-01-11' - DATE '2024-01-01' + 1) d
            LEFT JOIN temporada t ON d.dia BETWEEN t.fecha_inicio AND t.fecha_fin
           GROUP BY d.dia)
   WHERE n <> 1;
  IF v_malos > 0 THEN
    RAISE_APPLICATION_ERROR(-20010, 'Temporadas con huecos o solapes: ' || v_malos || ' dias');
  END IF;
  DBMS_OUTPUT.PUT_LINE('Temporadas OK: calendario completo sin huecos ni solapes.');
END;
/

-- 3. Alojamientos (60), repartidos desigual entre municipios.
-- Armenia tiene mas hoteles, Salento y Filandia mas glampings y hostales.
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES ( 1,  1, 1, 'Hotel Torre Quimbaya Centro', 'Carrera 14 # 18-40, Centro', 4, '6067301379', 'reservas@hoteltorrequimbayacentro.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES ( 2,  1, 1, 'Gran Hotel Bulevar del Cafe', 'Avenida Bolivar # 3N-25', 5, '6067302758', 'reservas@granhotelbulevardelcafe.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES ( 3,  1, 1, 'Hotel Parque Sucre', 'Calle 21 # 15-12, Centro', 3, '6067304137', 'reservas@hotelparquesucre.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES ( 4,  1, 1, 'Hotel Ejecutivo La Castellana', 'Carrera 13 # 4N-60, La Castellana', 4, '6067305516', 'reservas@hotelejecutivolacastellana.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES ( 5,  1, 1, 'Hotel Portal de Fundadores', 'Calle 2N # 14-35', 3, '6067306895', 'reservas@hotelportaldefundadores.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES ( 6,  1, 1, 'Hotel Boutique Arrayanes', 'Avenida Centenario # 7-80', 4, '6067308274', 'reservas@hotelboutiquearrayanes.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES ( 7,  1, 4, 'Hostal Casa Guadua Armenia', 'Calle 19 # 12-44', 2, '6067309653', 'reservas@hostalcasaguaduaarmenia.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES ( 8,  1, 4, 'Hostal La Estacion', 'Carrera 18 # 23-10', 1, '6067311032', 'reservas@hostallaestacion.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES ( 9,  1, 4, 'Hostal Mochileros del Eje', 'Calle 16 # 20-05', 2, '6067312411', 'reservas@hostalmochilerosdeleje.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (10,  1, 2, 'Finca Cafetera El Edén Viejo', 'Km 4 via Aeropuerto El Edén', 4, '6067313790', 'reservas@fincacafeteraeledenviejo.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (11,  1, 3, 'Glamping Mirador de la Patria', 'Vereda La Patria, Km 6', 4, '6067315169', 'reservas@glampingmiradordelapatria.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (12,  2, 1, 'Hotel Mirador de Calarcá', 'Carrera 25 # 38-20', 3, '6067316548', 'reservas@hotelmiradordecalarca.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (13,  2, 1, 'Hotel Jardin Botanico Calarcá', 'Km 3 via al Jardin Botanico', 4, '6067317927', 'reservas@hoteljardinbotanicocalarca.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (14,  2, 2, 'Finca Cafetera La Bella', 'Vereda La Bella, Km 5', 4, '6067319306', 'reservas@fincacafeteralabella.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (15,  2, 2, 'Finca Hacienda Quebradanegra', 'Vereda Quebradanegra', 3, '6067320685', 'reservas@fincahaciendaquebradanegra.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (16,  2, 3, 'Glamping Alto del Roble', 'Vereda El Crucero, Km 9', 4, '6067322064', 'reservas@glampingaltodelroble.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (17,  3, 1, 'Hotel Calle Real Salento', 'Calle Real # 6-15', 4, '6067323443', 'reservas@hotelcallerealsalento.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (18,  3, 4, 'Hostal Bahareque Salento', 'Carrera 4 # 2-30', 2, '6067324822', 'reservas@hostalbaharequesalento.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (19,  3, 4, 'Hostal Palma de Cera', 'Calle 7 # 3-12', 2, '6067326201', 'reservas@hostalpalmadecera.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (20,  3, 4, 'Hostal Mirador Alto de la Cruz', 'Carrera 2 # 9-40', 3, '6067327580', 'reservas@hostalmiradoraltodelacruz.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (21,  3, 3, 'Glamping Valle de Cocora', 'Vereda Cocora, Km 8', 5, '6067328959', 'reservas@glampingvalledecocora.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (22,  3, 3, 'Glamping Niebla y Montana', 'Vereda Boquia, Km 3', 4, '6067330338', 'reservas@glampingnieblaymontana.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (23,  3, 3, 'Glamping Rio Quindio', 'Vereda El Agrado', 3, '6067331717', 'reservas@glampingrioquindio.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (24,  3, 2, 'Finca Cafetera Ocaso Dorado', 'Vereda Palestina, Km 4', 4, '6067333096', 'reservas@fincacafeteraocasodorado.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (25,  3, 2, 'Finca Cafetera Don Elias', 'Vereda El Roble', 3, '6067334475', 'reservas@fincacafeteradonelias.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (26,  3, 2, 'Finca La Serrania', 'Vereda Llano Grande', 3, '6067335854', 'reservas@fincalaserrania.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (27,  4, 4, 'Hostal Colores de Filandia', 'Calle 6 # 5-20', 2, '6067337233', 'reservas@hostalcoloresdefilandia.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (28,  4, 4, 'Hostal Mirador Colina Iluminada', 'Carrera 7 # 4-11', 3, '6067338612', 'reservas@hostalmiradorcolinailuminada.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (29,  4, 3, 'Glamping Bosque de Filandia', 'Vereda Cruces, Km 2', 5, '6067339991', 'reservas@glampingbosquedefilandia.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (30,  4, 3, 'Glamping Las Brumas', 'Vereda La Palmera', 4, '6067341370', 'reservas@glampinglasbrumas.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (31,  4, 3, 'Glamping Aldea del Bambu', 'Vereda Fachadas', 3, '6067342749', 'reservas@glampingaldeadelbambu.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (32,  4, 2, 'Finca Cafetera Los Arrayanes', 'Vereda El Vigilante', 4, '6067344128', 'reservas@fincacafeteralosarrayanes.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (33,  4, 2, 'Finca Villa Sofia Filandia', 'Vereda La Julia', 3, '6067345507', 'reservas@fincavillasofiafilandia.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (34,  5, 1, 'Hotel Campestre Panorama', 'Km 2 via Panaca', 4, '6067346886', 'reservas@hotelcampestrepanorama.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (35,  5, 1, 'Hotel Las Acacias Quimbaya', 'Calle 15 # 8-30', 3, '6067348265', 'reservas@hotellasacaciasquimbaya.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (36,  5, 2, 'Finca Cafetera El Guadual', 'Vereda El Laurel', 4, '6067349644', 'reservas@fincacafeteraelguadual.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (37,  5, 2, 'Finca Hacienda Combia', 'Vereda Kerman', 4, '6067351023', 'reservas@fincahaciendacombia.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (38,  5, 2, 'Finca Villa del Platanal', 'Vereda La Union', 3, '6067352402', 'reservas@fincavilladelplatanal.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (39,  5, 3, 'Glamping Estrellas de Quimbaya', 'Vereda Puerto Alejandria', 4, '6067353781', 'reservas@glampingestrellasdequimbaya.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (40,  6, 1, 'Hotel Parque del Cafe Montenegro', 'Km 1 via Parque del Cafe', 4, '6067355160', 'reservas@hotelparquedelcafemontenegro.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (41,  6, 1, 'Hotel Campestre Pueblo Tapao', 'Vereda Pueblo Tapao', 3, '6067356539', 'reservas@hotelcampestrepueblotapao.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (42,  6, 2, 'Finca Cafetera San Alberto Real', 'Vereda Baraya', 5, '6067357918', 'reservas@fincacafeterasanalbertoreal.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (43,  6, 2, 'Finca El Cafetal de la Abuela', 'Vereda La Esperanza', 3, '6067359297', 'reservas@fincaelcafetaldelaabuela.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (44,  6, 2, 'Finca Hacienda Bambusa', 'Vereda Calle Larga', 4, '6067360676', 'reservas@fincahaciendabambusa.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (45,  6, 2, 'Finca Villa Chiquinquira', 'Vereda El Castillo', 3, '6067362055', 'reservas@fincavillachiquinquira.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (46,  6, 3, 'Glamping Cafetal Encantado', 'Vereda Santa Rita', 4, '6067363434', 'reservas@glampingcafetalencantado.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (47,  7, 2, 'Finca Cafetera La Floresta', 'Vereda La Cristalina', 4, '6067364813', 'reservas@fincacafeteralafloresta.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (48,  7, 2, 'Finca El Mirador de Circasia', 'Vereda Barcelona Alta', 3, '6067366192', 'reservas@fincaelmiradordecircasia.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (49,  7, 2, 'Finca Hacienda Villa Nueva', 'Vereda La Pola', 3, '6067367571', 'reservas@fincahaciendavillanueva.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (50,  7, 3, 'Glamping Cielo Abierto', 'Vereda Membrillal', 4, '6067368950', 'reservas@glampingcieloabierto.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (51,  8, 1, 'Hotel Aeropuerto La Tebaida', 'Avenida Principal # 10-15', 3, '6067370329', 'reservas@hotelaeropuertolatebaida.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (52,  8, 1, 'Hotel Campestre Los Guaduales', 'Km 3 via Armenia', 4, '6067371708', 'reservas@hotelcampestrelosguaduales.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (53,  8, 2, 'Finca Recreativa La Tebaida', 'Vereda La Silvia', 3, '6067373087', 'reservas@fincarecreativalatebaida.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (54,  9, 3, 'Glamping Mirador de Buenavista', 'Vereda Rio Verde Alto', 4, '6067374466', 'reservas@glampingmiradordebuenavista.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (55,  9, 2, 'Finca Cafetera El Balcon', 'Vereda Los Sauces', 3, '6067375845', 'reservas@fincacafeteraelbalcon.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (56, 10, 4, 'Hostal Pueblo Lento Pijao', 'Calle 4 # 6-21', 2, '6067377224', 'reservas@hostalpueblolentopijao.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (57, 10, 2, 'Finca Cafetera La Moravia', 'Vereda Rio Lejos', 3, '6067378603', 'reservas@fincacafeteralamoravia.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (58, 11, 2, 'Finca Cafetera Alto Gris', 'Vereda San Juan', 3, '6067379982', 'reservas@fincacafeteraaltogris.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (59, 11, 4, 'Hostal Montana Genova', 'Carrera 10 # 9-18', 1, '6067381361', 'reservas@hostalmontanagenova.com.co');
INSERT INTO alojamiento (id_alojamiento, id_municipio, id_tipo, nombre_comercial, direccion, estrellas, telefono, correo) VALUES (60, 12, 2, 'Finca La Cascada de Cordoba', 'Vereda Rio Verde', 3, '6067382740', 'reservas@fincalacascadadecordoba.com.co');
COMMIT;

-- 3.1 Habitaciones. La cantidad por alojamiento va en v_num_hab (posicion = id).
-- Hoteles 15-40, fincas 3-5, glampings 4-8, hostales 6-14.
DECLARE
  TYPE t_lista IS TABLE OF PLS_INTEGER;
  v_num_hab t_lista := t_lista(40, 38, 35, 32, 24, 18, 12, 10, 8, 5, 5, 22, 16, 5, 4, 6, 20, 14, 11, 9, 8, 6, 5, 5, 3, 4, 10, 8, 7, 5, 4, 5, 3, 30, 15, 5, 4, 3, 6, 34, 20, 5, 4, 5, 3, 5, 5, 4, 3, 6, 28, 22, 5, 5, 3, 7, 4, 3, 6, 4);
  v_tipo_aloj  PLS_INTEGER;
  v_n          PLS_INTEGER;
  v_tipo       VARCHAR2(10);
  v_cap        PLS_INTEGER;
  v_numero     VARCHAR2(10);
  v_desc       VARCHAR2(500);
  v_u          NUMBER;
BEGIN
  DBMS_RANDOM.SEED(20262);
  FOR a IN (SELECT id_alojamiento, id_tipo FROM alojamiento ORDER BY id_alojamiento) LOOP
    v_tipo_aloj := a.id_tipo;
    v_n := v_num_hab(a.id_alojamiento);
    FOR j IN 1 .. v_n LOOP
      v_u := DBMS_RANDOM.VALUE;
      IF v_tipo_aloj = 1 THEN                                   -- hotel
        v_numero := TO_CHAR(100 * (TRUNC((j - 1) / 10) + 1) + MOD(j - 1, 10) + 1);
        IF j > v_n * 0.85 THEN
          v_tipo := 'SUITE';    v_cap := 2 + TRUNC(DBMS_RANDOM.VALUE(0, 3));   -- 2-4
          v_desc := 'Suite con sala, minibar y vista panorámica.';
        ELSIF j <= v_n * 0.30 THEN
          v_tipo := 'SENCILLA'; v_cap := CASE WHEN v_u < 0.5 THEN 1 ELSE 2 END;
          v_desc := 'Habitación sencilla con cama semidoble, escritorio y wifi.';
        ELSE
          v_tipo := 'DOBLE';    v_cap := CASE WHEN v_u < 0.65 THEN 2 ELSE 3 END;
          v_desc := 'Habitación doble con dos camas o cama queen.';
        END IF;
      ELSIF v_tipo_aloj = 2 THEN                                -- finca
        v_numero := 'H' || j;
        IF j = v_n AND v_n >= 4 THEN
          v_tipo := 'SUITE';    v_cap := 3 + TRUNC(DBMS_RANDOM.VALUE(0, 2));   -- 3-4
          v_desc := 'Suite principal de la casa de hacienda con balcón al cafetal.';
        ELSE
          v_tipo := 'DOBLE';    v_cap := CASE WHEN v_u < 0.6 THEN 2 ELSE 3 END;
          v_desc := 'Habitación en bahareque con vista a los cafetales.';
        END IF;
      ELSIF v_tipo_aloj = 3 THEN                                -- glamping
        v_numero := 'C-' || j;
        v_tipo := 'CABANA';
        v_cap := CASE WHEN v_u < 0.55 THEN 2 WHEN v_u < 0.85 THEN 4 ELSE 6 END;
        v_desc := 'Cabaña con jacuzzi, malla catamarán y vista a la montaña.';
      ELSE                                                      -- hostal
        v_numero := 'H' || LPAD(j, 2, '0');
        IF j <= v_n * 0.30 THEN
          v_tipo := 'SENCILLA'; v_cap := 1;
          v_desc := 'Habitación privada individual con baño compartido.';
        ELSE
          v_tipo := 'DOBLE';
          v_cap := CASE WHEN v_u < 0.4 THEN 2 WHEN v_u < 0.7 THEN 3 WHEN v_u < 0.9 THEN 4 ELSE 6 END;
          v_desc := CASE WHEN v_cap >= 4 THEN 'Habitación compartida tipo dormitorio con lockers.'
                         ELSE 'Habitación privada con baño propio.' END;
        END IF;
      END IF;
      INSERT INTO habitacion (id_alojamiento, numero, capacidad, tipo, descripcion)
      VALUES (a.id_alojamiento, v_numero, v_cap, v_tipo, v_desc);
    END LOOP;
  END LOOP;
  COMMIT;
END;
/

-- 3.2 Tarifas: una por cada habitacion x temporada (INSERT ... SELECT del cruce).
-- precio = base del alojamiento * factor de la habitacion * factor de temporada * inflacion anual.
-- El factor de temporada alta cambia por alojamiento (1.20 a 1.80), no es un % fijo.
INSERT INTO tarifa (id_habitacion, id_temporada, precio_noche)
SELECT h.id_habitacion,
       te.id_temporada,
       ROUND(
         CASE a.id_tipo WHEN 1 THEN  60000 + a.estrellas * 30000
                        WHEN 2 THEN 110000 + a.estrellas * 20000
                        WHEN 3 THEN 150000 + a.estrellas * 25000
                        ELSE         35000 + a.estrellas * 10000 END
       * CASE h.tipo WHEN 'SENCILLA' THEN 0.80 WHEN 'DOBLE' THEN 1.00
                     WHEN 'SUITE'    THEN 1.70 ELSE 1.30 END
       * (1 + (h.capacidad - 2) * 0.12)
       * (1 + (MOD(ORA_HASH(h.id_habitacion), 17) - 8) / 100)
       * CASE te.nivel
           WHEN 'BAJA'  THEN 1
           WHEN 'MEDIA' THEN 1 + 0.45 * (0.20 + MOD(ORA_HASH(a.id_alojamiento * 7), 61) / 100)
           ELSE              1.20 + MOD(ORA_HASH(a.id_alojamiento * 7), 61) / 100
         END
       * (1 + 0.06 * (te.anio - 2024))
       , -3) AS precio_noche
  FROM habitacion h
  JOIN alojamiento a ON a.id_alojamiento = h.id_alojamiento
 CROSS JOIN temporada te;
COMMIT;

-- 3.3 Servicios: de 3 a 7 por alojamiento segun el tipo (H hotel, F finca, G glamping, O hostal).
-- La unidad de cobro va al inicio de la descripcion: [persona], [persona-noche], [reserva], [noche].
DECLARE
  TYPE t_txt IS TABLE OF VARCHAR2(200);
  TYPE t_nums IS TABLE OF NUMBER;
  -- catalogo base (las 4 listas van en el mismo orden)
  c_nom    t_txt := t_txt('Desayuno típico',
                         'Tour del café',
                         'Tour Valle de Cocora',
                         'Transporte aeropuerto El Edén',
                         'Alquiler de bicicletas',
                         'Spa y masajes',
                         'Cena romántica',
                         'Cabalgata',
                         'Entrada Parque del Café',
                         'Lavandería',
                         'Parqueadero',
                         'Fogata y asado',
                         'Avistamiento de aves',
                         'Clase de barismo',
                         'Late check-out');
  c_desc   t_txt := t_txt('[persona-noche] Arepa, huevos, fruta y café de origen.',
                         '[persona] Recorrido por el cafetal, beneficio y catación.',
                         '[persona] Caminata guiada entre palmas de cera con transporte.',
                         '[reserva] Traslado privado ida o regreso al aeropuerto.',
                         '[persona] Bicicleta de montaña por día con casco.',
                         '[persona] Masaje relajante de 60 minutos con aceites de café.',
                         '[reserva] Cena de tres tiempos para dos personas.',
                         '[persona] Cabalgata guiada de dos horas por senderos rurales.',
                         '[persona] Pasaporte de atracciones con transporte.',
                         '[reserva] Lavado y planchado de una bolsa de ropa.',
                         '[noche] Parqueadero cubierto y vigilado por noche.',
                         '[reserva] Kit de asado y fogata nocturna.',
                         '[persona] Salida de madrugada con guía ornitólogo.',
                         '[persona] Taller de métodos de preparación de café.',
                         '[reserva] Salida extendida hasta las 4 p. m.');
  c_precio t_nums := t_nums(22000, 75000, 95000, 75000, 40000, 150000, 180000, 70000, 105000, 30000, 15000, 85000, 70000, 55000, 45000);
  c_aplica t_txt := t_txt('HFGO', 'FGOH', 'GOHF', 'HFG', 'OGF', 'HG', 'GH', 'FG', 'HFG', 'HO', 'H', 'GF', 'FG', 'FO', 'HO');
  v_tipo_letra CHAR(1);
  v_n          PLS_INTEGER;
  v_ok         PLS_INTEGER;
  v_ini        PLS_INTEGER;
  i            PLS_INTEGER;
BEGIN
  FOR a IN (SELECT id_alojamiento, id_tipo FROM alojamiento ORDER BY id_alojamiento) LOOP
    v_tipo_letra := CASE a.id_tipo WHEN 1 THEN 'H' WHEN 2 THEN 'F' WHEN 3 THEN 'G' ELSE 'O' END;
    v_n   := 3 + TRUNC(DBMS_RANDOM.VALUE(0, 5));                 -- 3 a 7 servicios
    v_ok  := 0;
    v_ini := TRUNC(DBMS_RANDOM.VALUE(1, c_nom.COUNT + 1));
    FOR k IN 0 .. c_nom.COUNT - 1 LOOP
      EXIT WHEN v_ok >= v_n;
      i := MOD(v_ini - 1 + k, c_nom.COUNT) + 1;
      IF INSTR(c_aplica(i), v_tipo_letra) > 0 THEN
        INSERT INTO servicio (id_alojamiento, nombre, descripcion, precio)
        VALUES (a.id_alojamiento, c_nom(i), c_desc(i),
                ROUND(c_precio(i) * DBMS_RANDOM.VALUE(0.85, 1.15), -2));
        v_ok := v_ok + 1;
      END IF;
    END LOOP;
  END LOOP;
  COMMIT;
END;
/

-- 4. Clientes (3000). Ciudades con pesos distintos, algunos extranjeros con pasaporte.
-- No se usa TI porque un menor no reserva.
DECLARE
  TYPE t_txt IS TABLE OF VARCHAR2(40);
  v_nom t_txt := t_txt('Santiago','Valentina','Sebastián','Mariana','Mateo','Isabella','Nicolás','Sofía',
                       'Alejandro','Camila','Daniel','Daniela','Samuel','Gabriela','Juan Pablo','Sara',
                       'Andrés','Laura','Felipe','Natalia','Carlos','Paula','Diego','Juliana','Jorge',
                       'Manuela','Luis','Catalina','Javier','Valeria','Ricardo','Ana María','Óscar',
                       'Luisa','Fernando','Carolina','Esteban','Andrea','Miguel','Lucía','David','Emily',
                       'John','Hannah','Lukas','Chloé','Martín','Florencia');
  v_ape t_txt := t_txt('García','Rodríguez','Martínez','López','González','Hernández','Pérez','Sánchez',
                       'Ramírez','Torres','Flórez','Rivera','Gómez','Díaz','Restrepo','Moreno','Muñoz',
                       'Rojas','Jiménez','Vargas','Castro','Ortiz','Osorio','Giraldo','Cardona','Arango',
                       'Henao','Londoño','Quintero','Ospina','Valencia','Mejía','Zuluaga','Salazar',
                       'Aristizábal','Betancur','Smith','Müller','Dubois','Fernández');
  -- ciudades, peso y si es del exterior
  TYPE t_nums IS TABLE OF NUMBER;
  v_ciu  t_txt  := t_txt('Bogotá',
                          'Medellín',
                          'Cali',
                          'Pereira',
                          'Armenia',
                          'Manizales',
                          'Ibagué',
                          'Bucaramanga',
                          'Barranquilla',
                          'Cartagena',
                          'Cúcuta',
                          'Villavicencio',
                          'Neiva',
                          'Pasto',
                          'Santa Marta',
                          'Tuluá',
                          'Calarcá',
                          'Popayán',
                          'Montería',
                          'Palmira',
                          'Madrid',
                          'Ciudad de México',
                          'Miami',
                          'Nueva York',
                          'Buenos Aires',
                          'Santiago de Chile',
                          'Lima',
                          'Quito',
                          'Toronto',
                          'Berlín',
                          'París',
                          'Ámsterdam',
                          'Londres',
                          'Panamá');
  v_peso t_nums := t_nums(230, 140, 115, 60, 45, 40, 35, 30, 28, 20, 15, 15, 12, 10, 10, 12, 10, 8, 7, 8, 22, 15, 14, 10, 10, 8, 8, 8, 6, 6, 6, 4, 4, 4);
  v_ext  t_txt  := t_txt('N', 'N', 'N', 'N', 'N', 'N', 'N', 'N', 'N', 'N', 'N', 'N', 'N', 'N', 'N', 'N', 'N', 'N', 'N', 'N', 'S', 'S', 'S', 'S', 'S', 'S', 'S', 'S', 'S', 'S', 'S', 'S', 'S', 'S');
  v_total   NUMBER := 0;
  v_r       NUMBER;
  v_acum    NUMBER;
  v_c       PLS_INTEGER;
  v_nombre  VARCHAR2(80);
  v_ap1     VARCHAR2(40);
  v_ap2     VARCHAR2(40);
  v_tdoc    VARCHAR2(3);
  v_ndoc    VARCHAR2(20);
  v_tel     VARCHAR2(20);
  v_dom     VARCHAR2(20);
  v_usr     VARCHAR2(60);
BEGIN
  FOR k IN 1 .. v_ciu.COUNT LOOP v_total := v_total + v_peso(k); END LOOP;
  FOR i IN 1 .. 3000 LOOP
    v_r := DBMS_RANDOM.VALUE(0, v_total); v_acum := 0; v_c := v_ciu.COUNT;
    FOR k IN 1 .. v_ciu.COUNT LOOP
      v_acum := v_acum + v_peso(k);
      IF v_r < v_acum THEN v_c := k; EXIT; END IF;
    END LOOP;
    v_nombre := v_nom(TRUNC(DBMS_RANDOM.VALUE(1, v_nom.COUNT + 1)));
    v_ap1    := v_ape(TRUNC(DBMS_RANDOM.VALUE(1, v_ape.COUNT + 1)));
    v_ap2    := v_ape(TRUNC(DBMS_RANDOM.VALUE(1, v_ape.COUNT + 1)));
    IF v_ext(v_c) = 'S' THEN
      v_tdoc := 'PAS';
      v_ndoc := CHR(65 + MOD(i, 26)) || CHR(65 + MOD(i * 7, 26)) || LPAD(i * 37 + 104729, 7, '0');
      v_tel  := '+' || TRUNC(DBMS_RANDOM.VALUE(1, 60)) || ' ' || TRUNC(DBMS_RANDOM.VALUE(200000000, 999999999));
    ELSE
      v_tdoc := CASE WHEN DBMS_RANDOM.VALUE < 0.045 THEN 'CE' ELSE 'CC' END;
      v_ndoc := TO_CHAR(CASE v_tdoc WHEN 'CE' THEN 300000 + i * 41
                                    ELSE 1000000000 + i * 313 + TRUNC(DBMS_RANDOM.VALUE(0, 313)) END);
      v_tel  := '3' || TRUNC(DBMS_RANDOM.VALUE(0, 3)) || TRUNC(DBMS_RANDOM.VALUE(0, 10))
                    || LPAD(TRUNC(DBMS_RANDOM.VALUE(0, 10000000)), 7, '0');
    END IF;
    v_dom := CASE TRUNC(DBMS_RANDOM.VALUE(1, 6)) WHEN 1 THEN 'gmail.com' WHEN 2 THEN 'hotmail.com'
                  WHEN 3 THEN 'outlook.com' WHEN 4 THEN 'yahoo.com' ELSE 'gmail.com' END;
    -- correo sin tildes, con el id para que no se repita
    v_usr := LOWER(TRANSLATE(REPLACE(v_nombre, ' ', '') || '.' || REPLACE(v_ap1, ' ', ''),
                             'ÁÉÍÓÚáéíóúÑñÜüé', 'AEIOUaeiouNnUue'));
    INSERT INTO cliente (id_cliente, tipo_documento, numero_documento, nombre, apellido, correo,
                         telefono, ciudad_origen, fecha_registro)
    VALUES (i, v_tdoc, v_ndoc, v_nombre, v_ap1 || ' ' || v_ap2, v_usr || i || '@' || v_dom,
            v_tel, v_ciu(v_c),
            DATE '2023-06-01' + TRUNC(DBMS_RANDOM.VALUE(0, 1200)));
  END LOOP;
  COMMIT;
END;
/

-- 5. Reservas (26000), lineas de habitacion y servicios.
-- - Cada alojamiento tiene un peso distinto (habitaciones, municipio y popularidad).
-- - La fecha de check-in se escoge con pesos por temporada y dia de la semana.
-- - Por cada habitacion se guarda un string de '0' y '1' (un caracter por dia) para
--   no generar solapes: una linea solo entra si todas sus noches estan en '0'.
-- - Algunas reservas son de 2 a 4 habitaciones y algunas lineas llegan un dia despues.
-- - precio_unitario guarda el precio del servicio en esa epoca.
DECLARE
  c_base    CONSTANT DATE        := DATE '2024-01-01';
  c_corte   CONSTANT DATE        := DATE '2026-10-20';
  c_dias    CONSTANT PLS_INTEGER := 1096;
  c_meta    CONSTANT PLS_INTEGER := 26000;

  TYPE t_num IS TABLE OF NUMBER        INDEX BY PLS_INTEGER;
  TYPE t_vc  IS TABLE OF VARCHAR2(20)  INDEX BY PLS_INTEGER;
  TYPE t_occ IS TABLE OF VARCHAR2(1200) INDEX BY PLS_INTEGER;

  -- alojamientos
  a_tipo t_num; a_muni t_num; a_ini t_num; a_cnt t_num; a_sini t_num; a_scnt t_num; a_cum t_num;
  -- habitaciones
  h_id t_num; h_cap t_num; h_aloj t_num; occ t_occ;
  -- servicios
  s_id t_num; s_aloj t_num; s_precio t_num; s_uni t_vc;
  -- calendario
  d_nivel t_vc; cum_hotel t_num; cum_otro t_num;
  -- clientes
  cli_cum t_num;
  -- habitaciones escogidas para la reserva actual
  sel_g t_num; sel_li t_num; sel_ln t_num; sel_hu t_num;
  ser_usado t_num;

  v_ceros     VARCHAR2(1200) := RPAD('0', 1200, '0');
  v_acum      NUMBER;
  v_w         NUMBER;
  v_d         DATE;
  v_wd        PLS_INTEGER;
  v_ok        PLS_INTEGER := 0;
  v_intentos  PLS_INTEGER := 0;
  v_rechazos  PLS_INTEGER := 0;
  ia          PLS_INTEGER;
  di          PLS_INTEGER;
  n           PLS_INTEGER;
  k           PLS_INTEGER;
  v_found     PLS_INTEGER;
  v_off       PLS_INTEGER;
  g           PLS_INTEGER;
  v_li          PLS_INTEGER;
  v_ln          PLS_INTEGER;
  v_u         NUMBER;
  v_tipo      PLS_INTEGER;
  v_cin       DATE;
  v_cout      DATE;
  v_crea      DATE;
  v_fcan      DATE;
  v_min_c     DATE;
  v_max_c     DATE;
  v_hi_ant    DATE;
  v_lo_tar    DATE;
  v_lead      PLS_INTEGER;
  v_estado    VARCHAR2(10);
  v_id_res    NUMBER;
  v_cli       PLS_INTEGER;
  v_hu_total  PLS_INTEGER;
  v_nser      PLS_INTEGER;
  v_si        PLS_INTEGER;
  v_cant      PLS_INTEGER;
  v_fact_anio NUMBER;
  v_rep       BOOLEAN;

  -- escoge un indice al azar segun los pesos acumulados (busqueda binaria)
  FUNCTION elegir (p_cum IN t_num, p_lo IN PLS_INTEGER, p_hi IN PLS_INTEGER) RETURN PLS_INTEGER IS
    v_r  NUMBER := DBMS_RANDOM.VALUE(0, p_cum(p_hi));
    lo   PLS_INTEGER := p_lo;
    hi   PLS_INTEGER := p_hi;
    mid  PLS_INTEGER;
  BEGIN
    WHILE lo < hi LOOP
      mid := TRUNC((lo + hi) / 2);
      IF p_cum(mid) > v_r THEN hi := mid; ELSE lo := mid + 1; END IF;
    END LOOP;
    RETURN lo;
  END elegir;

  FUNCTION factor_municipio (p_m IN PLS_INTEGER) RETURN NUMBER IS
  BEGIN
    RETURN CASE p_m WHEN 1 THEN 1.0 WHEN 2 THEN 0.9 WHEN 3 THEN 1.6 WHEN 4 THEN 1.4
                    WHEN 5 THEN 1.2 WHEN 6 THEN 1.3 WHEN 7 THEN 0.9 WHEN 8 THEN 0.8
                    WHEN 9 THEN 0.8 WHEN 10 THEN 0.6 WHEN 11 THEN 0.5 ELSE 0.5 END;
  END factor_municipio;
BEGIN
  DBMS_RANDOM.SEED(777);

  -- peso de cada alojamiento
  FOR a IN (SELECT id_alojamiento, id_tipo, id_municipio FROM alojamiento ORDER BY id_alojamiento) LOOP
    a_tipo(a.id_alojamiento) := a.id_tipo;
    a_muni(a.id_alojamiento) := a.id_municipio;
    a_cnt(a.id_alojamiento)  := 0;
    a_scnt(a.id_alojamiento) := 0;
  END LOOP;

  SELECT id_habitacion, capacidad, id_alojamiento
    BULK COLLECT INTO h_id, h_cap, h_aloj
    FROM habitacion ORDER BY id_alojamiento, id_habitacion;
  FOR i IN 1 .. h_id.COUNT LOOP
    IF a_cnt(h_aloj(i)) = 0 THEN a_ini(h_aloj(i)) := i; END IF;
    a_cnt(h_aloj(i)) := a_cnt(h_aloj(i)) + 1;
    occ(i) := v_ceros;
  END LOOP;

  SELECT id_servicio, id_alojamiento, precio,
         CASE WHEN descripcion LIKE '[persona-noche]%' THEN 'PERSONA_NOCHE'
              WHEN descripcion LIKE '[persona]%'       THEN 'PERSONA'
              WHEN descripcion LIKE '[noche]%'         THEN 'NOCHE'
              ELSE 'RESERVA' END
    BULK COLLECT INTO s_id, s_aloj, s_precio, s_uni
    FROM servicio ORDER BY id_alojamiento, id_servicio;
  FOR i IN 1 .. s_id.COUNT LOOP
    IF a_scnt(s_aloj(i)) = 0 THEN a_sini(s_aloj(i)) := i; END IF;
    a_scnt(s_aloj(i)) := a_scnt(s_aloj(i)) + 1;
  END LOOP;

  v_acum := 0;
  FOR i IN 1 .. 60 LOOP
    v_acum := v_acum + POWER(a_cnt(i), 0.75) * factor_municipio(a_muni(i))
                       * EXP(DBMS_RANDOM.NORMAL * 0.5);
    a_cum(i) := v_acum;
  END LOOP;

  -- nivel de temporada de cada dia y pesos para el check-in
  FOR r IN (SELECT d.dia, t.nivel
              FROM (SELECT c_base + LEVEL - 1 AS dia FROM dual CONNECT BY LEVEL <= 1107) d
              JOIN temporada t ON d.dia BETWEEN t.fecha_inicio AND t.fecha_fin) LOOP
    d_nivel(r.dia - c_base) := r.nivel;
  END LOOP;

  v_acum := 0; v_w := 0;
  FOR i IN 0 .. c_dias - 1 LOOP
    v_d  := c_base + i;
    v_wd := MOD(i, 7);                         -- 0 = lunes
    v_u  := CASE EXTRACT(YEAR FROM v_d) WHEN 2024 THEN 0.85 WHEN 2025 THEN 1.0 ELSE 1.12 END;
    -- hoteles
    v_acum := v_acum + v_u
            * CASE d_nivel(i) WHEN 'ALTA' THEN 2.6 WHEN 'MEDIA' THEN 1.5 ELSE 1.0 END
            * CASE v_wd WHEN 4 THEN 1.3 WHEN 5 THEN 1.2 WHEN 6 THEN 0.7 ELSE 1.0 END;
    cum_hotel(i) := v_acum;
    -- fincas, glampings y hostales
    v_w := v_w + v_u
         * CASE d_nivel(i) WHEN 'ALTA' THEN 4.5 WHEN 'MEDIA' THEN 2.0 ELSE 1.0 END
         * CASE v_wd WHEN 0 THEN 0.7 WHEN 1 THEN 0.6 WHEN 2 THEN 0.6 WHEN 3 THEN 0.9
                     WHEN 4 THEN 1.9 WHEN 5 THEN 1.6 ELSE 0.8 END;
    cum_otro(i) := v_w;
  END LOOP;

  -- pesos de clientes (algunos reservan mucho mas)
  v_acum := 0;
  FOR i IN 1 .. 3000 LOOP
    v_acum := v_acum + EXP(DBMS_RANDOM.NORMAL * 1.0);
    cli_cum(i) := v_acum;
  END LOOP;

  -- ciclo principal
  WHILE v_ok < c_meta AND v_intentos < 400000 LOOP
    v_intentos := v_intentos + 1;
    ia     := elegir(a_cum, 1, 60);
    v_tipo := a_tipo(ia);
    IF v_tipo = 1 THEN di := elegir(cum_hotel, 0, c_dias - 1);
    ELSE               di := elegir(cum_otro,  0, c_dias - 1);
    END IF;

    -- noches segun el tipo
    v_u := DBMS_RANDOM.VALUE * 100;
    n := CASE v_tipo
           WHEN 1 THEN CASE WHEN v_u < 30 THEN 1 WHEN v_u < 65 THEN 2 WHEN v_u < 85 THEN 3 WHEN v_u < 95 THEN 4 ELSE 5 END
           WHEN 2 THEN CASE WHEN v_u < 10 THEN 1 WHEN v_u < 45 THEN 2 WHEN v_u < 70 THEN 3 WHEN v_u < 88 THEN 4 WHEN v_u < 96 THEN 5 ELSE 6 END
           WHEN 3 THEN CASE WHEN v_u < 40 THEN 1 WHEN v_u < 80 THEN 2 ELSE 3 END
           ELSE        CASE WHEN v_u < 35 THEN 1 WHEN v_u < 70 THEN 2 WHEN v_u < 90 THEN 3 ELSE 4 END
         END;
    IF d_nivel(di) = 'ALTA' AND DBMS_RANDOM.VALUE < 0.35 THEN n := n + 1; END IF;

    -- cuantas habitaciones pide
    v_u := DBMS_RANDOM.VALUE;
    k := 1;
    IF    v_tipo = 1 AND v_u < 0.15 THEN k := 2 + TRUNC(DBMS_RANDOM.VALUE(0, 3));   -- 2-4
    ELSIF v_tipo = 2 AND v_u < 0.22 THEN k := 2 + TRUNC(DBMS_RANDOM.VALUE(0, 2));   -- 2-3
    ELSIF v_tipo = 3 AND v_u < 0.08 THEN k := 2;
    ELSIF v_tipo = 4 AND v_u < 0.10 THEN k := 2 + TRUNC(DBMS_RANDOM.VALUE(0, 2));   -- 2-3
    END IF;
    k := LEAST(k, a_cnt(ia));

    -- buscar k habitaciones libres
    v_found := 0;
    v_off := TRUNC(DBMS_RANDOM.VALUE(0, a_cnt(ia)));
    FOR j IN 0 .. a_cnt(ia) - 1 LOOP
      g  := a_ini(ia) + MOD(v_off + j, a_cnt(ia));
      v_li := di; v_ln := n;
      IF v_found >= 1 AND n >= 2 THEN
        v_u := DBMS_RANDOM.VALUE;
        IF    v_u < 0.12 THEN v_li := di + 1; v_ln := n - 1;   -- llega un día después
        ELSIF v_u < 0.20 THEN v_ln := n - 1;                 -- se va un día antes
        END IF;
      END IF;
      IF INSTR(SUBSTR(occ(g), v_li + 1, v_ln), '1') = 0 THEN
        v_found := v_found + 1;
        sel_g(v_found) := g; sel_li(v_found) := v_li; sel_ln(v_found) := v_ln;
        EXIT WHEN v_found = k;
      END IF;
    END LOOP;

    IF v_found = 0 THEN
      v_rechazos := v_rechazos + 1;
    ELSE
      -- marcar las noches como ocupadas
      FOR x IN 1 .. v_found LOOP
        occ(sel_g(x)) := SUBSTR(occ(sel_g(x)), 1, sel_li(x)) || RPAD('1', sel_ln(x), '1')
                         || SUBSTR(occ(sel_g(x)), sel_li(x) + sel_ln(x) + 1);
      END LOOP;

      v_cin  := c_base + di;
      v_cout := v_cin + n;

      -- fecha de creacion (en temporada alta se reserva con mas anticipacion)
      IF d_nivel(di) = 'ALTA' THEN
        v_lead := 7 + TRUNC(-LN(1 - DBMS_RANDOM.VALUE) * 35);
      ELSE
        v_lead := 1 + TRUNC(-LN(1 - DBMS_RANDOM.VALUE) * CASE WHEN v_tipo = 1 THEN 10 ELSE 18 END);
      END IF;
      v_lead := LEAST(v_lead, 180);
      v_crea := v_cin - v_lead;
      IF v_crea > c_corte THEN                -- no puede ser despues del corte
        v_crea := c_corte - TRUNC(DBMS_RANDOM.VALUE(0, 25));
      END IF;
      v_crea := v_crea + DBMS_RANDOM.VALUE(8, 22) / 24;

      -- estado segun la fecha de corte
      v_u := DBMS_RANDOM.VALUE;
      IF v_cout <= c_corte THEN
        v_estado := CASE WHEN v_u < 0.13 THEN 'CANCELADA' ELSE 'COMPLETADA' END;
      ELSIF v_cin <= c_corte THEN
        v_estado := CASE WHEN v_u < 0.13 THEN 'CANCELADA' ELSE 'CONFIRMADA' END;
      ELSE
        IF v_u < 0.10 THEN
          v_estado := 'CANCELADA';
        ELSIF v_crea >= c_corte - 20 AND v_u < 0.55 THEN
          v_estado := 'PENDIENTE';
        ELSE
          v_estado := 'CONFIRMADA';
        END IF;
      END IF;

      -- fecha de cancelacion
      v_fcan := NULL;
      IF v_estado = 'CANCELADA' THEN
        v_min_c := TRUNC(v_crea);
        v_max_c := LEAST(v_cin - 1, c_corte);
        v_hi_ant := LEAST(v_max_c, v_cin - 6);
        v_lo_tar := GREATEST(v_min_c, v_cin - 5);
        IF v_hi_ant >= v_min_c AND (DBMS_RANDOM.VALUE < 0.6 OR v_lo_tar > v_max_c) THEN
          -- mas de 5 dias: reembolso 80%
          v_fcan := v_min_c + TRUNC(DBMS_RANDOM.VALUE(0, v_hi_ant - v_min_c + 1));
        ELSE
          -- 5 dias o menos: sin reembolso
          v_fcan := v_lo_tar + TRUNC(DBMS_RANDOM.VALUE(0, v_max_c - v_lo_tar + 1));
        END IF;
        v_fcan := GREATEST(v_fcan + DBMS_RANDOM.VALUE(8, 22) / 24, v_crea + 1 / 24);
      END IF;

      v_cli := elegir(cli_cum, 1, 3000);
      INSERT INTO reserva (id_cliente, id_alojamiento, fecha_checkin, fecha_checkout, estado,
                           fecha_creacion, fecha_cancelacion)
      VALUES (v_cli, ia, v_cin, v_cout, v_estado, v_crea, v_fcan)
      RETURNING id_reserva INTO v_id_res;

      -- lineas de habitacion
      v_hu_total := 0;
      FOR x IN 1 .. v_found LOOP
        sel_hu(x) := GREATEST(1, CEIL(h_cap(sel_g(x)) * SQRT(DBMS_RANDOM.VALUE)));
        v_hu_total := v_hu_total + sel_hu(x);
        INSERT INTO reserva_habitacion (id_reserva, id_habitacion, id_alojamiento,
                                        fecha_checkin, fecha_checkout, num_huespedes)
        VALUES (v_id_res, h_id(sel_g(x)), ia, c_base + sel_li(x), c_base + sel_li(x) + sel_ln(x), sel_hu(x));
      END LOOP;

      -- servicios: de 0 a 4 por reserva
      v_u := DBMS_RANDOM.VALUE;
      v_nser := CASE WHEN v_u < 0.15 THEN 0 WHEN v_u < 0.40 THEN 1 WHEN v_u < 0.70 THEN 2
                     WHEN v_u < 0.90 THEN 3 ELSE 4 END;
      v_nser := LEAST(v_nser, a_scnt(ia));
      v_fact_anio := CASE EXTRACT(YEAR FROM v_cin) WHEN 2024 THEN 0.88 WHEN 2025 THEN 0.94 ELSE 1 END;
      ser_usado.DELETE;
      FOR m IN 1 .. v_nser LOOP
        -- que no se repita el servicio
        LOOP
          v_si := a_sini(ia) + TRUNC(DBMS_RANDOM.VALUE(0, a_scnt(ia)));
          v_rep := ser_usado.EXISTS(v_si);
          EXIT WHEN NOT v_rep;
        END LOOP;
        ser_usado(v_si) := 1;
        v_cant := CASE s_uni(v_si)
                    WHEN 'PERSONA_NOCHE' THEN v_hu_total * n
                    WHEN 'PERSONA'       THEN GREATEST(1, CEIL(v_hu_total * SQRT(DBMS_RANDOM.VALUE)))
                    WHEN 'NOCHE'         THEN n
                    ELSE CASE WHEN DBMS_RANDOM.VALUE < 0.85 THEN 1 ELSE 2 END
                  END;
        INSERT INTO reserva_servicio (id_reserva, id_servicio, id_alojamiento, cantidad, precio_unitario)
        VALUES (v_id_res, s_id(v_si), ia, LEAST(v_cant, 999), ROUND(s_precio(v_si) * v_fact_anio, -2));
      END LOOP;

      v_ok := v_ok + 1;
    END IF;
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Reservas creadas: ' || v_ok || ' | intentos: ' || v_intentos
                       || ' | descartados por alojamiento lleno: ' || v_rechazos);
END;
/

-- 6. Pagos. El total se calcula noche a noche con la tarifa de la temporada + servicios.
-- PENDIENTE: sin pago, pago pendiente o fallido.
-- CONFIRMADA: anticipo (o pago completo); si ya llegaron, tambien el saldo.
-- COMPLETADA: pago unico, anticipo + saldo o tres abonos. Siempre suma el total exacto.
-- cancelada: anticipo; si cancelo con mas de 5 dias se reembolsa el 80%.
DECLARE
  c_corte CONSTANT DATE := DATE '2026-10-20';
  CURSOR c_res IS
    WITH k AS (SELECT LEVEL - 1 AS n FROM dual CONNECT BY LEVEL <= 31),
    estadia AS (
      SELECT rh.id_reserva, SUM(ta.precio_noche) AS valor
        FROM reserva_habitacion rh
        JOIN k          ON k.n < rh.fecha_checkout - rh.fecha_checkin
        JOIN temporada te ON rh.fecha_checkin + k.n BETWEEN te.fecha_inicio AND te.fecha_fin
        JOIN tarifa ta  ON ta.id_habitacion = rh.id_habitacion AND ta.id_temporada = te.id_temporada
       GROUP BY rh.id_reserva),
    servicios AS (
      SELECT id_reserva, SUM(cantidad * precio_unitario) AS valor
        FROM reserva_servicio GROUP BY id_reserva)
    SELECT r.id_reserva, r.estado, r.fecha_creacion, r.fecha_checkin, r.fecha_checkout,
           r.fecha_cancelacion, NVL(e.valor, 0) + NVL(s.valor, 0) AS total
      FROM reserva r
      LEFT JOIN estadia   e ON e.id_reserva = r.id_reserva
      LEFT JOIN servicios s ON s.id_reserva = r.id_reserva
     ORDER BY r.id_reserva;
  TYPE t_res IS TABLE OF c_res%ROWTYPE;
  v_res   t_res;
  v_u     NUMBER;
  v_a1    NUMBER;
  v_a2    NUMBER;
  v_f     DATE;

  FUNCTION metodo (p_al_llegar IN BOOLEAN) RETURN VARCHAR2 IS
    u NUMBER := DBMS_RANDOM.VALUE;
  BEGIN
    IF p_al_llegar THEN
      RETURN CASE WHEN u < 0.30 THEN 'TARJETA_CREDITO' WHEN u < 0.60 THEN 'TARJETA_DEBITO'
                  WHEN u < 0.90 THEN 'EFECTIVO' ELSE 'TRANSFERENCIA' END;
    ELSE
      RETURN CASE WHEN u < 0.40 THEN 'TARJETA_CREDITO' WHEN u < 0.70 THEN 'PSE'
                  WHEN u < 0.85 THEN 'TARJETA_DEBITO' ELSE 'TRANSFERENCIA' END;
    END IF;
  END metodo;

  PROCEDURE pagar (p_res IN NUMBER, p_fecha IN DATE, p_monto IN NUMBER,
                   p_estado IN VARCHAR2, p_al_llegar IN BOOLEAN DEFAULT FALSE) IS
    v_met VARCHAR2(16) := metodo(p_al_llegar);
  BEGIN
    -- a veces hay un intento fallido antes
    IF p_estado = 'EXITOSO' AND DBMS_RANDOM.VALUE < 0.06 THEN
      INSERT INTO pago (id_reserva, fecha_pago, monto, metodo, estado)
      VALUES (p_res, p_fecha - 10 / 1440, p_monto, 'TARJETA_CREDITO', 'FALLIDO');
    END IF;
    INSERT INTO pago (id_reserva, fecha_pago, monto, metodo, estado)
    VALUES (p_res, p_fecha, p_monto, v_met, p_estado);
  END pagar;
BEGIN
  OPEN c_res;
  LOOP
    FETCH c_res BULK COLLECT INTO v_res LIMIT 2000;
    EXIT WHEN v_res.COUNT = 0;
    FOR i IN 1 .. v_res.COUNT LOOP
      v_a1 := ROUND(v_res(i).total * (0.3 + 0.1 * TRUNC(DBMS_RANDOM.VALUE(0, 3))), -2);   -- anticipo 30, 40 o 50%
      v_u  := DBMS_RANDOM.VALUE;

      IF v_res(i).estado = 'PENDIENTE' THEN
        IF v_u >= 0.45 THEN
          INSERT INTO pago (id_reserva, fecha_pago, monto, metodo, estado)
          VALUES (v_res(i).id_reserva, v_res(i).fecha_creacion + 5 / 1440, v_a1,
                  CASE WHEN v_u < 0.62 THEN 'PSE' WHEN v_u < 0.80 THEN 'TRANSFERENCIA' ELSE 'TARJETA_CREDITO' END,
                  CASE WHEN v_u < 0.80 THEN 'PENDIENTE' ELSE 'FALLIDO' END);
        END IF;

      ELSIF v_res(i).estado = 'CONFIRMADA' THEN
        IF v_u < 0.25 THEN
          pagar(v_res(i).id_reserva, v_res(i).fecha_creacion + 5 / 1440, v_res(i).total, 'EXITOSO');
        ELSE
          pagar(v_res(i).id_reserva, v_res(i).fecha_creacion + 5 / 1440, v_a1, 'EXITOSO');
          IF v_res(i).fecha_checkin <= c_corte THEN
            pagar(v_res(i).id_reserva, v_res(i).fecha_checkin + DBMS_RANDOM.VALUE(14, 19) / 24,
                  v_res(i).total - v_a1, 'EXITOSO', TRUE);
          END IF;
        END IF;

      ELSIF v_res(i).estado = 'COMPLETADA' THEN
        IF v_u < 0.30 THEN
          IF DBMS_RANDOM.VALUE < 0.6 THEN
            pagar(v_res(i).id_reserva, v_res(i).fecha_creacion + 5 / 1440, v_res(i).total, 'EXITOSO');
          ELSE
            pagar(v_res(i).id_reserva, v_res(i).fecha_checkin + DBMS_RANDOM.VALUE(14, 19) / 24,
                  v_res(i).total, 'EXITOSO', TRUE);
          END IF;
        ELSIF v_u < 0.85 THEN
          pagar(v_res(i).id_reserva, v_res(i).fecha_creacion + 5 / 1440, v_a1, 'EXITOSO');
          pagar(v_res(i).id_reserva, v_res(i).fecha_checkin + DBMS_RANDOM.VALUE(14, 19) / 24,
                v_res(i).total - v_a1, 'EXITOSO', TRUE);
        ELSE
          v_a2 := ROUND(v_res(i).total * 0.3, -2);
          v_f  := v_res(i).fecha_creacion
                  + GREATEST(0, TRUNC((v_res(i).fecha_checkin - v_res(i).fecha_creacion) / 2));
          pagar(v_res(i).id_reserva, v_res(i).fecha_creacion + 5 / 1440, v_a1, 'EXITOSO');
          pagar(v_res(i).id_reserva, v_f + 2 / 24, v_a2, 'EXITOSO');
          pagar(v_res(i).id_reserva, v_res(i).fecha_checkout + DBMS_RANDOM.VALUE(8, 11) / 24,
                v_res(i).total - v_a1 - v_a2, 'EXITOSO', TRUE);
        END IF;

      ELSE                                                    -- cancelada
        IF v_u < 0.75 THEN
          pagar(v_res(i).id_reserva, v_res(i).fecha_creacion + 5 / 1440, v_a1, 'EXITOSO');
          IF TRUNC(v_res(i).fecha_checkin) - TRUNC(v_res(i).fecha_cancelacion) > 5 THEN
            -- reembolso del 80%
            INSERT INTO pago (id_reserva, fecha_pago, monto, metodo, estado)
            VALUES (v_res(i).id_reserva,
                    LEAST(v_res(i).fecha_cancelacion + DBMS_RANDOM.VALUE(1, 3), c_corte + 0.75),
                    ROUND(v_a1 * 0.8, 2), 'TRANSFERENCIA', 'REEMBOLSADO');
          END IF;
        END IF;
      END IF;
    END LOOP;
  END LOOP;
  CLOSE c_res;
  COMMIT;
END;
/

-- 7. Reseñas solo de reservas COMPLETADA, despues del checkout.
-- Cada alojamiento tiene su propia calidad y su propia tasa de reseñas.
DECLARE
  c_corte CONSTANT DATE := DATE '2026-10-20';
  TYPE t_num IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
  TYPE t_txt IS TABLE OF VARCHAR2(200);
  v_calidad t_num;
  v_tasa    t_num;
  v_cal     PLS_INTEGER;
  v_txt     VARCHAR2(200);
  v_c1 t_txt := t_txt('Muy mala experiencia, la habitación no correspondía a las fotos.',
                      'El servicio fue deficiente y nadie resolvió los problemas.',
                      'Ruido toda la noche y poca limpieza. No volvería.');
  v_c2 t_txt := t_txt('Regular. La ubicación es buena pero el lugar necesita mantenimiento.',
                      'El desayuno llegó frío y el agua caliente falló.',
                      'Esperábamos más por el precio que pagamos.');
  v_c3 t_txt := t_txt('Aceptable para una noche, nada especial.',
                      'Buen paisaje, aunque la atención fue lenta.',
                      'Cumple, pero la cama era incómoda.');
  v_c4 t_txt := t_txt('Muy buena estadía, personal amable y buena vista.',
                      'Lugar tranquilo y limpio; el café de la finca es excelente.',
                      'Recomendado, solo mejoraría el wifi.');
  v_c5 t_txt := t_txt('¡Excelente! Volveremos en la próxima temporada.',
                      'Una experiencia inolvidable en el paisaje cafetero.',
                      'Todo perfecto: atención, comida y ubicación.');
BEGIN
  FOR a IN (SELECT id_alojamiento, estrellas FROM alojamiento) LOOP
    v_calidad(a.id_alojamiento) := LEAST(4.8, 2.9 + 0.3 * a.estrellas + DBMS_RANDOM.NORMAL * 0.35);
    v_tasa(a.id_alojamiento)    := DBMS_RANDOM.VALUE(0.38, 0.75);
  END LOOP;

  FOR r IN (SELECT id_reserva, id_alojamiento, fecha_checkout
              FROM reserva WHERE estado = 'COMPLETADA' ORDER BY id_reserva) LOOP
    IF DBMS_RANDOM.VALUE < v_tasa(r.id_alojamiento) THEN
      v_cal := GREATEST(1, LEAST(5, ROUND(v_calidad(r.id_alojamiento) + DBMS_RANDOM.NORMAL * 0.9)));
      v_txt := NULL;
      IF DBMS_RANDOM.VALUE < 0.80 THEN
        v_txt := CASE v_cal
                   WHEN 1 THEN v_c1(TRUNC(DBMS_RANDOM.VALUE(1, 4)))
                   WHEN 2 THEN v_c2(TRUNC(DBMS_RANDOM.VALUE(1, 4)))
                   WHEN 3 THEN v_c3(TRUNC(DBMS_RANDOM.VALUE(1, 4)))
                   WHEN 4 THEN v_c4(TRUNC(DBMS_RANDOM.VALUE(1, 4)))
                   ELSE        v_c5(TRUNC(DBMS_RANDOM.VALUE(1, 4))) END;
      END IF;
      INSERT INTO resena (id_reserva, id_alojamiento, calificacion, comentario, fecha_resena)
      VALUES (r.id_reserva, r.id_alojamiento, v_cal, v_txt,
              LEAST(r.fecha_checkout + TRUNC(-LN(1 - DBMS_RANDOM.VALUE) * 4) + DBMS_RANDOM.VALUE(9, 22) / 24,
                    c_corte + 0.75));
    END IF;
  END LOOP;
  COMMIT;
END;
/

-- 8. Usuarios del sistema (12)
INSERT INTO usuario_sistema (nombre_usuario, nombre_completo, correo, rol, id_alojamiento)
VALUES ('admin.plataforma', 'Laura Marcela Giraldo', 'admin@turismouq.com.co', 'ADMIN_PLATAFORMA', NULL);
INSERT INTO usuario_sistema (nombre_usuario, nombre_completo, correo, rol, id_alojamiento)
VALUES ('admin.soporte', 'Andrés Felipe Ospina', 'soporte@turismouq.com.co', 'ADMIN_PLATAFORMA', NULL);
INSERT INTO usuario_sistema (nombre_usuario, nombre_completo, correo, rol, id_alojamiento)
VALUES ('enc.torrequimbaya', 'Carlos Arturo Henao', 'carlos.henao@turismouq.com.co', 'ENCARGADO', 1);
INSERT INTO usuario_sistema (nombre_usuario, nombre_completo, correo, rol, id_alojamiento)
VALUES ('enc.bulevar', 'Paula Andrea Restrepo', 'paula.restrepo@turismouq.com.co', 'ENCARGADO', 2);
INSERT INTO usuario_sistema (nombre_usuario, nombre_completo, correo, rol, id_alojamiento)
VALUES ('enc.ocasodorado', 'Jorge Iván Cardona', 'jorge.cardona@turismouq.com.co', 'ENCARGADO', 24);
INSERT INTO usuario_sistema (nombre_usuario, nombre_completo, correo, rol, id_alojamiento)
VALUES ('enc.cocora', 'Natalia Zuluaga', 'natalia.zuluaga@turismouq.com.co', 'ENCARGADO', 21);
INSERT INTO usuario_sistema (nombre_usuario, nombre_completo, correo, rol, id_alojamiento)
VALUES ('enc.bahareque', 'Sebastián Arango', 'sebastian.arango@turismouq.com.co', 'ENCARGADO', 18);
INSERT INTO usuario_sistema (nombre_usuario, nombre_completo, correo, rol, id_alojamiento)
VALUES ('rec.torrequimbaya', 'Daniela Quintero', 'daniela.quintero@turismouq.com.co', 'RECEPCION', 1);
INSERT INTO usuario_sistema (nombre_usuario, nombre_completo, correo, rol, id_alojamiento)
VALUES ('rec.parquecafe', 'Mateo Valencia', 'mateo.valencia@turismouq.com.co', 'RECEPCION', 40);
INSERT INTO usuario_sistema (nombre_usuario, nombre_completo, correo, rol, id_alojamiento)
VALUES ('gerente', 'Ana María Londoño', 'gerencia@turismouq.com.co', 'GERENTE', NULL);
INSERT INTO usuario_sistema (nombre_usuario, nombre_completo, correo, rol, id_alojamiento, estado)
VALUES ('auditor', 'Ricardo Salazar', 'auditoria@turismouq.com.co', 'AUDITOR', NULL, 'ACTIVO');
INSERT INTO usuario_sistema (nombre_usuario, nombre_completo, correo, rol, id_alojamiento, estado)
VALUES ('enc.antiguo', 'Óscar Mejía', 'oscar.mejia@turismouq.com.co', 'ENCARGADO', 34, 'INACTIVO');
COMMIT;

-- 9. Ajustes finales: fecha de registro del cliente antes de su primera reserva,
-- reinicio de las columnas identity (porque algunos id se insertaron a mano) y estadisticas.
UPDATE cliente c
   SET fecha_registro = (SELECT TRUNC(MIN(r.fecha_creacion)) - 1 - MOD(c.id_cliente, 30)
                           FROM reserva r WHERE r.id_cliente = c.id_cliente)
 WHERE fecha_registro > (SELECT MIN(r.fecha_creacion) FROM reserva r WHERE r.id_cliente = c.id_cliente);
COMMIT;

ALTER TABLE municipio          MODIFY (id_municipio   GENERATED BY DEFAULT ON NULL AS IDENTITY (START WITH LIMIT VALUE));
ALTER TABLE tipo_alojamiento   MODIFY (id_tipo        GENERATED BY DEFAULT ON NULL AS IDENTITY (START WITH LIMIT VALUE));
ALTER TABLE alojamiento        MODIFY (id_alojamiento GENERATED BY DEFAULT ON NULL AS IDENTITY (START WITH LIMIT VALUE));
ALTER TABLE temporada          MODIFY (id_temporada   GENERATED BY DEFAULT ON NULL AS IDENTITY (START WITH LIMIT VALUE));
ALTER TABLE cliente            MODIFY (id_cliente     GENERATED BY DEFAULT ON NULL AS IDENTITY (START WITH LIMIT VALUE));

BEGIN
  DBMS_STATS.GATHER_SCHEMA_STATS(ownname => USER, cascade => TRUE);
END;
/

WHENEVER SQLERROR CONTINUE

-- Conteo final por tabla
SELECT 'MUNICIPIO' tabla, COUNT(*) filas FROM municipio UNION ALL
SELECT 'TIPO_ALOJAMIENTO', COUNT(*) FROM tipo_alojamiento UNION ALL
SELECT 'ALOJAMIENTO', COUNT(*) FROM alojamiento UNION ALL
SELECT 'HABITACION', COUNT(*) FROM habitacion UNION ALL
SELECT 'TEMPORADA', COUNT(*) FROM temporada UNION ALL
SELECT 'TARIFA', COUNT(*) FROM tarifa UNION ALL
SELECT 'CLIENTE', COUNT(*) FROM cliente UNION ALL
SELECT 'RESERVA', COUNT(*) FROM reserva UNION ALL
SELECT 'RESERVA_HABITACION', COUNT(*) FROM reserva_habitacion UNION ALL
SELECT 'PAGO', COUNT(*) FROM pago UNION ALL
SELECT 'SERVICIO', COUNT(*) FROM servicio UNION ALL
SELECT 'RESERVA_SERVICIO', COUNT(*) FROM reserva_servicio UNION ALL
SELECT 'RESENA', COUNT(*) FROM resena UNION ALL
SELECT 'USUARIO_SISTEMA', COUNT(*) FROM usuario_sistema;
