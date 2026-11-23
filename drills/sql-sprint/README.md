# SQL Sprint: Joins, Subqueries and Optimization

A short, focused drill set for a live SQL interview. 14 drills on one small payments dataset, plus 25 quick-fire discussion questions.

| File | What it is |
|---|---|
| `sql_sprint_notebook.sql` | The Databricks notebook: setup cell, every drill brief and a blank answer cell for each |
| `drills.md` | The same drill briefs, for reading |
| `setup.sql` | The dataset on its own |
| `answer_key.md` | Solutions, expected results and quick-fire answers. Open only after each drill |

## The dataset

| Table | One row means | Watch for |
|---|---|---|
| `s_customers` | a customer; `referred_by` points to another customer | a referrer that doesn't exist |
| `s_accounts` | an account owned by a customer | a customer with two accounts, one with none, an account whose customer is missing |
| `s_transactions` | a transaction; negative amount = money out | declined and pending rows, a null `account_id`, two rows with the same timestamp |
| `s_refunds` | a refund of a transaction | one transaction refunded twice |
| `s_fee_tiers` | a fee band (`min_amt` included, `max_amt` excluded) | a debit exactly on a boundary |
| `s_segments` | a segment change for a customer | a customer with two rows |

**Spend** always means posted debits (`status = 'posted'` and `amount < 0`), shown as a positive number.

## The interview format (Karat)

About 60 minutes: a short intro, roughly 10 minutes of quick discussion questions, then roughly 40 minutes of SQL questions in several parts that get harder. Getting through more parts matters more than polishing one.

## The plan

| When | Time | What |
|---|---|---|
| Night 1 | 2.5 h | Setup, then J1 to J8. Check the answer key after each one. Note every miss. |
| Night 2 | 2.5 h | S1 to S5 and O1. Then answer the quick-fire questions out loud, timed. Redo last night's misses cold. |
| Interview morning | 1 h | Redo J2, J3, J4 and S1 cold. Skim the quick-fire answers. Run the Karat AV test and open Karat Studio. Then stop studying. |

Rule for each drill: set a timer, write it, run it, then check. If you're stuck for 10 minutes, read one hint at a time.

## In the interview, for every SQL question

1. **Restate and clarify:** "Should customers with no activity show 0? Count declined transactions? Which time zone?"
2. **Say the grain:** "One row per customer."
3. **Build in CTEs:** one step per CTE, so you can check each one.
4. **Check as you go:** run each CTE and glance at the row count. Did a join multiply rows?
5. **Talk while typing:** say why you chose a left join, `exists` or a window.
6. **Mention performance in one line** when relevant: "At scale I'd filter on the raw date column so the engine can skip files."

## Quick-fire questions

Answer each in two or three sentences, out loud, in under 30 seconds. Answers are at the end of `answer_key.md`.

1. What's the difference between an inner and a left join?
2. What changes if a filter on the right table moves from `ON` to `WHERE` in a left join?
3. What are a semi-join and an anti-join? How do you write them?
4. Why avoid `not in` with a subquery?
5. `union` vs `union all`?
6. `where` vs `having`?
7. What is a correlated subquery, and when would you replace it?
8. CTE vs subquery vs temp table?
9. Window function vs `group by`?
10. `row_number` vs `rank` vs `dense_rank`?
11. `count(*)` vs `count(col)` vs `count(distinct col)`?
12. How do aggregates treat nulls?
13. Is `null = null` true?
14. What is fan-out, and how do you prevent it?
15. In what order does SQL run its clauses?
16. A query got slow. How do you narrow down the cause?
17. Indexes vs partitioning vs clustering?
18. What is predicate pushdown?
19. What is a broadcast join?
20. What is data skew, and how do you handle it?
21. Why is `select *` bad in a warehouse?
22. Normalization vs denormalization?
23. OLTP vs OLAP?
24. How do you deduplicate a table?
25. Which modern SQL features do you use?
