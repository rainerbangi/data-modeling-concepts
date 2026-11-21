-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 19: A corrected file arrives (8 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **What this tests:** idempotent loads: rerunning a load must not change the result.
-- MAGIC
-- MAGIC **Scenario:** The vendor resends Mar 14 with corrected numbers and a new item. Your nightly job may also be rerun by mistake.
-- MAGIC
-- MAGIC **Raw data:**
-- MAGIC - `d19_fct_sales_daily`: your fact table, one row per day and item.
-- MAGIC - `d19_file_0314`: the corrected file for Mar 14.
-- MAGIC
-- MAGIC **Your task:** load the corrected Mar 14 file. Running your statement twice must give the same result.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. What happens to Mar 14 if you just insert the file?
-- MAGIC 2. Think "replace this date's data", not "add rows".
-- MAGIC 3. Databricks can delete and insert for a date range in one atomic statement.
-- MAGIC
-- MAGIC **Check yourself:** running your load twice leaves the table identical.

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the next cell to create this drill's practice tables.

-- COMMAND ----------

-- Setup
create or replace table d19_fct_sales_daily as
select * from values (date'2026-03-13','STRAW',4), (date'2026-03-14','STRAW',6)
as t(sale_date, item_id, units);
create or replace table d19_file_0314 as
select * from values (date'2026-03-14','STRAW',7), (date'2026-03-14','BLUE',2)
as t(sale_date, item_id, units);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

-- Drill 19 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 19 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.
