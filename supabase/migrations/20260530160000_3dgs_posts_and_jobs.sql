-- DeepX 3DGS and mesh posts.

alter table if exists public.presets
  add column if not exists media_type text not null default 'image';

alter table if exists public.presets
  drop constraint if exists presets_media_type_check;

alter table if exists public.presets
  add constraint presets_media_type_check
    check (media_type in ('image', 'gaussian_splat', 'triangle_mesh'));

create index if not exists idx_presets_media_type_updated
  on public.presets(media_type, updated_at desc);

create table if not exists public.splat_generation_jobs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'queued'
    check (status in ('queued', 'uploading', 'running', 'finalizing', 'succeeded', 'failed')),
  progress integer not null default 0 check (progress >= 0 and progress <= 100),
  stage text not null default 'Queued',
  source_bucket text not null default 'deepx-3d-sources',
  source_image_paths text[] not null default '{}'::text[],
  output_bucket text not null default 'deepx-3d-assets',
  output_asset_path text,
  output_payload jsonb not null default '{}'::jsonb check (jsonb_typeof(output_payload) = 'object'),
  thumbnail_payload jsonb not null default '{}'::jsonb check (jsonb_typeof(thumbnail_payload) = 'object'),
  post_title text not null default 'Untitled',
  post_description text not null default '',
  post_tags text[] not null default '{}'::text[],
  post_mention_user_ids uuid[] not null default '{}'::uuid[],
  post_visibility text not null default 'public' check (post_visibility in ('public', 'private')),
  is_paid boolean not null default false,
  price_cents integer,
  accent_color_hex text,
  created_preset_id uuid references public.presets(id) on delete set null,
  error_message text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_splat_generation_jobs_user_created
  on public.splat_generation_jobs(user_id, created_at desc);
create index if not exists idx_splat_generation_jobs_status
  on public.splat_generation_jobs(status, updated_at desc);

drop trigger if exists trg_splat_generation_jobs_updated_at on public.splat_generation_jobs;
create trigger trg_splat_generation_jobs_updated_at
before update on public.splat_generation_jobs
for each row execute function public.set_updated_at();

alter table public.splat_generation_jobs enable row level security;

drop policy if exists splat_jobs_select_own on public.splat_generation_jobs;
create policy splat_jobs_select_own
  on public.splat_generation_jobs
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists splat_jobs_insert_own on public.splat_generation_jobs;
create policy splat_jobs_insert_own
  on public.splat_generation_jobs
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists splat_jobs_update_own on public.splat_generation_jobs;

insert into storage.buckets (id, name, public)
values ('deepx-3d-sources', 'deepx-3d-sources', false)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('deepx-3d-assets', 'deepx-3d-assets', true)
on conflict (id) do nothing;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'deepx_3d_sources_own_folder'
  ) then
    create policy deepx_3d_sources_own_folder
      on storage.objects
      for all
      to authenticated
      using (bucket_id = 'deepx-3d-sources' and (storage.foldername(name))[1] = auth.uid()::text)
      with check (bucket_id = 'deepx-3d-sources' and (storage.foldername(name))[1] = auth.uid()::text);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'deepx_3d_assets_public_read'
  ) then
    create policy deepx_3d_assets_public_read
      on storage.objects
      for select
      to anon, authenticated
      using (bucket_id = 'deepx-3d-assets');
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'deepx_3d_assets_own_folder'
  ) then
    create policy deepx_3d_assets_own_folder
      on storage.objects
      for all
      to authenticated
      using (bucket_id = 'deepx-3d-assets' and (storage.foldername(name))[1] = auth.uid()::text)
      with check (bucket_id = 'deepx-3d-assets' and (storage.foldername(name))[1] = auth.uid()::text);
  end if;
end $$;
