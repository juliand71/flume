-- Add 'choose_period' to onboarding_step CHECK constraint

-- Drop the auto-generated check constraint on onboarding_step
-- (Postgres names inline column checks as: {table}_{column}_check)
alter table public.profiles
  drop constraint profiles_onboarding_step_check;

alter table public.profiles
  add constraint profiles_onboarding_step_check
    check (onboarding_step in (
      'welcome', 'link_bank', 'syncing', 'choose_period',
      'confirm_income', 'create_budget', 'savings_goal', 'complete'
    ));
