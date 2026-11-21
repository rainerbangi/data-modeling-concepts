# Answer Key

Open only after you finish a drill. Every answer follows the same order, so the reasoning lands before the SQL:

1. **The idea:** what the drill is really teaching, in one or two lines.
2. **Shape and grain:** what one raw row means, and what one output row means.
3. **The trap:** the mistake most people make, shown with the drill's own numbers.
4. **Think it through:** the steps in plain words. Each step becomes one CTE.
5. **SQL:** comments match the steps.
6. **Expected:** the result to compare with yours.
7. **Why this way:** why this is the best approach, and what the alternatives cost.

Your SQL can differ. What must match: the expected result, and that you named the trap.

**Conventions used everywhere**
- SCD2 ranges are half-open: `valid_from` included, `valid_to` excluded, open row `9999-12-31`.
- The sandwich join: `valid_from <= d and d < valid_to`. Each day lands in exactly one version.
- A missing **state** value is unknown, so it stays null. A missing **event** means nothing happened, so it counts as zero.
- Ratios: sum the parts, divide last, `nullif` the denominator.

---

## A. Dimensions

### 1. Date dimension

**The idea:** every time-based model needs a calendar table with one row per day. You build it from nothing, by generating dates.

**Shape and grain:** a dimension. One row per calendar day.

**The trap:** two of them.
- `date_trunc('week', d)` starts weeks on **Monday** in Databricks. The drill wants **Sunday**, so 2026-03-14 (a Saturday) must map to 2026-03-08, not 2026-03-09.
- A fiscal year that starts Feb 1 means **January belongs to the previous fiscal year**. 2026-01-15 is fiscal 2025.

**Think it through:**
1. Generate every date in the range: `sequence()` makes an array of dates, `explode()` turns it into rows.
2. Week start: Databricks `dayofweek()` returns Sunday = 1 to Saturday = 7. Subtract `dayofweek - 1` days and you land on Sunday.
3. Fiscal year: February to December keep the calendar year; January goes back one.
4. Weekend: day 1 (Sunday) or day 7 (Saturday).

```sql
create or replace table d01_dim_date as
select d                                   as calendar_date,
       date_format(d, 'EEEE')              as day_name,
       date_sub(d, dayofweek(d) - 1)       as week_start,   -- step 2: back up to Sunday
       month(d)                            as month,
       case when month(d) >= 2 then year(d)
            else year(d) - 1 end           as fiscal_year,  -- step 3: January belongs to last FY
       dayofweek(d) in (1, 7)              as is_weekend    -- step 4
from (                                                      -- step 1: one row per day
  select explode(sequence(date'2025-12-01', date'2026-12-31', interval 1 day)) as d
);
```

**Expected:** 396 rows. 2026-03-14 (Saturday) has week_start 2026-03-08. 2026-01-15 has fiscal_year 2025.

**Why this way:** generating dates guarantees no gaps. Building a calendar from fact dates (`select distinct sale_date`) silently skips days with no sales, and later joins to it lose those days.

---

### 2. Keys that never drop rows

**The idea:** a fact row must never disappear because its dimension row is missing. Give the dimension an "Unknown" member and point orphans at it.

**Shape and grain:** a dimension (one row per store, plus Unknown) and a transaction fact (one row per sale).

**The trap:** sale 3 has store Z, which isn't in the store table, and sale 4 has no store at all. An inner join drops both, so total units fall from 11 to 8 and nobody notices.

**Think it through:**
1. Build the store dimension with a surrogate key: a hash of the business key, so it's the same every time you rebuild.
2. Add one extra row: key `-1`, "Unknown store".
3. Join sales to stores with a **left** join, so every sale survives.
4. Where no store matched, use `-1`.

```sql
create or replace table d02_dim_store as
select xxhash64(store_id) as store_key, store_id, store_name   -- step 1: stable surrogate key
from d02_stores
union all
select -1, 'UNKNOWN', 'Unknown store';                         -- step 2: the Unknown member

select s.sale_id,
       coalesce(d.store_key, -1) as store_key,                 -- step 4: orphans point to Unknown
       s.units
from d02_sales s
left join d02_dim_store d on d.store_id = s.store_id;          -- step 3: left join keeps every sale
```

**Expected:** 4 rows, 11 units, two rows with store_key -1.

**Why this way:** the Unknown member keeps totals right and makes data problems *visible*: you can count rows with key -1 and alert on them. Dropping rows hides the problem; a null key breaks every later inner join.

---

### 3. Fix typos, keep no history (SCD1)

**The idea:** some attributes don't need history. A typo fix should simply overwrite the old value. That's SCD Type 1.

**Shape and grain:** a dimension, one row per store, current values only.

**The trap:** store B's region goes from null to "West". The check `t.region <> s.region` compares null with "West", which gives **null, not true**, so the change is skipped. You need a null-safe comparison.

**Think it through:**
1. Match incoming rows to existing ones on the business key, `store_id`.
2. If matched and anything changed, overwrite the values. Use `<=>` (null-safe equals: `null <=> null` is true, `null <=> 'West'` is false).
3. If not matched, insert it as a new store.
4. Only update rows that actually changed, so a rerun changes nothing.

```sql
merge into d03_dim_store t
using d03_incoming s
on t.store_id = s.store_id                                          -- step 1
when matched and not (t.store_name <=> s.store_name                 -- step 2 + 4: only real changes,
                      and t.region <=> s.region)                    --   null-safe
  then update set store_name = s.store_name, region = s.region
when not matched                                                    -- step 3
  then insert (store_key, store_id, store_name, region)
       values (xxhash64(s.store_id), s.store_id, s.store_name, s.region);
```

**Expected:** first run updates A ("Stor A" to "Store A") and B (region null to West), and inserts C. A second run changes nothing.

**Why this way:** one `merge` does update and insert in a single atomic step. The "only if changed" condition makes it idempotent and avoids rewriting unchanged rows, which keeps Delta history clean.

---

### 4. Nightly full dump into SCD2

**The idea:** the source sends the *whole* item list every night. You keep history by comparing tonight's list with the current versions and recording only what changed.

**Shape and grain:** a state dump in, an SCD2 dimension out. One row per item per version.

**The trap:** a single `merge` can't both *close* STRAW's old version and *insert* its new version, because one source row can only take one action. Run it as two statements: close, then open.

**Think it through:**
1. **Close:** for each current version whose category differs from tonight's, set `valid_to` to today and `is_current` to false.
2. **Open:** insert a new current version for every item that now has no current row. That catches both changed items (just closed) and brand-new items (KIWI).
3. Unchanged items (BLUE) are untouched by both steps.

```sql
-- step 1: close versions that changed
merge into d04_dim_item t
using d04_dump_0302 s
on t.item_id = s.item_id and t.is_current
when matched and not (t.category <=> s.category)
  then update set valid_to = date'2026-03-02', is_current = false;

-- step 2: open a version for anything without a current row (changed or new)
insert into d04_dim_item
select xxhash64(s.item_id, date'2026-03-02') as item_key,
       s.item_id, s.category,
       date'2026-03-02' as valid_from, date'9999-12-31' as valid_to, true as is_current
from d04_dump_0302 s
left join d04_dim_item t on t.item_id = s.item_id and t.is_current
where t.item_id is null;
```

**Expected:** STRAW Berries (Mar 1 to Mar 2, not current), STRAW Fresh Berries (current), BLUE Berries (unchanged, current), KIWI Tropical (new, current). Exactly 3 current rows.

**Why this way:** it touches only changed rows. In production the date comes from a parameter, and both statements run in one job so a failure in between can be rerun safely. A one-statement alternative exists (union the changed rows in twice with a null merge key), but the two-step version is far easier to read and explain.

---

### 5. One fact, two dates (role-playing dimension)

**The idea:** one fact can have several dates (ordered, received). Each one joins to the same date dimension separately, playing a different "role".

**Shape and grain:** a transaction fact, one row per delivery. Output: units by ordered week and received week.

**The trap:** PO 103 hasn't been received, so `received_date` is null. An inner join on received date drops it, and 30 units vanish.

**Think it through:**
1. Join the date table once as **o** (ordered date) to get the ordered week.
2. Join it again as **r** (received date) to get the received week. Make this a **left** join, because a PO may not have arrived.
3. Group by both weeks and sum units.

```sql
select o.week_start as ordered_week,
       r.week_start as received_week,
       sum(d.units) as units
from d05_deliveries d
join d01_dim_date o      on o.calendar_date = d.ordered_date    -- step 1: role "ordered"
left join d01_dim_date r on r.calendar_date = d.received_date   -- step 2: role "received", may be null
group by all;                                                   -- step 3
```

**Expected:** (Mar 1, Mar 8, 40), (Mar 1, Mar 1, 20), (Mar 8, null, 30).

**Why this way:** aliasing one dimension is how every BI tool and semantic layer models multiple dates. Copying the date table into "dim_order_date" and "dim_receipt_date" duplicates data for no gain.

---

### 6. Promotions that share items (bridge table)

**The idea:** one promo covers many items, and one item can be in many promos. That many-to-many link lives in a **bridge** table. The danger is counting a sale twice.

**Shape and grain:** promos (one row per promo), a bridge (one row per promo and item), and sales (one row per sale).

**The trap:** the Mar 6 STRAW sale (10 units) is in both P1 and P2. Per-promo totals are 14 and 15. Add them and you get 29, but only 19 units were ever sold on promo.

**Think it through:**
- **(a) Units per promo:** join sales to the bridge and promos, keep sales inside each promo's dates, and group by promo. A sale counting toward two promos is correct *here*, because each promo really had it. Just never add these rows together.
- **(b) Units on any promo:** ask a yes/no question per sale: "was this sale on *any* promo?" `exists` answers exactly that, and counts each sale once.
- Note: these end dates are **inclusive**, so `between` is right here. Always check what kind of end date you have.

```sql
-- (a) per promo: each promo's own total (do not add these up)
select p.promo_id, sum(s.units) as units
from d06_sales s
join d06_promo_items pi on pi.item_id = s.item_id
join d06_promos p       on p.promo_id = pi.promo_id
                       and s.sale_date between p.start_date and p.end_date   -- inclusive end
group by p.promo_id;

-- (b) on any promo: one yes/no per sale, so no double counting
select sum(s.units) as units_on_promo
from d06_sales s
where exists (
  select 1
  from d06_promo_items pi
  join d06_promos p on p.promo_id = pi.promo_id
  where pi.item_id = s.item_id
    and s.sale_date between p.start_date and p.end_date
);
```

**Expected:** (a) P1 14, P2 15. (b) 19.

**Why this way:** `exists` stops at the first match and never multiplies rows. The common alternative, join then `select distinct`, works but is slower and breaks easily once more columns are added.

---

## B. Change logs

The whole block uses one recipe. Learn it once:

| Step | Problem it fixes | Tool |
|---|---|---|
| **Clean** | two changes on the same day | `row_number`, keep the newest |
| **Collapse** | a "change" to the same value | `lag`, keep only real changes |
| **Close** | each version needs an end | `lead`, next start = this end |
| **Calendar** | one row per day | sandwich join to dates |

Not every drill needs all four. The skill is spotting which ones the data needs.

---

### 7. Price changes

**The idea:** a change log only says when a value *started*. SCD2 adds when it *ended*, which is simply when the next change started.

**Shape and grain:** a change log in; SCD2 out, one row per item per price.

**The trap:** the latest price has no next change, so `lead()` returns null. A null `valid_to` makes the sandwich join (`d < valid_to`) fail, and current sales lose their price.

**Think it through:**
1. For each item, order changes by date.
2. `valid_from` = this change's date.
3. `valid_to` = the next change's date (`lead`). If there is no next change, use `9999-12-31` (open).

```sql
create or replace table d07_price_scd2 as
select item_id, price,
       effective_date as valid_from,                               -- step 2
       coalesce(
         lead(effective_date) over (partition by item_id           -- step 1 + 3: next start
                                    order by effective_date),      --   = this end
         date'9999-12-31'                                          -- still open
       ) as valid_to
from d07_price_changes;
```

**Expected:** STRAW 3.99 (Jan 1 to Feb 15), 4.49 (Feb 15 to Mar 10), 3.79 (Mar 10 to 9999). BLUE 2.99 (Jan 1 to 9999).

**Why this way:** one pass with a window function. The old alternative, a self-join to find "the smallest later date", is slower and harder to read. Save this table: drill 16 uses it.

---

### 8. Shelf capacity to daily rows

**The idea:** to put capacity next to daily sales, you turn each version (a date range) into one row per day.

**Shape and grain:** change log, then SCD2, then a daily snapshot: one row per store, item and day.

**The trap:** joining dates with `between valid_from and valid_to` includes **both** ends, so Mar 15 matches the 50 version *and* the 80 version. That day gets two rows, and capacity adds up to 130.

**Think it through:**
1. Close each version with `lead` (drill 7).
2. Join to the calendar with the sandwich: a date belongs to a version if `valid_from <= date` **and** `date < valid_to`. The start is in, the end is out, so each date lands in exactly one version.
3. Filter to the days you want.

```sql
with scd2 as (                                                  -- step 1
  select store_id, item_id, capacity,
         changed_on as valid_from,
         coalesce(lead(changed_on) over (partition by store_id, item_id order by changed_on),
                  date'9999-12-31') as valid_to
  from d08_capacity_changes
)
select d.calendar_date, c.store_id, c.item_id, c.capacity
from scd2 c
join d01_dim_date d
  on  c.valid_from <= d.calendar_date                          -- step 2: bottom bread, included
  and d.calendar_date < c.valid_to                             --         top bread, excluded
where d.calendar_date between date'2026-03-13' and date'2026-03-17'   -- step 3: plain filter, fine
order by c.store_id, d.calendar_date;
```

**Expected:** A: 50, 50, 80, 80, 80 (Mar 13 to 17). B: 60, 60 (Mar 16 and 17). 7 rows; Mar 15 for A appears once.

**Why this way:** half-open ranges never overlap and never leave gaps, so every day is counted exactly once. `between` is fine for filtering one range; it's wrong for matching a day to back-to-back versions.

---

### 9. Two changes on one day

**The idea:** if someone changes capacity twice in one day, only the last change counts for that day.

**Shape and grain:** change log to SCD2, one row per item per **day-level** version.

**The trap:** without cleaning, the 70 change gets valid_from Mar 14 and valid_to Mar 14 (the next change is the same day). That's a version that covers zero days, and it confuses every lookup.

**Think it through:**
1. **Clean:** number changes within each store, item and day, newest first (`row_number ... order by change_ts desc`). Keep number 1.
2. **Close:** apply `lead` to the cleaned rows.

```sql
with ranked as (                                              -- step 1: rank within a day
  select store_id, item_id, capacity,
         cast(change_ts as date) as changed_on,
         row_number() over (partition by store_id, item_id, cast(change_ts as date)
                            order by change_ts desc) as rn
  from d09_capacity_changes
),
latest as (select * from ranked where rn = 1)                 -- keep the last change per day
select store_id, item_id, capacity,
       changed_on as valid_from,                              -- step 2: close
       coalesce(lead(changed_on) over (partition by store_id, item_id order by changed_on),
                date'9999-12-31') as valid_to
from latest;
```

**Expected:** 50 (Jan 1 to Mar 14), 80 (Mar 14 to 9999).

**Why this way:** `row_number` picks exactly one row even when timestamps tie, and is the standard "latest per key" pattern. Filtering in a separate CTE (`where rn = 1`) replaces `qualify` and works in every warehouse.

---

### 10. Changes that change nothing

**The idea:** a "change" to the same value isn't a change. Keep it and you split one version into two.

**Shape and grain:** change log to SCD2, one row per real change.

**The trap:** order matters. If you close (`lead`) before collapsing, the 50 version ends on Feb 1 (the no-op row) instead of Mar 1. Collapse first, then close.

**Think it through:**
1. **Collapse:** for each row, look at the previous value (`lag`). Keep the row only if it's the first row or the value differs.
2. **Close:** `lead` on what's left.

Walk through it: 50, **50**, 80, **80**, 60. The bold rows repeat the previous value and are dropped, leaving 50, 80, 60.

```sql
with compared as (                                            -- step 1: what came before?
  select item_id, capacity, changed_on,
         lag(capacity) over (partition by item_id order by changed_on) as prev_capacity
  from d10_capacity_changes
),
changed as (
  select * from compared
  where prev_capacity is null                                  -- the first row always stays
     or capacity <> prev_capacity                              -- a real change
)
select item_id, capacity,                                      -- step 2: close
       changed_on as valid_from,
       coalesce(lead(changed_on) over (partition by item_id order by changed_on),
                date'9999-12-31') as valid_to
from changed;
```

**Expected:** 50 (Jan 1 to Mar 1), 80 (Mar 1 to Apr 5), 60 (Apr 5 to 9999). 3 versions.

**Why this way:** the fewest, correct versions make lookups faster and history readable. If capacity could be null, use `not (capacity <=> prev_capacity)` instead of `<>`.

---

### 11. Next-day effect and a start date

**The idea:** real change logs come with business rules. Here: a change takes effect the **next day**, and never before the item's `start_date`.

**Shape and grain:** change log to SCD2, one row per store, item and version.

**The trap:** four, all in the data.
- The rule: an entry on Mar 14 takes effect Mar 15.
- Entries before the start date: store A's first entry (Dec 30) would start Dec 31, but A starts Jan 1. Store B's entry (Mar 10) would start Mar 11, but B starts Mar 16.
- Two entries on Mar 14 (70 and 80) land on the same effective day. The later one (80) wins.
- Apr 2 repeats 80. Drop it.

**Think it through:**
1. **Effective date** = the later of `start_date` and the day after the change: `greatest(start_date, change_date + 1)`.
2. **Clean:** one row per effective day, newest entry wins.
3. **Collapse:** drop repeats.
4. **Close:** `lead`.

```sql
with effective as (                                                    -- step 1: apply the rules
  select store_id, item_id, capacity, change_timestamp,
         greatest(start_date,
                  date_add(cast(change_timestamp as date), 1)) as effective_date
  from d11_capacity_changes
),
ranked as (                                                            -- step 2: clean
  select *, row_number() over (partition by store_id, item_id, effective_date
                               order by change_timestamp desc) as rn
  from effective
),
latest as (select * from ranked where rn = 1),
compared as (                                                          -- step 3: collapse
  select *, lag(capacity) over (partition by store_id, item_id
                                order by effective_date) as prev_capacity
  from latest
),
changed as (
  select * from compared
  where prev_capacity is null or capacity <> prev_capacity
)
select store_id, item_id, capacity,                                    -- step 4: close
       effective_date as valid_from,
       coalesce(lead(effective_date) over (partition by store_id, item_id
                                           order by effective_date),
                date'9999-12-31') as valid_to
from changed;
```

**Expected:** A 50 (Jan 1 to Mar 15), A 80 (Mar 15 to 9999), B 60 (Mar 16 to 9999). 3 versions.

**Why this way:** compute the business date **first**, then run the standard recipe on it. Every later step then works on the date that matters, and the rules live in one place.

---

### 12. Backdated corrections

**The idea:** a change can be *entered* after the date it *takes effect*. History is built on the effective date; the entered date only breaks ties.

**Shape and grain:** change log to SCD2 on effective date.

**The trap:** ordering by `entered_at` puts the Mar 20 correction (effective Mar 15) after the Mar 15 entry (effective Mar 16), so versions come out in the wrong order. Two entries for Mar 16 (80, then 75) must resolve to the **latest entered**: 75.

**Think it through:**
1. **Clean:** one row per effective date. If several, the latest `entered_at` wins (the most recent correction).
2. **Close:** order by `effective_date`, not `entered_at`.

```sql
with ranked as (                                                     -- step 1
  select *, row_number() over (partition by store_id, item_id, effective_date
                               order by entered_at desc) as rn      -- latest correction wins
  from d12_capacity_changes
),
latest as (select * from ranked where rn = 1)
select store_id, item_id, capacity,
       effective_date as valid_from,                                -- step 2: timeline by effective date
       coalesce(lead(effective_date) over (partition by store_id, item_id
                                           order by effective_date),
                date'9999-12-31') as valid_to
from latest;
```

**Expected:** 50 (Jan 1 to Mar 15), 70 (Mar 15 to Mar 16), 75 (Mar 16 to 9999). Mar 15 = 70; Mar 16 = 75.

**Why this way:** it gives the best-known truth for every day. When a backdated entry lands, rebuild the affected date range (drill 19), not just today.

---

### 13. Discontinued items

**The idea:** an "end" event doesn't create a version. It closes the last one.

**Shape and grain:** change log with an end event, to SCD2.

**The trap:** if you filter out the discontinue row *before* `lead`, the 80 version has no next row and stays open forever. The item looks active after it was discontinued.

**Think it through:**
1. **Close** using *all* rows, including the discontinue row. Now the 80 version ends on Apr 1.
2. **Then** remove the discontinue row itself, because it isn't a version.

```sql
with versions as (                                                  -- step 1: close using every event
  select item_id, action, capacity,
         effective_date as valid_from,
         coalesce(lead(effective_date) over (partition by item_id order by effective_date),
                  date'9999-12-31') as valid_to
  from d13_capacity_events
)
select item_id, capacity, valid_from, valid_to                      -- step 2: drop the end event
from versions
where action = 'set';
```

**Expected:** 50 (Jan 1 to Mar 15), 80 (Mar 15 to Apr 1). No version on or after Apr 1.

**Why this way:** filter **after** the window function, never before. A `where` clause runs before window functions, so filtering early changes what `lead` can see. This order rule shows up in every change-log problem.

---

### 14. Database change feed (CDC)

**The idea:** a database change feed sends inserts (I), updates (U) and deletes (D). It's a change log with noise: duplicates, no-op updates and deletes.

**Shape and grain:** CDC to SCD2 of item category, one row per item per version.

**The trap:** three.
- STRAW's Mar 2 update arrives twice (an exact duplicate).
- KIWI's Feb 10 update repeats "Tropical" (no change).
- KIWI's delete must **end** its version but not become a version (drill 13).

**Think it through:**
1. **Clean:** one row per item per day; newest commit wins. This also removes the exact duplicate.
2. **Collapse:** keep a row if it's a delete or the category changed. Use `<=>` because a delete has a null category.
3. **Close:** `lead` on everything kept, including deletes.
4. **Drop the delete rows.**

```sql
with dated as (
  select op, item_id, category, commit_ts, cast(commit_ts as date) as change_date
  from d14_item_cdc
),
ranked as (                                                              -- step 1: clean
  select *, row_number() over (partition by item_id, change_date
                               order by commit_ts desc) as rn
  from dated
),
latest as (select * from ranked where rn = 1),
compared as (                                                            -- step 2: collapse
  select *, lag(category) over (partition by item_id order by change_date) as prev_category
  from latest
),
changed as (
  select * from compared
  where op = 'D' or not (category <=> prev_category)                    -- deletes + real changes
),
versions as (                                                            -- step 3: close
  select item_id, op, category, change_date as valid_from,
         coalesce(lead(change_date) over (partition by item_id order by change_date),
                  date'9999-12-31') as valid_to
  from changed
)
select item_id, category, valid_from, valid_to                           -- step 4: no delete versions
from versions
where op <> 'D';
```

**Expected:** STRAW Berries (Jan 1 to Mar 2), STRAW Fresh Berries (Mar 2 to 9999), KIWI Tropical (Feb 1 to Apr 1).

**Why this way:** it's drills 9, 10 and 13 in one, in the same order: clean, collapse, close, then drop. If you remember the order, any CDC feed is the same problem.

---

### 15. Status history, two questions

**The idea:** the **question** picks the shape, not the table. The same status history can be an SCD2 or an accumulating snapshot.

**Shape and grain:**
- (a) "How many POs were shipped on Mar 5?" asks for **state at a point in time**, so SCD2.
- (b) "How long from ordered to received?" asks for **time between steps**, so an accumulating snapshot: one row per PO with a column per step.

**The trap:** forcing one shape onto both questions. Counting "shipped" rows by date answers neither correctly.

**Think it through:**
- **(a)** Close each status with `lead` (it lasts until the next status). Count POs whose shipped version covers Mar 5, using the sandwich.
- **(b)** Pivot: one row per PO, taking the timestamp for each step with `min(case when ...)`. Keep received POs and average the days.

```sql
-- (a) state on a date: SCD2
with v as (
  select po_id, status,
         cast(status_at as date) as valid_from,
         coalesce(lead(cast(status_at as date)) over (partition by po_id order by status_at),
                  date'9999-12-31') as valid_to
  from d15_po_status
)
select count(*) as shipped_on_mar5
from v
where status = 'shipped'
  and valid_from <= date'2026-03-05' and date'2026-03-05' < valid_to;   -- the sandwich

-- (b) time between steps: accumulating snapshot
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

**Expected:** (a) 2 (P1 shipped Mar 3 to 6, P2 shipped from Mar 5). (b) 5.0 (only P1 was received).

**Why this way:** each shape answers its question with one simple filter or average. In an interview, say the question out loud and name the shape *before* writing SQL.

---

### 16. Price on the day of sale

**The idea:** a sale must use the price that was true **on the sale date**, not today's price. That's a point-in-time ("as-was") lookup into SCD2.

**Shape and grain:** transaction fact plus SCD2 lookup. One row per sale.

**The trap:** three.
- Joining on the current price charges every sale today's 3.79.
- `between` puts the Feb 15 sale in two price versions, so it appears twice.
- Sale 5 (Dec 20, 2025) happened before any price existed. An inner join drops it.

**Think it through:**
1. **Left** join each sale to the price version that covers its date, using the sandwich.
2. Revenue = units × price.
3. Flag sales with no price instead of hiding them.

```sql
select s.sale_id, s.item_id, s.sold_on, s.units,
       p.price,
       s.units * p.price  as revenue,
       p.price is null    as is_unpriced                       -- step 3: make gaps visible
from d16_sales s
left join d07_price_scd2 p                                     -- step 1: keep every sale
  on  p.item_id    = s.item_id
  and p.valid_from <= s.sold_on                                --   the sandwich: exactly one
  and s.sold_on    <  p.valid_to;                              --   version per sale
```

**Expected:** sale 1: 11.97 (3 × 3.99), 2: 8.98 (2 × 4.49, Feb 15 uses the new price), 3: 15.16 (4 × 3.79), 4: 2.99, 5: null, flagged.

**Why this way:** this is the most-used SCD2 query in practice. Every fact that needs a historical attribute is built this way.

---

## C. Transaction facts

### 17. Reloaded rows

**The idea:** files get reloaded with corrections. The same sale can arrive twice; the **latest load** is the truth.

**Shape and grain:** transaction fact. Output: one row per item per day.

**The trap:** sale 1005 arrives with 3 units, then again with 4. Sum both and Mar 16 shows 8 units instead of 5.

**Think it through:**
1. **Dedupe:** number the copies of each `sale_id`, newest `loaded_at` first. Keep number 1.
2. **Aggregate:** sum units per day and item.

```sql
with ranked as (                                                  -- step 1: newest copy first
  select *, row_number() over (partition by sale_id order by loaded_at desc) as rn
  from d17_sales
)
select cast(sold_at as date) as sale_date, item_id, sum(units) as units   -- step 2
from ranked
where rn = 1
group by all;
```

**Expected:** Mar 14: 6. Mar 16: 5 (sale 1005 counted once as 4, plus 1).

**Why this way:** "latest row per key" is the most common SQL screen question. `row_number` handles ties and keeps the whole row. `max(loaded_at)` plus a join back works but needs a second pass and breaks on ties.

---

### 18. Returns and voids

**The idea:** a return is a **new event** (negative units on its own date). A void **cancels** an earlier sale as if it never happened. Different rules, different handling.

**Shape and grain:** transaction fact. Output: net units per day.

**The trap:** the natural query `txn_id not in (select ref_txn_id from d18_txns)` returns **nothing**, because `ref_txn_id` contains nulls, and `x not in (..., null)` is never true. Use `not exists`, which ignores nulls.

**Think it through:**
1. Keep sales and returns (returns already carry negative units).
2. Drop any sale that a void points to.
3. Sum by day. Void rows themselves carry no units, so leave them out.

```sql
select s.sold_on, sum(s.units) as net_units                 -- step 3
from d18_txns s
where s.txn_type in ('sale', 'return')                       -- step 1
  and not exists (                                           -- step 2: null-safe anti-join
    select 1 from d18_txns v
    where v.txn_type = 'void' and v.ref_txn_id = s.txn_id
  )
group by s.sold_on;
```

**Expected:** Mar 14: 5 (5 + 3, minus voided sale 2). Mar 15: 1 (2 − 1).

**Why this way:** `not exists` is null-safe and usually as fast as an anti-join. Make it your default; treat `not in` with a subquery as a bug waiting to happen.

---

### 19. A corrected file arrives

**The idea:** a load must be **idempotent**: running it twice gives the same result. When a corrected file arrives, replace that date's data instead of appending.

**Shape and grain:** daily transaction fact. One row per day and item.

**The trap:** a plain `insert` adds Mar 14 a second time, so Mar 14 shows 6 + 7 = 13. Running it again makes it worse.

**Think it through:**
1. Remove everything for the dates in the file.
2. Insert the file's rows.
3. Do both in one atomic step, so a failure never leaves the day half-loaded.

```sql
insert into d19_fct_sales_daily
replace where sale_date = date'2026-03-14'          -- steps 1-3 in one atomic statement
select sale_date, item_id, units
from d19_file_0314;
```

**Expected:** Mar 13 STRAW 4; Mar 14 STRAW 7, BLUE 2. The same after a second run.

**Why this way:** Delta's `replace where` deletes and inserts atomically. A separate `delete` then `insert` can fail in the middle and leave the day empty. `merge` on a key also works, but it won't delete rows that disappeared from the corrected file. In a pipeline, the date range comes from a parameter, which also makes backfills free.

---

### 20. Two feeds, one fact

**The idea:** to combine two event feeds, **aggregate each to the same grain first, then join**. Joining raw rows multiplies them.

**Shape and grain:** transaction fact. One row per store, item and day, with units sold and shrink units.

**The trap:** two.
- **Fan-out:** Mar 14 has 2 sales rows and 2 shrink rows. Joining them raw makes 4 rows: sales sum to 12 (not 6) and shrink to 6 (not 3).
- **Dropped days:** Mar 15 has only sales and Mar 16 only shrink. An inner join drops both.

**Think it through:**
1. Sum sales to store, item and day.
2. Sum shrink to the same grain.
3. **Full outer** join on the grain, so days in either feed survive.
4. `coalesce` the keys (they come from whichever side exists) and fill missing measures with 0. Missing events mean nothing happened.

```sql
with s as (                                                            -- step 1
  select sold_on as d, store_id, item_id, sum(units) as units_sold
  from d20_sales group by all
),
k as (                                                                 -- step 2
  select logged_on as d, store_id, item_id, sum(units) as shrink_units
  from d20_shrink group by all
)
select coalesce(s.d, k.d)               as calendar_date,              -- step 4: keys from either side
       coalesce(s.store_id, k.store_id) as store_id,
       coalesce(s.item_id, k.item_id)   as item_id,
       coalesce(s.units_sold, 0)        as units_sold,                 --   no sale means zero sold
       coalesce(k.shrink_units, 0)      as shrink_units
from s
full outer join k                                                      -- step 3
  on s.d = k.d and s.store_id = k.store_id and s.item_id = k.item_id;
```

**Expected:** Mar 14: 6 sold, 3 shrink. Mar 15: 3, 0. Mar 16: 0, 5.

**Why this way:** after step 1 and 2, each side has exactly one row per grain, so the join is one-to-one and can't multiply. An alternative is `union all` both feeds with zero-filled columns, then one `group by`. It's equally correct and scales nicely to three or more feeds.

---

### 21. The daily file

**The idea:** a row every day doesn't make something a snapshot. Ask: **can I add up a week of these rows and get a real number?**

**Shape and grain:** a transaction fact already rolled up to one row per item per day.

**The trap:** seeing a row per day and treating it like on-hand stock (averaging, or taking the last value). Units sold are events; a week's total of 20 is a real number.

**Think it through:**
1. Read one row aloud: "On Mar 9 we **sold** 3." Something happened, so it's events.
2. Events add up across days, so sum them.

```sql
select sum(units) as units_week
from d21_daily_item_sales
where sale_date between date'2026-03-09' and date'2026-03-15';   -- a plain range filter, fine
```

**Expected:** 20.

**Why this way:** the "sum test" is the fastest way to classify any table. If adding rows across time gives a real number, it's events. If it gives nonsense (like adding 7 nightly stock counts), it's a snapshot.

---

### 22. Counting customers

**The idea:** distinct counts are **non-additive**. You can't add daily customer counts to get a weekly count. You recount from the detail rows.

**Shape and grain:** transaction lines. Output 1: one row per day. Output 2: one number for the week.

**The trap:** C1 shopped on Mar 14 and Mar 15. Daily counts are 2 and 1; adding them says 3 customers this week. The truth is 2 (C1 and C2).

**Think it through:**
1. Daily: units are additive, so sum them; customers need `count(distinct)` per day.
2. Weekly: go back to the line-level rows and count distinct customers across the whole week. Don't reuse the daily counts.

```sql
-- step 1: daily
select sold_on,
       sum(units)                  as units,        -- additive
       count(distinct customer_id) as customers     -- non-additive
from d22_lines
group by sold_on;

-- step 2: weekly, recounted from the detail rows
select count(distinct customer_id) as customers_week
from d22_lines
where sold_on between date'2026-03-09' and date'2026-03-15';
```

**Expected:** Mar 14: 4 units, 2 customers. Mar 15: 3 units, 1 customer. Week: 2.

**Why this way:** it's the "daily vs weekly active users" interview question. In a semantic layer, define the measure as `count(distinct customer_id)` on the detail table, so it recounts correctly for any date range. For huge tables, `approx_count_distinct` is the fast alternative when an estimate is acceptable.

---

## D. Snapshots, processes, coverage

### 23. Average stock on hand

**The idea:** stock on hand is **semi-additive**: add it across items or stores on one day, but **average** it across days.

**Shape and grain:** periodic snapshot, one row per store, item and night.

**The trap:** two wrong answers.
- Sum all rows: 40 + 40 + 37 + 10 + 12 + 8 = 147. That adds the same stock three nights in a row.
- Average all rows: 24.5. That's the average per item, not the store's average stock.

**Think it through:**
1. Per day, add across items: the store's total stock that night (50, 52, 45).
2. Average those daily totals across days.

```sql
with per_day as (                                    -- step 1: add across items, one day at a time
  select count_date, sum(on_hand) as on_hand
  from d23_counts
  where store_id = 'A'
  group by count_date
)
select avg(on_hand) as avg_daily_on_hand            -- step 2: average across days
from per_day;
```

**Expected:** 49.

**Why this way:** two levels of aggregation, in the right order: sum within a day, average across days. Memorize "**events add, levels average, rates recompute.**"

---

### 24. A snapshot that skips zeros

**The idea:** a missing row can mean two different things. You have to know which, and the file log tells you.

**Shape and grain:** a sparse periodic snapshot. Output: one row per item per day.

**The trap:**
- The file lists only items with stock above zero. So on a day the file **arrived**, a missing item means **0**.
- On Mar 11 the file **didn't arrive**. Every item that day is **unknown** (null), not 0.

**Think it through:**
1. Build the full grid: every item × every day. You can't reason about missing rows without it.
2. Attach the file log, to know whether each day's file arrived.
3. Attach the counts.
4. If the file arrived, use the count or 0. If not, null.

```sql
with grid as (                                                         -- step 1
  select d.calendar_date, i.item_id
  from d01_dim_date d
  cross join (select * from values ('STRAW'), ('BLUE') as t(item_id)) i
  where d.calendar_date between date'2026-03-09' and date'2026-03-12'
)
select g.calendar_date, g.item_id,
       case when f.arrived then coalesce(c.on_hand, 0) end as on_hand   -- step 4: 0 or unknown
from grid g
left join d24_file_log f on f.file_date = g.calendar_date               -- step 2
left join d24_counts c   on c.count_date = g.calendar_date              -- step 3
                        and c.item_id    = g.item_id
order by g.item_id, g.calendar_date;
```

**Expected:** STRAW 5, 3, null, 0. BLUE 2, 0, null, 4.

**Why this way:** "grid, then left join the facts" is the standard way to find what's missing. Defaulting to 0 everywhere would report a full stockout on Mar 11 that never happened.

---

### 25. Stock from movements

**The idea:** if you know the opening stock and every movement (deliveries, sales, shrink), you can **calculate** stock for every day with a running total.

**Shape and grain:** transactions in, periodic snapshot out. One row per item per day.

**The trap:** two.
- Quiet days (Mar 10 and 12) have no movements, so they have no rows. They still need a stock value.
- Forgetting the opening balance (20) makes every day 20 too low.

**Think it through:**
1. Net the movements per day (Mar 9: +24 − 6 = +18).
2. Build a grid of every day, so quiet days exist.
3. Left join the daily net movements; quiet days get 0.
4. Stock = opening + running total of net movements up to that day.

```sql
with days as (                                                        -- step 2
  select calendar_date from d01_dim_date
  where calendar_date between date'2026-03-09' and date'2026-03-12'
),
moves as (                                                            -- step 1
  select item_id, event_date, sum(qty_change) as net
  from d25_events group by all
),
grid as (
  select o.item_id, o.on_hand as opening, d.calendar_date
  from d25_opening o cross join days d
)
select g.item_id, g.calendar_date,
       g.opening + sum(coalesce(m.net, 0)) over (                     -- step 3 + 4
         partition by g.item_id order by g.calendar_date
         rows between unbounded preceding and current row) as on_hand
from grid g
left join moves m on m.item_id = g.item_id and m.event_date = g.calendar_date;
```

**Expected:** Mar 9: 38. Mar 10: 38. Mar 11: 31. Mar 12: 31.

**Why this way:** a window running sum is one pass over the data. The alternative, joining each day to every earlier day and summing, grows with the square of the number of days. Spell out `rows between unbounded preceding and current row` so duplicates in the order column can't change the result.

---

### 26. Missing snapshot days

**The idea:** you can't find missing rows by looking at the rows you have. Build what *should* exist, then subtract what does.

**Shape and grain:** a coverage check. Output: one row per missing store-day.

**The trap:** querying the snapshot table for gaps. The gaps aren't in it.

**Think it through:**
1. Expected grid: every store × every day in the range.
2. Anti-join: keep grid rows with no matching snapshot.

```sql
with grid as (                                                          -- step 1
  select s.store_id, d.calendar_date
  from (select distinct store_id from d26_snapshots) s
  cross join d01_dim_date d
  where d.calendar_date between date'2026-03-01' and date'2026-03-07'
)
select g.store_id, g.calendar_date                                       -- step 2
from grid g
left join d26_snapshots x
  on x.store_id = g.store_id and x.snapshot_date = g.calendar_date
where x.store_id is null;
```

**Expected:** A Mar 3; B Mar 6; B Mar 7.

**Why this way:** "left join, then `is null`" and `not exists` are both standard anti-joins and run about the same. This query is also a ready-made data test: schedule it, and alert when it returns rows.

---

### 27. Purchase order lifecycle

**The idea:** a process with fixed steps (ordered, shipped, received) is best stored as **one row per process**, with a column per step. That's an accumulating snapshot.

**Shape and grain:** status events in. One row per PO out.

**The trap:** two.
- In-flight POs have no "received" timestamp. That null is information ("not yet"), so the PO must stay.
- P1's "shipped" event is duplicated. `min` takes one value either way, so duplicates can't hurt.

**Think it through:**
1. Pivot: per PO, take the timestamp of each step with `min(case when status = ... then status_at end)`.
2. Days to receive = received − ordered (null if not received).
3. Overdue = not received **and** more than 5 days since ordering, as of Mar 10.

```sql
with piv as (                                                           -- step 1: pivot
  select po_id,
         min(case when status = 'ordered'  then status_at end) as ordered_at,
         min(case when status = 'shipped'  then status_at end) as shipped_at,
         min(case when status = 'received' then status_at end) as received_at
  from d27_po_events
  group by po_id
)
select *,
       datediff(received_at, ordered_at) as days_to_receive,             -- step 2
       received_at is null
         and datediff(date'2026-03-10', ordered_at) > 5 as is_overdue    -- step 3
from piv;
```

**Expected:** P1: 5 days, not overdue. P2: null, overdue (8 days old). P3: null, not overdue (3 days old).

**Why this way:** conditional aggregation pivots in one pass and tolerates duplicate or missing steps. Durations between steps become simple subtraction, which is why this shape exists.

---

### 28. On promo, no sales

**The idea:** some facts record that something **was true**, with no measure at all: "STRAW was on promo at store A on Mar 2." That's a **factless** fact, and it's how you find things that *didn't* happen.

**Shape and grain:** a coverage fact, one row per store, item and promo day. Then an anti-join to sales.

**The trap:** looking in the sales table for days with no sales. Those days aren't there.

**Think it through:**
1. Expand each promo into one row per day it covered (end date inclusive here, so `between`).
2. Left join daily sales.
3. Keep promo days with no sales or zero sales.

```sql
with coverage as (                                                      -- step 1
  select d.calendar_date, p.store_id, p.item_id, p.promo_id
  from d28_promos p
  join d01_dim_date d on d.calendar_date between p.start_date and p.end_date   -- inclusive end
)
select c.*
from coverage c
left join d28_daily_sales s                                             -- step 2
  on  s.calendar_date = c.calendar_date
  and s.store_id      = c.store_id
  and s.item_id       = c.item_id
where coalesce(s.units, 0) = 0;                                          -- step 3
```

**Expected:** Mar 2 and Mar 4.

**Why this way:** expanding ranges to days turns "did it happen?" into a simple join. The same pattern answers "which stores were open but reported nothing" and "which customers were eligible but didn't buy."

---

### 29. Weekly counts, daily sales

**The idea:** before combining two tables, bring them to the **same grain**. Here: roll daily sales up to weeks, because counts only exist weekly.

**Shape and grain:** a weekly snapshot and a daily transaction fact. Output: one row per item per week.

**The trap:** joining daily sales straight to the weekly count repeats the count on every sales day, and any total built from it is inflated.

**Think it through:**
1. Map each sale date to its week (the date dimension already has `week_start`).
2. Sum sales per week and item.
3. Join to the weekly count; one row each side, so one-to-one.
4. Sell-through = units sold ÷ stock at the week's open.

```sql
with weekly_sales as (                                                 -- steps 1 + 2
  select d.week_start, s.item_id, sum(s.units) as units_sold
  from d29_daily_sales s
  join d01_dim_date d on d.calendar_date = s.sale_date
  group by all
)
select c.week_start, c.item_id, w.units_sold, c.on_hand_at_open,
       w.units_sold / nullif(c.on_hand_at_open, 0) as sell_through     -- step 4
from d29_weekly_counts c
left join weekly_sales w                                               -- step 3
  on w.week_start = c.week_start and w.item_id = c.item_id;
```

**Expected:** week of Mar 1: 16 / 40 = 0.40. Week of Mar 8: 20 / 35 = 0.571.

**Why this way:** always roll the finer table up to the coarser grain. The reverse, spreading a weekly count across days, invents data. The date dimension does the week mapping, so the week rule (Sunday start) lives in one place.

---

## E. Analysis and tests

### 30. Stockout streaks (gaps and islands)

**The idea:** find runs of consecutive days with the same condition. Each run is an "island". The trick is giving every island its own ID.

**Shape and grain:** a daily snapshot in. One row per stockout streak out.

**The trap:** `group by on_hand = 0` puts all 6 out-of-stock days in one group, as if it were one long streak. There are really three separate streaks.

**Think it through:**
1. For each day, flag whether it **starts a new run**: true when today's in-or-out status differs from yesterday's (`lag`).
2. Running-sum those flags. Every time a new run starts, the counter goes up by 1, so all days in the same run share the same number: the island ID.
3. Keep the out-of-stock days and group by island ID to get start, end and length.

Walk through it:

| Day | On hand | Out? | Starts new? | Island |
|---|---|---|---|---|
| Mar 1 | 5 | no | 0 | 0 |
| Mar 2 | 0 | yes | 1 | 1 |
| Mar 3 | 0 | yes | 0 | 1 |
| Mar 4 | 3 | no | 1 | 2 |
| Mar 5 | 0 | yes | 1 | 3 |

```sql
with flagged as (                                                   -- step 1
  select item_id, calendar_date,
         on_hand = 0 as is_out,
         case when (on_hand = 0) <> lag(on_hand = 0) over w then 1 else 0 end as starts_new
  from d30_on_hand
  window w as (partition by item_id order by calendar_date)
),
islands as (                                                        -- step 2: running count = island id
  select *, sum(starts_new) over (partition by item_id order by calendar_date) as island_id
  from flagged
)
select item_id,                                                     -- step 3
       min(calendar_date) as out_from,
       max(calendar_date) as out_to,
       count(*)           as days_out
from islands
where is_out
group by item_id, island_id
order by out_from;
```

**Expected:** Mar 2 to 3 (2 days), Mar 5 to 7 (3 days), Mar 9 (1 day).

**Why this way:** two window passes, no self-joins, and it works for any "streak" question (logins in a row, days over budget). A known alternative when days are consecutive: `calendar_date - row_number()` is constant within a run. It's shorter but only works when every day has a row, so the flag method is safer.

---

### 31. Same period last year

**The idea:** compare a period with the same period a year earlier, and report the change correctly: in **points** and in **percent**, which are different things.

**Shape and grain:** an aggregate at store × fiscal period. One output row.

**The trap:** mixing up the two changes. Shrink went from 7.2% to 5.8%.
- Change in **points**: 5.8 − 7.2 = **−1.4 points**.
- Change in **percent**: 5.8 ÷ 7.2 − 1 = **−19.4%**.

Saying "shrink fell 1.4%" is wrong; it fell 1.4 points, which is 19.4%.

**Think it through:**
1. Use a running period number (`fiscal_period_seq`) so "last year" is simple arithmetic: 13 periods per year, so last year = seq − 13.
2. Self-join the table to itself on store and seq − 13.
3. Compute both rates with sum-then-divide, then both kinds of change.

```sql
select cur.store_id, cur.fiscal_period_seq,
       round(cur.shrink_amt / nullif(cur.sales_amt, 0) * 100, 2) as rate_pct,       -- this year
       round(ly.shrink_amt  / nullif(ly.sales_amt, 0)  * 100, 2) as rate_ly_pct,    -- last year
       round((cur.shrink_amt / nullif(cur.sales_amt, 0)
            - ly.shrink_amt  / nullif(ly.sales_amt, 0)) * 100, 2)  as change_pts,   -- difference
       round((  (cur.shrink_amt / nullif(cur.sales_amt, 0))
              / nullif(ly.shrink_amt / nullif(ly.sales_amt, 0), 0) - 1) * 100, 1)
                                                                  as change_pct     -- ratio
from d31_agg cur
left join d31_agg ly                                                   -- steps 1 + 2
  on  ly.store_id          = cur.store_id
  and ly.fiscal_period_seq = cur.fiscal_period_seq - 13
where cur.fiscal_period_seq = 14;
```

**Expected:** 5.8%, 7.2%, −1.4 points, −19.4%.

**Why this way:** a sequence number makes "same period last year" a one-line join, even across 53-week years when the calendar table assigns the sequence. `lag(..., 13)` also works, but only if no period is ever missing.

---

### 32. Write the tests

**The idea:** a data test is a query that returns **rows when something is wrong** and **zero rows when it's right**. That makes it easy to automate.

**Shape and grain:** three checks on three tables.

**The trap:** writing queries that just show the data (like `select count(*)`), which someone has to read and judge. A test must decide on its own.

**Think it through:**
1. **Grain:** group by the grain columns; any group with more than one row is a duplicate.
2. **SCD2 overlap:** two versions of the same item overlap if each starts before the other ends: `a.from < b.to and b.from < a.to`. Use `a.key < b.key` so each pair is checked once and a row isn't compared with itself.
3. **Reconciliation:** the fact's total must equal the source's total. Return a row only when they differ.

```sql
-- step 1: grain is one row per day, store, item
select calendar_date, store_id, item_id, count(*) as n
from d32_fct
group by all
having count(*) > 1;

-- step 2: no two versions of an item overlap
select a.item_id, a.item_key, b.item_key
from d32_dim_item a
join d32_dim_item b
  on  a.item_id   = b.item_id
  and a.item_key  < b.item_key                       -- each pair once
  and a.valid_from < b.valid_to
  and b.valid_from < a.valid_to;                     -- the overlap condition

-- step 3: fact total equals source total
select s.total as source_units, f.total as fact_units
from (select sum(units) as total from d32_source_sales) s
cross join (select sum(units) as total from d32_fct) f
where s.total <> f.total;
```

**Expected:** each returns 1 row on this data: a duplicate grain row; an overlap from Mar 1 to Mar 10; 6 vs 12 units.

**Why this way:** "zero rows means pass" is exactly how dbt tests work, so these move into dbt unchanged later. Memorize the overlap condition; it's a common interview question on its own.

---

## F. Combos (interview style)

For each combo, name the drills it combines **before** writing SQL. That's what an interviewer wants to hear: you recognize the parts.

### 33. The Afresh problem

**The idea:** the whole pipeline end to end: a capacity change log and a sales feed become one daily fact, then a semi-additive metric on top.

**Shape and grain:** capacity change log → SCD2 → daily; sales events → deduped → daily. Output fact: one row per store, item and day. Metric: days of cover per store.

**Recipe:** drill 11 (capacity SCD2) + drill 8 (daily) + drill 17 (dedupe sales) + drill 20 (full outer join) + drill 23 (semi-additive average).

**The trap:** five.
- Sale 1005 was reloaded (3, then 4): keep 4.
- Sale 1006 is a return (−1): keep it; it nets out.
- Store B sold 2 units on Mar 15, before its capacity starts on Mar 16. Capacity that day is **unknown (null)**, not 0.
- Capacity is semi-additive: add across items per day, average across days.
- Compare only days where capacity is known, or the ratio mixes days with and without capacity.

**Think it through:**
1. Capacity SCD2 with the business rules (drill 11).
2. Expand to daily rows with the sandwich (drill 8).
3. Dedupe sales, then sum per store, item and day (drill 17).
4. Full outer join on the grain. Days with no sales count as zero sold; days with no capacity stay null.
5. Metric: per store and day, sum capacity and units across items; then average each across days and divide.

```sql
create or replace table c33_fct_store_item_daily as
with effective as (                                                     -- step 1: drill 11
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
cap_daily as (                                                          -- step 2: drill 8
  select d.calendar_date, c.store_id, c.item_id, c.capacity
  from cap_scd2 c
  join d01_dim_date d on c.valid_from <= d.calendar_date and d.calendar_date < c.valid_to
  where d.calendar_date <= date'2026-03-16'                             -- stop at the last day of data
),
sales_ranked as (                                                       -- step 3: drill 17
  select *, row_number() over (partition by sale_id order by loaded_at desc) as rn
  from c33_sales
),
sales_daily as (
  select cast(sold_at as date) as calendar_date, store_id, item_id, sum(units) as units_sold
  from sales_ranked where rn = 1
  group by all
)
select coalesce(s.calendar_date, c.calendar_date) as calendar_date,      -- step 4: drill 20
       coalesce(s.store_id, c.store_id)           as store_id,
       coalesce(s.item_id, c.item_id)             as item_id,
       coalesce(s.units_sold, 0)                  as units_sold,         -- no sale means zero sold
       c.capacity                                 as capacity_units      -- no capacity means unknown, so null
from sales_daily s
full outer join cap_daily c
  on s.calendar_date = c.calendar_date and s.store_id = c.store_id and s.item_id = c.item_id;

-- step 5: days of cover, Mar 14 to 16, only days with known capacity
with per_day as (
  select calendar_date, store_id,
         sum(capacity_units) as capacity,          -- add across items within a day
         sum(units_sold)     as units_sold
  from c33_fct_store_item_daily
  where calendar_date between date'2026-03-14' and date'2026-03-16'
    and capacity_units is not null
  group by all
)
select store_id,
       avg(capacity) / nullif(avg(units_sold), 0) as days_of_cover   -- average across days, divide last
from per_day
group by store_id;
```

**Expected fact rows (Mar 14 to 16):** A: 6 sold / 50 capacity, 0 / 80, 8 / 80. B: 2 / null (Mar 15), 4 / 60 (Mar 16).
**Expected days of cover:** A 15.0 (70 ÷ 4.67). B 15.0 (60 ÷ 4).

**Why this way:** each CTE does one job you can name, which is how you'd split it into models later (staging, SCD2, daily, fact). In an interview, draw the four boxes first, then write the SQL box by box.

---

### 34. Shrink by category: as-was vs as-is

**The idea:** when an item changes category, a report can use the category **at the time** (as-was) or **today's** category (as-is). Both are valid; they answer different questions.

**Shape and grain:** a category change log (SCD2) and a shrink fact. Output: shrink by category, two ways.

**Recipe:** drill 7 (SCD2) + drill 16 (as-was lookup). As-is = join to the current version only.

**The trap:** the Mar 5 STRAW shrink (10) happened while STRAW was "Berries". As-was puts it under Berries; as-is moves it to "Fresh Berries". Using the wrong one makes the Berries manager responsible for shrink that isn't theirs, or the reverse.

**Think it through:**
1. Build category SCD2 with `lead`.
2. **As-was:** join shrink to the version covering the shrink date (sandwich).
3. **As-is:** join shrink to the current version (`valid_to = 9999-12-31`).
4. `union all` the two results with a label.

```sql
with cat as (                                                              -- step 1
  select item_id, category, effective_date as valid_from,
         coalesce(lead(effective_date) over (partition by item_id order by effective_date),
                  date'9999-12-31') as valid_to
  from c34_category_changes
)
select 'as_was' as view, c.category, sum(s.shrink_amt) as shrink_amt       -- step 2
from c34_shrink s
join cat c
  on  c.item_id = s.item_id
  and c.valid_from <= s.shrink_date and s.shrink_date < c.valid_to
group by all
union all
select 'as_is', c.category, sum(s.shrink_amt)                              -- step 3
from c34_shrink s
join cat c
  on  c.item_id  = s.item_id
  and c.valid_to = date'9999-12-31'
group by all;
```

**Expected:** as-was: Berries 14, Fresh Berries 6. As-is: Fresh Berries 16, Berries 4.

**Why this way:** default to as-was for accountability ("who owned it then"), and as-is for trends under today's structure. Say which one you're using; an interviewer wants to hear you ask.

---

### 35. Revenue at the right price

**The idea:** a messy price log (same-day changes and repeats) becomes clean SCD2, which then prices every sale correctly.

**Shape and grain:** price change log → SCD2; sales → priced. Output: revenue per month.

**Recipe:** drill 9 (same-day) + drill 10 (collapse) + drill 7 (close) + drill 16 (lookup).

**The trap:** four.
- Feb 15 has two changes (4.49, then 4.29): 4.29 wins.
- Mar 1 repeats 4.29: drop it.
- The Dec 31, 2025 sale has no price: count it, don't drop it.
- The Mar 12 return (−1) reduces revenue: keep it.

**Think it through:**
1. **Clean:** latest change per item per day.
2. **Collapse:** drop repeats.
3. **Close:** `lead`.
4. **Lookup:** left join sales to the version covering the sale date.
5. Sum revenue by month and count unpriced units.

```sql
with ranked as (                                                         -- step 1
  select item_id, price, cast(change_ts as date) as eff,
         row_number() over (partition by item_id, cast(change_ts as date)
                            order by change_ts desc) as rn
  from c35_price_changes
),
latest as (select * from ranked where rn = 1),
compared as (                                                            -- step 2
  select *, lag(price) over (partition by item_id order by eff) as prev_price
  from latest
),
changed as (select * from compared where prev_price is null or price <> prev_price),
price_scd2 as (                                                          -- step 3
  select item_id, price, eff as valid_from,
         coalesce(lead(eff) over (partition by item_id order by eff), date'9999-12-31') as valid_to
  from changed
)
select date_trunc('month', s.sold_on)                               as month,   -- step 5
       sum(s.units * p.price)                                       as revenue,
       sum(case when p.price is null then s.units else 0 end)       as unpriced_units
from c35_sales s
left join price_scd2 p                                                   -- step 4
  on  p.item_id = s.item_id
  and p.valid_from <= s.sold_on and s.sold_on < p.valid_to
group by all
order by month;
```

**Expected:** Dec 2025: revenue null, 1 unpriced unit. Feb: 20.55 (3 × 3.99 + 2 × 4.29). Mar: 15.66 (1 × 4.29 + 4 × 3.79 − 1 × 3.79).

**Why this way:** the same four-step recipe as every change-log drill, then the standard lookup. Reporting unpriced units next to revenue keeps a data gap from silently shrinking revenue.

---

### 36. Counted vs computed stock

**The idea:** compare stock you **calculated** from movements with stock someone **counted**. The difference (drift) is unexplained loss: theft, damage or bad data.

**Shape and grain:** movements → computed daily stock; counts → counted daily stock. Output: one row per item per day.

**Recipe:** drill 25 (running total) + a join to counts + `lag` for the daily change in drift.

**The trap:** drift is **cumulative**. Day 3's drift of −3 includes day 2's −1. The loss that happened *on* day 3 is only −2. Reporting −3 for day 3 double-counts.

**Think it through:**
1. Computed stock: opening + running total of net movements (drill 25).
2. Join the counts on the same day.
3. Drift = counted − computed.
4. Unexplained today = today's drift − yesterday's drift.

```sql
with days as (
  select calendar_date from d01_dim_date
  where calendar_date between date'2026-03-09' and date'2026-03-11'
),
moves as (select item_id, event_date, sum(qty_change) as net from c36_events group by all),
computed as (                                                            -- step 1
  select o.item_id, d.calendar_date,
         o.on_hand + sum(coalesce(m.net, 0)) over (
           partition by o.item_id order by d.calendar_date
           rows between unbounded preceding and current row) as computed
  from c36_opening o
  cross join days d
  left join moves m on m.item_id = o.item_id and m.event_date = d.calendar_date
),
compared as (                                                            -- steps 2 + 3
  select c.item_id, c.calendar_date, c.computed, k.counted,
         k.counted - c.computed as drift
  from computed c
  join c36_counts k on k.item_id = c.item_id and k.count_date = c.calendar_date
)
select *,
       drift - coalesce(lag(drift) over (partition by item_id order by calendar_date), 0)
         as unexplained_today                                            -- step 4
from compared
order by calendar_date;
```

**Expected:** computed 38, 34, 29. Counted 38, 33, 26. Drift 0, −1, −3. Unexplained today 0, −1, −2.

**Why this way:** cumulative vs daily change is the same idea as on-hand vs movements. `lag` turns any running number back into a daily change.

---

### 37. Promo lift with overlapping promos

**The idea:** compare average daily sales on promo days with non-promo days. Count each **day** once, even if two promos cover it, and include days with zero sales.

**Shape and grain:** promos (date ranges) and sales. Output: one row per item per on-promo flag.

**The trap:** two.
- Mar 4 and 5 sit in both P1 and P2. Joining sales to promos counts those days twice.
- Mar 2, 5, 7 and 8 had no sales. Leave them out and every average is too high.

**Think it through:**
1. Build every day in the window (the grid).
2. Flag each day: on promo if **any** promo covers it (`exists`, so overlaps count once).
3. Left join sales; days with no sales get 0.
4. Average daily units by flag.

```sql
with days as (                                                           -- step 1
  select d.calendar_date, i.item_id
  from d01_dim_date d
  cross join (select distinct item_id from c37_promos) i
  where d.calendar_date between date'2026-03-01' and date'2026-03-10'
),
flagged as (                                                             -- step 2
  select d.calendar_date, d.item_id,
         exists (select 1 from c37_promos p
                 where p.item_id = d.item_id
                   and d.calendar_date between p.start_date and p.end_date) as on_promo  -- inclusive end
  from days d
),
daily as (                                                               -- step 3
  select f.calendar_date, f.item_id, f.on_promo, coalesce(sum(s.units), 0) as units
  from flagged f
  left join c37_sales s on s.item_id = f.item_id and s.sale_date = f.calendar_date
  group by all
)
select item_id, on_promo,                                                -- step 4
       count(*)   as days,
       sum(units) as units,
       avg(units) as avg_daily_units
from daily
group by all;
```

**Expected:** on promo: 8 days, 14 units, 1.75 per day. Not on promo: 2 days, 3 units, 1.5 per day.

**Why this way:** grid first, then a yes/no flag per day. It combines drill 6 (count once with `exists`) and drill 24 (a grid so missing days count).

---

### 38. On-time delivery by supplier tier

**The idea:** judge each PO by the supplier's tier **when it was ordered**, not today's tier.

**Shape and grain:** PO events → accumulating snapshot; tier changes → SCD2. Output: on-time rate per tier.

**Recipe:** drill 27 (pivot POs) + drill 7 (tier SCD2) + drill 16 (as-was lookup at the order date).

**The trap:** two.
- S1 became "Preferred" on Mar 5. P1 (ordered Mar 1) was a Standard order. Using today's tier puts all POs under Preferred.
- P4 hasn't been received. Leave it out of the rate; it isn't late or on time yet.

**Think it through:**
1. Pivot events to one row per PO with ordered and received timestamps.
2. Build tier SCD2.
3. Join each PO to the tier covering its **order date**.
4. Keep received POs; on time = received within 3 days. The average of a 1/0 flag is the rate.

```sql
with po as (                                                             -- step 1
  select po_id, supplier_id,
         min(case when status = 'ordered'  then status_at end) as ordered_at,
         min(case when status = 'received' then status_at end) as received_at
  from c38_po_events
  group by po_id, supplier_id
),
tier as (                                                                -- step 2
  select supplier_id, tier, effective_date as valid_from,
         coalesce(lead(effective_date) over (partition by supplier_id order by effective_date),
                  date'9999-12-31') as valid_to
  from c38_tier_changes
)
select t.tier,
       count(*) as received_pos,
       avg(case when datediff(p.received_at, p.ordered_at) <= 3 then 1.0 else 0.0 end)
         as on_time_rate                                                 -- step 4
from po p
join tier t                                                              -- step 3: tier at order time
  on  t.supplier_id = p.supplier_id
  and t.valid_from <= cast(p.ordered_at as date)
  and cast(p.ordered_at as date) < t.valid_to
where p.received_at is not null
group by t.tier;
```

**Expected:** Standard: 1 PO, 100%. Preferred: 2 POs, 50%.

**Why this way:** "average of a 1/0 flag" gives a rate in one line and is easy to read. The as-was join makes the tier change visible instead of hiding it.

---

### 39. Before vs after go-live

**The idea:** measure a change around an event date that's **different for each store**, and only compare stores with a full window on both sides.

**Shape and grain:** weekly aggregate per store, plus go-live dates. Output: one row per store.

**The trap:** three.
- A fixed calendar window (say, March) is wrong because each store went live on a different date. Measure weeks **relative** to each store's go-live.
- Store B has only one week after go-live, so it lacks a full window. Including it biases the result; exclude it.
- Averaging weekly rates gives the wrong answer; sum shrink and sales first, then divide.

**Think it through:**
1. Week offset = (week start − go-live) ÷ 7. Before = −2, −1; after = 0, 1.
2. Keep weeks with offset −2 to 1.
3. Keep only stores with all 4 weeks.
4. Rate before = sum of shrink ÷ sum of sales over the two before weeks; same for after. Change in points = after − before.

```sql
with tagged as (                                                         -- step 1
  select w.*, datediff(w.week_start, s.go_live_date) / 7 as week_offset
  from c39_weekly w
  join c39_stores s on s.store_id = w.store_id
),
windowed as (select * from tagged where week_offset between -2 and 1),  -- step 2
complete as (                                                            -- step 3
  select store_id from windowed group by store_id having count(*) = 4
)
select w.store_id,                                                       -- step 4
       sum(case when week_offset < 0  then shrink_amt end)
         / nullif(sum(case when week_offset < 0  then sales_amt end), 0) * 100 as rate_before_pct,
       sum(case when week_offset >= 0 then shrink_amt end)
         / nullif(sum(case when week_offset >= 0 then sales_amt end), 0) * 100 as rate_after_pct,
       (  sum(case when week_offset >= 0 then shrink_amt end)
            / nullif(sum(case when week_offset >= 0 then sales_amt end), 0)
        - sum(case when week_offset < 0  then shrink_amt end)
            / nullif(sum(case when week_offset < 0  then sales_amt end), 0)) * 100 as change_pts
from windowed w
join complete c on c.store_id = w.store_id
group by w.store_id;
```

**Expected:** A: 7.0% before, 4.5% after, −2.5 points. B excluded.

**Why this way:** it's how customer success would prove "shrink dropped after Afresh went live." Relative windows and complete-window filtering are what make the comparison fair.

---

### 40. Full mock: answer outline

**The idea:** put it all together and **talk while you build**. The interviewer grades the order of your thinking as much as the SQL.

**Step 1: ask questions first.**
- Who uses days of cover, and what do they decide with it?
- Is capacity per store and SKU?
- What's a "complete" day (do we wait for late files)?
- Which calendar: fiscal or calendar weeks?
- Do returns count against sales?

**Step 2: read each source aloud and name its shape.**

| Source | One row means | Shape | Drill |
|---|---|---|---|
| `pos_lines` | "this line sold" (can be reloaded) | transaction, dedupe on `line_id` | 17 |
| `sku_master_daily` | "this is the SKU list tonight" | full dump, compress to SCD2 | 4 |
| `planogram_changes` | "capacity is now X, from this date" (sometimes backdated) | change log to SCD2 | 11, 12 |

**Step 3: the model.**
- `dim_sku` (SCD2, from the nightly dump), `dim_store`, `dim_date`
- `int_capacity_scd2` → `int_capacity_daily` (sandwich join)
- `fct_store_sku_daily`: grain store × SKU × day. `units_sold` from deduped lines (zero when there were no sales), `capacity_units` from daily capacity (null when unknown). Full outer join.

**Step 4: the metric.** For each category and day, sum capacity and units across stores and SKUs, with category as-was (sandwich join to `dim_sku` on the day). Then average each over the last 7 complete days and divide. Use only days with known capacity.

**Step 5: edge cases, said out loud.** Corrected lines; returns; backdated resets; two resets in a day; a SKU moving category mid-week; a missing nightly dump (keep yesterday's versions, flag it); sales before capacity exists.

**Step 6: tests.** Grain uniqueness on the fact; no overlapping versions in both SCD2 tables; fact units equal deduped source units.

**Why this way:** questions, shapes, model, metric, edge cases, tests: that order shows judgment before syntax, which is exactly what a solo-owner modeling role screens for.
