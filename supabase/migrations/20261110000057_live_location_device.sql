-- the phone app (Android) shares the place with the app closed. When the person starts sharing in the app, the site
-- gets a secret for this one phone (loc_device_token, signed in) and hands it to the app; with it the phone can start
-- that one share (within 15 minutes, once), then move it or stop it, and nothing else: it reads nothing.
-- Only a hash of the secret is kept. Starting a share again from the site (loc_share) or from another phone takes the
-- share away from the old phone, which then stops by itself at its next update.
create table if not exists private.loc_devices (
  token_hash text primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  used_at timestamptz,
  seen_at timestamptz
);
create index if not exists loc_devices_user_idx on private.loc_devices (user_id);
alter table private.loc_devices enable row level security;
revoke all on private.loc_devices from public, anon, authenticated;

-- which phone keeps this share going, and when it last did
alter table public.live_locations add column if not exists dev_hash text;
alter table public.live_locations add column if not exists dev_at timestamptz;

create or replace function private.loc_hash(t text) returns text language sql immutable set search_path to '' as
$f$ select encode(sha256(convert_to(coalesce(t, ''), 'UTF8')), 'hex') $f$;

-- a secret for this phone, for the person signed in on the site
create or replace function public.loc_device_token() returns text language plpgsql security definer set search_path to '' as $f$
declare me uuid := auth.uid(); t text;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  if not public.can_post() then raise exception 'not_allowed'; end if;
  t := replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
  delete from private.loc_devices d where d.user_id = me and d.used_at is null and d.created_at < now() - interval '1 day';
  delete from private.loc_devices d where d.user_id = me and d.token_hash not in
    (select x.token_hash from private.loc_devices x where x.user_id = me order by x.created_at desc limit 5);
  insert into private.loc_devices (token_hash, user_id) values (private.loc_hash(t), me);
  return t;
end $f$;

-- the person a phone's secret belongs to (only while they may post), noting that the phone was seen
create or replace function private.loc_dev_user(p_token text) returns uuid language plpgsql security definer set search_path to '' as $f$
declare u uuid;
begin
  if p_token is null or length(p_token) < 24 or length(p_token) > 200 then return null; end if;
  update private.loc_devices set seen_at = now() where token_hash = private.loc_hash(p_token) returning user_id into u;
  if u is null or not exists (select 1 from public.profiles where id = u and onboarded and not banned) then return null; end if;
  return u;
end $f$;

-- the phone starts the share it was given (the first place it found)
create or replace function public.loc_share_dev(p_token text, p_lat double precision, p_lng double precision, p_acc integer,
  p_audience text, p_minutes integer, p_approx boolean)
returns jsonb language plpgsql security definer set search_path to '' as $f$
declare u uuid := private.loc_dev_user(p_token); h text := private.loc_hash(p_token); r public.live_locations;
  v_aud text := coalesce(p_audience, 'friends'); v_ap boolean := coalesce(p_approx, false);
begin
  if u is null then raise exception 'bad_token'; end if;
  if not exists (select 1 from private.loc_devices where token_hash = h and used_at is null and created_at > now() - interval '15 minutes')
    then raise exception 'bad_token'; end if;
  if p_lat is null or p_lng is null or p_lat not between -90 and 90 or p_lng not between -180 and 180 then raise exception 'bad_location'; end if;
  if v_aud not in ('friends', 'public') or coalesce(p_minutes, -1) not in (0, 15, 60, 480) then raise exception 'bad_request'; end if;
  if v_aud = 'public' and public.is_minor(u) then raise exception 'minor_public'; end if;
  update private.loc_devices set used_at = now() where token_hash = h;
  insert into public.live_locations as l (user_id, lat, lng, acc, audience, approx, started_at, updated_at, expires_at, dev_hash, dev_at)
  values (u, private.loc_round(p_lat, v_ap), private.loc_round(p_lng, v_ap),
          case when v_ap then 1000 else greatest(0, least(coalesce(p_acc, 0), 100000)) end,
          v_aud, v_ap, now(), now(), case when p_minutes = 0 then null else now() + make_interval(mins => p_minutes) end, h, now())
  on conflict (user_id) do update set lat = excluded.lat, lng = excluded.lng, acc = excluded.acc, heading = null, speed = null,
    audience = excluded.audience, approx = excluded.approx, started_at = excluded.started_at, updated_at = excluded.updated_at,
    expires_at = excluded.expires_at, dev_hash = excluded.dev_hash, dev_at = excluded.dev_at
  returning * into r;
  return jsonb_build_object('on', true, 'audience', r.audience, 'approx', r.approx, 'started_at', r.started_at, 'expires_at', r.expires_at);
end $f$;

-- the phone moved: only the phone that keeps this share may move it
create or replace function public.loc_update_dev(p_token text, p_lat double precision, p_lng double precision, p_acc integer,
  p_heading integer, p_speed real)
returns jsonb language plpgsql security definer set search_path to '' as $f$
declare u uuid := private.loc_dev_user(p_token); h text := private.loc_hash(p_token); r public.live_locations;
begin
  if u is null then return jsonb_build_object('on', false); end if;
  if p_lat is null or p_lng is null or p_lat not between -90 and 90 or p_lng not between -180 and 180 then raise exception 'bad_location'; end if;
  select * into r from public.live_locations where user_id = u for update;
  if r.user_id is null or r.dev_hash is distinct from h then return jsonb_build_object('on', false); end if;
  if r.expires_at is not null and r.expires_at <= now() then
    delete from public.live_locations where user_id = u; return jsonb_build_object('on', false); end if;
  if r.updated_at > now() - interval '3 seconds' then
    return jsonb_build_object('on', true, 'audience', r.audience, 'approx', r.approx, 'expires_at', r.expires_at, 'skip', true); end if;
  update public.live_locations set lat = private.loc_round(p_lat, r.approx), lng = private.loc_round(p_lng, r.approx),
    acc = case when r.approx then 1000 else greatest(0, least(coalesce(p_acc, 0), 100000)) end,
    heading = case when r.approx or p_heading is null then null else ((p_heading % 360) + 360) % 360 end,
    speed = case when r.approx or p_speed is null or p_speed < 0 then null else least(p_speed, 400) end,
    updated_at = now(), dev_at = now()
  where user_id = u;
  return jsonb_build_object('on', true, 'audience', r.audience, 'approx', r.approx, 'expires_at', r.expires_at);
end $f$;

-- the stop button in the phone's notification
create or replace function public.loc_stop_dev(p_token text) returns void language plpgsql security definer set search_path to '' as $f$
declare u uuid := private.loc_dev_user(p_token); h text := private.loc_hash(p_token);
begin
  if u is null then return; end if;
  delete from public.live_locations where user_id = u and dev_hash = h;
  delete from private.loc_devices where token_hash = h;
end $f$;

-- sharing started on the site belongs to the site: a phone that kept an earlier share lets it go
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
    audience = excluded.audience, approx = excluded.approx, started_at = excluded.started_at, updated_at = excluded.updated_at,
    expires_at = excluded.expires_at, dev_hash = null, dev_at = null
  returning * into r;
  return jsonb_build_object('on', true, 'audience', r.audience, 'approx', r.approx, 'started_at', r.started_at, 'expires_at', r.expires_at);
end $f$;

revoke all on function public.loc_device_token() from public, anon;
grant execute on function public.loc_device_token() to authenticated;
revoke all on function public.loc_share_dev(text, double precision, double precision, integer, text, integer, boolean) from public;
revoke all on function public.loc_update_dev(text, double precision, double precision, integer, integer, real) from public;
revoke all on function public.loc_stop_dev(text) from public;
grant execute on function public.loc_share_dev(text, double precision, double precision, integer, text, integer, boolean) to anon, authenticated;
grant execute on function public.loc_update_dev(text, double precision, double precision, integer, integer, real) to anon, authenticated;
grant execute on function public.loc_stop_dev(text) to anon, authenticated;
revoke all on function private.loc_hash(text) from public, anon, authenticated;
revoke all on function private.loc_dev_user(text) from public, anon, authenticated;
