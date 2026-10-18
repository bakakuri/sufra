-- ============ live broadcasts ============
alter table public.rooms drop constraint rooms_kind_check;
alter table public.rooms add constraint rooms_kind_check check (kind in ('supra','birja','live'));
alter table public.rooms add column gifts int not null default 0;
create or replace function public.live_gift(p_room bigint, p_emoji text) returns int language plpgsql security definer set search_path = '' as $$
declare cost int := public.gift_cost(p_emoji); r record; bal int; share int;
begin
  if cost is null then raise exception 'bad_gift'; end if;
  select * into r from public.rooms where id = p_room and live and kind = 'live';
  if r is null then raise exception 'not_found'; end if;
  if r.host = auth.uid() or public.is_blocked(auth.uid(), r.host) then raise exception 'not_allowed'; end if;
  bal := public.spend_coins(cost, 'ლაივის საჩუქარი');
  share := floor(cost * 0.8)::int;
  update public.profiles set coins = coins + share where id = r.host;
  insert into public.coin_log (user_id, amount, label) values (r.host, share, 'ლაივის საჩუქარი');
  insert into public.gifts (sender, recipient, emoji, cost) values (auth.uid(), r.host, p_emoji, cost);
  update public.rooms set gifts = gifts + cost where id = p_room;
  return bal;
end $$;
create or replace function public.trg_room_live() returns trigger language plpgsql security definer set search_path = '' as $$
declare f record;
begin
  if new.kind <> 'live' then return new; end if;
  if exists(select 1 from public.rooms where host = new.host and kind = 'live' and id <> new.id and created_at > now() - interval '3 hours') then return new; end if;
  for f in
    select case when fr.requester = new.host then fr.addressee else fr.requester end as uid
    from public.friendships fr where fr.status = 'accepted' and (fr.requester = new.host or fr.addressee = new.host) limit 300
  loop
    perform public.notify(f.uid, new.host, 'live_start', jsonb_build_object('room', new.id, 'title', left(new.title, 80)));
  end loop;
  return new;
end $$;
create trigger rooms_live_notify after insert on public.rooms for each row execute function public.trg_room_live();

-- ============ housekeeping job: expired messages, stale rooms, old help requests ============
create or replace function private.housekeeping() returns void language plpgsql security definer set search_path = '' as $$
begin
  delete from public.messages where expires_at is not null and expires_at < now() - interval '2 minutes';
  update public.rooms set live = false, ended_at = now() where live and created_at < now() - interval '12 hours';
  update public.help_requests set status = 'resolved' where status = 'open' and expires_at < now();
end $$;
revoke execute on function private.housekeeping() from public, anon, authenticated;

-- ============ moderation for the new content ============
alter table public.reports drop constraint reports_target_type_check;
alter table public.reports add constraint reports_target_type_check check (target_type in ('post','comment','user','listing','message','page','story','event','job','ride','room','fixture','place','review','toast','help'));
create or replace function public.admin_hide(p_type text, p_id bigint, p_hidden boolean) returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_staff() then raise exception 'staff_only'; end if;
  if p_type = 'post' then update public.posts set hidden = p_hidden where id = p_id;
  elsif p_type = 'comment' then update public.comments set hidden = p_hidden where id = p_id;
  elsif p_type = 'listing' then update public.listings set hidden = p_hidden where id = p_id;
  elsif p_type = 'job' then update public.jobs set hidden = p_hidden where id = p_id;
  elsif p_type = 'place' then update public.places set hidden = p_hidden where id = p_id;
  elsif p_type = 'review' then update public.place_reviews set hidden = p_hidden where id = p_id;
  elsif p_type = 'toast' then update public.toasts set hidden = p_hidden where id = p_id;
  elsif p_type = 'help' then update public.help_requests set hidden = p_hidden where id = p_id;
  else raise exception 'bad_type'; end if;
end $$;

-- lock down trigger functions, expose RPCs to signed-in users only
revoke execute on function public.places_limit(), public.place_rating(), public.toast_likes_count(), public.toasts_limit(), public.trg_help_request(), public.trg_help_offer(), public.trg_help_done(), public.kin_before(), public.kin_after(), public.trg_room_live() from public, anon, authenticated;
do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as sig from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname in ('edit_message','unsend_message','pin_message','set_chat_ttl','places_near','help_author','can_donate','join_surname_group','is_kin_of','review_place','respond_kin','live_gift','admin_hide')
  loop
    execute format('revoke execute on function %s from public, anon', f.sig);
    execute format('grant execute on function %s to authenticated', f.sig);
  end loop;
end $$;

-- scheduled jobs
create extension if not exists pg_cron;
select cron.schedule('sufra-celebrations', '0 4 * * *', 'select private.daily_celebrations()');
select cron.schedule('sufra-housekeeping', '*/10 * * * *', 'select private.housekeeping()');
