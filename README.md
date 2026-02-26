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

## Architecture

- **SwiftUI client** — Views → ViewModels → Repositories → Services. No business logic; reads from Supabase directly, mutations via the Railway service.
- **Railway service** — Plaid API gateway. Handles link token creation, public token exchange, transaction sync, and webhook ingestion. The Plaid access token never leaves this service.
- **Supabase** — Postgres + Auth. RLS on every table. Migrations are versioned SQL files; never edit schema directly in the dashboard.
