-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 5: One fact, two dates (8 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **What this tests:** role-playing dimensions, and keeping rows whose second date isn't known yet.
-- MAGIC
-- MAGIC **Scenario:** The supply chain team wants delivery volume by the week a PO was **ordered** and the week it was **received**, in one table.
-- MAGIC
-- MAGIC **Raw data:** `d05_deliveries`, one row per purchase order, with `ordered_date`, `received_date` (null if not delivered yet) and `units`.
-- MAGIC
-- MAGIC **Your task:** one query returning `ordered_week, received_week, units`, using `d01_dim_date` for the weeks. POs not yet received must still appear.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. You need the date table twice in one query. How do you tell the two apart?
-- MAGIC 2. One of the two dates can be null. Which join keeps that row?
-- MAGIC
-- MAGIC **Check yourself:** total units equal the source total, and POs not yet received still appear.

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the next cell to create this drill's practice tables.

-- COMMAND ----------

-- Setup
create or replace table d05_deliveries as
select * from values
  (101, date'2026-03-02', date'2026-03-09', 40),
  (102, date'2026-03-04', date'2026-03-05', 20),
  (103, date'2026-03-10', cast(null as date), 30)
as t(po_id, ordered_date, received_date, units);

-- COMMAND ----------

SELECT * FROM d01_dim_date;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

SELECT
  od.week_start  AS ordered_week,
  rd.week_start  AS received_week,
  (f.units)   AS units
FROM d05_deliveries f
LEFT JOIN d01_dim_date od ON f.ordered_date =  od.calendar_date   -- role 1: order date
LEFT JOIN d01_dim_date rd ON f.received_date = rd.calendar_date  -- role 2: received date
--GROUP BY od.week_start, rd.week_start
ORDER BY ordered_week, received_week;

-- COMMAND ----------

SELECT
  od.week_start  AS ordered_week,
  rd.week_start  AS received_week,
  SUM(f.units)   AS units
FROM d05_deliveries f
LEFT JOIN d01_dim_date od ON f.ordered_date =  od.calendar_date   -- role 1: order date
LEFT JOIN d01_dim_date rd ON f.received_date = rd.calendar_date  -- role 2: received date
GROUP BY od.week_start, rd.week_start
ORDER BY ordered_week, received_week;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 5 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.