-- Etapa 2 — Gerenciamento de Clientes
-- Mantém os campos existentes e adiciona somente o armazenamento da assinatura.

alter table public.cobrapp_customers
  add column if not exists signature_data text;

create index if not exists cobrapp_customers_user_active_idx
  on public.cobrapp_customers(user_id, is_active);

create index if not exists cobrapp_customers_created_at_idx
  on public.cobrapp_customers(created_at);
