-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 28: On promo, no sales (10 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **Task:** Build one row per store, item and day on promo, then list promo days with zero sales.

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the next cell to create this drill's practice tables.

-- COMMAND ----------

-- Setup
create or replace table d28_promos as
select * from values ('P1','A','STRAW',date'2026-03-01',date'2026-03-04')
as t(promo_id, store_id, item_id, start_date, end_date);       -- end_date is INCLUSIVE
create or replace table d28_daily_sales as
select * from values (date'2026-03-01','A','STRAW',5), (date'2026-03-03','A','STRAW',2)
as t(calendar_date, store_id, item_id, units);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

-- Drill 28 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 28 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.
