-- DeepX completion: watch later + collection engagement + view stats.

create table if not exists public.watch_later_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  target_type text not null check (target_type in ('post', 'collection')),
  target_id uuid not null,
  created_at timestamptz not null default timezone('utc', now()),
  constraint watch_later_items_user_target_unique
    unique (user_id, target_type, target_id)
);

create index if not exists idx_watch_later_user_created
  on public.watch_later_items(user_id, created_at desc);
create index if not exists idx_watch_later_target
  on public.watch_later_items(target_type, target_id, created_at desc);

create table if not exists public.collection_reactions (
  id uuid primary key default gen_random_uuid(),
  collection_id uuid not null references public.collections(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  reaction smallint not null check (reaction in (-1, 1)),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint collection_reactions_unique unique (collection_id, user_id)
);

create table if not exists public.collection_comments (
  id uuid primary key default gen_random_uuid(),
  collection_id uuid not null references public.collections(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  content text not null check (char_length(content) > 0),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.saved_collections (
  id uuid primary key default gen_random_uuid(),
  collection_id uuid not null references public.collections(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint saved_collections_unique unique (collection_id, user_id)
);

create table if not exists public.collection_view_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  collection_id uuid not null references public.collections(id) on delete cascade,
  view_count integer not null default 1 check (view_count >= 1),
  first_viewed_at timestamptz not null default timezone('utc', now()),
  last_viewed_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint collection_view_history_unique unique (user_id, collection_id)
);

create index if not exists idx_collection_reactions_collection
  on public.collection_reactions(collection_id);
create index if not exists idx_collection_comments_collection_created
  on public.collection_comments(collection_id, created_at desc);
create index if not exists idx_saved_collections_collection
  on public.saved_collections(collection_id);
create index if not exists idx_collection_view_history_last_viewed
  on public.collection_view_history(user_id, last_viewed_at desc);
create index if not exists idx_collection_view_history_collection
  on public.collection_view_history(collection_id);

drop trigger if exists trg_collection_reactions_updated_at on public.collection_reactions;
create trigger trg_collection_reactions_updated_at
before update on public.collection_reactions
for each row execute function public.set_updated_at();

drop trigger if exists trg_collection_comments_updated_at on public.collection_comments;
create trigger trg_collection_comments_updated_at
before update on public.collection_comments
for each row execute function public.set_updated_at();

drop trigger if exists trg_saved_collections_updated_at on public.saved_collections;
create trigger trg_saved_collections_updated_at
before update on public.saved_collections
for each row execute function public.set_updated_at();

drop trigger if exists trg_collection_view_history_updated_at on public.collection_view_history;
create trigger trg_collection_view_history_updated_at
before update on public.collection_view_history
for each row execute function public.set_updated_at();

alter table public.watch_later_items enable row level security;
alter table public.collection_reactions enable row level security;
alter table public.collection_comments enable row level security;
alter table public.saved_collections enable row level security;
alter table public.collection_view_history enable row level security;

drop policy if exists watch_later_items_select_own on public.watch_later_items;
create policy watch_later_items_select_own
  on public.watch_later_items
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists watch_later_items_insert_own on public.watch_later_items;
create policy watch_later_items_insert_own
  on public.watch_later_items
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists watch_later_items_delete_own on public.watch_later_items;
create policy watch_later_items_delete_own
  on public.watch_later_items
  for delete
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists collection_reactions_select_all_authenticated on public.collection_reactions;
create policy collection_reactions_select_all_authenticated
  on public.collection_reactions
  for select
  to authenticated
  using (true);

drop policy if exists collection_reactions_select_all_anon on public.collection_reactions;
create policy collection_reactions_select_all_anon
  on public.collection_reactions
  for select
  to anon
  using (true);

drop policy if exists collection_reactions_insert_own on public.collection_reactions;
create policy collection_reactions_insert_own
  on public.collection_reactions
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists collection_reactions_update_own on public.collection_reactions;
create policy collection_reactions_update_own
  on public.collection_reactions
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists collection_reactions_delete_own on public.collection_reactions;
create policy collection_reactions_delete_own
  on public.collection_reactions
  for delete
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists collection_comments_select_all_authenticated on public.collection_comments;
create policy collection_comments_select_all_authenticated
  on public.collection_comments
  for select
  to authenticated
  using (true);

drop policy if exists collection_comments_select_all_anon on public.collection_comments;
create policy collection_comments_select_all_anon
  on public.collection_comments
  for select
  to anon
  using (true);

drop policy if exists collection_comments_insert_own on public.collection_comments;
create policy collection_comments_insert_own
  on public.collection_comments
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists collection_comments_update_own on public.collection_comments;
create policy collection_comments_update_own
  on public.collection_comments
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists collection_comments_delete_own on public.collection_comments;
create policy collection_comments_delete_own
  on public.collection_comments
  for delete
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists saved_collections_select_all_authenticated on public.saved_collections;
create policy saved_collections_select_all_authenticated
  on public.saved_collections
  for select
  to authenticated
  using (true);

drop policy if exists saved_collections_select_all_anon on public.saved_collections;
create policy saved_collections_select_all_anon
  on public.saved_collections
  for select
  to anon
  using (true);

drop policy if exists saved_collections_insert_own on public.saved_collections;
create policy saved_collections_insert_own
  on public.saved_collections
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists saved_collections_delete_own on public.saved_collections;
create policy saved_collections_delete_own
  on public.saved_collections
  for delete
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists collection_view_history_select_own on public.collection_view_history;
create policy collection_view_history_select_own
  on public.collection_view_history
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists collection_view_history_insert_own on public.collection_view_history;
create policy collection_view_history_insert_own
  on public.collection_view_history
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists collection_view_history_update_own on public.collection_view_history;
create policy collection_view_history_update_own
  on public.collection_view_history
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists collection_view_history_delete_own on public.collection_view_history;
create policy collection_view_history_delete_own
  on public.collection_view_history
  for delete
  to authenticated
  using (auth.uid() = user_id);

create or replace view public.preset_stats as
select
  p.id as preset_id,
  coalesce((
    select count(*)
    from public.preset_reactions r
    where r.preset_id = p.id and r.reaction = 1
  ), 0)::bigint as likes_count,
  coalesce((
    select count(*)
    from public.preset_reactions r
    where r.preset_id = p.id and r.reaction = -1
  ), 0)::bigint as dislikes_count,
  coalesce((
    select count(*)
    from public.preset_comments c
    where c.preset_id = p.id
  ), 0)::bigint as comments_count,
  coalesce((
    select count(*)
    from public.saved_presets s
    where s.preset_id = p.id
  ), 0)::bigint as saves_count,
  coalesce((
    select sum(v.view_count)::bigint
    from public.view_history v
    where v.preset_id = p.id
  ), 0)::bigint as views_count
from public.presets p;

create or replace view public.collection_stats as
select
  c.id as collection_id,
  coalesce((
    select count(*)
    from public.collection_reactions r
    where r.collection_id = c.id and r.reaction = 1
  ), 0)::bigint as likes_count,
  coalesce((
    select count(*)
    from public.collection_reactions r
    where r.collection_id = c.id and r.reaction = -1
  ), 0)::bigint as dislikes_count,
  coalesce((
    select count(*)
    from public.collection_comments cm
    where cm.collection_id = c.id
  ), 0)::bigint as comments_count,
  coalesce((
    select count(*)
    from public.saved_collections s
    where s.collection_id = c.id
  ), 0)::bigint as saves_count,
  coalesce((
    select sum(v.view_count)::bigint
    from public.collection_view_history v
    where v.collection_id = c.id
  ), 0)::bigint as views_count
from public.collections c;

create or replace function public.record_collection_view(p_collection_id uuid)
returns void
language plpgsql
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    return;
  end if;

  insert into public.collection_view_history (user_id, collection_id, view_count)
  values (v_user, p_collection_id, 1)
  on conflict (user_id, collection_id) do update
    set view_count = public.collection_view_history.view_count + 1,
        last_viewed_at = timezone('utc', now());
end;
$$;

grant execute on function public.record_collection_view(uuid) to authenticated;
