-- Manual restoration notes for the pre-lightweight DeepX renderer.
--
-- This file is intentionally outside supabase/migrations so it never runs
-- automatically. Use it only if the app code for parallax, head/camera
-- tracking, 3D, and 360 rendering is restored from version control.

begin;

-- 1) Re-open render-mode writes for legacy runtimes.
alter table if exists public.presets
  drop constraint if exists presets_image_only_mode_check;
alter table if exists public.presets
  drop constraint if exists presets_thumbnail_image_only_mode_check;
alter table if exists public.collection_items
  drop constraint if exists collection_items_image_only_mode_check;
alter table if exists public.collections
  drop constraint if exists collections_thumbnail_image_only_mode_check;
alter table if exists public.mode_states
  drop constraint if exists mode_states_image_only_mode_check;

-- 2) Ensure enum labels used by the older editor/runtime exist.
do $$
begin
  if not exists (
    select 1
    from pg_enum
    where enumtypid = 'public.render_mode'::regtype
      and enumlabel = '3d'
  ) then
    alter type public.render_mode add value '3d';
  end if;

  if not exists (
    select 1
    from pg_enum
    where enumtypid = 'public.render_mode'::regtype
      and enumlabel = '360'
  ) then
    alter type public.render_mode add value '360';
  end if;

  if not exists (
    select 1
    from pg_enum
    where enumtypid = 'public.render_mode'::regtype
      and enumlabel = 'post_studio_draft'
  ) then
    alter type public.render_mode add value 'post_studio_draft';
  end if;
end $$;

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

commit;
