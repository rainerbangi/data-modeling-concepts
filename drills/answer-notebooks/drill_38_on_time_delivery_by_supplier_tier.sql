-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 38: On-time delivery by supplier tier (25 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **What this tests:** an accumulating snapshot plus an as-was SCD2 lookup; combines drills 27, 7 and 16.
-- MAGIC
-- MAGIC **Scenario:** Procurement says Preferred suppliers deliver on time more often. Supplier S1 was upgraded to Preferred on Mar 5. Test the claim fairly.
-- MAGIC
-- MAGIC **Raw data:**
-- MAGIC - `c38_tier_changes`: `supplier_id, tier, effective_date`.
-- MAGIC - `c38_po_events`: `po_id, supplier_id, status, status_at`.
-- MAGIC
-- MAGIC **Your task:** on-time rate (received within 3 days of ordering) by the supplier's tier **when the PO was ordered**. Only received POs count.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. Make one row per PO first.
-- MAGIC 2. Which date decides the tier: order, receipt or today?
-- MAGIC 3. A rate is the average of a 1/0 flag.
-- MAGIC
-- MAGIC **Check yourself:** 3 POs counted; 1 is excluded.

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the next cell to create this drill's practice tables.

-- COMMAND ----------

-- Setup
create or replace table c38_tier_changes as
select * from values ('S1','Standard',date'2026-01-01'), ('S1','Preferred',date'2026-03-05')
as t(supplier_id, tier, effective_date);
create or replace table c38_po_events as
select * from values
  ('P1','S1','ordered',timestamp'2026-03-01 09:00:00'), ('P1','S1','received',timestamp'2026-03-03 09:00:00'),
  ('P2','S1','ordered',timestamp'2026-03-06 09:00:00'), ('P2','S1','received',timestamp'2026-03-12 09:00:00'),
  ('P3','S1','ordered',timestamp'2026-03-07 09:00:00'), ('P3','S1','received',timestamp'2026-03-09 09:00:00'),
  ('P4','S1','ordered',timestamp'2026-03-08 09:00:00')
as t(po_id, supplier_id, status, status_at);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

-- Drill 38 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 38 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.
