-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 11: Next-day effect and a start date (15 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **Rule:** a change takes effect the day after `change_timestamp`, but never before `start_date`.
-- MAGIC
-- MAGIC **Task:** SCD2.
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
