-- ============ party planning ============
alter table public.events add column reminded boolean not null default false;
revoke update on public.events from authenticated;
grant update (title, starts_at, place, description, tamada, hue) on public.events to authenticated;

-- the host and everyone who said yes or maybe
create or replace function public.event_party(e bigint, u uuid) returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.events where id = e and host = u)
      or exists (select 1 from public.event_rsvps where event_id = e and user_id = u and status in ('yes', 'maybe'));
$$;
-- the host and the tamada run the toast list
create or replace function public.event_lead(e bigint) returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.events where id = e and (host = auth.uid() or tamada = auth.uid()));
$$;

create table public.event_toasts (
  id bigint generated always as identity primary key,
  event_id bigint not null references public.events(id) on delete cascade,
  pos int not null default 0,
  title text not null check (char_length(title) between 1 and 120),
  toast_id bigint references public.toasts(id) on delete set null,
  done boolean not null default false,
  created_at timestamptz not null default now()
);
create index event_toasts_event_idx on public.event_toasts (event_id, pos);
alter table public.event_toasts enable row level security;
revoke all on public.event_toasts from anon;
create policy "event toasts visible" on public.event_toasts for select to authenticated using (exists (select 1 from public.events e where e.id = event_id));
create policy "lead adds toast" on public.event_toasts for insert to authenticated with check (public.event_lead(event_id));
create policy "lead edits toast" on public.event_toasts for update to authenticated using (public.event_lead(event_id)) with check (public.event_lead(event_id));
create policy "lead removes toast" on public.event_toasts for delete to authenticated using (public.event_lead(event_id));

-- shared costs, split equally between the host and the guests who said yes; only the party sees them
create table public.event_costs (
  id bigint generated always as identity primary key,
  event_id bigint not null references public.events(id) on delete cascade,
  paid_by uuid not null references public.profiles(id) on delete cascade,
  amount numeric(10,2) not null check (amount > 0 and amount <= 100000),
  what text not null check (char_length(what) between 1 and 80),
  added_by uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);
create index event_costs_event_idx on public.event_costs (event_id);
alter table public.event_costs enable row level security;
revoke all on public.event_costs from anon;
revoke update on public.event_costs from authenticated;
create policy "party sees costs" on public.event_costs for select to authenticated using (public.event_party(event_id, (select auth.uid())));
create policy "party adds cost" on public.event_costs for insert to authenticated with check (added_by = (select auth.uid()) and public.event_party(event_id, (select auth.uid())) and public.event_party(event_id, paid_by));
create policy "remove cost" on public.event_costs for delete to authenticated using (added_by = (select auth.uid()) or exists (select 1 from public.events e where e.id = event_id and e.host = (select auth.uid())));

create table public.event_payments (
  id bigint generated always as identity primary key,
  event_id bigint not null references public.events(id) on delete cascade,
  from_user uuid not null references public.profiles(id) on delete cascade,
  to_user uuid not null references public.profiles(id) on delete cascade,
  amount numeric(10,2) not null check (amount > 0 and amount <= 100000),
  added_by uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  check (from_user <> to_user)
);
create index event_payments_event_idx on public.event_payments (event_id);
alter table public.event_payments enable row level security;
revoke all on public.event_payments from anon;
revoke update on public.event_payments from authenticated;
create policy "party sees payments" on public.event_payments for select to authenticated using (public.event_party(event_id, (select auth.uid())));
create policy "record payment" on public.event_payments for insert to authenticated with check (added_by = (select auth.uid()) and (from_user = (select auth.uid()) or to_user = (select auth.uid()))
  and public.event_party(event_id, from_user) and public.event_party(event_id, to_user));
create policy "remove payment" on public.event_payments for delete to authenticated using (added_by = (select auth.uid()));

-- invite friends: one notification per person and event
create or replace function public.invite_to_event(p_event bigint, p_users uuid[]) returns int language plpgsql security definer set search_path = '' as $$
declare e record; n int := 0; u uuid;
begin
  select id, host, title, starts_at, group_id into e from public.events where id = p_event;
  if e.id is null then raise exception 'not_found'; end if;
  if not public.can_post() or not public.event_party(p_event, auth.uid()) then raise exception 'not_allowed'; end if;
  foreach u in array coalesce(p_users[1:50], '{}') loop
    continue when u = auth.uid() or not public.are_friends(auth.uid(), u) or not public.group_open_to(e.group_id, u);
    continue when exists (select 1 from public.notifications where user_id = u and kind = 'event_invite' and ref->>'event' = p_event::text);
    perform public.notify(u, auth.uid(), 'event_invite', jsonb_build_object('event', p_event, 'title', left(e.title, 80), 'at', e.starts_at));
    n := n + 1;
  end loop;
  return n;
end $$;

-- a reminder three hours before, to the host and everyone coming
create or replace function private.event_reminders() returns int language plpgsql security definer set search_path = '' as $$
declare n int;
begin
  with due as (
    update public.events set reminded = true
    where not reminded and starts_at > now() and starts_at <= now() + interval '3 hours'
    returning id, host, title, starts_at
  )
  insert into public.notifications (user_id, actor, kind, ref)
  select x.uid, null, 'event_soon', jsonb_build_object('event', d.id, 'title', left(d.title, 80), 'at', d.starts_at)
  from due d
  cross join lateral (select d.host as uid union select r.user_id from public.event_rsvps r where r.event_id = d.id and r.status = 'yes') x
  where not public.notif_off(x.uid, 'event_soon');
  get diagnostics n = row_count;
  return n;
end $$;
revoke execute on function private.event_reminders() from public, anon, authenticated;
select cron.schedule('sufra-reminders', '*/10 * * * *', 'select private.event_reminders()');

-- ============ shared albums ============
create table public.albums (
  id bigint generated always as identity primary key,
  owner uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 80),
  about text check (char_length(about) <= 500),
  event_id bigint references public.events(id) on delete set null,
  audience text not null default 'friends' check (audience in ('friends', 'members', 'all')),
  cover_url text check (cover_url is null or cover_url ~ '^https://'),
  photos int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index albums_owner_idx on public.albums (owner, updated_at desc);
create index albums_event_idx on public.albums (event_id) where event_id is not null;
create table public.album_members (
  album_id bigint not null references public.albums(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  added_by uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (album_id, user_id)
);
create index album_members_user_idx on public.album_members (user_id);
create table public.album_photos (
  id bigint generated always as identity primary key,
  album_id bigint not null references public.albums(id) on delete cascade,
  added_by uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  url text not null check (url ~ '^https://'),
  md text check (md is null or md ~ '^https://'),
  sm text check (sm is null or sm ~ '^https://'),
  w int, h int,
  caption text check (char_length(caption) <= 200),
  created_at timestamptz not null default now()
);
create index album_photos_album_idx on public.album_photos (album_id, created_at);

create or replace function public.album_can_add(a bigint, u uuid) returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.albums al where al.id = a and (al.owner = u
    or exists (select 1 from public.album_members m where m.album_id = a and m.user_id = u)
    or (al.event_id is not null and public.event_party(al.event_id, u))));
$$;
create or replace function public.album_visible(a bigint) returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.albums al where al.id = a and not public.is_blocked(al.owner, auth.uid()) and (
    al.owner = auth.uid() or al.audience = 'all'
    or (al.audience = 'friends' and public.are_friends(al.owner, auth.uid()))
    or public.album_can_add(a, auth.uid())));
$$;

alter table public.albums enable row level security;
alter table public.album_members enable row level security;
alter table public.album_photos enable row level security;
revoke all on public.albums, public.album_members, public.album_photos from anon;
revoke update on public.albums, public.album_members, public.album_photos from authenticated;
grant update (title, about, audience, cover_url) on public.albums to authenticated;
grant update (caption) on public.album_photos to authenticated;

create policy "albums visible" on public.albums for select to authenticated using (public.album_visible(id));
create policy "create album" on public.albums for insert to authenticated with check (owner = (select auth.uid()) and public.can_post() and (event_id is null or public.event_party(event_id, (select auth.uid()))));
create policy "owner edits album" on public.albums for update to authenticated using (owner = (select auth.uid())) with check (owner = (select auth.uid()));
create policy "owner or staff removes album" on public.albums for delete to authenticated using (owner = (select auth.uid()) or public.is_staff());

create policy "album members visible" on public.album_members for select to authenticated using (public.album_visible(album_id));
create policy "owner adds member" on public.album_members for insert to authenticated with check (added_by = (select auth.uid()) and exists (select 1 from public.albums al where al.id = album_id and al.owner = (select auth.uid())));
create policy "owner or self removes member" on public.album_members for delete to authenticated using (user_id = (select auth.uid()) or exists (select 1 from public.albums al where al.id = album_id and al.owner = (select auth.uid())));

create policy "album photos visible" on public.album_photos for select to authenticated using (public.album_visible(album_id));
create policy "add album photo" on public.album_photos for insert to authenticated with check (added_by = (select auth.uid()) and public.can_post() and public.album_can_add(album_id, (select auth.uid())));
create policy "edit own caption" on public.album_photos for update to authenticated using (added_by = (select auth.uid())) with check (added_by = (select auth.uid()));
create policy "remove album photo" on public.album_photos for delete to authenticated using (added_by = (select auth.uid()) or public.is_staff() or exists (select 1 from public.albums al where al.id = album_id and al.owner = (select auth.uid())));

create or replace function public.album_photos_before() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if (select count(*) from public.album_photos where album_id = new.album_id) >= 1000 then raise exception 'album_full'; end if;
  if (select count(*) from public.album_photos where added_by = new.added_by and created_at > now() - interval '1 hour') >= 200 then raise exception 'rate_limit'; end if;
  return new;
end $$;
create trigger album_photos_before before insert on public.album_photos for each row execute function public.album_photos_before();

create or replace function public.trg_album_photo() returns trigger language plpgsql security definer set search_path = '' as $$
declare a record; aid bigint := coalesce(new.album_id, old.album_id);
begin
  update public.albums al set photos = (select count(*) from public.album_photos p where p.album_id = aid), updated_at = now(),
    cover_url = case
      when tg_op = 'INSERT' and al.cover_url is null then coalesce(new.md, new.url)
      when tg_op = 'DELETE' and al.cover_url in (old.md, old.url) then (select coalesce(p.md, p.url) from public.album_photos p where p.album_id = aid order by p.created_at desc limit 1)
      else al.cover_url end
  where al.id = aid
  returning al.id, al.owner, al.title into a;
  if a.id is null then return null; end if;
  if tg_op = 'INSERT' and a.owner <> new.added_by
     and not exists (select 1 from public.notifications where user_id = a.owner and actor = new.added_by and kind = 'album_photo' and ref->>'album' = aid::text and created_at > now() - interval '6 hours') then
    perform public.notify(a.owner, new.added_by, 'album_photo', jsonb_build_object('album', aid, 'title', left(a.title, 80)));
  end if;
  return null;
end $$;
create trigger album_photos_count after insert or delete on public.album_photos for each row execute function public.trg_album_photo();

create or replace function public.trg_album_member() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform public.notify(new.user_id, new.added_by, 'album_invite', jsonb_build_object('album', new.album_id, 'title', (select left(title, 80) from public.albums where id = new.album_id)));
  return null;
end $$;
create trigger album_members_notify after insert on public.album_members for each row execute function public.trg_album_member();

-- ============ group management ============
alter table public.groups
  add column rules text check (char_length(rules) <= 2000),
  add column join_mode text not null default 'open' check (join_mode in ('open', 'request')),
  add column post_approval boolean not null default false;
revoke update on public.groups from authenticated;
grant update (name, description, hue, is_private, rules, join_mode, post_approval) on public.groups to authenticated;

create or replace function public.is_group_admin(g bigint) returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.groups where id = g and owner = auth.uid())
      or exists (select 1 from public.group_members where group_id = g and user_id = auth.uid() and role = 'admin');
$$;

-- every group can be found by name; a closed group's posts stay with its members
alter policy "groups visible" on public.groups using (true);
-- open groups are joined directly, closed groups and "on request" groups through a request
alter policy "join public group" on public.group_members with check (user_id = (select auth.uid()) and role = 'member' and exists (
  select 1 from public.groups g where g.id = group_members.group_id and ((not g.is_private and g.join_mode = 'open') or g.owner = (select auth.uid()))));

create table public.group_requests (
  group_id bigint not null references public.groups(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  note text check (char_length(note) <= 300),
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
  created_at timestamptz not null default now(),
  primary key (group_id, user_id)
);
create index group_requests_pending_idx on public.group_requests (group_id) where status = 'pending';
alter table public.group_requests enable row level security;
revoke all on public.group_requests from anon;
revoke update on public.group_requests from authenticated;
grant update (note, status, created_at) on public.group_requests to authenticated;
create policy "requests visible" on public.group_requests for select to authenticated using (user_id = (select auth.uid()) or public.is_group_admin(group_id));
create policy "ask to join" on public.group_requests for insert to authenticated with check (user_id = (select auth.uid()) and status = 'pending' and public.can_post()
  and not public.is_group_member(group_id) and exists (select 1 from public.groups g where g.id = group_id and (g.is_private or g.join_mode = 'request')));
create policy "ask again" on public.group_requests for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()) and status = 'pending');
create policy "withdraw request" on public.group_requests for delete to authenticated using (user_id = (select auth.uid()) or public.is_group_admin(group_id));

create or replace function public.trg_group_request() returns trigger language plpgsql security definer set search_path = '' as $$
declare g record; a uuid;
begin
  if new.status <> 'pending' or (tg_op = 'UPDATE' and old.status = 'pending') then return null; end if;
  select id, owner, name into g from public.groups where id = new.group_id;
  for a in select g.owner union select user_id from public.group_members where group_id = new.group_id and role = 'admin' loop
    if not exists (select 1 from public.notifications where user_id = a and actor = new.user_id and kind = 'group_request' and ref->>'group' = g.id::text and created_at > now() - interval '1 day') then
      perform public.notify(a, new.user_id, 'group_request', jsonb_build_object('group', g.id, 'name', left(g.name, 80)));
    end if;
  end loop;
  return null;
end $$;
create trigger group_requests_notify after insert or update on public.group_requests for each row execute function public.trg_group_request();

create or replace function public.group_respond(p_group bigint, p_user uuid, p_accept boolean) returns void language plpgsql security definer set search_path = '' as $$
declare g record;
begin
  if not public.is_group_admin(p_group) then raise exception 'not_allowed'; end if;
  update public.group_requests set status = case when p_accept then 'accepted' else 'declined' end where group_id = p_group and user_id = p_user and status = 'pending';
  if not found then raise exception 'not_found'; end if;
  if p_accept then
    insert into public.group_members (group_id, user_id) values (p_group, p_user) on conflict do nothing;
    select name into g from public.groups where id = p_group;
    perform public.notify(p_user, auth.uid(), 'group_ok', jsonb_build_object('group', p_group, 'name', left(g.name, 80)));
  end if;
end $$;

create or replace function public.group_set_role(p_group bigint, p_user uuid, p_role text) returns void language plpgsql security definer set search_path = '' as $$
declare g record;
begin
  select id, owner, name into g from public.groups where id = p_group;
  if g.owner is distinct from auth.uid() then raise exception 'not_allowed'; end if;
  if p_role not in ('admin', 'member') or p_user = g.owner then raise exception 'bad_role'; end if;
  update public.group_members set role = p_role where group_id = p_group and user_id = p_user;
  if not found then raise exception 'not_found'; end if;
  if p_role = 'admin' then perform public.notify(p_user, auth.uid(), 'group_admin', jsonb_build_object('group', p_group, 'name', left(g.name, 80))); end if;
end $$;

-- admins remove members (an admin only by the owner); the owner never
alter policy "leave group" on public.group_members using (
  user_id = (select auth.uid())
  or exists (select 1 from public.groups g where g.id = group_members.group_id and g.owner = (select auth.uid()))
  or (public.is_group_admin(group_id) and role = 'member' and not exists (select 1 from public.groups g where g.id = group_members.group_id and g.owner = group_members.user_id)));

-- posts waiting for an admin in groups that review new posts
alter table public.posts add column pending boolean not null default false;
create or replace function public.posts_group_gate() returns trigger language plpgsql security definer set search_path = '' as $$
declare g record;
begin
  new.pending := false;
  if new.group_id is null then return new; end if;
  select owner, post_approval into g from public.groups where id = new.group_id;
  new.pending := coalesce(g.post_approval, false) and new.author <> g.owner
    and not exists (select 1 from public.group_members where group_id = new.group_id and user_id = new.author and role = 'admin');
  return new;
end $$;
create trigger posts_group_gate before insert on public.posts for each row execute function public.posts_group_gate();

create or replace function public.trg_group_pending() returns trigger language plpgsql security definer set search_path = '' as $$
declare g record; a uuid;
begin
  if not new.pending then return null; end if;
  select id, owner, name into g from public.groups where id = new.group_id;
  for a in select g.owner union select user_id from public.group_members where group_id = new.group_id and role = 'admin' loop
    perform public.notify(a, new.author, 'group_pending', jsonb_build_object('group', g.id, 'name', left(g.name, 80), 'post', new.id));
  end loop;
  return null;
end $$;
create trigger posts_group_pending after insert on public.posts for each row execute function public.trg_group_pending();

create or replace function public.group_review_post(p_post bigint, p_ok boolean) returns void language plpgsql security definer set search_path = '' as $$
declare p record; g record;
begin
  select id, author, group_id, pending into p from public.posts where id = p_post;
  if p.id is null or p.group_id is null or not p.pending then raise exception 'not_found'; end if;
  if not public.is_group_admin(p.group_id) then raise exception 'not_allowed'; end if;
  select name into g from public.groups where id = p.group_id;
  -- a declined post is then removed by the admin (the delete policy allows group admins)
  if p_ok then
    update public.posts set pending = false where id = p_post;
    perform public.notify(p.author, auth.uid(), 'group_post_ok', jsonb_build_object('group', p.group_id, 'name', left(g.name, 80), 'post', p_post));
  else
    perform public.notify(p.author, auth.uid(), 'group_post_no', jsonb_build_object('group', p.group_id, 'name', left(g.name, 80)));
  end if;
end $$;

alter policy "posts visible" on public.posts using (
  ((not hidden) or (author = (select auth.uid())) or public.is_staff())
  and ((author = (select auth.uid())) or ((not draft) and (created_at <= now())))
  and (not public.is_blocked(author, (select auth.uid())))
  and ((group_id is null) or public.group_visible(group_id))
  and ((not pending) or (author = (select auth.uid())) or public.is_group_admin(group_id)));
alter policy "author or staff removes post" on public.posts using (
  (author = (select auth.uid())) or public.is_staff() or (group_id is not null and public.is_group_admin(group_id)));
alter policy "remove comment" on public.comments using (
  (author = (select auth.uid())) or public.is_staff()
  or exists (select 1 from public.posts p where p.id = comments.post_id and (p.author = (select auth.uid()) or (p.group_id is not null and public.is_group_admin(p.group_id)))));

-- mentions wait until a reviewed post is approved
create or replace function public.trg_post_mentions() returns trigger language plpgsql security definer set search_path = '' as $$
declare u uuid; olds uuid[] := '{}';
begin
  if new.draft or new.hidden or new.pending or new.created_at > now() + interval '1 minute' then return new; end if;
  if tg_op = 'UPDATE' and not old.draft and not old.pending then olds := public.mention_ids(old.body); end if;
  foreach u in array public.mention_ids(new.body) loop
    continue when u = new.author or u = any(olds);
    continue when not public.group_open_to(new.group_id, u);
    perform public.notify(u, new.author, 'mention', jsonb_build_object('post', new.id, 'text', left(new.body, 80)));
  end loop;
  return new;
end $$;
create or replace trigger posts_mentions after insert or update of body, draft, pending on public.posts for each row execute function public.trg_post_mentions();

-- ============ anti-spam ============
-- words the moderators list are masked in posts and comments ("ც***"); a word also catches its endings
create table public.bad_words (
  word text primary key check (char_length(word) between 2 and 40 and word = lower(word)),
  added_by uuid default auth.uid() references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);
alter table public.bad_words enable row level security;
revoke all on public.bad_words from anon;
revoke update on public.bad_words from authenticated;
create policy "staff sees words" on public.bad_words for select to authenticated using (public.is_staff());
create policy "staff adds word" on public.bad_words for insert to authenticated with check (public.is_staff());
create policy "staff removes word" on public.bad_words for delete to authenticated using (public.is_staff());

create or replace function public.mask_words(t text) returns text language plpgsql stable security definer set search_path = '' as $f$
declare w text; r text := t;
begin
  if t is null or t = '' then return t; end if;
  for w in select word from public.bad_words loop
    r := regexp_replace(r, '\m' || regexp_replace(w, '([.*+?^${}()|\[\]\\])', '\\\1', 'g') || '\w*', left(w, 1) || '***', 'gi');
  end loop;
  return r;
end $f$;
revoke execute on function public.mask_words(text) from public, anon, authenticated;

create index if not exists posts_author_time_idx on public.posts (author, created_at desc);
create index if not exists comments_author_time_idx on public.comments (author, created_at desc);
create index if not exists messages_sender_time_idx on public.messages (sender, created_at desc);
create index if not exists friendships_requester_idx on public.friendships (requester);

create or replace function public.young_account(u uuid) returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce((select created_at > now() - interval '1 day' from public.profiles where id = u), false);
$$;
revoke execute on function public.young_account(uuid) from public, anon, authenticated;

create or replace function public.antispam_post() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' and not public.is_staff() then
    if (select count(*) from public.posts where author = new.author and created_at > now() - interval '1 hour') >= 15 then raise exception 'rate_limit'; end if;
    if new.body ~* '(https?://|www\.)' and public.young_account(new.author)
       and (select count(*) from public.posts where author = new.author and created_at > now() - interval '1 hour' and body ~* '(https?://|www\.)') >= 2 then raise exception 'spam_links'; end if;
  end if;
  if tg_op = 'INSERT' or new.body is distinct from old.body then new.body := public.mask_words(new.body); end if;
  return new;
end $$;
create trigger posts_antispam before insert or update of body on public.posts for each row execute function public.antispam_post();

create or replace function public.antispam_comment() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_staff() then
    if (select count(*) from public.comments where author = new.author and created_at > now() - interval '1 minute') >= 8
       or (select count(*) from public.comments where author = new.author and created_at > now() - interval '1 hour') >= 120 then raise exception 'rate_limit'; end if;
    if char_length(new.body) >= 15 and (select count(distinct post_id) from public.comments where author = new.author and body = new.body and created_at > now() - interval '10 minutes') >= 3 then raise exception 'spam_duplicate'; end if;
    if new.body ~* '(https?://|www\.)' and public.young_account(new.author)
       and (select count(*) from public.comments where author = new.author and created_at > now() - interval '1 hour' and body ~* '(https?://|www\.)') >= 3 then raise exception 'spam_links'; end if;
  end if;
  new.body := public.mask_words(new.body);
  return new;
end $$;
create trigger comments_antispam before insert on public.comments for each row execute function public.antispam_comment();

create or replace function public.antispam_message() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.kind = 'system' or public.is_staff() then return new; end if;
  if (select count(*) from public.messages where sender = new.sender and created_at > now() - interval '1 minute') >= 30 then raise exception 'rate_limit'; end if;
  if char_length(coalesce(new.body, '')) >= 15 and (select count(distinct conv_id) from public.messages where sender = new.sender and body = new.body and created_at > now() - interval '10 minutes') >= 5 then raise exception 'spam_duplicate'; end if;
  if coalesce(new.body, '') ~* '(https?://|www\.)' and public.young_account(new.sender)
     and (select count(distinct conv_id) from public.messages where sender = new.sender and created_at > now() - interval '1 hour' and body ~* '(https?://|www\.)') >= 8 then raise exception 'spam_links'; end if;
  return new;
end $$;
create trigger messages_antispam before insert on public.messages for each row execute function public.antispam_message();

create or replace function public.antispam_friend() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if (select count(*) from public.friendships where requester = new.requester and created_at > now() - interval '1 day') >= 50 then raise exception 'rate_limit'; end if;
  return new;
end $$;
create trigger friendships_antispam before insert on public.friendships for each row execute function public.antispam_friend();

-- three different people reporting the same post or comment hide it until a moderator looks
create or replace function public.trg_report_autohide() returns trigger language plpgsql security definer set search_path = '' as $$
declare n int;
begin
  if new.target_type not in ('post', 'comment') or new.target_id !~ '^\d{1,18}$' then return null; end if;
  select count(distinct reporter) into n from public.reports
    where target_type = new.target_type and target_id = new.target_id and status = 'open' and created_at > now() - interval '7 days';
  if n >= 3 then
    if new.target_type = 'post' then
      update public.posts p set hidden = true where p.id = new.target_id::bigint and not p.hidden
        and not exists (select 1 from public.profiles a where a.id = p.author and a.role in ('admin', 'moderator'));
    else
      update public.comments c set hidden = true where c.id = new.target_id::bigint and not c.hidden
        and not exists (select 1 from public.profiles a where a.id = c.author and a.role in ('admin', 'moderator'));
    end if;
  end if;
  return null;
end $$;
create trigger reports_autohide after insert on public.reports for each row execute function public.trg_report_autohide();

-- ============ lock down ============
revoke execute on function public.event_party(bigint, uuid), public.event_lead(bigint), public.album_can_add(bigint, uuid), public.album_visible(bigint), public.is_group_admin(bigint) from public, anon;
grant execute on function public.event_party(bigint, uuid), public.event_lead(bigint), public.album_can_add(bigint, uuid), public.album_visible(bigint), public.is_group_admin(bigint) to authenticated;
revoke execute on function public.invite_to_event(bigint, uuid[]), public.group_respond(bigint, uuid, boolean), public.group_set_role(bigint, uuid, text),
  public.group_review_post(bigint, boolean) from public, anon;
grant execute on function public.invite_to_event(bigint, uuid[]), public.group_respond(bigint, uuid, boolean), public.group_set_role(bigint, uuid, text),
  public.group_review_post(bigint, boolean) to authenticated;
revoke execute on function public.album_photos_before(), public.trg_album_photo(), public.trg_album_member(), public.trg_group_request(), public.posts_group_gate(),
  public.trg_group_pending(), public.trg_post_mentions(), public.antispam_post(), public.antispam_comment(), public.antispam_message(), public.antispam_friend(),
  public.trg_report_autohide() from public, anon, authenticated;

-- the select policy reads the row itself, so INSERT ... RETURNING sees the new album
alter policy "albums visible" on public.albums using (
  not public.is_blocked(owner, (select auth.uid())) and (
    owner = (select auth.uid()) or audience = 'all'
    or (audience = 'friends' and public.are_friends(owner, (select auth.uid())))
    or exists (select 1 from public.album_members m where m.album_id = albums.id and m.user_id = (select auth.uid()))
    or (event_id is not null and public.event_party(event_id, (select auth.uid())))));
