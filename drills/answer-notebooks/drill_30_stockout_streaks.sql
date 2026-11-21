-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 30: Stockout streaks (12 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **What this tests:** gaps and islands, the classic "hard" SQL question.
-- MAGIC
-- MAGIC **Scenario:** The replenishment team wants every stockout streak: when it started, when it ended and how many days it lasted.
-- MAGIC
-- MAGIC **Raw data:** `d30_on_hand`: one row per item per day with `on_hand`.
-- MAGIC
-- MAGIC **Your task:** one row per streak of consecutive days with on_hand = 0: `out_from, out_to, days_out`.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. `group by on_hand = 0` merges every out-of-stock day into one group. Why is that wrong?
-- MAGIC 2. Mark the days where the status flips from yesterday.
-- MAGIC 3. A running count of those flips gives each streak its own number.
-- MAGIC
-- MAGIC **Check yourself:** separate streaks come out as separate rows.

-- COMMAND ----------

use workspace.drills;
select current_catalog(), current_schema()

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the next cell to create this drill's practice tables.

-- COMMAND ----------

-- Setup
create or replace table d30_on_hand as
select item_id, date_add(date'2026-03-01', pos) as calendar_date, on_hand
from (select 'STRAW' as item_id, posexplode(array(5,0,0,3,0,0,0,2,0,4)) as (pos, on_hand));

-- COMMAND ----------

select * from d30_on_hand;

-- COMMAND ----------

select * from d30_on_hand;

-- COMMAND ----------

with outs as (select 
item_id,calendar_date, on_hand,
date_sub(calendar_date,
    row_number() over (partition by item_id order by calendar_date) ) as streak_key
from d30_on_hand
where on_hand = 0)
select
    item_id, min(calendar_date) as start_date,
    max(calendar_date) as end_date,
    count(*) as days_out
from outs
group by item_id,streak_key
order by item_id,streak_key;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

-- Drill 30 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 30 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.