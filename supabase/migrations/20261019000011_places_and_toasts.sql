-- ============ places, reviews, check-ins ============
create table public.places (
  id bigint generated always as identity primary key,
  name text not null check (char_length(name) between 2 and 80),
  kind text not null check (kind in ('restaurant','cafe','bar','winery','hotel','guesthouse','sight','nature','shop','other')),
  region text not null default '' check (char_length(region) <= 60),
  city text not null default '' check (char_length(city) <= 60),
  address text not null default '' check (char_length(address) <= 120),
  lat double precision not null check (lat between -90 and 90),
  lng double precision not null check (lng between -180 and 180),
  phone text not null default '' check (char_length(phone) <= 30),
  website text not null default '' check (char_length(website) <= 200 and (website = '' or website ~* '^https?://')),
  about text not null default '' check (char_length(about) <= 600),
  photo text check (photo is null or photo ~* '^https://'),
  tags text[] not null default '{}' check (cardinality(tags) <= 12),
  created_by uuid references public.profiles(id) on delete set null,
  rating numeric(3,2) not null default 0,
  reviews int not null default 0,
  hidden boolean not null default false,
  created_at timestamptz not null default now()
);
create index places_geo_idx on public.places (lat, lng) where not hidden;
create index places_name_idx on public.places (lower(name));
alter table public.places enable row level security;
create policy "places visible" on public.places for select to authenticated using (not hidden or created_by = (select auth.uid()) or public.is_staff());
create policy "add place" on public.places for insert to authenticated with check (created_by = (select auth.uid()) and public.can_post() and not hidden and rating = 0 and reviews = 0);
create policy "edit own place" on public.places for update to authenticated using (created_by = (select auth.uid()) or public.is_staff()) with check (created_by = (select auth.uid()) or public.is_staff());
create policy "remove own place" on public.places for delete to authenticated using (created_by = (select auth.uid()) or public.is_staff());
revoke update on public.places from authenticated;
grant update (name, kind, region, city, address, lat, lng, phone, website, about, photo, tags) on public.places to authenticated;

create or replace function public.places_limit() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_staff() and (select count(*) from public.places where created_by = new.created_by and created_at > now() - interval '1 day') >= 10 then raise exception 'too_many'; end if;
  return new;
end $$;
create trigger places_limit before insert on public.places for each row execute function public.places_limit();

create table public.place_reviews (
  id bigint generated always as identity primary key,
  place_id bigint not null references public.places(id) on delete cascade,
  author uuid not null references public.profiles(id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  body text not null default '' check (char_length(body) <= 1000),
  photos jsonb not null default '[]' check (jsonb_typeof(photos) = 'array' and jsonb_array_length(photos) <= 4),
  hidden boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (place_id, author)
);
alter table public.place_reviews enable row level security;
create policy "reviews visible" on public.place_reviews for select to authenticated using ((not hidden or author = (select auth.uid()) or public.is_staff()) and not public.is_blocked(author, (select auth.uid())));
create policy "write review" on public.place_reviews for insert to authenticated with check (author = (select auth.uid()) and public.can_post() and not hidden);
create policy "edit own review" on public.place_reviews for update to authenticated using (author = (select auth.uid())) with check (author = (select auth.uid()));
create policy "remove review" on public.place_reviews for delete to authenticated using (author = (select auth.uid()) or public.is_staff());
revoke update on public.place_reviews from authenticated;
grant update (rating, body, photos, updated_at) on public.place_reviews to authenticated;

create or replace function public.place_rating() returns trigger language plpgsql security definer set search_path = '' as $$
declare pid bigint := coalesce(new.place_id, old.place_id);
begin
  update public.places p set rating = coalesce((select round(avg(r.rating)::numeric, 2) from public.place_reviews r where r.place_id = pid and not r.hidden), 0),
    reviews = (select count(*) from public.place_reviews r where r.place_id = pid and not r.hidden) where p.id = pid;
  return null;
end $$;
create trigger place_reviews_rating after insert or update or delete on public.place_reviews for each row execute function public.place_rating();

create or replace function public.review_place(p_place bigint, p_rating int, p_body text, p_photos jsonb) returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.can_post() then raise exception 'not_allowed'; end if;
  if p_rating is null or p_rating not between 1 and 5 then raise exception 'bad_request'; end if;
  if not exists(select 1 from public.places where id = p_place and not hidden) then raise exception 'not_found'; end if;
  insert into public.place_reviews (place_id, author, rating, body, photos)
    values (p_place, auth.uid(), p_rating, left(trim(coalesce(p_body, '')), 1000), coalesce(p_photos, '[]'::jsonb))
    on conflict (place_id, author) do update set rating = excluded.rating, body = excluded.body, photos = excluded.photos, updated_at = now();
end $$;

alter table public.posts add column place_id bigint references public.places(id) on delete set null;
create index posts_place_idx on public.posts (place_id, created_at desc) where place_id is not null;

create or replace function public.places_near(p_lat double precision, p_lng double precision, p_km double precision default 30, p_kind text default null, p_q text default null, p_limit int default 80)
returns table (id bigint, name text, kind text, region text, city text, address text, lat double precision, lng double precision, photo text, tags text[], rating numeric, reviews int, km double precision)
language sql stable security invoker set search_path = '' as $$
  with box as (select least(greatest(coalesce(p_km, 30), 0.2), 600) as km)
  select p.id, p.name, p.kind, p.region, p.city, p.address, p.lat, p.lng, p.photo, p.tags, p.rating, p.reviews,
    6371 * 2 * asin(sqrt(power(sin(radians(p.lat - p_lat) / 2), 2) + cos(radians(p_lat)) * cos(radians(p.lat)) * power(sin(radians(p.lng - p_lng) / 2), 2))) as km
  from public.places p, box
  where not p.hidden
    and p.lat between p_lat - box.km / 111.0 and p_lat + box.km / 111.0
    and p.lng between p_lng - box.km / (111.0 * greatest(cos(radians(p_lat)), 0.05)) and p_lng + box.km / (111.0 * greatest(cos(radians(p_lat)), 0.05))
    and (p_kind is null or p.kind = p_kind)
    and (p_q is null or p_q = '' or p.name ilike '%' || p_q || '%' or p.city ilike '%' || p_q || '%' or exists(select 1 from unnest(p.tags) t where t ilike '%' || p_q || '%')
         or exists(select 1 from public.place_reviews r where r.place_id = p.id and not r.hidden and r.body ilike '%' || p_q || '%'))
  order by km
  limit least(greatest(coalesce(p_limit, 80), 1), 200);
$$;

-- ============ toast book ============
create table public.toasts (
  id bigint generated always as identity primary key,
  author uuid references public.profiles(id) on delete set null,
  occasion text not null check (occasion in ('supra','wedding','christening','birthday','memorial','friends','homeland','parents','love','kids','guests','other')),
  title text not null check (char_length(title) between 2 and 80),
  body text not null check (char_length(body) between 10 and 1500),
  likes int not null default 0,
  hidden boolean not null default false,
  created_at timestamptz not null default now()
);
create index toasts_occ_idx on public.toasts (occasion, likes desc);
alter table public.toasts enable row level security;
create policy "toasts visible" on public.toasts for select to authenticated using (not hidden or author = (select auth.uid()) or public.is_staff());
create policy "write toast" on public.toasts for insert to authenticated with check (author = (select auth.uid()) and public.can_post() and likes = 0 and not hidden);
create policy "edit own toast" on public.toasts for update to authenticated using (author = (select auth.uid())) with check (author = (select auth.uid()));
create policy "remove toast" on public.toasts for delete to authenticated using (author = (select auth.uid()) or public.is_staff());
revoke update on public.toasts from authenticated;
grant update (occasion, title, body) on public.toasts to authenticated;
create table public.toast_likes (
  toast_id bigint not null references public.toasts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (toast_id, user_id)
);
alter table public.toast_likes enable row level security;
create policy "my toast likes" on public.toast_likes for select to authenticated using (user_id = (select auth.uid()));
create policy "like toast" on public.toast_likes for insert to authenticated with check (user_id = (select auth.uid()));
create policy "unlike toast" on public.toast_likes for delete to authenticated using (user_id = (select auth.uid()));
create or replace function public.toast_likes_count() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  update public.toasts set likes = (select count(*) from public.toast_likes where toast_id = coalesce(new.toast_id, old.toast_id)) where id = coalesce(new.toast_id, old.toast_id);
  return null;
end $$;
create trigger toast_likes_count after insert or delete on public.toast_likes for each row execute function public.toast_likes_count();
create or replace function public.toasts_limit() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.author is not null and not public.is_staff() and (select count(*) from public.toasts where author = new.author and created_at > now() - interval '1 day') >= 20 then raise exception 'too_many'; end if;
  return new;
end $$;
create trigger toasts_limit before insert on public.toasts for each row execute function public.toasts_limit();
