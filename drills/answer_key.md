# Answer Key

Open only after you finish a drill. Each answer gives the **shape**, the **trap**, the **SQL** and the **expected result**.
Your SQL can differ. What must match: the expected result, and that you named the trap.

---

## A. Dimensions

### 1. Date dimension
**Shape:** dimension built from a date spine. **Trap:** `date_trunc('week', d)` starts weeks on Monday in Databricks; January belongs to the previous fiscal year.
```sql
create or replace table d01_dim_date as
select d as calendar_date,
       date_format(d, 'EEEE') as day_name,
       date_sub(d, dayofweek(d) - 1) as week_start,           -- dayofweek: Sun = 1 ... Sat = 7
       month(d) as month,
       case when month(d) >= 2 then year(d) else year(d) - 1 end as fiscal_year,
       dayofweek(d) in (1, 7) as is_weekend
from (select explode(sequence(date'2025-12-01', date'2026-12-31', interval 1 day)) as d);
```
**Expected:** 396 rows. 2026-03-14 (Saturday) has week_start 2026-03-08.

### 2. Keys that never drop rows
**Shape:** dimension + Unknown member. **Trap:** an inner join drops store Z and the null store.
```sql
create or replace table d02_dim_store as
select xxhash64(store_id) as store_key, store_id, store_name from d02_stores
union all
select -1, 'UNKNOWN', 'Unknown store';

select s.sale_id, coalesce(d.store_key, -1) as store_key, s.units
from d02_sales s
left join d02_dim_store d on d.store_id = s.store_id;
```
**Expected:** 4 rows, 11 units, two rows with store_key -1.

### 3. SCD1 merge
**Shape:** SCD1 (overwrite). **Trap:** `t.region <> s.region` is null when one side is null, so B's change is missed. Use null-safe `<=>`.
```sql
merge into d03_dim_store t
using d03_incoming s
on t.store_id = s.store_id
when matched and not (t.store_name <=> s.store_name and t.region <=> s.region)
  then update set store_name = s.store_name, region = s.region
when not matched
  then insert (store_key, store_id, store_name, region)
       values (xxhash64(s.store_id), s.store_id, s.store_name, s.region);
```
**Expected:** first run updates 2 rows and inserts 1. Second run changes nothing.

### 4. SCD2 from a nightly full dump
**Shape:** state dump compressed into SCD2. **Trap:** one MERGE cannot both close a changed row and insert its new version. Close first, then insert anything with no current row.
```sql
merge into d04_dim_item t
using d04_dump_0302 s
on t.item_id = s.item_id and t.is_current
when matched and not (t.category <=> s.category)
  then update set valid_to = date'2026-03-02', is_current = false;

insert into d04_dim_item
select xxhash64(s.item_id, date'2026-03-02'), s.item_id, s.category,
       date'2026-03-02', date'9999-12-31', true
from d04_dump_0302 s
left join d04_dim_item t on t.item_id = s.item_id and t.is_current
where t.item_id is null;
```
**Expected:** STRAW Berries (Mar 1 to Mar 2, not current), STRAW Fresh Berries (current), BLUE (unchanged), KIWI (new).

### 5. Role-playing dates
**Shape:** transaction fact with two date roles. **Trap:** one join to the date table can't serve both dates; an inner join on received_date drops PO 103.
```sql
select o.week_start as ordered_week, r.week_start as received_week, sum(d.units) as units
from d05_deliveries d
join d01_dim_date o      on o.calendar_date = d.ordered_date
left join d01_dim_date r on r.calendar_date = d.received_date
group by all;
```
**Expected:** (Mar 1, Mar 8, 40), (Mar 1, Mar 1, 20), (Mar 8, null, 30).

### 6. Bridge table
**Shape:** many-to-many via a bridge. **Trap:** joining sales to the bridge copies the Mar 6 STRAW sale into both promos; adding per-promo totals gives 29, not 19. **Note:** end dates are inclusive here, so `between` is correct.
```sql
-- (a) per promo: fine on its own, never add these up
select p.promo_id, sum(s.units) as units
from d06_sales s
join d06_promo_items pi on pi.item_id = s.item_id
join d06_promos p on p.promo_id = pi.promo_id
                 and s.sale_date between p.start_date and p.end_date
group by p.promo_id;

-- (b) any promo: each sale counted once
select sum(s.units) as units_on_promo
from d06_sales s
where exists (
  select 1
  from d06_promo_items pi
  join d06_promos p on p.promo_id = pi.promo_id
  where pi.item_id = s.item_id
    and s.sale_date between p.start_date and p.end_date);
```
**Expected:** (a) P1 14, P2 15. (b) 19.

---

## B. Change logs

### 7. Price changes
**Shape:** change log to SCD2. **Trap:** forgetting the open end (null valid_to breaks the sandwich join).
```sql
create or replace table d07_price_scd2 as
select item_id, price,
       effective_date as valid_from,
       coalesce(lead(effective_date) over (partition by item_id order by effective_date),
                date'9999-12-31') as valid_to
from d07_price_changes;
```
**Expected:** STRAW 3.99 (Jan 1 to Feb 15), 4.49 (Feb 15 to Mar 10), 3.79 (Mar 10 to 9999); BLUE 2.99 (Jan 1 to 9999).

### 8. Capacity to daily rows
**Shape:** change log to SCD2 to daily snapshot. **Trap:** `between valid_from and valid_to` puts Mar 15 in both versions.
```sql
with scd2 as (
  select store_id, item_id, capacity, changed_on as valid_from,
         coalesce(lead(changed_on) over (partition by store_id, item_id order by changed_on),
                  date'9999-12-31') as valid_to
  from d08_capacity_changes
)
select d.calendar_date, c.store_id, c.item_id, c.capacity
from scd2 c
join d01_dim_date d
  on  c.valid_from <= d.calendar_date          -- bottom bread: included
  and d.calendar_date < c.valid_to             -- top bread: excluded
where d.calendar_date between date'2026-03-13' and date'2026-03-17'   -- a plain filter, fine
order by c.store_id, d.calendar_date;
```
**Expected:** A: 50, 50, 80, 80, 80 (Mar 13 to 17). B: 60, 60 (Mar 16, 17). 7 rows.

### 9. Two changes on one day
**Shape:** change log to SCD2. **Trap:** without dedupe, LEAD makes a version that starts and ends Mar 14.
```sql
with ranked as (
  select store_id, item_id, capacity, cast(change_ts as date) as changed_on,
         row_number() over (partition by store_id, item_id, cast(change_ts as date)
                            order by change_ts desc) as rn
  from d09_capacity_changes
),
latest as (select * from ranked where rn = 1)
select store_id, item_id, capacity, changed_on as valid_from,
       coalesce(lead(changed_on) over (partition by store_id, item_id order by changed_on),
                date'9999-12-31') as valid_to
from latest;
```
**Expected:** 50 (Jan 1 to Mar 14), 80 (Mar 14 to 9999).

### 10. Changes that change nothing
**Shape:** change log to SCD2. **Trap:** order. Collapse with LAG **before** LEAD, or the valid_to dates come out wrong.
```sql
with compared as (
  select item_id, capacity, changed_on,
         lag(capacity) over (partition by item_id order by changed_on) as prev_capacity
  from d10_capacity_changes
),
changed as (
  select * from compared
  where prev_capacity is null or capacity <> prev_capacity
)
select item_id, capacity, changed_on as valid_from,
       coalesce(lead(changed_on) over (partition by item_id order by changed_on),
                date'9999-12-31') as valid_to
from changed;
```
**Expected:** 50 (Jan 1 to Mar 1), 80 (Mar 1 to Apr 5), 60 (Apr 5 to 9999).

### 11. Next-day effect and a start date
**Shape:** change log to SCD2. **Traps:** the next-day rule; entries made before start_date; two entries landing on the same effective day; a repeated value.
```sql
with effective as (
  select store_id, item_id, capacity, change_timestamp,
         greatest(start_date, date_add(cast(change_timestamp as date), 1)) as effective_date
  from d11_capacity_changes
),
ranked as (
  select *, row_number() over (partition by store_id, item_id, effective_date
                               order by change_timestamp desc) as rn
  from effective
),
latest as (select * from ranked where rn = 1),
compared as (
  select *, lag(capacity) over (partition by store_id, item_id order by effective_date) as prev_capacity
  from latest
),
changed as (select * from compared where prev_capacity is null or capacity <> prev_capacity)
select store_id, item_id, capacity, effective_date as valid_from,
       coalesce(lead(effective_date) over (partition by store_id, item_id order by effective_date),
                date'9999-12-31') as valid_to
from changed;
```
**Expected:** A 50 (Jan 1 to Mar 15), A 80 (Mar 15 to 9999), B 60 (Mar 16 to 9999).

### 12. Backdated corrections
**Shape:** change log to SCD2 on effective date. **Trap:** ordering by `entered_at` instead of `effective_date`. When two entries share an effective date, the latest entered wins.
```sql
with ranked as (
  select *, row_number() over (partition by store_id, item_id, effective_date
                               order by entered_at desc) as rn
  from d12_capacity_changes
),
latest as (select * from ranked where rn = 1)
select store_id, item_id, capacity, effective_date as valid_from,
       coalesce(lead(effective_date) over (partition by store_id, item_id order by effective_date),
                date'9999-12-31') as valid_to
from latest;
```
**Expected:** 50 (Jan 1 to Mar 15), 70 (Mar 15 to Mar 16), 75 (Mar 16 to 9999). Mar 15 = 70, Mar 16 = 75.

### 13. Discontinued items
**Shape:** change log to SCD2 with an end event. **Trap:** filtering out the discontinue row before LEAD leaves the 80 version open forever.
```sql
with versions as (
  select item_id, action, capacity, effective_date as valid_from,
         coalesce(lead(effective_date) over (partition by item_id order by effective_date),
                  date'9999-12-31') as valid_to
  from d13_capacity_events
)
select item_id, capacity, valid_from, valid_to
from versions
where action = 'set';
```
**Expected:** 50 (Jan 1 to Mar 15), 80 (Mar 15 to Apr 1).

### 14. Database change feed
**Shape:** CDC to SCD2. **Traps:** the exact duplicate row; the no-op update; the delete must end the version but not become one.
```sql
with dated as (
  select op, item_id, category, commit_ts, cast(commit_ts as date) as change_date
  from d14_item_cdc
),
ranked as (
  select *, row_number() over (partition by item_id, change_date order by commit_ts desc) as rn
  from dated
),
latest as (select * from ranked where rn = 1),
compared as (
  select *, lag(category) over (partition by item_id order by change_date) as prev_category
  from latest
),
changed as (
  select * from compared
  where op = 'D' or not (category <=> prev_category)      -- keep deletes and real changes
),
versions as (
  select item_id, op, category, change_date as valid_from,
         coalesce(lead(change_date) over (partition by item_id order by change_date),
                  date'9999-12-31') as valid_to
  from changed
)
select item_id, category, valid_from, valid_to
from versions
where op <> 'D';
```
**Expected:** STRAW Berries (Jan 1 to Mar 2), STRAW Fresh Berries (Mar 2 to 9999), KIWI Tropical (Feb 1 to Apr 1).

### 15. Status history, two questions
**Shape:** (a) "status on a date" = SCD2. (b) "time between steps" = accumulating snapshot. Same raw table, the question picks the shape.
```sql
-- (a)
with v as (
  select po_id, status, cast(status_at as date) as valid_from,
         coalesce(lead(cast(status_at as date)) over (partition by po_id order by status_at),
                  date'9999-12-31') as valid_to
  from d15_po_status
)
select count(*) as shipped_on_mar5
from v
where status = 'shipped'
  and valid_from <= date'2026-03-05' and date'2026-03-05' < valid_to;

-- (b)
select avg(datediff(received_at, ordered_at)) as avg_days_to_receive
from (
  select po_id,
         min(case when status = 'ordered'  then status_at end) as ordered_at,
         min(case when status = 'received' then status_at end) as received_at
  from d15_po_status
  group by po_id
)
where received_at is not null;
```
**Expected:** (a) 2 (P1 and P2). (b) 5.0.

### 16. Price on the day of sale
**Shape:** point-in-time lookup into SCD2. **Traps:** joining on the current price (as-is); `between` charges the Feb 15 sale twice; an inner join drops the unpriced sale.
```sql
select s.sale_id, s.item_id, s.sold_on, s.units, p.price,
       s.units * p.price as revenue,
       p.price is null as is_unpriced
from d16_sales s
left join d07_price_scd2 p
  on  p.item_id = s.item_id
  and p.valid_from <= s.sold_on and s.sold_on < p.valid_to;
```
**Expected:** 1: 11.97, 2: 8.98, 3: 15.16, 4: 2.99, 5: null (flagged).

---

## C. Transaction facts

### 17. Reloaded rows
**Shape:** transaction fact. **Trap:** sale 1005 counted twice. Newest load wins.
```sql
with ranked as (
  select *, row_number() over (partition by sale_id order by loaded_at desc) as rn
  from d17_sales
)
select cast(sold_at as date) as sale_date, item_id, sum(units) as units
from ranked
where rn = 1
group by all;
```
**Expected:** Mar 14: 6. Mar 16: 5.

### 18. Returns and voids
**Shape:** transaction fact. **Trap:** `txn_id not in (select ref_txn_id from d18_txns)` returns nothing, because the subquery contains nulls. Use NOT EXISTS.
```sql
select s.sold_on, sum(s.units) as net_units
from d18_txns s
where s.txn_type in ('sale', 'return')
  and not exists (
    select 1 from d18_txns v
    where v.txn_type = 'void' and v.ref_txn_id = s.txn_id)
group by s.sold_on;
```
**Expected:** Mar 14: 5. Mar 15: 1.

### 19. A corrected file arrives
**Shape:** idempotent load. **Trap:** a plain insert duplicates Mar 14 on every rerun.
```sql
insert into d19_fct_sales_daily
replace where sale_date = date'2026-03-14'
select sale_date, item_id, units from d19_file_0314;
```
**Expected:** Mar 13 STRAW 4; Mar 14 STRAW 7, BLUE 2. Same after a second run. In a pipeline, the date range comes from a parameter.

### 20. Two feeds, one fact
**Shape:** transaction fact from two event feeds. **Traps:** joining raw rows multiplies them (12 sold, 6 shrink on Mar 14); an inner join drops Mar 15 and 16.
```sql
with s as (
  select sold_on as d, store_id, item_id, sum(units) as units_sold
  from d20_sales group by all
),
k as (
  select logged_on as d, store_id, item_id, sum(units) as shrink_units
  from d20_shrink group by all
)
select coalesce(s.d, k.d)               as calendar_date,
       coalesce(s.store_id, k.store_id) as store_id,
       coalesce(s.item_id, k.item_id)   as item_id,
       coalesce(s.units_sold, 0)        as units_sold,
       coalesce(k.shrink_units, 0)      as shrink_units
from s
full outer join k
  on s.d = k.d and s.store_id = k.store_id and s.item_id = k.item_id;
```
**Expected:** Mar 14: 6 / 3. Mar 15: 3 / 0. Mar 16: 0 / 5.

### 21. The daily file
**Shape:** transaction fact already rolled up to the day, not a snapshot. **Trap:** a row every day looks like a snapshot. The sum test decides: a week's total is a real number.
```sql
select sum(units) as units_week
from d21_daily_item_sales
where sale_date between date'2026-03-09' and date'2026-03-15';
```
**Expected:** 20.

### 22. Counting customers
**Shape:** transaction fact with a non-additive measure. **Trap:** adding daily distinct customers gives 3 for the week; the truth is 2. Recount from line level.
```sql
select sold_on, sum(units) as units, count(distinct customer_id) as customers
from d22_lines
group by sold_on;

select count(distinct customer_id) as customers_week
from d22_lines
where sold_on between date'2026-03-09' and date'2026-03-15';
```
**Expected:** Mar 14: 4 units, 2 customers. Mar 15: 3 units, 1 customer. Week: 2.

---

## D. Snapshots, processes, coverage

### 23. Average stock on hand
**Shape:** periodic snapshot, semi-additive. **Trap:** summing across days (147) or averaging rows (24.5). Add across items per day, then average across days.
```sql
with per_day as (
  select count_date, sum(on_hand) as on_hand
  from d23_counts
  where store_id = 'A'
  group by count_date
)
select avg(on_hand) as avg_daily_on_hand from per_day;
```
**Expected:** 49.

### 24. A snapshot that skips zeros
**Shape:** sparse periodic snapshot. **Trap:** a missing item on a day the file arrived means 0; a missing file means unknown (null).
```sql
with grid as (
  select d.calendar_date, i.item_id
  from d01_dim_date d
  cross join (select * from values ('STRAW'), ('BLUE') as t(item_id)) i
  where d.calendar_date between date'2026-03-09' and date'2026-03-12'
)
select g.calendar_date, g.item_id,
       case when f.arrived then coalesce(c.on_hand, 0) end as on_hand
from grid g
left join d24_file_log f on f.file_date = g.calendar_date
left join d24_counts c   on c.count_date = g.calendar_date and c.item_id = g.item_id
order by g.item_id, g.calendar_date;
```
**Expected:** STRAW 5, 3, null, 0. BLUE 2, 0, null, 4.

### 25. Stock from movements
**Shape:** periodic snapshot built from transactions. **Traps:** quiet days (Mar 10, 12) need rows; forgetting the opening balance.
```sql
with days as (
  select calendar_date from d01_dim_date
  where calendar_date between date'2026-03-09' and date'2026-03-12'
),
moves as (
  select item_id, event_date, sum(qty_change) as net
  from d25_events group by all
),
grid as (
  select o.item_id, o.on_hand as opening, d.calendar_date
  from d25_opening o cross join days d
)
select g.item_id, g.calendar_date,
       g.opening + sum(coalesce(m.net, 0)) over (
         partition by g.item_id order by g.calendar_date
         rows between unbounded preceding and current row) as on_hand
from grid g
left join moves m on m.item_id = g.item_id and m.event_date = g.calendar_date;
```
**Expected:** 38, 38, 31, 31.

### 26. Missing snapshot days
**Shape:** coverage check. **Trap:** you can't find missing rows by looking at rows that exist. Build the expected grid, then anti-join.
```sql
with grid as (
  select s.store_id, d.calendar_date
  from (select distinct store_id from d26_snapshots) s
  cross join d01_dim_date d
  where d.calendar_date between date'2026-03-01' and date'2026-03-07'
)
select g.store_id, g.calendar_date
from grid g
left join d26_snapshots x on x.store_id = g.store_id and x.snapshot_date = g.calendar_date
where x.store_id is null;
```
**Expected:** A Mar 3; B Mar 6; B Mar 7.

### 27. Purchase order lifecycle
**Shape:** accumulating snapshot. **Traps:** in-flight POs must stay (nulls are information); the duplicate event (MIN handles it).
```sql
with piv as (
  select po_id,
         min(case when status = 'ordered'  then status_at end) as ordered_at,
         min(case when status = 'shipped'  then status_at end) as shipped_at,
         min(case when status = 'received' then status_at end) as received_at
  from d27_po_events
  group by po_id
)
select *,
       datediff(received_at, ordered_at) as days_to_receive,
       received_at is null and datediff(date'2026-03-10', ordered_at) > 5 as is_overdue
from piv;
```
**Expected:** P1 5 days, not overdue. P2 null days, overdue (8 days). P3 null days, not overdue (3 days).

### 28. On promo, no sales
**Shape:** factless coverage fact plus an anti-join. **Trap:** you can't find "no sale" rows in the sales table. **Note:** inclusive end date, so `between`.
```sql
with coverage as (
  select d.calendar_date, p.store_id, p.item_id, p.promo_id
  from d28_promos p
  join d01_dim_date d on d.calendar_date between p.start_date and p.end_date
)
select c.*
from coverage c
left join d28_daily_sales s
  on s.calendar_date = c.calendar_date and s.store_id = c.store_id and s.item_id = c.item_id
where coalesce(s.units, 0) = 0;
```
**Expected:** Mar 2 and Mar 4.

### 29. Weekly counts, daily sales
**Shape:** two grains to align. **Trap:** joining daily sales straight to weekly counts. Roll sales up to the week first.
```sql
with weekly_sales as (
  select d.week_start, s.item_id, sum(s.units) as units_sold
  from d29_daily_sales s
  join d01_dim_date d on d.calendar_date = s.sale_date
  group by all
)
select c.week_start, c.item_id, w.units_sold, c.on_hand_at_open,
       w.units_sold / nullif(c.on_hand_at_open, 0) as sell_through
from d29_weekly_counts c
left join weekly_sales w on w.week_start = c.week_start and w.item_id = c.item_id;
```
**Expected:** week of Mar 1: 16 / 40 = 0.40. Week of Mar 8: 20 / 35 = 0.571.

---

## E. Analysis and tests

### 30. Stockout streaks
**Shape:** gaps and islands. **Trap:** grouping by on_hand = 0 merges separate streaks into one.
```sql
with flagged as (
  select item_id, calendar_date, on_hand = 0 as is_out,
         case when (on_hand = 0) <> lag(on_hand = 0) over w then 1 else 0 end as starts_new
  from d30_on_hand
  window w as (partition by item_id order by calendar_date)
),
islands as (
  select *, sum(starts_new) over (partition by item_id order by calendar_date) as island_id
  from flagged
)
select item_id, min(calendar_date) as out_from, max(calendar_date) as out_to, count(*) as days_out
from islands
where is_out
group by item_id, island_id
order by out_from;
```
**Expected:** Mar 2 to 3 (2 days), Mar 5 to 7 (3 days), Mar 9 (1 day).

### 31. Same period last year
**Shape:** period comparison on a fiscal sequence. **Trap:** points vs percent.
```sql
select cur.store_id, cur.fiscal_period_seq,
       round(cur.shrink_amt / nullif(cur.sales_amt, 0) * 100, 2) as rate_pct,
       round(ly.shrink_amt  / nullif(ly.sales_amt, 0)  * 100, 2) as rate_ly_pct,
       round((cur.shrink_amt / nullif(cur.sales_amt, 0)
            - ly.shrink_amt  / nullif(ly.sales_amt, 0)) * 100, 2) as change_pts,
       round(((cur.shrink_amt / nullif(cur.sales_amt, 0))
            / nullif(ly.shrink_amt / nullif(ly.sales_amt, 0), 0) - 1) * 100, 1) as change_pct
from d31_agg cur
left join d31_agg ly
  on ly.store_id = cur.store_id and ly.fiscal_period_seq = cur.fiscal_period_seq - 13
where cur.fiscal_period_seq = 14;
```
**Expected:** 5.8%, 7.2%, -1.4 points, -19.4%.

### 32. Write the tests
**Trap:** each test must return rows when something is wrong, and 0 rows when it's right.
```sql
-- grain: one row per day, store, item
select calendar_date, store_id, item_id, count(*) as n
from d32_fct group by all having count(*) > 1;

-- SCD2: no two versions of an item overlap
select a.item_id, a.item_key, b.item_key
from d32_dim_item a
join d32_dim_item b
  on  a.item_id = b.item_id and a.item_key < b.item_key
  and a.valid_from < b.valid_to and b.valid_from < a.valid_to;

-- reconciliation: fact total equals source total
select s.total as source_units, f.total as fact_units
from (select sum(units) as total from d32_source_sales) s
cross join (select sum(units) as total from d32_fct) f
where s.total <> f.total;
```
**Expected:** each returns 1 row on this data (duplicate grain; overlap Mar 1 to 10; 6 vs 12).

---

## F. Combos

### 33. The Afresh problem
**Recipe:** drill 11 (capacity SCD2), then drill 8 (daily capacity), drill 17 (dedupe sales), drill 20 (full outer join).
**Traps:** the corrected sale; the return; B's sale on Mar 15 before capacity starts (null, not 0); capacity is semi-additive; compare only days where capacity is known.
```sql
create or replace table c33_fct_store_item_daily as
with effective as (
  select store_id, item_id, capacity, change_timestamp,
         greatest(start_date, date_add(cast(change_timestamp as date), 1)) as effective_date
  from c33_capacity_changes
),
ranked as (
  select *, row_number() over (partition by store_id, item_id, effective_date
                               order by change_timestamp desc) as rn
  from effective
),
latest as (select * from ranked where rn = 1),
compared as (
  select *, lag(capacity) over (partition by store_id, item_id order by effective_date) as prev_capacity
  from latest
),
changed as (select * from compared where prev_capacity is null or capacity <> prev_capacity),
cap_scd2 as (
  select store_id, item_id, capacity, effective_date as valid_from,
         coalesce(lead(effective_date) over (partition by store_id, item_id order by effective_date),
                  date'9999-12-31') as valid_to
  from changed
),
cap_daily as (
  select d.calendar_date, c.store_id, c.item_id, c.capacity
  from cap_scd2 c
  join d01_dim_date d on c.valid_from <= d.calendar_date and d.calendar_date < c.valid_to
  where d.calendar_date <= date'2026-03-16'
),
sales_ranked as (
  select *, row_number() over (partition by sale_id order by loaded_at desc) as rn
  from c33_sales
),
sales_daily as (
  select cast(sold_at as date) as calendar_date, store_id, item_id, sum(units) as units_sold
  from sales_ranked where rn = 1 group by all
)
select coalesce(s.calendar_date, c.calendar_date) as calendar_date,
       coalesce(s.store_id, c.store_id)           as store_id,
       coalesce(s.item_id, c.item_id)             as item_id,
       coalesce(s.units_sold, 0)                  as units_sold,
       c.capacity                                 as capacity_units
from sales_daily s
full outer join cap_daily c
  on s.calendar_date = c.calendar_date and s.store_id = c.store_id and s.item_id = c.item_id;

-- days of cover, Mar 14 to 16, only days with known capacity
with per_day as (
  select calendar_date, store_id,
         sum(capacity_units) as capacity, sum(units_sold) as units_sold   -- add across items per day
  from c33_fct_store_item_daily
  where calendar_date between date'2026-03-14' and date'2026-03-16'
    and capacity_units is not null
  group by all
)
select store_id, avg(capacity) / nullif(avg(units_sold), 0) as days_of_cover
from per_day
group by store_id;
```
**Expected fact rows (Mar 14 to 16):** A: 6/50, 0/80, 8/80. B: 2/null (Mar 15), 4/60 (Mar 16).
**Expected days of cover:** A 15.0 (70 / 4.67). B 15.0 (60 / 4).

### 34. Shrink by category, as-was vs as-is
**Recipe:** drill 7 (SCD2), then drill 16 (as-was lookup); as-is = the current version.
```sql
with cat as (
  select item_id, category, effective_date as valid_from,
         coalesce(lead(effective_date) over (partition by item_id order by effective_date),
                  date'9999-12-31') as valid_to
  from c34_category_changes
)
select 'as_was' as view, c.category, sum(s.shrink_amt) as shrink_amt
from c34_shrink s
join cat c on c.item_id = s.item_id and c.valid_from <= s.shrink_date and s.shrink_date < c.valid_to
group by all
union all
select 'as_is', c.category, sum(s.shrink_amt)
from c34_shrink s
join cat c on c.item_id = s.item_id and c.valid_to = date'9999-12-31'
group by all;
```
**Expected:** as-was: Berries 14, Fresh Berries 6. As-is: Fresh Berries 16, Berries 4.

### 35. Revenue at the right price
**Recipe:** drill 9 (same-day dedupe), then drill 10 (collapse), drill 7 (LEAD), drill 16 (lookup).
```sql
with ranked as (
  select item_id, price, cast(change_ts as date) as eff,
         row_number() over (partition by item_id, cast(change_ts as date) order by change_ts desc) as rn
  from c35_price_changes
),
latest as (select * from ranked where rn = 1),
compared as (
  select *, lag(price) over (partition by item_id order by eff) as prev_price from latest
),
changed as (select * from compared where prev_price is null or price <> prev_price),
price_scd2 as (
  select item_id, price, eff as valid_from,
         coalesce(lead(eff) over (partition by item_id order by eff), date'9999-12-31') as valid_to
  from changed
)
select date_trunc('month', s.sold_on) as month,
       sum(s.units * p.price) as revenue,
       sum(case when p.price is null then s.units else 0 end) as unpriced_units
from c35_sales s
left join price_scd2 p
  on p.item_id = s.item_id and p.valid_from <= s.sold_on and s.sold_on < p.valid_to
group by all
order by month;
```
**Expected:** Dec 2025: revenue null, 1 unpriced unit. Feb: 20.55. Mar: 15.66.

### 36. Counted vs computed stock
**Recipe:** drill 25 (computed on-hand), then join the counts and use LAG for daily change.
```sql
with days as (
  select calendar_date from d01_dim_date
  where calendar_date between date'2026-03-09' and date'2026-03-11'
),
moves as (select item_id, event_date, sum(qty_change) as net from c36_events group by all),
computed as (
  select o.item_id, d.calendar_date,
         o.on_hand + sum(coalesce(m.net, 0)) over (
           partition by o.item_id order by d.calendar_date
           rows between unbounded preceding and current row) as computed
  from c36_opening o
  cross join days d
  left join moves m on m.item_id = o.item_id and m.event_date = d.calendar_date
),
compared as (
  select c.item_id, c.calendar_date, c.computed, k.counted, k.counted - c.computed as drift
  from computed c
  join c36_counts k on k.item_id = c.item_id and k.count_date = c.calendar_date
)
select *, drift - coalesce(lag(drift) over (partition by item_id order by calendar_date), 0)
          as unexplained_today
from compared
order by calendar_date;
```
**Expected:** computed 38, 34, 29. Counted 38, 33, 26. Drift 0, -1, -3. Unexplained today 0, -1, -2.

### 37. Promo lift with overlapping promos
**Traps:** Mar 4 and 5 sit in two promos (count each day once); days with no sales must count as zero days.
```sql
with days as (
  select d.calendar_date, i.item_id
  from d01_dim_date d
  cross join (select distinct item_id from c37_promos) i
  where d.calendar_date between date'2026-03-01' and date'2026-03-10'
),
flagged as (
  select d.calendar_date, d.item_id,
         exists (select 1 from c37_promos p
                 where p.item_id = d.item_id
                   and d.calendar_date between p.start_date and p.end_date) as on_promo
  from days d
),
daily as (
  select f.calendar_date, f.item_id, f.on_promo, coalesce(sum(s.units), 0) as units
  from flagged f
  left join c37_sales s on s.item_id = f.item_id and s.sale_date = f.calendar_date
  group by all
)
select item_id, on_promo, count(*) as days, sum(units) as units, avg(units) as avg_daily_units
from daily
group by all;
```
**Expected:** on promo: 8 days, 14 units, 1.75 per day. Not on promo: 2 days, 3 units, 1.5 per day.

### 38. On-time delivery by supplier tier
**Recipe:** drill 27 (accumulating snapshot), then drill 7 (tier SCD2) and drill 16 (as-was lookup at the order date).
```sql
with po as (
  select po_id, supplier_id,
         min(case when status = 'ordered'  then status_at end) as ordered_at,
         min(case when status = 'received' then status_at end) as received_at
  from c38_po_events
  group by po_id, supplier_id
),
tier as (
  select supplier_id, tier, effective_date as valid_from,
         coalesce(lead(effective_date) over (partition by supplier_id order by effective_date),
                  date'9999-12-31') as valid_to
  from c38_tier_changes
)
select t.tier,
       count(*) as received_pos,
       avg(case when datediff(p.received_at, p.ordered_at) <= 3 then 1.0 else 0.0 end) as on_time_rate
from po p
join tier t
  on  t.supplier_id = p.supplier_id
  and t.valid_from <= cast(p.ordered_at as date) and cast(p.ordered_at as date) < t.valid_to
where p.received_at is not null
group by t.tier;
```
**Expected:** Standard 1 PO, 100%. Preferred 2 POs, 50%.

### 39. Before vs after go-live
**Traps:** the window is relative to each store; store B lacks a second week after go-live, so it's excluded; sum the parts, then divide.
```sql
with tagged as (
  select w.*, datediff(w.week_start, s.go_live_date) / 7 as week_offset
  from c39_weekly w
  join c39_stores s on s.store_id = w.store_id
),
windowed as (
  select * from tagged where week_offset between -2 and 1
),
complete as (
  select store_id from windowed group by store_id having count(*) = 4
)
select w.store_id,
       sum(case when week_offset < 0  then shrink_amt end)
         / nullif(sum(case when week_offset < 0  then sales_amt end), 0) * 100 as rate_before_pct,
       sum(case when week_offset >= 0 then shrink_amt end)
         / nullif(sum(case when week_offset >= 0 then sales_amt end), 0) * 100 as rate_after_pct,
       (sum(case when week_offset >= 0 then shrink_amt end)
          / nullif(sum(case when week_offset >= 0 then sales_amt end), 0)
        - sum(case when week_offset < 0 then shrink_amt end)
          / nullif(sum(case when week_offset < 0 then sales_amt end), 0)) * 100 as change_pts
from windowed w
join complete c on c.store_id = w.store_id
group by w.store_id;
```
**Expected:** A: 7.0% before, 4.5% after, -2.5 points. B excluded.

### 40. Full mock: answer outline
**Questions first:** who acts on days of cover, and how often? Is capacity per store and SKU? What counts as a complete day? Which calendar? Do returns count as sales?
**Shapes:**
- `pos_lines`: transaction, with corrections (drill 17).
- `sku_master_daily`: full nightly dump, to be compressed into SCD2 (drill 4).
- `planogram_changes`: change log with backdating (drill 12).
**Model:**
- `dim_sku` (SCD2), `dim_store`, `dim_date`.
- `int_capacity_scd2`, then `int_capacity_daily` (sandwich join).
- `fct_store_sku_daily`: grain store x SKU x day, with units_sold (from deduped lines) and capacity_units (null when unknown). Full outer join.
**Metric:** for each category and day, sum capacity and units across stores and SKUs (category as-was, via the SCD2 sandwich on the day). Then average across the last 7 complete days and divide, counting only days with known capacity.
**Edge cases:** corrected lines; returns; backdated resets; same-day resets; SKU moving categories mid-week; a missing nightly dump; sales before capacity exists.
**Tests:** grain uniqueness on the fact; no overlapping versions in both SCD2s; fact units equal deduped source units.
