-- ============================================================
-- DATA CLEANING: CUSTOMER ORDERS DATASET       
-- Date: 11/06/2026
-- Guide Source: Lore So What
-- Objective: Prepare a consistent and reliable dataset for
-- downstream exploratory data analysis (EDA).
-- ============================================================
--
-- TABLE NAME MAP (sequence logic: t0 -> t1 -> t2 -> t3)
--   raw_dataset  		 	 -> orders_raw   		 (t0, unchanged, never touched)
--   staging table      	 -> order_t1_staging     (t1, working copy)
--   deduplication table	 -> order_t2_deduped     (t2, de-duplicated)
--   final_table	     	 -> order_t3_final       (t3, analysis-ready)
--
-- CHANGE LOG (v3) - every changed or added line is tagged [F#] in the script
--   [F1]  Fixed misplaced ")" in the order_date UPDATE
--   [F4]  Rows with no email are no longer treated as duplicates of each other in dedupe
--   [F6]  Added a check for non-numeric quantity values left after the 'two' fix
--   [F7]  SQL_SAFE_UPDATES switched off at setup, back on at the end
--   [F8]  Added a check showing whether "duplicates" share an order_id (dedupe key itself NOT changed)
--   [F9]  '.com' repair now runs BEFORE the email lookup
--   [F10] Added a preview of the emails the name-based lookup will fill (fill logic NOT changed)
--   [F11] Added a check for dates that became NULL because no format matched
--   [F12] Empty-string quantity / order_date set to NULL before data typing, plus pre-ALTER checks
--   [F13] initcap() no longer applied to notes (free text); notes are only trimmed
--   [F14] t2 built with LIKE + ALTER (no hard-coded DDL); rn is INT; INSERT uses explicit columns
--   [F15] Removed duplicate TRIM in country CASE; price preview now uses TRIM(price) = ''
--   [F16] Flag comment: wording fixed (plural) and marked as "as of last run"
--   [F17] Stage headings renumbered (no duplicate STAGE 04)
--   [F18] Tabs, line breaks and non-breaking spaces cleaned before TRIM
--   [F19] DISTINCT checks added for order_status and product_name
--   [F20] Validation queries added (new STAGE 07)
--   [F21] PRIMARY KEY on order_id in order_t3_final (guarded by a check)
-- ============================================================


-- ############################################################
-- STAGE 00: SETUP
-- ############################################################

-- [F7] Workbench safe-update mode blocks UPDATE/DELETE without a key in the WHERE clause.
-- It is switched off for this script and switched back on at the end (STAGE 07).
SET SQL_SAFE_UPDATES = 0;

-- Proper Naming TEXT Fields
-- Usually we use CONCAT(UPPER(),SUBSTRING()) for proper naming, but this can become repetitive and excess syntax
-- So creating a function alike is helpful, since MySQL has no built-in INITCAP for proper naming, we created a function 'initcap'

DROP FUNCTION IF EXISTS initcap;

DELIMITER $$

CREATE FUNCTION initcap(input TEXT)
RETURNS TEXT
DETERMINISTIC
BEGIN
    DECLARE result TEXT DEFAULT '';
    DECLARE i INT DEFAULT 1;
    DECLARE len INT DEFAULT CHAR_LENGTH(input);
    DECLARE ch VARCHAR(1);
    DECLARE capitalize BOOLEAN DEFAULT TRUE;

    -- [ADDED] NULL or blank values are returned exactly as they came in
    IF input IS NULL OR TRIM(input) = '' THEN
        RETURN input;
    END IF;

    WHILE i <= len DO
        SET ch = SUBSTRING(input, i, 1);

        IF capitalize THEN
            SET result = CONCAT(result, UPPER(ch));
        ELSE
            SET result = CONCAT(result, LOWER(ch));
        END IF;

        SET capitalize = ch IN (' ', '-', '_', '.', '/', '(', ',');
        SET i = i + 1;
    END WHILE;

    RETURN result;
END$$

DELIMITER ;

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


-- ############################################################
-- STAGE 02: PROPER NAMING VALUES (uniforming values)
-- ############################################################

SELECT *
FROM order_t1_staging;

-- [F18] CSV imports often carry tabs, line breaks (\r, \n) and non-breaking spaces that TRIM() does not remove.
-- They are turned into plain spaces first, so the TRIM() steps below can work.

UPDATE order_t1_staging
SET
    customer_name = REGEXP_REPLACE(customer_name, '[\\t\\r\\n\\x{00A0}]', ' '),
    email         = REGEXP_REPLACE(email,         '[\\t\\r\\n\\x{00A0}]', ' '),
    order_date    = REGEXP_REPLACE(order_date,    '[\\t\\r\\n\\x{00A0}]', ' '),
    product_name  = REGEXP_REPLACE(product_name,  '[\\t\\r\\n\\x{00A0}]', ' '),
    quantity      = REGEXP_REPLACE(quantity,      '[\\t\\r\\n\\x{00A0}]', ' '),
    price         = REGEXP_REPLACE(price,         '[\\t\\r\\n\\x{00A0}]', ' '),
    country       = REGEXP_REPLACE(country,       '[\\t\\r\\n\\x{00A0}]', ' '),
    order_status  = REGEXP_REPLACE(order_status,  '[\\t\\r\\n\\x{00A0}]', ' '),
    notes         = REGEXP_REPLACE(notes,         '[\\t\\r\\n\\x{00A0}]', ' ');

-- From out prior set-up, we will our new function 'initcap' from our prior setup
-- Our goal is to UPPERCASE initial letters of each word and TRIM excess spaces.
-- [F13] notes is free text, so it is no longer passed through initcap() (trimmed only, in the next UPDATE).

UPDATE order_t1_staging
SET 
	customer_name = initcap(TRIM(customer_name)),
    product_name = initcap(trim(product_name)),
    country = initcap(trim(country)),
    order_status = initcap(trim(order_status));
    
UPDATE order_t1_staging
SET
    order_id = trim(order_id),
    email = LOWER(trim(email)),
	order_date = trim(order_date),
	quantity = trim(quantity),
    price = trim(price),
    notes = trim(notes);

SELECT *
FROM order_t1_staging;

-- ############################################################
-- STAGE 03: STANDARDIZING VALUES (fixing unusual values)
-- ############################################################

-- Coloumn Field: quantity, has a value expressed in words rather than figures.

SELECT distinct(quantity)
FROM  order_t1_staging;

SELECT quantity,
CASE 
	WHEN quantity = 'two' THEN 2
    ELSE quantity
END AS clean_quantity
FROM order_t1_staging;

-- We test and verify our query statement before changes. 
-- Now we can safely update the staging dataset. 

UPDATE order_t1_staging
SET quantity = 
	CASE 
	WHEN quantity = 'two' THEN 2
    ELSE quantity
END;

-- [F6] Check: any quantity that is still not a whole number (other number-words, symbols, etc.)
-- Blank values are expected here and are handled in STAGE 06.

SELECT order_id, quantity
FROM order_t1_staging
WHERE TRIM(quantity) <> ''
  AND quantity NOT REGEXP '^[0-9]+$';


-- Column Field: country, has incosistent values where abbreviations and full names were mixed together

SELECT distinct(country)
FROM  order_t1_staging
ORDER BY country;

-- [F15] ELSE TRIM(country) changed to ELSE country: values were already trimmed in STAGE 02.
SELECT country,
CASE WHEN country LIKE 'usa%' THEN 'United States' 
	 WHEN country LIKE 'us' THEN 'United States' 
     WHEN country LIKE 'uk' THEN 'United Kingdom' 
     ELSE country 
END AS cleaned_country
FROM  order_t1_staging;

-- We test and verify our query statement before changes. 
-- Now we can safely update the staging dataset.

UPDATE order_t1_staging
SET country = 
CASE WHEN country LIKE 'usa%' THEN 'United States' 
	 WHEN country LIKE 'us' THEN 'United States' 
     WHEN country LIKE 'uk' THEN 'United Kingdom' 
     ELSE country 
END;

-- Column Field: order_date, has different date formats

SELECT distinct(order_date)
FROM order_t1_staging
ORDER BY order_date;

-- There are two date values that have different date format
-- For the sake of a repetition, we will skip hard coding, rather we will use a dynamic statement logic
-- Assumption: slash dates with the year last (nn/nn/yyyy) are read as MONTH/DAY/YEAR.

SELECT order_date,
COALESCE(
    CASE WHEN TRIM(order_date) REGEXP '^[0-9]{4}-[0-9]{1,2}-[0-9]{1,2}$'
         THEN STR_TO_DATE(TRIM(order_date), '%Y-%m-%d') END,
    CASE WHEN TRIM(order_date) REGEXP '^[0-9]{4}/[0-9]{1,2}/[0-9]{1,2}$'
         THEN STR_TO_DATE(TRIM(order_date), '%Y/%m/%d') END,
    CASE WHEN TRIM(order_date) REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$'
         THEN STR_TO_DATE(TRIM(order_date), '%m/%d/%Y') END
         ) AS clean_order_date
		
FROM order_t1_staging
ORDER BY order_id;

-- We test and verify our query statement before changes. 
-- Now we can safely update the staging dataset.

-- [F1] Fixed: the third CASE now closes with "END" and then the COALESCE closes with ")".
UPDATE order_t1_staging
SET order_date = COALESCE(
    CASE WHEN TRIM(order_date) REGEXP '^[0-9]{4}-[0-9]{1,2}-[0-9]{1,2}$'
         THEN STR_TO_DATE(TRIM(order_date), '%Y-%m-%d') END,
    CASE WHEN TRIM(order_date) REGEXP '^[0-9]{4}/[0-9]{1,2}/[0-9]{1,2}$'
         THEN STR_TO_DATE(TRIM(order_date), '%Y/%m/%d') END,
    CASE WHEN TRIM(order_date) REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$'
         THEN STR_TO_DATE(TRIM(order_date), '%m/%d/%Y') END
         );

-- [F11] Check: dates that had a value in the raw table but became NULL (no format matched). 
-- Expected result: no rows. Any row shown needs a manual look.

SELECT s.order_id, r.order_date AS raw_order_date
FROM order_t1_staging s
JOIN orders_raw r ON s.order_id = r.order_id
WHERE s.order_date IS NULL
  AND r.order_date IS NOT NULL
  AND TRIM(r.order_date) <> '';

SELECT *
FROM order_t1_staging;


-- Column Field: price, has inconsistent decimal formatting. 

SELECT distinct(price)
FROM order_t1_staging;

-- [F15] Preview now uses TRIM(price) = '' to match the UPDATE below.
SELECT price,CASE WHEN price IS NULL OR TRIM(price) = '' 
				THEN price
		 WHEN REGEXP_REPLACE(price, '[^0-9.]', '') REGEXP '^[0-9]+$'
                THEN CONCAT(REGEXP_REPLACE(price, '[^0-9.]', ''), '.00')
		ELSE REGEXP_REPLACE(price, '[^0-9.]', '') END AS price_new
FROM order_t1_staging;

-- We test and verify our query statement before changes. 
-- Now we can safely update the staging dataset.

UPDATE order_t1_staging
SET price = CASE 
WHEN price IS NULL OR TRIM(price) = ''
		THEN price
WHEN REGEXP_REPLACE(price, '[^0-9.]', '') REGEXP '^[0-9]+$'
		THEN CONCAT(REGEXP_REPLACE(price, '[^0-9.]', ''), '.00')
ELSE REGEXP_REPLACE(price, '[^0-9.]', '')
END;


-- Column Field:email, has suspicious address and unusual formats that is up for review

SELECT order_id, customer_name, email, REPLACE(email, '@@', '@') AS email_fixed
FROM order_t1_staging
WHERE email LIKE '%@@%';

UPDATE order_t1_staging
SET email = REPLACE(email, '@@', '@')
WHERE email LIKE '%@@%';

-- Column Field: customer names, has suspicious names and unusual formats that is up for review
-- However, email address is a much stronger identifier than customer name in this context
-- We will hard code these issues only since these are rare instances and really not useful in data analysis in this context.

UPDATE order_t1_staging
SET customer_name = 'Carlos Hernandez'
WHERE customer_name LIKE 'Carlos Hern%';

UPDATE order_t1_staging
SET customer_name = 'Jessica'
WHERE order_id = '1009'
AND email = 'jessica@abc.com';


SELECT order_id,customer_name, email
FROM order_t1_staging;

-- [F19] Checks: review the remaining text fields for spelling variants 
-- (e.g. Canceled / Cancelled, Complete / Completed, product names written differently).

SELECT DISTINCT order_status
FROM order_t1_staging
ORDER BY order_status;

SELECT DISTINCT product_name
FROM order_t1_staging
ORDER BY product_name;

-- ############################################################
-- STAGE 04: MISSING VALUES (validating missing values)
-- ############################################################

-- Most of the missing values occur in the column field:email

SELECT customer_name,email
FROM order_t1_staging
ORDER BY email;

-- [F9] The '.com' repair now comes first, so repaired emails can also be used by the lookup below.
-- There are emails that has lacking format such '.com' in the end.
-- We will try to fill up those values 

SELECT order_id, email, CONCAT(email, '.com') AS email_fixed
FROM order_t1_staging
WHERE email REGEXP '^[^@ ]+@(gmail|outlook|hotmail|yahoo)$';

UPDATE order_t1_staging
SET email = CONCAT(email, '.com')
WHERE email REGEXP '^[^@ ]+@(gmail|outlook|hotmail|yahoo)$';

-- We see that there are missing emails that has correspindong matches from other entries.
-- We will try to lookup matching values. 
-- Note: this fills an email by matching customer_name only (an imputation). 
-- It is limited to names that have exactly one valid email in the data.

-- [F10] Preview: the rows that the lookup below will fill, and with which email.

SELECT t.order_id, t.customer_name, t.email AS current_email, m.fill_email
FROM order_t1_staging t
JOIN (
    SELECT customer_name, MIN(email) AS fill_email
    FROM order_t1_staging
    WHERE email IS NOT NULL
      AND TRIM(email) <> ''
      AND email REGEXP '^[^@ ]+@[^@ ]+[.][^@ ]+$'
    GROUP BY customer_name
    HAVING COUNT(DISTINCT email) = 1
) m ON t.customer_name = m.customer_name
WHERE t.email IS NULL OR TRIM(t.email) = '';

WITH email_lookup AS (
    SELECT customer_name, MIN(email) AS fill_email
    FROM order_t1_staging
    WHERE email IS NOT NULL
      AND TRIM(email) <> ''
      AND email REGEXP '^[^@ ]+@[^@ ]+[.][^@ ]+$'
    GROUP BY customer_name
    HAVING COUNT(DISTINCT email) = 1
)
UPDATE order_t1_staging t
JOIN email_lookup m ON t.customer_name = m.customer_name
SET t.email = m.fill_email
WHERE t.email IS NULL OR TRIM(t.email) = '';

SELECT *
FROM order_t1_staging;

-- Column Field: product_name & price, had instances where line items does not make sense. 

SELECT order_id,product_name,price,country,order_date,email
FROM order_t1_staging
WHERE (product_name IS NULL OR product_name = '')
OR 	 (price IS NULL OR price = '');

-- FLAG: price verification | order_id(s): 1006,1014 | product: Samsung Galaxy S22 | order_date: 2023-11-07
-- [F16] The ids, product and date above are as of the last run: confirm them against the query output above.
-- Issue: price is missing for these rows. Likely cause (unconfirmed): data-entry error.
-- Not estimated: the same product is priced differently by region and date,
-- so copying or averaging another price could introduce variance.
-- Action: verify the price with other sources (data owner / order record). Status: open.


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