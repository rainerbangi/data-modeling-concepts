# 2. Answers (PostgreSQL)

Run each answer under its drill's setup. All were tested on PostgreSQL. Each gives the answer, the trap, expected results and likely follow-up questions.

---

## Part 1: Read it first

### R1. Three kinds of count

**Answer:** `5 | 3 | 2`.
- `count(*)` counts rows: 5.
- `count(referred_by)` skips nulls: 1, 1, 9 = 3.
- `count(distinct referred_by)` also removes repeats: 1, 9 = 2.

**Say it:** "`count(*)` counts rows, `count(column)` skips nulls, `count(distinct column)` also removes repeats."

### R2. Division and rounding

**Answer:** `a = 2`, `b = 2.5000000000000000`, `c = 1.5000000000000000`. And `round(2.5::float8, 1)` **fails**: Postgres has no two-argument `round` for `double precision`.

- `5 / 2` is integer division because both sides are integers. Databricks would return 2.5.
- `avg` of integers returns `numeric`, so it's safe.
- `round(x, n)` needs `numeric`. Cast first: `round(x::numeric, 1)`.

**A safe percentage in Postgres:**
```sql
select round(100.0 * 1 / nullif(3, 0), 1) as pct;   -- 33.3
```
`100.0` makes it numeric; `nullif` avoids a division-by-zero error.

### R3. A left join with a WHERE filter

**Answer:** 3 rows: (1, 101), (2, 103), (3, 104). Users 4 (no account) and 5 (savings only) are missing. Their `a.account_type` is null or not 'checking', so `WHERE` throws them out, which turns the left join into an inner join.

**Fix:** move the filter into the `ON`.
```sql
select u.user_id, a.account_id
from users u
left join accounts a on a.user_id = u.user_id
                    and a.account_type = 'checking'
order by u.user_id;
```
**Expected:** 5 rows; users 4 and 5 have a null `account_id`.

### R4. NOT IN and a null

**Answer:** **no rows.** The subquery returns a null (transaction 4). `106 not in (101, 102, 103, null)` is "unknown", never true, so every row is filtered out.

**Fix:**
```sql
select a.account_id
from accounts a
where not exists (select 1 from transactions t where t.account_id = a.account_id);
```
**Expected:** 106.

**Follow-up:** *"Could you keep `not in`?"* Only with `where account_id is not null` inside the subquery. `not exists` is safer and clearer.

### R5. March by BETWEEN

**Bug:** `'2026-03-31'` compared with a timestamp means **midnight** at the start of March 31, so transaction 4 (18:45) is missed. The buggy query returns 60.

**Fix:** a half-open range.
```sql
select sum(amount) from transactions
where created_at >= '2026-03-01'
  and created_at <  '2026-04-01';
```
**Expected:** 100.

### R6. Filtering a window function

**Why it fails:** `where` runs **before** window functions, so `row_number()` doesn't exist yet. The second query fails because Postgres has no `qualify`.

**Fix 1: CTE, then filter.**
```sql
with ranked as (
  select *, row_number() over (partition by user_id order by created_at desc) as rn
  from transactions
)
select txn_id, user_id, created_at from ranked where rn = 1 order by user_id;
```
**Fix 2: Postgres's `distinct on`.**
```sql
select distinct on (user_id) txn_id, user_id, created_at
from transactions
order by user_id, created_at desc;
```
**Expected (both):** transaction 2 for user 1, transaction 3 for user 2.

### R7. Where do nulls sort?

**Answer:** payment 3 with a **null** amount. In Postgres, nulls count as **larger** than any value: they come **last** in `asc` and **first** in `desc`. Databricks does the opposite (nulls first in `asc`, last in `desc`).

**Fix:**
```sql
select payment_id, amount from payments
order by amount desc nulls last
limit 1;
```
**Expected:** payment 2, amount 100.

### R8. Date arithmetic

| Column | Value | Type |
|---|---|---|
| a | `2026-03-08` | `date` (date + integer = date) |
| b | `2026-03-08 00:00:00` | `timestamp` (date + interval = timestamp) |
| c | `30` | `integer` (date − date = days) |
| d | `1 day 03:00:00` | `interval` (timestamp − timestamp) |
| e | `2026-03-01 00:00:00` plus a time zone offset, such as `-05` | `timestamp with time zone` (`date_trunc` on a date) |

**Days between two timestamps as an integer:** cast to dates and subtract.
```sql
select timestamp '2026-03-02 12:00'::date - timestamp '2026-03-01 09:00'::date as days;  -- 1
```

**Watch out:** `date_trunc('month', some_date)` returns a timestamp with a time zone. Add `::date` when you want a date.

---

## Part 2: Joins

### J1. Every user's March spend

**The trap:** `where t.status = 'posted'` drops users 4 and 5, because after the left join their `t.status` is null.

```sql
select u.user_id,
       coalesce(sum(-t.amount), 0) as march_spend
from users u
left join accounts a     on a.user_id = u.user_id
left join transactions t on t.account_id = a.account_id
                        and t.status = 'posted'
                        and t.amount < 0
                        and t.created_at >= '2026-03-01'
                        and t.created_at <  '2026-04-01'
group by u.user_id
order by u.user_id;
```
**Expected:** 1: 150, 2: 575, 3: 200, 4: 0, 5: 0.

**Follow-ups:**
- *"Why not `extract(month from created_at) = 3`?"* It matches March of every year, and a function on the column stops an index from being used.
- *"Why coalesce to 0?"* No spend is a real zero. For something like a balance, missing would mean unknown, and I'd leave it null.

### J2. Spend and refunds per user

**The trap:** transaction 6 has two refunds. Joining transactions to refunds makes it two rows, so its 200 is counted twice.

```sql
with spend as (
  select a.user_id, sum(-t.amount) as spend
  from transactions t
  join accounts a on a.account_id = t.account_id
  where t.status = 'posted' and t.amount < 0
  group by a.user_id
),
refunded as (
  select a.user_id, sum(r.amount) as refunded
  from refunds r
  join transactions t on t.txn_id = r.txn_id
  join accounts a     on a.account_id = t.account_id
  group by a.user_id
)
select s.user_id, s.spend, coalesce(r.refunded, 0) as refunded
from spend s
left join refunded r on r.user_id = s.user_id
order by s.user_id;
```
**Expected:** 1: 160 / 50, 2: 575 / 0, 3: 220 / 80.

**Follow-up:** *"How would you catch this in production?"* A test that each output key appears once, and a reconciliation test: the total in the result equals the total in the source.

#### A result looks wrong: three checks

**1. Do the rows match what one row should mean?** If the answer is "one row per user", these two numbers must be equal:
```sql
select count(*) as total_rows, count(distinct user_id) as users
from ( /* your query, without the final semicolon */ ) q;
```
More rows than users means a join copied some users.

**2. Which join did it?** Count rows after each step. The count jumps at the join that copies. Example from drill J2:

| Step | Rows | What it means |
|---|---|---|
| transactions | 7 | one row per transaction |
| + accounts | 7 | still one per transaction: each belongs to one account. Fine |
| + refunds | 8 | transaction 6 has 2 refunds, so it now appears **twice** |

**3. Does a total match the source table?** Compare with the raw sum:
```sql
select sum(-amount) from transactions where status = 'posted' and amount < 0;   -- 955
```
In J2, summing spend after joining refunds gives 1,155: transaction 6's 200 was counted twice.

**How to fix it:**
- **Aggregate first, then join.** Total refunds per user in their own CTE, then join that one row per user.
- **Deduplicate the lookup table.** Keep one row per key with `row_number()` or `distinct on`.
- **Check the join condition.** A missing column in `on` matches far too many rows.

### J3. Users with no activity, users with travel

```sql
-- (a) anti-join
select u.user_id, u.name
from users u
where not exists (select 1 from transactions t where t.user_id = u.user_id)
order by u.user_id;

-- (b) semi-join
select u.user_id, u.name
from users u
where exists (select 1 from transactions t
              where t.user_id = u.user_id
                and t.category = 'travel'
                and t.status = 'posted')
order by u.user_id;
```
**Expected:** (a) user 5 (Eli). User 4 has a declined transaction, so it isn't "no transactions". (b) users 2 and 3.

**The traps:** in (a), `not in` would return nothing because transaction 6 has a null `user_id`. In (b), a plain join returns user 3 twice (two travel rows).

**Databricks vs Postgres:** `left anti join` becomes `not exists`; `left semi join` becomes `exists`.

### J4. Who referred whom

```sql
-- (a)
select u.user_id, u.name, r.name as referred_by_name
from users u
left join users r on r.user_id = u.referred_by
order by u.user_id;

-- (b)
select r.user_id, r.name, count(u.user_id) as referrals
from users r
left join users u on u.referred_by = r.user_id
group by r.user_id, r.name
order by r.user_id;
```
**Expected:** (a) users 2 and 3 show "Ana"; everyone else null (user 4's referrer, 9, doesn't exist). (b) user 1: 2; everyone else 0.

**Why `count(u.user_id)`:** `count(*)` would count the null row for a user with no referrals as 1.

### J5. Fee per transaction

**The trap:** transaction 2 is exactly 100. `between 0 and 100` and `between 100 and 500` both match, so it gets two fees.

```sql
select t.txn_id, -t.amount as debit, f.tier,
       round(-t.amount * f.fee_pct / 100, 2) as fee
from transactions t
join fee_tiers f
  on -t.amount >= f.min_amt
 and -t.amount <  f.max_amt
order by t.txn_id;

select sum(round(-t.amount * f.fee_pct / 100, 2)) as total_fees
from transactions t
join fee_tiers f on -t.amount >= f.min_amt and -t.amount < f.max_amt;
```
**Expected:** 6 rows. Transaction 2 (100) is tier 2, fee 0.50. Transaction 6 (499.99) is tier 2, fee 2.50. Transaction 5 (500) is tier 3, fee 1.25. Total 6.50.

---

## Part 3: Aggregation

### A1. Payment success rate per user

```sql
select user_id,
       count(*) filter (where status = 'success') as successes,
       count(*) filter (where status = 'failed')  as failures,
       count(*) filter (where status = 'pending') as pending,
       round(100.0 * count(*) filter (where status = 'success')
             / nullif(count(*) filter (where status in ('success', 'failed')), 0), 1) as success_rate_pct
from payments
group by user_id
order by user_id;
```
**Expected:**

| user | successes | failures | pending | success_rate_pct |
|---|---|---|---|---|
| 1 | 2 | 1 | 0 | 66.7 |
| 2 | 1 | 3 | 0 | 25.0 |
| 3 | 0 | 1 | 1 | 0.0 |
| 4 | 1 | 0 | 0 | 100.0 |

**The traps:** `100 * successes / total` with integers gives 66 or 0; use `100.0`. Payment 10 has a null amount, but it still counts as a failure, because we count rows, not amounts.

**Databricks vs Postgres:** `count_if(status = 'success')` becomes `count(*) filter (where status = 'success')`. `sum(case when ... then 1 else 0 end)` works in both.

### A2. Users with repeated failures

```sql
select user_id, count(*) as failures
from payments
where status = 'failed'
  and created_at >= '2026-03-01' and created_at < '2026-04-01'
group by user_id
having count(*) >= 2
order by user_id;
```
**Expected:** user 2, 3 failures.

**Say it:** "`where` filters rows before grouping; `having` filters groups after. Row conditions go in `where`, because it also means less data to group."

### A3. Possible duplicate charges

**The idea:** compare each charge with the previous charge **of the same user, merchant and amount**.

```sql
with ordered as (
  select *,
         lag(created_at) over (partition by user_id, merchant, amount
                               order by created_at) as prev_at
  from card_txns
)
select txn_id, user_id, created_at,
       extract(epoch from created_at - prev_at)::int as seconds_since_previous
from ordered
where created_at - prev_at <= interval '60 seconds'
order by txn_id;
```
**Expected:** 2 (40 seconds), 5 (60), 9 (10).

**Self-join version** (same result):
```sql
select distinct a.txn_id, a.user_id, a.created_at
from card_txns a
join card_txns b
  on  b.user_id  = a.user_id
  and b.merchant = a.merchant
  and b.amount   = a.amount
  and b.created_at <  a.created_at
  and b.created_at >= a.created_at - interval '60 seconds'
order by a.txn_id;
```

**Follow-ups:**
- *"Why isn't transaction 6 flagged?"* Different amount. Transaction 8 is a different user.
- *"Which version is better?"* `lag` reads the table once. The self-join can explode if one user has many charges in a minute, which is why it needs `distinct`.

---

## Part 4: Window functions

### W1. Latest transaction per user

```sql
-- 1. row_number in a CTE (works everywhere)
with ranked as (
  select *, row_number() over (partition by user_id
                               order by created_at desc, abs(amount) desc) as rn
  from transactions
  where user_id is not null
)
select user_id, txn_id, created_at from ranked where rn = 1 order by user_id;

-- 2. distinct on (Postgres only)
select distinct on (user_id) user_id, txn_id, created_at
from transactions
where user_id is not null
order by user_id, created_at desc, abs(amount) desc;
```
**Expected:** user 1: 2, user 2: 3, user 3: 5 (ties with 6; 5 is the larger amount), user 4: 8.

**Rules for `distinct on`:** the `order by` must **start** with the `distinct on` columns; the next columns decide which row wins.

### W2. Running account balance

**The trap:** with `order by created_at` and no frame, SQL uses `range between unbounded preceding and current row`. Rows with the **same** `created_at` are treated as one step, so entries 2 and 3 both show 750 instead of 800 and 750.

```sql
-- (a)
select account_id, entry_id, created_at, amount,
       sum(amount) over (partition by account_id
                         order by created_at, entry_id
                         rows between unbounded preceding and current row) as balance
from ledger
order by account_id, created_at, entry_id;

-- (b) first entry that took each account below zero
with balances as (
  select account_id, entry_id, created_at,
         sum(amount) over (partition by account_id order by created_at, entry_id
                           rows between unbounded preceding and current row) as balance
  from ledger
)
select distinct on (account_id) account_id, entry_id, created_at, balance
from balances
where balance < 0
order by account_id, created_at, entry_id;
```
**Expected:** (a) account 101: 1000, 800, 750, 1050. Account 102: 500, 0, −20. (b) account 102, entry 7, balance −20.

**Say it:** "For running totals I always write the frame (`rows between unbounded preceding and current row`) and add a tie-breaker to the `order by`."

### W3. Top merchants

```sql
with spend as (
  select merchant, sum(amount) as spend
  from card_txns
  group by merchant
)
select merchant, spend,
       row_number() over (order by spend desc, merchant) as row_num,
       rank()       over (order by spend desc)           as rnk,
       dense_rank() over (order by spend desc)           as dense_rnk
from spend
order by spend desc, merchant;
```
**Expected:**

| merchant | spend | row_num | rank | dense_rank |
|---|---|---|---|---|
| Cafe | 300 | 1 | 1 | 1 |
| Grocer | 300 | 2 | 1 | 1 |
| Air | 250 | 3 | 3 | 2 |
| Books | 100 | 4 | 4 | 3 |
| Gas | 100 | 5 | 4 | 3 |

**"Top 3":** `row_number <= 3` gives 3 rows (Cafe, Grocer, Air); `rank <= 3` gives the same 3; `dense_rank <= 3` gives **5** (Books and Gas share third place).

**Postgres shortcut:**
```sql
select merchant, sum(amount) as spend
from card_txns
group by merchant
order by spend desc
fetch first 3 rows with ties;
```

**Say it:** "I ask whether ties should be kept. Exactly N rows: `row_number` with a tie-breaker. N positions, ties included: `rank`."

### W4. Moving average with a missing day

```sql
with filled as (
  select d::date as day, coalesce(s.spend, 0) as spend
  from generate_series(date '2026-03-01', date '2026-03-09', interval '1 day') as d
  left join daily_spend s on s.day = d::date
),
filled_avg as (
  select day, round(avg(spend) over (order by day rows between 2 preceding and current row), 2) as filled_avg
  from filled
)
select s.day, s.spend,
       round(avg(s.spend) over (order by s.day rows between 2 preceding and current row), 2) as rows_avg,
       round(avg(s.spend) over (order by s.day
                                range between interval '2 days' preceding and current row), 2) as range_avg,
       f.filled_avg
from daily_spend s
join filled_avg f on f.day = s.day
order by s.day;
```
**Expected:**

| day | spend | rows_avg | range_avg | filled_avg |
|---|---|---|---|---|
| Mar 1 | 100 | 100.00 | 100.00 | 100.00 |
| Mar 2 | 50 | 75.00 | 75.00 | 75.00 |
| Mar 4 | 70 | 73.33 | 60.00 | 40.00 |
| Mar 5 | 30 | 50.00 | 50.00 | 33.33 |
| Mar 8 | 200 | 100.00 | 200.00 | 66.67 |
| Mar 9 | 40 | 90.00 | 120.00 | 80.00 |

**Which is right:** `filled_avg`. Missing days had no spend, so they're zeros.
- `rows` takes the last 3 **rows**, reaching back past gaps (on Mar 8 it averages Mar 4, 5 and 8).
- `range` uses the right **calendar** window but averages only the days that exist, ignoring the zeros.

### W5. Monthly active users and month-over-month change

**The trap:** without February, `lag` compares March with **January**.

```sql
with months as (
  select generate_series(date '2026-01-01', date '2026-04-01', interval '1 month')::date as month
),
mau as (
  select date_trunc('month', activity_date)::date as month,
         count(distinct user_id) as mau
  from activity
  group by 1
),
filled as (
  select m.month, coalesce(x.mau, 0) as mau
  from months m
  left join mau x on x.month = m.month
)
select month, mau,
       lag(mau) over (order by month)                                           as prev_mau,
       mau - lag(mau) over (order by month)                                     as change,
       round(100.0 * (mau - lag(mau) over (order by month))
             / nullif(lag(mau) over (order by month), 0), 1)                    as pct_change
from filled
order by month;
```
**Expected:**

| month | mau | prev_mau | change | pct_change |
|---|---|---|---|---|
| 2026-01-01 | 2 | null | null | null |
| 2026-02-01 | 0 | 2 | −2 | −100.0 |
| 2026-03-01 | 3 | 0 | 3 | null |
| 2026-04-01 | 2 | 3 | −1 | −33.3 |

**Watch out:** `date_trunc` returns a timestamp with a time zone here; `::date` makes the join to the month series clean.

### W6. Active this month, not last month

```sql
-- not exists
select distinct a.user_id
from activity a
where a.activity_date >= '2026-04-01' and a.activity_date < '2026-05-01'
  and not exists (select 1 from activity p
                  where p.user_id = a.user_id
                    and p.activity_date >= '2026-03-01' and p.activity_date < '2026-04-01')
order by a.user_id;

-- except
select user_id from activity where activity_date >= '2026-04-01' and activity_date < '2026-05-01'
except
select user_id from activity where activity_date >= '2026-03-01' and activity_date < '2026-04-01'
order by user_id;
```
**Expected:** user 4.

**Say it:** "`except` removes duplicates, like `union`. Postgres also has `except all` if duplicates matter."

### W7. Fill missing days in daily totals

```sql
select d::date as day, coalesce(sum(s.amount), 0) as total
from generate_series(date '2026-03-01', date '2026-03-07', interval '1 day') as d
left join sales s
  on s.created_at >= d
 and s.created_at <  d + interval '1 day'
group by d
order by d;
```
**Expected:** Mar 1: 80, Mar 2: 20, Mar 3: 0, Mar 4: 70, Mar 5: 0, Mar 6: 0, Mar 7: 50.

**Why join on a range, not `s.created_at::date = d::date`:** both work here, but the range lets Postgres use an index on `created_at`, while a cast on the column blocks it.

---

## Part 5: Modeling and performance

### D1. Design the tables

**Relationships:** a user has many accounts; an account has many cards and many transactions; a merchant has many transactions. A transaction may or may not use a card.

```sql
drop table if exists transactions; drop table if exists cards; drop table if exists accounts;
drop table if exists merchants; drop table if exists users;

create table users (
  user_id     bigint primary key,
  email       text not null unique,
  signup_date date not null
);

create table accounts (
  account_id   bigint primary key,
  user_id      bigint not null references users (user_id),
  account_type text   not null check (account_type in ('checking', 'savings')),
  opened_on    date   not null
);

create table cards (
  card_id     bigint primary key,
  account_id  bigint not null references accounts (account_id),
  card_number text   not null unique,
  status      text   not null check (status in ('active', 'frozen', 'closed'))
);

create table merchants (
  merchant_id bigint primary key,
  name        text not null,
  category    text not null
);

create table transactions (
  txn_id      bigint primary key,
  account_id  bigint not null references accounts (account_id),
  card_id     bigint references cards (card_id),            -- null for non-card transactions
  merchant_id bigint references merchants (merchant_id),
  created_at  timestamp not null,
  amount      numeric(12,2) not null check (amount <> 0),
  status      text not null check (status in ('posted', 'pending', 'declined'))
);

create index on transactions (account_id, created_at);

insert into users values (1, 'ana@example.com', '2026-01-05');
insert into accounts values (101, 1, 'checking', '2026-01-05');
insert into cards values (1, 101, '4111000011112222', 'active');
insert into merchants values (1, 'Cafe', 'dining');
insert into transactions values (1, 101, 1, 1, '2026-03-01 10:00', -25.00, 'posted');

-- should fail: account 999 does not exist
insert into transactions values (2, 999, null, 1, '2026-03-01 11:00', -10.00, 'posted');
```
**Expected:** the last insert fails with a foreign key violation.

**Talking points:**
- **Normalization:** the merchant's name and category live once in `merchants`, not on every transaction, so a rename is one update. That's third normal form.
- **When to denormalize:** for analytics, a wide fact table (transactions with merchant name copied in) is faster to query. Normalize where data is written, denormalize where it's read.
- **Money:** `numeric(12,2)`, never `float`, because floats can't store cents exactly.
- **Index:** foreign keys aren't indexed automatically in Postgres; index the ones you filter or join on.

### O1. Make a slow query fast

**What's slow:**
- **Sequential scan** of all 100,000 rows: there's no index on `user_id`.
- `date_trunc('month', created_at)` and `lower(status)` wrap columns in functions, so even an index on those columns couldn't be used.
- `select *` returns every column.

**Fix:**
```sql
create index idx_txn_user_created on transactions (user_id, created_at);

explain analyze
select txn_id, created_at, amount
from transactions
where user_id = 42
  and created_at >= '2026-03-01' and created_at < '2026-04-01'
  and status = 'posted';
```
**Expected:** the first plan shows `Seq Scan on transactions`. The new plan shows an `Index Scan` or `Bitmap Index Scan` using `idx_txn_user_created`, and the execution time drops. Both return the same rows.

**Why this column order:** equality column first (`user_id`), range column second (`created_at`). Postgres jumps to user 42 and reads only their March rows.

**Follow-ups:**
- *"Index everything, then?"* No. Each index slows writes and takes space. Index the columns used in frequent filters and joins.
- *"What if `status` must be case-insensitive?"* Clean it once on write, or create an expression index on `lower(status)`.

### O2. Talk track: "This query got slow"

1. **Clarify:** "Sudden or gradual? What changed: data size, the query, an index, or a deploy?"
2. **Measure:** run `explain analyze` and find the step with the most time.
3. **Common causes in Postgres:**
   - A **sequential scan** where an index should be used: a missing index, or a function on the column.
   - **Stale statistics:** row estimates far from actual rows; run `analyze`.
   - **A bad join:** a join that multiplies rows, or a nested loop over a big table.
   - **A sort or hash that spills to disk** (`external merge` in the plan): not enough `work_mem`.
   - **Locks** from another transaction, or table **bloat** after many updates (`vacuum`).
4. **Fix the biggest cause**, then **measure again** with `explain analyze`.

**Say it in one line:** "Find the slow step with `explain analyze`, fix the biggest cause, measure again."

---

## Part 6: Mock round

### M1. Part 1: spend per category
```sql
select category, sum(-amount) as spend, count(*) as debits
from transactions
where status = 'posted' and amount < 0
group by category
order by spend desc;
```
**Expected:** travel 720 (3), grocery 275 (5), dining 150 (3).

### M1. Part 2: spend per state
**Clarify:** account 105 belongs to user 6, who isn't in `users`. An inner join drops 40 of spend silently. Keep it visible as "unknown".
```sql
select coalesce(u.state, 'unknown') as state, sum(-t.amount) as spend
from transactions t
join accounts a     on a.account_id = t.account_id
left join users u   on u.user_id = a.user_id
where t.status = 'posted' and t.amount < 0
group by 1
order by spend desc;
```
**Expected:** NJ 635, NY 470, unknown 40. Total 1,145, matching Part 1.

### M1. Part 3: accounts, debits and spend per user
**The trap:** after joining transactions, `count(*)` counts transactions, not accounts.
```sql
select u.user_id,
       count(distinct a.account_id) as accounts,
       count(t.txn_id)              as posted_debits,
       coalesce(sum(-t.amount), 0)  as spend
from users u
left join accounts a     on a.user_id = u.user_id
left join transactions t on t.account_id = a.account_id
                        and t.status = 'posted' and t.amount < 0
group by u.user_id
order by u.user_id;
```
**Expected:** 1: 2 / 4 / 220, 2: 1 / 3 / 635, 3: 1 / 3 / 250, 4: 0 / 0 / 0, 5: 1 / 0 / 0.

### M1. Part 4: days from signup to first spend
```sql
with first_spend as (
  select a.user_id, min(t.created_at)::date as first_spend_date
  from transactions t
  join accounts a on a.account_id = t.account_id
  where t.status = 'posted' and t.amount < 0
  group by a.user_id
)
select u.user_id, u.signup_date, f.first_spend_date,
       f.first_spend_date - u.signup_date as days_to_first_spend
from users u
left join first_spend f on f.user_id = u.user_id
order by u.user_id;
```
**Expected:** 1: 55, 2: 25, 3: **−5**, 4: null, 5: null.

**The odd thing:** user 3's first spend (Jan 28) is **before** they signed up (Feb 2) and before account 104 opened (Feb 3). Say it: "That's a data quality issue: a backdated transaction or a wrong signup date. I'd flag it, not drop it."

**Databricks vs Postgres:** `datediff(a, b)` becomes `a - b` on dates.

### M1. Part 5: rank and share within state
```sql
with spend as (
  select u.user_id, u.state, sum(-t.amount) as spend
  from transactions t
  join accounts a on a.account_id = t.account_id
  join users u    on u.user_id = a.user_id
  where t.status = 'posted' and t.amount < 0
  group by u.user_id, u.state
)
select user_id, state, spend,
       rank() over (partition by state order by spend desc)               as state_rank,
       round(100.0 * spend / sum(spend) over (partition by state), 1)    as pct_of_state
from spend
order by state, state_rank;
```
**Expected:** NJ: user 2, rank 1, 100.0%. NY: user 3, rank 1 (250, 53.2%); user 1, rank 2 (220, 46.8%).

---

## Quick-fire answers

1. **Inner vs left join:** inner keeps matches only; left keeps every row from the left table, with nulls where nothing matched.
2. **`ON` vs `WHERE` in a left join:** `ON` decides what matches; `WHERE` filters afterwards. A right-table filter in `WHERE` turns the left join into an inner join.
3. **Semi-join vs anti-join:** semi keeps rows that have a match (`exists`); anti keeps rows that don't (`not exists`). Neither duplicates rows.
4. **`not in` with a subquery:** if the subquery returns a null, the result is empty.
5. **`union` vs `union all`:** `union` removes duplicates (costly); `union all` keeps everything. Default to `union all`.
6. **`where` vs `having`:** `where` filters rows before grouping; `having` filters groups after.
7. **Correlated subquery:** an inner query that uses the outer row, so it logically runs per row. Often better as a join or window.
8. **CTE vs subquery:** usually the same plan; CTEs are easier to read and reuse. Since Postgres 12, CTEs are inlined unless you write `materialized`.
9. **Window function vs `group by`:** `group by` collapses rows; a window adds the aggregate to each row and keeps them.
10. **`row_number` vs `rank` vs `dense_rank`:** on ties: always unique; tied with gaps after; tied with no gaps.
11. **`count(*)` vs `count(col)` vs `count(distinct col)`:** rows; non-null values; distinct non-null values.
12. **Nulls in aggregates:** `sum`, `avg`, `min`, `max`, `count(col)` skip nulls.
13. **`null = null`:** not true (unknown). Use `is null` or `is not distinct from`.
14. **Fan-out:** a one-to-many join repeats rows and inflates sums. Aggregate before joining.
15. **Order of execution:** from and joins, where, group by, having, window functions, select, distinct, order by, limit.
16. **`rows` vs `range`:** `rows` counts physical rows; `range` uses values, so ties are grouped and intervals follow the calendar.
17. **Default window frame:** with `order by` and no frame: `range between unbounded preceding and current row`. Ties are summed together.
18. **Index:** a sorted structure that lets Postgres find rows without reading the whole table. Speeds reads, slows writes.
19. **Composite index order:** equality columns first, then range columns.
20. **When an index isn't used:** a function on the column, a type mismatch, a leading wildcard (`like '%x'`), or the filter matches most rows.
21. **`explain` vs `explain analyze`:** `explain` shows the plan; `explain analyze` runs the query and shows actual times and rows.
22. **Normalization:** store each fact once (no repeated data), so updates happen in one place. 3NF: every column depends on the key, the whole key and nothing but the key.
23. **Denormalization:** copying data into wide tables to make reads faster. Common in analytics.
24. **Primary key vs foreign key:** a primary key uniquely identifies a row; a foreign key must match a primary key in another table. Postgres enforces both.
25. **One-to-many:** one user, many accounts; the foreign key lives on the "many" side (`accounts.user_id`).
26. **ACID:** Atomicity (all or nothing), Consistency (rules hold), Isolation (transactions don't see each other's half-done work), Durability (committed data survives a crash).
27. **OLTP vs OLAP:** many small reads and writes of single rows (Postgres for an app) vs large scans and aggregations (a warehouse like Databricks).
28. **View vs materialized view:** a view runs its query each time; a materialized view stores the result and needs `refresh materialized view`.
29. **Deduplicating:** `row_number() over (partition by key order by loaded_at desc)` and keep 1, or `distinct on (key)` in Postgres.
30. **Upsert in Postgres:** `insert ... on conflict (key) do update set ...`. Postgres 15+ also has `merge`.
