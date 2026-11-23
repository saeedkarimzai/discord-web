
-- Secure invite codes for Discord Web. Run in Supabase SQL Editor.
create table if not exists public.server_invites (
  id uuid primary key default gen_random_uuid(),
  server_id uuid not null references public.servers(id) on delete cascade,
  code text not null unique,
  created_by uuid not null references auth.users(id) on delete cascade,
  expires_at timestamptz,
  max_uses integer check (max_uses is null or max_uses > 0),
  uses integer not null default 0 check (uses >= 0),
  created_at timestamptz not null default now()
);
create index if not exists server_invites_code_idx on public.server_invites(code);
alter table public.server_invites enable row level security;

create or replace function public.create_server_invite(
  p_server_id uuid,
  p_expires_at timestamptz default null,
  p_max_uses integer default null
) returns text
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare v_code text;
begin
  if auth.uid() is null then raise exception 'Sign in first.'; end if;
  if p_max_uses is not null and p_max_uses < 1 then raise exception 'Invite use limit must be positive.'; end if;
  if not exists(select 1 from public.servers s where s.id=p_server_id and s.owner_id=auth.uid()) then
    raise exception 'Only the server owner can create invites.';
  end if;
  v_code := lower(encode(gen_random_bytes(8),'hex'));
  insert into public.server_invites(server_id,code,created_by,expires_at,max_uses)
  values(p_server_id,v_code,auth.uid(),p_expires_at,p_max_uses);
  return v_code;
end;
$$;

create or replace function public.join_server_by_invite(p_code text)
returns uuid
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare v_invite public.server_invites%rowtype; v_inserted integer;
begin
  if auth.uid() is null then raise exception 'Sign in first.'; end if;
  select * into v_invite from public.server_invites
  where code=lower(trim(p_code)) for update;
  if not found then raise exception 'Invite code not found.'; end if;
  if v_invite.expires_at is not null and v_invite.expires_at <= now() then raise exception 'This invite has expired.'; end if;
  if v_invite.max_uses is not null and v_invite.uses >= v_invite.max_uses then raise exception 'This invite has reached its use limit.'; end if;
  insert into public.server_members(server_id,user_id,role)
  values(v_invite.server_id,auth.uid(),'member')
  on conflict(server_id,user_id) do nothing;
  get diagnostics v_inserted = row_count;
  if v_inserted > 0 then
    update public.server_invites set uses=uses+1 where id=v_invite.id;
  end if;
  return v_invite.server_id;
end;
$$;

revoke all on function public.create_server_invite(uuid,timestamptz,integer) from public, anon;
revoke all on function public.join_server_by_invite(text) from public, anon;
grant execute on function public.create_server_invite(uuid,timestamptz,integer) to authenticated;
grant execute on function public.join_server_by_invite(text) to authenticated;
