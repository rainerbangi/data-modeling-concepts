# SQL Sprint: Joins, Subqueries and Optimization

A focused prep set for a live Karat SQL interview. Everything you need is in two notebooks.

## Start here

| Open | What it is |
|---|---|
| `1_drills` | Run the setup cells once, then work through the drills. Empty answer cells under each one. |
| `2_answers` | Solutions you can run, expected results and likely follow-up questions. Open only after each drill. |

## The interview format (Karat)

About 60 minutes on video, in Karat Studio:

| Segment | Time | What to expect | Practice with |
|---|---|---|---|
| Intro | ~5 min | Who you are, your current work | A 60-second pitch |
| Discussion | ~10 min | Quick questions out loud: concepts, "what does this return?", "what's wrong with this?", "how would you speed this up?" | Part 1, O2, quick-fire questions |
| SQL | ~40 min | One schema, several parts that get harder | Parts 2 to 4, then the M1 mock |

You're scored on getting through parts, clarifying assumptions and explaining your thinking. Silence costs more than a small mistake.

## The plan

| When | Time | What |
|---|---|---|
| Mon night | 3 h | Setup. Part 1 out loud. Part 2, J1 to J8. |
| Tue night | 3 h | Part 3, S1 to S7. Part 4, O1 and O2. Quick-fire questions out loud, timed. |
| Wed morning | 1.5 h | M1 mock round, 40 minutes, out loud. Redo your two weakest drills. Run the Karat AV test. Stop an hour before. |

## In the interview, for every SQL question

1. **Clarify:** nulls, duplicates, date boundaries, what "active" means.
2. **Say the grain:** "One row per customer."
3. **Build in CTEs**, one step each.
4. **Check row counts** as you go: did a join multiply rows?
5. **Talk while typing.**
6. **Mention performance in one line** when relevant.
