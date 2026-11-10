-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 3: Fix typos, keep no history (8 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **Task:** Apply `d03_incoming` to `d03_dim_store`. History does not matter. Running your statement twice must change nothing the second time.

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the next cell to create this drill's practice tables.

-- COMMAND ----------

-- Setup
create or replace table d03_dim_store as
select xxhash64(store_id) as store_key, * from values
  ('A','Stor A','East'), ('B','Store B', cast(null as string))
as t(store_id, store_name, region);
create or replace table d03_incoming as
select * from values ('A','Store A','East'), ('B','Store B','West'), ('C','Store C','South')
as t(store_id, store_name, region);

-- COMMAND ----------

SELECT * FROM d03_dim_store;
SELECT * FROM d03_incoming;

-- COMMAND ----------

SELECT * FROM d03_dim_store;

-- COMMAND ----------

SELECT * FROM d03_incoming;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

SELECT CAST(NULL as STRING) != 'West';
SELECT NULL IS DISTINCT FROM 'West';

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Drill 3: Fix typos, keep no history (8 min)
-- MAGIC Before you write SQL, say out loud: what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC Task: Apply d03_incoming to d03_dim_store. History does not matter. Running your statement twice must change nothing the second time.

-- COMMAND ----------


MERGE INTO
d03_dim_store AS d USING
d03_incoming AS i
ON d.store_id = i.store_id
WHEN MATCHED AND (
    d.store_name IS DISTINCT FROM i.store_name
    OR d.region IS DISTINCT FROM i.region
)
THEN UPDATE SET
    store_name = i.store_name
    , region = i.region
WHEN NOT MATCHED
THEN INSERT 
(store_key, store_id, store_name, region)
VALUES
(xxhash64(i.store_id), i.store_id, i.store_name, i.region)

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 3 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.