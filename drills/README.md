# Drills

40 timed drills that make fact and dimensional modeling SQL automatic.
About a third of them involve change logs, the gap from the Afresh interview.

## Files
| File | What it is |
|---|---|
| `drill_bank.md` | The 40 drills: setup SQL, task, time limit. No answers. |
| `answer_key.md` | Shape, trap, solution SQL and expected result for each drill. Open only after you finish. |
| `log.md` | One line per attempt. Tells you what to do next. |

## Daily routine (20 minutes)
1. Open `log.md`. Do the next drill, or a redo that is due today.
2. Open that drill in `drill_bank.md`. Run its setup SQL in the SQL editor.
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
- No QUALIFY. Missing state = null, missing events = 0. Ratios: sum the parts, divide last.
