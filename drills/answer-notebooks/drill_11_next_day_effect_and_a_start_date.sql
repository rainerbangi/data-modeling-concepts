-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 11: Next-day effect and a start date (15 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **What this tests:** applying business rules to a change log before the standard SCD2 steps; combines drills 9 and 10.
-- MAGIC
-- MAGIC **Scenario:** Store managers reset shelves after closing and save the new capacity in a back-office tool. The forecasting team needs capacity for any store, item and date.
-- MAGIC
-- MAGIC **Raw data:** `d11_capacity_changes`, one row each time a manager saves a capacity.
-- MAGIC
-- MAGIC | Column | Meaning |
-- MAGIC |---|---|
-- MAGIC | store_id, item_id | the store and item |
-- MAGIC | capacity | units the shelf holds after the reset |
-- MAGIC | start_date | the date the item starts selling in that store |
-- MAGIC | change_timestamp | when the manager clicked save |
-- MAGIC
-- MAGIC **What the store ops team tells you if you ask:**
-- MAGIC - A change takes effect the **next morning**.
-- MAGIC - No capacity applies before the item's start date.
-- MAGIC - Managers sometimes save several times in a day; the last save counts.
-- MAGIC - The tool logs a save even if the value didn't change.
-- MAGIC
-- MAGIC **Your task:** SCD2: `store_id, item_id, capacity, valid_from, valid_to`.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. Work out each row's **effective date** first, applying both date rules.
-- MAGIC 2. Then it's the drill 9 and 10 steps, on the effective date.
-- MAGIC 3. Two different saves can land on the same effective date. Check store A.
-- MAGIC
-- MAGIC **Check yourself:** 3 versions in total.

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the next cell to create this drill's practice tables.

-- COMMAND ----------

-- Setup
create or replace table d11_capacity_changes as
select * from values
  ('A','STRAW',50,date'2026-01-01',timestamp'2025-12-30 09:00:00'),
  ('A','STRAW',70,date'2026-01-01',timestamp'2026-03-14 09:00:00'),
  ('A','STRAW',80,date'2026-01-01',timestamp'2026-03-14 16:00:00'),
  ('A','STRAW',80,date'2026-01-01',timestamp'2026-04-02 10:00:00'),
  ('B','STRAW',60,date'2026-03-16',timestamp'2026-03-10 11:00:00')
as t(store_id, item_id, capacity, start_date, change_timestamp);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

-- Drill 11 answer
with effective as (
  select store_id, item_id, capacity, change_timestamp,
         greatest(date_add(date(change_timestamp), 1), start_date) as eff_date
  from d11_capacity_changes
),
last_per_day as (
  select *
  from effective
  qualify row_number() over (
            partition by store_id, item_id, eff_date
            order by change_timestamp desc) = 1
),
real_changes as (
  select *
  from last_per_day
  qualify capacity is distinct from
          lag(capacity) over (partition by store_id, item_id order by eff_date)
)
select store_id, item_id, capacity,
       eff_date as valid_from,
       lead(eff_date, 1, date '9999-12-31')
         over (partition by store_id, item_id order by eff_date) as valid_to,
       lead(eff_date) over (partition by store_id, item_id order by eff_date) is null as is_current
from real_changes
order by store_id, item_id, valid_from;

-- COMMAND ----------



-- COMMAND ----------

SELECT greatest(date_add(timestamp '2027-05-24 00:00:00',2),current_date());

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 11 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.