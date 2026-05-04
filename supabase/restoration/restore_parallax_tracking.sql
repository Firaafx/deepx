-- Manual restoration notes for the pre-image-only DeepX renderer.
--
-- This file is intentionally outside supabase/migrations so it never runs
-- automatically. Use it only together with app code restored from version
-- control for parallax, head/camera tracking, 3D, and 360 rendering.

begin;

-- 1) Recreate the legacy render-mode enum and state table.
do $$
begin
  if not exists (
    select 1 from pg_type where typname = 'render_mode'
  ) then
    create type public.render_mode as enum (
      '2d',
      '3d',
      '360',
      'post_studio_draft'
    );
  end if;
end $$;

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

-- 2) Re-open render-mode writes for legacy runtimes.
alter table if exists public.presets
  add column if not exists mode public.render_mode not null default '2d',
  add column if not exists thumbnail_mode public.render_mode default '2d';

alter table if exists public.presets
  drop constraint if exists presets_user_name_unique;

alter table if exists public.presets
  add constraint presets_user_mode_name_unique unique (user_id, mode, name);

alter table if exists public.collection_items
  add column if not exists mode public.render_mode not null default '2d';

alter table if exists public.collections
  add column if not exists thumbnail_mode public.render_mode default '2d';

create index if not exists idx_mode_states_user_mode
  on public.mode_states(user_id, mode);
create index if not exists idx_presets_mode_updated
  on public.presets(mode, updated_at desc);
create index if not exists idx_presets_user_mode
  on public.presets(user_id, mode);

-- 3) Restore tracker settings storage expected by the legacy tracking service.
alter table if exists public.user_settings
  add column if not exists tracker_enabled boolean not null default true,
  add column if not exists tracker_ui_visible boolean not null default false,
  add column if not exists tracker_config jsonb not null default '{}'::jsonb;

alter table if exists public.user_settings
  drop constraint if exists user_settings_tracker_config_object;
alter table if exists public.user_settings
  add constraint user_settings_tracker_config_object
    check (jsonb_typeof(tracker_config) = 'object');

-- 4) Re-enable RLS and ownership policies for restored mode state.
alter table public.mode_states enable row level security;

drop policy if exists mode_states_select_own on public.mode_states;
create policy mode_states_select_own
  on public.mode_states
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists mode_states_insert_own on public.mode_states;
create policy mode_states_insert_own
  on public.mode_states
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists mode_states_update_own on public.mode_states;
create policy mode_states_update_own
  on public.mode_states
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists mode_states_delete_own on public.mode_states;
create policy mode_states_delete_own
  on public.mode_states
  for delete
  to authenticated
  using (auth.uid() = user_id);

commit;
