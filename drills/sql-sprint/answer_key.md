# SQL Sprint: Answer Key

Open only after you attempt a drill. Spend always means posted debits (`status = 'posted' and amount < 0`), shown as a positive number.

Each answer has: **the idea**, **the trap**, **think it through**, **SQL**, **expected**, and **follow-ups** an interviewer is likely to ask next, with short answers to say out loud.

---

## Part 1: Discussion warm-up

### P1. Three kinds of count

**Answer:** `5, 3, 2`.
- `count(*)` counts rows: 5 customers.
- `count(referred_by)` counts non-null values: C1, C1, C9 = 3.
- `count(distinct referred_by)` counts distinct non-null values: C1, C9 = 2.

**Say it:** "`count(*)` counts rows, `count(col)` skips nulls, `count(distinct col)` also removes repeats."

### P2. An average with a null

**Answer:** `15`. `avg` skips nulls, so it's (10 + 20) ÷ 2, not ÷ 3.

**Follow-up:** "How would you treat the null as zero?" `avg(coalesce(x, 0))` gives 10. Ask first whether null really means zero here; often it means unknown.

### P3. A left join with a WHERE filter

**Answer:** 3 rows (C1 with A1, C2 with A3, C3 with A4). Missing: C4 (no account, so `account_type` is null) and C5 (only a savings account). The `where` filter threw them out, turning the left join into an inner join.

**Fix:** move the filter into the `on` clause.

```sql
select c.customer_id, a.account_id
from s_customers c
left join s_accounts a on a.customer_id = c.customer_id
                      and a.account_type = 'checking';
```

Now all 5 customers appear; C4 and C5 have a null `account_id`.

### P4. Division

**Answer in Databricks:** `a = 3.5`, `b = 3`, `c = 3.5`. Databricks (Spark) returns a decimal or double for `/`. Postgres and SQL Server return **3** for `7 / 2`, because both sides are integers.

**Say it:** "For rates I cast one side to a decimal and wrap the denominator in `nullif(..., 0)`, so the result is right in any engine and never divides by zero."

### B1. Customers per state

**Bug 1:** after the join, one row means one **account**, not one customer. C1 has two accounts, so NY counts C1 twice.
**Bug 2:** `count(*)` counts the null row for a customer with no account (C4), so CT shows 1 instead of 0.

**Fix:** count distinct customers on the account side, which skips nulls.

```sql
select c.state, count(distinct a.customer_id) as customers_with_account
from s_customers c
left join s_accounts a on a.customer_id = c.customer_id
group by c.state
order by c.state;
```

**Expected:** CT 0, NJ 1, NY 3. (The buggy query gives CT 1, NJ 1, NY 4.)

### B2. March by BETWEEN

**Bug:** `'2026-03-31'` compared with a timestamp means **midnight** at the start of March 31, so every transaction later that day is missed.

**Fix:** a half-open range.

```sql
select sum(-amount) as march_spend
from s_transactions
where status = 'posted' and amount < 0
  and txn_ts >= timestamp'2026-03-01'
  and txn_ts <  timestamp'2026-04-01';
```

**Expected:** 985.00. (This data has no March 31 rows, so the buggy query happens to match here. That's exactly why this bug survives testing.)

### B3. Grouping

**What happens:** an error. `category` is in `select` but not in `group by` and not inside an aggregate, so the engine doesn't know which category to show for each customer.

**Two fixes, depending on the question:**
- Spend per customer **and** category: add `t.category` to `group by` (or use `group by all`).
- Spend per customer only: remove `t.category` from `select`.

### B4. Filtering a window

**Why it fails:** `where` runs before window functions, so `row_number()` doesn't exist yet when `where` is evaluated.

**Fix 1:** compute it in a subquery or CTE, then filter outside.

```sql
select account_id, txn_id, txn_ts
from (
  select *, row_number() over (partition by account_id order by txn_ts desc) as rn
  from s_transactions
)
where rn = 1;
```

**Fix 2:** in Databricks, Snowflake and BigQuery, `qualify` filters a window result inline: `... qualify row_number() over (...) = 1`.

**Watch out:** two things in this data. The row with a null `account_id` forms its own group and comes back as a "latest transaction", so add `where account_id is not null` inside the subquery. And A4 has two rows at the same time, so add a tie-breaker to the `order by` (see S1).

---

## Part 2: Joins

### J1. Join types: predict the rows

**The idea:** a join's row count is the number of matching pairs, plus the unmatched rows from any side an outer join keeps.

**Think it through:** 5 customers, 6 accounts. C1 has 2 accounts. C4 has none. A5 belongs to C6, who isn't a customer.
- **Inner:** matched pairs only: C1 ×2, C2, C3, C5 = **5**.
- **Left** (customers first): the 5 pairs plus C4 = **6**.
- **Right:** the 5 pairs plus A5 = **6**.
- **Full:** the 5 pairs plus C4 plus A5 = **7**.

```sql
select 'inner' as join_type, count(*) as n
from s_customers c join s_accounts a on a.customer_id = c.customer_id
union all
select 'left', count(*)
from s_customers c left join s_accounts a on a.customer_id = c.customer_id
union all
select 'right', count(*)
from s_customers c right join s_accounts a on a.customer_id = c.customer_id
union all
select 'full', count(*)
from s_customers c full outer join s_accounts a on a.customer_id = c.customer_id;
```

**Expected:** inner 5, left 6, right 6, full 7.

**Follow-ups:**
- *"When would you use a right join?"* Rarely; I flip the tables and use a left join so the "kept" table always reads first.
- *"What's a cross join for?"* Every left row with every right row. Useful on purpose to build a grid, such as every customer × every month (S7).

### J2. Every customer's March spend

**The idea:** a filter on the right-hand table of a left join belongs in the `ON` clause.

**The trap:** `where t.status = 'posted'` drops C4 and C5, because after the left join their `t.status` is null, and `null = 'posted'` isn't true.

**Think it through:**
1. Start from customers, because everyone must appear.
2. Left join accounts, then transactions, with every transaction filter in the transaction join's `ON`.
3. Sum spend, and turn "no spend" into 0 with `coalesce`.

```sql
select c.customer_id,
       coalesce(sum(-t.amount), 0) as march_spend
from s_customers c
left join s_accounts a     on a.customer_id = c.customer_id
left join s_transactions t on t.account_id  = a.account_id
                          and t.status = 'posted'                -- filters on the right table
                          and t.amount < 0                       --   stay in the ON clause
                          and t.txn_ts >= timestamp'2026-03-01'
                          and t.txn_ts <  timestamp'2026-04-01'  -- half-open month
group by c.customer_id
order by c.customer_id;
```

**Expected:** C1 150, C2 575, C3 220, C4 0, C5 0.

**Follow-ups:**
- *"Why not `month(txn_ts) = 3`?"* It also matches March of other years, and a function on the column stops the engine from skipping files by date.
- *"Why coalesce to 0 here?"* No spend is an event that didn't happen, so zero is the truth. For something like a balance, a missing value would mean unknown, and I'd leave it null.

### J3. Spend and refunds per customer

**The idea:** when two "many" tables hang off the same parent, aggregate each one to the output grain before joining.

**The trap:** T6 has two refunds. Joining transactions to refunds turns T6 into two rows, so its 200 is counted twice and C3's spend jumps.

**Think it through:**
1. Spend per customer (transactions → accounts).
2. Refunds per customer (refunds → transactions → accounts), separately.
3. Left join the two summaries; both are one row per customer.

```sql
with spend as (
  select a.customer_id, sum(-t.amount) as spend
  from s_transactions t
  join s_accounts a on a.account_id = t.account_id
  where t.status = 'posted' and t.amount < 0
  group by a.customer_id
),
refunds as (
  select a.customer_id, sum(r.amount) as refunded
  from s_refunds r
  join s_transactions t on t.txn_id = r.txn_id
  join s_accounts a     on a.account_id = t.account_id
  group by a.customer_id
)
select s.customer_id, s.spend, coalesce(r.refunded, 0) as refunded
from spend s
left join refunds r on r.customer_id = s.customer_id
order by s.customer_id;
```

**Expected:** C1 220 / 50, C2 635 / 0, C3 250 / 80, C6 40 / 0.

**Follow-ups:**
- *"How would you catch fan-out in production?"* A test that the output's grain is unique, plus a reconciliation test: total spend in the result equals total spend in the source.
- *"Couldn't you just use `sum(distinct ...)`?"* No. Two different transactions with the same amount would collapse into one.

### J4. Accounts with no transactions

**The idea:** "X with no Y" is an anti-join. Use `not exists` or a left join with `is null`.

**The trap:** T9 has a null `account_id`. `x not in (list containing null)` is never true, so the `not in` version returns **no rows**.

```sql
-- 1. not exists: null-safe, usually the clearest
select a.account_id, a.customer_id
from s_accounts a
where not exists (select 1 from s_transactions t where t.account_id = a.account_id);

-- 2. left join, keep the unmatched
select a.account_id, a.customer_id
from s_accounts a
left join s_transactions t on t.account_id = a.account_id
where t.txn_id is null;

-- 3. not in: returns nothing because the subquery contains a null
select account_id, customer_id
from s_accounts
where account_id not in (select account_id from s_transactions);
```

**Expected:** versions 1 and 2 return A6 (C5). Version 3 returns no rows.

**Follow-ups:**
- *"How would you make `not in` safe?"* Add `where account_id is not null` inside the subquery. But I'd rather use `not exists`.
- *"Which is fastest?"* Modern engines usually plan `not exists` and the left-join version the same way, as an anti-join. I pick `not exists` for clarity.

### J5. Customers with a travel purchase

**The idea:** "customers who have at least one Y" is a semi-join. Each customer is kept once, however many matches they have.

**The trap:** C3 has two travel transactions (T6 and T11), so a plain join returns C3 twice. Adding `distinct` hides that and does extra work.

```sql
select c.customer_id, c.name
from s_customers c
where exists (
  select 1
  from s_accounts a
  join s_transactions t on t.account_id = a.account_id
  where a.customer_id = c.customer_id
    and t.category = 'travel'
    and t.status = 'posted'
)
order by c.customer_id;
```

**Expected:** C2 Ben, C3 Cara.

**Follow-ups:**
- *"`in` vs `exists`?"* Both are semi-joins and usually plan the same. `exists` handles nulls predictably and can correlate on several columns.
- *"And with a join?"* `join` plus `distinct` works but builds all the duplicates first, then removes them.

### J6. Who referred whom

**The idea:** a table that points to itself needs a self-join with two aliases, one per role.

**The trap:** an inner self-join drops C1 and C5 (no referrer) and C4 (referrer C9 doesn't exist). In (b), `count(*)` would count 1 for a customer with no referrals.

```sql
-- (a) each customer with their referrer's name
select c.customer_id, c.name, r.name as referred_by_name
from s_customers c
left join s_customers r on r.customer_id = c.referred_by
order by c.customer_id;

-- (b) referrals made by each customer, including zero
select r.customer_id, r.name, count(c.customer_id) as referrals
from s_customers r
left join s_customers c on c.referred_by = r.customer_id
group by r.customer_id, r.name
order by r.customer_id;
```

**Expected:** (a) C2 and C3 show "Ana"; everyone else null. (b) C1 2, everyone else 0.

**Follow-ups:**
- *"How would you find C4's broken reference?"* An anti-join: customers whose `referred_by` is not null and has no matching customer. In a pipeline, that's a relationship test.
- *"What if referrals were many levels deep?"* A recursive CTE walks the chain.

### J7. Fee per transaction

**The idea:** a range join matches a value to the band that contains it. Use `>=` and `<` so a value on a boundary fits exactly one band.

**The trap:** T2 is exactly 100.00. `between 0 and 100` and `between 100 and 500` both match, so T2 gets two rows and two fees.

```sql
select t.txn_id, -t.amount as debit, f.tier,
       round(-t.amount * f.fee_pct / 100, 2) as fee
from s_transactions t
join s_fee_tiers f
  on  -t.amount >= f.min_amt
  and -t.amount <  f.max_amt
where t.status = 'posted' and t.amount < 0
order by t.txn_id;

select sum(round(-t.amount * f.fee_pct / 100, 2)) as total_fees
from s_transactions t
join s_fee_tiers f on -t.amount >= f.min_amt and -t.amount < f.max_amt
where t.status = 'posted' and t.amount < 0;
```

**Expected:** 11 rows, one per posted debit. T2 (100.00) is tier 2, fee 0.50. T12 (500.00) is tier 3, fee 1.25. Total fees 6.20.

**Follow-ups:**
- *"Is a range join slow at scale?"* It can't use a simple hash join. With a small tier table, the engine broadcasts it, which is fine. With two big tables, bucket the ranges first or use the engine's range-join hint.
- *"Same pattern elsewhere?"* Any "value in effect on a date" lookup: an exchange rate or price history (SCD2) joined on `valid_from <= date and date < valid_to`.

### J8. March spend by current segment

**The idea:** before joining, check that the key is unique on the side you expect to be "one".

**The trap:** C1 has two segment rows. Joining directly matches C1's March spend to both, so 150 shows up under standard and premium.

**Think it through:**
1. Prove the problem: `select customer_id, count(*) from s_segments group by 1 having count(*) > 1` returns C1.
2. Keep the latest segment per customer with `row_number`.
3. Aggregate March spend per customer.
4. Left join spend to the latest segment; missing segments become "unknown".

```sql
with latest_segment as (
  select customer_id, segment
  from (
    select *, row_number() over (partition by customer_id order by updated_at desc) as rn
    from s_segments
  )
  where rn = 1
),
march_spend as (
  select a.customer_id, sum(-t.amount) as spend
  from s_transactions t
  join s_accounts a on a.account_id = t.account_id
  where t.status = 'posted' and t.amount < 0
    and t.txn_ts >= timestamp'2026-03-01' and t.txn_ts < timestamp'2026-04-01'
  group by a.customer_id
)
select coalesce(s.segment, 'unknown') as segment, sum(m.spend) as spend
from march_spend m
left join latest_segment s on s.customer_id = m.customer_id
group by all
order by segment;
```

**Expected:** premium 150, standard 795, unknown 40. Total 985, the same as total March spend.

**Follow-ups:**
- *"What if they wanted the segment at the time of each transaction?"* Turn `s_segments` into SCD2 with `lead(updated_at)` as `valid_to`, then join on the transaction date with the sandwich condition.

---

## Part 3: Subqueries and window functions

### S1. Latest transaction per account

**The idea:** "latest per group" works with a correlated subquery or a window function. The window reads the table once and handles ties deliberately.

**The trap:** A4 has two transactions at exactly the same time (T6 and T11). The correlated subquery returns both.

```sql
-- 1. correlated subquery: logically runs once per row, and returns ties
select t.account_id, t.txn_id, t.txn_ts
from s_transactions t
where t.account_id is not null
  and t.txn_ts = (select max(t2.txn_ts)
                  from s_transactions t2
                  where t2.account_id = t.account_id)
order by t.account_id, t.txn_id;

-- 2. window function: one pass, exactly one row per account
select account_id, txn_id, txn_ts
from (
  select *, row_number() over (partition by account_id
                               order by txn_ts desc, abs(amount) desc) as rn  -- tie-break on purpose
  from s_transactions
  where account_id is not null
)
where rn = 1
order by account_id;
```

**Expected:** the window version returns A1 T10, A2 T13, A3 T12, A4 T6, A5 T8. The subquery version also returns T11 for A4 (6 rows).

**Follow-ups:**
- *"Which would you use?"* The window: one scan, and the tie rule is explicit. If the business wants ties, I'd use `rank` instead of `row_number`.
- *"Why add a second sort column?"* Without it, `row_number` picks one of the tied rows unpredictably, and results can change between runs.

### S2. Debits above the account's own average

**The idea:** a window aggregate puts the group's average on every row, so you can compare without collapsing rows.

**The trap:** filtering `where -amount > avg(...) over (...)` fails, because `where` runs before windows. Compute first, filter outside.

```sql
select txn_id, account_id, -amount as debit, round(avg_debit, 2) as avg_debit
from (
  select *, avg(-amount) over (partition by account_id) as avg_debit
  from s_transactions
  where status = 'posted' and amount < 0 and account_id is not null
)
where -amount > avg_debit
order by txn_id;
```

**Expected:** T12 (500 vs 211.67), T2 (100 vs 70.00), T6 (200 vs 83.33).

**Follow-ups:**
- *"Write it with a subquery instead."* `where -t.amount > (select avg(-t2.amount) from s_transactions t2 where t2.account_id = t.account_id and ...)`. Same result; the window computes each average once instead of per row.
- *"What's a better 'unusual' rule?"* Compare with the account's own history before this transaction (a running average with `rows between unbounded preceding and 1 preceding`), so a big purchase isn't part of its own baseline.

### S3. Top category per customer, keeping ties

**The idea:** top-N per group is a ranking window. `row_number`, `rank` and `dense_rank` differ only on ties.

**The trap:** C1 spent 110 on grocery and 110 on dining. `row_number` keeps one of them arbitrarily.

```sql
with cat as (
  select a.customer_id, t.category, sum(-t.amount) as spend
  from s_transactions t
  join s_accounts a on a.account_id = t.account_id
  where t.status = 'posted' and t.amount < 0
  group by all
)
select customer_id, category, spend
from (
  select *, rank() over (partition by customer_id order by spend desc) as rnk
  from cat
)
where rnk = 1
order by customer_id, category;
```

**Expected:** C1 dining 110 and grocery 110, C2 travel 500, C3 travel 220, C6 dining 40.

| Function | Spend 110, 110, 90 |
|---|---|
| `row_number` | 1, 2, 3 |
| `rank` | 1, 1, 3 |
| `dense_rank` | 1, 1, 2 |

**Follow-up:** *"Top 2 categories, but at most 2 rows per customer?"* `row_number() <= 2` with a tie-breaker. With `rank` or `dense_rank`, ties could return more than 2.

### S4. Average March spend per active customer

**The idea:** "average per customer" means aggregate per customer first, then average the totals.

**The trap:** `avg(-amount)` over transactions averages **transactions** (985 ÷ 7 = 140.71), not customers.

```sql
with per_customer as (
  select a.customer_id, sum(-t.amount) as spend
  from s_transactions t
  join s_accounts a on a.account_id = t.account_id
  where t.status = 'posted' and t.amount < 0
    and t.txn_ts >= timestamp'2026-03-01' and t.txn_ts < timestamp'2026-04-01'
  group by a.customer_id
)
select round(avg(spend), 2) as avg_spend_per_customer
from per_customer;
```

**Expected:** 246.25 (C1 150, C2 575, C3 220, C6 40).

**Follow-up:** *"Should inactive customers count as zero?"* That's a business question: "average per active customer" excludes them; "average per customer" includes them as zeros. Ask before writing.

### S5. Customers above the average

**The idea:** a scalar subquery returns one value and can sit in `where`. A CTE lets you reuse the per-customer step.

```sql
with per_customer as (
  select a.customer_id, sum(-t.amount) as spend
  from s_transactions t
  join s_accounts a on a.account_id = t.account_id
  where t.status = 'posted' and t.amount < 0
    and t.txn_ts >= timestamp'2026-03-01' and t.txn_ts < timestamp'2026-04-01'
  group by a.customer_id
)
select customer_id, spend
from per_customer
where spend > (select avg(spend) from per_customer)
order by customer_id;
```

**Expected:** C2 575.

**Follow-up:** *"Same thing with a window?"* Add `avg(spend) over ()` (an empty window means the whole result) and filter in an outer query.

### S6. One row per customer, many measures

**The idea:** conditional aggregation: one `group by`, with a `case` inside each aggregate. It replaces several separate queries and pivots values into columns.

**The trap:** `sum(case when ... then x end)` returns **null** when nothing matches. Use `else 0` for spend columns. And compute the rate from the parts.

```sql
select a.customer_id,
       count(case when t.status = 'posted'   then 1 end)                            as posted_debits,
       count(case when t.status = 'declined' then 1 end)                            as declined,
       sum(case when t.status = 'posted' and t.category = 'grocery' then -t.amount else 0 end) as grocery_spend,
       sum(case when t.status = 'posted' and t.category = 'travel'  then -t.amount else 0 end) as travel_spend,
       round(100.0 * count(case when t.status = 'declined' then 1 end)
                   / nullif(count(*), 0), 1)                                         as decline_rate
from s_transactions t
join s_accounts a on a.account_id = t.account_id
where t.amount < 0
group by a.customer_id
order by a.customer_id;
```

**Expected:**

| customer | posted_debits | declined | grocery | travel | decline_rate |
|---|---|---|---|---|---|
| C1 | 4 | 0 | 110 | 0 | 0.0 |
| C2 | 3 | 1 | 135 | 500 | 25.0 |
| C3 | 3 | 0 | 30 | 220 | 0.0 |
| C6 | 1 | 0 | 0 | 0 | 0.0 |

**Follow-ups:**
- *"Why `count(case ... then 1 end)`?"* `count` skips nulls, and a `case` with no `else` returns null, so it counts only matching rows. `sum(case ... then 1 else 0 end)` is equivalent.
- *"Databricks also has `count_if(status = 'declined')` and `pivot`."* Mention them as shortcuts; the `case` version works everywhere.

### S7. Month-over-month spend, with missing months

**The idea:** to compare consecutive months, every month must exist as a row. Build a spine (every customer × every month), attach spend, then use `lag`.

**The trap:** without the spine, C3's months are Jan and Mar only, so `lag` compares March with **January** and calls it "the previous month".

**Think it through:**
1. Months: generate Jan to Apr 2026.
2. Customers: everyone with a posted debit.
3. Spine: cross join customers × months.
4. Monthly spend per customer.
5. Left join spend onto the spine; no spend means 0.
6. `lag` over each customer's months.

```sql
with months as (
  select explode(sequence(date'2026-01-01', date'2026-04-01', interval 1 month)) as month
),
customers as (
  select distinct a.customer_id
  from s_transactions t
  join s_accounts a on a.account_id = t.account_id
  where t.status = 'posted' and t.amount < 0
),
monthly as (
  select a.customer_id, date_trunc('month', t.txn_ts) as month, sum(-t.amount) as spend
  from s_transactions t
  join s_accounts a on a.account_id = t.account_id
  where t.status = 'posted' and t.amount < 0
  group by all
),
spine as (
  select c.customer_id, m.month, coalesce(x.spend, 0) as spend
  from customers c
  cross join months m
  left join monthly x on x.customer_id = c.customer_id and cast(x.month as date) = m.month
)
select customer_id, month, spend,
       lag(spend) over (partition by customer_id order by month)          as prev_spend,
       spend - lag(spend) over (partition by customer_id order by month)  as change
from spine
order by customer_id, month;
```

**Expected (spend by month, Jan to Apr):** C1 0, 0, 150, 70. C2 0, 60, 575, 0. C3 30, 0, 220, 0. C6 0, 0, 40, 0. `change` is null only in January.

**Follow-ups:**
- *"Rolling 3-month spend?"* `sum(spend) over (partition by customer_id order by month rows between 2 preceding and current row)`, on the spine so every window is 3 real months.
- *"`rows` vs `range`?"* `rows` counts physical rows; `range` uses values, so ties (or missing dates) change what's included. On a complete spine, `rows` is safe and clear.

---

## Part 4: Optimization

### O1. Fix a slow query

**The idea:** optimization questions test whether you can **spot** waste and **explain** the cost, more than any single trick.

**The problems:**

| Problem | Why it hurts at 2 billion rows | Fix |
|---|---|---|
| `select *` | Columnar storage reads every column from disk | Select only the needed columns |
| `date_format(txn_ts, ...)` in `where` | A function on the column stops file skipping, so every file is read | A half-open range on the raw column |
| `upper(status)` | Same: a function on the column, evaluated on every row | Compare the stored value; clean casing once upstream |
| Refunds joined, never used | An extra join, and it duplicates T1 and T6, so any sum is wrong | Remove it |
| `in (select ... from s_accounts)` | Reads accounts a second time | Filter `account_type` in the accounts join you already have |
| No aggregation | Ships every row to the caller | Aggregate to the grain the question needs |

**Rewrite:**

```sql
select c.customer_id, c.name, sum(-t.amount) as march_spend
from s_transactions t
join s_accounts a  on a.account_id = t.account_id and a.account_type = 'checking'
join s_customers c on c.customer_id = a.customer_id
where t.txn_ts >= timestamp'2026-03-01' and t.txn_ts < timestamp'2026-04-01'
  and t.status = 'posted' and t.amount < 0
group by c.customer_id, c.name
order by c.customer_id;
```

**Expected:** C1 150, C2 575, C3 220.

**How to prove it's faster:** `explain formatted` on both, then the query profile: files and bytes scanned (should drop sharply with the date range), rows after each join, shuffle size, spill to disk, and task time skew.

**Follow-ups:**
- *"What would you change in the table itself?"* Cluster `transactions` on `txn_ts` (liquid clustering), so date filters skip most files. Keep file sizes healthy (compaction).
- *"The join to accounts is slow."* Accounts is small, so the engine should broadcast it. Check the plan shows a broadcast join, not a shuffle of 2 billion rows.

### O2. Talk track: "This query got slow"

**A strong 90-second answer:**
1. **Clarify:** "Was it sudden or gradual? What changed: data volume, code, cluster size, or the source?" Sudden usually means a code or data change; gradual usually means growth.
2. **Look:** "I open the query profile and find the slowest step. Then I ask which bucket it's in."
3. **Three buckets:**
   - **Reading too much:** many small files, no file skipping (a function on the filter column, wrong clustering), `select *`.
   - **Joining or shuffling too much:** fan-out from a duplicate key, joining before aggregating, a big table shuffled instead of a small one broadcast.
   - **Compute:** one task far slower than the others (skew on a hot key), or spilling to disk because memory is too small.
4. **Fix the biggest one first**, then **measure again** and compare with the old profile.
5. **Prevent:** a runtime alert, and row-count checks so fan-out is caught before it gets slow.

**Say it in one line:** "Find the slow step, decide if it's reading, joining or compute, fix the biggest, measure again."

---

## Part 5: Mock round

### M1. Part 1: spend per category

```sql
select t.category, sum(-t.amount) as spend, count(*) as debits
from s_transactions t
where t.status = 'posted' and t.amount < 0
group by t.category
order by spend desc;
```

**Expected:** travel 720 (3), grocery 275 (5), dining 150 (3).

### M1. Part 2: spend per state

**Clarify:** A5's customer C6 isn't in `s_customers`. An inner join silently drops 40 of spend. Say so, and keep it visible as "unknown".

```sql
select coalesce(c.state, 'unknown') as state, sum(-t.amount) as spend
from s_transactions t
join s_accounts a       on a.account_id = t.account_id
left join s_customers c on c.customer_id = a.customer_id
where t.status = 'posted' and t.amount < 0
group by all
order by spend desc;
```

**Expected:** NJ 635, NY 470, unknown 40. Total 1,145, matching M1 Part 1.

### M1. Part 3: accounts, debits and spend per customer

**The trap:** joining accounts and transactions then using `count(*)` for accounts counts transactions. Count distinct accounts, and keep filters in the `ON`.

```sql
select c.customer_id,
       count(distinct a.account_id)        as accounts,
       count(t.txn_id)                     as posted_debits,
       coalesce(sum(-t.amount), 0)         as spend
from s_customers c
left join s_accounts a     on a.customer_id = c.customer_id
left join s_transactions t on t.account_id = a.account_id
                          and t.status = 'posted' and t.amount < 0
group by c.customer_id
order by c.customer_id;
```

**Expected:** C1 2 / 4 / 220, C2 1 / 3 / 635, C3 1 / 3 / 250, C4 0 / 0 / 0, C5 1 / 0 / 0.

### M1. Part 4: days from signup to first spend

```sql
with first_spend as (
  select a.customer_id, min(cast(t.txn_ts as date)) as first_spend_date
  from s_transactions t
  join s_accounts a on a.account_id = t.account_id
  where t.status = 'posted' and t.amount < 0
  group by a.customer_id
)
select c.customer_id, c.signup_date, f.first_spend_date,
       datediff(f.first_spend_date, c.signup_date) as days_to_first_spend
from s_customers c
left join first_spend f on f.customer_id = c.customer_id
order by c.customer_id;
```

**Expected:** C1 55, C2 25, C3 **−5**, C4 null, C5 null.

**The analysis point:** C3's first spend (T15, Jan 28) is **before** C3 signed up (Feb 2) and before account A4 was opened (Feb 3). Call it out: "That's a data quality issue, maybe a backdated transaction or a wrong signup date. I'd flag it, not silently drop it." Karat rewards noticing this.

### M1. Part 5: rank and share within state

```sql
with spend as (
  select c.customer_id, c.state, sum(-t.amount) as spend
  from s_transactions t
  join s_accounts a  on a.account_id = t.account_id
  join s_customers c on c.customer_id = a.customer_id
  where t.status = 'posted' and t.amount < 0
  group by all
)
select customer_id, state, spend,
       rank() over (partition by state order by spend desc)               as state_rank,
       round(100.0 * spend / sum(spend) over (partition by state), 1)    as pct_of_state
from spend
order by state, state_rank;
```

**Expected:** NJ: C2 rank 1, 100.0%. NY: C3 rank 1 (250, 53.2%), C1 rank 2 (220, 46.8%).

**Follow-up:** *"Why `sum(spend) over (partition by state)` and not a join to a state total?"* Same result with one pass and no second query. Percent-of-total is a classic window question.

---

## Quick-fire answers

1. **Inner vs left join:** inner keeps matches only; left keeps every row from the left table, with nulls where nothing matched.
2. **`ON` vs `WHERE` in a left join:** `ON` decides what matches; `WHERE` filters the result afterwards. A right-table filter in `WHERE` turns the left join into an inner join.
3. **Semi-join vs anti-join:** semi keeps left rows that have a match (`exists`); anti keeps those that don't (`not exists`). Neither duplicates rows.
4. **Why avoid `not in` with a subquery:** if the subquery returns any null, the result is empty.
5. **`union` vs `union all`:** `union` removes duplicates, which costs a sort or hash; `union all` keeps everything. Default to `union all`.
6. **`where` vs `having`:** `where` filters rows before grouping; `having` filters groups after.
7. **Correlated subquery:** an inner query that refers to the outer row, so it logically runs once per row. Often better as a join or a window.
8. **CTE vs subquery vs temp table:** CTEs and subqueries usually run the same; CTEs read top-down and can be reused within the query. A temp table stores the result for reuse across queries.
9. **Window function vs `group by`:** `group by` collapses rows; a window adds the aggregate to each row and keeps them all.
10. **`row_number` vs `rank` vs `dense_rank`:** on ties: always unique; tied with gaps after; tied with no gaps.
11. **`count(*)` vs `count(col)` vs `count(distinct col)`:** all rows; non-null values; distinct non-null values.
12. **Nulls in aggregates:** `sum`, `avg`, `min`, `max` and `count(col)` skip nulls. `avg` of 10, null, 20 is 15.
13. **`null = null`:** not true (it's unknown). Use `is null`, or null-safe `<=>` / `is not distinct from`.
14. **Fan-out:** a one-to-many join repeats rows from the "one" side and inflates its sums. Aggregate before joining, and test the grain.
15. **Order of execution:** from and joins, where, group by, having, window functions, select, distinct, order by, limit.
16. **A query got slow:** see O2. Find the slow step; is it reading, joining or compute; fix the biggest; measure again.
17. **Indexes vs partitioning vs clustering:** OLTP databases use indexes to find rows. Warehouses skip files using stats, partitions and clustering (liquid clustering, Z-order) on columns you filter by.
18. **Predicate pushdown:** the engine applies filters as early as possible, even while reading files. A function on the column can block it.
19. **Broadcast join:** a small table is copied to every worker, so the big table doesn't shuffle.
20. **Skew:** one key has far more rows than others, so one task runs much longer. Fix with adaptive query execution, salting the hot key, or handling it separately.
21. **`select *` in a warehouse:** storage is columnar, so every extra column is extra data read.
22. **Normalization vs denormalization:** normalized (3NF) avoids duplicated data and suits writes (OLTP). Denormalized (star schema, wide tables) suits reads and analytics (OLAP).
23. **OLTP vs OLAP:** many small reads and writes of single rows vs large scans and aggregations.
24. **Deduplicating:** define the key and which copy wins, then `row_number() over (partition by key order by loaded_at desc)` and keep 1.
25. **Modern SQL you use:** CTEs, window functions with frames, `qualify`, `group by all`, `merge`, `pivot`, arrays and structs with `explode`, `count_if`.
26. **ACID:** Atomicity (all or nothing), Consistency (rules always hold), Isolation (concurrent transactions don't see each other's half-done work), Durability (committed data survives a crash). Delta Lake brings ACID to tables in a data lake.
27. **Primary key vs foreign key:** a primary key uniquely identifies a row; a foreign key points to another table's primary key. In warehouses they're often informational (not enforced), so you test them instead.
28. **View vs materialized view vs table:** a view stores the query and runs it each time; a materialized view stores the result and refreshes it; a table stores data you load.
29. **Relational vs NoSQL:** relational for structured data, joins and strong consistency (payments, ledgers); NoSQL for flexible schemas, huge write volume or simple key lookups at scale.
30. **Star vs snowflake schema:** a star has facts joined to flat dimensions (fewer joins, faster to query); a snowflake normalizes dimensions into more tables (less duplication, more joins).
