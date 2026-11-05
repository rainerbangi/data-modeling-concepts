-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 12: Backdated corrections (12 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **Task:** SCD2. What was the capacity on Mar 15? On Mar 16?

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the next cell to create this drill's practice tables.

-- COMMAND ----------

-- Setup
create or replace table d12_capacity_changes as
select * from values
  ('A','STRAW',50,date'2026-01-01',timestamp'2025-12-30 10:00:00'),
  ('A','STRAW',80,date'2026-03-16',timestamp'2026-03-15 12:00:00'),
  ('A','STRAW',70,date'2026-03-15',timestamp'2026-03-20 09:00:00'),
  ('A','STRAW',75,date'2026-03-16',timestamp'2026-03-21 08:00:00')
as t(store_id, item_id, capacity, effective_date, entered_at);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

-- Drill 12 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 12 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.
