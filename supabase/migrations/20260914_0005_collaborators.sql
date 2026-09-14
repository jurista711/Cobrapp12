create extension if not exists pgcrypto;

create table if not exists public.cobrapp_collaborators (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  auth_user_id uuid unique references auth.users(id) on delete cascade,
  name text not null,
  email text not null,
  role text not null check (role in ('admin','manager','operational')),
  permissions jsonb not null default '{}'::jsonb,
  route_name text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(owner_id,email)
);

alter table public.cobrapp_collaborators enable row level security;
create policy cobrapp_collaborators_owner_all on public.cobrapp_collaborators for all using (owner_id=auth.uid()) with check (owner_id=auth.uid());
create policy cobrapp_collaborators_self_read on public.cobrapp_collaborators for select using (auth_user_id=auth.uid());

create or replace function public.cobrapp_create_collaborator(p_name text,p_email text,p_password text,p_role text,p_permissions jsonb,p_route_name text default null,p_is_active boolean default true)
returns uuid language plpgsql security definer set search_path=public,auth,extensions as $$
declare v_owner uuid:=auth.uid(); v_user uuid:=gen_random_uuid(); v_collab uuid; v_email text:=lower(trim(p_email));
begin
  if v_owner is null then raise exception 'Usuário não autenticado'; end if;
  if trim(coalesce(p_name,''))='' then raise exception 'Nome obrigatório'; end if;
  if v_email='' then raise exception 'E-mail obrigatório'; end if;
  if length(coalesce(p_password,''))<6 then raise exception 'A senha inicial deve ter pelo menos 6 caracteres'; end if;
  if p_role not in ('admin','manager','operational') then raise exception 'Nível de permissão inválido'; end if;
  if exists(select 1 from auth.users where lower(email)=v_email) then raise exception 'Já existe usuário com este e-mail'; end if;
  insert into auth.users(id,aud,role,email,encrypted_password,email_confirmed_at,confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,is_anonymous)
  values(v_user,'authenticated','authenticated',v_email,crypt(p_password,gen_salt('bf')),now(),now(),jsonb_build_object('provider','email','providers',jsonb_build_array('email'),'owner_id',v_owner,'collaborator',true,'collaborator_role',p_role,'permissions',coalesce(p_permissions,'{}'::jsonb)),jsonb_build_object('name',trim(p_name)),now(),now(),false);
  insert into auth.identities(provider_id,user_id,identity_data,provider,last_sign_in_at,created_at,updated_at,email)
  values(v_user::text,v_user,jsonb_build_object('sub',v_user::text,'email',v_email),'email',now(),now(),now(),v_email);
  insert into public.cobrapp_collaborators(owner_id,auth_user_id,name,email,role,permissions,route_name,is_active)
  values(v_owner,v_user,trim(p_name),v_email,p_role,coalesce(p_permissions,'{}'::jsonb),nullif(trim(coalesce(p_route_name,'')),''),p_is_active) returning id into v_collab;
  return v_collab;
end $$;

create or replace function public.cobrapp_update_collaborator(p_id uuid,p_name text,p_email text,p_password text,p_role text,p_permissions jsonb,p_route_name text,p_is_active boolean)
returns void language plpgsql security definer set search_path=public,auth,extensions as $$
declare v_owner uuid:=auth.uid(); v_auth_user uuid; v_email text:=lower(trim(p_email));
begin
  select auth_user_id into v_auth_user from public.cobrapp_collaborators where id=p_id and owner_id=v_owner;
  if v_auth_user is null then raise exception 'Colaborador não encontrado'; end if;
  if p_role not in ('admin','manager','operational') then raise exception 'Nível de permissão inválido'; end if;
  update public.cobrapp_collaborators set name=trim(p_name),email=v_email,role=p_role,permissions=coalesce(p_permissions,'{}'::jsonb),route_name=nullif(trim(coalesce(p_route_name,'')),''),is_active=p_is_active,updated_at=now() where id=p_id and owner_id=v_owner;
  update auth.users set email=v_email,raw_app_meta_data=jsonb_build_object('provider','email','providers',jsonb_build_array('email'),'owner_id',v_owner,'collaborator',true,'collaborator_role',p_role,'permissions',coalesce(p_permissions,'{}'::jsonb)),raw_user_meta_data=jsonb_build_object('name',trim(p_name)),updated_at=now(),banned_until=case when p_is_active then null else now()+interval '100 years' end where id=v_auth_user;
  update auth.identities set email=v_email,identity_data=jsonb_build_object('sub',v_auth_user::text,'email',v_email),updated_at=now() where user_id=v_auth_user and provider='email';
  if coalesce(trim(p_password),'')<>'' then
    if length(p_password)<6 then raise exception 'A senha deve ter pelo menos 6 caracteres'; end if;
    update auth.users set encrypted_password=crypt(p_password,gen_salt('bf')),updated_at=now() where id=v_auth_user;
  end if;
end $$;

grant execute on function public.cobrapp_create_collaborator(text,text,text,text,jsonb,text,boolean) to authenticated;
grant execute on function public.cobrapp_update_collaborator(uuid,text,text,text,text,jsonb,text,boolean) to authenticated;

create or replace function public.cobrapp_collaborator_has_access(p_owner uuid, p_area text)
returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.cobrapp_collaborators c where c.owner_id=p_owner and c.auth_user_id=auth.uid() and c.is_active and (c.role='admin' or coalesce((c.permissions->>p_area)::boolean,false)));
$$;
grant execute on function public.cobrapp_collaborator_has_access(uuid,text) to authenticated;

create index if not exists cobrapp_collaborators_owner_idx on public.cobrapp_collaborators(owner_id);
create index if not exists cobrapp_collaborators_auth_user_idx on public.cobrapp_collaborators(auth_user_id);
