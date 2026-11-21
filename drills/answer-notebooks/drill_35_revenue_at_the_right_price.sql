-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 35: Revenue at the right price (25 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **What this tests:** cleaning a messy price log, then pricing sales; combines drills 9, 10, 7 and 16.
-- MAGIC
-- MAGIC **Scenario:** Finance wants monthly revenue using the price in effect on each sale date, plus a count of units that couldn't be priced.
-- MAGIC
-- MAGIC **Raw data:**
-- MAGIC - `c35_price_changes`: `item_id, price, change_ts`. Effective the same day. Some days have more than one change; some changes repeat the previous price.
-- MAGIC - `c35_sales`: `sold_on, item_id, units` (returns are negative).
-- MAGIC
-- MAGIC **Your task:** `month, revenue, unpriced_units`.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. Clean the log before closing versions: same-day changes, then repeats.
-- MAGIC 2. One sale happened before any price existed.
-- MAGIC
-- MAGIC **Check yourself:** 3 months; one has null revenue and 1 unpriced unit.

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the next cell to create this drill's practice tables.

-- COMMAND ----------

-- Setup
create or replace table c35_price_changes as
select * from values
  ('STRAW',3.99,timestamp'2026-01-01 08:00:00'), ('STRAW',4.49,timestamp'2026-02-15 09:00:00'),
  ('STRAW',4.29,timestamp'2026-02-15 17:00:00'), ('STRAW',4.29,timestamp'2026-03-01 08:00:00'),
  ('STRAW',3.79,timestamp'2026-03-10 08:00:00')
as t(item_id, price, change_ts);                 -- effective the same day
create or replace table c35_sales as
select * from values
  (date'2025-12-31','STRAW',1), (date'2026-02-10','STRAW',3), (date'2026-02-15','STRAW',2),
  (date'2026-03-05','STRAW',1), (date'2026-03-12','STRAW',4), (date'2026-03-12','STRAW',-1)
as t(sold_on, item_id, units);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

-- Drill 35 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 35 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.
