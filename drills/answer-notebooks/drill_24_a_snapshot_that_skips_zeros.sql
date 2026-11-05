-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 24: A snapshot that skips zeros (12 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **Rule:** the file lists only items with stock above zero.
-- MAGIC
-- MAGIC **Task:** On-hand for STRAW and BLUE on every day from Mar 9 to 12.

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the next cell to create this drill's practice tables.

-- COMMAND ----------

-- Setup
create or replace table d24_counts as
select * from values
  (date'2026-03-09','STRAW',5), (date'2026-03-09','BLUE',2), (date'2026-03-10','STRAW',3),
  (date'2026-03-12','BLUE',4)
as t(count_date, item_id, on_hand);
create or replace table d24_file_log as
select * from values
  (date'2026-03-09',true), (date'2026-03-10',true), (date'2026-03-11',false), (date'2026-03-12',true)
as t(file_date, arrived);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

-- Drill 24 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 24 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.
