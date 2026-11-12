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