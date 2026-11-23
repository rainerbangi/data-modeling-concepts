# SQL Sprint: Joins, Subqueries and Optimization

A focused drill set for a live Karat SQL interview, built to match its format: quick discussion questions first, then one schema with several SQL parts that get harder. 30 exercises on one small payments dataset, plus 30 quick-fire questions.

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
| `s_transactions` | a transaction; a negative amount is money out | declined and pending rows, a null `account_id`, two rows with the same timestamp, a customer with a month of no spend, a transaction dated before its account was opened |
| `s_refunds` | a refund of a transaction | one transaction refunded twice |
| `s_fee_tiers` | a fee band (`min_amt` included, `max_amt` excluded) | a debit exactly on a boundary |
| `s_segments` | a segment change for a customer | a customer with two rows |

**Spend** always means posted debits (`status = 'posted'` and `amount < 0`), shown as a positive number.

## The interview format (Karat)

About 60 minutes on a video call, in Karat Studio:

| Segment | Time | What to expect | Practice with |
|---|---|---|---|
| Intro | ~5 min | Who you are, your current work | A 60-second pitch |
| Discussion | ~10 min | Short questions answered out loud: concepts, "what does this return?", "what's wrong with this?", "how would you speed this up?" | Quick-fire questions, Part 1, O2 |
| SQL | ~40 min | One schema, several parts, each harder: aggregation, joins, conditional aggregation, window functions, rolling or month-over-month metrics | Parts 2 to 5, then the M1 mock |

You're scored on getting through parts, clarifying assumptions (nulls, duplicates, date boundaries) and explaining your thinking. Silence costs more than a small mistake.

## The drills

| Part | Drills | Focus |
|---|---|---|
| 1. Discussion warm-up | P1 to P4, B1 to B4 | Predict the output; spot the bug |
| 2. Joins | J1 to J8 | Join types, left-join filters, fan-out, anti- and semi-joins, self-joins, range joins, duplicate keys |
| 3. Subqueries and windows | S1 to S7 | Correlated subqueries vs windows, top-N with ties, two-step aggregation, conditional aggregation, month-over-month with missing months |
| 4. Optimization | O1, O2 | Fix a slow query; the "it got slow" talk track |
| 5. Mock round | M1 (5 parts) | A full 40-minute Karat-style question, timed and out loud |

## The plan

| When | Time | What |
|---|---|---|
| Night 1 (Mon) | 3 h | Setup. Part 1 out loud (20 min). Part 2, J1 to J8. Check the answer key after each drill and note every miss. |
| Night 2 (Tue) | 3 h | Part 3, S1 to S7. Part 4, O1 and O2. Then the 30 quick-fire questions out loud, timed. |
| Interview morning (Wed) | 1.5 h | M1 mock round, 40 minutes, timed and out loud. Then redo your two weakest drills cold. Run the Karat AV test and open Karat Studio. Stop studying an hour before. |

Rule for each drill: set a timer, write it, run it, then check. If you're stuck for 10 minutes, read one hint at a time.

## In the interview, for every SQL question

1. **Restate and clarify:** "Should customers with no activity show 0? Count declined transactions? Which time zone?"
2. **Say the grain:** "One row per customer."
3. **Build in CTEs:** one step per CTE, so you can check each one.
4. **Check as you go:** run each CTE and glance at the row count. Did a join multiply rows?
5. **Talk while typing:** say why you chose a left join, `exists` or a window.
6. **Mention performance in one line** when relevant: "At scale I'd filter on the raw date column so the engine can skip files."

## Quick-fire questions

Answer each in two or three sentences, out loud, in under 30 seconds. Answers are at the end of `answer_key.md`. Questions 26 to 30 come up often in Karat's discussion segment.

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
26. What does ACID mean?
27. Primary key vs foreign key? Are they enforced in a warehouse?
28. View vs materialized view vs table?
29. When would you choose a relational database over NoSQL?
30. Star schema vs snowflake schema?
