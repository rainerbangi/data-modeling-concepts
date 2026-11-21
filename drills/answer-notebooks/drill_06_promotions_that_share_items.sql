-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Drill 6: Promotions that share items (12 min)
-- MAGIC
-- MAGIC **Before you write SQL, say out loud:** what one row of each raw table means, the shape, and the grain of your output.
-- MAGIC
-- MAGIC **What this tests:** many-to-many relationships (bridge tables) and double counting.
-- MAGIC
-- MAGIC **Scenario:** Marketing asks two questions: "How many units did each promo drive?" and "How many units in total were sold while on any promo?"
-- MAGIC
-- MAGIC **Raw data:**
-- MAGIC - `d06_promos`: one row per promo, with start and end dates (**end date inclusive**).
-- MAGIC - `d06_promo_items`: which items each promo covers (a bridge: one row per promo and item).
-- MAGIC - `d06_sales`: one row per sale.
-- MAGIC
-- MAGIC **Your task:** (a) units per promo; (b) total units sold while the item was on any promo.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. Look for a sale whose item and date fit **two** promos.
-- MAGIC 2. (a) and (b) are different questions; one can count a sale twice, the other can't.
-- MAGIC 3. For (b), you want a yes/no per sale: "is there any promo that covers it?"
-- MAGIC
-- MAGIC **Check yourself:** (b) is 19. Your (a) rows should add up to more than 19, and that's fine.

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the next cell to create this drill's practice tables.

-- COMMAND ----------

-- Setup
create or replace table d06_promos as
select * from values ('P1', date'2026-03-01', date'2026-03-07'), ('P2', date'2026-03-05', date'2026-03-10')
as t(promo_id, start_date, end_date);          -- end_date is INCLUSIVE
create or replace table d06_promo_items as
select * from values ('P1','STRAW'), ('P1','BLUE'), ('P2','STRAW') as t(promo_id, item_id);
create or replace table d06_sales as
select * from values
  (date'2026-03-06','STRAW',10), (date'2026-03-06','BLUE',4),
  (date'2026-03-09','STRAW',5),  (date'2026-03-12','STRAW',7)
as t(sale_date, item_id, units);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## My answer
-- MAGIC Start your timer. Write from a blank cell, no notes. Add more cells if you need them.

-- COMMAND ----------

SELECT p.promo_id,
       SUM(s.units) AS units
FROM d06_sales s
JOIN d06_promo_items pi                                   -- ① which promos is this item in?
  ON pi.item_id = s.item_id
JOIN d06_promos p                                         -- ② was the sale inside that promo's dates?
  ON p.promo_id = pi.promo_id
 AND s.sale_date BETWEEN p.start_date AND p.end_date      --    BETWEEN includes both ends
GROUP BY p.promo_id;                                    -- ③ add up each promo's stamps


-- COMMAND ----------

SELECT SUM(s.units) AS units_on_any_promo
FROM d06_sales s
WHERE EXISTS (                                            -- "does at least one promo cover this sale?"
  SELECT 1
  FROM d06_promo_items pi
  JOIN d06_promos p
    ON p.promo_id = pi.promo_id
  WHERE pi.item_id = s.item_id                            -- same item…
    AND s.sale_date BETWEEN p.start_date AND p.end_date   -- …and inside the promo's dates
);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review
-- MAGIC - **Time:** __ min (limit in the title)
-- MAGIC - **Result:** Pass / Fail
-- MAGIC - **Trap caught?** Yes / No
-- MAGIC - **What I missed:**
-- MAGIC - **Genie Code feedback:** (ask: "Review my answer to drill 6 using my coach rules. Do not rewrite it.")
-- MAGIC
-- MAGIC Then check `answer_key.md` and add one line to `log.md`.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **_SCRATCH WORK_**
-- MAGIC
-- MAGIC
-- MAGIC Task: (a) Units sold under each promo. (b) Total units sold while the item was on any promo.

-- COMMAND ----------

SELECT COUNT(*), SUM(s.units) FROM
d06_promo_items pi JOIN d06_sales s
ON pi.item_id = s.item_id;

SELECT * FROM
d06_promo_items pi JOIN d06_sales s
ON pi.item_id = s.item_id
JOIN d06_promos p ON (p.promo_id = pi.promo_id
AND s.sale_date BETWEEN p.start_date AND p.end_date);


SELECT 
    p.promo_id,
    SUM(s.units) as units
FROM
d06_promo_items pi 
JOIN d06_sales s ON pi.item_id = s.item_id
JOIN d06_promos p ON  pi.promo_id = p.promo_id AND s.sale_date BETWEEN p.start_date AND p.end_date
GROUP BY p.promo_id;

-- COMMAND ----------

select p.promo_id, sum(s.units) as units
from d06_sales s
join d06_promo_items pi on pi.item_id = s.item_id              -- step 1
join d06_promos p on p.promo_id = pi.promo_id
              and s.sale_date between p.start_date and p.end_date  -- step 2
group by p.promo_id;   

-- COMMAND ----------

-- MAGIC %md
-- MAGIC

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Here’s a practice drill in the same style as your others.**
-- MAGIC
-- MAGIC Tasks
-- MAGIC
-- MAGIC (a) List the students enrolled in at least one STEM course in 2026-FALL.
-- MAGIC
-- MAGIC (b) What is the total scholarship money held by those students?
-- MAGIC
-- MAGIC (c) List the students who have never taken a STEM course (any term).

-- COMMAND ----------

create or replace table p01_students as
select * from values
  ('S1','Ava', 1000), ('S2','Ben', 500), ('S3','Cara', 2000),
  ('S4','Dev', 750),  ('S5','Eli', 300)
as t(student_id, name, scholarship);

create or replace table p01_courses as
select * from values
  ('C1','Calculus', true), ('C2','Physics', true),
  ('C3','Poetry',  false), ('C4','History', false)
as t(course_id, title, is_stem);

create or replace table p01_enrollments as
select * from values
  ('S1','C1','2026-FALL'),   ('S1','C2','2026-FALL'),
  ('S2','C3','2026-FALL'),
  ('S3','C1','2026-SPRING'), ('S3','C4','2026-FALL'),
  ('S4','C2','2026-FALL'),   ('S4','C3','2026-FALL')
as t(student_id, course_id, term);

-- COMMAND ----------

SELECT * FROM p01_students;


-- COMMAND ----------

SELECT * FROM p01_courses;

-- COMMAND ----------

SELECT * FROM p01_enrollments;

-- COMMAND ----------

--(a) List the students enrolled in at least one STEM course in 2026-FALL.

 -- p01_courses -- 1 row represents 1 course
 -- p01_enrollments -- 1 row represents 1 student enrollment
 -- p01_students -- 1 row represents 1 student

-- JOINING p01_enrollments and p01_courses to determine STEM courses in 2026-FALL

SELECT * FROM p01_students s
WHERE EXISTS (
SELECT 1 
FROM p01_enrollments e
JOIN p01_courses c ON c.course_id = e.course_id AND e.term = '2026-FALL' AND c.is_stem = true
WHERE s.student_id = e.student_id)


-- COMMAND ----------

--(b) What is the total scholarship money held by those students?

SELECT SUM(scholarship) FROM p01_students s
WHERE EXISTS (
SELECT 1 
FROM p01_enrollments e
JOIN p01_courses c ON c.course_id = e.course_id AND e.term = '2026-FALL' AND c.is_stem = true
WHERE s.student_id = e.student_id)


-- COMMAND ----------

--(c) List the students who have never taken a STEM course (any term).
--→ S2 Ben (only Poetry) and S5 Eli (no enrollments at all). NOT EXISTS keeps Eli naturally: no rows found means “none exist,” so the answer is TRUE.

SELECT * FROM p01_students s
WHERE NOT EXISTS (
    SELECT *
FROM p01_enrollments e
JOIN p01_courses c ON c.course_id = e.course_id AND is_stem = true
WHERE s.student_id = e.student_id
)



-- COMMAND ----------

select sum(s.units)                                    -- add up the units…
from d06_sales s                                       -- …of the sales…
where exists (                                         -- …where the clerk says YES to:
  select 1                                             --   "is there at least one page…
  from d06_promo_items pi                              --    in the binder (items…
  join d06_promos p on p.promo_id = pi.promo_id        --    …joined to their promo dates)
  where pi.item_id = s.item_id                         --    …with MY item…
    and s.sale_date between p.start_date and p.end_date  --  …that covers MY date?"
);