# Must-Do Drills for Interview Prep

15 drills that cover every pattern an analytics engineering interview tests. Every other drill is listed under the must-do that teaches the same pattern, so the table accounts for all 40. If time is short, do the must-dos and read the rest in `answer_key.md`.

## The list, in order

| Order | Drill | Area | Pattern | Why interviewers ask it | Also covers |
|---|---|---|---|---|---|
| Start | 1 Date dimension | Setup | Calendar built from generated dates | Every model joins to a calendar; later drills reuse `d01_dim_date` | |
| 1 | 17 Reloaded rows | Transaction facts | Latest row per key (`row_number`) | The most common SQL screen question | |
| 2 | 18 Returns and voids | Transaction facts | `not exists` vs `not in` with nulls | A classic null gotcha | |
| 3 | 20 Two feeds, one fact | Transaction facts | Aggregate first, then full outer join | Fan-out is the core modeling mistake | 21, 29 |
| 4 | 22 Counting customers | Measure types | Non-additive measures | The daily vs weekly active users trap | |
| 5 | 6 Promotions that share items | Many-to-many | Many-to-many bridge, double counting | Tests whether you notice duplicates | 37 |
| 6 | 19 A corrected file arrives | Loading | Idempotent loads (`replace where`) | Incremental loading and backfills | |
| 7 | 4 Nightly full dump | Dimensions and SCD2 | SCD2 from a full snapshot (`merge`) | The SCD2 question in its most common form | 3 |
| 8 | 11 Next-day effect and a start date | Change logs and SCD2 | Change log to SCD2 (clean, collapse, close) | The Afresh gap; real business rules | 7, 9, 10, 12, 13, 14 |
| 9 | 34 Shrink by category, as-was vs as-is | Dimensions and SCD2 | SCD2 joined to a fact, two ways | "Category then or now?" is a top modeling question | 2, 5, 16, 35 |
| 10 | 25 Stock from movements | Snapshots | Date spine + running total | Window functions and filling quiet days | 24, 36 |
| 11 | 27 Purchase order lifecycle | Snapshots | Accumulating snapshot (pivot with `case`) | Conditional aggregation and process metrics | 15, 38 |
| 12 | 30 Stockout streaks | Window functions | Gaps and islands | The classic "hard" SQL question | |
| 13 | 31 Same period last year | Comparisons over time | Self-join on period; points vs percent | Year-over-year metrics | 39 |
| 14 | 32 Write the tests | Testing | Grain, overlap and reconciliation tests | Shows you prove your models right | 26, 28 |
| 15 | 33 The Afresh problem | End to end | Everything end to end, plus a semi-additive measure | Your main story; a full modeling round | 8, 23 |
| Finish | 40 Full mock | Mock interview | Questions, shapes, model, SQL, edge cases, tests | A 45-minute rehearsal, out loud and recorded | |

## How to use it

- Start with drill 1, then work down the list in order; later drills build on earlier ones. Finish with drill 40.
- For each one, read the "Also covers" drills in `answer_key.md` afterwards (5 minutes each). Same pattern, different disguise.
- Log every attempt in `log.md`. A drill counts as done after two passes in a row.
