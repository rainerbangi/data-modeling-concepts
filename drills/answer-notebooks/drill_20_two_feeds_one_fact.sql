-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 20: Two feeds, one fact (12 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **Task:** One row per store, item and day with `units_sold` and `shrink_units`.

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the next cell to create this drill's practice tables.

-- COMMAND ----------

-- Setup
create or replace table d20_sales as
select * from values
  (date'2026-03-14','A','STRAW',4), (date'2026-03-14','A','STRAW',2), (date'2026-03-15','A','STRAW',3)
as t(sold_on, store_id, item_id, units);
create or replace table d20_shrink as
select * from values
  (date'2026-03-14','A','STRAW',1,'spoiled'), (date'2026-03-14','A','STRAW',2,'damaged'),
  (date'2026-03-16','A','STRAW',5,'spoiled')
as t(logged_on, store_id, item_id, units, reason);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

-- Drill 20 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 20 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.
