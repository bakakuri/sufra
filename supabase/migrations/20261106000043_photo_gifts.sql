-- Peera coins, stage 2: gifts on photos.
--
-- New prices, from a coffee (50) to a crown (25,000). Whoever receives a gift gets half of it (gift_share);
-- of that half, only the part the sender paid with cash coins becomes cash, so gifting never turns
-- spending coins into lari. The same rule now holds for profile and live gifts.
-- A photo shows what it got: posts.gifts counts each gift, posts.gift_top is the dearest one (it picks the frame),
-- so the feed reads them with the post itself.

-- 1. prices ------------------------------------------------------------------------------------

create or replace function public.gift_cost(e text) returns integer
language sql immutable set search_path = '' as $$
  select case e when '☕' then 50 when '🌹' then 100 when '📚' then 100 when '🎓' then 300 when '💐' then 500
    when '🧸' then 800 when '🎂' then 1000 when '🏆' then 5000 when '💎' then 10000 when '👑' then 25000 else null end $$;

-- 2. where a gift went and what the receiver got ----------------------------------------------

alter table public.gifts
  add column if not exists post_id bigint references public.posts(id) on delete set null,
  add column if not exists share integer not null default 0,
  add column if not exists share_cash integer not null default 0;
create index if not exists gifts_post_idx on public.gifts (post_id, created_at desc) where post_id is not null;

alter table public.posts
  add column if not exists gifts jsonb not null default '{}'::jsonb,
  add column if not exists gift_top integer not null default 0;

-- people can insert posts (and read every column), so a new post always starts with no gifts,
-- and only the gift function below may change them
create or replace function private.posts_gifts_guard() returns trigger
language plpgsql set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    new.gifts := '{}'::jsonb; new.gift_top := 0;
  elsif coalesce(current_setting('peera.gift', true), '') <> '1' then
    new.gifts := old.gifts; new.gift_top := old.gift_top;
  end if;
  return new;
end $$;
drop trigger if exists posts_gifts_guard on public.posts;
create trigger posts_gifts_guard before insert or update of gifts, gift_top on public.posts
  for each row execute function private.posts_gifts_guard();

-- 3. paying for a gift ---------------------------------------------------------------------------

-- the sender pays the full price (other coins first); the receiver gets half, and half of the cash part as cash
create or replace function private.gift_pay(p_from uuid, p_to uuid, p_emoji text, p_label_out text, p_label_in text,
  out o_bal integer, out o_cost integer, out o_share integer, out o_cash integer)
language plpgsql security definer set search_path = '' as $$
declare v_part numeric := coalesce((private.coin_cfg() ->> 'gift_share')::numeric, 0.5); s record;
begin
  o_cost := public.gift_cost(p_emoji);
  if o_cost is null then raise exception 'bad_gift'; end if;
  select * into s from private.spend(p_from, o_cost, p_label_out);
  o_bal := s.o_bal;
  o_share := floor(o_cost * v_part)::int;
  o_cash := floor(s.o_cash * v_part)::int;
  if o_share > 0 then perform private.credit(p_to, o_share, p_label_in, o_cash); end if;
end $$;

-- a gift on a photo: someone else's visible photo post, not to a minor you do not know
create or replace function public.post_gift(p_post bigint, p_emoji text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); p record; g record; v_gifts jsonb; v_top int;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if not public.can_post() then raise exception 'not_allowed'; end if;
  if public.gift_cost(p_emoji) is null then raise exception 'bad_gift'; end if;
  select id, author, media, group_id into p from public.posts
    where id = p_post and not hidden and not draft and not pending and created_at <= now() and repost_of is null;
  if p.id is null or public.is_blocked(p.author, me) or (p.group_id is not null and not public.group_visible(p.group_id)) then raise exception 'not_found'; end if;
  if p.author = me then raise exception 'own_post'; end if;
  if not exists (select 1 from jsonb_array_elements(case when jsonb_typeof(p.media) = 'array' then p.media else '[]'::jsonb end) m where m ->> 'type' = 'image') then
    raise exception 'not_photo';
  end if;
  if not public.may_reach(me, p.author) then raise exception 'minor_protected'; end if;
  select * into g from private.gift_pay(me, p.author, p_emoji, 'საჩუქარი ფოტოს ' || p_emoji, 'საჩუქარი შენს ფოტოზე ' || p_emoji);
  insert into public.gifts (sender, recipient, emoji, cost, post_id, share, share_cash)
    values (me, p.author, p_emoji, g.o_cost, p_post, g.o_share, g.o_cash);
  perform set_config('peera.gift', '1', true);
  update public.posts set gifts = jsonb_set(gifts, array[p_emoji], to_jsonb(coalesce((gifts ->> p_emoji)::int, 0) + 1)),
                          gift_top = greatest(gift_top, g.o_cost)
    where id = p_post returning gifts, gift_top into v_gifts, v_top;
  perform set_config('peera.gift', '', true);
  perform public.notify(p.author, me, 'gift', jsonb_build_object('emoji', p_emoji, 'post', p_post, 'coins', g.o_share));
  return jsonb_build_object('coins', g.o_bal, 'gifts', v_gifts, 'gift_top', v_top, 'share', g.o_share);
end $$;

-- who gave this photo what: the dearest first
create or replace function public.post_gifts(p_post bigint) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare me uuid := auth.uid(); p record;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  select id, author, group_id, hidden, draft, pending, created_at into p from public.posts where id = p_post;
  if p.id is null or public.is_blocked(p.author, me) or (p.group_id is not null and not public.group_visible(p.group_id))
     or ((p.hidden or p.draft or p.pending or p.created_at > now()) and p.author <> me and not public.is_staff()) then
    raise exception 'not_found';
  end if;
  return coalesce((select jsonb_agg(jsonb_build_object('u', x.sender, 'e', x.emoji, 'c', x.cost, 'at', x.created_at) order by x.cost desc, x.created_at desc)
    from (select sender, emoji, cost, created_at from public.gifts
          where post_id = p_post and not public.is_blocked(sender, me)
          order by cost desc, created_at desc limit 100) x), '[]'::jsonb);
end $$;

-- a gift on a profile: the same prices and the same half
create or replace function public.send_gift(p_to uuid, p_emoji text) returns integer
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); g record;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if public.gift_cost(p_emoji) is null then raise exception 'bad_gift'; end if;
  if p_to = me or public.is_blocked(me, p_to) then raise exception 'not_allowed'; end if;
  if not public.may_reach(me, p_to) then raise exception 'minor_protected'; end if;
  select * into g from private.gift_pay(me, p_to, p_emoji, 'საჩუქარი ' || p_emoji, 'საჩუქარი ' || p_emoji);
  insert into public.gifts (sender, recipient, emoji, cost, share, share_cash) values (me, p_to, p_emoji, g.o_cost, g.o_share, g.o_cash);
  perform public.notify(p_to, me, 'gift', jsonb_build_object('emoji', p_emoji, 'coins', g.o_share));
  return g.o_bal;
end $$;

-- a gift in a live broadcast: half to the host, like everywhere else
create or replace function public.live_gift(p_room bigint, p_emoji text) returns integer
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); r record; g record;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if public.gift_cost(p_emoji) is null then raise exception 'bad_gift'; end if;
  select * into r from public.rooms where id = p_room and live and kind = 'live';
  if r.id is null then raise exception 'not_found'; end if;
  if r.host = me or public.is_blocked(me, r.host) then raise exception 'not_allowed'; end if;
  if not public.may_reach(me, r.host) then raise exception 'minor_protected'; end if;
  select * into g from private.gift_pay(me, r.host, p_emoji, 'ლაივის საჩუქარი ' || p_emoji, 'ლაივის საჩუქარი ' || p_emoji);
  insert into public.gifts (sender, recipient, emoji, cost, share, share_cash) values (me, r.host, p_emoji, g.o_cost, g.o_share, g.o_cash);
  update public.rooms set gifts = gifts + g.o_cost where id = p_room;
  return g.o_bal;
end $$;

do $$
declare f text;
begin
  foreach f in array array['public.post_gift(bigint,text)', 'public.post_gifts(bigint)'] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $$;
