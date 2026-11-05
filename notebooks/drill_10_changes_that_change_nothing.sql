-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 10: Changes that change nothing (10 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **Task:** SCD2 with one row per real change.
-- MAGIC
-- MAGIC **Check yourself:** 3 versions.

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the next cell to create this drill's practice tables.

-- COMMAND ----------

-- Setup
create or replace table d10_capacity_changes as
select * from values
  ('STRAW',50,date'2026-01-01'), ('STRAW',50,date'2026-02-01'), ('STRAW',80,date'2026-03-01'),
  ('STRAW',80,date'2026-03-20'), ('STRAW',60,date'2026-04-05')
as t(item_id, capacity, changed_on);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

-- Drill 10 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 10 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.
