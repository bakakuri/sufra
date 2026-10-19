-- groups and pages get their own picture; groups are no longer created automatically from "my corner"
alter table public.groups add column if not exists avatar_url text;
alter table public.groups add constraint groups_avatar_https check (avatar_url is null or avatar_url ~ '^https://[^\s"''<>()]+$');
alter table public.pages add constraint pages_avatar_https check (avatar_url is null or avatar_url ~ '^https://[^\s"''<>()]+$');

-- a new group is made by hand: the client may only fill these columns
revoke insert on public.groups from authenticated;
grant insert (owner, name, description, hue, is_private, join_mode, post_approval, rules, avatar_url) on public.groups to authenticated;
grant update (avatar_url) on public.groups to authenticated;

-- "my corner" no longer joins or creates groups
revoke execute on function public.join_place_groups() from public, anon, authenticated;

-- the surname group belongs to the person who makes it
create or replace function public.join_surname_group()
returns bigint
language plpgsql
security definer
set search_path to ''
as $function$
declare s text; g bigint;
begin
  if not public.can_post() then raise exception 'not_allowed'; end if;
  select trim(surname) into s from public.profiles where id = auth.uid();
  if coalesce(s, '') = '' then raise exception 'bad_request'; end if;
  insert into public.groups (owner, name, description, hue, is_private, kind, place_key)
    values (auth.uid(), left('გვარი · ' || s, 80), 'გვარის საერთო სახლი: ისტორია, ნათესავები, შეხვედრები', floor(random() * 360)::int, false, 'surname', 'surname:' || lower(s))
    on conflict (place_key) do nothing;
  select id into g from public.groups where place_key = 'surname:' || lower(s);
  insert into public.group_members (group_id, user_id) values (g, auth.uid()) on conflict do nothing;
  return g;
end $function$;

-- photo grades pay the photo's author: 1 coin for 1-4, 2 for 5, 3 for 5+
-- once per person per photo; a grader pays out at most 40 grades a day, an author earns at most 150 coins a day from grades
alter table public.post_grades add column if not exists created_at timestamptz not null default now();
alter table public.post_grades add column if not exists paid int not null default 0;
create index if not exists post_grades_time_idx on public.post_grades (created_at desc);
create index if not exists post_grades_user_time_idx on public.post_grades (user_id, created_at desc);
revoke insert, update, delete on public.post_grades from anon;
revoke insert, update on public.post_grades from authenticated;
grant insert (post_id, user_id, grade), update (post_id, user_id, grade) on public.post_grades to authenticated;

create or replace function private.grade_reward()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
declare a uuid; img boolean; amt int := 0; given int; earned int;
begin
  select p.author,
         exists (select 1 from jsonb_array_elements(case when jsonb_typeof(p.media) = 'array' then p.media else '[]'::jsonb end) m where m ->> 'type' = 'image')
    into a, img
    from public.posts p where p.id = new.post_id;
  if a is null or a = new.user_id or not img or public.is_blocked(new.user_id, a) then return null; end if;
  select count(*) into given from public.post_grades g
    where g.user_id = new.user_id and g.paid > 0 and g.created_at > now() - interval '1 day';
  select coalesce(sum(g.paid), 0) into earned from public.post_grades g join public.posts p on p.id = g.post_id
    where p.author = a and g.created_at > now() - interval '1 day';
  if given < 40 and earned < 150 then
    amt := least(case new.grade when '5+' then 3 when '5' then 2 else 1 end, 150 - earned);
    update public.post_grades set paid = amt where post_id = new.post_id and user_id = new.user_id;
    update public.profiles set coins = coins + amt where id = a;
    insert into public.coin_log (user_id, amount, label) values (a, amt, 'ფოტოს შეფასება');
  end if;
  if new.grade = '5+' then
    perform public.notify(a, new.user_id, 'grade_plus', jsonb_build_object('post', new.post_id, 'coins', amt));
  end if;
  return null;
end $function$;
revoke execute on function private.grade_reward() from public, anon, authenticated;
create or replace trigger post_grade_reward after insert on public.post_grades
  for each row execute function private.grade_reward();

-- grade a photo and learn how many coins went to its author (0 when it was a regrade or a daily limit was reached)
create or replace function public.grade_photo(p_post bigint, p_grade text)
returns integer
language plpgsql
security invoker
set search_path to ''
as $function$
declare fresh boolean; got int;
begin
  if not exists (select 1 from public.posts where id = p_post) then raise exception 'not_found'; end if;
  insert into public.post_grades (post_id, user_id, grade) values (p_post, auth.uid(), p_grade)
    on conflict (post_id, user_id) do update set grade = excluded.grade
    returning (xmax = 0) into fresh;
  if not fresh then return 0; end if;
  select paid into got from public.post_grades where post_id = p_post and user_id = auth.uid();
  return coalesce(got, 0);
end $function$;
revoke execute on function public.grade_photo(bigint, text) from public, anon;
grant execute on function public.grade_photo(bigint, text) to authenticated;

create or replace function public.notif_category(k text)
returns text
language sql
immutable
set search_path to ''
as $function$
  select case
    when k in ('react', 'comment_like', 'repost', 'msg_react', 'story_react', 'grade_plus') then 'reactions'
    when k in ('comment', 'comment_reply', 'mention') then 'comments'
    when k in ('friend_req', 'friend_ok', 'kin_req', 'kin_ok') then 'friends'
    when k = 'message' then 'messages'
    when k in ('nameday', 'birthday', 'nameday_me', 'birthday_me') then 'celebrations'
    when k = 'live_start' then 'live'
    when k = 'room_invite' then 'rooms'
    when k = 'help_new' then 'help'
    when k in ('match', 'super') then 'dating'
    when k = 'gift' then 'gifts'
    when k like 'bet\_%' then 'sport'
    when k like 'ride\_%' or k like 'job\_%' then 'deals'
    when k like 'group\_%' then 'groups'
    when k like 'event\_%' or k like 'album\_%' then 'events'
    else 'system' end;
$function$;

-- profile visitors are counted for the header badge
create index if not exists profile_visits_visited_idx on public.profile_visits (visited, visited_at desc);
