-- RayMax is 3D-first: legacy image detail payloads become explicit missing-3D placeholders.
-- Card/collection thumbnails remain image payloads and are intentionally untouched.

alter table if exists public.presets
  drop constraint if exists presets_media_type_check;

do $$
declare
  missing_payload jsonb := jsonb_build_object(
    'schemaVersion', 1,
    'media', jsonb_build_object(
      'type', 'missing_3d',
      'url', '',
      'path', '',
      'format', '',
      'contentType', 'application/octet-stream'
    ),
    'transform', jsonb_build_object(
      'scale', 1,
      'position', jsonb_build_array(0, 0, 0),
      'rotation', jsonb_build_array(0, 0, 0)
    ),
    'camera', jsonb_build_object(
      'initialPosition', jsonb_build_array(0, 0, 3),
      'initialTarget', jsonb_build_array(0, 0, 0),
      'rotationDegrees', jsonb_build_object('yaw', 0, 'pitch', 0, 'roll', 0),
      'fov', 45,
      'distance', 3
    ),
    'source', jsonb_build_object('kind', 'missing_3d'),
    'meta', jsonb_build_object(
      'editor', 'migration_3d_only_missing_payloads',
      'reason', 'legacy_image_payload',
      'migratedFrom', 'image',
      'preferredType', 'missing_3d'
    )
  );
begin
  if to_regclass('public.presets') is not null then
    update public.presets
      set media_type = payload #>> '{media,type}'
      where lower(payload #>> '{media,type}') in (
        'gaussian_splat',
        'triangle_mesh'
      )
      and media_type is distinct from payload #>> '{media,type}';

    update public.presets
      set
        payload = missing_payload,
        media_type = 'missing_3d'
      where media_type is distinct from 'missing_3d'
      and lower(coalesce(payload #>> '{media,type}', media_type, 'image')) not in (
        'gaussian_splat',
        'triangle_mesh'
      );
  end if;

  if to_regclass('public.collection_items') is not null then
    update public.collection_items
      set preset_snapshot = missing_payload
      where lower(coalesce(preset_snapshot #>> '{media,type}', 'image')) not in (
        'gaussian_splat',
        'triangle_mesh',
        'missing_3d'
      );
  end if;
end $$;

alter table if exists public.presets
  alter column media_type set default 'missing_3d';

alter table if exists public.presets
  add constraint presets_media_type_check
    check (media_type in ('gaussian_splat', 'triangle_mesh', 'missing_3d'));
