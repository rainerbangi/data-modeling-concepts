-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 17: Reloaded rows (8 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **What this tests:** keeping the latest row per key, the most common SQL screen question.
-- MAGIC
-- MAGIC **Scenario:** The POS vendor re-sends a sale when it's corrected. Each copy has the same `sale_id` and a newer `loaded_at`. The sales report should count each sale once, using its latest version.
-- MAGIC
-- MAGIC **Raw data:** `d17_sales`: `sale_id, sold_at, item_id, units, loaded_at`.
-- MAGIC
-- MAGIC **Your task:** units per item per day: `sale_date, item_id, units`.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. Find the sale that appears more than once. Which copy is right?
-- MAGIC 2. Rank copies within each `sale_id`, newest first.
-- MAGIC
-- MAGIC **Check yourself:** each `sale_id` is counted once.

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the next cell to create this drill's practice tables.

-- COMMAND ----------

-- Setup
create or replace table d17_sales as
select * from values
  (1001,timestamp'2026-03-14 10:05:00','STRAW',4,timestamp'2026-03-14 23:00:00'),
  (1002,timestamp'2026-03-14 15:40:00','STRAW',2,timestamp'2026-03-14 23:00:00'),
  (1005,timestamp'2026-03-16 11:00:00','STRAW',3,timestamp'2026-03-16 23:00:00'),
  (1005,timestamp'2026-03-16 11:00:00','STRAW',4,timestamp'2026-03-17 06:00:00'),
  (1006,timestamp'2026-03-16 17:20:00','STRAW',1,timestamp'2026-03-16 23:00:00')
as t(sale_id, sold_at, item_id, units, loaded_at);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

-- Drill 17 answer

SELECT * FROM d17_sales;

-- COMMAND ----------

DESCRIBE d17_sales;

with cte_dedup as (select
    sale_id, item_id, sold_at, units, loaded_at
from d17_sales
qualify row_number() over (partition by sale_id order by loaded_at desc) = 1 )
select 
    item_id,
    date(sold_at) as sale_date,
    sum(units) as daily_units
from cte_dedup
group by all
order by sale_date desc ;

-- COMMAND ----------

--Soln ensuring sold_at always in NYC time
with cte_dedup as (
  select sale_id, item_id, sold_at, units, loaded_at
  from d17_sales
  qualify row_number() over (partition by sale_id order by loaded_at desc) = 1
)
select item_id,
       date(from_utc_timestamp(sold_at, 'America/New_York')) as sale_date,
       sum(units) as daily_units
from cte_dedup
group by all
order by sale_date desc;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 17 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.