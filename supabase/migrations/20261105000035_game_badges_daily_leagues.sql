-- badges that bring coins once, the joker "hand of the day" scores, and the region and group leagues.
-- run after fair_game_ratings.sql (the leagues add up game_ratings.season_pts).

-- ---------- badges: each one pays its coins once ----------
create table if not exists public.game_badges (
  user_id uuid not null references public.profiles(id) on delete cascade,
  badge text not null,
  created_at timestamptz not null default now(),
  primary key (user_id, badge)
);
alter table public.game_badges enable row level security;
drop policy if exists "badges are public" on public.game_badges;
create policy "badges are public" on public.game_badges for select to authenticated using (true);

create or replace function public.game_badge(p_badge text)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare me uuid := auth.uid(); price int; c int; n int;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  price := case p_badge
    when 'mars' then 10 when 'koks' then 20 when 'mars10' then 30 when 'longw' then 10 when 'match' then 20
    when 'mate20' then 20 when 'master' then 30 when 'pz7' then 20
    when 'king' then 10 when 'take3' then 20 when 'give' then 10
    when 'prem' then 20 when 'k1000' then 30 when 'daily' then 10
    when 'fish' then 10 when 'dry' then 30
    when 'career3' then 20 when 'career6' then 50
    when 'egg10' then 20 when 'ev_ny' then 30 when 'ev_easter' then 30 when 'ev_tbil' then 30 when 'ev_giorgi' then 30
    else null end;
  if price is null then raise exception 'bad_badge'; end if;
  -- a few a day at most, so a tampered phone cannot empty the list at once
  select count(*) into n from public.game_badges where user_id = me and created_at > now() - interval '1 day';
  if n >= 6 then select coins into c from public.profiles where id = me; return jsonb_build_object('coins', c, 'paid', false); end if;
  insert into public.game_badges (user_id, badge) values (me, p_badge) on conflict do nothing;
  if not found then select coins into c from public.profiles where id = me; return jsonb_build_object('coins', c, 'paid', false); end if;
  update public.profiles set coins = coins + price where id = me returning coins into c;
  insert into public.coin_log (user_id, amount, label) values (me, price, 'ნიშანი: ' || p_badge);
  return jsonb_build_object('coins', c, 'paid', true);
end $$;
revoke all on function public.game_badge(text) from public, anon;
grant execute on function public.game_badge(text) to authenticated;

-- ---------- the hand of the day: the first score of the day for each person, seen by friends ----------
create table if not exists public.game_daily (
  user_id uuid not null references public.profiles(id) on delete cascade,
  day text not null check (day ~ '^\d{4}-\d{2}-\d{2}$'),
  game text not null check (game in ('joker','sprint')),
  score int not null check (score between -5000 and 5000),
  created_at timestamptz not null default now(),
  primary key (user_id, day, game)
);
alter table public.game_daily enable row level security;
drop policy if exists "own daily score" on public.game_daily;
create policy "own daily score" on public.game_daily for insert to authenticated
  with check (user_id = (select auth.uid())
    and day in (to_char(now() at time zone 'Asia/Tbilisi', 'YYYY-MM-DD'), to_char((now() - interval '1 day') at time zone 'Asia/Tbilisi', 'YYYY-MM-DD')));
drop policy if exists "friends see daily scores" on public.game_daily;
create policy "friends see daily scores" on public.game_daily for select to authenticated
  using (user_id = (select auth.uid()) or public.are_friends((select auth.uid()), user_id));
create index if not exists game_daily_day on public.game_daily (day, game, score desc);

-- ---------- leagues of regions and of groups: the month's rating points of their members ----------
create or replace function public.game_region_board(p_game text, p_season text)
returns table (region text, name text, players int, pts int)
language sql stable security definer set search_path to '' as $$
  select p.home_region, p.home_region, count(*)::int, sum(r.season_pts)::int
  from public.game_ratings r join public.profiles p on p.id = r.user_id
  where r.game = p_game and r.season = p_season and r.season_games > 0
    and coalesce(p.home_region, '') <> ''
  group by p.home_region
  order by sum(r.season_pts) desc, count(*) desc
  limit 20
$$;
revoke all on function public.game_region_board(text, text) from public, anon;
grant execute on function public.game_region_board(text, text) to authenticated;

-- open groups only, and only those with at least two players this month
create or replace function public.game_group_board(p_game text, p_season text)
returns table (id bigint, name text, players int, pts int)
language sql stable security definer set search_path to '' as $$
  select g.id, g.name, count(*)::int, sum(r.season_pts)::int
  from public.groups g
  join public.group_members m on m.group_id = g.id
  join public.game_ratings r on r.user_id = m.user_id
  where not g.is_private and r.game = p_game and r.season = p_season and r.season_games > 0
  group by g.id, g.name
  having count(*) >= 2
  order by sum(r.season_pts) desc, count(*) desc
  limit 20
$$;
revoke all on function public.game_group_board(text, text) from public, anon;
grant execute on function public.game_group_board(text, text) to authenticated;
