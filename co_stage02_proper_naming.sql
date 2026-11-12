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

