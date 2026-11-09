-- The games are for the admin only for now: the app shows everyone else a "closed" page (js/glock.js).
-- The casino keeps the same lock here, so no round can be played by calling the server directly: while
-- app_settings games_lock is on, only an admin may start a casino round or join the shared aviator.
-- Rounds already started can still be finished. To open the games: set games_lock to {"on": false}.

insert into public.app_settings (key, value) values ('games_lock', '{"on": true}'::jsonb)
  on conflict (key) do update set value = excluded.value;

create or replace function private.games_open(p_user uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select not coalesce((select (value ->> 'on')::boolean from public.app_settings where key = 'games_lock'), false)
    or exists (select 1 from public.profiles where id = p_user and role = 'admin') $$;

-- may this person play this game for this bet now? (the lock, adult, not banned, casino and game on, bet and day limits)
create or replace function private.casino_check(p_user uuid, p_game text, p_bet integer) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare c jsonb := private.casino_cfg(); v_today int;
begin
  if p_user is null then raise exception 'not_signed_in'; end if;
  if not private.games_open(p_user) then raise exception 'games_locked'; end if;
  if not public.is_adult(p_user) then raise exception 'not_adult'; end if;
  if exists (select 1 from public.profiles where id = p_user and banned) then raise exception 'not_allowed'; end if;
  if not coalesce((c ->> 'on')::boolean, false) or not coalesce((c -> 'games' ->> p_game)::boolean, true) then raise exception 'casino_closed'; end if;
  if p_bet is not null then
    if p_bet < coalesce((c ->> 'min_bet')::int, 10) or p_bet > coalesce((c ->> 'max_bet')::int, 500) then raise exception 'bad_bet'; end if;
    select coalesce(sum(bet), 0) into v_today from public.casino_rounds
      where user_id = p_user and created_at >= (private.tday()::timestamp at time zone 'Asia/Tbilisi');
    if v_today + p_bet > coalesce((c ->> 'day_bets')::int, 20000) then raise exception 'casino_day_cap'; end if;
  end if;
  return c;
end $$;

-- the shared aviator: watching it is behind the same lock
create or replace function public.avl_state() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); r public.avl_rounds; v_crash numeric; ph text; m numeric; b record; w int; v_max int := coalesce((private.casino_cfg() ->> 'max_win')::int, 100000);
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if not private.games_open(me) then raise exception 'games_locked'; end if;
  if not public.is_adult(me) then raise exception 'not_adult'; end if;
  r := private.avl_cur();
  select s.crash into v_crash from private.avl_secret s where s.round_id = r.id;
  ph := case when clock_timestamp() < r.t0 then 'bet' when clock_timestamp() < r.t0 + make_interval(secs => ln(v_crash) / 0.11) then 'fly' else 'gone' end;
  if ph = 'fly' then
    /* automatic cash-outs the plane has passed */
    m := exp(0.11 * extract(epoch from clock_timestamp() - r.t0));
    for b in select * from public.casino_rounds where game = 'avl' and state = 'open' and (data ->> 'r')::bigint = r.id
        and (data ->> 'auto') is not null and (data ->> 'auto')::numeric <= m and (data ->> 'auto')::numeric < v_crash for update loop
      w := least(floor(b.bet * (b.data ->> 'auto')::numeric)::int, v_max);
      perform private.casino_move(b.user_id, 'avl', w, false);
      update public.casino_rounds set state = 'done', win = w, settled_at = now(), data = data || jsonb_build_object('m', (b.data ->> 'auto')::numeric) where id = b.id;
    end loop;
  elsif ph = 'gone' and not r.done then
    perform private.avl_end(r.id);
  end if;
  return jsonb_build_object('id', r.id, 'phase', ph, 't0', extract(epoch from r.t0), 'now', extract(epoch from clock_timestamp()), 'k', 0.11, 'win_s', 7,
    'crash', case when ph = 'gone' then v_crash end,
    'bets', coalesce((select jsonb_agg(jsonb_build_object('u', x.user_id, 'bet', x.bet, 'm', x.data -> 'm', 'win', x.win) order by x.bet desc)
      from public.casino_rounds x where x.game = 'avl' and (x.data ->> 'r')::bigint = r.id), '[]'::jsonb),
    'me', (select jsonb_build_object('bet', x.bet, 'auto', x.data -> 'auto', 'm', x.data -> 'm', 'win', x.win)
      from public.casino_rounds x where x.game = 'avl' and x.user_id = me and (x.data ->> 'r')::bigint = r.id limit 1),
    'hist', coalesce((select jsonb_agg(h.crash order by h.id desc) from (select id, crash from public.avl_rounds where done and crash is not null order by id desc limit 20) h), '[]'::jsonb),
    'coins', (select coins from public.profiles where id = me));
end $$;
