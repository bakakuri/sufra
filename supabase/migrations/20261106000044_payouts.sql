-- Peera coins, stage 3: paying out cash coins in lari, by hand.
--
-- Who can ask: 18 or older, verified, on Peera for at least 30 days, not restricted; at least min_out cash coins
-- (10,000 = 1 ₾), in whole tetri (multiples of 100). One open request at a time.
-- Asking takes the coins off the balance at once (they wait in the request). The admin pays by bank transfer
-- and marks it paid, or rejects it with a reason and the coins come back as cash. The person can cancel while it waits.
-- An optional monthly budget (out_budget, in lari; 0 = none) stops new requests once the month's total would pass it.

create table if not exists public.payouts (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  coins      integer not null check (coins > 0),
  gel        numeric(10,2) not null check (gel > 0),
  iban       text not null check (iban ~ '^GE[0-9]{2}[A-Z]{2}[0-9]{16}$'),
  holder     text not null check (char_length(holder) between 3 and 80),
  status     text not null default 'pending' check (status in ('pending', 'paid', 'rejected', 'cancelled')),
  note       text check (note is null or char_length(note) <= 200),
  created_at timestamptz not null default now(),
  decided_at timestamptz,
  decided_by uuid references public.profiles(id) on delete set null
);
create index if not exists payouts_user_idx on public.payouts (user_id, created_at desc);
create index if not exists payouts_status_idx on public.payouts (status, created_at);
create unique index if not exists payouts_one_open on public.payouts (user_id) where status = 'pending';
alter table public.payouts enable row level security;
drop policy if exists "own payouts" on public.payouts;
create policy "own payouts" on public.payouts for select to authenticated using (user_id = (select auth.uid()));
revoke all on public.payouts from anon;
revoke insert, update, delete, truncate on public.payouts from authenticated;

update public.app_settings set value = value || '{"out_budget": 0}'::jsonb where key = 'coins' and not value ? 'out_budget';

-- a Georgian IBAN: GE, 2 check digits, 2 letters of the bank, 16 digits, and the check digits must add up (mod 97)
create or replace function private.iban_ok(p text) returns boolean
language plpgsql immutable set search_path = '' as $$
declare s text := upper(regexp_replace(coalesce(p, ''), '\s', '', 'g')); r text; m int := 0; ch text;
begin
  if s !~ '^GE[0-9]{2}[A-Z]{2}[0-9]{16}$' then return false; end if;
  r := substr(s, 5) || substr(s, 1, 4);
  for i in 1 .. length(r) loop
    ch := substr(r, i, 1);
    if ch ~ '[A-Z]' then m := (m * 100 + ascii(ch) - 55) % 97; else m := (m * 10 + ch::int) % 97; end if;
  end loop;
  return m = 1;
end $$;

-- what the person meets of the conditions
create or replace function private.payout_req(p_user uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'adult', public.is_adult(p.id), 'verified', p.verified, 'not_banned', not p.banned,
    'age_days', floor(extract(epoch from now() - p.created_at) / 86400)::int,
    'old_enough', p.created_at <= now() - interval '30 days',
    'cash', p.coins_cash)
  from public.profiles p where p.id = p_user $$;

-- the payout page: the conditions, the numbers, my requests
create or replace function public.my_payouts() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare me uuid := auth.uid(); v_cfg jsonb := private.coin_cfg();
begin
  if me is null then raise exception 'not_signed_in'; end if;
  return private.payout_req(me) || jsonb_build_object(
    'rate', coalesce((v_cfg ->> 'rate')::int, 10000), 'min_out', coalesce((v_cfg ->> 'min_out')::int, 10000),
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

create or replace function public.cancel_payout(p_id bigint) returns integer
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); r public.payouts;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  update public.payouts set status = 'cancelled', decided_at = now() where id = p_id and user_id = me and status = 'pending' returning * into r;
  if r.id is null then raise exception 'not_pending'; end if;
  return private.credit(me, r.coins, 'გატანა გაუქმდა', r.coins);
end $$;

-- admin: the requests with what helps decide (account age, where the cash came from in the last 30 days)
create or replace function public.admin_payouts(p_status text default 'pending') returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v_cfg jsonb := private.coin_cfg(); v_month timestamptz := (date_trunc('month', now() at time zone 'Asia/Tbilisi') at time zone 'Asia/Tbilisi');
begin
  if not public.is_admin() then raise exception 'admin_only'; end if;
  if p_status not in ('pending', 'paid', 'rejected', 'cancelled') then raise exception 'bad_request'; end if;
  return jsonb_build_object(
    'pending_n', (select count(*) from public.payouts where status = 'pending'),
    'pending_gel', (select coalesce(sum(gel), 0) from public.payouts where status = 'pending'),
    'month_paid', (select coalesce(sum(gel), 0) from public.payouts where status = 'paid' and decided_at >= v_month),
    'month_asked', (select coalesce(sum(gel), 0) from public.payouts where status in ('pending', 'paid') and created_at >= v_month),
    'budget', coalesce((v_cfg ->> 'out_budget')::numeric, 0),
    'list', coalesce((select jsonb_agg(x order by case when p_status = 'pending' then extract(epoch from (x ->> 'created_at')::timestamptz) else -extract(epoch from (x ->> 'created_at')::timestamptz) end) from (
      select jsonb_build_object('id', o.id, 'u', o.user_id, 'coins', o.coins, 'gel', o.gel, 'iban', o.iban, 'holder', o.holder,
        'status', o.status, 'note', o.note, 'created_at', o.created_at, 'decided_at', o.decided_at, 'decided_by', o.decided_by,
        'name', p.name, 'username', p.username, 'verified', p.verified, 'joined', p.created_at, 'cash_now', p.coins_cash,
        'act30', (select coalesce(sum(e.cash), 0) from private.earn_events e where e.user_id = o.user_id and not e.undone and e.created_at > now() - interval '30 days'),
        'gift30', (select coalesce(sum(g.share_cash), 0) from public.gifts g where g.recipient = o.user_id and g.created_at > now() - interval '30 days'),
        'paid_before', (select coalesce(sum(q.gel), 0) from public.payouts q where q.user_id = o.user_id and q.status = 'paid' and q.id <> o.id)) x
      from public.payouts o join public.profiles p on p.id = o.user_id
      where o.status = p_status
      order by case when p_status = 'pending' then o.created_at end asc, o.created_at desc limit 100) y(x)), '[]'::jsonb));
end $$;

-- paid by bank transfer (the note can hold the transfer reference), or rejected with a reason: the coins come back as cash
create or replace function public.admin_payout_decide(p_id bigint, p_status text, p_note text default null) returns void
language plpgsql security definer set search_path = '' as $$
declare r public.payouts; v_note text := nullif(left(btrim(coalesce(p_note, '')), 200), '');
begin
  if not public.is_admin() then raise exception 'admin_only'; end if;
  if p_status not in ('paid', 'rejected') then raise exception 'bad_request'; end if;
  if p_status = 'rejected' and char_length(coalesce(v_note, '')) < 3 then raise exception 'note_needed'; end if;
  update public.payouts set status = p_status, note = v_note, decided_at = now(), decided_by = auth.uid()
    where id = p_id and status = 'pending' returning * into r;
  if r.id is null then raise exception 'not_pending'; end if;
  if p_status = 'rejected' then perform private.credit(r.user_id, r.coins, 'გატანა უარყოფილია', r.coins); end if;
  perform public.notify(r.user_id, null, 'payout_' || p_status, jsonb_build_object('gel', r.gel, 'coins', r.coins, 'note', v_note));
  perform private.admin_log('payout_' || p_status, r.user_id::text, jsonb_build_object('id', r.id, 'gel', r.gel, 'coins', r.coins, 'note', v_note));
end $$;

-- the most paid out in a month, in lari (0 = no limit)
create or replace function public.admin_coin_budget(p_gel numeric) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v jsonb := private.coin_cfg();
begin
  if not public.is_admin() then raise exception 'admin_only'; end if;
  if p_gel is null or p_gel < 0 or p_gel > 1000000 then raise exception 'bad_request'; end if;
  v := v || jsonb_build_object('out_budget', round(p_gel, 2));
  insert into public.app_settings (key, value) values ('coins', v) on conflict (key) do update set value = excluded.value;
  return v;
end $$;

do $$
declare f text;
begin
  foreach f in array array['public.my_payouts()', 'public.request_payout(integer,text,text)', 'public.cancel_payout(bigint)',
                           'public.admin_payouts(text)', 'public.admin_payout_decide(bigint,text,text)', 'public.admin_coin_budget(numeric)'] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $$;

-- the admin panel's tab shows how many requests wait
create or replace function public.admin_stats() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare today date := (now() at time zone 'Asia/Tbilisi')::date;
begin
  if not public.is_staff() then raise exception 'staff_only'; end if;
  return jsonb_build_object(
    'users', (select count(*) from public.profiles),
    'users_today', (select count(*) from public.profiles where created_at > now() - interval '1 day'),
    'active_today', (select count(*) from public.profiles where last_seen > now() - interval '1 day'),
    'active_week', (select count(*) from public.profiles where last_seen > now() - interval '7 days'),
    'posts_today', (select count(*) from public.posts where created_at > now() - interval '1 day'),
    'comments_today', (select count(*) from public.comments where created_at > now() - interval '1 day'),
    'messages_today', (select count(*) from public.messages where created_at > now() - interval '1 day'),
    'stories_live', (select count(*) from public.stories where expires_at > now()),
    'groups', (select count(*) from public.groups),
    'pages', (select count(*) from public.pages),
    'events_soon', (select count(*) from public.events where starts_at > now()),
    'listings', (select count(*) from public.listings where not hidden),
    'recipes', (select count(*) from public.recipes),
    'rooms_live', (select count(*) from public.rooms where live and created_at > now() - interval '12 hours'),
    'coins_total', (select coalesce(sum(coins), 0) from public.profiles),
    'promos_live', (select count(*) from public.promos where active and starts_at <= now() and (ends_at is null or ends_at > now())),
    'open_reports', (select count(*) from public.reports where status = 'open'),
    'pending_verifications', (select count(*) from public.verification_requests where status = 'pending'),
    'pending_ads', (select count(*) from public.ads where status = 'pending'),
    'pending_payouts', case when public.is_admin() then (select count(*) from public.payouts where status = 'pending') else 0 end,
    'banned', (select count(*) from public.profiles where banned),
    'days', (select jsonb_agg(jsonb_build_object('d', d,
        'users', (select count(*) from public.profiles where (created_at at time zone 'Asia/Tbilisi')::date = d),
        'posts', (select count(*) from public.posts where (created_at at time zone 'Asia/Tbilisi')::date = d)) order by d)
      from generate_series(today - 13, today, interval '1 day') g(dd), lateral (select g.dd::date as d) x));
end $$;
