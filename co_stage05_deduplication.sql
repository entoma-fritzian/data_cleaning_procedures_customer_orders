-- ############################################################
-- STAGE 05: DEDUPLICATION (identifying repetitive rows)
-- ############################################################

-- [F8] Check (dedupe key NOT changed): groups of rows that the key below treats as duplicates.
-- n_order_ids > 1 means the rows have DIFFERENT order_ids, so they might be separate real orders.
-- Review before relying on the delete.

SELECT email, product_name, quantity, order_date,
       COUNT(*) AS n_rows,
       COUNT(DISTINCT order_id) AS n_order_ids,
       GROUP_CONCAT(order_id ORDER BY order_id) AS order_ids
FROM order_t1_staging
WHERE email IS NOT NULL AND TRIM(email) <> ''
GROUP BY email, product_name, quantity, order_date
HAVING COUNT(*) > 1;

-- [F4] Rows with no email get their own unique partition (based on order_id),
-- so rows with a missing email are never deleted as "duplicates" of one another.

SELECT *, 
ROW_NUMBER() OVER(
	partition by COALESCE(NULLIF(TRIM(email), ''), CONCAT('no_email_', order_id)), product_name, quantity, order_date
	ORDER BY order_id) AS rn 
FROM order_t1_staging;

-- We create a new staging table, this time to remove duplicates
-- We drop existing table to avoid confusion 

DROP TABLE IF EXISTS order_t2_deduped;

-- [F14] The hard-coded CREATE TABLE was replaced: t2 now copies the structure of t1 and adds rn as INT,
-- so new columns in the dataset do not need a manual edit here.

CREATE TABLE order_t2_deduped
LIKE order_t1_staging;

ALTER TABLE order_t2_deduped
ADD COLUMN rn INT;

INSERT INTO order_t2_deduped (order_id, customer_name, email, order_date, product_name, quantity, price, country, order_status, notes, rn)
SELECT order_id, customer_name, email, order_date, product_name, quantity, price, country, order_status, notes,
ROW_NUMBER() OVER (
partition by COALESCE(NULLIF(TRIM(email), ''), CONCAT('no_email_', order_id)), product_name, quantity, order_date
ORDER BY order_id)
FROM order_t1_staging;

-- We delete line items that have an rn (row_number) of more than 1

DELETE 
FROM order_t2_deduped
WHERE rn > 1;

-- After removing duplicates, we can now also remove the rn column 

ALTER TABLE order_t2_deduped
DROP COLUMN rn;

SELECT *
FROM order_t2_deduped;
