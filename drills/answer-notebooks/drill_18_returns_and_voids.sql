-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 18: Returns and voids (10 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **Rule:** a void cancels the referenced sale completely. A return is a new event on its own date.
-- MAGIC
-- MAGIC **Task:** Net units per day.

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the next cell to create this drill's practice tables.

-- COMMAND ----------

-- Setup
create or replace table d18_txns as
select * from values
  (1,'sale',  cast(null as int),date'2026-03-14','STRAW',5),
  (2,'sale',  cast(null as int),date'2026-03-14','STRAW',3),
  (3,'void',  2,                date'2026-03-14','STRAW',cast(null as int)),
  (4,'return',1,                date'2026-03-15','STRAW',-1),
  (5,'sale',  cast(null as int),date'2026-03-15','STRAW',2)
as t(txn_id, txn_type, ref_txn_id, sold_on, item_id, units);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

-- Drill 18 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 18 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.
