-- online joker run by the server: the deal, the rules and the bots live here, so no phone ever holds another player's cards.
-- A table opened with state {srv:true} is played only through these functions: jks_start (the host), jks_act (a move from the
-- player whose turn it is), jks_tick (any player at the table: it makes the move that is due — a bot's, an absent player's, one
-- whose time ran out — clears a finished trick and deals the next hand), jks_hand (your own cards). Hands are kept in
-- private.jk_deal, which no client can read. Public tables are listed in a lobby (jks_lobby) and found by jks_quick; a finished game
-- with two or more people moves their joker rating and this week's league points (jk_ratings) and their statistics (jk_stats).

alter table public.jk_tables drop constraint if exists jk_tables_len_check;
alter table public.jk_tables add constraint jk_tables_len_check check (len in ('quick', 'full', 'nines'));
alter table public.jk_tables add column if not exists pub boolean not null default false;
create index if not exists jk_tables_pub_idx on public.jk_tables (status, updated_at desc) where pub;
grant update (pub) on public.jk_tables to authenticated;
grant insert (host, len, seats, state, pub) on public.jk_tables to authenticated;

create table if not exists private.jk_deal (
  table_id bigint not null references public.jk_tables(id) on delete cascade,
  seat smallint not null check (seat between 0 and 3),
  cards jsonb not null default '[]'::jsonb,
  first3 jsonb not null default '[]'::jsonb,
  primary key (table_id, seat));
alter table private.jk_deal enable row level security;
revoke all on private.jk_deal from public, anon, authenticated;

create table if not exists public.jk_ratings (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  rating int not null default 1500,
  games int not null default 0,
  wins int not null default 0,
  week date,
  week_pts int not null default 0,
  updated_at timestamptz not null default now());
alter table public.jk_ratings enable row level security;
create policy "joker ratings visible" on public.jk_ratings for select using (true);
revoke all on public.jk_ratings from anon;
grant select on public.jk_ratings to authenticated;

create table if not exists public.jk_stats (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  g int not null default 0, w int not null default 0, hands int not null default 0, exact int not null default 0,
  kh int not null default 0, prem int not null default 0, best int, sum bigint not null default 0,
  bids int not null default 0, took int not null default 0, online int not null default 0,
  updated_at timestamptz not null default now());
alter table public.jk_stats enable row level security;
create policy "joker stats visible" on public.jk_stats for select using (true);
revoke all on public.jk_stats from anon;
grant select on public.jk_stats to authenticated;

-- ---------- the rules ----------
create or replace function private.jks_ms() returns bigint language sql volatile set search_path to '' as
$f$ select (extract(epoch from clock_timestamp()) * 1000)::bigint $f$;
create or replace function private.jks_seq(len text) returns int[] language sql immutable set search_path to '' as
$f$ select case len when 'full' then array[1,2,3,4,5,6,7,8,9,9,9,9,8,7,6,5,4,3,2,1,9,9,9,9] when 'nines' then array_fill(9, array[16]) else array[1,2,3,4,5,6,7,8] end $f$;
create or replace function private.jks_sec(len text, h int) returns int language sql immutable set search_path to '' as
$f$ select case len when 'full' then case when h < 8 then 0 when h < 12 then 1 when h < 20 then 2 else 3 end when 'nines' then least(3, h / 4) else 0 end $f$;
create or replace function private.jks_secend(len text, h int) returns boolean language sql immutable set search_path to '' as
$f$ select case len when 'full' then h in (7, 11, 19, 23) when 'nines' then h % 4 = 3 else h = 7 end $f$;
-- bid and made: 50 a trick plus 50; all tricks bid and taken: 100 a trick; pass and none: 50; otherwise 10 a trick; bid and none: the ხიშტი
create or replace function private.jks_pts(b int, t int, n int, kh int) returns int language sql immutable set search_path to '' as
$f$ select case when t = b then case when b = n then 100 * n when b = 0 then 50 else 50 * b + 50 end when b > 0 and t = 0 then -kh else 10 * t end $f$;
create or replace function private.jks_val(c jsonb, trump text) returns int language sql immutable set search_path to '' as
$f$ select case when c ? 'j' then 60 when trump is not null and c->>'s' = trump then 20 + (c->>'r')::int else (c->>'r')::int end $f$;
create or replace function private.jks_suit(e jsonb) returns text language sql immutable set search_path to '' as
$f$ select case when e->'card' ? 'j' then e->>'js' else e->'card'->>'s' end $f$;

-- what may be played: follow the suit (a high joker led asks for the top card of it); without it, trump; a joker always
create or replace function private.jks_legal(hand jsonb, trick jsonb, trump text) returns jsonb language plpgsql immutable set search_path to '' as $f$
declare lead jsonb; suit text; jk jsonb; ofs jsonb; tr jsonb; mx int;
begin
  if trick is null or jsonb_array_length(trick) = 0 then return hand; end if;
  lead := trick->0; suit := private.jks_suit(lead);
  select coalesce(jsonb_agg(c), '[]'::jsonb) into jk from jsonb_array_elements(hand) c where c ? 'j';
  select coalesce(jsonb_agg(c), '[]'::jsonb) into ofs from jsonb_array_elements(hand) c where not c ? 'j' and c->>'s' = suit;
  if jsonb_array_length(ofs) > 0 then
    if lead->'card' ? 'j' and lead->>'jm' = 'hi' then
      select max((c->>'r')::int) into mx from jsonb_array_elements(ofs) c;
      select coalesce(jsonb_agg(c), '[]'::jsonb) into ofs from jsonb_array_elements(ofs) c where (c->>'r')::int = mx;
    end if;
    return ofs || jk;
  end if;
  if trump is not null then
    select coalesce(jsonb_agg(c), '[]'::jsonb) into tr from jsonb_array_elements(hand) c where not c ? 'j' and c->>'s' = trump;
    if jsonb_array_length(tr) > 0 then return tr || jk; end if;
  end if;
  return hand;
end $f$;

-- who takes the trick: a later high joker beats an earlier one; a high joker that led a plain suit loses to a trump;
-- a low joker that led wins only if nobody followed, trumped or played a high joker
create or replace function private.jks_winner(t jsonb, trump text) returns int language plpgsql immutable set search_path to '' as $f$
declare lead jsonb := t->0; suit text; trumped boolean; i int; e jsonb; v int; bv int := -100000; best int := 0;
begin
  suit := private.jks_suit(lead);
  trumped := trump is not null and exists (select 1 from jsonb_array_elements(t) x where not x->'card' ? 'j' and x->'card'->>'s' = trump);
  for i in 0 .. jsonb_array_length(t) - 1 loop
    e := t->i;
    if e->'card' ? 'j' then v := case when e->>'jm' = 'hi' then case when i = 0 and trumped and (lead->>'js') is distinct from trump then 99 else 1000 + i end else -1 end;
    elsif trump is not null and e->'card'->>'s' = trump then v := 100 + (e->'card'->>'r')::int;
    elsif e->'card'->>'s' = suit then v := (e->'card'->>'r')::int;
    else v := 0; end if;
    if v > bv then bv := v; best := i; end if;
  end loop;
  if bv <= 0 then return (lead->>'p')::int; end if;
  return (t->best->>'p')::int;
end $f$;

-- ---------- the bots (the same heads as the game against the computer, at its middle level) ----------
create or replace function private.jks_bot_trump(f3 jsonb) returns text language sql immutable set search_path to '' as $f$
  select s from (select c->>'s' s, sum((c->>'r')::int) v from jsonb_array_elements(f3) c where not c ? 'j' group by 1) x where v >= 11 order by v desc, s limit 1
$f$;
create or replace function private.jks_bot_bid(hand jsonb, trump text, n int, forb int) returns int language plpgsql immutable set search_path to '' as $f$
declare e numeric := 0; c jsonb; r int; ln int; nt int; b int; s text;
begin
  select count(*) into nt from jsonb_array_elements(hand) x where trump is not null and not x ? 'j' and x->>'s' = trump;
  for c in select * from jsonb_array_elements(hand) loop
    if c ? 'j' then e := e + 1; continue; end if;
    r := (c->>'r')::int;
    select count(*) into ln from jsonb_array_elements(hand) x where not x ? 'j' and x->>'s' = c->>'s';
    if trump is not null and c->>'s' = trump then e := e + case r when 14 then .95 when 13 then .8 when 12 then .55 when 11 then .4 else .25 end;
    else e := e + case when r = 14 then case when ln <= 3 then .8 else .6 end when r = 13 then case when ln between 2 and 4 then .4 else .2 end else 0 end; end if;
  end loop;
  if trump is not null and nt >= 4 then e := e + (nt - 3) * .3; end if;
  if trump is not null and nt > 0 then
    foreach s in array array['s','c','h','d'] loop
      if s <> trump and not exists (select 1 from jsonb_array_elements(hand) x where not x ? 'j' and x->>'s' = s) then e := e + least(nt, 2) * .3; end if;
    end loop;
  end if;
  b := greatest(0, least(n, round(e)::int));
  if b = forb then b := case when b > 0 then b - 1 else b + 1 end; end if;
  return least(n, b);
end $f$;
create or replace function private.jks_bot_play(hand jsonb, trick jsonb, trump text, need int, p int) returns jsonb language plpgsql immutable set search_path to '' as $f$
declare L jsonb := private.jks_legal(hand, trick, trump); nj jsonb; jk jsonb; c jsonb; best jsonb; bv int; v int; anyS text;
begin
  select coalesce(jsonb_agg(x order by private.jks_val(x, trump)), '[]'::jsonb) into nj from jsonb_array_elements(L) x where not x ? 'j';
  select x into jk from jsonb_array_elements(L) x where x ? 'j' limit 1;
  anyS := coalesce(trump, (array['s','c','h','d'])[1 + floor(random() * 4)::int]);
  if jsonb_array_length(trick) = 0 then
    if need > 0 then
      c := nj->(jsonb_array_length(nj) - 1);
      if c is not null and ((c->>'r')::int = 14 or (trump is not null and c->>'s' = trump and (c->>'r')::int >= 13)) then return jsonb_build_object('c', c); end if;
      if jk is not null then return jsonb_build_object('c', jk, 'jm', 'hi', 'js', anyS); end if;
      return jsonb_build_object('c', coalesce(c, L->0));
    end if;
    if jsonb_array_length(nj) > 0 then return jsonb_build_object('c', nj->0); end if;
    return jsonb_build_object('c', L->0, 'jm', 'lo', 'js', coalesce(trump, 'h'));
  end if;
  if need > 0 then
    for c in select * from jsonb_array_elements(nj) loop
      if private.jks_winner(trick || jsonb_build_array(jsonb_build_object('p', p, 'card', c)), trump) = p then return jsonb_build_object('c', c); end if;
    end loop;
    if jk is not null and private.jks_winner(trick || jsonb_build_array(jsonb_build_object('p', p, 'card', jk, 'jm', 'hi')), trump) = p then
      return jsonb_build_object('c', jk, 'jm', 'hi'); end if;
    return jsonb_build_object('c', coalesce(nj->0, L->0), 'jm', 'lo');
  end if;
  best := null; bv := -1;
  for c in select * from jsonb_array_elements(nj) loop
    if private.jks_winner(trick || jsonb_build_array(jsonb_build_object('p', p, 'card', c)), trump) <> p then
      v := private.jks_val(c, trump); if v > bv then bv := v; best := c; end if; end if;
  end loop;
  if best is not null then return jsonb_build_object('c', best); end if;
  if jk is not null then return jsonb_build_object('c', jk, 'jm', 'lo'); end if;
  return jsonb_build_object('c', nj->0);
end $f$;

-- ---------- the game ----------
-- a new deal: shuffled with the database's strong random, five cards' worth of rules kept in the state
create or replace function private.jks_deal(p_table bigint, st jsonb) returns jsonb language plpgsql volatile set search_path to '' as $f$
declare n int; d jsonb; s int; dealer int; tc jsonb;
begin
  n := (private.jks_seq(st->>'len'))[(st->>'h')::int + 1];
  dealer := (((st->>'dealer')::int) + 1) % 4;
  select jsonb_agg(c order by gen_random_uuid()) into d from (
    select jsonb_build_object('s', s0, 'r', r0) c from unnest(array['s','c','h','d']) s0, generate_series(6, 14) r0 where not (r0 = 6 and s0 in ('s','c'))
    union all select '{"j":1}'::jsonb union all select '{"j":2}'::jsonb) x;
  delete from private.jk_deal where table_id = p_table;
  for s in 0 .. 3 loop
    insert into private.jk_deal (table_id, seat, cards, first3)
    select p_table, s, coalesce(jsonb_agg(d->k order by k), '[]'::jsonb), coalesce(jsonb_agg(d->k order by k) filter (where k < s * n + 3), '[]'::jsonb)
    from generate_series(s * n, (s + 1) * n - 1) k;
  end loop;
  st := st || jsonb_build_object('n', n, 'dealer', dealer, 'bids', '[null,null,null,null]'::jsonb, 'taken', '[0,0,0,0]'::jsonb, 'trick', '[]'::jsonb,
    'win', null, 'cur', (dealer + 1) % 4, 'deal', coalesce((st->>'deal')::int, 0) + 1, 'counts', jsonb_build_array(n, n, n, n), 'last', null);
  if n < 9 then tc := d->(4 * n); st := st || jsonb_build_object('trumpCard', tc, 'trump', case when tc ? 'j' then null else tc->>'s' end, 'phase', 'bid');
  else st := st || jsonb_build_object('trumpCard', null, 'trump', null, 'phase', 'trump', 'counts', '[3,3,3,3]'::jsonb); end if;
  return st;
end $f$;

-- when the person to move must have moved by (0: a bot or an absent player, who moves at the bots' pace)
create or replace function private.jks_dl(t record, st jsonb) returns jsonb language plpgsql volatile set search_path to '' as $f$
declare c int := (st->>'cur')::int; tt int := coalesce((st->'opt'->>'tt')::int, 60);
begin
  st := jsonb_set(st, '{at}', to_jsonb(private.jks_ms()));
  if c is null or c < 0 or st->>'phase' not in ('trump','bid','play') or st->'win' <> 'null'::jsonb or t.seats[c + 1] is null or coalesce((st->'away'->>c)::boolean, false)
    then return jsonb_set(st, '{dl}', '0'); end if;
  return jsonb_set(st, '{dl}', to_jsonb(private.jks_ms() + tt * 1000));
end $f$;

-- the end of a hand: score it, and the section premium when a section ends
create or replace function private.jks_score(st jsonb) returns jsonb language plpgsql immutable set search_path to '' as $f$
declare len text := st->>'len'; h int := (st->>'h')::int; n int := (st->>'n')::int; sec int; kh int; o jsonb := coalesce(st->'opt', '{}'::jsonb);
  pts int[] := array[0,0,0,0]; sc int[]; p int; b int; tk int; hist jsonb := coalesce(st->'hist', '[]'::jsonb); pr int[] := array[0,0,0,0];
  allm boolean; best int; anym boolean := false; rows jsonb;
begin
  sec := private.jks_sec(len, h);
  kh := case o->>'kh' when '200' then 200 when '500' then 500 when '0' then 0 else case when len = 'nines' or sec % 2 = 1 then 500 else 200 end end;
  select array_agg(x::int order by i) into sc from jsonb_array_elements_text(st->'score') with ordinality a(x, i);
  for p in 0 .. 3 loop
    b := (st->'bids'->>p)::int; tk := (st->'taken'->>p)::int; pts[p + 1] := private.jks_pts(b, tk, n, kh); sc[p + 1] := sc[p + 1] + pts[p + 1];
  end loop;
  hist := hist || jsonb_build_array(jsonb_build_object('n', n, 'b', st->'bids', 't', st->'taken', 'p', to_jsonb(pts), 's', sec));
  if coalesce((o->>'prem')::boolean, true) and private.jks_secend(len, h) then
    select coalesce(jsonb_agg(r), '[]'::jsonb) into rows from jsonb_array_elements(hist) r where not r ? 'pr' and (r->>'s')::int = sec;
    for p in 0 .. 3 loop
      select bool_and((r->'b'->>p)::int = (r->'t'->>p)::int) into allm from jsonb_array_elements(rows) r;
      if allm then anym := true; end if;
    end loop;
    for p in 0 .. 3 loop
      select bool_and((r->'b'->>p)::int = (r->'t'->>p)::int), greatest(0, max((r->'p'->>p)::int)) into allm, best from jsonb_array_elements(rows) r;
      pr[p + 1] := case when allm then best when anym then -best else 0 end;
      sc[p + 1] := sc[p + 1] + pr[p + 1];
    end loop;
    if pr <> array[0,0,0,0] then hist := hist || jsonb_build_array(jsonb_build_object('pr', 1, 'n', 0, 's', sec, 'b', '[]'::jsonb, 't', '[]'::jsonb, 'p', to_jsonb(pr))); end if;
  end if;
  return st || jsonb_build_object('score', to_jsonb(sc), 'hist', hist, 'h', h + 1);
end $f$;

-- a game is over: ratings (against the other people at the table), this week's league points and everyone's statistics
create or replace function private.jks_finish(t record, st jsonb) returns void language plpgsql volatile set search_path to '' as $f$
declare sc int[]; mx int; ppl int[] := '{}'; p int; q int; d numeric; e numeric; s numeric; k numeric; rk int; wk date := date_trunc('week', now())::date;
  rows jsonb := coalesce(st->'hist', '[]'::jsonb); dr numeric[] := array[0,0,0,0];
begin
  select array_agg(x::int order by i) into sc from jsonb_array_elements_text(st->'score') with ordinality a(x, i);
  mx := greatest(sc[1], sc[2], sc[3], sc[4]);
  for p in 0 .. 3 loop if t.seats[p + 1] is not null then ppl := ppl || p; end if; end loop;
  foreach p in array ppl loop
    insert into public.jk_stats (user_id) values (t.seats[p + 1]) on conflict (user_id) do nothing;
    update public.jk_stats set g = g + 1, w = w + (sc[p + 1] = mx)::int, online = online + 1, sum = sum + sc[p + 1], best = greatest(coalesce(best, sc[p + 1]), sc[p + 1]),
      hands = hands + (select count(*) from jsonb_array_elements(rows) x where not x ? 'pr'),
      exact = exact + (select count(*) from jsonb_array_elements(rows) x where not x ? 'pr' and (x->'b'->>p)::int = (x->'t'->>p)::int),
      kh = kh + (select count(*) from jsonb_array_elements(rows) x where not x ? 'pr' and (x->'b'->>p)::int > 0 and (x->'t'->>p)::int = 0),
      prem = prem + (select count(*) from jsonb_array_elements(rows) x where x ? 'pr' and (x->'p'->>p)::int > 0),
      bids = bids + (select coalesce(sum((x->'b'->>p)::int), 0) from jsonb_array_elements(rows) x where not x ? 'pr'),
      took = took + (select coalesce(sum((x->'t'->>p)::int), 0) from jsonb_array_elements(rows) x where not x ? 'pr'),
      updated_at = now() where user_id = t.seats[p + 1];
  end loop;
  if coalesce(array_length(ppl, 1), 0) < 2 then return; end if;
  foreach p in array ppl loop insert into public.jk_ratings (user_id) values (t.seats[p + 1]) on conflict (user_id) do nothing; end loop;
  k := 24.0 / (array_length(ppl, 1) - 1);
  foreach p in array ppl loop
    d := 0;
    foreach q in array ppl loop
      if q <> p then
        select 1.0 / (1 + power(10, ((b.rating - a.rating)::numeric) / 400)) into e from public.jk_ratings a, public.jk_ratings b where a.user_id = t.seats[p + 1] and b.user_id = t.seats[q + 1];
        s := case when sc[p + 1] > sc[q + 1] then 1 when sc[p + 1] = sc[q + 1] then .5 else 0 end;
        d := d + k * (s - e);
      end if;
    end loop;
    dr[p + 1] := d;
  end loop;
  foreach p in array ppl loop
    rk := (select count(*) from unnest(sc) x where x > sc[p + 1]);
    update public.jk_ratings set rating = greatest(100, rating + round(dr[p + 1])::int), games = games + 1, wins = wins + (sc[p + 1] = mx)::int,
      week_pts = case when week = wk then week_pts else 0 end + greatest(0, 3 - rk), week = wk, updated_at = now() where user_id = t.seats[p + 1];
  end loop;
end $f$;

-- one move for the seat to move (checked), then the state that follows; p_mv: {k:'trump',s} | {k:'bid',v} | {k:'card',c,jm,js}
create or replace function private.jks_move(t record, st jsonb, seat int, mv jsonb) returns jsonb language plpgsql volatile set search_path to '' as $f$
declare ph text := st->>'phase'; n int := (st->>'n')::int; bids jsonb := st->'bids'; f int; v int; hand jsonb; c jsonb; L jsonb; tr jsonb; e jsonb; w int; lead boolean;
begin
  if (st->>'cur')::int is distinct from seat or st->'win' <> 'null'::jsonb then raise exception 'not_your_turn'; end if;
  if ph = 'trump' and mv->>'k' = 'trump' then
    st := st || jsonb_build_object('trump', case when mv->>'s' in ('s','c','h','d') then mv->>'s' end, 'phase', 'bid', 'cur', (((st->>'dealer')::int) + 1) % 4, 'counts', jsonb_build_array(n, n, n, n));
    return st;
  end if;
  if ph = 'bid' and mv->>'k' = 'bid' then
    v := floor((mv->>'v')::numeric)::int;
    if v is null or v < 0 or v > n then raise exception 'bad_move'; end if;
    if seat = (st->>'dealer')::int then f := n - (select coalesce(sum(x::int), 0) from jsonb_array_elements_text(bids) x where x <> 'null'); if v = f then raise exception 'bad_move'; end if; end if;
    bids := jsonb_set(bids, array[seat::text], to_jsonb(v));
    if not exists (select 1 from jsonb_array_elements(bids) x where x = 'null'::jsonb) then st := st || jsonb_build_object('bids', bids, 'phase', 'play', 'cur', (((st->>'dealer')::int) + 1) % 4);
    else st := st || jsonb_build_object('bids', bids, 'cur', (seat + 1) % 4); end if;
    return st;
  end if;
  if ph = 'play' and mv->>'k' = 'card' then
    select cards into hand from private.jk_deal d where d.table_id = t.id and d.seat = jks_move.seat for update;
    c := case when mv->'c' ? 'j' then jsonb_build_object('j', (mv->'c'->>'j')::int) else jsonb_build_object('s', mv->'c'->>'s', 'r', (mv->'c'->>'r')::int) end;
    L := private.jks_legal(hand, st->'trick', st->>'trump');
    if not exists (select 1 from jsonb_array_elements(L) x where x = c) then raise exception 'bad_move'; end if;
    lead := jsonb_array_length(st->'trick') = 0;
    select coalesce(jsonb_agg(x order by i), '[]'::jsonb) into hand from jsonb_array_elements(hand) with ordinality a(x, i)
      where i <> (select min(i2) from jsonb_array_elements(hand) with ordinality b(y, i2) where y = c);
    update private.jk_deal d set cards = hand where d.table_id = t.id and d.seat = jks_move.seat;
    e := jsonb_build_object('p', seat, 'card', c,
      'jm', case when c ? 'j' then case when mv->>'jm' = 'lo' then 'lo' else 'hi' end end,
      'js', case when c ? 'j' and lead then coalesce(case when mv->>'js' in ('s','c','h','d') then mv->>'js' end, (array['s','c','h','d'])[1 + floor(random() * 4)::int]) end);
    tr := (st->'trick') || jsonb_build_array(e);
    st := st || jsonb_build_object('trick', tr, 'counts', jsonb_set(st->'counts', array[seat::text], to_jsonb(jsonb_array_length(hand))));
    if jsonb_array_length(tr) < 4 then return st || jsonb_build_object('cur', (seat + 1) % 4); end if;
    w := private.jks_winner(tr, st->>'trump');
    return st || jsonb_build_object('win', w, 'cur', -1, 'taken', jsonb_set(st->'taken', array[w::text], to_jsonb(((st->'taken'->>w)::int) + 1)));
  end if;
  raise exception 'bad_move';
end $f$;

-- the move a bot makes for a seat (a bot's own, an absent player's, or one whose time is up)
create or replace function private.jks_auto(t record, st jsonb, seat int) returns jsonb language plpgsql volatile set search_path to '' as $f$
declare ph text := st->>'phase'; hand jsonb; f3 jsonb; n int := (st->>'n')::int; f int := -1; m jsonb;
begin
  select d.cards, d.first3 into hand, f3 from private.jk_deal d where d.table_id = t.id and d.seat = jks_auto.seat;
  if ph = 'trump' then return private.jks_move(t, st, seat, jsonb_build_object('k', 'trump', 's', private.jks_bot_trump(f3))); end if;
  if ph = 'bid' then
    if seat = (st->>'dealer')::int then f := n - (select coalesce(sum(x::int), 0) from jsonb_array_elements_text(st->'bids') x where x <> 'null'); end if;
    return private.jks_move(t, st, seat, jsonb_build_object('k', 'bid', 'v', private.jks_bot_bid(hand, st->>'trump', n, f)));
  end if;
  m := private.jks_bot_play(hand, st->'trick', st->>'trump', ((st->'bids'->>seat)::int) - ((st->'taken'->>seat)::int), seat);
  return private.jks_move(t, st, seat, jsonb_build_object('k', 'card', 'c', m->'c', 'jm', m->'jm', 'js', m->'js'));
end $f$;

-- write the state (the guard below lets only these functions do it while a game is on)
create or replace function private.jks_put(p_table bigint, st jsonb, p_status text) returns void language plpgsql volatile set search_path to '' as $f$
begin
  perform set_config('peera.jks', '1', true);
  update public.jk_tables set state = st, status = p_status, updated_at = now() where id = p_table;
  perform set_config('peera.jks', '', true);
end $f$;

create or replace function private.jks_guard() returns trigger language plpgsql set search_path to '' as $f$
begin
  if coalesce(current_setting('peera.jks', true), '') = '1' then return new; end if;
  if coalesce(old.state ? 'srv', false) or coalesce(new.state ? 'srv', false) then
    if old.status in ('play', 'over') then
      new.state := old.state; new.seats := old.seats; new.len := old.len; new.host := old.host;
      if new.status is distinct from 'closed' then new.status := old.status; end if;
    elsif new.status in ('play', 'over') then
      new.status := old.status;
    end if;
  end if;
  return new;
end $f$;
drop trigger if exists jk_tables_srv_guard on public.jk_tables;
create trigger jk_tables_srv_guard before update on public.jk_tables for each row execute function private.jks_guard();

-- ---------- what the app calls ----------
create or replace function public.jks_version() returns int language sql stable set search_path to '' as $f$ select 1 $f$;

-- the host starts the game: bots take the empty seats, the house rules are checked, the first hand is dealt
create or replace function public.jks_start(p_table bigint) returns jsonb language plpgsql security definer set search_path to '' as $f$
declare t record; o jsonb; st jsonb; names text[] := array['გურამი','რეზო','ლუკა','დათო','ნიკა','თამარი','ნინო','ანა','მარიამი','სალომე']; bots jsonb := '[null,null,null,null]'::jsonb; p int; nm text;
begin
  select * into t from public.jk_tables where id = p_table for update;
  if t.id is null or t.host is distinct from auth.uid() or t.status not in ('wait', 'over') or not coalesce(t.state ? 'srv', false) then raise exception 'not_allowed'; end if;
  o := coalesce(t.state->'opt', '{}'::jsonb);
  o := jsonb_build_object('kh', case when o->>'kh' in ('std','200','500','0') then o->>'kh' else 'std' end,
    'prem', coalesce((o->>'prem')::boolean, true), 'tt', case when (o->>'tt') in ('30','60','90') then (o->>'tt')::int else 60 end);
  for p in 0 .. 3 loop
    if t.seats[p + 1] is null then
      select x into nm from unnest(names) x where not exists (select 1 from jsonb_array_elements_text(bots) y where y = x) order by random() limit 1;
      bots := jsonb_set(bots, array[p::text], to_jsonb(nm));
    end if;
  end loop;
  st := jsonb_build_object('srv', true, 'pub', t.pub, 'opt', o, 'len', t.len, 'h', 0, 'score', '[0,0,0,0]'::jsonb, 'hist', '[]'::jsonb, 'bots', bots,
    'away', '[false,false,false,false]'::jsonb, 'dealer', floor(random() * 4)::int, 'deal', 0, 'seq', 0);
  st := private.jks_deal(p_table, st);
  st := private.jks_dl(t, st);
  perform private.jks_put(p_table, st, 'play');
  return st;
end $f$;

-- a move from the person whose turn it is
create or replace function public.jks_act(p_table bigint, p_move jsonb) returns jsonb language plpgsql security definer set search_path to '' as $f$
declare t record; st jsonb; v_seat int;
begin
  select * into t from public.jk_tables where id = p_table for update;
  if t.id is null or t.status <> 'play' or not coalesce(t.state ? 'srv', false) then raise exception 'not_allowed'; end if;
  v_seat := array_position(t.seats, auth.uid()) - 1;
  if v_seat is null then raise exception 'not_allowed'; end if;
  st := private.jks_move(t, t.state, v_seat, p_move);
  st := jsonb_set(st, array['away', v_seat::text], 'false');
  st := jsonb_set(st, '{seq}', to_jsonb(coalesce((st->>'seq')::int, 0) + 1));
  st := private.jks_dl(t, st);
  perform private.jks_put(p_table, st, 'play');
  return jsonb_build_object('state', st, 'hand', (select d.cards from private.jk_deal d where d.table_id = p_table and d.seat = v_seat));
end $f$;

-- whatever is due at the table, one step at a time, at the pace a person can follow:
-- a bot's or an absent player's move after 0.8 s, an automatic move when someone's time is up (they are then marked away),
-- a finished trick swept after 1.4 s, the next hand dealt 3.8 s after the last one ended
create or replace function public.jks_tick(p_table bigint) returns jsonb language plpgsql security definer set search_path to '' as $f$
declare t record; st jsonb; ph text; c int; at bigint; now_ms bigint := private.jks_ms(); fast boolean := coalesce(current_setting('peera.jks_fast', true), '') = '1';
  w int; seq int[]; human boolean; away boolean; dl bigint;
begin
  select * into t from public.jk_tables where id = p_table for update;
  if t.id is null or t.status <> 'play' or not coalesce(t.state ? 'srv', false) then return null; end if;
  if not coalesce(auth.uid() = any(t.seats), false) and t.host is distinct from auth.uid() then return t.state; end if;
  st := t.state; ph := st->>'phase'; c := (st->>'cur')::int; at := coalesce((st->>'at')::bigint, 0); dl := coalesce((st->>'dl')::bigint, 0);
  if ph = 'play' and st->'win' <> 'null'::jsonb then
    if not fast and now_ms - at < 1400 then return st; end if;
    w := (st->>'win')::int;
    st := st || jsonb_build_object('last', jsonb_build_object('t', st->'trick', 'w', w), 'trick', '[]'::jsonb, 'win', null, 'cur', w);
    if not exists (select 1 from jsonb_array_elements(st->'counts') x where x::int > 0) then
      st := private.jks_score(st) || jsonb_build_object('cur', -1);
      seq := private.jks_seq(st->>'len');
      if (st->>'h')::int >= array_length(seq, 1) then
        st := st || jsonb_build_object('phase', 'over', 'dl', 0, 'at', now_ms);
        perform private.jks_put(p_table, st, 'over'); perform private.jks_finish(t, st); return st;
      end if;
      st := st || jsonb_build_object('phase', 'handover', 'dl', 0, 'at', now_ms);
      perform private.jks_put(p_table, st, 'play'); return st;
    end if;
  elsif ph = 'handover' then
    if not fast and now_ms - at < 3800 then return st; end if;
    st := private.jks_deal(p_table, st);
  elsif ph in ('trump', 'bid', 'play') and c >= 0 then
    human := t.seats[c + 1] is not null; away := coalesce((st->'away'->>c)::boolean, false);
    if human and not away then
      if dl = 0 or now_ms < dl then return st; end if;
      st := jsonb_set(st, array['away', c::text], 'true');
    elsif not fast and now_ms - at < 800 then return st; end if;
    st := private.jks_auto(t, st, c);
  else
    return st;
  end if;
  st := jsonb_set(st, '{seq}', to_jsonb(coalesce((st->>'seq')::int, 0) + 1));
  st := private.jks_dl(t, st);
  perform private.jks_put(p_table, st, 'play');
  return st;
end $f$;

-- a player who was marked away is back at the table
create or replace function public.jks_back(p_table bigint) returns void language plpgsql security definer set search_path to '' as $f$
declare t record; seat int; st jsonb;
begin
  select * into t from public.jk_tables where id = p_table for update;
  if t.id is null or t.status <> 'play' or not coalesce(t.state ? 'srv', false) then return; end if;
  seat := array_position(t.seats, auth.uid()) - 1;
  if seat is null or not coalesce((t.state->'away'->>seat)::boolean, false) then return; end if;
  st := jsonb_set(t.state, array['away', seat::text], 'false');
  if (st->>'cur')::int = seat then st := private.jks_dl(t, st); end if;
  perform private.jks_put(p_table, st, 'play');
end $f$;

-- your own cards (the first three while the trump of a nine-card hand is being chosen)
create or replace function public.jks_hand(p_table bigint) returns jsonb language plpgsql stable security definer set search_path to '' as $f$
declare t record; v_seat int; r record;
begin
  select * into t from public.jk_tables where id = p_table;
  if t.id is null or not coalesce(t.state ? 'srv', false) then return null; end if;
  v_seat := array_position(t.seats, auth.uid()) - 1;
  if v_seat is null then return null; end if;
  select * into r from private.jk_deal d where d.table_id = p_table and d.seat = v_seat;
  if r.table_id is null then return jsonb_build_object('seat', v_seat, 'deal', t.state->'deal', 'cards', '[]'::jsonb); end if;
  return jsonb_build_object('seat', v_seat, 'deal', t.state->'deal', 'cards', case when t.state->>'phase' = 'trump' then r.first3 else r.cards end);
end $f$;

-- public tables: those waiting for players and those being played (to watch); not those of people who blocked you
create or replace function public.jks_lobby() returns table (id bigint, host uuid, len text, seats uuid[], status text, free int, updated_at timestamptz)
language sql stable security definer set search_path to '' as $f$
  select t.id, t.host, t.len, t.seats, t.status, (select count(*) from unnest(t.seats) s where s is null)::int, t.updated_at
  from public.jk_tables t
  where t.pub and coalesce(t.state ? 'srv', false) and not public.is_blocked(t.host, auth.uid())
    and ((t.status = 'wait' and t.updated_at > now() - interval '2 hours') or (t.status = 'play' and t.updated_at > now() - interval '10 minutes'))
  order by t.status = 'wait' desc, t.updated_at desc limit 30
$f$;

-- quick game: sit at a public table that waits for players at this length, or open one
create or replace function public.jks_quick(p_len text) returns bigint language plpgsql security definer set search_path to '' as $f$
declare t record; i int; me uuid := auth.uid(); v_id bigint; v_len text := case when p_len in ('quick','full','nines') then p_len else 'quick' end;
begin
  if me is null or not public.can_post() then raise exception 'not_allowed'; end if;
  for t in select * from public.jk_tables x where x.pub and x.status = 'wait' and x.len = v_len and coalesce(x.state ? 'srv', false)
    and x.updated_at > now() - interval '30 minutes' and not public.is_blocked(x.host, me) order by x.updated_at desc limit 20 for update skip locked loop
    if me = any(t.seats) then return t.id; end if;
    for i in 1 .. 4 loop
      if t.seats[i] is null then update public.jk_tables set seats[i] = me, updated_at = now() where jk_tables.id = t.id; return t.id; end if;
    end loop;
  end loop;
  insert into public.jk_tables (host, len, seats, state, pub) values (me, v_len, array[me, null, null, null]::uuid[], '{"srv":true}'::jsonb, true) returning jk_tables.id into v_id;
  return v_id;
end $f$;

-- the joker tables: by rating, or by this week's league points
create or replace function public.jks_top(p_kind text) returns table (user_id uuid, rating int, games int, wins int, week_pts int)
language sql stable security definer set search_path to '' as $f$
  select r.user_id, r.rating, r.games, r.wins, case when r.week = date_trunc('week', now())::date then r.week_pts else 0 end
  from public.jk_ratings r join public.profiles p on p.id = r.user_id
  where not p.banned and not public.is_blocked(r.user_id, auth.uid()) and (p_kind <> 'week' or r.week = date_trunc('week', now())::date)
  order by case when p_kind = 'week' then case when r.week = date_trunc('week', now())::date then r.week_pts else 0 end else r.rating end desc, r.games desc limit 50
$f$;

-- a game against the computer counts in your statistics too (what the app says, kept within what one game can be; once a minute at most)
create or replace function public.jk_stat_add(p jsonb) returns void language plpgsql security definer set search_path to '' as $f$
declare me uuid := auth.uid(); h int := least(greatest(coalesce((p->>'hands')::int, 0), 0), 24); last timestamptz;
begin
  if me is null or not exists (select 1 from public.profiles where id = me and onboarded and not banned) then return; end if;
  select updated_at into last from public.jk_stats where user_id = me;
  if last is not null and last > now() - interval '60 seconds' then return; end if;
  insert into public.jk_stats (user_id) values (me) on conflict (user_id) do nothing;
  update public.jk_stats set g = g + 1, w = w + (coalesce((p->>'w')::boolean, false))::int, hands = hands + h,
    exact = exact + least(greatest(coalesce((p->>'exact')::int, 0), 0), h), kh = kh + least(greatest(coalesce((p->>'kh')::int, 0), 0), h),
    prem = prem + least(greatest(coalesce((p->>'prem')::int, 0), 0), 4),
    best = greatest(coalesce(best, -100000), least(greatest(coalesce((p->>'score')::int, 0), -20000), 20000)),
    sum = sum + least(greatest(coalesce((p->>'score')::int, 0), -20000), 20000),
    bids = bids + least(greatest(coalesce((p->>'bids')::int, 0), 0), 9 * h), took = took + least(greatest(coalesce((p->>'took')::int, 0), 0), 9 * h),
    updated_at = now() where user_id = me;
end $f$;

-- a joker table can be taken over by another player's app only when it is run by an app (not by the server)
create or replace function public.jk_take_host(p_table bigint, p_old uuid)
returns boolean language plpgsql security definer set search_path to '' as $f$
declare t record;
begin
  select * into t from public.jk_tables where id = p_table for update;
  if t.id is null or t.status is distinct from 'play' or t.host is distinct from p_old or t.host = auth.uid()
     or not coalesce(auth.uid() = any(t.seats), false) or coalesce(t.state->>'g','joker') <> 'joker' or coalesce(t.state ? 'srv', false)
     or t.updated_at > now() - interval '20 seconds' then return false; end if;
  update public.jk_tables set host = auth.uid(), updated_at = now() where id = p_table;
  return true;
end $f$;

revoke all on function public.jks_version(), public.jks_start(bigint), public.jks_act(bigint, jsonb), public.jks_tick(bigint), public.jks_back(bigint),
  public.jks_hand(bigint), public.jks_lobby(), public.jks_quick(text), public.jks_top(text), public.jk_stat_add(jsonb) from public, anon;
grant execute on function public.jks_version(), public.jks_start(bigint), public.jks_act(bigint, jsonb), public.jks_tick(bigint), public.jks_back(bigint),
  public.jks_hand(bigint), public.jks_lobby(), public.jks_quick(text), public.jks_top(text), public.jk_stat_add(jsonb) to authenticated;
revoke all on function private.jks_ms(), private.jks_seq(text), private.jks_sec(text, int), private.jks_secend(text, int), private.jks_pts(int, int, int, int),
  private.jks_val(jsonb, text), private.jks_suit(jsonb), private.jks_legal(jsonb, jsonb, text), private.jks_winner(jsonb, text), private.jks_bot_trump(jsonb),
  private.jks_bot_bid(jsonb, text, int, int), private.jks_bot_play(jsonb, jsonb, text, int, int), private.jks_deal(bigint, jsonb), private.jks_score(jsonb),
  private.jks_put(bigint, jsonb, text) from public, anon, authenticated;
