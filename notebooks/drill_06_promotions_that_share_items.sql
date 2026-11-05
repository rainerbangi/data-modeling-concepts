-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 6: Promotions that share items (12 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **Task:** (a) Units sold under each promo. (b) Total units sold while the item was on any promo.
-- MAGIC
-- MAGIC **Check yourself:** (b) is 19.

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the next cell to create this drill's practice tables.

-- COMMAND ----------

-- Setup
create or replace table d06_promos as
select * from values ('P1', date'2026-03-01', date'2026-03-07'), ('P2', date'2026-03-05', date'2026-03-10')
as t(promo_id, start_date, end_date);          -- end_date is INCLUSIVE
create or replace table d06_promo_items as
select * from values ('P1','STRAW'), ('P1','BLUE'), ('P2','STRAW') as t(promo_id, item_id);
create or replace table d06_sales as
select * from values
  (date'2026-03-06','STRAW',10), (date'2026-03-06','BLUE',4),
  (date'2026-03-09','STRAW',5),  (date'2026-03-12','STRAW',7)
as t(sale_date, item_id, units);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

-- Drill 6 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 6 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.
