-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 2: Keys that never drop rows (8 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **What this tests:** surrogate keys, and protecting fact rows from missing dimension rows (orphans).
-- MAGIC
-- MAGIC **Scenario:** Finance says the sales dashboard shows fewer units than the POS system. You suspect some sales point to stores that aren't in the store table.
-- MAGIC
-- MAGIC **Raw data:**
-- MAGIC - `d02_stores`: one row per known store.
-- MAGIC - `d02_sales`: one row per sale, with `store_id` and `units`. Some `store_id` values are unknown, and one is missing.
-- MAGIC
-- MAGIC **Your task:**
-- MAGIC 1. Build `d02_dim_store (store_key, store_id, store_name)` with a surrogate key.
-- MAGIC 2. Write the sales fact query with `sale_id, store_key, units`.
-- MAGIC
-- MAGIC Every sale must appear, and total units must equal the source total.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. What does an inner join do to a sale whose store isn't in the dimension?
-- MAGIC 2. Data warehouses often keep one special dimension row for "we don't know which store".
-- MAGIC 3. A hash of the business key gives the same surrogate key every time you rebuild.
-- MAGIC
-- MAGIC **Check yourself:** every sale appears once, and total units equal the source table's total.

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the next cell to create this drill's practice tables.

-- COMMAND ----------

-- Setup
create or replace table d02_stores as
select * from values ('A','Store A'), ('B','Store B') as t(store_id, store_name);
create or replace table d02_sales as
select * from values (1,'A',5), (2,'B',3), (3,'Z',2), (4,cast(null as string),1)
as t(sale_id, store_id, units);

-- COMMAND ----------

SELECT * FROM d02_sales;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

-- DBTITLE 1,d02_dim_store with surrogate keys
-- d02_dim_store: one row per real store, plus special members
-- -1 = unknown store  (a store exists, but we can't tell which)
-- -2 = not applicable  (the sale has no store at all)
create or replace table d02_dim_store as
select
  row_number() over (order by store_id) as store_key,  -- deterministic on rebuild
  store_id,
  store_name
from d02_stores
union all
select -1 as store_key, 'U' as store_id, 'Unknown' as store_name
union all
select -2 as store_key, cast(null as string) as store_id, 'Not applicable' as store_name;

-- COMMAND ----------

-- DBTITLE 1,d02_fact_sales with store_key
-- d02_fact_sales: one row per sale; every sale survives
-- LEFT JOIN keeps unmatched sales; CASE assigns the special keys.
-- NULL never matches on equality, so it falls through to the NULL branch.
create or replace table d02_fact_sales as
select
  s.sale_id,
  case
    when d.store_key is not null then d.store_key   -- matched a real store
    when s.store_id is null         then -2         -- no store at all
    else                                 -1         -- store exists, unknown which
  end as store_key,
  s.units
from d02_sales s
left join d02_dim_store d
  on s.store_id = d.store_id;

-- COMMAND ----------

-- DBTITLE 1,Checks
-- Checks: fact keeps all 4 sales, units sum to 11, no NULL keys
select
  count(*) as fact_rows,                    -- expect 4
  sum(units) as total_units,                -- expect 11
  count_if(store_key is null) as null_keys,  -- expect 0
from d02_fact_sales;

select
  count(*) as dim_rows,                    -- expect 4
  count(distinct store_key) as distinct_keys  -- expect 4
from d02_dim_store;

-- COMMAND ----------

select * from d02_dim_store;

-- COMMAND ----------

select * from workspace.drills.d02_fact_sales

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 2 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.