-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 22: Counting customers (10 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **What this tests:** non-additive measures (distinct counts), the "daily vs weekly active users" trap.
-- MAGIC
-- MAGIC **Scenario:** Marketing wants a daily table with units and the number of customers, and then the number of customers for the week.
-- MAGIC
-- MAGIC **Raw data:** `d22_lines`: one row per basket line, with `customer_id, sold_on, item_id, units`.
-- MAGIC
-- MAGIC **Your task:**
-- MAGIC 1. A daily result with units and distinct customers.
-- MAGIC 2. Distinct customers for the week of Mar 9 to 15.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. Add up your daily customer counts. Is that the weekly answer?
-- MAGIC 2. Look for a customer who shopped on more than one day.
-- MAGIC
-- MAGIC **Check yourself:** daily customers add up to 3; the weekly answer is not 3.

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the next cell to create this drill's practice tables.

-- COMMAND ----------

-- Setup
create or replace table d22_lines as
select * from values
  ('C1',date'2026-03-14','STRAW',2), ('C1',date'2026-03-14','BLUE',1),
  ('C2',date'2026-03-14','STRAW',1), ('C1',date'2026-03-15','STRAW',3)
as t(customer_id, sold_on, item_id, units);

-- COMMAND ----------

select * from d22_lines;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

-- Drill 22 answer
select sold_on, sum(units) as units, count(distinct customer_id) as customers
from d22_lines
group by sold_on;

select count(distinct customer_id) as customers_week
from d22_lines
where sold_on between date'2026-03-09' and date'2026-03-15';




-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 22 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.