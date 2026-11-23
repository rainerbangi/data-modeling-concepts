### J1. Join types: predict the rows (5 min)
**What this tests:** how each join type treats unmatched rows.

**Your task:** before running anything, write down how many rows `s_customers` joined to `s_accounts` (on `customer_id`) returns for an **inner**, **left**, **right** and **full outer** join. Then run all four and compare.

**Hints:**
1. Look for a customer with no account, a customer with two accounts and an account whose customer doesn't exist.
2. Outer joins add the unmatched rows from the side they keep.

**Check yourself:** your four predictions match the four counts.

### J2. Every customer's March spend (8 min)
**What this tests:** where a filter goes in a left join.

**Scenario:** Marketing wants every customer with their March 2026 spend, including customers who spent nothing (show 0).

**Your task:** `customer_id, march_spend` for all 5 customers. Spend = posted debits (`status = 'posted'`, `amount < 0`), shown as positive.

**Hints:**
1. Write it with the filters in `WHERE` first. Who disappears?
2. Filters on the table you're left-joining to belong somewhere else.
3. How do you select every moment in March without wrapping the column in a function?

**Check yourself:** 5 rows; customers with no spend show 0, not null.

### J3. Spend and refunds per customer (10 min)
**What this tests:** fan-out when two "many" tables meet.

**Scenario:** Finance wants, per customer, total posted spend (all time) and total refunded, in one table.

**Your task:** `customer_id, spend, refunded`, one row per customer that has spend.

**Hints:**
1. Join transactions to refunds directly and look at T6. How many times does it appear?
2. Get each measure to one row per customer before combining them.

**Check yourself:** each customer's spend matches a query that ignores refunds entirely.

### J4. Accounts with no transactions (8 min)
**What this tests:** anti-joins and the `not in` null trap.

**Scenario:** Ops wants accounts that have never had a transaction, to send an activation email.

**Your task:** write it three ways: `not exists`, `left join ... is null`, and `not in (subquery)`. Explain why one of them behaves differently.

**Hints:**
1. Look at every `account_id` in `s_transactions`. Is any of them unusual?
2. What does `'A6' not in ('A1', null)` evaluate to?

**Check yourself:** two of your three versions agree.

### J5. Customers with a travel purchase (6 min)
**What this tests:** semi-joins: keeping each match once.

**Your task:** customers (`customer_id, name`) with at least one posted travel transaction. Each customer once.

**Hints:**
1. Try a plain join first and count the rows per customer.
2. You want a yes/no per customer, not every matching transaction.

**Check yourself:** no customer appears twice, and you didn't need `distinct`.

### J6. Who referred whom (8 min)
**What this tests:** self-joins and counting with outer joins.

**Scenario:** Growth wants (a) every customer with their referrer's name and (b) how many people each customer referred, including zero.

**Your task:** two queries.

**Hints:**
1. The same table plays two roles. Give each its own alias.
2. One referrer ID doesn't exist as a customer.
3. For (b), what does `count(*)` return for a customer who referred nobody?

**Check yourself:** (a) has 5 rows; (b) has 5 rows and its counts add up to the number of customers with a known referrer.

### J7. Fee per transaction (8 min)
**What this tests:** range (non-equi) joins and boundary values.

**Scenario:** Each posted debit pays a fee based on its size, from `s_fee_tiers` (`min_amt` included, `max_amt` excluded).

**Your task:** `txn_id, debit, tier, fee` for every posted debit, fee rounded to cents.

**Hints:**
1. The join condition is a range, not an equality.
2. Find a debit that sits exactly on a tier boundary. How many tiers does `between` match?

**Check yourself:** one row per posted debit, never two.

### J8. March spend by current segment (10 min)
**What this tests:** duplicate keys on the "one" side of a join.

**Scenario:** The CFO wants March spend by customer segment, using each customer's **current** segment.

**Your task:** `segment, spend`. Customers with no segment go under "unknown".

**Hints:**
1. Check whether `customer_id` is unique in `s_segments`.
2. Reduce the segment table to one row per customer before joining.

**Check yourself:** the segment totals add up to total March spend.

### S1. Latest transaction per account (8 min)
**What this tests:** correlated subqueries vs window functions, and ties.

**Your task:** the latest transaction per account (ignore rows with no account). Write it twice: with a correlated subquery using `max(txn_ts)`, and with a window function. If two transactions tie on time, keep the larger one.

**Hints:**
1. Compare the row counts of your two versions. Which account differs, and why?
2. Which ranking function returns exactly one row per group?

**Check yourself:** your window version returns one row per account.

### S2. Debits above the account's own average (8 min)
**What this tests:** comparing a row to its group's aggregate.

**Your task:** posted debits larger than their account's average posted debit: `txn_id, account_id, debit, avg_debit`.

**Hints:**
1. You need the average next to every row, without collapsing rows.
2. Can you filter on a window function in the same `select`'s `where`?

**Check yourself:** every row's debit is above the average shown beside it.

### S3. Top category per customer, keeping ties (8 min)
**What this tests:** top-N per group and tie handling.

**Your task:** each customer's top spending category (all time, posted debits). If two categories tie, return both.

**Hints:**
1. Aggregate to customer and category first.
2. `row_number`, `rank` and `dense_rank` differ only on ties. Which one keeps both?

**Check yourself:** one customer returns two rows.

### S4. Average March spend per active customer (6 min)
**What this tests:** two-step aggregation.

**Your task:** the average March spend per customer, counting only customers who spent in March.

**Hints:**
1. What does `avg(-amount)` over transactions actually average?
2. Aggregate per customer first, then average.

**Check yourself:** your answer is larger than the average transaction size.

### S5. Customers above the average (6 min)
**What this tests:** scalar subqueries and reusable CTEs.

**Your task:** customers whose March spend is above the average from S4.

**Hints:**
1. Reuse S4's per-customer step as a CTE.
2. A subquery in `where` must return exactly one value.

**Check yourself:** every returned customer's spend is above the S4 average.

### O1. Fix a slow query (15 min)
**What this tests:** spotting waste in a query and explaining the fix. Karat often asks this as a discussion question.

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
1. List every problem you see and why it hurts at scale.
2. Rewrite it to return March posted spend per customer, checking accounts only.
3. Say how you would prove your version is faster.

**Hints:**
1. Look at what's selected, what's joined but never used, and every function wrapped around a column in `where`.
2. Does one of the joins change the grain?

**Check yourself:** you found at least 5 problems, and your rewrite returns one row per customer.
