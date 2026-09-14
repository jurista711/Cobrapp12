-- Etapa 11 — Notificações e Lembretes

create table if not exists public.cobrapp_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  type text not null,
  title text not null,
  body text not null,
  reference_type text,
  reference_id uuid,
  event_key text not null,
  is_read boolean not null default false,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  unique(user_id,event_key)
);

create index if not exists idx_cobrapp_notifications_user_created
  on public.cobrapp_notifications(user_id,created_at desc);
create index if not exists idx_cobrapp_notifications_user_unread
  on public.cobrapp_notifications(user_id,is_read) where deleted_at is null;

create table if not exists public.cobrapp_email_reminders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  customer_id uuid not null,
  installment_id uuid,
  email text not null,
  subject text not null,
  body text not null,
  event_key text not null,
  status text not null default 'queued' check (status in ('queued','sent','error')),
  scheduled_for date not null default current_date,
  sent_at timestamptz,
  error_text text,
  created_at timestamptz not null default now(),
  unique(user_id,event_key)
);

create index if not exists idx_cobrapp_email_reminders_user_status
  on public.cobrapp_email_reminders(user_id,status,scheduled_for);

alter table public.cobrapp_notifications enable row level security;
alter table public.cobrapp_email_reminders enable row level security;

drop policy if exists cobrapp_notifications_owner on public.cobrapp_notifications;
create policy cobrapp_notifications_owner on public.cobrapp_notifications
for all using (
  user_id = auth.uid() or public.cobrapp_collaborator_has_access(user_id,'payments')
)
with check (
  user_id = auth.uid() or public.cobrapp_collaborator_has_access(user_id,'payments')
);

drop policy if exists cobrapp_email_reminders_owner on public.cobrapp_email_reminders;
create policy cobrapp_email_reminders_owner on public.cobrapp_email_reminders
for select using (
  user_id = auth.uid() or public.cobrapp_collaborator_has_access(user_id,'payments')
);

create or replace function public.cobrapp_is_premium(p_user uuid)
returns boolean
language sql
security definer
set search_path=public,auth
as $$
  select exists(
    select 1 from auth.users u where u.id=p_user and (
      coalesce((u.raw_user_meta_data->>'premium')::boolean,false)
      or coalesce((u.raw_app_meta_data->>'premium')::boolean,false)
      or lower(coalesce(u.raw_user_meta_data->>'plan',u.raw_user_meta_data->>'plano','')) in ('premium','pro')
    )
  );
$$;

create or replace function public.cobrapp_sync_notifications(p_user uuid)
returns void
language plpgsql
security definer
set search_path=public,auth
as $$
begin
  if auth.uid() is null or (
    auth.uid() <> p_user and not public.cobrapp_collaborator_has_access(p_user,'payments')
  ) then
    raise exception 'Acesso negado';
  end if;

  insert into public.cobrapp_notifications(user_id,type,title,body,reference_type,reference_id,event_key)
  select p_user,'overdue','Parcela vencida',
         c.name || ' possui a parcela ' || i.number || ' vencida em ' || to_char(i.due_date,'DD/MM/YYYY') || '.',
         'installment',i.id,'overdue:'||i.id::text||':'||i.due_date::text
  from public.cobrapp_installments i
  join public.cobrapp_customers c on c.id=i.customer_id
  where i.user_id=p_user
    and i.due_date < current_date
    and lower(i.status) not in ('paid','paga','quitado','renegotiated','renegociada')
  on conflict(user_id,event_key) do nothing;

  insert into public.cobrapp_notifications(user_id,type,title,body,reference_type,reference_id,event_key)
  select p_user,'upcoming','Parcela a vencer',
         c.name || ' possui a parcela ' || i.number || ' com vencimento em ' || to_char(i.due_date,'DD/MM/YYYY') || '.',
         'installment',i.id,'upcoming:'||i.id::text||':'||i.due_date::text
  from public.cobrapp_installments i
  join public.cobrapp_customers c on c.id=i.customer_id
  where i.user_id=p_user
    and i.due_date between current_date and current_date + 3
    and lower(i.status) not in ('paid','paga','quitado','renegotiated','renegociada')
  on conflict(user_id,event_key) do nothing;

  insert into public.cobrapp_notifications(user_id,type,title,body,reference_type,reference_id,event_key)
  select p_user,'commitment','Compromisso de pagamento',
         c.name || ' prometeu pagar R$ ' || to_char(coalesce(l.commitment_amount,0),'FM999999990D00') ||
         ' em ' || to_char(l.commitment_date,'DD/MM/YYYY') || '.',
         'loan',l.id,'commitment:'||l.id::text||':'||l.commitment_date::text
  from public.cobrapp_loans l
  join public.cobrapp_customers c on c.id=l.customer_id
  where l.user_id=p_user
    and l.commitment_date is not null
    and l.commitment_date <= current_date + 3
    and lower(l.status) not in ('paid','quitado','liquidated','liquidado')
  on conflict(user_id,event_key) do nothing;

  if public.cobrapp_is_premium(p_user) then
    insert into public.cobrapp_email_reminders(
      user_id,customer_id,installment_id,email,subject,body,event_key,scheduled_for
    )
    select p_user,c.id,i.id,c.email,
      case when i.due_date < current_date then 'Pagamento vencido' else 'Lembrete de pagamento' end,
      case when i.due_date < current_date
        then 'Olá '||c.name||', lembramos que a parcela '||i.number||' venceu em '||to_char(i.due_date,'DD/MM/YYYY')||'.'
        else 'Olá '||c.name||', lembramos que a parcela '||i.number||' vence em '||to_char(i.due_date,'DD/MM/YYYY')||'.'
      end,
      'email:'||i.id::text||':'||i.due_date::text,
      current_date
    from public.cobrapp_installments i
    join public.cobrapp_customers c on c.id=i.customer_id
    where i.user_id=p_user
      and nullif(trim(c.email),'') is not null
      and i.due_date <= current_date + 3
      and lower(i.status) not in ('paid','paga','quitado','renegotiated','renegociada')
    on conflict(user_id,event_key) do nothing;
  end if;
end;
$$;

create or replace function public.cobrapp_notify_payment_insert()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare v_name text;
begin
  select name into v_name from public.cobrapp_customers where id=new.customer_id;
  insert into public.cobrapp_notifications(user_id,type,title,body,reference_type,reference_id,event_key)
  values(
    new.user_id,'payment','Pagamento registrado',
    'Pagamento de R$ '||to_char(new.amount,'FM999999990D00')||' registrado para '||coalesce(v_name,'Cliente')||'.',
    'payment',new.id,'payment:'||new.id::text
  ) on conflict(user_id,event_key) do nothing;
  return new;
end;
$$;

drop trigger if exists trg_cobrapp_notify_payment on public.cobrapp_payments;
create trigger trg_cobrapp_notify_payment
after insert on public.cobrapp_payments
for each row execute function public.cobrapp_notify_payment_insert();

create or replace function public.cobrapp_notify_loan_status()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare v_name text;
begin
  if lower(coalesce(new.status,'')) in ('paid','quitado','liquidated','liquidado')
     and lower(coalesce(old.status,'')) not in ('paid','quitado','liquidated','liquidado') then
    select name into v_name from public.cobrapp_customers where id=new.customer_id;
    insert into public.cobrapp_notifications(user_id,type,title,body,reference_type,reference_id,event_key)
    values(
      new.user_id,'loan_paid','Empréstimo quitado',
      'O empréstimo de '||coalesce(v_name,'Cliente')||' foi quitado.',
      'loan',new.id,'loan_paid:'||new.id::text
    ) on conflict(user_id,event_key) do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_cobrapp_notify_loan_status on public.cobrapp_loans;
create trigger trg_cobrapp_notify_loan_status
after update of status on public.cobrapp_loans
for each row execute function public.cobrapp_notify_loan_status();

create or replace function public.cobrapp_notify_customer_insert()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
  insert into public.cobrapp_notifications(user_id,type,title,body,reference_type,reference_id,event_key)
  values(
    new.user_id,'customer','Novo cliente','Cliente '||new.name||' cadastrado.',
    'customer',new.id,'customer:'||new.id::text
  ) on conflict(user_id,event_key) do nothing;
  return new;
end;
$$;

drop trigger if exists trg_cobrapp_notify_customer on public.cobrapp_customers;
create trigger trg_cobrapp_notify_customer
after insert on public.cobrapp_customers
for each row execute function public.cobrapp_notify_customer_insert();

grant execute on function public.cobrapp_sync_notifications(uuid) to authenticated;
grant execute on function public.cobrapp_is_premium(uuid) to authenticated;
