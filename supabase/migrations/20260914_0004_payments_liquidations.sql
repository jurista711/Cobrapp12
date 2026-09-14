-- Etapa 4 — Pagamentos e Liquidações

alter table public.cobrapp_company_settings
  add column if not exists payment_methods text[] not null default array['Dinheiro','Pix','Cartão de Crédito','Cartão de Débito','Cheque','Transferência']::text[];

alter table public.cobrapp_payments
  add column if not exists registered_by uuid,
  add column if not exists registered_by_email text,
  add column if not exists batch_id uuid,
  add column if not exists late_fee_amount numeric not null default 0,
  add column if not exists credit_amount numeric not null default 0;

alter table public.cobrapp_installments
  add column if not exists late_interest_paid numeric not null default 0,
  add column if not exists late_fee_paid numeric not null default 0;

create table if not exists public.cobrapp_customer_credits (
  user_id uuid not null references auth.users(id) on delete cascade,
  customer_id uuid not null references public.cobrapp_customers(id) on delete cascade,
  balance numeric not null default 0,
  updated_at timestamptz not null default now(),
  primary key (user_id, customer_id)
);

alter table public.cobrapp_customer_credits enable row level security;
drop policy if exists cobrapp_customer_credits_all on public.cobrapp_customer_credits;
create policy cobrapp_customer_credits_all on public.cobrapp_customer_credits
for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create index if not exists cobrapp_payments_batch_idx on public.cobrapp_payments(user_id,batch_id);
create index if not exists cobrapp_payments_paid_at_idx on public.cobrapp_payments(user_id,paid_at);

create or replace function public.cobrapp_registrar_pagamento_etapa4(
  p_customer_id uuid,
  p_loan_id uuid,
  p_installment_ids uuid[] default null,
  p_amount numeric default 0,
  p_method text default 'Dinheiro',
  p_paid_at date default current_date,
  p_notes text default null,
  p_auto_apply boolean default false
) returns jsonb
language plpgsql
security invoker
as $$
declare
  v_user uuid := auth.uid();
  v_email text := auth.jwt() ->> 'email';
  v_remaining numeric := round(p_amount,2);
  v_batch uuid := gen_random_uuid();
  v_applied numeric := 0;
  v_credit numeric := 0;
  v_first_payment uuid;
  v_payment uuid;
  v_principal_due numeric;
  v_late_interest_accrued numeric;
  v_late_interest_due numeric;
  v_fee_due numeric;
  v_principal_part numeric;
  v_late_interest_part numeric;
  v_fee_part numeric;
  v_row_total numeric;
  v_new_paid numeric;
  v_days_late integer;
  v_new_status text;
  r record;
begin
  if v_user is null then raise exception 'Usuário não autenticado'; end if;
  if p_amount <= 0 then raise exception 'O valor deve ser maior que zero'; end if;
  if not exists(select 1 from public.cobrapp_customers where id=p_customer_id and user_id=v_user) then raise exception 'Cliente não encontrado'; end if;
  if not exists(select 1 from public.cobrapp_loans where id=p_loan_id and customer_id=p_customer_id and user_id=v_user) then raise exception 'Empréstimo não encontrado'; end if;
  if not p_auto_apply and coalesce(array_length(p_installment_ids,1),0)=0 then raise exception 'Selecione ao menos uma parcela'; end if;

  for r in
    select i.*, l.late_interest_enabled, l.late_interest_rate, l.late_fee_base
      from public.cobrapp_installments i
      join public.cobrapp_loans l on l.id=i.loan_id
     where i.user_id=v_user and i.loan_id=p_loan_id
       and i.status not in ('paid','renegotiated')
       and (p_auto_apply or i.id = any(coalesce(p_installment_ids,'{}'::uuid[])))
     order by i.due_date, i.number
  loop
    exit when v_remaining <= 0;
    v_principal_due := greatest(round(r.amount - coalesce(r.paid_amount,0),2),0);
    v_days_late := greatest((p_paid_at - r.due_date),0);
    if r.late_interest_enabled and v_days_late > 0 then
      v_late_interest_accrued := round(v_principal_due * (coalesce(r.late_interest_rate,0)/100) * (v_days_late/30.0),2);
    else
      v_late_interest_accrued := 0;
    end if;
    v_late_interest_due := greatest(v_late_interest_accrued - coalesce(r.late_interest_paid,0),0);
    v_fee_due := case when v_days_late > 0 then greatest(coalesce(r.late_fee_base,0) - coalesce(r.late_fee_paid,0),0) else 0 end;
    v_fee_part := least(v_remaining, v_fee_due);
    v_remaining := round(v_remaining - v_fee_part,2);
    v_late_interest_part := least(v_remaining, v_late_interest_due);
    v_remaining := round(v_remaining - v_late_interest_part,2);
    v_principal_part := least(v_remaining, v_principal_due);
    v_remaining := round(v_remaining - v_principal_part,2);
    v_row_total := round(v_fee_part + v_late_interest_part + v_principal_part,2);

    if v_row_total > 0 then
      v_new_paid := round(coalesce(r.paid_amount,0) + v_principal_part,2);
      v_new_status := case when v_new_paid >= r.amount and (coalesce(r.late_interest_paid,0)+v_late_interest_part) >= v_late_interest_accrued and (coalesce(r.late_fee_paid,0)+v_fee_part) >= coalesce(r.late_fee_base,0) then 'paid' else 'partial' end;
      insert into public.cobrapp_payments(user_id,customer_id,loan_id,installment_id,amount,paid_at,method,notes,type,principal_amount,late_interest_amount,late_fee_amount,registered_by,registered_by_email,batch_id)
      values(v_user,p_customer_id,p_loan_id,r.id,v_row_total,p_paid_at,p_method,p_notes,'total',v_principal_part,v_late_interest_part,v_fee_part,v_user,v_email,v_batch)
      returning id into v_payment;
      if v_first_payment is null then v_first_payment := v_payment; end if;
      update public.cobrapp_installments
         set paid_amount=v_new_paid,
             late_interest_paid=coalesce(late_interest_paid,0)+v_late_interest_part,
             late_fee_paid=coalesce(late_fee_paid,0)+v_fee_part,
             status=v_new_status,
             paid_at=case when v_new_status='paid' then p_paid_at else paid_at end
       where id=r.id and user_id=v_user;
      v_applied := round(v_applied + v_row_total,2);
    end if;
  end loop;

  if v_remaining > 0 then
    v_credit := v_remaining;
    insert into public.cobrapp_payments(user_id,customer_id,loan_id,installment_id,amount,paid_at,method,notes,type,credit_amount,registered_by,registered_by_email,batch_id)
    values(v_user,p_customer_id,p_loan_id,null,v_credit,p_paid_at,p_method,coalesce(p_notes,'') || case when p_notes is null or p_notes='' then '' else ' • ' end || 'Crédito para parcelas futuras','credit',v_credit,v_user,v_email,v_batch)
    returning id into v_payment;
    if v_first_payment is null then v_first_payment := v_payment; end if;
    insert into public.cobrapp_customer_credits(user_id,customer_id,balance,updated_at)
    values(v_user,p_customer_id,v_credit,now())
    on conflict(user_id,customer_id) do update set balance=public.cobrapp_customer_credits.balance + excluded.balance,updated_at=now();
  end if;

  if not exists(select 1 from public.cobrapp_installments where loan_id=p_loan_id and user_id=v_user and status not in ('paid','renegotiated')) then
    update public.cobrapp_loans set status='paid',updated_at=now() where id=p_loan_id and user_id=v_user;
  end if;

  return jsonb_build_object('batch_id',v_batch,'first_payment_id',v_first_payment,'amount_received',round(p_amount,2),'amount_applied',v_applied,'credit',v_credit,'remaining_balance',(select coalesce(round(sum(greatest(amount-coalesce(paid_amount,0),0)),2),0) from public.cobrapp_installments where loan_id=p_loan_id and user_id=v_user and status not in ('paid','renegotiated')));
end;
$$;

grant execute on function public.cobrapp_registrar_pagamento_etapa4(uuid,uuid,uuid[],numeric,text,date,text,boolean) to authenticated;
