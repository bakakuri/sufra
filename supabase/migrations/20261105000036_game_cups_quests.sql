-- the day's tasks paying coins, friends' cups and group duels.
-- run after fair_game_ratings.sql: a cup match is decided by the result of its rated online game in game_matches.

-- ---------- the day's tasks: up to three paid a day, each once ----------
create table if not exists public.game_quests (
  user_id uuid not null references public.profiles(id) on delete cascade,
  day text not null check (day ~ '^\d{4}-\d{2}-\d{2}$'),
  quest text not null check (quest ~ '^[a-z0-9]{2,12}$'),
  created_at timestamptz not null default now(),
  primary key (user_id, day, quest)
);
alter table public.game_quests enable row level security;
drop policy if exists "own quests" on public.game_quests;
create policy "own quests" on public.game_quests for select to authenticated using (user_id = (select auth.uid()));

create or replace function public.game_quest(p_day text, p_quest text)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare me uuid := auth.uid(); today text := to_char(now() at time zone 'Asia/Tbilisi', 'YYYY-MM-DD'); n int; c int; price int;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if p_day <> today then raise exception 'not_today'; end if;
  price := case p_quest when 'win3' then 20 when 'nardi' then 15 when 'chess' then 15 when 'shashi' then 15 when 'joker' then 15 when 'durak' then 15
    when 'bura' then 20 when 'domino' then 20 when 'egg' then 10 when 'loto' then 10 when 'pz' then 15 when 'sprint' then 20 when 'online' then 20 when 'mars' then 25 when 'three' then 20 else null end;
  if price is null then raise exception 'bad_quest'; end if;
  select count(*) into n from public.game_quests where user_id = me and day = today;
  if n >= 3 then raise exception 'quests_done'; end if;
  insert into public.game_quests (user_id, day, quest) values (me, today, p_quest) on conflict do nothing;
  if not found then select coins into c from public.profiles where id = me; return jsonb_build_object('coins', c, 'paid', false); end if;
  update public.profiles set coins = coins + price where id = me returning coins into c;
  insert into public.coin_log (user_id, amount, label) values (me, price, 'დავალება: ' || p_quest);
  return jsonb_build_object('coins', c, 'paid', true);
end $$;
revoke all on function public.game_quest(text, text) from public, anon;
grant execute on function public.game_quest(text, text) to authenticated;

-- ---------- cups among friends, and duels between two groups ----------
create table if not exists public.game_cups (
  id bigint generated always as identity primary key,
  host uuid not null references public.profiles(id) on delete cascade,
  kind text not null default 'cup' check (kind in ('cup', 'duel')),
  game text not null check (game in ('nardi', 'shashi', 'chess')),
  name text not null check (char_length(name) between 2 and 60),
  size int not null default 8 check (size between 2 and 16),
  group_a bigint references public.groups(id) on delete cascade,
  group_b bigint references public.groups(id) on delete cascade,
  status text not null default 'open' check (status in ('open', 'play', 'done', 'closed')),
  winner uuid references public.profiles(id) on delete set null,
  team_win text check (team_win in ('a', 'b', 'draw')),
  created_at timestamptz not null default now(),
  check (kind = 'cup' and group_a is null and group_b is null or kind = 'duel' and group_a is not null and group_b is not null and group_a <> group_b)
);
create table if not exists public.game_cup_players (
  cup_id bigint not null references public.game_cups(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  team text check (team in ('a', 'b')),
  joined_at timestamptz not null default now(),
  primary key (cup_id, user_id)
);
create table if not exists public.game_cup_matches (
  id bigint generated always as identity primary key,
  cup_id bigint not null references public.game_cups(id) on delete cascade,
  round int not null,
  slot int not null,
  p1 uuid references public.profiles(id) on delete set null,
  p2 uuid references public.profiles(id) on delete set null,
  gid text,
  winner uuid references public.profiles(id) on delete set null,
  status text not null default 'wait' check (status in ('wait', 'done')),
  unique (cup_id, round, slot)
);
alter table public.game_cups enable row level security;
alter table public.game_cup_players enable row level security;
alter table public.game_cup_matches enable row level security;
drop policy if exists "cups are visible" on public.game_cups;
create policy "cups are visible" on public.game_cups for select to authenticated using (not public.is_blocked(host, (select auth.uid())));
drop policy if exists "cup players are visible" on public.game_cup_players;
create policy "cup players are visible" on public.game_cup_players for select to authenticated using (true);
drop policy if exists "cup matches are visible" on public.game_cup_matches;
create policy "cup matches are visible" on public.game_cup_matches for select to authenticated using (true);
create index if not exists game_cups_recent on public.game_cups (created_at desc);
create index if not exists game_cup_players_user on public.game_cup_players (user_id);

create or replace function private.group_admin(p_group bigint, p_user uuid) returns boolean language sql stable security definer set search_path to '' as $$
  select exists (select 1 from public.groups g where g.id = p_group and g.owner = p_user)
      or exists (select 1 from public.group_members m where m.group_id = p_group and m.user_id = p_user and m.role in ('owner', 'admin'))
$$;
create or replace function private.group_member(p_group bigint, p_user uuid) returns boolean language sql stable security definer set search_path to '' as $$
  select exists (select 1 from public.groups g where g.id = p_group and g.owner = p_user)
      or exists (select 1 from public.group_members m where m.group_id = p_group and m.user_id = p_user)
$$;

create or replace function public.cup_create(p_kind text, p_game text, p_name text, p_size int, p_group_a bigint default null, p_group_b bigint default null)
returns bigint language plpgsql security definer set search_path to '' as $$
declare me uuid := auth.uid(); new_id bigint; n int;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  select count(*) into n from public.game_cups where host = me and created_at > now() - interval '1 day';
  if n >= 5 then raise exception 'too_many'; end if;
  if p_kind = 'cup' then
    if p_size not in (4, 8, 16) then raise exception 'bad_size'; end if;
    insert into public.game_cups (host, kind, game, name, size) values (me, 'cup', p_game, p_name, p_size) returning game_cups.id into new_id;
    insert into public.game_cup_players (cup_id, user_id) values (new_id, me);
  elsif p_kind = 'duel' then
    if p_size not in (3, 5, 7) then raise exception 'bad_size'; end if;
    if not private.group_admin(p_group_a, me) then raise exception 'not_admin'; end if;
    if exists (select 1 from public.groups where id = p_group_b and is_private) then raise exception 'private_group'; end if;
    insert into public.game_cups (host, kind, game, name, size, group_a, group_b) values (me, 'duel', p_game, p_name, p_size, p_group_a, p_group_b) returning game_cups.id into new_id;
    insert into public.game_cup_players (cup_id, user_id, team) values (new_id, me, 'a');
  else raise exception 'bad_kind'; end if;
  return new_id;
end $$;

create or replace function public.cup_join(p_cup bigint, p_team text default null)
returns void language plpgsql security definer set search_path to '' as $$
declare me uuid := auth.uid(); c public.game_cups; n int;
begin
  select * into c from public.game_cups where id = p_cup for update;
  if c.id is null or c.status <> 'open' or public.is_blocked(c.host, me) then raise exception 'not_allowed'; end if;
  if c.kind = 'cup' then
    if me <> c.host and not public.are_friends(c.host, me) then raise exception 'friends_only'; end if;
    select count(*) into n from public.game_cup_players where cup_id = c.id;
    if n >= c.size then raise exception 'full'; end if;
    insert into public.game_cup_players (cup_id, user_id) values (c.id, me) on conflict do nothing;
  else
    if p_team not in ('a', 'b') then raise exception 'bad_team'; end if;
    if not private.group_member(case when p_team = 'a' then c.group_a else c.group_b end, me) then raise exception 'not_member'; end if;
    select count(*) into n from public.game_cup_players where cup_id = c.id and team = p_team;
    if n >= c.size then raise exception 'full'; end if;
    insert into public.game_cup_players (cup_id, user_id, team) values (c.id, me, p_team) on conflict do nothing;
  end if;
end $$;

create or replace function public.cup_leave(p_cup bigint)
returns void language sql security definer set search_path to '' as $$
  delete from public.game_cup_players p using public.game_cups c
  where p.cup_id = p_cup and p.user_id = auth.uid() and c.id = p.cup_id and c.status = 'open' and c.host <> auth.uid()
$$;

/* the host starts: a cup draws a bracket (byes for the missing places), a duel pairs the two teams in joining order */
create or replace function public.cup_start(p_cup bigint)
returns void language plpgsql security definer set search_path to '' as $$
declare me uuid := auth.uid(); c public.game_cups; ps uuid[]; pa uuid[]; pb uuid[]; sz int := 2; i int;
begin
  select * into c from public.game_cups where id = p_cup for update;
  if c.id is null or c.host <> me or c.status <> 'open' then raise exception 'not_allowed'; end if;
  if c.kind = 'cup' then
    select array_agg(user_id order by random()) into ps from public.game_cup_players where cup_id = c.id;
    if coalesce(array_length(ps, 1), 0) < 2 then raise exception 'too_few'; end if;
    while sz < array_length(ps, 1) loop sz := sz * 2; end loop;
    for i in 0 .. sz / 2 - 1 loop
      insert into public.game_cup_matches (cup_id, round, slot, p1, p2) values (c.id, 1, i, ps[i * 2 + 1], ps[i * 2 + 2]);
    end loop;
    /* a bye: the lone player goes straight through */
    update public.game_cup_matches set winner = coalesce(p1, p2), status = 'done' where cup_id = c.id and round = 1 and (p1 is null or p2 is null);
    perform private.cup_advance(c.id);
  else
    select array_agg(user_id order by joined_at) into pa from public.game_cup_players where cup_id = c.id and team = 'a';
    select array_agg(user_id order by joined_at) into pb from public.game_cup_players where cup_id = c.id and team = 'b';
    if coalesce(array_length(pa, 1), 0) < 1 or coalesce(array_length(pb, 1), 0) < 1 then raise exception 'too_few'; end if;
    for i in 1 .. least(array_length(pa, 1), array_length(pb, 1)) loop
      insert into public.game_cup_matches (cup_id, round, slot, p1, p2) values (c.id, 1, i - 1, pa[i], pb[i]);
    end loop;
  end if;
  update public.game_cups set status = 'play' where id = c.id;
end $$;

/* winners of a round meet in the next; the last winner takes the cup */
create or replace function private.cup_advance(p_cup bigint)
returns void language plpgsql security definer set search_path to '' as $$
declare r int; n int; m record;
begin
  select max(round) into r from public.game_cup_matches where cup_id = p_cup;
  loop
    select count(*) into n from public.game_cup_matches where cup_id = p_cup and round = r;
    if exists (select 1 from public.game_cup_matches where cup_id = p_cup and round = r and status <> 'done') then return; end if;
    if n = 1 then update public.game_cups set status = 'done', winner = (select winner from public.game_cup_matches where cup_id = p_cup and round = r) where id = p_cup; return; end if;
    for m in select slot, winner from public.game_cup_matches where cup_id = p_cup and round = r order by slot loop
      insert into public.game_cup_matches (cup_id, round, slot) values (p_cup, r + 1, m.slot / 2) on conflict do nothing;
      if m.slot % 2 = 0 then update public.game_cup_matches set p1 = m.winner where cup_id = p_cup and round = r + 1 and slot = m.slot / 2;
      else update public.game_cup_matches set p2 = m.winner where cup_id = p_cup and round = r + 1 and slot = m.slot / 2; end if;
    end loop;
    /* the whole round is decided, so an empty place in the next one is a bye */
    update public.game_cup_matches set winner = coalesce(p1, p2), status = 'done' where cup_id = p_cup and round = r + 1 and (p1 is null or p2 is null);
    r := r + 1;
  end loop;
end $$;

/* a player of the match names the online game it is played in */
create or replace function public.cup_gid(p_match bigint, p_gid text)
returns void language plpgsql security definer set search_path to '' as $$
declare me uuid := auth.uid(); m public.game_cup_matches;
begin
  if p_gid !~ '^g[a-z0-9]{4,14}$' then raise exception 'bad_gid'; end if;
  select * into m from public.game_cup_matches where id = p_match for update;
  if m.id is null or m.status <> 'wait' or me not in (m.p1, m.p2) then raise exception 'not_allowed'; end if;
  update public.game_cup_matches set gid = p_gid where id = m.id;
end $$;

/* the match is decided by its game's agreed result; a draw or a void game means playing again */
create or replace function public.cup_settle(p_match bigint)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare m public.game_cup_matches; g public.game_matches; c public.game_cups; w uuid; a int; b int;
begin
  select * into m from public.game_cup_matches where id = p_match for update;
  if m.id is null or m.status <> 'wait' or m.gid is null then return jsonb_build_object('done', m.status = 'done'); end if;
  select * into g from public.game_matches where gid = m.gid;
  if g.id is null or g.result is null then return jsonb_build_object('done', false, 'pending', true); end if;
  if not ((g.p1 = m.p1 and g.p2 = m.p2) or (g.p1 = m.p2 and g.p2 = m.p1)) then update public.game_cup_matches set gid = null where id = m.id; return jsonb_build_object('done', false); end if;
  w := case when g.result = 1 then g.p1 when g.result = -1 then g.p2 else null end;
  if w is null then update public.game_cup_matches set gid = null where id = m.id; return jsonb_build_object('done', false, 'again', true); end if;
  update public.game_cup_matches set winner = w, status = 'done' where id = m.id;
  select * into c from public.game_cups where id = m.cup_id;
  if c.kind = 'cup' then perform private.cup_advance(c.id);
  elsif not exists (select 1 from public.game_cup_matches where cup_id = c.id and status <> 'done') then
    select count(*) filter (where winner = p1), count(*) filter (where winner = p2) into a, b from public.game_cup_matches where cup_id = c.id;
    update public.game_cups set status = 'done', team_win = case when a > b then 'a' when b > a then 'b' else 'draw' end where id = c.id;
  end if;
  return jsonb_build_object('done', true, 'winner', w);
end $$;

revoke all on function public.cup_create(text, text, text, int, bigint, bigint) from public, anon;
revoke all on function public.cup_join(bigint, text) from public, anon;
revoke all on function public.cup_leave(bigint) from public, anon;
revoke all on function public.cup_start(bigint) from public, anon;
revoke all on function public.cup_gid(bigint, text) from public, anon;
revoke all on function public.cup_settle(bigint) from public, anon;
grant execute on function public.cup_create(text, text, text, int, bigint, bigint) to authenticated;
grant execute on function public.cup_join(bigint, text) to authenticated;
grant execute on function public.cup_leave(bigint) to authenticated;
grant execute on function public.cup_start(bigint) to authenticated;
grant execute on function public.cup_gid(bigint, text) to authenticated;
grant execute on function public.cup_settle(bigint) to authenticated;

-- the cup page follows its bracket live
do $$ begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'game_cup_matches') then alter publication supabase_realtime add table public.game_cup_matches; end if;
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'game_cup_players') then alter publication supabase_realtime add table public.game_cup_players; end if;
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'game_cups') then alter publication supabase_realtime add table public.game_cups; end if;
  end if;
end $$;
