-- Databricks notebook source
-- MAGIC %md
-- MAGIC # SQL Sprint: Joins, Subqueries and Optimization
-- MAGIC
-- MAGIC 14 drills on one payments dataset. For each: start a timer, write your answer in the blank cell, run it, then check `answer_key.md`.
-- MAGIC
-- MAGIC **Spend** = posted debits (`status = 'posted'` and `amount < 0`), shown as a positive number.
-- MAGIC
-- MAGIC Run the next two cells first.

-- COMMAND ----------

use workspace.drills;

-- COMMAND ----------

-- SQL sprint: one small payments dataset used by every drill.
-- Run once in the drills schema: use workspace.drills;

create or replace table s_customers as
select * from values
  ('C1', 'Ana',  date'2026-01-05', cast(null as string), 'NY'),
  ('C2', 'Ben',  date'2026-01-20', 'C1',                 'NJ'),
  ('C3', 'Cara', date'2026-02-02', 'C1',                 'NY'),
  ('C4', 'Dev',  date'2026-02-15', 'C9',                 'CT'),
  ('C5', 'Eli',  date'2026-03-01', cast(null as string), 'NY')
as t(customer_id, name, signup_date, referred_by, state);

create or replace table s_accounts as
select * from values
  ('A1', 'C1', 'checking', date'2026-01-05'),
  ('A2', 'C1', 'savings',  date'2026-01-10'),
  ('A3', 'C2', 'checking', date'2026-01-21'),
  ('A4', 'C3', 'checking', date'2026-02-03'),
  ('A5', 'C6', 'checking', date'2026-02-20'),
  ('A6', 'C5', 'savings',  date'2026-03-02')
as t(account_id, customer_id, account_type, opened_on);

-- amount: negative = money out (a debit), positive = money in (a deposit)
create or replace table s_transactions as
select * from values
  ('T1',  'A1',                 timestamp'2026-03-01 10:00:00',  -50.00, 'posted',   'grocery'),
  ('T2',  'A1',                 timestamp'2026-03-02 12:00:00', -100.00, 'posted',   'dining'),
  ('T3',  'A1',                 timestamp'2026-03-05 09:00:00', 1000.00, 'posted',   'payroll'),
  ('T4',  'A3',                 timestamp'2026-03-03 18:00:00',  -75.00, 'posted',   'grocery'),
  ('T5',  'A3',                 timestamp'2026-03-03 18:01:00',  -75.00, 'declined', 'grocery'),
  ('T6',  'A4',                 timestamp'2026-03-10 08:00:00', -200.00, 'posted',   'travel'),
  ('T7',  'A2',                 timestamp'2026-03-15 11:00:00',  300.00, 'posted',   'transfer'),
  ('T8',  'A5',                 timestamp'2026-03-12 13:00:00',  -40.00, 'posted',   'dining'),
  ('T9',  cast(null as string), timestamp'2026-03-20 15:00:00',  -10.00, 'pending',  'dining'),
  ('T10', 'A1',                 timestamp'2026-04-01 10:00:00',  -60.00, 'posted',   'grocery'),
  ('T11', 'A4',                 timestamp'2026-03-10 08:00:00',  -20.00, 'posted',   'travel'),
  ('T12', 'A3',                 timestamp'2026-03-25 10:00:00', -500.00, 'posted',   'travel'),
  ('T13', 'A2',                 timestamp'2026-04-02 09:00:00',  -10.00, 'posted',   'dining')
as t(txn_id, account_id, txn_ts, amount, status, category);

create or replace table s_refunds as
select * from values
  ('R1', 'T6', date'2026-03-12', 50.00),
  ('R2', 'T6', date'2026-03-14', 30.00),
  ('R3', 'T1', date'2026-03-02', 50.00)
as t(refund_id, txn_id, refunded_on, amount);

-- fee tiers: min_amt included, max_amt excluded
create or replace table s_fee_tiers as
select * from values
  (1,   0.00,       100.00, 1.00),
  (2, 100.00,       500.00, 0.50),
  (3, 500.00, 1000000000.00, 0.25)
as t(tier, min_amt, max_amt, fee_pct);

-- one row per segment change; the latest row is the current segment
create or replace table s_segments as
select * from values
  ('C1', 'standard', date'2026-01-05'),
  ('C1', 'premium',  date'2026-03-01'),
  ('C2', 'standard', date'2026-01-20'),
  ('C3', 'standard', date'2026-02-02')
as t(customer_id, segment, updated_at);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## J1. Join types: predict the rows (5 min)
-- MAGIC **What this tests:** how each join type treats unmatched rows.
-- MAGIC
-- MAGIC **Your task:** before running anything, write down how many rows `s_customers` joined to `s_accounts` (on `customer_id`) returns for an **inner**, **left**, **right** and **full outer** join. Then run all four and compare.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. Look for a customer with no account, a customer with two accounts and an account whose customer doesn't exist.
-- MAGIC 2. Outer joins add the unmatched rows from the side they keep.
-- MAGIC
-- MAGIC **Check yourself:** your four predictions match the four counts.

-- COMMAND ----------

-- J1 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## J2. Every customer's March spend (8 min)
-- MAGIC **What this tests:** where a filter goes in a left join.
-- MAGIC
-- MAGIC **Scenario:** Marketing wants every customer with their March 2026 spend, including customers who spent nothing (show 0).
-- MAGIC
-- MAGIC **Your task:** `customer_id, march_spend` for all 5 customers. Spend = posted debits (`status = 'posted'`, `amount < 0`), shown as positive.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. Write it with the filters in `WHERE` first. Who disappears?
-- MAGIC 2. Filters on the table you're left-joining to belong somewhere else.
-- MAGIC 3. How do you select every moment in March without wrapping the column in a function?
-- MAGIC
-- MAGIC **Check yourself:** 5 rows; customers with no spend show 0, not null.

-- COMMAND ----------

-- J2 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## J3. Spend and refunds per customer (10 min)
-- MAGIC **What this tests:** fan-out when two "many" tables meet.
-- MAGIC
-- MAGIC **Scenario:** Finance wants, per customer, total posted spend (all time) and total refunded, in one table.
-- MAGIC
-- MAGIC **Your task:** `customer_id, spend, refunded`, one row per customer that has spend.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. Join transactions to refunds directly and look at T6. How many times does it appear?
-- MAGIC 2. Get each measure to one row per customer before combining them.
-- MAGIC
-- MAGIC **Check yourself:** each customer's spend matches a query that ignores refunds entirely.

-- COMMAND ----------

-- J3 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## J4. Accounts with no transactions (8 min)
-- MAGIC **What this tests:** anti-joins and the `not in` null trap.
-- MAGIC
-- MAGIC **Scenario:** Ops wants accounts that have never had a transaction, to send an activation email.
-- MAGIC
-- MAGIC **Your task:** write it three ways: `not exists`, `left join ... is null`, and `not in (subquery)`. Explain why one of them behaves differently.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. Look at every `account_id` in `s_transactions`. Is any of them unusual?
-- MAGIC 2. What does `'A6' not in ('A1', null)` evaluate to?
-- MAGIC
-- MAGIC **Check yourself:** two of your three versions agree.

-- COMMAND ----------

-- J4 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## J5. Customers with a travel purchase (6 min)
-- MAGIC **What this tests:** semi-joins: keeping each match once.
-- MAGIC
-- MAGIC **Your task:** customers (`customer_id, name`) with at least one posted travel transaction. Each customer once.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. Try a plain join first and count the rows per customer.
-- MAGIC 2. You want a yes/no per customer, not every matching transaction.
-- MAGIC
-- MAGIC **Check yourself:** no customer appears twice, and you didn't need `distinct`.

-- COMMAND ----------

-- J5 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## J6. Who referred whom (8 min)
-- MAGIC **What this tests:** self-joins and counting with outer joins.
-- MAGIC
-- MAGIC **Scenario:** Growth wants (a) every customer with their referrer's name and (b) how many people each customer referred, including zero.
-- MAGIC
-- MAGIC **Your task:** two queries.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. The same table plays two roles. Give each its own alias.
-- MAGIC 2. One referrer ID doesn't exist as a customer.
-- MAGIC 3. For (b), what does `count(*)` return for a customer who referred nobody?
-- MAGIC
-- MAGIC **Check yourself:** (a) has 5 rows; (b) has 5 rows and its counts add up to the number of customers with a known referrer.

-- COMMAND ----------

-- J6 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## J7. Fee per transaction (8 min)
-- MAGIC **What this tests:** range (non-equi) joins and boundary values.
-- MAGIC
-- MAGIC **Scenario:** Each posted debit pays a fee based on its size, from `s_fee_tiers` (`min_amt` included, `max_amt` excluded).
-- MAGIC
-- MAGIC **Your task:** `txn_id, debit, tier, fee` for every posted debit, fee rounded to cents.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. The join condition is a range, not an equality.
-- MAGIC 2. Find a debit that sits exactly on a tier boundary. How many tiers does `between` match?
-- MAGIC
-- MAGIC **Check yourself:** one row per posted debit, never two.

-- COMMAND ----------

-- J7 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## J8. March spend by current segment (10 min)
-- MAGIC **What this tests:** duplicate keys on the "one" side of a join.
-- MAGIC
-- MAGIC **Scenario:** The CFO wants March spend by customer segment, using each customer's **current** segment.
-- MAGIC
-- MAGIC **Your task:** `segment, spend`. Customers with no segment go under "unknown".
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. Check whether `customer_id` is unique in `s_segments`.
-- MAGIC 2. Reduce the segment table to one row per customer before joining.
-- MAGIC
-- MAGIC **Check yourself:** the segment totals add up to total March spend.

-- COMMAND ----------

-- J8 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## S1. Latest transaction per account (8 min)
-- MAGIC **What this tests:** correlated subqueries vs window functions, and ties.
-- MAGIC
-- MAGIC **Your task:** the latest transaction per account (ignore rows with no account). Write it twice: with a correlated subquery using `max(txn_ts)`, and with a window function. If two transactions tie on time, keep the larger one.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. Compare the row counts of your two versions. Which account differs, and why?
-- MAGIC 2. Which ranking function returns exactly one row per group?
-- MAGIC
-- MAGIC **Check yourself:** your window version returns one row per account.

-- COMMAND ----------

-- S1 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## S2. Debits above the account's own average (8 min)
-- MAGIC **What this tests:** comparing a row to its group's aggregate.
-- MAGIC
-- MAGIC **Your task:** posted debits larger than their account's average posted debit: `txn_id, account_id, debit, avg_debit`.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. You need the average next to every row, without collapsing rows.
-- MAGIC 2. Can you filter on a window function in the same `select`'s `where`?
-- MAGIC
-- MAGIC **Check yourself:** every row's debit is above the average shown beside it.

-- COMMAND ----------

-- S2 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## S3. Top category per customer, keeping ties (8 min)
-- MAGIC **What this tests:** top-N per group and tie handling.
-- MAGIC
-- MAGIC **Your task:** each customer's top spending category (all time, posted debits). If two categories tie, return both.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. Aggregate to customer and category first.
-- MAGIC 2. `row_number`, `rank` and `dense_rank` differ only on ties. Which one keeps both?
-- MAGIC
-- MAGIC **Check yourself:** one customer returns two rows.

-- COMMAND ----------

-- S3 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## S4. Average March spend per active customer (6 min)
-- MAGIC **What this tests:** two-step aggregation.
-- MAGIC
-- MAGIC **Your task:** the average March spend per customer, counting only customers who spent in March.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. What does `avg(-amount)` over transactions actually average?
-- MAGIC 2. Aggregate per customer first, then average.
-- MAGIC
-- MAGIC **Check yourself:** your answer is larger than the average transaction size.

-- COMMAND ----------

-- S4 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## S5. Customers above the average (6 min)
-- MAGIC **What this tests:** scalar subqueries and reusable CTEs.
-- MAGIC
-- MAGIC **Your task:** customers whose March spend is above the average from S4.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. Reuse S4's per-customer step as a CTE.
-- MAGIC 2. A subquery in `where` must return exactly one value.
-- MAGIC
-- MAGIC **Check yourself:** every returned customer's spend is above the S4 average.

-- COMMAND ----------

-- S5 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## O1. Fix a slow query (15 min)
-- MAGIC **What this tests:** spotting waste in a query and explaining the fix. Karat often asks this as a discussion question.
-- MAGIC
-- MAGIC **The query:**
-- MAGIC
-- MAGIC ```sql
-- MAGIC select *
-- MAGIC from s_transactions t
-- MAGIC join s_accounts a  on a.account_id = t.account_id
-- MAGIC join s_customers c on c.customer_id = a.customer_id
-- MAGIC left join s_refunds r on r.txn_id = t.txn_id
-- MAGIC where date_format(t.txn_ts, 'yyyy-MM') = '2026-03'
-- MAGIC   and upper(t.status) = 'POSTED'
-- MAGIC   and t.account_id in (select account_id from s_accounts where account_type = 'checking');
-- MAGIC ```
-- MAGIC
-- MAGIC **Your task:**
-- MAGIC 1. List every problem you see and why it hurts at scale.
-- MAGIC 2. Rewrite it to return March posted spend per customer, checking accounts only.
-- MAGIC 3. Say how you would prove your version is faster.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. Look at what's selected, what's joined but never used, and every function wrapped around a column in `where`.
-- MAGIC 2. Does one of the joins change the grain?
-- MAGIC
-- MAGIC **Check yourself:** you found at least 5 problems, and your rewrite returns one row per customer.

-- COMMAND ----------

-- O1 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Quick-fire questions
-- MAGIC
-- MAGIC Answer the 25 questions in `README.md` out loud, about 30 seconds each. Answers are at the end of `answer_key.md`.
