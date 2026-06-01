-- Keep legacy databases that restored public.presets.mode compatible with
-- media_type-based publishing. Clean databases where mode was dropped are
-- intentionally left unchanged.

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'presets'
      and column_name = 'mode'
  ) and exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'render_mode'
  ) then
    alter table public.presets
      alter column mode set default '2d'::public.render_mode;

    update public.presets
    set mode = '2d'::public.render_mode
    where mode is null;

    alter table public.presets
      alter column mode set not null;
  end if;
end $$;
