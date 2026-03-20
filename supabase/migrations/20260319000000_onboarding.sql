-- Onboarding step tracking

-- ── Add onboarding_step to profiles ──────────────────────────────────────────

alter table public.profiles
  add column onboarding_step text
    check (onboarding_step in (
      'welcome', 'link_bank', 'syncing', 'confirm_income',
      'create_budget', 'savings_goal', 'complete'
    ));

-- Existing users keep NULL (treated as onboarding complete).
-- New users start at 'welcome' via the updated trigger below.

-- ── Update profile auto-creation trigger ─────────────────────────────────────

create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, onboarding_step)
  values (new.id, 'welcome');
  return new;
end;
$$ language plpgsql security definer;
