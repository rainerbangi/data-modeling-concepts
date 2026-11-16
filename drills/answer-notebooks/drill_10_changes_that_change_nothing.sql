-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 10: Changes that change nothing (10 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **Task:** SCD2 with one row per real change.
-- MAGIC
-- MAGIC **Check yourself:** 3 versions.

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the next cell to create this drill's practice tables.

-- COMMAND ----------

-- Setup
create or replace table d10_capacity_changes as
select * from values
  ('STRAW',50,date'2026-01-01'), ('STRAW',50,date'2026-02-01'), ('STRAW',80,date'2026-03-01'),
  ('STRAW',80,date'2026-03-20'), ('STRAW',60,date'2026-04-05')
as t(item_id, capacity, changed_on);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

-- Drill 10 answer
SELECT * FROM d10_capacity_changes;

-- COMMAND ----------

-- DBTITLE 1,Cell 7
with deduped as (SELECT 
    item_id,
    capacity,
    changed_on
FROM
(SELECT
    *,
    LAG(capacity) OVER (PARTITION BY item_id ORDER BY changed_on) as prev_capacity
FROM d10_capacity_changes) t
WHERE prev_capacity IS DISTINCT FROM capacity),
scd2 as (
SELECT 
    item_id,
    capacity,
    changed_on as valid_from,
    LEAD (changed_on, 1 , date '9999-12-31') OVER (PARTITION BY item_id ORDER BY changed_on) as valid_to,
    CASE WHEN LEAD (changed_on) OVER (PARTITION BY item_id ORDER BY changed_on) is null then true else false end as active
 FROM deduped)
 SELECT * FROM scd2
where date '2026-03-15'>= valid_from 
and date '2026-03-15'< valid_to;


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 10 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.