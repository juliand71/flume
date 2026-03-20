# First-Launch Onboarding Flow

## Context

The app currently drops authenticated users into empty tab views with no guidance. New users have to independently discover they need to: link a bank → wait for sync → create income streams → create a budget period → set up savings goals. This plan adds a guided, tracked, resumable onboarding flow that walks users through each step.

## Onboarding Steps

```
Splash → Login/Signup → Welcome → Link Bank → Syncing → Confirm Income → Create Budget → Emergency Fund → Complete → MainTabView
```

| Step | What happens | New work needed |
|------|-------------|-----------------|
| **Splash** | Simple logo fade-in/scale (~1.5s), every cold launch | New `SplashView` in `FlumeApp.swift` |
| **Login/Signup** | Existing auth flow, no changes | None |
| **Welcome** | "Welcome to Flume" + Get Started button | New view |
| **Link Bank** | Guided Plaid prompt, reuses `PlaidLinkFlow` | New view wrapping existing components |
| **Syncing** | Animated loading, polls `GET /budget/sync-status` every 3s | New backend endpoint + new view |
| **Confirm Income** | Backend detects recurring income from transactions, user confirms/edits | New backend endpoint (income detection algorithm) + new view |
| **Create Budget** | Backend suggests period dates + 50/30/20 targets based on income stream, user adjusts | New backend endpoint + new view, calls existing `POST /budget/periods` |
| **Emergency Fund** | Suggest savings goal at 3x monthly expenses, user adjusts or skips | New view, calls existing `POST /budget/savings-goals` |

## Database Migration

**File:** `supabase/migrations/20260319000000_onboarding.sql`

1. Add `onboarding_step text` column to `profiles` with CHECK constraint for valid values (`welcome`, `link_bank`, `syncing`, `confirm_income`, `create_budget`, `savings_goal`, `complete`)
2. Replace `handle_new_user()` trigger function to set `onboarding_step = 'welcome'` for new signups
3. Existing users keep `NULL` (treated as onboarding complete — no disruption)

## New Backend Endpoints (Go)

All follow existing handler pattern: closure returning `http.HandlerFunc`, `auth.UserID(r.Context())`, `pgxpool.Pool`.

### `GET /onboarding/status` — `handler/onboarding.go`
Returns current step + contextual booleans (has_plaid_items, transaction_count, has_income_streams, has_budget_period, has_savings_goal). Single query joining profiles with existence checks. Allows client to handle edge cases (e.g., user already linked bank in a previous partial attempt).

### `PATCH /onboarding/step` — `handler/onboarding.go`
Advances step. Body: `{"step": "confirm_income"}`. Validates forward-only transitions. Updates `profiles.onboarding_step`.

### `GET /budget/sync-status` — `handler/sync_status.go`
Returns `{has_plaid_items, transaction_count}`. Polled by the syncing screen.

### `GET /budget/detect-income` — `handler/income_detection.go`
**Income detection algorithm:**
1. Query transactions where `personal_finance_category->>'primary' = 'INCOME'` and `amount < 0` (Plaid convention)
2. Group by normalized name (lowercase, strip trailing digits/IDs)
3. For groups with 2+ occurrences: compute median interval between dates, classify frequency (weekly ~7d, biweekly ~14d, semimonthly clusters around 1st/15th, monthly ~30d)
4. Return detected streams with name, estimated_amount (median absolute), frequency, next_expected_date, confidence (high: 4+ occurrences + low stddev, medium: 2-3, low: 2 or high variance)
5. Also compute `monthly_expense_estimate` (sum of positive amounts / months of data) for emergency fund suggestion

**Edge cases:** No income detected → empty array, client shows manual entry form. < 30 days data → include `date_range_days` so client can warn.

### `POST /budget/suggest-period` — `handler/budget_suggestion.go`
Body: `{"income_stream_id": "uuid"}`. Looks up income stream frequency/amount, computes period dates:
- monthly: 1st→1st
- biweekly: last pay date→+14d
- semimonthly: 1st→16th or 16th→1st
- weekly: last pay date→+7d

Suggests 50/30/20 split (fixed/flex/savings) of income as targets.

### Route registration in `services/api/cmd/server/main.go`
Add all 4 new routes inside the authenticated `r.Group` block.

## New iOS Files

All under `ios/Flume/Flume/Features/Onboarding/`:

| File | Purpose |
|------|---------|
| `OnboardingViewModel.swift` | @Observable state machine. Holds current step, step-specific data. Methods: `loadStatus()`, `advanceStep()`, `pollSyncStatus()`, `detectIncome()`, `confirmIncomeStreams()`, `fetchBudgetSuggestion()`, `createBudgetPeriod()`, `createEmergencyFund()` |
| `OnboardingContainerView.swift` | Switch on `viewModel.currentStep`, renders the correct step view with transition animations |
| `SplashView.swift` | Logo fade-in + scale animation, ~1.5s |
| `WelcomeStepView.swift` | Welcome message + "Get Started" button |
| `LinkBankStepView.swift` | Explanatory text + reuses `PlaidLinkFlow`. On Plaid success: advance to syncing step immediately, fire token exchange in background Task |
| `SyncingStepView.swift` | Animated loading. Polls `GET /budget/sync-status` every 3s. Auto-advances when `transaction_count > 0`. Shows "taking longer than expected" at 60s, option to skip at 120s |
| `IncomeConfirmStepView.swift` | Calls `detectIncome()` on appear. Lists detected streams (editable name/amount/frequency). Add/delete streams. "Confirm" creates income streams via existing `POST /budget/income-streams` |
| `BudgetSetupStepView.swift` | Calls `suggestPeriod()` with primary income stream. Shows suggested dates + targets (all editable). "Create Budget" calls existing `POST /budget/periods` |
| `SavingsGoalStepView.swift` | Suggests emergency fund at 3x `monthlyExpenseEstimate`. User adjusts target. "Create" or "Skip" both advance to complete |

New models under `ios/Flume/Flume/Models/`:
- `OnboardingStatus.swift` — Decodable for `/onboarding/status`
- `DetectedIncome.swift` — Decodable for `/budget/detect-income` and `/budget/suggest-period`

## Modified iOS Files

### `RootView.swift`
Three-way routing: unauthenticated → `LoginView` | onboarding incomplete → `OnboardingContainerView` | else → `MainTabView`. Fetches onboarding status on auth state change. `OnboardingContainerView` takes an `onComplete` closure to transition to `MainTabView`.

### `FlumeApp.swift`
Add `@State showSplash = true`. Show `SplashView` overlay on launch, dismiss after animation completes (~2s), then show `RootView`. Independent of auth state.

### `BudgetAPIService.swift`
Add 5 methods: `fetchOnboardingStatus`, `updateOnboardingStep`, `fetchSyncStatus`, `detectIncome`, `suggestPeriod`.

## Implementation Order

1. **Database migration** — `onboarding_step` column + trigger update
2. **Backend endpoints** — onboarding.go, sync_status.go, income_detection.go, budget_suggestion.go + route registration
3. **iOS models** — OnboardingStatus.swift, DetectedIncome.swift
4. **iOS API methods** — BudgetAPIService additions
5. **iOS views** — OnboardingViewModel → individual step views → OnboardingContainerView
6. **iOS integration** — RootView changes, FlumeApp splash
7. **End-to-end test** — Fresh signup through complete onboarding

## Verification

1. Create a fresh Supabase user → verify `profiles.onboarding_step = 'welcome'`
2. Run Go API locally, hit each new endpoint with curl to verify responses
3. Build iOS app, sign up with new account → verify onboarding flow starts
4. Complete each step, kill the app mid-flow → verify it resumes at correct step
5. Verify existing users (NULL onboarding_step) go straight to MainTabView
