-- Remove legacy render-mode storage from databases that still have old columns.
-- Detail content is represented by presets.media_type and payload; thumbnails are image payloads only.

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

alter table if exists public.collection_items
  drop constraint if exists collection_items_image_only_mode_check,
  drop column if exists mode;

alter table if exists public.collections
  drop constraint if exists collections_thumbnail_image_only_mode_check,
  drop column if exists thumbnail_mode;

drop type if exists public.render_mode;
