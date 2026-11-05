-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 34: Shrink by category, as-was vs as-is (20 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **Task:** March shrink by category two ways: as-was (category at the time) and as-is (today's category).

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the next cell to create this drill's practice tables.

-- COMMAND ----------

-- Setup
create or replace table c34_category_changes as
select * from values
  ('STRAW','Berries',date'2026-01-01'), ('STRAW','Fresh Berries',date'2026-03-10'),
  ('BLUE','Berries',date'2026-01-01')
as t(item_id, category, effective_date);
create or replace table c34_shrink as
select * from values
  (date'2026-03-05','STRAW',10.0), (date'2026-03-12','STRAW',6.0), (date'2026-03-12','BLUE',4.0)
as t(shrink_date, item_id, shrink_amt);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

-- Drill 34 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 34 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.
