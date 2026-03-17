-- Budgeting engine: budget categories, category mappings, savings goals, account roles, income streams

-- ── New columns on transactions ────────────────────────────────────────────

alter table public.transactions
  add column category_override text
    check (category_override in ('income','fixed','flex','savings','transfer','ignore')),
  add column personal_finance_category jsonb;

-- ── income_streams ───────────────────────────────────────────────────────────

create table public.income_streams (
  id uuid not null default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  estimated_amount numeric not null,
  frequency text not null check (frequency in ('weekly','biweekly','semimonthly','monthly')),
  next_expected_date date,
  active boolean not null default true,
  created_at timestamptz not null default now(),

  constraint income_streams_pkey primary key (id)
);

create index idx_income_streams_user_id on public.income_streams (user_id);

-- ── budget_periods ─────────────────────────────────────────────────────────

create table public.budget_periods (
  id uuid not null default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  start_date date not null,
  end_date date not null,
  income_target numeric not null default 0,
  fixed_target numeric not null default 0,
  flex_target numeric not null default 0,
  savings_target numeric not null default 0,
  income_stream_id uuid references public.income_streams(id),
  created_at timestamptz not null default now(),

  constraint budget_periods_pkey primary key (id),
  constraint budget_periods_user_start_unique unique (user_id, start_date)
);

create index idx_budget_periods_user_id on public.budget_periods (user_id);

-- ── category_mappings ──────────────────────────────────────────────────────

create table public.category_mappings (
  id uuid not null default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade, -- null = system default
  plaid_primary_category text not null,
  plaid_detailed_category text,
  budget_category text not null check (budget_category in ('income','fixed','flex','savings','transfer','ignore')),
  created_at timestamptz not null default now(),

  constraint category_mappings_pkey primary key (id),
  constraint category_mappings_unique unique (user_id, plaid_primary_category, plaid_detailed_category)
);

create index idx_category_mappings_user_id on public.category_mappings (user_id);

-- ── System default category mappings (user_id = null) ──────────────────────

insert into public.category_mappings (user_id, plaid_primary_category, plaid_detailed_category, budget_category) values
  -- Income
  (null, 'INCOME', null, 'income'),
  -- Fixed expenses
  (null, 'RENT_AND_UTILITIES', null, 'fixed'),
  (null, 'LOAN_PAYMENTS', null, 'fixed'),
  (null, 'HOME_IMPROVEMENT', null, 'fixed'),
  -- Flex spending
  (null, 'FOOD_AND_DRINK', null, 'flex'),
  (null, 'GENERAL_MERCHANDISE', null, 'flex'),
  (null, 'ENTERTAINMENT', null, 'flex'),
  (null, 'PERSONAL_CARE', null, 'flex'),
  (null, 'GENERAL_SERVICES', null, 'flex'),
  (null, 'TRANSPORTATION', null, 'flex'),
  (null, 'TRAVEL', null, 'flex'),
  (null, 'MEDICAL', null, 'flex'),
  (null, 'GOVERNMENT_AND_NON_PROFIT', null, 'flex'),
  -- Transfers
  (null, 'TRANSFER_IN', null, 'transfer'),
  (null, 'TRANSFER_OUT', null, 'transfer'),
  (null, 'BANK_FEES', null, 'fixed');

-- ── savings_goals ────────────────────────────────────────────────────────────

create table public.savings_goals (
  id uuid not null default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  target_amount numeric not null default 0,
  current_amount numeric not null default 0,
  emoji text,
  is_emergency_fund boolean not null default false,
  priority integer not null default 0,
  archived boolean not null default false,
  created_at timestamptz not null default now(),

  constraint savings_goals_pkey primary key (id)
);

create index idx_savings_goals_user_id on public.savings_goals (user_id);

-- ── account_roles ────────────────────────────────────────────────────────────

create table public.account_roles (
  id uuid not null default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  account_role text not null check (account_role in ('checking','savings','credit_card')),
  created_at timestamptz not null default now(),

  constraint account_roles_pkey primary key (id),
  constraint account_roles_account_unique unique (account_id)
);

create index idx_account_roles_user_id on public.account_roles (user_id);

-- ── transactions_with_category view ──────────────────────────────────────────

create view public.transactions_with_category as
select t.*,
  coalesce(
    t.category_override,
    ucm.budget_category,  -- user mapping
    scm.budget_category,  -- system mapping
    'flex'                -- fallback
  ) as budget_category
from public.transactions t
left join public.category_mappings ucm
  on ucm.user_id = t.user_id
  and ucm.plaid_primary_category = t.personal_finance_category->>'primary'
  and (ucm.plaid_detailed_category = t.personal_finance_category->>'detailed'
       or ucm.plaid_detailed_category is null)
left join public.category_mappings scm
  on scm.user_id is null
  and scm.plaid_primary_category = t.personal_finance_category->>'primary'
  and (scm.plaid_detailed_category = t.personal_finance_category->>'detailed'
       or scm.plaid_detailed_category is null);

-- ── RLS ────────────────────────────────────────────────────────────────────

alter table public.budget_periods enable row level security;
alter table public.category_mappings enable row level security;
alter table public.savings_goals enable row level security;
alter table public.account_roles enable row level security;
alter table public.income_streams enable row level security;

-- budget_periods
create policy "Users can read own budget periods"
  on public.budget_periods for select
  using (auth.uid() = user_id);

-- category_mappings: users can read system defaults (user_id is null) + their own
create policy "Users can read category mappings"
  on public.category_mappings for select
  using (user_id is null or auth.uid() = user_id);

-- savings_goals
create policy "Users can read own savings goals"
  on public.savings_goals for select
  using (auth.uid() = user_id);

-- account_roles
create policy "Users can read own account roles"
  on public.account_roles for select
  using (auth.uid() = user_id);

-- income_streams
create policy "Users can read own income streams"
  on public.income_streams for select
  using (auth.uid() = user_id);

-- ── Grants ─────────────────────────────────────────────────────────────────
-- authenticated: read-only (writes go through Railway service)
-- service_role: full access (bypasses RLS)

-- budget_periods
grant select on public.budget_periods to authenticated;
grant all on public.budget_periods to service_role;

-- category_mappings
grant select on public.category_mappings to authenticated;
grant all on public.category_mappings to service_role;

-- savings_goals
grant select on public.savings_goals to authenticated;
grant all on public.savings_goals to service_role;

-- account_roles
grant select on public.account_roles to authenticated;
grant all on public.account_roles to service_role;

-- income_streams
grant select on public.income_streams to authenticated;
grant all on public.income_streams to service_role;

-- transactions_with_category view
grant select on public.transactions_with_category to authenticated;
grant select on public.transactions_with_category to service_role;
