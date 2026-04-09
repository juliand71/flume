-- Seed data for local development
-- Debug user UUID matches auth.DebugUserID in Go API

-- ── Debug user in Supabase Auth ─────────────────────────────────────────────

INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at, confirmation_token,
  raw_app_meta_data, raw_user_meta_data
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated',
  'debug@flume.local',
  crypt('debug123', gen_salt('bf')),
  now(), now(), now(), '',
  '{"provider":"email","providers":["email"]}',
  '{}'
) ON CONFLICT (id) DO NOTHING;

-- Profile with onboarding complete and a realistic data set loaded
INSERT INTO public.profiles (id, display_name, onboarding_step)
VALUES ('00000000-0000-0000-0000-000000000000', 'Debug User', 'complete')
ON CONFLICT (id) DO NOTHING;

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
