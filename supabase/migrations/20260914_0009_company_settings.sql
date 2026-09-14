-- Etapa 9 — Configurações da Empresa

alter table public.cobrapp_company_settings
  add column if not exists company_name text,
  add column if not exists trade_name text,
  add column if not exists tax_id text,
  add column if not exists address text,
  add column if not exists phone text,
  add column if not exists email text,
  add column if not exists logo_base64 text,
  add column if not exists signature_base64 text,
  add column if not exists late_fee_type text not null default 'percent';

alter table public.cobrapp_company_settings
  drop constraint if exists cobrapp_company_settings_late_fee_type_check;

alter table public.cobrapp_company_settings
  add constraint cobrapp_company_settings_late_fee_type_check
  check (late_fee_type in ('percent','fixed'));

create index if not exists cobrapp_company_settings_user_idx
  on public.cobrapp_company_settings(user_id);

alter table public.cobrapp_company_settings enable row level security;

drop policy if exists "company settings owner all" on public.cobrapp_company_settings;
create policy "company settings owner all"
on public.cobrapp_company_settings
for all
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "company settings collaborators" on public.cobrapp_company_settings;
create policy "company settings collaborators"
on public.cobrapp_company_settings
for all
using (public.cobrapp_collaborator_has_access(user_id,'settings'))
with check (public.cobrapp_collaborator_has_access(user_id,'settings'));
