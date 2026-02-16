-- DeepX web production overhaul
-- Backward-compatible migration.

begin;

-- ----------------------------------
-- Profiles + user settings extensions
-- ----------------------------------
alter table if exists public.profiles
  add column if not exists gender text,
  add column if not exists birth_date date,
  add column if not exists onboarding_completed boolean not null default false;

create index if not exists idx_profiles_onboarding_completed
  on public.profiles(onboarding_completed);

update public.profiles
set onboarding_completed = false
where onboarding_completed is null;

alter table if exists public.user_settings
  add column if not exists tracker_enabled boolean,
  add column if not exists tracker_ui_visible boolean;

update public.user_settings
set tracker_enabled = true
where tracker_enabled is null;

update public.user_settings
set tracker_ui_visible = false
where tracker_ui_visible is null;

alter table if exists public.user_settings
  alter column tracker_enabled set default true,
  alter column tracker_enabled set not null,
  alter column tracker_ui_visible set default false,
  alter column tracker_ui_visible set not null;

-- -------------------------
-- Collections and item stack
-- -------------------------
create table if not exists public.collections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(trim(name)) > 0),
  description text not null default '',
  published boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.collection_items (
  id uuid primary key default gen_random_uuid(),
  collection_id uuid not null references public.collections(id) on delete cascade,
  position integer not null check (position >= 0),
  mode public.render_mode not null,
  preset_name text not null check (char_length(trim(preset_name)) > 0),
  preset_snapshot jsonb not null check (jsonb_typeof(preset_snapshot) = 'object'),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint collection_items_collection_position_unique unique (collection_id, position)
);

create index if not exists idx_collections_owner_updated
  on public.collections(user_id, updated_at desc);
create index if not exists idx_collections_published_updated
  on public.collections(published, updated_at desc);
create index if not exists idx_collection_items_collection_position
  on public.collection_items(collection_id, position);

drop trigger if exists trg_collections_updated_at on public.collections;
create trigger trg_collections_updated_at
before update on public.collections
for each row execute function public.set_updated_at();

drop trigger if exists trg_collection_items_updated_at on public.collection_items;
create trigger trg_collection_items_updated_at
before update on public.collection_items
for each row execute function public.set_updated_at();

alter table public.collections enable row level security;
alter table public.collection_items enable row level security;

drop policy if exists collections_select_published_or_owner on public.collections;
create policy collections_select_published_or_owner
  on public.collections
  for select
  to authenticated
  using (published = true or auth.uid() = user_id);

drop policy if exists collections_insert_own on public.collections;
create policy collections_insert_own
  on public.collections
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists collections_update_own on public.collections;
create policy collections_update_own
  on public.collections
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists collections_delete_own on public.collections;
create policy collections_delete_own
  on public.collections
  for delete
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists collection_items_select_visible_collection on public.collection_items;
create policy collection_items_select_visible_collection
  on public.collection_items
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.collections c
      where c.id = collection_items.collection_id
        and (c.published = true or c.user_id = auth.uid())
    )
  );

drop policy if exists collection_items_insert_owner on public.collection_items;
create policy collection_items_insert_owner
  on public.collection_items
  for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.collections c
      where c.id = collection_items.collection_id
        and c.user_id = auth.uid()
    )
  );

drop policy if exists collection_items_update_owner on public.collection_items;
create policy collection_items_update_owner
  on public.collection_items
  for update
  to authenticated
  using (
    exists (
      select 1
      from public.collections c
      where c.id = collection_items.collection_id
        and c.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from public.collections c
      where c.id = collection_items.collection_id
        and c.user_id = auth.uid()
    )
  );

drop policy if exists collection_items_delete_owner on public.collection_items;
create policy collection_items_delete_owner
  on public.collection_items
  for delete
  to authenticated
  using (
    exists (
      select 1
      from public.collections c
      where c.id = collection_items.collection_id
        and c.user_id = auth.uid()
    )
  );

-- -----------------------------------
-- Chat policy recursion-safe helpers
-- -----------------------------------
create or replace function public.is_chat_member(
  p_chat_id uuid,
  p_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.chat_members m
    where m.chat_id = p_chat_id
      and m.user_id = coalesce(p_user_id, auth.uid())
  );
$$;

create or replace function public.is_chat_admin(
  p_chat_id uuid,
  p_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.chat_members m
    where m.chat_id = p_chat_id
      and m.user_id = coalesce(p_user_id, auth.uid())
      and m.role in ('owner', 'admin')
  );
$$;

create or replace function public.is_chat_owner(
  p_chat_id uuid,
  p_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.chat_members m
    where m.chat_id = p_chat_id
      and m.user_id = coalesce(p_user_id, auth.uid())
      and m.role = 'owner'
  );
$$;

grant execute on function public.is_chat_member(uuid, uuid) to authenticated;
grant execute on function public.is_chat_admin(uuid, uuid) to authenticated;
grant execute on function public.is_chat_owner(uuid, uuid) to authenticated;

drop policy if exists chats_select_member on public.chats;
create policy chats_select_member
  on public.chats
  for select
  to authenticated
  using (public.is_chat_member(chats.id, auth.uid()));

drop policy if exists chats_insert_own on public.chats;
create policy chats_insert_own
  on public.chats
  for insert
  to authenticated
  with check (auth.uid() = created_by);

drop policy if exists chats_update_admin on public.chats;
create policy chats_update_admin
  on public.chats
  for update
  to authenticated
  using (public.is_chat_admin(chats.id, auth.uid()))
  with check (public.is_chat_admin(chats.id, auth.uid()));

drop policy if exists chats_delete_owner on public.chats;
create policy chats_delete_owner
  on public.chats
  for delete
  to authenticated
  using (public.is_chat_owner(chats.id, auth.uid()));

drop policy if exists chat_members_select_chat_member on public.chat_members;
create policy chat_members_select_chat_member
  on public.chat_members
  for select
  to authenticated
  using (public.is_chat_member(chat_members.chat_id, auth.uid()));

drop policy if exists chat_members_insert_owner_or_self on public.chat_members;
create policy chat_members_insert_owner_or_self
  on public.chat_members
  for insert
  to authenticated
  with check (
    auth.uid() = user_id
    or exists (
      select 1
      from public.chats c
      where c.id = chat_members.chat_id
        and c.created_by = auth.uid()
    )
    or public.is_chat_admin(chat_members.chat_id, auth.uid())
  );

drop policy if exists chat_members_update_admin on public.chat_members;
create policy chat_members_update_admin
  on public.chat_members
  for update
  to authenticated
  using (public.is_chat_admin(chat_members.chat_id, auth.uid()))
  with check (public.is_chat_admin(chat_members.chat_id, auth.uid()));

drop policy if exists chat_members_delete_self_or_admin on public.chat_members;
create policy chat_members_delete_self_or_admin
  on public.chat_members
  for delete
  to authenticated
  using (
    auth.uid() = user_id
    or public.is_chat_admin(chat_members.chat_id, auth.uid())
  );

drop policy if exists chat_messages_select_chat_member on public.chat_messages;
create policy chat_messages_select_chat_member
  on public.chat_messages
  for select
  to authenticated
  using (public.is_chat_member(chat_messages.chat_id, auth.uid()));

drop policy if exists chat_messages_insert_own on public.chat_messages;
create policy chat_messages_insert_own
  on public.chat_messages
  for insert
  to authenticated
  with check (
    auth.uid() = sender_id
    and public.is_chat_member(chat_messages.chat_id, auth.uid())
  );

drop policy if exists chat_messages_delete_sender on public.chat_messages;
create policy chat_messages_delete_sender
  on public.chat_messages
  for delete
  to authenticated
  using (auth.uid() = sender_id);

commit;
