-- Budgeting engine: reservoirs, category mappings, savings buckets, account roles

-- ── New columns on transactions ────────────────────────────────────────────

alter table public.transactions
  add column reservoir_override text
    check (reservoir_override in ('income','fixed','flex','savings','transfer','ignore')),
  add column personal_finance_category jsonb;

-- ── budget_periods ─────────────────────────────────────────────────────────

create table public.budget_periods (
  id uuid not null default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  start_date date not null,
  end_date date not null,
  income_target numeric not null default 0,
  fixed_target numeric not null default 0,
  savings_target numeric not null default 0,
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
  reservoir text not null check (reservoir in ('income','fixed','flex','savings','transfer','ignore')),
  created_at timestamptz not null default now(),

  constraint category_mappings_pkey primary key (id),
  constraint category_mappings_unique unique (user_id, plaid_primary_category, plaid_detailed_category)
);

create index idx_category_mappings_user_id on public.category_mappings (user_id);

-- ── System default category mappings (user_id = null) ──────────────────────

insert into public.category_mappings (user_id, plaid_primary_category, plaid_detailed_category, reservoir) values
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

-- ── savings_buckets ────────────────────────────────────────────────────────

create table public.savings_buckets (
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

  constraint savings_buckets_pkey primary key (id)
);

create index idx_savings_buckets_user_id on public.savings_buckets (user_id);

-- ── account_reservoir_roles ────────────────────────────────────────────────

create table public.account_reservoir_roles (
  id uuid not null default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  reservoir_role text not null check (reservoir_role in ('income_and_fixed','flex_spending','savings')),
  created_at timestamptz not null default now(),

  constraint account_reservoir_roles_pkey primary key (id),
  constraint account_reservoir_roles_account_unique unique (account_id)
);

create index idx_account_reservoir_roles_user_id on public.account_reservoir_roles (user_id);

-- ── RLS ────────────────────────────────────────────────────────────────────

alter table public.budget_periods enable row level security;
alter table public.category_mappings enable row level security;
alter table public.savings_buckets enable row level security;
alter table public.account_reservoir_roles enable row level security;

-- budget_periods
create policy "Users can read own budget periods"
  on public.budget_periods for select
  using (auth.uid() = user_id);

-- category_mappings: users can read system defaults (user_id is null) + their own
create policy "Users can read category mappings"
  on public.category_mappings for select
  using (user_id is null or auth.uid() = user_id);

-- savings_buckets
create policy "Users can read own savings buckets"
  on public.savings_buckets for select
  using (auth.uid() = user_id);

-- account_reservoir_roles
create policy "Users can read own account roles"
  on public.account_reservoir_roles for select
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

-- savings_buckets
grant select on public.savings_buckets to authenticated;
grant all on public.savings_buckets to service_role;

-- account_reservoir_roles
grant select on public.account_reservoir_roles to authenticated;
grant all on public.account_reservoir_roles to service_role;
