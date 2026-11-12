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