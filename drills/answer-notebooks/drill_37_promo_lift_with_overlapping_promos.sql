-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 37: Promo lift with overlapping promos (20 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **What this tests:** comparing averages fairly: count each day once, and include days with no sales.
-- MAGIC
-- MAGIC **Scenario:** Marketing asks whether strawberries sell more per day on promo than off promo, for Mar 1 to 10. Two promos overlap.
-- MAGIC
-- MAGIC **Raw data:**
-- MAGIC - `c37_promos`: promo date ranges (**end date inclusive**).
-- MAGIC - `c37_sales`: `sale_date, item_id, units` (days with no sales have no row).
-- MAGIC
-- MAGIC **Your task:** average daily units on promo days vs non-promo days.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. A day covered by two promos is still one day.
-- MAGIC 2. Days with no sales must count, as zero.
-- MAGIC 3. Start from a list of every day, not from the sales table.
-- MAGIC
-- MAGIC **Check yourself:** on-promo days plus off-promo days equal 10.

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the next cell to create this drill's practice tables.

-- COMMAND ----------

-- Setup
create or replace table c37_promos as
select * from values ('P1','STRAW',date'2026-03-01',date'2026-03-05'), ('P2','STRAW',date'2026-03-04',date'2026-03-08')
as t(promo_id, item_id, start_date, end_date);   -- end_date is INCLUSIVE
create or replace table c37_sales as
select * from values
  (date'2026-03-01','STRAW',2), (date'2026-03-03','STRAW',3), (date'2026-03-04','STRAW',5),
  (date'2026-03-06','STRAW',4), (date'2026-03-09','STRAW',1), (date'2026-03-10','STRAW',2)
as t(sale_date, item_id, units);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

-- Drill 37 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 37 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.
