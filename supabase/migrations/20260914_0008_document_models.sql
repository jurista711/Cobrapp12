create table if not exists public.cobrapp_document_templates (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 title text not null, document_type text not null default 'personalizado', body text not null default '', is_system boolean not null default false,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.cobrapp_generated_documents (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 template_id uuid references public.cobrapp_document_templates(id) on delete set null, customer_id uuid references public.cobrapp_customers(id) on delete set null,
 loan_id uuid references public.cobrapp_loans(id) on delete set null, title text not null, body text not null,
 client_signature text, responsible_signature text, witness_signature text, created_at timestamptz not null default now()
);
alter table public.cobrapp_document_templates enable row level security;
alter table public.cobrapp_generated_documents enable row level security;
drop policy if exists "own_document_templates" on public.cobrapp_document_templates;
create policy "own_document_templates" on public.cobrapp_document_templates for all to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());
drop policy if exists "own_generated_documents" on public.cobrapp_generated_documents;
create policy "own_generated_documents" on public.cobrapp_generated_documents for all to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());
create index if not exists cobrapp_document_templates_user_idx on public.cobrapp_document_templates(user_id, updated_at desc);
create index if not exists cobrapp_generated_documents_user_idx on public.cobrapp_generated_documents(user_id, created_at desc);