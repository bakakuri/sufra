-- Gifts on each photo of a post (not the post as a whole), a bigger choice of gifts, and a 5+ that costs coins.
--
-- posts.gifts is now { "photo index": { "gift": count } }, so the gift shows on the photo it was given to.
-- A 5+ grade costs plus_cost coins (50 by default), once per photo post and person; the author gets half,
-- of that half cash only for the cash part paid, like any gift. Going back to 5+ after changing the grade is free.

-- 1. 28 gifts ------------------------------------------------------------------------------------

create or replace function public.gift_cost(e text) returns integer
language sql immutable set search_path = '' as $$
  select case e
    -- flowers
    when '🌷' then 50 when '🌹' then 100 when '🌻' then 150 when '🌸' then 200 when '💐' then 500
    -- sweet
    when '☕' then 50 when '🍫' then 80 when '🍦' then 100 when '🍇' then 120 when '🍰' then 300 when '🎂' then 1000
    -- feelings
    when '❤️' then 50 when '💌' then 150 when '🧸' then 800 when '💍' then 7000
    -- celebration and study
    when '🎈' then 60 when '📚' then 100 when '🎉' then 200 when '⭐' then 250 when '🎓' then 300 when '🎁' then 400
    -- precious
    when '🏆' then 5000 when '🚗' then 8000 when '💎' then 10000 when '🚀' then 12000 when '🏰' then 15000 when '🦄' then 20000 when '👑' then 25000
    else null end $$;

-- 2. which photo -----------------------------------------------------------------------------------

alter table public.gifts add column if not exists idx smallint not null default 0;
alter table public.gifts drop constraint if exists gifts_idx_check;
alter table public.gifts add constraint gifts_idx_check check (idx between 0 and 19);
comment on column public.posts.gifts is 'Gifts on each photo: { "photo index": { "gift": count } }. Only post_gift changes it (posts_gifts_guard).';

-- gifts sent before this change were all on the first photo
update public.posts set gifts = jsonb_build_object('0', gifts)
  where gifts <> '{}'::jsonb and not exists (select 1 from jsonb_each(gifts) e where jsonb_typeof(e.value) = 'object');

drop function if exists public.post_gift(bigint, text);
create or replace function public.post_gift(p_post bigint, p_emoji text, p_idx integer default 0) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); p record; g record; v_gifts jsonb; v_top int; k text := coalesce(p_idx, 0)::text;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if not public.can_post() then raise exception 'not_allowed'; end if;
  if public.gift_cost(p_emoji) is null then raise exception 'bad_gift'; end if;
  select id, author, media, group_id into p from public.posts
    where id = p_post and not hidden and not draft and not pending and created_at <= now() and repost_of is null;
  if p.id is null or public.is_blocked(p.author, me) or (p.group_id is not null and not public.group_visible(p.group_id)) then raise exception 'not_found'; end if;
  if p.author = me then raise exception 'own_post'; end if;
  if p_idx is null or p_idx < 0 or jsonb_typeof(p.media) <> 'array' or p_idx >= jsonb_array_length(p.media)
     or (p.media -> p_idx ->> 'type') is distinct from 'image' then
    raise exception 'not_photo';
  end if;
  if not public.may_reach(me, p.author) then raise exception 'minor_protected'; end if;
  select * into g from private.gift_pay(me, p.author, p_emoji, 'საჩუქარი ფოტოს ' || p_emoji, 'საჩუქარი შენს ფოტოზე ' || p_emoji);
  insert into public.gifts (sender, recipient, emoji, cost, post_id, idx, share, share_cash)
    values (me, p.author, p_emoji, g.o_cost, p_post, p_idx, g.o_share, g.o_cash);
  perform set_config('peera.gift', '1', true);
  update public.posts set
      gifts = jsonb_set(gifts, array[k], coalesce(gifts -> k, '{}'::jsonb) || jsonb_build_object(p_emoji, coalesce((gifts -> k ->> p_emoji)::int, 0) + 1)),
      gift_top = greatest(gift_top, g.o_cost)
    where id = p_post returning gifts, gift_top into v_gifts, v_top;
  perform set_config('peera.gift', '', true);
  perform public.notify(p.author, me, 'gift', jsonb_build_object('emoji', p_emoji, 'post', p_post, 'idx', p_idx, 'coins', g.o_share));
  return jsonb_build_object('coins', g.o_bal, 'gifts', v_gifts, 'gift_top', v_top, 'share', g.o_share);
end $$;
revoke all on function public.post_gift(bigint, text, integer) from public, anon;
grant execute on function public.post_gift(bigint, text, integer) to authenticated;

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
  return coalesce((select jsonb_agg(jsonb_build_object('u', x.sender, 'e', x.emoji, 'c', x.cost, 'i', x.idx, 'at', x.created_at) order by x.cost desc, x.created_at desc)
    from (select sender, emoji, cost, idx, created_at from public.gifts
          where post_id = p_post and not public.is_blocked(sender, me)
          order by cost desc, created_at desc limit 100) x), '[]'::jsonb);
end $$;

-- 3. a 5+ that costs coins -------------------------------------------------------------------------

alter table public.post_grades add column if not exists plus_paid boolean not null default false;
update public.app_settings set value = value || '{"plus_cost": 50}'::jsonb where key = 'coins' and not value ? 'plus_cost';

-- before the grade is saved: not enough coins means no 5+
create or replace function private.grade_plus() returns trigger
language plpgsql security definer set search_path = '' as $$
declare a uuid; v_cfg jsonb := private.coin_cfg(); v_cost int; v_part numeric; s record; v_share int := 0; v_cash int := 0;
begin
  -- an upsert first tries the insert: if the grade already exists, the update below decides
  if tg_op = 'INSERT' and exists (select 1 from public.post_grades where post_id = new.post_id and user_id = new.user_id) then return new; end if;
  if tg_op = 'UPDATE' then new.plus_paid := old.plus_paid; end if;
  if new.grade is distinct from '5+' or new.plus_paid then return new; end if;
  v_cost := coalesce((v_cfg ->> 'plus_cost')::int, 50);
  if v_cost <= 0 then return new; end if;
  select author into a from public.posts where id = new.post_id;
  if a is null or a = new.user_id then return new; end if;
  if not public.may_reach(new.user_id, a) then raise exception 'minor_protected'; end if;
  select * into s from private.spend(new.user_id, v_cost, '„5+“ ფოტოს');
  v_part := coalesce((v_cfg ->> 'gift_share')::numeric, 0.5);
  v_share := floor(v_cost * v_part)::int; v_cash := floor(s.o_cash * v_part)::int;
  if v_share > 0 then perform private.credit(a, v_share, '„5+“ შენს ფოტოზე', v_cash); end if;
  new.plus_paid := true;
  new.paid := coalesce(new.paid, 0) + v_share;
  perform public.notify(a, new.user_id, 'grade_plus', jsonb_build_object('post', new.post_id, 'coins', v_share));
  return new;
end $$;
drop trigger if exists post_grades_plus on public.post_grades;
create trigger post_grades_plus before insert or update of grade on public.post_grades
  for each row execute function private.grade_plus();

-- grading still pays its 1 coin to both; the 5+ notice now comes from grade_plus
create or replace function private.grade_reward() returns trigger
language plpgsql security definer set search_path = '' as $$
declare a uuid; img boolean; amt int := 0;
begin
  select p.author,
         exists (select 1 from jsonb_array_elements(case when jsonb_typeof(p.media) = 'array' then p.media else '[]'::jsonb end) m where m ->> 'type' = 'image')
    into a, img
    from public.posts p where p.id = new.post_id;
  if a is null or a = new.user_id or not img or public.is_blocked(new.user_id, a) then return null; end if;
  begin
    perform private.earn(new.user_id, 'grade', 'g:' || new.post_id, 'u:' || a);
    amt := coalesce(private.earn(a, 'got_grade', 'gg:' || new.post_id || ':' || new.user_id, 'u:' || new.user_id), 0);
    if amt > 0 then update public.post_grades set paid = paid + amt where post_id = new.post_id and user_id = new.user_id; end if;
  exception when others then
    raise warning 'grade earn failed: %', sqlerrm;
  end;
  return null;
end $$;

-- the coin page knows what a 5+ costs
create or replace function public.my_coins() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare me uuid := auth.uid(); v_day date := private.tday(); v_cfg jsonb := private.coin_cfg(); p record;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  select coins, coins_cash, last_bonus, bonus_streak into p from public.profiles where id = me;
  return jsonb_build_object(
    'coins', coalesce(p.coins, 0), 'cash', coalesce(p.coins_cash, 0),
    'last_bonus', p.last_bonus, 'streak', coalesce(p.bonus_streak, 0), 'day', v_day,
    'promo', private.promo_on(), 'until', v_cfg -> 'until',
    'rate', coalesce((v_cfg ->> 'rate')::int, 10000), 'min_out', coalesce((v_cfg ->> 'min_out')::int, 10000),
    'daily_max', coalesce((v_cfg ->> 'daily_max')::int, 150), 'plus_cost', coalesce((v_cfg ->> 'plus_cost')::int, 50),
    'today', (select coalesce(sum(e.amount), 0) from private.earn_events e join public.coin_rules r on r.action = e.action
              where e.user_id = me and e.day = v_day and not e.undone and r.in_max),
    'by', (select coalesce(jsonb_object_agg(action, n), '{}'::jsonb) from (
             select action, sum(amount) n from private.earn_events where user_id = me and day = v_day and not undone group by action) x),
    'done', (select coalesce(jsonb_agg(distinct e.action), '[]'::jsonb) from private.earn_events e join public.coin_rules r on r.action = e.action
             where e.user_id = me and r.once));
end $$;

-- the admin sets the price of a 5+ (0 makes it free)
create or replace function public.admin_coin_plus(p_cost integer) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v jsonb := private.coin_cfg();
begin
  if not public.is_admin() then raise exception 'admin_only'; end if;
  if p_cost is null or p_cost not between 0 and 100000 then raise exception 'bad_request'; end if;
  v := v || jsonb_build_object('plus_cost', p_cost);
  insert into public.app_settings (key, value) values ('coins', v) on conflict (key) do update set value = excluded.value;
  return v;
end $$;
revoke all on function public.admin_coin_plus(integer) from public, anon;
grant execute on function public.admin_coin_plus(integer) to authenticated;
