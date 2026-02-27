create table "transactions" (
  "id" uuid primary key default gen_random_uuid(),
  "account_id" uuid not null references accounts(id) on delete cascade,
  "user_id" uuid not null references profiles(id) on delete cascade,
  "plaid_transaction_id" text not null unique,
  "name" text not null,
  "amount" numeric not null,
  "iso_currency_code" text default 'USD',
  "category" text[],
  "date" date not null,
  "pending" boolean not null default false,
  "created_at" timestamptz not null default now()
);

create index idx_transactions_account_id on transactions(account_id);
create index idx_transactions_user_id on transactions(user_id);
create index idx_transactions_date on transactions(date desc);
