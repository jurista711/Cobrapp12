-- Etapa 10 — Rotas e Etiquetas

create table if not exists public.cobrapp_routes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  name text not null,
  region text,
  areas text[] not null default '{}'::text[],
  collaborator_id uuid references public.cobrapp_collaborators(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id, name)
);

alter table public.cobrapp_customers
  add column if not exists route_id uuid references public.cobrapp_routes(id) on delete set null;

create table if not exists public.cobrapp_tags (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  name text not null,
  color text not null default '#7C3AED',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id, name)
);

create table if not exists public.cobrapp_customer_tags (
  customer_id uuid not null references public.cobrapp_customers(id) on delete cascade,
  tag_id uuid not null references public.cobrapp_tags(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(customer_id, tag_id)
);

create index if not exists cobrapp_routes_user_idx on public.cobrapp_routes(user_id, name);
create index if not exists cobrapp_routes_collaborator_idx on public.cobrapp_routes(collaborator_id);
create index if not exists cobrapp_customers_route_idx on public.cobrapp_customers(user_id, route_id);
create index if not exists cobrapp_tags_user_idx on public.cobrapp_tags(user_id, name);
create index if not exists cobrapp_customer_tags_tag_idx on public.cobrapp_customer_tags(tag_id, customer_id);

alter table public.cobrapp_routes enable row level security;
alter table public.cobrapp_tags enable row level security;
alter table public.cobrapp_customer_tags enable row level security;

drop policy if exists cobrapp_routes_owner_access on public.cobrapp_routes;
create policy cobrapp_routes_owner_access on public.cobrapp_routes
for all using (
  user_id = auth.uid() or public.cobrapp_collaborator_has_access(user_id, 'routes')
) with check (
  user_id = auth.uid() or public.cobrapp_collaborator_has_access(user_id, 'routes')
);

drop policy if exists cobrapp_tags_owner_access on public.cobrapp_tags;
create policy cobrapp_tags_owner_access on public.cobrapp_tags
for all using (
  user_id = auth.uid() or public.cobrapp_collaborator_has_access(user_id, 'routes')
) with check (
  user_id = auth.uid() or public.cobrapp_collaborator_has_access(user_id, 'routes')
);

drop policy if exists cobrapp_customer_tags_owner_access on public.cobrapp_customer_tags;
create policy cobrapp_customer_tags_owner_access on public.cobrapp_customer_tags
for all using (
  exists (
    select 1 from public.cobrapp_customers c
    where c.id = customer_id
      and (c.user_id = auth.uid() or public.cobrapp_collaborator_has_access(c.user_id, 'routes'))
  )
) with check (
  exists (
    select 1 from public.cobrapp_customers c
    where c.id = customer_id
      and (c.user_id = auth.uid() or public.cobrapp_collaborator_has_access(c.user_id, 'routes'))
  )
);

-- Preserva etiquetas já existentes no cadastro de clientes.
insert into public.cobrapp_tags(user_id, name)
select distinct c.user_id, trim(t.tag_name)
from public.cobrapp_customers c
cross join lateral unnest(coalesce(c.tags, '{}'::text[])) as t(tag_name)
where trim(t.tag_name) <> ''
on conflict (user_id, name) do nothing;

insert into public.cobrapp_customer_tags(customer_id, tag_id)
select c.id, t.id
from public.cobrapp_customers c
join public.cobrapp_tags t on t.user_id = c.user_id and t.name = any(coalesce(c.tags, '{}'::text[]))
on conflict do nothing;
