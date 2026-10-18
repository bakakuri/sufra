-- profiles: home place and diaspora country
alter table public.profiles add column home_region text not null default '' check (char_length(home_region) <= 60),
  add column home_place text not null default '' check (char_length(home_place) <= 60),
  add column abroad text not null default '' check (char_length(abroad) <= 60);
grant select (home_region, home_place, abroad) on public.profiles to authenticated;
grant update (home_region, home_place, abroad) on public.profiles to authenticated;

-- groups: automatic village/region and diaspora groups
alter table public.groups add column kind text not null default 'normal' check (kind in ('normal','place','diaspora')),
  add column place_key text unique;

create or replace function public.join_place_groups() returns bigint[] language plpgsql security definer set search_path = '' as $$
declare me record; owner_id uuid; keys text[] := '{}'; names text[] := '{}'; kinds text[] := '{}'; ids bigint[] := '{}'; g bigint; i int;
begin
  if not public.can_post() then raise exception 'not_allowed'; end if;
  select home_region, home_place, abroad into me from public.profiles where id = auth.uid();
  select id into owner_id from public.profiles where role = 'admin' order by created_at limit 1;
  owner_id := coalesce(owner_id, auth.uid());
  if me.home_region <> '' then keys := keys || ('region:' || lower(me.home_region)); names := names || me.home_region; kinds := kinds || 'place'::text; end if;
  if me.home_place <> '' then keys := keys || ('place:' || lower(me.home_region) || ':' || lower(trim(me.home_place))); names := names || (trim(me.home_place) || case when me.home_region <> '' then ' · ' || me.home_region else '' end); kinds := kinds || 'place'::text; end if;
  if me.abroad <> '' then keys := keys || ('abroad:' || lower(me.abroad)); names := names || ('ქართველები · ' || me.abroad); kinds := kinds || 'diaspora'::text; end if;
  for i in 1 .. coalesce(array_length(keys, 1), 0) loop
    insert into public.groups (owner, name, description, hue, is_private, kind, place_key)
      values (owner_id, left(names[i], 80), case when kinds[i] = 'diaspora' then 'ქართველების საზოგადოება ' || me.abroad || 'ში' else 'ჩემი კუთხის ხალხი' end, floor(random() * 360)::int, false, kinds[i], keys[i])
      on conflict (place_key) do nothing;
    select id into g from public.groups where place_key = keys[i];
    insert into public.group_members (group_id, user_id) values (g, auth.uid()) on conflict do nothing;
    ids := ids || g;
  end loop;
  return ids;
end $$;

-- posts: drafts, scheduled publishing, link previews
alter table public.posts add column draft boolean not null default false,
  add column publish_at timestamptz,
  add column link jsonb;
create or replace function public.posts_schedule() returns trigger language plpgsql set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    if new.publish_at is not null and new.publish_at > now() then new.created_at := new.publish_at; else new.publish_at := null; new.created_at := now(); end if;
  else
    if old.draft or old.created_at > now() then
      if new.publish_at is not null and new.publish_at > now() then new.created_at := new.publish_at; else new.publish_at := null; new.created_at := now(); end if;
    else
      new.draft := old.draft; new.publish_at := old.publish_at; new.created_at := old.created_at;
    end if;
  end if;
  return new;
end $$;
create trigger posts_schedule before insert or update of draft, publish_at on public.posts for each row execute function public.posts_schedule();
alter policy "posts visible" on public.posts using (
  (not hidden or author = (select auth.uid()) or public.is_staff())
  and (author = (select auth.uid()) or (not draft and created_at <= now()))
  and not public.is_blocked(author, (select auth.uid()))
  and (group_id is null or public.group_visible(group_id)));
grant update (link, draft, publish_at) on public.posts to authenticated;
create index posts_drafts_idx on public.posts (author) where draft;

create or replace function public.trending_tags(p_limit int default 10) returns table (tag text, uses int) language sql stable security definer set search_path = '' as $$
  select t, count(*)::int from public.posts, unnest(tags) t
  where created_at > now() - interval '3 days' and created_at <= now() and not hidden and not draft
  group by t order by count(*) desc, t limit least(greatest(p_limit, 1), 30);
$$;

create or replace function public.my_memories() returns setof bigint language sql stable security invoker set search_path = '' as $$
  select id from public.posts
  where author = auth.uid() and not draft
    and extract(month from created_at at time zone 'Asia/Tbilisi') = extract(month from now() at time zone 'Asia/Tbilisi')
    and extract(day from created_at at time zone 'Asia/Tbilisi') = extract(day from now() at time zone 'Asia/Tbilisi')
    and created_at < date_trunc('year', now() at time zone 'Asia/Tbilisi') at time zone 'Asia/Tbilisi'
  order by created_at desc limit 12;
$$;

-- link preview cache, filled by the unfurl edge function with the service role
create table public.link_cache (
  url text primary key,
  data jsonb not null,
  fetched_at timestamptz not null default now()
);
alter table public.link_cache enable row level security;

-- close friends for stories
create table public.close_friends (
  owner uuid not null references public.profiles(id) on delete cascade,
  friend uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (owner, friend),
  check (owner <> friend)
);
alter table public.close_friends enable row level security;
create policy "my close friends" on public.close_friends for select to authenticated using (owner = (select auth.uid()));
create policy "add close friend" on public.close_friends for insert to authenticated with check (owner = (select auth.uid()));
create policy "remove close friend" on public.close_friends for delete to authenticated using (owner = (select auth.uid()));
create or replace function public.in_close(o uuid) returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.close_friends where owner = o and friend = auth.uid());
$$;
alter table public.stories add column audience text not null default 'all' check (audience in ('all','close'));
alter policy "stories visible" on public.stories using (
  expires_at > now() and not public.is_blocked(author, (select auth.uid()))
  and (audience = 'all' or author = (select auth.uid()) or public.in_close(author)));

-- message streaks between two friends (both wrote on consecutive days)
create or replace function public.dm_streaks() returns table (conv_id bigint, streak int) language sql stable security definer set search_path = '' as $$
  with my as (
    select c.id from public.conversations c join public.conversation_members m on m.conv_id = c.id and m.user_id = auth.uid() where not c.is_group
  ), days as (
    select ms.conv_id, (ms.created_at at time zone 'Asia/Tbilisi')::date as d, count(distinct ms.sender) as n
    from public.messages ms join my on my.id = ms.conv_id
    where ms.created_at > now() - interval '200 days' and ms.kind <> 'system'
    group by 1, 2
  ), both_days as (
    select conv_id, d, d - (row_number() over (partition by conv_id order by d))::int as grp from days where n >= 2
  ), runs as (
    select conv_id, max(d) as last_d, count(*)::int as len from both_days group by conv_id, grp
  )
  select conv_id, len from runs where last_d >= (now() at time zone 'Asia/Tbilisi')::date - 1 and len >= 2;
$$;

-- live rooms: virtual supra (video, tamada) and birja (voice)
create table public.rooms (
  id bigint generated always as identity primary key,
  host uuid not null references public.profiles(id) on delete cascade,
  kind text not null check (kind in ('supra','birja')),
  title text not null check (char_length(title) between 2 and 80),
  topic text not null default 'other' check (char_length(topic) <= 30),
  is_private boolean not null default false,
  live boolean not null default true,
  created_at timestamptz not null default now(),
  ended_at timestamptz
);
create index rooms_live_idx on public.rooms (created_at desc) where live;
alter table public.rooms enable row level security;
create policy "rooms visible" on public.rooms for select to authenticated using (
  not public.is_blocked(host, (select auth.uid())) and (not is_private or host = (select auth.uid()) or public.are_friends(host, (select auth.uid()))));
create policy "open room" on public.rooms for insert to authenticated with check (host = (select auth.uid()) and public.can_post() and live);
create policy "host updates room" on public.rooms for update to authenticated using (host = (select auth.uid())) with check (host = (select auth.uid()));
revoke update on public.rooms from authenticated;
grant update (title, topic, live, ended_at) on public.rooms to authenticated;
create or replace function public.invite_to_room(p_room bigint, p_users uuid[]) returns int language plpgsql security definer set search_path = '' as $$
declare r record; u uuid; n int := 0;
begin
  select * into r from public.rooms where id = p_room and live;
  if r is null then raise exception 'not_found'; end if;
  if r.host <> auth.uid() and not public.are_friends(r.host, auth.uid()) then raise exception 'not_allowed'; end if;
  foreach u in array p_users loop
    if public.are_friends(auth.uid(), u) then
      perform public.notify(u, auth.uid(), 'room_invite', jsonb_build_object('room', p_room, 'title', r.title, 'kind', r.kind));
      n := n + 1;
    end if;
  end loop;
  return n;
end $$;

-- match rooms: fixtures, coin predictions (shared pool), live chat
create table public.fixtures (
  id bigint generated always as identity primary key,
  league text not null default '' check (char_length(league) <= 60),
  home text not null check (char_length(home) between 2 and 60),
  away text not null check (char_length(away) between 2 and 60),
  starts_at timestamptz not null,
  status text not null default 'upcoming' check (status in ('upcoming','finished','cancelled')),
  home_score int check (home_score >= 0),
  away_score int check (away_score >= 0),
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);
create index fixtures_start_idx on public.fixtures (starts_at);
create table public.predictions (
  fixture_id bigint not null references public.fixtures(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  pick text not null check (pick in ('1','X','2')),
  stake int not null check (stake between 1 and 1000),
  payout int,
  created_at timestamptz not null default now(),
  primary key (fixture_id, user_id)
);
create table public.fixture_chat (
  id bigint generated always as identity primary key,
  fixture_id bigint not null references public.fixtures(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 500),
  created_at timestamptz not null default now()
);
create index fixture_chat_idx on public.fixture_chat (fixture_id, created_at desc);
alter table public.fixtures enable row level security;
alter table public.predictions enable row level security;
alter table public.fixture_chat enable row level security;
create policy "fixtures visible" on public.fixtures for select to authenticated using (true);
create policy "staff adds fixture" on public.fixtures for insert to authenticated with check (public.is_staff() and status = 'upcoming');
create policy "staff edits fixture" on public.fixtures for update to authenticated using (public.is_staff()) with check (public.is_staff());
revoke update on public.fixtures from authenticated;
grant update (league, home, away, starts_at) on public.fixtures to authenticated;
create policy "own predictions" on public.predictions for select to authenticated using (user_id = (select auth.uid()));
revoke insert, update on public.predictions from authenticated;
create policy "match chat visible" on public.fixture_chat for select to authenticated using (not public.is_blocked(user_id, (select auth.uid())));
create policy "write match chat" on public.fixture_chat for insert to authenticated with check (user_id = (select auth.uid()) and public.can_post());
create policy "staff clears match chat" on public.fixture_chat for delete to authenticated using (user_id = (select auth.uid()) or public.is_staff());
alter publication supabase_realtime add table public.fixture_chat;

create or replace function public.fixture_pool(p_fixture bigint) returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'n', count(*), 'total', coalesce(sum(stake), 0),
    '1', coalesce(sum(stake) filter (where pick = '1'), 0),
    'X', coalesce(sum(stake) filter (where pick = 'X'), 0),
    '2', coalesce(sum(stake) filter (where pick = '2'), 0))
  from public.predictions where fixture_id = p_fixture;
$$;
create or replace function public.predict(p_fixture bigint, p_pick text, p_stake int) returns int language plpgsql security definer set search_path = '' as $$
declare f record; bal int;
begin
  if not public.can_post() then raise exception 'not_allowed'; end if;
  select * into f from public.fixtures where id = p_fixture;
  if f is null or f.status <> 'upcoming' or f.starts_at <= now() then raise exception 'match_started'; end if;
  if p_pick not in ('1','X','2') or p_stake < 1 or p_stake > 1000 then raise exception 'bad_request'; end if;
  if exists(select 1 from public.predictions where fixture_id = p_fixture and user_id = auth.uid()) then raise exception 'already_predicted'; end if;
  bal := public.spend_coins(p_stake, 'პროგნოზი: ' || f.home || ' – ' || f.away);
  insert into public.predictions (fixture_id, user_id, pick, stake) values (p_fixture, auth.uid(), p_pick, p_stake);
  return bal;
end $$;
create or replace function public.admin_settle_fixture(p_fixture bigint, p_home int, p_away int) returns void language plpgsql security definer set search_path = '' as $$
declare f record; res text; total int; win int; p record; pay int;
begin
  if not public.is_staff() then raise exception 'staff_only'; end if;
  select * into f from public.fixtures where id = p_fixture for update;
  if f is null or f.status <> 'upcoming' then raise exception 'not_pending'; end if;
  if p_home < 0 or p_away < 0 then raise exception 'bad_request'; end if;
  res := case when p_home > p_away then '1' when p_home = p_away then 'X' else '2' end;
  select coalesce(sum(stake), 0), coalesce(sum(stake) filter (where pick = res), 0) into total, win from public.predictions where fixture_id = p_fixture;
  for p in select * from public.predictions where fixture_id = p_fixture loop
    pay := case when win = 0 then p.stake when p.pick = res then floor(p.stake::numeric * total / win)::int else 0 end;
    update public.predictions set payout = pay where fixture_id = p_fixture and user_id = p.user_id;
    if pay > 0 then
      update public.profiles set coins = coins + pay where id = p.user_id;
      insert into public.coin_log (user_id, amount, label) values (p.user_id, pay, case when win = 0 then 'პროგნოზის დაბრუნება' else 'მოგება: ' || f.home || ' – ' || f.away end);
    end if;
    perform public.notify(p.user_id, null, case when win = 0 then 'bet_refund' when p.pick = res then 'bet_won' else 'bet_lost' end,
      jsonb_build_object('fixture', p_fixture, 'match', f.home || ' – ' || f.away, 'score', p_home || ':' || p_away, 'coins', pay));
  end loop;
  update public.fixtures set status = 'finished', home_score = p_home, away_score = p_away where id = p_fixture;
end $$;
create or replace function public.admin_cancel_fixture(p_fixture bigint) returns void language plpgsql security definer set search_path = '' as $$
declare f record; p record;
begin
  if not public.is_staff() then raise exception 'staff_only'; end if;
  select * into f from public.fixtures where id = p_fixture for update;
  if f is null or f.status <> 'upcoming' then raise exception 'not_pending'; end if;
  for p in select * from public.predictions where fixture_id = p_fixture loop
    update public.predictions set payout = p.stake where fixture_id = p_fixture and user_id = p.user_id;
    update public.profiles set coins = coins + p.stake where id = p.user_id;
    insert into public.coin_log (user_id, amount, label) values (p.user_id, p.stake, 'პროგნოზის დაბრუნება');
    perform public.notify(p.user_id, null, 'bet_refund', jsonb_build_object('fixture', p_fixture, 'match', f.home || ' – ' || f.away, 'coins', p.stake));
  end loop;
  update public.fixtures set status = 'cancelled' where id = p_fixture;
end $$;

-- ride sharing between cities
create table public.rides (
  id bigint generated always as identity primary key,
  driver uuid not null references public.profiles(id) on delete cascade,
  from_city text not null check (char_length(from_city) between 2 and 60),
  to_city text not null check (char_length(to_city) between 2 and 60),
  depart_at timestamptz not null,
  seats int not null check (seats between 1 and 8),
  price numeric(8,2) not null default 0 check (price >= 0),
  car text not null default '' check (char_length(car) <= 60),
  note text not null default '' check (char_length(note) <= 500),
  status text not null default 'open' check (status in ('open','cancelled')),
  created_at timestamptz not null default now()
);
create index rides_route_idx on public.rides (depart_at, from_city, to_city);
create table public.ride_bookings (
  ride_id bigint not null references public.rides(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  seats int not null default 1 check (seats between 1 and 8),
  status text not null default 'pending' check (status in ('pending','accepted','declined','cancelled')),
  created_at timestamptz not null default now(),
  primary key (ride_id, user_id)
);
alter table public.rides enable row level security;
alter table public.ride_bookings enable row level security;
create policy "rides visible" on public.rides for select to authenticated using (not public.is_blocked(driver, (select auth.uid())));
create policy "offer ride" on public.rides for insert to authenticated with check (driver = (select auth.uid()) and public.can_post() and status = 'open' and depart_at > now());
create policy "driver edits ride" on public.rides for update to authenticated using (driver = (select auth.uid())) with check (driver = (select auth.uid()));
revoke update on public.rides from authenticated;
grant update (depart_at, seats, price, car, note, status) on public.rides to authenticated;
create policy "bookings visible" on public.ride_bookings for select to authenticated using (
  user_id = (select auth.uid()) or exists(select 1 from public.rides r where r.id = ride_id and r.driver = (select auth.uid())));
revoke insert, update on public.ride_bookings from authenticated;

create or replace function public.ride_seats_left(p_ride bigint) returns int language sql stable security definer set search_path = '' as $$
  select r.seats - coalesce((select sum(b.seats) from public.ride_bookings b where b.ride_id = r.id and b.status = 'accepted'), 0)::int from public.rides r where r.id = p_ride;
$$;
create or replace function public.ride_list(p_from text default null, p_to text default null, p_day date default null, p_mine boolean default false)
returns table (id bigint, driver uuid, from_city text, to_city text, depart_at timestamptz, seats int, seats_left int, price numeric, car text, note text, status text, my_status text, pending int)
language sql stable security definer set search_path = '' as $$
  select r.id, r.driver, r.from_city, r.to_city, r.depart_at, r.seats, public.ride_seats_left(r.id), r.price, r.car, r.note, r.status,
    (select b.status from public.ride_bookings b where b.ride_id = r.id and b.user_id = auth.uid()),
    case when r.driver = auth.uid() then (select count(*)::int from public.ride_bookings b where b.ride_id = r.id and b.status = 'pending') else 0 end
  from public.rides r
  where not public.is_blocked(r.driver, auth.uid())
    and (case when p_mine then (r.driver = auth.uid() or exists(select 1 from public.ride_bookings b where b.ride_id = r.id and b.user_id = auth.uid())) and r.depart_at > now() - interval '2 days'
         else r.status = 'open' and r.depart_at > now() - interval '1 hour' end)
    and (p_from is null or p_from = '' or r.from_city ilike p_from)
    and (p_to is null or p_to = '' or r.to_city ilike p_to)
    and (p_day is null or (r.depart_at at time zone 'Asia/Tbilisi')::date = p_day)
  order by r.depart_at limit 60;
$$;
create or replace function public.book_ride(p_ride bigint, p_seats int) returns void language plpgsql security definer set search_path = '' as $$
declare r record;
begin
  if not public.can_post() then raise exception 'not_allowed'; end if;
  select * into r from public.rides where id = p_ride;
  if r is null or r.status <> 'open' or r.depart_at <= now() then raise exception 'ride_closed'; end if;
  if r.driver = auth.uid() or public.is_blocked(r.driver, auth.uid()) then raise exception 'not_allowed'; end if;
  if p_seats < 1 or p_seats > public.ride_seats_left(p_ride) then raise exception 'no_seats'; end if;
  insert into public.ride_bookings (ride_id, user_id, seats, status) values (p_ride, auth.uid(), p_seats, 'pending')
    on conflict (ride_id, user_id) do update set seats = excluded.seats, status = 'pending', created_at = now();
  perform public.notify(r.driver, auth.uid(), 'ride_req', jsonb_build_object('ride', p_ride, 'route', r.from_city || ' → ' || r.to_city, 'seats', p_seats));
end $$;
create or replace function public.respond_booking(p_ride bigint, p_user uuid, p_accept boolean) returns void language plpgsql security definer set search_path = '' as $$
declare r record; b record;
begin
  select * into r from public.rides where id = p_ride and driver = auth.uid();
  if r is null then raise exception 'not_allowed'; end if;
  select * into b from public.ride_bookings where ride_id = p_ride and user_id = p_user;
  if b is null or b.status not in ('pending','accepted') then raise exception 'not_pending'; end if;
  if p_accept and b.status = 'pending' and b.seats > public.ride_seats_left(p_ride) then raise exception 'no_seats'; end if;
  update public.ride_bookings set status = case when p_accept then 'accepted' else 'declined' end where ride_id = p_ride and user_id = p_user;
  perform public.notify(p_user, auth.uid(), case when p_accept then 'ride_ok' else 'ride_no' end, jsonb_build_object('ride', p_ride, 'route', r.from_city || ' → ' || r.to_city));
end $$;
create or replace function public.cancel_booking(p_ride bigint) returns void language plpgsql security definer set search_path = '' as $$
declare r record;
begin
  select * into r from public.rides where id = p_ride;
  update public.ride_bookings set status = 'cancelled' where ride_id = p_ride and user_id = auth.uid() and status in ('pending','accepted');
  if found and r is not null then perform public.notify(r.driver, auth.uid(), 'ride_cancel', jsonb_build_object('ride', p_ride, 'route', r.from_city || ' → ' || r.to_city)); end if;
end $$;

-- jobs, applications and CVs
create table public.jobs (
  id bigint generated always as identity primary key,
  poster uuid not null references public.profiles(id) on delete cascade,
  page_id bigint references public.pages(id) on delete set null,
  title text not null check (char_length(title) between 3 and 100),
  company text not null default '' check (char_length(company) <= 80),
  city text not null default '' check (char_length(city) <= 60),
  job_type text not null default 'full' check (job_type in ('full','part','remote','intern','freelance')),
  category text not null default 'other' check (char_length(category) <= 30),
  salary_from int check (salary_from >= 0),
  salary_to int check (salary_to >= 0),
  description text not null default '' check (char_length(description) <= 4000),
  status text not null default 'open' check (status in ('open','closed')),
  hidden boolean not null default false,
  created_at timestamptz not null default now()
);
create index jobs_created_idx on public.jobs (created_at desc);
create table public.job_applications (
  job_id bigint not null references public.jobs(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  cover text not null default '' check (char_length(cover) <= 2000),
  status text not null default 'new' check (status in ('new','seen','invited','rejected')),
  created_at timestamptz not null default now(),
  primary key (job_id, user_id)
);
create table public.cvs (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  headline text not null default '' check (char_length(headline) <= 120),
  summary text not null default '' check (char_length(summary) <= 2000),
  experience jsonb not null default '[]',
  education jsonb not null default '[]',
  skills text[] not null default '{}',
  languages text[] not null default '{}',
  phone text not null default '' check (char_length(phone) <= 30),
  visible boolean not null default false,
  updated_at timestamptz not null default now()
);
alter table public.jobs enable row level security;
alter table public.job_applications enable row level security;
alter table public.cvs enable row level security;
create policy "jobs visible" on public.jobs for select to authenticated using ((not hidden or poster = (select auth.uid()) or public.is_staff()) and not public.is_blocked(poster, (select auth.uid())));
create policy "post job" on public.jobs for insert to authenticated with check (poster = (select auth.uid()) and public.can_post() and hidden = false and (page_id is null or public.owns_page(page_id)));
create policy "poster edits job" on public.jobs for update to authenticated using (poster = (select auth.uid())) with check (poster = (select auth.uid()));
create policy "poster or staff removes job" on public.jobs for delete to authenticated using (poster = (select auth.uid()) or public.is_staff());
revoke update on public.jobs from authenticated;
grant update (title, company, city, job_type, category, salary_from, salary_to, description, status) on public.jobs to authenticated;
create or replace function public.posted_job(j bigint) returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.jobs where id = j and poster = auth.uid());
$$;
create policy "applications visible" on public.job_applications for select to authenticated using (user_id = (select auth.uid()) or public.posted_job(job_id));
create policy "apply" on public.job_applications for insert to authenticated with check (
  user_id = (select auth.uid()) and status = 'new' and public.can_post()
  and exists(select 1 from public.jobs j where j.id = job_id and j.status = 'open' and j.poster <> (select auth.uid())));
create policy "poster reviews application" on public.job_applications for update to authenticated using (public.posted_job(job_id)) with check (public.posted_job(job_id));
create policy "withdraw application" on public.job_applications for delete to authenticated using (user_id = (select auth.uid()));
revoke update on public.job_applications from authenticated;
grant update (status) on public.job_applications to authenticated;
create or replace function public.applied_to_me(u uuid) returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.job_applications a join public.jobs j on j.id = a.job_id where a.user_id = u and j.poster = auth.uid());
$$;
create policy "cv visible" on public.cvs for select to authenticated using (user_id = (select auth.uid()) or visible or public.applied_to_me(user_id));
create policy "write own cv" on public.cvs for insert to authenticated with check (user_id = (select auth.uid()));
create policy "edit own cv" on public.cvs for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create or replace function public.trg_job_application() returns trigger language plpgsql security definer set search_path = '' as $$
declare j record;
begin
  select * into j from public.jobs where id = new.job_id;
  if tg_op = 'INSERT' then
    perform public.notify(j.poster, new.user_id, 'job_apply', jsonb_build_object('job', new.job_id, 'title', j.title));
  elsif new.status is distinct from old.status and new.status in ('invited','rejected') then
    perform public.notify(new.user_id, j.poster, case when new.status = 'invited' then 'job_invited' else 'job_rejected' end, jsonb_build_object('job', new.job_id, 'title', j.title));
  end if;
  return new;
end $$;
create trigger job_applications_notify after insert or update on public.job_applications for each row execute function public.trg_job_application();
revoke execute on function public.trg_job_application(), public.posts_schedule() from public, anon, authenticated;

create or replace function public.admin_hide(p_type text, p_id bigint, p_hidden boolean) returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_staff() then raise exception 'staff_only'; end if;
  if p_type = 'post' then update public.posts set hidden = p_hidden where id = p_id;
  elsif p_type = 'comment' then update public.comments set hidden = p_hidden where id = p_id;
  elsif p_type = 'listing' then update public.listings set hidden = p_hidden where id = p_id;
  elsif p_type = 'job' then update public.jobs set hidden = p_hidden where id = p_id;
  else raise exception 'bad_type'; end if;
end $$;

-- lock down the new functions the same way as the rest
do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as sig from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname in ('join_place_groups','trending_tags','my_memories','in_close','dm_streaks','invite_to_room','fixture_pool','predict',
      'admin_settle_fixture','admin_cancel_fixture','ride_seats_left','ride_list','book_ride','respond_booking','cancel_booking','posted_job','applied_to_me','admin_hide')
  loop
    execute format('revoke execute on function %s from public, anon', f.sig);
    execute format('grant execute on function %s to authenticated', f.sig);
  end loop;
end $$;
