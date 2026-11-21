-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 21: The daily file (6 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **What this tests:** classifying a table correctly when it looks like something else.
-- MAGIC
-- MAGIC **Scenario:** A vendor sends one row per item per day, with zeros on days with no sales. A colleague calls it "the daily sales snapshot".
-- MAGIC
-- MAGIC **Raw data:** `d21_daily_item_sales`: `item_id, sale_date, units`.
-- MAGIC
-- MAGIC **Your task:** units sold for the week of Mar 9 to 15, and one sentence on why your aggregate is valid.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. Read one row aloud. Did something happen, or is something true?
-- MAGIC 2. Does adding up a week of rows give a real number?
-- MAGIC
-- MAGIC **Check yourself:** you can explain in one sentence why adding these rows is valid.

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the next cell to create this drill's practice tables.

-- COMMAND ----------

-- Setup
create or replace table d21_daily_item_sales as
select * from values
  ('STRAW',date'2026-03-09',3), ('STRAW',date'2026-03-10',0), ('STRAW',date'2026-03-11',5),
  ('STRAW',date'2026-03-12',2), ('STRAW',date'2026-03-13',0), ('STRAW',date'2026-03-14',4),
  ('STRAW',date'2026-03-15',6)
as t(item_id, sale_date, units);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

-- Drill 21 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 21 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.
