-- Run this entire file once in Supabase Dashboard -> SQL Editor.
-- It creates the minimum cloud database for the Discord Web project.

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

-- Profiles
create policy "profiles readable by signed in users" on public.profiles
for select to authenticated using (true);
create policy "users create own profile" on public.profiles
for insert to authenticated with check (id = auth.uid());
create policy "users update own profile" on public.profiles
for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- Servers
create policy "members can read servers" on public.servers
for select to authenticated using (
  exists (select 1 from public.server_members m where m.server_id = id and m.user_id = auth.uid())
);
create policy "users create servers" on public.servers
for insert to authenticated with check (owner_id = auth.uid());
create policy "owners update servers" on public.servers
for update to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy "owners delete servers" on public.servers
for delete to authenticated using (owner_id = auth.uid());

-- Membership
create policy "members can read memberships" on public.server_members
for select to authenticated using (
  exists (select 1 from public.server_members me where me.server_id = server_id and me.user_id = auth.uid())
);
create policy "users can join servers" on public.server_members
for insert to authenticated with check (user_id = auth.uid());
create policy "users can leave own membership" on public.server_members
for delete to authenticated using (user_id = auth.uid());

-- Channels
create policy "members can read channels" on public.channels
for select to authenticated using (
  exists (select 1 from public.server_members m where m.server_id = channels.server_id and m.user_id = auth.uid())
);
create policy "members can create channels" on public.channels
for insert to authenticated with check (
  exists (select 1 from public.server_members m where m.server_id = server_id and m.user_id = auth.uid())
);
create policy "members can update channels" on public.channels
for update to authenticated using (
  exists (select 1 from public.server_members m where m.server_id = channels.server_id and m.user_id = auth.uid())
) with check (
  exists (select 1 from public.server_members m where m.server_id = server_id and m.user_id = auth.uid())
);
create policy "members can delete channels" on public.channels
for delete to authenticated using (
  exists (select 1 from public.server_members m where m.server_id = channels.server_id and m.user_id = auth.uid())
);

-- Messages
create policy "members can read messages" on public.messages
for select to authenticated using (
  exists (
    select 1 from public.channels c
    join public.server_members m on m.server_id = c.server_id
    where c.id = messages.channel_id and m.user_id = auth.uid()
  )
);
create policy "members can send messages" on public.messages
for insert to authenticated with check (
  user_id = auth.uid() and exists (
    select 1 from public.channels c
    join public.server_members m on m.server_id = c.server_id
    where c.id = channel_id and m.user_id = auth.uid()
  )
);
create policy "users can delete own messages" on public.messages
for delete to authenticated using (user_id = auth.uid());

-- Create/update a profile automatically after signup.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, username)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'username', split_part(coalesce(new.email, 'User'), '@', 1)))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Enable database-change realtime for chat messages.
alter publication supabase_realtime add table public.messages;
