## Part 1: Discussion warm-up

Karat opens with about 10 minutes of quick questions. Besides the 30 quick-fire questions in `README.md`, expect short snippets to **read** rather than write: "What does this return?" and "What's wrong with this?" Answer out loud in under a minute each, then run the snippet to check yourself.

### P1. Predict: three kinds of count (2 min)
**What this tests:** how `count` treats nulls and duplicates.

**Your task:** without running it, say what each column returns, then run it.

```sql
select count(*), count(referred_by), count(distinct referred_by)
from s_customers;
```

**Hints:**
1. Look at the `referred_by` column: how many nulls, and how many repeats?

**Check yourself:** you can explain why all three numbers differ.

### P2. Predict: an average with a null (2 min)
**What this tests:** how aggregates skip nulls.

**Your task:** what does this return, and why isn't it 10?

```sql
select avg(x) from values (10), (cast(null as int)), (20) as t(x);
```

**Hints:**
1. Does `avg` divide by 3 rows or by the number of non-null values?

**Check yourself:** you can say how to make it treat the null as zero.

### P3. Predict: a left join with a WHERE filter (3 min)
**What this tests:** spotting a left join that has silently become an inner join.

**Your task:** how many rows does this return, and which customers are missing?

```sql
select c.customer_id, a.account_id
from s_customers c
left join s_accounts a on a.customer_id = c.customer_id
where a.account_type = 'checking';
```

**Hints:**
1. What is `a.account_type` for a customer with no account?
2. And for a customer whose only account is a savings account?

**Check yourself:** you can rewrite it so every customer appears, with their checking account if they have one.

### P4. Predict: division (2 min)
**What this tests:** how numeric types change a result, and that engines differ.

**Your task:** what do these return in Databricks? What would `7 / 2` return in Postgres or SQL Server?

```sql
select 7 / 2 as a, 7 div 2 as b, cast(7 as double) / 2 as c;
```

**Hints:**
1. Some engines keep integer division when both sides are integers.

**Check yourself:** you can explain how you'd make a rate calculation safe in any engine.

### B1. Spot the bug: customers per state (3 min)
**What this tests:** counting after a join.

**Scenario:** "How many customers with an account do we have in each state?"

```sql
select c.state, count(*) as customers
from s_customers c
left join s_accounts a on a.customer_id = c.customer_id
group by c.state;
```

**Your task:** name both bugs and fix the query.

**Hints:**
1. What does one row mean after this join? Look at C1.
2. What does `count(*)` count for a customer with no account?

**Check yourself:** your fixed query counts each customer once and only customers with an account.

### B2. Spot the bug: March by BETWEEN (2 min)
**What this tests:** date boundaries on timestamps.

```sql
select sum(-amount) as march_spend
from s_transactions
where status = 'posted' and amount < 0
  and txn_ts between '2026-03-01' and '2026-03-31';
```

**Your task:** which March transactions could this miss, and how do you fix it?

**Hints:**
1. What time of day does `'2026-03-31'` mean when compared with a timestamp?

**Check yourself:** your filter includes every moment of March 31 and nothing from April.

### B3. Spot the bug: grouping (2 min)
**What this tests:** what `group by` allows in `select`.

```sql
select a.customer_id, t.category, sum(-t.amount) as spend
from s_transactions t
join s_accounts a on a.account_id = t.account_id
where t.status = 'posted' and t.amount < 0
group by a.customer_id;
```

**Your task:** what happens when this runs, and what are the two possible fixes depending on the question?

**Check yourself:** you can explain both fixes in one sentence each.

### B4. Spot the bug: filtering a window (2 min)
**What this tests:** the order SQL runs its clauses.

```sql
select account_id, txn_id, txn_ts
from s_transactions
where row_number() over (partition by account_id order by txn_ts desc) = 1;
```

**Your task:** why does this fail, and how do you fix it (two ways)?

**Hints:**
1. When do window functions run compared with `where`?

**Check yourself:** you can name one engine feature that filters on a window result directly.

---

## Part 2: Joins

### J1. Join types: predict the rows (5 min)
**What this tests:** how each join type treats unmatched rows.

**Tables:** `s_customers`, `s_accounts`, joined on `customer_id`.

**Your task:** before running anything, write down how many rows an **inner**, **left** (customers first), **right** and **full outer** join return. Then run all four as one query returning `join_type, n`.

**Hints:**
1. Find: a customer with no account, a customer with two accounts, an account whose customer doesn't exist.
2. Outer joins add the unmatched rows from the side they keep.

**Check yourself:** your four predictions match the four counts, and you can explain each one in a sentence.

### J2. Every customer's March spend (8 min)
**What this tests:** where a filter goes in a left join.

**Scenario:** Marketing wants a list of every customer with their March 2026 spend, including customers who spent nothing, to target a "come back" campaign.

**Tables:** `s_customers`, `s_accounts`, `s_transactions`.

**Your task:** return `customer_id, march_spend` for all 5 customers, sorted by `customer_id`. Spend = posted debits (`status = 'posted'`, `amount < 0`), shown as a positive number. Customers with no spend show `0`.

**Clarify first** (and the answers to assume):
- Do declined or pending transactions count? No.
- Do deposits count? No, only money out.
- Which time zone? Use the timestamps as stored.

**Hints:**
1. Write it with all filters in `WHERE` first. Who disappears, and why?
2. Filters on the table you left-join to belong in its `ON` clause.
3. Select every moment in March without wrapping `txn_ts` in a function.

**Check yourself:** 5 rows; customers with no spend show 0, not null.

### J3. Spend and refunds per customer (10 min)
**What this tests:** fan-out when two "many" tables meet the same parent.

**Scenario:** Finance wants, for each customer, total posted spend (all time) and total refunded, side by side, to watch refund rates.

**Tables:** `s_transactions`, `s_refunds`, `s_accounts`.

**Your task:** `customer_id, spend, refunded` (refunded 0 if none), one row per customer who has any spend, sorted by `customer_id`. Use the `customer_id` on the account, even if that customer isn't in `s_customers`.

**Hints:**
1. Join transactions to refunds directly and look at T6. How many rows does it become?
2. Get each measure to one row per customer before combining them.

**Check yourself:** each customer's spend equals what a query that ignores refunds returns.

### J4. Accounts with no transactions (8 min)
**What this tests:** anti-joins and the `not in` null trap.

**Scenario:** Ops wants accounts that have never had a transaction, to send an activation email.

**Tables:** `s_accounts`, `s_transactions`.

**Your task:** return `account_id, customer_id`. Write it three ways: `not exists`, `left join ... is null`, and `not in (subquery)`. Explain why one of them behaves differently.

**Hints:**
1. Look at every `account_id` value in `s_transactions`. Is one unusual?
2. What does `'A6' not in ('A1', null)` evaluate to?

**Check yourself:** two of your three versions agree, and you can explain the third in one sentence.

### J5. Customers with a travel purchase (6 min)
**What this tests:** semi-joins: keeping each match once.

**Scenario:** Partnerships wants to email customers who have booked travel with their card.

**Your task:** `customer_id, name` of customers with at least one **posted** travel transaction. Each customer appears once. Sort by `customer_id`.

**Hints:**
1. Try a plain join first and count the rows per customer.
2. You want a yes or no per customer, not every matching transaction.

**Check yourself:** no customer appears twice, and you didn't need `distinct`.

### J6. Who referred whom (8 min)
**What this tests:** self-joins and counting with outer joins.

**Scenario:** Growth is paying referral bonuses and needs two lists.

**Your task:**
- (a) Every customer with their referrer's name: `customer_id, name, referred_by_name`. Customers without a known referrer show null.
- (b) How many people each customer referred, including zero: `customer_id, name, referrals`.

**Hints:**
1. The same table plays two roles. Give each its own alias.
2. One `referred_by` value doesn't exist as a customer.
3. For (b), what does `count(*)` return for a customer who referred nobody?

**Check yourself:** both results have 5 rows. The referral counts add up to the number of customers whose referrer exists.

### J7. Fee per transaction (8 min)
**What this tests:** range (non-equi) joins and boundary values.

**Scenario:** Each posted debit pays a processing fee based on its size, defined in `s_fee_tiers` (`min_amt` included, `max_amt` excluded, `fee_pct` in percent).

**Your task:** `txn_id, debit, tier, fee` for every posted debit, fee rounded to cents, sorted by `txn_id`. Then the total fees.

**Hints:**
1. The join condition is a range, not an equality.
2. Find a debit that sits exactly on a tier boundary. How many tiers does `between` match?

**Check yourself:** exactly one row per posted debit.

### J8. March spend by current segment (10 min)
**What this tests:** duplicate keys on the side you expect to be "one".

**Scenario:** The CFO wants March spend by customer segment, using each customer's **current** segment (the latest row in `s_segments`).

**Your task:** `segment, spend`, sorted by segment. Spend from accounts whose customer has no segment goes under `'unknown'`.

**Clarify first:** "Current segment, or the segment at the time of each transaction?" Assume current.

**Hints:**
1. Check whether `customer_id` is unique in `s_segments`.
2. Reduce the segment table to one row per customer before joining.

**Check yourself:** the segment totals add up to total March spend.

---

## Part 3: Subqueries and window functions

### S1. Latest transaction per account (8 min)
**What this tests:** correlated subqueries vs window functions, and ties.

**Your task:** the latest transaction per account: `account_id, txn_id, txn_ts`. Ignore the row with no account. Write it twice:
1. With a correlated subquery using `max(txn_ts)`.
2. With a window function. If two transactions tie on time, keep the one with the larger amount.

**Hints:**
1. Compare the row counts of your two versions. Which account differs, and why?
2. Which ranking function always returns exactly one row per group?

**Check yourself:** your window version returns exactly one row per account.

### S2. Debits above the account's own average (8 min)
**What this tests:** comparing a row with its group's aggregate.

**Scenario:** Risk wants transactions that are unusually large for that account.

**Your task:** posted debits larger than their account's average posted debit: `txn_id, account_id, debit, avg_debit` (avg rounded to 2 decimals), sorted by `txn_id`.

**Hints:**
1. You need the average next to every row without collapsing rows.
2. Can you filter on a window function in the same query's `where`?

**Check yourself:** every row's debit is above the average beside it.

### S3. Top category per customer, keeping ties (8 min)
**What this tests:** top-N per group and tie handling.

**Your task:** each customer's top spending category, all time, posted debits: `customer_id, category, spend`. If two categories tie, return both. Sort by `customer_id, category`.

**Hints:**
1. Aggregate to customer and category first.
2. `row_number`, `rank` and `dense_rank` differ only on ties. Which keeps both?

**Check yourself:** exactly one customer returns two rows.

### S4. Average March spend per active customer (6 min)
**What this tests:** two-step aggregation.

**Your task:** the average March spend per customer, counting only customers (by the account's `customer_id`) who spent in March. One number, rounded to 2 decimals.

**Hints:**
1. What does `avg(-amount)` over transactions actually average?
2. Aggregate per customer first, then average the totals.

**Check yourself:** your answer is larger than the average March transaction.

### S5. Customers above the average (6 min)
**What this tests:** scalar subqueries and reusing a CTE.

**Your task:** `customer_id, spend` for customers whose March spend is above the S4 average.

**Hints:**
1. Reuse S4's per-customer step as a CTE.
2. A subquery in `where` must return exactly one value.

**Check yourself:** every customer returned is above the S4 average.

### S6. One row per customer, many measures (8 min)
**What this tests:** conditional aggregation (pivoting with `case`), the most reused pattern in analytics SQL.

**Scenario:** Risk wants a one-line summary per customer.

**Your task:** per customer (account's `customer_id`), all time: `customer_id, posted_debits` (count), `declined` (count), `grocery_spend`, `travel_spend`, `decline_rate` (declined ÷ all debits, as a percent with 1 decimal). Sort by `customer_id`.

**Hints:**
1. One `group by`, with `case when` inside each aggregate.
2. What does `sum(case when ... then x end)` return when nothing matches? Do you want that?
3. Ratios: sum the parts first, divide last, protect the denominator.

**Check yourself:** one row per customer; spend columns are never null.

### S7. Month-over-month spend, with missing months (12 min)
**What this tests:** a month spine, `lag`, and the difference between "no data" and zero.

**Scenario:** Product wants each customer's monthly spend from January to April 2026 and the change from the previous month. A month with no spend must show 0, not be missing, or the change will compare with the wrong month.

**Your task:** `customer_id, month, spend, prev_spend, change`, for every customer (account's `customer_id`) with any posted debit, and every month January to April 2026. Sort by `customer_id, month`.

**Hints:**
1. Build every customer × month pair first (a "spine"), then attach spend.
2. Run `lag` only after the spine exists. Why does order matter?
3. January has no previous month in range. What should `prev_spend` be?

**Check yourself:** 4 rows per customer; months with no spend show 0; `change` is null only in January.

---

## Part 4: Optimization

### O1. Fix a slow query (15 min)
**What this tests:** spotting waste in a query and explaining the fix. Senior candidates are often asked to optimize a slow query given a schema.

**The query:**

```sql
select *
from s_transactions t
join s_accounts a  on a.account_id = t.account_id
join s_customers c on c.customer_id = a.customer_id
left join s_refunds r on r.txn_id = t.txn_id
where date_format(t.txn_ts, 'yyyy-MM') = '2026-03'
  and upper(t.status) = 'POSTED'
  and t.account_id in (select account_id from s_accounts where account_type = 'checking');
```

**Your task:**
1. List every problem and why it hurts at scale (imagine `s_transactions` has 2 billion rows).
2. Rewrite it to return March posted spend per customer, checking accounts only: `customer_id, name, march_spend`.
3. Say how you'd prove your version is faster.

**Hints:**
1. Look at what's selected, what's joined but never used, and every function wrapped around a column in `where`.
2. Does one of the joins change the grain?

**Check yourself:** you found at least 5 problems; your rewrite returns one row per customer.

### O2. Talk track: "This query got slow" (5 min, out loud)
**What this tests:** a structured way to debug performance. You're scored on the structure, not on naming a tool.

**The prompt:** "A daily job that builds `fct_transactions_daily` used to take 5 minutes. Now it takes 2 hours. Walk me through what you'd do."

**Your task:** answer out loud in under 2 minutes. Cover: what you'd ask first, where you'd look, the likely causes and how you'd confirm the fix.

**Hints:**
1. Sudden or gradual? Did data, code or the cluster change?
2. The query profile tells you which step is slow. Then: too much read, too much shuffled, or one task far slower than the rest?

**Check yourself:** your answer has a clear order and ends with "measure again".

---

## Part 5: Mock round (40 min, out loud)

### M1. Karat-style progressive question
**What this tests:** everything above, the way Karat asks it: one schema, five parts, each harder than the last. Getting through more parts matters more than polishing one.

**How to run it:** set a 40-minute timer. Talk out loud as if the interviewer were listening. Clarify before each part. Don't look anything up until the timer ends.

**Scenario:** You're the analytics engineer at a payments app. The product lead asks a series of questions about customer spending, using `s_customers`, `s_accounts` and `s_transactions`.

**Part 1 (5 min):** total posted spend and the number of posted debits per category, highest spend first.

**Part 2 (5 min):** total posted spend per customer **state**. What happens to spend from an account whose customer isn't in `s_customers`? Say what you'd do and why.

**Part 3 (8 min):** for each customer in `s_customers`: number of accounts, number of posted debits and total spend. Customers with no accounts or no spend still appear with zeros.

**Part 4 (10 min):** for each customer in `s_customers`: their signup date, the date of their first posted debit, and the number of days between them. Customers who never spent show null for both.

**Part 5 (12 min):** each customer's spend rank within their state, highest first (ties share a rank), and their share of their state's total spend as a percent with 1 decimal. Only customers with spend.

**Check yourself:** compare with the answer key after the timer ends, then note which part took longest.
