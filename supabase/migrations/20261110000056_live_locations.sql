-- live location: a person shares where they are, live, for a while (15 minutes, an hour, 8 hours or until they stop).
-- Friends see it on the map; if they share with everyone, others see it too, as long as they may reach that person
-- (an adult and a pupil under 18 who do not know each other never see each other). A pupil under 18 shares with friends only.
-- The admin sees every shared place. Only the latest place is kept: stopping deletes it, there is no history.
-- An approximate share is rounded on the server to about a kilometre, so the exact place is never stored.
create table if not exists public.live_locations (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  lat double precision not null check (lat between -90 and 90),
  lng double precision not null check (lng between -180 and 180),
  acc integer check (acc >= 0),
  heading smallint check (heading between 0 and 359),
  speed real check (speed >= 0),
  audience text not null default 'friends' check (audience in ('friends', 'public')),
  approx boolean not null default false,
  started_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  expires_at timestamptz
);
create index if not exists live_locations_updated_idx on public.live_locations (updated_at);
alter table public.live_locations enable row level security;
-- each person reads their own row (to pick up their sharing after a reload); everything else goes through the functions below
drop policy if exists "own live location" on public.live_locations;
create policy "own live location" on public.live_locations for select to authenticated using (user_id = (select auth.uid()));
revoke insert, update, delete, truncate on public.live_locations from anon, authenticated;
revoke all on public.live_locations from anon;

-- an approximate place: two decimals, about 1.1 km north to south
create or replace function private.loc_round(v double precision, approx boolean) returns double precision
language sql immutable set search_path to '' as $f$ select case when approx then round(v::numeric, 2)::double precision else round(v::numeric, 6)::double precision end $f$;

-- start sharing, or change how (who sees it, for how long, how exact)
create or replace function public.loc_share(p_lat double precision, p_lng double precision, p_acc integer, p_audience text, p_minutes integer, p_approx boolean)
returns jsonb language plpgsql security definer set search_path to '' as $f$
declare me uuid := auth.uid(); r public.live_locations; v_aud text := coalesce(p_audience, 'friends'); v_ap boolean := coalesce(p_approx, false);
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if not public.can_post() then raise exception 'not_allowed'; end if;
  if p_lat is null or p_lng is null or p_lat not between -90 and 90 or p_lng not between -180 and 180 then raise exception 'bad_location'; end if;
  if v_aud not in ('friends', 'public') or coalesce(p_minutes, -1) not in (0, 15, 60, 480) then raise exception 'bad_request'; end if;
  if v_aud = 'public' and public.is_minor(me) then raise exception 'minor_public'; end if;
  insert into public.live_locations as l (user_id, lat, lng, acc, audience, approx, started_at, updated_at, expires_at)
  values (me, private.loc_round(p_lat, v_ap), private.loc_round(p_lng, v_ap),
          case when v_ap then 1000 else greatest(0, least(coalesce(p_acc, 0), 100000)) end,
          v_aud, v_ap, now(), now(), case when p_minutes = 0 then null else now() + make_interval(mins => p_minutes) end)
  on conflict (user_id) do update set lat = excluded.lat, lng = excluded.lng, acc = excluded.acc, heading = null, speed = null,
    audience = excluded.audience, approx = excluded.approx, started_at = excluded.started_at, updated_at = excluded.updated_at, expires_at = excluded.expires_at
  returning * into r;
  return jsonb_build_object('on', true, 'audience', r.audience, 'approx', r.approx, 'started_at', r.started_at, 'expires_at', r.expires_at);
end $f$;

-- the place moved (sent while the app is open); a few seconds apart at most
create or replace function public.loc_update(p_lat double precision, p_lng double precision, p_acc integer, p_heading integer, p_speed real)
returns jsonb language plpgsql security definer set search_path to '' as $f$
declare me uuid := auth.uid(); r public.live_locations;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if p_lat is null or p_lng is null or p_lat not between -90 and 90 or p_lng not between -180 and 180 then raise exception 'bad_location'; end if;
  select * into r from public.live_locations where user_id = me for update;
  if r.user_id is null then return jsonb_build_object('on', false); end if;
  if (r.expires_at is not null and r.expires_at <= now()) or not public.can_post() then
    delete from public.live_locations where user_id = me; return jsonb_build_object('on', false); end if;
  if r.updated_at > now() - interval '3 seconds' then
    return jsonb_build_object('on', true, 'audience', r.audience, 'approx', r.approx, 'expires_at', r.expires_at, 'skip', true); end if;
  update public.live_locations set lat = private.loc_round(p_lat, r.approx), lng = private.loc_round(p_lng, r.approx),
    acc = case when r.approx then 1000 else greatest(0, least(coalesce(p_acc, 0), 100000)) end,
    heading = case when r.approx or p_heading is null then null else ((p_heading % 360) + 360) % 360 end,
    speed = case when r.approx or p_speed is null or p_speed < 0 then null else least(p_speed, 400) end,
    updated_at = now()
  where user_id = me;
  return jsonb_build_object('on', true, 'audience', r.audience, 'approx', r.approx, 'expires_at', r.expires_at);
end $f$;

-- stop sharing: the place is deleted
create or replace function public.loc_stop() returns void language sql security definer set search_path to '' as $f$
  delete from public.live_locations where user_id = auth.uid() $f$;

-- what this person may see on the map: themselves; friends who share; those who share with everyone, when they may reach
-- each other; nobody they blocked or who blocked them. The admin sees all. A place not refreshed for a day is not shown;
-- after a week it is deleted, as is any share that ran out.
create or replace function public.live_map()
returns table (user_id uuid, lat double precision, lng double precision, acc integer, heading smallint, speed real, audience text, approx boolean,
               started_at timestamptz, updated_at timestamptz, expires_at timestamptz, friend boolean)
language plpgsql security definer set search_path to '' as $f$
declare me uuid := auth.uid(); adm boolean := public.is_admin();
begin
  if me is null then return; end if;
  if not adm and not public.can_post() then return; end if;
  delete from public.live_locations l where (l.expires_at is not null and l.expires_at <= now()) or l.updated_at < now() - interval '7 days';
  return query
    select l.user_id, l.lat, l.lng, l.acc, l.heading, l.speed, l.audience, l.approx, l.started_at, l.updated_at, l.expires_at,
           public.are_friends(me, l.user_id)
    from public.live_locations l join public.profiles p on p.id = l.user_id
    where l.updated_at > now() - interval '1 day' and not p.banned
      and (l.user_id = me or adm or (not public.is_blocked(me, l.user_id)
           and (public.are_friends(me, l.user_id) or (l.audience = 'public' and public.may_reach(me, l.user_id)))))
    order by l.updated_at desc
    limit 2000;
end $f$;

revoke all on function public.loc_share(double precision, double precision, integer, text, integer, boolean) from public, anon;
revoke all on function public.loc_update(double precision, double precision, integer, integer, real) from public, anon;
revoke all on function public.loc_stop() from public, anon;
revoke all on function public.live_map() from public, anon;
revoke all on function private.loc_round(double precision, boolean) from public, anon, authenticated;
grant execute on function public.loc_share(double precision, double precision, integer, text, integer, boolean) to authenticated;
grant execute on function public.loc_update(double precision, double precision, integer, integer, real) to authenticated;
grant execute on function public.loc_stop() to authenticated;
grant execute on function public.live_map() to authenticated;
