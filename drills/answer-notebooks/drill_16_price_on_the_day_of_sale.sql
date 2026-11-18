-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 16: Price on the day of sale (8 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **Task:** Revenue per sale at the price in effect that day, using `d07_price_scd2`. Flag sales with no price.

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the next cell to create this drill's practice tables.

-- COMMAND ----------

-- Setup
create or replace table d16_sales as
select * from values
  (1,'STRAW',date'2026-02-10',3), (2,'STRAW',date'2026-02-15',2), (3,'STRAW',date'2026-03-12',4),
  (4,'BLUE', date'2026-03-12',1), (5,'STRAW',date'2025-12-20',1)
as t(sale_id, item_id, sold_on, units);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

-- Drill 16 answer
SELECT * FROM d07_price_scd2;


-- COMMAND ----------

select f.sale_id, f.item_id, f.sold_on, f.units,
       d.price,
       f.units * d.price as revenue,
       d.price is null   as missing_price
from d16_sales f
left join d07_price_scd2 d
  on  f.item_id = d.item_id
  and f.sold_on >= d.valid_from
  and f.sold_on <  d.valid_to
order by f.sale_id desc;

-- COMMAND ----------

select * from d16_sales;

-- COMMAND ----------

-- DBTITLE 1,Solution
-- Solution
select
  f.sale_id,
  f.item_id,
  f.sold_on,
  f.units,
  d.price,
  coalesce(f.units * d.price, 0) as revenue,
  case when d.price is null then 'NO PRICE' else 'OK' end as price_status
from d16_sales f
left join d07_price_scd2 d
       on f.item_id = d.item_id
      and f.sold_on >= d.valid_from   -- valid_from inclusive
      and f.sold_on <  d.valid_to     -- valid_to exclusive
order by f.sale_id;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 16 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.