-- Seed data for local development
-- Debug user UUID matches auth.DebugUserID in Go API

-- ── Debug user in Supabase Auth ─────────────────────────────────────────────

INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  confirmation_token, recovery_token,
  email_change_token_new, email_change, email_change_token_current,
  phone_change, phone_change_token, reauthentication_token,
  raw_app_meta_data, raw_user_meta_data
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated',
  'debug@flume.local',
  crypt('debug123', gen_salt('bf')),
  now(), now(), now(),
  '', '',
  '', '', '',
  '', '', '',
  '{"provider":"email","providers":["email"]}',
  '{}'
) ON CONFLICT (id) DO NOTHING;

-- Profile with onboarding complete and a realistic data set loaded
INSERT INTO public.profiles (id, display_name, onboarding_step)
VALUES ('00000000-0000-0000-0000-000000000000', 'Debug User', 'complete')
ON CONFLICT (id) DO UPDATE SET display_name = EXCLUDED.display_name, onboarding_step = EXCLUDED.onboarding_step;

-- ── Debug user 2 (fresh / not onboarded) ────────────────────────────────────

INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  confirmation_token, recovery_token,
  email_change_token_new, email_change, email_change_token_current,
  phone_change, phone_change_token, reauthentication_token,
  raw_app_meta_data, raw_user_meta_data
) VALUES (
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated',
  'debug2@flume.local',
  crypt('debug123', gen_salt('bf')),
  now(), now(), now(),
  '', '',
  '', '', '',
  '', '', '',
  '{"provider":"email","providers":["email"]}',
  '{}'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, display_name, onboarding_step)
VALUES ('00000000-0000-0000-0000-000000000001', 'Debug User 2', 'welcome')
ON CONFLICT (id) DO UPDATE SET display_name = EXCLUDED.display_name, onboarding_step = EXCLUDED.onboarding_step;

-- ── Plaid item (fake test bank) ─────────────────────────────────────────────

INSERT INTO public.plaid_items (id, user_id, plaid_item_id, access_token, institution_name)
VALUES (
  '11111111-1111-1111-1111-111111111111',
  '00000000-0000-0000-0000-000000000000',
  'test_item_sandbox_001', 'access-sandbox-test-001', 'Test Bank'
) ON CONFLICT DO NOTHING;

-- ── Accounts ────────────────────────────────────────────────────────────────

INSERT INTO public.accounts (id, plaid_item_id, user_id, plaid_account_id, name, type, subtype, current_balance, available_balance) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa001', '11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000000', 'test_checking_001', 'Test Checking', 'depository', 'checking', 5200.00, 4950.00),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa002', '11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000000', 'test_savings_001', 'Test Savings', 'depository', 'savings', 15000.00, 15000.00),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa003', '11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000000', 'test_credit_001', 'Test Credit Card', 'credit', 'credit card', -1180.00, null)
ON CONFLICT DO NOTHING;

-- ── Account roles ───────────────────────────────────────────────────────────

INSERT INTO public.account_roles (account_id, user_id, account_role) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa001', '00000000-0000-0000-0000-000000000000', 'checking'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa002', '00000000-0000-0000-0000-000000000000', 'savings'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa003', '00000000-0000-0000-0000-000000000000', 'credit_card')
ON CONFLICT DO NOTHING;

-- ── Transactions (last ~60 days of realistic data) ──────────────────────────
-- Positive amounts = money out (debits), Negative amounts = money in (credits/income)
-- personal_finance_category JSONB must match Plaid format for detection endpoints

-- Income: biweekly paychecks from ACME Corp
INSERT INTO public.transactions (account_id, user_id, plaid_transaction_id, name, amount, date, personal_finance_category) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa001', '00000000-0000-0000-0000-000000000000', 'txn_income_001', 'ACME CORP PAYROLL', -2800.00, CURRENT_DATE - INTERVAL '56 days', '{"primary":"INCOME","detailed":"INCOME_WAGES"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa001', '00000000-0000-0000-0000-000000000000', 'txn_income_002', 'ACME CORP PAYROLL', -2800.00, CURRENT_DATE - INTERVAL '42 days', '{"primary":"INCOME","detailed":"INCOME_WAGES"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa001', '00000000-0000-0000-0000-000000000000', 'txn_income_003', 'ACME CORP PAYROLL', -2800.00, CURRENT_DATE - INTERVAL '28 days', '{"primary":"INCOME","detailed":"INCOME_WAGES"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa001', '00000000-0000-0000-0000-000000000000', 'txn_income_004', 'ACME CORP PAYROLL', -2800.00, CURRENT_DATE - INTERVAL '14 days', '{"primary":"INCOME","detailed":"INCOME_WAGES"}');

-- Fixed: rent (monthly)
INSERT INTO public.transactions (account_id, user_id, plaid_transaction_id, name, amount, date, personal_finance_category) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa001', '00000000-0000-0000-0000-000000000000', 'txn_rent_001', 'RIVERSIDE APARTMENTS', 1450.00, CURRENT_DATE - INTERVAL '55 days', '{"primary":"RENT_AND_UTILITIES","detailed":"RENT_AND_UTILITIES_RENT"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa001', '00000000-0000-0000-0000-000000000000', 'txn_rent_002', 'RIVERSIDE APARTMENTS', 1450.00, CURRENT_DATE - INTERVAL '25 days', '{"primary":"RENT_AND_UTILITIES","detailed":"RENT_AND_UTILITIES_RENT"}');

-- Fixed: utilities
INSERT INTO public.transactions (account_id, user_id, plaid_transaction_id, name, amount, date, personal_finance_category) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa001', '00000000-0000-0000-0000-000000000000', 'txn_util_001', 'CITY ELECTRIC CO', 95.00, CURRENT_DATE - INTERVAL '50 days', '{"primary":"RENT_AND_UTILITIES","detailed":"RENT_AND_UTILITIES_ELECTRICITY"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa001', '00000000-0000-0000-0000-000000000000', 'txn_util_002', 'CITY ELECTRIC CO', 102.00, CURRENT_DATE - INTERVAL '20 days', '{"primary":"RENT_AND_UTILITIES","detailed":"RENT_AND_UTILITIES_ELECTRICITY"}');

-- Fixed: internet
INSERT INTO public.transactions (account_id, user_id, plaid_transaction_id, name, amount, date, personal_finance_category) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa001', '00000000-0000-0000-0000-000000000000', 'txn_inet_001', 'COMCAST INTERNET', 79.99, CURRENT_DATE - INTERVAL '48 days', '{"primary":"RENT_AND_UTILITIES","detailed":"RENT_AND_UTILITIES_INTERNET"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa001', '00000000-0000-0000-0000-000000000000', 'txn_inet_002', 'COMCAST INTERNET', 79.99, CURRENT_DATE - INTERVAL '18 days', '{"primary":"RENT_AND_UTILITIES","detailed":"RENT_AND_UTILITIES_INTERNET"}');

-- Fixed: subscriptions (on credit card)
INSERT INTO public.transactions (account_id, user_id, plaid_transaction_id, name, amount, date, personal_finance_category) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa003', '00000000-0000-0000-0000-000000000000', 'txn_sub_001', 'SPOTIFY PREMIUM', 10.99, CURRENT_DATE - INTERVAL '45 days', '{"primary":"GENERAL_SERVICES","detailed":"GENERAL_SERVICES_SUBSCRIPTIONS"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa003', '00000000-0000-0000-0000-000000000000', 'txn_sub_002', 'SPOTIFY PREMIUM', 10.99, CURRENT_DATE - INTERVAL '15 days', '{"primary":"GENERAL_SERVICES","detailed":"GENERAL_SERVICES_SUBSCRIPTIONS"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa003', '00000000-0000-0000-0000-000000000000', 'txn_sub_003', 'NETFLIX', 15.49, CURRENT_DATE - INTERVAL '40 days', '{"primary":"GENERAL_SERVICES","detailed":"GENERAL_SERVICES_SUBSCRIPTIONS"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa003', '00000000-0000-0000-0000-000000000000', 'txn_sub_004', 'NETFLIX', 15.49, CURRENT_DATE - INTERVAL '10 days', '{"primary":"GENERAL_SERVICES","detailed":"GENERAL_SERVICES_SUBSCRIPTIONS"}');

-- Flex: groceries
INSERT INTO public.transactions (account_id, user_id, plaid_transaction_id, name, amount, date, personal_finance_category) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa003', '00000000-0000-0000-0000-000000000000', 'txn_groc_001', 'TRADER JOES #123', 67.42, CURRENT_DATE - INTERVAL '52 days', '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_GROCERIES"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa003', '00000000-0000-0000-0000-000000000000', 'txn_groc_002', 'WHOLE FOODS MKT', 89.13, CURRENT_DATE - INTERVAL '44 days', '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_GROCERIES"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa003', '00000000-0000-0000-0000-000000000000', 'txn_groc_003', 'TRADER JOES #123', 54.87, CURRENT_DATE - INTERVAL '37 days', '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_GROCERIES"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa003', '00000000-0000-0000-0000-000000000000', 'txn_groc_004', 'WHOLE FOODS MKT', 71.29, CURRENT_DATE - INTERVAL '23 days', '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_GROCERIES"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa003', '00000000-0000-0000-0000-000000000000', 'txn_groc_005', 'TRADER JOES #123', 62.15, CURRENT_DATE - INTERVAL '9 days', '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_GROCERIES"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa003', '00000000-0000-0000-0000-000000000000', 'txn_groc_006', 'WHOLE FOODS MKT', 83.44, CURRENT_DATE - INTERVAL '2 days', '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_GROCERIES"}');

-- Flex: restaurants
INSERT INTO public.transactions (account_id, user_id, plaid_transaction_id, name, amount, date, personal_finance_category) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa003', '00000000-0000-0000-0000-000000000000', 'txn_rest_001', 'CHIPOTLE #4521', 14.25, CURRENT_DATE - INTERVAL '49 days', '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_RESTAURANT"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa003', '00000000-0000-0000-0000-000000000000', 'txn_rest_002', 'STARBUCKS #8832', 6.45, CURRENT_DATE - INTERVAL '41 days', '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_COFFEE"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa003', '00000000-0000-0000-0000-000000000000', 'txn_rest_003', 'THAI GARDEN REST', 42.80, CURRENT_DATE - INTERVAL '30 days', '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_RESTAURANT"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa003', '00000000-0000-0000-0000-000000000000', 'txn_rest_004', 'STARBUCKS #8832', 5.75, CURRENT_DATE - INTERVAL '16 days', '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_COFFEE"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa003', '00000000-0000-0000-0000-000000000000', 'txn_rest_005', 'DOMINOS PIZZA', 28.99, CURRENT_DATE - INTERVAL '5 days', '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_RESTAURANT"}');

-- Flex: gas
INSERT INTO public.transactions (account_id, user_id, plaid_transaction_id, name, amount, date, personal_finance_category) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa003', '00000000-0000-0000-0000-000000000000', 'txn_gas_001', 'SHELL OIL #4412', 52.30, CURRENT_DATE - INTERVAL '47 days', '{"primary":"TRANSPORTATION","detailed":"TRANSPORTATION_GAS"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa003', '00000000-0000-0000-0000-000000000000', 'txn_gas_002', 'SHELL OIL #4412', 48.75, CURRENT_DATE - INTERVAL '22 days', '{"primary":"TRANSPORTATION","detailed":"TRANSPORTATION_GAS"}');

-- Flex: general shopping
INSERT INTO public.transactions (account_id, user_id, plaid_transaction_id, name, amount, date, personal_finance_category) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa003', '00000000-0000-0000-0000-000000000000', 'txn_shop_001', 'AMAZON.COM', 34.99, CURRENT_DATE - INTERVAL '35 days', '{"primary":"GENERAL_MERCHANDISE","detailed":"GENERAL_MERCHANDISE_ONLINE_MARKETPLACES"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa003', '00000000-0000-0000-0000-000000000000', 'txn_shop_002', 'TARGET #1234', 47.82, CURRENT_DATE - INTERVAL '12 days', '{"primary":"GENERAL_MERCHANDISE","detailed":"GENERAL_MERCHANDISE_SUPERSTORES"}');

-- Transfer: credit card payment
INSERT INTO public.transactions (account_id, user_id, plaid_transaction_id, name, amount, date, personal_finance_category) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa001', '00000000-0000-0000-0000-000000000000', 'txn_xfer_001', 'CREDIT CARD PAYMENT', 800.00, CURRENT_DATE - INTERVAL '30 days', '{"primary":"TRANSFER_OUT","detailed":"TRANSFER_OUT_ACCOUNT_TRANSFER"}');

-- ── Income stream (matches detected paycheck pattern) ───────────────────────

INSERT INTO public.income_streams (id, user_id, name, estimated_amount, frequency, next_expected_date) VALUES
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbb0001', '00000000-0000-0000-0000-000000000000', 'ACME Corp Payroll', 2800.00, 'biweekly', CURRENT_DATE + INTERVAL '1 day')
ON CONFLICT DO NOTHING;

-- ── Budget periods (current month + previous month) ─────────────────────────

INSERT INTO public.budget_periods (id, user_id, start_date, end_date, income_target, fixed_target, flex_target, savings_target, income_stream_id) VALUES
  ('cccccccc-cccc-cccc-cccc-cccccccc0001', '00000000-0000-0000-0000-000000000000', DATE_TRUNC('month', CURRENT_DATE), DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month', 2800.00, 1700.00, 600.00, 500.00, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbb0001'),
  ('cccccccc-cccc-cccc-cccc-cccccccc0002', '00000000-0000-0000-0000-000000000000', DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '1 month', DATE_TRUNC('month', CURRENT_DATE), 2800.00, 1700.00, 600.00, 500.00, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbb0001')
ON CONFLICT (id) DO UPDATE SET start_date = EXCLUDED.start_date, end_date = EXCLUDED.end_date;

-- ── Savings goals ───────────────────────────────────────────────────────────

INSERT INTO public.savings_goals (id, user_id, name, target_amount, current_amount, emoji, is_emergency_fund, priority) VALUES
  ('dddddddd-dddd-dddd-dddd-dddddddd0001', '00000000-0000-0000-0000-000000000000', 'Emergency Fund', 10000.00, 3500.00, '🛟', true, 0),
  ('dddddddd-dddd-dddd-dddd-dddddddd0002', '00000000-0000-0000-0000-000000000000', 'Vacation', 3000.00, 750.00, '✈️', false, 1)
ON CONFLICT DO NOTHING;

-- ════════════════════════════════════════════════════════════════════════════
-- DEBUG USER 3 — Weekly Budgeter (freelancer, paid weekly)
-- ════════════════════════════════════════════════════════════════════════════

INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  confirmation_token, recovery_token,
  email_change_token_new, email_change, email_change_token_current,
  phone_change, phone_change_token, reauthentication_token,
  raw_app_meta_data, raw_user_meta_data
) VALUES (
  '00000000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated',
  'debug3@flume.local',
  crypt('debug123', gen_salt('bf')),
  now(), now(), now(),
  '', '', '', '', '', '', '', '',
  '{"provider":"email","providers":["email"]}', '{}'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, display_name, onboarding_step)
VALUES ('00000000-0000-0000-0000-000000000002', 'Weekly Budgeter', 'complete')
ON CONFLICT (id) DO UPDATE SET display_name = EXCLUDED.display_name, onboarding_step = EXCLUDED.onboarding_step;

INSERT INTO public.plaid_items (id, user_id, plaid_item_id, access_token, institution_name)
VALUES ('11111111-1111-1111-1111-111111111112', '00000000-0000-0000-0000-000000000002', 'test_item_sandbox_003', 'access-sandbox-test-003', 'Test Credit Union')
ON CONFLICT DO NOTHING;

INSERT INTO public.accounts (id, plaid_item_id, user_id, plaid_account_id, name, type, subtype, current_balance, available_balance) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa01001', '11111111-1111-1111-1111-111111111112', '00000000-0000-0000-0000-000000000002', 'test_checking_003', 'Freelance Checking', 'depository', 'checking', 3800.00, 3600.00),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa01002', '11111111-1111-1111-1111-111111111112', '00000000-0000-0000-0000-000000000002', 'test_savings_003', 'Freelance Savings', 'depository', 'savings', 6200.00, 6200.00),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa01003', '11111111-1111-1111-1111-111111111112', '00000000-0000-0000-0000-000000000002', 'test_credit_003', 'Freelance Credit Card', 'credit', 'credit card', -420.00, null)
ON CONFLICT DO NOTHING;

INSERT INTO public.account_roles (account_id, user_id, account_role) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa01001', '00000000-0000-0000-0000-000000000002', 'checking'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa01002', '00000000-0000-0000-0000-000000000002', 'savings'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa01003', '00000000-0000-0000-0000-000000000002', 'credit_card')
ON CONFLICT DO NOTHING;

INSERT INTO public.income_streams (id, user_id, name, estimated_amount, frequency, next_expected_date) VALUES
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbb0002', '00000000-0000-0000-0000-000000000002', 'Freelance Client Payment', 1200.00, 'weekly', CURRENT_DATE + INTERVAL '3 days')
ON CONFLICT DO NOTHING;

-- Weekly budget periods: current week and previous week
-- Anchor on next_expected_date (3 days from now), walk back to find current period start
INSERT INTO public.budget_periods (id, user_id, start_date, end_date, income_target, fixed_target, flex_target, savings_target, income_stream_id) VALUES
  ('cccccccc-cccc-cccc-cccc-cccccccc0003', '00000000-0000-0000-0000-000000000002',
    CURRENT_DATE - ((EXTRACT(DOW FROM CURRENT_DATE)::int + 4) % 7) * INTERVAL '1 day',
    CURRENT_DATE - ((EXTRACT(DOW FROM CURRENT_DATE)::int + 4) % 7) * INTERVAL '1 day' + INTERVAL '7 days',
    1200.00, 500.00, 460.00, 240.00, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbb0002'),
  ('cccccccc-cccc-cccc-cccc-cccccccc0004', '00000000-0000-0000-0000-000000000002',
    CURRENT_DATE - ((EXTRACT(DOW FROM CURRENT_DATE)::int + 4) % 7) * INTERVAL '1 day' - INTERVAL '7 days',
    CURRENT_DATE - ((EXTRACT(DOW FROM CURRENT_DATE)::int + 4) % 7) * INTERVAL '1 day',
    1200.00, 500.00, 460.00, 240.00, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbb0002')
ON CONFLICT (id) DO UPDATE SET start_date = EXCLUDED.start_date, end_date = EXCLUDED.end_date;

-- Transactions for user 3 (last ~14 days)
INSERT INTO public.transactions (account_id, user_id, plaid_transaction_id, name, amount, date, personal_finance_category) VALUES
  -- Weekly income
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa01001', '00000000-0000-0000-0000-000000000002', 'u3_txn_income_001', 'FREELANCE CLIENT PAYMENT', -1200.00, CURRENT_DATE - INTERVAL '10 days', '{"primary":"INCOME","detailed":"INCOME_WAGES"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa01001', '00000000-0000-0000-0000-000000000002', 'u3_txn_income_002', 'FREELANCE CLIENT PAYMENT', -1200.00, CURRENT_DATE - INTERVAL '3 days', '{"primary":"INCOME","detailed":"INCOME_WAGES"}'),
  -- Rent (split weekly portion)
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa01001', '00000000-0000-0000-0000-000000000002', 'u3_txn_rent_001', 'VENMO RENT SHARE', 375.00, CURRENT_DATE - INTERVAL '8 days', '{"primary":"RENT_AND_UTILITIES","detailed":"RENT_AND_UTILITIES_RENT"}'),
  -- Utilities
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa01001', '00000000-0000-0000-0000-000000000002', 'u3_txn_util_001', 'PG&E ELECTRIC', 62.00, CURRENT_DATE - INTERVAL '11 days', '{"primary":"RENT_AND_UTILITIES","detailed":"RENT_AND_UTILITIES_ELECTRICITY"}'),
  -- Internet
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa01001', '00000000-0000-0000-0000-000000000002', 'u3_txn_inet_001', 'AT&T FIBER', 55.00, CURRENT_DATE - INTERVAL '9 days', '{"primary":"RENT_AND_UTILITIES","detailed":"RENT_AND_UTILITIES_INTERNET"}'),
  -- Groceries
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa01003', '00000000-0000-0000-0000-000000000002', 'u3_txn_groc_001', 'ALDI #0892', 42.15, CURRENT_DATE - INTERVAL '12 days', '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_GROCERIES"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa01003', '00000000-0000-0000-0000-000000000002', 'u3_txn_groc_002', 'ALDI #0892', 38.90, CURRENT_DATE - INTERVAL '5 days', '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_GROCERIES"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa01003', '00000000-0000-0000-0000-000000000002', 'u3_txn_groc_003', 'COSTCO #441', 67.25, CURRENT_DATE - INTERVAL '1 day', '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_GROCERIES"}'),
  -- Coffee / restaurants
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa01003', '00000000-0000-0000-0000-000000000002', 'u3_txn_coffee_001', 'BLUE BOTTLE COFFEE', 5.50, CURRENT_DATE - INTERVAL '13 days', '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_COFFEE"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa01003', '00000000-0000-0000-0000-000000000002', 'u3_txn_coffee_002', 'BLUE BOTTLE COFFEE', 5.50, CURRENT_DATE - INTERVAL '6 days', '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_COFFEE"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa01003', '00000000-0000-0000-0000-000000000002', 'u3_txn_rest_001', 'PHO SAIGON', 16.80, CURRENT_DATE - INTERVAL '4 days', '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_RESTAURANT"}'),
  -- Gas
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa01003', '00000000-0000-0000-0000-000000000002', 'u3_txn_gas_001', 'CHEVRON #2281', 44.10, CURRENT_DATE - INTERVAL '7 days', '{"primary":"TRANSPORTATION","detailed":"TRANSPORTATION_GAS"}'),
  -- Coworking space (fixed)
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa01003', '00000000-0000-0000-0000-000000000002', 'u3_txn_cowork_001', 'WEWORK MEMBERSHIP', 50.00, CURRENT_DATE - INTERVAL '10 days', '{"primary":"GENERAL_SERVICES","detailed":"GENERAL_SERVICES_OTHER_GENERAL_SERVICES"}'),
  -- Amazon purchase
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa01003', '00000000-0000-0000-0000-000000000002', 'u3_txn_shop_001', 'AMAZON.COM', 29.99, CURRENT_DATE - INTERVAL '2 days', '{"primary":"GENERAL_MERCHANDISE","detailed":"GENERAL_MERCHANDISE_ONLINE_MARKETPLACES"}');

INSERT INTO public.savings_goals (id, user_id, name, target_amount, current_amount, emoji, is_emergency_fund, priority) VALUES
  ('dddddddd-dddd-dddd-dddd-dddddddd0003', '00000000-0000-0000-0000-000000000002', 'Rainy Day Fund', 5000.00, 1200.00, '🌧️', true, 0),
  ('dddddddd-dddd-dddd-dddd-dddddddd0004', '00000000-0000-0000-0000-000000000002', 'New Laptop', 2000.00, 800.00, '💻', false, 1)
ON CONFLICT DO NOTHING;

-- ════════════════════════════════════════════════════════════════════════════
-- DEBUG USER 4 — Biweekly Budgeter (salaried, typical US employee)
-- ════════════════════════════════════════════════════════════════════════════

INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  confirmation_token, recovery_token,
  email_change_token_new, email_change, email_change_token_current,
  phone_change, phone_change_token, reauthentication_token,
  raw_app_meta_data, raw_user_meta_data
) VALUES (
  '00000000-0000-0000-0000-000000000003',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated',
  'debug4@flume.local',
  crypt('debug123', gen_salt('bf')),
  now(), now(), now(),
  '', '', '', '', '', '', '', '',
  '{"provider":"email","providers":["email"]}', '{}'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, display_name, onboarding_step)
VALUES ('00000000-0000-0000-0000-000000000003', 'Biweekly Budgeter', 'complete')
ON CONFLICT (id) DO UPDATE SET display_name = EXCLUDED.display_name, onboarding_step = EXCLUDED.onboarding_step;

INSERT INTO public.plaid_items (id, user_id, plaid_item_id, access_token, institution_name)
VALUES ('11111111-1111-1111-1111-111111111113', '00000000-0000-0000-0000-000000000003', 'test_item_sandbox_004', 'access-sandbox-test-004', 'Test National Bank')
ON CONFLICT DO NOTHING;

INSERT INTO public.accounts (id, plaid_item_id, user_id, plaid_account_id, name, type, subtype, current_balance, available_balance) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa02001', '11111111-1111-1111-1111-111111111113', '00000000-0000-0000-0000-000000000003', 'test_checking_004', 'Primary Checking', 'depository', 'checking', 4100.00, 3850.00),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa02002', '11111111-1111-1111-1111-111111111113', '00000000-0000-0000-0000-000000000003', 'test_savings_004', 'High Yield Savings', 'depository', 'savings', 20500.00, 20500.00),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa02003', '11111111-1111-1111-1111-111111111113', '00000000-0000-0000-0000-000000000003', 'test_credit_004', 'Rewards Visa', 'credit', 'credit card', -890.00, null)
ON CONFLICT DO NOTHING;

INSERT INTO public.account_roles (account_id, user_id, account_role) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa02001', '00000000-0000-0000-0000-000000000003', 'checking'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa02002', '00000000-0000-0000-0000-000000000003', 'savings'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa02003', '00000000-0000-0000-0000-000000000003', 'credit_card')
ON CONFLICT DO NOTHING;

INSERT INTO public.income_streams (id, user_id, name, estimated_amount, frequency, next_expected_date) VALUES
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbb0003', '00000000-0000-0000-0000-000000000003', 'BigCorp Direct Deposit', 2600.00, 'biweekly', CURRENT_DATE + INTERVAL '5 days')
ON CONFLICT DO NOTHING;

-- Biweekly budget periods (14-day): current and previous
INSERT INTO public.budget_periods (id, user_id, start_date, end_date, income_target, fixed_target, flex_target, savings_target, income_stream_id) VALUES
  ('cccccccc-cccc-cccc-cccc-cccccccc0005', '00000000-0000-0000-0000-000000000003',
    CURRENT_DATE - ((EXTRACT(DOW FROM CURRENT_DATE)::int + 2) % 14) * INTERVAL '1 day',
    CURRENT_DATE - ((EXTRACT(DOW FROM CURRENT_DATE)::int + 2) % 14) * INTERVAL '1 day' + INTERVAL '14 days',
    2600.00, 1300.00, 780.00, 520.00, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbb0003'),
  ('cccccccc-cccc-cccc-cccc-cccccccc0006', '00000000-0000-0000-0000-000000000003',
    CURRENT_DATE - ((EXTRACT(DOW FROM CURRENT_DATE)::int + 2) % 14) * INTERVAL '1 day' - INTERVAL '14 days',
    CURRENT_DATE - ((EXTRACT(DOW FROM CURRENT_DATE)::int + 2) % 14) * INTERVAL '1 day',
    2600.00, 1300.00, 780.00, 520.00, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbb0003')
ON CONFLICT (id) DO UPDATE SET start_date = EXCLUDED.start_date, end_date = EXCLUDED.end_date;

-- Transactions for user 4 (last ~28 days)
INSERT INTO public.transactions (account_id, user_id, plaid_transaction_id, name, amount, date, personal_finance_category) VALUES
  -- Biweekly paychecks
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa02001', '00000000-0000-0000-0000-000000000003', 'u4_txn_income_001', 'BIGCORP DIRECT DEPOSIT', -2600.00, CURRENT_DATE - INTERVAL '23 days', '{"primary":"INCOME","detailed":"INCOME_WAGES"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa02001', '00000000-0000-0000-0000-000000000003', 'u4_txn_income_002', 'BIGCORP DIRECT DEPOSIT', -2600.00, CURRENT_DATE - INTERVAL '9 days', '{"primary":"INCOME","detailed":"INCOME_WAGES"}'),
  -- Rent
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa02001', '00000000-0000-0000-0000-000000000003', 'u4_txn_rent_001', 'OAK GROVE APTS', 1100.00, CURRENT_DATE - INTERVAL '25 days', '{"primary":"RENT_AND_UTILITIES","detailed":"RENT_AND_UTILITIES_RENT"}'),
  -- Utilities
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa02001', '00000000-0000-0000-0000-000000000003', 'u4_txn_util_001', 'DUKE ENERGY', 85.00, CURRENT_DATE - INTERVAL '22 days', '{"primary":"RENT_AND_UTILITIES","detailed":"RENT_AND_UTILITIES_ELECTRICITY"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa02001', '00000000-0000-0000-0000-000000000003', 'u4_txn_inet_001', 'SPECTRUM INTERNET', 65.00, CURRENT_DATE - INTERVAL '20 days', '{"primary":"RENT_AND_UTILITIES","detailed":"RENT_AND_UTILITIES_INTERNET"}'),
  -- Gym
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa02003', '00000000-0000-0000-0000-000000000003', 'u4_txn_gym_001', 'PLANET FITNESS', 25.00, CURRENT_DATE - INTERVAL '18 days', '{"primary":"GENERAL_SERVICES","detailed":"GENERAL_SERVICES_SUBSCRIPTIONS"}'),
  -- Groceries
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa02003', '00000000-0000-0000-0000-000000000003', 'u4_txn_groc_001', 'KROGER #1552', 78.43, CURRENT_DATE - INTERVAL '24 days', '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_GROCERIES"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa02003', '00000000-0000-0000-0000-000000000003', 'u4_txn_groc_002', 'KROGER #1552', 62.17, CURRENT_DATE - INTERVAL '17 days', '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_GROCERIES"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa02003', '00000000-0000-0000-0000-000000000003', 'u4_txn_groc_003', 'PUBLIX #0873', 91.05, CURRENT_DATE - INTERVAL '10 days', '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_GROCERIES"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa02003', '00000000-0000-0000-0000-000000000003', 'u4_txn_groc_004', 'KROGER #1552', 55.29, CURRENT_DATE - INTERVAL '3 days', '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_GROCERIES"}'),
  -- Dining
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa02003', '00000000-0000-0000-0000-000000000003', 'u4_txn_rest_001', 'CHICK-FIL-A #2103', 12.45, CURRENT_DATE - INTERVAL '21 days', '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_RESTAURANT"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa02003', '00000000-0000-0000-0000-000000000003', 'u4_txn_rest_002', 'OLIVE GARDEN #881', 38.50, CURRENT_DATE - INTERVAL '14 days', '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_RESTAURANT"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa02003', '00000000-0000-0000-0000-000000000003', 'u4_txn_coffee_001', 'DUNKIN DONUTS', 4.85, CURRENT_DATE - INTERVAL '8 days', '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_COFFEE"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa02003', '00000000-0000-0000-0000-000000000003', 'u4_txn_rest_003', 'PANERA BREAD #419', 15.20, CURRENT_DATE - INTERVAL '2 days', '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_RESTAURANT"}'),
  -- Gas
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa02003', '00000000-0000-0000-0000-000000000003', 'u4_txn_gas_001', 'BP #7741', 51.20, CURRENT_DATE - INTERVAL '19 days', '{"primary":"TRANSPORTATION","detailed":"TRANSPORTATION_GAS"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa02003', '00000000-0000-0000-0000-000000000003', 'u4_txn_gas_002', 'BP #7741', 48.90, CURRENT_DATE - INTERVAL '5 days', '{"primary":"TRANSPORTATION","detailed":"TRANSPORTATION_GAS"}'),
  -- Shopping
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa02003', '00000000-0000-0000-0000-000000000003', 'u4_txn_shop_001', 'AMAZON.COM', 42.99, CURRENT_DATE - INTERVAL '15 days', '{"primary":"GENERAL_MERCHANDISE","detailed":"GENERAL_MERCHANDISE_ONLINE_MARKETPLACES"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa02003', '00000000-0000-0000-0000-000000000003', 'u4_txn_shop_002', 'WALMART #3312', 33.47, CURRENT_DATE - INTERVAL '6 days', '{"primary":"GENERAL_MERCHANDISE","detailed":"GENERAL_MERCHANDISE_SUPERSTORES"}'),
  -- Car insurance (fixed)
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa02001', '00000000-0000-0000-0000-000000000003', 'u4_txn_ins_001', 'GEICO AUTO INS', 135.00, CURRENT_DATE - INTERVAL '16 days', '{"primary":"LOAN_PAYMENTS","detailed":"LOAN_PAYMENTS_CAR_PAYMENT"}'),
  -- Subscriptions
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa02003', '00000000-0000-0000-0000-000000000003', 'u4_txn_sub_001', 'SPOTIFY PREMIUM', 10.99, CURRENT_DATE - INTERVAL '12 days', '{"primary":"GENERAL_SERVICES","detailed":"GENERAL_SERVICES_SUBSCRIPTIONS"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa02003', '00000000-0000-0000-0000-000000000003', 'u4_txn_sub_002', 'YOUTUBE PREMIUM', 13.99, CURRENT_DATE - INTERVAL '11 days', '{"primary":"GENERAL_SERVICES","detailed":"GENERAL_SERVICES_SUBSCRIPTIONS"}'),
  -- Credit card payment
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa02001', '00000000-0000-0000-0000-000000000003', 'u4_txn_xfer_001', 'CREDIT CARD PAYMENT', 600.00, CURRENT_DATE - INTERVAL '13 days', '{"primary":"TRANSFER_OUT","detailed":"TRANSFER_OUT_ACCOUNT_TRANSFER"}');

INSERT INTO public.savings_goals (id, user_id, name, target_amount, current_amount, emoji, is_emergency_fund, priority) VALUES
  ('dddddddd-dddd-dddd-dddd-dddddddd0005', '00000000-0000-0000-0000-000000000003', 'Emergency Fund', 15000.00, 8000.00, '🛟', true, 0),
  ('dddddddd-dddd-dddd-dddd-dddddddd0006', '00000000-0000-0000-0000-000000000003', 'House Down Payment', 50000.00, 12000.00, '🏠', false, 1)
ON CONFLICT DO NOTHING;

-- ════════════════════════════════════════════════════════════════════════════
-- DEBUG USER 5 — Semimonthly Budgeter (gov employee, paid 1st & 15th)
-- ════════════════════════════════════════════════════════════════════════════

INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  confirmation_token, recovery_token,
  email_change_token_new, email_change, email_change_token_current,
  phone_change, phone_change_token, reauthentication_token,
  raw_app_meta_data, raw_user_meta_data
) VALUES (
  '00000000-0000-0000-0000-000000000004',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated',
  'debug5@flume.local',
  crypt('debug123', gen_salt('bf')),
  now(), now(), now(),
  '', '', '', '', '', '', '', '',
  '{"provider":"email","providers":["email"]}', '{}'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, display_name, onboarding_step)
VALUES ('00000000-0000-0000-0000-000000000004', 'Semimonthly Budgeter', 'complete')
ON CONFLICT (id) DO UPDATE SET display_name = EXCLUDED.display_name, onboarding_step = EXCLUDED.onboarding_step;

INSERT INTO public.plaid_items (id, user_id, plaid_item_id, access_token, institution_name)
VALUES ('11111111-1111-1111-1111-111111111114', '00000000-0000-0000-0000-000000000004', 'test_item_sandbox_005', 'access-sandbox-test-005', 'Test Federal CU')
ON CONFLICT DO NOTHING;

INSERT INTO public.accounts (id, plaid_item_id, user_id, plaid_account_id, name, type, subtype, current_balance, available_balance) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa03001', '11111111-1111-1111-1111-111111111114', '00000000-0000-0000-0000-000000000004', 'test_checking_005', 'Joint Checking', 'depository', 'checking', 7200.00, 6800.00),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa03002', '11111111-1111-1111-1111-111111111114', '00000000-0000-0000-0000-000000000004', 'test_savings_005', 'Joint Savings', 'depository', 'savings', 35000.00, 35000.00),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa03003', '11111111-1111-1111-1111-111111111114', '00000000-0000-0000-0000-000000000004', 'test_credit_005', 'Family Visa', 'credit', 'credit card', -1650.00, null)
ON CONFLICT DO NOTHING;

INSERT INTO public.account_roles (account_id, user_id, account_role) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa03001', '00000000-0000-0000-0000-000000000004', 'checking'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa03002', '00000000-0000-0000-0000-000000000004', 'savings'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa03003', '00000000-0000-0000-0000-000000000004', 'credit_card')
ON CONFLICT DO NOTHING;

INSERT INTO public.income_streams (id, user_id, name, estimated_amount, frequency, next_expected_date) VALUES
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbb0004', '00000000-0000-0000-0000-000000000004', 'State Gov Payroll', 2500.00, 'semimonthly',
    CASE WHEN EXTRACT(DAY FROM CURRENT_DATE) <= 15
      THEN DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '14 days'  -- next = 15th
      ELSE DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month'   -- next = 1st of next month
    END)
ON CONFLICT DO NOTHING;

-- Semimonthly budget periods: 1st-15th and 16th-end
INSERT INTO public.budget_periods (id, user_id, start_date, end_date, income_target, fixed_target, flex_target, savings_target, income_stream_id) VALUES
  ('cccccccc-cccc-cccc-cccc-cccccccc0007', '00000000-0000-0000-0000-000000000004',
    CASE WHEN EXTRACT(DAY FROM CURRENT_DATE) <= 15
      THEN DATE_TRUNC('month', CURRENT_DATE)                                     -- 1st
      ELSE DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '15 days'                -- 16th
    END,
    CASE WHEN EXTRACT(DAY FROM CURRENT_DATE) <= 15
      THEN DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '15 days'                -- 16th
      ELSE DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month'                -- 1st of next
    END,
    2500.00, 1250.00, 750.00, 500.00, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbb0004'),
  ('cccccccc-cccc-cccc-cccc-cccccccc0008', '00000000-0000-0000-0000-000000000004',
    CASE WHEN EXTRACT(DAY FROM CURRENT_DATE) <= 15
      THEN DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '1 month' + INTERVAL '15 days'  -- 16th of prev month
      ELSE DATE_TRUNC('month', CURRENT_DATE)                                              -- 1st of this month
    END,
    CASE WHEN EXTRACT(DAY FROM CURRENT_DATE) <= 15
      THEN DATE_TRUNC('month', CURRENT_DATE)                                              -- 1st of this month
      ELSE DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '15 days'                         -- 16th of this month
    END,
    2500.00, 1250.00, 750.00, 500.00, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbb0004')
ON CONFLICT (id) DO UPDATE SET start_date = EXCLUDED.start_date, end_date = EXCLUDED.end_date;

-- Transactions for user 5 (last ~30 days)
INSERT INTO public.transactions (account_id, user_id, plaid_transaction_id, name, amount, date, personal_finance_category) VALUES
  -- Semimonthly paychecks
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa03001', '00000000-0000-0000-0000-000000000004', 'u5_txn_income_001', 'STATE GOV PAYROLL', -2500.00, CURRENT_DATE - INTERVAL '25 days', '{"primary":"INCOME","detailed":"INCOME_WAGES"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa03001', '00000000-0000-0000-0000-000000000004', 'u5_txn_income_002', 'STATE GOV PAYROLL', -2500.00, CURRENT_DATE - INTERVAL '10 days', '{"primary":"INCOME","detailed":"INCOME_WAGES"}'),
  -- Mortgage
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa03001', '00000000-0000-0000-0000-000000000004', 'u5_txn_mort_001', 'WELLS FARGO MORTGAGE', 1350.00, CURRENT_DATE - INTERVAL '28 days', '{"primary":"LOAN_PAYMENTS","detailed":"LOAN_PAYMENTS_MORTGAGE_PAYMENT"}'),
  -- Car payment
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa03001', '00000000-0000-0000-0000-000000000004', 'u5_txn_car_001', 'TOYOTA FINANCIAL', 320.00, CURRENT_DATE - INTERVAL '22 days', '{"primary":"LOAN_PAYMENTS","detailed":"LOAN_PAYMENTS_CAR_PAYMENT"}'),
  -- Insurance
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa03001', '00000000-0000-0000-0000-000000000004', 'u5_txn_ins_001', 'STATE FARM INS', 180.00, CURRENT_DATE - INTERVAL '20 days', '{"primary":"LOAN_PAYMENTS","detailed":"LOAN_PAYMENTS_INSURANCE_PAYMENT"}'),
  -- Utilities
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa03001', '00000000-0000-0000-0000-000000000004', 'u5_txn_util_001', 'ENTERGY POWER', 142.00, CURRENT_DATE - INTERVAL '24 days', '{"primary":"RENT_AND_UTILITIES","detailed":"RENT_AND_UTILITIES_ELECTRICITY"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa03001', '00000000-0000-0000-0000-000000000004', 'u5_txn_water_001', 'CITY WATER DEPT', 48.00, CURRENT_DATE - INTERVAL '23 days', '{"primary":"RENT_AND_UTILITIES","detailed":"RENT_AND_UTILITIES_SEWAGE_AND_WASTE_MANAGEMENT"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa03001', '00000000-0000-0000-0000-000000000004', 'u5_txn_inet_001', 'COX COMMUNICATIONS', 89.99, CURRENT_DATE - INTERVAL '18 days', '{"primary":"RENT_AND_UTILITIES","detailed":"RENT_AND_UTILITIES_INTERNET"}'),
  -- Daycare
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa03001', '00000000-0000-0000-0000-000000000004', 'u5_txn_daycare_001', 'BRIGHT HORIZONS', 450.00, CURRENT_DATE - INTERVAL '26 days', '{"primary":"GENERAL_SERVICES","detailed":"GENERAL_SERVICES_CHILDCARE"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa03001', '00000000-0000-0000-0000-000000000004', 'u5_txn_daycare_002', 'BRIGHT HORIZONS', 450.00, CURRENT_DATE - INTERVAL '12 days', '{"primary":"GENERAL_SERVICES","detailed":"GENERAL_SERVICES_CHILDCARE"}'),
  -- Groceries
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa03003', '00000000-0000-0000-0000-000000000004', 'u5_txn_groc_001', 'H-E-B #0045', 112.30, CURRENT_DATE - INTERVAL '27 days', '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_GROCERIES"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa03003', '00000000-0000-0000-0000-000000000004', 'u5_txn_groc_002', 'H-E-B #0045', 95.67, CURRENT_DATE - INTERVAL '19 days', '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_GROCERIES"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa03003', '00000000-0000-0000-0000-000000000004', 'u5_txn_groc_003', 'COSTCO #223', 148.22, CURRENT_DATE - INTERVAL '13 days', '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_GROCERIES"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa03003', '00000000-0000-0000-0000-000000000004', 'u5_txn_groc_004', 'H-E-B #0045', 87.45, CURRENT_DATE - INTERVAL '5 days', '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_GROCERIES"}'),
  -- Dining
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa03003', '00000000-0000-0000-0000-000000000004', 'u5_txn_rest_001', 'MCDONALDS #8812', 18.45, CURRENT_DATE - INTERVAL '21 days', '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_RESTAURANT"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa03003', '00000000-0000-0000-0000-000000000004', 'u5_txn_rest_002', 'TEXAS ROADHOUSE', 52.80, CURRENT_DATE - INTERVAL '7 days', '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_RESTAURANT"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa03003', '00000000-0000-0000-0000-000000000004', 'u5_txn_coffee_001', 'STARBUCKS #4412', 7.25, CURRENT_DATE - INTERVAL '3 days', '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_COFFEE"}'),
  -- Gas
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa03003', '00000000-0000-0000-0000-000000000004', 'u5_txn_gas_001', 'EXXON #3321', 58.40, CURRENT_DATE - INTERVAL '16 days', '{"primary":"TRANSPORTATION","detailed":"TRANSPORTATION_GAS"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa03003', '00000000-0000-0000-0000-000000000004', 'u5_txn_gas_002', 'EXXON #3321', 55.10, CURRENT_DATE - INTERVAL '2 days', '{"primary":"TRANSPORTATION","detailed":"TRANSPORTATION_GAS"}'),
  -- Kids shopping
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa03003', '00000000-0000-0000-0000-000000000004', 'u5_txn_shop_001', 'TARGET #5501', 65.30, CURRENT_DATE - INTERVAL '15 days', '{"primary":"GENERAL_MERCHANDISE","detailed":"GENERAL_MERCHANDISE_SUPERSTORES"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa03003', '00000000-0000-0000-0000-000000000004', 'u5_txn_shop_002', 'AMAZON.COM', 38.99, CURRENT_DATE - INTERVAL '8 days', '{"primary":"GENERAL_MERCHANDISE","detailed":"GENERAL_MERCHANDISE_ONLINE_MARKETPLACES"}'),
  -- Subscriptions
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa03003', '00000000-0000-0000-0000-000000000004', 'u5_txn_sub_001', 'DISNEY PLUS', 13.99, CURRENT_DATE - INTERVAL '14 days', '{"primary":"GENERAL_SERVICES","detailed":"GENERAL_SERVICES_SUBSCRIPTIONS"}'),
  -- Credit card payment
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa03001', '00000000-0000-0000-0000-000000000004', 'u5_txn_xfer_001', 'CREDIT CARD PAYMENT', 1200.00, CURRENT_DATE - INTERVAL '11 days', '{"primary":"TRANSFER_OUT","detailed":"TRANSFER_OUT_ACCOUNT_TRANSFER"}');

INSERT INTO public.savings_goals (id, user_id, name, target_amount, current_amount, emoji, is_emergency_fund, priority) VALUES
  ('dddddddd-dddd-dddd-dddd-dddddddd0007', '00000000-0000-0000-0000-000000000004', 'Emergency Fund', 20000.00, 14000.00, '🛟', true, 0),
  ('dddddddd-dddd-dddd-dddd-dddddddd0008', '00000000-0000-0000-0000-000000000004', 'College Fund', 30000.00, 5500.00, '🎓', false, 1),
  ('dddddddd-dddd-dddd-dddd-dddddddd0009', '00000000-0000-0000-0000-000000000004', 'Family Vacation', 4000.00, 1800.00, '🏖️', false, 2)
ON CONFLICT DO NOTHING;

-- ════════════════════════════════════════════════════════════════════════════
-- DEBUG USER 6 — Overspender (monthly, over budget, edge case testing)
-- ════════════════════════════════════════════════════════════════════════════

INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  confirmation_token, recovery_token,
  email_change_token_new, email_change, email_change_token_current,
  phone_change, phone_change_token, reauthentication_token,
  raw_app_meta_data, raw_user_meta_data
) VALUES (
  '00000000-0000-0000-0000-000000000005',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated',
  'debug6@flume.local',
  crypt('debug123', gen_salt('bf')),
  now(), now(), now(),
  '', '', '', '', '', '', '', '',
  '{"provider":"email","providers":["email"]}', '{}'
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, display_name, onboarding_step)
VALUES ('00000000-0000-0000-0000-000000000005', 'Overspender', 'complete')
ON CONFLICT (id) DO UPDATE SET display_name = EXCLUDED.display_name, onboarding_step = EXCLUDED.onboarding_step;

INSERT INTO public.plaid_items (id, user_id, plaid_item_id, access_token, institution_name)
VALUES ('11111111-1111-1111-1111-111111111115', '00000000-0000-0000-0000-000000000005', 'test_item_sandbox_006', 'access-sandbox-test-006', 'Test Startup Bank')
ON CONFLICT DO NOTHING;

INSERT INTO public.accounts (id, plaid_item_id, user_id, plaid_account_id, name, type, subtype, current_balance, available_balance) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa04001', '11111111-1111-1111-1111-111111111115', '00000000-0000-0000-0000-000000000005', 'test_checking_006', 'Checking', 'depository', 'checking', 1200.00, 980.00),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa04002', '11111111-1111-1111-1111-111111111115', '00000000-0000-0000-0000-000000000005', 'test_savings_006', 'Savings', 'depository', 'savings', 500.00, 500.00),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa04003', '11111111-1111-1111-1111-111111111115', '00000000-0000-0000-0000-000000000005', 'test_credit_006', 'Rewards Card', 'credit', 'credit card', -2850.00, null)
ON CONFLICT DO NOTHING;

INSERT INTO public.account_roles (account_id, user_id, account_role) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa04001', '00000000-0000-0000-0000-000000000005', 'checking'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa04002', '00000000-0000-0000-0000-000000000005', 'savings'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa04003', '00000000-0000-0000-0000-000000000005', 'credit_card')
ON CONFLICT DO NOTHING;

INSERT INTO public.income_streams (id, user_id, name, estimated_amount, frequency, next_expected_date) VALUES
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbb0005', '00000000-0000-0000-0000-000000000005', 'Startup Inc', 3000.00, 'monthly',
    DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month')
ON CONFLICT DO NOTHING;

-- Monthly budget periods (same style as user 1)
INSERT INTO public.budget_periods (id, user_id, start_date, end_date, income_target, fixed_target, flex_target, savings_target, income_stream_id) VALUES
  ('cccccccc-cccc-cccc-cccc-cccccccc0009', '00000000-0000-0000-0000-000000000005',
    DATE_TRUNC('month', CURRENT_DATE),
    DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month',
    3000.00, 1500.00, 900.00, 600.00, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbb0005'),
  ('cccccccc-cccc-cccc-cccc-cccccccc0010', '00000000-0000-0000-0000-000000000005',
    DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '1 month',
    DATE_TRUNC('month', CURRENT_DATE),
    3000.00, 1500.00, 900.00, 600.00, 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbb0005')
ON CONFLICT (id) DO UPDATE SET start_date = EXCLUDED.start_date, end_date = EXCLUDED.end_date;

-- Transactions for user 6: OVER BUDGET in fixed and flex, no savings
INSERT INTO public.transactions (account_id, user_id, plaid_transaction_id, name, amount, date, personal_finance_category) VALUES
  -- Income (monthly paycheck)
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa04001', '00000000-0000-0000-0000-000000000005', 'u6_txn_income_001', 'STARTUP INC PAYROLL', -3000.00, CURRENT_DATE - INTERVAL '28 days', '{"primary":"INCOME","detailed":"INCOME_WAGES"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa04001', '00000000-0000-0000-0000-000000000005', 'u6_txn_income_002', 'STARTUP INC PAYROLL', -3000.00, CURRENT_DATE - INTERVAL '2 days', '{"primary":"INCOME","detailed":"INCOME_WAGES"}'),
  -- Fixed: rent (target is 1500 total, but fixed expenses will total ~1700)
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa04001', '00000000-0000-0000-0000-000000000005', 'u6_txn_rent_001', 'LUXURY LOFTS LLC', 1350.00, CURRENT_DATE - INTERVAL '27 days', '{"primary":"RENT_AND_UTILITIES","detailed":"RENT_AND_UTILITIES_RENT"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa04001', '00000000-0000-0000-0000-000000000005', 'u6_txn_rent_002', 'LUXURY LOFTS LLC', 1350.00, CURRENT_DATE - INTERVAL '1 day', '{"primary":"RENT_AND_UTILITIES","detailed":"RENT_AND_UTILITIES_RENT"}'),
  -- Fixed: utilities
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa04001', '00000000-0000-0000-0000-000000000005', 'u6_txn_util_001', 'CITY POWER CO', 118.00, CURRENT_DATE - INTERVAL '24 days', '{"primary":"RENT_AND_UTILITIES","detailed":"RENT_AND_UTILITIES_ELECTRICITY"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa04001', '00000000-0000-0000-0000-000000000005', 'u6_txn_inet_001', 'VERIZON FIOS', 89.99, CURRENT_DATE - INTERVAL '22 days', '{"primary":"RENT_AND_UTILITIES","detailed":"RENT_AND_UTILITIES_INTERNET"}'),
  -- Fixed: subscriptions stacked up
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa04003', '00000000-0000-0000-0000-000000000005', 'u6_txn_sub_001', 'SPOTIFY PREMIUM', 10.99, CURRENT_DATE - INTERVAL '20 days', '{"primary":"GENERAL_SERVICES","detailed":"GENERAL_SERVICES_SUBSCRIPTIONS"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa04003', '00000000-0000-0000-0000-000000000005', 'u6_txn_sub_002', 'NETFLIX', 15.49, CURRENT_DATE - INTERVAL '19 days', '{"primary":"GENERAL_SERVICES","detailed":"GENERAL_SERVICES_SUBSCRIPTIONS"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa04003', '00000000-0000-0000-0000-000000000005', 'u6_txn_sub_003', 'HBO MAX', 15.99, CURRENT_DATE - INTERVAL '18 days', '{"primary":"GENERAL_SERVICES","detailed":"GENERAL_SERVICES_SUBSCRIPTIONS"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa04003', '00000000-0000-0000-0000-000000000005', 'u6_txn_sub_004', 'APPLE ONE', 19.95, CURRENT_DATE - INTERVAL '17 days', '{"primary":"GENERAL_SERVICES","detailed":"GENERAL_SERVICES_SUBSCRIPTIONS"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa04003', '00000000-0000-0000-0000-000000000005', 'u6_txn_sub_005', 'CHATGPT PLUS', 20.00, CURRENT_DATE - INTERVAL '16 days', '{"primary":"GENERAL_SERVICES","detailed":"GENERAL_SERVICES_SUBSCRIPTIONS"}'),
  -- Flex: dining out heavily (target 900, will total ~1300+)
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa04003', '00000000-0000-0000-0000-000000000005', 'u6_txn_rest_001', 'NOBU RESTAURANT', 145.00, CURRENT_DATE - INTERVAL '26 days', '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_RESTAURANT"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa04003', '00000000-0000-0000-0000-000000000005', 'u6_txn_rest_002', 'DOORDASH', 42.30, CURRENT_DATE - INTERVAL '23 days', '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_RESTAURANT"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa04003', '00000000-0000-0000-0000-000000000005', 'u6_txn_rest_003', 'UBER EATS', 38.75, CURRENT_DATE - INTERVAL '21 days', '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_RESTAURANT"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa04003', '00000000-0000-0000-0000-000000000005', 'u6_txn_rest_004', 'SUSHI HOUSE', 78.50, CURRENT_DATE - INTERVAL '14 days', '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_RESTAURANT"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa04003', '00000000-0000-0000-0000-000000000005', 'u6_txn_rest_005', 'DOORDASH', 35.20, CURRENT_DATE - INTERVAL '10 days', '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_RESTAURANT"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa04003', '00000000-0000-0000-0000-000000000005', 'u6_txn_rest_006', 'UBER EATS', 29.90, CURRENT_DATE - INTERVAL '7 days', '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_RESTAURANT"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa04003', '00000000-0000-0000-0000-000000000005', 'u6_txn_rest_007', 'STARBUCKS #1199', 8.45, CURRENT_DATE - INTERVAL '5 days', '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_COFFEE"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa04003', '00000000-0000-0000-0000-000000000005', 'u6_txn_rest_008', 'STARBUCKS #1199', 7.90, CURRENT_DATE - INTERVAL '3 days', '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_COFFEE"}'),
  -- Groceries (still some but mostly eating out)
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa04003', '00000000-0000-0000-0000-000000000005', 'u6_txn_groc_001', 'WHOLE FOODS MKT', 98.50, CURRENT_DATE - INTERVAL '25 days', '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_GROCERIES"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa04003', '00000000-0000-0000-0000-000000000005', 'u6_txn_groc_002', 'WHOLE FOODS MKT', 76.30, CURRENT_DATE - INTERVAL '11 days', '{"primary":"FOOD_AND_DRINK","detailed":"FOOD_AND_DRINK_GROCERIES"}'),
  -- Shopping spree
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa04003', '00000000-0000-0000-0000-000000000005', 'u6_txn_shop_001', 'AMAZON.COM', 189.99, CURRENT_DATE - INTERVAL '15 days', '{"primary":"GENERAL_MERCHANDISE","detailed":"GENERAL_MERCHANDISE_ONLINE_MARKETPLACES"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa04003', '00000000-0000-0000-0000-000000000005', 'u6_txn_shop_002', 'BEST BUY #7741', 149.99, CURRENT_DATE - INTERVAL '12 days', '{"primary":"GENERAL_MERCHANDISE","detailed":"GENERAL_MERCHANDISE_ELECTRONICS"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa04003', '00000000-0000-0000-0000-000000000005', 'u6_txn_shop_003', 'ZARA #0221', 87.50, CURRENT_DATE - INTERVAL '9 days', '{"primary":"GENERAL_MERCHANDISE","detailed":"GENERAL_MERCHANDISE_CLOTHING_AND_ACCESSORIES"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa04003', '00000000-0000-0000-0000-000000000005', 'u6_txn_shop_004', 'AMAZON.COM', 64.99, CURRENT_DATE - INTERVAL '4 days', '{"primary":"GENERAL_MERCHANDISE","detailed":"GENERAL_MERCHANDISE_ONLINE_MARKETPLACES"}'),
  -- Entertainment
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa04003', '00000000-0000-0000-0000-000000000005', 'u6_txn_ent_001', 'AMC THEATRES', 32.00, CURRENT_DATE - INTERVAL '13 days', '{"primary":"ENTERTAINMENT","detailed":"ENTERTAINMENT_TV_AND_MOVIES"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa04003', '00000000-0000-0000-0000-000000000005', 'u6_txn_ent_002', 'STUBHUB TICKETS', 120.00, CURRENT_DATE - INTERVAL '8 days', '{"primary":"ENTERTAINMENT","detailed":"ENTERTAINMENT_SPORTING_EVENTS_AMUSEMENT_PARKS_AND_MUSEUMS"}'),
  -- Gas
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa04003', '00000000-0000-0000-0000-000000000005', 'u6_txn_gas_001', 'SHELL OIL #2211', 55.40, CURRENT_DATE - INTERVAL '18 days', '{"primary":"TRANSPORTATION","detailed":"TRANSPORTATION_GAS"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa04003', '00000000-0000-0000-0000-000000000005', 'u6_txn_gas_002', 'SHELL OIL #2211', 52.80, CURRENT_DATE - INTERVAL '6 days', '{"primary":"TRANSPORTATION","detailed":"TRANSPORTATION_GAS"}'),
  -- Rideshare
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa04003', '00000000-0000-0000-0000-000000000005', 'u6_txn_uber_001', 'UBER TRIP', 24.50, CURRENT_DATE - INTERVAL '13 days', '{"primary":"TRANSPORTATION","detailed":"TRANSPORTATION_TAXIS_AND_RIDE_SHARES"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaa04003', '00000000-0000-0000-0000-000000000005', 'u6_txn_uber_002', 'UBER TRIP', 18.75, CURRENT_DATE - INTERVAL '8 days', '{"primary":"TRANSPORTATION","detailed":"TRANSPORTATION_TAXIS_AND_RIDE_SHARES"}');

INSERT INTO public.savings_goals (id, user_id, name, target_amount, current_amount, emoji, is_emergency_fund, priority) VALUES
  ('dddddddd-dddd-dddd-dddd-dddddddd0010', '00000000-0000-0000-0000-000000000005', 'Emergency Fund', 10000.00, 500.00, '🛟', true, 0),
  ('dddddddd-dddd-dddd-dddd-dddddddd0011', '00000000-0000-0000-0000-000000000005', 'Trip to Japan', 5000.00, 200.00, '🇯🇵', false, 1)
ON CONFLICT DO NOTHING;
