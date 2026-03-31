-- Revamp onboarding steps: replace create_budget with confirm_fixed, confirm_flex, review_savings

alter table public.profiles
  drop constraint profiles_onboarding_step_check;

alter table public.profiles
  add constraint profiles_onboarding_step_check
    check (onboarding_step in (
      'welcome', 'link_bank', 'syncing', 'choose_period',
      'confirm_income', 'confirm_fixed', 'confirm_flex',
      'review_savings', 'savings_goal', 'complete'
    ));

-- Migrate users stuck on removed step
update public.profiles
  set onboarding_step = 'confirm_fixed'
  where onboarding_step = 'create_budget';
