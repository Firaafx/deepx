-- Tracker/chat/upload runtime reliability fixes.

begin;

create or replace function public.create_group_chat(
  group_name text,
  member_ids uuid[]
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  current_id uuid := auth.uid();
  new_chat_id uuid;
  clean_name text;
  member_id uuid;
  unique_members uuid[];
begin
  if current_id is null then
    raise exception 'Not authenticated';
  end if;

  clean_name := nullif(trim(coalesce(group_name, '')), '');
  if clean_name is null then
    raise exception 'Group name is required';
  end if;

  unique_members := array(
    select distinct m
    from unnest(coalesce(member_ids, array[]::uuid[])) as m
    where m is not null and m <> current_id
  );

  insert into public.chats (created_by, is_group, name)
  values (current_id, true, clean_name)
  returning id into new_chat_id;

  insert into public.chat_members (chat_id, user_id, role)
  values (new_chat_id, current_id, 'owner')
  on conflict do nothing;

  foreach member_id in array unique_members loop
    insert into public.chat_members (chat_id, user_id, role)
    values (new_chat_id, member_id, 'member')
    on conflict do nothing;
  end loop;

  return new_chat_id;
end;
$$;

grant execute on function public.create_group_chat(text, uuid[]) to authenticated;

insert into storage.buckets (id, name, public)
values ('deepx-assets', 'deepx-assets', true)
on conflict (id) do update set public = excluded.public;

insert into storage.buckets (id, name, public)
values ('deepx-avatars', 'deepx-avatars', true)
on conflict (id) do update set public = excluded.public;

commit;
