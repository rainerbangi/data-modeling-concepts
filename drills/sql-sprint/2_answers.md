# 2. Answers (PostgreSQL)

Each answer is written the way you'd work it **in the interview**:

1. **Clarify:** the question to ask before typing, and the answer to assume.
2. **Plan:** one or two sentences to say before you write any SQL.
3. **Build:** the query in small steps, with what to check after each.
4. **Result** and a **check out loud.**
5. **The trap** the question is testing, and **follow-ups** with answers ready to say.

Run each query under its drill's setup from `1_drills.md`. Every query was tested on PostgreSQL.

---

## Part 1: Read it first

For these, the interviewer shows you a query and asks what it does. Answer before you run anything.

### R1. Three kinds of count

**Say:**
> "It returns 5, 3 and 2. `count(*)` counts every row, so 5 users. `count(referred_by)` skips nulls: users 2, 3 and 4 have a referrer, so 3. `count(distinct referred_by)` also removes repeats: the values are 1, 1 and 9, so 2 distinct."

**Follow-ups:**
- *"How many users have no referrer?"* "`count(*) - count(referred_by)`, which is 2. Or `count(*) filter (where referred_by is null)`."
- *"Does `count(1)` differ from `count(*)`?"* "No. Both count rows."

### R2. Division and rounding

**Say:**
> "`a` is **2**, not 2.5: both sides are integers, so Postgres does integer division and drops the remainder. `b` is 2.5, because casting one side to `numeric` makes the whole expression numeric. `c` is 1.5: `avg` of integers returns `numeric`, so it's safe."
>
> "`round(2.5::float8, 1)` fails. In Postgres the two-argument `round` only exists for `numeric`, so I'd cast first: `round(x::numeric, 1)`."

**A percentage that's always right:**
```sql
select round(100.0 * 1 / nullif(3, 0), 1) as pct;   -- 33.3
```
> "`100.0` makes the math numeric, and `nullif` turns a zero denominator into null instead of a division-by-zero error."

**Follow-up:** *"Why not `cast(a as float)`?"* "Floats can't store most decimals exactly. For money and percentages I use `numeric`."

### R3. A left join with a WHERE filter

**Say:**
> "It returns 3 rows: users 1, 2 and 3 with their checking accounts. Users 4 and 5 are missing. User 4 has no account, so after the left join `account_type` is null. User 5 only has savings. The `WHERE` filter removes both, so this left join is really an inner join."
>
> "If the goal is every user plus their checking account if they have one, the filter belongs in the `ON`:"

```sql
select u.user_id, a.account_id
from users u
left join accounts a
  on a.user_id = u.user_id
 and a.account_type = 'checking'
order by u.user_id;
```
**Result:** 5 rows; users 4 and 5 show a null `account_id`.

**Rule to say:** "A filter on the right table of a left join goes in `ON`. In `WHERE`, it throws away the rows the left join was supposed to keep."

### R4. NOT IN and a null

**Say:**
> "It returns **nothing**, even though account 106 has no transactions. The subquery returns a null (transaction 4 has no account). `106 not in (101, 102, 103, null)` asks '106 is not 101 and not 102 and not 103 and not null', and anything compared to null is unknown, so the row is never kept."

**Fix:**
```sql
select a.account_id
from accounts a
where not exists (
  select 1 from transactions t where t.account_id = a.account_id
);
```
**Result:** 106.

**Follow-ups:**
- *"Can you keep `not in`?"* "Only if I add `where account_id is not null` in the subquery. I default to `not exists` because nulls can't break it."
- *"Does `in` have the same problem?"* "No. `in` with a null still finds real matches. The problem is only with `not in`."

### R5. March by BETWEEN

**Say:**
> "It misses transaction 4 on March 31 at 18:45. Compared with a timestamp, `'2026-03-31'` means midnight at the **start** of March 31, so anything later that day is outside the range. It returns 60 instead of 100."

**Fix:**
```sql
select sum(amount)
from transactions
where created_at >= '2026-03-01'
  and created_at <  '2026-04-01';
```
**Result:** 100.

**Rule to say:** "For timestamps I use a half-open range: on or after the first day, before the first day of the next month. It never misses the last day and never double-counts the boundary."

### R6. Filtering a window function

**Say:**
> "The first fails because `WHERE` runs before window functions, so `row_number()` doesn't exist yet when the filter runs. The second fails because Postgres has no `QUALIFY`. I'd compute the row number in a CTE and filter outside, or use `DISTINCT ON`."

```sql
-- Option 1: works in every database
with ranked as (
  select *,
         row_number() over (partition by user_id order by created_at desc) as rn
  from transactions
)
select txn_id, user_id, created_at
from ranked
where rn = 1
order by user_id;

-- Option 2: Postgres only, shorter
select distinct on (user_id) txn_id, user_id, created_at
from transactions
order by user_id, created_at desc;
```
**Result (both):** transaction 2 for user 1, transaction 3 for user 2.

**Follow-up:** *"What's the full order SQL runs in?"* "From and joins, where, group by, having, window functions, select, distinct, order by, limit."

### R7. Where do nulls sort?

**Say:**
> "It returns payment 3, the one with a **null** amount. Postgres treats null as larger than any value, so it comes first in descending order and last in ascending order. For 'largest payment' I add `nulls last`."

```sql
select payment_id, amount
from payments
order by amount desc nulls last
limit 1;
```
**Result:** payment 2, amount 100.

**Follow-up:** *"Would `max(amount)` have the same problem?"* "No. Aggregates skip nulls, so `max` returns 100. The trap is only in `order by`."

### R8. Date arithmetic

**Say each one:**

| | Value | Type | Why |
|---|---|---|---|
| a | `2026-03-08` | date | date + integer adds days and stays a date |
| b | `2026-03-08 00:00:00` | timestamp | date + interval becomes a timestamp |
| c | `30` | integer | date − date gives the number of days |
| d | `1 day 03:00:00` | interval | timestamp − timestamp gives an interval |
| e | `2026-03-01 00:00:00` plus a time zone offset | timestamp with time zone | `date_trunc` on a date returns a timestamp |

**Days between two timestamps, as an integer:**
```sql
select timestamp '2026-03-02 12:00'::date - timestamp '2026-03-01 09:00'::date as days;  -- 1
```
> "I cast both to dates, then subtract. For seconds I'd use `extract(epoch from ts2 - ts1)`."

**Watch out:** "`date_trunc('month', d)` on a date gives a timestamp, so I add `::date` before joining it to a date column."

---

## Part 2: Joins

### J1. Every user's March spend

**Clarify:**
> "Spend means posted debits only, so I skip declined transactions and the deposit. March means March 1 up to, but not including, April 1. Users with no spend should show 0, not be dropped. Is that right?"

**Plan:**
> "One row per user. I'll start from `users` so nobody can drop out, left join to accounts and transactions, and put every transaction filter in the join, not in `WHERE`."

**Build:**

*Step 1. Users to accounts.* Check: 6 rows. User 1 has two accounts, and user 4 has none but is still there.
```sql
select u.user_id, a.account_id
from users u
left join accounts a on a.user_id = u.user_id
order by u.user_id;
```

*Step 2. Add transactions, filters in `ON`, then sum.*
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

**Result:**

| user_id | march_spend |
|---|---|
| 1 | 150 |
| 2 | 575 |
| 3 | 200 |
| 4 | 0 |
| 5 | 0 |

**Check out loud:** "5 rows, one per user. The total is 925; let me confirm against the raw table."
```sql
select sum(-amount) as march_spend
from transactions
where status = 'posted' and amount < 0
  and created_at >= '2026-03-01' and created_at < '2026-04-01';   -- 925
```

**The trap:** "If I put `t.status = 'posted'` in `WHERE`, users 4 and 5 disappear. After the left join their `status` is null, and null is not 'posted'."

**Follow-ups:**
- *"Why not `extract(month from created_at) = 3`?"* "It matches March of every year, and a function on the column stops an index from being used."
- *"Why `coalesce` to 0?"* "No spend is a real zero. For a state like a balance, missing means unknown, and I'd leave it null."
- *"Why `sum(-t.amount)`?"* "Debits are stored as negatives. Flipping the sign shows spend as a positive number."

### J2. Spend and refunds per user

**Clarify:**
> "Spend is posted debits. Refunds count toward the user who made the original transaction. A user with no refunds shows 0. Can one transaction have more than one refund?" (Yes: transaction 6 has two.)

**Plan:**
> "That last answer matters. Transactions and refunds are both 'many' per user. If I join them directly, a transaction with two refunds appears twice and its spend is counted twice. So I'll total each one per user in its own CTE, then join two tables that each have one row per user."

**Build:**

*Step 1. Show the problem.* The naive join has 8 rows instead of 7, and spend comes out at 1,155 instead of 955.
```sql
select count(*) as row_count, sum(-t.amount) as spend
from transactions t
join accounts a     on a.account_id = t.account_id
left join refunds r on r.txn_id = t.txn_id
where t.status = 'posted' and t.amount < 0;   -- 8 rows, 1155
```

*Step 2. Aggregate first, then join.*
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

**Result:**

| user_id | spend | refunded |
|---|---|---|
| 1 | 160 | 50 |
| 2 | 575 | 0 |
| 3 | 220 | 80 |

**Check out loud:** "Spend adds up to 955, the raw total. Refunds add up to 130, the sum of the refunds table."

**Follow-ups:**
- *"How would you catch this in production?"* "Two tests that return rows only when something is wrong: a key that appears more than once, and a total that doesn't match the source."
- *"What if a user had refunds but no spend?"* "Then I'd combine the two CTEs with a `full outer join` and `coalesce` both sides, so neither side drops a user."

#### A result looks wrong: three checks

Use these in any drill when a number looks off.

**1. Does each row mean what it should?** If the answer is "one row per user", then `select count(*), count(distinct user_id) from (your query) q` must give two equal numbers. More rows than users means a join copied some.

**2. Which join copied rows?** Count rows after each join. The count jumps at the culprit. In J2:

| Step | Rows | What it means |
|---|---|---|
| transactions | 7 | one row per transaction |
| + accounts | 7 | each transaction has one account. Fine |
| + refunds | 8 | transaction 6 has 2 refunds, so it now appears **twice** |

**3. Does a total match the source?** Compare with the raw sum (955 in J2). A bigger number means rows were copied; a smaller one means rows were dropped.

**Fixes:** aggregate before joining; keep one row per key in a lookup table (`row_number()` or `distinct on`); check that the `on` clause has every key column.

### J3. Users with no activity, users with travel

**Clarify:**
> "For (a), does any transaction count as activity, even declined or pending?" (Assume yes, so user 4 has activity.)
> "For (b), only posted travel, and each user once?" (Yes.)

**Plan:**
> "Both are existence questions, not counts. For (a) I'll use `not exists`, an anti-join. For (b) I'll use `exists`, a semi-join. Neither one copies rows, so I won't need `distinct`."

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

**Result:** (a) user 5, Eli. (b) users 2 (Ben) and 3 (Cara).

**Check out loud:** "User 4 is not in (a) because he has a declined transaction. User 3 has two travel rows but shows once."

**The traps:**
- "`where user_id not in (select user_id from transactions)` returns **nothing**, because transaction 6 has a null `user_id`."
- "A plain join for (b) returns Cara twice. `distinct` would hide that, but `exists` avoids it."

**Follow-ups:**
- *"Write (a) with a join instead."* "`left join transactions t on t.user_id = u.user_id where t.txn_id is null`. Same result; `not exists` reads more clearly."
- *"Which is faster?"* "Postgres usually plans `not exists` and the left-join version the same way, as an anti-join."

**Databricks vs Postgres:** `left anti join` becomes `not exists`; `left semi join` becomes `exists`.

### J4. Who referred whom

**Clarify:**
> "User 4 was referred by user 9, who isn't in the table. Should I show null for the name and keep user 4?" (Yes.)

**Plan:**
> "One table in two roles: the user and the referrer. I'll alias it twice and use left joins, so users with no referrer, or a missing one, stay in the result."

```sql
-- (a) each user and their referrer's name
select u.user_id, u.name, r.name as referred_by_name
from users u
left join users r on r.user_id = u.referred_by
order by u.user_id;

-- (b) how many people each user referred
select r.user_id, r.name, count(u.user_id) as referrals
from users r
left join users u on u.referred_by = r.user_id
group by r.user_id, r.name
order by r.user_id;
```

**Result:** (a) users 2 and 3 show "Ana"; users 1, 4 and 5 show null. (b) Ana referred 2; everyone else 0.

**Check out loud:** "Both have 5 rows. The referrals add up to 2, but there are 3 non-null `referred_by` values. The missing one is user 4's referrer, 9, who isn't in the table."

**The trap:** "`count(*)` would give each user with no referrals a 1, because the left join keeps one row of nulls for them. `count(u.user_id)` counts only real matches."

**Follow-up:** *"How would you find referral chains of any depth?"* "A recursive CTE: `with recursive` starts from a user and joins back to `users` until there's no referrer."

### J5. Fee per transaction

**Clarify:**
> "The tiers include `min_amt` and exclude `max_amt`, so 100 is in tier 2. The fee uses the debit as a positive number. Should I round each fee to cents and then total, or total and then round?" (Round each fee; that's what gets charged.)

**Plan:**
> "This is a range join: each transaction matches the tier whose range contains its amount. I'll use `>=` and `<` so a boundary value matches exactly one tier."

**Build:**

*Step 1. Prove `between` is wrong.* This returns rows only when a transaction matches more than one tier.
```sql
select t.txn_id, count(*) as tiers_matched
from transactions t
join fee_tiers f on -t.amount between f.min_amt and f.max_amt
group by t.txn_id
having count(*) > 1;   -- transactions 2 and 5
```

*Step 2. The correct join.*
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

**Result:**

| txn_id | debit | tier | fee |
|---|---|---|---|
| 1 | 50.00 | 1 | 0.50 |
| 2 | 100.00 | 2 | 0.50 |
| 3 | 75.00 | 1 | 0.75 |
| 4 | 200.00 | 2 | 1.00 |
| 5 | 500.00 | 3 | 1.25 |
| 6 | 499.99 | 2 | 2.50 |

Total fees: **6.50**.

**Check out loud:** "6 rows for 6 transactions, so each matched exactly one tier."

**Follow-ups:**
- *"What if a transaction matches no tier?"* "An inner join drops it silently. I'd use a left join and check for null tiers."
- *"How do you stop overlapping tiers?"* "Postgres can enforce it with an exclusion constraint on a range type. Otherwise, a test that returns overlapping pairs."

---

## Part 3: Aggregation

### A1. Payment success rate per user

**Clarify:**
> "Success rate is successes divided by successes plus failures, so pending is left out of both. Payment 10 has a null amount but status 'failed': I'll still count it as a failure, since we're counting attempts, not money. All dates included?" (Yes.)

**Plan:**
> "One row per user. A single `group by user_id` with a `filter` on each count, and the rate computed from the same counts. I'll use `100.0` so the division isn't integer, and `nullif` so a user with only pending payments gets null instead of an error."

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

**Result:**

| user_id | successes | failures | pending | success_rate_pct |
|---|---|---|---|---|
| 1 | 2 | 1 | 0 | 66.7 |
| 2 | 1 | 3 | 0 | 25.0 |
| 3 | 0 | 1 | 1 | 0.0 |
| 4 | 1 | 0 | 0 | 100.0 |

**Check out loud:** "For each user, the three counts add up to their total payments: 3, 4, 2 and 1. That's all 10 rows."

**The traps:**
- "`100 * 2 / 3` is integer math and returns 66, not 66.7."
- "`count(amount) filter (where status = 'failed')` would miss payment 10. Count rows, not a nullable column."

**Follow-ups:**
- *"Overall success rate across all users?"* "Sum the parts, divide last: run the same expression without `group by`. Averaging the four user rates would weight a user with 1 payment the same as a user with 4."
- *"What if they also wanted the success rate by amount?"* "`sum(amount) filter (where status = 'success')` over `sum(amount) filter (where status in (...))`. Payment 10's null amount drops out of both."

**Databricks vs Postgres:** `count_if(status = 'success')` becomes `count(*) filter (where status = 'success')`. `sum(case when ... then 1 else 0 end)` works in both.

### A2. Users with repeated failures

**Clarify:**
> "March by `created_at`, March 1 up to April 1. 'Two or more' includes exactly two."

**Plan:**
> "`WHERE` keeps failed March payments, `GROUP BY` makes one row per user, `HAVING` keeps users with at least two."

```sql
select user_id, count(*) as failures
from payments
where status = 'failed'
  and created_at >= '2026-03-01' and created_at < '2026-04-01'
group by user_id
having count(*) >= 2
order by user_id;
```

**Result:** user 2, 3 failures.

**Check out loud:** "User 3 also has a failure, but in February, so it's filtered out before grouping. User 1 has only one."

**Say it:** "`WHERE` filters rows before grouping; `HAVING` filters groups after. Row conditions go in `WHERE`, which also means less data to group."

**Follow-up:** *"Two failures in a row, back to back?"* "Then I'd use `lag(status)` per user ordered by time and flag rows where both are 'failed'."

### A3. Possible duplicate charges

**Clarify:**
> "Same charge means same user, same merchant and same amount. Up to 60 seconds earlier, with exactly 60 counting. I flag the later charge and keep the first one as the original. If three come in a row, I compare each with the one just before it." (Yes to all.)

**Plan:**
> "For each charge, I'll get the time of the previous charge with the same user, merchant and amount using `lag`, partitioned by those three columns. Then keep rows where the gap is 60 seconds or less."

**Build:**

*Step 1. Look at the gaps.* Check: the first charge in each group has a null `prev_at`.
```sql
select txn_id, user_id, merchant, amount, created_at,
       lag(created_at) over (partition by user_id, merchant, amount
                             order by created_at) as prev_at
from card_txns
order by user_id, merchant, amount, created_at;
```

*Step 2. Filter in an outer query.* A window can't go in `WHERE`.
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

**Result:**

| txn_id | user_id | created_at | seconds_since_previous |
|---|---|---|---|
| 2 | 1 | 2026-03-01 10:00:40 | 40 |
| 5 | 2 | 2026-03-02 09:01:00 | 60 |
| 9 | 1 | 2026-03-01 10:00:50 | 10 |

**Check out loud:** "Transaction 9 was inserted last but happened at 10:00:50, so ordering by time, not by `txn_id`, matters. Transaction 3 is 250 seconds after 9, so it's fine. Transaction 6 is a different amount. Transaction 8 is a different user."

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
- *"Which version is better?"* "`lag` reads the table once. The self-join can multiply rows when a user has many charges in a minute, which is why it needs `distinct`."
- *"Should you flag against any earlier charge within 60 seconds, not just the previous one?"* "The self-join does that. Here both give the same rows."
- *"How would you remove the duplicates?"* "Keep rows where the gap is null or over 60 seconds."

---

## Part 4: Window functions

### W1. Latest transaction per user

**Clarify:**
> "Latest by `created_at`. If two tie on time, keep the larger amount, which means the larger absolute value since debits are negative. Rows with no user are skipped."

**Plan:**
> "Top 1 per group. I'll number each user's transactions newest first and keep number 1. The `order by` gets a tie-breaker so the result is the same every run."

```sql
-- 1. row_number in a CTE (works everywhere)
with ranked as (
  select *,
         row_number() over (partition by user_id
                            order by created_at desc, abs(amount) desc) as rn
  from transactions
  where user_id is not null
)
select user_id, txn_id, created_at
from ranked
where rn = 1
order by user_id;

-- 2. distinct on (Postgres only)
select distinct on (user_id) user_id, txn_id, created_at
from transactions
where user_id is not null
order by user_id, created_at desc, abs(amount) desc;
```

**Result:**

| user_id | txn_id | created_at |
|---|---|---|
| 1 | 2 | 2026-04-01 10:00 |
| 2 | 3 | 2026-03-25 10:00 |
| 3 | 5 | 2026-03-10 08:00 |
| 4 | 8 | 2026-03-12 13:00 |

**Check out loud:** "4 rows for 4 users, and both versions agree. User 3's transactions 5 and 6 tie on time; 5 wins because 200 is larger than 20."

**The traps:**
- "Without the tie-breaker, user 3 could return 5 on one run and 6 on the next."
- "`distinct on` needs the `order by` to **start** with the same columns; the columns after decide which row wins."

**Follow-ups:**
- *"What if they want every tied row?"* "Use `rank()` ordered only by `created_at desc` and keep rank 1. User 3 would return two rows."
- *"Latest transaction plus the user's name from `users`?"* "Pick the row first, then join, so the join works on one row per user."

**Databricks vs Postgres:** no `qualify`. Use the CTE or `distinct on`.

### W2. Running account balance

**Clarify:**
> "Each account starts at 0, so the balance is the running sum of its entries. Entries 2 and 3 have the same timestamp; I'll break the tie by `entry_id`."

**Plan:**
> "A running sum per account: `sum(amount) over (partition by account_id order by created_at, entry_id)`. I'll write the frame explicitly as `rows`, because the default frame treats tied timestamps as one step."

**Build:**

*Step 1. Show the default-frame problem.* Entries 2 and 3 both show 750.
```sql
select entry_id, account_id, created_at, amount,
       sum(amount) over (partition by account_id order by created_at) as default_frame
from ledger
order by account_id, created_at, entry_id;
```

*Step 2. (a) The fix: a tie-breaker and a `rows` frame.*
```sql
select account_id, entry_id, created_at, amount,
       sum(amount) over (partition by account_id
                         order by created_at, entry_id
                         rows between unbounded preceding and current row) as balance
from ledger
order by account_id, created_at, entry_id;
```

*Step 3. (b) The first entry that took each account below zero.*
```sql
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

**Result (a):**

| account_id | entry_id | amount | balance |
|---|---|---|---|
| 101 | 1 | 1000 | 1000 |
| 101 | 2 | −200 | 800 |
| 101 | 3 | −50 | 750 |
| 101 | 4 | 300 | 1050 |
| 102 | 5 | 500 | 500 |
| 102 | 6 | −500 | 0 |
| 102 | 7 | −20 | −20 |

**Result (b):** account 102, entry 7, balance −20.

**Check out loud:** "Each account's last balance should equal its plain total: 1,050 and −20."
```sql
select account_id, sum(amount) as final_balance
from ledger
group by account_id
order by account_id;
```

**Say it:** "For running totals I always write `rows between unbounded preceding and current row` and add a tie-breaker."

**Follow-ups:**
- *"Why does the default frame do that?"* "With `order by` and no frame, the default is `range between unbounded preceding and current row`. `range` groups rows with the same `order by` value, so tied rows all get the sum through the last of them."
- *"End-of-day balance?"* "Compute the running balance, then keep the last entry per account per day with `row_number` ordered by time descending."

### W3. Top merchants

**Clarify:**
> "Spend is the sum of amounts per merchant. Cafe and Grocer tie at 300. For 'top 3', do you want exactly 3 merchants, or the top 3 spend levels with ties included?"

**Plan:**
> "Aggregate to one row per merchant first, then rank. I'll show all three functions so we can see where they differ."

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

**Result:**

| merchant | spend | row_num | rank | dense_rank |
|---|---|---|---|---|
| Cafe | 300 | 1 | 1 | 1 |
| Grocer | 300 | 2 | 1 | 1 |
| Air | 250 | 3 | 3 | 2 |
| Books | 100 | 4 | 4 | 3 |
| Gas | 100 | 5 | 4 | 3 |

**"Top 3" with each:**
- `row_number <= 3`: 3 rows (Cafe, Grocer, Air). Exactly 3, ties broken by name.
- `rank <= 3`: the same 3 rows. Rank skips 2 after the tie.
- `dense_rank <= 3`: **5** rows. Books and Gas share third place.

**Postgres shortcut:**
```sql
select merchant, sum(amount) as spend
from card_txns
group by merchant
order by spend desc
fetch first 3 rows with ties;
```

**Say it:** "Exactly N rows: `row_number` with a tie-breaker. N positions with ties: `rank`. N distinct values: `dense_rank`."

**Follow-up:** *"Top 3 merchants per category?"* "Same thing with `partition by category` in the window, then filter the rank in an outer query."

### W4. Moving average with a missing day

**Clarify:**
> "A missing day means no spend, so it counts as 0. A 3-day window means the day itself plus the two calendar days before it."

**Plan:**
> "I'll compute it three ways to show the difference. The right one fills missing days with 0 first, using `generate_series`, then averages the last 3 rows."

```sql
with filled as (
  select d::date as day, coalesce(s.spend, 0) as spend
  from generate_series(date '2026-03-01', date '2026-03-09', interval '1 day') as d
  left join daily_spend s on s.day = d::date
),
filled_avg as (
  select day,
         round(avg(spend) over (order by day rows between 2 preceding and current row), 2) as filled_avg
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

**Result:**

| day | spend | rows_avg | range_avg | filled_avg |
|---|---|---|---|---|
| Mar 1 | 100 | 100.00 | 100.00 | 100.00 |
| Mar 2 | 50 | 75.00 | 75.00 | 75.00 |
| Mar 4 | 70 | 73.33 | 60.00 | 40.00 |
| Mar 5 | 30 | 50.00 | 50.00 | 33.33 |
| Mar 8 | 200 | 100.00 | 200.00 | 66.67 |
| Mar 9 | 40 | 90.00 | 120.00 | 80.00 |

**Explain Mar 4 out loud:**
> "`rows` takes the last 3 rows: Mar 1, 2 and 4, so it reaches back 4 days. `range` takes Mar 2 to 4 but only the rows that exist, so it averages 50 and 70 and ignores the missing Mar 3. Filled takes 50, 0 and 70 and divides by 3: 40. Only filled matches 'average daily spend over 3 days'."

**Follow-ups:**
- *"When is `range` right?"* "When a missing day means unknown, not zero. For example, an average price: if there was no quote that day, I wouldn't invent a 0."
- *"First two days only have 1 or 2 days of history. Problem?"* "I'd ask. Often you show null until a full window exists: `case when count(*) over (same window) = 3 then avg(...) end`."

### W5. Monthly active users and month-over-month change

**Clarify:**
> "Active means at least one activity row in the month, counted once per user. January to April 2026. A month with no activity shows 0. When last month was 0, percent change is null."

**Plan:**
> "Build the four months with `generate_series`, count distinct users per month, left join the counts onto the months, then use `lag` for last month. The spine matters: without February, `lag` would compare March with January."

**Build:**

*Step 1. Distinct users per month.* Check: only 3 rows; February is missing.
```sql
select date_trunc('month', activity_date)::date as month,
       count(distinct user_id) as mau
from activity
group by 1
order by 1;
```

*Step 2. Month spine, fill, then `lag`.*
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
       lag(mau) over (order by month)                                        as prev_mau,
       mau - lag(mau) over (order by month)                                  as change,
       round(100.0 * (mau - lag(mau) over (order by month))
             / nullif(lag(mau) over (order by month), 0), 1)                 as pct_change
from filled
order by month;
```

**Result:**

| month | mau | prev_mau | change | pct_change |
|---|---|---|---|---|
| 2026-01-01 | 2 | null | null | null |
| 2026-02-01 | 0 | 2 | −2 | −100.0 |
| 2026-03-01 | 3 | 0 | 3 | null |
| 2026-04-01 | 2 | 3 | −1 | −33.3 |

**Check out loud:** "January has 3 rows but 2 users, because user 1 appears twice. That's why it's `count(distinct)`."

**Follow-ups:**
- *"Why `::date` after `date_trunc`?"* "On a date, `date_trunc` returns a timestamp with time zone. Casting keeps the join to the month series clean."
- *"Can you avoid repeating `lag` three times?"* "Yes: compute `prev_mau` in one CTE, then do the math in the next."
- *"Can MAU be summed across months?"* "No. A user active in two months would count twice. Distinct counts are recomputed for each period."

### W6. Active this month, not last month

**Clarify:**
> "April 2026 vs March 2026, fixed months, not relative to today. Each user once."

**Plan:**
> "April's users minus March's users: a set difference. I'll write it with `not exists` and with `except`."

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

**Result:** user 4.

**Check out loud:** "April has users 1 and 4. User 1 was active in March, so only user 4 is new."

**Say it:** "`except` removes duplicates, like `union`. `except all` keeps them."

**Follow-up:** *"For every month, not just April?"* "Build one row per user and month, then keep pairs with no row for the same user in the month before:"
```sql
with user_months as (
  select distinct user_id, date_trunc('month', activity_date)::date as month
  from activity
)
select c.month, c.user_id
from user_months c
where not exists (select 1 from user_months p
                  where p.user_id = c.user_id
                    and p.month = (c.month - interval '1 month')::date)
order by c.month, c.user_id;
```
> "January: users 1 and 2. March: 1, 2 and 3, since nobody was active in February. April: user 4."

### W7. Fill missing days in daily totals

**Clarify:**
> "March 1 to 7 inclusive. A sale at 23:59:59 on March 7 belongs to March 7. Days with no sales show 0."

**Plan:**
> "Build all 7 days with `generate_series`, left join sales onto each day's time range, and sum with `coalesce` to 0."

```sql
select d::date as day, coalesce(sum(s.amount), 0) as total
from generate_series(date '2026-03-01', date '2026-03-07', interval '1 day') as d
left join sales s
  on s.created_at >= d
 and s.created_at <  d + interval '1 day'
group by d
order by d;
```

**Result:**

| day | total |
|---|---|
| 2026-03-01 | 80 |
| 2026-03-02 | 20 |
| 2026-03-03 | 0 |
| 2026-03-04 | 70 |
| 2026-03-05 | 0 |
| 2026-03-06 | 0 |
| 2026-03-07 | 50 |

**Check out loud:** "7 rows. The totals add up to 220, which is the sum of all sales."

**Follow-ups:**
- *"Why join on a range, not `s.created_at::date = d::date`?"* "Both work here. The range lets Postgres use an index on `created_at`; a cast on the column blocks it."
- *"Dates from the data instead of hardcoded?"* "`generate_series((select min(created_at)::date from sales), (select max(created_at)::date from sales), interval '1 day')`."

**Databricks vs Postgres:** `explode(sequence(...))` becomes `generate_series(...)`.

---

## Part 5: Modeling and performance

### D1. Design the tables

**Clarify:**
> "Can a user have several accounts, and an account several cards?" (Yes.) "Is a merchant shared across many transactions?" (Yes.) "Can a transaction happen without a card, like a transfer?" (Yes.)

**Say the model first** (whiteboard or out loud):

| Table | Primary key | Foreign keys | One-to-many |
|---|---|---|---|
| users | user_id | | one user, many accounts |
| accounts | account_id | user_id → users | one account, many cards and transactions |
| cards | card_id | account_id → accounts | |
| merchants | merchant_id | | one merchant, many transactions |
| transactions | txn_id | account_id → accounts, card_id → cards (nullable), merchant_id → merchants | |

> "The foreign key always lives on the 'many' side. `card_id` is nullable because not every transaction uses a card."

**Then the DDL:**
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
**Result:** the last insert fails with a foreign key violation.

**Talking points:**
- **Normalization:** "A merchant's name lives once, in `merchants`, so a rename is one update. That's third normal form: every column depends on the key and nothing else."
- **When to denormalize:** "For analytics, a wide fact table with the merchant name copied in is faster to query. Normalize where data is written, denormalize where it's read."
- **Money:** "`numeric(12,2)`, never `float`, because floats can't store cents exactly."
- **Indexes:** "Postgres doesn't index foreign keys automatically. I'd index the ones I filter or join on."

**Follow-ups:**
- *"Would you store the full card number?"* "No. In practice it's tokenized by a payment processor; I'd store a token and the last 4 digits."
- *"Sign or a direction column for amounts?"* "Either works. A signed amount makes balances a plain `sum`; a `direction` column makes intent explicit. I'd pick one and enforce it with a `check`."
- *"How would you track a card's status changes over time?"* "A history table with `valid_from` and `valid_to`, one row per status period, instead of overwriting `status`."

### O1. Make a slow query fast

**Clarify:**
> "How often does this run, and how big will the table get? Is `status` always lowercase?" (Assume it runs often and status is always lowercase.)

**Read the plan out loud:**
> "It's a `Seq Scan on transactions`: Postgres reads all 100,000 rows and throws away almost all of them. Three reasons it's slow:"
- "There's no index on `user_id`, the most selective filter."
- "`date_trunc('month', created_at)` and `lower(status)` wrap columns in functions, so even an index on those columns couldn't be used."
- "`select *` returns every column when we need three."

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
**Result:** the new plan uses `idx_txn_user_created` (an `Index Scan` or `Bitmap Index Scan`), and the execution time drops. Both versions return the same rows.

**Check out loud:** "Same row count before and after, so I changed the speed, not the answer."

**Why this column order:** "Equality column first (`user_id`), range column second (`created_at`). Postgres jumps to user 42 and reads only their March rows."

**Follow-ups:**
- *"Index everything, then?"* "No. Each index slows writes and takes space. Index the columns used in frequent filters and joins."
- *"What if `status` really is mixed case?"* "Clean it once on write, or create an expression index on `lower(status)`."
- *"Why might Postgres ignore the index?"* "If the filter matches a large share of the table, a sequential scan is cheaper. Stale statistics can also mislead it; `analyze` refreshes them."

### O2. Talk track: "This query got slow"

**Say it in this order:**
1. **Clarify:** "Did it slow down suddenly or gradually? What changed: data size, the query, an index, or a deploy?"
2. **Measure:** "I'd run `explain analyze` and find the step that takes the most time, and compare estimated rows with actual rows."
3. **Common causes in Postgres:**
   - **A sequential scan** where an index should be used: a missing index, or a function on the column.
   - **Stale statistics:** estimated rows far from actual rows. Run `analyze`.
   - **A bad join:** a join that multiplies rows, or a nested loop over a big table.
   - **A sort or hash that spills to disk** (`external merge` in the plan): not enough `work_mem`.
   - **Locks** from another transaction, or table **bloat** after many updates (`vacuum`).
4. **Fix the biggest cause, then measure again** with `explain analyze`.

**Say it in one line:** "Find the slow step with `explain analyze`, fix the biggest cause, measure again."

**Follow-up:** *"Data grew 10 times. What then?"* "Make sure filters are indexed, then consider partitioning by date, so queries on recent data skip old partitions."

---

## Part 6: Mock round

Before Part 1, say this once:
> "Spend means posted debits, shown positive. I'll skip pending and declined, and deposits and transfers in. I'll confirm the rules for each part as we go."

### M1. Part 1: spend per category

**Plan:** "One row per category. Filter to posted debits, then group."
```sql
select category, sum(-amount) as spend, count(*) as debits
from transactions
where status = 'posted' and amount < 0
group by category
order by spend desc;
```
**Result:**

| category | spend | debits |
|---|---|---|
| travel | 720 | 3 |
| grocery | 275 | 5 |
| dining | 150 | 3 |

**Check out loud:** "Total spend is 1,145 over 11 debits. I'll use 1,145 to check Part 2."

### M1. Part 2: spend per state

**Clarify:**
> "Account 105 belongs to user 6, who isn't in `users`. An inner join would drop 40 of spend without telling anyone. I'd keep it as 'unknown' so the total still matches. Is that OK?"

```sql
select coalesce(u.state, 'unknown') as state, sum(-t.amount) as spend
from transactions t
join accounts a     on a.account_id = t.account_id
left join users u   on u.user_id = a.user_id
where t.status = 'posted' and t.amount < 0
group by 1
order by spend desc;
```
**Result:** NJ 635, NY 470, unknown 40.

**Check out loud:** "635 + 470 + 40 = 1,145, which matches Part 1. CT doesn't appear because Dev has no accounts."

**Follow-up:** *"Should CT show with 0?"* "If they want every state, I'd start from the list of states and left join the spend."

### M1. Part 3: accounts, debits and spend per user

**Clarify:** "Every user in `users`, even with no accounts. Debits and spend are posted debits only."

**Plan:** "Start from `users`, left join accounts and transactions, with transaction filters in the `ON`. Accounts need `count(distinct)`, because joining transactions repeats each account once per transaction."
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
**Result:**

| user_id | accounts | posted_debits | spend |
|---|---|---|---|
| 1 | 2 | 4 | 220 |
| 2 | 1 | 3 | 635 |
| 3 | 1 | 3 | 250 |
| 4 | 0 | 0 | 0 |
| 5 | 1 | 0 | 0 |

**Check out loud:** "Spend totals 1,105: Part 1's 1,145 minus the 40 from the unknown user. Debits total 10: 11 minus that one."

**The trap:** "`count(*)` would give user 1 four accounts, and user 4 one account (the row of nulls)."

### M1. Part 4: days from signup to first spend

**Clarify:** "First spend is the earliest posted debit. Users with no spend show null days. Any day count is fine, not just positive?" (Yes.)

**Plan:** "Find each user's first spend date in a CTE, one row per user, then left join to `users` and subtract dates."
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
**Result:**

| user_id | signup_date | first_spend_date | days_to_first_spend |
|---|---|---|---|
| 1 | 2026-01-05 | 2026-03-01 | 55 |
| 2 | 2026-01-20 | 2026-02-14 | 25 |
| 3 | 2026-02-02 | 2026-01-28 | **−5** |
| 4 | 2026-02-15 | null | null |
| 5 | 2026-03-01 | null | null |

**Say the odd thing:**
> "User 3's first spend, January 28, is before they signed up on February 2, and before account 104 opened on February 3. That's a data quality issue: a backdated transaction or a wrong signup date. I'd flag it and ask, not drop it."

**Databricks vs Postgres:** `datediff(a, b)` becomes `a - b` on dates.

### M1. Part 5: rank and share within state

**Clarify:** "Only users with spend and a known state, so the unknown user is out. Ties share a rank, so `rank`. Share is the user's spend over their state's total."

**Plan:** "One row per user with their spend and state. Then two windows partitioned by state: `rank` for position, `sum` for the state total."
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
       rank() over (partition by state order by spend desc)            as state_rank,
       round(100.0 * spend / sum(spend) over (partition by state), 1)  as pct_of_state
from spend
order by state, state_rank;
```
**Result:**

| user_id | state | spend | state_rank | pct_of_state |
|---|---|---|---|---|
| 2 | NJ | 635 | 1 | 100.0 |
| 3 | NY | 250 | 1 | 53.2 |
| 1 | NY | 220 | 2 | 46.8 |

**Check out loud:** "Shares add up to 100 within each state."

**Follow-up:** *"Share of the whole company instead?"* "Drop the `partition by`: `sum(spend) over ()` is the grand total on every row."

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
