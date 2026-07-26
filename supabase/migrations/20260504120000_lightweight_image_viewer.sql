-- RayMax lightweight image viewer migration.
-- Normalizes active render payloads to a single image URL while preserving
-- the existing render_mode enum for storage compatibility.

create or replace function public.raymax_extract_image_url(p_payload jsonb)
returns text
language plpgsql
immutable
as $$
declare
  v_scene jsonb;
  v_url text;
begin
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    return '';
  end if;

  v_scene := case
    when jsonb_typeof(p_payload -> 'scene') = 'object' then p_payload -> 'scene'
    else p_payload
  end;

  v_url := nullif(trim(coalesce(
    v_scene ->> 'imageUrl',
    v_scene ->> 'image_url',
    v_scene ->> 'assetUrl',
    v_scene ->> 'asset_url',
    p_payload ->> 'imageUrl',
    p_payload ->> 'image_url',
    p_payload ->> 'assetUrl',
    p_payload ->> 'asset_url',
    ''
  )), '');
  if v_url is not null then
    return v_url;
  end if;

  select nullif(trim(coalesce(layer.value ->> 'url', layer.value ->> 'imageUrl', '')), '')
    into v_url
  from jsonb_each(v_scene) as layer(key, value)
  where layer.key <> 'turning_point'
    and jsonb_typeof(layer.value) = 'object'
    and lower(coalesce(layer.value ->> 'isVisible', 'true')) <> 'false'
    and nullif(trim(coalesce(layer.value ->> 'url', layer.value ->> 'imageUrl', '')), '') is not null
  order by
    case when lower(coalesce(layer.value ->> 'isRect', 'false')) = 'true' then 1 else 0 end asc,
    case
      when coalesce(layer.value ->> 'order', '') ~ '^-?[0-9]+(\.[0-9]+)?$'
        then (layer.value ->> 'order')::numeric
      else 0
    end asc
  limit 1;

  if v_url is not null then
    return v_url;
  end if;

  with recursive walk(value) as (
    values (p_payload)
    union all
    select child.value
    from walk
    cross join lateral (
      select value
      from jsonb_each(
        case when jsonb_typeof(walk.value) = 'object' then walk.value else '{}'::jsonb end
      )
      union all
      select value
      from jsonb_array_elements(
        case when jsonb_typeof(walk.value) = 'array' then walk.value else '[]'::jsonb end
      )
    ) as child
  )
  select trim(value #>> '{}')
    into v_url
  from walk
  where jsonb_typeof(value) = 'string'
    and (
      lower(value #>> '{}') like 'data:image/%'
      or lower(value #>> '{}') like 'http%.png%'
      or lower(value #>> '{}') like 'http%.jpg%'
      or lower(value #>> '{}') like 'http%.jpeg%'
      or lower(value #>> '{}') like 'http%.webp%'
      or lower(value #>> '{}') like 'http%.gif%'
      or lower(value #>> '{}') like 'http%.avif%'
      or lower(value #>> '{}') like '%/storage/v1/object/%'
    )
  limit 1;

  return coalesce(v_url, '');
end;
$$;

create or replace function public.raymax_simple_image_payload(
  p_payload jsonb,
  p_source_mode text,
  p_editor text
)
returns jsonb
language sql
immutable
as $$
  select jsonb_build_object(
    'schemaVersion', 2,
    'mode', '2d',
    'scene', jsonb_build_object(
      'imageUrl', coalesce(public.raymax_extract_image_url(p_payload), '')
    ),
    'controls', '{}'::jsonb,
    'meta', jsonb_build_object(
      'editor', coalesce(nullif(p_editor, ''), 'image_migration'),
      'sourceMode', coalesce(nullif(p_source_mode, ''), '2d')
    )
  );
$$;

update public.presets
set
  payload = public.raymax_simple_image_payload(
    payload,
    mode::text,
    'lightweight_image_migration'
  ),
  thumbnail_payload = public.raymax_simple_image_payload(
    coalesce(nullif(thumbnail_payload, '{}'::jsonb), payload),
    coalesce(thumbnail_mode::text, mode::text),
    'lightweight_thumbnail_migration'
  ),
  mode = '2d',
  thumbnail_mode = '2d';

update public.collection_items
set
  preset_snapshot = public.raymax_simple_image_payload(
    preset_snapshot,
    mode::text,
    'lightweight_collection_item_migration'
  ),
  mode = '2d';

with first_items as (
  select distinct on (collection_id)
    collection_id,
    preset_snapshot,
    mode
  from public.collection_items
  order by collection_id, position asc
)
update public.collections as c
set
  thumbnail_payload = public.raymax_simple_image_payload(
    coalesce(nullif(c.thumbnail_payload, '{}'::jsonb), first_items.preset_snapshot, '{}'::jsonb),
    coalesce(c.thumbnail_mode::text, first_items.mode::text, '2d'),
    'lightweight_collection_thumbnail_migration'
  ),
  thumbnail_mode = '2d'
from first_items
where first_items.collection_id = c.id;

update public.collections
set
  thumbnail_payload = public.raymax_simple_image_payload(
    coalesce(nullif(thumbnail_payload, '{}'::jsonb), '{}'::jsonb),
    coalesce(thumbnail_mode::text, '2d'),
    'lightweight_collection_thumbnail_migration'
  ),
  thumbnail_mode = '2d'
where thumbnail_payload is null
   or thumbnail_payload = '{}'::jsonb
   or thumbnail_mode::text is distinct from '2d';

delete from public.mode_states
where mode::text <> '2d';

alter table if exists public.user_settings
  drop constraint if exists user_settings_tracker_config_object;

alter table if exists public.user_settings
  drop column if exists tracker_enabled,
  drop column if exists tracker_ui_visible,
  drop column if exists tracker_config;

alter table if exists public.presets
  drop constraint if exists presets_image_only_mode_check;
alter table if exists public.presets
  add constraint presets_image_only_mode_check
    check (mode::text = '2d');

alter table if exists public.presets
  drop constraint if exists presets_thumbnail_image_only_mode_check;
alter table if exists public.presets
  add constraint presets_thumbnail_image_only_mode_check
    check (thumbnail_mode is null or thumbnail_mode::text = '2d');

alter table if exists public.collection_items
  drop constraint if exists collection_items_image_only_mode_check;
alter table if exists public.collection_items
  add constraint collection_items_image_only_mode_check
    check (mode::text = '2d');

alter table if exists public.collections
  drop constraint if exists collections_thumbnail_image_only_mode_check;
alter table if exists public.collections
  add constraint collections_thumbnail_image_only_mode_check
    check (thumbnail_mode is null or thumbnail_mode::text = '2d');

alter table if exists public.mode_states
  drop constraint if exists mode_states_image_only_mode_check;
alter table if exists public.mode_states
  add constraint mode_states_image_only_mode_check
    check (mode::text = '2d');
