-- ============ @mentions in posts and comments ============
create or replace function public.mention_ids(t text) returns uuid[] language sql stable security definer set search_path = '' as $$
  select coalesce(array_agg(distinct p.id), '{}')
  from (select rtrim(lower(m[1]), '.') as u from regexp_matches(coalesce(t, ''), '(?:^|[^A-Za-z0-9_.@/])@([A-Za-z0-9_.]{3,24})', 'g') as m limit 15) x
  join public.profiles p on lower(p.username) = x.u and p.onboarded and not p.banned;
$$;
revoke execute on function public.mention_ids(text) from public, anon, authenticated;

-- can this person see a post of that group?
create or replace function public.group_open_to(g bigint, u uuid) returns boolean language sql stable security definer set search_path = '' as $$
  select g is null
    or exists (select 1 from public.groups where id = g and (not is_private or owner = u))
    or exists (select 1 from public.group_members where group_id = g and user_id = u);
$$;
revoke execute on function public.group_open_to(bigint, uuid) from public, anon, authenticated;

create or replace function public.trg_post_mentions() returns trigger language plpgsql security definer set search_path = '' as $$
declare u uuid; olds uuid[] := '{}';
begin
  if new.draft or new.hidden or new.created_at > now() + interval '1 minute' then return new; end if;
  if tg_op = 'UPDATE' and not old.draft then olds := public.mention_ids(old.body); end if;
  foreach u in array public.mention_ids(new.body) loop
    continue when u = new.author or u = any(olds);
    continue when not public.group_open_to(new.group_id, u);
    perform public.notify(u, new.author, 'mention', jsonb_build_object('post', new.id, 'text', left(new.body, 80)));
  end loop;
  return new;
end $$;
create trigger posts_mentions after insert or update of body, draft on public.posts for each row execute function public.trg_post_mentions();

create or replace function public.trg_comment() returns trigger language plpgsql security definer set search_path = '' as $$
declare pa uuid; pg bigint; ca uuid; u uuid;
begin
  select author, group_id into pa, pg from public.posts where id = new.post_id;
  if new.parent_id is not null then
    select author into ca from public.comments where id = new.parent_id;
    perform public.notify(ca, new.author, 'comment_reply', jsonb_build_object('post', new.post_id, 'comment', new.parent_id, 'text', left(new.body, 80)));
  end if;
  if ca is null or pa is distinct from ca then
    perform public.notify(pa, new.author, 'comment', jsonb_build_object('post', new.post_id, 'text', left(new.body, 80)));
  end if;
  foreach u in array public.mention_ids(new.body) loop
    continue when u = new.author or u = pa or u = ca;
    continue when not public.group_open_to(pg, u);
    perform public.notify(u, new.author, 'mention', jsonb_build_object('post', new.post_id, 'comment', new.id, 'text', left(new.body, 80)));
  end loop;
  return new;
end $$;

-- ============ reactions on chat messages ============
-- removing a reaction sets emoji to null (an UPDATE), so the change reaches the chat through filtered realtime
create table public.message_reactions (
  message_id bigint not null references public.messages(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  conv_id bigint not null references public.conversations(id) on delete cascade,
  emoji text check (emoji is null or emoji in ('❤️','😂','😮','😢','👍','🍷','🔥','🙏')),
  created_at timestamptz not null default now(),
  primary key (message_id, user_id)
);
create index message_reactions_conv_idx on public.message_reactions (conv_id);
alter table public.message_reactions enable row level security;
revoke all on public.message_reactions from anon;
revoke update on public.message_reactions from authenticated;
grant update (emoji) on public.message_reactions to authenticated;

create or replace function public.msg_react_before() returns trigger language plpgsql security definer set search_path = '' as $$
declare m record;
begin
  if tg_op = 'UPDATE' then new.message_id := old.message_id; new.user_id := old.user_id; new.conv_id := old.conv_id; new.created_at := now(); return new; end if;
  select conv_id, deleted into m from public.messages where id = new.message_id;
  if m.conv_id is null or m.deleted then raise exception 'not_found'; end if;
  new.conv_id := m.conv_id; new.created_at := now();
  return new;
end $$;
create trigger message_reactions_before before insert or update on public.message_reactions for each row execute function public.msg_react_before();

create policy "reactions in my chats" on public.message_reactions for select to authenticated using (public.is_member(conv_id));
create policy "react to message" on public.message_reactions for insert to authenticated with check (user_id = (select auth.uid()) and public.is_member(conv_id) and public.can_post());
create policy "change my reaction" on public.message_reactions for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create or replace function public.trg_msg_react() returns trigger language plpgsql security definer set search_path = '' as $$
declare m record;
begin
  if new.emoji is null or (tg_op = 'UPDATE' and old.emoji is not distinct from new.emoji) then return null; end if;
  select id, sender, conv_id, body, kind into m from public.messages where id = new.message_id;
  if m.sender = new.user_id then return null; end if;
  if exists (select 1 from public.conversation_members where conv_id = m.conv_id and user_id = m.sender and muted_until > now()) then return null; end if;
  if not exists (select 1 from public.notifications where user_id = m.sender and actor = new.user_id and kind = 'msg_react' and ref->>'msg' = m.id::text) then
    perform public.notify(m.sender, new.user_id, 'msg_react', jsonb_build_object('conv', m.conv_id, 'msg', m.id, 'emoji', new.emoji,
      'text', left(case when m.kind = 'voice' then '🎤' when m.kind = 'image' then '📷' else coalesce(m.body, '') end, 60)));
  end if;
  return null;
end $$;

-- ============ muting and archiving chats (only the member sees their own flags) ============
alter table public.conversation_members add column muted_until timestamptz, add column archived boolean not null default false;
grant update (muted_until, archived) on public.conversation_members to authenticated;
create trigger message_reactions_notify after insert or update on public.message_reactions for each row execute function public.trg_msg_react();

create or replace function public.trg_message() returns trigger language plpgsql security definer set search_path = '' as $$
declare m record;
begin
  update public.conversations set last_message_at = new.created_at where id = new.conv_id;
  if new.kind = 'system' then return new; end if;
  for m in select user_id, muted_until from public.conversation_members where conv_id = new.conv_id and user_id <> new.sender loop
    if m.muted_until is null or m.muted_until < now() then
      perform public.notify(m.user_id, new.sender, 'message', jsonb_build_object('conv', new.conv_id, 'text', left(case when new.kind = 'voice' then '🎤' when new.kind = 'image' then '📷' else new.body end, 80)));
    end if;
  end loop;
  -- a new message brings an archived chat back, unless it is muted
  update public.conversation_members set archived = false
    where conv_id = new.conv_id and archived and (user_id = new.sender or muted_until is null or muted_until < now());
  return new;
end $$;

create or replace function public.my_conv_flags() returns table (conv_id bigint, muted_until timestamptz, archived boolean)
language sql stable security definer set search_path = '' as $$
  select conv_id, muted_until, archived from public.conversation_members where user_id = auth.uid();
$$;
revoke execute on function public.my_conv_flags() from public, anon;
grant execute on function public.my_conv_flags() to authenticated;

-- the chat list with my own flags (my_conversations stays as it was for older clients)
create or replace function public.my_chats()
 returns table(conv_id bigint, is_group boolean, title text, last_message_at timestamptz, last_body text, last_kind text, last_sender uuid, unread integer, members uuid[], muted_until timestamptz, archived boolean)
 language sql stable set search_path = '' as $$
  select c.id, c.is_group, c.title, c.last_message_at, lm.body, lm.kind, lm.sender,
    (select count(*)::int from public.messages m where m.conv_id = c.id and m.created_at > public.my_last_read(c.id) and m.sender is distinct from auth.uid()),
    (select array_agg(x.user_id) from public.conversation_members x where x.conv_id = c.id and x.user_id <> auth.uid()),
    f.muted_until, f.archived
  from public.conversation_members cm
  join public.conversations c on c.id = cm.conv_id
  join public.my_conv_flags() f on f.conv_id = c.id
  left join lateral (select m.body, m.kind, m.sender from public.messages m where m.conv_id = c.id order by m.created_at desc limit 1) lm on true
  where cm.user_id = auth.uid()
  order by c.last_message_at desc
  limit 200;
$$;

-- ============ story reactions and polls ============
alter table public.stories add column poll jsonb;
create or replace function public.stories_before() returns trigger language plpgsql set search_path = '' as $$
declare o jsonb := '[]'::jsonb; x jsonb;
begin
  if new.poll is null then return new; end if;
  if jsonb_typeof(new.poll) <> 'object' or jsonb_typeof(new.poll->'opts') <> 'array' then new.poll := null; return new; end if;
  for x in select * from jsonb_array_elements(new.poll->'opts') limit 4 loop
    if jsonb_typeof(x) = 'string' and length(trim(x #>> '{}')) > 0 then o := o || to_jsonb(left(trim(x #>> '{}'), 30)); end if;
  end loop;
  if jsonb_array_length(o) < 2 then new.poll := null; return new; end if;
  new.poll := jsonb_build_object('q', left(coalesce(trim(new.poll->>'q'), ''), 90), 'opts', o);
  return new;
end $$;
create trigger stories_before before insert on public.stories for each row execute function public.stories_before();
revoke update on public.stories from authenticated;

create or replace function public.story_author(s bigint) returns uuid language sql stable security definer set search_path = '' as $$
  select author from public.stories where id = s;
$$;

create table public.story_reactions (
  story_id bigint not null references public.stories(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  emoji text not null check (emoji in ('❤️','😂','😮','😢','🔥','👏','🍷')),
  created_at timestamptz not null default now(),
  primary key (story_id, user_id)
);
alter table public.story_reactions enable row level security;
revoke all on public.story_reactions from anon;
create policy "story reactions visible" on public.story_reactions for select to authenticated using (user_id = (select auth.uid()) or public.story_author(story_id) = (select auth.uid()));
create policy "react to story" on public.story_reactions for insert to authenticated with check (user_id = (select auth.uid()) and public.can_post() and exists (select 1 from public.stories s where s.id = story_id and s.author <> (select auth.uid())));
create policy "change story reaction" on public.story_reactions for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "remove story reaction" on public.story_reactions for delete to authenticated using (user_id = (select auth.uid()));

create table public.story_votes (
  story_id bigint not null references public.stories(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  opt int not null check (opt between 0 and 3),
  created_at timestamptz not null default now(),
  primary key (story_id, user_id)
);
alter table public.story_votes enable row level security;
revoke all on public.story_votes from anon;
revoke update on public.story_votes from authenticated;
create policy "story votes visible" on public.story_votes for select to authenticated using (user_id = (select auth.uid()) or public.story_author(story_id) = (select auth.uid()));
create policy "vote in story" on public.story_votes for insert to authenticated with check (user_id = (select auth.uid()) and exists (
  select 1 from public.stories s where s.id = story_id and s.poll is not null and s.author <> (select auth.uid()) and opt < jsonb_array_length(s.poll->'opts')));

create or replace function public.trg_story_react() returns trigger language plpgsql security definer set search_path = '' as $$
declare a uuid;
begin
  a := public.story_author(new.story_id);
  if not exists (select 1 from public.notifications where user_id = a and actor = new.user_id and kind = 'story_react' and ref->>'story' = new.story_id::text) then
    perform public.notify(a, new.user_id, 'story_react', jsonb_build_object('story', new.story_id, 'emoji', new.emoji));
  end if;
  return null;
end $$;
create trigger story_reactions_notify after insert on public.story_reactions for each row execute function public.trg_story_react();

-- results: the author always, others after voting
create or replace function public.story_poll(p_story bigint) returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare s record; mine int; res jsonb;
begin
  select id, author, poll into s from public.stories where id = p_story and expires_at > now() - interval '2 days';
  if s.id is null or s.poll is null then return null; end if;
  select opt into mine from public.story_votes where story_id = p_story and user_id = auth.uid();
  if s.author <> auth.uid() and mine is null then return jsonb_build_object('mine', null); end if;
  select jsonb_build_object('mine', mine, 'total', count(*), 'counts', (
    select jsonb_agg(coalesce((select count(*) from public.story_votes v where v.story_id = p_story and v.opt = i), 0) order by i)
    from generate_series(0, jsonb_array_length(s.poll->'opts') - 1) i))
  into res from public.story_votes where story_id = p_story;
  return res;
end $$;

-- ============ notification categories ============
create or replace function public.notif_category(k text) returns text language sql immutable set search_path = '' as $$
  select case
    when k in ('react', 'comment_like', 'repost', 'msg_react', 'story_react') then 'reactions'
    when k in ('comment', 'comment_reply', 'mention') then 'comments'
    when k in ('friend_req', 'friend_ok', 'kin_req', 'kin_ok') then 'friends'
    when k = 'message' then 'messages'
    when k in ('nameday', 'birthday', 'nameday_me', 'birthday_me') then 'celebrations'
    when k = 'live_start' then 'live'
    when k = 'room_invite' then 'rooms'
    when k = 'help_new' then 'help'
    when k in ('match', 'super') then 'dating'
    when k = 'gift' then 'gifts'
    when k like 'bet\_%' then 'sport'
    when k like 'ride\_%' or k like 'job\_%' then 'deals'
    when k like 'group\_%' then 'groups'
    when k like 'event\_%' or k like 'album\_%' then 'events'
    else 'system' end;
$$;

alter publication supabase_realtime add table public.message_reactions;

revoke execute on function public.trg_post_mentions(), public.trg_comment(), public.msg_react_before(), public.trg_msg_react(), public.trg_message(),
  public.stories_before(), public.trg_story_react() from public, anon, authenticated;
revoke execute on function public.my_chats(), public.story_poll(bigint), public.story_author(bigint), public.notif_category(text) from public, anon;
grant execute on function public.my_chats(), public.story_poll(bigint), public.story_author(bigint), public.notif_category(text) to authenticated;
