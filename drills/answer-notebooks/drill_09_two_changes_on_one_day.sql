-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 9: Two changes on one day (10 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **What this tests:** deduplicating a change log to the grain of the history (the day).
-- MAGIC
-- MAGIC **Scenario:** A manager set capacity to 70 in the morning and corrected it to 80 the same afternoon. Reports work at day level.
-- MAGIC
-- MAGIC **Raw data:** `d09_capacity_changes`, one row per save, with a timestamp `change_ts`. A change is effective on the day it was made.
-- MAGIC
-- MAGIC **Your task:** SCD2 by day: `store_id, item_id, capacity, valid_from, valid_to`.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. Build SCD2 straight from these rows and look at the 70 version's dates. What's wrong?
-- MAGIC 2. Pick one row per store, item and **day**. Which one should win?
-- MAGIC 3. "Latest row per group" has a standard window function.
-- MAGIC
-- MAGIC **Check yourself:** 2 versions; none starts and ends on the same day.

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the next cell to create this drill's practice tables.

-- COMMAND ----------

-- Setup
create or replace table d09_capacity_changes as
select * from values
  ('A','STRAW',50,timestamp'2026-01-01 08:00:00'),
  ('A','STRAW',70,timestamp'2026-03-14 09:00:00'),
  ('A','STRAW',80,timestamp'2026-03-14 16:00:00')
as t(store_id, item_id, capacity, change_ts);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

with last_change_per_day as (                         -- step 1: one value per day
  select store_id, item_id, capacity, change_day
  from (
    select store_id, item_id, capacity,
           date(change_ts) as change_day,
           row_number() over (
             partition by store_id, item_id, date(change_ts)
             order by change_ts desc,                 -- latest change wins…
                      capacity desc                   -- …edge case 1: a fixed tie-breaker
           ) as rn
    from d09_capacity_changes
  ) t
  where rn = 1
),
real_changes as (                                     -- step 2: edge case 2, drop no-change days
  select store_id, item_id, capacity, change_day
  from (
    select *,
           lag(capacity) over (partition by store_id, item_id order by change_day) as prev_capacity
    from last_change_per_day
  ) t
  where capacity is distinct from prev_capacity       -- the first row (prev = NULL) is kept
)
select                                                -- step 3: build the versions
  xxhash64(store_id, item_id, change_day) as capacity_version_key,
  store_id, item_id, capacity,
  change_day as valid_from,
  lead(change_day, 1, date '9999-12-31')
    over (partition by store_id, item_id order by change_day) as valid_to,
  lead(change_day)
    over (partition by store_id, item_id order by change_day) is null as is_current
from real_changes;

-- COMMAND ----------



-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 9 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.