-- ############################################################
-- STAGE 01: STAGE (t0 -> t1)
-- ############################################################

-- Viewing raw dataset

SELECT * 
FROM orders_raw;

-- We create a staging table for a safe dataset editing, drop any existing table. 

DROP TABLE IF EXISTS order_t1_staging;

CREATE TABLE order_t1_staging
LIKE orders_raw;

INSERT order_t1_staging
SELECT order_id, customer_name, email, order_date, product_name, quantity, price, country, order_status, notes
FROM orders_raw;
