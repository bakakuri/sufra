create table public.coin_log (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  amount int not null,
  label text not null,
  created_at timestamptz not null default now()
);
create index coin_log_user_idx on public.coin_log (user_id, created_at desc);
create table public.gifts (
  id bigint generated always as identity primary key,
  sender uuid references public.profiles(id) on delete set null,
  recipient uuid not null references public.profiles(id) on delete cascade,
  emoji text not null,
  cost int not null,
  created_at timestamptz not null default now()
);
create table public.swipes (
  swiper uuid not null references public.profiles(id) on delete cascade,
  target uuid not null references public.profiles(id) on delete cascade,
  kind text not null check (kind in ('like','nope','super')),
  created_at timestamptz not null default now(),
  primary key (swiper, target)
);
create table public.matches (
  a uuid not null references public.profiles(id) on delete cascade,
  b uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (a, b),
  check (a < b)
);
create table public.events (
  id bigint generated always as identity primary key,
  host uuid not null references public.profiles(id) on delete cascade,
  title text not null check (char_length(title) between 2 and 120),
  starts_at timestamptz not null,
  place text not null default '' check (char_length(place) <= 160),
  description text not null default '' check (char_length(description) <= 1000),
  tamada uuid references public.profiles(id) on delete set null,
  hue int not null default 20,
  group_id bigint references public.groups(id) on delete cascade,
  created_at timestamptz not null default now()
);
create table public.event_rsvps (
  event_id bigint not null references public.events(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  status text not null check (status in ('yes','maybe','no')),
  primary key (event_id, user_id)
);
create table public.event_items (
  id bigint generated always as identity primary key,
  event_id bigint not null references public.events(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 60),
  added_by uuid references public.profiles(id) on delete set null,
  claimed_by uuid references public.profiles(id) on delete set null
);
create table public.listings (
  id bigint generated always as identity primary key,
  seller uuid not null references public.profiles(id) on delete cascade,
  title text not null check (char_length(title) between 2 and 100),
  price numeric(12,2) not null check (price >= 0),
  category text not null default 'other',
  city text not null default '' check (char_length(city) <= 60),
  description text not null default '' check (char_length(description) <= 1500),
  media jsonb not null default '[]',
  status text not null default 'active' check (status in ('active','sold')),
  hidden boolean not null default false,
  created_at timestamptz not null default now()
);
create index listings_created_idx on public.listings (created_at desc);
create table public.listing_saves (
  user_id uuid not null references public.profiles(id) on delete cascade,
  listing_id bigint not null references public.listings(id) on delete cascade,
  primary key (user_id, listing_id)
);
create table public.ads (
  id bigint generated always as identity primary key,
  page_id bigint not null references public.pages(id) on delete cascade,
  post_id bigint not null references public.posts(id) on delete cascade,
  budget int not null check (budget between 10 and 100000),
  spent int not null default 0,
  status text not null default 'pending' check (status in ('pending','active','rejected','ended')),
  created_at timestamptz not null default now()
);
create table public.reports (
  id bigint generated always as identity primary key,
  reporter uuid references public.profiles(id) on delete set null,
  target_type text not null check (target_type in ('post','comment','user','listing','message','page','story','event')),
  target_id text not null,
  reason text not null check (char_length(reason) <= 120),
  details text not null default '' check (char_length(details) <= 1000),
  status text not null default 'open' check (status in ('open','resolved','dismissed')),
  resolved_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);
create table public.verification_requests (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  selfie_url text not null,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  reviewed_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);
alter table public.coin_log enable row level security;
alter table public.gifts enable row level security;
alter table public.swipes enable row level security;
alter table public.matches enable row level security;
alter table public.events enable row level security;
alter table public.event_rsvps enable row level security;
alter table public.event_items enable row level security;
alter table public.listings enable row level security;
alter table public.listing_saves enable row level security;
alter table public.ads enable row level security;
alter table public.reports enable row level security;
alter table public.verification_requests enable row level security;

create policy "own coin log" on public.coin_log for select to authenticated using (user_id = (select auth.uid()));
create policy "gifts visible to both" on public.gifts for select to authenticated using (recipient = (select auth.uid()) or sender = (select auth.uid()));
create policy "own swipes" on public.swipes for select to authenticated using (swiper = (select auth.uid()));
create policy "own matches" on public.matches for select to authenticated using (a = (select auth.uid()) or b = (select auth.uid()));
create policy "events visible" on public.events for select to authenticated using ((group_id is null or public.group_visible(group_id)) and not public.is_blocked(host, (select auth.uid())));
create policy "create event" on public.events for insert to authenticated with check (host = (select auth.uid()) and public.can_post() and (group_id is null or public.is_group_member(group_id)));
create policy "host edits event" on public.events for update to authenticated using (host = (select auth.uid())) with check (host = (select auth.uid()));
create policy "host removes event" on public.events for delete to authenticated using (host = (select auth.uid()) or public.is_staff());
create policy "rsvps visible" on public.event_rsvps for select to authenticated using (true);
create policy "rsvp" on public.event_rsvps for insert to authenticated with check (user_id = (select auth.uid()));
create policy "change rsvp" on public.event_rsvps for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "items visible" on public.event_items for select to authenticated using (true);
create policy "add item" on public.event_items for insert to authenticated with check (added_by = (select auth.uid()) and (claimed_by is null or claimed_by = (select auth.uid())) and exists(select 1 from public.events e where e.id = event_id));
create policy "claim item" on public.event_items for update to authenticated using (claimed_by is null or claimed_by = (select auth.uid())) with check (claimed_by is null or claimed_by = (select auth.uid()));
create policy "remove item" on public.event_items for delete to authenticated using (added_by = (select auth.uid()) or exists(select 1 from public.events e where e.id = event_id and e.host = (select auth.uid())));
revoke update on public.event_items from authenticated;
grant update (claimed_by) on public.event_items to authenticated;
create policy "listings visible" on public.listings for select to authenticated using ((not hidden or seller = (select auth.uid()) or public.is_staff()) and not public.is_blocked(seller, (select auth.uid())));
create policy "create listing" on public.listings for insert to authenticated with check (seller = (select auth.uid()) and public.can_post() and hidden = false);
create policy "seller edits listing" on public.listings for update to authenticated using (seller = (select auth.uid())) with check (seller = (select auth.uid()));
create policy "seller or staff removes listing" on public.listings for delete to authenticated using (seller = (select auth.uid()) or public.is_staff());
revoke update on public.listings from authenticated;
grant update (title, price, category, city, description, media, status) on public.listings to authenticated;
create policy "own listing saves" on public.listing_saves for select to authenticated using (user_id = (select auth.uid()));
create policy "save listing" on public.listing_saves for insert to authenticated with check (user_id = (select auth.uid()));
create policy "unsave listing" on public.listing_saves for delete to authenticated using (user_id = (select auth.uid()));
create policy "ads visible" on public.ads for select to authenticated using (public.owns_page(page_id) or public.is_staff() or status = 'active');
create policy "file report" on public.reports for insert to authenticated with check (reporter = (select auth.uid()) and status = 'open');
create policy "own or staff reports" on public.reports for select to authenticated using (reporter = (select auth.uid()) or public.is_staff());
create policy "request verification" on public.verification_requests for insert to authenticated with check (user_id = (select auth.uid()) and status = 'pending');
create policy "own or staff verification" on public.verification_requests for select to authenticated using (user_id = (select auth.uid()) or public.is_staff());

create or replace function public.spend_coins(p_amount int, p_label text) returns int language plpgsql security definer set search_path = '' as $$
declare bal int;
begin
  if p_amount <= 0 then raise exception 'bad_amount'; end if;
  update public.profiles set coins = coins - p_amount where id = auth.uid() and coins >= p_amount returning coins into bal;
  if bal is null then raise exception 'not_enough_coins'; end if;
  insert into public.coin_log (user_id, amount, label) values (auth.uid(), -p_amount, left(p_label, 80));
  return bal;
end $$;
revoke execute on function public.spend_coins(int, text) from public, anon, authenticated;
create or replace function public.daily_bonus() returns int language plpgsql security definer set search_path = '' as $$
declare bal int;
begin
  update public.profiles set coins = coins + 20, last_bonus = current_date where id = auth.uid() and (last_bonus is null or last_bonus < current_date) returning coins into bal;
  if bal is null then raise exception 'already_claimed'; end if;
  insert into public.coin_log (user_id, amount, label) values (auth.uid(), 20, 'დღიური ბონუსი');
  return bal;
end $$;
create or replace function public.game_result(p_game text, p_win boolean) returns jsonb language plpgsql security definer set search_path = '' as $$
declare wins_today int; r int; c int; reward int := 0;
begin
  if auth.uid() is null then raise exception 'not_signed_in'; end if;
  select count(*) into wins_today from public.coin_log where user_id = auth.uid() and label like 'მოგება:%' and created_at > now() - interval '1 day';
  if p_win and wins_today < 10 then reward := 10; end if;
  update public.profiles set rating = greatest(100, rating + case when p_win then 12 else -9 end), coins = coins + reward where id = auth.uid() returning rating, coins into r, c;
  if reward > 0 then insert into public.coin_log (user_id, amount, label) values (auth.uid(), reward, 'მოგება: ' || left(p_game, 30)); end if;
  return jsonb_build_object('rating', r, 'coins', c, 'reward', reward);
end $$;
create or replace function public.gift_cost(e text) returns int language sql immutable set search_path = '' as $$
  select case e when '🌹' then 5 when '☕' then 3 when '🍇' then 5 when '🎲' then 8 when '🍷' then 10 when '💐' then 15 when '🧸' then 20 when '🎂' then 25 when '🏆' then 100 else null end;
$$;
create or replace function public.send_gift(p_to uuid, p_emoji text) returns int language plpgsql security definer set search_path = '' as $$
declare cost int := public.gift_cost(p_emoji); bal int;
begin
  if cost is null then raise exception 'bad_gift'; end if;
  if p_to = auth.uid() or public.is_blocked(auth.uid(), p_to) then raise exception 'not_allowed'; end if;
  bal := public.spend_coins(cost, 'საჩუქარი');
  insert into public.gifts (sender, recipient, emoji, cost) values (auth.uid(), p_to, p_emoji, cost);
  perform public.notify(p_to, auth.uid(), 'gift', jsonb_build_object('emoji', p_emoji));
  return bal;
end $$;
create or replace function public.swipe(p_target uuid, p_kind text) returns boolean language plpgsql security definer set search_path = '' as $$
declare matched boolean := false;
begin
  if not public.is_adult(auth.uid()) or not public.is_adult(p_target) then raise exception 'adults_only'; end if;
  if not exists(select 1 from public.profiles where id = auth.uid() and dating) then raise exception 'dating_off'; end if;
  if p_kind not in ('like','nope','super') then raise exception 'bad_kind'; end if;
  if p_kind = 'super' then perform public.spend_coins(5, 'სუპერ მოწონება'); end if;
  insert into public.swipes (swiper, target, kind) values (auth.uid(), p_target, p_kind) on conflict (swiper, target) do update set kind = excluded.kind, created_at = now();
  if p_kind in ('like','super') and exists(select 1 from public.swipes where swiper = p_target and target = auth.uid() and kind in ('like','super')) then
    insert into public.matches (a, b) values (least(auth.uid(), p_target), greatest(auth.uid(), p_target)) on conflict do nothing;
    perform public.notify(p_target, auth.uid(), 'match', '{}');
    perform public.notify(auth.uid(), p_target, 'match', '{}');
    matched := true;
  elsif p_kind = 'super' then
    perform public.notify(p_target, auth.uid(), 'super', '{}');
  end if;
  return matched;
end $$;
create or replace function public.likes_me_count() returns int language sql stable security definer set search_path = '' as $$
  select count(*)::int from public.swipes s where s.target = auth.uid() and s.kind in ('like','super')
    and not exists(select 1 from public.swipes m where m.swiper = auth.uid() and m.target = s.swiper);
$$;
create or replace function public.create_ad(p_post bigint, p_budget int) returns bigint language plpgsql security definer set search_path = '' as $$
declare pg bigint; ad bigint;
begin
  select page_id into pg from public.posts where id = p_post and author = auth.uid();
  if pg is null or not public.owns_page(pg) then raise exception 'post_must_belong_to_your_page'; end if;
  if p_budget < 10 then raise exception 'min_budget'; end if;
  perform public.spend_coins(p_budget, 'რეკლამა');
  insert into public.ads (page_id, post_id, budget) values (pg, p_post, p_budget) returning id into ad;
  return ad;
end $$;
create or replace function public.ad_impression(p_ad bigint) returns void language plpgsql security definer set search_path = '' as $$
begin
  update public.ads set spent = spent + 1, status = case when spent + 1 >= budget then 'ended' else status end where id = p_ad and status = 'active';
end $$;
create or replace function public.friend_suggestions(p_limit int default 12) returns table (id uuid, name text, city text, hue int, avatar_url text, verified boolean, mutual int)
language sql stable security definer set search_path = '' as $$
  with my_friends as (select case when requester = auth.uid() then addressee else requester end as f from public.friendships where status = 'accepted' and auth.uid() in (requester, addressee)),
  related as (select case when f2.requester = mf.f then f2.addressee else f2.requester end as cand from my_friends mf join public.friendships f2 on f2.status = 'accepted' and mf.f in (f2.requester, f2.addressee))
  select p.id, p.name, p.city, p.hue, p.avatar_url, p.verified, coalesce((select count(*) from related r where r.cand = p.id), 0)::int as mutual
  from public.profiles p
  where p.id <> auth.uid() and p.onboarded and not p.banned
    and not exists(select 1 from public.friendships f where (f.requester = p.id and f.addressee = auth.uid()) or (f.addressee = p.id and f.requester = auth.uid()))
    and not public.is_blocked(p.id, auth.uid())
  order by mutual desc, (p.city = (select city from public.profiles where id = auth.uid())) desc, p.created_at desc
  limit least(greatest(p_limit, 1), 50);
$$;
create or replace function public.mutual_friends(other uuid) returns int language sql stable security definer set search_path = '' as $$
  with a as (select case when requester = auth.uid() then addressee else requester end f from public.friendships where status = 'accepted' and auth.uid() in (requester, addressee)),
       b as (select case when requester = other then addressee else requester end f from public.friendships where status = 'accepted' and other in (requester, addressee))
  select count(*)::int from a join b using (f);
$$;
create or replace function public.trending_tags(p_limit int default 10) returns table (tag text, uses int) language sql stable security definer set search_path = '' as $$
  select t, count(*)::int from public.posts, unnest(tags) t where created_at > now() - interval '3 days' and not hidden group by t order by count(*) desc, t limit least(greatest(p_limit, 1), 30);
$$;
