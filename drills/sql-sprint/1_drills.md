# 1. Drills (PostgreSQL)

**How to practice:** open the Karat Studio practice environment (or any Postgres), choose **PostgreSQL**, paste the drill's **Setup** at the top and write your query under it. Karat Studio recreates the tables every time you click Run, so keep the setup in the editor.

**Spend** means posted debits (`status = 'posted'` and `amount < 0`), shown as a positive number.

After each drill: check `2_answers.md` (same ID) and log it in `progress.md`.

---

## Part 1: Read it first (predict the output, find the bug)

Say your answer out loud **before** running anything. Then run it to check.

### R1. Three kinds of count (2 min)
**What this tests:** how `count` treats nulls and repeats.

**Setup**
```sql
drop table if exists users;
create table users (user_id int primary key, name text, referred_by int);
insert into users values
  (1, 'Ana', null), (2, 'Ben', 1), (3, 'Cara', 1), (4, 'Dev', 9), (5, 'Eli', null);
```

**Predict:**
```sql
select count(*), count(referred_by), count(distinct referred_by) from users;
```

**Check yourself:** you can explain why all three numbers differ.

### R2. Division and rounding (3 min)
**What this tests:** integer division and `round` on decimals. Both behave differently from Databricks.

**Setup:** none.

**Predict each value, then run:**
```sql
select 5 / 2            as a,
       5::numeric / 2   as b,
       avg(x)           as c
from (values (1), (2)) as t(x);
```
Then predict whether this runs: `select round(2.5::float8, 1);`

**Databricks vs Postgres:** Databricks returns 2.5 for `5 / 2`. Postgres keeps integer division.

**Check yourself:** you can write a percentage that is correct in Postgres and rounded to 1 decimal.

### R3. A left join with a WHERE filter (3 min)
**What this tests:** spotting a left join that silently became an inner join.

**Setup**
```sql
drop table if exists accounts; drop table if exists users;
create table users (user_id int primary key, name text);
create table accounts (account_id int primary key, user_id int, account_type text);
insert into users values (1, 'Ana'), (2, 'Ben'), (3, 'Cara'), (4, 'Dev'), (5, 'Eli');
insert into accounts values
  (101, 1, 'checking'), (102, 1, 'savings'), (103, 2, 'checking'),
  (104, 3, 'checking'), (106, 5, 'savings');
```

**Predict:** how many rows, and which users are missing?
```sql
select u.user_id, a.account_id
from users u
left join accounts a on a.user_id = u.user_id
where a.account_type = 'checking';
```

**Check yourself:** you can rewrite it so all 5 users appear, with their checking account if they have one.

### R4. NOT IN and a null (3 min)
**What this tests:** the most common null trap in SQL interviews.

**Setup**
```sql
drop table if exists transactions; drop table if exists accounts;
create table accounts (account_id int primary key, user_id int);
create table transactions (txn_id int primary key, account_id int, amount numeric(10,2));
insert into accounts values (101, 1), (102, 1), (103, 2), (106, 5);
insert into transactions values (1, 101, -50), (2, 102, 300), (3, 103, -75), (4, null, -10);
```

**Predict:** this asks for accounts with no transactions. What does it return?
```sql
select account_id from accounts
where account_id not in (select account_id from transactions);
```

**Check yourself:** you can write a version that returns the right account.

### R5. March by BETWEEN (2 min)
**What this tests:** date boundaries on timestamps.

**Setup**
```sql
drop table if exists transactions;
create table transactions (txn_id int primary key, created_at timestamp, amount numeric(10,2));
insert into transactions values
  (1, '2026-03-01 00:00:00', 10), (2, '2026-03-15 12:00:00', 20),
  (3, '2026-03-31 00:00:00', 30), (4, '2026-03-31 18:45:00', 40), (5, '2026-04-01 00:00:00', 50);
```

**Find the bug:** this should total March.
```sql
select sum(amount) from transactions
where created_at between '2026-03-01' and '2026-03-31';
```

**Check yourself:** your fix includes every moment of March 31 and nothing from April.

### R6. Filtering a window function (2 min)
**What this tests:** the order SQL runs its clauses, and a Databricks habit that breaks.

**Setup**
```sql
drop table if exists transactions;
create table transactions (txn_id int primary key, user_id int, created_at timestamp);
insert into transactions values
  (1, 1, '2026-03-01 10:00'), (2, 1, '2026-04-01 10:00'), (3, 2, '2026-03-25 10:00');
```

**Find the bug:** both of these fail in Postgres. Why?
```sql
select * from transactions
where row_number() over (partition by user_id order by created_at desc) = 1;

select * from transactions
qualify row_number() over (partition by user_id order by created_at desc) = 1;
```

**Databricks vs Postgres:** `qualify` works in Databricks, not in Postgres.

**Check yourself:** you can fix it two ways in Postgres.

### R7. Where do nulls sort? (2 min)
**What this tests:** a sorting default that is the **opposite** of Databricks.

**Setup**
```sql
drop table if exists payments;
create table payments (payment_id int primary key, amount numeric(10,2));
insert into payments values (1, 25), (2, 100), (3, null), (4, 60);
```

**Predict:** "What's our largest payment?"
```sql
select payment_id, amount from payments order by amount desc limit 1;
```

**Check yourself:** you know Postgres's default null position for `asc` and `desc`, and how to override it.

### R8. Date arithmetic (3 min)
**What this tests:** what Postgres returns when you add and subtract dates.

**Setup:** none.

**Predict the value and type of each:**
```sql
select date '2026-03-01' + 7                           as a,
       date '2026-03-01' + interval '7 days'           as b,
       date '2026-03-31' - date '2026-03-01'           as c,
       timestamp '2026-03-02 12:00' - timestamp '2026-03-01 09:00' as d,
       date_trunc('month', date '2026-03-15')          as e;
```

**Databricks vs Postgres:** no `date_add` or `datediff` in Postgres. You use `+`, `-` and intervals.

**Check yourself:** you can get the number of days between two timestamps as an integer.

---

## Part 2: Joins

### J1. Every user's March spend (8 min)
**What this tests:** where a filter goes in a left join.

**Scenario:** Marketing wants every user with their March 2026 spend, including users who spent nothing (show 0).

**Setup**
```sql
drop table if exists transactions; drop table if exists accounts; drop table if exists users;
create table users (user_id int primary key, name text);
create table accounts (account_id int primary key, user_id int);
create table transactions (txn_id int primary key, account_id int, created_at timestamp,
                           amount numeric(10,2), status text);
insert into users values (1, 'Ana'), (2, 'Ben'), (3, 'Cara'), (4, 'Dev'), (5, 'Eli');
insert into accounts values (101, 1), (102, 1), (103, 2), (104, 3), (106, 5);
insert into transactions values
  (1, 101, '2026-03-01 10:00',   -50, 'posted'),
  (2, 101, '2026-03-02 12:00',  -100, 'posted'),
  (3, 101, '2026-03-05 09:00',  1000, 'posted'),
  (4, 103, '2026-03-03 18:00',   -75, 'posted'),
  (5, 103, '2026-03-03 18:01',   -75, 'declined'),
  (6, 104, '2026-03-10 08:00',  -200, 'posted'),
  (7, 101, '2026-04-01 10:00',   -60, 'posted'),
  (8, 103, '2026-03-25 10:00',  -500, 'posted');
```

**Your task:** `user_id, march_spend` for all 5 users, sorted by `user_id`.

**Clarify first:** declined transactions and deposits don't count.

**Hints:**
1. Put the filters in `WHERE` first. Who disappears?
2. Filters on the table you left-join to belong in its `ON`.

**Check yourself:** 5 rows; users with no spend show 0, not null.

### J2. Spend and refunds per user (10 min)
**What this tests:** fan-out when two "many" tables meet.

**Scenario:** Finance wants total spend and total refunded per user, side by side.

**Setup**
```sql
drop table if exists refunds; drop table if exists transactions; drop table if exists accounts;
create table accounts (account_id int primary key, user_id int);
create table transactions (txn_id int primary key, account_id int, amount numeric(10,2), status text);
create table refunds (refund_id int primary key, txn_id int, amount numeric(10,2));
insert into accounts values (101, 1), (102, 1), (103, 2), (104, 3);
insert into transactions values
  (1, 101, -50, 'posted'), (2, 101, -100, 'posted'), (3, 102, -10, 'posted'),
  (4, 103, -75, 'posted'), (5, 103, -500, 'posted'),
  (6, 104, -200, 'posted'), (7, 104, -20, 'posted');
insert into refunds values (1, 6, 50), (2, 6, 30), (3, 1, 50);
```

**Your task:** `user_id, spend, refunded` (0 if none), one row per user, sorted by `user_id`.

**Hints:**
1. Join transactions to refunds directly and look at transaction 6.
2. Get each measure to one row per user before combining.

**Check yourself:** each user's spend equals what a query that ignores refunds returns.

### J3. Users with no activity, users with travel (8 min)
**What this tests:** anti-joins and semi-joins.

**Setup**
```sql
drop table if exists transactions; drop table if exists users;
create table users (user_id int primary key, name text);
create table transactions (txn_id int primary key, user_id int, category text, status text);
insert into users values (1, 'Ana'), (2, 'Ben'), (3, 'Cara'), (4, 'Dev'), (5, 'Eli');
insert into transactions values
  (1, 1, 'grocery', 'posted'), (2, 2, 'travel', 'posted'), (3, 3, 'travel', 'posted'),
  (4, 3, 'travel', 'posted'), (5, 4, 'travel', 'declined'), (6, null, 'dining', 'pending');
```

**Your task:**
- (a) Users with **no** transactions at all: `user_id, name`.
- (b) Users with at least one **posted** travel transaction, each once: `user_id, name`.

**Databricks vs Postgres:** no `left anti join` or `left semi join`. Use `not exists` and `exists`.

**Hints:**
1. For (a), why is `not in` risky with this data?
2. For (b), a plain join returns one user twice. Why?

**Check yourself:** no user appears twice, and you didn't need `distinct`.

### J4. Who referred whom (8 min)
**What this tests:** self-joins and counting zeros.

**Setup**
```sql
drop table if exists users;
create table users (user_id int primary key, name text, referred_by int);
insert into users values
  (1, 'Ana', null), (2, 'Ben', 1), (3, 'Cara', 1), (4, 'Dev', 9), (5, 'Eli', null);
```

**Your task:**
- (a) Every user with their referrer's name (null if none or unknown).
- (b) How many people each user referred, including zero.

**Hints:**
1. One table, two roles: give each an alias.
2. What does `count(*)` return for a user who referred nobody?

**Check yourself:** both results have 5 rows.

### J5. Fee per transaction (8 min)
**What this tests:** joining on a range, and boundary values.

**Setup**
```sql
drop table if exists fee_tiers; drop table if exists transactions;
create table transactions (txn_id int primary key, amount numeric(10,2));
create table fee_tiers (tier int primary key, min_amt numeric(12,2), max_amt numeric(12,2), fee_pct numeric(5,2));
insert into transactions values (1, -50), (2, -100), (3, -75), (4, -200), (5, -500), (6, -499.99);
insert into fee_tiers values (1, 0, 100, 1.00), (2, 100, 500, 0.50), (3, 500, 1000000000, 0.25);
-- min_amt is included, max_amt is excluded
```

**Your task:** `txn_id, debit, tier, fee` (fee rounded to cents), then the total fees.

**Hints:**
1. The join condition is a range, not an equality.
2. Which transaction sits exactly on a boundary? How many tiers does `between` match?

**Check yourself:** exactly one row per transaction.

---

## Part 3: Aggregation

### A1. Payment success rate per user (8 min)
**What this tests:** conditional counts with `FILTER`, and safe division.

**Scenario:** Risk wants each user's payment outcomes.

**Setup**
```sql
drop table if exists payments;
create table payments (payment_id int primary key, user_id int, created_at timestamp,
                       amount numeric(10,2), status text);
insert into payments values
  (1, 1, '2026-03-01 10:00',  25, 'success'),
  (2, 1, '2026-03-02 11:00',  40, 'failed'),
  (3, 1, '2026-03-02 11:01',  40, 'success'),
  (4, 2, '2026-03-05 09:00', 100, 'failed'),
  (5, 2, '2026-03-05 09:02', 100, 'failed'),
  (6, 2, '2026-03-06 12:00', 100, 'success'),
  (7, 3, '2026-03-10 08:00',  60, 'pending'),
  (8, 3, '2026-02-20 08:00',  15, 'failed'),
  (9, 4, '2026-03-12 13:00',  30, 'success'),
  (10, 2, '2026-03-20 15:00', null, 'failed');
```

**Your task:** per user: `user_id, successes, failures, pending, success_rate_pct`. Success rate = successes ÷ (successes + failures), as a percent with 1 decimal. Pending doesn't count. Sort by `user_id`.

**Databricks vs Postgres:** `count_if(...)` becomes `count(*) filter (where ...)`.

**Hints:**
1. One `group by`, with a `filter` on each count.
2. What does `1 / 3` return in Postgres?

**Check yourself:** 4 rows; every rate is between 0 and 100.

### A2. Users with repeated failures (5 min)
**What this tests:** `HAVING` vs `WHERE`.

**Setup:** same as A1.

**Your task:** users with **2 or more failed** payments in **March 2026**: `user_id, failures`.

**Hints:**
1. Which condition filters rows, and which filters groups?

**Check yourself:** every user returned has at least 2 failures, all in March.

### A3. Possible duplicate charges (10 min)
**What this tests:** comparing a row with the previous one (`LAG`) or a self-join on a time window.

**Scenario:** Support suspects the card network sometimes sends the same charge twice. Flag a charge if the **same user** had a charge at the **same merchant** for the **same amount** up to **60 seconds earlier**.

**Setup**
```sql
drop table if exists card_txns;
create table card_txns (txn_id int primary key, user_id int, created_at timestamp,
                        amount numeric(10,2), merchant text);
insert into card_txns values
  (1, 1, '2026-03-01 10:00:00', 25, 'Cafe'),
  (2, 1, '2026-03-01 10:00:40', 25, 'Cafe'),
  (3, 1, '2026-03-01 10:05:00', 25, 'Cafe'),
  (4, 2, '2026-03-02 09:00:00', 60, 'Grocer'),
  (5, 2, '2026-03-02 09:01:00', 60, 'Grocer'),
  (6, 2, '2026-03-02 09:00:30', 15, 'Grocer'),
  (7, 3, '2026-03-03 12:00:00', 80, 'Air'),
  (8, 4, '2026-03-03 12:00:20', 80, 'Air'),
  (9, 1, '2026-03-01 10:00:50', 25, 'Cafe');
```

**Your task:** `txn_id, user_id, created_at, seconds_since_previous` for flagged charges, sorted by `txn_id`.

**Clarify first:** exactly 60 seconds counts as a duplicate.

**Hints:**
1. Which columns define "the same charge"? Those go in `partition by`.
2. Subtracting timestamps gives an interval. `extract(epoch from ...)` turns it into seconds.

**Check yourself:** no flagged charge is more than 60 seconds after the one before it.

---

## Part 4: Window functions

### W1. Latest transaction per user (8 min)
**What this tests:** top-1 per group, ties, and a Postgres-only shortcut.

**Setup**
```sql
drop table if exists transactions;
create table transactions (txn_id int primary key, user_id int, created_at timestamp, amount numeric(10,2));
insert into transactions values
  (1, 1, '2026-03-01 10:00',  -50), (2, 1, '2026-04-01 10:00',  -60),
  (3, 2, '2026-03-25 10:00', -500), (4, 2, '2026-02-14 19:00',  -60),
  (5, 3, '2026-03-10 08:00', -200), (6, 3, '2026-03-10 08:00',  -20),
  (7, null, '2026-03-20 15:00', -10), (8, 4, '2026-03-12 13:00', -40);
```

**Your task:** each user's latest transaction: `user_id, txn_id, created_at`. If two tie on time, keep the larger amount (more money). Ignore rows with no user. Write it two ways: `row_number` in a CTE, and `distinct on`.

**Databricks vs Postgres:** no `qualify`; `distinct on` is Postgres-only.

**Hints:**
1. Which user has a tie?
2. `distinct on (user_id)` keeps the first row per user by the `order by`. What must the `order by` start with?

**Check yourself:** exactly one row per user, and both versions agree.

### W2. Running account balance (10 min)
**What this tests:** running totals, and the default window frame trap.

**Setup**
```sql
drop table if exists ledger;
create table ledger (entry_id int primary key, account_id int, created_at timestamp, amount numeric(10,2));
insert into ledger values
  (1, 101, '2026-03-01 09:00', 1000), (2, 101, '2026-03-02 10:00', -200),
  (3, 101, '2026-03-02 10:00',  -50), (4, 101, '2026-03-05 12:00',  300),
  (5, 102, '2026-03-01 08:00',  500), (6, 102, '2026-03-03 08:00', -500),
  (7, 102, '2026-03-04 08:00',  -20);
```

**Your task:**
- (a) `account_id, entry_id, created_at, amount, balance`: the balance after each entry, in time order (ties by `entry_id`).
- (b) Accounts that ever went negative, with the first entry that did it.

**Hints:**
1. Write `sum(amount) over (partition by account_id order by created_at)` first and look at entries 2 and 3.
2. When a window has `order by` and no frame, which frame does SQL use?

**Check yourself:** every balance equals the previous balance plus the entry's amount.

### W3. Top merchants: ROW_NUMBER, RANK, DENSE_RANK (8 min)
**What this tests:** how the three ranking functions treat ties.

**Setup**
```sql
drop table if exists card_txns;
create table card_txns (txn_id int primary key, merchant text, amount numeric(10,2));
insert into card_txns values
  (1, 'Cafe', 200), (2, 'Cafe', 100), (3, 'Grocer', 300), (4, 'Air', 250),
  (5, 'Books', 60), (6, 'Books', 40), (7, 'Gas', 100);
```

**Your task:**
- (a) Spend per merchant with all three rankings side by side.
- (b) "Top 3 merchants." Return what each function would give, and say which one you'd use and why.

**Hints:**
1. Aggregate first, then rank.
2. Postgres also has `fetch first 3 rows with ties`.

**Check yourself:** you can explain why the three versions return different row counts.

### W4. Moving average with a missing day (12 min)
**What this tests:** `ROWS` vs `RANGE` frames, and filling gaps.

**Setup**
```sql
drop table if exists daily_spend;
create table daily_spend (day date primary key, spend numeric(10,2));
insert into daily_spend values
  ('2026-03-01', 100), ('2026-03-02', 50), ('2026-03-04', 70),
  ('2026-03-05', 30), ('2026-03-08', 200), ('2026-03-09', 40);
-- days with no row had no spend
```

**Your task:** a 3-day moving average (that day and the 2 days before), three ways, side by side for each day in the table:
- `rows_avg`: using `rows between 2 preceding and current row`
- `range_avg`: using `range between interval '2 days' preceding and current row`
- `filled_avg`: after filling missing days with 0

Then say which is right for "average daily spend over the last 3 days".

**Hints:**
1. `rows` counts rows; `range` counts calendar time. What happens around Mar 3?
2. Missing days had **no spend**. Does `range` treat them as 0, or ignore them?
3. `generate_series` builds every date.

**Check yourself:** on Mar 4, all three values are different.

### W5. Monthly active users and month-over-month change (12 min)
**What this tests:** distinct counts per month, `LAG`, and a month with no data.

**Setup**
```sql
drop table if exists activity;
create table activity (user_id int, activity_date date);
insert into activity values
  (1, '2026-01-03'), (1, '2026-01-20'), (2, '2026-01-15'),
  (1, '2026-03-02'), (2, '2026-03-10'), (3, '2026-03-11'), (3, '2026-03-25'),
  (4, '2026-04-01'), (1, '2026-04-05');
```

**Your task:** `month, mau, prev_mau, change, pct_change` for January to April 2026. Months with no activity show 0. Percent change with 1 decimal; null when last month was 0.

**Hints:**
1. Where's February? What does `lag` compare March with if February is missing?
2. Build all four months with `generate_series`, then attach the counts.
3. Division by zero raises an error in Postgres. How do you avoid it?

**Check yourself:** 4 rows; February shows 0.

### W6. Active this month, not last month (8 min)
**What this tests:** comparing two sets of users.

**Setup:** same as W5.

**Your task:** users active in April 2026 who were **not** active in March 2026. Write it twice: with `not exists`, and with `except`.

**Hints:**
1. Each month's active users is a set; you want April minus March.

**Check yourself:** both versions return the same users.

### W7. Fill missing days in daily totals (8 min)
**What this tests:** `generate_series` to create a date spine.

**Scenario:** A daily revenue chart must show every day in March 1 to 7, with 0 on days with no sales.

**Setup**
```sql
drop table if exists sales;
create table sales (sale_id int primary key, created_at timestamp, amount numeric(10,2));
insert into sales values
  (1, '2026-03-01 10:00', 50), (2, '2026-03-01 15:00', 30), (3, '2026-03-02 09:00', 20),
  (4, '2026-03-04 12:00', 70), (5, '2026-03-07 18:00', 40), (6, '2026-03-07 23:59:59', 10);
```

**Your task:** `day, total` for every day March 1 to 7, sorted by day.

**Databricks vs Postgres:** `explode(sequence(...))` becomes `generate_series(...)`.

**Hints:**
1. `generate_series` over dates returns timestamps. Cast to `date`.
2. Group sales by `created_at::date`, then left join onto the series.

**Check yourself:** 7 rows; the totals add up to the sum of all sales.

---

## Part 5: Modeling and performance

### D1. Design the tables (15 min, whiteboard or SQL)
**What this tests:** keys, one-to-many relationships, constraints and normalization. Karat may use the whiteboard for this.

**Scenario:** design tables for a payments app: **users** own **accounts**; each account can have several **cards**; **transactions** happen on an account, sometimes with a card, at a **merchant**.

**Your task:**
1. Name the tables, their primary keys and foreign keys.
2. Say which relationships are one-to-many.
3. Write the `create table` statements with `primary key`, `references`, `not null`, `unique` and one `check` constraint.
4. Insert one valid row per table, then try a transaction for an account that doesn't exist and confirm it's rejected.

**Hints:**
1. Where should a merchant's name live: on every transaction, or in its own table? Why?
2. A card number must be unique across the whole app.

**Check yourself:** the bad insert fails with a foreign key error.

### O1. Make a slow query fast (12 min)
**What this tests:** indexes and query plans. Unlike Databricks, Postgres uses **indexes**, and `explain analyze` is your query profile.

**Setup** (100,000 rows, so the plan changes when you add an index)
```sql
drop table if exists transactions;
create table transactions (txn_id int primary key, user_id int, created_at timestamp,
                           amount numeric(10,2), status text);
insert into transactions
select g, g % 5000, timestamp '2026-01-01' + (g % 120) * interval '1 day' + (g % 1440) * interval '1 minute',
       -((g % 300) + 1), case when g % 10 = 0 then 'declined' else 'posted' end
from generate_series(1, 100000) as g;
analyze transactions;
```

**The slow query:**
```sql
explain analyze
select *
from transactions
where user_id = 42
  and date_trunc('month', created_at) = '2026-03-01'
  and lower(status) = 'posted';
```

**Your task:**
1. Run it and read the plan. What kind of scan is it?
2. List what makes it slow.
3. Add the right index and rewrite the query so it can use it. Run `explain analyze` again and compare.

**Hints:**
1. Which column has the most selective filter?
2. A function wrapped around a column usually stops an index from being used.

**Check yourself:** the new plan uses your index, and the result has the same rows as before.

### O2. Talk track: "This query got slow" (5 min, out loud)
**What this tests:** a calm, structured answer. You're scored on structure.

**The prompt:** "A report query on Postgres used to take 2 seconds. Now it takes 2 minutes. What do you do?"

**Your task:** answer out loud in under 2 minutes.

**Hints:**
1. What changed: data size, the query, indexes, or table statistics?
2. `explain analyze` tells you where the time goes.

**Check yourself:** your answer has a clear order and ends with "measure again".

---

## Part 6: Mock round (40 min, out loud)

### M1. Karat-style progressive question
**What this tests:** everything, the way Karat asks it: one schema, parts that get harder. Getting through more parts beats perfecting one.

**How to run it:** 40-minute timer, talk out loud, clarify before each part, no answer key until the end.

**Setup**
```sql
drop table if exists transactions; drop table if exists accounts; drop table if exists users;
create table users (user_id int primary key, name text, signup_date date, state text);
create table accounts (account_id int primary key, user_id int, opened_on date);
create table transactions (txn_id int primary key, account_id int, created_at timestamp,
                           amount numeric(10,2), status text, category text);
insert into users values
  (1, 'Ana', '2026-01-05', 'NY'), (2, 'Ben', '2026-01-20', 'NJ'), (3, 'Cara', '2026-02-02', 'NY'),
  (4, 'Dev', '2026-02-15', 'CT'), (5, 'Eli', '2026-03-01', 'NY');
insert into accounts values
  (101, 1, '2026-01-05'), (102, 1, '2026-01-10'), (103, 2, '2026-01-21'),
  (104, 3, '2026-02-03'), (105, 6, '2026-02-20'), (106, 5, '2026-03-02');
insert into transactions values
  (1, 101, '2026-03-01 10:00',  -50, 'posted', 'grocery'),
  (2, 101, '2026-03-02 12:00', -100, 'posted', 'dining'),
  (3, 101, '2026-03-05 09:00', 1000, 'posted', 'payroll'),
  (4, 103, '2026-03-03 18:00',  -75, 'posted', 'grocery'),
  (5, 103, '2026-03-03 18:01',  -75, 'declined', 'grocery'),
  (6, 104, '2026-03-10 08:00', -200, 'posted', 'travel'),
  (7, 102, '2026-03-15 11:00',  300, 'posted', 'transfer'),
  (8, 105, '2026-03-12 13:00',  -40, 'posted', 'dining'),
  (9, null, '2026-03-20 15:00', -10, 'pending', 'dining'),
  (10, 101, '2026-04-01 10:00', -60, 'posted', 'grocery'),
  (11, 104, '2026-03-10 08:00', -20, 'posted', 'travel'),
  (12, 103, '2026-03-25 10:00', -500, 'posted', 'travel'),
  (13, 102, '2026-04-02 09:00', -10, 'posted', 'dining'),
  (14, 103, '2026-02-14 19:00', -60, 'posted', 'grocery'),
  (15, 104, '2026-01-28 12:00', -30, 'posted', 'grocery');
```

**Part 1 (5 min):** total spend and number of posted debits per category, highest spend first.

**Part 2 (5 min):** total spend per user **state**. One account belongs to a user who isn't in `users`. What do you do with that spend?

**Part 3 (8 min):** for each user in `users`: number of accounts, number of posted debits, total spend. Users with nothing still appear with zeros.

**Part 4 (10 min):** for each user: signup date, date of first posted debit, and days between them. Anything odd?

**Part 5 (12 min):** each user's spend rank within their state (ties share a rank) and their share of the state's total spend, as a percent with 1 decimal. Only users with spend.

---

## Quick-fire questions

Answer each out loud in about 30 seconds. Answers are at the end of `2_answers.md`.

1. Inner join vs left join?
2. What changes if a right-table filter moves from `ON` to `WHERE` in a left join?
3. What are a semi-join and an anti-join, and how do you write them in Postgres?
4. Why avoid `not in` with a subquery?
5. `union` vs `union all`?
6. `where` vs `having`?
7. What is a correlated subquery, and when would you replace it?
8. CTE vs subquery?
9. Window function vs `group by`?
10. `row_number` vs `rank` vs `dense_rank`?
11. `count(*)` vs `count(col)` vs `count(distinct col)`?
12. How do aggregates treat nulls?
13. Is `null = null` true?
14. What is fan-out, and how do you prevent it?
15. In what order does SQL run its clauses?
16. `rows` vs `range` in a window frame?
17. What is the default window frame when you use `order by`?
18. What is an index?
19. In a two-column index, which column goes first?
20. When won't Postgres use an index?
21. `explain` vs `explain analyze`?
22. What is normalization?
23. When would you denormalize?
24. Primary key vs foreign key?
25. How do you model a one-to-many relationship?
26. What does ACID mean?
27. OLTP vs OLAP?
28. View vs materialized view?
29. How do you deduplicate rows?
30. How do you upsert in Postgres?
