-- ############################################################
-- STAGE 06: DATA TYPING (validating and changing data typing)
-- ############################################################

-- We have cleaned the dataset and remove duplicates before changing data types.
-- In this way, we can avoid turning values into nulls and blanks upon change in data typing. 
-- We must create another table set for the final dataset to secure order_t2_deduped. 

DROP TABLE IF EXISTS order_t3_final; 

CREATE TABLE order_t3_final
LIKE  order_t2_deduped;

INSERT order_t3_final
SELECT order_id, customer_name, email, order_date, product_name, quantity, price, country, order_status, notes
FROM order_t2_deduped;

SELECT *
FROM order_t3_final;

-- [F12] Empty strings cannot become INT or DATE in strict mode, so they are set to NULL first.

UPDATE order_t3_final
SET quantity = NULL
WHERE TRIM(quantity) = '';

UPDATE order_t3_final
SET order_date = NULL
WHERE TRIM(order_date) = '';

-- [F12] Checks before the type change. Expected result for both: no rows.

SELECT order_id, quantity
FROM order_t3_final
WHERE quantity IS NOT NULL
  AND quantity NOT REGEXP '^[0-9]+$';

SELECT order_id, order_date
FROM order_t3_final
WHERE order_date IS NOT NULL
  AND order_date NOT REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$';

-- After securing the dataset, we can now alter the table of its data typing in each column 

ALTER TABLE order_t3_final
MODIFY COLUMN order_id INT,
MODIFY COLUMN customer_name VARCHAR(255),
MODIFY COLUMN email VARCHAR(255),
MODIFY COLUMN order_date DATE,
MODIFY COLUMN product_name VARCHAR(255),
MODIFY COLUMN quantity INT,
MODIFY COLUMN country VARCHAR(100),
MODIFY COLUMN order_status VARCHAR(50),
MODIFY COLUMN notes TEXT;

-- We have issues in converting price(TEXT) into price(DECIMAL) 
-- We narrowed down the culprit and change its value

UPDATE  order_t3_final
SET price = NULL 
WHERE TRIM(price) = '';

-- Now we can turn price into DECIMAL

ALTER TABLE  order_t3_final
MODIFY COLUMN price DECIMAL(10,2);

-- [F21] Primary key on order_id, so duplicate order ids cannot return.
-- Check first: expected result is no rows. If rows appear, the ALTER below will fail, so fix those first.

SELECT order_id, COUNT(*) AS n_rows
FROM order_t3_final
GROUP BY order_id
HAVING COUNT(*) > 1 OR order_id IS NULL;

ALTER TABLE order_t3_final
MODIFY COLUMN order_id INT NOT NULL,
ADD PRIMARY KEY (order_id);
