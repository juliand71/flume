-- ============================================================================
-- Budget Test Data Seed
-- Three checking accounts with different paycheck patterns:
--   1. Biweekly steady paycheck ($2,500 every 14 days)
--   2. Monthly steady paycheck ($5,200 on the 1st)
--   3. Unpredictable freelance income ($800-$4,500, irregular intervals)
-- ============================================================================

-- Fixed UUIDs for reproducibility
-- Test user
\set test_user_id   '11111111-1111-1111-1111-111111111111'

-- Plaid items (one per "institution")
\set plaid_item_1   '22222222-2222-2222-2222-222222222201'
\set plaid_item_2   '22222222-2222-2222-2222-222222222202'
\set plaid_item_3   '22222222-2222-2222-2222-222222222203'

-- Accounts
\set acct_biweekly  '33333333-3333-3333-3333-333333333301'
\set acct_monthly   '33333333-3333-3333-3333-333333333302'
\set acct_freelance '33333333-3333-3333-3333-333333333303'

-- Income streams
\set is_biweekly    '44444444-4444-4444-4444-444444444401'
\set is_monthly     '44444444-4444-4444-4444-444444444402'
\set is_freelance   '44444444-4444-4444-4444-444444444403'

-- Budget periods
\set bp_biweekly    '55555555-5555-5555-5555-555555555501'
\set bp_monthly     '55555555-5555-5555-5555-555555555502'
\set bp_freelance   '55555555-5555-5555-5555-555555555503'

-- ── Test user ─────────────────────────────────────────────────────────────────

INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at, instance_id, aud, role)
VALUES (
  :'test_user_id',
  'testuser@flume.dev',
  crypt('password123', gen_salt('bf')),
  now(),
  now(),
  now(),
  '00000000-0000-0000-0000-000000000000',
  'authenticated',
  'authenticated'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, display_name)
VALUES (:'test_user_id', 'Test User')
ON CONFLICT (id) DO NOTHING;

-- ── Plaid items ───────────────────────────────────────────────────────────────

INSERT INTO public.plaid_items (id, user_id, plaid_item_id, access_token, institution_name) VALUES
  (:'plaid_item_1', :'test_user_id', 'test-item-biweekly', 'access-sandbox-biweekly', 'Test Bank (Biweekly)'),
  (:'plaid_item_2', :'test_user_id', 'test-item-monthly',  'access-sandbox-monthly',  'Test Bank (Monthly)'),
  (:'plaid_item_3', :'test_user_id', 'test-item-freelance','access-sandbox-freelance', 'Test Bank (Freelance)')
ON CONFLICT (id) DO NOTHING;

-- ── Accounts ──────────────────────────────────────────────────────────────────

INSERT INTO public.accounts (id, plaid_item_id, user_id, plaid_account_id, name, type, subtype, mask, current_balance, available_balance) VALUES
  (:'acct_biweekly',  :'plaid_item_1', :'test_user_id', 'test-acct-biweekly',  'Biweekly Checking',  'depository', 'checking', '1234', 5200.00, 5200.00),
  (:'acct_monthly',   :'plaid_item_2', :'test_user_id', 'test-acct-monthly',   'Monthly Checking',   'depository', 'checking', '5678', 8400.00, 8400.00),
  (:'acct_freelance', :'plaid_item_3', :'test_user_id', 'test-acct-freelance', 'Freelance Checking', 'depository', 'checking', '9012', 3100.00, 3100.00)
ON CONFLICT (id) DO NOTHING;

-- ── Account roles ─────────────────────────────────────────────────────────────

INSERT INTO public.account_roles (account_id, user_id, account_role) VALUES
  (:'acct_biweekly',  :'test_user_id', 'checking'),
  (:'acct_monthly',   :'test_user_id', 'checking'),
  (:'acct_freelance', :'test_user_id', 'checking')
ON CONFLICT (account_id) DO NOTHING;

-- ── Income streams ────────────────────────────────────────────────────────────

INSERT INTO public.income_streams (id, user_id, name, estimated_amount, frequency, next_expected_date) VALUES
  (:'is_biweekly',  :'test_user_id', 'ACME Corp Payroll',      2500.00, 'biweekly',  CURRENT_DATE + interval '14 days'),
  (:'is_monthly',   :'test_user_id', 'MegaCorp Salary',        5200.00, 'monthly',   date_trunc('month', CURRENT_DATE) + interval '1 month'),
  (:'is_freelance', :'test_user_id', 'Freelance Consulting',   2500.00, 'monthly',   NULL)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- ACCOUNT 1: BIWEEKLY PAYCHECK ($2,500 every 14 days)
-- ============================================================================

-- Paychecks: every 14 days for 6 months
INSERT INTO public.transactions (account_id, user_id, plaid_transaction_id, name, amount, date, pending, personal_finance_category)
SELECT
  :'acct_biweekly', :'test_user_id',
  'test-bw-pay-' || to_char(d, 'YYYY-MM-DD'),
  'ACME CORP PAYROLL',
  -2500.00,
  d::date,
  false,
  '{"primary":"INCOME","detailed":"INCOME_WAGES"}'::jsonb
FROM generate_series(
  CURRENT_DATE - interval '6 months',
  CURRENT_DATE,
  interval '14 days'
) AS d
ON CONFLICT (plaid_transaction_id) DO NOTHING;

-- Rent: $1,500 on the 1st of each month
INSERT INTO public.transactions (account_id, user_id, plaid_transaction_id, name, amount, date, pending, personal_finance_category)
SELECT
  :'acct_biweekly', :'test_user_id',
  'test-bw-rent-' || to_char(d, 'YYYY-MM-DD'),
  'PARKVIEW APARTMENTS',
  1500.00,
  d::date,
  false,
  '{"primary":"RENT_AND_UTILITIES","detailed":"RENT_AND_UTILITIES_RENT"}'::jsonb
FROM generate_series(
  date_trunc('month', CURRENT_DATE - interval '6 months'),
  date_trunc('month', CURRENT_DATE),
  interval '1 month'
) AS d
ON CONFLICT (plaid_transaction_id) DO NOTHING;

-- Utilities: ~$120 on the 15th of each month
INSERT INTO public.transactions (account_id, user_id, plaid_transaction_id, name, amount, date, pending, personal_finance_category)
SELECT
  :'acct_biweekly', :'test_user_id',
  'test-bw-util-' || to_char(d, 'YYYY-MM-DD'),
  'CITY POWER & WATER',
  115.00 + (extract(month from d) * 3.5),
  (d + interval '14 days')::date,
  false,
  '{"primary":"RENT_AND_UTILITIES","detailed":"RENT_AND_UTILITIES_GAS_AND_ELECTRICITY"}'::jsonb
FROM generate_series(
  date_trunc('month', CURRENT_DATE - interval '6 months'),
  date_trunc('month', CURRENT_DATE),
  interval '1 month'
) AS d
ON CONFLICT (plaid_transaction_id) DO NOTHING;

-- Groceries: ~2 per week, $40-$150
INSERT INTO public.transactions (account_id, user_id, plaid_transaction_id, name, amount, date, pending, personal_finance_category)
SELECT
  :'acct_biweekly', :'test_user_id',
  'test-bw-groc-' || to_char(d, 'YYYY-MM-DD') || '-' || row_number() over (),
  CASE (extract(dow from d)::int % 3)
    WHEN 0 THEN 'WHOLE FOODS MARKET'
    WHEN 1 THEN 'TRADER JOES'
    ELSE 'SAFEWAY'
  END,
  40.00 + (random() * 110)::numeric(6,2),
  d::date,
  false,
  '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_GROCERIES"}'::jsonb
FROM generate_series(
  CURRENT_DATE - interval '6 months',
  CURRENT_DATE,
  interval '4 days'
) AS d
ON CONFLICT (plaid_transaction_id) DO NOTHING;

-- Entertainment: ~3 per month, $10-$80
INSERT INTO public.transactions (account_id, user_id, plaid_transaction_id, name, amount, date, pending, personal_finance_category)
SELECT
  :'acct_biweekly', :'test_user_id',
  'test-bw-ent-' || to_char(d, 'YYYY-MM-DD'),
  CASE (extract(day from d)::int % 4)
    WHEN 0 THEN 'NETFLIX.COM'
    WHEN 1 THEN 'AMC THEATRES'
    WHEN 2 THEN 'SPOTIFY USA'
    ELSE 'STEAM GAMES'
  END,
  10.00 + (random() * 70)::numeric(6,2),
  d::date,
  false,
  '{"primary":"ENTERTAINMENT","detailed":"ENTERTAINMENT_MUSIC_AND_AUDIO"}'::jsonb
FROM generate_series(
  CURRENT_DATE - interval '6 months',
  CURRENT_DATE,
  interval '10 days'
) AS d
ON CONFLICT (plaid_transaction_id) DO NOTHING;

-- Gas: ~weekly, $35-$60
INSERT INTO public.transactions (account_id, user_id, plaid_transaction_id, name, amount, date, pending, personal_finance_category)
SELECT
  :'acct_biweekly', :'test_user_id',
  'test-bw-gas-' || to_char(d, 'YYYY-MM-DD'),
  CASE (extract(dow from d)::int % 2)
    WHEN 0 THEN 'SHELL OIL'
    ELSE 'CHEVRON'
  END,
  35.00 + (random() * 25)::numeric(6,2),
  d::date,
  false,
  '{"primary":"TRANSPORTATION","detailed":"TRANSPORTATION_GAS"}'::jsonb
FROM generate_series(
  CURRENT_DATE - interval '6 months',
  CURRENT_DATE,
  interval '7 days'
) AS d
ON CONFLICT (plaid_transaction_id) DO NOTHING;

-- ============================================================================
-- ACCOUNT 2: MONTHLY PAYCHECK ($5,200 on the 1st)
-- ============================================================================

-- Paychecks: 1st of each month
INSERT INTO public.transactions (account_id, user_id, plaid_transaction_id, name, amount, date, pending, personal_finance_category)
SELECT
  :'acct_monthly', :'test_user_id',
  'test-mo-pay-' || to_char(d, 'YYYY-MM-DD'),
  'MEGACORP INC DIRECT DEP',
  -5200.00,
  d::date,
  false,
  '{"primary":"INCOME","detailed":"INCOME_WAGES"}'::jsonb
FROM generate_series(
  date_trunc('month', CURRENT_DATE - interval '6 months'),
  date_trunc('month', CURRENT_DATE),
  interval '1 month'
) AS d
ON CONFLICT (plaid_transaction_id) DO NOTHING;

-- Mortgage: $2,200 on the 1st
INSERT INTO public.transactions (account_id, user_id, plaid_transaction_id, name, amount, date, pending, personal_finance_category)
SELECT
  :'acct_monthly', :'test_user_id',
  'test-mo-mort-' || to_char(d, 'YYYY-MM-DD'),
  'WELLS FARGO MORTGAGE',
  2200.00,
  (d + interval '1 day')::date,
  false,
  '{"primary":"LOAN_PAYMENTS","detailed":"LOAN_PAYMENTS_MORTGAGE_PAYMENT"}'::jsonb
FROM generate_series(
  date_trunc('month', CURRENT_DATE - interval '6 months'),
  date_trunc('month', CURRENT_DATE),
  interval '1 month'
) AS d
ON CONFLICT (plaid_transaction_id) DO NOTHING;

-- Car insurance: $180/mo on the 5th
INSERT INTO public.transactions (account_id, user_id, plaid_transaction_id, name, amount, date, pending, personal_finance_category)
SELECT
  :'acct_monthly', :'test_user_id',
  'test-mo-ins-' || to_char(d, 'YYYY-MM-DD'),
  'GEICO AUTO INSURANCE',
  180.00,
  (d + interval '4 days')::date,
  false,
  '{"primary":"RENT_AND_UTILITIES","detailed":"RENT_AND_UTILITIES_OTHER_UTILITIES"}'::jsonb
FROM generate_series(
  date_trunc('month', CURRENT_DATE - interval '6 months'),
  date_trunc('month', CURRENT_DATE),
  interval '1 month'
) AS d
ON CONFLICT (plaid_transaction_id) DO NOTHING;

-- Groceries: ~2 per week, $60-$200
INSERT INTO public.transactions (account_id, user_id, plaid_transaction_id, name, amount, date, pending, personal_finance_category)
SELECT
  :'acct_monthly', :'test_user_id',
  'test-mo-groc-' || to_char(d, 'YYYY-MM-DD') || '-' || row_number() over (),
  CASE (extract(dow from d)::int % 2)
    WHEN 0 THEN 'COSTCO WHOLESALE'
    ELSE 'WHOLE FOODS MARKET'
  END,
  60.00 + (random() * 140)::numeric(6,2),
  d::date,
  false,
  '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_GROCERIES"}'::jsonb
FROM generate_series(
  CURRENT_DATE - interval '6 months',
  CURRENT_DATE,
  interval '4 days'
) AS d
ON CONFLICT (plaid_transaction_id) DO NOTHING;

-- Dining out: ~weekly, $25-$90
INSERT INTO public.transactions (account_id, user_id, plaid_transaction_id, name, amount, date, pending, personal_finance_category)
SELECT
  :'acct_monthly', :'test_user_id',
  'test-mo-dine-' || to_char(d, 'YYYY-MM-DD'),
  CASE (extract(dow from d)::int % 3)
    WHEN 0 THEN 'CHIPOTLE MEXICAN GRILL'
    WHEN 1 THEN 'OLIVE GARDEN'
    ELSE 'LOCAL PIZZERIA'
  END,
  25.00 + (random() * 65)::numeric(6,2),
  d::date,
  false,
  '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_RESTAURANT"}'::jsonb
FROM generate_series(
  CURRENT_DATE - interval '6 months',
  CURRENT_DATE,
  interval '7 days'
) AS d
ON CONFLICT (plaid_transaction_id) DO NOTHING;

-- Shopping: ~biweekly, $20-$150
INSERT INTO public.transactions (account_id, user_id, plaid_transaction_id, name, amount, date, pending, personal_finance_category)
SELECT
  :'acct_monthly', :'test_user_id',
  'test-mo-shop-' || to_char(d, 'YYYY-MM-DD'),
  CASE (extract(day from d)::int % 3)
    WHEN 0 THEN 'AMAZON.COM'
    WHEN 1 THEN 'TARGET'
    ELSE 'BEST BUY'
  END,
  20.00 + (random() * 130)::numeric(6,2),
  d::date,
  false,
  '{"primary":"GENERAL_MERCHANDISE","detailed":"GENERAL_MERCHANDISE_ONLINE_MARKETPLACES"}'::jsonb
FROM generate_series(
  CURRENT_DATE - interval '6 months',
  CURRENT_DATE,
  interval '14 days'
) AS d
ON CONFLICT (plaid_transaction_id) DO NOTHING;

-- ============================================================================
-- ACCOUNT 3: UNPREDICTABLE FREELANCE INCOME
-- ============================================================================

-- Irregular income deposits (hand-picked dates and amounts)
INSERT INTO public.transactions (account_id, user_id, plaid_transaction_id, name, amount, date, pending, personal_finance_category) VALUES
  (:'acct_freelance', :'test_user_id', 'test-fl-inc-01', 'CLIENT A - WEB DEV',        -3200.00, CURRENT_DATE - interval '175 days', false, '{"primary":"INCOME","detailed":"INCOME_OTHER_INCOME"}'::jsonb),
  (:'acct_freelance', :'test_user_id', 'test-fl-inc-02', 'CLIENT B - CONSULTING',      -1800.00, CURRENT_DATE - interval '160 days', false, '{"primary":"INCOME","detailed":"INCOME_OTHER_INCOME"}'::jsonb),
  (:'acct_freelance', :'test_user_id', 'test-fl-inc-03', 'CLIENT A - WEB DEV',        -2400.00, CURRENT_DATE - interval '148 days', false, '{"primary":"INCOME","detailed":"INCOME_OTHER_INCOME"}'::jsonb),
  (:'acct_freelance', :'test_user_id', 'test-fl-inc-04', 'CLIENT C - DESIGN',          -950.00, CURRENT_DATE - interval '130 days', false, '{"primary":"INCOME","detailed":"INCOME_OTHER_INCOME"}'::jsonb),
  (:'acct_freelance', :'test_user_id', 'test-fl-inc-05', 'CLIENT B - CONSULTING',     -4500.00, CURRENT_DATE - interval '118 days', false, '{"primary":"INCOME","detailed":"INCOME_OTHER_INCOME"}'::jsonb),
  (:'acct_freelance', :'test_user_id', 'test-fl-inc-06', 'CLIENT A - WEB DEV',        -1200.00, CURRENT_DATE - interval '99 days',  false, '{"primary":"INCOME","detailed":"INCOME_OTHER_INCOME"}'::jsonb),
  (:'acct_freelance', :'test_user_id', 'test-fl-inc-07', 'CLIENT D - APP PROTOTYPE',  -3800.00, CURRENT_DATE - interval '85 days',  false, '{"primary":"INCOME","detailed":"INCOME_OTHER_INCOME"}'::jsonb),
  (:'acct_freelance', :'test_user_id', 'test-fl-inc-08', 'CLIENT C - DESIGN',          -800.00, CURRENT_DATE - interval '72 days',  false, '{"primary":"INCOME","detailed":"INCOME_OTHER_INCOME"}'::jsonb),
  (:'acct_freelance', :'test_user_id', 'test-fl-inc-09', 'CLIENT A - WEB DEV',        -2800.00, CURRENT_DATE - interval '55 days',  false, '{"primary":"INCOME","detailed":"INCOME_OTHER_INCOME"}'::jsonb),
  (:'acct_freelance', :'test_user_id', 'test-fl-inc-10', 'CLIENT B - CONSULTING',     -1500.00, CURRENT_DATE - interval '48 days',  false, '{"primary":"INCOME","detailed":"INCOME_OTHER_INCOME"}'::jsonb),
  (:'acct_freelance', :'test_user_id', 'test-fl-inc-11', 'CLIENT E - SEO AUDIT',      -2200.00, CURRENT_DATE - interval '33 days',  false, '{"primary":"INCOME","detailed":"INCOME_OTHER_INCOME"}'::jsonb),
  (:'acct_freelance', :'test_user_id', 'test-fl-inc-12', 'CLIENT A - WEB DEV',        -3500.00, CURRENT_DATE - interval '22 days',  false, '{"primary":"INCOME","detailed":"INCOME_OTHER_INCOME"}'::jsonb),
  (:'acct_freelance', :'test_user_id', 'test-fl-inc-13', 'CLIENT C - DESIGN',         -1100.00, CURRENT_DATE - interval '15 days',  false, '{"primary":"INCOME","detailed":"INCOME_OTHER_INCOME"}'::jsonb),
  (:'acct_freelance', :'test_user_id', 'test-fl-inc-14', 'CLIENT B - CONSULTING',     -2600.00, CURRENT_DATE - interval '8 days',   false, '{"primary":"INCOME","detailed":"INCOME_OTHER_INCOME"}'::jsonb),
  (:'acct_freelance', :'test_user_id', 'test-fl-inc-15', 'CLIENT D - APP PROTOTYPE',  -4200.00, CURRENT_DATE - interval '2 days',   false, '{"primary":"INCOME","detailed":"INCOME_OTHER_INCOME"}'::jsonb)
ON CONFLICT (plaid_transaction_id) DO NOTHING;

-- Freelance expenses: coworking space monthly
INSERT INTO public.transactions (account_id, user_id, plaid_transaction_id, name, amount, date, pending, personal_finance_category)
SELECT
  :'acct_freelance', :'test_user_id',
  'test-fl-cowork-' || to_char(d, 'YYYY-MM-DD'),
  'WEWORK MEMBERSHIP',
  350.00,
  (d + interval '2 days')::date,
  false,
  '{"primary":"RENT_AND_UTILITIES","detailed":"RENT_AND_UTILITIES_RENT"}'::jsonb
FROM generate_series(
  date_trunc('month', CURRENT_DATE - interval '6 months'),
  date_trunc('month', CURRENT_DATE),
  interval '1 month'
) AS d
ON CONFLICT (plaid_transaction_id) DO NOTHING;

-- Freelance expenses: coffee shops, ~3x/week
INSERT INTO public.transactions (account_id, user_id, plaid_transaction_id, name, amount, date, pending, personal_finance_category)
SELECT
  :'acct_freelance', :'test_user_id',
  'test-fl-coffee-' || to_char(d, 'YYYY-MM-DD'),
  CASE (extract(dow from d)::int % 2)
    WHEN 0 THEN 'STARBUCKS'
    ELSE 'BLUE BOTTLE COFFEE'
  END,
  4.50 + (random() * 8)::numeric(6,2),
  d::date,
  false,
  '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_COFFEE"}'::jsonb
FROM generate_series(
  CURRENT_DATE - interval '6 months',
  CURRENT_DATE,
  interval '3 days'
) AS d
ON CONFLICT (plaid_transaction_id) DO NOTHING;

-- Freelance expenses: software subscriptions on the 10th
INSERT INTO public.transactions (account_id, user_id, plaid_transaction_id, name, amount, date, pending, personal_finance_category)
SELECT
  :'acct_freelance', :'test_user_id',
  'test-fl-sw-' || to_char(d, 'YYYY-MM-DD'),
  'ADOBE CREATIVE CLOUD',
  54.99,
  (d + interval '9 days')::date,
  false,
  '{"primary":"GENERAL_SERVICES","detailed":"GENERAL_SERVICES_OTHER_GENERAL_SERVICES"}'::jsonb
FROM generate_series(
  date_trunc('month', CURRENT_DATE - interval '6 months'),
  date_trunc('month', CURRENT_DATE),
  interval '1 month'
) AS d
ON CONFLICT (plaid_transaction_id) DO NOTHING;

-- ============================================================================
-- BUDGET PERIODS (one current period per account pattern)
-- ============================================================================

-- Biweekly: current 2-week period
INSERT INTO public.budget_periods (id, user_id, start_date, end_date, income_target, fixed_target, flex_target, savings_target, income_stream_id) VALUES
  (:'bp_biweekly', :'test_user_id',
   CURRENT_DATE - (extract(day from CURRENT_DATE)::int % 14 || ' days')::interval,
   CURRENT_DATE - (extract(day from CURRENT_DATE)::int % 14 || ' days')::interval + interval '14 days',
   2500.00, 1700.00, 500.00, 300.00, :'is_biweekly')
ON CONFLICT (user_id, start_date) DO NOTHING;

-- Monthly: current month
INSERT INTO public.budget_periods (id, user_id, start_date, end_date, income_target, fixed_target, flex_target, savings_target, income_stream_id) VALUES
  (:'bp_monthly', :'test_user_id',
   date_trunc('month', CURRENT_DATE)::date,
   (date_trunc('month', CURRENT_DATE) + interval '1 month')::date,
   5200.00, 2500.00, 1200.00, 1500.00, :'is_monthly')
ON CONFLICT (user_id, start_date) DO NOTHING;

-- Freelance: current month (best approximation for irregular income)
INSERT INTO public.budget_periods (id, user_id, start_date, end_date, income_target, fixed_target, flex_target, savings_target, income_stream_id) VALUES
  (:'bp_freelance', :'test_user_id',
   date_trunc('month', CURRENT_DATE)::date,
   (date_trunc('month', CURRENT_DATE) + interval '1 month')::date,
   4000.00, 450.00, 800.00, 2750.00, :'is_freelance')
ON CONFLICT (user_id, start_date) DO NOTHING;
