-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 4: Nightly full dump (12 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **Task:** The source sends its full item list every night. Apply the 2026-03-02 dump to `d04_dim_item` so category history is kept.
-- MAGIC
-- MAGIC **Check yourself:** STRAW has 2 rows, BLUE 1, KIWI 1. Exactly 3 rows are current.

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the next cell to create this drill's practice tables.

-- COMMAND ----------

-- Setup
create or replace table d04_dim_item as
select xxhash64(item_id, date'2026-03-01') as item_key, item_id, category,
       date'2026-03-01' as valid_from, date'9999-12-31' as valid_to, true as is_current
from values ('STRAW','Berries'), ('BLUE','Berries') as t(item_id, category);
create or replace table d04_dump_0302 as
select * from values ('STRAW','Fresh Berries'), ('BLUE','Berries'), ('KIWI','Tropical')
as t(item_id, category);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

-- Drill 4 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 4 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.
