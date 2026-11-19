-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 25: Stock from movements (12 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **Task:** End-of-day on-hand for every day from Mar 9 to 12. The opening balance is end of day Mar 8.

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

SELECT current_catalog(), current_schema()

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the next cell to create this drill's practice tables.

-- COMMAND ----------

-- Setup
create or replace table d25_opening as
select * from values ('STRAW', date'2026-03-08', 20) as t(item_id, as_of, on_hand);
create or replace table d25_events as
select * from values
  ('STRAW',date'2026-03-09',24,'delivery'), ('STRAW',date'2026-03-09',-6,'sale'),
  ('STRAW',date'2026-03-11',-5,'sale'),     ('STRAW',date'2026-03-11',-2,'shrink')
as t(item_id, event_date, qty_change, event_type);

-- COMMAND ----------

select * from d25_opening;

-- COMMAND ----------

select * from d25_events;

-- COMMAND ----------

  with date_spine as (select d.calendar_date, i.item_id
  from d01_dim_date d
  cross join (select * from values ('STRAW'), ('BLUE') as t(item_id)) i
  where d.calendar_date between date'2026-03-09' and date'2026-03-12'),
daily_change as (
  select item_id, event_date, sum(qty_change) as net_change
  from d25_events
  group by all
)
select 
d.item_id, d.calendar_date, c.net_change, o.on_hand,
sum(coalesce(net_change,0)) over (partition by d.item_id order by  d.calendar_date ) as total_change_from_start,
o.on_hand + sum(coalesce(net_change,0)) over (partition by d.item_id order by  d.calendar_date ) as on_hand
from date_spine d
left join daily_change c 
on d.calendar_date = c.event_date and d.item_id=c.item_id
left join d25_opening o on d.item_id=o.item_id;

--“Today’s stock = what I started with + everything that’s changed since then.”


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

-- Drill 25 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 25 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.