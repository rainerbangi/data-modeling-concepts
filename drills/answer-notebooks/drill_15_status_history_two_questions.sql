-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 15: Status history, two questions (12 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **What this tests:** choosing the shape from the **question**, not the table.
-- MAGIC
-- MAGIC **Scenario:** The supply chain team has a log of purchase order status changes and asks two things:
-- MAGIC (a) "How many POs were in shipped status on Mar 5?"
-- MAGIC (b) "On average, how many days from ordered to received?"
-- MAGIC
-- MAGIC **Raw data:** `d15_po_status`: `po_id, status ('ordered', 'shipped', 'received'), status_at`.
-- MAGIC
-- MAGIC **Your task:** answer both questions.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. (a) is about the state at one moment. Which shape answers "what was true on a date"?
-- MAGIC 2. (b) is about time between two steps. What if each PO were one row with a column per step?
-- MAGIC 3. Not every PO has been received.
-- MAGIC
-- MAGIC **Check yourself:** (a) 2. (b) 5.0.

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the next cell to create this drill's practice tables.

-- COMMAND ----------

-- Setup
create or replace table d15_po_status as
select * from values
  ('P1','ordered', timestamp'2026-03-01 09:00:00'), ('P1','shipped', timestamp'2026-03-03 09:00:00'),
  ('P1','received',timestamp'2026-03-06 09:00:00'),
  ('P2','ordered', timestamp'2026-03-02 09:00:00'), ('P2','shipped', timestamp'2026-03-05 09:00:00'),
  ('P3','ordered', timestamp'2026-03-04 09:00:00')
as t(po_id, status, status_at);

-- COMMAND ----------

-- DBTITLE 1,h
--(a) How many POs were in "shipped" status on Mar 5? 

with status_range as (select po_id,status, date(status_at) as valid_from, LEAD(date(status_at),1, date '9999-12-31') OVER (PARTITION BY po_id Order by status_at) as valid_to from d15_po_status)
select count(*) from status_range
where date '2026-03-15' >= valid_from and date '2026-03-15' < valid_to and status = 'shipped';

-- (b) Average days from ordered to received, for received POs. Which shape fits each question?


SELECT
avg(datediff(day,order_date,received_date)) as avg_duration
from
(SELECT
po_id,
min(CASE WHEN status = 'ordered' then date(status_at) end) as order_date,
min(CASE WHEN status = 'received' then date(status_at) end) as received_date
FROM d15_po_status
group by 1) t
where received_date is not null


-- COMMAND ----------

SELECT
po_id,
SUM(case when status = 'ordered' then 1 else 0 end),
SUM(case when status = 'received' then 1 end)
FROM d15_po_status
group by 1;

-- COMMAND ----------

--grain check

select po_id, status_at, count(*)
from d15_po_status
group by po_id, status_at
having count(*) > 1;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

-- Drill 15 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 15 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.