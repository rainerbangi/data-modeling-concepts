-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 13: Discontinued items (10 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **What this tests:** end events in a change log, and when a `WHERE` clause runs relative to window functions.
-- MAGIC
-- MAGIC **Scenario:** When an item is discontinued, the log records a "discontinue" event. Reports must not show capacity for it after that date.
-- MAGIC
-- MAGIC **Raw data:** `d13_capacity_events`: `item_id, action ('set' or 'discontinue'), capacity, effective_date`.
-- MAGIC
-- MAGIC **Your task:** SCD2 of capacity. No version may exist on or after the discontinue date.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. Is a discontinue row a version, or the end of one?
-- MAGIC 2. If you filter out discontinue rows first, what does `LEAD` see for the last real version?
-- MAGIC
-- MAGIC **Check yourself:** no version covers the discontinue date or anything after it.

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the next cell to create this drill's practice tables.

-- COMMAND ----------

-- Setup
create or replace table d13_capacity_events as
select * from values
  ('STRAW','set',50,date'2026-01-01'), ('STRAW','set',80,date'2026-03-15'),
  ('STRAW','discontinue',cast(null as int),date'2026-04-01')
as t(item_id, action, capacity, effective_date);


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

-- Drill 13 answer
with timeline as (
  select item_id, action, capacity,
         effective_date as valid_from,
         lead(effective_date, 1, date '9999-12-31')
           over (partition by item_id order by effective_date) as valid_to
  from d13_capacity_events
)
select item_id, capacity, valid_from, valid_to,
       valid_to = date '9999-12-31' as is_current, null is distinct from null as test_scalar_op, 'r'='r' as test_scalar_op2
from timeline
where action = 'set'
order by item_id, valid_from;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 13 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.