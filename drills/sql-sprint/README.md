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

1. **Read** what's being asked.
2. **Set a timer** for the minutes shown.
3. **Write and run** your answer in the empty cell.
4. **Stuck after 10 minutes?** Read one hint.
5. **Check** your answer in `2_answers` (same drill number).
6. **Note any misses** to redo Wednesday morning.

---

## Step 4: In the interview

**The hour:** about 5 minutes of introductions, 10 minutes of quick questions, then 40 minutes of SQL that gets harder in stages. Finishing more stages beats perfecting one.

**For each question:**

1. **Confirm the rules first.** "Should customers with no purchases show zero?"
2. **Say what one row means.** "One row per customer."
3. **Build it in small steps,** checking each one.
4. **Check the totals.** A wrong join quietly duplicates rows.
5. **Think out loud.** Silence costs more than a small mistake.
6. **Mention speed briefly.** "On a large table, I'd filter by date first."
