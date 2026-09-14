alter table public.cobrapp_expenses
  add column if not exists status text not null default 'paid',
  add column if not exists notes text;

alter table public.cobrapp_expenses
  drop constraint if exists cobrapp_expenses_status_check;

alter table public.cobrapp_expenses
  add constraint cobrapp_expenses_status_check check (status in ('paid','pending'));

create index if not exists cobrapp_expenses_user_spent_at_idx
  on public.cobrapp_expenses(user_id, spent_at desc);

create index if not exists cobrapp_expenses_user_category_idx
  on public.cobrapp_expenses(user_id, category);

create index if not exists cobrapp_expenses_user_status_idx
  on public.cobrapp_expenses(user_id, status);
