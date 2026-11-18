-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 14: Database change feed (15 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **Task:** SCD2 of item category by day. `op` is insert, update or delete.

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the next cell to create this drill's practice tables.

-- COMMAND ----------

-- Setup
create or replace table d14_item_cdc as
select * from values
  ('I','STRAW','Berries',      timestamp'2026-01-01 09:00:00'),
  ('U','STRAW','Fresh Berries',timestamp'2026-03-02 10:00:00'),
  ('U','STRAW','Fresh Berries',timestamp'2026-03-02 10:00:00'),
  ('I','KIWI','Tropical',      timestamp'2026-02-01 09:00:00'),
  ('U','KIWI','Tropical',      timestamp'2026-02-10 09:00:00'),
  ('D','KIWI',cast(null as string), timestamp'2026-04-01 09:00:00')
as t(op, item_id, category, commit_ts);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

-- Drill 14 answer

select *,  date_format(commit_ts, 'yyyy-MM-dd HH:mm') from d14_item_cdc
order by item_id, commit_ts;


-- COMMAND ----------

with last_per_day as (
  select op, item_id, category, date(commit_ts) as change_day
  from d14_item_cdc
  qualify row_number() over (
            partition by item_id, date(commit_ts)
            order by commit_ts desc) = 1
),
real_changes as (
  select *
  from last_per_day
  qualify category is distinct from
          lag(category) over (partition by item_id order by change_day)
)
,
timeline as (
  select item_id, op, category,
         change_day as valid_from,
         lead(change_day, 1, date '9999-12-31')
           over (partition by item_id order by change_day) as valid_to
  from real_changes
)
select item_id, category, valid_from, valid_to,
       valid_to = date '9999-12-31' as is_current
from timeline
where op <> 'D'
order by item_id, valid_from;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 14 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.