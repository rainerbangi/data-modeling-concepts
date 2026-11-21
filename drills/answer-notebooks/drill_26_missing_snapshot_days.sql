-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 26: Missing snapshot days (8 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **What this tests:** finding rows that **don't** exist (coverage checks).
-- MAGIC
-- MAGIC **Scenario:** Data quality asks: "Which stores failed to send a daily snapshot in the first week of March?"
-- MAGIC
-- MAGIC **Raw data:** `d26_snapshots`: one row per store per day that a snapshot arrived.
-- MAGIC
-- MAGIC **Your task:** list every store and day from Mar 1 to 7 with no snapshot.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. You can't find a missing row by looking at the rows that exist.
-- MAGIC 2. Build the list of rows that **should** exist, then compare.
-- MAGIC
-- MAGIC **Check yourself:** 3 missing store-days.

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the next cell to create this drill's practice tables.

-- COMMAND ----------

-- Setup
create or replace table d26_snapshots as
select * from values
  ('A',date'2026-03-01'),('A',date'2026-03-02'),('A',date'2026-03-04'),('A',date'2026-03-05'),
  ('A',date'2026-03-06'),('A',date'2026-03-07'),
  ('B',date'2026-03-01'),('B',date'2026-03-02'),('B',date'2026-03-03'),('B',date'2026-03-04'),
  ('B',date'2026-03-05')
as t(store_id, snapshot_date);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

-- Drill 26 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 26 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.
