-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 32: Write the tests (10 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **What this tests:** data tests that pass with zero rows, the way dbt tests work.
-- MAGIC
-- MAGIC **Scenario:** Before shipping a model, you add automated checks. A check must **return rows only when something is wrong**.
-- MAGIC
-- MAGIC **Raw data:**
-- MAGIC - `d32_source_sales`: the source.
-- MAGIC - `d32_fct`: the fact (one row per day, store, item, or so it claims).
-- MAGIC - `d32_dim_item`: an SCD2 dimension.
-- MAGIC
-- MAGIC **Your task:** three tests: (1) the fact's grain is unique, (2) no two SCD2 versions of an item overlap, (3) fact total equals source total. All three should fail on this data.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. A duplicate grain is a group with more than one row.
-- MAGIC 2. Two ranges overlap when each starts before the other ends.
-- MAGIC 3. Compare two single-row totals; return a row only if they differ.
-- MAGIC
-- MAGIC **Check yourself:** each test returns at least one row on this data.

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the next cell to create this drill's practice tables.

-- COMMAND ----------

-- Setup
create or replace table d32_source_sales as
select * from values (1,date'2026-03-14','A','STRAW',4), (2,date'2026-03-14','A','STRAW',2)
as t(sale_id, calendar_date, store_id, item_id, units);
create or replace table d32_fct as
select * from values (date'2026-03-14','A','STRAW',6), (date'2026-03-14','A','STRAW',6)
as t(calendar_date, store_id, item_id, units);
create or replace table d32_dim_item as
select * from values
  (11,'STRAW','Berries',      date'2026-01-01',date'2026-03-10'),
  (12,'STRAW','Fresh Berries',date'2026-03-01',date'9999-12-31')
as t(item_key, item_id, category, valid_from, valid_to);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

-- Drill 32 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 32 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.
