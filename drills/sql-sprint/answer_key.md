# SQL Sprint: Answer Key

Open only after you attempt a drill. Spend = posted debits only (`status = 'posted' and amount < 0`), shown as a positive number.

---

### J1. Join types: predict the rows

**The idea:** before you write a join, know which rows survive. Interviewers often ask you to predict counts.

**Think it through:** 5 customers, 6 accounts. C1 has 2 accounts. C4 has none. A5 belongs to C6, who isn't a customer.
- Inner: only matches. C1 ×2, C2, C3, C5 = **5**.
- Left (customers first): the 5 matches plus C4 with nulls = **6**.
- Right: the 5 matches plus A5 with nulls = **6**.
- Full: matches plus both orphans = **7**.

```sql
select 'inner' as join_type, count(*) as n from s_customers c join s_accounts a on a.customer_id = c.customer_id
union all
select 'left',  count(*) from s_customers c left join s_accounts a on a.customer_id = c.customer_id
union all
select 'right', count(*) from s_customers c right join s_accounts a on a.customer_id = c.customer_id
union all
select 'full',  count(*) from s_customers c full outer join s_accounts a on a.customer_id = c.customer_id;
```

**Expected:** inner 5, left 6, right 6, full 7.

**Say it:** "A join's row count is the number of matching pairs. One-to-many multiplies; outer joins add the unmatched rows from the kept side."

---

### J2. Every customer's March spend

**The idea:** a filter on the right-hand table belongs in the `ON` clause of a left join. In `WHERE`, it silently turns the left join into an inner join.

**The trap:** `where t.status = 'posted'` throws away C4 and C5, because their `t.status` is null after the left join.

**Think it through:**
1. Start from customers (everyone must appear).
2. Left join accounts, then left join transactions, with every transaction filter in the `ON`.
3. Sum spend; `coalesce` to 0 for customers with none.

```sql
select c.customer_id,
       coalesce(sum(-t.amount), 0) as march_spend
from s_customers c
left join s_accounts a     on a.customer_id = c.customer_id
left join s_transactions t on t.account_id  = a.account_id
                          and t.status = 'posted'                       -- filters on the right table
                          and t.amount < 0                              --   stay in the ON clause
                          and t.txn_ts >= timestamp'2026-03-01'
                          and t.txn_ts <  timestamp'2026-04-01'          -- half-open date range
group by c.customer_id
order by c.customer_id;
```

**Expected:** C1 150, C2 575, C3 220, C4 0, C5 0.

**Why this way:** a half-open range (`>=` start, `<` next month) catches every timestamp in March and lets the engine skip files by date. `month(t.txn_ts) = 3` would also match other years and blocks file skipping.

---

### J3. Spend and refunds per customer (fan-out)

**The idea:** joining two "many" tables to the same parent multiplies rows. Aggregate each one to the output grain first.

**The trap:** T6 has two refunds. Join transactions to refunds directly and T6's 200 appears twice, so C3's spend becomes 420 instead of 220.

**Think it through:**
1. Spend per customer (transactions → accounts).
2. Refunds per customer (refunds → transactions → accounts), separately.
3. Join the two summaries, one row each per customer.

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

**Expected:** C1 220 spend / 50 refunded. C2 575 / 0. C3 220 / 80. C6 40 / 0.

**Say it:** "After every join, I ask what one row means now. If it changed, my sums are wrong."

---

### J4. Accounts with no transactions (anti-join)

**The idea:** "find X with no Y" is an anti-join. Use `not exists` or `left join ... where y.key is null`. Avoid `not in` with a subquery.

**The trap:** T9 has a null `account_id`. `account_id not in (select account_id from s_transactions)` returns **zero rows**, because comparing with null is never true.

```sql
-- correct: not exists ignores nulls
select a.account_id, a.customer_id
from s_accounts a
where not exists (select 1 from s_transactions t where t.account_id = a.account_id);

-- also correct: left join, keep the unmatched
select a.account_id, a.customer_id
from s_accounts a
left join s_transactions t on t.account_id = a.account_id
where t.txn_id is null;

-- wrong: returns nothing because of the null account_id
select account_id from s_accounts
where account_id not in (select account_id from s_transactions);
```

**Expected:** A6 (customer C5). The `not in` version returns no rows.

---

### J5. Customers with a travel purchase (semi-join)

**The idea:** "customers who have at least one Y" is a semi-join: keep each customer once, no matter how many matches.

**The trap:** a plain join returns C3 twice (T6 and T11 are both travel). People then add `distinct`, which hides the problem and does extra work.

```sql
select c.customer_id, c.name
from s_customers c
where exists (
  select 1
  from s_accounts a
  join s_transactions t on t.account_id = a.account_id
  where a.customer_id = c.customer_id
    and t.category = 'travel' and t.status = 'posted'
)
order by c.customer_id;
```

**Expected:** C2 Ben, C3 Cara.

**Why this way:** `exists` stops at the first match and can never duplicate. `in (subquery)` also works here; `join` plus `distinct` works but is slower and breaks once you add columns.

---

### J6. Who referred whom (self-join)

**The idea:** a table that points to itself (a referrer is also a customer) needs a self-join with two aliases.

**The trap:** an inner self-join drops customers with no referrer (C1, C5) and C4, whose referrer C9 doesn't exist.

```sql
-- each customer with their referrer's name
select c.customer_id, c.name, r.name as referred_by_name
from s_customers c
left join s_customers r on r.customer_id = c.referred_by
order by c.customer_id;

-- referrals made by each customer, including zero
select r.customer_id, r.name, count(c.customer_id) as referrals
from s_customers r
left join s_customers c on c.referred_by = r.customer_id
group by r.customer_id, r.name
order by r.customer_id;
```

**Expected:** only C2 and C3 have a referrer name (Ana). Referrals: C1 2, everyone else 0.

**Why `count(c.customer_id)`:** `count(*)` would count the null row for customers with no referrals as 1. `count(column)` skips nulls.

---

### J7. Fee per transaction (range join)

**The idea:** some joins match a value to a **range**, not an exact key. Use `>=` and `<` (half-open) so a boundary value fits one tier only.

**The trap:** `between min_amt and max_amt` puts the 100.00 debit (T2) in **both** tier 1 and tier 2, so it's charged twice.

```sql
select t.txn_id, -t.amount as debit, f.tier,
       round(-t.amount * f.fee_pct / 100, 2) as fee
from s_transactions t
join s_fee_tiers f
  on  -t.amount >= f.min_amt
  and -t.amount <  f.max_amt
where t.status = 'posted' and t.amount < 0
order by t.txn_id;
```

**Expected:** 9 rows, one per posted debit. T2 (100.00) is tier 2, fee 0.50. T12 (500.00) is tier 3, fee 1.25. Total fees 5.30.

---

### J8. March spend by current segment (duplicate keys)

**The idea:** before joining, check the key is unique on the side you expect to be "one". If it isn't, every match multiplies.

**The trap:** C1 has two segment rows. Joining directly counts C1's 150 under **both** standard and premium.

**Think it through:**
1. Keep the latest segment per customer (`row_number`).
2. Join spend to that one row.
3. Customers with no segment get "unknown".

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

**Expected:** premium 150, standard 795, unknown 40 (C6's account A5).

**Say it:** "I check uniqueness with `select key, count(*) ... having count(*) > 1` before I trust a join."

---

### S1. Latest transaction per account

**The idea:** "latest per group" can be written with a correlated subquery or a window function. The window is usually faster and handles ties on purpose.

**The trap:** A4 has two transactions at the same timestamp. The correlated subquery returns both.

```sql
-- correlated subquery: runs the inner query per row, and returns ties
select t.account_id, t.txn_id, t.txn_ts
from s_transactions t
where t.account_id is not null
  and t.txn_ts = (select max(t2.txn_ts) from s_transactions t2 where t2.account_id = t.account_id);

-- window function: one pass, exactly one row per account, ties broken on purpose
select account_id, txn_id, txn_ts
from (
  select *, row_number() over (partition by account_id
                               order by txn_ts desc, abs(amount) desc) as rn
  from s_transactions
  where account_id is not null
)
where rn = 1
order by account_id;
```

**Expected:** the window version returns A1 T10, A2 T13, A3 T12, A4 T6, A5 T8. The subquery version also returns T11 for A4.

**Say it:** "`row_number` gives exactly one row; `rank` keeps ties. I pick based on whether the business wants ties."

---

### S2. Debits above the account's own average

**The idea:** compare each row with an aggregate of its group. A window function adds the group average to every row without collapsing them.

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

**Expected:** T12 (500 vs 287.50), T2 (100 vs 70), T6 (200 vs 110).

**Why this way:** the subquery version (`where -amount > (select avg ... where same account)`) reruns per row; the window computes each average once. Filter the window result in an outer query, because `where` runs before window functions.

---

### S3. Top category per customer, keeping ties

**The idea:** "top N per group" is a ranking window. The choice of `row_number`, `rank` or `dense_rank` decides what happens with ties.

**The trap:** C1 spent 110 on grocery and 110 on dining. `row_number` picks one at random; the question asks to keep ties.

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

---

### S4. Average March spend per active customer (two-step aggregation)

**The idea:** "average per customer" means aggregate per customer first, then average those totals.

**The trap:** `avg(-amount)` over transactions gives the average **transaction** (about 140.71), not the average **customer** spend.

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

---

### S5. Customers above the average

**The idea:** a scalar subquery (one value) can sit in `where`. A CTE makes it readable and reusable.

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
where spend > (select avg(spend) from per_customer);
```

**Expected:** C2 575.

**Say it:** "A scalar subquery must return exactly one row. If it could return more, it errors, so I make sure it aggregates."

---

### O1. Fix a slow query

**The idea:** optimization interviews test whether you can **spot** waste and **explain** the fix, more than any single trick.

**The slow query (from the drill):**

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

**The problems:**

| Problem | Why it hurts | Fix |
|---|---|---|
| `select *` | Columnar storage reads every column | Select only the columns you need |
| Function on the date column | The engine can't skip files by date | Half-open range on the raw column |
| `upper(status)` | Same: a function on the column, every row | Compare the stored value, or clean it once upstream |
| Refunds joined but not used | Extra join, and it multiplies T1 and T6 | Remove it |
| `in (subquery)` on accounts | Reads accounts twice | Filter `a.account_type` in the join you already have |
| No aggregation | Ships every row to the caller | Aggregate to the answer's grain |

**Rewrite** (March posted spend per customer, checking accounts only):

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

**How you'd prove it's faster:** run `explain formatted` on both, and open the query profile. Look for: files and bytes scanned, rows after each join, shuffle size, spill to disk, and skew (one task far slower than the rest).

**At scale, also say:** cluster the big table on the filter column (liquid clustering on `txn_ts`); let the engine broadcast small tables like accounts; pre-aggregate before joining big tables; avoid `distinct` as a patch for fan-out.

---

## Quick-fire answers

1. **Inner vs left join:** inner keeps matches only; left keeps every row from the left table, with nulls where nothing matched.
2. **`ON` vs `WHERE` in a left join:** `ON` decides what matches; `WHERE` filters the result afterwards. A right-table filter in `WHERE` turns a left join into an inner join.
3. **Semi-join vs anti-join:** semi keeps left rows that have a match (`exists`); anti keeps those that don't (`not exists`). Neither duplicates rows.
4. **Why avoid `not in` with a subquery:** if the subquery returns any null, the result is empty.
5. **`union` vs `union all`:** `union` removes duplicates (a sort or hash, costly); `union all` keeps everything. Default to `union all`.
6. **`where` vs `having`:** `where` filters rows before grouping; `having` filters groups after.
7. **Correlated subquery:** an inner query that refers to the outer row, so it logically runs once per row. Often better as a join or window.
8. **CTE vs subquery vs temp table:** CTEs and subqueries are the same to the engine, but CTEs read top-down and can be reused in the query. A temp table stores the result, useful when reused across queries.
9. **Window function vs `group by`:** `group by` collapses rows; a window adds the aggregate to each row and keeps them all.
10. **`row_number` vs `rank` vs `dense_rank`:** see S3. Ties: unique, gaps, no gaps.
11. **`count(*)` vs `count(col)` vs `count(distinct col)`:** all rows; non-null values; distinct non-null values.
12. **Nulls in aggregates:** `sum`, `avg`, `count(col)` skip nulls. `avg` of 10, null, 20 is 15, not 10.
13. **`null = null`:** not true (unknown). Use `is null`, or null-safe `<=>` / `is not distinct from`.
14. **Fan-out:** a one-to-many join repeats the "one" side, inflating its sums. Aggregate before joining.
15. **Order of execution:** from and joins, where, group by, having, window functions, select, distinct, order by, limit. That's why you can't filter a window result in `where`.
16. **A query got slow. How do you narrow it down?** Did data grow or the query change? Then the query profile: which step takes the time, and is it reading too much (files), joining or shuffling too much (query), or skewed or spilling (compute)? Fix the biggest step, measure again.
17. **Indexes vs partitioning vs clustering:** OLTP databases use indexes to find rows. Warehouses like Databricks skip files using stats, partitions and clustering (liquid clustering, Z-order) on columns you filter by.
18. **Predicate pushdown:** the engine applies filters as early as possible, even while reading files. A function on the column can stop it.
19. **Broadcast join:** a small table is copied to every worker, so the big table never shuffles. Good for dimensions.
20. **Skew:** one key has far more rows (say, one huge merchant), so one task runs much longer. Fixes: salting, adaptive query execution, handling the hot key separately.
21. **Why `select *` is bad in a warehouse:** storage is columnar; you pay to read every column.
22. **Normalization vs denormalization:** normalized (3NF) avoids duplicate data and suits writes (OLTP). Denormalized (star schema, wide tables) suits reads and analytics (OLAP).
23. **OLTP vs OLAP:** many small reads and writes of single rows vs large scans and aggregations.
24. **How do you dedupe?** Define the key and which copy wins, then `row_number() over (partition by key order by loaded_at desc)` and keep 1.
25. **Modern SQL features you use:** CTEs, window functions with frames (`rows between 6 preceding and current row`), `qualify` (filters a window result inline in Databricks, Snowflake, BigQuery), `group by all`, `merge`, `pivot`, arrays and structs (`explode`), `count_if`, `any_value`.
