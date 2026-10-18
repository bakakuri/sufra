create extension if not exists pg_net with schema extensions;
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique check (username ~ '^[a-z0-9_.]{3,24}$'),
  name text not null default 'მომხმარებელი' check (char_length(name) between 1 and 60),
  bio text not null default '' check (char_length(bio) <= 300),
  city text not null default '' check (char_length(city) <= 60),
  hue int not null default 330 check (hue between 0 and 360),
  avatar_url text,
  cover_url text,
  birthday date,
  lang text not null default 'ka',
  privacy jsonb not null default '{"online":true,"guest":false,"dm":"all","chal":"all","near":"all"}',
  dating boolean not null default false,
  gender text check (gender in ('f','m','x')),
  seeking text check (seeking in ('f','m','all')),
  dating_bio text not null default '' check (char_length(dating_bio) <= 300),
  interests text[] not null default '{}',
  is_business boolean not null default false,
  verified boolean not null default false,
  role text not null default 'user' check (role in ('user','moderator','admin')),
  banned boolean not null default false,
  coins int not null default 120 check (coins >= 0),
  rating int not null default 1500,
  last_bonus date,
  last_seen timestamptz default now(),
  onboarded boolean not null default false,
  created_at timestamptz not null default now()
);
alter table public.profiles enable row level security;

create table public.blocks (
  blocker uuid not null references public.profiles(id) on delete cascade,
  blocked uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker, blocked),
  check (blocker <> blocked)
);
alter table public.blocks enable row level security;

create or replace function public.is_staff() returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.profiles where id = auth.uid() and role in ('admin','moderator'));
$$;
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;
create or replace function public.can_post() returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.profiles where id = auth.uid() and onboarded and not banned);
$$;
create or replace function public.is_adult(u uuid) returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.profiles where id = u and birthday is not null and birthday <= (current_date - interval '18 years')::date);
$$;
create or replace function public.is_blocked(a uuid, b uuid) returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.blocks where (blocker = a and blocked = b) or (blocker = b and blocked = a));
$$;

create policy "profiles readable by signed-in users" on public.profiles for select to authenticated using (true);
create policy "users update own profile" on public.profiles for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));
revoke insert, update, delete on public.profiles from anon, authenticated;
grant update (username, name, bio, city, hue, avatar_url, cover_url, lang, privacy, dating, gender, seeking, dating_bio, interests, is_business, last_seen) on public.profiles to authenticated;

create policy "see own blocks" on public.blocks for select to authenticated using (blocker = (select auth.uid()));
create policy "block others" on public.blocks for insert to authenticated with check (blocker = (select auth.uid()));
create policy "unblock" on public.blocks for delete to authenticated using (blocker = (select auth.uid()));

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path = '' as $$
declare first_user boolean;
begin
  select not exists(select 1 from public.profiles where role = 'admin') into first_user;
  insert into public.profiles (id, name, role, hue)
  values (new.id,
          left(coalesce(nullif(trim(new.raw_user_meta_data->>'name'), ''), split_part(new.email, '@', 1), 'მომხმარებელი'), 60),
          case when first_user then 'admin' else 'user' end,
          floor(random() * 360)::int);
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

create or replace function public.complete_onboarding(p_name text, p_birthday date, p_username text, p_city text) returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'not_signed_in'; end if;
  if p_birthday is null or p_birthday > (current_date - interval '13 years')::date then raise exception 'too_young'; end if;
  if p_birthday < date '1900-01-01' then raise exception 'bad_birthday'; end if;
  update public.profiles set
    name = left(trim(p_name), 60),
    birthday = coalesce(birthday, p_birthday),
    username = nullif(lower(trim(p_username)), ''),
    city = left(coalesce(trim(p_city), ''), 60),
    onboarded = true
  where id = auth.uid();
end $$;

revoke execute on function public.handle_new_user() from public, anon, authenticated;
