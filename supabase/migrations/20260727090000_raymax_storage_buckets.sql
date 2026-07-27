-- Create RayMax storage resources for projects that applied the pre-rebrand
-- migrations before the application switched to the RayMax bucket names.

begin;

insert into storage.buckets (id, name, public)
values
  ('raymax-assets', 'raymax-assets', true),
  ('raymax-avatars', 'raymax-avatars', true),
  ('raymax-3d-sources', 'raymax-3d-sources', false),
  ('raymax-3d-assets', 'raymax-3d-assets', true)
on conflict (id) do update set
  name = excluded.name,
  public = excluded.public;

drop policy if exists raymax_assets_read_public on storage.objects;
drop policy if exists raymax_assets_write_own on storage.objects;
drop policy if exists raymax_avatars_read_public on storage.objects;
drop policy if exists raymax_avatars_write_own on storage.objects;
drop policy if exists raymax_3d_sources_write_own on storage.objects;
drop policy if exists raymax_3d_assets_read_public on storage.objects;
drop policy if exists raymax_3d_assets_write_own on storage.objects;

create policy raymax_assets_read_public
  on storage.objects for select
  to anon, authenticated
  using (bucket_id = 'raymax-assets');

create policy raymax_assets_write_own
  on storage.objects for all
  to authenticated
  using (
    bucket_id = 'raymax-assets'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'raymax-assets'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy raymax_avatars_read_public
  on storage.objects for select
  to anon, authenticated
  using (bucket_id = 'raymax-avatars');

create policy raymax_avatars_write_own
  on storage.objects for all
  to authenticated
  using (
    bucket_id = 'raymax-avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'raymax-avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy raymax_3d_sources_write_own
  on storage.objects for all
  to authenticated
  using (
    bucket_id = 'raymax-3d-sources'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'raymax-3d-sources'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy raymax_3d_assets_read_public
  on storage.objects for select
  to anon, authenticated
  using (bucket_id = 'raymax-3d-assets');

create policy raymax_3d_assets_write_own
  on storage.objects for all
  to authenticated
  using (
    bucket_id = 'raymax-3d-assets'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'raymax-3d-assets'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

alter table if exists public.splat_generation_jobs
  alter column source_bucket set default 'raymax-3d-sources',
  alter column output_bucket set default 'raymax-3d-assets';

commit;
