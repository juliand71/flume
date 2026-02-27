create table "plaid_items" (
  "id" uuid primary key default gen_random_uuid(),
  "user_id" uuid not null references profiles(id) on delete cascade,
  "plaid_item_id" text not null unique,
  "access_token" text not null,
  "institution_name" text,
  "cursor" text,
  "created_at" timestamptz not null default now()
);
