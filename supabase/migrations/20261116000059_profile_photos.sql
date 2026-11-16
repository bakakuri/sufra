-- A person's own photos on their profile ("ფოტოები"): uploaded straight, or into albums of their own (not the shared
-- albums, which several people fill together). Who sees them is the owner's choice in the privacy settings
-- (profiles.privacy->>'photos'): everyone ('all'), friends ('friends', the default) or nobody ('none'). The owner
-- always sees their own; people who blocked each other never see each other's. "Nobody" means nobody, staff too.
create table if not exists public.photo_albums (
  id bigint generated always as identity primary key,
  owner uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 1 and 60),
  created_at timestamptz not null default now()
);
create index if not exists photo_albums_owner_idx on public.photo_albums (owner, created_at desc);

create table if not exists public.photos (
  id bigint generated always as identity primary key,
  owner uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  album_id bigint references public.photo_albums(id) on delete set null,
  url text not null check (url ~ '^https://'),
  sm text check (sm is null or sm ~ '^https://'),
  w integer check (w is null or w between 1 and 20000),
  h integer check (h is null or h between 1 and 20000),
  caption text not null default '' check (char_length(caption) <= 300),
  created_at timestamptz not null default now()
);
create index if not exists photos_owner_idx on public.photos (owner, created_at desc);
create index if not exists photos_album_idx on public.photos (album_id, created_at desc);

-- may the signed-in person see this owner's photos?
create or replace function public.can_see_photos(p_owner uuid) returns boolean
language sql stable security definer set search_path = '' as $f$
  select case
    when auth.uid() is null then false
    when p_owner = auth.uid() then true
    when public.is_blocked(p_owner, auth.uid()) then false
    else coalesce((
      select case coalesce(p.privacy->>'photos', 'friends')
               when 'all' then true
               when 'friends' then public.are_friends(p_owner, auth.uid())
               else false end
      from public.profiles p where p.id = p_owner), false)
  end
$f$;

-- what a visitor is told: 'ok', or why not ('friends': friends only; 'none': nobody)
create or replace function public.photo_access(p_user uuid) returns text
language sql stable security definer set search_path = '' as $f$
  select case when public.can_see_photos(p_user) then 'ok'
              else coalesce((select case when p.privacy->>'photos' = 'none' then 'none' else 'friends' end from public.profiles p where p.id = p_user), 'none') end
$f$;

alter table public.photo_albums enable row level security;
alter table public.photos enable row level security;

drop policy if exists "photo albums seen as the owner allows" on public.photo_albums;
create policy "photo albums seen as the owner allows" on public.photo_albums for select to authenticated using (public.can_see_photos(owner));
drop policy if exists "own photo albums made" on public.photo_albums;
create policy "own photo albums made" on public.photo_albums for insert to authenticated with check (owner = (select auth.uid()) and public.can_post());
drop policy if exists "own photo albums renamed" on public.photo_albums;
create policy "own photo albums renamed" on public.photo_albums for update to authenticated using (owner = (select auth.uid())) with check (owner = (select auth.uid()));
drop policy if exists "own photo albums deleted" on public.photo_albums;
create policy "own photo albums deleted" on public.photo_albums for delete to authenticated using (owner = (select auth.uid()) or public.is_staff());

drop policy if exists "photos seen as the owner allows" on public.photos;
create policy "photos seen as the owner allows" on public.photos for select to authenticated using (public.can_see_photos(owner));
drop policy if exists "own photos added" on public.photos;
create policy "own photos added" on public.photos for insert to authenticated with check (
  owner = (select auth.uid()) and public.can_post()
  and (album_id is null or exists (select 1 from public.photo_albums a where a.id = album_id and a.owner = (select auth.uid()))));
drop policy if exists "own photos changed" on public.photos;
create policy "own photos changed" on public.photos for update to authenticated using (owner = (select auth.uid())) with check (
  owner = (select auth.uid())
  and (album_id is null or exists (select 1 from public.photo_albums a where a.id = album_id and a.owner = (select auth.uid()))));
drop policy if exists "own photos deleted" on public.photos;
create policy "own photos deleted" on public.photos for delete to authenticated using (owner = (select auth.uid()) or public.is_staff());

revoke all on public.photo_albums, public.photos from anon;
grant select, insert, update, delete on public.photo_albums, public.photos to authenticated;
-- the owner and the time are not to be changed by hand
revoke update on public.photos from authenticated;
grant update (album_id, caption) on public.photos to authenticated;
revoke update on public.photo_albums from authenticated;
grant update (title) on public.photo_albums to authenticated;

-- at most 100 new photos a day, 50 albums in all
create or replace function private.photo_caps() returns trigger language plpgsql security definer set search_path = '' as $f$
begin
  if tg_table_name = 'photos' then
    if (select count(*) from public.photos where owner = new.owner and created_at > now() - interval '1 day') >= 100 then raise exception 'too_many'; end if;
  else
    if (select count(*) from public.photo_albums where owner = new.owner) >= 50 then raise exception 'too_many'; end if;
  end if;
  return new;
end $f$;
drop trigger if exists photos_cap on public.photos;
create trigger photos_cap before insert on public.photos for each row execute function private.photo_caps();
drop trigger if exists photo_albums_cap on public.photo_albums;
create trigger photo_albums_cap before insert on public.photo_albums for each row execute function private.photo_caps();

-- a person's albums with how many photos each holds and the newest as its cover (what the visitor may see)
create or replace function public.photo_albums_of(p_user uuid)
returns table (id bigint, title text, n integer, cover text, created_at timestamptz)
language sql stable security invoker set search_path = '' as $f$
  select a.id, a.title,
         (select count(*)::integer from public.photos p where p.album_id = a.id),
         (select coalesce(p.sm, p.url) from public.photos p where p.album_id = a.id order by p.created_at desc limit 1),
         a.created_at
  from public.photo_albums a where a.owner = p_user order by a.created_at desc
$f$;

revoke execute on function public.can_see_photos(uuid), public.photo_access(uuid), public.photo_albums_of(uuid) from public, anon;
revoke execute on function private.photo_caps() from public, anon, authenticated;
grant execute on function public.can_see_photos(uuid), public.photo_access(uuid), public.photo_albums_of(uuid) to authenticated;
