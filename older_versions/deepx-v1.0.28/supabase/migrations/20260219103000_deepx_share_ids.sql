-- DeepX share id support for routeable post/collection links.

create or replace function public.generate_base62_id(p_len integer default 8)
returns text
language plpgsql
as $$
declare
  chars constant text := 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  out_text text := '';
  i integer;
begin
  if p_len < 1 then
    return '';
  end if;
  for i in 1..p_len loop
    out_text := out_text || substr(chars, floor(random() * length(chars) + 1)::integer, 1);
  end loop;
  return out_text;
end;
$$;

alter table if exists public.presets
  add column if not exists share_id text;

alter table if exists public.collections
  add column if not exists share_id text;

-- Backfill presets share ids.
do $$
declare
  row_record record;
  candidate text;
  taken boolean;
begin
  for row_record in
    select id from public.presets
    where share_id is null or share_id !~ '^[A-Za-z0-9]{8}$'
  loop
    loop
      candidate := public.generate_base62_id(8);
      select exists(
        select 1 from public.presets p where p.share_id = candidate
      ) into taken;
      exit when not taken;
    end loop;

    update public.presets
    set share_id = candidate
    where id = row_record.id;
  end loop;
end;
$$;

-- Backfill collection share ids.
do $$
declare
  row_record record;
  candidate text;
  taken boolean;
begin
  for row_record in
    select id from public.collections
    where share_id is null or share_id !~ '^[A-Za-z0-9]{8}$'
  loop
    loop
      candidate := public.generate_base62_id(8);
      select exists(
        select 1 from public.collections c where c.share_id = candidate
      ) into taken;
      exit when not taken;
    end loop;

    update public.collections
    set share_id = candidate
    where id = row_record.id;
  end loop;
end;
$$;

alter table if exists public.presets
  alter column share_id set not null;

alter table if exists public.collections
  alter column share_id set not null;

alter table if exists public.presets
  drop constraint if exists presets_share_id_format;

alter table if exists public.presets
  add constraint presets_share_id_format
    check (share_id ~ '^[A-Za-z0-9]{8}$');

alter table if exists public.collections
  drop constraint if exists collections_share_id_format;

alter table if exists public.collections
  add constraint collections_share_id_format
    check (share_id ~ '^[A-Za-z0-9]{8}$');

create unique index if not exists idx_presets_share_id_unique
  on public.presets(share_id);

create unique index if not exists idx_collections_share_id_unique
  on public.collections(share_id);

create or replace function public.ensure_preset_share_id()
returns trigger
language plpgsql
as $$
declare
  candidate text;
  taken boolean;
begin
  if new.share_id is not null and new.share_id <> '' then
    if new.share_id !~ '^[A-Za-z0-9]{8}$' then
      raise exception 'Invalid presets.share_id format';
    end if;
    return new;
  end if;

  loop
    candidate := public.generate_base62_id(8);
    select exists(
      select 1 from public.presets p
      where p.share_id = candidate
        and p.id <> coalesce(new.id, '00000000-0000-0000-0000-000000000000'::uuid)
    ) into taken;
    exit when not taken;
  end loop;

  new.share_id := candidate;
  return new;
end;
$$;

create or replace function public.ensure_collection_share_id()
returns trigger
language plpgsql
as $$
declare
  candidate text;
  taken boolean;
begin
  if new.share_id is not null and new.share_id <> '' then
    if new.share_id !~ '^[A-Za-z0-9]{8}$' then
      raise exception 'Invalid collections.share_id format';
    end if;
    return new;
  end if;

  loop
    candidate := public.generate_base62_id(8);
    select exists(
      select 1 from public.collections c
      where c.share_id = candidate
        and c.id <> coalesce(new.id, '00000000-0000-0000-0000-000000000000'::uuid)
    ) into taken;
    exit when not taken;
  end loop;

  new.share_id := candidate;
  return new;
end;
$$;

drop trigger if exists trg_presets_share_id on public.presets;
create trigger trg_presets_share_id
before insert or update of share_id on public.presets
for each row execute function public.ensure_preset_share_id();

drop trigger if exists trg_collections_share_id on public.collections;
create trigger trg_collections_share_id
before insert or update of share_id on public.collections
for each row execute function public.ensure_collection_share_id();
