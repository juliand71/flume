# Comprehensive Onboarding & API Test Plan

## Context
The onboarding flow has zero test coverage on both the iOS client and Go API server. We need comprehensive tests covering all combinations of budget periods, income types/frequencies, fixed and flex spending configurations. This plan covers:
- **Swift**: Unit tests for `OnboardingViewModel` with mocked API service
- **Go**: Unit tests for pure detection/computation logic + integration tests for all API endpoints

---

# Part 1: Swift (iOS) Tests

## 1.1 Refactoring for Testability (3 files, ~15 lines)

### Create `BudgetAPIServiceProtocol`
**New file:** `ios/Flume/Flume/Services/BudgetAPIServiceProtocol.swift`

Protocol with the 9 methods `OnboardingViewModel` calls:
`fetchOnboardingStatus`, `updateOnboardingStep`, `fetchSyncStatus`, `detectIncome`, `detectFixed`, `detectFlex`, `createIncomeStream`, `createPeriod`, `createSavingsGoal`

### Conform `BudgetAPIService`
**File:** [BudgetAPIService.swift:3](services/api/../../ios/Flume/Flume/Services/BudgetAPIService.swift#L3)
- Add `, BudgetAPIServiceProtocol` to struct declaration. No method changes needed.

### Inject dependency into OnboardingViewModel
**File:** [OnboardingViewModel.swift](ios/Flume/Flume/Features/Onboarding/OnboardingViewModel.swift)
- Line 49: `private let budgetAPI: BudgetAPIServiceProtocol`
- Add init: `init(budgetAPI: BudgetAPIServiceProtocol = BudgetAPIService.shared)`
- Line 118: `BudgetAPIService.shared` → `budgetAPI`
- Add `var dateProvider: () -> Date = { Date() }` and use it on line 257

## 1.2 Test Infrastructure

### MockBudgetAPIService
**New:** `ios/Flume/FlumeTests/Mocks/MockBudgetAPIService.swift`
- `Result<T, Error>` stubs for each method
- Call-tracking arrays (e.g. `detectIncomeCalls`, `createPeriodCalls`)

### Factories (static builders with sensible defaults)

| File | Builds |
|------|--------|
| `FlumeTests/Factories/IncomeFactory.swift` | `DetectedIncomeStream`, `IncomeDetectionResponse`, `IncomeStream` + presets: weekly/biweekly/semimonthly/monthly/multipleStreams/lowConfidence |
| `FlumeTests/Factories/FixedExpenseFactory.swift` | `DetectedFixedExpense`, `FixedDetectionResponse` + preset: typicalExpenses() |
| `FlumeTests/Factories/FlexFactory.swift` | `FlexDetectionResponse` |
| `FlumeTests/Factories/BudgetPeriodFactory.swift` | `BudgetPeriod`, `OnboardingStatus`, `SyncStatus`, `SavingsGoal` |

## 1.3 Test Suites

### Period Date Computation — `OnboardingPeriodDateTests.swift`
Pin `dateProvider` to April 10, 2026.

- Monthly: starts 1st, ends 1st of next month
- Semimonthly half 1: 1st–16th
- Semimonthly half 2: 16th–1st of next
- Biweekly with anchor in past/future/nil
- Weekly for each startDay 1–7 (`@Test(arguments: 1...7)`)
- Unknown period type → no-op

### Income Detection — `OnboardingIncomeTests.swift`
- Detect populates `detectedStreams`, `monthlyExpenseEstimate`, `dateRangeDays`
- `expandedSearch` nil → false
- `isLoading` lifecycle
- API error → `errorMessage`
- Each frequency type preserved (`@Test(arguments:)`)
- No streams, multiple streams, mixed confidence
- `confirmIncomeStream` appends / error returns nil
- Parameter verification via call tracking

### Fixed Expenses — `OnboardingFixedTests.swift`
- Detect populates expenses + `confirmedFixedTotal`
- Loading/error paths
- Nil period dates → early return (guard line 184)
- User adjustment cascades to `projectedSavings`

### Flex Spending — `OnboardingFlexTests.swift`
- Detect sets both `detectedFlexTotal` and `confirmedFlexTarget`
- `flexTransactionCount`
- Nil dates → early return (guard line 199)
- User adjusting target affects savings

### Budget Calculations — `OnboardingBudgetCalcTests.swift`
- `projectedSavings` parameterized: positive/zero/negative (`@Test(arguments:)`)
- `createBudgetFromConfirmedValues` passes correct values, stream ID, handles nil dates
- Emergency fund creation happy/error paths

### Step Navigation — `OnboardingStepNavTests.swift`
- Initial step = `.welcome`
- `loadStatus` happy/nil/error paths
- `advanceStep` progression and terminal state
- `Step.allCases` ordering contract

### Combinatorial — `OnboardingCombinationTests.swift`
**5 period configs** (monthly, semimonthly x2, biweekly, weekly) x **4 frequencies** = **20 parameterized tests**

Each: configure VM → `computePeriodDates()` → `detectIncome` → verify dates passed + stream frequency

---

# Part 2: Go API Tests

## 2.1 Refactoring for Testability (2 files)

### Extract `computeSuggestionDates` from `SuggestPeriod`
**File:** [budget_suggestion.go:56-107](services/api/internal/handler/budget_suggestion.go#L56-L107)

Extract the `switch frequency` block into a pure function:
```go
func computeSuggestionDates(today time.Time, frequency string, nextExpectedDate *string) (start, end time.Time)
```

### Extract `computeBudgetSplit`
```go
func computeBudgetSplit(incomeTarget float64) (fixed, flex, savings float64)
```

No other refactoring needed — helper functions in `income_detection.go` are already standalone and testable from same-package `_test.go` files.

## 2.2 Test File Organization

```
services/api/internal/handler/
├── income_detection_test.go     # Unit: normalizeTxnName, classifyFrequency, computePeriodAmount, median*, stddev*
├── budget_suggestion_test.go    # Unit: computeSuggestionDates, computeBudgetSplit
├── onboarding_test.go           # Unit: stepIndex
├── integration_test.go          # Integration: all endpoints (build tag: integration)
└── testhelpers_test.go          # Shared: DB setup, seed helpers, HTTP helpers
```

## 2.3 Unit Tests — Pure Functions

### `normalizeTxnName` (table-driven)
| Input | Expected |
|-------|----------|
| `"ACME CORP PAYROLL"` | `"acme corp payroll"` |
| `"SHELL OIL #4412"` | `"shell oil"` |
| `"  lots   of   spaces  "` | `"lots of spaces"` |
| `"PAYMENT 12"` | `"payment 12"` (2 digits, under 3-digit threshold) |
| `"PAYMENT 123"` | `"payment"` |
| `""` | `""` |

### `classifyFrequency` (boundary tests)
| medianDays | Expected |
|------------|----------|
| 4 | `""` |
| 5, 7, 9 | `"weekly"` |
| 10-11 | `""` (gap) |
| 12, 14, 16 | `"biweekly"` |
| 17-26 | `""` (gap) |
| 27, 30, 33 | `"monthly"` |
| 34 | `""` |

### `computePeriodAmount` (frequency x period length matrix)
| amount | frequency | periodDays | expected |
|--------|-----------|------------|----------|
| 2800 | biweekly | 14 | 2800 (1 occ) |
| 2800 | biweekly | 28 | 5600 (2 occ) |
| 5000 | monthly | 30 | 5000 |
| 1000 | weekly | 14 | 2000 |
| 3000 | semimonthly | 30 | 6000 |
| 2800 | biweekly | 1 | 2800 (clamped to 1) |

### `medianInt`, `medianFloat`, `stddevInt`
- Empty → 0
- Single element
- Odd/even lengths
- Unsorted input (medianInt sorts internally; medianFloat does NOT — document this)

### `computeSuggestionDates` (parameterized)
| today | frequency | nextExpected | start | end |
|-------|-----------|--------------|-------|-----|
| 2026-04-15 | monthly | nil | 04-01 | 05-01 |
| 2026-04-15 | biweekly | "2026-04-20" | 04-06 | 04-20 |
| 2026-04-15 | biweekly | nil | 04-15 | 04-29 |
| 2026-04-10 | semimonthly | nil | 04-01 | 04-16 |
| 2026-04-20 | semimonthly | nil | 04-16 | 05-01 |
| 2026-04-15 | weekly | "2026-04-18" | 04-11 | 04-18 |
| 2026-04-15 | "garbage" | nil | 04-01 | 05-01 (monthly fallback) |

### `computeBudgetSplit`
| income | fixed (50%) | flex (30%) | savings (20%) |
|--------|-------------|------------|---------------|
| 5000 | 2500 | 1500 | 1000 |
| 0 | 0 | 0 | 0 |
| 100.01 | 50.01 | 30.00 | 20.00 |

### `stepIndex`
- Each valid step returns correct index (0–9)
- Invalid step → -1
- Ordering is strictly increasing

## 2.4 Integration Test Infrastructure

### Build tag
```go
//go:build integration
```
Run with: `go test -tags integration ./internal/handler/`

### `testhelpers_test.go`
- `setupTestDB(t) *pgxpool.Pool` — connects via `TEST_DATABASE_URL`, uses `t.Cleanup` to truncate tables after each test
- `seedUser(t, pool, userID)` — inserts into `auth.users` + `profiles`
- `seedAccount(t, pool, userID) accountID` — inserts plaid_item + account
- `seedTransactions(t, pool, userID, accountID, []testTxn)` — bulk inserts with specified amounts/dates/categories
- `seedIncomeStream(t, pool, userID, ...)` / `seedBudgetPeriod(...)` / `seedSavingsGoal(...)`
- `seedCategoryMappings(t, pool)` — system default mappings
- `makeRequest(method, path, body, userID) *http.Request` — builds request with auth context injected
- `execHandler(t, handler, req) *httptest.ResponseRecorder`

### Test Fixtures
Defined as Go structs:
- **Biweekly income**: 4 txns @ -2800, 14-day intervals → expect freq=biweekly, confidence=high
- **Monthly income**: 3 txns @ -1500, 30-day intervals
- **Weekly income**: 5 txns @ -400, 7-day intervals
- **Mixed expenses**: rent (fixed) + groceries (flex) + income
- **Transfer pair**: opposite amounts on different accounts within 1 day

## 2.5 Integration Tests — All Endpoints

### Onboarding
- `GET /onboarding/status` — returns step + boolean flags matching seed state
- `PATCH /onboarding/step` — forward advance works, backward returns 400, invalid step returns 400

### Accounts
- `GET /budget/accounts` — returns seeded accounts with roles
- `PATCH /budget/accounts/{id}/role` — sets role, invalid role 400, wrong user 404

### Income Streams (CRUD)
- POST valid → 201, missing name → 400, invalid frequency → 400, amount ≤ 0 → 400
- GET → returns active only
- PATCH partial update, invalid freq → 400
- DELETE → 204, subsequent GET excludes it

### Budget Periods
- POST valid → 201, end ≤ start → 400
- GET current-period → returns period with actuals
- GET periods → paginated, ordered by start_date DESC
- PATCH → partial target update

### Detection Endpoints
- `GET /budget/detect-income` — seed biweekly paycheck txns → returns detected stream with correct frequency/confidence/amount
- `GET /budget/detect-income` with date range returning nothing → expands search, `expanded_search=true`
- `GET /budget/detect-fixed` — seed fixed txns → grouped by name, sorted by total desc
- `GET /budget/detect-flex` — seed flex txns → returns total + count
- Missing date params → 400

### Budget Suggestion
- `POST /budget/suggest-period` for each frequency (monthly/biweekly/semimonthly/weekly) → correct dates + 50/30/20 split
- Missing stream ID → 400, nonexistent → 404

### Transactions
- GET filtered by period + optional category
- POST override → changes budget_category
- Invalid category → 400, wrong user → 404

### Category Mappings
- GET → returns system + user mappings
- POST → creates user mapping, upserts on duplicate

### Category Summary
- Seed period + transactions → correct actuals vs targets per category + surplus
- No active period → 404

### Savings Goals (CRUD + fill)
- POST/GET/PATCH/DELETE standard flows
- `POST /budget/savings-goals/fill` → atomic batch update of current_amount
- Fill with invalid goal → 404 + rollback

### Sync Status
- With/without plaid items → correct booleans + count

### End-to-End Onboarding Flow (single test)
Walk through the full onboarding: status → advance steps → seed bank data → detect income/fixed/flex → create stream → create period → create goal → complete

---

# File Summary

### Swift — Production Changes (3 files)
- `ios/Flume/Flume/Services/BudgetAPIServiceProtocol.swift` (new)
- `ios/Flume/Flume/Services/BudgetAPIService.swift` (1 line)
- `ios/Flume/Flume/Features/Onboarding/OnboardingViewModel.swift` (~5 lines)

### Swift — Test Files (12 new)
- `ios/Flume/FlumeTests/Mocks/MockBudgetAPIService.swift`
- `ios/Flume/FlumeTests/Factories/{Income,FixedExpense,Flex,BudgetPeriod}Factory.swift`
- `ios/Flume/FlumeTests/Onboarding/{PeriodDate,Income,Fixed,Flex,BudgetCalc,StepNav,Combination}Tests.swift`

### Go — Production Changes (1 file)
- `services/api/internal/handler/budget_suggestion.go` — extract `computeSuggestionDates` + `computeBudgetSplit`

### Go — Test Files (4 new)
- `services/api/internal/handler/income_detection_test.go`
- `services/api/internal/handler/budget_suggestion_test.go`
- `services/api/internal/handler/onboarding_test.go`
- `services/api/internal/handler/integration_test.go` (includes `testhelpers_test.go` or separate file)

---

# Verification

### Swift
```bash
xcodebuild test -scheme Flume -destination 'platform=iOS Simulator,name=iPhone 16'
```
All tests pass with zero network calls (mock only). App behavior unchanged.

### Go Unit Tests
```bash
cd services/api && go test ./internal/handler/
```

### Go Integration Tests
```bash
cd services/api && TEST_DATABASE_URL="postgresql://..." go test -tags integration ./internal/handler/ -v
```
Requires local Supabase running (`supabase start`).
