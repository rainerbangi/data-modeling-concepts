-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 39: Before vs after go-live (20 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **Task:** Shrink rate for the 2 weeks before vs the 2 weeks starting at go-live, per store, and the change in points. Only include stores with all 4 weeks.

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the next cell to create this drill's practice tables.

-- COMMAND ----------

-- Setup
create or replace table c39_stores as
select * from values ('A',date'2026-03-08'), ('B',date'2026-03-15') as t(store_id, go_live_date);
create or replace table c39_weekly as
select * from values
  ('A',date'2026-02-22',60.0,1000.0), ('A',date'2026-03-01',80.0,1000.0),
  ('A',date'2026-03-08',50.0,1000.0), ('A',date'2026-03-15',40.0,1000.0),
  ('B',date'2026-03-01',70.0,1000.0), ('B',date'2026-03-08',65.0,1000.0),
  ('B',date'2026-03-15',55.0,1000.0)
as t(store_id, week_start, shrink_amt, sales_amt);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

-- Drill 39 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 39 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.
