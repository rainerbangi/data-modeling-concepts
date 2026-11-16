-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 8: Shelf capacity to daily rows (10 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **Task:** Capacity for every store, item and day from 2026-03-13 to 2026-03-17.
-- MAGIC
-- MAGIC **Check yourself:** 7 rows. Mar 15 for store A appears once.

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the next cell to create this drill's practice tables.

-- COMMAND ----------

-- Setup
create or replace table d08_capacity_changes as
select * from values
  ('A','STRAW',50,date'2026-01-01'), ('A','STRAW',80,date'2026-03-15'),
  ('B','STRAW',60,date'2026-03-16')
as t(store_id, item_id, capacity, changed_on);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

with change_log_scd2 as (SELECT
    store_id,
    item_id,
    capacity,
    changed_on AS valid_from,
    LEAD(changed_on, 1, DATE '9999-12-31') OVER (PARTITION BY store_id,item_id ORDER BY changed_on) AS valid_to
 FROM d08_capacity_changes)
SELECT 
    store_id,
    item_id,
    capacity,
    valid_from,
    valid_to,
    d.calendar_date
FROM d01_dim_date d
JOIN change_log_scd2 c
ON d.calendar_date >= c.valid_from AND d.calendar_date < c.valid_to 
WHERE d.calendar_date BETWEEN DATE '2026-03-13' AND DATE '2026-03-17'
ORDER BY store_id, calendar_date;

-- COMMAND ----------

-- Setup
create or replace table d08_capacity_changes as
select * from values
  ('A','STRAW',50,date'2026-01-01', timestamp'2026-01-01 06:00:00'),
  ('A','STRAW',70,date'2026-03-15', timestamp'2026-03-15 06:00:00'),  -- first load that day
  ('A','STRAW',80,date'2026-03-15', timestamp'2026-03-15 14:30:00'),  -- correction, same day, loaded later
  ('B','STRAW',60,date'2026-03-16', timestamp'2026-03-16 06:00:00')
as t(store_id, item_id, capacity, changed_on, _loaded_at);

-- COMMAND ----------

SELECT * FROM d08_capacity_changes;

-- COMMAND ----------

-- fct_capacity_daily
-- Grain:   one row per (store_id, item_id, calendar_date)
-- Range:   2026-03-13 to 2026-03-17
-- Missing: store/items with no capacity yet appear with capacity = NULL (full grid)
-- Ties:    two changes on the same day → the latest _loaded_at wins

CREATE OR REPLACE TABLE fct_capacity_daily_08 AS

WITH changes_deduped AS (
  SELECT store_id, item_id, capacity, changed_on
  FROM (
    SELECT *,
           ROW_NUMBER() OVER (
             PARTITION BY store_id, item_id, changed_on
             ORDER BY _loaded_at DESC
           ) AS rn
    FROM d08_capacity_changes
  )
  WHERE rn = 1
),

capacity_scd2 AS (
  SELECT store_id, item_id, capacity,
         changed_on AS valid_from,
         LEAD(changed_on, 1, DATE '9999-12-31')
           OVER (PARTITION BY store_id, item_id ORDER BY changed_on) AS valid_to
  FROM changes_deduped
),

date_spine AS (
  SELECT DISTINCT calendar_date
  FROM d01_dim_date
  WHERE calendar_date BETWEEN DATE '2026-03-13' AND DATE '2026-03-17'
),

store_items AS (
  SELECT DISTINCT store_id, item_id
  FROM changes_deduped
)

SELECT
  si.store_id,
  si.item_id,
  d.calendar_date,
  c.capacity
FROM date_spine d
CROSS JOIN store_items si
LEFT JOIN capacity_scd2 c
  ON 
 c.store_id = si.store_id
  AND c.item_id  = si.item_id
 AND  d.calendar_date >= c.valid_from
  AND d.calendar_date <  c.valid_to;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 8 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.