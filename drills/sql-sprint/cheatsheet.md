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
| Range join | `on x >= lo and x < hi` |
| Self-join | `from users u left join users r on r.user_id = u.referred_by` |

## Aggregation
| Task | Postgres |
|---|---|
| Conditional count | `count(*) filter (where status = 'failed')` |
| Conditional sum | `sum(amount) filter (where status = 'posted')` |
| Safe percentage | `round(100.0 * a / nullif(b, 0), 1)` |
| Filter groups | `having count(*) >= 2` |
| List / text of values | `array_agg(distinct x)` · `string_agg(x, ', ' order by x)` |
| Median | `percentile_cont(0.5) within group (order by x)` |

## Window functions
| Task | Postgres |
|---|---|
| Latest row per key | `with r as (select *, row_number() over (partition by k order by ts desc) as rn from t) select * from r where rn = 1` |
| Same, shorter | `select distinct on (k) * from t order by k, ts desc` |
| Ties: 1,2,3 · 1,1,3 · 1,1,2 | `row_number()` · `rank()` · `dense_rank()` |
| Top N with ties | `order by spend desc fetch first 3 rows with ties` |
| Previous / next value | `lag(x) over (partition by k order by ts)` · `lead(x)` |
| Running total | `sum(x) over (partition by k order by ts, id rows between unbounded preceding and current row)` |
| 7-day moving average | `avg(x) over (order by d rows between 6 preceding and current row)` (fill missing days first) |
| Share of total | `100.0 * x / sum(x) over (partition by k)` |

## Dates
| Task | Postgres |
|---|---|
| Add days | `d + 7` (date) · `ts + interval '7 days'` (timestamp) |
| Days between | `end_d - start_d` · timestamps: `end_ts::date - start_ts::date` |
| Seconds between | `extract(epoch from ts2 - ts1)` |
| First of month | `date_trunc('month', ts)::date` |
| Format | `to_char(ts, 'YYYY-MM')` |
| Parts | `extract(year from d)` · `extract(dow from d)` (Sun = 0) · `extract(isodow from d)` (Mon = 1) |
| A month, safely | `ts >= '2026-03-01' and ts < '2026-04-01'` (never `between`) |
| Every day in a range | `generate_series(date '2026-03-01', date '2026-03-07', interval '1 day')::date` |
| Today / now | `current_date` · `now()` |

## Strings, nulls, casting
| Task | Postgres |
|---|---|
| Text pieces | `split_part(s, ',', 1)` · `strpos(s, 'x')` · `substring(s, 1, 3)` · `s1 \|\| s2` |
| Pattern match | `like` · `ilike` (any case) · `s ~ '^A'` (regex) |
| Default for null | `coalesce(x, 0)` |
| Null-safe equals | `a is not distinct from b` |
| Cast | `x::text` · `x::int` · `x::numeric` · `x::date` |
| If / else | `case when x > 0 then 'in' else 'out' end` |

## Table setup
```sql
drop table if exists t;
create table t (
  id int primary key,
  user_id int references users (user_id),
  created_at timestamp,
  amount numeric(10,2),
  status text
);
insert into t values
  (1, 1, '2026-03-01 10:00', -50.00, 'posted'),
  (2, 1, '2026-03-02 09:00',  20.00, 'posted');
```
Inline rows: `select * from (values (1, 'a'), (2, 'b')) as v(id, name)`

## Performance
| Task | Postgres |
|---|---|
| See the plan with real times | `explain analyze select ...` |
| Index for a filter + date range | `create index on t (user_id, created_at)` (equality column first) |
| Index can't be used when | a function wraps the column, `like '%x'`, or most rows match |
| Upsert | `insert ... on conflict (id) do update set amount = excluded.amount` |
| Set difference | `select ... except select ...` |
