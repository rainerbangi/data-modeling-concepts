# SQL Sprint (PostgreSQL)

Prep for the OnePay Karat SQL interview: **Wednesday, Nov 25, 2:00 PM ET**.

Karat Studio offers **PostgreSQL** and MySQL, with no tables loaded. You'll create your own tables and write Postgres syntax, so these drills are in Postgres.

| File | What it's for |
|---|---|
| `1_drills.md` | The drills. Each has a setup script to paste, the task and hints |
| `2_answers.md` | Tested answers and follow-up questions. Open after each drill |
| `cheatsheet.md` | Databricks habit on the left, Postgres on the right. Keep it open in the interview (tell the interviewer first) |
| `progress.md` | Your tracker: one line per attempt, plus a redo list |

**In one sentence:** practice each drill in Karat Studio, check it, log it, and on Wednesday follow the play-by-play at the bottom of this page.

---

## Step 1: Set up (once, 5 minutes)

1. Open your Karat **interview dashboard** and launch the **Karat Studio** practice environment.
2. Choose **PostgreSQL**.
3. For each drill, paste its **Setup** at the top of the editor and write your query under it. Studio rebuilds the tables on every run, so keep the setup in place.

---

## Step 2: Follow this plan

### Monday night (about 3 hours)
- [ ] Skim `cheatsheet.md`, especially "the 5 that will bite you". 10 minutes.
- [ ] **Part 1: Read it first** (R1 to R8). Say each answer out loud before running it.
- [ ] **Part 2: Joins** (J1 to J5).

### Tuesday night (about 3 hours)
- [ ] **Part 3: Aggregation** (A1 to A3).
- [ ] **Part 4: Window functions** (W1 to W7).
- [ ] **Part 5: Modeling and performance** (D1, O1, O2).
- [ ] **Quick-fire questions** (end of `1_drills.md`), out loud.

### Wednesday morning (about 1.5 hours)
- [ ] **Part 6: Mock round** (M1). 40 minutes, timer on, out loud.
- [ ] Redo everything on your **redo list** in `progress.md`.
- [ ] Run Karat's **AV test**. Stop studying an hour before.

---

## Step 3: How to do each drill

1. **Set a timer** and write your answer under the setup.
2. **Stuck?** Read one hint.
3. **Check** it in `2_answers.md`, then **log it** in `progress.md`.

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

---

## Step 5: Interview day, play by play

### Before the call

| When | What to do | Why |
|---|---|---|
| 60 min before | Stop studying. Eat, water, bathroom. | A rested brain beats one more drill. |
| 30 min before | Open Karat Studio, choose **PostgreSQL**, run a tiny test (`select 1;`). Open `cheatsheet.md` in another tab. | No surprises with the tool or the language. |
| 10 min before | Headphones on, camera and mic checked, phone silent. Read "the 5 that will bite you" once. | You start calm, with the traps fresh in mind. |

### During the hour

| Minutes | What happens | What you do |
|---|---|---|
| 0 to 5 | **Introductions** | Give your 60-second pitch: who you are, what you build, why this role. Then say: *"I'll be using PostgreSQL. Is it OK if I keep a syntax cheatsheet open?"* |
| 5 to 15 | **Quick questions** | Short answers out loud, about 30 seconds each, like the quick-fire drills. If you don't know, say how you'd find out. |
| 15 to 55 | **The SQL problem**, in stages that get harder | For each stage: confirm the rules, say what one row means, build in small steps, check totals, think out loud (Step 4). |
| 55 to 60 | **Your questions** | Ask one: *"What does the analytics team's work look like day to day?"* |

### If something goes wrong

| Situation | What to say or do |
|---|---|
| You get an error | Read it out loud, then fix it. Most are syntax from the cheatsheet: `qualify`, `date_add`, `datediff`, `5 / 2`. |
| You're stuck | *"Let me write the simple version first, then improve it."* A working simple answer beats an unfinished perfect one. |
| You forget syntax | *"I'll check the docs for this one."* Karat allows it if you say so. |
| A result looks wrong | Count rows: `select count(*) from ...`. A wrong join usually shows up as too many rows. |
| Time is running out | Describe the rest out loud: *"Next I'd add a window function to rank them."* You get credit for the plan. |
