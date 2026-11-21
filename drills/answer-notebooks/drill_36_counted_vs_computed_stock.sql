-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 36: Counted vs computed stock (20 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **What this tests:** reconciling two sources of truth, and cumulative vs daily differences.
-- MAGIC
-- MAGIC **Scenario:** Loss prevention wants to know how much stock went missing each day: the gap between stock calculated from movements and stock counted on the shelf.
-- MAGIC
-- MAGIC **Raw data:**
-- MAGIC - `c36_opening`: on-hand at the end of Mar 8.
-- MAGIC - `c36_events`: stock movements.
-- MAGIC - `c36_counts`: physical counts per day.
-- MAGIC
-- MAGIC **Your task:** per day: computed on-hand, counted on-hand, drift (counted − computed) and **unexplained loss that day**.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. Computed on-hand is drill 25.
-- MAGIC 2. Drift carries over from one day to the next. How much of today's drift is new today?
-- MAGIC
-- MAGIC **Check yourself:** drift on Mar 11 is −3; the loss **on** Mar 11 is smaller.

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the next cell to create this drill's practice tables.

-- COMMAND ----------

-- Setup
create or replace table c36_opening as select * from values ('STRAW',date'2026-03-08',20) as t(item_id, as_of, on_hand);
create or replace table c36_events as
select * from values
  ('STRAW',date'2026-03-09',24), ('STRAW',date'2026-03-09',-6),
  ('STRAW',date'2026-03-10',-4), ('STRAW',date'2026-03-11',-5)
as t(item_id, event_date, qty_change);
create or replace table c36_counts as
select * from values ('STRAW',date'2026-03-09',38), ('STRAW',date'2026-03-10',33), ('STRAW',date'2026-03-11',26)
as t(item_id, count_date, counted);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

-- Drill 36 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 36 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.
