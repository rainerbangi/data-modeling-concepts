-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 15: Status history, two questions (12 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **Task:** (a) How many POs were in "shipped" status on Mar 5? (b) Average days from ordered to received, for received POs. Which shape fits each question?

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
