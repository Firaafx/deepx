-- DeepX runtime + moderation + recommendation exclusions.

create table if not exists public.content_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_user_id uuid not null references auth.users(id) on delete cascade,
  target_type text not null check (target_type in ('post', 'collection')),
  target_id uuid not null,
  reason text not null check (char_length(trim(reason)) > 0),
  details text,
  status text not null default 'open' check (status in ('open', 'reviewing', 'resolved', 'dismissed')),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.recommendation_exclusions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  exclusion_type text not null check (exclusion_type in ('post', 'collection', 'user')),
  target_id uuid not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint recommendation_exclusions_user_target_unique
    unique (user_id, exclusion_type, target_id)
);

create index if not exists idx_content_reports_reporter_created
  on public.content_reports(reporter_user_id, created_at desc);
create index if not exists idx_content_reports_target
  on public.content_reports(target_type, target_id, created_at desc);
create index if not exists idx_content_reports_status
  on public.content_reports(status, created_at desc);
create index if not exists idx_recommendation_exclusions_user_created
  on public.recommendation_exclusions(user_id, created_at desc);
create index if not exists idx_recommendation_exclusions_target
  on public.recommendation_exclusions(exclusion_type, target_id, created_at desc);
create index if not exists idx_notifications_user_read_created
  on public.notifications(user_id, read, created_at desc);
create index if not exists idx_collections_owner_updated
  on public.collections(user_id, updated_at desc);
create index if not exists idx_watch_later_items_user_target
  on public.watch_later_items(user_id, target_type, created_at desc);

alter table public.content_reports enable row level security;
alter table public.recommendation_exclusions enable row level security;

drop trigger if exists trg_content_reports_updated_at on public.content_reports;
create trigger trg_content_reports_updated_at
before update on public.content_reports
for each row execute function public.set_updated_at();

drop trigger if exists trg_recommendation_exclusions_updated_at on public.recommendation_exclusions;
create trigger trg_recommendation_exclusions_updated_at
before update on public.recommendation_exclusions
for each row execute function public.set_updated_at();

drop policy if exists content_reports_select_own on public.content_reports;
create policy content_reports_select_own
  on public.content_reports
  for select
  to authenticated
  using (auth.uid() = reporter_user_id);

drop policy if exists content_reports_insert_own on public.content_reports;
create policy content_reports_insert_own
  on public.content_reports
  for insert
  to authenticated
  with check (auth.uid() = reporter_user_id);

drop policy if exists recommendation_exclusions_select_own on public.recommendation_exclusions;
create policy recommendation_exclusions_select_own
  on public.recommendation_exclusions
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists recommendation_exclusions_insert_own on public.recommendation_exclusions;
create policy recommendation_exclusions_insert_own
  on public.recommendation_exclusions
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists recommendation_exclusions_update_own on public.recommendation_exclusions;
create policy recommendation_exclusions_update_own
  on public.recommendation_exclusions
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists recommendation_exclusions_delete_own on public.recommendation_exclusions;
create policy recommendation_exclusions_delete_own
  on public.recommendation_exclusions
  for delete
  to authenticated
  using (auth.uid() = user_id);

-- Ensure authenticated users can mark their own notifications as seen.
drop policy if exists notifications_update_own on public.notifications;
create policy notifications_update_own
  on public.notifications
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
