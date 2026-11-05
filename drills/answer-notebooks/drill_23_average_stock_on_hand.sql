-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 23: Average stock on hand (8 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **Task:** Average daily on-hand units for store A over Mar 9 to 11.

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the next cell to create this drill's practice tables.

-- COMMAND ----------

-- Setup
create or replace table d23_counts as
select * from values
  (date'2026-03-09','A','STRAW',40), (date'2026-03-10','A','STRAW',40), (date'2026-03-11','A','STRAW',37),
  (date'2026-03-09','A','BLUE',10),  (date'2026-03-10','A','BLUE',12),  (date'2026-03-11','A','BLUE',8)
as t(count_date, store_id, item_id, on_hand);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

-- Drill 23 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 23 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.
