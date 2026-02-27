create table "profiles" (
  "id" uuid primary key references auth.users(id) on delete cascade,
  "display_name" text,
  "created_at" timestamptz not null default now()
);
