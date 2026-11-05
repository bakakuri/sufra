-- per-game ratings that change only when both players took part, a monthly season, and a character to sit at the tables
alter table public.profiles add column if not exists look jsonb;
alter table public.profiles drop constraint if exists profiles_look_ok;
alter table public.profiles add constraint profiles_look_ok check (look is null or (jsonb_typeof(look) = 'object' and pg_column_size(look) < 600));
grant update (look) on public.profiles to authenticated;

create table if not exists public.game_ratings (
  user_id uuid not null references public.profiles(id) on delete cascade,
  game text not null check (game in ('nardi','shashi','chess','joker')),
  rating int not null default 1500,
  games int not null default 0,
  wins int not null default 0,
  season text not null default to_char(now() at time zone 'Asia/Tbilisi', 'YYYY-MM'),
  season_pts int not null default 0,
  season_games int not null default 0,
  updated_at timestamptz not null default now(),
  primary key (user_id, game)
);
alter table public.game_ratings enable row level security;
drop policy if exists "game ratings are public" on public.game_ratings;
create policy "game ratings are public" on public.game_ratings for select to authenticated using (true);
create index if not exists game_ratings_top on public.game_ratings (game, rating desc);
create index if not exists game_ratings_season on public.game_ratings (game, season, season_pts desc);

create table if not exists public.game_matches (
  id bigint generated always as identity primary key,
  gid text not null unique check (gid ~ '^g[a-z0-9]{4,14}$'),
  game text not null check (game in ('nardi','shashi','chess')),
  p1 uuid not null references public.profiles(id) on delete cascade,
  p2 uuid not null references public.profiles(id) on delete cascade,
  seen1 boolean not null default false,
  seen2 boolean not null default false,
  rated boolean not null default true,
  r1 smallint check (r1 in (1,-1,2)),
  r2 smallint check (r2 in (1,-1,2)),
  t1 timestamptz,
  t2 timestamptz,
  result smallint,
  d1 int,
  d2 int,
  created_at timestamptz not null default now(),
  finished_at timestamptz,
  check (p1 <> p2)
);
alter table public.game_matches enable row level security;
drop policy if exists "players see their matches" on public.game_matches;
create policy "players see their matches" on public.game_matches for select to authenticated using (auth.uid() = p1 or auth.uid() = p2);
create index if not exists game_matches_p1 on public.game_matches (p1, created_at desc);
create index if not exists game_matches_p2 on public.game_matches (p2, created_at desc);

-- both phones call this when the game opens; a pair counts for rating at most five times a day
create or replace function public.match_meet(p_gid text, p_game text, p_opp uuid, p_side int)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare me uuid := auth.uid(); m public.game_matches; a uuid; b uuid; n int;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if p_gid !~ '^g[a-z0-9]{4,14}$' or p_game not in ('nardi','shashi','chess') or p_side not in (1,-1) or p_opp is null or p_opp = me then raise exception 'bad_match'; end if;
  if not exists (select 1 from public.profiles where id = p_opp) or public.is_blocked(me, p_opp) then raise exception 'not_allowed'; end if;
  if p_side = 1 then a := me; b := p_opp; else a := p_opp; b := me; end if;
  select * into m from public.game_matches where gid = p_gid for update;
  if m.id is null then
    select count(*) into n from public.game_matches where rated and created_at > now() - interval '1 day' and ((p1 = a and p2 = b) or (p1 = b and p2 = a));
    insert into public.game_matches (gid, game, p1, p2, seen1, seen2, rated) values (p_gid, p_game, a, b, p_side = 1, p_side = -1, n < 5)
      on conflict (gid) do nothing returning * into m;
    if m.id is not null then return jsonb_build_object('id', m.id, 'rated', m.rated); end if;
    select * into m from public.game_matches where gid = p_gid for update;
  end if;
  if m.game <> p_game or m.p1 <> a or m.p2 <> b or m.result is not null then raise exception 'bad_match'; end if;
  if p_side = 1 then update public.game_matches set seen1 = true where id = m.id; else update public.game_matches set seen2 = true where id = m.id; end if;
  return jsonb_build_object('id', m.id, 'rated', m.rated);
end $$;

create or replace function private.match_apply(p_id bigint, p_res smallint)
returns void language plpgsql security definer set search_path to '' as $$
declare m public.game_matches; ra public.game_ratings; rb public.game_ratings; s1 numeric; e1 numeric; k1 int; k2 int; v1 int := 0; v2 int := 0;
  cur text := to_char(now() at time zone 'Asia/Tbilisi', 'YYYY-MM'); w uuid; wins_today int;
begin
  select * into m from public.game_matches where id = p_id for update;
  if m.id is null or m.result is not null then return; end if;
  if p_res is null or p_res not in (1,-1,2) then update public.game_matches set result = 0, d1 = 0, d2 = 0, finished_at = now() where id = m.id; return; end if;
  if not (m.rated and m.seen1 and m.seen2) then update public.game_matches set result = p_res, d1 = 0, d2 = 0, finished_at = now() where id = m.id; return; end if;
  insert into public.game_ratings (user_id, game) values (m.p1, m.game), (m.p2, m.game) on conflict do nothing;
  select * into ra from public.game_ratings where user_id = m.p1 and game = m.game for update;
  select * into rb from public.game_ratings where user_id = m.p2 and game = m.game for update;
  s1 := case p_res when 1 then 1 when -1 then 0 else 0.5 end;
  e1 := 1 / (1 + power(10::numeric, (rb.rating - ra.rating) / 400.0));
  k1 := case when ra.games < 20 then 32 else 20 end;
  k2 := case when rb.games < 20 then 32 else 20 end;
  v1 := round(k1 * (s1 - e1)); v2 := round(k2 * ((1 - s1) - (1 - e1)));
  update public.game_ratings set rating = greatest(100, rating + v1), games = games + 1, wins = wins + (p_res = 1)::int,
    season_pts = (case when season = cur then season_pts else 0 end) + v1, season_games = (case when season = cur then season_games else 0 end) + 1, season = cur, updated_at = now()
    where user_id = m.p1 and game = m.game;
  update public.game_ratings set rating = greatest(100, rating + v2), games = games + 1, wins = wins + (p_res = -1)::int,
    season_pts = (case when season = cur then season_pts else 0 end) + v2, season_games = (case when season = cur then season_games else 0 end) + 1, season = cur, updated_at = now()
    where user_id = m.p2 and game = m.game;
  update public.game_matches set result = p_res, d1 = v1, d2 = v2, finished_at = now() where id = m.id;
  update public.profiles p set rating = (select max(g.rating) from public.game_ratings g where g.user_id = p.id) where p.id in (m.p1, m.p2);
  if p_res in (1,-1) then
    w := case when p_res = 1 then m.p1 else m.p2 end;
    select count(*) into wins_today from public.coin_log where user_id = w and label like 'მოგება:%' and created_at > now() - interval '1 day';
    if wins_today < 10 then
      update public.profiles set coins = coins + 10 where id = w;
      insert into public.coin_log (user_id, amount, label) values (w, 10, 'მოგება: ' || m.game);
    end if;
  end if;
end $$;

create or replace function private.match_view(p_id bigint, p_me uuid)
returns jsonb language sql security definer set search_path to '' as $$
  select jsonb_build_object('result', m.result, 'rated', m.rated and m.seen1 and m.seen2, 'pending', m.result is null,
    'delta', case when p_me = m.p1 then m.d1 else m.d2 end,
    'rating', (select g.rating from public.game_ratings g where g.user_id = p_me and g.game = m.game))
  from public.game_matches m where m.id = p_id
$$;

-- each player says how the game ended (1: side one won, -1: side two won, 2: a draw).
-- admitting a loss counts at once; otherwise both must say the same; if they disagree the game does not count
create or replace function public.match_report(p_gid text, p_res int)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare me uuid := auth.uid(); m public.game_matches;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if p_res not in (1,-1,2) then raise exception 'bad_result'; end if;
  select * into m from public.game_matches where gid = p_gid for update;
  if m.id is null or me not in (m.p1, m.p2) then raise exception 'not_allowed'; end if;
  if m.result is null then
    if me = m.p1 then update public.game_matches set r1 = p_res, t1 = now() where id = m.id returning * into m;
    else update public.game_matches set r2 = p_res, t2 = now() where id = m.id returning * into m; end if;
    if (me = m.p1 and p_res = -1) or (me = m.p2 and p_res = 1) then perform private.match_apply(m.id, p_res::smallint);
    elsif m.r1 is not null and m.r2 is not null then
      if m.r1 = m.r2 then perform private.match_apply(m.id, m.r1); else perform private.match_apply(m.id, 0::smallint); end if;
    end if;
  end if;
  return private.match_view(m.id, me);
end $$;

-- a claim the other player never answered counts after two minutes; a game nobody finished closes after a day
create or replace function public.match_settle_mine()
returns int language plpgsql security definer set search_path to '' as $$
declare me uuid := auth.uid(); m record; n int := 0;
begin
  if me is null then return 0; end if;
  for m in select * from public.game_matches where result is null and (p1 = me or p2 = me) order by id limit 20 loop
    if m.r1 is not null and m.r2 is null and m.t1 < now() - interval '2 minutes' then perform private.match_apply(m.id, m.r1); n := n + 1;
    elsif m.r2 is not null and m.r1 is null and m.t2 < now() - interval '2 minutes' then perform private.match_apply(m.id, m.r2); n := n + 1;
    elsif m.r1 is null and m.r2 is null and m.created_at < now() - interval '1 day' then update public.game_matches set result = 0, d1 = 0, d2 = 0, finished_at = now() where id = m.id; n := n + 1;
    end if;
  end loop;
  return n;
end $$;

-- games against the computer only give coins now; rating comes from games with people
create or replace function public.game_result(p_game text, p_win boolean)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare wins_today int; c int; r int; reward int := 0;
begin
  if auth.uid() is null then raise exception 'not_signed_in'; end if;
  select count(*) into wins_today from public.coin_log where user_id = auth.uid() and label like 'მოგება:%' and created_at > now() - interval '1 day';
  if p_win and wins_today < 10 then reward := 5; end if;
  if reward > 0 then
    update public.profiles set coins = coins + reward where id = auth.uid();
    insert into public.coin_log (user_id, amount, label) values (auth.uid(), reward, 'მოგება: ' || left(p_game, 30));
  end if;
  select coins, rating into c, r from public.profiles where id = auth.uid();
  return jsonb_build_object('rating', r, 'coins', c, 'reward', reward);
end $$;

revoke all on function private.match_apply(bigint, smallint) from public, anon, authenticated;
revoke all on function private.match_view(bigint, uuid) from public, anon, authenticated;
revoke all on function public.match_meet(text, text, uuid, int) from public, anon;
revoke all on function public.match_report(text, int) from public, anon;
revoke all on function public.match_settle_mine() from public, anon;
grant execute on function public.match_meet(text, text, uuid, int) to authenticated;
grant execute on function public.match_report(text, int) to authenticated;
grant execute on function public.match_settle_mine() to authenticated;
