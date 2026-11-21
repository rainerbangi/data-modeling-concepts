-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 40: Full mock (45 min, talk out loud, record yourself)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **What this tests:** everything, plus the order of your thinking. Interviewers grade the process as much as the SQL.
-- MAGIC
-- MAGIC **Scenario:** You are the only data modeler at a grocery AI company. Category managers want **days of cover by category for the last 7 complete days, with categories as they were at the time**.
-- MAGIC
-- MAGIC **Raw data:**
-- MAGIC 1. `pos_lines(line_id, basket_id, sold_at, store_id, sku, qty, net_amt, loaded_at)`: lines can be reloaded with corrections.
-- MAGIC 2. `sku_master_daily(sku, sku_name, category, department, as_of_date)`: the full SKU list, sent every night.
-- MAGIC 3. `planogram_changes(store_id, sku, capacity_units, effective_date, entered_at)`: entered whenever a shelf is reset, sometimes backdated.
-- MAGIC
-- MAGIC **Your task, in this order:**
-- MAGIC 1. The questions you would ask before building.
-- MAGIC 2. Each source's shape, read aloud.
-- MAGIC 3. The model: facts, dimensions and each one's grain.
-- MAGIC 4. The core SQL.
-- MAGIC 5. Five edge cases.
-- MAGIC 6. Three tests.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. Each source matches a drill you've done. Name it.
-- MAGIC 2. "As they were at the time" tells you how to join category.
-- MAGIC 3. Capacity is semi-additive; check how you average.
-- MAGIC
-- MAGIC **Check yourself:** compare with the outline in `answer_key.md`.

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

-- Drill 40 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 40 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.
