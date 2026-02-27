-- RLS, tightened grants, and profile auto-creation trigger

-- ── Enable RLS ──────────────────────────────────────────────────────────────
alter table public.profiles enable row level security;
alter table public.plaid_items enable row level security;
alter table public.accounts enable row level security;
alter table public.transactions enable row level security;

-- ── RLS policies ────────────────────────────────────────────────────────────

-- profiles
create policy "Users can read own profile"
  on public.profiles for select
  using (auth.uid() = id);

create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = id);

-- plaid_items
create policy "Users can read own plaid items"
  on public.plaid_items for select
  using (auth.uid() = user_id);

-- accounts
create policy "Users can read own accounts"
  on public.accounts for select
  using (auth.uid() = user_id);

-- transactions
create policy "Users can read own transactions"
  on public.transactions for select
  using (auth.uid() = user_id);

-- ── Tighten grants ─────────────────────────────────────────────────────────
-- Revoke the broad defaults, then grant only what each role needs.
-- service_role bypasses RLS so it keeps full access.

-- anon: no access to anything except profiles (for signup edge cases)
revoke all on public.plaid_items from anon;
revoke all on public.accounts from anon;
revoke all on public.transactions from anon;
revoke insert, update, delete, truncate, references, trigger on public.profiles from anon;

-- authenticated: read-only (all writes go through the Railway service)
revoke all on public.plaid_items from authenticated;
grant select on public.plaid_items to authenticated;

revoke all on public.accounts from authenticated;
grant select on public.accounts to authenticated;

revoke all on public.transactions from authenticated;
grant select on public.transactions to authenticated;

revoke insert, delete, truncate, references, trigger on public.profiles from authenticated;
grant select, update on public.profiles to authenticated;

-- ── Auto-create profile on signup ───────────────────────────────────────────
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id)
  values (new.id);
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
