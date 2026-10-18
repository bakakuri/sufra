create table public.conversations (
  id bigint generated always as identity primary key,
  is_group boolean not null default false,
  title text check (char_length(title) <= 80),
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  last_message_at timestamptz not null default now()
);
create table public.conversation_members (
  conv_id bigint not null references public.conversations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  last_read_at timestamptz not null default now(),
  joined_at timestamptz not null default now(),
  primary key (conv_id, user_id)
);
create index conv_members_user_idx on public.conversation_members (user_id);
create table public.messages (
  id bigint generated always as identity primary key,
  conv_id bigint not null references public.conversations(id) on delete cascade,
  sender uuid references public.profiles(id) on delete set null,
  body text not null default '' check (char_length(body) <= 4000),
  media jsonb,
  kind text not null default 'text' check (kind in ('text','voice','image','system','game')),
  created_at timestamptz not null default now()
);
create index messages_conv_idx on public.messages (conv_id, created_at desc);
create table public.notifications (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  actor uuid references public.profiles(id) on delete cascade,
  kind text not null,
  ref jsonb not null default '{}',
  read boolean not null default false,
  created_at timestamptz not null default now()
);
create index notifications_user_idx on public.notifications (user_id, created_at desc);
create table public.push_subs (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  created_at timestamptz not null default now()
);
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;
alter table public.notifications enable row level security;
alter table public.push_subs enable row level security;

create or replace function public.is_member(c bigint) returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.conversation_members where conv_id = c and user_id = auth.uid());
$$;
create policy "my conversations" on public.conversations for select to authenticated using (public.is_member(id));
create policy "rename group chat" on public.conversations for update to authenticated using (public.is_member(id) and is_group) with check (public.is_member(id) and is_group);
revoke update on public.conversations from authenticated;
grant update (title) on public.conversations to authenticated;
create policy "members of my conversations" on public.conversation_members for select to authenticated using (public.is_member(conv_id));
create policy "mark read" on public.conversation_members for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "leave conversation" on public.conversation_members for delete to authenticated using (user_id = (select auth.uid()));
revoke update on public.conversation_members from authenticated;
grant update (last_read_at) on public.conversation_members to authenticated;
create policy "read messages" on public.messages for select to authenticated using (public.is_member(conv_id));
create policy "send message" on public.messages for insert to authenticated with check (sender = (select auth.uid()) and public.is_member(conv_id) and public.can_post() and kind <> 'system');
create policy "unsend own message" on public.messages for delete to authenticated using (sender = (select auth.uid()));
revoke update on public.messages from authenticated;
create policy "my notifications" on public.notifications for select to authenticated using (user_id = (select auth.uid()));
create policy "mark notifications read" on public.notifications for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "clear notifications" on public.notifications for delete to authenticated using (user_id = (select auth.uid()));
revoke insert on public.notifications from authenticated;
revoke update on public.notifications from authenticated;
grant update (read) on public.notifications to authenticated;
create policy "my push subscriptions" on public.push_subs for select to authenticated using (user_id = (select auth.uid()));
create policy "add push subscription" on public.push_subs for insert to authenticated with check (user_id = (select auth.uid()));
create policy "remove push subscription" on public.push_subs for delete to authenticated using (user_id = (select auth.uid()));

-- conversation RPCs
create or replace function public.start_dm(other uuid) returns bigint language plpgsql security definer set search_path = '' as $$
declare c bigint; pr jsonb;
begin
  if auth.uid() is null or other = auth.uid() then raise exception 'bad_request'; end if;
  if not public.can_post() then raise exception 'not_allowed'; end if;
  if public.is_blocked(auth.uid(), other) then raise exception 'blocked'; end if;
  select c1.conv_id into c from public.conversation_members c1
    join public.conversation_members c2 on c2.conv_id = c1.conv_id and c2.user_id = other
    join public.conversations cv on cv.id = c1.conv_id and not cv.is_group
    where c1.user_id = auth.uid() limit 1;
  if c is not null then return c; end if;
  select privacy into pr from public.profiles where id = other;
  if coalesce(pr->>'dm','all') = 'friends' and not public.are_friends(auth.uid(), other) then raise exception 'dm_friends_only'; end if;
  insert into public.conversations (is_group, created_by) values (false, auth.uid()) returning id into c;
  insert into public.conversation_members (conv_id, user_id) values (c, auth.uid()), (c, other);
  return c;
end $$;
create or replace function public.create_group_chat(p_title text, p_members uuid[]) returns bigint language plpgsql security definer set search_path = '' as $$
declare c bigint; m uuid;
begin
  if not public.can_post() then raise exception 'not_allowed'; end if;
  if coalesce(array_length(p_members, 1), 0) < 1 or array_length(p_members, 1) > 49 then raise exception 'bad_members'; end if;
  insert into public.conversations (is_group, title, created_by) values (true, left(coalesce(nullif(trim(p_title), ''), 'ჯგუფი'), 80), auth.uid()) returning id into c;
  insert into public.conversation_members (conv_id, user_id) values (c, auth.uid());
  foreach m in array p_members loop
    if m <> auth.uid() and not public.is_blocked(auth.uid(), m) and exists(select 1 from public.profiles where id = m) then
      insert into public.conversation_members (conv_id, user_id) values (c, m) on conflict do nothing;
    end if;
  end loop;
  insert into public.messages (conv_id, sender, body, kind) values (c, auth.uid(), 'ჯგუფი შეიქმნა', 'system');
  return c;
end $$;
create or replace function public.add_to_group_chat(c bigint, p_members uuid[]) returns void language plpgsql security definer set search_path = '' as $$
declare m uuid;
begin
  if not public.is_member(c) or not exists(select 1 from public.conversations where id = c and is_group) then raise exception 'not_allowed'; end if;
  foreach m in array p_members loop
    if not public.is_blocked(auth.uid(), m) and exists(select 1 from public.profiles where id = m) then
      insert into public.conversation_members (conv_id, user_id) values (c, m) on conflict do nothing;
    end if;
  end loop;
end $$;

-- notifications
create or replace function public.notify(p_user uuid, p_actor uuid, p_kind text, p_ref jsonb) returns void language plpgsql security definer set search_path = '' as $$
begin
  if p_user is null or p_user = p_actor then return; end if;
  if p_actor is not null and public.is_blocked(p_user, p_actor) then return; end if;
  insert into public.notifications (user_id, actor, kind, ref) values (p_user, p_actor, p_kind, coalesce(p_ref, '{}'));
end $$;
revoke execute on function public.notify(uuid, uuid, text, jsonb) from public, anon, authenticated;

create or replace function public.trg_reaction() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform public.notify((select author from public.posts where id = new.post_id), new.user_id, 'react', jsonb_build_object('post', new.post_id, 'emoji', new.emoji));
  return new;
end $$;
create trigger reactions_notify after insert on public.reactions for each row execute function public.trg_reaction();
create or replace function public.trg_comment() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform public.notify((select author from public.posts where id = new.post_id), new.author, 'comment', jsonb_build_object('post', new.post_id, 'text', left(new.body, 80)));
  return new;
end $$;
create trigger comments_notify after insert on public.comments for each row execute function public.trg_comment();
create or replace function public.trg_friend() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' then perform public.notify(new.addressee, new.requester, 'friend_req', '{}');
  elsif tg_op = 'UPDATE' and new.status = 'accepted' and old.status = 'pending' then perform public.notify(new.requester, new.addressee, 'friend_ok', '{}');
  end if;
  return new;
end $$;
create trigger friendships_notify after insert or update on public.friendships for each row execute function public.trg_friend();
create or replace function public.trg_message() returns trigger language plpgsql security definer set search_path = '' as $$
declare m record;
begin
  update public.conversations set last_message_at = new.created_at where id = new.conv_id;
  if new.kind = 'system' then return new; end if;
  for m in select user_id from public.conversation_members where conv_id = new.conv_id and user_id <> new.sender loop
    perform public.notify(m.user_id, new.sender, 'message', jsonb_build_object('conv', new.conv_id, 'text', left(case when new.kind = 'voice' then '🎤' when new.kind = 'image' then '📷' else new.body end, 80)));
  end loop;
  return new;
end $$;
create trigger messages_notify after insert on public.messages for each row execute function public.trg_message();
revoke execute on function public.trg_reaction(), public.trg_comment(), public.trg_friend(), public.trg_message() from public, anon, authenticated;

alter publication supabase_realtime add table public.messages, public.notifications;
