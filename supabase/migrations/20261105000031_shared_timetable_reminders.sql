-- კურსელები: a class or course shares one timetable and one list of exams, and everybody gets reminders.

-- ============ 1. who may put a lesson or a deadline on a group's timetable ============
-- every member of a class or course group (they are the class), elsewhere the group's owner and admins
create or replace function public.can_share_study(g bigint) returns boolean language sql stable security definer set search_path = '' as $$
  select public.is_group_member(g)
     and (exists (select 1 from public.groups where id = g and kind in ('class', 'course')) or public.is_group_admin(g));
$$;

drop policy if exists "add lesson" on public.lessons;
drop policy if exists "edit own lesson" on public.lessons;
create policy "add lesson" on public.lessons for insert to authenticated
  with check (owner = (select auth.uid()) and (group_id is null or public.can_share_study(group_id)));
create policy "edit own lesson" on public.lessons for update to authenticated
  using (owner = (select auth.uid())) with check (owner = (select auth.uid()) and (group_id is null or public.can_share_study(group_id)));

drop policy if exists "add deadline" on public.deadlines;
drop policy if exists "edit own deadline" on public.deadlines;
create policy "add deadline" on public.deadlines for insert to authenticated
  with check (owner = (select auth.uid()) and (group_id is null or public.can_share_study(group_id)));
create policy "edit own deadline" on public.deadlines for update to authenticated
  using (owner = (select auth.uid())) with check (owner = (select auth.uid()) and (group_id is null or public.can_share_study(group_id)));

-- a calm limit against flooding a shared timetable
create or replace function public.trg_study_limit() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_table_name = 'lessons' and (select count(*) from public.lessons where owner = new.owner and created_at > now() - interval '1 day') >= 80 then raise exception 'too_many'; end if;
  if tg_table_name = 'deadlines' and (select count(*) from public.deadlines where owner = new.owner and created_at > now() - interval '1 day') >= 40 then raise exception 'too_many'; end if;
  return new;
end $$;
create trigger lessons_limit before insert on public.lessons for each row execute function public.trg_study_limit();
create trigger deadlines_limit before insert on public.deadlines for each row execute function public.trg_study_limit();

-- a new exam or assignment of the group reaches its members
create or replace function public.trg_deadline_shared() returns trigger language plpgsql security definer set search_path = '' as $$
declare m record; gname text;
begin
  if new.group_id is null then return new; end if;
  select name into gname from public.groups where id = new.group_id;
  for m in select user_id from public.group_members where group_id = new.group_id and user_id <> new.owner limit 500 loop
    perform public.notify(m.user_id, new.owner, 'study_deadline', jsonb_build_object('deadline', new.id, 'title', left(new.title, 80), 'kind', new.kind,
      'due', new.due_at, 'group', new.group_id, 'gname', left(coalesce(gname, ''), 60)));
  end loop;
  return new;
end $$;
create trigger deadlines_shared after insert on public.deadlines for each row execute function public.trg_deadline_shared();

-- ============ 2. notification category "study", so it can be muted in the settings ============
create or replace function public.notif_category(k text) returns text language sql immutable set search_path = '' as $$
  select case
    when k in ('react', 'comment_like', 'repost', 'msg_react', 'story_react', 'grade_plus', 'recipe_cook') then 'reactions'
    when k in ('comment', 'comment_reply', 'mention', 'story_mention') then 'comments'
    when k in ('friend_req', 'friend_ok', 'kin_req', 'kin_ok') then 'friends'
    when k = 'message' then 'messages'
    when k in ('nameday', 'birthday', 'nameday_me', 'birthday_me') then 'celebrations'
    when k = 'live_start' then 'live'
    when k in ('room_invite', 'jk_invite') then 'rooms'
    when k = 'help_new' then 'help'
    when k in ('match', 'super') then 'dating'
    when k = 'gift' then 'gifts'
    when k = 'promo' then 'promo'
    when k in ('lesson_soon', 'deadline_soon', 'study_deadline') then 'study'
    when k like 'bet\_%' then 'sport'
    when k like 'ride\_%' or k like 'job\_%' then 'deals'
    when k like 'group\_%' then 'groups'
    when k like 'event\_%' or k like 'album\_%' then 'events'
    else 'system' end;
$$;

-- ============ 3. reminders: a quarter of an hour before a lecture, the evening before and the morning of a deadline ============
-- times are Tbilisi time; each reminder goes once (private.study_sent), only to people seen in the last 30 days
create table if not exists private.study_sent (
  user_id uuid not null,
  kind text not null,
  ref bigint not null,
  day date not null,
  primary key (user_id, kind, ref, day)
);

create or replace function private.study_reminders() returns integer language plpgsql security definer set search_path = '' as $$
declare loc timestamp := now() at time zone 'Asia/Tbilisi'; d date := (now() at time zone 'Asia/Tbilisi')::date;
  dow int := extract(isodow from now() at time zone 'Asia/Tbilisi')::int; odd boolean := extract(week from now() at time zone 'Asia/Tbilisi')::int % 2 = 1;
  t time := (now() at time zone 'Asia/Tbilisi')::time; n int := 0; k int;
begin
  -- lectures starting within the next 15 minutes
  with l as (
    select id, owner, group_id, title, starts, place from public.lessons
    where day = dow and (weeks = 'all' or (weeks = 'odd') = odd) and starts > t and starts <= t + interval '15 minutes'
  ), who as (
    select l.id, l.owner as uid from l where l.group_id is null
    union select l.id, m.user_id from l join public.group_members m on m.group_id = l.group_id
  ), fresh as (
    insert into private.study_sent (user_id, kind, ref, day)
    select w.uid, 'lesson', w.id, d from who w join public.profiles p on p.id = w.uid
    where p.last_seen > now() - interval '30 days' and not p.banned and not public.notif_off(w.uid, 'lesson_soon')
    on conflict do nothing returning user_id, ref
  )
  insert into public.notifications (user_id, actor, kind, ref)
  select f.user_id, null, 'lesson_soon', jsonb_build_object('lesson', l.id, 'title', left(l.title, 80), 'starts', to_char(l.starts, 'HH24:MI'), 'place', left(l.place, 60))
  from fresh f join l on l.id = f.ref;
  get diagnostics k = row_count; n := n + k;

  -- deadlines: tomorrow (from 19:00) and today (from 07:30)
  with x as (
    select dl.id, dl.owner, dl.group_id, dl.title, dl.kind, dl.due_at, case when (dl.due_at at time zone 'Asia/Tbilisi')::date = d then 'today' else 'tomorrow' end as w
    from public.deadlines dl
    where dl.created_at < now() - interval '3 hours'
      and ((t >= time '19:00' and (dl.due_at at time zone 'Asia/Tbilisi')::date = d + 1)
        or (t >= time '07:30' and (dl.due_at at time zone 'Asia/Tbilisi')::date = d and dl.due_at > now()))
  ), who as (
    select x.id, x.w, x.owner as uid from x where x.group_id is null
    union select x.id, x.w, m.user_id from x join public.group_members m on m.group_id = x.group_id
  ), fresh as (
    insert into private.study_sent (user_id, kind, ref, day)
    select w.uid, 'dl_' || w.w, w.id, d from who w join public.profiles p on p.id = w.uid
    where p.last_seen > now() - interval '30 days' and not p.banned and not public.notif_off(w.uid, 'deadline_soon')
      and not exists (select 1 from public.deadline_done dd where dd.user_id = w.uid and dd.deadline_id = w.id)
    on conflict do nothing returning user_id, kind, ref
  )
  insert into public.notifications (user_id, actor, kind, ref)
  select f.user_id, null, 'deadline_soon', jsonb_build_object('deadline', x.id, 'title', left(x.title, 80), 'kind', x.kind, 'due', x.due_at, 'when', x.w)
  from fresh f join x on x.id = f.ref and 'dl_' || x.w = f.kind;
  get diagnostics k = row_count; n := n + k;

  -- once a night: old marks and old reminders go
  if t >= time '03:00' and t < time '03:05' then
    delete from private.study_sent where day < d - 3;
    delete from public.notifications where kind in ('lesson_soon', 'deadline_soon') and created_at < now() - interval '2 days';
  end if;
  return n;
end $$;
revoke all on function private.study_reminders() from public;

select cron.schedule('kurselebi-study-reminders', '*/5 * * * *', 'select private.study_reminders()');
