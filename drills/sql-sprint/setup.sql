-- SQL sprint: one small payments dataset used by every drill.
-- Run once in the drills schema: use workspace.drills;

create or replace table s_customers as
select * from values
  ('C1', 'Ana',  date'2026-01-05', cast(null as string), 'NY'),
  ('C2', 'Ben',  date'2026-01-20', 'C1',                 'NJ'),
  ('C3', 'Cara', date'2026-02-02', 'C1',                 'NY'),
  ('C4', 'Dev',  date'2026-02-15', 'C9',                 'CT'),
  ('C5', 'Eli',  date'2026-03-01', cast(null as string), 'NY')
as t(customer_id, name, signup_date, referred_by, state);

create or replace table s_accounts as
select * from values
  ('A1', 'C1', 'checking', date'2026-01-05'),
  ('A2', 'C1', 'savings',  date'2026-01-10'),
  ('A3', 'C2', 'checking', date'2026-01-21'),
  ('A4', 'C3', 'checking', date'2026-02-03'),
  ('A5', 'C6', 'checking', date'2026-02-20'),
  ('A6', 'C5', 'savings',  date'2026-03-02')
as t(account_id, customer_id, account_type, opened_on);

-- amount: negative = money out (a debit), positive = money in (a deposit)
create or replace table s_transactions as
select * from values
  ('T1',  'A1',                 timestamp'2026-03-01 10:00:00',  -50.00, 'posted',   'grocery'),
  ('T2',  'A1',                 timestamp'2026-03-02 12:00:00', -100.00, 'posted',   'dining'),
  ('T3',  'A1',                 timestamp'2026-03-05 09:00:00', 1000.00, 'posted',   'payroll'),
  ('T4',  'A3',                 timestamp'2026-03-03 18:00:00',  -75.00, 'posted',   'grocery'),
  ('T5',  'A3',                 timestamp'2026-03-03 18:01:00',  -75.00, 'declined', 'grocery'),
  ('T6',  'A4',                 timestamp'2026-03-10 08:00:00', -200.00, 'posted',   'travel'),
  ('T7',  'A2',                 timestamp'2026-03-15 11:00:00',  300.00, 'posted',   'transfer'),
  ('T8',  'A5',                 timestamp'2026-03-12 13:00:00',  -40.00, 'posted',   'dining'),
  ('T9',  cast(null as string), timestamp'2026-03-20 15:00:00',  -10.00, 'pending',  'dining'),
  ('T10', 'A1',                 timestamp'2026-04-01 10:00:00',  -60.00, 'posted',   'grocery'),
  ('T11', 'A4',                 timestamp'2026-03-10 08:00:00',  -20.00, 'posted',   'travel'),
  ('T12', 'A3',                 timestamp'2026-03-25 10:00:00', -500.00, 'posted',   'travel'),
  ('T13', 'A2',                 timestamp'2026-04-02 09:00:00',  -10.00, 'posted',   'dining'),
  ('T14', 'A3',                 timestamp'2026-02-14 19:00:00',  -60.00, 'posted',   'grocery'),
  ('T15', 'A4',                 timestamp'2026-01-28 12:00:00',  -30.00, 'posted',   'grocery')
as t(txn_id, account_id, txn_ts, amount, status, category);

create or replace table s_refunds as
select * from values
  ('R1', 'T6', date'2026-03-12', 50.00),
  ('R2', 'T6', date'2026-03-14', 30.00),
  ('R3', 'T1', date'2026-03-02', 50.00)
as t(refund_id, txn_id, refunded_on, amount);

-- fee tiers: min_amt included, max_amt excluded
create or replace table s_fee_tiers as
select * from values
  (1,   0.00,       100.00, 1.00),
  (2, 100.00,       500.00, 0.50),
  (3, 500.00, 1000000000.00, 0.25)
as t(tier, min_amt, max_amt, fee_pct);

-- one row per segment change; the latest row is the current segment
create or replace table s_segments as
select * from values
  ('C1', 'standard', date'2026-01-05'),
  ('C1', 'premium',  date'2026-03-01'),
  ('C2', 'standard', date'2026-01-20'),
  ('C3', 'standard', date'2026-02-02')
as t(customer_id, segment, updated_at);
