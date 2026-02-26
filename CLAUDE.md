# Budget App — Claude Context

## Project Overview

A personal budgeting app built on flow-based budgeting principles. The app connects to bank and credit card accounts via Plaid and helps users understand their cash flow through a simple account and transaction view.

This is a solo passion project, initially for personal/family use with the option to scale later.

---

## Current MVP Scope

The MVP is intentionally minimal. Do not add features, tables, or abstractions beyond what is needed to support:

1. **Authentication** — user can sign up, log in, and log out
2. **Accounts** — user can view linked bank and credit card accounts with current balances
3. **Transactions** — user can view transactions for each account

That's it. Do not implement savings buckets, sweep/allocation logic, push notifications, or any other features until explicitly asked.

---

## Tech Stack

### iOS / macOS Client
- **SwiftUI** — shared UI across iOS and macOS targets
- **Supabase Swift SDK** — auth and data fetching
- Minimum targets: iOS 17, macOS 14

### Backend (Railway)
- **Fastify + TypeScript** — lightweight Plaid integration service
- Handles: Plaid link token generation, public token exchange, transaction sync, webhook ingestion
- The Plaid access token is stored server-side only and never exposed to the client

### Database & Auth
- **Supabase** — Postgres, auth, and realtime
- Row Level Security (RLS) enabled on all tables
- The Swift client connects directly to Supabase for reads; mutations that involve Plaid go through the Railway service

---

## Repo Structure

```
budget-app/
├── ios-macos/              # SwiftUI app
├── railway-service/        # Fastify/TypeScript Plaid service
│   └── src/
│       ├── routes/         # link, exchange, sync, webhook
│       ├── lib/            # plaid client, supabase client
│       └── index.ts
└── supabase/
    ├── migrations/         # SQL schema files
    └── seed/               # Dev/test seed data
```

---

## Database Schema

Keep the schema minimal. Current tables:

```sql
profiles          -- extends Supabase auth.users
plaid_items       -- a linked institution (stores access token server-side)
accounts          -- individual bank/credit accounts within an item
transactions      -- synced from Plaid via transactions/sync cursor
```

Do not add tables beyond these until the MVP is complete and a new feature is explicitly scoped.

---

## Architecture Principles

### General
- **Minimal surface area.** Only build what is needed for the current scope. Resist the urge to build ahead.
- **Separation of concerns.** Plaid logic lives in the Railway service. Auth and data live in Supabase. The client is a consumer only.
- **No business logic in the client.** The SwiftUI app fetches and displays data. Calculations and mutations happen server-side or in the database.

### SwiftUI Client
- Use a clear layered structure: **Views → ViewModels → Repositories → Services**
- ViewModels own state and call repositories
- Repositories abstract Supabase queries — views never call Supabase directly
- One repository per domain (AccountRepository, TransactionRepository)
- Use Swift `async/await` throughout, no callbacks or Combine unless necessary

### Railway Service
- One file per route group under `src/routes/`
- Plaid client and Supabase client are initialized once in `src/lib/` and imported where needed
- Sync logic is encapsulated in a reusable function, not duplicated across routes
- All endpoints return consistent `{ success: true }` or `{ error: string }` shapes

### Supabase
- Every table has RLS enabled
- The service role key is only used in the Railway service
- The anon key is used in the Swift client
- Migrations are versioned SQL files in `supabase/migrations/` — do not make schema changes directly in the Supabase dashboard

---

## Environment Variables

### Railway Service
```
PLAID_CLIENT_ID
PLAID_SECRET
PLAID_ENV            # sandbox | production
SUPABASE_URL
SUPABASE_SERVICE_ROLE_KEY
RAILWAY_PUBLIC_DOMAIN
```

### SwiftUI Client (in xcconfig or Info.plist)
```
SUPABASE_URL
SUPABASE_ANON_KEY
RAILWAY_SERVICE_URL
```

---

## What to Avoid

- Do not add third-party dependencies without a clear reason — prefer platform APIs and official SDKs
- Do not implement caching layers until there is a demonstrated need
- Do not build generic/reusable abstractions prematurely — wait for the duplication to appear first
- Do not store the Plaid access token anywhere except the `plaid_items` table, accessed only by the Railway service
