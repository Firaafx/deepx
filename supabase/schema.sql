-- DeepX production schema for Supabase
-- Run this in Supabase SQL Editor after creating your project.

create extension if not exists pgcrypto;

-- enum for mode-scoped records
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'render_mode') THEN
    CREATE TYPE public.render_mode AS ENUM ('2d', '3d');
  END IF;
END $$;

-- per-user persisted editor/session state
create table if not exists public.mode_states (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  mode public.render_mode not null,
  state jsonb not null default '{}'::jsonb
    check (jsonb_typeof(state) = 'object'),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint mode_states_user_mode_unique unique (user_id, mode)
);

-- named presets saved by users
create table if not exists public.presets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  mode public.render_mode not null,
  name text not null check (char_length(trim(name)) > 0),
  payload jsonb not null check (jsonb_typeof(payload) = 'object'),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint presets_user_mode_name_unique unique (user_id, mode, name)
);

create index if not exists idx_mode_states_user_mode on public.mode_states(user_id, mode);
create index if not exists idx_presets_mode_updated on public.presets(mode, updated_at desc);
create index if not exists idx_presets_user_mode on public.presets(user_id, mode);

-- auto-update updated_at
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists trg_mode_states_updated_at on public.mode_states;
create trigger trg_mode_states_updated_at
before update on public.mode_states
for each row
execute function public.set_updated_at();

drop trigger if exists trg_presets_updated_at on public.presets;
create trigger trg_presets_updated_at
before update on public.presets
for each row
execute function public.set_updated_at();

-- RLS
alter table public.mode_states enable row level security;
alter table public.presets enable row level security;

-- mode_states policies: users can only manage their own state
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'mode_states'
      AND policyname = 'mode_states_select_own'
  ) THEN
    CREATE POLICY mode_states_select_own
      ON public.mode_states
      FOR SELECT
      TO authenticated
      USING (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'mode_states'
      AND policyname = 'mode_states_insert_own'
  ) THEN
    CREATE POLICY mode_states_insert_own
      ON public.mode_states
      FOR INSERT
      TO authenticated
      WITH CHECK (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'mode_states'
      AND policyname = 'mode_states_update_own'
  ) THEN
    CREATE POLICY mode_states_update_own
      ON public.mode_states
      FOR UPDATE
      TO authenticated
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'mode_states'
      AND policyname = 'mode_states_delete_own'
  ) THEN
    CREATE POLICY mode_states_delete_own
      ON public.mode_states
      FOR DELETE
      TO authenticated
      USING (auth.uid() = user_id);
  END IF;
END $$;

-- presets policies:
-- authenticated users can view feed presets from everyone,
-- but only create/update/delete their own.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'presets'
      AND policyname = 'presets_select_feed'
  ) THEN
    CREATE POLICY presets_select_feed
      ON public.presets
      FOR SELECT
      TO authenticated
      USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'presets'
      AND policyname = 'presets_insert_own'
  ) THEN
    CREATE POLICY presets_insert_own
      ON public.presets
      FOR INSERT
      TO authenticated
      WITH CHECK (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'presets'
      AND policyname = 'presets_update_own'
  ) THEN
    CREATE POLICY presets_update_own
      ON public.presets
      FOR UPDATE
      TO authenticated
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'presets'
      AND policyname = 'presets_delete_own'
  ) THEN
    CREATE POLICY presets_delete_own
      ON public.presets
      FOR DELETE
      TO authenticated
      USING (auth.uid() = user_id);
  END IF;
END $$;
