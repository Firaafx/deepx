-- DeepX v1.0.021 publish/tracker/guest feed upgrades.

-- 1) Extend presets for publish metadata, visibility, and thumbnail payloads.
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

-- Publishing should create new rows; remove old unique name constraint.
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

-- 2) Notifications table for mentions.
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

-- 3) Persist tracker runtime configuration in user settings.
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

-- 4) Guest feed read policies for anon users.

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

-- Collection guest reads.
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
