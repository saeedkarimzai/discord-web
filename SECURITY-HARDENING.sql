-- Discord Web RLS hardening migration
-- Apply this to the existing Supabase project after reviewing the app's current access model.
-- The app currently has no invite/join flow, so only a server owner can add the initial owner
-- membership and manage channels. This prevents users from joining arbitrary servers by UUID.

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

drop policy if exists "users can delete own messages" on public.messages;
drop policy if exists "members can delete own messages" on public.messages;
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
