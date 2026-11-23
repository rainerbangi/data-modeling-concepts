# SQL Sprint (PostgreSQL)

**Interview:** Wednesday, Nov 25, 2:00 PM ET · Karat Studio · PostgreSQL

| File | Use it to |
|---|---|
| `1_drills.md` | Practice. Each drill has a setup to paste, a task and hints |
| `2_answers.md` | Check your answer after each drill |
| `cheatsheet.md` | Translate Databricks habits to Postgres. Keep it open in the interview |
| `progress.md` | Log each attempt and build your redo list |

---

## 1. Set up (once)

Open your Karat dashboard, launch **Karat Studio**, choose **PostgreSQL**.

---

## 2. Plan

**Monday night**
- [ ] Read "the 5 that will bite you" at the top of `cheatsheet.md`
- [ ] Part 1: Read it first (R1 to R8)
- [ ] Part 2: Joins (J1 to J5)

**Tuesday night**
- [ ] Part 3: Aggregation (A1 to A3)
- [ ] Part 4: Window functions (W1 to W7)
- [ ] Part 5: Modeling and performance (D1, O1, O2)
- [ ] Quick-fire questions, out loud

**Wednesday morning**
- [ ] Part 6: Mock round (M1), 40 minutes, out loud
- [ ] Your redo list in `progress.md`

---

## 3. Each drill

**Paste the setup → set a timer → write your query below it → one hint if stuck → check `2_answers.md` → log it in `progress.md`.**

Karat Studio rebuilds the tables on every run, so keep the setup at the top of the editor.

---

## 4. Interview day

### Before the call

| When | Do this |
|---|---|
| 60 min before | Stop studying. Eat, drink water. |
| 30 min before | Open Karat Studio, choose PostgreSQL, run `select 1;`. Open `cheatsheet.md` in another tab. |
| 10 min before | Headphones on, camera and mic checked, phone silent. |

### The hour

| Minutes | What happens | What you do |
|---|---|---|
| 0 to 5 | Introductions | Your 60-second pitch. Then ask: *"Is it OK if I keep a syntax cheatsheet open?"* |
| 5 to 15 | Quick questions | 30-second answers out loud. If unsure, say how you'd find out. |
| 15 to 55 | SQL problem, in stages that get harder | The six moves below, for every stage. Finishing more stages beats perfecting one. |
| 55 to 60 | Your questions | Ask one: *"What does the team's day-to-day work look like?"* |

### The six moves, for every SQL question

1. **Confirm the rules.** *"Should users with no purchases show zero, or be left out?"* Two correct queries can give different answers if they assume different rules. Ask first.
2. **Say what one row means.** *"One row per user."* That's your target. A user appearing twice tells you something's wrong.
3. **Build in small steps.** One CTE at a time: run it, look at it. A mistake caught early takes seconds to fix.
4. **Check the totals.** A careless join quietly copies rows (see "A result looks wrong" below).
5. **Think out loud.** *"I'm using a left join so users with no purchases stay in."* The interviewer can only score what they hear.
6. **Mention speed in one line.** *"On a large table, I'd index `user_id` and filter by date first."* Go deeper only if asked.

### If something goes wrong

| Situation | Do this |
|---|---|
| An error | Read it out loud. Most are Databricks habits: `qualify`, `date_add`, `datediff`, `5 / 2`. Check the cheatsheet. |
| Stuck | *"Let me write the simple version first."* A working simple answer beats an unfinished perfect one. |
| Forgot syntax | *"I'll check the docs for this."* Karat allows it if you say so. |
| A result looks wrong | Almost always a join copied rows. Run the three checks below. |
| Running out of time | Say the rest out loud: *"Next I'd rank them with a window function."* You get credit for the plan. |

### A result looks wrong: three checks

**1. Do the rows match what one row should mean?** If the answer is "one row per user", these two numbers must be equal:
```sql
select count(*) as total_rows, count(distinct user_id) as users
from ( /* your query, without the final semicolon */ ) q;
```
More rows than users means a join copied some users.

**2. Which join did it?** Count rows after each step. The count jumps at the join that copies. Example from drill J2:

| Step | Rows | What it means |
|---|---|---|
| transactions | 7 | one row per transaction |
| + accounts | 7 | still one per transaction: each belongs to one account. Fine |
| + refunds | 8 | transaction 6 has 2 refunds, so it now appears **twice** |

**3. Does a total match the source table?** Compare with the raw sum:
```sql
select sum(-amount) from transactions where status = 'posted' and amount < 0;   -- 955
```
In J2, summing spend after joining refunds gives 1,155: transaction 6's 200 was counted twice.

**How to fix it:**
- **Aggregate first, then join.** Total refunds per user in their own CTE, then join that one row per user.
- **Deduplicate the lookup table.** Keep one row per key with `row_number()` or `distinct on`.
- **Check the join condition.** A missing column in `on` matches far too many rows.
