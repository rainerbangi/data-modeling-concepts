# SQL Sprint

Prep for the OnePay Karat SQL interview: **Wednesday, Nov 25, 2:00 PM ET**.

You only need two notebooks:
- **`1_drills`**: where you work. Every drill has an empty cell for your answer.
- **`2_answers`**: where you check. Open a drill's answer only after you've tried it.

---

## Step 1: Set up (once, 5 minutes)

1. In Databricks, open `drills/sql-sprint/1_drills`.
2. Attach **Serverless** compute (top right).
3. Run the first two code cells. They create the practice tables.

---

## Step 2: Follow this plan

Work top to bottom. Tick each box as you go.

### Monday night (about 3 hours)

- [ ] **Part 1: Discussion warm-up** (P1 to P4, B1 to B4). Say each answer out loud before running it. 20 minutes.
- [ ] **Part 2: Joins** (J1 to J8). About 10 minutes each.

### Tuesday night (about 3 hours)

- [ ] **Part 3: Subqueries and windows** (S1 to S7). About 10 minutes each.
- [ ] **Part 4: Optimization** (O1, O2). O2 is spoken, not written.
- [ ] **Quick-fire questions** (last cell of `1_drills`). Answer all 30 out loud, about 30 seconds each.

### Wednesday morning (about 1.5 hours)

- [ ] **Part 5: Mock round** (M1). 40 minutes, timer on, talking out loud the whole time.
- [ ] Redo the **two drills you found hardest**, without notes.
- [ ] Run Karat's **AV test** and open **Karat Studio** so nothing surprises you.
- [ ] **Stop studying an hour before** the interview.

---

## Step 3: How to do each drill

1. **Read** the brief: the scenario, the output it asks for, and "Clarify first" if there is one.
2. **Start a timer** for the minutes in the drill's title.
3. **Write your answer** in the empty cell under the drill and run it.
4. **Stuck for 10 minutes?** Read one hint, then try again.
5. **Check** in `2_answers` under the same drill ID (for example, J3).
6. **Missed it?** Add it to your list for Wednesday morning.

---

## Step 4: In the interview

For every SQL question, follow the same six moves:

1. **Clarify:** "Do declined transactions count? Should customers with no activity show 0?"
2. **Say the grain:** "One row per customer."
3. **Build in steps:** one CTE per step, so each piece can be checked.
4. **Check row counts:** did a join multiply rows?
5. **Talk while you type:** silence costs more than a small mistake.
6. **Mention performance in one line:** "At scale I'd filter on the raw date column so files can be skipped."

**What to expect:** about 5 minutes of introductions, about 10 minutes of quick discussion questions, then about 40 minutes of SQL. The SQL is usually one schema with several parts that get harder. Getting through more parts matters more than perfecting one.
