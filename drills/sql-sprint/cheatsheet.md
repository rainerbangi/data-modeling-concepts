# PostgreSQL Cheatsheet

**5 traps:** `5 / 2` = **2** (use `5::numeric / 2`) · `order by x desc` puts **nulls first** (add `nulls last`) · no `qualify` (CTE + `where rn = 1`) · dates use `+` and `-`, not functions · `round(x, 2)` needs `numeric` (`round(x::numeric, 2)`)

## Order of execution
`from` / `join` → `where` → `group by` → `having` → window functions → `select` → `distinct` → `order by` → `limit`

## Joins
| Task | Postgres |
|---|---|
| Keep rows with a match | `where exists (select 1 from b where b.id = a.id)` |
| Keep rows with no match | `where not exists (select 1 from b where b.id = a.id)` (never `not in` with a subquery) |
| Filter the right table of a left join | Put it in `on`, not `where` |
| Combine two feeds | `full outer join ... using (user_id)`, then `coalesce` each measure |
| Range join | `on x >= lo and x < hi` |
| Self-join | `from users u left join users r on r.user_id = u.referred_by` |
| Stack rows | `union all` (keeps all) · `union` (removes duplicates) |

## Aggregation
| Task | Postgres |
|---|---|
| Conditional count | `count(*) filter (where status = 'failed')` |
| Conditional sum | `sum(amount) filter (where status = 'posted')` |
| Safe percentage | `round(100.0 * a / nullif(b, 0), 1)` |
| Filter groups | `having count(*) >= 2` |
| List of values | `string_agg(x, ', ' order by x)` · `array_agg(distinct x)` |
| Median | `percentile_cont(0.5) within group (order by x)` |
| Larger / smaller of two | `greatest(a, b)` · `least(a, b)` |

## Window functions
| Task | Postgres |
|---|---|
| Number rows per key | `row_number() over (partition by k order by ts desc, id)` |
| Ties: 1,2,3 · 1,1,3 · 1,1,2 | `row_number()` · `rank()` · `dense_rank()` |
| Top N with ties | `order by spend desc fetch first 3 rows with ties` |
| Previous / next value | `lag(x) over (partition by k order by ts)` · `lead(x)` |
| Running total | `sum(x) over (partition by k order by ts, id rows between unbounded preceding and current row)` |
| Moving average | `avg(x) over (order by d rows between 6 preceding and current row)` (fill missing days first) |
| Default frame | with `order by`: `range ... current row`, so **ties are summed together**. Write `rows` |

## Dates
| Task | Postgres |
|---|---|
| Add days | `d + 7` (date) · `ts + interval '7 days'` · `d + interval '1 month'` |
| Days between | `end_d - start_d` · timestamps: `end_ts::date - start_ts::date` |
| Seconds between | `extract(epoch from ts2 - ts1)` |
| First of month | `date_trunc('month', ts)::date` |
| Format | `to_char(ts, 'YYYY-MM')` |
| Parts | `extract(year from d)` · `extract(dow from d)` (Sun = 0) · `extract(isodow from d)` (Mon = 1) |
| A month, safely | `ts >= '2026-03-01' and ts < '2026-04-01'` (never `between`) |
| Every day in a range | `generate_series(date '2026-03-01', date '2026-03-07', interval '1 day')::date` |

## Strings, nulls, casting
| Task | Postgres |
|---|---|
| Text pieces | `split_part(s, ',', 1)` · `strpos(s, 'x')` · `substring(s, 1, 3)` · `s1 \|\| s2` |
| Pattern match | `like` · `ilike` (any case) · `s ~ '^A'` (regex) |
| Default for null | `coalesce(x, 0)` |
| Null-safe equals | `a is not distinct from b` |
| Cast | `x::text` · `x::int` · `x::numeric` · `x::date` |
| If / else | `case when x > 0 then 'in' else 'out' end` |

## Error → fix
| Error says | Fix |
|---|---|
| …must appear in the GROUP BY… | group by it, or aggregate it |
| window functions not allowed in WHERE | compute in a CTE, filter outside |
| division by zero | `nullif(denominator, 0)` |
| round(double precision, integer)… | `round(x::numeric, 2)` |
| column "id" is ambiguous | prefix with the table alias |
| operator… integer = text | cast one side: `x::int` |

## Performance
| Task | Postgres |
|---|---|
| See the plan with real times | `explain analyze select ...` |
| Read a plan | innermost line runs first · expected vs actual `rows=` 10× apart: `analyze` · red flags: many `Rows Removed`, `Disk:`, huge `loops` |
| Index for a filter + date range | `create index on t (user_id, created_at)` (equality column first) |
| Index can't be used when | a function wraps the column, `like '%x'`, or most rows match |
| Upsert | `insert ... on conflict (id) do update set amount = excluded.amount` |

<!-- page 2 -->

# Interview patterns

**Say before you type:** "One row per ___." · "Are nulls, ties and duplicates possible?" · "Is the end date included?" · **Check after:** row count = keys · total = source total · one edge case by hand

**Table used below:** `t (id, user_id, ts timestamp, amount numeric, status text)`. Swap in the real names.

## 1. Latest row per user
```sql
with ranked as (
  select *, row_number() over (
           partition by user_id
           order by ts desc, id desc) as rn
  from t
)
select * from ranked where rn = 1;

-- Postgres only
select distinct on (user_id) *
from t
order by user_id, ts desc, id desc;
```

## 2. Running total
```sql
select id, user_id, ts, amount,
       sum(amount) over (
         partition by user_id order by ts, id
         rows between unbounded preceding
                  and current row) as running
from t;
```

## 3. Aggregate before joining (no fan-out)
```sql
with a as (select user_id, sum(amount) as spend
           from t group by user_id),
     b as (select user_id, sum(amount) as refunded
           from refunds group by user_id)
select coalesce(a.user_id, b.user_id) as user_id,
       coalesce(a.spend, 0)    as spend,
       coalesce(b.refunded, 0) as refunded
from a
full outer join b on b.user_id = a.user_id;
```

## 4. Fill missing days
```sql
select d::date as day,
       coalesce(sum(t.amount), 0) as total
from generate_series(date '2026-03-01',
                     date '2026-03-31',
                     interval '1 day') as d
left join t on t.ts >= d
           and t.ts <  d + interval '1 day'
group by d
order by d;
```

## 5. Month over month (with a month spine)
```sql
with months as (
  select generate_series(date '2026-01-01',
           date '2026-04-01',
           interval '1 month')::date as m
), mau as (
  select date_trunc('month', ts)::date as m,
         count(distinct user_id) as users
  from t group by 1
), filled as (
  select months.m, coalesce(mau.users, 0) as users
  from months left join mau using (m)
), prev as (
  select *, lag(users) over (order by m) as prev
  from filled
)
select m, users, prev,
       round(100.0 * (users - prev)
             / nullif(prev, 0), 1) as pct_change
from prev
order by m;
```

## 6. In this month, not last month
```sql
select distinct c.user_id
from t c
where c.ts >= '2026-04-01' and c.ts < '2026-05-01'
  and not exists (
    select 1 from t p
    where p.user_id = c.user_id
      and p.ts >= '2026-03-01'
      and p.ts <  '2026-04-01');
```

## 7. Repeat within 60 seconds
```sql
with x as (
  select *, lag(ts) over (
              partition by user_id, amount
              order by ts) as prev_ts
  from t
)
select id, extract(epoch from ts - prev_ts) as secs
from x
where ts - prev_ts <= interval '60 seconds';
```

## 8. Top 3 per group, ties kept
```sql
with s as (
  select status, user_id, sum(amount) as total
  from t group by status, user_id
), r as (
  select *, rank() over (partition by status
                         order by total desc) as rnk
  from s
)
select * from r where rnk <= 3;
```

## 9. Rate and share of total
```sql
select user_id,
       round(100.0 * count(*) filter (
               where status = 'success')
             / nullif(count(*), 0), 1) as success_pct,
       round(100.0 * sum(amount)
             / sum(sum(amount)) over (), 1) as pct_of_all
from t
group by user_id;
```

## 10. Consecutive-day streaks
```sql
with days as (
  select distinct user_id, ts::date as d from t
), g as (
  select *, d - (row_number() over (
                   partition by user_id
                   order by d))::int as grp
  from days
)
select user_id, min(d) as start_day,
       max(d) as end_day, count(*) as streak
from g
group by user_id, grp;
```
Consecutive days minus 1, 2, 3 land on the same date, so each streak shares one `grp`.
