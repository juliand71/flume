create table "accounts" (
  "id" uuid primary key default gen_random_uuid(),
  "plaid_item_id" uuid not null references plaid_items(id) on delete cascade,
  "user_id" uuid not null references profiles(id) on delete cascade,
  "plaid_account_id" text not null unique,
  "name" text not null,
  "official_name" text,
  "type" text not null,
  "subtype" text,
  "mask" text,
  "current_balance" numeric,
  "available_balance" numeric,
  "iso_currency_code" text default 'USD',
  "updated_at" timestamptz not null default now(),
  "created_at" timestamptz not null default now()
);

create index idx_accounts_user_id on accounts(user_id);
