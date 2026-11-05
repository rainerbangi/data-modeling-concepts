-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 17: Reloaded rows (8 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **Task:** Units per item per day.

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the next cell to create this drill's practice tables.

-- COMMAND ----------

-- Setup
create or replace table d17_sales as
select * from values
  (1001,timestamp'2026-03-14 10:05:00','STRAW',4,timestamp'2026-03-14 23:00:00'),
  (1002,timestamp'2026-03-14 15:40:00','STRAW',2,timestamp'2026-03-14 23:00:00'),
  (1005,timestamp'2026-03-16 11:00:00','STRAW',3,timestamp'2026-03-16 23:00:00'),
  (1005,timestamp'2026-03-16 11:00:00','STRAW',4,timestamp'2026-03-17 06:00:00'),
  (1006,timestamp'2026-03-16 17:20:00','STRAW',1,timestamp'2026-03-16 23:00:00')
as t(sale_id, sold_at, item_id, units, loaded_at);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

-- Drill 17 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 17 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.
