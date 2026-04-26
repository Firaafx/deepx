-- Dynamic card monetization + entitlement + verification

alter table if exists public.profiles
  add column if not exists is_verified boolean not null default false;

alter table if exists public.presets
  add column if not exists is_paid boolean not null default false,
  add column if not exists price_cents integer,
  add column if not exists accent_color_hex text;

alter table if exists public.collections
  add column if not exists is_paid boolean not null default false,
  add column if not exists price_cents integer,
  add column if not exists accent_color_hex text;

alter table if exists public.presets
  drop constraint if exists presets_price_cents_non_negative;
alter table if exists public.presets
  add constraint presets_price_cents_non_negative
    check (price_cents is null or price_cents >= 0);

alter table if exists public.collections
  drop constraint if exists collections_price_cents_non_negative;
alter table if exists public.collections
  add constraint collections_price_cents_non_negative
    check (price_cents is null or price_cents >= 0);

alter table if exists public.presets
  drop constraint if exists presets_accent_color_hex_valid;
alter table if exists public.presets
  add constraint presets_accent_color_hex_valid
    check (accent_color_hex is null or accent_color_hex ~ '^#[0-9A-Fa-f]{6}$');

alter table if exists public.collections
  drop constraint if exists collections_accent_color_hex_valid;
alter table if exists public.collections
  add constraint collections_accent_color_hex_valid
    check (accent_color_hex is null or accent_color_hex ~ '^#[0-9A-Fa-f]{6}$');

create table if not exists public.viewer_content_entitlements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  target_type text not null check (target_type in ('post', 'collection')),
  target_id uuid not null,
  has_paid boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint viewer_content_entitlements_unique
    unique (user_id, target_type, target_id)
);

create index if not exists idx_viewer_entitlements_user
  on public.viewer_content_entitlements(user_id, target_type, target_id);
create index if not exists idx_viewer_entitlements_target
  on public.viewer_content_entitlements(target_type, target_id, user_id);

drop trigger if exists trg_viewer_entitlements_updated_at on public.viewer_content_entitlements;
create trigger trg_viewer_entitlements_updated_at
before update on public.viewer_content_entitlements
for each row execute function public.set_updated_at();

alter table public.viewer_content_entitlements enable row level security;

drop policy if exists viewer_entitlements_select_own_or_owner on public.viewer_content_entitlements;
create policy viewer_entitlements_select_own_or_owner
  on public.viewer_content_entitlements
  for select
  to authenticated
  using (
    auth.uid() = user_id
    or (
      target_type = 'post'
      and exists (
        select 1
        from public.presets p
        where p.id = viewer_content_entitlements.target_id
          and p.user_id = auth.uid()
      )
    )
    or (
      target_type = 'collection'
      and exists (
        select 1
        from public.collections c
        where c.id = viewer_content_entitlements.target_id
          and c.user_id = auth.uid()
      )
    )
  );

drop policy if exists viewer_entitlements_insert_own_or_owner on public.viewer_content_entitlements;
create policy viewer_entitlements_insert_own_or_owner
  on public.viewer_content_entitlements
  for insert
  to authenticated
  with check (
    auth.uid() = user_id
    or (
      target_type = 'post'
      and exists (
        select 1
        from public.presets p
        where p.id = viewer_content_entitlements.target_id
          and p.user_id = auth.uid()
      )
    )
    or (
      target_type = 'collection'
      and exists (
        select 1
        from public.collections c
        where c.id = viewer_content_entitlements.target_id
          and c.user_id = auth.uid()
      )
    )
  );

drop policy if exists viewer_entitlements_update_own_or_owner on public.viewer_content_entitlements;
create policy viewer_entitlements_update_own_or_owner
  on public.viewer_content_entitlements
  for update
  to authenticated
  using (
    auth.uid() = user_id
    or (
      target_type = 'post'
      and exists (
        select 1
        from public.presets p
        where p.id = viewer_content_entitlements.target_id
          and p.user_id = auth.uid()
      )
    )
    or (
      target_type = 'collection'
      and exists (
        select 1
        from public.collections c
        where c.id = viewer_content_entitlements.target_id
          and c.user_id = auth.uid()
      )
    )
  )
  with check (
    auth.uid() = user_id
    or (
      target_type = 'post'
      and exists (
        select 1
        from public.presets p
        where p.id = viewer_content_entitlements.target_id
          and p.user_id = auth.uid()
      )
    )
    or (
      target_type = 'collection'
      and exists (
        select 1
        from public.collections c
        where c.id = viewer_content_entitlements.target_id
          and c.user_id = auth.uid()
      )
    )
  );

drop policy if exists viewer_entitlements_delete_own_or_owner on public.viewer_content_entitlements;
create policy viewer_entitlements_delete_own_or_owner
  on public.viewer_content_entitlements
  for delete
  to authenticated
  using (
    auth.uid() = user_id
    or (
      target_type = 'post'
      and exists (
        select 1
        from public.presets p
        where p.id = viewer_content_entitlements.target_id
          and p.user_id = auth.uid()
      )
    )
    or (
      target_type = 'collection'
      and exists (
        select 1
        from public.collections c
        where c.id = viewer_content_entitlements.target_id
          and c.user_id = auth.uid()
      )
    )
  );