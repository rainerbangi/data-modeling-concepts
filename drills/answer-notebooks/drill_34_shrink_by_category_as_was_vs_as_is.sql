-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 34: Shrink by category, as-was vs as-is (20 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **What this tests:** SCD2 joined to a fact, two ways, and knowing which one the business means.
-- MAGIC
-- MAGIC **Scenario:** Strawberries moved from "Berries" to "Fresh Berries" on Mar 10. The Berries manager asks why their March shrink looks low; the Fresh Berries manager asks why theirs looks high.
-- MAGIC
-- MAGIC **Raw data:**
-- MAGIC - `c34_category_changes`: `item_id, category, effective_date`.
-- MAGIC - `c34_shrink`: `shrink_date, item_id, shrink_amt`.
-- MAGIC
-- MAGIC **Your task:** March shrink by category two ways: **as-was** (category at the time) and **as-is** (today's category).
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. Build category history first (drill 7).
-- MAGIC 2. As-was: join on the date. As-is: join to the current version only.
-- MAGIC 3. Which view should each manager use, and why?
-- MAGIC
-- MAGIC **Check yourself:** both views have the same total.

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the next cell to create this drill's practice tables.

-- COMMAND ----------

-- Setup
create or replace table c34_category_changes as
select * from values
  ('STRAW','Berries',date'2026-01-01'), ('STRAW','Fresh Berries',date'2026-03-10'),
  ('BLUE','Berries',date'2026-01-01')
as t(item_id, category, effective_date);
create or replace table c34_shrink as
select * from values
  (date'2026-03-05','STRAW',10.0), (date'2026-03-12','STRAW',6.0), (date'2026-03-12','BLUE',4.0)
as t(shrink_date, item_id, shrink_amt);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

-- Drill 34 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 34 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.
