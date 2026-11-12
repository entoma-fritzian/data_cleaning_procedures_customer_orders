-- ############################################################
-- STAGE 07: VALIDATION (checking the final dataset)
-- ############################################################

-- [F20] Row count at every stage (counts should only go down at the dedupe step)

SELECT 't0 orders_raw' AS stage, COUNT(*) AS n_rows FROM orders_raw
UNION ALL
SELECT 't1 order_t1_staging', COUNT(*) FROM order_t1_staging
UNION ALL
SELECT 't2 order_t2_deduped', COUNT(*) FROM order_t2_deduped
UNION ALL
SELECT 't3 order_t3_final', COUNT(*) FROM order_t3_final;

-- [F20] Missing values per column in the final table

SELECT
    SUM(customer_name IS NULL OR customer_name = '') AS missing_customer_name,
    SUM(email IS NULL OR email = '')                 AS missing_email,
    SUM(order_date IS NULL)                          AS missing_order_date,
    SUM(product_name IS NULL OR product_name = '')   AS missing_product_name,
    SUM(quantity IS NULL)                            AS missing_quantity,
    SUM(price IS NULL)                               AS missing_price,
    SUM(country IS NULL OR country = '')             AS missing_country,
    SUM(order_status IS NULL OR order_status = '')   AS missing_order_status
FROM order_t3_final;

-- [F20] Values that do not look right: zero or negative quantity/price, emails with a bad format

SELECT *
FROM order_t3_final
WHERE quantity <= 0 OR price <= 0;

SELECT order_id, email
FROM order_t3_final
WHERE email IS NOT NULL
  AND email <> ''
  AND email NOT REGEXP '^[^@ ]+@[^@ ]+[.][^@ ]+$';

-- [F7] Safe-update mode back on

SET SQL_SAFE_UPDATES = 1;

-- ############################################################
-- STAGE 08: DATASET READY FOR ANALYSIS
-- ############################################################

SELECT *
FROM order_t3_final;