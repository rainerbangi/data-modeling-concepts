# CLAUDE.md

This repo trains Rainer to be a strong analytics engineer: dimensional modeling, SQL, semantic layers and AI agents, on Databricks. The learning matters more than the code.

## Repo layout

| Path | What it holds | Rule |
|---|---|---|
| `drills/drill_bank.md` | All 40 drill briefs with setup SQL | No answers |
| `drills/answer-notebooks/` | One Databricks notebook per drill | No answers in the task cell |
| `drills/answer_key.md` | Explanations, solution SQL, expected results | The only place answers live |
| `drills/must_do.md` | The 15 interview-priority drills | Keep in sync with drill numbers |
| `drills/log.md` | Rainer's attempt log | Edit only when asked |

## Editing drills

- A drill brief has, in order: **What this tests**, **Scenario**, **Raw data**, **Your task**, **Hints** (2 or 3, gentle to specific), **Check yourself**.
- "Check yourself" describes what a correct result looks like (row counts, invariants). It never gives the numbers.
- A brief lives in two places: `drill_bank.md` and the first cell of its notebook. Change both together.
- In a notebook, change only the first (task) cell. Never touch the **My answer** or **Review** cells: they hold Rainer's work.
- Setup SQL, solution SQL and "Expected" results must agree. Before changing any of them, run the setup and solution and confirm the result.
- An answer follows this order: the idea, shape and grain, the trap, think it through (one step per CTE), SQL, expected, why this way.

## Modeling conventions

- Layers: raw, staging, intermediate, marts. Names: `stg_<source>__<entity>`, `int_<entity>_<what>`, `dim_`, `fct_`, `agg_`.
- State every fact's grain in one sentence: "one row per store, item and day."
- Aggregate each source to the grain before joining. Use a full outer join to combine feeds.
- SCD2: `valid_from` included, `valid_to` excluded, open row `9999-12-31`. Join with the sandwich: `valid_from <= d and d < valid_to`. Use `between` only for inclusive end dates (such as promotions).
- Change log to SCD2: clean (latest per day), collapse (drop repeats), close (`lead`), then expand to days if needed. Filter after window functions, not before.
- Missing state = null; missing events = 0.
- Measures: events add, levels average across time, rates and distinct counts recompute.
- Ratios: sum the parts, divide last, `nullif` the denominator.
- No `qualify`: filter `row_number()` in a separate CTE.
- Unknown dimension member uses key `-1`, so fact rows are never dropped.
- Tests return rows only when something is wrong (grain, overlap, reconciliation).

## Working with Rainer

- Coach, don't author: when he's practicing, give hints and reviews, not full answers, unless he asks.
- Plain English, short sentences, concise. No em dashes.
- Explain with a tiny data example when it helps.
- Work on a branch and open a pull request for his review. Don't push to `main`.
