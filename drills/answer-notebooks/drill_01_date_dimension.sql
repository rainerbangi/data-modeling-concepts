-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 1: Date dimension (10 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **What this tests:** building a dimension from nothing, date functions, and calendar rules that differ from the defaults (week start, fiscal year).
-- MAGIC
-- MAGIC **Scenario:** Every model you build next will join to a calendar. The business plans in **weeks that start on Sunday** and a **fiscal year that starts Feb 1** (named by the year it starts in: Feb 2025 to Jan 2026 is fiscal 2025).
-- MAGIC
-- MAGIC **Raw data:** none. You generate the dates yourself.
-- MAGIC
-- MAGIC **Your task:** create `d01_dim_date`, one row per day from 2025-12-01 to 2026-12-31, with:
-- MAGIC
-- MAGIC | Column | Meaning |
-- MAGIC |---|---|
-- MAGIC | calendar_date | the date |
-- MAGIC | day_name | Monday, Tuesday, ... |
-- MAGIC | week_start | the Sunday that starts this date's week |
-- MAGIC | month | 1 to 12 |
-- MAGIC | fiscal_year | per the rule above |
-- MAGIC | is_weekend | true on Saturday and Sunday |
-- MAGIC
-- MAGIC **Hints** (one at a time, only if stuck):
-- MAGIC 1. Two functions together turn a start and end date into one row per day.
-- MAGIC 2. Check what day of the week Databricks counts as 1, and what `date_trunc('week', ...)` returns.
-- MAGIC 3. Only one month of the year breaks the "fiscal year = calendar year" rule.
-- MAGIC
-- MAGIC **Check yourself:** 396 rows. Spot-check one Saturday's week_start and one January date's fiscal_year against the rules. Later drills reuse this table.

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

WITH date_spine AS (
  SELECT explode(
    sequence(
      to_date('2025-12-01'),
      to_date('2026-12-31'),
      interval 1 day
    )
  ) AS calendar_date
)
SELECT
    calendar_date,
    date_format(calendar_date, 'EEEE') as day_name,
    date_format(calendar_date, 'MMMM') as month_name,
    CASE
        WHEN MONTH(calendar_date) BETWEEN 2 AND 12 THEN YEAR(calendar_date)
        ELSE YEAR(calendar_date)-1 END
    AS fiscal_year,
    weekday(calendar_date) AS weekday
FROM date_spine





-- COMMAND ----------

create or replace table d01_dim_date as
with date_spine as
(select
  explode(
    sequence(date'2025-12-01', date'2026-12-31', interval 1 day)
    ) as d
 )
select d as calendar_date,
       date_format(d, 'EEEE') as day_name,
       date_sub(d, dayofweek(d) - 1) as week_start,           -- dayofweek: Sun = 1 ... Sat = 7
       month(d) as month,
       case when month(d) >= 2 then year(d) else year(d) - 1 end as fiscal_year,
       dayofweek(d) in (1, 7) as is_weekend,
       dayofweek(d) as day_of_week
from date_spine;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 1 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.