# Flume

A flow-based personal budgeting app. Connect your accounts, see your cash flow.

## Monorepo structure

```
flume/
├── ios/          # SwiftUI app — iOS 17 + macOS 14
├── service/      # Fastify/TypeScript Plaid integration service (Railway)
└── supabase/     # Database migrations and seed data
```

## Getting started

### Service

```bash
cd service
cp .env.example .env   # fill in your keys
npm install
npm run dev
```

### iOS app

Open `ios/Flume.xcodeproj` in Xcode, set your team, and run.

### Supabase (local dev)

```bash
supabase start          # spins up local Postgres + Auth
supabase db reset       # applies migrations + seed
```

## Debug mode

Debug mode bypasses JWT authentication in the API and uses a fixed debug user ID, so you can run the iOS app against a local backend without real Supabase credentials.

### Starting the API in debug mode

```bash
cd services/api
DEBUG=1 go run ./cmd/server/main.go
```

You'll see `*** DEBUG MODE: Auth bypassed, using debug user ID ***` in the logs confirming it's active.

### Debug users

Two users are seeded by `supabase db reset`:

| User | Email | Password | State |
|------|-------|----------|-------|
| Debug User (default) | `debug@flume.local` | `debug123` | Fully onboarded — linked bank, transactions, budget periods, savings goals |
| Debug User 2 | `debug2@flume.local` | `debug123` | Fresh — no data, starts at the beginning of onboarding |

Log into the iOS app with either email/password. Because the API ignores the JWT in debug mode, both credentials work as entry points.

### Switching between debug users at runtime

After logging in, tap the **ladybug icon** (top-right of the Budget tab) to open Debug Settings. Select the user you want and sign out/sign back in — the app will start as that user.

This works by sending an `X-Debug-User-ID` header on all API requests when "Fresh (no data)" is selected, which the backend picks up to route to the second user's data.

> The debug toolbar icon and header injection are `#if DEBUG` only and are stripped from release builds.

## Architecture

- **SwiftUI client** — Views → ViewModels → Repositories → Services. No business logic; reads from Supabase directly, mutations via the Railway service.
- **Railway service** — Plaid API gateway. Handles link token creation, public token exchange, transaction sync, and webhook ingestion. The Plaid access token never leaves this service.
- **Supabase** — Postgres + Auth. RLS on every table. Migrations are versioned SQL files; never edit schema directly in the dashboard.
