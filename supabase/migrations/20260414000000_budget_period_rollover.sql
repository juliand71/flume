-- Budget period rollover, deficit handling & savings transactions

-- A1: Link transactions to savings goals
ALTER TABLE public.transactions
  ADD COLUMN savings_goal_id uuid REFERENCES public.savings_goals(id) ON DELETE SET NULL;

-- Recreate the view so it picks up the new savings_goal_id column.
-- The view uses t.* which snapshots columns at creation time.
DROP VIEW IF EXISTS public.transactions_with_category;
CREATE VIEW public.transactions_with_category AS
SELECT t.*,
  coalesce(
    t.category_override,
    ucm.budget_category,
    scm.budget_category,
    'flex'
  ) AS budget_category
FROM public.transactions t
LEFT JOIN public.category_mappings ucm
  ON ucm.user_id = t.user_id
  AND ucm.plaid_primary_category = t.personal_finance_category->>'primary'
  AND (ucm.plaid_detailed_category = t.personal_finance_category->>'detailed'
       OR ucm.plaid_detailed_category IS NULL)
LEFT JOIN public.category_mappings scm
  ON scm.user_id IS NULL
  AND scm.plaid_primary_category = t.personal_finance_category->>'primary'
  AND (scm.plaid_detailed_category = t.personal_finance_category->>'detailed'
       OR scm.plaid_detailed_category IS NULL);

-- Re-grant access after view recreation
GRANT SELECT ON public.transactions_with_category TO authenticated;
GRANT SELECT ON public.transactions_with_category TO service_role;

-- B1: Track carryover between budget periods
ALTER TABLE public.budget_periods
  ADD COLUMN carryover_amount numeric NOT NULL DEFAULT 0;

-- B1: Support withdrawals from savings goals (for deficit coverage)
ALTER TABLE public.savings_goal_allocations
  ADD COLUMN type text NOT NULL DEFAULT 'fill'
  CHECK (type IN ('fill', 'withdrawal'));

-- Allow withdrawal allocations to have negative amounts (they reduce goal balance)
ALTER TABLE public.savings_goal_allocations
  DROP CONSTRAINT IF EXISTS savings_goal_allocations_amount_check;

ALTER TABLE public.savings_goal_allocations
  ADD CONSTRAINT savings_goal_allocations_amount_check CHECK (
    (type = 'fill' AND amount > 0) OR
    (type = 'withdrawal' AND amount > 0)
  );
