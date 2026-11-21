-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 27: Purchase order lifecycle (12 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **What this tests:** the accumulating snapshot: one row per process, a column per step.
-- MAGIC
-- MAGIC **Scenario:** The supply chain lead wants a PO tracker: when each PO was ordered, shipped and received, how long receiving took, and which POs are overdue.
-- MAGIC
-- MAGIC **Raw data:** `d27_po_events`: `po_id, status, status_at`. Events can be duplicated.
-- MAGIC
-- MAGIC **Your task:** one row per PO with `ordered_at, shipped_at, received_at, days_to_receive, is_overdue`. Overdue = not received and more than 5 days since ordering, as of Mar 10.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. Turn rows (one per event) into columns (one per step).
-- MAGIC 2. `min` or `max` combined with `case when` picks one timestamp per step.
-- MAGIC 3. POs still in progress must stay in the result.
-- MAGIC
-- MAGIC **Check yourself:** 3 rows; exactly one is overdue.

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the next cell to create this drill's practice tables.

-- COMMAND ----------

-- Setup
create or replace table d27_po_events as
select * from values
  ('P1','ordered', timestamp'2026-03-01 09:00:00'), ('P1','shipped', timestamp'2026-03-03 09:00:00'),
  ('P1','shipped', timestamp'2026-03-03 09:00:00'), ('P1','received',timestamp'2026-03-06 09:00:00'),
  ('P2','ordered', timestamp'2026-03-02 09:00:00'), ('P2','shipped', timestamp'2026-03-05 09:00:00'),
  ('P3','ordered', timestamp'2026-03-07 09:00:00')
as t(po_id, status, status_at);

-- COMMAND ----------


with deduped_purchases as (
    select po_id, status, status_at
    from d27_po_events
    where status_at < date'2026-03-11'
    qualify row_number() over (partition by po_id, status, status_at order by status_at desc) =1 
 
),
piv as (
    select
    po_id,
    min (case when status = 'ordered' then status_at end) as ordered_at,
    min (case when status = 'shipped' then status_at end) as shipped_at,   
    min (case when status = 'received' then status_at end) as received_at
    from deduped_purchases
    group by po_id
)
select 
*,
date_diff(day,ordered_at, received_at) as ordered_to_received,
case
 when (received_at is null and date_diff(day,ordered_at,date'2026-03-10')>5 ) then 1 else 0 end as over_due
from piv;

-- COMMAND ----------

with piv as (
  select po_id,
         min(case when status = 'ordered'  then status_at end) as ordered_at,
         min(case when status = 'shipped'  then status_at end) as shipped_at,
         min(case when status = 'received' then status_at end) as received_at
  from d27_po_events
  group by po_id
)
select *,
       datediff(received_at, ordered_at) as days_to_receive,
       received_at is null and datediff(date'2026-03-10', ordered_at) > 5 as is_overdue
from piv;

-- COMMAND ----------

select * from d27_po_events;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

-- Drill 27 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 27 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.