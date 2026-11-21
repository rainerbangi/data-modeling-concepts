# Drills

40 timed drills that make fact and dimensional modeling SQL automatic.
About a third of them involve change logs, the gap from the Afresh interview.

## Files
| File | What it is |
|---|---|
| `must_do.md` | The 15 drills to do first when preparing for an interview. |
| `answer-notebooks/` | One notebook per drill: the brief, setup cell, your answer and a review section. |
| `drill_bank.md` | The 40 drills: setup SQL, task, time limit. No answers. |
| `answer_key.md` | Shape, trap, solution SQL and expected result for each drill. Open only after you finish. |
| `log.md` | One line per attempt. Tells you what to do next. |

## Daily routine (20 minutes)
1. Open `log.md`. Do the next drill, or a redo that is due today.
2. Open that drill's notebook in `answer-notebooks/` and run its setup cell.
3. Start a timer. Say the grain and the shape out loud, then write your SQL from a blank editor. No notes.
4. Ask Genie Code: "Review my answer to drill N using my coach rules. Do not rewrite it."
5. Check `answer_key.md`. Compare your result to the expected rows.
6. Add one line to `log.md`. Commit.

## Pass or fail
Pass = correct result + within the time limit + you caught the trap.
Fail = redo the same drill 7 days later. Two passes in a row = mastered.

## Setup (once)
```sql
create schema if not exists workspace.drills;
use workspace.drills;
```
Every setup block assumes `use workspace.drills;`. Drill 1 builds `d01_dim_date`, which later drills reuse.

## Conventions used in every answer
- SCD2: `valid_from` inclusive, `valid_to` exclusive, open row `9999-12-31`.
- Sandwich join: `valid_from <= d and d < valid_to`.
- Exception: tables whose end dates are inclusive (promotions here) use `between`. Always check which kind of end date you have.
- No QUALIFY: filter `row_number()` results in a separate CTE, which works in every warehouse.

## Two rules that prevent wrong numbers

### 1. Missing state = null, missing events = 0

A missing row means different things depending on what the table records.

- **Events** record something that *happened*: a sale, a delivery, a shrink log. No row means nothing happened, so the value is **0**.
- **State** records something that *is true*: shelf capacity, stock on hand, price. No row means we don't know, so the value is **null**.

| Day | Sales rows | Capacity rows | units_sold | capacity |
|---|---|---|---|---|
| Mar 15 | none | none | 0 | null |

On Mar 15, the store sold nothing (0 is a fact), but capacity simply wasn't recorded (null is honest). Writing 0 for capacity would claim the shelf held nothing, and every ratio built on it would be wrong. In SQL: `coalesce(units_sold, 0)`, but leave capacity as it is.

### 2. Ratios: sum the parts, divide last

Never average or add up ratios. Add up the top and the bottom separately, then divide once.

| Store | Shrink $ | Sales $ | Shrink rate |
|---|---|---|---|
| A | 50 | 1,000 | 5% |
| B | 20 | 100 | 20% |

- Averaging the rates: (5% + 20%) ÷ 2 = **12.5%**. Wrong: tiny store B counts as much as store A.
- Summing the parts: (50 + 20) ÷ (1,000 + 100) = **6.4%**. Right: each dollar counts once.

In SQL: `sum(shrink_amt) / nullif(sum(sales_amt), 0)`. The `nullif` returns null instead of an error when sales are 0.

The same rule applies to every ratio: days of cover, sell-through, on-time rate. It's also why aggregate tables store the **parts** (sums), never only the ratio.
