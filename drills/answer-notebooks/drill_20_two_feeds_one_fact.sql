-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 20: Two feeds, one fact (12 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **What this tests:** combining two event sources at one grain without multiplying rows (fan-out).
-- MAGIC
-- MAGIC **Scenario:** You're building `fct_store_item_daily` with both units sold and shrink units, from two separate feeds.
-- MAGIC
-- MAGIC **Raw data:**
-- MAGIC - `d20_sales`: one row per sale.
-- MAGIC - `d20_shrink`: one row per shrink log (spoiled, damaged).
-- MAGIC
-- MAGIC **Your task:** one row per store, item and day, with `units_sold` and `shrink_units`.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. Join the raw tables and look at Mar 14's totals. What happened?
-- MAGIC 2. Get each feed to the output grain **before** joining.
-- MAGIC 3. Some days exist in only one feed. Which join keeps both?
-- MAGIC
-- MAGIC **Check yourself:** 3 rows. Mar 14: 6 sold, 3 shrink.

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the next cell to create this drill's practice tables.

-- COMMAND ----------

-- Setup
create or replace table d20_sales as
select * from values
  (date'2026-03-14','A','STRAW',4), (date'2026-03-14','A','STRAW',2), (date'2026-03-15','A','STRAW',3)
as t(sold_on, store_id, item_id, units);
create or replace table d20_shrink as
select * from values
  (date'2026-03-14','A','STRAW',1,'spoiled'), (date'2026-03-14','A','STRAW',2,'damaged'),
  (date'2026-03-16','A','STRAW',5,'spoiled')
as t(logged_on, store_id, item_id, units, reason);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

with daily_sales as (
    select sold_on, store_id, item_id, sum(units) as sold_units
    from d20_sales group by 1,2,3
),
daily_shrink as (
    select logged_on, store_id, item_id, sum(units) as shrink_units
    from d20_shrink group by 1,2,3
)
select
coalesce (k.sold_on, s.logged_on) as cal_date,
coalesce (k.store_id, s.store_id) as store_id,
coalesce (k.item_id, s.item_id) as item_id,
coalesce (k.sold_units, 0) as sold_units,
coalesce (s.shrink_units, 0) as shrink_units
from
daily_sales k full outer join daily_shrink s
on k.sold_on = s.logged_on 
and k.store_id = s.store_id 
and k.item_id = s.item_id;

-- COMMAND ----------

-- Drill 20 answer
select * from d20_sales;

-- COMMAND ----------

select * from d20_shrink;

-- COMMAND ----------

select logged_on, store_id, item_id, reason, count(*)
from d20_shrink
group by all
having count(*) > 1;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 20 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.