-- More casino games on coins: two five-reel slots (the Golden Fleece, Batumi Night), mines, plinko,
-- and the aviator flown together (everyone in one plane, seeing who is in and who has cashed out).
--
-- The same rules as the first casino games (20261108000049): adults only, every result decided here with pgcrypto's random
-- bytes, the admin's limits (bet, biggest single win, daily bets) and per-game switches, one coin-history line per game a day.
--
-- What each gives back on average (worked out exactly from the reels and tables):
--   Golden Fleece ~95.3%, Batumi Night ~95.6%: 10 lines, a wild, 3+ scatters give 8 / 10 free spins with wins doubled
--   mines 97%: after k gems among n mines the multiplier is 0.97 / P(k gems in a row)
--   plinko ~97%: tables for 8, 12 and 16 rows at three risks
--   the shared aviator 97%, as the solo one: the crash point is 0.97/u for u uniform in (0,1]

-- 1. the new games: the round table takes them, the settings switch them on, the coin history names them ----------

alter table public.casino_rounds drop constraint if exists casino_rounds_game_check;
alter table public.casino_rounds add constraint casino_rounds_game_check
  check (game in ('slot', 'fleece', 'batumi', 'roulette', 'bj', 'aviator', 'mines', 'plinko', 'avl'));
create index if not exists casino_rounds_avl on public.casino_rounds (((data ->> 'r')::bigint)) where game = 'avl';
update public.app_settings set value = jsonb_set(value, '{games}',
  '{"fleece": true, "batumi": true, "mines": true, "plinko": true, "avl": true}'::jsonb || coalesce(value -> 'games', '{}'::jsonb))
  where key = 'casino';

create or replace function private.casino_move(p_user uuid, p_game text, p_delta integer, p_round boolean) returns integer
language plpgsql security definer set search_path = '' as $$
declare v_bal int; v_line bigint; v_act text := 'casino_' || p_game;
  v_label text := case p_game when 'slot' then 'ქართული სლოტი' when 'fleece' then 'ოქროს საწმისი' when 'batumi' then 'ბათუმის ღამე'
    when 'roulette' then 'რულეტკა' when 'bj' then 'ბლექჯეკი' when 'mines' then 'ნაღმები' when 'plinko' then 'პლინკო' else 'ავიატორი' end;
begin
  update public.profiles set coins = coins + p_delta where id = p_user and coins + p_delta >= 0 returning coins into v_bal;
  if v_bal is null then raise exception 'not_enough_coins'; end if;
  if p_delta = 0 and not p_round then return v_bal; end if;
  select l.id into v_line from public.coin_log l
    where l.user_id = p_user and l.action = v_act and l.created_at >= (private.tday()::timestamp at time zone 'Asia/Tbilisi')
    order by l.created_at desc limit 1;
  if v_line is not null then
    update public.coin_log set amount = amount + p_delta, n = n + case when p_round then 1 else 0 end, created_at = now() where id = v_line;
  else
    insert into public.coin_log (user_id, amount, label, action, n) values (p_user, p_delta, v_label, v_act, 1);
  end if;
  return v_bal;
end $$;

-- 2. five-reel slots ------------------------------------------------------------------------------------------------
-- the reels: 32 stops each, read three at a time; W the wild, S the scatter, H1-H4 the pictures, A K Q J T the letters

create or replace function private.slot5_strips(p_game text) returns text[]
language sql immutable set search_path = '' as $$
  select case p_game when 'fleece' then array[['Q','H1','Q','H4','H3','S','H2','H4','J','T','A','K','T','Q','J','A','H3','J','K','T','K','Q','H4','A','J','W','K','H3','H2','T','W','H1'],['K','H2','H3','Q','J','Q','J','W','H4','T','H1','A','S','H2','K','J','Q','K','H3','A','T','A','J','W','H4','H1','H4','T','K','Q','H3','T'],['K','W','A','H3','H1','Q','H4','H4','K','A','A','H4','K','T','W','T','H2','S','Q','J','J','J','H1','T','H3','Q','H2','J','T','Q','H3','K'],['A','J','Q','A','Q','H4','H1','H3','W','Q','H2','J','J','K','H3','K','J','A','K','T','H4','H2','H3','T','T','T','K','H1','S','Q','W','H4'],['K','T','J','H3','H4','S','T','H3','A','K','K','J','T','H2','Q','Q','A','H4','H1','J','H4','H1','Q','J','T','H3','H2','W','Q','K','W','A']]
    when 'batumi' then array[['A','H3','K','T','J','Q','H3','H4','W','T','H3','Q','K','T','J','K','A','H4','K','H2','A','J','T','S','J','H2','W','H4','Q','H1','Q','T'],['A','H4','A','T','K','J','J','H1','H3','T','H2','Q','K','K','J','J','H4','W','T','T','S','H4','Q','Q','H1','Q','H2','A','K','W','H3','H3'],['H1','W','K','W','J','A','H1','H3','H4','K','Q','A','J','H3','T','J','A','T','H4','H3','Q','J','T','T','Q','H2','K','H2','Q','H4','K','S'],['J','H4','W','Q','A','K','H2','J','K','J','T','A','J','H3','T','T','A','H1','H3','H1','H3','T','Q','H4','H2','W','Q','H4','Q','K','S','K'],['K','J','K','H4','J','H3','H1','S','H2','A','Q','Q','H4','H4','K','K','H1','A','T','Q','H3','W','A','Q','H3','H2','W','T','J','T','T','J']] end $$;

-- pays for 3, 4, 5 on a line, in line bets (the bet / 10)
create or replace function private.slot5_pay(p_sym text, p_n integer) returns integer
language sql immutable set search_path = '' as $$
  select case when p_n < 3 then 0 else (case p_sym when 'W' then array[80,400,1500] when 'H1' then array[40,150,800] when 'H2' then array[30,120,400]
    when 'H3' then array[25,80,250] when 'H4' then array[15,60,200] when 'A' then array[12,40,150] when 'K' then array[10,30,125]
    when 'Q' then array[8,25,100] when 'J' then array[8,20,80] when 'T' then array[8,15,60] else array[0,0,0] end)[p_n - 2] end $$;

-- ten lines over five reels, rows 0 top, 1 middle, 2 bottom
create or replace function private.slot5_lines() returns integer[]
language sql immutable set search_path = '' as $$
  select array[[1,1,1,1,1],[0,0,0,0,0],[2,2,2,2,2],[0,1,2,1,0],[2,1,0,1,2],[0,0,1,2,2],[2,2,1,0,0],[1,0,0,0,1],[1,2,2,2,1],[1,0,1,2,1]] $$;

-- a screen: on each reel a random stop and the two after it
create or replace function private.slot5_grid(p_st text[]) returns text[]
language plpgsql volatile set search_path = '' as $$
declare g text[] := array_fill(''::text, array[5, 3]); x int; s int; r int; n int := array_length(p_st, 2);
begin
  for x in 1..5 loop s := private.rnd(n); for r in 1..3 loop g[x][r] := p_st[x][((s + r - 1) % n) + 1]; end loop; end loop;
  return g;
end $$;

create or replace function private.slot5_json(p_g text[]) returns jsonb
language sql immutable set search_path = '' as $$
  select jsonb_agg(jsonb_build_array(p_g[x][1], p_g[x][2], p_g[x][3]) order by x) from generate_series(1, 5) x $$;

-- what a screen pays: each line from the left, the higher of its leading wilds and its first other symbol with the wilds
-- standing in (a scatter stands in for nothing); and where the scatters are
create or replace function private.slot5_eval(p_g text[], p_bet integer, p_mult integer) returns jsonb
language plpgsql immutable set search_path = '' as $$
declare v_ln int[] := private.slot5_lines(); l int; x int; s text[]; nw int; base text; n int; wp int; bp int; w int; v_wins jsonb := '[]'; tot int := 0; sc jsonb := '[]'; r int;
begin
  for l in 1..10 loop
    s := '{}';
    for x in 1..5 loop s := s || p_g[x][v_ln[l][x] + 1]; end loop;
    nw := 0;
    for x in 1..5 loop exit when s[x] <> 'W'; nw := nw + 1; end loop;
    wp := private.slot5_pay('W', nw);
    base := 'W';
    for x in 1..5 loop if s[x] <> 'W' then base := s[x]; exit; end if; end loop;
    n := 0; bp := 0;
    if base <> 'S' and base <> 'W' then
      for x in 1..5 loop exit when s[x] <> base and s[x] <> 'W'; n := n + 1; end loop;
      bp := private.slot5_pay(base, n);
    end if;
    if greatest(wp, bp) > 0 then
      w := floor(p_bet * greatest(wp, bp) * p_mult / 10.0)::int;
      v_wins := v_wins || jsonb_build_array(jsonb_build_object('l', l - 1, 'n', case when wp >= bp then nw else n end, 's', case when wp >= bp then 'W' else base end, 'w', w));
      tot := tot + w;
    end if;
  end loop;
  for x in 1..5 loop for r in 1..3 loop if p_g[x][r] = 'S' then sc := sc || jsonb_build_array(jsonb_build_array(x - 1, r - 1)); end if; end loop; end loop;
  return jsonb_build_object('wins', v_wins, 'tot', tot, 'sc', sc);
end $$;

create or replace function public.slot5_spin(p_game text, p_bet integer) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); c jsonb; st text[]; g text[]; e jsonb; fe jsonb; fg text[]; fsn int := 0; fs jsonb := '[]'; k int;
  tot int; base int; v_wins jsonb; v_win int; v_bal int; v_id bigint;
begin
  if p_game is null or p_game not in ('fleece', 'batumi') then raise exception 'bad_request'; end if;
  c := private.casino_check(me, p_game, p_bet);
  perform private.casino_hold(me, p_bet);
  st := private.slot5_strips(p_game);
  g := private.slot5_grid(st);
  e := private.slot5_eval(g, p_bet, 1);
  base := (e ->> 'tot')::int; tot := base; v_wins := e -> 'wins';
  if jsonb_array_length(e -> 'sc') >= 3 then
    v_wins := v_wins || jsonb_build_array(jsonb_build_object('l', -1, 'n', jsonb_array_length(e -> 'sc'), 's', 'S', 'c', e -> 'sc', 'w', 0));
    fsn := case p_game when 'fleece' then 8 else 10 end;
    for k in 1..fsn loop
      fg := private.slot5_grid(st); fe := private.slot5_eval(fg, p_bet, 2);
      fs := fs || jsonb_build_array(jsonb_build_object('grid', private.slot5_json(fg), 'wins', fe -> 'wins', 'win', (fe ->> 'tot')::int));
      tot := tot + (fe ->> 'tot')::int;
    end loop;
  end if;
  v_win := least(tot, coalesce((c ->> 'max_win')::int, 100000));
  v_bal := private.casino_move(me, p_game, v_win - p_bet, true);
  insert into public.casino_rounds (user_id, game, bet, win, data, settled_at)
    values (me, p_game, p_bet, v_win, jsonb_build_object('g', private.slot5_json(g), 'fs', fsn), now()) returning id into v_id;
  return jsonb_build_object('id', v_id, 'grid', private.slot5_json(g), 'wins', v_wins, 'base', base, 'fs', fs, 'win', v_win, 'coins', v_bal);
end $$;

-- 3. mines --------------------------------------------------------------------------------------------------------

create or replace function private.mines_mult(p_n integer, p_k integer) returns numeric
language plpgsql immutable set search_path = '' as $$
declare p numeric := 1; j int;
begin
  if p_k <= 0 then return 1; end if;
  for j in 0..p_k - 1 loop p := p * (25 - j)::numeric / (25 - p_n - j); end loop;
  return floor(0.97 * p * 100) / 100;
end $$;

-- what the player sees: the mines show only when the round is over
create or replace function private.mines_view(p_round bigint) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare o record; v_s jsonb;
begin
  select * into o from public.casino_rounds where id = p_round;
  select cs.s into v_s from private.casino_secret cs where cs.round_id = p_round;
  return jsonb_build_object('id', o.id, 'state', o.state, 'bet', o.bet, 'win', o.win, 'mines', (o.data ->> 'mines')::int, 'picks', coalesce(o.data -> 'picks', '[]'::jsonb),
    'm', coalesce((o.data ->> 'm')::numeric, 1), 'boom', o.data -> 'boom', 'pos', case when o.state = 'done' then v_s -> 'pos' end,
    'coins', (select coins from public.profiles where id = o.user_id));
end $$;

-- a new field; an unfinished one comes back instead
create or replace function public.mines_start(p_bet integer, p_mines integer) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); v_open bigint; v_pos int[]; v_id bigint;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  select id into v_open from public.casino_rounds where user_id = me and game = 'mines' and state = 'open' order by id desc limit 1;
  if v_open is not null then return private.mines_view(v_open); end if;
  if p_mines is null or p_mines not between 1 and 24 then raise exception 'bad_request'; end if;
  perform private.casino_check(me, 'mines', p_bet);
  perform private.casino_hold(me, p_bet);
  v_pos := array(select c from generate_series(0, 24) c order by extensions.gen_random_bytes(8) limit p_mines);
  perform private.casino_move(me, 'mines', -p_bet, true);
  insert into public.casino_rounds (user_id, game, bet, state, data) values (me, 'mines', p_bet, 'open', jsonb_build_object('mines', p_mines, 'picks', '[]'::jsonb, 'm', 1))
    returning id into v_id;
  insert into private.casino_secret (round_id, s) values (v_id, jsonb_build_object('pos', to_jsonb(v_pos)));
  return private.mines_view(v_id);
end $$;

create or replace function public.mines_pick(p_round bigint, p_cell integer) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); o record; v_pos jsonb; v_picks jsonb; n int; k int; m numeric; w int;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  select * into o from public.casino_rounds where id = p_round and user_id = me and game = 'mines' for update;
  if o.id is null then raise exception 'not_found'; end if;
  if o.state <> 'open' then return private.mines_view(p_round); end if;
  v_picks := coalesce(o.data -> 'picks', '[]'::jsonb);
  if p_cell is null or p_cell not between 0 and 24 or v_picks @> to_jsonb(p_cell) then raise exception 'bad_request'; end if;
  select cs.s -> 'pos' into v_pos from private.casino_secret cs where cs.round_id = p_round;
  if v_pos @> to_jsonb(p_cell) then
    update public.casino_rounds set state = 'done', win = 0, settled_at = now(), data = data || jsonb_build_object('boom', p_cell) where id = p_round;
    return private.mines_view(p_round);
  end if;
  v_picks := v_picks || to_jsonb(p_cell); n := (o.data ->> 'mines')::int; k := jsonb_array_length(v_picks); m := private.mines_mult(n, k);
  if k >= 25 - n then
    w := least(floor(o.bet * m)::int, coalesce((private.casino_cfg() ->> 'max_win')::int, 100000));
    perform private.casino_move(me, 'mines', w, false);
    update public.casino_rounds set state = 'done', win = w, settled_at = now(), data = data || jsonb_build_object('picks', v_picks, 'm', m) where id = p_round;
  else
    update public.casino_rounds set data = data || jsonb_build_object('picks', v_picks, 'm', m) where id = p_round;
  end if;
  return private.mines_view(p_round);
end $$;

create or replace function public.mines_cashout(p_round bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); o record; w int;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  select * into o from public.casino_rounds where id = p_round and user_id = me and game = 'mines' for update;
  if o.id is null then raise exception 'not_found'; end if;
  if o.state <> 'open' then return private.mines_view(p_round); end if;
  if jsonb_array_length(coalesce(o.data -> 'picks', '[]'::jsonb)) = 0 then raise exception 'bad_request'; end if;
  w := least(floor(o.bet * (o.data ->> 'm')::numeric)::int, coalesce((private.casino_cfg() ->> 'max_win')::int, 100000));
  perform private.casino_move(me, 'mines', w, false);
  update public.casino_rounds set state = 'done', win = w, settled_at = now() where id = p_round;
  return private.mines_view(p_round);
end $$;

-- 4. plinko -------------------------------------------------------------------------------------------------------

create or replace function private.plinko_tab(p_rows integer, p_risk text) returns numeric[]
language sql immutable set search_path = '' as $$
  select case
    when p_rows = 8 and p_risk = 'low' then array[5.5,2,1.1,1,0.45,1,1.1,2,5.5]::numeric[]
    when p_rows = 8 and p_risk = 'mid' then array[13,3,1.3,0.7,0.35,0.7,1.3,3,13]::numeric[]
    when p_rows = 8 and p_risk = 'high' then array[29,4,1.5,0.25,0.2,0.25,1.5,4,29]::numeric[]
    when p_rows = 12 and p_risk = 'low' then array[10,3,1.6,1.4,1.1,1,0.4,1,1.1,1.4,1.6,3,10]::numeric[]
    when p_rows = 12 and p_risk = 'mid' then array[33,11,4,2,1.1,0.6,0.2,0.6,1.1,2,4,11,33]::numeric[]
    when p_rows = 12 and p_risk = 'high' then array[170,24,8,1.8,0.7,0.2,0.2,0.2,0.7,1.8,8,24,170]::numeric[]
    when p_rows = 16 and p_risk = 'low' then array[16,9,2,1.4,1.4,1.2,1.1,1,0.4,1,1.1,1.2,1.4,1.4,2,9,16]::numeric[]
    when p_rows = 16 and p_risk = 'mid' then array[110,41,10,5,3,1.5,1,0.5,0.2,0.5,1,1.5,3,5,10,41,110]::numeric[]
    when p_rows = 16 and p_risk = 'high' then array[1000,130,25,8,4,2,0.2,0.2,0.2,0.2,0.2,2,4,8,25,130,1000]::numeric[]
  end $$;

create or replace function public.plinko_drop(p_bet integer, p_rows integer, p_risk text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); c jsonb; v_path int[]; v_slot int; v_mult numeric; v_win int; v_bal int; v_id bigint;
begin
  if p_rows is null or p_rows not in (8, 12, 16) or p_risk is null or p_risk not in ('low', 'mid', 'high') then raise exception 'bad_request'; end if;
  c := private.casino_check(me, 'plinko', p_bet);
  perform private.casino_hold(me, p_bet);
  v_path := array(select private.rnd(2) from generate_series(1, p_rows));
  v_slot := (select sum(x) from unnest(v_path) x);
  v_mult := (private.plinko_tab(p_rows, p_risk))[v_slot + 1];
  v_win := least(floor(p_bet * v_mult)::int, coalesce((c ->> 'max_win')::int, 100000));
  v_bal := private.casino_move(me, 'plinko', v_win - p_bet, true);
  insert into public.casino_rounds (user_id, game, bet, win, data, settled_at)
    values (me, 'plinko', p_bet, v_win, jsonb_build_object('rows', p_rows, 'risk', p_risk, 'slot', v_slot, 'm', v_mult), now()) returning id into v_id;
  return jsonb_build_object('id', v_id, 'path', to_jsonb(v_path), 'slot', v_slot, 'mult', v_mult, 'win', v_win, 'coins', v_bal);
end $$;

-- 5. the aviator flown together ------------------------------------------------------------------------------------
-- one round after another while anyone watches: 7 seconds to bet, the flight (the multiplier e^(0.11 t)), 3 seconds to see it go.
-- a round starts when someone asks for the state after the last one ended; the crash point is kept apart until the plane has gone.
-- each bet is a casino round (game avl, data.r the flight), so the limits, the day's total and the coin history work as for the rest

create table if not exists public.avl_rounds (
  id bigint generated always as identity primary key,
  t0 timestamptz not null,
  crash numeric,
  done boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists avl_rounds_t0 on public.avl_rounds (t0);
alter table public.avl_rounds enable row level security;
revoke all on public.avl_rounds from anon, authenticated;
comment on table public.avl_rounds is 'The shared aviator flights. The crash point is in private.avl_secret until the plane has gone.';
create table if not exists private.avl_secret (round_id bigint primary key references public.avl_rounds(id) on delete cascade, crash numeric not null);

-- a flight ends: automatic cash-outs below the crash are paid at their mark, the rest are lost
create or replace function private.avl_end(p_id bigint) returns void
language plpgsql security definer set search_path = '' as $$
declare v_crash numeric; b record; w int; v_max int := coalesce((private.casino_cfg() ->> 'max_win')::int, 100000);
begin
  select s.crash into v_crash from private.avl_secret s where s.round_id = p_id;
  update public.avl_rounds set crash = v_crash, done = true where id = p_id and not done;
  for b in select * from public.casino_rounds where game = 'avl' and state = 'open' and (data ->> 'r')::bigint = p_id for update loop
    if (b.data ->> 'auto') is not null and (b.data ->> 'auto')::numeric < v_crash then
      w := least(floor(b.bet * (b.data ->> 'auto')::numeric)::int, v_max);
      perform private.casino_move(b.user_id, 'avl', w, false);
      update public.casino_rounds set state = 'done', win = w, settled_at = now(), data = data || jsonb_build_object('m', (b.data ->> 'auto')::numeric, 'crash', v_crash) where id = b.id;
    else
      update public.casino_rounds set state = 'done', win = 0, settled_at = now(), data = data || jsonb_build_object('crash', v_crash) where id = b.id;
    end if;
  end loop;
end $$;

-- the flight now, starting a new one when the last has gone (one at a time: an advisory lock)
create or replace function private.avl_cur() returns public.avl_rounds
language plpgsql security definer set search_path = '' as $$
declare r public.avl_rounds; v_crash numeric; u numeric;
begin
  perform pg_advisory_xact_lock(hashtext('peera_avl'));
  select * into r from public.avl_rounds order by id desc limit 1;
  if r.id is not null then
    select s.crash into v_crash from private.avl_secret s where s.round_id = r.id;
    if clock_timestamp() < r.t0 + make_interval(secs => ln(v_crash) / 0.11 + 3) then return r; end if;
    if not r.done then perform private.avl_end(r.id); end if;
  end if;
  u := (private.rnd31() + 1)::numeric / 2147483648;
  v_crash := least(200, greatest(1, floor(100 * 0.97 / u) / 100));
  insert into public.avl_rounds (t0) values (clock_timestamp() + interval '7 seconds') returning * into r;
  insert into private.avl_secret (round_id, crash) values (r.id, v_crash);
  delete from public.avl_rounds where t0 < now() - interval '3 days';
  return r;
end $$;

create or replace function public.avl_state() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); r public.avl_rounds; v_crash numeric; ph text; m numeric; b record; w int; v_max int := coalesce((private.casino_cfg() ->> 'max_win')::int, 100000);
begin
  if me is null then raise exception 'not_signed_in'; end if;
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

create or replace function public.avl_bet(p_round bigint, p_bet integer, p_auto numeric default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); r public.avl_rounds;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  r := private.avl_cur();
  if r.id <> p_round or clock_timestamp() >= r.t0 then raise exception 'avl_late'; end if;
  if p_auto is not null and (p_auto < 1.01 or p_auto > 200) then raise exception 'bad_request'; end if;
  if exists (select 1 from public.casino_rounds where game = 'avl' and user_id = me and (data ->> 'r')::bigint = r.id) then raise exception 'avl_in'; end if;
  perform private.casino_check(me, 'avl', p_bet);
  perform private.casino_hold(me, p_bet);
  perform private.casino_move(me, 'avl', -p_bet, true);
  insert into public.casino_rounds (user_id, game, bet, state, data) values (me, 'avl', p_bet, 'open', jsonb_build_object('r', r.id, 'auto', round(p_auto, 2)));
  return public.avl_state();
end $$;

create or replace function public.avl_cashout(p_round bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); r public.avl_rounds; v_crash numeric; m numeric; b record; w int;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  r := private.avl_cur();
  if r.id = p_round and clock_timestamp() >= r.t0 then
    select s.crash into v_crash from private.avl_secret s where s.round_id = r.id;
    m := exp(0.11 * extract(epoch from clock_timestamp() - r.t0));
    if m < v_crash then
      select * into b from public.casino_rounds where game = 'avl' and user_id = me and state = 'open' and (data ->> 'r')::bigint = r.id for update;
      if b.id is not null then
        m := floor(m * 100) / 100;
        w := least(floor(b.bet * m)::int, coalesce((private.casino_cfg() ->> 'max_win')::int, 100000));
        perform private.casino_move(me, 'avl', w, false);
        update public.casino_rounds set state = 'done', win = w, settled_at = now(), data = data || jsonb_build_object('m', m) where id = b.id;
      end if;
    end if;
  end if;
  return public.avl_state();
end $$;

-- 6. the admin: the new games among the switches and the numbers ----------------------------------------------------

create or replace function public.admin_casino_set(p_cfg jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v jsonb := private.casino_cfg(); k text; n int;
begin
  if not public.is_admin() then raise exception 'admin_only'; end if;
  if p_cfg ? 'on' then v := v || jsonb_build_object('on', (p_cfg ->> 'on')::boolean); end if;
  foreach k in array array['min_bet', 'max_bet', 'max_win', 'day_bets'] loop
    if p_cfg ? k then
      n := (p_cfg ->> k)::int;
      if n is null or n < 1 or n > 10000000 then raise exception 'bad_request'; end if;
      v := v || jsonb_build_object(k, n);
    end if;
  end loop;
  if coalesce((v ->> 'min_bet')::int, 10) > coalesce((v ->> 'max_bet')::int, 500) then raise exception 'bad_request'; end if;
  if p_cfg ? 'games' then
    if jsonb_typeof(p_cfg -> 'games') <> 'object' then raise exception 'bad_request'; end if;
    v := jsonb_set(v, '{games}', coalesce(v -> 'games', '{}'::jsonb) || (select coalesce(jsonb_object_agg(key, value::text::boolean), '{}'::jsonb)
      from jsonb_each(p_cfg -> 'games') where key in ('slot', 'fleece', 'batumi', 'roulette', 'bj', 'aviator', 'mines', 'plinko', 'avl')));
  end if;
  insert into public.app_settings (key, value) values ('casino', v) on conflict (key) do update set value = excluded.value;
  return v;
end $$;

create or replace function public.admin_casino_stats() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v_day timestamptz := private.tday()::timestamp at time zone 'Asia/Tbilisi';
begin
  if not public.is_admin() then raise exception 'admin_only'; end if;
  return jsonb_build_object('cfg', private.casino_cfg(),
    'games', (select coalesce(jsonb_object_agg(g, x), '{}'::jsonb) from (
      select g, jsonb_build_object(
        'd_n', count(r.id) filter (where r.created_at >= v_day), 'd_bet', coalesce(sum(r.bet) filter (where r.created_at >= v_day), 0),
        'd_win', coalesce(sum(r.win) filter (where r.created_at >= v_day), 0), 'd_ppl', count(distinct r.user_id) filter (where r.created_at >= v_day),
        'w_n', count(r.id), 'w_bet', coalesce(sum(r.bet), 0), 'w_win', coalesce(sum(r.win), 0)) x
      from unnest(array['slot', 'fleece', 'batumi', 'roulette', 'bj', 'aviator', 'avl', 'mines', 'plinko']) g
      left join public.casino_rounds r on r.game = g and r.created_at >= now() - interval '7 days' and r.state = 'done'
      group by g) t),
    'top', (select coalesce(jsonb_agg(jsonb_build_object('u', user_id, 'net', net, 'n', n) order by net desc), '[]'::jsonb) from (
      select user_id, sum(win - bet) net, count(*) n from public.casino_rounds where created_at >= v_day and state = 'done'
      group by user_id order by sum(win - bet) desc limit 5) t));
end $$;

-- 7. who may call what ------------------------------------------------------------------------------------------------

revoke all on function public.slot5_spin(text, integer) from public, anon;
revoke all on function public.mines_start(integer, integer) from public, anon;
revoke all on function public.mines_pick(bigint, integer) from public, anon;
revoke all on function public.mines_cashout(bigint) from public, anon;
revoke all on function public.plinko_drop(integer, integer, text) from public, anon;
revoke all on function public.avl_state() from public, anon;
revoke all on function public.avl_bet(bigint, integer, numeric) from public, anon;
revoke all on function public.avl_cashout(bigint) from public, anon;
grant execute on function public.slot5_spin(text, integer), public.mines_start(integer, integer), public.mines_pick(bigint, integer), public.mines_cashout(bigint),
  public.plinko_drop(integer, integer, text), public.avl_state(), public.avl_bet(bigint, integer, numeric), public.avl_cashout(bigint) to authenticated;
