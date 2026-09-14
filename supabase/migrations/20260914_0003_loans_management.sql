-- Etapa 3 — Empréstimos e Prestações
-- Campos necessários exclusivamente para as funções previstas nesta etapa.

create table if not exists public.cobrapp_company_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  late_interest_enabled boolean not null default false,
  late_interest_rate numeric not null default 0,
  late_fee_base numeric not null default 0,
  updated_at timestamptz not null default now()
);

alter table public.cobrapp_company_settings
  add column if not exists late_interest_enabled boolean not null default false,
  add column if not exists late_interest_rate numeric not null default 0,
  add column if not exists late_fee_base numeric not null default 0,
  add column if not exists updated_at timestamptz not null default now();

alter table public.cobrapp_loans
  add column if not exists late_interest_enabled boolean not null default false,
  add column if not exists late_fee_base numeric not null default 0,
  add column if not exists default_payment_method text not null default 'Dinheiro',
  add column if not exists amortization_method text not null default 'simple',
  add column if not exists commitment_date date,
  add column if not exists commitment_amount numeric,
  add column if not exists commitment_notes text,
  add column if not exists renegotiated_from uuid references public.cobrapp_loans(id) on delete set null,
  add column if not exists early_discount_percent numeric not null default 0;

alter table public.cobrapp_loans drop constraint if exists cobrapp_loans_amortization_method_check;
alter table public.cobrapp_loans add constraint cobrapp_loans_amortization_method_check check (amortization_method in ('simple', 'price'));

alter table public.cobrapp_loans drop constraint if exists cobrapp_loans_early_discount_percent_check;
alter table public.cobrapp_loans add constraint cobrapp_loans_early_discount_percent_check check (early_discount_percent >= 0 and early_discount_percent <= 100);

alter table public.cobrapp_company_settings enable row level security;

drop policy if exists "cobrapp_company_settings_select_own" on public.cobrapp_company_settings;
create policy "cobrapp_company_settings_select_own" on public.cobrapp_company_settings for select using (auth.uid() = user_id);

drop policy if exists "cobrapp_company_settings_insert_own" on public.cobrapp_company_settings;
create policy "cobrapp_company_settings_insert_own" on public.cobrapp_company_settings for insert with check (auth.uid() = user_id);

drop policy if exists "cobrapp_company_settings_update_own" on public.cobrapp_company_settings;
create policy "cobrapp_company_settings_update_own" on public.cobrapp_company_settings for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

create index if not exists cobrapp_loans_status_idx on public.cobrapp_loans(user_id, status);
create index if not exists cobrapp_loans_commitment_date_idx on public.cobrapp_loans(user_id, commitment_date) where commitment_date is not null;
