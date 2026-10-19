-- ============ post edits and reposts ============
alter table public.posts
  add column edited_at timestamptz,
  add column repost_of bigint references public.posts(id) on delete cascade;
create index posts_repost_idx on public.posts (repost_of) where repost_of is not null;
-- one plain repost per person and post (quotes can be many)
create unique index posts_one_repost_idx on public.posts (author, repost_of) where repost_of is not null and body = '';
grant update (place_id) on public.posts to authenticated;

create or replace function public.posts_edited() returns trigger language plpgsql set search_path = '' as $$
begin
  new.repost_of := old.repost_of;
  if not old.draft and old.created_at <= now()
     and (new.body is distinct from old.body or new.media is distinct from old.media or new.place_id is distinct from old.place_id) then
    new.edited_at := now();
  end if;
  return new;
end $$;
create trigger posts_edited before update on public.posts for each row execute function public.posts_edited();

create or replace function public.posts_repost() returns trigger language plpgsql security definer set search_path = '' as $$
declare o record;
begin
  if new.repost_of is null then return new; end if;
  select id, author, body, repost_of, group_id, hidden, draft, created_at into o from public.posts where id = new.repost_of;
  if o.id is null or o.hidden or o.draft or o.created_at > now() then raise exception 'not_found'; end if;
  -- reposting a plain repost points to the original
  if o.repost_of is not null and o.body = '' then
    new.repost_of := o.repost_of;
    select id, author, body, repost_of, group_id, hidden, draft, created_at into o from public.posts where id = new.repost_of;
    if o.id is null or o.hidden or o.draft or o.created_at > now() then raise exception 'not_found'; end if;
  end if;
  if o.group_id is not null then raise exception 'not_allowed'; end if;
  if public.is_blocked(new.author, o.author) then raise exception 'blocked'; end if;
  new.media := '[]'::jsonb; new.poll := null; new.is_clip := false;
  return new;
end $$;
create trigger posts_repost before insert on public.posts for each row execute function public.posts_repost();

create or replace function public.trg_repost_notify() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.repost_of is not null and not new.draft then
    perform public.notify((select author from public.posts where id = new.repost_of), new.author, 'repost', jsonb_build_object('post', new.repost_of, 'quote', new.body <> '', 'by', new.id));
  end if;
  return new;
end $$;
create trigger posts_repost_notify after insert on public.posts for each row execute function public.trg_repost_notify();

create or replace function public.repost_stats(p_ids bigint[]) returns table (post_id bigint, n int, mine bigint)
language sql stable security invoker set search_path = '' as $$
  select u.id,
    (select count(*)::int from public.posts r where r.repost_of = u.id and not r.hidden and not r.draft),
    (select r.id from public.posts r where r.repost_of = u.id and r.author = auth.uid() and r.body = '' limit 1)
  from unnest(p_ids) as u(id);
$$;

-- a story made from a post links back to it
alter table public.stories add column post_id bigint references public.posts(id) on delete set null;

-- ============ comment replies and likes ============
alter table public.comments
  add column parent_id bigint references public.comments(id) on delete cascade,
  add column likes int not null default 0;
create index comments_parent_idx on public.comments (parent_id) where parent_id is not null;

create or replace function public.comments_before() returns trigger language plpgsql security definer set search_path = '' as $$
declare par record;
begin
  new.likes := 0;
  if new.parent_id is not null then
    select id, post_id, parent_id into par from public.comments where id = new.parent_id;
    if par.id is null or par.post_id <> new.post_id then new.parent_id := null;
    else new.parent_id := coalesce(par.parent_id, par.id);  -- replies stay one level deep
    end if;
  end if;
  return new;
end $$;
create trigger comments_before before insert on public.comments for each row execute function public.comments_before();

create or replace function public.trg_comment() returns trigger language plpgsql security definer set search_path = '' as $$
declare pa uuid; ca uuid;
begin
  select author into pa from public.posts where id = new.post_id;
  if new.parent_id is not null then
    select author into ca from public.comments where id = new.parent_id;
    perform public.notify(ca, new.author, 'comment_reply', jsonb_build_object('post', new.post_id, 'comment', new.parent_id, 'text', left(new.body, 80)));
  end if;
  if ca is null or pa is distinct from ca then
    perform public.notify(pa, new.author, 'comment', jsonb_build_object('post', new.post_id, 'text', left(new.body, 80)));
  end if;
  return new;
end $$;

create table public.comment_likes (
  comment_id bigint not null references public.comments(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (comment_id, user_id)
);
create index comment_likes_user_idx on public.comment_likes (user_id);
alter table public.comment_likes enable row level security;
revoke all on public.comment_likes from anon;
create policy "comment likes visible" on public.comment_likes for select to authenticated using (user_id = (select auth.uid()));
create policy "like comment" on public.comment_likes for insert to authenticated
  with check (user_id = (select auth.uid()) and public.can_post() and exists (select 1 from public.comments c where c.id = comment_id));
create policy "unlike comment" on public.comment_likes for delete to authenticated using (user_id = (select auth.uid()));

create or replace function public.trg_comment_like() returns trigger language plpgsql security definer set search_path = '' as $$
declare c record; cid bigint := coalesce(new.comment_id, old.comment_id);
begin
  update public.comments set likes = (select count(*) from public.comment_likes where comment_id = cid) where id = cid;
  if tg_op = 'INSERT' then
    select id, author, post_id, body into c from public.comments where id = new.comment_id;
    if not exists (select 1 from public.notifications where user_id = c.author and actor = new.user_id and kind = 'comment_like' and ref->>'comment' = c.id::text) then
      perform public.notify(c.author, new.user_id, 'comment_like', jsonb_build_object('post', c.post_id, 'comment', c.id, 'text', left(c.body, 60)));
    end if;
  end if;
  return null;
end $$;
create trigger comment_likes_count after insert or delete on public.comment_likes for each row execute function public.trg_comment_like();

-- ============ notification preferences and quiet hours ============
-- {"off": {"reactions": true, ...}, "quiet": {"on": true, "from": 23, "to": 8, "tz": "Asia/Tbilisi"}}
-- readable only by the owner (through my_profile), writable by the owner
alter table public.profiles add column notif jsonb not null default '{}'::jsonb check (jsonb_typeof(notif) = 'object' and pg_column_size(notif) < 2000);
grant update (notif) on public.profiles to authenticated;

create or replace function public.notif_category(k text) returns text language sql immutable set search_path = '' as $$
  select case
    when k in ('react', 'comment_like', 'repost') then 'reactions'
    when k in ('comment', 'comment_reply') then 'comments'
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
    else 'system' end;
$$;

create or replace function public.notif_off(u uuid, k text) returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce((select (notif->'off'->>public.notif_category(k)) = 'true' from public.profiles where id = u), false);
$$;
revoke execute on function public.notif_off(uuid, text) from public, anon, authenticated;

-- messages always reach the inbox (only their push can be muted); system notices always arrive
create or replace function public.notify(p_user uuid, p_actor uuid, p_kind text, p_ref jsonb) returns void language plpgsql security definer set search_path = '' as $$
begin
  if p_user is null or p_user = p_actor then return; end if;
  if p_actor is not null and public.is_blocked(p_user, p_actor) then return; end if;
  if p_kind <> 'message' and public.notif_category(p_kind) <> 'system' and public.notif_off(p_user, p_kind) then return; end if;
  insert into public.notifications (user_id, actor, kind, ref) values (p_user, p_actor, p_kind, coalesce(p_ref, '{}'));
end $$;
revoke execute on function public.notify(uuid, uuid, text, jsonb) from public, anon, authenticated;

create or replace function private.daily_celebrations() returns int language plpgsql security definer set search_path = '' as $$
declare today text := to_char((now() at time zone 'Asia/Tbilisi')::date, 'MM-DD'); n int := 0; k int;
begin
  create temp table _cel (uid uuid, kind text, label text) on commit drop;
  insert into _cel
    select p.id, 'nameday', coalesce(nullif(p.nameday_label, ''), 'ანგელოზის დღე') from public.profiles p
    where p.nameday = today and p.onboarded and not p.banned;
  insert into _cel
    select p.id, 'nameday', min(d.label) from public.profiles p
    join public.name_days d on d.md = today and lower(split_part(trim(p.name), ' ', 1)) = any(d.names)
    where p.nameday is null and p.onboarded and not p.banned group by p.id;
  insert into _cel
    select p.id, 'birthday', 'დაბადების დღე' from public.profiles p
    where p.birthday is not null and to_char(p.birthday, 'MM-DD') = today and p.onboarded and not p.banned;

  -- friends
  insert into public.notifications (user_id, actor, kind, ref)
  select x.uid, x.ids[1], x.kind, jsonb_build_object('n', x.cnt, 'label', x.label, 'ids', to_jsonb(x.ids[1:5]), 'day', today)
  from (
    select f.friend as uid, c.kind, count(*)::int as cnt, min(c.label) as label, array_agg(c.uid order by c.uid) as ids
    from _cel c
    join lateral (
      select case when fr.requester = c.uid then fr.addressee else fr.requester end as friend
      from public.friendships fr where fr.status = 'accepted' and (fr.requester = c.uid or fr.addressee = c.uid)
    ) f on true
    group by f.friend, c.kind
  ) x
  where not public.notif_off(x.uid, x.kind)
    and not exists (select 1 from public.notifications o where o.user_id = x.uid and o.kind = x.kind and o.ref->>'day' = today and o.created_at > now() - interval '20 hours');
  get diagnostics k = row_count; n := n + k;

  -- the person celebrating
  insert into public.notifications (user_id, actor, kind, ref)
  select c.uid, null, c.kind || '_me', jsonb_build_object('label', c.label, 'day', today) from _cel c
  where not public.notif_off(c.uid, c.kind || '_me')
    and not exists (select 1 from public.notifications o where o.user_id = c.uid and o.kind = c.kind || '_me' and o.ref->>'day' = today and o.created_at > now() - interval '20 hours');
  get diagnostics k = row_count; n := n + k;
  return n;
end $$;
revoke execute on function private.daily_celebrations() from public, anon, authenticated;

-- the push sender asks whether this push may go out now (category muted, quiet hours)
create or replace function public.push_allowed(p_user uuid, p_kind text) returns boolean language plpgsql stable security definer set search_path = '' as $$
declare pr jsonb; q jsonb; h int; f int; t int;
begin
  select notif into pr from public.profiles where id = p_user;
  if pr is null then return true; end if;
  if public.notif_category(p_kind) <> 'system' and (pr->'off'->>public.notif_category(p_kind)) = 'true' then return false; end if;
  q := pr->'quiet';
  if q is null or (q->>'on') is distinct from 'true' then return true; end if;
  f := coalesce(nullif(q->>'from', '')::int, 23); t := coalesce(nullif(q->>'to', '')::int, 8);
  begin
    h := extract(hour from now() at time zone coalesce(nullif(q->>'tz', ''), 'Asia/Tbilisi'))::int;
  exception when others then
    h := extract(hour from now() at time zone 'Asia/Tbilisi')::int;
  end;
  if f = t then return true; end if;
  if f < t then return not (h >= f and h < t); end if;
  return not (h >= f or h < t);
end $$;
revoke execute on function public.push_allowed(uuid, text) from public, anon, authenticated;
grant execute on function public.push_allowed(uuid, text) to service_role;

-- ============ "seen" in chats ============
-- members see each other's seen_at, which stays empty for people who hide read receipts;
-- the raw last_read_at is only readable by its owner (for unread counts)
alter table public.conversation_members add column seen_at timestamptz;
create or replace function public.cm_seen() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if coalesce((select privacy->>'read' from public.profiles where id = new.user_id), 'true') = 'false' then new.seen_at := null;
  else new.seen_at := new.last_read_at;
  end if;
  return new;
end $$;
create trigger cm_seen before insert or update of last_read_at on public.conversation_members for each row execute function public.cm_seen();
update public.conversation_members cm set seen_at = cm.last_read_at
  where coalesce((select privacy->>'read' from public.profiles where id = cm.user_id), 'true') <> 'false';

create or replace function public.trg_read_privacy() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if (new.privacy->>'read') = 'false' and (old.privacy->>'read') is distinct from 'false' then
    update public.conversation_members set seen_at = null where user_id = new.id;
  end if;
  return null;
end $$;
create trigger profiles_read_privacy after update of privacy on public.profiles for each row execute function public.trg_read_privacy();

create or replace function public.my_last_read(p_conv bigint) returns timestamptz language sql stable security definer set search_path = '' as $$
  select last_read_at from public.conversation_members where conv_id = p_conv and user_id = auth.uid();
$$;

create or replace function public.my_conversations()
 returns table(conv_id bigint, is_group boolean, title text, last_message_at timestamptz, last_body text, last_kind text, last_sender uuid, unread integer, members uuid[])
 language sql stable set search_path = '' as $$
  select c.id, c.is_group, c.title, c.last_message_at, lm.body, lm.kind, lm.sender,
    (select count(*)::int from public.messages m where m.conv_id = c.id and m.created_at > public.my_last_read(c.id) and m.sender is distinct from auth.uid()),
    (select array_agg(x.user_id) from public.conversation_members x where x.conv_id = c.id and x.user_id <> auth.uid())
  from public.conversation_members cm
  join public.conversations c on c.id = cm.conv_id
  left join lateral (select m.body, m.kind, m.sender from public.messages m where m.conv_id = c.id order by m.created_at desc limit 1) lm on true
  where cm.user_id = auth.uid()
  order by c.last_message_at desc
  limit 100;
$$;

revoke select on public.conversation_members from anon, authenticated;
grant select (conv_id, user_id, joined_at, seen_at) on public.conversation_members to authenticated;

-- read marks are pushed live to the other members
alter publication supabase_realtime add table public.conversation_members;

-- ============ lock down ============
revoke execute on function public.posts_edited(), public.posts_repost(), public.trg_repost_notify(), public.comments_before(),
  public.trg_comment(), public.trg_comment_like(), public.cm_seen(), public.trg_read_privacy() from public, anon, authenticated;
revoke execute on function public.repost_stats(bigint[]), public.notif_category(text), public.my_last_read(bigint), public.my_conversations() from public, anon;
grant execute on function public.repost_stats(bigint[]), public.notif_category(text), public.my_last_read(bigint), public.my_conversations() to authenticated;
