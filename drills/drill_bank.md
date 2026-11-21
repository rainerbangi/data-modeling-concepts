# Drill Bank

Run each setup block in `workspace.drills`. Do not look at `answer_key.md` until you finish.
Before writing SQL, say out loud: (1) what one row of each raw table means, (2) the shape, (3) the grain of your output.

| Block | Drills | Focus |
|---|---|---|
| A | 1 to 6 | Dimensions |
| B | 7 to 16 | Change logs |
| C | 17 to 22 | Transaction facts |
| D | 23 to 29 | Snapshots, processes, coverage |
| E | 30 to 32 | Analysis and tests |
| F | 33 to 40 | Combos (interview style) |

---

## A. Dimensions

### Drill 1: Date dimension (10 min)
**What this tests:** building a dimension from nothing, date functions, and calendar rules that differ from the defaults (week start, fiscal year).

**Scenario:** Every model you build next will join to a calendar. The business plans in **weeks that start on Sunday** and a **fiscal year that starts Feb 1** (named by the year it starts in: Feb 2025 to Jan 2026 is fiscal 2025).

**Raw data:** none. You generate the dates yourself.

**Your task:** create `d01_dim_date`, one row per day from 2025-12-01 to 2026-12-31, with:

| Column | Meaning |
|---|---|
| calendar_date | the date |
| day_name | Monday, Tuesday, ... |
| week_start | the Sunday that starts this date's week |
| month | 1 to 12 |
| fiscal_year | per the rule above |
| is_weekend | true on Saturday and Sunday |

**Hints** (one at a time, only if stuck):
1. Two functions together turn a start and end date into one row per day.
2. Check what day of the week Databricks counts as 1, and what `date_trunc('week', ...)` returns.
3. Only one month of the year breaks the "fiscal year = calendar year" rule.

**Check yourself:** 396 rows. Spot-check one Saturday's week_start and one January date's fiscal_year against the rules. Later drills reuse this table.

### Drill 2: Keys that never drop rows (8 min)
**What this tests:** surrogate keys, and protecting fact rows from missing dimension rows (orphans).

**Scenario:** Finance says the sales dashboard shows fewer units than the POS system. You suspect some sales point to stores that aren't in the store table.

**Raw data:**
- `d02_stores`: one row per known store.
- `d02_sales`: one row per sale, with `store_id` and `units`. Some `store_id` values are unknown, and one is missing.

**Setup** (run first):
```sql
create or replace table d02_stores as
select * from values ('A','Store A'), ('B','Store B') as t(store_id, store_name);
create or replace table d02_sales as
select * from values (1,'A',5), (2,'B',3), (3,'Z',2), (4,cast(null as string),1)
as t(sale_id, store_id, units);
```

**Your task:**
1. Build `d02_dim_store (store_key, store_id, store_name)` with a surrogate key.
2. Write the sales fact query with `sale_id, store_key, units`.

Every sale must appear, and total units must equal the source total.

**Hints:**
1. What does an inner join do to a sale whose store isn't in the dimension?
2. Data warehouses often keep one special dimension row for "we don't know which store".
3. A hash of the business key gives the same surrogate key every time you rebuild.

**Check yourself:** every sale appears once, and total units equal the source table's total.

### Drill 3: Fix typos, keep no history (8 min)
**What this tests:** SCD Type 1 with `MERGE`, idempotent loads, and comparing values that can be null.

**Scenario:** The store master has typos and missing regions. The business wants them fixed in place; nobody needs to know the old wrong values.

**Raw data:**
- `d03_dim_store`: your current dimension.
- `d03_incoming`: today's corrected store list, including a new store.

**Setup** (run first):
```sql
create or replace table d03_dim_store as
select xxhash64(store_id) as store_key, * from values
  ('A','Stor A','East'), ('B','Store B', cast(null as string))
as t(store_id, store_name, region);
create or replace table d03_incoming as
select * from values ('A','Store A','East'), ('B','Store B','West'), ('C','Store C','South')
as t(store_id, store_name, region);
```

**Your task:** write one statement that applies `d03_incoming` to `d03_dim_store`:
- update stores whose name or region changed,
- insert new stores,
- running it a second time must change nothing.

**Hints:**
1. One SQL statement can update matches and insert non-matches.
2. Look at store B's old region. What does `null <> 'West'` return?
3. Only update rows that actually changed, or a rerun rewrites everything.

**Check yourself:** running your statement a second time affects 0 rows.

### Drill 4: Nightly full dump (12 min)
**What this tests:** building SCD Type 2 from a source that only shows **current** values.

**Scenario:** The item system can't send changes. Every night it sends the **whole** item list as it is now. Merchandising wants to report sales by the category an item had *at the time*, so you must keep history.

**Raw data:**
- `d04_dim_item`: your SCD2 item dimension (`valid_from`, `valid_to`, `is_current`).
- `d04_dump_0302`: the full item list sent on 2026-03-02.

**Setup** (run first):
```sql
create or replace table d04_dim_item as
select xxhash64(item_id, date'2026-03-01') as item_key, item_id, category,
       date'2026-03-01' as valid_from, date'9999-12-31' as valid_to, true as is_current
from values ('STRAW','Berries'), ('BLUE','Berries') as t(item_id, category);
create or replace table d04_dump_0302 as
select * from values ('STRAW','Fresh Berries'), ('BLUE','Berries'), ('KIWI','Tropical')
as t(item_id, category);
```

**Your task:** apply the Mar 2 dump so category history is kept: close versions that changed, open new versions, and add new items. Unchanged items stay as they are.

**Hints:**
1. Compare tonight's list with only the **current** version of each item.
2. A changed item needs two actions: close the old version and open a new one. Can one `MERGE` row do both?
3. After closing, "which items have no current version?" catches both changed and brand-new items.

**Check yourself:** exactly one current row per item, and unchanged items keep their original row.

### Drill 5: One fact, two dates (8 min)
**What this tests:** role-playing dimensions, and keeping rows whose second date isn't known yet.

**Scenario:** The supply chain team wants delivery volume by the week a PO was **ordered** and the week it was **received**, in one table.

**Raw data:** `d05_deliveries`, one row per purchase order, with `ordered_date`, `received_date` (null if not delivered yet) and `units`.

**Setup** (run first):
```sql
create or replace table d05_deliveries as
select * from values
  (101, date'2026-03-02', date'2026-03-09', 40),
  (102, date'2026-03-04', date'2026-03-05', 20),
  (103, date'2026-03-10', cast(null as date), 30)
as t(po_id, ordered_date, received_date, units);
```

**Your task:** one query returning `ordered_week, received_week, units`, using `d01_dim_date` for the weeks. POs not yet received must still appear.

**Hints:**
1. You need the date table twice in one query. How do you tell the two apart?
2. One of the two dates can be null. Which join keeps that row?

**Check yourself:** total units equal the source total, and POs not yet received still appear.

### Drill 6: Promotions that share items (12 min)
**What this tests:** many-to-many relationships (bridge tables) and double counting.

**Scenario:** Marketing asks two questions: "How many units did each promo drive?" and "How many units in total were sold while on any promo?"

**Raw data:**
- `d06_promos`: one row per promo, with start and end dates (**end date inclusive**).
- `d06_promo_items`: which items each promo covers (a bridge: one row per promo and item).
- `d06_sales`: one row per sale.

**Setup** (run first):
```sql
create or replace table d06_promos as
select * from values ('P1', date'2026-03-01', date'2026-03-07'), ('P2', date'2026-03-05', date'2026-03-10')
as t(promo_id, start_date, end_date);          -- end_date is INCLUSIVE
create or replace table d06_promo_items as
select * from values ('P1','STRAW'), ('P1','BLUE'), ('P2','STRAW') as t(promo_id, item_id);
create or replace table d06_sales as
select * from values
  (date'2026-03-06','STRAW',10), (date'2026-03-06','BLUE',4),
  (date'2026-03-09','STRAW',5),  (date'2026-03-12','STRAW',7)
as t(sale_date, item_id, units);
```

**Your task:** (a) units per promo; (b) total units sold while the item was on any promo.

**Hints:**
1. Look for a sale whose item and date fit **two** promos.
2. (a) and (b) are different questions; one can count a sale twice, the other can't.
3. For (b), you want a yes/no per sale: "is there any promo that covers it?"

**Check yourself:** (b) is smaller than the sum of your (a) rows. Can you explain why?

---

## B. Change logs

### Drill 7: Price changes (8 min)
**What this tests:** turning a change log into SCD2 with `LEAD`, and the open-ended current row.

**Scenario:** Pricing logs a row each time a price changes. Finance needs, for any day, the price that was in effect.

**Raw data:** `d07_price_changes`, one row per price change: `item_id, price, effective_date`.

**Setup** (run first):
```sql
create or replace table d07_price_changes as
select * from values
  ('STRAW', 3.99, date'2026-01-01'), ('STRAW', 4.49, date'2026-02-15'),
  ('STRAW', 3.79, date'2026-03-10'), ('BLUE', 2.99, date'2026-01-01')
as t(item_id, price, effective_date);
```

**Your task:** build `d07_price_scd2 (item_id, price, valid_from, valid_to)`, one row per price version. `valid_from` included, `valid_to` excluded, current price ending 9999-12-31. Save it as a table; drill 16 uses it.

**Hints:**
1. A version ends when the next one starts.
2. One window function looks at the next row in order.
3. What does that function return for the newest price, and why is that a problem for later joins?

**Check yourself:** one row per price change, and no `valid_to` is null.

### Drill 8: Shelf capacity to daily rows (10 min)
**What this tests:** expanding SCD2 ranges into daily rows, and the boundary-day bug.

**Scenario:** The forecasting model needs shelf capacity for **every** store, item and day, so it can sit next to daily sales.

**Raw data:** `d08_capacity_changes`, one row per capacity change: `store_id, item_id, capacity, changed_on`.

**Setup** (run first):
```sql
create or replace table d08_capacity_changes as
select * from values
  ('A','STRAW',50,date'2026-01-01'), ('A','STRAW',80,date'2026-03-15'),
  ('B','STRAW',60,date'2026-03-16')
as t(store_id, item_id, capacity, changed_on);
```

**Your task:** capacity for every store, item and day from 2026-03-13 to 2026-03-17: `calendar_date, store_id, item_id, capacity`.

**Hints:**
1. First close each version (drill 7), then join to the calendar.
2. Which versions contain a given date? Write the condition with both ends.
3. On the day capacity changes, how many versions does your condition match?

**Check yourself:** each store, item and day appears exactly once.

### Drill 9: Two changes on one day (10 min)
**What this tests:** deduplicating a change log to the grain of the history (the day).

**Scenario:** A manager set capacity to 70 in the morning and corrected it to 80 the same afternoon. Reports work at day level.

**Raw data:** `d09_capacity_changes`, one row per save, with a timestamp `change_ts`. A change is effective on the day it was made.

**Setup** (run first):
```sql
create or replace table d09_capacity_changes as
select * from values
  ('A','STRAW',50,timestamp'2026-01-01 08:00:00'),
  ('A','STRAW',70,timestamp'2026-03-14 09:00:00'),
  ('A','STRAW',80,timestamp'2026-03-14 16:00:00')
as t(store_id, item_id, capacity, change_ts);
```

**Your task:** SCD2 by day: `store_id, item_id, capacity, valid_from, valid_to`.

**Hints:**
1. Build SCD2 straight from these rows and look at the 70 version's dates. What's wrong?
2. Pick one row per store, item and **day**. Which one should win?
3. "Latest row per group" has a standard window function.

**Check yourself:** no version starts and ends on the same day.

### Drill 10: Changes that change nothing (10 min)
**What this tests:** collapsing repeated values, and why step order matters.

**Scenario:** The capacity tool logs a row every time someone clicks save, even when the number didn't change. History should only show real changes.

**Raw data:** `d10_capacity_changes`: `item_id, capacity, changed_on`.

**Setup** (run first):
```sql
create or replace table d10_capacity_changes as
select * from values
  ('STRAW',50,date'2026-01-01'), ('STRAW',50,date'2026-02-01'), ('STRAW',80,date'2026-03-01'),
  ('STRAW',80,date'2026-03-20'), ('STRAW',60,date'2026-04-05')
as t(item_id, capacity, changed_on);
```

**Your task:** SCD2 with one row per **real** change.

**Hints:**
1. Compare each row with the row before it.
2. Should you remove repeats before or after you compute `valid_to`? Try both on paper.

**Check yourself:** no two back-to-back versions of an item have the same capacity.

### Drill 11: Next-day effect and a start date (15 min)
**What this tests:** applying business rules to a change log before the standard SCD2 steps; combines drills 9 and 10.

**Scenario:** Store managers reset shelves after closing and save the new capacity in a back-office tool. The forecasting team needs capacity for any store, item and date.

**Raw data:** `d11_capacity_changes`, one row each time a manager saves a capacity.

| Column | Meaning |
|---|---|
| store_id, item_id | the store and item |
| capacity | units the shelf holds after the reset |
| start_date | the date the item starts selling in that store |
| change_timestamp | when the manager clicked save |

**What the store ops team tells you if you ask:**
- A change takes effect the **next morning**.
- No capacity applies before the item's start date.
- Managers sometimes save several times in a day; the last save counts.
- The tool logs a save even if the value didn't change.

**Setup** (run first):
```sql
create or replace table d11_capacity_changes as
select * from values
  ('A','STRAW',50,date'2026-01-01',timestamp'2025-12-30 09:00:00'),
  ('A','STRAW',70,date'2026-01-01',timestamp'2026-03-14 09:00:00'),
  ('A','STRAW',80,date'2026-01-01',timestamp'2026-03-14 16:00:00'),
  ('A','STRAW',80,date'2026-01-01',timestamp'2026-04-02 10:00:00'),
  ('B','STRAW',60,date'2026-03-16',timestamp'2026-03-10 11:00:00')
as t(store_id, item_id, capacity, start_date, change_timestamp);
```

**Your task:** SCD2: `store_id, item_id, capacity, valid_from, valid_to`.

**Hints:**
1. Work out each row's **effective date** first, applying both date rules.
2. Then it's the drill 9 and 10 steps, on the effective date.
3. Two different saves can land on the same effective date. Check store A.

**Check yourself:** versions never overlap or leave gaps, no two back-to-back versions have the same capacity, and nothing starts before `start_date`.

### Drill 12: Backdated corrections (12 min)
**What this tests:** the difference between when something **takes effect** and when it was **entered**.

**Scenario:** Ops sometimes enters a capacity change days after it actually happened, with the real effective date. Finance wants history that reflects what was true on each day, using the best information available now.

**Raw data:** `d12_capacity_changes`: `store_id, item_id, capacity, effective_date, entered_at`.

**Setup** (run first):
```sql
create or replace table d12_capacity_changes as
select * from values
  ('A','STRAW',50,date'2026-01-01',timestamp'2025-12-30 10:00:00'),
  ('A','STRAW',80,date'2026-03-16',timestamp'2026-03-15 12:00:00'),
  ('A','STRAW',70,date'2026-03-15',timestamp'2026-03-20 09:00:00'),
  ('A','STRAW',75,date'2026-03-16',timestamp'2026-03-21 08:00:00')
as t(store_id, item_id, capacity, effective_date, entered_at);
```

**Your task:** SCD2, then answer: what was the capacity on Mar 15? On Mar 16?

**Hints:**
1. Which date orders the timeline: effective or entered?
2. Two entries have the same effective date. Which one is the truth?

**Check yourself:** versions follow the effective dates, and each effective date appears once.

### Drill 13: Discontinued items (10 min)
**What this tests:** end events in a change log, and when a `WHERE` clause runs relative to window functions.

**Scenario:** When an item is discontinued, the log records a "discontinue" event. Reports must not show capacity for it after that date.

**Raw data:** `d13_capacity_events`: `item_id, action ('set' or 'discontinue'), capacity, effective_date`.

**Setup** (run first):
```sql
create or replace table d13_capacity_events as
select * from values
  ('STRAW','set',50,date'2026-01-01'), ('STRAW','set',80,date'2026-03-15'),
  ('STRAW','discontinue',cast(null as int),date'2026-04-01')
as t(item_id, action, capacity, effective_date);
```

**Your task:** SCD2 of capacity. No version may exist on or after the discontinue date.

**Hints:**
1. Is a discontinue row a version, or the end of one?
2. If you filter out discontinue rows first, what does `LEAD` see for the last real version?

**Check yourself:** no version covers the discontinue date or anything after it.

### Drill 14: Database change feed (15 min)
**What this tests:** turning a CDC feed (insert, update, delete) into SCD2; combines drills 9, 10 and 13.

**Scenario:** The item database streams every change to a feed. You need item category history by day.

**Raw data:** `d14_item_cdc`: `op ('I' insert, 'U' update, 'D' delete), item_id, category, commit_ts`.

**Setup** (run first):
```sql
create or replace table d14_item_cdc as
select * from values
  ('I','STRAW','Berries',      timestamp'2026-01-01 09:00:00'),
  ('U','STRAW','Fresh Berries',timestamp'2026-03-02 10:00:00'),
  ('U','STRAW','Fresh Berries',timestamp'2026-03-02 10:00:00'),
  ('I','KIWI','Tropical',      timestamp'2026-02-01 09:00:00'),
  ('U','KIWI','Tropical',      timestamp'2026-02-10 09:00:00'),
  ('D','KIWI',cast(null as string), timestamp'2026-04-01 09:00:00')
as t(op, item_id, category, commit_ts);
```

**Your task:** SCD2 of item category by day: `item_id, category, valid_from, valid_to`.

**Hints:**
1. Look for noise: a row that appears twice, and an update that doesn't change anything.
2. What should a delete do to the item's history?
3. Deletes have a null category. Which comparison handles nulls?

**Check yourself:** no duplicate or no-op versions, and nothing is active for a deleted item after its delete.

### Drill 15: Status history, two questions (12 min)
**What this tests:** choosing the shape from the **question**, not the table.

**Scenario:** The supply chain team has a log of purchase order status changes and asks two things:
(a) "How many POs were in shipped status on Mar 5?"
(b) "On average, how many days from ordered to received?"

**Raw data:** `d15_po_status`: `po_id, status ('ordered', 'shipped', 'received'), status_at`.

**Setup** (run first):
```sql
create or replace table d15_po_status as
select * from values
  ('P1','ordered', timestamp'2026-03-01 09:00:00'), ('P1','shipped', timestamp'2026-03-03 09:00:00'),
  ('P1','received',timestamp'2026-03-06 09:00:00'),
  ('P2','ordered', timestamp'2026-03-02 09:00:00'), ('P2','shipped', timestamp'2026-03-05 09:00:00'),
  ('P3','ordered', timestamp'2026-03-04 09:00:00')
as t(po_id, status, status_at);
```

**Your task:** answer both questions.

**Hints:**
1. (a) is about the state at one moment. Which shape answers "what was true on a date"?
2. (b) is about time between two steps. What if each PO were one row with a column per step?
3. Not every PO has been received.

**Check yourself:** (b) uses only POs that were received.

### Drill 16: Price on the day of sale (8 min)
**What this tests:** point-in-time ("as-was") lookups into SCD2, the most common SCD2 query in practice.

**Scenario:** Finance wants revenue per sale at the price that was in effect on the sale date, not today's price.

**Raw data:**
- `d16_sales`: `sale_id, item_id, sold_on, units`.
- `d07_price_scd2`: from drill 7.

**Setup** (run first):
```sql
create or replace table d16_sales as
select * from values
  (1,'STRAW',date'2026-02-10',3), (2,'STRAW',date'2026-02-15',2), (3,'STRAW',date'2026-03-12',4),
  (4,'BLUE', date'2026-03-12',1), (5,'STRAW',date'2025-12-20',1)
as t(sale_id, item_id, sold_on, units);
```

**Your task:** `sale_id, sold_on, units, price, revenue, is_unpriced` for every sale. Flag sales with no price instead of dropping them.

**Hints:**
1. Join each sale to the version whose range contains its date.
2. Look at the sale on Feb 15, the day the price changed.
3. One sale happened before any price existed. Which join keeps it?

**Check yourself:** every sale appears exactly once, either priced or flagged.

---

## C. Transaction facts

### Drill 17: Reloaded rows (8 min)
**What this tests:** keeping the latest row per key, the most common SQL screen question.

**Scenario:** The POS vendor re-sends a sale when it's corrected. Each copy has the same `sale_id` and a newer `loaded_at`. The sales report should count each sale once, using its latest version.

**Raw data:** `d17_sales`: `sale_id, sold_at, item_id, units, loaded_at`.

**Setup** (run first):
```sql
create or replace table d17_sales as
select * from values
  (1001,timestamp'2026-03-14 10:05:00','STRAW',4,timestamp'2026-03-14 23:00:00'),
  (1002,timestamp'2026-03-14 15:40:00','STRAW',2,timestamp'2026-03-14 23:00:00'),
  (1005,timestamp'2026-03-16 11:00:00','STRAW',3,timestamp'2026-03-16 23:00:00'),
  (1005,timestamp'2026-03-16 11:00:00','STRAW',4,timestamp'2026-03-17 06:00:00'),
  (1006,timestamp'2026-03-16 17:20:00','STRAW',1,timestamp'2026-03-16 23:00:00')
as t(sale_id, sold_at, item_id, units, loaded_at);
```

**Your task:** units per item per day: `sale_date, item_id, units`.

**Hints:**
1. Find the sale that appears more than once. Which copy is right?
2. Rank copies within each `sale_id`, newest first.

**Check yourself:** each `sale_id` is counted once.

### Drill 18: Returns and voids (10 min)
**What this tests:** business rules for corrections, and a classic null trap with `NOT IN`.

**Scenario:** Finance needs net units per day. The POS records three kinds of transactions.

**Raw data:** `d18_txns`: `txn_id, txn_type, ref_txn_id, sold_on, item_id, units`.

| txn_type | Meaning |
|---|---|
| sale | a normal sale |
| return | a customer brings an item back on a later day (negative units, its own date) |
| void | a cashier cancels a sale completely; `ref_txn_id` points to it |

**Setup** (run first):
```sql
create or replace table d18_txns as
select * from values
  (1,'sale',  cast(null as int),date'2026-03-14','STRAW',5),
  (2,'sale',  cast(null as int),date'2026-03-14','STRAW',3),
  (3,'void',  2,                date'2026-03-14','STRAW',cast(null as int)),
  (4,'return',1,                date'2026-03-15','STRAW',-1),
  (5,'sale',  cast(null as int),date'2026-03-15','STRAW',2)
as t(txn_id, txn_type, ref_txn_id, sold_on, item_id, units);
```

**Your task:** net units per day.

**Hints:**
1. A return and a void are different: one is a new event, the other erases an event.
2. Try `txn_id not in (select ref_txn_id from d18_txns)`. Why does it return nothing?
3. There's a null-safe way to say "no void points to this sale".

**Check yourself:** a voided sale contributes nothing, and a return counts on its own date.

### Drill 19: A corrected file arrives (8 min)
**What this tests:** idempotent loads: rerunning a load must not change the result.

**Scenario:** The vendor resends Mar 14 with corrected numbers and a new item. Your nightly job may also be rerun by mistake.

**Raw data:**
- `d19_fct_sales_daily`: your fact table, one row per day and item.
- `d19_file_0314`: the corrected file for Mar 14.

**Setup** (run first):
```sql
create or replace table d19_fct_sales_daily as
select * from values (date'2026-03-13','STRAW',4), (date'2026-03-14','STRAW',6)
as t(sale_date, item_id, units);
create or replace table d19_file_0314 as
select * from values (date'2026-03-14','STRAW',7), (date'2026-03-14','BLUE',2)
as t(sale_date, item_id, units);
```

**Your task:** load the corrected Mar 14 file. Running your statement twice must give the same result.

**Hints:**
1. What happens to Mar 14 if you just insert the file?
2. Think "replace this date's data", not "add rows".
3. Databricks can delete and insert for a date range in one atomic statement.

**Check yourself:** running your load twice leaves the table identical.

### Drill 20: Two feeds, one fact (12 min)
**What this tests:** combining two event sources at one grain without multiplying rows (fan-out).

**Scenario:** You're building `fct_store_item_daily` with both units sold and shrink units, from two separate feeds.

**Raw data:**
- `d20_sales`: one row per sale.
- `d20_shrink`: one row per shrink log (spoiled, damaged).

**Setup** (run first):
```sql
create or replace table d20_sales as
select * from values
  (date'2026-03-14','A','STRAW',4), (date'2026-03-14','A','STRAW',2), (date'2026-03-15','A','STRAW',3)
as t(sold_on, store_id, item_id, units);
create or replace table d20_shrink as
select * from values
  (date'2026-03-14','A','STRAW',1,'spoiled'), (date'2026-03-14','A','STRAW',2,'damaged'),
  (date'2026-03-16','A','STRAW',5,'spoiled')
as t(logged_on, store_id, item_id, units, reason);
```

**Your task:** one row per store, item and day, with `units_sold` and `shrink_units`.

**Hints:**
1. Join the raw tables and look at Mar 14's totals. What happened?
2. Get each feed to the output grain **before** joining.
3. Some days exist in only one feed. Which join keeps both?

**Check yourself:** each column's total equals its feed's raw total, and days found in only one feed still appear.

### Drill 21: The daily file (6 min)
**What this tests:** classifying a table correctly when it looks like something else.

**Scenario:** A vendor sends one row per item per day, with zeros on days with no sales. A colleague calls it "the daily sales snapshot".

**Raw data:** `d21_daily_item_sales`: `item_id, sale_date, units`.

**Setup** (run first):
```sql
create or replace table d21_daily_item_sales as
select * from values
  ('STRAW',date'2026-03-09',3), ('STRAW',date'2026-03-10',0), ('STRAW',date'2026-03-11',5),
  ('STRAW',date'2026-03-12',2), ('STRAW',date'2026-03-13',0), ('STRAW',date'2026-03-14',4),
  ('STRAW',date'2026-03-15',6)
as t(item_id, sale_date, units);
```

**Your task:** units sold for the week of Mar 9 to 15, and one sentence on why your aggregate is valid.

**Hints:**
1. Read one row aloud. Did something happen, or is something true?
2. Does adding up a week of rows give a real number?

**Check yourself:** you can explain in one sentence why adding these rows is valid.

### Drill 22: Counting customers (10 min)
**What this tests:** non-additive measures (distinct counts), the "daily vs weekly active users" trap.

**Scenario:** Marketing wants a daily table with units and the number of customers, and then the number of customers for the week.

**Raw data:** `d22_lines`: one row per basket line, with `customer_id, sold_on, item_id, units`.

**Setup** (run first):
```sql
create or replace table d22_lines as
select * from values
  ('C1',date'2026-03-14','STRAW',2), ('C1',date'2026-03-14','BLUE',1),
  ('C2',date'2026-03-14','STRAW',1), ('C1',date'2026-03-15','STRAW',3)
as t(customer_id, sold_on, item_id, units);
```

**Your task:**
1. A daily result with units and distinct customers.
2. Distinct customers for the week of Mar 9 to 15.

**Hints:**
1. Add up your daily customer counts. Is that the weekly answer?
2. Look for a customer who shopped on more than one day.

**Check yourself:** you can explain why the weekly number is not the sum of the daily numbers.

---

## D. Snapshots, processes, coverage

### Drill 23: Average stock on hand (8 min)
**What this tests:** semi-additive measures: adding across items but not across days.

**Scenario:** The store manager asks, "On average, how many units did store A have on its shelves each night this week?"

**Raw data:** `d23_counts`: one row per store, item and night with `on_hand`.

**Setup** (run first):
```sql
create or replace table d23_counts as
select * from values
  (date'2026-03-09','A','STRAW',40), (date'2026-03-10','A','STRAW',40), (date'2026-03-11','A','STRAW',37),
  (date'2026-03-09','A','BLUE',10),  (date'2026-03-10','A','BLUE',12),  (date'2026-03-11','A','BLUE',8)
as t(count_date, store_id, item_id, on_hand);
```

**Your task:** average daily on-hand units for store A over Mar 9 to 11.

**Hints:**
1. What does `sum(on_hand)` over all rows represent? Does it mean anything?
2. Get the store's total per night first, then decide how to combine nights.

**Check yourself:** your answer falls between the smallest and largest nightly store total.

### Drill 24: A snapshot that skips zeros (12 min)
**What this tests:** the meaning of a missing row: zero vs unknown.

**Scenario:** The inventory system sends a nightly file, but it only lists items with stock **above zero**. One night the file never arrived.

**Raw data:**
- `d24_counts`: `count_date, item_id, on_hand`.
- `d24_file_log`: `file_date, arrived` (true or false).

**Setup** (run first):
```sql
create or replace table d24_counts as
select * from values
  (date'2026-03-09','STRAW',5), (date'2026-03-09','BLUE',2), (date'2026-03-10','STRAW',3),
  (date'2026-03-12','BLUE',4)
as t(count_date, item_id, on_hand);
create or replace table d24_file_log as
select * from values
  (date'2026-03-09',true), (date'2026-03-10',true), (date'2026-03-11',false), (date'2026-03-12',true)
as t(file_date, arrived);
```

**Your task:** on-hand for STRAW and BLUE on every day from Mar 9 to 12.

**Hints:**
1. You need a row for every item and day, even ones not in the file.
2. An item missing from a file that arrived means something different from an item on a day with no file.

**Check yourself:** 8 rows, and you can explain why each empty value is 0 or null.

### Drill 25: Stock from movements (12 min)
**What this tests:** building a daily snapshot from events with a date spine and a running total.

**Scenario:** There's no nightly count. You know the opening stock and every delivery, sale and shrink event. The planner needs end-of-day stock for every day.

**Raw data:**
- `d25_opening`: on-hand at the end of Mar 8.
- `d25_events`: `item_id, event_date, qty_change (+ in, − out), event_type`.

**Setup** (run first):
```sql
create or replace table d25_opening as
select * from values ('STRAW', date'2026-03-08', 20) as t(item_id, as_of, on_hand);
create or replace table d25_events as
select * from values
  ('STRAW',date'2026-03-09',24,'delivery'), ('STRAW',date'2026-03-09',-6,'sale'),
  ('STRAW',date'2026-03-11',-5,'sale'),     ('STRAW',date'2026-03-11',-2,'shrink')
as t(item_id, event_date, qty_change, event_type);
```

**Your task:** end-of-day on-hand for every day from Mar 9 to 12.

**Hints:**
1. Some days have no events. They still need a row.
2. Stock on a day = opening + everything that moved up to and including that day.
3. A window function can keep a running total.

**Check yourself:** one row per day, including days with no events.

### Drill 26: Missing snapshot days (8 min)
**What this tests:** finding rows that **don't** exist (coverage checks).

**Scenario:** Data quality asks: "Which stores failed to send a daily snapshot in the first week of March?"

**Raw data:** `d26_snapshots`: one row per store per day that a snapshot arrived.

**Setup** (run first):
```sql
create or replace table d26_snapshots as
select * from values
  ('A',date'2026-03-01'),('A',date'2026-03-02'),('A',date'2026-03-04'),('A',date'2026-03-05'),
  ('A',date'2026-03-06'),('A',date'2026-03-07'),
  ('B',date'2026-03-01'),('B',date'2026-03-02'),('B',date'2026-03-03'),('B',date'2026-03-04'),
  ('B',date'2026-03-05')
as t(store_id, snapshot_date);
```

**Your task:** list every store and day from Mar 1 to 7 with no snapshot.

**Hints:**
1. You can't find a missing row by looking at the rows that exist.
2. Build the list of rows that **should** exist, then compare.

**Check yourself:** every row you return is a store and day with no snapshot.

### Drill 27: Purchase order lifecycle (12 min)
**What this tests:** the accumulating snapshot: one row per process, a column per step.

**Scenario:** The supply chain lead wants a PO tracker: when each PO was ordered, shipped and received, how long receiving took, and which POs are overdue.

**Raw data:** `d27_po_events`: `po_id, status, status_at`. Events can be duplicated.

**Setup** (run first):
```sql
create or replace table d27_po_events as
select * from values
  ('P1','ordered', timestamp'2026-03-01 09:00:00'), ('P1','shipped', timestamp'2026-03-03 09:00:00'),
  ('P1','shipped', timestamp'2026-03-03 09:00:00'), ('P1','received',timestamp'2026-03-06 09:00:00'),
  ('P2','ordered', timestamp'2026-03-02 09:00:00'), ('P2','shipped', timestamp'2026-03-05 09:00:00'),
  ('P3','ordered', timestamp'2026-03-07 09:00:00')
as t(po_id, status, status_at);
```

**Your task:** one row per PO with `ordered_at, shipped_at, received_at, days_to_receive, is_overdue`. Overdue = not received and more than 5 days since ordering, as of Mar 10.

**Hints:**
1. Turn rows (one per event) into columns (one per step).
2. `min` or `max` combined with `case when` picks one timestamp per step.
3. POs still in progress must stay in the result.

**Check yourself:** one row per PO, and POs still in progress appear.

### Drill 28: On promo, no sales (10 min)
**What this tests:** factless facts (coverage) and anti-joins.

**Scenario:** The promo team asks: "Which days was strawberry on promo at store A but sold nothing?"

**Raw data:**
- `d28_promos`: promo date ranges (**end date inclusive**).
- `d28_daily_sales`: one row per store, item and day **with** sales.

**Setup** (run first):
```sql
create or replace table d28_promos as
select * from values ('P1','A','STRAW',date'2026-03-01',date'2026-03-04')
as t(promo_id, store_id, item_id, start_date, end_date);       -- end_date is INCLUSIVE
create or replace table d28_daily_sales as
select * from values (date'2026-03-01','A','STRAW',5), (date'2026-03-03','A','STRAW',2)
as t(calendar_date, store_id, item_id, units);
```

**Your task:** build one row per store, item and day on promo, then list the promo days with zero sales.

**Hints:**
1. The days you want aren't in the sales table at all.
2. Expand each promo into one row per day it ran.

**Check yourself:** every day you return falls inside the promo.

### Drill 29: Weekly counts, daily sales (10 min)
**What this tests:** aligning two grains before combining them.

**Scenario:** Stock is counted once a week (at the week's open); sales are daily. The category manager wants weekly sell-through = units sold in the week ÷ on-hand at the week's open.

**Raw data:**
- `d29_weekly_counts`: `week_start, item_id, on_hand_at_open`.
- `d29_daily_sales`: `sale_date, item_id, units`.

**Setup** (run first):
```sql
create or replace table d29_weekly_counts as
select * from values (date'2026-03-01','STRAW',40), (date'2026-03-08','STRAW',35)
as t(week_start, item_id, on_hand_at_open);
create or replace table d29_daily_sales as
select * from values
  (date'2026-03-02','STRAW',10), (date'2026-03-05','STRAW',6),
  (date'2026-03-09','STRAW',12), (date'2026-03-13','STRAW',8)
as t(sale_date, item_id, units);
```

**Your task:** sell-through per item per week.

**Hints:**
1. What happens if you join daily rows straight to weekly rows?
2. Which table should change grain, and which direction is safe?
3. `d01_dim_date` already knows each date's week.

**Check yourself:** one row per item per week.

---

## E. Analysis and tests

### Drill 30: Stockout streaks (12 min)
**What this tests:** gaps and islands, the classic "hard" SQL question.

**Scenario:** The replenishment team wants every stockout streak: when it started, when it ended and how many days it lasted.

**Raw data:** `d30_on_hand`: one row per item per day with `on_hand`.

**Setup** (run first):
```sql
create or replace table d30_on_hand as
select item_id, date_add(date'2026-03-01', pos) as calendar_date, on_hand
from (select 'STRAW' as item_id, posexplode(array(5,0,0,3,0,0,0,2,0,4)) as (pos, on_hand));
```

**Your task:** one row per streak of consecutive days with on_hand = 0: `out_from, out_to, days_out`.

**Hints:**
1. `group by on_hand = 0` merges every out-of-stock day into one group. Why is that wrong?
2. Mark the days where the status flips from yesterday.
3. A running count of those flips gives each streak its own number.

**Check yourself:** separate streaks come out as separate rows.

### Drill 31: Same period last year (8 min)
**What this tests:** year-over-year comparisons, and points vs percent.

**Scenario:** Customer success wants to tell a grocer how shrink changed versus the same fiscal period last year. There are 13 fiscal periods a year, numbered with a running sequence.

**Raw data:** `d31_agg`: `store_id, fiscal_period_seq, shrink_amt, sales_amt`.

**Setup** (run first):
```sql
create or replace table d31_agg as
select * from values ('A',1,72.0,1000.0), ('A',14,58.0,1000.0)
as t(store_id, fiscal_period_seq, shrink_amt, sales_amt);    -- 13 periods per year
```

**Your task:** for period 14: shrink rate, last year's rate, change in **points** and change in **percent**.

**Hints:**
1. With a running period number, "last year" is simple arithmetic.
2. Join the table to itself.
3. If a rate goes from 10% to 8%, how many points did it change? How many percent?

**Check yourself:** your change in points and your change in percent are different numbers.

### Drill 32: Write the tests (10 min)
**What this tests:** data tests that pass with zero rows, the way dbt tests work.

**Scenario:** Before shipping a model, you add automated checks. A check must **return rows only when something is wrong**.

**Raw data:**
- `d32_source_sales`: the source.
- `d32_fct`: the fact (one row per day, store, item, or so it claims).
- `d32_dim_item`: an SCD2 dimension.

**Setup** (run first):
```sql
create or replace table d32_source_sales as
select * from values (1,date'2026-03-14','A','STRAW',4), (2,date'2026-03-14','A','STRAW',2)
as t(sale_id, calendar_date, store_id, item_id, units);
create or replace table d32_fct as
select * from values (date'2026-03-14','A','STRAW',6), (date'2026-03-14','A','STRAW',6)
as t(calendar_date, store_id, item_id, units);
create or replace table d32_dim_item as
select * from values
  (11,'STRAW','Berries',      date'2026-01-01',date'2026-03-10'),
  (12,'STRAW','Fresh Berries',date'2026-03-01',date'9999-12-31')
as t(item_key, item_id, category, valid_from, valid_to);
```

**Your task:** three tests: (1) the fact's grain is unique, (2) no two SCD2 versions of an item overlap, (3) fact total equals source total. All three should fail on this data.

**Hints:**
1. A duplicate grain is a group with more than one row.
2. Two ranges overlap when each starts before the other ends.
3. Compare two single-row totals; return a row only if they differ.

**Check yourself:** each test returns at least one row on this data.

---

## F. Combos (interview style)

### Drill 33: The Afresh problem (30 min)
**What this tests:** the whole pipeline end to end: change log → SCD2 → daily, deduped sales, full outer join, and a semi-additive metric. Combines drills 11, 8, 17, 20 and 23.

**Scenario:** Category managers want **days of cover** per store: how many days of sales the shelf can hold. You must build the daily fact first, then the metric.

**Raw data:**
- `c33_capacity_changes`: same table and rules as drill 11 (next-day effect, start date, several saves a day, repeated saves).
- `c33_sales`: one row per sale; corrected sales are re-sent with a newer `loaded_at`; returns have negative units.

**Setup** (run first):
```sql
create or replace table c33_capacity_changes as select * from d11_capacity_changes;
create or replace table c33_sales as
select * from values
  (1001,timestamp'2026-03-14 10:05:00','A','STRAW', 4,timestamp'2026-03-14 23:00:00'),
  (1002,timestamp'2026-03-14 15:40:00','A','STRAW', 2,timestamp'2026-03-14 23:00:00'),
  (1003,timestamp'2026-03-16 09:12:00','A','STRAW', 9,timestamp'2026-03-16 23:00:00'),
  (1004,timestamp'2026-03-15 13:30:00','B','STRAW', 2,timestamp'2026-03-15 23:00:00'),
  (1005,timestamp'2026-03-16 11:00:00','B','STRAW', 3,timestamp'2026-03-16 23:00:00'),
  (1005,timestamp'2026-03-16 11:00:00','B','STRAW', 4,timestamp'2026-03-17 06:00:00'),
  (1006,timestamp'2026-03-16 17:20:00','A','STRAW',-1,timestamp'2026-03-16 23:00:00')
as t(sale_id, sold_at, store_id, item_id, units, loaded_at);
```

**Your task:**
1. Build `c33_fct_store_item_daily (calendar_date, store_id, item_id, units_sold, capacity_units)`.
2. Days of cover per store for Mar 14 to 16 = average daily capacity ÷ average daily units sold, using only days where capacity is known.

**Hints:**
1. Draw the boxes first: capacity side, sales side, then the join.
2. A sale before capacity exists: is its capacity 0 or unknown?
3. Capacity adds across items on a day but not across days.

**Check yourself:** the fact has one row per store, item and day, and capacity is null (not 0) where unknown.

### Drill 34: Shrink by category, as-was vs as-is (20 min)
**What this tests:** SCD2 joined to a fact, two ways, and knowing which one the business means.

**Scenario:** Strawberries moved from "Berries" to "Fresh Berries" on Mar 10. The Berries manager asks why their March shrink looks low; the Fresh Berries manager asks why theirs looks high.

**Raw data:**
- `c34_category_changes`: `item_id, category, effective_date`.
- `c34_shrink`: `shrink_date, item_id, shrink_amt`.

**Setup** (run first):
```sql
create or replace table c34_category_changes as
select * from values
  ('STRAW','Berries',date'2026-01-01'), ('STRAW','Fresh Berries',date'2026-03-10'),
  ('BLUE','Berries',date'2026-01-01')
as t(item_id, category, effective_date);
create or replace table c34_shrink as
select * from values
  (date'2026-03-05','STRAW',10.0), (date'2026-03-12','STRAW',6.0), (date'2026-03-12','BLUE',4.0)
as t(shrink_date, item_id, shrink_amt);
```

**Your task:** March shrink by category two ways: **as-was** (category at the time) and **as-is** (today's category).

**Hints:**
1. Build category history first (drill 7).
2. As-was: join on the date. As-is: join to the current version only.
3. Which view should each manager use, and why?

**Check yourself:** both views have the same total.

### Drill 35: Revenue at the right price (25 min)
**What this tests:** cleaning a messy price log, then pricing sales; combines drills 9, 10, 7 and 16.

**Scenario:** Finance wants monthly revenue using the price in effect on each sale date, plus a count of units that couldn't be priced.

**Raw data:**
- `c35_price_changes`: `item_id, price, change_ts`. Effective the same day. Some days have more than one change; some changes repeat the previous price.
- `c35_sales`: `sold_on, item_id, units` (returns are negative).

**Setup** (run first):
```sql
create or replace table c35_price_changes as
select * from values
  ('STRAW',3.99,timestamp'2026-01-01 08:00:00'), ('STRAW',4.49,timestamp'2026-02-15 09:00:00'),
  ('STRAW',4.29,timestamp'2026-02-15 17:00:00'), ('STRAW',4.29,timestamp'2026-03-01 08:00:00'),
  ('STRAW',3.79,timestamp'2026-03-10 08:00:00')
as t(item_id, price, change_ts);                 -- effective the same day
create or replace table c35_sales as
select * from values
  (date'2025-12-31','STRAW',1), (date'2026-02-10','STRAW',3), (date'2026-02-15','STRAW',2),
  (date'2026-03-05','STRAW',1), (date'2026-03-12','STRAW',4), (date'2026-03-12','STRAW',-1)
as t(sold_on, item_id, units);
```

**Your task:** `month, revenue, unpriced_units`.

**Hints:**
1. Clean the log before closing versions: same-day changes, then repeats.
2. One sale happened before any price existed.

**Check yourself:** unpriced units are reported, not dropped.

### Drill 36: Counted vs computed stock (20 min)
**What this tests:** reconciling two sources of truth, and cumulative vs daily differences.

**Scenario:** Loss prevention wants to know how much stock went missing each day: the gap between stock calculated from movements and stock counted on the shelf.

**Raw data:**
- `c36_opening`: on-hand at the end of Mar 8.
- `c36_events`: stock movements.
- `c36_counts`: physical counts per day.

**Setup** (run first):
```sql
create or replace table c36_opening as select * from values ('STRAW',date'2026-03-08',20) as t(item_id, as_of, on_hand);
create or replace table c36_events as
select * from values
  ('STRAW',date'2026-03-09',24), ('STRAW',date'2026-03-09',-6),
  ('STRAW',date'2026-03-10',-4), ('STRAW',date'2026-03-11',-5)
as t(item_id, event_date, qty_change);
create or replace table c36_counts as
select * from values ('STRAW',date'2026-03-09',38), ('STRAW',date'2026-03-10',33), ('STRAW',date'2026-03-11',26)
as t(item_id, count_date, counted);
```

**Your task:** per day: computed on-hand, counted on-hand, drift (counted − computed) and **unexplained loss that day**.

**Hints:**
1. Computed on-hand is drill 25.
2. Drift carries over from one day to the next. How much of today's drift is new today?

**Check yourself:** each day's unexplained loss adds up to the latest drift.

### Drill 37: Promo lift with overlapping promos (20 min)
**What this tests:** comparing averages fairly: count each day once, and include days with no sales.

**Scenario:** Marketing asks whether strawberries sell more per day on promo than off promo, for Mar 1 to 10. Two promos overlap.

**Raw data:**
- `c37_promos`: promo date ranges (**end date inclusive**).
- `c37_sales`: `sale_date, item_id, units` (days with no sales have no row).

**Setup** (run first):
```sql
create or replace table c37_promos as
select * from values ('P1','STRAW',date'2026-03-01',date'2026-03-05'), ('P2','STRAW',date'2026-03-04',date'2026-03-08')
as t(promo_id, item_id, start_date, end_date);   -- end_date is INCLUSIVE
create or replace table c37_sales as
select * from values
  (date'2026-03-01','STRAW',2), (date'2026-03-03','STRAW',3), (date'2026-03-04','STRAW',5),
  (date'2026-03-06','STRAW',4), (date'2026-03-09','STRAW',1), (date'2026-03-10','STRAW',2)
as t(sale_date, item_id, units);
```

**Your task:** average daily units on promo days vs non-promo days.

**Hints:**
1. A day covered by two promos is still one day.
2. Days with no sales must count, as zero.
3. Start from a list of every day, not from the sales table.

**Check yourself:** on-promo days plus off-promo days equal 10.

### Drill 38: On-time delivery by supplier tier (25 min)
**What this tests:** an accumulating snapshot plus an as-was SCD2 lookup; combines drills 27, 7 and 16.

**Scenario:** Procurement says Preferred suppliers deliver on time more often. Supplier S1 was upgraded to Preferred on Mar 5. Test the claim fairly.

**Raw data:**
- `c38_tier_changes`: `supplier_id, tier, effective_date`.
- `c38_po_events`: `po_id, supplier_id, status, status_at`.

**Setup** (run first):
```sql
create or replace table c38_tier_changes as
select * from values ('S1','Standard',date'2026-01-01'), ('S1','Preferred',date'2026-03-05')
as t(supplier_id, tier, effective_date);
create or replace table c38_po_events as
select * from values
  ('P1','S1','ordered',timestamp'2026-03-01 09:00:00'), ('P1','S1','received',timestamp'2026-03-03 09:00:00'),
  ('P2','S1','ordered',timestamp'2026-03-06 09:00:00'), ('P2','S1','received',timestamp'2026-03-12 09:00:00'),
  ('P3','S1','ordered',timestamp'2026-03-07 09:00:00'), ('P3','S1','received',timestamp'2026-03-09 09:00:00'),
  ('P4','S1','ordered',timestamp'2026-03-08 09:00:00')
as t(po_id, supplier_id, status, status_at);
```

**Your task:** on-time rate (received within 3 days of ordering) by the supplier's tier **when the PO was ordered**. Only received POs count.

**Hints:**
1. Make one row per PO first.
2. Which date decides the tier: order, receipt or today?
3. A rate is the average of a 1/0 flag.

**Check yourself:** POs not yet received are excluded.

### Drill 39: Before vs after go-live (20 min)
**What this tests:** comparing windows relative to an event date that differs per store, and fair comparisons.

**Scenario:** Customer success wants to show each grocer how shrink changed after the product went live. Compare the 2 weeks before go-live with the first 2 weeks after.

**Raw data:**
- `c39_stores`: `store_id, go_live_date`.
- `c39_weekly`: `store_id, week_start, shrink_amt, sales_amt`.

**Setup** (run first):
```sql
create or replace table c39_stores as
select * from values ('A',date'2026-03-08'), ('B',date'2026-03-15') as t(store_id, go_live_date);
create or replace table c39_weekly as
select * from values
  ('A',date'2026-02-22',60.0,1000.0), ('A',date'2026-03-01',80.0,1000.0),
  ('A',date'2026-03-08',50.0,1000.0), ('A',date'2026-03-15',40.0,1000.0),
  ('B',date'2026-03-01',70.0,1000.0), ('B',date'2026-03-08',65.0,1000.0),
  ('B',date'2026-03-15',55.0,1000.0)
as t(store_id, week_start, shrink_amt, sales_amt);
```

**Your task:** per store: shrink rate before, rate after, change in points. Only include stores with all 4 weeks of data.

**Hints:**
1. Measure weeks relative to each store's own go-live date.
2. Does every store have a full window?
3. Rates: sum the parts, then divide.

**Check yourself:** stores without all 4 weeks are excluded.

### Drill 40: Full mock (45 min, talk out loud, record yourself)
**What this tests:** everything, plus the order of your thinking. Interviewers grade the process as much as the SQL.

**Scenario:** You are the only data modeler at a grocery AI company. Category managers want **days of cover by category for the last 7 complete days, with categories as they were at the time**.

**Raw data:**
1. `pos_lines(line_id, basket_id, sold_at, store_id, sku, qty, net_amt, loaded_at)`: lines can be reloaded with corrections.
2. `sku_master_daily(sku, sku_name, category, department, as_of_date)`: the full SKU list, sent every night.
3. `planogram_changes(store_id, sku, capacity_units, effective_date, entered_at)`: entered whenever a shelf is reset, sometimes backdated.

**Your task, in this order:**
1. The questions you would ask before building.
2. Each source's shape, read aloud.
3. The model: facts, dimensions and each one's grain.
4. The core SQL.
5. Five edge cases.
6. Three tests.

**Hints:**
1. Each source matches a drill you've done. Name it.
2. "As they were at the time" tells you how to join category.
3. Capacity is semi-additive; check how you average.

**Check yourself:** compare with the outline in `answer_key.md`.

