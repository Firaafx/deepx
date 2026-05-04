-- DeepX active image-only schema reset.
-- Historical migrations keep the old renderer chronology; this migration
-- removes active render-mode and tracker storage from the live schema.

create or replace function public.deepx_image_payload_v3(
  p_payload jsonb,
  p_editor text default 'active_image_only_migration'
)
returns jsonb
language sql
immutable
as $$
  select jsonb_build_object(
    'schemaVersion', 3,
    'image', jsonb_build_object(
      'url', coalesce(public.deepx_extract_image_url(p_payload), ''),
      'offsetX', 0.0,
      'offsetY', 0.0,
      'scale', 1.0,
      'rotationDegrees', 0.0,
      'flipX', false,
      'flipY', false
    ),
    'source', jsonb_build_object(
      'kind', 'upload',
      'linkedItemPosition', 0
    ),
    'meta', jsonb_build_object(
      'editor', coalesce(nullif(p_editor, ''), 'active_image_only_migration')
    )
  );
$$;

update public.presets
set
  payload = public.deepx_image_payload_v3(payload, 'active_image_only_post'),
  thumbnail_payload = public.deepx_image_payload_v3(
    coalesce(nullif(thumbnail_payload, '{}'::jsonb), payload),
    'active_image_only_card'
  );

update public.collection_items
set preset_snapshot = public.deepx_image_payload_v3(
  preset_snapshot,
  'active_image_only_collection_item'
);

update public.collections
set thumbnail_payload = public.deepx_image_payload_v3(
  coalesce(nullif(thumbnail_payload, '{}'::jsonb), '{}'::jsonb),
  'active_image_only_collection_card'
);

alter table if exists public.user_settings
  drop constraint if exists user_settings_tracker_config_object;

alter table if exists public.user_settings
  drop column if exists tracker_enabled,
  drop column if exists tracker_ui_visible,
  drop column if exists tracker_config;

drop trigger if exists trg_mode_states_updated_at on public.mode_states;
drop table if exists public.mode_states cascade;

drop index if exists public.idx_mode_states_user_mode;
drop index if exists public.idx_presets_mode_updated;
drop index if exists public.idx_presets_user_mode;

alter table if exists public.presets
  drop constraint if exists presets_image_only_mode_check,
  drop constraint if exists presets_thumbnail_image_only_mode_check,
  drop constraint if exists presets_user_mode_name_unique,
  drop column if exists mode,
  drop column if exists thumbnail_mode;

alter table if exists public.presets
  add constraint presets_user_name_unique unique (user_id, name);

alter table if exists public.collection_items
  drop constraint if exists collection_items_image_only_mode_check,
  drop column if exists mode;

alter table if exists public.collections
  drop constraint if exists collections_thumbnail_image_only_mode_check,
  drop column if exists thumbnail_mode;

drop type if exists public.render_mode;
