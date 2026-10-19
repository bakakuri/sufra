-- the admin panel controls the whole site: settings and section switches, sponsored posts and stories,
-- notifications to everyone, coins, a fuller overview and a log of what the team did

-- an audit log: written only by the database itself, read by the team
create table if not exists public.admin_log (
  id bigserial primary key,
  actor uuid references public.profiles(id) on delete set null,
  action text not null,
  target text,
  detail jsonb,
  created_at timestamptz not null default now());
create index if not exists admin_log_time_idx on public.admin_log (created_at desc);
alter table public.admin_log enable row level security;
create policy "team reads the log" on public.admin_log for select using (public.is_staff());
revoke all on public.admin_log from anon;
grant select on public.admin_log to authenticated;

create or replace function private.admin_log(p_action text, p_target text, p_detail jsonb)
returns void
language sql
security definer
set search_path to ''
as $function$
  insert into public.admin_log (actor, action, target, detail) values (auth.uid(), p_action, p_target, p_detail);
$function$;
revoke execute on function private.admin_log(text, text, jsonb) from public, anon, authenticated;

-- site settings: a banner for everyone and switches that turn whole sections off
create table if not exists public.app_settings (
  key text primary key check (key ~ '^[a-z_]{1,32}$'),
  value jsonb not null default '{}'::jsonb check (pg_column_size(value) < 8000),
  updated_by uuid references public.profiles(id) on delete set null,
  updated_at timestamptz not null default now());
alter table public.app_settings enable row level security;
create policy "settings readable" on public.app_settings for select using ((select auth.uid()) is not null);
create policy "admin adds settings" on public.app_settings for insert with check (public.is_admin());
create policy "admin changes settings" on public.app_settings for update using (public.is_admin()) with check (public.is_admin());
revoke all on public.app_settings from anon;
grant select, insert, update on public.app_settings to authenticated;

create or replace function private.settings_stamp()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
begin
  new.updated_by := auth.uid();
  new.updated_at := now();
  perform private.admin_log('settings', new.key, new.value);
  return new;
end $function$;
revoke execute on function private.settings_stamp() from public, anon, authenticated;
create or replace trigger app_settings_stamp before insert or update on public.app_settings for each row execute function private.settings_stamp();

-- sponsored posts and stories made by the admin; people see them only while they run
create table if not exists public.promos (
  id bigserial primary key,
  kind text not null default 'post' check (kind in ('post','story')),
  brand text not null default 'სუფრა' check (char_length(brand) between 1 and 60),
  brand_url text check (brand_url is null or brand_url ~ '^https://[^\s"''<>()]+$'),
  title text check (title is null or char_length(title) <= 120),
  body text check (body is null or char_length(body) <= 1000),
  media_url text check (media_url is null or media_url ~ '^https://[^\s"''<>()]+$'),
  media_type text not null default 'image' check (media_type in ('image','video')),
  w int check (w is null or w between 1 and 20000),
  h int check (h is null or h between 1 and 20000),
  link text check (link is null or link ~ '^(https://[^\s"''<>()]+|#[a-z]+(-[^\s"''<>()]+)?)$'),
  cta text check (cta is null or char_length(cta) <= 30),
  every int not null default 8 check (every between 3 and 50),
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  active boolean not null default true,
  reach int not null default 0,
  clicks int not null default 0,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  check (kind = 'post' or media_url is not null),
  check (title is not null or body is not null or media_url is not null));
create index if not exists promos_live_idx on public.promos (kind, active, starts_at);
alter table public.promos enable row level security;
create policy "promos visible" on public.promos for select using (public.is_admin() or (active and starts_at <= now() and (ends_at is null or ends_at > now())));
create policy "admin makes promos" on public.promos for insert with check (public.is_admin());
create policy "admin edits promos" on public.promos for update using (public.is_admin()) with check (public.is_admin());
create policy "admin removes promos" on public.promos for delete using (public.is_admin());
revoke all on public.promos from anon;
grant select, delete on public.promos to authenticated;
grant insert (kind, brand, brand_url, title, body, media_url, media_type, w, h, link, cta, every, starts_at, ends_at, active),
      update (kind, brand, brand_url, title, body, media_url, media_type, w, h, link, cta, every, starts_at, ends_at, active) on public.promos to authenticated;
grant usage on sequence public.promos_id_seq to authenticated;

create or replace function private.promo_log()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
begin
  if tg_op = 'INSERT' then new.created_by := auth.uid(); perform private.admin_log('promo_new', new.id::text, jsonb_build_object('kind', new.kind, 'title', coalesce(new.title, left(new.body, 60)))); return new; end if;
  if tg_op = 'UPDATE' then
    if old.active is distinct from new.active then perform private.admin_log(case when new.active then 'promo_on' else 'promo_off' end, new.id::text, jsonb_build_object('title', coalesce(new.title, left(new.body, 60)))); end if;
    return new; end if;
  perform private.admin_log('promo_del', old.id::text, jsonb_build_object('title', coalesce(old.title, left(old.body, 60)), 'reach', old.reach, 'clicks', old.clicks));
  return old;
end $function$;
revoke execute on function private.promo_log() from public, anon, authenticated;
create or replace trigger promos_log_ins before insert on public.promos for each row execute function private.promo_log();
create or replace trigger promos_log_upd before update on public.promos for each row execute function private.promo_log();
create or replace trigger promos_log_del after delete on public.promos for each row execute function private.promo_log();

-- who saw and who tapped: counted once per person
create table if not exists public.promo_seen (
  promo_id bigint not null references public.promos(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  clicked boolean not null default false,
  at timestamptz not null default now(),
  primary key (promo_id, user_id));
alter table public.promo_seen enable row level security;
revoke all on public.promo_seen from anon, authenticated;

create or replace function public.promo_hit(p_promo bigint, p_click boolean default false)
returns void
language plpgsql
security definer
set search_path to ''
as $function$
begin
  if auth.uid() is null then return; end if;
  if not exists (select 1 from public.promos where id = p_promo and active and starts_at <= now() and (ends_at is null or ends_at > now())) then return; end if;
  insert into public.promo_seen (promo_id, user_id, clicked) values (p_promo, auth.uid(), coalesce(p_click, false))
    on conflict (promo_id, user_id) do nothing;
  if found then
    update public.promos set reach = reach + 1, clicks = clicks + (case when p_click then 1 else 0 end) where id = p_promo;
  elsif p_click then
    update public.promo_seen set clicked = true where promo_id = p_promo and user_id = auth.uid() and not clicked;
    if found then update public.promos set clicks = clicks + 1 where id = p_promo; end if;
  end if;
end $function$;
revoke execute on function public.promo_hit(bigint, boolean) from public, anon;
grant execute on function public.promo_hit(bigint, boolean) to authenticated;

-- a notification to everyone (or a region, or the verified, or only me as a test).
-- it is its own category, so anyone can turn these off in notification settings
create or replace function public.notif_category(k text)
returns text
language sql
immutable
set search_path to ''
as $function$
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
    when k like 'bet\_%' then 'sport'
    when k like 'ride\_%' or k like 'job\_%' then 'deals'
    when k like 'group\_%' then 'groups'
    when k like 'event\_%' or k like 'album\_%' then 'events'
    else 'system' end;
$function$;

create table if not exists public.broadcasts (
  id bigserial primary key,
  sent_by uuid references public.profiles(id) on delete set null,
  text text not null,
  link text,
  audience jsonb not null default '{}'::jsonb,
  sent int not null default 0,
  created_at timestamptz not null default now());
alter table public.broadcasts enable row level security;
create policy "team reads broadcasts" on public.broadcasts for select using (public.is_staff());
revoke all on public.broadcasts from anon;
grant select on public.broadcasts to authenticated;

create or replace function public.admin_broadcast(p_text text, p_link text default null, p_aud text default 'all', p_region text default null, p_dry boolean default false)
returns int
language plpgsql
security definer
set search_path to ''
as $function$
declare t text := left(trim(coalesce(p_text, '')), 200); l text := nullif(trim(coalesce(p_link, '')), ''); n int := 0; b bigint; u uuid;
begin
  if not public.is_admin() then raise exception 'admin_only'; end if;
  if p_aud not in ('all', 'active', 'region', 'verified', 'me') then raise exception 'bad_request'; end if;
  if p_aud = 'region' and coalesce(trim(p_region), '') = '' then raise exception 'bad_request'; end if;
  if p_dry then
    select count(*) into n from public.profiles p
      where not p.banned and not public.notif_off(p.id, 'promo')
        and (p_aud = 'all' or (p_aud = 'me' and p.id = auth.uid()) or (p_aud = 'verified' and p.verified)
          or (p_aud = 'region' and p.home_region = p_region) or (p_aud = 'active' and p.last_seen > now() - interval '7 days'));
    return n;
  end if;
  if char_length(t) < 2 then raise exception 'bad_request'; end if;
  if l is not null and l !~ '^(https://[^\s"''<>()]+|#[a-z]+(-[^\s"''<>()]+)?)$' then raise exception 'bad_request'; end if;
  if p_aud <> 'me' and (select count(*) from public.broadcasts where created_at > now() - interval '1 day' and audience->>'aud' <> 'me') >= 20 then raise exception 'rate_limit'; end if;
  insert into public.broadcasts (sent_by, text, link, audience) values (auth.uid(), t, l, jsonb_build_object('aud', p_aud, 'region', p_region)) returning id into b;
  for u in select p.id from public.profiles p
      where not p.banned and not public.notif_off(p.id, 'promo')
        and (p_aud = 'all' or (p_aud = 'me' and p.id = auth.uid()) or (p_aud = 'verified' and p.verified)
          or (p_aud = 'region' and p.home_region = p_region) or (p_aud = 'active' and p.last_seen > now() - interval '7 days')) loop
    insert into public.notifications (user_id, actor, kind, ref) values (u, null, 'promo', jsonb_build_object('text', t, 'link', l, 'b', b));
    n := n + 1;
  end loop;
  update public.broadcasts set sent = n where id = b;
  perform private.admin_log('broadcast', b::text, jsonb_build_object('text', t, 'aud', p_aud, 'region', p_region, 'sent', n));
  return n;
end $function$;
revoke execute on function public.admin_broadcast(text, text, text, text, boolean) from public, anon;
grant execute on function public.admin_broadcast(text, text, text, text, boolean) to authenticated;

-- a personal message from the team, and coins given or taken by the admin
create or replace function public.admin_notify_user(p_user uuid, p_text text)
returns void
language plpgsql
security definer
set search_path to ''
as $function$
declare t text := left(trim(coalesce(p_text, '')), 300);
begin
  if not public.is_staff() then raise exception 'staff_only'; end if;
  if char_length(t) < 2 or not exists (select 1 from public.profiles where id = p_user) then raise exception 'bad_request'; end if;
  insert into public.notifications (user_id, actor, kind, ref) values (p_user, null, 'admin_msg', jsonb_build_object('text', t));
  perform private.admin_log('message', p_user::text, jsonb_build_object('text', t));
end $function$;
revoke execute on function public.admin_notify_user(uuid, text) from public, anon;
grant execute on function public.admin_notify_user(uuid, text) to authenticated;

create or replace function public.admin_coins(p_user uuid, p_amount int, p_note text default null)
returns int
language plpgsql
security definer
set search_path to ''
as $function$
declare c int; note text := left(coalesce(nullif(trim(p_note), ''), case when p_amount > 0 then 'სუფრის საჩუქარი' else 'ადმინისტრაციის კორექცია' end), 80);
begin
  if not public.is_admin() then raise exception 'admin_only'; end if;
  if p_amount is null or p_amount = 0 or abs(p_amount) > 100000 then raise exception 'bad_request'; end if;
  update public.profiles set coins = greatest(0, coins + p_amount) where id = p_user returning coins into c;
  if c is null then raise exception 'not_found'; end if;
  insert into public.coin_log (user_id, amount, label) values (p_user, p_amount, note);
  insert into public.notifications (user_id, actor, kind, ref) values (p_user, null, 'admin_coins', jsonb_build_object('coins', p_amount, 'note', note));
  perform private.admin_log('coins', p_user::text, jsonb_build_object('amount', p_amount, 'note', note));
  return c;
end $function$;
revoke execute on function public.admin_coins(uuid, int, text) from public, anon;
grant execute on function public.admin_coins(uuid, int, text) to authenticated;

-- what the team sees about one person
create or replace function public.admin_user_info(p_user uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $function$
begin
  if not public.is_staff() then raise exception 'staff_only'; end if;
  return jsonb_build_object(
    'coins', (select coins from public.profiles where id = p_user),
    'last_seen', (select last_seen from public.profiles where id = p_user),
    'email', case when public.is_admin() then (select email from auth.users where id = p_user) end,
    'posts', (select count(*) from public.posts where author = p_user),
    'comments', (select count(*) from public.comments where author = p_user),
    'friends', (select count(*) from public.friendships where status = 'accepted' and (requester = p_user or addressee = p_user)),
    'reports', (select count(*) from public.reports where target_type = 'user' and target_id = p_user::text),
    'reported_content', (select count(*) from public.reports r where r.target_type = 'post' and exists (select 1 from public.posts p where p.id::text = r.target_id and p.author = p_user)));
end $function$;
revoke execute on function public.admin_user_info(uuid) from public, anon;
grant execute on function public.admin_user_info(uuid) to authenticated;

-- hiding is logged too
create or replace function public.admin_hide(p_type text, p_id bigint, p_hidden boolean)
returns void
language plpgsql
security definer
set search_path to ''
as $function$
begin
  if not public.is_staff() then raise exception 'staff_only'; end if;
  if p_type = 'post' then update public.posts set hidden = p_hidden where id = p_id;
  elsif p_type = 'comment' then update public.comments set hidden = p_hidden where id = p_id;
  elsif p_type = 'listing' then update public.listings set hidden = p_hidden where id = p_id;
  elsif p_type = 'job' then update public.jobs set hidden = p_hidden where id = p_id;
  elsif p_type = 'place' then update public.places set hidden = p_hidden where id = p_id;
  elsif p_type = 'review' then update public.place_reviews set hidden = p_hidden where id = p_id;
  elsif p_type = 'toast' then update public.toasts set hidden = p_hidden where id = p_id;
  elsif p_type = 'help' then update public.help_requests set hidden = p_hidden where id = p_id;
  else raise exception 'bad_type'; end if;
  perform private.admin_log(case when p_hidden then 'hide' else 'unhide' end, p_type || ':' || p_id, null);
end $function$;

-- bans, roles and verification changed by someone from the team
create or replace function private.profile_admin_log()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
begin
  if auth.uid() is null or auth.uid() = new.id then return null; end if;
  if old.banned is distinct from new.banned then perform private.admin_log(case when new.banned then 'ban' else 'unban' end, new.id::text, jsonb_build_object('name', new.name)); end if;
  if old.role is distinct from new.role then perform private.admin_log('role', new.id::text, jsonb_build_object('name', new.name, 'from', old.role, 'to', new.role)); end if;
  if old.verified is distinct from new.verified then perform private.admin_log(case when new.verified then 'verify' else 'unverify' end, new.id::text, jsonb_build_object('name', new.name)); end if;
  return null;
end $function$;
revoke execute on function private.profile_admin_log() from public, anon, authenticated;
create or replace trigger profiles_admin_log after update of banned, role, verified on public.profiles for each row execute function private.profile_admin_log();

-- someone else's content removed by the team
create or replace function private.content_admin_log()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
declare v jsonb := to_jsonb(old); owner text;
begin
  if auth.uid() is null or pg_trigger_depth() > 1 then return null; end if;
  owner := coalesce(v->>'author', v->>'owner', v->>'host', v->>'seller', v->>'poster', v->>'created_by', v->>'driver');
  if owner is not distinct from auth.uid()::text or not public.is_staff() then return null; end if;
  perform private.admin_log('delete', tg_table_name || ':' || (v->>'id'),
    jsonb_build_object('owner', owner, 'text', left(coalesce(v->>'body', v->>'title', v->>'name', v->>'media_url', ''), 120)));
  return null;
end $function$;
revoke execute on function private.content_admin_log() from public, anon, authenticated;
create or replace trigger posts_admin_log after delete on public.posts for each row execute function private.content_admin_log();
create or replace trigger comments_admin_log after delete on public.comments for each row execute function private.content_admin_log();
create or replace trigger stories_admin_log after delete on public.stories for each row execute function private.content_admin_log();
create or replace trigger groups_admin_log after delete on public.groups for each row execute function private.content_admin_log();
create or replace trigger pages_admin_log after delete on public.pages for each row execute function private.content_admin_log();
create or replace trigger events_admin_log after delete on public.events for each row execute function private.content_admin_log();
create or replace trigger listings_admin_log after delete on public.listings for each row execute function private.content_admin_log();
create or replace trigger recipes_admin_log after delete on public.recipes for each row execute function private.content_admin_log();
create or replace trigger jobs_admin_log after delete on public.jobs for each row execute function private.content_admin_log();
create or replace trigger places_admin_log after delete on public.places for each row execute function private.content_admin_log();
create or replace trigger toasts_admin_log after delete on public.toasts for each row execute function private.content_admin_log();
create or replace trigger help_admin_log after delete on public.help_requests for each row execute function private.content_admin_log();
create or replace trigger albums_admin_log after delete on public.albums for each row execute function private.content_admin_log();
create or replace trigger rides_admin_log after delete on public.rides for each row execute function private.content_admin_log();

-- the team can also remove rides and highlights and end a live room
create policy "staff removes ride" on public.rides for delete using (public.is_staff());
grant delete on public.rides to authenticated;
create policy "staff removes highlight" on public.highlights for delete using (public.is_staff());
create policy "staff ends room" on public.rooms for update using (public.is_staff()) with check (public.is_staff());

-- the overview: more numbers and the last two weeks day by day (Tbilisi time)
create or replace function public.admin_stats()
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $function$
declare today date := (now() at time zone 'Asia/Tbilisi')::date;
begin
  if not public.is_staff() then raise exception 'staff_only'; end if;
  return jsonb_build_object(
    'users', (select count(*) from public.profiles),
    'users_today', (select count(*) from public.profiles where created_at > now() - interval '1 day'),
    'active_today', (select count(*) from public.profiles where last_seen > now() - interval '1 day'),
    'active_week', (select count(*) from public.profiles where last_seen > now() - interval '7 days'),
    'posts_today', (select count(*) from public.posts where created_at > now() - interval '1 day'),
    'comments_today', (select count(*) from public.comments where created_at > now() - interval '1 day'),
    'messages_today', (select count(*) from public.messages where created_at > now() - interval '1 day'),
    'stories_live', (select count(*) from public.stories where expires_at > now()),
    'groups', (select count(*) from public.groups),
    'pages', (select count(*) from public.pages),
    'events_soon', (select count(*) from public.events where starts_at > now()),
    'listings', (select count(*) from public.listings where not hidden),
    'recipes', (select count(*) from public.recipes),
    'rooms_live', (select count(*) from public.rooms where live and created_at > now() - interval '12 hours'),
    'coins_total', (select coalesce(sum(coins), 0) from public.profiles),
    'promos_live', (select count(*) from public.promos where active and starts_at <= now() and (ends_at is null or ends_at > now())),
    'open_reports', (select count(*) from public.reports where status = 'open'),
    'pending_verifications', (select count(*) from public.verification_requests where status = 'pending'),
    'pending_ads', (select count(*) from public.ads where status = 'pending'),
    'banned', (select count(*) from public.profiles where banned),
    'days', (select jsonb_agg(jsonb_build_object('d', d,
        'users', (select count(*) from public.profiles where (created_at at time zone 'Asia/Tbilisi')::date = d),
        'posts', (select count(*) from public.posts where (created_at at time zone 'Asia/Tbilisi')::date = d)) order by d)
      from generate_series(today - 13, today, interval '1 day') g(dd), lateral (select g.dd::date as d) x));
end $function$;
