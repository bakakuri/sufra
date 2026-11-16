-- Groups and channels as world-class ones work.
--
-- Channels and business pages: co-admins (an admin edits the page and writes as it, an editor only writes as it);
-- a cover, contacts, opening hours and the main button for a business; a pinned post; followers choose how much they
-- are told (every post, only the pinned highlights, nothing), and a new post reaches those who chose every post;
-- reviews with stars for a business; numbers for the page's admins (followers over a month, reach).
--
-- Groups: a cover; a pinned announcement; questions asked of who wants to join (the answers go with the request);
-- topics for posts; words that send a post to the admins first; a member muted for a while; the group's own chat
-- (made on first use, its members kept in step with the group's); the admins' log of what was done; numbers for the
-- admins and the most active members of the month.

-- ---------- channels and pages ----------
alter table public.pages
  add column if not exists cover_url text check (cover_url is null or cover_url ~ '^https://'),
  add column if not exists address text not null default '' check (char_length(address) <= 160),
  add column if not exists phone text not null default '' check (char_length(phone) <= 30),
  add column if not exists website text not null default '' check (website = '' or website ~ '^https?://'),
  add column if not exists hours jsonb not null default '{}'::jsonb check (jsonb_typeof(hours) = 'object'),
  add column if not exists action text not null default 'msg' check (action in ('msg', 'call', 'site', 'none')),
  add column if not exists pinned_post bigint references public.posts(id) on delete set null,
  add column if not exists rating numeric(2,1),
  add column if not exists reviews integer not null default 0;

create table if not exists public.page_admins (
  page_id bigint not null references public.pages(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'editor' check (role in ('admin', 'editor')),
  added_by uuid default auth.uid() references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (page_id, user_id)
);
create index if not exists page_admins_user_idx on public.page_admins (user_id);

-- 'owner', 'admin', 'editor' or null: what the signed-in person is on the page
create or replace function public.page_role(p bigint) returns text
language sql stable security definer set search_path = '' as $f$
  select case when exists (select 1 from public.pages where id = p and owner = auth.uid()) then 'owner'
              else (select role from public.page_admins where page_id = p and user_id = auth.uid()) end
$f$;

-- writing as the page: its owner, its admins and its editors
create or replace function public.owns_page(p bigint) returns boolean
language sql stable security definer set search_path = '' as $f$
  select public.page_role(p) is not null
$f$;

drop policy if exists "owner edits page" on public.pages;
create policy "owner edits page" on public.pages for update to authenticated
  using (public.page_role(id) in ('owner', 'admin')) with check (public.page_role(id) in ('owner', 'admin'));
grant update (cover_url, address, phone, website, hours, action, pinned_post) on public.pages to authenticated;

alter table public.page_admins enable row level security;
drop policy if exists "page admins seen by the page's people" on public.page_admins;
create policy "page admins seen by the page's people" on public.page_admins for select to authenticated using (public.owns_page(page_id));
drop policy if exists "page owner adds admins" on public.page_admins;
create policy "page owner adds admins" on public.page_admins for insert to authenticated with check (
  exists (select 1 from public.pages p where p.id = page_id and p.owner = (select auth.uid())) and user_id <> (select auth.uid())
  and not public.is_blocked(user_id, (select auth.uid())));
drop policy if exists "page owner changes admins" on public.page_admins;
create policy "page owner changes admins" on public.page_admins for update to authenticated
  using (exists (select 1 from public.pages p where p.id = page_id and p.owner = (select auth.uid())))
  with check (exists (select 1 from public.pages p where p.id = page_id and p.owner = (select auth.uid())));
drop policy if exists "page admin removed or leaves" on public.page_admins;
create policy "page admin removed or leaves" on public.page_admins for delete to authenticated using (
  user_id = (select auth.uid()) or exists (select 1 from public.pages p where p.id = page_id and p.owner = (select auth.uid())));
revoke all on public.page_admins from anon;
grant select, insert, delete on public.page_admins to authenticated;
grant update (role) on public.page_admins to authenticated;

-- how much a follower is told: every post, only the pinned ones, nothing
alter table public.page_follows add column if not exists notify text not null default 'all' check (notify in ('all', 'highlights', 'off'));
drop policy if exists "follower sets how much" on public.page_follows;
create policy "follower sets how much" on public.page_follows for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
revoke update on public.page_follows from authenticated;
grant update (notify) on public.page_follows to authenticated;

-- the page's notifications have their own switch in the settings
create or replace function public.notif_category(k text) returns text
language sql immutable set search_path = '' as $f$
  select case
    when k in ('react', 'comment_like', 'repost', 'msg_react', 'story_react', 'grade_plus', 'recipe_cook') then 'reactions'
    when k in ('comment', 'comment_reply', 'mention', 'story_mention') then 'comments'
    when k in ('friend_req', 'friend_ok', 'kin_req', 'kin_ok') then 'friends'
    when k = 'message' then 'messages'
    when k in ('nameday', 'birthday', 'nameday_me', 'birthday_me') then 'celebrations'
    when k = 'live_start' then 'live'
    when k in ('room_invite', 'jk_invite') then 'rooms'
    when k = 'help_new' then 'help'
    when k in ('match', 'super') then 'dating'
    when k = 'gift' then 'gifts'
    when k = 'promo' then 'promo'
    when k in ('lesson_soon', 'deadline_soon', 'study_deadline') then 'study'
    when k like 'bet\_%' then 'sport'
    when k like 'ride\_%' or k like 'job\_%' then 'deals'
    when k like 'group\_%' then 'groups'
    when k like 'page\_%' then 'pages'
    when k like 'event\_%' or k like 'album\_%' then 'events'
    else 'system' end;
$f$;

-- a new post of a page reaches the followers who chose every post (2000 at most at once)
create or replace function private.page_post_notify() returns trigger language plpgsql security definer set search_path = '' as $f$
declare pg record; u uuid;
begin
  if new.page_id is null or new.draft or new.hidden or (new.publish_at is not null and new.publish_at > now()) then return null; end if;
  select id, name into pg from public.pages where id = new.page_id;
  for u in select user_id from public.page_follows where page_id = new.page_id and notify = 'all' order by created_at limit 2000 loop
    perform public.notify(u, new.author, 'page_post', jsonb_build_object('page', pg.id, 'name', left(pg.name, 80), 'post', new.id));
  end loop;
  return null;
end $f$;
drop trigger if exists posts_page_notify on public.posts;
create trigger posts_page_notify after insert on public.posts for each row execute function private.page_post_notify();

-- a post pinned on a page reaches every follower who has not turned the page off
create or replace function private.page_pin_notify() returns trigger language plpgsql security definer set search_path = '' as $f$
declare u uuid;
begin
  if new.pinned_post is null or new.pinned_post is not distinct from old.pinned_post then return null; end if;
  for u in select user_id from public.page_follows where page_id = new.id and notify <> 'off' order by created_at limit 2000 loop
    perform public.notify(u, auth.uid(), 'page_pin', jsonb_build_object('page', new.id, 'name', left(new.name, 80), 'post', new.pinned_post));
  end loop;
  return null;
end $f$;
drop trigger if exists pages_pin_notify on public.pages;
create trigger pages_pin_notify after update of pinned_post on public.pages for each row execute function private.page_pin_notify();

-- reviews of a business, with stars; the page keeps its average and count
create table if not exists public.page_reviews (
  id bigint generated always as identity primary key,
  page_id bigint not null references public.pages(id) on delete cascade,
  author uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  body text not null default '' check (char_length(body) <= 1000),
  created_at timestamptz not null default now(),
  updated_at timestamptz,
  unique (page_id, author)
);
create index if not exists page_reviews_page_idx on public.page_reviews (page_id, created_at desc);
alter table public.page_reviews enable row level security;
drop policy if exists "page reviews visible" on public.page_reviews;
create policy "page reviews visible" on public.page_reviews for select to authenticated using (not public.is_blocked(author, (select auth.uid())));
drop policy if exists "a business reviewed" on public.page_reviews;
create policy "a business reviewed" on public.page_reviews for insert to authenticated with check (
  author = (select auth.uid()) and public.can_post() and not public.owns_page(page_id)
  and exists (select 1 from public.pages p where p.id = page_id and p.kind = 'business'));
drop policy if exists "own review changed" on public.page_reviews;
create policy "own review changed" on public.page_reviews for update to authenticated using (author = (select auth.uid())) with check (author = (select auth.uid()));
drop policy if exists "own review removed" on public.page_reviews;
create policy "own review removed" on public.page_reviews for delete to authenticated using (author = (select auth.uid()) or public.is_staff());
revoke all on public.page_reviews from anon;
grant select, insert, delete on public.page_reviews to authenticated;
grant update (rating, body) on public.page_reviews to authenticated;

create or replace function private.page_review_sum() returns trigger language plpgsql security definer set search_path = '' as $f$
declare p bigint := coalesce(new.page_id, old.page_id);
begin
  update public.pages set
    rating = (select round(avg(rating)::numeric, 1) from public.page_reviews where page_id = p),
    reviews = (select count(*) from public.page_reviews where page_id = p)
  where id = p;
  return null;
end $f$;
drop trigger if exists page_reviews_sum on public.page_reviews;
create trigger page_reviews_sum after insert or update or delete on public.page_reviews for each row execute function private.page_review_sum();
create or replace function private.page_review_stamp() returns trigger language plpgsql set search_path = '' as $f$
begin new.updated_at := now(); return new; end $f$;
drop trigger if exists page_reviews_stamp on public.page_reviews;
create trigger page_reviews_stamp before update on public.page_reviews for each row execute function private.page_review_stamp();

-- the page's numbers, for its owner and admins
create or replace function public.page_stats(p bigint) returns jsonb
language plpgsql stable security definer set search_path = '' as $f$
declare r jsonb;
begin
  if coalesce(public.page_role(p), '') not in ('owner', 'admin') and not public.is_staff() then raise exception 'not_allowed'; end if;
  select jsonb_build_object(
    'followers', (select count(*) from public.page_follows where page_id = p),
    'new7', (select count(*) from public.page_follows where page_id = p and created_at > now() - interval '7 days'),
    'new30', (select count(*) from public.page_follows where page_id = p and created_at > now() - interval '30 days'),
    'posts30', (select count(*) from public.posts where page_id = p and created_at > now() - interval '30 days' and not draft),
    'reactions30', (select count(*) from public.reactions x join public.posts q on q.id = x.post_id where q.page_id = p and x.created_at > now() - interval '30 days'),
    'comments30', (select count(*) from public.comments x join public.posts q on q.id = x.post_id where q.page_id = p and x.created_at > now() - interval '30 days'),
    'daily', coalesce((select jsonb_agg(jsonb_build_object('d', d::date, 'n', n) order by d) from (
        select gs as d, (select count(*) from public.page_follows f where f.page_id = p and f.created_at >= gs and f.created_at < gs + interval '1 day') as n
        from generate_series(date_trunc('day', now()) - interval '29 days', date_trunc('day', now()), interval '1 day') gs) t), '[]'::jsonb),
    'top', coalesce((select jsonb_agg(t) from (
        select q.id, left(q.body, 80) as body,
               (select count(*) from public.reactions x where x.post_id = q.id) as reactions,
               (select count(*) from public.comments x where x.post_id = q.id) as comments
        from public.posts q where q.page_id = p and q.created_at > now() - interval '30 days' and not q.draft
        order by 3 desc, 4 desc limit 3) t), '[]'::jsonb)
  ) into r;
  return r;
end $f$;

-- ---------- groups ----------
alter table public.groups
  add column if not exists cover_url text check (cover_url is null or cover_url ~ '^https://'),
  add column if not exists pinned_post bigint references public.posts(id) on delete set null,
  add column if not exists questions jsonb not null default '[]'::jsonb check (jsonb_typeof(questions) = 'array' and jsonb_array_length(questions) <= 3),
  add column if not exists topics text[] not null default '{}' check (cardinality(topics) <= 12),
  add column if not exists blocked_words text[] not null default '{}' check (cardinality(blocked_words) <= 50),
  add column if not exists conv_id bigint references public.conversations(id) on delete set null;

-- the admins, not only the owner, keep the group's page and settings
drop policy if exists "owner edits group" on public.groups;
create policy "owner edits group" on public.groups for update to authenticated using (public.is_group_admin(id)) with check (public.is_group_admin(id));
grant update (cover_url, pinned_post, questions, topics, blocked_words) on public.groups to authenticated;

alter table public.posts add column if not exists topic text check (topic is null or char_length(topic) between 1 and 24);
grant insert (topic), update (topic) on public.posts to authenticated;

alter table public.group_requests add column if not exists answers jsonb not null default '[]'::jsonb check (jsonb_typeof(answers) = 'array' and jsonb_array_length(answers) <= 3);
grant insert (answers), update (answers) on public.group_requests to authenticated;

-- who is muted in a group, and till when; kept apart from the membership, so leaving and joining again does not lift it
create table if not exists public.group_mutes (
  group_id bigint not null references public.groups(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  until timestamptz not null,
  by uuid default auth.uid() references public.profiles(id) on delete set null,
  primary key (group_id, user_id)
);
alter table public.group_mutes enable row level security;
drop policy if exists "group mutes for its admins and the muted" on public.group_mutes;
create policy "group mutes for its admins and the muted" on public.group_mutes for select to authenticated
  using (user_id = (select auth.uid()) or public.is_group_admin(group_id));
revoke all on public.group_mutes from anon, authenticated;
grant select on public.group_mutes to authenticated;

create or replace function private.muted_in(g bigint, u uuid) returns boolean language sql stable security definer set search_path = '' as $f$
  select exists (select 1 from public.group_mutes where group_id = g and user_id = u and until > now())
$f$;

-- a group's post: pending when the group checks posts or when it holds a word the admins keep out; a muted member
-- does not post until their time is over
create or replace function public.posts_group_gate() returns trigger
language plpgsql security definer set search_path = '' as $f$
declare g record; m record; w text; b text;
begin
  new.pending := false;
  if new.group_id is null then return new; end if;
  select owner, post_approval, blocked_words into g from public.groups where id = new.group_id;
  select role into m from public.group_members where group_id = new.group_id and user_id = new.author;
  if new.author <> g.owner and private.muted_in(new.group_id, new.author) then raise exception 'muted'; end if;
  new.pending := coalesce(g.post_approval, false) and new.author <> g.owner and coalesce(m.role, '') <> 'admin';
  if not new.pending and new.author <> g.owner and coalesce(m.role, '') <> 'admin' then
    b := lower(coalesce(new.body, ''));
    foreach w in array coalesce(g.blocked_words, '{}') loop
      if length(trim(w)) > 0 and position(lower(trim(w)) in b) > 0 then new.pending := true; exit; end if;
    end loop;
  end if;
  return new;
end $f$;

-- a muted member does not comment in the group either
create or replace function private.comment_group_mute() returns trigger language plpgsql security definer set search_path = '' as $f$
declare gid bigint;
begin
  select group_id into gid from public.posts where id = new.post_id;
  if gid is not null and private.muted_in(gid, new.author) then
    raise exception 'muted';
  end if;
  return new;
end $f$;
drop trigger if exists comments_group_mute on public.comments;
create trigger comments_group_mute before insert on public.comments for each row execute function private.comment_group_mute();

-- what the admins did, for the admins
create table if not exists public.group_log (
  id bigint generated always as identity primary key,
  group_id bigint not null references public.groups(id) on delete cascade,
  actor uuid references public.profiles(id) on delete set null,
  action text not null,
  target uuid references public.profiles(id) on delete set null,
  post_id bigint,
  note text not null default '',
  created_at timestamptz not null default now()
);
create index if not exists group_log_group_idx on public.group_log (group_id, created_at desc);
alter table public.group_log enable row level security;
drop policy if exists "group log for its admins" on public.group_log;
create policy "group log for its admins" on public.group_log for select to authenticated using (public.is_group_admin(group_id));
revoke all on public.group_log from anon, authenticated;
grant select on public.group_log to authenticated;

-- (nothing is written while the group itself is being deleted)
create or replace function private.glog(g bigint, a text, t uuid default null, p bigint default null, n text default '') returns void
language sql security definer set search_path = '' as $f$
  insert into public.group_log (group_id, actor, action, target, post_id, note)
  select g, auth.uid(), a, t, p, left(coalesce(n, ''), 200) where exists (select 1 from public.groups where id = g);
$f$;

create or replace function private.group_log_requests() returns trigger language plpgsql security definer set search_path = '' as $f$
begin
  if old.status = 'pending' and new.status in ('accepted', 'declined') then
    perform private.glog(new.group_id, case when new.status = 'accepted' then 'accept' else 'decline' end, new.user_id);
  end if;
  return null;
end $f$;
drop trigger if exists group_requests_log on public.group_requests;
create trigger group_requests_log after update of status on public.group_requests for each row execute function private.group_log_requests();

create or replace function private.group_log_members() returns trigger language plpgsql security definer set search_path = '' as $f$
begin
  if tg_op = 'DELETE' then
    if auth.uid() is not null and auth.uid() <> old.user_id then perform private.glog(old.group_id, 'remove', old.user_id); end if;
    return null;
  end if;
  if new.role is distinct from old.role then perform private.glog(new.group_id, 'role', new.user_id, null, new.role); end if;
  return null;
end $f$;
drop trigger if exists group_members_log on public.group_members;
create trigger group_members_log after update of role or delete on public.group_members for each row execute function private.group_log_members();

create or replace function private.group_log_posts() returns trigger language plpgsql security definer set search_path = '' as $f$
begin
  if tg_op = 'DELETE' then
    if old.group_id is not null and auth.uid() is not null and auth.uid() <> old.author then
      perform private.glog(old.group_id, case when old.pending then 'decline_post' else 'delete_post' end, old.author, old.id, left(old.body, 80));
    end if;
    return null;
  end if;
  if new.group_id is not null and old.pending and not new.pending then perform private.glog(new.group_id, 'approve', new.author, new.id, left(new.body, 80)); end if;
  return null;
end $f$;
drop trigger if exists posts_group_log on public.posts;
create trigger posts_group_log after update of pending or delete on public.posts for each row execute function private.group_log_posts();

create or replace function private.group_log_settings() returns trigger language plpgsql security definer set search_path = '' as $f$
begin
  if new.pinned_post is distinct from old.pinned_post then
    perform private.glog(new.id, case when new.pinned_post is null then 'unpin' else 'pin' end, null, coalesce(new.pinned_post, old.pinned_post));
  end if;
  if (new.rules, new.questions, new.topics, new.blocked_words, new.is_private, new.join_mode, new.post_approval, new.name, new.description)
     is distinct from (old.rules, old.questions, old.topics, old.blocked_words, old.is_private, old.join_mode, old.post_approval, old.name, old.description) then
    perform private.glog(new.id, 'settings');
  end if;
  -- the group's chat carries its name
  if new.name is distinct from old.name and new.conv_id is not null then
    update public.conversations set title = left(new.name, 80) where id = new.conv_id;
  end if;
  return null;
end $f$;
drop trigger if exists groups_settings_log on public.groups;
create trigger groups_settings_log after update on public.groups for each row execute function private.group_log_settings();

-- muting a member for a while (minutes; 0 lifts it)
create or replace function public.group_mute(p_group bigint, p_user uuid, p_minutes integer) returns void
language plpgsql security definer set search_path = '' as $f$
begin
  if not public.is_group_admin(p_group) then raise exception 'not_allowed'; end if;
  if exists (select 1 from public.groups where id = p_group and owner = p_user)
     or exists (select 1 from public.group_members where group_id = p_group and user_id = p_user and role = 'admin') then
    raise exception 'not_allowed';
  end if;
  if p_minutes > 0 then
    if not exists (select 1 from public.group_members where group_id = p_group and user_id = p_user) then raise exception 'not_found'; end if;
    insert into public.group_mutes (group_id, user_id, until) values (p_group, p_user, now() + make_interval(mins => least(p_minutes, 60 * 24 * 30)))
    on conflict (group_id, user_id) do update set until = excluded.until, by = auth.uid();
  else
    delete from public.group_mutes where group_id = p_group and user_id = p_user;
  end if;
  perform private.glog(p_group, case when p_minutes > 0 then 'mute' else 'unmute' end, p_user, null, case when p_minutes > 0 then p_minutes::text else '' end);
end $f$;

-- the group's own chat: made the first time a member opens it, with all the members; then kept in step
create or replace function public.group_chat(p_group bigint) returns bigint
language plpgsql security definer set search_path = '' as $f$
declare g record; c bigint;
begin
  if not public.is_group_member(p_group) and not exists (select 1 from public.groups where id = p_group and owner = auth.uid()) then
    raise exception 'not_allowed';
  end if;
  select id, owner, name, conv_id into g from public.groups where id = p_group for update;
  c := g.conv_id;
  if c is null then
    insert into public.conversations (is_group, title, created_by) values (true, left(g.name, 80), g.owner) returning id into c;
    update public.groups set conv_id = c where id = p_group;
    insert into public.conversation_members (conv_id, user_id) values (c, g.owner) on conflict do nothing;
    insert into public.conversation_members (conv_id, user_id) select c, user_id from public.group_members where group_id = p_group on conflict do nothing;
    insert into public.messages (conv_id, sender, body, kind) values (c, auth.uid(), 'ჯგუფის ჩატი შეიქმნა', 'system');
  else
    insert into public.conversation_members (conv_id, user_id) values (c, auth.uid()) on conflict do nothing;
  end if;
  return c;
end $f$;

create or replace function private.group_chat_members() returns trigger language plpgsql security definer set search_path = '' as $f$
declare c bigint;
begin
  select conv_id into c from public.groups where id = coalesce(new.group_id, old.group_id);
  if c is null then return null; end if;
  if tg_op = 'INSERT' then
    insert into public.conversation_members (conv_id, user_id) values (c, new.user_id) on conflict do nothing;
  else
    delete from public.conversation_members where conv_id = c and user_id = old.user_id;
  end if;
  return null;
end $f$;
drop trigger if exists group_members_chat on public.group_members;
create trigger group_members_chat after insert or delete on public.group_members for each row execute function private.group_chat_members();

-- a group deleted takes its chat with it
create or replace function private.group_chat_gone() returns trigger language plpgsql security definer set search_path = '' as $f$
begin
  if old.conv_id is not null then delete from public.conversations where id = old.conv_id; end if;
  return old;
end $f$;
drop trigger if exists groups_chat_gone on public.groups;
create trigger groups_chat_gone after delete on public.groups for each row execute function private.group_chat_gone();

-- only a post of the group (or of the page) can be pinned on it
create or replace function private.pin_own_post() returns trigger language plpgsql security definer set search_path = '' as $f$
begin
  if new.pinned_post is not null and new.pinned_post is distinct from old.pinned_post then
    if tg_table_name = 'groups' and not exists (select 1 from public.posts where id = new.pinned_post and group_id = new.id and not pending) then raise exception 'not_allowed'; end if;
    if tg_table_name = 'pages' and not exists (select 1 from public.posts where id = new.pinned_post and page_id = new.id) then raise exception 'not_allowed'; end if;
  end if;
  return new;
end $f$;
drop trigger if exists groups_pin_own on public.groups;
create trigger groups_pin_own before update of pinned_post on public.groups for each row execute function private.pin_own_post();
drop trigger if exists pages_pin_own on public.pages;
create trigger pages_pin_own before update of pinned_post on public.pages for each row execute function private.pin_own_post();

-- the group's numbers, for its admins
create or replace function public.group_stats(p_group bigint) returns jsonb
language plpgsql stable security definer set search_path = '' as $f$
declare r jsonb;
begin
  if not public.is_group_admin(p_group) and not public.is_staff() then raise exception 'not_allowed'; end if;
  select jsonb_build_object(
    'members', (select count(*) from public.group_members where group_id = p_group),
    'new7', (select count(*) from public.group_members where group_id = p_group and created_at > now() - interval '7 days'),
    'new30', (select count(*) from public.group_members where group_id = p_group and created_at > now() - interval '30 days'),
    'posts30', (select count(*) from public.posts where group_id = p_group and created_at > now() - interval '30 days' and not pending),
    'comments30', (select count(*) from public.comments x join public.posts q on q.id = x.post_id where q.group_id = p_group and x.created_at > now() - interval '30 days'),
    'active30', (select count(distinct a) from (
        select author a from public.posts where group_id = p_group and created_at > now() - interval '30 days'
        union all select x.author from public.comments x join public.posts q on q.id = x.post_id where q.group_id = p_group and x.created_at > now() - interval '30 days') t),
    'daily', coalesce((select jsonb_agg(jsonb_build_object('d', d::date, 'n', n) order by d) from (
        select gs as d, (select count(*) from public.group_members m where m.group_id = p_group and m.created_at >= gs and m.created_at < gs + interval '1 day') as n
        from generate_series(date_trunc('day', now()) - interval '29 days', date_trunc('day', now()), interval '1 day') gs) t), '[]'::jsonb)
  ) into r;
  return r;
end $f$;

-- the most active members of the last 30 days (posts count twice), up to five, with their counts
create or replace function public.group_stars(p_group bigint) returns table (user_id uuid, posts integer, comments integer)
language sql stable security definer set search_path = '' as $f$
  with a as (
    select author u, 2 as w, 1 as p, 0 as c from public.posts where group_id = p_group and not pending and created_at > now() - interval '30 days'
    union all
    select x.author, 1, 0, 1 from public.comments x join public.posts q on q.id = x.post_id where q.group_id = p_group and x.created_at > now() - interval '30 days')
  select u, sum(p)::integer, sum(c)::integer from a
  where public.group_visible(p_group) and exists (select 1 from public.group_members m where m.group_id = p_group and m.user_id = a.u)
  group by u having sum(w) >= 3 order by sum(w) desc limit 5
$f$;

revoke execute on function public.page_role(bigint), public.page_stats(bigint), public.group_mute(bigint, uuid, integer), public.group_chat(bigint),
  public.group_stats(bigint), public.group_stars(bigint) from public, anon;
grant execute on function public.page_role(bigint), public.page_stats(bigint), public.group_mute(bigint, uuid, integer), public.group_chat(bigint),
  public.group_stats(bigint), public.group_stars(bigint) to authenticated;
revoke execute on function private.glog(bigint, text, uuid, bigint, text), private.page_post_notify(), private.page_pin_notify(), private.page_review_sum(),
  private.comment_group_mute(), private.group_log_requests(), private.group_log_members(), private.group_log_posts(), private.group_log_settings(),
  private.group_chat_members(), private.page_review_stamp(), private.group_chat_gone(), private.pin_own_post(), private.muted_in(bigint, uuid) from public, anon, authenticated;
