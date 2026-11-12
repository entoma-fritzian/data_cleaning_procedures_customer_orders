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

