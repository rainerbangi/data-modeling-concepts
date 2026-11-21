-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 33: The Afresh problem (30 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **What this tests:** the whole pipeline end to end: change log → SCD2 → daily, deduped sales, full outer join, and a semi-additive metric. Combines drills 11, 8, 17, 20 and 23.
-- MAGIC
-- MAGIC **Scenario:** Category managers want **days of cover** per store: how many days of sales the shelf can hold. You must build the daily fact first, then the metric.
-- MAGIC
-- MAGIC **Raw data:**
-- MAGIC - `c33_capacity_changes`: same table and rules as drill 11 (next-day effect, start date, several saves a day, repeated saves).
-- MAGIC - `c33_sales`: one row per sale; corrected sales are re-sent with a newer `loaded_at`; returns have negative units.
-- MAGIC
-- MAGIC **Your task:**
-- MAGIC 1. Build `c33_fct_store_item_daily (calendar_date, store_id, item_id, units_sold, capacity_units)`.
-- MAGIC 2. Days of cover per store for Mar 14 to 16 = average daily capacity ÷ average daily units sold, using only days where capacity is known.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. Draw the boxes first: capacity side, sales side, then the join.
-- MAGIC 2. A sale before capacity exists: is its capacity 0 or unknown?
-- MAGIC 3. Capacity adds across items on a day but not across days.
-- MAGIC
-- MAGIC **Check yourself:** both stores come out at 15.0 days of cover.

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the next cell to create this drill's practice tables.

-- COMMAND ----------

-- Setup
-- Needs drill 11 setup to have run first
create or replace table c33_capacity_changes as select * from d11_capacity_changes;
create or replace table c33_sales as
select * from values
  (1001,timestamp'2026-03-14 10:05:00','A','STRAW', 4,timestamp'2026-03-14 23:00:00'),
  (1002,timestamp'2026-03-14 15:40:00','A','STRAW', 2,timestamp'2026-03-14 23:00:00'),
  (1003,timestamp'2026-03-16 09:12:00','A','STRAW', 9,timestamp'2026-03-16 23:00:00'),
  (1004,timestamp'2026-03-15 13:30:00','B','STRAW', 2,timestamp'2026-03-15 23:00:00'),
  (1005,timestamp'2026-03-16 11:00:00','B','STRAW', 3,timestamp'2026-03-16 23:00:00'),
  (1005,timestamp'2026-03-16 11:00:00','B','STRAW', 4,timestamp'2026-03-17 06:00:00'),
  (1006,timestamp'2026-03-16 17:20:00','A','STRAW',-1,timestamp'2026-03-16 23:00:00')
as t(sale_id, sold_at, store_id, item_id, units, loaded_at);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

-- Drill 33 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 33 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.
