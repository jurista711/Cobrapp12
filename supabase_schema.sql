-- CobrApp / PrestApp - schema Supabase (Etapa 4)
create table if not exists public.cobrapp_customers (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 name text not null, phone text, document text, address text, notes text, created_at timestamptz not null default now()
);
create table if not exists public.cobrapp_loans (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 customer_id uuid not null references public.cobrapp_customers(id) on delete cascade,
 principal numeric(14,2) not null check (principal > 0), installments integer not null default 1 check (installments > 0),
 interest_rate numeric(8,2) not null default 0, status text not null default 'active',
 total_amount numeric(14,2), created_at timestamptz not null default now()
);
create table if not exists public.cobrapp_installments (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 loan_id uuid not null references public.cobrapp_loans(id) on delete cascade, customer_id uuid not null references public.cobrapp_customers(id) on delete cascade,
 number integer not null, due_date date not null, amount numeric(14,2) not null check (amount > 0), paid_amount numeric(14,2) not null default 0,
 status text not null default 'pending', paid_at date, created_at timestamptz not null default now(),
 unique(loan_id, number)
);
create table if not exists public.cobrapp_payments (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 customer_id uuid not null references public.cobrapp_customers(id) on delete cascade,
 loan_id uuid references public.cobrapp_loans(id) on delete set null,
 installment_id uuid references public.cobrapp_installments(id) on delete set null,
 amount numeric(14,2) not null check (amount > 0), paid_at date not null default current_date, method text, notes text, created_at timestamptz not null default now()
);

alter table public.cobrapp_customers enable row level security;
alter table public.cobrapp_loans enable row level security;
alter table public.cobrapp_installments enable row level security;
alter table public.cobrapp_payments enable row level security;

drop policy if exists cobrapp_customers_all on public.cobrapp_customers;
drop policy if exists cobrapp_loans_all on public.cobrapp_loans;
drop policy if exists cobrapp_installments_all on public.cobrapp_installments;
drop policy if exists cobrapp_payments_all on public.cobrapp_payments;
create policy cobrapp_customers_all on public.cobrapp_customers for all to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());
create policy cobrapp_loans_all on public.cobrapp_loans for all to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());
create policy cobrapp_installments_all on public.cobrapp_installments for all to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());
create policy cobrapp_payments_all on public.cobrapp_payments for all to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());

grant select,insert,update,delete on public.cobrapp_customers, public.cobrapp_loans, public.cobrapp_installments, public.cobrapp_payments to authenticated;
create index if not exists cobrapp_loans_customer_idx on public.cobrapp_loans(customer_id);
create index if not exists cobrapp_installments_loan_idx on public.cobrapp_installments(loan_id);
create index if not exists cobrapp_installments_due_idx on public.cobrapp_installments(due_date);
create index if not exists cobrapp_payments_customer_idx on public.cobrapp_payments(customer_id);
create index if not exists cobrapp_payments_loan_idx on public.cobrapp_payments(loan_id);

-- Cria as parcelas do empréstimo de forma atômica.
create or replace function public.cobrapp_criar_emprestimo(
 p_customer_id uuid, p_principal numeric, p_installments integer, p_interest_rate numeric default 0
) returns jsonb language plpgsql security definer set search_path=public as $$
declare v_user uuid:=auth.uid(); v_loan uuid; v_total numeric; v_each numeric; v_last numeric; i integer;
begin
 if v_user is null then raise exception 'Usuário não autenticado'; end if;
 if not exists(select 1 from public.cobrapp_customers where id=p_customer_id and user_id=v_user) then raise exception 'Cliente não encontrado'; end if;
 if p_principal<=0 or p_installments<1 then raise exception 'Dados do empréstimo inválidos'; end if;
 v_total:=round(p_principal*(1+coalesce(p_interest_rate,0)/100),2);
 v_each:=round(v_total/p_installments,2); v_last:=v_total-(v_each*(p_installments-1));
 insert into public.cobrapp_loans(user_id,customer_id,principal,installments,interest_rate,status,total_amount)
 values(v_user,p_customer_id,p_principal,p_installments,coalesce(p_interest_rate,0),'active',v_total) returning id into v_loan;
 for i in 1..p_installments loop
   insert into public.cobrapp_installments(user_id,loan_id,customer_id,number,due_date,amount)
   values(v_user,v_loan,p_customer_id,i,(current_date + ((i-1)*30)),case when i=p_installments then v_last else v_each end);
 end loop;
 return jsonb_build_object('loan_id',v_loan,'total_amount',v_total,'installment_amount',v_each);
end $$;
revoke execute on function public.cobrapp_criar_emprestimo(uuid,numeric,integer,numeric) from public,anon;
grant execute on function public.cobrapp_criar_emprestimo(uuid,numeric,integer,numeric) to authenticated;

-- Registra pagamento parcial ou integral em uma parcela.
create or replace function public.cobrapp_registrar_pagamento(
 p_installment_id uuid, p_amount numeric, p_method text default 'Dinheiro', p_notes text default null
) returns jsonb language plpgsql security definer set search_path=public as $$
declare v_user uuid:=auth.uid(); v_i public.cobrapp_installments%rowtype; v_left numeric; v_new numeric; v_status text; v_pid uuid;
begin
 if v_user is null then raise exception 'Usuário não autenticado'; end if;
 select * into v_i from public.cobrapp_installments where id=p_installment_id and user_id=v_user for update;
 if not found then raise exception 'Parcela não encontrada'; end if;
 v_left:=v_i.amount-coalesce(v_i.paid_amount,0);
 if p_amount<=0 or p_amount>v_left then raise exception 'Valor inválido. Saldo da parcela: R$ %',v_left; end if;
 v_new:=coalesce(v_i.paid_amount,0)+p_amount; v_status:=case when v_new>=v_i.amount then 'paid' else 'partial' end;
 insert into public.cobrapp_payments(user_id,customer_id,loan_id,installment_id,amount,method,notes) values(v_user,v_i.customer_id,v_i.loan_id,v_i.id,p_amount,p_method,p_notes) returning id into v_pid;
 update public.cobrapp_installments set paid_amount=v_new,status=v_status,paid_at=case when v_status='paid' then current_date else paid_at end where id=v_i.id;
 if not exists(select 1 from public.cobrapp_installments where loan_id=v_i.loan_id and status<>'paid') then update public.cobrapp_loans set status='paid' where id=v_i.loan_id and user_id=v_user; end if;
 return jsonb_build_object('payment_id',v_pid,'installment_id',v_i.id,'amount',p_amount,'paid_amount',v_new,'remaining',v_i.amount-v_new,'status',v_status);
end $$;
revoke execute on function public.cobrapp_registrar_pagamento(uuid,numeric,text,text) from public,anon;
grant execute on function public.cobrapp_registrar_pagamento(uuid,numeric,text,text) to authenticated;


-- Etapa 6: tipos de cobrança, juros e histórico detalhado.
alter table public.cobrapp_payments add column if not exists type text not null default 'total';
alter table public.cobrapp_installments add column if not exists interest_amount numeric(14,2) not null default 0;
alter table public.cobrapp_installments add column if not exists interest_paid numeric(14,2) not null default 0;
alter table public.cobrapp_installments add column if not exists late_fee numeric(14,2) not null default 0;

create index if not exists cobrapp_payments_type_idx on public.cobrapp_payments(type);

create or replace function public.cobrapp_registrar_pagamento(
 p_installment_id uuid, p_amount numeric, p_method text default 'Dinheiro', p_notes text default null, p_type text default 'total'
) returns jsonb language plpgsql security definer set search_path=public as $$
declare
 v_user uuid:=auth.uid(); v_i public.cobrapp_installments%rowtype; v_left numeric; v_new numeric; v_status text; v_pid uuid;
begin
 if v_user is null then raise exception 'Usuário não autenticado'; end if;
 if p_type not in ('total','interest','late_interest') then raise exception 'Tipo de cobrança inválido'; end if;
 select * into v_i from public.cobrapp_installments where id=p_installment_id and user_id=v_user for update;
 if not found then raise exception 'Parcela não encontrada'; end if;
 if p_amount<=0 then raise exception 'O valor deve ser maior que zero'; end if;
 if p_type='interest' then
   insert into public.cobrapp_payments(user_id,customer_id,loan_id,installment_id,amount,method,notes,type) values(v_user,v_i.customer_id,v_i.loan_id,v_i.id,p_amount,p_method,p_notes,'interest') returning id into v_pid;
   update public.cobrapp_installments set interest_paid=coalesce(interest_paid,0)+p_amount where id=v_i.id;
   return jsonb_build_object('payment_id',v_pid,'installment_id',v_i.id,'amount',p_amount,'remaining',greatest(v_i.amount-coalesce(v_i.paid_amount,0),0),'status',v_i.status,'message','Juros registrados.');
 elsif p_type='late_interest' then
   insert into public.cobrapp_payments(user_id,customer_id,loan_id,installment_id,amount,method,notes,type) values(v_user,v_i.customer_id,v_i.loan_id,v_i.id,p_amount,p_method,p_notes,'late_interest') returning id into v_pid;
   update public.cobrapp_installments set late_fee=coalesce(late_fee,0)+p_amount where id=v_i.id;
   return jsonb_build_object('payment_id',v_pid,'installment_id',v_i.id,'amount',p_amount,'remaining',greatest(v_i.amount-coalesce(v_i.paid_amount,0),0),'status',v_i.status,'message','Juros de atraso registrados.');
 end if;
 v_left:=v_i.amount-coalesce(v_i.paid_amount,0);
 if p_amount>v_left then raise exception 'Valor inválido. Saldo da parcela: R$ %',v_left; end if;
 v_new:=coalesce(v_i.paid_amount,0)+p_amount; v_status:=case when v_new>=v_i.amount then 'paid' else 'partial' end;
 insert into public.cobrapp_payments(user_id,customer_id,loan_id,installment_id,amount,method,notes,type) values(v_user,v_i.customer_id,v_i.loan_id,v_i.id,p_amount,p_method,p_notes,'total') returning id into v_pid;
 update public.cobrapp_installments set paid_amount=v_new,status=v_status,paid_at=case when v_status='paid' then current_date else paid_at end where id=v_i.id;
 if not exists(select 1 from public.cobrapp_installments where loan_id=v_i.loan_id and status<>'paid') then update public.cobrapp_loans set status='paid' where id=v_i.loan_id and user_id=v_user; end if;
 return jsonb_build_object('payment_id',v_pid,'installment_id',v_i.id,'amount',p_amount,'paid_amount',v_new,'remaining',v_i.amount-v_new,'status',v_status,'message','Pagamento registrado.');
end $$;
revoke execute on function public.cobrapp_registrar_pagamento(uuid,numeric,text,text,text) from public,anon;
grant execute on function public.cobrapp_registrar_pagamento(uuid,numeric,text,text,text) to authenticated;


-- Etapa 8: recibos numerados e comprovante da cobrança.
create sequence if not exists public.cobrapp_receipt_number_seq;
create table if not exists public.cobrapp_receipts (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 payment_id uuid not null references public.cobrapp_payments(id) on delete cascade,
 customer_id uuid not null references public.cobrapp_customers(id) on delete cascade,
 receipt_number bigint not null unique default nextval('public.cobrapp_receipt_number_seq'),
 amount numeric(14,2) not null,
 issued_at timestamptz not null default now(),
 text_content text not null
);
alter table public.cobrapp_receipts enable row level security;
drop policy if exists cobrapp_receipts_all on public.cobrapp_receipts;
create policy cobrapp_receipts_all on public.cobrapp_receipts for all to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());
grant select,insert on public.cobrapp_receipts to authenticated;
create index if not exists cobrapp_receipts_payment_idx on public.cobrapp_receipts(payment_id);

-- Substitui a RPC da Etapa 6 acrescentando a emissão automática do recibo.
create or replace function public.cobrapp_registrar_pagamento(
 p_installment_id uuid, p_amount numeric, p_method text default 'Dinheiro', p_notes text default null, p_type text default 'total'
) returns jsonb language plpgsql security definer set search_path=public as $$
declare
 v_user uuid:=auth.uid(); v_i public.cobrapp_installments%rowtype; v_left numeric; v_new numeric; v_status text; v_pid uuid; v_rid uuid; v_receipt bigint; v_customer text; v_text text;
begin
 if v_user is null then raise exception 'Usuário não autenticado'; end if;
 if p_type not in ('total','interest','late_interest') then raise exception 'Tipo de cobrança inválido'; end if;
 select * into v_i from public.cobrapp_installments where id=p_installment_id and user_id=v_user for update;
 if not found then raise exception 'Parcela não encontrada'; end if;
 if p_amount<=0 then raise exception 'O valor deve ser maior que zero'; end if;
 select name into v_customer from public.cobrapp_customers where id=v_i.customer_id and user_id=v_user;
 if p_type='interest' then
   insert into public.cobrapp_payments(user_id,customer_id,loan_id,installment_id,amount,method,notes,type) values(v_user,v_i.customer_id,v_i.loan_id,v_i.id,p_amount,p_method,p_notes,'interest') returning id into v_pid;
   update public.cobrapp_installments set interest_paid=coalesce(interest_paid,0)+p_amount where id=v_i.id;
 elsif p_type='late_interest' then
   insert into public.cobrapp_payments(user_id,customer_id,loan_id,installment_id,amount,method,notes,type) values(v_user,v_i.customer_id,v_i.loan_id,v_i.id,p_amount,p_method,p_notes,'late_interest') returning id into v_pid;
   update public.cobrapp_installments set late_fee=coalesce(late_fee,0)+p_amount where id=v_i.id;
 else
   v_left:=v_i.amount-coalesce(v_i.paid_amount,0);
   if p_amount>v_left then raise exception 'Valor inválido. Saldo da parcela: R$ %',v_left; end if;
   v_new:=coalesce(v_i.paid_amount,0)+p_amount; v_status:=case when v_new>=v_i.amount then 'paid' else 'partial' end;
   insert into public.cobrapp_payments(user_id,customer_id,loan_id,installment_id,amount,method,notes,type) values(v_user,v_i.customer_id,v_i.loan_id,v_i.id,p_amount,p_method,p_notes,'total') returning id into v_pid;
   update public.cobrapp_installments set paid_amount=v_new,status=v_status,paid_at=case when v_status='paid' then current_date else paid_at end where id=v_i.id;
   if not exists(select 1 from public.cobrapp_installments where loan_id=v_i.loan_id and status<>'paid') then update public.cobrapp_loans set status='paid' where id=v_i.loan_id and user_id=v_user; end if;
 end if;
 v_receipt:=nextval('public.cobrapp_receipt_number_seq');
 v_text:='COBRAPP - RECIBO' || chr(10) || 'Recibo: #' || v_receipt::text || chr(10) || 'Cliente: ' || coalesce(v_customer,'') || chr(10) || 'Parcela: ' || v_i.number::text || chr(10) || 'Valor: R$ ' || replace(to_char(p_amount,'FM999999990.00'),'.',',') || chr(10) || 'Tipo: ' || case p_type when 'interest' then 'Somente juros' when 'late_interest' then 'Juros de atraso' else 'Pagamento' end || chr(10) || 'Forma: ' || coalesce(p_method,'') || chr(10) || 'Data: ' || current_date::text;
 insert into public.cobrapp_receipts(user_id,payment_id,customer_id,receipt_number,amount,text_content) values(v_user,v_pid,v_i.customer_id,v_receipt,p_amount,v_text) returning id into v_rid;
 return jsonb_build_object('payment_id',v_pid,'receipt_id',v_rid,'receipt_number',v_receipt,'installment_id',v_i.id,'amount',p_amount,'paid_amount',coalesce(v_new,v_i.paid_amount),'remaining',greatest(v_i.amount-coalesce(v_new,v_i.paid_amount),0),'status',coalesce(v_status,v_i.status),'message',case p_type when 'interest' then 'Juros registrados.' when 'late_interest' then 'Juros de atraso registrados.' else 'Pagamento registrado.' end,'receipt_text',v_text);
end $$;
revoke execute on function public.cobrapp_registrar_pagamento(uuid,numeric,text,text,text) from public,anon;
grant execute on function public.cobrapp_registrar_pagamento(uuid,numeric,text,text,text) to authenticated;


-- Etapa 9: controle de caixa/despesas.
create table if not exists public.cobrapp_expenses (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 amount numeric(14,2) not null check (amount > 0),
 description text not null,
 category text not null default 'Geral',
 spent_at date not null default current_date,
 created_at timestamptz not null default now()
);
alter table public.cobrapp_expenses enable row level security;
drop policy if exists cobrapp_expenses_all on public.cobrapp_expenses;
create policy cobrapp_expenses_all on public.cobrapp_expenses for all to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());
grant select,insert,update,delete on public.cobrapp_expenses to authenticated;
create index if not exists cobrapp_expenses_spent_at_idx on public.cobrapp_expenses(spent_at);
create index if not exists cobrapp_expenses_category_idx on public.cobrapp_expenses(category);


-- Etapa 10: rotas de cobrança e distribuição de clientes.
create table if not exists public.cobrapp_routes (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 name text not null,
 description text,
 created_at timestamptz not null default now()
);
create table if not exists public.cobrapp_customer_routes (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 route_id uuid not null references public.cobrapp_routes(id) on delete cascade,
 customer_id uuid not null references public.cobrapp_customers(id) on delete cascade,
 created_at timestamptz not null default now(),
 unique(customer_id)
);
alter table public.cobrapp_routes enable row level security;
alter table public.cobrapp_customer_routes enable row level security;
drop policy if exists cobrapp_routes_all on public.cobrapp_routes;
drop policy if exists cobrapp_customer_routes_all on public.cobrapp_customer_routes;
create policy cobrapp_routes_all on public.cobrapp_routes for all to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());
create policy cobrapp_customer_routes_all on public.cobrapp_customer_routes for all to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());
grant select,insert,update,delete on public.cobrapp_routes, public.cobrapp_customer_routes to authenticated;
create index if not exists cobrapp_routes_user_idx on public.cobrapp_routes(user_id);
create index if not exists cobrapp_customer_routes_route_idx on public.cobrapp_customer_routes(route_id);
create index if not exists cobrapp_customer_routes_customer_idx on public.cobrapp_customer_routes(customer_id);

-- Etapa 14: perfil e configurações do usuário
create table if not exists public.cobrapp_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  name text not null default '',
  phone text,
  business_name text,
  currency text not null default 'BRL',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.cobrapp_profiles enable row level security;
drop policy if exists cobrapp_profiles_all on public.cobrapp_profiles;
create policy cobrapp_profiles_all on public.cobrapp_profiles for all to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());
grant select,insert,update,delete on public.cobrapp_profiles to authenticated;
create index if not exists cobrapp_profiles_user_idx on public.cobrapp_profiles(user_id);
