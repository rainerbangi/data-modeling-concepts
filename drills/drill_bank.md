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
**Task:** Build `d01_dim_date` from 2025-12-01 to 2026-12-31 with: `calendar_date`, `day_name`, `week_start` (weeks start on **Sunday**), `month`, `fiscal_year` (fiscal year starts **Feb 1** and is named by its starting year), `is_weekend`.
**Check yourself:** 2026-03-14 has week_start 2026-03-08. 2026-01-15 has fiscal_year 2025.

### Drill 2: Keys that never drop rows (8 min)
```sql
create or replace table d02_stores as
select * from values ('A','Store A'), ('B','Store B') as t(store_id, store_name);
create or replace table d02_sales as
select * from values (1,'A',5), (2,'B',3), (3,'Z',2), (4,cast(null as string),1)
as t(sale_id, store_id, units);
```
**Task:** Build `d02_dim_store (store_key, store_id, store_name)` with surrogate keys, then a sales fact with `store_key`. Every sale must survive. Total units must be 11.

### Drill 3: Fix typos, keep no history (8 min)
```sql
create or replace table d03_dim_store as
select xxhash64(store_id) as store_key, * from values
  ('A','Stor A','East'), ('B','Store B', cast(null as string))
as t(store_id, store_name, region);
create or replace table d03_incoming as
select * from values ('A','Store A','East'), ('B','Store B','West'), ('C','Store C','South')
as t(store_id, store_name, region);
```
**Task:** Apply `d03_incoming` to `d03_dim_store`. History does not matter. Running your statement twice must change nothing the second time.

### Drill 4: Nightly full dump (12 min)
```sql
create or replace table d04_dim_item as
select xxhash64(item_id, date'2026-03-01') as item_key, item_id, category,
       date'2026-03-01' as valid_from, date'9999-12-31' as valid_to, true as is_current
from values ('STRAW','Berries'), ('BLUE','Berries') as t(item_id, category);
create or replace table d04_dump_0302 as
select * from values ('STRAW','Fresh Berries'), ('BLUE','Berries'), ('KIWI','Tropical')
as t(item_id, category);
```
**Task:** The source sends its full item list every night. Apply the 2026-03-02 dump to `d04_dim_item` so category history is kept.
**Check yourself:** STRAW has 2 rows, BLUE 1, KIWI 1. Exactly 3 rows are current.

### Drill 5: One fact, two dates (8 min)
```sql
create or replace table d05_deliveries as
select * from values
  (101, date'2026-03-02', date'2026-03-09', 40),
  (102, date'2026-03-04', date'2026-03-05', 20),
  (103, date'2026-03-10', cast(null as date), 30)
as t(po_id, ordered_date, received_date, units);
```
**Task:** Units by ordered week and received week in one query, using `d01_dim_date`. Undelivered POs must still appear.

### Drill 6: Promotions that share items (12 min)
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
**Task:** (a) Units sold under each promo. (b) Total units sold while the item was on any promo.
**Check yourself:** (b) is 19.

---

## B. Change logs

### Drill 7: Price changes (8 min)
```sql
create or replace table d07_price_changes as
select * from values
  ('STRAW', 3.99, date'2026-01-01'), ('STRAW', 4.49, date'2026-02-15'),
  ('STRAW', 3.79, date'2026-03-10'), ('BLUE', 2.99, date'2026-01-01')
as t(item_id, price, effective_date);
```
**Task:** Build `d07_price_scd2 (item_id, price, valid_from, valid_to)`. Save it as a table; drill 16 uses it.

### Drill 8: Shelf capacity to daily rows (10 min)
```sql
create or replace table d08_capacity_changes as
select * from values
  ('A','STRAW',50,date'2026-01-01'), ('A','STRAW',80,date'2026-03-15'),
  ('B','STRAW',60,date'2026-03-16')
as t(store_id, item_id, capacity, changed_on);
```
**Task:** Capacity for every store, item and day from 2026-03-13 to 2026-03-17.
**Check yourself:** 7 rows. Mar 15 for store A appears once.

### Drill 9: Two changes on one day (10 min)
```sql
create or replace table d09_capacity_changes as
select * from values
  ('A','STRAW',50,timestamp'2026-01-01 08:00:00'),
  ('A','STRAW',70,timestamp'2026-03-14 09:00:00'),
  ('A','STRAW',80,timestamp'2026-03-14 16:00:00')
as t(store_id, item_id, capacity, change_ts);
```
**Task:** SCD2 by day. A change is effective on the day it was made.

### Drill 10: Changes that change nothing (10 min)
```sql
create or replace table d10_capacity_changes as
select * from values
  ('STRAW',50,date'2026-01-01'), ('STRAW',50,date'2026-02-01'), ('STRAW',80,date'2026-03-01'),
  ('STRAW',80,date'2026-03-20'), ('STRAW',60,date'2026-04-05')
as t(item_id, capacity, changed_on);
```
**Task:** SCD2 with one row per real change.
**Check yourself:** 3 versions.

### Drill 11: Next-day effect and a start date (15 min)
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
**Rule:** a change takes effect the day after `change_timestamp`, but never before `start_date`.
**Task:** SCD2.
**Check yourself:** 3 versions in total.

### Drill 12: Backdated corrections (12 min)
```sql
create or replace table d12_capacity_changes as
select * from values
  ('A','STRAW',50,date'2026-01-01',timestamp'2025-12-30 10:00:00'),
  ('A','STRAW',80,date'2026-03-16',timestamp'2026-03-15 12:00:00'),
  ('A','STRAW',70,date'2026-03-15',timestamp'2026-03-20 09:00:00'),
  ('A','STRAW',75,date'2026-03-16',timestamp'2026-03-21 08:00:00')
as t(store_id, item_id, capacity, effective_date, entered_at);
```
**Task:** SCD2. What was the capacity on Mar 15? On Mar 16?

### Drill 13: Discontinued items (10 min)
```sql
create or replace table d13_capacity_events as
select * from values
  ('STRAW','set',50,date'2026-01-01'), ('STRAW','set',80,date'2026-03-15'),
  ('STRAW','discontinue',cast(null as int),date'2026-04-01')
as t(item_id, action, capacity, effective_date);
```
**Task:** SCD2. No version may exist on or after the discontinue date.

### Drill 14: Database change feed (15 min)
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
**Task:** SCD2 of item category by day. `op` is insert, update or delete.

### Drill 15: Status history, two questions (12 min)
```sql
create or replace table d15_po_status as
select * from values
  ('P1','ordered', timestamp'2026-03-01 09:00:00'), ('P1','shipped', timestamp'2026-03-03 09:00:00'),
  ('P1','received',timestamp'2026-03-06 09:00:00'),
  ('P2','ordered', timestamp'2026-03-02 09:00:00'), ('P2','shipped', timestamp'2026-03-05 09:00:00'),
  ('P3','ordered', timestamp'2026-03-04 09:00:00')
as t(po_id, status, status_at);
```
**Task:** (a) How many POs were in "shipped" status on Mar 5? (b) Average days from ordered to received, for received POs. Which shape fits each question?

### Drill 16: Price on the day of sale (8 min)
```sql
create or replace table d16_sales as
select * from values
  (1,'STRAW',date'2026-02-10',3), (2,'STRAW',date'2026-02-15',2), (3,'STRAW',date'2026-03-12',4),
  (4,'BLUE', date'2026-03-12',1), (5,'STRAW',date'2025-12-20',1)
as t(sale_id, item_id, sold_on, units);
```
**Task:** Revenue per sale at the price in effect that day, using `d07_price_scd2`. Flag sales with no price.

---

## C. Transaction facts

### Drill 17: Reloaded rows (8 min)
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
**Task:** Units per item per day.

### Drill 18: Returns and voids (10 min)
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
**Rule:** a void cancels the referenced sale completely. A return is a new event on its own date.
**Task:** Net units per day.

### Drill 19: A corrected file arrives (8 min)
```sql
create or replace table d19_fct_sales_daily as
select * from values (date'2026-03-13','STRAW',4), (date'2026-03-14','STRAW',6)
as t(sale_date, item_id, units);
create or replace table d19_file_0314 as
select * from values (date'2026-03-14','STRAW',7), (date'2026-03-14','BLUE',2)
as t(sale_date, item_id, units);
```
**Task:** Load the corrected Mar 14 file. Running your load twice must give the same result.

### Drill 20: Two feeds, one fact (12 min)
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
**Task:** One row per store, item and day with `units_sold` and `shrink_units`.

### Drill 21: The daily file (6 min)
```sql
create or replace table d21_daily_item_sales as
select * from values
  ('STRAW',date'2026-03-09',3), ('STRAW',date'2026-03-10',0), ('STRAW',date'2026-03-11',5),
  ('STRAW',date'2026-03-12',2), ('STRAW',date'2026-03-13',0), ('STRAW',date'2026-03-14',4),
  ('STRAW',date'2026-03-15',6)
as t(item_id, sale_date, units);
```
**Task:** There is a row every day. Is this a snapshot? Give units sold for the week and explain in one sentence why your aggregate is valid.

### Drill 22: Counting customers (10 min)
```sql
create or replace table d22_lines as
select * from values
  ('C1',date'2026-03-14','STRAW',2), ('C1',date'2026-03-14','BLUE',1),
  ('C2',date'2026-03-14','STRAW',1), ('C1',date'2026-03-15','STRAW',3)
as t(customer_id, sold_on, item_id, units);
```
**Task:** A daily fact with units and distinct customers. Then distinct customers for the week of Mar 9 to 15.

---

## D. Snapshots, processes, coverage

### Drill 23: Average stock on hand (8 min)
```sql
create or replace table d23_counts as
select * from values
  (date'2026-03-09','A','STRAW',40), (date'2026-03-10','A','STRAW',40), (date'2026-03-11','A','STRAW',37),
  (date'2026-03-09','A','BLUE',10),  (date'2026-03-10','A','BLUE',12),  (date'2026-03-11','A','BLUE',8)
as t(count_date, store_id, item_id, on_hand);
```
**Task:** Average daily on-hand units for store A over Mar 9 to 11.

### Drill 24: A snapshot that skips zeros (12 min)
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
**Rule:** the file lists only items with stock above zero.
**Task:** On-hand for STRAW and BLUE on every day from Mar 9 to 12.

### Drill 25: Stock from movements (12 min)
```sql
create or replace table d25_opening as
select * from values ('STRAW', date'2026-03-08', 20) as t(item_id, as_of, on_hand);
create or replace table d25_events as
select * from values
  ('STRAW',date'2026-03-09',24,'delivery'), ('STRAW',date'2026-03-09',-6,'sale'),
  ('STRAW',date'2026-03-11',-5,'sale'),     ('STRAW',date'2026-03-11',-2,'shrink')
as t(item_id, event_date, qty_change, event_type);
```
**Task:** End-of-day on-hand for every day from Mar 9 to 12. The opening balance is end of day Mar 8.

### Drill 26: Missing snapshot days (8 min)
```sql
create or replace table d26_snapshots as
select * from values
  ('A',date'2026-03-01'),('A',date'2026-03-02'),('A',date'2026-03-04'),('A',date'2026-03-05'),
  ('A',date'2026-03-06'),('A',date'2026-03-07'),
  ('B',date'2026-03-01'),('B',date'2026-03-02'),('B',date'2026-03-03'),('B',date'2026-03-04'),
  ('B',date'2026-03-05')
as t(store_id, snapshot_date);
```
**Task:** List every store and day from Mar 1 to 7 with no snapshot.

### Drill 27: Purchase order lifecycle (12 min)
```sql
create or replace table d27_po_events as
select * from values
  ('P1','ordered', timestamp'2026-03-01 09:00:00'), ('P1','shipped', timestamp'2026-03-03 09:00:00'),
  ('P1','shipped', timestamp'2026-03-03 09:00:00'), ('P1','received',timestamp'2026-03-06 09:00:00'),
  ('P2','ordered', timestamp'2026-03-02 09:00:00'), ('P2','shipped', timestamp'2026-03-05 09:00:00'),
  ('P3','ordered', timestamp'2026-03-07 09:00:00')
as t(po_id, status, status_at);
```
**Task:** One row per PO with a timestamp per step, days from ordered to received, and an `is_overdue` flag: not received and more than 5 days since ordering, as of Mar 10.

### Drill 28: On promo, no sales (10 min)
```sql
create or replace table d28_promos as
select * from values ('P1','A','STRAW',date'2026-03-01',date'2026-03-04')
as t(promo_id, store_id, item_id, start_date, end_date);       -- end_date is INCLUSIVE
create or replace table d28_daily_sales as
select * from values (date'2026-03-01','A','STRAW',5), (date'2026-03-03','A','STRAW',2)
as t(calendar_date, store_id, item_id, units);
```
**Task:** Build one row per store, item and day on promo, then list promo days with zero sales.

### Drill 29: Weekly counts, daily sales (10 min)
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
**Task:** Weekly sell-through = units sold in the week / on-hand at the week's open.

---

## E. Analysis and tests

### Drill 30: Stockout streaks (12 min)
```sql
create or replace table d30_on_hand as
select item_id, date_add(date'2026-03-01', pos) as calendar_date, on_hand
from (select 'STRAW' as item_id, posexplode(array(5,0,0,3,0,0,0,2,0,4)) as (pos, on_hand));
```
**Task:** One row per stockout streak: start, end, days out.

### Drill 31: Same period last year (8 min)
```sql
create or replace table d31_agg as
select * from values ('A',1,72.0,1000.0), ('A',14,58.0,1000.0)
as t(store_id, fiscal_period_seq, shrink_amt, sales_amt);    -- 13 periods per year
```
**Task:** For period 14: shrink rate, rate last year, change in points, change in percent.

### Drill 32: Write the tests (10 min)
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
**Task:** Write three tests that must return 0 rows: grain, SCD2 overlap, reconciliation. All three should fail on this data.

---

## F. Combos (interview style)

### Drill 33: The Afresh problem (30 min)
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
**Task:** Build `c33_fct_store_item_daily` (units_sold, capacity_units) through SCD2 and daily capacity. Then days of cover per store for Mar 14 to 16 = avg daily capacity / avg daily units sold, over days where capacity is known.

### Drill 34: Shrink by category, as-was vs as-is (20 min)
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
**Task:** March shrink by category two ways: as-was (category at the time) and as-is (today's category).

### Drill 35: Revenue at the right price (25 min)
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
**Task:** Revenue by month at the price in effect, plus a count of units with no price.

### Drill 36: Counted vs computed stock (20 min)
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
**Task:** Per day: computed on-hand, counted on-hand, drift (counted minus computed), and unexplained loss that day.

### Drill 37: Promo lift with overlapping promos (20 min)
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
**Task:** For Mar 1 to 10: average daily units on promo days vs non-promo days.

### Drill 38: On-time delivery by supplier tier (25 min)
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
**Task:** On-time rate (received within 3 days) by supplier tier at the time of ordering. Only received POs count.

### Drill 39: Before vs after go-live (20 min)
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
**Task:** Shrink rate for the 2 weeks before vs the 2 weeks starting at go-live, per store, and the change in points. Only include stores with all 4 weeks.

### Drill 40: Full mock (45 min, talk out loud, record yourself)
No setup. Design on paper or a whiteboard, then write the core SQL.

You are the only data modeler at a grocery AI company. Raw tables:
1. `pos_lines(line_id, basket_id, sold_at, store_id, sku, qty, net_amt, loaded_at)`: lines can be reloaded with corrections.
2. `sku_master_daily(sku, sku_name, category, department, as_of_date)`: the full SKU list, sent every night.
3. `planogram_changes(store_id, sku, capacity_units, effective_date, entered_at)`: entered whenever a shelf is reset, sometimes backdated.

**Ask:** Category managers want days of cover by category for the last 7 complete days, with categories as they were at the time.
**Deliver:** questions you would ask, each source's shape, the model (facts, dims, grain), the core SQL, 5 edge cases, 3 tests.
