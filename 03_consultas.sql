-- Script 3: Las 7 consultas de analisis (Entrega 1)

SET PAGESIZE 100;
SET LINESIZE 200;

-- 1. Ocupacion por municipio y mes (PIVOT)
-- Filtramos por el 2026 y cruzamos las tablas para saber cuantas reservas entraron por mes
SELECT * FROM (
    SELECT 
        m.nombre AS municipio, 
        TO_CHAR(r.fecha_checkin, 'MM') AS mes_reserva
    FROM reserva r
    JOIN alojamiento a ON r.id_alojamiento = a.id_alojamiento
    JOIN municipio m ON a.id_municipio = m.id_municipio
    WHERE r.estado IN ('CONFIRMADA', 'COMPLETADA') 
      AND TO_CHAR(r.fecha_checkin, 'YYYY') = '2026'
)
PIVOT (
    COUNT(*) FOR mes_reserva IN (
        '01' AS ENE, '02' AS FEB, '03' AS MAR, '04' AS ABR, 
        '05' AS MAY, '06' AS JUN, '07' AS JUL, '08' AS AGO, 
        '09' AS SEP, '10' AS OCT, '11' AS NOV, '12' AS DIC
    )
) ORDER BY municipio;


-- 2. Ingresos usando ROLLUP/CUBE con GROUPING
-- Se saca el subtotal por municipio, tipo y temporada.
SELECT 
    CASE 
        WHEN GROUPING(m.nombre) = 1 THEN 'SUBTOTAL MUNICIPIO' 
        ELSE m.nombre 
    END AS municipio,
    CASE 
        WHEN GROUPING(ta.nombre) = 1 THEN 'SUBTOTAL TIPO' 
        ELSE ta.nombre 
    END AS tipo_alojamiento,
    CASE 
        WHEN GROUPING(t.nivel) = 1 THEN 'SUBTOTAL TEMPORADA' 
        ELSE t.nivel 
    END AS temporada,
    SUM(p.monto) AS total_ingresos
FROM pago p
JOIN reserva r ON p.id_reserva = r.id_reserva
JOIN alojamiento a ON r.id_alojamiento = a.id_alojamiento
JOIN municipio m ON a.id_municipio = m.id_municipio
JOIN tipo_alojamiento ta ON a.id_tipo = ta.id_tipo
LEFT JOIN temporada t ON r.fecha_checkin BETWEEN t.fecha_inicio AND t.fecha_fin
WHERE p.estado = 'EXITOSO'
GROUP BY CUBE(m.nombre, ta.nombre, t.nivel)
ORDER BY m.nombre, ta.nombre, t.nivel;


-- 3. Los 3 alojamientos que mas venden por municipio (RANK con PARTITION BY)
SELECT municipio, alojamiento, ingresos_totales, ranking
FROM (
    SELECT 
        m.nombre AS municipio, 
        a.nombre_comercial AS alojamiento, 
        SUM(p.monto) AS ingresos_totales,
        RANK() OVER (PARTITION BY m.id_municipio ORDER BY SUM(p.monto) DESC) AS ranking
    FROM pago p
    JOIN reserva r ON p.id_reserva = r.id_reserva
    JOIN alojamiento a ON r.id_alojamiento = a.id_alojamiento
    JOIN municipio m ON a.id_municipio = m.id_municipio
    WHERE p.estado = 'EXITOSO'
    GROUP BY m.id_municipio, m.nombre, a.id_alojamiento, a.nombre_comercial
)
WHERE ranking <= 3;


-- 4. Variacion de ingresos mes a mes (LAG)
-- Sumamos los pagos en la subconsulta y en el select principal comparamos con la funcion LAG.
SELECT 
    mes, 
    ingreso_actual,
    LAG(ingreso_actual, 1, 0) OVER (ORDER BY mes) AS ingreso_mes_anterior,
    ingreso_actual - LAG(ingreso_actual, 1, 0) OVER (ORDER BY mes) AS diferencia
FROM (
    SELECT 
        TO_CHAR(fecha_pago, 'YYYY-MM') AS mes,
        SUM(monto) AS ingreso_actual
    FROM pago
    WHERE estado = 'EXITOSO'
    GROUP BY TO_CHAR(fecha_pago, 'YYYY-MM')
);


-- 5. Consulta parametrizada (Reservas por rango de fechas)
-- Oracle pide ingresar las fechas al ejecutar la consulta usando las variables con el &
SELECT 
    r.id_reserva, 
    c.nombre || ' ' || c.apellido AS cliente, 
    r.fecha_checkin, 
    r.estado,
    a.nombre_comercial AS alojamiento
FROM reserva r
JOIN cliente c ON r.id_cliente = c.id_cliente
JOIN alojamiento a ON r.id_alojamiento = a.id_alojamiento
WHERE r.fecha_checkin >= TO_DATE('&fecha_inicio_YYYY_MM_DD', 'YYYY-MM-DD') 
  AND r.fecha_checkin <= TO_DATE('&fecha_fin_YYYY_MM_DD', 'YYYY-MM-DD');


-- 6. UNPIVOT (Transformar los tipos de habitacion a filas)
-- Primero se hace un PIVOT en la subconsulta interna y luego se vuelve a des-pivotar 
SELECT nombre_comercial, categoria, cantidad
FROM (
    SELECT * FROM (
        SELECT a.nombre_comercial, h.tipo
        FROM habitacion h 
        JOIN alojamiento a ON h.id_alojamiento = a.id_alojamiento
    ) 
    PIVOT (
        COUNT(*) FOR tipo IN (
            'SENCILLA' AS sencillas, 
            'DOBLE'    AS dobles, 
            'SUITE'    AS suites, 
            'CABANA'   AS cabanas
        )
    )
)
UNPIVOT (
    cantidad FOR categoria IN (
        sencillas AS 'SENCILLA', 
        dobles    AS 'DOBLE', 
        suites    AS 'SUITE', 
        cabanas   AS 'CABANA'
    )
)
WHERE cantidad > 0
ORDER BY nombre_comercial, categoria;


-- 7. Consulta Libre: Ranking de satisfaccion de clientes por municipio
-- Promediamos la calificacion de los alojamientos pero solo si tienen minimo 5 reseñas
SELECT 
    m.nombre AS municipio,
    a.nombre_comercial AS alojamiento,
    ROUND(AVG(re.calificacion), 1) AS promedio,
    COUNT(re.id_resena) AS cant_resenas
FROM resena re
JOIN alojamiento a ON re.id_alojamiento = a.id_alojamiento
JOIN municipio m ON a.id_municipio = m.id_municipio
GROUP BY m.nombre, a.nombre_comercial
HAVING COUNT(re.id_resena) >= 5
ORDER BY municipio, promedio DESC;