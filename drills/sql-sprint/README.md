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

1. **Set a timer** and write your answer in the empty cell.
2. **Stuck?** Read one hint.
3. **Check** it in `2_answers`, and note any misses for Wednesday.

---

## Step 4: In the interview

**The hour:** about 5 minutes of introductions, 10 minutes of quick questions, then 40 minutes of SQL that gets harder in stages. Finishing more stages beats perfecting one, because each stage builds on the last and the interviewer scores how far you get.

**For each question:**

1. **Confirm the rules first.** *"Should customers with no purchases show zero, or be left out?"*
   Most questions hide a choice like this. Two people can write correct SQL and get different answers because they assumed different rules. Asking first shows judgment and saves you from rewriting later.

2. **Say what one row means.** *"One row per customer."*
   This is the target for your answer. If the result should have one row per customer and you see a customer twice, you know something is wrong before anyone else does.

3. **Build it in small steps, checking each one.**
   Write one piece, run it, look at it, then add the next, like testing each brick before building the wall. A mistake caught at step one takes seconds to fix; found at the end, it takes minutes you don't have.

4. **Check the totals.**
   Joining two tables can quietly copy rows. Example: one customer with two accounts and a $100 purchase becomes $200 after a careless join. A quick count or total before and after each join catches this, and it's the most common SQL mistake interviewers look for.

5. **Think out loud.**
   The interviewer can only score what they can hear. Saying *"I'm using a left join so customers with no purchases stay in"* earns credit even if the final query has a small slip. Silence earns nothing.

6. **Mention speed briefly.** *"On a large table, I'd filter by date first."*
   One sentence shows you've worked with real data volumes: reading less data is the biggest speed-up. Don't go deeper unless they ask.
