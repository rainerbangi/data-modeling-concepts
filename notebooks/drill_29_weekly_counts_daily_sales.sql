-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 29: Weekly counts, daily sales (10 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **Task:** Weekly sell-through = units sold in the week / on-hand at the week's open.

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the next cell to create this drill's practice tables.

-- COMMAND ----------

-- Setup
create or replace table d29_weekly_counts as
select * from values (date'2026-03-01','STRAW',40), (date'2026-03-08','STRAW',35)
as t(week_start, item_id, on_hand_at_open);
create or replace table d29_daily_sales as
select * from values
  (date'2026-03-02','STRAW',10), (date'2026-03-05','STRAW',6),
  (date'2026-03-09','STRAW',12), (date'2026-03-13','STRAW',8)
as t(sale_date, item_id, units);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

-- Drill 29 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 29 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.
