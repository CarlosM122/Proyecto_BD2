-- Script 5: Preparacion como administrador (Entrega 2)
-- Este script se corre UNA vez conectado como SYSTEM a la base XEPDB1
-- (no a la raiz CDB$ROOT). Los scripts 06 a 09 se corren con el usuario del proyecto.
--
-- Hace tres cosas:
--   1. Crea el tablespace TS_HISTORICO para el historico de reservas.
--   2. Le da cuota en ese tablespace al usuario del proyecto.
--   3. Le da los privilegios que necesita la Entrega 2 (vistas materializadas,
--      procedimientos, disparadores, secuencias y el job del refresco).
--
-- ANTES DE CORRER: cambiar 'TURISMOUQ' por el nombre del usuario del proyecto.

SET SERVEROUTPUT ON

DECLARE
  v_usuario  VARCHAR2(128) := 'TURISMOUQ';   -- <<< cambiar por el usuario del proyecto
  v_dir      VARCHAR2(500);
  v_existe   NUMBER;
BEGIN
  v_usuario := UPPER(v_usuario);

  -- tiene que estar en la PDB, en la raiz no se pueden crear objetos del proyecto
  IF SYS_CONTEXT('USERENV', 'CON_NAME') = 'CDB$ROOT' THEN
    RAISE_APPLICATION_ERROR(-20100, 'Conectese a XEPDB1 y no a CDB$ROOT');
  END IF;

  SELECT COUNT(*) INTO v_existe FROM dba_users WHERE username = v_usuario;
  IF v_existe = 0 THEN
    RAISE_APPLICATION_ERROR(-20101, 'No existe el usuario ' || v_usuario);
  END IF;

  -- el datafile se crea en la misma carpeta donde esta el tablespace USERS
  SELECT COUNT(*) INTO v_existe FROM dba_tablespaces WHERE tablespace_name = 'TS_HISTORICO';
  IF v_existe = 0 THEN
    SELECT SUBSTR(file_name, 1, GREATEST(INSTR(file_name, '/', -1), INSTR(file_name, '\', -1)))
      INTO v_dir
      FROM dba_data_files
     WHERE tablespace_name = 'USERS'
       AND ROWNUM = 1;

    EXECUTE IMMEDIATE 'CREATE TABLESPACE ts_historico '
                   || 'DATAFILE ''' || v_dir || 'ts_historico01.dbf'' '
                   || 'SIZE 50M AUTOEXTEND ON NEXT 10M MAXSIZE 1G '
                   || 'EXTENT MANAGEMENT LOCAL SEGMENT SPACE MANAGEMENT AUTO';
    DBMS_OUTPUT.PUT_LINE('Tablespace TS_HISTORICO creado en ' || v_dir);
  ELSE
    DBMS_OUTPUT.PUT_LINE('El tablespace TS_HISTORICO ya existia');
  END IF;

  EXECUTE IMMEDIATE 'ALTER USER ' || v_usuario || ' QUOTA UNLIMITED ON ts_historico';

  EXECUTE IMMEDIATE 'GRANT CREATE TABLE, CREATE VIEW, CREATE MATERIALIZED VIEW, CREATE PROCEDURE, '
                 || 'CREATE TRIGGER, CREATE SEQUENCE, CREATE JOB TO ' || v_usuario;
  DBMS_OUTPUT.PUT_LINE('Cuota y privilegios otorgados a ' || v_usuario);
END;
/

-- Verificacion
SELECT tablespace_name, file_name, ROUND(bytes / 1024 / 1024) AS mb, autoextensible
  FROM dba_data_files
 WHERE tablespace_name = 'TS_HISTORICO';
