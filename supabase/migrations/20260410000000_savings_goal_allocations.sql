-- Track which savings goal fills came from which budget period

create table public.savings_goal_allocations (
  id uuid not null default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  budget_period_id uuid not null references public.budget_periods(id) on delete cascade,
  savings_goal_id uuid not null references public.savings_goals(id) on delete cascade,
  amount numeric not null check (amount > 0),
  created_at timestamptz not null default now(),

  constraint savings_goal_allocations_pkey primary key (id)
);

create index idx_sga_user_period on public.savings_goal_allocations (user_id, budget_period_id);

-- ── RLS ────────────────────────────────────────────────────────────────────

alter table public.savings_goal_allocations enable row level security;

create policy "Users can read own savings goal allocations"
  on public.savings_goal_allocations for select
  using (auth.uid() = user_id);

-- ── Grants ─────────────────────────────────────────────────────────────────

grant select on public.savings_goal_allocations to authenticated;
grant all on public.savings_goal_allocations to service_role;
