-- styles for the 3D tables, bought with coins; and a record of each finished season for medals
create table if not exists public.game_items (
  user_id uuid not null references public.profiles(id) on delete cascade,
  item text not null check (item in ('nardi:orn','joker:geo','chess:carved','chess:modern')),
  created_at timestamptz not null default now(),
  primary key (user_id, item)
);
alter table public.game_items enable row level security;
drop policy if exists "own items" on public.game_items;
create policy "own items" on public.game_items for select to authenticated using (auth.uid() = user_id);

create or replace function public.buy_item(p_item text)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare me uuid := auth.uid(); price int; c int;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  price := case p_item when 'nardi:orn' then 300 when 'joker:geo' then 250 when 'chess:carved' then 200 when 'chess:modern' then 300 else null end;
  if price is null then raise exception 'bad_item'; end if;
  if exists (select 1 from public.game_items where user_id = me and item = p_item) then
    select coins into c from public.profiles where id = me; return jsonb_build_object('coins', c, 'owned', true);
  end if;
  update public.profiles set coins = coins - price where id = me and coins >= price returning coins into c;
  if c is null then raise exception 'not_enough_coins'; end if;
  insert into public.game_items (user_id, item) values (me, p_item);
  insert into public.coin_log (user_id, amount, label) values (me, -price, 'სტილი: ' || p_item);
  return jsonb_build_object('coins', c, 'owned', true);
end $$;
revoke all on function public.buy_item(text) from public, anon;
grant execute on function public.buy_item(text) to authenticated;

create table if not exists public.game_seasons (
  user_id uuid not null references public.profiles(id) on delete cascade,
  game text not null,
  season text not null,
  pts int not null,
  games int not null,
  primary key (user_id, game, season)
);
alter table public.game_seasons enable row level security;
drop policy if exists "seasons are public" on public.game_seasons;
create policy "seasons are public" on public.game_seasons for select to authenticated using (true);
create index if not exists game_seasons_rank on public.game_seasons (game, season, pts desc);

-- when a player's first rated game of a new month comes, last month's points are kept in game_seasons
create or replace function private.season_keep() returns trigger language plpgsql security definer set search_path to '' as $$
begin
  if old.season is distinct from new.season and old.season_games > 0 then
    insert into public.game_seasons (user_id, game, season, pts, games) values (old.user_id, old.game, old.season, old.season_pts, old.season_games)
    on conflict (user_id, game, season) do update set pts = excluded.pts, games = excluded.games;
  end if;
  return new;
end $$;
drop trigger if exists game_ratings_season_keep on public.game_ratings;
create trigger game_ratings_season_keep before update on public.game_ratings for each row execute function private.season_keep();
