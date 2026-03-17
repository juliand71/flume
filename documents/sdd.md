# Flume -- Software Design Document

## Context

Flume is a personal finance app with three components:

- **iOS client** — SwiftUI
- **Sync service** — TypeScript/Fastify, owns all Plaid interactions and the data pipeline
- **API service** — Go, serves budget data and handles user actions
- **Database** — Supabase (hosted Postgres)

The budgeting engine is the major feature: users will see their income arrive, watch fixed expenses drain out, and distribute what remains into savings goals. The backend, database, and API use **conventional financial terminology**. The iOS user experience is themed around **water** -- money flows, pools, and fills -- but water names are applied only at the frontend display layer.

**Scope:** Checking, savings, and credit card accounts only.

---

## 1. Service Architecture

The backend is split into two independently deployed services that communicate through the shared Postgres database. No direct service-to-service calls.

### 1a. Sync Service — TypeScript/Fastify (`services/sync`)

**Role:** Plaid-facing, event-driven. A dumb data pipeline that syncs raw Plaid data into Postgres and nothing else. No budget logic.

**Responsibilities:**
- Plaid Link token generation and public token exchange
- Incremental transaction sync via `transactionsSync()` + account balance updates
- Store `personal_finance_category` from Plaid on each transaction
- Plaid webhook ingestion and verification
- Auto-assign account roles (checking/savings/credit_card) on account link

**Why TypeScript:** The Plaid Node SDK (`plaid` npm package) is first-party and well-maintained. The existing sync code is already written and tested in TypeScript.

### 1b. API Service — Go (`services/api`)

**Role:** User-facing, request-driven. Owns all budget domain logic.

**Responsibilities:**
- Budget period CRUD (user creates and manages their own budget periods)
- Compute period actuals on read (aggregate transactions within period date range)
- Income stream management (user defines their income sources)
- Category mapping management
- Savings goal CRUD and surplus distribution
- Account role management
- Transaction category overrides

**Stack:**
- Router: `net/http` with `chi` (lightweight, stdlib-compatible)
- Database: `pgx` (direct Postgres, no ORM)
- Auth: Manual JWT validation of Supabase tokens (`golang-jwt/jwt`)
- Config: environment variables

**Why Go:** The API service is pure CRUD + budget math over Postgres — a workload Go excels at. Using a different language from the sync service enforces a real service boundary. Direct `pgx` usage teaches Postgres fundamentals rather than abstracting them behind an SDK.

### 1c. Database as Contract

With two languages, the Postgres schema is the shared contract between services. Both services define their own structs/types that map to the same tables. There are no shared code packages — the schema and its migrations (managed in `supabase/migrations/`) are the single source of truth.

**Write ownership** (each table has one owner to avoid contention):

| Owner | Tables |
|---|---|
| Sync service | `plaid_items`, `accounts`, `transactions` (raw Plaid data) |
| API service | `budget_periods`, `income_streams`, `savings_goals`, `category_mappings`, `account_roles`, `transactions.category_override` |

Both services read from all tables freely.

### 1d. Project Layout

```
flume/
├── ios/                      # SwiftUI app
├── services/
│   ├── sync/                 # TypeScript/Fastify (migrated from service/)
│   │   ├── src/
│   │   │   ├── index.ts
│   │   │   ├── lib/
│   │   │   │   ├── plaid.ts
│   │   │   │   ├── supabase.ts
│   │   │   │   ├── auth.ts
│   │   │   │   ├── sync.ts
│   │   │   │   └── webhook-verify.ts
│   │   │   └── routes/
│   │   │       ├── link.ts
│   │   │       ├── exchange.ts
│   │   │       ├── sync.ts
│   │   │       └── webhooks.ts
│   │   ├── package.json
│   │   └── tsconfig.json
│   └── api/                  # Go
│       ├── cmd/
│       │   └── server/
│       │       └── main.go
│       ├── internal/
│       │   ├── auth/
│       │   │   └── jwt.go         # Supabase JWT validation
│       │   ├── db/
│       │   │   └── db.go          # pgx pool setup
│       │   ├── handler/
│       │   │   ├── periods.go
│       │   │   ├── transactions.go
│       │   │   ├── income_streams.go
│       │   │   ├── savings_goals.go
│       │   │   ├── categories.go
│       │   │   └── accounts.go
│       │   └── model/
│       │       ├── period.go
│       │       ├── transaction.go
│       │       ├── savings_goal.go
│       │       └── category.go
│       ├── go.mod
│       └── go.sum
├── supabase/                 # migrations (shared contract)
└── documents/
```

### 1e. Communication Pattern

```
                    ┌──────────────────┐
  Plaid ──webhook──>│   Sync Service   │──writes──> Postgres
  iOS ──link/sync──>│ TypeScript:3001  │           (transactions,
                    └──────────────────┘            accounts)
                                                        │
                    ┌──────────────────┐                │
  iOS ──budget────>│   API Service    │──reads─────────┘
      ──goals────>│    Go:3002       │──writes──> (budget_periods,
      ──settings──>└──────────────────┘             income_streams,
                                                    savings_goals,
                                                    categories, overrides)
```

### 1f. Auth (both services)

Both services validate Supabase JWTs from the `Authorization: Bearer <token>` header. The sync service uses `supabase.auth.getUser(token)` via the JS SDK. The Go API service validates the JWT directly:

1. Fetch Supabase JWT secret from `SUPABASE_JWT_SECRET` env var
2. Parse and verify the token signature with `golang-jwt/jwt`
3. Extract `sub` claim as the user ID (UUID)

The webhook route on the sync service is the sole exception — it uses Plaid's own JWT verification instead.

### 1g. Local Development

```bash
# Terminal 1: sync service
cd services/sync && npm run dev

# Terminal 2: API service
cd services/api && go run ./cmd/server

# Terminal 3: Supabase local
supabase start
```

### 1h. Deployment (Railway)

Each service is a separate Railway service within the same Railway project:

| Railway Service | Source | Env Vars |
|---|---|---|
| **flume-sync** | `services/sync` | `PLAID_CLIENT_ID`, `PLAID_SECRET`, `PLAID_ENV`, `SUPABASE_URL`, `SUPABASE_SECRET_KEY` |
| **flume-api** | `services/api` | `SUPABASE_DB_URL` (direct Postgres connection string), `SUPABASE_JWT_SECRET` |

The Go service connects to Postgres directly via `SUPABASE_DB_URL` rather than going through the Supabase REST API.

The iOS app stores two base URLs:
- `SYNC_BASE_URL` — for link token, exchange, manual sync
- `API_BASE_URL` — for all budget endpoints

---

## 2. Water Glossary (Frontend Display Only)

Every financial concept has a water-themed display name used in the iOS UI. The backend, database, and API use conventional financial terms. The iOS app maps conventional terms to water names at the display layer.

| Water Display Name | Financial Concept | Backend Identifier |
|---|---|---|
| **Source** | Income | `income` (budget category value) |
| **Reservoir** | Budget category | `budget_category` column / category enum |
| **Basin** | Checking account | `checking` (account role) |
| **Cistern** | Savings account | `savings` (account role) |
| **Canal** | Credit card | `credit_card` (account role) |
| **Flow** | Transaction | `transactions` table |
| **Intake** | Income stream | `income_streams` table |
| **Flux** | Budget period | `budget_periods` table |
| **Bucket** | Savings goal | `savings_goals` table |
| **Spillover** | Surplus / leftover | `surplus` (computed field) |
| **Drain** | Expense | display-only concept |
| **Level** | Balance / progress | display-only concept |
| **Dry** | Over budget | display-only concept |

---

## 3. Account Model

Users connect accounts via Plaid. Each account is assigned a **role** that determines how it participates in the budget.

| Plaid `type` | Plaid `subtype` | Role | Behavior |
|---|---|---|---|
| `depository` | `checking` | `checking` | Income lands here. Fixed + flex expenses drain from here. |
| `depository` | `savings` | `savings` | Holds savings goal allocations. Only inbound transfers count. |
| `credit` | `credit card` | `credit_card` | Transactions categorize into budget categories. Payments are checking-to-credit transfers (excluded from budget). |

### Schema: `account_roles`

The current migration uses roles `('income_and_fixed', 'flex_spending', 'savings')`. Update to conventional account roles:

```sql
account_role text not null check (account_role in ('checking', 'savings', 'credit_card'))
```

Auto-assignment on account link (in the sync service exchange route):
- `type=depository, subtype=checking` -> `checking`
- `type=depository, subtype=savings` -> `savings`
- `type=credit` -> `credit_card`

Users can override via settings (through the API service) but the defaults should be correct for the three supported account types.

---

## 4. Budget Categories

Every transaction is assigned to exactly one budget category. The category determines which pool the money is tracked against.

| Category | Purpose | Examples |
|---|---|---|
| `income` | Money coming in | Paychecks, direct deposits, refunds |
| `fixed` | Non-negotiable recurring expenses | Rent, utilities, loan payments, insurance |
| `flex` | Discretionary spending | Food, entertainment, shopping, travel |
| `savings` | Money moved to savings account | Transfers from checking to savings |
| `transfer` | Internal money movement (excluded) | CC payments, account-to-account transfers |
| `ignore` | Not budgeted | ATM withdrawals, Venmo transfers the user opts out of |

### Category auto-assignment

Category assignment is computed at read time by the API service so that changing a category mapping retroactively recategorizes all past transactions. The priority:

1. **`category_override`** on the transaction (user manually re-categorized)
2. **User-specific `category_mappings`** (user customized a Plaid category)
3. **System default `category_mappings`** (`user_id = null` rows from migration seed)
4. **Fallback**: `flex` (unknown categories default to discretionary)

The `personal_finance_category` field from Plaid (jsonb with `primary` and `detailed` keys) is the lookup key. Matching: first try `(primary, detailed)`, then fall back to `(primary, null)`.

### Computed category (database view)

```sql
create view transactions_with_category as
select t.*,
  coalesce(
    t.category_override,
    ucm.budget_category,  -- user mapping
    scm.budget_category,  -- system mapping
    'flex'                -- fallback
  ) as budget_category
from transactions t
left join category_mappings ucm
  on ucm.user_id = t.user_id
  and ucm.plaid_primary_category = t.personal_finance_category->>'primary'
  and (ucm.plaid_detailed_category = t.personal_finance_category->>'detailed'
       or ucm.plaid_detailed_category is null)
left join category_mappings scm
  on scm.user_id is null
  and scm.plaid_primary_category = t.personal_finance_category->>'primary'
  and (scm.plaid_detailed_category = t.personal_finance_category->>'detailed'
       or scm.plaid_detailed_category is null);
```

---

## 5. Budget Periods

A **budget period** is one budget cycle. The user defines their own periods based on their pay schedule.

### User-driven period creation

The user tells Flume how they get paid:
1. Create an **income stream** — name (e.g. "ACME Payroll"), amount, frequency (weekly/biweekly/semimonthly/monthly)
2. Create a **budget period** — start date, end date, and spending targets

The app does not auto-detect income or auto-generate periods. The user knows when they get paid and sets this up themselves.

### Income stream schema

```sql
create table public.income_streams (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  name text not null,                    -- e.g. "ACME CORP PAYROLL"
  estimated_amount numeric not null,     -- expected deposit amount
  frequency text not null check (frequency in ('weekly','biweekly','semimonthly','monthly')),
  next_expected_date date,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
```

### Budget period schema

```sql
alter table budget_periods
  add column income_stream_id uuid references income_streams(id),
  add column flex_target numeric not null default 0;
```

Targets are set by the user when creating a budget period:
- `income_target` — expected income for the period
- `fixed_target` — expected fixed expenses
- `flex_target` — discretionary spending budget
- `savings_target` — income minus fixed minus flex (the surplus goal)

### Actuals — computed on read

When the iOS app requests the current budget period, the Go API service computes actuals by aggregating transactions from the `transactions_with_category` view within the period date range:

```sql
select
  coalesce(sum(amount) filter (where budget_category = 'income'), 0) as actual_income,
  coalesce(sum(amount) filter (where budget_category = 'fixed'), 0)  as actual_fixed,
  coalesce(sum(amount) filter (where budget_category = 'flex'), 0)   as actual_flex,
  coalesce(sum(amount) filter (where budget_category = 'savings'), 0) as actual_savings
from transactions_with_category
where user_id = $1
  and date >= $2  -- period start_date
  and date < $3;  -- period end_date
```

No cached `actual_*` columns needed. The database does the work, and the result is always fresh.

### Surplus

```
surplus = actual_income - actual_fixed - actual_flex
```

This is the money available to distribute into savings goals.

---

## 6. Credit Card Handling

Credit cards require special logic to avoid double-counting.

### Principle
- **Credit card transactions categorize into budget categories** -- a $50 restaurant charge on a credit card counts as a `flex` expense, just like a debit card purchase would.
- **Credit card payments are excluded** -- when you pay your credit card bill from your checking account, that transfer is tagged `transfer` and excluded from category totals.
- **Credit card balance is a liability** -- displayed separately, not subtracted from category balances.

### Implementation
1. During sync, the sync service stores transactions on credit card accounts with their `personal_finance_category` like any other transaction. No budget logic runs.
2. Transfer detection: the API service identifies credit card payments when computing actuals — transactions on a checking account with Plaid category `TRANSFER_OUT` where the payee matches a linked credit card institution are treated as `transfer` category.
3. The budget calculation (in the actuals query) sums category spending across **all** account types (checking + credit card), but filters out `transfer` and `ignore` categories.

### Budget math for a single period

```
total_income    = sum(transactions where budget_category = 'income')
total_fixed     = sum(transactions where budget_category = 'fixed')
total_flex      = sum(transactions where budget_category = 'flex')
total_savings   = sum(transactions where budget_category = 'savings')
surplus         = total_income - total_fixed - total_flex
```

Note: Plaid reports expenses as positive amounts and income as negative. The sync service normalizes on write: income stored as positive, expenses stored as positive, with the budget category indicating direction.

---

## 7. Savings Goals

Savings goals track progress toward savings targets. Users distribute their surplus into savings goals.

### Existing schema (rename needed)

Rename `savings_buckets` to `savings_goals`. Columns stay the same: `name`, `target_amount`, `current_amount`, `emoji`, `is_emergency_fund`, `priority`, `archived`.

### Savings goal fill flow

1. At the end of (or during) a budget period, the user sees their surplus amount.
2. They distribute surplus across savings goals (manual allocation).
3. The API service updates `current_amount` on each savings goal.
4. The actual transfer to the savings account happens outside Flume (user initiates in their bank app), or Flume can track it as a detected `savings` category transfer.

### Auto-fill rules (future enhancement, not in v1)

Users could configure percentage-based or priority-based auto-distribution. For v1, manual allocation only.

---

## 8. API Routes

### 8a. Sync Service Routes (TypeScript/Fastify)

All require auth (JWT from Supabase) except webhooks.

| Method | Path | Description |
|---|---|---|
| `POST` | `/link/token` | Generate Plaid Link token for client |
| `POST` | `/exchange` | Exchange public token, store access token, upsert accounts, trigger sync |
| `POST` | `/sync` | Manual transaction sync trigger |
| `POST` | `/webhooks` | Receive Plaid webhook events (no auth — Plaid JWT verified) |

These routes are unchanged from the current implementation.

### 8b. API Service Routes (Go)

All require auth (Supabase JWT validated in Go middleware).

**Budget Periods**

| Method | Path | Description |
|---|---|---|
| `GET` | `/budget/current-period` | Get the active budget period with actuals computed on read |
| `GET` | `/budget/periods` | List budget period history (paginated) |
| `POST` | `/budget/periods` | Create a new budget period (user sets dates + targets) |
| `PATCH` | `/budget/periods/:id` | Update budget period targets |
| `GET` | `/budget/category-summary` | Get category summary for active period (actuals vs targets) |

**Transactions**

| Method | Path | Description |
|---|---|---|
| `GET` | `/budget/transactions?period_id=X` | Get categorized transactions for a period, grouped by category |
| `POST` | `/budget/transactions/:id/override` | Override a single transaction's budget category |

**Income Streams**

| Method | Path | Description |
|---|---|---|
| `GET` | `/budget/income-streams` | List user's income streams |
| `POST` | `/budget/income-streams` | Create an income stream |
| `PATCH` | `/budget/income-streams/:id` | Update an income stream |
| `DELETE` | `/budget/income-streams/:id` | Deactivate an income stream |

**Savings Goals**

| Method | Path | Description |
|---|---|---|
| `GET` | `/budget/savings-goals` | List all savings goals |
| `POST` | `/budget/savings-goals` | Create a savings goal |
| `PATCH` | `/budget/savings-goals/:id` | Update savings goal (name, target, emoji, etc.) |
| `POST` | `/budget/savings-goals/fill` | Distribute surplus into savings goals `{ allocations: [{ savings_goal_id, amount }] }` |

**Categories**

| Method | Path | Description |
|---|---|---|
| `GET` | `/budget/categories` | Get merged category mappings (system defaults + user overrides) |
| `POST` | `/budget/categories` | Create/update a user category override |

**Accounts**

| Method | Path | Description |
|---|---|---|
| `GET` | `/budget/accounts` | Get accounts with their roles |
| `PATCH` | `/budget/accounts/:id/role` | Change an account's role |

---

## 9. Sync Service Changes

The existing `sync.ts` needs one change to support the budget engine.

### Store `personal_finance_category`

Extract `personal_finance_category` from the Plaid `transactionsSync()` response and include it in the transaction upsert:

```typescript
{
  // ... existing fields
  personal_finance_category: txn.personal_finance_category ?? null,
}
```

This is the only sync service change. All budget logic (category assignment, period actuals, income detection) lives in the Go API service.

---

## 10. iOS UI Design

### Display name mapping

The iOS app maps conventional backend terms to water-themed UI labels at the view layer. A central mapping keeps this consistent:

```swift
enum WaterTheme {
    static let periodTitle = "Flux"
    static let checkingAccount = "Basin"
    static let savingsAccount = "Cistern"
    static let creditCard = "Canal"
    static let transaction = "Flow"
    static let savingsGoal = "Bucket"
    static let surplus = "Spillover"
    static let categoryDisplayNames: [String: String] = [
        "income": "Source",
        "fixed": "Fixed",
        "flex": "Flex",
        "savings": "Savings",
    ]
}
```

### Navigation structure

```
MainTabView
  +-- Tab 1: "Flux" (budget overview)                <- display: "Flux", model: BudgetPeriod
  |     +-- BudgetPeriodView (category bars + surplus)
  |     +-- CategoryDetailView (transactions for a category)
  |     +-- SavingsGoalFillView (distribute surplus)
  +-- Tab 2: "Cistern" (savings goals)                <- display: "Cistern", model: SavingsGoal
  |     +-- SavingsGoalListView
  |     +-- SavingsGoalDetailView
  +-- Tab 3: "Basins" (accounts)                       <- display: "Basins", model: Account
  |     +-- AccountsListView (with role badges)
  |     +-- TransactionListView
  +-- Tab 4: Settings
        +-- Category mappings editor
        +-- Income stream management
        +-- Account role overrides
```

### 10a. Budget Period Overview (displayed as "Flux")

```
+-----------------------------------+
|  Mar 1 - Mar 14  (Flux #12)      |
|  -------------------------------- |
|                                   |
|  +--- Source -------------------+ |
|  |  $4,200 of $4,200           | |  <- fills as deposits arrive
|  +------------------------------+ |
|                                   |
|  +--- Fixed --------------------+ |
|  |  $1,850 of $2,100           | |  <- drains as bills hit
|  +------------------------------+ |
|                                   |
|  +--- Flex ---------------------+ |
|  |  $380 of $600               | |  <- discretionary spending
|  +------------------------------+ |
|                                   |
|  +--- Spillover ----------------+ |
|  |  $1,070 available           | |  <- what's left to distribute
|  |  [Fill Buckets]             | |
|  +------------------------------+ |
|                                   |
|  Canal Balance: -$1,240           |  <- credit card liability
+-----------------------------------+
```

Each category bar is animated like a water level, filling or draining. Tapping a category shows its transactions (displayed as "Flows" in the UI).

### 10b. Savings Goal Distribution (displayed as "Bucket Fill")

```
+-----------------------------------+
|  Distribute Spillover: $1,070     |
|  -------------------------------- |
|                                   |
|  Emergency Fund       $500 / $5k  |
|  [====--------]     +[$___]      |
|                                   |
|  Vacation           $1.2k / $3k   |
|  [========----]     +[$___]      |
|                                   |
|  New Laptop          $200 / $2k   |
|  [==----------]     +[$___]      |
|                                   |
|  Remaining: $1,070                |
|               [Confirm Fill]      |
+-----------------------------------+
```

### 10c. Transaction Detail (displayed as "Flows")

Tapping a category shows its transactions for the active budget period, grouped by date. Each transaction shows name, amount, and the assigned budget category tag. Users can tap to override the category.

### iOS service layer update

The iOS app needs two API service clients:

```swift
enum APIBase {
    static let sync = URL(string: "https://flume-sync.up.railway.app")!
    static let api  = URL(string: "https://flume-api.up.railway.app")!
}
```

- `SyncAPIService` — link token, exchange, manual sync (existing, retargeted)
- `BudgetAPIService` — all `/budget/*` endpoints (new, uses conventional route names)

Both attach the same Supabase auth token.

### New iOS models

Swift structs use conventional financial terms. The `WaterTheme` enum (above) maps these to water display names in the view layer.

```swift
struct BudgetPeriod: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let startDate: Date
    let endDate: Date
    let incomeTarget: Decimal
    let fixedTarget: Decimal
    let flexTarget: Decimal
    let savingsTarget: Decimal
    let actualIncome: Decimal    // computed by API service on read
    let actualFixed: Decimal
    let actualFlex: Decimal
    let actualSavings: Decimal
    let incomeStreamId: UUID?
    let createdAt: Date
}

struct IncomeStream: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let name: String
    let estimatedAmount: Decimal
    let frequency: String
    let nextExpectedDate: Date?
    let active: Bool
}

struct SavingsGoal: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let name: String
    let targetAmount: Decimal
    let currentAmount: Decimal
    let emoji: String?
    let isEmergencyFund: Bool
    let priority: Int
    let archived: Bool
}

struct CategoryMapping: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID?
    let plaidPrimaryCategory: String
    let plaidDetailedCategory: String?
    let budgetCategory: String
}
```

---

## 11. Implementation Order

### Phase 1: Service split + sync foundation
- Migrate `service/` to `services/sync/`
- Scaffold Go API service in `services/api/` (chi router, pgx pool, JWT auth middleware)
- Update `sync.ts` to store `personal_finance_category` from Plaid
- Create the `transactions_with_category` database view
- Add `personal_finance_category` to the iOS `Transaction` model
- Verify both services run locally and connect to Supabase

### Phase 2: Account roles
- Rename `account_reservoir_roles` to `account_roles`, update enum to `(checking, savings, credit_card)`
- Auto-assign roles in the sync service exchange route on account link
- Add `GET /budget/accounts` and `PATCH /budget/accounts/:id/role` in Go API
- iOS: show role badges on accounts list

### Phase 3: Budget periods + categories
- Create `income_streams` table migration
- Add income stream CRUD endpoints in Go API
- Add budget period CRUD endpoints in Go API with actuals computed on read
- Add `GET /budget/category-summary` endpoint
- iOS: build BudgetPeriodView with category bars

### Phase 4: Transaction categorization
- Add `GET /budget/transactions` endpoint in Go API
- Add `POST /budget/transactions/:id/override` endpoint
- Add `GET /budget/categories` and `POST /budget/categories` endpoints
- iOS: build CategoryDetailView and category override UI

### Phase 5: Savings goals
- Add savings goal CRUD endpoints in Go API
- Add `POST /budget/savings-goals/fill` endpoint
- iOS: build SavingsGoalListView, SavingsGoalDetailView, SavingsGoalFillView

### Phase 6: Polish
- Water-level animations on category bars (water theme is display-only)
- Budget period history view
- Settings screen for income streams + category mappings
- Deploy both services to Railway

---

## 12. Verification

- **Unit tests (Go)**: Budget math (surplus calculation, category assignment via view, actuals aggregation)
- **Unit tests (TypeScript)**: Sync logic, webhook verification
- **Integration tests**: Sync service writes transactions -> API service reads and computes correct actuals
- **Manual QA**: Connect a sandbox Plaid account, trigger sync, verify transactions appear, create a budget period, check category actuals, distribute surplus into savings goals
- **Edge cases**: Multiple income streams, credit card refunds, mid-period category remapping, period with no transactions
