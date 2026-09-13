-- Etapa 16 — campos de clientes vindos da planilha clientes.xlsx
alter table public.cobrapp_customers
  add column if not exists last_name text,
  add column if not exists landline text,
  add column if not exists email text,
  add column if not exists tags text[] not null default '{}'::text[],
  add column if not exists co_debtor_name text,
  add column if not exists co_debtor_document text,
  add column if not exists co_debtor_phone text,
  add column if not exists is_active boolean not null default true,
  add column if not exists reference1_name text,
  add column if not exists reference1_relation text,
  add column if not exists reference1_phone text;

create index if not exists cobrapp_customers_active_idx
  on public.cobrapp_customers(user_id, is_active);

create index if not exists cobrapp_customers_name_idx
  on public.cobrapp_customers(user_id, name);
