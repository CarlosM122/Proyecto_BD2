-- Script 4: Verificacion de la carga
-- Revisa los puntos de la retroalimentacion de la Entrega 1. No modifica datos.
SET PAGESIZE 200
SET LINESIZE 200

-- V1. Volumen minimo por tabla
SELECT tabla, filas, minimo, CASE WHEN filas >= minimo THEN 'OK' ELSE 'FALTA' END AS estado
  FROM (SELECT 'MUNICIPIO' tabla, (SELECT COUNT(*) FROM municipio) filas, 12 minimo FROM dual UNION ALL
        SELECT 'TIPO_ALOJAMIENTO', (SELECT COUNT(*) FROM tipo_alojamiento), 4 FROM dual UNION ALL
        SELECT 'ALOJAMIENTO', (SELECT COUNT(*) FROM alojamiento), 60 FROM dual UNION ALL
        SELECT 'HABITACION', (SELECT COUNT(*) FROM habitacion), 400 FROM dual UNION ALL
        SELECT 'TEMPORADA', (SELECT COUNT(*) FROM temporada), 6 FROM dual UNION ALL
        SELECT 'TARIFA (= hab x temp)', (SELECT COUNT(*) FROM tarifa),
               (SELECT COUNT(*) FROM habitacion) * (SELECT COUNT(*) FROM temporada) FROM dual UNION ALL
        SELECT 'CLIENTE', (SELECT COUNT(*) FROM cliente), 3000 FROM dual UNION ALL
        SELECT 'RESERVA', (SELECT COUNT(*) FROM reserva), 25000 FROM dual UNION ALL
        SELECT 'RESERVA_HABITACION', (SELECT COUNT(*) FROM reserva_habitacion), 25000 FROM dual UNION ALL
        SELECT 'PAGO', (SELECT COUNT(*) FROM pago), 25000 FROM dual UNION ALL
        SELECT 'SERVICIO', (SELECT COUNT(*) FROM servicio), 30 FROM dual UNION ALL
        SELECT 'RESERVA_SERVICIO', (SELECT COUNT(*) FROM reserva_servicio), 40000 FROM dual UNION ALL
        SELECT 'USUARIO_SISTEMA', (SELECT COUNT(*) FROM usuario_sistema), 10 FROM dual);

-- V2. Dias sin temporada o con dos temporadas (debe dar 0 y 0)
SELECT SUM(CASE WHEN n = 0 THEN 1 ELSE 0 END) AS dias_sin_temporada,
       SUM(CASE WHEN n > 1 THEN 1 ELSE 0 END) AS dias_con_solape
  FROM (SELECT d.dia, COUNT(t.id_temporada) n
          FROM (SELECT DATE '2024-01-01' + LEVEL - 1 dia FROM dual
                CONNECT BY LEVEL <= DATE '2027-01-11' - DATE '2024-01-01' + 1) d
          LEFT JOIN temporada t ON d.dia BETWEEN t.fecha_inicio AND t.fecha_fin
         GROUP BY d.dia);

SELECT anio, nivel, COUNT(*) AS temporadas, SUM(fecha_fin - fecha_inicio + 1) AS dias
  FROM temporada GROUP BY anio, nivel ORDER BY anio, nivel;

-- V3. Noches reservadas sin temporada o sin tarifa (debe dar 0 y 0)
WITH k AS (SELECT LEVEL - 1 n FROM dual CONNECT BY LEVEL <= 31),
noches AS (SELECT rh.id_habitacion, rh.fecha_checkin + k.n AS dia
             FROM reserva_habitacion rh JOIN k ON k.n < rh.fecha_checkout - rh.fecha_checkin)
SELECT COUNT(*) AS noches_totales,
       SUM(CASE WHEN te.id_temporada IS NULL THEN 1 ELSE 0 END) AS noches_sin_temporada,
       SUM(CASE WHEN te.id_temporada IS NOT NULL AND tf.id_tarifa IS NULL THEN 1 ELSE 0 END) AS noches_sin_tarifa
  FROM noches n
  LEFT JOIN temporada te ON n.dia BETWEEN te.fecha_inicio AND te.fecha_fin
  LEFT JOIN tarifa    tf ON tf.id_habitacion = n.id_habitacion AND tf.id_temporada = te.id_temporada;

-- V4. Reservas por mes y por nivel de temporada
SELECT TO_CHAR(fecha_checkin, 'MM') AS mes, COUNT(*) AS reservas,
       ROUND(100 * RATIO_TO_REPORT(COUNT(*)) OVER (), 1) AS pct
  FROM reserva GROUP BY TO_CHAR(fecha_checkin, 'MM') ORDER BY mes;

SELECT te.nivel, COUNT(*) AS reservas, ROUND(100 * RATIO_TO_REPORT(COUNT(*)) OVER (), 1) AS pct_reservas,
       ROUND(100 * MAX(dias.d) / (DATE '2026-12-31' - DATE '2024-01-01' + 1), 1) AS pct_dias_calendario
  FROM reserva r
  JOIN temporada te ON r.fecha_checkin BETWEEN te.fecha_inicio AND te.fecha_fin
  JOIN (SELECT nivel, SUM(LEAST(fecha_fin, DATE '2026-12-31') - fecha_inicio + 1) d
          FROM temporada WHERE fecha_inicio <= DATE '2026-12-31' GROUP BY nivel) dias ON dias.nivel = te.nivel
 GROUP BY te.nivel ORDER BY 2 DESC;

-- V5. Reservas por alojamiento y por municipio
SELECT MIN(n) AS min_reservas, MAX(n) AS max_reservas, ROUND(AVG(n)) AS promedio,
       ROUND(STDDEV(n) / AVG(n), 2) AS coef_variacion
  FROM (SELECT id_alojamiento, COUNT(*) n FROM reserva GROUP BY id_alojamiento);

SELECT mu.nombre AS municipio, COUNT(DISTINCT a.id_alojamiento) AS alojamientos, COUNT(r.id_reserva) AS reservas
  FROM municipio mu JOIN alojamiento a ON a.id_municipio = mu.id_municipio
  LEFT JOIN reserva r ON r.id_alojamiento = a.id_alojamiento
 GROUP BY mu.nombre ORDER BY reservas DESC;

-- V6. Solapes en la misma habitacion (debe dar 0)
SELECT COUNT(*) AS solapes
  FROM reserva_habitacion x
  JOIN reserva_habitacion y
    ON y.id_habitacion = x.id_habitacion
   AND y.id_reserva_hab > x.id_reserva_hab
   AND x.fecha_checkin  < y.fecha_checkout
   AND y.fecha_checkin  < x.fecha_checkout;

-- V7. Lineas fuera del rango de la reserva o con mas huespedes que la capacidad (debe dar 0)
SELECT SUM(CASE WHEN rh.fecha_checkin < r.fecha_checkin OR rh.fecha_checkout > r.fecha_checkout
                THEN 1 ELSE 0 END) AS lineas_fuera_de_rango,
       SUM(CASE WHEN rh.num_huespedes > h.capacidad THEN 1 ELSE 0 END) AS lineas_sobre_capacidad
  FROM reserva_habitacion rh
  JOIN reserva r    ON r.id_reserva    = rh.id_reserva
  JOIN habitacion h ON h.id_habitacion = rh.id_habitacion;

-- V8. Reservas con varias habitaciones y con varios pagos
SELECT habitaciones, COUNT(*) AS reservas
  FROM (SELECT id_reserva, COUNT(*) habitaciones FROM reserva_habitacion GROUP BY id_reserva)
 GROUP BY habitaciones ORDER BY habitaciones;

SELECT pagos_exitosos, COUNT(*) AS reservas
  FROM (SELECT r.id_reserva, COUNT(p.id_pago) pagos_exitosos
          FROM reserva r LEFT JOIN pago p ON p.id_reserva = r.id_reserva AND p.estado = 'EXITOSO'
         GROUP BY r.id_reserva)
 GROUP BY pagos_exitosos ORDER BY pagos_exitosos;

-- V9. Pagos por estado de la reserva y del pago
SELECT r.estado AS estado_reserva, p.estado AS estado_pago, COUNT(*) AS pagos,
       TO_CHAR(SUM(p.monto), '999G999G999G990') AS monto
  FROM pago p JOIN reserva r ON r.id_reserva = p.id_reserva
 GROUP BY r.estado, p.estado ORDER BY 1, 2;

-- V10. Regla de reembolso en canceladas (incumplen debe dar 0)
SELECT CASE WHEN TRUNC(r.fecha_checkin) - TRUNC(r.fecha_cancelacion) > 5 THEN 'MAS DE 5 DIAS' ELSE '5 DIAS O MENOS' END AS anticipacion,
       COUNT(*) AS canceladas,
       SUM(CASE WHEN NVL(x.pagado, 0) > 0 THEN 1 ELSE 0 END) AS con_pago,
       SUM(CASE WHEN (TRUNC(r.fecha_checkin) - TRUNC(r.fecha_cancelacion) > 5
                      AND NVL(x.pagado, 0) > 0 AND NVL(x.reemb, 0) <> ROUND(0.8 * x.pagado, 2))
                  OR (TRUNC(r.fecha_checkin) - TRUNC(r.fecha_cancelacion) <= 5 AND NVL(x.reemb, 0) > 0)
                THEN 1 ELSE 0 END) AS incumplen
  FROM reserva r
  LEFT JOIN (SELECT id_reserva,
                    SUM(CASE WHEN estado = 'EXITOSO' THEN monto END)     AS pagado,
                    SUM(CASE WHEN estado = 'REEMBOLSADO' THEN monto END) AS reemb
               FROM pago GROUP BY id_reserva) x ON x.id_reserva = r.id_reserva
 WHERE r.estado = 'CANCELADA'
 GROUP BY CASE WHEN TRUNC(r.fecha_checkin) - TRUNC(r.fecha_cancelacion) > 5 THEN 'MAS DE 5 DIAS' ELSE '5 DIAS O MENOS' END;

-- V11. Completadas pagadas exactamente (diferencias debe dar 0)
WITH k AS (SELECT LEVEL - 1 n FROM dual CONNECT BY LEVEL <= 31),
est AS (SELECT rh.id_reserva, SUM(tf.precio_noche) v
          FROM reserva_habitacion rh
          JOIN k ON k.n < rh.fecha_checkout - rh.fecha_checkin
          JOIN temporada te ON rh.fecha_checkin + k.n BETWEEN te.fecha_inicio AND te.fecha_fin
          JOIN tarifa tf ON tf.id_habitacion = rh.id_habitacion AND tf.id_temporada = te.id_temporada
         GROUP BY rh.id_reserva),
ser AS (SELECT id_reserva, SUM(cantidad * precio_unitario) v FROM reserva_servicio GROUP BY id_reserva),
pag AS (SELECT id_reserva, SUM(monto) v FROM pago WHERE estado = 'EXITOSO' GROUP BY id_reserva)
SELECT COUNT(*) AS completadas,
       SUM(CASE WHEN NVL(pag.v, 0) <> NVL(est.v, 0) + NVL(ser.v, 0) THEN 1 ELSE 0 END) AS diferencias
  FROM reserva r
  LEFT JOIN est ON est.id_reserva = r.id_reserva
  LEFT JOIN ser ON ser.id_reserva = r.id_reserva
  LEFT JOIN pag ON pag.id_reserva = r.id_reserva
 WHERE r.estado = 'COMPLETADA';

-- V12. Suma de todos los pagos vs ingreso neto
SELECT TO_CHAR(SUM(monto), '999G999G999G990') AS suma_todos_los_pagos,
       TO_CHAR(SUM(CASE estado WHEN 'EXITOSO' THEN monto WHEN 'REEMBOLSADO' THEN -monto ELSE 0 END),
               '999G999G999G990') AS ingreso_neto,
       ROUND(100 * (SUM(monto) / SUM(CASE estado WHEN 'EXITOSO' THEN monto WHEN 'REEMBOLSADO' THEN -monto ELSE 0 END) - 1), 1)
         AS inflacion_si_se_suma_todo_pct
  FROM pago;

-- V13. Reseñas (pct >= 40 e invalidas = 0)
SELECT (SELECT COUNT(*) FROM resena) AS resenas,
       (SELECT COUNT(*) FROM reserva WHERE estado = 'COMPLETADA') AS completadas,
       ROUND(100 * (SELECT COUNT(*) FROM resena) / (SELECT COUNT(*) FROM reserva WHERE estado = 'COMPLETADA'), 1) AS pct,
       (SELECT COUNT(*) FROM resena re JOIN reserva r ON r.id_reserva = re.id_reserva
         WHERE r.estado <> 'COMPLETADA' OR re.fecha_resena < r.fecha_checkout) AS invalidas
  FROM dual;

SELECT calificacion, COUNT(*) AS resenas FROM resena GROUP BY calificacion ORDER BY calificacion;

-- V14. Estados coherentes con la fecha de corte (todo en 0)
SELECT SUM(CASE WHEN estado = 'COMPLETADA' AND fecha_checkout > DATE '2026-10-20' THEN 1 ELSE 0 END) AS completadas_futuras,
       SUM(CASE WHEN estado IN ('PENDIENTE') AND fecha_checkin <= DATE '2026-10-20' THEN 1 ELSE 0 END) AS pendientes_vencidas,
       SUM(CASE WHEN fecha_creacion > fecha_checkin THEN 1 ELSE 0 END) AS creadas_despues_checkin,
       SUM(CASE WHEN fecha_cancelacion < fecha_creacion OR fecha_cancelacion >= fecha_checkin THEN 1 ELSE 0 END) AS cancelacion_incoherente
  FROM reserva;
