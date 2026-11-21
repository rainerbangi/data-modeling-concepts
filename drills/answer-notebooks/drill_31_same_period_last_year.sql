-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 31: Same period last year (8 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **What this tests:** year-over-year comparisons, and points vs percent.
-- MAGIC
-- MAGIC **Scenario:** Customer success wants to tell a grocer how shrink changed versus the same fiscal period last year. There are 13 fiscal periods a year, numbered with a running sequence.
-- MAGIC
-- MAGIC **Raw data:** `d31_agg`: `store_id, fiscal_period_seq, shrink_amt, sales_amt`.
-- MAGIC
-- MAGIC **Your task:** for period 14: shrink rate, last year's rate, change in **points** and change in **percent**.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. With a running period number, "last year" is simple arithmetic.
-- MAGIC 2. Join the table to itself.
-- MAGIC 3. Going from 7.2% to 5.8% is a change of how many points? And how many percent?
-- MAGIC
-- MAGIC **Check yourself:** this year 5.8%, last year 7.2%.

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the next cell to create this drill's practice tables.

-- COMMAND ----------

-- Setup
create or replace table d31_agg as
select * from values ('A',1,72.0,1000.0), ('A',14,58.0,1000.0)
as t(store_id, fiscal_period_seq, shrink_amt, sales_amt);    -- 13 periods per year

-- COMMAND ----------

--Task: For period 14: shrink rate, rate last year, change in points, change in percent.

-- COMMAND ----------

describe d31_agg

-- COMMAND ----------

with base_cte as (select
cy.store_id,
cy.fiscal_period_seq,
round(cy.shrink_amt/nullif(cy.sales_amt,0)*100,2) as cy_shrink_rate,
round(ly.shrink_amt/nullif(ly.sales_amt,0)*100,2) as ly_shrink_rate,
round(cy.shrink_amt/nullif(cy.sales_amt,0)*100 - ly.shrink_amt/nullif(ly.sales_amt,0)*100,2) as change_points,
ly.fiscal_period_seq = cy.fiscal_period_seq - 13 as on_check,
cy.fiscal_period_seq - 13 as ly_seq
from d31_agg cy
join d31_agg ly
on ly.fiscal_period_seq = cy.fiscal_period_seq - 13)
select *, round((cy_shrink_rate-ly_shrink_rate)/nullif(ly_shrink_rate,0) *100,2) as change_percent
 from base_cte;

-- COMMAND ----------

select cur.store_id, cur.fiscal_period_seq,
       round(cur.shrink_amt / nullif(cur.sales_amt, 0) * 100, 2) as rate_pct,
       round(ly.shrink_amt  / nullif(ly.sales_amt, 0)  * 100, 2) as rate_ly_pct,
       round((cur.shrink_amt / nullif(cur.sales_amt, 0)
            - ly.shrink_amt  / nullif(ly.sales_amt, 0)) * 100, 2) as change_pts,
       round(((cur.shrink_amt / nullif(cur.sales_amt, 0))
            / nullif(ly.shrink_amt / nullif(ly.sales_amt, 0), 0) - 1) * 100, 1) as change_pct
from d31_agg cur
left join d31_agg ly
  on ly.store_id = cur.store_id and ly.fiscal_period_seq = cur.fiscal_period_seq - 13
where cur.fiscal_period_seq = 14;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

-- Drill 31 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 31 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.