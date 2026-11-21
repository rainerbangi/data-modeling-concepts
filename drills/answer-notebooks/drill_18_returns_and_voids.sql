-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 18: Returns and voids (10 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **What this tests:** business rules for corrections, and a classic null trap with `NOT IN`.
-- MAGIC
-- MAGIC **Scenario:** Finance needs net units per day. The POS records three kinds of transactions.
-- MAGIC
-- MAGIC **Raw data:** `d18_txns`: `txn_id, txn_type, ref_txn_id, sold_on, item_id, units`.
-- MAGIC
-- MAGIC | txn_type | Meaning |
-- MAGIC |---|---|
-- MAGIC | sale | a normal sale |
-- MAGIC | return | a customer brings an item back on a later day (negative units, its own date) |
-- MAGIC | void | a cashier cancels a sale completely; `ref_txn_id` points to it |
-- MAGIC
-- MAGIC **Your task:** net units per day.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. A return and a void are different: one is a new event, the other erases an event.
-- MAGIC 2. Try `txn_id not in (select ref_txn_id from d18_txns)`. Why does it return nothing?
-- MAGIC 3. There's a null-safe way to say "no void points to this sale".
-- MAGIC
-- MAGIC **Check yourself:** Mar 14: 5. Mar 15: 1.

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the next cell to create this drill's practice tables.

-- COMMAND ----------

-- Setup
create or replace table d18_txns as
select * from values
  (1,'sale',  cast(null as int),date'2026-03-14','STRAW',5),
  (2,'sale',  cast(null as int),date'2026-03-14','STRAW',3),
  (3,'void',  2,                date'2026-03-14','STRAW',cast(null as int)),
  (4,'return',1,                date'2026-03-15','STRAW',-1),
  (5,'sale',  cast(null as int),date'2026-03-15','STRAW',2)
as t(txn_id, txn_type, ref_txn_id, sold_on, item_id, units);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

-- Drill 18 answer
SELECT item_id,sold_on, sum(units)  FROM d18_txns d
WHERE d.txn_type IN ('sale', 'return') AND NOT EXISTS (
   SELECT 1 FROM d18_txns e 
WHERE e.txn_type = 'void' and d.txn_id = e.ref_txn_id ) 
group by all
order by sold_on desc;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 18 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### **OTHER SAMPLE QUESTIONS AND QUERIES**

-- COMMAND ----------

--Rainer's original answer
with cte_base as (
select *
from d18_txns main
left join d18_txns later
on main.txn_id = later.ref_txn_id
where later.txn_type is distinct from 'void'
and main.txn_type <> 'void'
)
select
item_id, sold_on, sum(units) as daily_units
from cte_base
group by all

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Task: list the students who have no active enrollment.
-- MAGIC
-- MAGIC Do these 3 things:
-- MAGIC
-- MAGIC 1) Say the grain of each table and of your output out loud.
-- MAGIC 2) Write it with NOT EXISTS.
-- MAGIC 3) Predict what these two tempting versions would return, and why they’re wrong:
-- MAGIC - a) where student_id not in (select student_id from enrollments where status = 'active')
-- MAGIC - b) students s left join enrollments e on s.student_id = e.student_id where e.status <> 'active'

-- COMMAND ----------

--Another sample question
create or replace table practice_students as
select * from values
  (1, 'Ana'),
  (2, 'Ben'),
  (3, 'Cy'),
  (4, 'Di')
as t(student_id, name);

create or replace table practice_enrollments as
select * from values
  (1,                    'MATH', 'active'),
  (1,                    'ART',  'dropped'),
  (2,                    'ART',  'dropped'),
  (cast(null as int),    'BIO',  'active')
as t(student_id, course, status);

select * from practice_students;

-- COMMAND ----------

select * from practice_enrollments;

-- COMMAND ----------

select student_id
from practice_students s
WHERE NOT EXISTS (
select 1 from practice_enrollments e
WHERE e.status = 'active'
and e.student_id =s.student_id);

-- COMMAND ----------

select student_id
from practice_students s
where student_id not in (select student_id from practice_enrollments e
WHERE e.status = 'active' and student_id is not null);

-- COMMAND ----------

select * from practice_students s 
left join practice_enrollments e 
on s.student_id = e.student_id and e.status = 'active'
where e.status is null;