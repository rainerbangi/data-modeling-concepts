# Databricks to Postgres Cheatsheet

Left: what you'd write in Databricks. Right: what to type in Postgres. **Same** means your habit works as is.

**The 5 that will bite you:** `5 / 2` is **2** · nulls sort **first** in `desc` · no `qualify` · no `date_add` / `datediff` · `round(x, 2)` needs `numeric`.

## 1. Query skeleton

| Databricks | Postgres |
|---|---|
| `with ... select ... from ... where ... group by ... having ... order by ... limit` | **Same** |
| Run order: from/join > where > group by > having > window > select > distinct > order by > limit | **Same** |
| `group by all` | Not available. List columns: `group by 1, 2` |
| `` `my col` `` (backticks) | `"my col"` (double quotes). Unquoted names become lowercase |
| `'text'` for strings | **Same** (never double quotes for strings) |
| `limit 3` | **Same**. With ties: `order by spend desc fetch first 3 rows with ties` |

## 2. Joins

| Databricks | Postgres |
|---|---|
| `join`, `left join`, `full outer join`, `cross join`, `using (id)` | **Same** |
| `left semi join b on ...` | `where exists (select 1 from b where ...)` |
| `left anti join b on ...` | `where not exists (select 1 from b where ...)` |
| Range join: `on x >= lo and x < hi` | **Same** |
| `explode` per row | `cross join lateral unnest(arr) as u(x)` |

## 3. Aggregations

| Databricks | Postgres |
|---|---|
| `count_if(status = 'failed')` | `count(*) filter (where status = 'failed')` |
| `sum(case when ... then x else 0 end)` | **Same** |
| `count(distinct x)` | **Same** |
| `approx_count_distinct(x)` | `count(distinct x)` |
| `percentile_approx(x, 0.5)` | `percentile_cont(0.5) within group (order by x)` |
| `bool_or(x)`, `bool_and(x)` | **Same** |
| `having count(*) > 1` | **Same** |

## 4. Window functions

| Databricks | Postgres |
|---|---|
| `row_number() / rank() / dense_rank() over (partition by .. order by ..)` | **Same** |
| `lag(x) over (...)`, `lead(x, 2) over (...)` | **Same** |
| `sum(x) over (order by d rows between unbounded preceding and current row)` | **Same** |
| `range between interval 2 days preceding and current row` | `range between interval '2 days' preceding and current row` (quotes) |
| `... qualify row_number() over (...) = 1` | CTE, then `where rn = 1` |
| Latest row per key | Also: `select distinct on (key) * from t order by key, ts desc` |
| `last(x, true)` / `ignore nulls` | Not available. Use a subquery or `coalesce` |
| No frame + `order by` = running total, ties summed together | **Same** trap. Write `rows between ...` and add a tie-breaker |

## 5. Dates and times

| Databricks | Postgres |
|---|---|
| `current_date()`, `current_timestamp()` | `current_date`, `now()` (no parentheses on `current_date`) |
| `date_add(d, 7)` | `d + 7` (stays a date) |
| `d + interval 7 days` | `d + interval '7 days'` (becomes a timestamp) |
| `datediff(end, start)` | `end::date - start::date` (an integer) |
| `ts2 - ts1` in seconds | `extract(epoch from ts2 - ts1)` |
| `date_trunc('month', ts)` | **Same**, but on a date it returns a timestamp: add `::date` |
| `date_format(ts, 'yyyy-MM')` | `to_char(ts, 'YYYY-MM')` |
| `to_date('2026-03-01')` | `date '2026-03-01'` or `'2026-03-01'::date` |
| `year(d)`, `month(d)` | `extract(year from d)`, `extract(month from d)` |
| `dayofweek(d)` (Sun = 1) | `extract(dow from d)` (Sun = 0) or `extract(isodow from d)` (Mon = 1, Sun = 7) |
| `last_day(d)` | `(date_trunc('month', d) + interval '1 month - 1 day')::date` |
| `explode(sequence(d1, d2, interval 1 day))` | `generate_series(d1, d2, interval '1 day')::date` |
| `ts >= '2026-03-01' and ts < '2026-04-01'` | **Same** (never `between` on timestamps) |

## 6. Strings

| Databricks | Postgres |
|---|---|
| `concat_ws(',', collect_list(x))` | `string_agg(x, ',' order by x)` |
| `collect_list(x)` / `collect_set(x)` | `array_agg(x)` / `array_agg(distinct x)` |
| `split(s, ',')[0]` | `split_part(s, ',', 1)` (counts from 1) |
| `s rlike '^A'` | `s ~ '^A'` (case-insensitive: `~*`) |
| `like`, `ilike`, `lower`, `upper`, `trim`, `length`, `lpad` | **Same** |
| `substring(s, 1, 3)`, `s1 \|\| s2`, `concat(a, b)` | **Same** |
| `instr(s, 'x')` | `strpos(s, 'x')` |

## 7. Nulls

| Databricks | Postgres |
|---|---|
| `nvl(x, 0)`, `ifnull(x, 0)` | `coalesce(x, 0)` |
| `nullif(x, 0)` | **Same** |
| `a <=> b` (null-safe equals) | `a is not distinct from b` |
| `order by x desc` puts nulls **last** | Puts nulls **first**. Write `order by x desc nulls last` |
| `order by x asc` puts nulls **first** | Puts nulls **last**. Write `nulls first` if needed |
| `x / 0`: null or an error, depending on ANSI mode | Always an **error**. Write `x / nullif(y, 0)` |

## 8. Casting and numbers

| Databricks | Postgres |
|---|---|
| `cast(x as string)` | `x::text` |
| `cast(x as int)`, `cast(x as date)` | **Same**, or `x::int`, `x::date` |
| `5 / 2` returns 2.5 | Returns **2**. Write `5::numeric / 2` or `100.0 * a / b` |
| `round(x, 2)` on any number | Needs `numeric`: `round(x::numeric, 2)` |
| `if(cond, a, b)` | `case when cond then a else b end` |
| `double` for money | `numeric(12,2)` |

## 9. Table setup (Karat Studio has no tables: you create them)

| Databricks | Postgres |
|---|---|
| `create or replace table t (...) using delta` | `drop table if exists t;` then `create table t (...)` |
| `string` | `text` |
| `create table t as select ...` | **Same** |
| `select * from values (1, 'a') as t(id, v)` | `select * from (values (1, 'a')) as t(id, v)` |
| `insert into t values (1, 'a'), (2, 'b')` | **Same** |
| `timestamp '2026-03-01 10:00'`, `date '2026-03-01'` | **Same**, or plain `'2026-03-01 10:00'` in an insert |
| Primary keys not enforced | Enforced: `id int primary key`, `user_id int references users (user_id)` |

**Template to paste:**
```sql
drop table if exists t;
create table t (id int primary key, user_id int, created_at timestamp, amount numeric(10,2), status text);
insert into t values (1, 1, '2026-03-01 10:00', -50, 'posted');
```

## 10. Postgres-only extras worth using

| Feature | Example |
|---|---|
| `distinct on` | `select distinct on (user_id) * from t order by user_id, created_at desc` |
| `generate_series` | `select d::date from generate_series(date '2026-03-01', date '2026-03-07', interval '1 day') d` |
| `filter` | `count(*) filter (where status = 'failed')` |
| `fetch first n rows with ties` | Top N including ties, no window needed |
| `except` / `intersect` | Users in April **except** users in March |
| `explain analyze` | Runs the query and shows the plan with real times (your query profile) |
| Indexes | `create index on t (user_id, created_at)`: equality column first, range column second |
| Upsert | `insert ... on conflict (id) do update set amount = excluded.amount` |
