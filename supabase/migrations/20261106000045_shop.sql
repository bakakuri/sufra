-- Peera coins, stage 4: a shop for coins (the market stays as it is: lari, meeting in person).
--
-- Only people the admin lets in can sell, and every product waits for the admin before it shows.
-- Buying holds the coins: the seller sends, the buyer confirms (or 7 days pass after sending), then the seller gets
-- the price minus shop_fee (10%); of that, cash only for the cash part the buyer paid, so the shop never turns
-- spending coins into lari. Before sending, either side can cancel and the buyer gets everything back as it was paid.
-- A problem goes to the admin, who refunds the buyer or pays the seller.

-- 1. sellers ------------------------------------------------------------------------------------

create table if not exists public.shop_sellers (
  user_id    uuid primary key references public.profiles(id) on delete cascade,
  name       text not null check (char_length(name) between 2 and 60),
  about      text not null default '' check (char_length(about) <= 500),
  city       text not null default '' check (char_length(city) <= 60),
  status     text not null default 'pending' check (status in ('pending', 'approved', 'rejected', 'blocked')),
  note       text check (note is null or char_length(note) <= 200),
  created_at timestamptz not null default now(),
  decided_at timestamptz,
  decided_by uuid references public.profiles(id) on delete set null
);
create index if not exists shop_sellers_status_idx on public.shop_sellers (status, created_at);
alter table public.shop_sellers enable row level security;
drop policy if exists "shop sellers visible" on public.shop_sellers;
create policy "shop sellers visible" on public.shop_sellers for select to authenticated
  using (status = 'approved' or user_id = (select auth.uid()) or public.is_admin());

-- 2. products -----------------------------------------------------------------------------------

create table if not exists public.shop_items (
  id         bigint generated always as identity primary key,
  seller     uuid not null references public.profiles(id) on delete cascade,
  title      text not null check (char_length(title) between 2 and 100),
  about      text not null default '' check (char_length(about) <= 2000),
  price      integer not null check (price between 10 and 10000000),
  media      jsonb not null default '[]'::jsonb check (jsonb_typeof(media) = 'array' and jsonb_array_length(media) <= 6),
  stock      integer not null default 1 check (stock between 0 and 10000),
  delivery   text not null default '' check (char_length(delivery) <= 300),
  status     text not null default 'pending' check (status in ('pending', 'active', 'rejected', 'paused', 'removed')),
  approved   boolean not null default false,
  note       text check (note is null or char_length(note) <= 200),
  sold       integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists shop_items_status_idx on public.shop_items (status, created_at desc);
create index if not exists shop_items_seller_idx on public.shop_items (seller, created_at desc);
alter table public.shop_items enable row level security;
drop policy if exists "shop items visible" on public.shop_items;
create policy "shop items visible" on public.shop_items for select to authenticated
  using ((status = 'active' and not public.is_blocked(seller, (select auth.uid()))) or seller = (select auth.uid()) or public.is_admin());

-- 3. orders -------------------------------------------------------------------------------------

create table if not exists public.shop_orders (
  id          bigint generated always as identity primary key,
  item_id     bigint references public.shop_items(id) on delete set null,
  title       text not null,
  photo       text,
  buyer       uuid not null references public.profiles(id) on delete cascade,
  seller      uuid not null references public.profiles(id) on delete cascade,
  price       integer not null check (price > 0),
  cash        integer not null default 0 check (cash >= 0),
  delivery    text not null check (char_length(delivery) between 5 and 500),
  status      text not null default 'paid' check (status in ('paid', 'shipped', 'completed', 'cancelled', 'disputed', 'refunded')),
  ship_note   text check (ship_note is null or char_length(ship_note) <= 300),
  dispute     text check (dispute is null or char_length(dispute) <= 500),
  admin_note  text check (admin_note is null or char_length(admin_note) <= 300),
  payout      integer,
  payout_cash integer,
  created_at  timestamptz not null default now(),
  shipped_at  timestamptz,
  done_at     timestamptz
);
create index if not exists shop_orders_buyer_idx on public.shop_orders (buyer, created_at desc);
create index if not exists shop_orders_seller_idx on public.shop_orders (seller, created_at desc);
create index if not exists shop_orders_status_idx on public.shop_orders (status, shipped_at);
alter table public.shop_orders enable row level security;
drop policy if exists "shop orders of both sides" on public.shop_orders;
create policy "shop orders of both sides" on public.shop_orders for select to authenticated
  using (buyer = (select auth.uid()) or seller = (select auth.uid()) or public.is_admin());

-- everything changes only through the functions below
revoke all on public.shop_sellers, public.shop_items, public.shop_orders from anon;
revoke insert, update, delete, truncate on public.shop_sellers, public.shop_items, public.shop_orders from authenticated;

-- 4. becoming a seller --------------------------------------------------------------------------

create or replace function public.shop_apply(p_name text, p_about text, p_city text) returns text
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); v_st text; v_name text := btrim(coalesce(p_name, ''));
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if not public.can_post() then raise exception 'not_allowed'; end if;
  if not public.is_adult(me) then raise exception 'not_adult'; end if;
  if char_length(v_name) not between 2 and 60 then raise exception 'bad_name'; end if;
  select status into v_st from public.shop_sellers where user_id = me;
  if v_st = 'approved' then raise exception 'already_seller'; end if;
  if v_st = 'blocked' then raise exception 'not_allowed'; end if;
  insert into public.shop_sellers (user_id, name, about, city) values (me, v_name, left(btrim(coalesce(p_about, '')), 500), left(btrim(coalesce(p_city, '')), 60))
    on conflict (user_id) do update set name = excluded.name, about = excluded.about, city = excluded.city, status = 'pending', note = null, created_at = now();
  return 'pending';
end $$;

create or replace function public.admin_shop_seller(p_user uuid, p_status text, p_note text default null) returns void
language plpgsql security definer set search_path = '' as $$
declare v_note text := nullif(left(btrim(coalesce(p_note, '')), 200), '');
begin
  if not public.is_admin() then raise exception 'admin_only'; end if;
  if p_status not in ('approved', 'rejected', 'blocked') then raise exception 'bad_request'; end if;
  if p_status <> 'approved' and v_note is null then raise exception 'note_needed'; end if;
  update public.shop_sellers set status = p_status, note = v_note, decided_at = now(), decided_by = auth.uid() where user_id = p_user;
  if not found then raise exception 'not_found'; end if;
  if p_status <> 'approved' then
    update public.shop_items set status = 'paused', updated_at = now() where seller = p_user and status in ('active', 'pending');
  end if;
  perform public.notify(p_user, null, 'shop_seller_' || p_status, jsonb_build_object('note', v_note));
  perform private.admin_log('shop_seller_' || p_status, p_user::text, jsonb_build_object('note', v_note));
end $$;

-- 5. products: a seller adds and edits, the admin approves -------------------------------------

create or replace function public.shop_item_save(p_id bigint, p_title text, p_about text, p_price integer, p_media jsonb, p_stock integer, p_delivery text)
returns bigint language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); v_id bigint; it public.shop_items; v_title text := btrim(coalesce(p_title, '')); v_media jsonb := coalesce(p_media, '[]'::jsonb);
  v_about text := left(btrim(coalesce(p_about, '')), 2000); v_del text := left(btrim(coalesce(p_delivery, '')), 300);
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if not exists (select 1 from public.shop_sellers where user_id = me and status = 'approved') or not public.can_post() then raise exception 'not_seller'; end if;
  if char_length(v_title) not between 2 and 100 then raise exception 'bad_title'; end if;
  if p_price is null or p_price not between 10 and 10000000 then raise exception 'bad_price'; end if;
  if p_stock is null or p_stock not between 0 and 10000 then raise exception 'bad_request'; end if;
  -- photos only from this site's storage
  if jsonb_typeof(v_media) <> 'array' or jsonb_array_length(v_media) > 6 or exists (
       select 1 from jsonb_array_elements(v_media) m
       where jsonb_typeof(m) <> 'object' or m ->> 'type' <> 'image'
          or coalesce(m ->> 'url', '') not like 'https://iasospzhhdedpilykpiu.supabase.co/storage/v1/object/public/%') then
    raise exception 'bad_media';
  end if;
  if p_id is null then
    if (select count(*) from public.shop_items where seller = me and status <> 'removed') >= 50 then raise exception 'too_many'; end if;
    insert into public.shop_items (seller, title, about, price, media, stock, delivery)
      values (me, v_title, v_about, p_price, v_media, p_stock, v_del) returning id into v_id;
    return v_id;
  end if;
  select * into it from public.shop_items where id = p_id and seller = me and status <> 'removed' for update;
  if it.id is null then raise exception 'not_found'; end if;
  -- what buyers see changed: back to the admin; only the stock changes freely
  if (it.title, it.about, it.price, it.media, it.delivery) is distinct from (v_title, v_about, p_price, v_media, v_del) then
    update public.shop_items set title = v_title, about = v_about, price = p_price, media = v_media, delivery = v_del, stock = p_stock,
      status = 'pending', approved = false, note = null, updated_at = now() where id = p_id;
  else
    update public.shop_items set stock = p_stock, updated_at = now() where id = p_id;
  end if;
  return p_id;
end $$;

-- pause, show again (once approved), or remove
create or replace function public.shop_item_state(p_id bigint, p_state text) returns text
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); it public.shop_items;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if p_state not in ('paused', 'active', 'removed') then raise exception 'bad_request'; end if;
  select * into it from public.shop_items where id = p_id and seller = me and status <> 'removed' for update;
  if it.id is null then raise exception 'not_found'; end if;
  if p_state = 'active' and (not it.approved or not exists (select 1 from public.shop_sellers where user_id = me and status = 'approved')) then
    raise exception 'not_approved';
  end if;
  update public.shop_items set status = p_state, updated_at = now() where id = p_id;
  return p_state;
end $$;

create or replace function public.admin_shop_item(p_id bigint, p_ok boolean, p_note text default null) returns void
language plpgsql security definer set search_path = '' as $$
declare it public.shop_items; v_note text := nullif(left(btrim(coalesce(p_note, '')), 200), '');
begin
  if not public.is_admin() then raise exception 'admin_only'; end if;
  if not p_ok and v_note is null then raise exception 'note_needed'; end if;
  update public.shop_items set status = case when p_ok then 'active' else 'rejected' end, approved = p_ok, note = v_note, updated_at = now()
    where id = p_id and status = 'pending' returning * into it;
  if it.id is null then raise exception 'not_pending'; end if;
  perform public.notify(it.seller, null, case when p_ok then 'shop_item_ok' else 'shop_item_rejected' end, jsonb_build_object('item', it.id, 'title', it.title, 'note', v_note));
  perform private.admin_log(case when p_ok then 'shop_item_ok' else 'shop_item_rejected' end, it.seller::text, jsonb_build_object('item', it.id, 'title', it.title, 'note', v_note));
end $$;

-- 6. buying and the held coins -----------------------------------------------------------------

-- the seller gets the price minus the fee; of that, cash only for the cash the buyer paid
create or replace function private.shop_release(p_order bigint, p_note text default null) returns void
language plpgsql security definer set search_path = '' as $$
declare o public.shop_orders; v_keep numeric := 1 - coalesce((private.coin_cfg() ->> 'shop_fee')::numeric, 0.1); v_pay int; v_cash int;
begin
  select * into o from public.shop_orders where id = p_order for update;
  if o.id is null or o.status not in ('paid', 'shipped', 'disputed') then raise exception 'not_pending'; end if;
  v_pay := floor(o.price * v_keep)::int; v_cash := floor(o.cash * v_keep)::int;
  update public.shop_orders set status = 'completed', payout = v_pay, payout_cash = v_cash, done_at = now(),
    admin_note = coalesce(p_note, admin_note) where id = p_order;
  if v_pay > 0 then perform private.credit(o.seller, v_pay, left('გაყიდვა: ' || o.title, 80), v_cash); end if;
  perform public.notify(o.seller, o.buyer, 'shop_done', jsonb_build_object('order', o.id, 'title', o.title, 'coins', v_pay));
end $$;

-- the buyer gets back exactly what was paid (the cash part as cash), and the product its piece
create or replace function private.shop_refund(p_order bigint, p_status text, p_note text default null) returns void
language plpgsql security definer set search_path = '' as $$
declare o public.shop_orders;
begin
  select * into o from public.shop_orders where id = p_order for update;
  if o.id is null or o.status not in ('paid', 'shipped', 'disputed') then raise exception 'not_pending'; end if;
  update public.shop_orders set status = p_status, done_at = now(), admin_note = coalesce(p_note, admin_note) where id = p_order;
  perform private.credit(o.buyer, o.price, left('დაბრუნდა: ' || o.title, 80), o.cash);
  update public.shop_items set stock = stock + 1, sold = greatest(0, sold - 1) where id = o.item_id;
end $$;

create or replace function public.shop_buy(p_item bigint, p_delivery text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); it public.shop_items; s record; v_id bigint; v_del text := btrim(coalesce(p_delivery, ''));
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if not public.can_post() then raise exception 'not_allowed'; end if;
  select * into it from public.shop_items where id = p_item for update;
  if it.id is null or it.status <> 'active' or public.is_blocked(it.seller, me)
     or not exists (select 1 from public.shop_sellers where user_id = it.seller and status = 'approved') then raise exception 'not_found'; end if;
  if it.seller = me then raise exception 'own_item'; end if;
  if it.stock < 1 then raise exception 'sold_out'; end if;
  if not public.may_reach(me, it.seller) then raise exception 'minor_protected'; end if;
  if char_length(v_del) not between 5 and 500 then raise exception 'bad_delivery'; end if;
  select * into s from private.spend(me, it.price, left('მაღაზია: ' || it.title, 80));
  update public.shop_items set stock = stock - 1, sold = sold + 1, updated_at = now() where id = it.id;
  insert into public.shop_orders (item_id, title, photo, buyer, seller, price, cash, delivery)
    values (it.id, it.title, coalesce(it.media -> 0 ->> 'sm', it.media -> 0 ->> 'url'), me, it.seller, it.price, s.o_cash, v_del)
    returning id into v_id;
  perform public.notify(it.seller, me, 'shop_order', jsonb_build_object('order', v_id, 'title', it.title, 'coins', it.price));
  return jsonb_build_object('order', v_id, 'coins', s.o_bal);
end $$;

-- ship (seller), received (buyer), cancel before sending (either), a problem (buyer)
create or replace function public.shop_order_act(p_order bigint, p_act text, p_note text default null) returns text
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); o public.shop_orders; v_note text := nullif(btrim(coalesce(p_note, '')), '');
begin
  if me is null then raise exception 'not_signed_in'; end if;
  select * into o from public.shop_orders where id = p_order for update;
  if o.id is null or me not in (o.buyer, o.seller) then raise exception 'not_found'; end if;
  if p_act = 'ship' then
    if me <> o.seller or o.status <> 'paid' then raise exception 'not_allowed'; end if;
    update public.shop_orders set status = 'shipped', shipped_at = now(), ship_note = left(v_note, 300) where id = o.id;
    perform public.notify(o.buyer, o.seller, 'shop_shipped', jsonb_build_object('order', o.id, 'title', o.title, 'note', left(v_note, 300)));
    return 'shipped';
  elsif p_act = 'received' then
    if me <> o.buyer or o.status not in ('paid', 'shipped') then raise exception 'not_allowed'; end if;
    perform private.shop_release(o.id);
    return 'completed';
  elsif p_act = 'cancel' then
    if o.status <> 'paid' then raise exception 'not_allowed'; end if;
    perform private.shop_refund(o.id, 'cancelled');
    perform public.notify(case when me = o.buyer then o.seller else o.buyer end, me, 'shop_cancelled', jsonb_build_object('order', o.id, 'title', o.title));
    return 'cancelled';
  elsif p_act = 'dispute' then
    if me <> o.buyer or o.status not in ('paid', 'shipped') then raise exception 'not_allowed'; end if;
    if char_length(coalesce(v_note, '')) < 5 then raise exception 'note_needed'; end if;
    update public.shop_orders set status = 'disputed', dispute = left(v_note, 500) where id = o.id;
    perform public.notify(o.seller, o.buyer, 'shop_dispute', jsonb_build_object('order', o.id, 'title', o.title));
    return 'disputed';
  end if;
  raise exception 'bad_request';
end $$;

-- 7 days after sending with no problem raised, the order completes by itself
create or replace function private.shop_auto() returns integer
language plpgsql security definer set search_path = '' as $$
declare r record; n int := 0;
begin
  for r in select id from public.shop_orders where status = 'shipped' and shipped_at < now() - interval '7 days' order by shipped_at limit 200 loop
    begin perform private.shop_release(r.id, 'ავტომატურად, 7 დღის შემდეგ'); n := n + 1;
    exception when others then raise warning 'shop auto % failed: %', r.id, sqlerrm; end;
  end loop;
  return n;
end $$;

-- the admin settles a problem: back to the buyer, or to the seller
create or replace function public.admin_shop_resolve(p_order bigint, p_refund boolean, p_note text) returns void
language plpgsql security definer set search_path = '' as $$
declare o public.shop_orders; v_note text := nullif(left(btrim(coalesce(p_note, '')), 300), '');
begin
  if not public.is_admin() then raise exception 'admin_only'; end if;
  if v_note is null then raise exception 'note_needed'; end if;
  select * into o from public.shop_orders where id = p_order;
  if o.id is null or o.status <> 'disputed' then raise exception 'not_pending'; end if;
  if p_refund then
    perform private.shop_refund(o.id, 'refunded', v_note);
    perform public.notify(o.buyer, null, 'shop_refunded', jsonb_build_object('order', o.id, 'title', o.title, 'coins', o.price, 'note', v_note));
    perform public.notify(o.seller, null, 'shop_refunded', jsonb_build_object('order', o.id, 'title', o.title, 'note', v_note));
  else
    perform private.shop_release(o.id, v_note);
    perform public.notify(o.buyer, null, 'shop_resolved', jsonb_build_object('order', o.id, 'title', o.title, 'note', v_note));
  end if;
  perform private.admin_log(case when p_refund then 'shop_refund' else 'shop_release' end, o.buyer::text, jsonb_build_object('order', o.id, 'title', o.title, 'coins', o.price, 'note', v_note));
end $$;

do $$
declare f text;
begin
  foreach f in array array['public.shop_apply(text,text,text)', 'public.admin_shop_seller(uuid,text,text)',
    'public.shop_item_save(bigint,text,text,integer,jsonb,integer,text)', 'public.shop_item_state(bigint,text)', 'public.admin_shop_item(bigint,boolean,text)',
    'public.shop_buy(bigint,text)', 'public.shop_order_act(bigint,text,text)', 'public.admin_shop_resolve(bigint,boolean,text)'] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $$;

select cron.schedule('peera-shop-auto', '23 * * * *', $$select private.shop_auto()$$);

-- 8. the admin panel's tab shows what waits: sellers, products and problems ---------------------

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
    'pending_shop', case when public.is_admin() then
        (select count(*) from public.shop_sellers where status = 'pending')
      + (select count(*) from public.shop_items where status = 'pending')
      + (select count(*) from public.shop_orders where status = 'disputed') else 0 end,
    'banned', (select count(*) from public.profiles where banned),
    'days', (select jsonb_agg(jsonb_build_object('d', d,
        'users', (select count(*) from public.profiles where (created_at at time zone 'Asia/Tbilisi')::date = d),
        'posts', (select count(*) from public.posts where (created_at at time zone 'Asia/Tbilisi')::date = d)) order by d)
      from generate_series(today - 13, today, interval '1 day') g(dd), lateral (select g.dd::date as d) x));
end $$;
