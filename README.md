# data_cleaning_procedures_customer_orders
My recreated script to an SQL project tutorial by 'Lore So What' on YouTube entitle "Watch me Cleaning Data in minutes with SQL"
https://youtu.be/eOlHqTfWi6k?si=XF5zP6HO-xFc7sHv


# MySQL Data Cleaning: Customer Orders

A MySQL script that turns a messy customer-orders CSV into a consistent, analysis-ready table for exploratory data analysis (EDA).

Built by following the *Lore So What* data-cleaning guide, then extended with extra checks and fixes.

## What the script does

The script works in stages. Each stage writes to a new table, so the raw data is never touched.

```
orders_raw  ->  order_t1_staging  ->  order_t2_deduped  ->  order_t3_final
   (t0)             (t1)                  (t2)                  (t3)
 untouched      cleaned copy          duplicates removed     typed, analysis-ready
```

| Stage | What happens |
|-------|--------------|
| 00 Setup | Creates an `initcap()` function (MySQL has no built-in proper-case) and switches off safe-update mode for the run |
| 01 Stage | Copies `orders_raw` into `order_t1_staging` |
| 02 Proper naming | Removes hidden whitespace (tabs, line breaks, non-breaking spaces), trims, proper-cases text fields, lowercases email |
| 03 Standardizing | Fixes quantity written as a word, mixed country names, mixed date formats, price formatting, `@@` in emails, and two hard-coded name fixes |
| 04 Missing values | Repairs emails missing `.com`, fills missing emails from other rows of the same customer name, flags rows with a missing price |
| 05 Deduplication | Removes duplicate rows with `ROW_NUMBER()`, keeping the lowest `order_id` |
| 06 Data typing | Converts columns to `INT`, `DATE`, `DECIMAL(10,2)`, `VARCHAR`; adds a primary key on `order_id` |
| 07 Validation | Row counts per stage, missing values per column, suspicious values |
| 08 Ready | Final table `order_t3_final` |

Each cleaning step follows the same pattern: look at the problem, preview the fix with a `SELECT`, then apply it with an `UPDATE`.

## Dataset Status: Before and After
You check and balance and before and after datasets 

[Visit_raw_dataset]()

[Visit final_clean_dataset]()

Snapshot of the dataset before cleaning (`orders_raw`) and after (`order_t3_final`).

### Overview

| Metric | Before (`orders_raw`) | After (`order_t3_final`) |
|--------|----------------------|--------------------------|
| Total rows | 15 | 9 |
| Duplicate rows removed | n/a | 6 |
| Missing customer name | 1 | 0 |
| Missing email | 1 | 0 |
| Missing order date | 0 | 0 |
| Missing price | 1 | 1 |

### What changed

Check the final cleaned data: 
| Issue | Rows affected | Handling |
|-------|---------------|----------|
| Quantity written as a word | 1 | Converted to a number |
| Country abbreviations mixed with full names | 7 | Standardized to one spelling |
| Mixed date formats | 2 | Converted to `YYYY-MM-DD` |
| Price with currency signs / inconsistent decimals | 10 | Cleaned to figures with 2 decimals |
| Emails with `@@` or missing `.com` | 2 | Repaired |
| Missing email | 1 | Filled from rows with the same customer name (only where that name has exactly one valid email) |

*Counts are taken from the 15-row raw table, before the 6 duplicates were removed.*

### Flagged values (not resolved)

These values were **not estimated or guessed**. They need verification from the data owner or the original order records.

| Order ID | Field | Issue | Status |
|----------|-------|-------|--------|
| 1014 | `price` | Missing. The same product is priced differently by region and date, so a price was not copied or averaged. | Open |

### Manual fixes (dataset-specific)

| Order ID | Field | Fix |
|----------|-------|-----|
| 1009 | `customer_name` | Missing name set to "Jessica" using the matching email |
| 1008 | `customer_name` | Damaged "Carlos Hern..." names set to "Carlos Hernandez" |

## Requirements

- MySQL **8.0+** (the script uses window functions, CTEs and `REGEXP_REPLACE`)
- MySQL Workbench, or any MySQL client

## How to run

1. Create or choose a database and select it.
2. Import your CSV into a table named `orders_raw` (in Workbench: *Table Data Import Wizard*). The script expects these columns:
   `order_id, customer_name, email, order_date, product_name, quantity, price, country, order_status, notes`
3. Open `sql/customer_orders_cleaning.sql` and run it from top to bottom.
4. Read the output of the check queries as you go. Several are expected to return **no rows**; any row shown needs a manual look.
5. Your cleaned data is in `order_t3_final`.

> **Warning:** the script runs `DROP TABLE IF EXISTS` on `order_t1_staging`, `order_t2_deduped` and `order_t3_final`, so it can be re-run safely, but it will overwrite tables with those names. `orders_raw` is only read, never changed.


## Assumptions and known limitations

- **Date order:** dates written `nn/nn/yyyy` are read as month/day/year. Dates in no recognized format become `NULL`; a check query lists them.
- **Dedupe key:** rows count as duplicates when email, product, quantity and order date all match. A check query shows whether such rows have different `order_id`s, since those might be separate real orders. Rows with no email are never deleted as duplicates.
- **Email fill:** a missing email is filled from another row with the same customer name, only when that name has exactly one valid email in the data. This is an imputation, so review the preview query first.
- **Missing prices** are flagged for verification, not estimated.
- **Dataset-specific fixes:** the hard-coded fixes for two customer names (Stage 03) and the price flag (Stage 04) apply to the original dataset and may not be relevant to yours.
- **Proper-casing** (`initcap`) turns brand spellings such as "iPhone" into "Iphone".

## Credits

Cleaning approach based on the *Lore So What* guide.
https://youtu.be/eOlHqTfWi6k?si=XF5zP6HO-xFc7sHv

## License

To be added.
