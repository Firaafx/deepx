-- DeepX production schema for Supabase
-- Run this in Supabase SQL Editor after creating your project.

create extension if not exists pgcrypto;

-- enum for mode-scoped records
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'render_mode') THEN
    CREATE TYPE public.render_mode AS ENUM ('2d', '3d');
  END IF;
END $$;

-- ==========================================
-- DeepX v1.0.021 publish/tracker/guest schema sync
-- ==========================================

alter table if exists public.presets
  add column if not exists title text,
  add column if not exists description text not null default '',
  add column if not exists tags text[] not null default '{}'::text[],
  add column if not exists mention_user_ids uuid[] not null default '{}'::uuid[],
  add column if not exists visibility text not null default 'public',
  add column if not exists thumbnail_payload jsonb not null default '{}'::jsonb,
  add column if not exists thumbnail_mode public.render_mode;

update public.presets
set title = coalesce(nullif(trim(name), ''), 'Untitled')
where title is null or trim(title) = '';

alter table if exists public.presets
  alter column title set not null,
  alter column title set default 'Untitled';

alter table if exists public.presets
  drop constraint if exists presets_visibility_check;

alter table if exists public.presets
  add constraint presets_visibility_check
    check (visibility in ('public', 'private'));

alter table if exists public.presets
  drop constraint if exists presets_thumbnail_payload_object_check;

alter table if exists public.presets
  add constraint presets_thumbnail_payload_object_check
    check (jsonb_typeof(thumbnail_payload) = 'object');

alter table if exists public.presets
  drop constraint if exists presets_user_mode_name_unique;

create index if not exists idx_presets_visibility_updated
  on public.presets(visibility, updated_at desc);
create index if not exists idx_presets_user_visibility_updated
  on public.presets(user_id, visibility, updated_at desc);
create index if not exists idx_presets_tags_gin
  on public.presets using gin(tags);
create index if not exists idx_presets_mentions_gin
  on public.presets using gin(mention_user_ids);

alter table if exists public.collections
  add column if not exists tags text[] not null default '{}'::text[],
  add column if not exists mention_user_ids uuid[] not null default '{}'::uuid[],
  add column if not exists thumbnail_payload jsonb not null default '{}'::jsonb,
  add column if not exists thumbnail_mode public.render_mode;

alter table if exists public.collections
  drop constraint if exists collections_thumbnail_payload_object_check;

alter table if exists public.collections
  add constraint collections_thumbnail_payload_object_check
    check (jsonb_typeof(thumbnail_payload) = 'object');

create index if not exists idx_collections_tags_gin
  on public.collections using gin(tags);
create index if not exists idx_collections_mentions_gin
  on public.collections using gin(mention_user_ids);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  actor_user_id uuid references auth.users(id) on delete set null,
  kind text not null default 'mention' check (kind in ('mention', 'system')),
  title text not null,
  body text not null default '',
  data jsonb not null default '{}'::jsonb check (jsonb_typeof(data) = 'object'),
  read boolean not null default false,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_notifications_user_created
  on public.notifications(user_id, created_at desc);
create index if not exists idx_notifications_user_read_created
  on public.notifications(user_id, read, created_at desc);

alter table public.notifications enable row level security;

drop policy if exists notifications_select_own on public.notifications;
create policy notifications_select_own
  on public.notifications
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists notifications_insert_actor_or_self on public.notifications;
create policy notifications_insert_actor_or_self
  on public.notifications
  for insert
  to authenticated
  with check (
    auth.uid() = user_id
    or auth.uid() = actor_user_id
  );

drop policy if exists notifications_update_own on public.notifications;
create policy notifications_update_own
  on public.notifications
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists notifications_delete_own on public.notifications;
create policy notifications_delete_own
  on public.notifications
  for delete
  to authenticated
  using (auth.uid() = user_id);

alter table if exists public.user_settings
  add column if not exists tracker_config jsonb not null default '{}'::jsonb;

update public.user_settings
set tracker_config = '{}'::jsonb
where tracker_config is null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'user_settings_tracker_config_object'
  ) then
    alter table public.user_settings
      add constraint user_settings_tracker_config_object
      check (jsonb_typeof(tracker_config) = 'object');
  end if;
end $$;

drop policy if exists presets_select_feed on public.presets;
create policy presets_select_feed
  on public.presets
  for select
  to authenticated
  using (visibility = 'public' or auth.uid() = user_id);

drop policy if exists presets_select_feed_anon on public.presets;
create policy presets_select_feed_anon
  on public.presets
  for select
  to anon
  using (visibility = 'public');

drop policy if exists profiles_select_all_anon on public.profiles;
create policy profiles_select_all_anon
  on public.profiles
  for select
  to anon
  using (true);

drop policy if exists preset_reactions_select_all_anon on public.preset_reactions;
create policy preset_reactions_select_all_anon
  on public.preset_reactions
  for select
  to anon
  using (true);

drop policy if exists preset_comments_select_all_anon on public.preset_comments;
create policy preset_comments_select_all_anon
  on public.preset_comments
  for select
  to anon
  using (true);

drop policy if exists saved_presets_select_all_anon on public.saved_presets;
create policy saved_presets_select_all_anon
  on public.saved_presets
  for select
  to anon
  using (true);

drop policy if exists collections_select_published_or_owner on public.collections;
create policy collections_select_published_or_owner
  on public.collections
  for select
  to authenticated
  using (published = true or auth.uid() = user_id);

drop policy if exists collections_select_published_anon on public.collections;
create policy collections_select_published_anon
  on public.collections
  for select
  to anon
  using (published = true);

drop policy if exists collection_items_select_published_anon on public.collection_items;
create policy collection_items_select_published_anon
  on public.collection_items
  for select
  to anon
  using (
    exists (
      select 1
      from public.collections c
      where c.id = collection_items.collection_id
        and c.published = true
    )
  );

-- ==========================================
-- DeepX web production overhaul extensions
-- ==========================================

-- Profiles + user settings extensions
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

-- Collections + ordered immutable item snapshots
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

-- Chat helper functions for recursion-safe policy checks
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

-- per-user persisted editor/session state
create table if not exists public.mode_states (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  mode public.render_mode not null,
  state jsonb not null default '{}'::jsonb
    check (jsonb_typeof(state) = 'object'),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint mode_states_user_mode_unique unique (user_id, mode)
);

-- named presets saved by users
create table if not exists public.presets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  mode public.render_mode not null,
  name text not null check (char_length(trim(name)) > 0),
  payload jsonb not null check (jsonb_typeof(payload) = 'object'),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint presets_user_mode_name_unique unique (user_id, mode, name)
);

create index if not exists idx_mode_states_user_mode on public.mode_states(user_id, mode);
create index if not exists idx_presets_mode_updated on public.presets(mode, updated_at desc);
create index if not exists idx_presets_user_mode on public.presets(user_id, mode);

create or replace function public.generate_base62_id(p_len integer default 8)
returns text
language plpgsql
as $$
declare
  chars constant text := 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  out_text text := '';
  i integer;
begin
  if p_len < 1 then
    return '';
  end if;
  for i in 1..p_len loop
    out_text := out_text || substr(chars, floor(random() * length(chars) + 1)::integer, 1);
  end loop;
  return out_text;
end;
$$;

alter table if exists public.presets
  add column if not exists share_id text;

alter table if exists public.collections
  add column if not exists share_id text;

do $$
declare
  row_record record;
  candidate text;
  taken boolean;
begin
  for row_record in
    select id
    from public.presets
    where share_id is null or share_id !~ '^[A-Za-z0-9]{8}$'
  loop
    loop
      candidate := public.generate_base62_id(8);
      select exists(
        select 1 from public.presets p where p.share_id = candidate
      ) into taken;
      exit when not taken;
    end loop;

    update public.presets
    set share_id = candidate
    where id = row_record.id;
  end loop;
end;
$$;

do $$
declare
  row_record record;
  candidate text;
  taken boolean;
begin
  for row_record in
    select id
    from public.collections
    where share_id is null or share_id !~ '^[A-Za-z0-9]{8}$'
  loop
    loop
      candidate := public.generate_base62_id(8);
      select exists(
        select 1 from public.collections c where c.share_id = candidate
      ) into taken;
      exit when not taken;
    end loop;

    update public.collections
    set share_id = candidate
    where id = row_record.id;
  end loop;
end;
$$;

alter table if exists public.presets
  alter column share_id set not null;

alter table if exists public.collections
  alter column share_id set not null;

alter table if exists public.presets
  drop constraint if exists presets_share_id_format;

alter table if exists public.presets
  add constraint presets_share_id_format
    check (share_id ~ '^[A-Za-z0-9]{8}$');

alter table if exists public.collections
  drop constraint if exists collections_share_id_format;

alter table if exists public.collections
  add constraint collections_share_id_format
    check (share_id ~ '^[A-Za-z0-9]{8}$');

create unique index if not exists idx_presets_share_id_unique
  on public.presets(share_id);

create unique index if not exists idx_collections_share_id_unique
  on public.collections(share_id);

create or replace function public.ensure_preset_share_id()
returns trigger
language plpgsql
as $$
declare
  candidate text;
  taken boolean;
begin
  if new.share_id is not null and new.share_id <> '' then
    if new.share_id !~ '^[A-Za-z0-9]{8}$' then
      raise exception 'Invalid presets.share_id format';
    end if;
    return new;
  end if;

  loop
    candidate := public.generate_base62_id(8);
    select exists(
      select 1
      from public.presets p
      where p.share_id = candidate
        and p.id <> coalesce(new.id, '00000000-0000-0000-0000-000000000000'::uuid)
    ) into taken;
    exit when not taken;
  end loop;

  new.share_id := candidate;
  return new;
end;
$$;

create or replace function public.ensure_collection_share_id()
returns trigger
language plpgsql
as $$
declare
  candidate text;
  taken boolean;
begin
  if new.share_id is not null and new.share_id <> '' then
    if new.share_id !~ '^[A-Za-z0-9]{8}$' then
      raise exception 'Invalid collections.share_id format';
    end if;
    return new;
  end if;

  loop
    candidate := public.generate_base62_id(8);
    select exists(
      select 1
      from public.collections c
      where c.share_id = candidate
        and c.id <> coalesce(new.id, '00000000-0000-0000-0000-000000000000'::uuid)
    ) into taken;
    exit when not taken;
  end loop;

  new.share_id := candidate;
  return new;
end;
$$;

drop trigger if exists trg_presets_share_id on public.presets;
create trigger trg_presets_share_id
before insert or update of share_id on public.presets
for each row execute function public.ensure_preset_share_id();

drop trigger if exists trg_collections_share_id on public.collections;
create trigger trg_collections_share_id
before insert or update of share_id on public.collections
for each row execute function public.ensure_collection_share_id();

-- auto-update updated_at
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists trg_mode_states_updated_at on public.mode_states;
create trigger trg_mode_states_updated_at
before update on public.mode_states
for each row
execute function public.set_updated_at();

drop trigger if exists trg_presets_updated_at on public.presets;
create trigger trg_presets_updated_at
before update on public.presets
for each row
execute function public.set_updated_at();

-- RLS
alter table public.mode_states enable row level security;
alter table public.presets enable row level security;

-- mode_states policies: users can only manage their own state
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'mode_states'
      AND policyname = 'mode_states_select_own'
  ) THEN
    CREATE POLICY mode_states_select_own
      ON public.mode_states
      FOR SELECT
      TO authenticated
      USING (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'mode_states'
      AND policyname = 'mode_states_insert_own'
  ) THEN
    CREATE POLICY mode_states_insert_own
      ON public.mode_states
      FOR INSERT
      TO authenticated
      WITH CHECK (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'mode_states'
      AND policyname = 'mode_states_update_own'
  ) THEN
    CREATE POLICY mode_states_update_own
      ON public.mode_states
      FOR UPDATE
      TO authenticated
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'mode_states'
      AND policyname = 'mode_states_delete_own'
  ) THEN
    CREATE POLICY mode_states_delete_own
      ON public.mode_states
      FOR DELETE
      TO authenticated
      USING (auth.uid() = user_id);
  END IF;
END $$;

-- presets policies:
-- authenticated users can view feed presets from everyone,
-- but only create/update/delete their own.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'presets'
      AND policyname = 'presets_select_feed'
  ) THEN
    CREATE POLICY presets_select_feed
      ON public.presets
      FOR SELECT
      TO authenticated
      USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'presets'
      AND policyname = 'presets_insert_own'
  ) THEN
    CREATE POLICY presets_insert_own
      ON public.presets
      FOR INSERT
      TO authenticated
      WITH CHECK (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'presets'
      AND policyname = 'presets_update_own'
  ) THEN
    CREATE POLICY presets_update_own
      ON public.presets
      FOR UPDATE
      TO authenticated
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'presets'
      AND policyname = 'presets_delete_own'
  ) THEN
    CREATE POLICY presets_delete_own
      ON public.presets
      FOR DELETE
      TO authenticated
      USING (auth.uid() = user_id);
  END IF;
END $$;
-- ==========================================
-- Social + profile + chat + settings schema
-- ==========================================

create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  username text unique
    check (username is null or char_length(trim(username)) between 3 and 32),
  full_name text,
  avatar_url text,
  bio text not null default '',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.follows (
  follower_id uuid not null references auth.users(id) on delete cascade,
  following_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  primary key (follower_id, following_id),
  check (follower_id <> following_id)
);

create table if not exists public.preset_reactions (
  preset_id uuid not null references public.presets(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  reaction smallint not null check (reaction in (-1, 1)),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (preset_id, user_id)
);

create table if not exists public.preset_comments (
  id uuid primary key default gen_random_uuid(),
  preset_id uuid not null references public.presets(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  content text not null check (char_length(trim(content)) > 0),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.saved_presets (
  user_id uuid not null references auth.users(id) on delete cascade,
  preset_id uuid not null references public.presets(id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, preset_id)
);

create table if not exists public.view_history (
  user_id uuid not null references auth.users(id) on delete cascade,
  preset_id uuid not null references public.presets(id) on delete cascade,
  view_count integer not null default 1 check (view_count >= 1),
  first_viewed_at timestamptz not null default timezone('utc', now()),
  last_viewed_at timestamptz not null default timezone('utc', now()),
  primary key (user_id, preset_id)
);

create table if not exists public.chats (
  id uuid primary key default gen_random_uuid(),
  created_by uuid references auth.users(id) on delete set null,
  name text,
  is_group boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.chat_members (
  chat_id uuid not null references public.chats(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member'
    check (role in ('owner', 'admin', 'member')),
  joined_at timestamptz not null default timezone('utc', now()),
  primary key (chat_id, user_id)
);

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  chat_id uuid not null references public.chats(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  body text not null default '',
  shared_preset_id uuid references public.presets(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  check (
    char_length(trim(coalesce(body, ''))) > 0
    or shared_preset_id is not null
  )
);

create table if not exists public.user_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  theme_mode text not null default 'dark'
    check (theme_mode in ('light', 'dark', 'system')),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_profiles_username on public.profiles(username);
create index if not exists idx_follows_following_id on public.follows(following_id);
create index if not exists idx_preset_reactions_preset on public.preset_reactions(preset_id);
create index if not exists idx_preset_comments_preset_created on public.preset_comments(preset_id, created_at desc);
create index if not exists idx_saved_presets_preset on public.saved_presets(preset_id);
create index if not exists idx_view_history_last_viewed on public.view_history(user_id, last_viewed_at desc);
create index if not exists idx_chat_members_user on public.chat_members(user_id, chat_id);
create index if not exists idx_chat_messages_chat_created on public.chat_messages(chat_id, created_at);
create index if not exists idx_chat_messages_shared_preset on public.chat_messages(shared_preset_id);

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

drop trigger if exists trg_preset_reactions_updated_at on public.preset_reactions;
create trigger trg_preset_reactions_updated_at
before update on public.preset_reactions
for each row execute function public.set_updated_at();

drop trigger if exists trg_preset_comments_updated_at on public.preset_comments;
create trigger trg_preset_comments_updated_at
before update on public.preset_comments
for each row execute function public.set_updated_at();

drop trigger if exists trg_chats_updated_at on public.chats;
create trigger trg_chats_updated_at
before update on public.chats
for each row execute function public.set_updated_at();

drop trigger if exists trg_user_settings_updated_at on public.user_settings;
create trigger trg_user_settings_updated_at
before update on public.user_settings
for each row execute function public.set_updated_at();

-- Keep profile row and settings synced with auth users.
create or replace function public.handle_new_user_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (user_id, email)
  values (new.id, coalesce(new.email, ''))
  on conflict (user_id) do update
    set email = excluded.email;

  insert into public.user_settings (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created_deepx on auth.users;
create trigger on_auth_user_created_deepx
after insert on auth.users
for each row execute function public.handle_new_user_profile();

-- Backfill for existing users.
insert into public.profiles (user_id, email)
select id, coalesce(email, '')
from auth.users
on conflict (user_id) do update
  set email = excluded.email;

insert into public.user_settings (user_id)
select id from auth.users
on conflict (user_id) do nothing;

-- RLS
alter table public.profiles enable row level security;
alter table public.follows enable row level security;
alter table public.preset_reactions enable row level security;
alter table public.preset_comments enable row level security;
alter table public.saved_presets enable row level security;
alter table public.view_history enable row level security;
alter table public.chats enable row level security;
alter table public.chat_members enable row level security;
alter table public.chat_messages enable row level security;
alter table public.user_settings enable row level security;

DO $$
BEGIN
  -- profiles
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'profiles'
      AND policyname = 'profiles_select_all_authenticated'
  ) THEN
    CREATE POLICY profiles_select_all_authenticated
      ON public.profiles
      FOR SELECT
      TO authenticated
      USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'profiles'
      AND policyname = 'profiles_insert_own'
  ) THEN
    CREATE POLICY profiles_insert_own
      ON public.profiles
      FOR INSERT
      TO authenticated
      WITH CHECK (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'profiles'
      AND policyname = 'profiles_update_own'
  ) THEN
    CREATE POLICY profiles_update_own
      ON public.profiles
      FOR UPDATE
      TO authenticated
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
  END IF;

  -- follows
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'follows'
      AND policyname = 'follows_select_all_authenticated'
  ) THEN
    CREATE POLICY follows_select_all_authenticated
      ON public.follows
      FOR SELECT
      TO authenticated
      USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'follows'
      AND policyname = 'follows_insert_own'
  ) THEN
    CREATE POLICY follows_insert_own
      ON public.follows
      FOR INSERT
      TO authenticated
      WITH CHECK (auth.uid() = follower_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'follows'
      AND policyname = 'follows_delete_own'
  ) THEN
    CREATE POLICY follows_delete_own
      ON public.follows
      FOR DELETE
      TO authenticated
      USING (auth.uid() = follower_id);
  END IF;

  -- preset_reactions
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'preset_reactions'
      AND policyname = 'preset_reactions_select_all_authenticated'
  ) THEN
    CREATE POLICY preset_reactions_select_all_authenticated
      ON public.preset_reactions
      FOR SELECT
      TO authenticated
      USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'preset_reactions'
      AND policyname = 'preset_reactions_insert_own'
  ) THEN
    CREATE POLICY preset_reactions_insert_own
      ON public.preset_reactions
      FOR INSERT
      TO authenticated
      WITH CHECK (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'preset_reactions'
      AND policyname = 'preset_reactions_update_own'
  ) THEN
    CREATE POLICY preset_reactions_update_own
      ON public.preset_reactions
      FOR UPDATE
      TO authenticated
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'preset_reactions'
      AND policyname = 'preset_reactions_delete_own'
  ) THEN
    CREATE POLICY preset_reactions_delete_own
      ON public.preset_reactions
      FOR DELETE
      TO authenticated
      USING (auth.uid() = user_id);
  END IF;

  -- preset_comments
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'preset_comments'
      AND policyname = 'preset_comments_select_all_authenticated'
  ) THEN
    CREATE POLICY preset_comments_select_all_authenticated
      ON public.preset_comments
      FOR SELECT
      TO authenticated
      USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'preset_comments'
      AND policyname = 'preset_comments_insert_own'
  ) THEN
    CREATE POLICY preset_comments_insert_own
      ON public.preset_comments
      FOR INSERT
      TO authenticated
      WITH CHECK (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'preset_comments'
      AND policyname = 'preset_comments_update_own'
  ) THEN
    CREATE POLICY preset_comments_update_own
      ON public.preset_comments
      FOR UPDATE
      TO authenticated
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'preset_comments'
      AND policyname = 'preset_comments_delete_own'
  ) THEN
    CREATE POLICY preset_comments_delete_own
      ON public.preset_comments
      FOR DELETE
      TO authenticated
      USING (auth.uid() = user_id);
  END IF;

  -- saved_presets
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'saved_presets'
      AND policyname = 'saved_presets_select_all_authenticated'
  ) THEN
    CREATE POLICY saved_presets_select_all_authenticated
      ON public.saved_presets
      FOR SELECT
      TO authenticated
      USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'saved_presets'
      AND policyname = 'saved_presets_insert_own'
  ) THEN
    CREATE POLICY saved_presets_insert_own
      ON public.saved_presets
      FOR INSERT
      TO authenticated
      WITH CHECK (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'saved_presets'
      AND policyname = 'saved_presets_delete_own'
  ) THEN
    CREATE POLICY saved_presets_delete_own
      ON public.saved_presets
      FOR DELETE
      TO authenticated
      USING (auth.uid() = user_id);
  END IF;

  -- view_history
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'view_history'
      AND policyname = 'view_history_select_own'
  ) THEN
    CREATE POLICY view_history_select_own
      ON public.view_history
      FOR SELECT
      TO authenticated
      USING (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'view_history'
      AND policyname = 'view_history_insert_own'
  ) THEN
    CREATE POLICY view_history_insert_own
      ON public.view_history
      FOR INSERT
      TO authenticated
      WITH CHECK (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'view_history'
      AND policyname = 'view_history_update_own'
  ) THEN
    CREATE POLICY view_history_update_own
      ON public.view_history
      FOR UPDATE
      TO authenticated
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'view_history'
      AND policyname = 'view_history_delete_own'
  ) THEN
    CREATE POLICY view_history_delete_own
      ON public.view_history
      FOR DELETE
      TO authenticated
      USING (auth.uid() = user_id);
  END IF;

  -- chats
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'chats'
      AND policyname = 'chats_select_member'
  ) THEN
    CREATE POLICY chats_select_member
      ON public.chats
      FOR SELECT
      TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM public.chat_members m
          WHERE m.chat_id = chats.id
            AND m.user_id = auth.uid()
        )
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'chats'
      AND policyname = 'chats_insert_own'
  ) THEN
    CREATE POLICY chats_insert_own
      ON public.chats
      FOR INSERT
      TO authenticated
      WITH CHECK (auth.uid() = created_by);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'chats'
      AND policyname = 'chats_update_admin'
  ) THEN
    CREATE POLICY chats_update_admin
      ON public.chats
      FOR UPDATE
      TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM public.chat_members m
          WHERE m.chat_id = chats.id
            AND m.user_id = auth.uid()
            AND m.role in ('owner', 'admin')
        )
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'chats'
      AND policyname = 'chats_delete_owner'
  ) THEN
    CREATE POLICY chats_delete_owner
      ON public.chats
      FOR DELETE
      TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM public.chat_members m
          WHERE m.chat_id = chats.id
            AND m.user_id = auth.uid()
            AND m.role = 'owner'
        )
      );
  END IF;

  -- chat_members
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'chat_members'
      AND policyname = 'chat_members_select_chat_member'
  ) THEN
    CREATE POLICY chat_members_select_chat_member
      ON public.chat_members
      FOR SELECT
      TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM public.chat_members me
          WHERE me.chat_id = chat_members.chat_id
            AND me.user_id = auth.uid()
        )
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'chat_members'
      AND policyname = 'chat_members_insert_owner_or_self'
  ) THEN
    CREATE POLICY chat_members_insert_owner_or_self
      ON public.chat_members
      FOR INSERT
      TO authenticated
      WITH CHECK (
        auth.uid() = user_id
        OR EXISTS (
          SELECT 1 FROM public.chats c
          WHERE c.id = chat_members.chat_id
            AND c.created_by = auth.uid()
        )
        OR EXISTS (
          SELECT 1 FROM public.chat_members me
          WHERE me.chat_id = chat_members.chat_id
            AND me.user_id = auth.uid()
            AND me.role in ('owner', 'admin')
        )
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'chat_members'
      AND policyname = 'chat_members_update_admin'
  ) THEN
    CREATE POLICY chat_members_update_admin
      ON public.chat_members
      FOR UPDATE
      TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM public.chat_members me
          WHERE me.chat_id = chat_members.chat_id
            AND me.user_id = auth.uid()
            AND me.role in ('owner', 'admin')
        )
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'chat_members'
      AND policyname = 'chat_members_delete_self_or_admin'
  ) THEN
    CREATE POLICY chat_members_delete_self_or_admin
      ON public.chat_members
      FOR DELETE
      TO authenticated
      USING (
        auth.uid() = user_id
        OR EXISTS (
          SELECT 1 FROM public.chat_members me
          WHERE me.chat_id = chat_members.chat_id
            AND me.user_id = auth.uid()
            AND me.role in ('owner', 'admin')
        )
      );
  END IF;

  -- chat_messages
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'chat_messages'
      AND policyname = 'chat_messages_select_chat_member'
  ) THEN
    CREATE POLICY chat_messages_select_chat_member
      ON public.chat_messages
      FOR SELECT
      TO authenticated
      USING (
        EXISTS (
          SELECT 1 FROM public.chat_members m
          WHERE m.chat_id = chat_messages.chat_id
            AND m.user_id = auth.uid()
        )
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'chat_messages'
      AND policyname = 'chat_messages_insert_own'
  ) THEN
    CREATE POLICY chat_messages_insert_own
      ON public.chat_messages
      FOR INSERT
      TO authenticated
      WITH CHECK (
        auth.uid() = sender_id
        AND EXISTS (
          SELECT 1 FROM public.chat_members m
          WHERE m.chat_id = chat_messages.chat_id
            AND m.user_id = auth.uid()
        )
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'chat_messages'
      AND policyname = 'chat_messages_delete_sender'
  ) THEN
    CREATE POLICY chat_messages_delete_sender
      ON public.chat_messages
      FOR DELETE
      TO authenticated
      USING (auth.uid() = sender_id);
  END IF;

  -- user_settings
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'user_settings'
      AND policyname = 'user_settings_select_own'
  ) THEN
    CREATE POLICY user_settings_select_own
      ON public.user_settings
      FOR SELECT
      TO authenticated
      USING (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'user_settings'
      AND policyname = 'user_settings_insert_own'
  ) THEN
    CREATE POLICY user_settings_insert_own
      ON public.user_settings
      FOR INSERT
      TO authenticated
      WITH CHECK (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'user_settings'
      AND policyname = 'user_settings_update_own'
  ) THEN
    CREATE POLICY user_settings_update_own
      ON public.user_settings
      FOR UPDATE
      TO authenticated
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

create or replace view public.preset_stats as
select
  p.id as preset_id,
  coalesce((
    select count(*)
    from public.preset_reactions r
    where r.preset_id = p.id and r.reaction = 1
  ), 0)::bigint as likes_count,
  coalesce((
    select count(*)
    from public.preset_reactions r
    where r.preset_id = p.id and r.reaction = -1
  ), 0)::bigint as dislikes_count,
  coalesce((
    select count(*)
    from public.preset_comments c
    where c.preset_id = p.id
  ), 0)::bigint as comments_count,
  coalesce((
    select count(*)
    from public.saved_presets s
    where s.preset_id = p.id
  ), 0)::bigint as saves_count
from public.presets p;

create or replace view public.profile_stats as
select
  pr.user_id,
  coalesce((
    select count(*)
    from public.follows f
    where f.following_id = pr.user_id
  ), 0)::bigint as followers_count,
  coalesce((
    select count(*)
    from public.follows f
    where f.follower_id = pr.user_id
  ), 0)::bigint as following_count,
  coalesce((
    select count(*)
    from public.presets p
    where p.user_id = pr.user_id
  ), 0)::bigint as posts_count
from public.profiles pr;

create or replace function public.record_preset_view(p_preset_id uuid)
returns void
language plpgsql
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    return;
  end if;

  insert into public.view_history (user_id, preset_id, view_count)
  values (v_user, p_preset_id, 1)
  on conflict (user_id, preset_id) do update
    set view_count = public.view_history.view_count + 1,
        last_viewed_at = timezone('utc', now());
end;
$$;

create or replace function public.create_or_get_direct_chat(other_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  current_id uuid := auth.uid();
  existing_chat uuid;
begin
  if current_id is null then
    raise exception 'Not authenticated';
  end if;

  if other_user_id is null or other_user_id = current_id then
    raise exception 'Invalid direct chat target';
  end if;

  select c.id into existing_chat
  from public.chats c
  join public.chat_members m_self
    on m_self.chat_id = c.id and m_self.user_id = current_id
  join public.chat_members m_other
    on m_other.chat_id = c.id and m_other.user_id = other_user_id
  where c.is_group = false
    and (
      select count(*)
      from public.chat_members m
      where m.chat_id = c.id
    ) = 2
  limit 1;

  if existing_chat is not null then
    return existing_chat;
  end if;

  insert into public.chats (created_by, is_group, name)
  values (current_id, false, null)
  returning id into existing_chat;

  insert into public.chat_members (chat_id, user_id, role)
  values
    (existing_chat, current_id, 'owner'),
    (existing_chat, other_user_id, 'member')
  on conflict do nothing;

  return existing_chat;
end;
$$;

create or replace function public.create_group_chat(
  group_name text,
  member_ids uuid[]
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  current_id uuid := auth.uid();
  new_chat_id uuid;
  clean_name text;
  member_id uuid;
  unique_members uuid[];
begin
  if current_id is null then
    raise exception 'Not authenticated';
  end if;

  clean_name := nullif(trim(coalesce(group_name, '')), '');
  if clean_name is null then
    raise exception 'Group name is required';
  end if;

  unique_members := array(
    select distinct m
    from unnest(coalesce(member_ids, array[]::uuid[])) as m
    where m is not null and m <> current_id
  );

  insert into public.chats (created_by, is_group, name)
  values (current_id, true, clean_name)
  returning id into new_chat_id;

  insert into public.chat_members (chat_id, user_id, role)
  values (new_chat_id, current_id, 'owner')
  on conflict do nothing;

  foreach member_id in array unique_members loop
    insert into public.chat_members (chat_id, user_id, role)
    values (new_chat_id, member_id, 'member')
    on conflict do nothing;
  end loop;

  return new_chat_id;
end;
$$;

grant execute on function public.record_preset_view(uuid) to authenticated;
grant execute on function public.create_or_get_direct_chat(uuid) to authenticated;
grant execute on function public.create_group_chat(text, uuid[]) to authenticated;

-- Storage buckets for uploads.
insert into storage.buckets (id, name, public)
values ('deepx-assets', 'deepx-assets', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('deepx-avatars', 'deepx-avatars', true)
on conflict (id) do nothing;

DO $$
BEGIN
  -- deepx-assets
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'deepx_assets_select_public'
  ) THEN
    CREATE POLICY deepx_assets_select_public
      ON storage.objects
      FOR SELECT
      TO authenticated
      USING (bucket_id = 'deepx-assets');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'deepx_assets_insert_own_folder'
  ) THEN
    CREATE POLICY deepx_assets_insert_own_folder
      ON storage.objects
      FOR INSERT
      TO authenticated
      WITH CHECK (
        bucket_id = 'deepx-assets'
        AND (storage.foldername(name))[1] = auth.uid()::text
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'deepx_assets_update_own_folder'
  ) THEN
    CREATE POLICY deepx_assets_update_own_folder
      ON storage.objects
      FOR UPDATE
      TO authenticated
      USING (
        bucket_id = 'deepx-assets'
        AND (storage.foldername(name))[1] = auth.uid()::text
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'deepx_assets_delete_own_folder'
  ) THEN
    CREATE POLICY deepx_assets_delete_own_folder
      ON storage.objects
      FOR DELETE
      TO authenticated
      USING (
        bucket_id = 'deepx-assets'
        AND (storage.foldername(name))[1] = auth.uid()::text
      );
  END IF;

  -- deepx-avatars
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'deepx_avatars_select_public'
  ) THEN
    CREATE POLICY deepx_avatars_select_public
      ON storage.objects
      FOR SELECT
      TO authenticated
      USING (bucket_id = 'deepx-avatars');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'deepx_avatars_insert_own_folder'
  ) THEN
    CREATE POLICY deepx_avatars_insert_own_folder
      ON storage.objects
      FOR INSERT
      TO authenticated
      WITH CHECK (
        bucket_id = 'deepx-avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'deepx_avatars_update_own_folder'
  ) THEN
    CREATE POLICY deepx_avatars_update_own_folder
      ON storage.objects
      FOR UPDATE
      TO authenticated
      USING (
        bucket_id = 'deepx-avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
      AND policyname = 'deepx_avatars_delete_own_folder'
  ) THEN
    CREATE POLICY deepx_avatars_delete_own_folder
      ON storage.objects
      FOR DELETE
      TO authenticated
      USING (
        bucket_id = 'deepx-avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
      );
  END IF;
END $$;
