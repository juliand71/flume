
  create table "public"."accounts" (
    "id" uuid not null default gen_random_uuid(),
    "plaid_item_id" uuid not null,
    "user_id" uuid not null,
    "plaid_account_id" text not null,
    "name" text not null,
    "official_name" text,
    "type" text not null,
    "subtype" text,
    "mask" text,
    "current_balance" numeric,
    "available_balance" numeric,
    "iso_currency_code" text default 'USD'::text,
    "updated_at" timestamp with time zone not null default now(),
    "created_at" timestamp with time zone not null default now()
      );



  create table "public"."plaid_items" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "plaid_item_id" text not null,
    "access_token" text not null,
    "institution_name" text,
    "cursor" text,
    "created_at" timestamp with time zone not null default now()
      );



  create table "public"."profiles" (
    "id" uuid not null,
    "display_name" text,
    "created_at" timestamp with time zone not null default now()
      );



  create table "public"."transactions" (
    "id" uuid not null default gen_random_uuid(),
    "account_id" uuid not null,
    "user_id" uuid not null,
    "plaid_transaction_id" text not null,
    "name" text not null,
    "amount" numeric not null,
    "iso_currency_code" text default 'USD'::text,
    "category" text[],
    "date" date not null,
    "pending" boolean not null default false,
    "created_at" timestamp with time zone not null default now()
      );


CREATE UNIQUE INDEX accounts_pkey ON public.accounts USING btree (id);

CREATE UNIQUE INDEX accounts_plaid_account_id_key ON public.accounts USING btree (plaid_account_id);

CREATE INDEX idx_accounts_user_id ON public.accounts USING btree (user_id);

CREATE INDEX idx_transactions_account_id ON public.transactions USING btree (account_id);

CREATE INDEX idx_transactions_date ON public.transactions USING btree (date DESC);

CREATE INDEX idx_transactions_user_id ON public.transactions USING btree (user_id);

CREATE UNIQUE INDEX plaid_items_pkey ON public.plaid_items USING btree (id);

CREATE UNIQUE INDEX plaid_items_plaid_item_id_key ON public.plaid_items USING btree (plaid_item_id);

CREATE UNIQUE INDEX profiles_pkey ON public.profiles USING btree (id);

CREATE UNIQUE INDEX transactions_pkey ON public.transactions USING btree (id);

CREATE UNIQUE INDEX transactions_plaid_transaction_id_key ON public.transactions USING btree (plaid_transaction_id);

alter table "public"."accounts" add constraint "accounts_pkey" PRIMARY KEY using index "accounts_pkey";

alter table "public"."plaid_items" add constraint "plaid_items_pkey" PRIMARY KEY using index "plaid_items_pkey";

alter table "public"."profiles" add constraint "profiles_pkey" PRIMARY KEY using index "profiles_pkey";

alter table "public"."transactions" add constraint "transactions_pkey" PRIMARY KEY using index "transactions_pkey";

alter table "public"."accounts" add constraint "accounts_plaid_account_id_key" UNIQUE using index "accounts_plaid_account_id_key";

alter table "public"."accounts" add constraint "accounts_plaid_item_id_fkey" FOREIGN KEY (plaid_item_id) REFERENCES public.plaid_items(id) ON DELETE CASCADE not valid;

alter table "public"."accounts" validate constraint "accounts_plaid_item_id_fkey";

alter table "public"."accounts" add constraint "accounts_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE not valid;

alter table "public"."accounts" validate constraint "accounts_user_id_fkey";

alter table "public"."plaid_items" add constraint "plaid_items_plaid_item_id_key" UNIQUE using index "plaid_items_plaid_item_id_key";

alter table "public"."plaid_items" add constraint "plaid_items_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE not valid;

alter table "public"."plaid_items" validate constraint "plaid_items_user_id_fkey";

alter table "public"."profiles" add constraint "profiles_id_fkey" FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."profiles" validate constraint "profiles_id_fkey";

alter table "public"."transactions" add constraint "transactions_account_id_fkey" FOREIGN KEY (account_id) REFERENCES public.accounts(id) ON DELETE CASCADE not valid;

alter table "public"."transactions" validate constraint "transactions_account_id_fkey";

alter table "public"."transactions" add constraint "transactions_plaid_transaction_id_key" UNIQUE using index "transactions_plaid_transaction_id_key";

alter table "public"."transactions" add constraint "transactions_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE not valid;

alter table "public"."transactions" validate constraint "transactions_user_id_fkey";

grant delete on table "public"."accounts" to "anon";

grant insert on table "public"."accounts" to "anon";

grant references on table "public"."accounts" to "anon";

grant select on table "public"."accounts" to "anon";

grant trigger on table "public"."accounts" to "anon";

grant truncate on table "public"."accounts" to "anon";

grant update on table "public"."accounts" to "anon";

grant delete on table "public"."accounts" to "authenticated";

grant insert on table "public"."accounts" to "authenticated";

grant references on table "public"."accounts" to "authenticated";

grant select on table "public"."accounts" to "authenticated";

grant trigger on table "public"."accounts" to "authenticated";

grant truncate on table "public"."accounts" to "authenticated";

grant update on table "public"."accounts" to "authenticated";

grant delete on table "public"."accounts" to "service_role";

grant insert on table "public"."accounts" to "service_role";

grant references on table "public"."accounts" to "service_role";

grant select on table "public"."accounts" to "service_role";

grant trigger on table "public"."accounts" to "service_role";

grant truncate on table "public"."accounts" to "service_role";

grant update on table "public"."accounts" to "service_role";

grant delete on table "public"."plaid_items" to "anon";

grant insert on table "public"."plaid_items" to "anon";

grant references on table "public"."plaid_items" to "anon";

grant select on table "public"."plaid_items" to "anon";

grant trigger on table "public"."plaid_items" to "anon";

grant truncate on table "public"."plaid_items" to "anon";

grant update on table "public"."plaid_items" to "anon";

grant delete on table "public"."plaid_items" to "authenticated";

grant insert on table "public"."plaid_items" to "authenticated";

grant references on table "public"."plaid_items" to "authenticated";

grant select on table "public"."plaid_items" to "authenticated";

grant trigger on table "public"."plaid_items" to "authenticated";

grant truncate on table "public"."plaid_items" to "authenticated";

grant update on table "public"."plaid_items" to "authenticated";

grant delete on table "public"."plaid_items" to "service_role";

grant insert on table "public"."plaid_items" to "service_role";

grant references on table "public"."plaid_items" to "service_role";

grant select on table "public"."plaid_items" to "service_role";

grant trigger on table "public"."plaid_items" to "service_role";

grant truncate on table "public"."plaid_items" to "service_role";

grant update on table "public"."plaid_items" to "service_role";

grant delete on table "public"."profiles" to "anon";

grant insert on table "public"."profiles" to "anon";

grant references on table "public"."profiles" to "anon";

grant select on table "public"."profiles" to "anon";

grant trigger on table "public"."profiles" to "anon";

grant truncate on table "public"."profiles" to "anon";

grant update on table "public"."profiles" to "anon";

grant delete on table "public"."profiles" to "authenticated";

grant insert on table "public"."profiles" to "authenticated";

grant references on table "public"."profiles" to "authenticated";

grant select on table "public"."profiles" to "authenticated";

grant trigger on table "public"."profiles" to "authenticated";

grant truncate on table "public"."profiles" to "authenticated";

grant update on table "public"."profiles" to "authenticated";

grant delete on table "public"."profiles" to "service_role";

grant insert on table "public"."profiles" to "service_role";

grant references on table "public"."profiles" to "service_role";

grant select on table "public"."profiles" to "service_role";

grant trigger on table "public"."profiles" to "service_role";

grant truncate on table "public"."profiles" to "service_role";

grant update on table "public"."profiles" to "service_role";

grant delete on table "public"."transactions" to "anon";

grant insert on table "public"."transactions" to "anon";

grant references on table "public"."transactions" to "anon";

grant select on table "public"."transactions" to "anon";

grant trigger on table "public"."transactions" to "anon";

grant truncate on table "public"."transactions" to "anon";

grant update on table "public"."transactions" to "anon";

grant delete on table "public"."transactions" to "authenticated";

grant insert on table "public"."transactions" to "authenticated";

grant references on table "public"."transactions" to "authenticated";

grant select on table "public"."transactions" to "authenticated";

grant trigger on table "public"."transactions" to "authenticated";

grant truncate on table "public"."transactions" to "authenticated";

grant update on table "public"."transactions" to "authenticated";

grant delete on table "public"."transactions" to "service_role";

grant insert on table "public"."transactions" to "service_role";

grant references on table "public"."transactions" to "service_role";

grant select on table "public"."transactions" to "service_role";

grant trigger on table "public"."transactions" to "service_role";

grant truncate on table "public"."transactions" to "service_role";

grant update on table "public"."transactions" to "service_role";


