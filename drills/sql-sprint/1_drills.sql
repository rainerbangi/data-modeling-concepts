-- Databricks notebook source
-- MAGIC %md
-- MAGIC # 1. Drills: joins, subqueries and optimization
-- MAGIC
-- MAGIC **How to use this notebook**
-- MAGIC 1. Run the next two cells once. They create the practice tables.
-- MAGIC 2. Work down the parts in order. For each drill: start a timer, write your answer in the empty cell under it, run it.
-- MAGIC 3. Check yourself in the `2_answers` notebook, under the same drill ID.
-- MAGIC
-- MAGIC **Spend** always means posted debits (`status = 'posted'` and `amount < 0`), shown as a positive number.
-- MAGIC
-- MAGIC ## The dataset
-- MAGIC
-- MAGIC | Table | One row means | Watch for |
-- MAGIC |---|---|---|
-- MAGIC | `s_customers` | a customer; `referred_by` points to another customer | a referrer that doesn't exist |
-- MAGIC | `s_accounts` | an account owned by a customer | a customer with two accounts, one with none, an account whose customer is missing |
-- MAGIC | `s_transactions` | a transaction; a negative amount is money out | declined and pending rows, a null `account_id`, two rows with the same timestamp, a customer with a month of no spend |
-- MAGIC | `s_refunds` | a refund of a transaction | one transaction refunded twice |
-- MAGIC | `s_fee_tiers` | a fee band (`min_amt` included, `max_amt` excluded) | a debit exactly on a boundary |
-- MAGIC | `s_segments` | a segment change for a customer | a customer with two rows |

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
  ('T13', 'A2',                 timestamp'2026-04-02 09:00:00',  -10.00, 'posted',   'dining'),
  ('T14', 'A3',                 timestamp'2026-02-14 19:00:00',  -60.00, 'posted',   'grocery'),
  ('T15', 'A4',                 timestamp'2026-01-28 12:00:00',  -30.00, 'posted',   'grocery')
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
-- MAGIC ## Part 1: Discussion warm-up
-- MAGIC
-- MAGIC Karat opens with about 10 minutes of quick questions. Besides the 30 quick-fire questions in `README.md`, expect short snippets to **read** rather than write: "What does this return?" and "What's wrong with this?" Answer out loud in under a minute each, then run the snippet to check yourself.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### P1. Predict: three kinds of count (2 min)
-- MAGIC **What this tests:** how `count` treats nulls and duplicates.
-- MAGIC
-- MAGIC **Your task:** without running it, say what each column returns, then run it.
-- MAGIC
-- MAGIC ```sql
-- MAGIC select count(*), count(referred_by), count(distinct referred_by)
-- MAGIC from s_customers;
-- MAGIC ```
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. Look at the `referred_by` column: how many nulls, and how many repeats?
-- MAGIC
-- MAGIC **Check yourself:** you can explain why all three numbers differ.

-- COMMAND ----------

-- P1 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### P2. Predict: an average with a null (2 min)
-- MAGIC **What this tests:** how aggregates skip nulls.
-- MAGIC
-- MAGIC **Your task:** what does this return, and why isn't it 10?
-- MAGIC
-- MAGIC ```sql
-- MAGIC select avg(x) from values (10), (cast(null as int)), (20) as t(x);
-- MAGIC ```
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. Does `avg` divide by 3 rows or by the number of non-null values?
-- MAGIC
-- MAGIC **Check yourself:** you can say how to make it treat the null as zero.

-- COMMAND ----------

-- P2 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### P3. Predict: a left join with a WHERE filter (3 min)
-- MAGIC **What this tests:** spotting a left join that has silently become an inner join.
-- MAGIC
-- MAGIC **Your task:** how many rows does this return, and which customers are missing?
-- MAGIC
-- MAGIC ```sql
-- MAGIC select c.customer_id, a.account_id
-- MAGIC from s_customers c
-- MAGIC left join s_accounts a on a.customer_id = c.customer_id
-- MAGIC where a.account_type = 'checking';
-- MAGIC ```
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. What is `a.account_type` for a customer with no account?
-- MAGIC 2. And for a customer whose only account is a savings account?
-- MAGIC
-- MAGIC **Check yourself:** you can rewrite it so every customer appears, with their checking account if they have one.

-- COMMAND ----------

-- P3 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### P4. Predict: division (2 min)
-- MAGIC **What this tests:** how numeric types change a result, and that engines differ.
-- MAGIC
-- MAGIC **Your task:** what do these return in Databricks? What would `7 / 2` return in Postgres or SQL Server?
-- MAGIC
-- MAGIC ```sql
-- MAGIC select 7 / 2 as a, 7 div 2 as b, cast(7 as double) / 2 as c;
-- MAGIC ```
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. Some engines keep integer division when both sides are integers.
-- MAGIC
-- MAGIC **Check yourself:** you can explain how you'd make a rate calculation safe in any engine.

-- COMMAND ----------

-- P4 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### B1. Spot the bug: customers per state (3 min)
-- MAGIC **What this tests:** counting after a join.
-- MAGIC
-- MAGIC **Scenario:** "How many customers with an account do we have in each state?"
-- MAGIC
-- MAGIC ```sql
-- MAGIC select c.state, count(*) as customers
-- MAGIC from s_customers c
-- MAGIC left join s_accounts a on a.customer_id = c.customer_id
-- MAGIC group by c.state;
-- MAGIC ```
-- MAGIC
-- MAGIC **Your task:** name both bugs and fix the query.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. What does one row mean after this join? Look at C1.
-- MAGIC 2. What does `count(*)` count for a customer with no account?
-- MAGIC
-- MAGIC **Check yourself:** your fixed query counts each customer once and only customers with an account.

-- COMMAND ----------

-- B1 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### B2. Spot the bug: March by BETWEEN (2 min)
-- MAGIC **What this tests:** date boundaries on timestamps.
-- MAGIC
-- MAGIC ```sql
-- MAGIC select sum(-amount) as march_spend
-- MAGIC from s_transactions
-- MAGIC where status = 'posted' and amount < 0
-- MAGIC   and txn_ts between '2026-03-01' and '2026-03-31';
-- MAGIC ```
-- MAGIC
-- MAGIC **Your task:** which March transactions could this miss, and how do you fix it?
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. What time of day does `'2026-03-31'` mean when compared with a timestamp?
-- MAGIC
-- MAGIC **Check yourself:** your filter includes every moment of March 31 and nothing from April.

-- COMMAND ----------

-- B2 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### B3. Spot the bug: grouping (2 min)
-- MAGIC **What this tests:** what `group by` allows in `select`.
-- MAGIC
-- MAGIC ```sql
-- MAGIC select a.customer_id, t.category, sum(-t.amount) as spend
-- MAGIC from s_transactions t
-- MAGIC join s_accounts a on a.account_id = t.account_id
-- MAGIC where t.status = 'posted' and t.amount < 0
-- MAGIC group by a.customer_id;
-- MAGIC ```
-- MAGIC
-- MAGIC **Your task:** what happens when this runs, and what are the two possible fixes depending on the question?
-- MAGIC
-- MAGIC **Check yourself:** you can explain both fixes in one sentence each.

-- COMMAND ----------

-- B3 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### B4. Spot the bug: filtering a window (2 min)
-- MAGIC **What this tests:** the order SQL runs its clauses.
-- MAGIC
-- MAGIC ```sql
-- MAGIC select account_id, txn_id, txn_ts
-- MAGIC from s_transactions
-- MAGIC where row_number() over (partition by account_id order by txn_ts desc) = 1;
-- MAGIC ```
-- MAGIC
-- MAGIC **Your task:** why does this fail, and how do you fix it (two ways)?
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. When do window functions run compared with `where`?
-- MAGIC
-- MAGIC **Check yourself:** you can name one engine feature that filters on a window result directly.

-- COMMAND ----------

-- B4 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Part 2: Joins

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### J1. Join types: predict the rows (5 min)
-- MAGIC **What this tests:** how each join type treats unmatched rows.
-- MAGIC
-- MAGIC **Tables:** `s_customers`, `s_accounts`, joined on `customer_id`.
-- MAGIC
-- MAGIC **Your task:** before running anything, write down how many rows an **inner**, **left** (customers first), **right** and **full outer** join return. Then run all four as one query returning `join_type, n`.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. Find: a customer with no account, a customer with two accounts, an account whose customer doesn't exist.
-- MAGIC 2. Outer joins add the unmatched rows from the side they keep.
-- MAGIC
-- MAGIC **Check yourself:** your four predictions match the four counts, and you can explain each one in a sentence.

-- COMMAND ----------

-- J1 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### J2. Every customer's March spend (8 min)
-- MAGIC **What this tests:** where a filter goes in a left join.
-- MAGIC
-- MAGIC **Scenario:** Marketing wants a list of every customer with their March 2026 spend, including customers who spent nothing, to target a "come back" campaign.
-- MAGIC
-- MAGIC **Tables:** `s_customers`, `s_accounts`, `s_transactions`.
-- MAGIC
-- MAGIC **Your task:** return `customer_id, march_spend` for all 5 customers, sorted by `customer_id`. Spend = posted debits (`status = 'posted'`, `amount < 0`), shown as a positive number. Customers with no spend show `0`.
-- MAGIC
-- MAGIC **Clarify first** (and the answers to assume):
-- MAGIC - Do declined or pending transactions count? No.
-- MAGIC - Do deposits count? No, only money out.
-- MAGIC - Which time zone? Use the timestamps as stored.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. Write it with all filters in `WHERE` first. Who disappears, and why?
-- MAGIC 2. Filters on the table you left-join to belong in its `ON` clause.
-- MAGIC 3. Select every moment in March without wrapping `txn_ts` in a function.
-- MAGIC
-- MAGIC **Check yourself:** 5 rows; customers with no spend show 0, not null.

-- COMMAND ----------

-- J2 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### J3. Spend and refunds per customer (10 min)
-- MAGIC **What this tests:** fan-out when two "many" tables meet the same parent.
-- MAGIC
-- MAGIC **Scenario:** Finance wants, for each customer, total posted spend (all time) and total refunded, side by side, to watch refund rates.
-- MAGIC
-- MAGIC **Tables:** `s_transactions`, `s_refunds`, `s_accounts`.
-- MAGIC
-- MAGIC **Your task:** `customer_id, spend, refunded` (refunded 0 if none), one row per customer who has any spend, sorted by `customer_id`. Use the `customer_id` on the account, even if that customer isn't in `s_customers`.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. Join transactions to refunds directly and look at T6. How many rows does it become?
-- MAGIC 2. Get each measure to one row per customer before combining them.
-- MAGIC
-- MAGIC **Check yourself:** each customer's spend equals what a query that ignores refunds returns.

-- COMMAND ----------

-- J3 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### J4. Accounts with no transactions (8 min)
-- MAGIC **What this tests:** anti-joins and the `not in` null trap.
-- MAGIC
-- MAGIC **Scenario:** Ops wants accounts that have never had a transaction, to send an activation email.
-- MAGIC
-- MAGIC **Tables:** `s_accounts`, `s_transactions`.
-- MAGIC
-- MAGIC **Your task:** return `account_id, customer_id`. Write it three ways: `not exists`, `left join ... is null`, and `not in (subquery)`. Explain why one of them behaves differently.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. Look at every `account_id` value in `s_transactions`. Is one unusual?
-- MAGIC 2. What does `'A6' not in ('A1', null)` evaluate to?
-- MAGIC
-- MAGIC **Check yourself:** two of your three versions agree, and you can explain the third in one sentence.

-- COMMAND ----------

-- J4 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### J5. Customers with a travel purchase (6 min)
-- MAGIC **What this tests:** semi-joins: keeping each match once.
-- MAGIC
-- MAGIC **Scenario:** Partnerships wants to email customers who have booked travel with their card.
-- MAGIC
-- MAGIC **Your task:** `customer_id, name` of customers with at least one **posted** travel transaction. Each customer appears once. Sort by `customer_id`.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. Try a plain join first and count the rows per customer.
-- MAGIC 2. You want a yes or no per customer, not every matching transaction.
-- MAGIC
-- MAGIC **Check yourself:** no customer appears twice, and you didn't need `distinct`.

-- COMMAND ----------

-- J5 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### J6. Who referred whom (8 min)
-- MAGIC **What this tests:** self-joins and counting with outer joins.
-- MAGIC
-- MAGIC **Scenario:** Growth is paying referral bonuses and needs two lists.
-- MAGIC
-- MAGIC **Your task:**
-- MAGIC - (a) Every customer with their referrer's name: `customer_id, name, referred_by_name`. Customers without a known referrer show null.
-- MAGIC - (b) How many people each customer referred, including zero: `customer_id, name, referrals`.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. The same table plays two roles. Give each its own alias.
-- MAGIC 2. One `referred_by` value doesn't exist as a customer.
-- MAGIC 3. For (b), what does `count(*)` return for a customer who referred nobody?
-- MAGIC
-- MAGIC **Check yourself:** both results have 5 rows. The referral counts add up to the number of customers whose referrer exists.

-- COMMAND ----------

-- J6 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### J7. Fee per transaction (8 min)
-- MAGIC **What this tests:** range (non-equi) joins and boundary values.
-- MAGIC
-- MAGIC **Scenario:** Each posted debit pays a processing fee based on its size, defined in `s_fee_tiers` (`min_amt` included, `max_amt` excluded, `fee_pct` in percent).
-- MAGIC
-- MAGIC **Your task:** `txn_id, debit, tier, fee` for every posted debit, fee rounded to cents, sorted by `txn_id`. Then the total fees.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. The join condition is a range, not an equality.
-- MAGIC 2. Find a debit that sits exactly on a tier boundary. How many tiers does `between` match?
-- MAGIC
-- MAGIC **Check yourself:** exactly one row per posted debit.

-- COMMAND ----------

-- J7 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### J8. March spend by current segment (10 min)
-- MAGIC **What this tests:** duplicate keys on the side you expect to be "one".
-- MAGIC
-- MAGIC **Scenario:** The CFO wants March spend by customer segment, using each customer's **current** segment (the latest row in `s_segments`).
-- MAGIC
-- MAGIC **Your task:** `segment, spend`, sorted by segment. Spend from accounts whose customer has no segment goes under `'unknown'`.
-- MAGIC
-- MAGIC **Clarify first:** "Current segment, or the segment at the time of each transaction?" Assume current.
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
-- MAGIC ## Part 3: Subqueries and window functions

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### S1. Latest transaction per account (8 min)
-- MAGIC **What this tests:** correlated subqueries vs window functions, and ties.
-- MAGIC
-- MAGIC **Your task:** the latest transaction per account: `account_id, txn_id, txn_ts`. Ignore the row with no account. Write it twice:
-- MAGIC 1. With a correlated subquery using `max(txn_ts)`.
-- MAGIC 2. With a window function. If two transactions tie on time, keep the one with the larger amount.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. Compare the row counts of your two versions. Which account differs, and why?
-- MAGIC 2. Which ranking function always returns exactly one row per group?
-- MAGIC
-- MAGIC **Check yourself:** your window version returns exactly one row per account.

-- COMMAND ----------

-- S1 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### S2. Debits above the account's own average (8 min)
-- MAGIC **What this tests:** comparing a row with its group's aggregate.
-- MAGIC
-- MAGIC **Scenario:** Risk wants transactions that are unusually large for that account.
-- MAGIC
-- MAGIC **Your task:** posted debits larger than their account's average posted debit: `txn_id, account_id, debit, avg_debit` (avg rounded to 2 decimals), sorted by `txn_id`.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. You need the average next to every row without collapsing rows.
-- MAGIC 2. Can you filter on a window function in the same query's `where`?
-- MAGIC
-- MAGIC **Check yourself:** every row's debit is above the average beside it.

-- COMMAND ----------

-- S2 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### S3. Top category per customer, keeping ties (8 min)
-- MAGIC **What this tests:** top-N per group and tie handling.
-- MAGIC
-- MAGIC **Your task:** each customer's top spending category, all time, posted debits: `customer_id, category, spend`. If two categories tie, return both. Sort by `customer_id, category`.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. Aggregate to customer and category first.
-- MAGIC 2. `row_number`, `rank` and `dense_rank` differ only on ties. Which keeps both?
-- MAGIC
-- MAGIC **Check yourself:** exactly one customer returns two rows.

-- COMMAND ----------

-- S3 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### S4. Average March spend per active customer (6 min)
-- MAGIC **What this tests:** two-step aggregation.
-- MAGIC
-- MAGIC **Your task:** the average March spend per customer, counting only customers (by the account's `customer_id`) who spent in March. One number, rounded to 2 decimals.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. What does `avg(-amount)` over transactions actually average?
-- MAGIC 2. Aggregate per customer first, then average the totals.
-- MAGIC
-- MAGIC **Check yourself:** your answer is larger than the average March transaction.

-- COMMAND ----------

-- S4 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### S5. Customers above the average (6 min)
-- MAGIC **What this tests:** scalar subqueries and reusing a CTE.
-- MAGIC
-- MAGIC **Your task:** `customer_id, spend` for customers whose March spend is above the S4 average.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. Reuse S4's per-customer step as a CTE.
-- MAGIC 2. A subquery in `where` must return exactly one value.
-- MAGIC
-- MAGIC **Check yourself:** every customer returned is above the S4 average.

-- COMMAND ----------

-- S5 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### S6. One row per customer, many measures (8 min)
-- MAGIC **What this tests:** conditional aggregation (pivoting with `case`), the most reused pattern in analytics SQL.
-- MAGIC
-- MAGIC **Scenario:** Risk wants a one-line summary per customer.
-- MAGIC
-- MAGIC **Your task:** per customer (account's `customer_id`), all time: `customer_id, posted_debits` (count), `declined` (count), `grocery_spend`, `travel_spend`, `decline_rate` (declined ÷ all debits, as a percent with 1 decimal). Sort by `customer_id`.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. One `group by`, with `case when` inside each aggregate.
-- MAGIC 2. What does `sum(case when ... then x end)` return when nothing matches? Do you want that?
-- MAGIC 3. Ratios: sum the parts first, divide last, protect the denominator.
-- MAGIC
-- MAGIC **Check yourself:** one row per customer; spend columns are never null.

-- COMMAND ----------

-- S6 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### S7. Month-over-month spend, with missing months (12 min)
-- MAGIC **What this tests:** a month spine, `lag`, and the difference between "no data" and zero.
-- MAGIC
-- MAGIC **Scenario:** Product wants each customer's monthly spend from January to April 2026 and the change from the previous month. A month with no spend must show 0, not be missing, or the change will compare with the wrong month.
-- MAGIC
-- MAGIC **Your task:** `customer_id, month, spend, prev_spend, change`, for every customer (account's `customer_id`) with any posted debit, and every month January to April 2026. Sort by `customer_id, month`.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. Build every customer × month pair first (a "spine"), then attach spend.
-- MAGIC 2. Run `lag` only after the spine exists. Why does order matter?
-- MAGIC 3. January has no previous month in range. What should `prev_spend` be?
-- MAGIC
-- MAGIC **Check yourself:** 4 rows per customer; months with no spend show 0; `change` is null only in January.

-- COMMAND ----------

-- S7 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Part 4: Optimization

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### O1. Fix a slow query (15 min)
-- MAGIC **What this tests:** spotting waste in a query and explaining the fix. Senior candidates are often asked to optimize a slow query given a schema.
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
-- MAGIC 1. List every problem and why it hurts at scale (imagine `s_transactions` has 2 billion rows).
-- MAGIC 2. Rewrite it to return March posted spend per customer, checking accounts only: `customer_id, name, march_spend`.
-- MAGIC 3. Say how you'd prove your version is faster.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. Look at what's selected, what's joined but never used, and every function wrapped around a column in `where`.
-- MAGIC 2. Does one of the joins change the grain?
-- MAGIC
-- MAGIC **Check yourself:** you found at least 5 problems; your rewrite returns one row per customer.

-- COMMAND ----------

-- O1 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### O2. Talk track: "This query got slow" (5 min, out loud)
-- MAGIC **What this tests:** a structured way to debug performance. You're scored on the structure, not on naming a tool.
-- MAGIC
-- MAGIC **The prompt:** "A daily job that builds `fct_transactions_daily` used to take 5 minutes. Now it takes 2 hours. Walk me through what you'd do."
-- MAGIC
-- MAGIC **Your task:** answer out loud in under 2 minutes. Cover: what you'd ask first, where you'd look, the likely causes and how you'd confirm the fix.
-- MAGIC
-- MAGIC **Hints:**
-- MAGIC 1. Sudden or gradual? Did data, code or the cluster change?
-- MAGIC 2. The query profile tells you which step is slow. Then: too much read, too much shuffled, or one task far slower than the rest?
-- MAGIC
-- MAGIC **Check yourself:** your answer has a clear order and ends with "measure again".

-- COMMAND ----------

-- O2 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Part 5: Mock round (40 min, out loud)

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### M1. Karat-style progressive question
-- MAGIC **What this tests:** everything above, the way Karat asks it: one schema, five parts, each harder than the last. Getting through more parts matters more than polishing one.
-- MAGIC
-- MAGIC **How to run it:** set a 40-minute timer. Talk out loud as if the interviewer were listening. Clarify before each part. Don't look anything up until the timer ends.
-- MAGIC
-- MAGIC **Scenario:** You're the analytics engineer at a payments app. The product lead asks a series of questions about customer spending, using `s_customers`, `s_accounts` and `s_transactions`.
-- MAGIC
-- MAGIC **Part 1 (5 min):** total posted spend and the number of posted debits per category, highest spend first.
-- MAGIC
-- MAGIC **Part 2 (5 min):** total posted spend per customer **state**. What happens to spend from an account whose customer isn't in `s_customers`? Say what you'd do and why.
-- MAGIC
-- MAGIC **Part 3 (8 min):** for each customer in `s_customers`: number of accounts, number of posted debits and total spend. Customers with no accounts or no spend still appear with zeros.
-- MAGIC
-- MAGIC **Part 4 (10 min):** for each customer in `s_customers`: their signup date, the date of their first posted debit, and the number of days between them. Customers who never spent show null for both.
-- MAGIC
-- MAGIC **Part 5 (12 min):** each customer's spend rank within their state, highest first (ties share a rank), and their share of their state's total spend as a percent with 1 decimal. Only customers with spend.
-- MAGIC
-- MAGIC **Check yourself:** compare with the answer key after the timer ends, then note which part took longest.

-- COMMAND ----------

-- M1 answer


-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Quick-fire questions
-- MAGIC
-- MAGIC Answer each in two or three sentences, out loud, in under 30 seconds. Answers are at the end of the `2_answers` notebook. Questions 26 to 30 come up often in Karat's discussion segment.
-- MAGIC
-- MAGIC 1. What's the difference between an inner and a left join?
-- MAGIC 2. What changes if a filter on the right table moves from `ON` to `WHERE` in a left join?
-- MAGIC 3. What are a semi-join and an anti-join? How do you write them?
-- MAGIC 4. Why avoid `not in` with a subquery?
-- MAGIC 5. `union` vs `union all`?
-- MAGIC 6. `where` vs `having`?
-- MAGIC 7. What is a correlated subquery, and when would you replace it?
-- MAGIC 8. CTE vs subquery vs temp table?
-- MAGIC 9. Window function vs `group by`?
-- MAGIC 10. `row_number` vs `rank` vs `dense_rank`?
-- MAGIC 11. `count(*)` vs `count(col)` vs `count(distinct col)`?
-- MAGIC 12. How do aggregates treat nulls?
-- MAGIC 13. Is `null = null` true?
-- MAGIC 14. What is fan-out, and how do you prevent it?
-- MAGIC 15. In what order does SQL run its clauses?
-- MAGIC 16. A query got slow. How do you narrow down the cause?
-- MAGIC 17. Indexes vs partitioning vs clustering?
-- MAGIC 18. What is predicate pushdown?
-- MAGIC 19. What is a broadcast join?
-- MAGIC 20. What is data skew, and how do you handle it?
-- MAGIC 21. Why is `select *` bad in a warehouse?
-- MAGIC 22. Normalization vs denormalization?
-- MAGIC 23. OLTP vs OLAP?
-- MAGIC 24. How do you deduplicate a table?
-- MAGIC 25. Which modern SQL features do you use?
-- MAGIC 26. What does ACID mean?
-- MAGIC 27. Primary key vs foreign key? Are they enforced in a warehouse?
-- MAGIC 28. View vs materialized view vs table?
-- MAGIC 29. When would you choose a relational database over NoSQL?
-- MAGIC 30. Star schema vs snowflake schema?
