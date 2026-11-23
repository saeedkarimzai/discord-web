-- Discord Web Supabase database setup
-- Run this entire file in Supabase Dashboard -> SQL Editor.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null default 'User',
  created_at timestamptz not null default now()
);

create table if not exists public.servers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  icon text not null default 'D',
  owner_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.server_members (
  server_id uuid not null references public.servers(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner','member')),
  created_at timestamptz not null default now(),
  primary key (server_id, user_id)
);

create table if not exists public.channels (
  id uuid primary key default gen_random_uuid(),
  server_id uuid not null references public.servers(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  channel_id uuid not null references public.channels(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  content text not null check (char_length(content) between 1 and 2000),
  created_at timestamptz not null default now()
);

create index if not exists messages_channel_created_idx on public.messages(channel_id, created_at);
create index if not exists channels_server_idx on public.channels(server_id);
create index if not exists members_user_idx on public.server_members(user_id);

alter table public.profiles enable row level security;
alter table public.servers enable row level security;
alter table public.server_members enable row level security;
alter table public.channels enable row level security;
alter table public.messages enable row level security;

-- Explicit Data API privileges; RLS policies above remain the row-level security boundary.
grant usage on schema public to authenticated;
grant select,insert,update on public.profiles to authenticated;
grant select,insert,update,delete on public.servers to authenticated;
grant select,insert,delete on public.server_members to authenticated;
grant select,insert,update,delete on public.channels to authenticated;
grant select,insert,delete on public.messages to authenticated;


-- Profiles
 drop policy if exists "profiles readable by signed in users" on public.profiles;
create policy "profiles readable by signed in users" on public.profiles
for select to authenticated using (true);

drop policy if exists "users create own profile" on public.profiles;
create policy "users create own profile" on public.profiles
for insert to authenticated with check (id = (select auth.uid()));

drop policy if exists "users update own profile" on public.profiles;
create policy "users update own profile" on public.profiles
for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- Servers
 drop policy if exists "members can read servers" on public.servers;
create policy "members can read servers" on public.servers
for select to authenticated using (
  owner_id = (select auth.uid())
  or exists (
    select 1 from public.server_members m
    where m.server_id = public.servers.id and m.user_id = (select auth.uid())
  )
);

drop policy if exists "users create servers" on public.servers;
create policy "users create servers" on public.servers
for insert to authenticated with check (owner_id = (select auth.uid()));

drop policy if exists "owners update servers" on public.servers;
create policy "owners update servers" on public.servers
for update to authenticated using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));

drop policy if exists "owners delete servers" on public.servers;
create policy "owners delete servers" on public.servers
for delete to authenticated using (owner_id = (select auth.uid()));

-- Membership
-- Keep membership reads simple to avoid recursive RLS checks.
drop policy if exists "members can read memberships" on public.server_members;
drop policy if exists "users can read own memberships" on public.server_members;
create policy "users can read own memberships" on public.server_members
for select to authenticated using (user_id = (select auth.uid()));

drop policy if exists "users can join servers" on public.server_members;
drop policy if exists "server owners can add their own owner membership" on public.server_members;
create policy "server owners can add their own owner membership" on public.server_members
for insert to authenticated with check (
  user_id = (select auth.uid())
  and role = 'owner'
  and exists (
    select 1 from public.servers s
    where s.id = server_id and s.owner_id = (select auth.uid())
  )
);

drop policy if exists "users can leave own membership" on public.server_members;
create policy "members can leave their own membership" on public.server_members
for delete to authenticated using (
  user_id = (select auth.uid()) and role <> 'owner'
);

-- Channels
drop policy if exists "members can read channels" on public.channels;
create policy "members can read channels" on public.channels
for select to authenticated using (
  exists (
    select 1 from public.server_members m
    where m.server_id = public.channels.server_id and m.user_id = (select auth.uid())
  )
);

drop policy if exists "members can create channels" on public.channels;
drop policy if exists "server owners can create channels" on public.channels;
create policy "server owners can create channels" on public.channels
for insert to authenticated with check (
  exists (
    select 1 from public.servers s
    where s.id = public.channels.server_id
      and s.owner_id = (select auth.uid())
  )
);

drop policy if exists "members can update channels" on public.channels;
drop policy if exists "server owners can update channels" on public.channels;
create policy "server owners can update channels" on public.channels
for update to authenticated using (
  exists (
    select 1 from public.servers s
    where s.id = public.channels.server_id
      and s.owner_id = (select auth.uid())
  )
) with check (
  exists (
    select 1 from public.servers s
    where s.id = public.channels.server_id
      and s.owner_id = (select auth.uid())
  )
);

drop policy if exists "members can delete channels" on public.channels;
drop policy if exists "server owners can delete channels" on public.channels;
create policy "server owners can delete channels" on public.channels
for delete to authenticated using (
  exists (
    select 1 from public.servers s
    where s.id = public.channels.server_id
      and s.owner_id = (select auth.uid())
  )
);

-- Messages
drop policy if exists "members can read messages" on public.messages;
create policy "members can read messages" on public.messages
for select to authenticated using (
  exists (
    select 1
    from public.channels c
    join public.server_members m on m.server_id = c.server_id
    where c.id = public.messages.channel_id and m.user_id = (select auth.uid())
  )
);

drop policy if exists "members can send messages" on public.messages;
create policy "members can send messages" on public.messages
for insert to authenticated with check (
  user_id = (select auth.uid())
  and exists (
    select 1
    from public.channels c
    join public.server_members m on m.server_id = c.server_id
    where c.id = public.messages.channel_id and m.user_id = (select auth.uid())
  )
);

drop policy if exists "users can delete own messages" on public.messages;
create policy "members can delete own messages" on public.messages
for delete to authenticated using (
  user_id = (select auth.uid())
  and exists (
    select 1
    from public.channels c
    join public.server_members m on m.server_id = c.server_id
    where c.id = public.messages.channel_id
      and m.user_id = (select auth.uid())
  )
);

-- Automatically create a profile after signup.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $handler$
begin
  insert into public.profiles (id, username)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'username', split_part(coalesce(new.email, 'User'), '@', 1))
  )
  on conflict (id) do nothing;
  return new;
end;
$handler$;
revoke all on function public.handle_new_user() from public, anon, authenticated;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Enable realtime for chat messages without failing if it is already enabled.
do $$
begin
  alter publication supabase_realtime add table public.messages;
exception
  when duplicate_object then null;
end $$;


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
create index if not exists server_invites_server_id_idx on public.server_invites(server_id);
create index if not exists server_invites_created_by_idx on public.server_invites(created_by);
create index if not exists messages_user_id_idx on public.messages(user_id);
create index if not exists servers_owner_id_idx on public.servers(owner_id);
drop index if exists public.server_invites_code_idx;
alter table public.server_invites enable row level security;

do $revoke$
begin
  if to_regprocedure('public.rls_auto_enable()') is not null then
    execute 'revoke all on function public.rls_auto_enable() from public, anon, authenticated';
  end if;
end $revoke$;

create or replace function public.create_server_invite(
  p_server_id uuid,
  p_expires_at timestamptz default null,
  p_max_uses integer default null
) returns text
language plpgsql security definer
set search_path = ''
as $$
declare v_code text;
begin
  if auth.uid() is null then raise exception 'Sign in first.'; end if;
  if p_max_uses is not null and p_max_uses < 1 then raise exception 'Invite use limit must be positive.'; end if;
  if not exists(select 1 from public.servers s where s.id=p_server_id and s.owner_id=auth.uid()) then
    raise exception 'Only the server owner can create invites.';
  end if;
  v_code := lower(replace(gen_random_uuid()::text,'-',''));
  insert into public.server_invites(server_id,code,created_by,expires_at,max_uses)
  values(p_server_id,v_code,auth.uid(),p_expires_at,p_max_uses);
  return v_code;
end;
$$;

create or replace function public.join_server_by_invite(p_code text)
returns uuid
language plpgsql security definer
set search_path = ''
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
