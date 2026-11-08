-- Casino on coins: a Georgian slot, roulette, blackjack and the aviator.
--
-- Nobody can buy coins: they come only from activity and the admin's gifts. Every result is decided here, on the
-- server, with pgcrypto's random bytes; the phone only shows it. Only adults play (public.is_adult), and only while
-- the admin keeps the casino and that game on.
--
-- Limits (app_settings 'casino', set by the admin): a bet between min_bet and max_bet, one payout at most max_win,
-- and all bets of one person in one day (Tbilisi) at most day_bets.
--
-- What each game gives back on average (the rest stays with the house):
--   slot      ~94.9%  (3 of a kind on the line 9x…250x, the first two alike 1x)
--   roulette  ~97.3%  (European, one zero)
--   blackjack ~99%    (3:2, dealer stands on 17, double on the first two cards, no split)
--   aviator   ~97%    (the crash point is 0.97/u for u uniform in (0,1]; any cash-out plan gives back 97%)
--
-- In the coin history each game is one line a day: the net of all its rounds, and how many rounds.

-- 1. settings, rounds, secrets -------------------------------------------------------------------

insert into public.app_settings (key, value) values ('casino',
  '{"on": true, "min_bet": 10, "max_bet": 500, "max_win": 100000, "day_bets": 20000,
    "games": {"slot": true, "roulette": true, "bj": true, "aviator": true}}'::jsonb)
  on conflict (key) do nothing;

create table if not exists public.casino_rounds (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  game text not null check (game in ('slot', 'roulette', 'bj', 'aviator')),
  bet integer not null check (bet > 0),
  win integer not null default 0 check (win >= 0),
  state text not null default 'done' check (state in ('open', 'done')),
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  settled_at timestamptz
);
create index if not exists casino_rounds_user on public.casino_rounds (user_id, created_at desc);
create index if not exists casino_rounds_open on public.casino_rounds (user_id, game) where state = 'open';
create index if not exists casino_rounds_day on public.casino_rounds (created_at);
alter table public.casino_rounds enable row level security;
drop policy if exists "own rounds" on public.casino_rounds;
create policy "own rounds" on public.casino_rounds for select to authenticated using (user_id = (select auth.uid()));
revoke all on public.casino_rounds from anon, authenticated;
grant select on public.casino_rounds to authenticated;
comment on table public.casino_rounds is 'One row per casino round. Only the casino functions write here; what must stay hidden (the deck, the crash point) is in private.casino_secret.';

create table if not exists private.casino_secret (
  round_id bigint primary key references public.casino_rounds(id) on delete cascade,
  s jsonb not null
);

-- 2. shared pieces ---------------------------------------------------------------------------------

-- 31 random bits from pgcrypto, and from them a fair whole number in [0, n): numbers past the last full run of n
-- are thrown away, so no result comes up more often than another
create or replace function private.rnd31() returns integer
language sql volatile set search_path = '' as $$
  select ((('x' || encode(extensions.gen_random_bytes(4), 'hex'))::bit(32)::int) & 2147483647)::int $$;

create or replace function private.rnd(n integer) returns integer
language plpgsql volatile set search_path = '' as $$
declare lim bigint := 2147483648 - (2147483648 % n); x int;
begin
  loop x := private.rnd31(); exit when x < lim; end loop;
  return x % n;
end $$;

create or replace function private.casino_cfg() returns jsonb
language sql stable set search_path = '' as $$
  select coalesce((select value from public.app_settings where key = 'casino'), '{}'::jsonb) $$;

-- may this person play this game for this bet now? (adult, not banned, casino and game on, bet and day limits)
create or replace function private.casino_check(p_user uuid, p_game text, p_bet integer) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare c jsonb := private.casino_cfg(); v_today int;
begin
  if p_user is null then raise exception 'not_signed_in'; end if;
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

-- holds the balance until the round is written; not enough coins stops the round before anything happens
create or replace function private.casino_hold(p_user uuid, p_need integer) returns integer
language plpgsql security definer set search_path = '' as $$
declare v int;
begin
  select coins into v from public.profiles where id = p_user for update;
  if coalesce(v, 0) < p_need then raise exception 'not_enough_coins'; end if;
  return v;
end $$;

-- moves coins and keeps one history line per game a day (the net, and the number of rounds)
create or replace function private.casino_move(p_user uuid, p_game text, p_delta integer, p_round boolean) returns integer
language plpgsql security definer set search_path = '' as $$
declare v_bal int; v_line bigint; v_act text := 'casino_' || p_game;
  v_label text := case p_game when 'slot' then 'ქართული სლოტი' when 'roulette' then 'რულეტკა' when 'bj' then 'ბლექჯეკი' else 'ავიატორი' end;
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

-- what the casino page needs: the limits, whether this person may play, how much is left for today
create or replace function public.casino_info() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare me uuid := auth.uid(); c jsonb := private.casino_cfg();
begin
  if me is null then raise exception 'not_signed_in'; end if;
  return jsonb_build_object(
    'on', coalesce((c ->> 'on')::boolean, false), 'games', coalesce(c -> 'games', '{}'::jsonb),
    'min_bet', coalesce((c ->> 'min_bet')::int, 10), 'max_bet', coalesce((c ->> 'max_bet')::int, 500),
    'max_win', coalesce((c ->> 'max_win')::int, 100000), 'day_bets', coalesce((c ->> 'day_bets')::int, 20000),
    'adult', public.is_adult(me),
    'today', (select coalesce(sum(bet), 0) from public.casino_rounds where user_id = me and created_at >= (private.tday()::timestamp at time zone 'Asia/Tbilisi')),
    'coins', (select coins from public.profiles where id = me));
end $$;

-- this person's last rounds of one game
create or replace function public.casino_mine(p_game text) returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', id, 'bet', bet, 'win', win, 'd', data, 'at', created_at) order by id desc), '[]'::jsonb)
  from (select id, bet, win, data, created_at from public.casino_rounds
        where user_id = auth.uid() and game = p_game and state = 'done' order by id desc limit 20) x $$;

-- 3. the Georgian slot -----------------------------------------------------------------------------

create or replace function public.slot_spin(p_bet integer) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); c jsonb;
  syms text[] := array['grape', 'church', 'khach', 'wine', 'kantsi', 'seven'];
  w int[] := array[8, 7, 6, 4, 3, 2];           -- out of 30, the same on every reel
  pay3 int[] := array[9, 14, 22, 45, 90, 250];  -- three of a kind on the line
  r int[] := '{}'; i int; k int; x int; acc int; v_mult numeric := 0; v_win int; v_bal int; v_id bigint; v_r jsonb;
begin
  c := private.casino_check(me, 'slot', p_bet);
  perform private.casino_hold(me, p_bet);
  for i in 1..3 loop
    x := private.rnd(30); acc := 0;
    for k in 1..6 loop acc := acc + w[k]; if x < acc then r := r || k; exit; end if; end loop;
  end loop;
  if r[1] = r[2] and r[2] = r[3] then v_mult := pay3[r[1]];
  elsif r[1] = r[2] then v_mult := 1;
  end if;
  v_win := least(floor(p_bet * v_mult)::int, coalesce((c ->> 'max_win')::int, 100000));
  v_bal := private.casino_move(me, 'slot', v_win - p_bet, true);
  v_r := (select jsonb_agg(syms[e] order by o) from unnest(r) with ordinality as t(e, o));
  insert into public.casino_rounds (user_id, game, bet, win, data, settled_at)
    values (me, 'slot', p_bet, v_win, jsonb_build_object('r', v_r, 'x', v_mult), now()) returning id into v_id;
  return jsonb_build_object('id', v_id, 'r', v_r, 'mult', v_mult, 'win', v_win, 'coins', v_bal);
end $$;

-- 4. roulette (European) ---------------------------------------------------------------------------

-- p_bets: [{t, v, a}], t is n (a number 0-36), red, black, even, odd, low (1-18), high (19-36), dozen (v 1-3), col (v 1-3)
create or replace function public.roulette_spin(p_bets jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); c jsonb; b jsonb; t text; v int; a int; tot int := 0; n int; is_red boolean; won boolean;
  red int[] := array[1,3,5,7,9,12,14,16,18,19,21,23,25,27,30,32,34,36]; v_win bigint := 0; v_bal int; v_id bigint;
begin
  if p_bets is null or jsonb_typeof(p_bets) <> 'array' or jsonb_array_length(p_bets) not between 1 and 80 then raise exception 'bad_bet'; end if;
  for b in select value from jsonb_array_elements(p_bets) loop
    t := b ->> 't'; v := (b ->> 'v')::int; a := (b ->> 'a')::int;
    if a is null or a < 1 or a > 100000 then raise exception 'bad_bet'; end if;
    if t = 'n' and (v is null or v not between 0 and 36) then raise exception 'bad_bet'; end if;
    if t in ('dozen', 'col') and (v is null or v not between 1 and 3) then raise exception 'bad_bet'; end if;
    if t not in ('n', 'red', 'black', 'even', 'odd', 'low', 'high', 'dozen', 'col') then raise exception 'bad_bet'; end if;
    tot := tot + a;
  end loop;
  c := private.casino_check(me, 'roulette', tot);
  perform private.casino_hold(me, tot);
  n := private.rnd(37); is_red := n = any(red);
  for b in select value from jsonb_array_elements(p_bets) loop
    t := b ->> 't'; v := (b ->> 'v')::int; a := (b ->> 'a')::int;
    won := case t when 'n' then v = n
      when 'red' then is_red when 'black' then n > 0 and not is_red
      when 'even' then n > 0 and n % 2 = 0 when 'odd' then n % 2 = 1
      when 'low' then n between 1 and 18 when 'high' then n between 19 and 36
      when 'dozen' then n > 0 and (n - 1) / 12 + 1 = v
      when 'col' then n > 0 and (n - 1) % 3 + 1 = v end;
    if won then v_win := v_win + a::bigint * case t when 'n' then 36 when 'dozen' then 3 when 'col' then 3 else 2 end; end if;
  end loop;
  v_win := least(v_win, coalesce((c ->> 'max_win')::int, 100000));
  v_bal := private.casino_move(me, 'roulette', v_win::int - tot, true);
  insert into public.casino_rounds (user_id, game, bet, win, data, settled_at)
    values (me, 'roulette', tot, v_win, jsonb_build_object('n', n, 'b', p_bets), now()) returning id into v_id;
  return jsonb_build_object('id', v_id, 'n', n, 'win', v_win, 'bet', tot, 'coins', v_bal);
end $$;

-- 5. blackjack -------------------------------------------------------------------------------------

create or replace function private.bj_val(h text[]) returns integer
language plpgsql immutable set search_path = '' as $$
declare t int := 0; aces int := 0; c text; r text;
begin
  foreach c in array coalesce(h, '{}') loop
    r := left(c, length(c) - 1);
    if r = 'A' then t := t + 11; aces := aces + 1;
    elsif r in ('K', 'Q', 'J', '10') then t := t + 10;
    else t := t + r::int; end if;
  end loop;
  while t > 21 and aces > 0 loop t := t - 10; aces := aces - 1; end loop;
  return t;
end $$;

-- what the player sees: the dealer's second card stays face down until the hand ends
create or replace function private.bj_view(p_round bigint) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare o record; v_s jsonb; p text[]; d text[];
begin
  select * into o from public.casino_rounds where id = p_round;
  select cs.s into v_s from private.casino_secret cs where cs.round_id = p_round;
  p := array(select jsonb_array_elements_text(o.data -> 'p'));
  d := array(select jsonb_array_elements_text(coalesce(o.data -> 'd', v_s -> 'd')));
  return jsonb_build_object('id', o.id, 'state', o.state, 'bet', o.bet, 'win', o.win, 'p', to_jsonb(p), 'pv', private.bj_val(p),
    'd', case when o.state = 'open' then jsonb_build_array(d[1]) else to_jsonb(d) end,
    'dv', case when o.state = 'open' then private.bj_val(array[d[1]]) else private.bj_val(d) end,
    'end', o.data -> 'end', 'dbl', coalesce((o.data ->> 'dbl')::boolean, false),
    'coins', (select coins from public.profiles where id = o.user_id));
end $$;

-- the hand ends: the dealer draws to 17 (unless the player went over), the bet is paid
create or replace function private.bj_finish(p_round bigint) returns void
language plpgsql security definer set search_path = '' as $$
declare o record; v_s jsonb; p text[]; d text[]; deck text[]; pv int; dv int; pbj boolean; dbj boolean; m numeric; v_end text; v_win int;
begin
  select * into o from public.casino_rounds where id = p_round for update;
  if o.state <> 'open' then return; end if;
  select cs.s into v_s from private.casino_secret cs where cs.round_id = p_round for update;
  p := array(select jsonb_array_elements_text(o.data -> 'p'));
  d := array(select jsonb_array_elements_text(v_s -> 'd'));
  deck := array(select jsonb_array_elements_text(v_s -> 'deck'));
  pv := private.bj_val(p); pbj := pv = 21 and cardinality(p) = 2;
  dbj := private.bj_val(d) = 21 and cardinality(d) = 2;
  if pv <= 21 and not pbj and not dbj then
    while private.bj_val(d) < 17 loop d := d || deck[1]; deck := deck[2:]; end loop;
  end if;
  dv := private.bj_val(d);
  if pv > 21 then m := 0; v_end := 'bust';
  elsif pbj and dbj then m := 1; v_end := 'push';
  elsif pbj then m := 2.5; v_end := 'bj';
  elsif dbj then m := 0; v_end := 'dbj';
  elsif dv > 21 then m := 2; v_end := 'dbust';
  elsif pv > dv then m := 2; v_end := 'win';
  elsif pv = dv then m := 1; v_end := 'push';
  else m := 0; v_end := 'lose'; end if;
  v_win := least(floor(o.bet * m)::int, coalesce((private.casino_cfg() ->> 'max_win')::int, 100000));
  if v_win > 0 then perform private.casino_move(o.user_id, 'bj', v_win, false); end if;
  update public.casino_rounds set state = 'done', win = v_win, settled_at = now(),
    data = data || jsonb_build_object('d', to_jsonb(d), 'end', v_end) where id = p_round;
  update private.casino_secret set s = jsonb_build_object('d', to_jsonb(d), 'deck', to_jsonb(deck)) where round_id = p_round;
end $$;

-- a new hand; an unfinished one comes back instead
create or replace function public.bj_deal(p_bet integer) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); v_open bigint; deck text[]; p text[]; d text[]; v_id bigint;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  select id into v_open from public.casino_rounds where user_id = me and game = 'bj' and state = 'open' order by id desc limit 1;
  if v_open is not null then return private.bj_view(v_open); end if;
  perform private.casino_check(me, 'bj', p_bet);
  perform private.casino_hold(me, p_bet);
  deck := array(select r || s from unnest(array['A','2','3','4','5','6','7','8','9','10','J','Q','K']) r
                cross join unnest(array['S','H','D','C']) s order by extensions.gen_random_bytes(8));
  p := array[deck[1], deck[3]]; d := array[deck[2], deck[4]]; deck := deck[5:];
  perform private.casino_move(me, 'bj', -p_bet, true);
  insert into public.casino_rounds (user_id, game, bet, state, data) values (me, 'bj', p_bet, 'open', jsonb_build_object('p', to_jsonb(p)))
    returning id into v_id;
  insert into private.casino_secret (round_id, s) values (v_id, jsonb_build_object('d', to_jsonb(d), 'deck', to_jsonb(deck)));
  -- a blackjack on either side ends the hand at once
  if private.bj_val(p) = 21 or private.bj_val(d) = 21 then perform private.bj_finish(v_id); end if;
  return private.bj_view(v_id);
end $$;

-- hit, stand or double (double: on the first two cards, one more card, the bet doubles)
create or replace function public.bj_act(p_round bigint, p_act text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); o record; v_s jsonb; p text[]; deck text[];
begin
  if me is null then raise exception 'not_signed_in'; end if;
  select * into o from public.casino_rounds where id = p_round and user_id = me and game = 'bj' for update;
  if o.id is null then raise exception 'not_found'; end if;
  if o.state <> 'open' then return private.bj_view(p_round); end if;
  select cs.s into v_s from private.casino_secret cs where cs.round_id = p_round for update;
  p := array(select jsonb_array_elements_text(o.data -> 'p'));
  deck := array(select jsonb_array_elements_text(v_s -> 'deck'));
  if p_act = 'stand' then
    perform private.bj_finish(p_round);
  elsif p_act in ('hit', 'double') then
    if p_act = 'double' then
      if cardinality(p) <> 2 then raise exception 'bad_request'; end if;
      perform private.casino_check(me, 'bj', o.bet);
      perform private.casino_hold(me, o.bet);
      perform private.casino_move(me, 'bj', -o.bet, false);
      update public.casino_rounds set bet = bet * 2, data = data || '{"dbl": true}'::jsonb where id = p_round;
    end if;
    p := p || deck[1]; deck := deck[2:];
    update public.casino_rounds set data = data || jsonb_build_object('p', to_jsonb(p)) where id = p_round;
    update private.casino_secret set s = v_s || jsonb_build_object('deck', to_jsonb(deck)) where round_id = p_round;
    if p_act = 'double' or private.bj_val(p) >= 21 then perform private.bj_finish(p_round); end if;
  else
    raise exception 'bad_request';
  end if;
  return private.bj_view(p_round);
end $$;

-- 6. the aviator -----------------------------------------------------------------------------------
-- the multiplier grows as e^(0.11 t), t in seconds from the start; the plane flies away at the crash point.
-- cashing out is checked against the server's clock; an automatic cash-out pays at its mark if the plane gets there.

create or replace function private.av_now(p_t0 numeric) returns numeric
language sql volatile set search_path = '' as $$
  select exp(0.11 * greatest(0, extract(epoch from clock_timestamp()) - p_t0)) $$;

create or replace function private.av_view(p_round bigint) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
declare o record;
begin
  select * into o from public.casino_rounds where id = p_round;
  return jsonb_build_object('id', o.id, 'state', o.state, 'bet', o.bet, 'win', o.win, 't0', o.data -> 't0', 'auto', o.data -> 'auto',
    'm', o.data -> 'm', 'crash', case when o.state = 'done' then o.data -> 'crash' end, 'k', 0.11,
    'now', extract(epoch from clock_timestamp()), 'coins', (select coins from public.profiles where id = o.user_id));
end $$;

-- settles a flying round if it can be settled now: the auto mark reached, or the plane gone. p_out: the player cashes out
create or replace function private.av_settle(p_round bigint, p_out boolean) returns void
language plpgsql security definer set search_path = '' as $$
declare o record; v_crash numeric; v_auto numeric; m numeric; v_m numeric := null; v_win int := 0;
begin
  select * into o from public.casino_rounds where id = p_round for update;
  if o.state <> 'open' then return; end if;
  select (cs.s ->> 'crash')::numeric into v_crash from private.casino_secret cs where cs.round_id = p_round;
  v_auto := (o.data ->> 'auto')::numeric;
  m := private.av_now((o.data ->> 't0')::numeric);
  if v_auto is not null and v_auto < v_crash and m >= v_auto then v_m := v_auto;
  elsif m >= v_crash then v_m := null;
  elsif p_out then v_m := floor(m * 100) / 100;
  else return; end if;
  if v_m is not null then
    v_win := least(floor(o.bet * v_m)::int, coalesce((private.casino_cfg() ->> 'max_win')::int, 100000));
    if v_win > 0 then perform private.casino_move(o.user_id, 'aviator', v_win, false); end if;
  end if;
  update public.casino_rounds set state = 'done', win = v_win, settled_at = now(),
    data = data || jsonb_build_object('crash', v_crash, 'm', v_m) where id = p_round;
end $$;

-- a new flight; an unfinished one is settled first, or comes back if the plane is still in the air
create or replace function public.av_start(p_bet integer, p_auto numeric default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); v_open bigint; u numeric; v_crash numeric; v_id bigint;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  for v_open in select id from public.casino_rounds where user_id = me and game = 'aviator' and state = 'open' loop
    perform private.av_settle(v_open, false);
  end loop;
  select id into v_open from public.casino_rounds where user_id = me and game = 'aviator' and state = 'open' order by id desc limit 1;
  if v_open is not null then return private.av_view(v_open); end if;
  if p_auto is not null and (p_auto < 1.01 or p_auto > 200) then raise exception 'bad_request'; end if;
  perform private.casino_check(me, 'aviator', p_bet);
  perform private.casino_hold(me, p_bet);
  u := (private.rnd31() + 1)::numeric / 2147483648;  -- uniform in (0, 1]
  v_crash := least(200, greatest(1, floor(100 * 0.97 / u) / 100));
  perform private.casino_move(me, 'aviator', -p_bet, true);
  insert into public.casino_rounds (user_id, game, bet, state, data)
    values (me, 'aviator', p_bet, 'open', jsonb_build_object('t0', extract(epoch from clock_timestamp()), 'auto', round(p_auto, 2)))
    returning id into v_id;
  insert into private.casino_secret (round_id, s) values (v_id, jsonb_build_object('crash', v_crash));
  return private.av_view(v_id);
end $$;

-- while flying: has the plane gone, or the auto mark been reached?
create or replace function public.av_tick(p_round bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid();
begin
  if not exists (select 1 from public.casino_rounds where id = p_round and user_id = me and game = 'aviator') then raise exception 'not_found'; end if;
  perform private.av_settle(p_round, false);
  return private.av_view(p_round);
end $$;

create or replace function public.av_cashout(p_round bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid();
begin
  if not exists (select 1 from public.casino_rounds where id = p_round and user_id = me and game = 'aviator') then raise exception 'not_found'; end if;
  perform private.av_settle(p_round, true);
  return private.av_view(p_round);
end $$;

-- 7. the admin: limits, games on and off, what was bet and won -------------------------------------

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
      from jsonb_each(p_cfg -> 'games') where key in ('slot', 'roulette', 'bj', 'aviator')));
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
      from unnest(array['slot', 'roulette', 'bj', 'aviator']) g
      left join public.casino_rounds r on r.game = g and r.created_at >= now() - interval '7 days' and r.state = 'done'
      group by g) t),
    'top', (select coalesce(jsonb_agg(jsonb_build_object('u', user_id, 'net', net, 'n', n) order by net desc), '[]'::jsonb) from (
      select user_id, sum(win - bet) net, count(*) n from public.casino_rounds where created_at >= v_day and state = 'done'
      group by user_id order by sum(win - bet) desc limit 5) t));
end $$;

-- 8. who may call what ------------------------------------------------------------------------------

revoke all on function public.casino_info() from public, anon;
revoke all on function public.casino_mine(text) from public, anon;
revoke all on function public.slot_spin(integer) from public, anon;
revoke all on function public.roulette_spin(jsonb) from public, anon;
revoke all on function public.bj_deal(integer) from public, anon;
revoke all on function public.bj_act(bigint, text) from public, anon;
revoke all on function public.av_start(integer, numeric) from public, anon;
revoke all on function public.av_tick(bigint) from public, anon;
revoke all on function public.av_cashout(bigint) from public, anon;
revoke all on function public.admin_casino_set(jsonb) from public, anon;
revoke all on function public.admin_casino_stats() from public, anon;
grant execute on function public.casino_info(), public.casino_mine(text), public.slot_spin(integer), public.roulette_spin(jsonb),
  public.bj_deal(integer), public.bj_act(bigint, text), public.av_start(integer, numeric), public.av_tick(bigint), public.av_cashout(bigint),
  public.admin_casino_set(jsonb), public.admin_casino_stats() to authenticated;
