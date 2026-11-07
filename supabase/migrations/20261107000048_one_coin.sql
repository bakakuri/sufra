-- A coin is a coin: every coin counts, from before the promotion and after it.
--
-- Until now the balance had two parts: coins_cash (paid out in lari) and the rest (spending only).
-- Now there is one kind of coin. coins_cash stays as a column, so nothing that reads it breaks,
-- but it always equals coins: every coin can be paid out (10,000 = 1 ₾), with the same conditions as before
-- (18+, verified, 30 days on Peera, 10,000 at least).
--
-- The promotion now means: paying out is open. When it ends or the admin stops it, coins stay and can be spent,
-- but no new payout request can be made until it is on again. Requests already sent are still decided.
--
-- Predictions are free only from now on: with every coin worth lari, a coin stake in a shared pool
-- would be a bet of money. A prediction still pays 1 coin, a right one 5.

-- 1. one kind of coin ----------------------------------------------------------------------------

create or replace function private.coins_clamp() returns trigger
language plpgsql set search_path = '' as $$
begin
  -- every coin counts: the part that can be paid out is the whole balance
  new.coins_cash := greatest(0, coalesce(new.coins, 0));
  return new;
end $$;

update public.profiles set coins_cash = greatest(0, coins) where coins_cash is distinct from greatest(0, coins);

comment on column public.profiles.coins_cash is 'Always equal to coins (one kind of coin since 20261107000048); kept for the functions that read it.';

-- 2. paying out is open while the promotion runs ---------------------------------------------------

create or replace function public.my_payouts() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare me uuid := auth.uid(); v_cfg jsonb := private.coin_cfg();
begin
  if me is null then raise exception 'not_signed_in'; end if;
  return private.payout_req(me) || jsonb_build_object(
    'rate', coalesce((v_cfg ->> 'rate')::int, 10000), 'min_out', coalesce((v_cfg ->> 'min_out')::int, 10000),
    'open', private.promo_on(), 'until', v_cfg -> 'until',
    'list', coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at desc, x.id desc) from (
      select id, coins, gel, iban, holder, status, note, created_at, decided_at from public.payouts
      where user_id = me order by created_at desc, id desc limit 20) x), '[]'::jsonb));
end $$;

create or replace function public.request_payout(p_coins integer, p_iban text, p_holder text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); v_cfg jsonb := private.coin_cfg(); v_rate int; v_min int; v_budget numeric; v_req jsonb;
  v_iban text; v_holder text; v_gel numeric; v_month numeric; v_id bigint; v_bal int;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if not private.promo_on() then raise exception 'payouts_closed'; end if;
  v_rate := coalesce((v_cfg ->> 'rate')::int, 10000);
  v_min := coalesce((v_cfg ->> 'min_out')::int, 10000);
  v_budget := coalesce((v_cfg ->> 'out_budget')::numeric, 0);
  perform 1 from public.profiles where id = me for update;
  v_req := private.payout_req(me);
  if v_req is null or not (v_req ->> 'not_banned')::boolean then raise exception 'not_allowed'; end if;
  if not (v_req ->> 'adult')::boolean then raise exception 'not_adult'; end if;
  if not (v_req ->> 'verified')::boolean then raise exception 'not_verified'; end if;
  if not (v_req ->> 'old_enough')::boolean then raise exception 'too_new_payout'; end if;
  if p_coins is null or p_coins < v_min or p_coins % 100 <> 0 then raise exception 'below_min'; end if;
  if (v_req ->> 'cash')::int < p_coins then raise exception 'not_enough_cash'; end if;
  v_iban := upper(regexp_replace(coalesce(p_iban, ''), '\s', '', 'g'));
  if not private.iban_ok(v_iban) then raise exception 'bad_iban'; end if;
  v_holder := btrim(regexp_replace(coalesce(p_holder, ''), '\s+', ' ', 'g'));
  if char_length(v_holder) not between 3 and 80 then raise exception 'bad_holder'; end if;
  if exists (select 1 from public.payouts where user_id = me and status = 'pending') then raise exception 'payout_open'; end if;
  v_gel := round(p_coins::numeric / v_rate, 2);
  if v_budget > 0 then
    select coalesce(sum(gel), 0) into v_month from public.payouts
      where status in ('pending', 'paid') and created_at >= (date_trunc('month', now() at time zone 'Asia/Tbilisi') at time zone 'Asia/Tbilisi');
    if v_month + v_gel > v_budget then raise exception 'budget_full'; end if;
  end if;
  update public.profiles set coins = coins - p_coins, coins_cash = coins_cash - p_coins
    where id = me and coins_cash >= p_coins returning coins into v_bal;
  if v_bal is null then raise exception 'not_enough_cash'; end if;
  insert into public.payouts (user_id, coins, gel, iban, holder) values (me, p_coins, v_gel, v_iban, v_holder) returning id into v_id;
  insert into public.coin_log (user_id, amount, label, cash) values (me, -p_coins, 'ლარად გატანა: ' || to_char(v_gel, 'FM999990.00') || ' ₾', -p_coins);
  return jsonb_build_object('id', v_id, 'coins', v_bal, 'gel', v_gel);
end $$;

-- 3. predictions are free -------------------------------------------------------------------------

create or replace function public.predict(p_fixture bigint, p_pick text, p_stake integer) returns integer
language plpgsql security definer set search_path = '' as $$
declare f record; v_bal int;
begin
  if not public.can_post() then raise exception 'not_allowed'; end if;
  select * into f from public.fixtures where id = p_fixture;
  if f.id is null or f.status <> 'upcoming' or f.starts_at <= now() then raise exception 'match_started'; end if;
  if p_pick not in ('1','X','2') then raise exception 'bad_request'; end if;
  if coalesce(p_stake, 0) <> 0 then raise exception 'free_only'; end if;
  if exists (select 1 from public.predictions where fixture_id = p_fixture and user_id = auth.uid()) then raise exception 'already_predicted'; end if;
  insert into public.predictions (fixture_id, user_id, pick, stake) values (p_fixture, auth.uid(), p_pick, 0);
  perform private.earn(auth.uid(), 'predict', 'fx:' || p_fixture);
  select coins into v_bal from public.profiles where id = auth.uid();
  return v_bal;
end $$;

-- the match page shows how many picked each result (free predictions have no stake to count)
create or replace function public.fixture_pool(p_fixture bigint) returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'n', count(*), 'total', coalesce(sum(stake), 0),
    '1', coalesce(sum(stake) filter (where pick = '1'), 0),
    'X', coalesce(sum(stake) filter (where pick = 'X'), 0),
    '2', coalesce(sum(stake) filter (where pick = '2'), 0),
    'c1', count(*) filter (where pick = '1'),
    'cX', count(*) filter (where pick = 'X'),
    'c2', count(*) filter (where pick = '2'))
  from public.predictions where fixture_id = p_fixture;
$$;
