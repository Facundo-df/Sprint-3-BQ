-- ============================================================
-- SPRINT 3 - INTRODUCCIÓN A BIGQUERY Y SQL EN LA NUBE
-- Consultas realizadas durante los ejercicios
-- ============================================================


-- ============================================================
-- NIVEL 1 - ENTORNO E INGESTA HÍBRIDA
-- ============================================================


-- ------------------------------------------------------------
-- EJERCICIO 1 - ARQUITECTURA DE DATOS
-- Creación del dataset Silver mediante SQL
-- Bronze se creó mediante UI.
-- Gold se creó mediante Cloud Shell con bq, por lo que
-- esos pasos no corresponden a SQL.
-- ------------------------------------------------------------

CREATE SCHEMA `sprint3-analytics-facuunn123.sprint3_silver`
OPTIONS (
  location = 'EU'
);


-- ============================================================
-- EJERCICIO 2 - INGESTA EN CAPA BRONZE
-- TABLAS EXTERNAS
-- ============================================================


-- ------------------------------------------------------------
-- transactions_raw
-- Tabla externa conectada al CSV del ERP.
-- El archivo utiliza ; como delimitador.
-- ------------------------------------------------------------

CREATE EXTERNAL TABLE `sprint3-analytics-facuunn123.sprint3_bronze.transactions_raw`
OPTIONS (
  format = 'CSV',
  uris = ['gs://bootcamp-data-analytics-public/ERP/transactions.csv'],
  field_delimiter = ';'
);


-- ------------------------------------------------------------
-- companies_raw
-- Esquema definido manualmente.
-- Todas las columnas se almacenan como STRING.
-- Se ignora la primera fila del CSV.
-- ------------------------------------------------------------

CREATE EXTERNAL TABLE `sprint3-analytics-facuunn123.sprint3_bronze.companies_raw`
(
  id STRING,
  company_name STRING,
  phone STRING,
  email STRING,
  country STRING,
  website STRING
)
OPTIONS (
  format = 'CSV',
  uris = ['gs://bootcamp-data-analytics-public/ERP/companies.csv'],
  skip_leading_rows = 1
);


-- ------------------------------------------------------------
-- american_users_raw
-- Tabla externa estándar.
-- ------------------------------------------------------------

CREATE EXTERNAL TABLE `sprint3-analytics-facuunn123.sprint3_bronze.american_users_raw`
OPTIONS (
  format = 'CSV',
  uris = ['gs://bootcamp-data-analytics-public/CRM/american_users.csv']
);


-- ------------------------------------------------------------
-- european_users_raw
-- Tabla externa estándar.
-- ------------------------------------------------------------

CREATE EXTERNAL TABLE `sprint3-analytics-facuunn123.sprint3_bronze.european_users_raw`
OPTIONS (
  format = 'CSV',
  uris = ['gs://bootcamp-data-analytics-public/CRM/european_users.csv']
);


-- ------------------------------------------------------------
-- credit_cards_raw
-- Tabla externa estándar.
-- ------------------------------------------------------------

CREATE EXTERNAL TABLE `sprint3-analytics-facuunn123.sprint3_bronze.credit_cards_raw`
OPTIONS (
  format = 'CSV',
  uris = ['gs://bootcamp-data-analytics-public/CRM/credit_cards.csv']
);


-- ============================================================
-- EJERCICIO 3 - CARGA DE DATOS LOCALES
-- ============================================================

-- products_raw se creó mediante Upload desde la interfaz
-- gráfica de BigQuery.
-- No se utilizó una sentencia SQL para crearla.


-- ============================================================
-- EJERCICIO 4 - MATERIALIZACIÓN Y RENDIMIENTO
-- ============================================================


-- ------------------------------------------------------------
-- 4.A - Materialización de transactions_raw
-- SQL generado mediante Gemini.
-- Convierte la tabla externa en una tabla nativa.
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE
  `sprint3-analytics-facuunn123.sprint3_bronze.transactions_raw_native`
AS
SELECT *
FROM `sprint3-analytics-facuunn123.sprint3_bronze.transactions_raw`;


-- ------------------------------------------------------------
-- 4.B - Auditoría de costes
-- Lectura de una sola columna de la tabla externa.
-- ------------------------------------------------------------

SELECT id
FROM `sprint3-analytics-facuunn123.sprint3_bronze.transactions_raw`;


-- Lectura de la misma columna en la tabla nativa.

SELECT id
FROM `sprint3-analytics-facuunn123.sprint3_bronze.transactions_raw_native`;


-- ------------------------------------------------------------
-- 4.C - Comprobación del efecto de LIMIT
-- Tabla nativa.
-- ------------------------------------------------------------

SELECT *
FROM `sprint3-analytics-facuunn123.sprint3_bronze.transactions_raw_native`
LIMIT 10;


-- Tabla externa.

SELECT *
FROM `sprint3-analytics-facuunn123.sprint3_bronze.transactions_raw`
LIMIT 10;


-- ============================================================
-- EJERCICIO 5 - REPORTING
-- TOP 5 DÍAS CON MÁS INGRESOS EN 2021
-- ============================================================

SELECT
  DATE(timestamp) AS fecha,
  ROUND(SUM(amount), 2) AS ingresos_totales
FROM `sprint3-analytics-facuunn123.sprint3_bronze.transactions_raw`
WHERE EXTRACT(YEAR FROM timestamp) = 2021
  AND declined = 0
GROUP BY fecha
ORDER BY ingresos_totales DESC
LIMIT 5;


-- Consulta auxiliar utilizada para comprobar declined.

SELECT DISTINCT declined
FROM `sprint3-analytics-facuunn123.sprint3_bronze.transactions_raw`;


-- ============================================================
-- EJERCICIO 6 - CONSULTAS COMPLEJAS
-- Empresas con operaciones entre 100 y 200 euros
-- en las fechas indicadas.
-- ============================================================

SELECT
  c.company_name AS nombre_empresa,
  c.country AS pais,
  DATE(t.timestamp) AS fecha
FROM `sprint3-analytics-facuunn123.sprint3_bronze.transactions_raw` AS t
JOIN `sprint3-analytics-facuunn123.sprint3_bronze.companies_raw` AS c
  ON t.business_id = c.id
WHERE t.amount BETWEEN 100 AND 200
  AND DATE(t.timestamp) IN (
    DATE '2015-04-29',
    DATE '2018-07-20',
    DATE '2024-03-13'
  )
ORDER BY fecha, nombre_empresa;


-- ============================================================
-- NIVEL 2 - EJERCICIO 1
-- LIMPIEZA DE PRODUCTOS
--
-- Objetivo:
-- Crear products_clean en la capa Silver, estandarizando los
-- nombres y formatos necesarios y conservando el resto de la
-- información útil para análisis posteriores.
-- ============================================================

CREATE OR REPLACE TABLE `sprint3-analytics-facuunn123.sprint3_silver.products_clean`
AS
SELECT
  id AS product_id,
  product_name AS name,
  CAST(REPLACE(warehouse_id, 'WH-', '') AS INT64) AS warehouse_id,
  price,
  colour,
  weight,
  category,
  brand,
  cost,
  launch_date
FROM `sprint3-analytics-facuunn123.sprint3_bronze.products_raw`;


-- ------------------------------------------------------------
-- Comprobación de la tabla limpia.
-- ------------------------------------------------------------

SELECT *
FROM `sprint3-analytics-facuunn123.sprint3_silver.products_clean`
LIMIT 10;

-- ============================================================
-- EJERCICIO 2 - TRANSACCIONES LIMPIAS
-- ============================================================

CREATE OR REPLACE TABLE
  `sprint3-analytics-facuunn123.sprint3_silver.transactions_clean`
AS
SELECT
  * EXCEPT(id, amount, timestamp, lat, longitude, product_ids),

  id AS transaction_id,

  IFNULL(
    SAFE_CAST(amount AS FLOAT64),
    0
  ) AS amount,

  SAFE_CAST(timestamp AS TIMESTAMP) AS timestamp,

  SAFE_CAST(lat AS FLOAT64) AS lat,

  SAFE_CAST(longitude AS FLOAT64) AS longitude,

  ARRAY(
    SELECT SAFE_CAST(TRIM(product_id) AS INT64)
    FROM UNNEST(SPLIT(product_ids, ',')) AS product_id
    WHERE SAFE_CAST(TRIM(product_id) AS INT64) IS NOT NULL
  ) AS product_ids

FROM `sprint3-analytics-facuunn123.sprint3_bronze.transactions_raw`;


-- Comprobación.

SELECT *
FROM `sprint3-analytics-facuunn123.sprint3_silver.transactions_clean`
LIMIT 10;


-- ============================================================
-- EJERCICIO 3 - UNIFICACIÓN DE USUARIOS
-- ============================================================

CREATE OR REPLACE TABLE
  `sprint3-analytics-facuunn123.sprint3_silver.users_combined`
AS

SELECT
  id AS user_id,
  * EXCEPT(id),
  'USA' AS origin
FROM `sprint3-analytics-facuunn123.sprint3_bronze.american_users_raw`

UNION ALL

SELECT
  id AS user_id,
  * EXCEPT(id),
  'EUROPE' AS origin
FROM `sprint3-analytics-facuunn123.sprint3_bronze.european_users_raw`;


-- Comprobación mostrando usuarios de ambas regiones.

SELECT
	user_id
	origin
FROM `sprint3-analytics-facuunn123.sprint3_silver.users_combined`
ORDER BY origin, user_id
LIMIT 20;



-- ============================================================
-- EJERCICIO 4 - MATERIALIZACIÓN DE COMPAÑÍAS Y TARJETAS
-- ============================================================


-- companies_clean

CREATE OR REPLACE TABLE
  `sprint3-analytics-facuunn123.sprint3_silver.companies_clean`
AS
SELECT
  id AS company_id,
  * EXCEPT(id)
FROM `sprint3-analytics-facuunn123.sprint3_bronze.companies_raw`;


-- credit_cards_clean

CREATE OR REPLACE TABLE
  `sprint3-analytics-facuunn123.sprint3_silver.credit_cards_clean`
AS
SELECT
  id AS card_id,
  * EXCEPT(id)
FROM `sprint3-analytics-facuunn123.sprint3_bronze.credit_cards_raw`;


-- Comprobación companies_clean.

SELECT *
FROM `sprint3-analytics-facuunn123.sprint3_silver.companies_clean`
LIMIT 10;


-- Comprobación credit_cards_clean.

SELECT *
FROM `sprint3-analytics-facuunn123.sprint3_silver.credit_cards_clean`
LIMIT 10;

-- ============================================================
-- NIVEL 3 - EJERCICIO 1
-- VISTA DE MARKETING: v_marketing_kpis
--
-- Objetivo:
-- Crear una vista en la capa Gold que combine datos de compañías
-- y transacciones para calcular la compra promedio por empresa
-- y clasificar a cada cliente como Premium o Standard.
-- ============================================================

CREATE OR REPLACE VIEW `sprint3-analytics-facuunn123.sprint3_gold.v_marketing_kpis`
AS
SELECT
  c.company_name,
  c.phone,
  c.country,
  AVG(t.amount) AS average_purchase,
  CASE
    WHEN AVG(t.amount) > 260 THEN 'Premium'
    ELSE 'Standard'
  END AS client_tier
FROM `sprint3-analytics-facuunn123.sprint3_silver.companies_clean` AS c
LEFT JOIN `sprint3-analytics-facuunn123.sprint3_silver.transactions_clean` AS t
  ON c.company_id = t.business_id
GROUP BY
  c.company_name,
  c.phone,
  c.country;


-- ------------------------------------------------------------
-- Consulta de comprobación / entrega
-- Muestra primero los clientes Premium y, dentro de cada grupo,
-- ordena de mayor a menor según la compra promedio.
-- ------------------------------------------------------------

SELECT *
FROM `sprint3-analytics-facuunn123.sprint3_gold.v_marketing_kpis`
ORDER BY
  CASE
    WHEN client_tier = 'Premium' THEN 1
    ELSE 2
  END,
  average_purchase DESC;
  
  -- ============================================================
-- NIVEL 3 - EJERCICIO 2
-- RANKING DE PRODUCTOS
--
-- Objetivo:
-- Crear una tabla Gold con todos los productos y el número de
-- veces que aparece cada uno en las transacciones.
-- ============================================================

CREATE OR REPLACE TABLE
  `sprint3-analytics-facuunn123.sprint3_gold.product_sales_ranking`
AS

WITH sold_products AS (
  SELECT
    product_id
  FROM `sprint3-analytics-facuunn123.sprint3_silver.transactions_clean`,
  UNNEST(product_ids) AS product_id
)

SELECT
  p.product_id,
  p.name,
  p.price,
  p.colour AS color,
  COUNT(s.product_id) AS total_sold
FROM `sprint3-analytics-facuunn123.sprint3_silver.products_clean` AS p
LEFT JOIN sold_products AS s
  ON p.product_id = s.product_id
GROUP BY
  p.product_id,
  p.name,
  p.price,
  p.colour;


-- ------------------------------------------------------------
-- Comprobación del ranking.
-- Ordena los productos desde los más vendidos.
-- ------------------------------------------------------------

SELECT *
FROM `sprint3-analytics-facuunn123.sprint3_gold.product_sales_ranking`
ORDER BY total_sold DESC, product_id;

-- ============================================================
-- NIVEL 3 - EJERCICIO 3
-- EXPORTACIÓN DE RESULTADOS
--
-- Objetivo:
-- Consultar el ranking final de productos antes de exportarlo
-- a CSV para abrirlo posteriormente en Excel. ( En mi caso hoja de calculo de google)
-- ============================================================

SELECT *
FROM `sprint3-analytics-facuunn123.sprint3_gold.product_sales_ranking`
ORDER BY total_sold DESC, product_id;

-- La exportación a CSV local se realiza manualmente desde los
-- resultados de BigQuery y no requiere una sentencia SQL.

  