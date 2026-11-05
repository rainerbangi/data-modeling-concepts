-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 8: Shelf capacity to daily rows (10 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **Task:** Capacity for every store, item and day from 2026-03-13 to 2026-03-17.
-- MAGIC
-- MAGIC **Check yourself:** 7 rows. Mar 15 for store A appears once.

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the next cell to create this drill's practice tables.

-- COMMAND ----------

-- Setup
create or replace table d08_capacity_changes as
select * from values
  ('A','STRAW',50,date'2026-01-01'), ('A','STRAW',80,date'2026-03-15'),
  ('B','STRAW',60,date'2026-03-16')
as t(store_id, item_id, capacity, changed_on);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

-- Drill 8 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 8 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.
