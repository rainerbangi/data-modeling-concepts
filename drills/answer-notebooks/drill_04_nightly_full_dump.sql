-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 4: Nightly full dump (12 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **What this tests:** building SCD Type 2 from a source that only shows **current** values.
-- MAGIC
-- MAGIC **Scenario:** The item system can't send changes. Every night it sends the **whole** item list as it is now. Merchandising wants to report sales by the category an item had *at the time*, so you must keep history.
-- MAGIC
-- MAGIC **Raw data:**
-- MAGIC - `d04_dim_item`: your SCD2 item dimension (`valid_from`, `valid_to`, `is_current`).
-- MAGIC - `d04_dump_0302`: the full item list sent on 2026-03-02.
-- MAGIC
-- MAGIC **Your task:** apply the Mar 2 dump so category history is kept: close versions that changed, open new versions, and add new items. Unchanged items stay as they are.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. Compare tonight's list with only the **current** version of each item.
-- MAGIC 2. A changed item needs two actions: close the old version and open a new one. Can one `MERGE` row do both?
-- MAGIC 3. After closing, "which items have no current version?" catches both changed and brand-new items.
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

SELECT * FROM d04_dim_item;

-- COMMAND ----------

SELECT * FROM d04_dump_0302;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

-- DBTITLE 1,Drill 4 answer: SCD2 full-dump apply
MERGE INTO d04_dim_item d
USING d04_dump_0302 s
  ON d.item_id = s.item_id
 AND d.is_current = true                              -- compare only against today's version
WHEN MATCHED AND d.category IS DISTINCT FROM s.category THEN
  UPDATE SET valid_to   = DATE'2026-03-02',
             is_current = false;

-- COMMAND ----------

SELECT * FROM d04_dim_item;

-- COMMAND ----------

SELECT * FROM d04_dim_item;

-- COMMAND ----------

INSERT INTO d04_dim_item (item_key, item_id, category, valid_from, valid_to, is_current)
SELECT xxhash64(s.item_id, DATE'2026-03-02'),
       s.item_id,
       s.category,
       DATE'2026-03-02',
       DATE'9999-12-31',
       true
FROM d04_dump_0302 s
LEFT JOIN d04_dim_item d
  ON d.item_id = s.item_id
 AND d.is_current = true
WHERE d.item_id IS NULL; 

-- COMMAND ----------

SELECT * FROM d04_dim_item;

-- COMMAND ----------

-- DBTITLE 1,Checks
-- Checks: expect STRAW 2 rows / 1 current, BLUE 1 / 1, KIWI 1 / 1; exactly 3 current total
select
  item_id,
  count(*) as rows_total,
  count_if(is_current) as rows_current
from d04_dim_item
group by item_id
order by item_id;

select * from d04_dim_item order by item_id, valid_from;
-- STRAW old: 2026-03-01 -> 2026-03-02 (closed, not current)
-- STRAW new: 2026-03-02 -> 9999-12-31 (current)
-- Sandwich join still works: valid_from <= d and d < valid_to

-- COMMAND ----------

SELECT item_id, count(*) AS versions, count_if(is_current) AS current_rows
FROM d04_dim_item
GROUP BY item_id;

-- COMMAND ----------

SELECT 
named_struct('city','NYC'),
EXPLODE(array('A','B', NULL));

-- COMMAND ----------

SELECT inline (array(
  named_struct('plan_code', 'HMO-BASE', 'pay_factor', 0.80),
  named_struct('plan_code', 'PPO-PLUS', 'pay_factor', 0.65)
));

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