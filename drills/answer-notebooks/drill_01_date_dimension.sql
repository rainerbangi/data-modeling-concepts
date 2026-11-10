-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 1: Date dimension (10 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **Task:** Build `d01_dim_date` from 2025-12-01 to 2026-12-31 with: `calendar_date`, `day_name`, `week_start` (weeks start on **Sunday**), `month`, `fiscal_year` (fiscal year starts **Feb 1** and is named by its starting year), `is_weekend`.
-- MAGIC
-- MAGIC **Check yourself:** 2026-03-14 has week_start 2026-03-08. 2026-01-15 has fiscal_year 2025.

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