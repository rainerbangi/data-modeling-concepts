-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 7: Price changes (8 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **What this tests:** turning a change log into SCD2 with `LEAD`, and the open-ended current row.
-- MAGIC
-- MAGIC **Scenario:** Pricing logs a row each time a price changes. Finance needs, for any day, the price that was in effect.
-- MAGIC
-- MAGIC **Raw data:** `d07_price_changes`, one row per price change: `item_id, price, effective_date`.
-- MAGIC
-- MAGIC **Your task:** build `d07_price_scd2 (item_id, price, valid_from, valid_to)`, one row per price version. `valid_from` included, `valid_to` excluded, current price ending 9999-12-31. Save it as a table; drill 16 uses it.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. A version ends when the next one starts.
-- MAGIC 2. One window function looks at the next row in order.
-- MAGIC 3. What does that function return for the newest price, and why is that a problem for later joins?
-- MAGIC
-- MAGIC **Check yourself:** 4 rows; no `valid_to` is null.

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the next cell to create this drill's practice tables.

-- COMMAND ----------

-- Setup
create or replace table d07_price_changes as
select * from values
  ('STRAW', 3.99, date'2026-01-01'), ('STRAW', 4.49, date'2026-02-15'),
  ('STRAW', 3.79, date'2026-03-10'), ('BLUE', 2.99, date'2026-01-01')
as t(item_id, price, effective_date);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 7 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.

-- COMMAND ----------

CREATE OR REPLACE TABLE d07_price_scd2 AS
WITH with_prev AS (
  SELECT *,
         LAG(price) OVER (PARTITION BY item_id ORDER BY effective_date) AS prev_price
  FROM d07_price_changes
),
real_changes AS (
  SELECT item_id, price, effective_date
  FROM with_prev
  WHERE prev_price IS DISTINCT FROM price   -- drop repeats; the first row (prev = NULL) is kept
)
SELECT item_id, price,
       effective_date AS valid_from,
       LEAD(effective_date, 1, DATE '9999-12-31')
         OVER (PARTITION BY item_id ORDER BY effective_date) AS valid_to
FROM real_changes;