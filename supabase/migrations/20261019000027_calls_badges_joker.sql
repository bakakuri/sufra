-- a video call started from a group chat: a private room that every member of the chat may enter
alter table public.rooms add column if not exists conv_id bigint references public.conversations(id) on delete set null;
create table if not exists public.room_access (
  room_id bigint not null references public.rooms(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  primary key (room_id, user_id));
alter table public.room_access enable row level security;
create policy "own room access" on public.room_access for select using (user_id = (select auth.uid()));
revoke all on public.room_access from anon;
grant select on public.room_access to authenticated;
alter policy "rooms visible" on public.rooms using ((not public.is_blocked(host, (select auth.uid())))
  and ((not is_private) or host = (select auth.uid()) or public.are_friends(host, (select auth.uid()))
       or exists (select 1 from public.room_access a where a.room_id = rooms.id and a.user_id = (select auth.uid()))));

create or replace function public.start_group_call(p_conv bigint)
returns bigint
language plpgsql
security definer
set search_path to ''
as $function$
declare c record; r bigint;
begin
  if not public.can_post() then raise exception 'not_allowed'; end if;
  select * into c from public.conversations where id = p_conv;
  if c.id is null or not c.is_group or not exists (select 1 from public.conversation_members where conv_id = p_conv and user_id = auth.uid()) then raise exception 'not_allowed'; end if;
  select id into r from public.rooms where conv_id = p_conv and live and created_at > now() - interval '6 hours' order by id desc limit 1;
  if r is not null then return r; end if;
  insert into public.rooms (host, kind, title, topic, is_private, live, conv_id)
    values (auth.uid(), 'supra', left('ზარი · ' || coalesce(nullif(c.title, ''), 'ჯგუფი'), 80), 'other', true, true, p_conv) returning id into r;
  insert into public.room_access (room_id, user_id) select r, user_id from public.conversation_members where conv_id = p_conv;
  insert into public.messages (conv_id, sender, body, kind, media) values (p_conv, auth.uid(), 'ვიდეოზარი დაიწყო, შემოგვიერთდი', 'text', jsonb_build_object('call', r));
  return r;
end $function$;
revoke execute on function public.start_group_call(bigint) from public, anon;
grant execute on function public.start_group_call(bigint) to authenticated;

-- badges: earned on the server from what people actually did, each with a small coin reward
create table if not exists public.achievements (
  user_id uuid not null references public.profiles(id) on delete cascade,
  code text not null,
  created_at timestamptz not null default now(),
  primary key (user_id, code));
alter table public.achievements enable row level security;
create policy "badges visible" on public.achievements for select using (true);
revoke all on public.achievements from anon;
grant select on public.achievements to authenticated;

create or replace function public.check_achievements()
returns text[]
language plpgsql
security definer
set search_path to ''
as $function$
declare me uuid := auth.uid(); got text[] := '{}'; c record; ok boolean;
begin
  if me is null then return got; end if;
  for c in select * from (values ('post1',10,'პირველი პოსტი'),('story1',10,'პირველი ისტორია'),('friends10',20,'10 მეგობარი'),('grader',20,'შემფასებელი'),
      ('star',30,'ვარსკვლავი'),('host',20,'მასპინძელი'),('tamada',30,'თამადა'),('supra',15,'სუფრის გამშლელი'),('nardi',30,'ნარდის ოსტატი'),
      ('helper',20,'კეთილი გული'),('cook',15,'მზარეული'),('verified',10,'ვერიფიცირებული'),('album',10,'მემატიანე')) v(code, coins, title) loop
    if exists (select 1 from public.achievements a where a.user_id = me and a.code = c.code) then continue; end if;
    ok := case c.code
      when 'post1' then exists (select 1 from public.posts where author = me and not draft)
      when 'story1' then exists (select 1 from public.stories where author = me)
      when 'friends10' then (select count(*) from public.friendships where status = 'accepted' and (requester = me or addressee = me)) >= 10
      when 'grader' then (select count(*) from public.post_grades where user_id = me) >= 50
      when 'star' then (select count(*) from public.post_grades g join public.posts p on p.id = g.post_id where p.author = me and g.user_id <> me and g.grade = '5+') >= 10
      when 'host' then exists (select 1 from public.events where host = me and starts_at < now())
      when 'tamada' then exists (select 1 from public.events where tamada = me and starts_at < now())
      when 'supra' then exists (select 1 from public.rooms where host = me and kind = 'supra')
      when 'nardi' then coalesce((select rating from public.profiles where id = me), 0) >= 1600
      when 'helper' then exists (select 1 from public.help_offers where user_id = me)
      when 'cook' then exists (select 1 from public.recipes where author = me)
      when 'verified' then coalesce((select verified from public.profiles where id = me), false)
      when 'album' then exists (select 1 from public.albums where owner = me)
      else false end;
    if ok then
      insert into public.achievements (user_id, code) values (me, c.code) on conflict do nothing;
      update public.profiles set coins = coins + c.coins where id = me;
      insert into public.coin_log (user_id, amount, label) values (me, c.coins, 'ნიშანი: ' || c.title);
      got := got || c.code;
    end if;
  end loop;
  return got;
end $function$;
revoke execute on function public.check_achievements() from public, anon;
grant execute on function public.check_achievements() to authenticated;

-- online joker: four seats, empty seats are played by bots; the host's app runs the rules,
-- every hand is stored so that only its owner (and the host) can read it
create table if not exists public.jk_tables (
  id bigserial primary key,
  host uuid not null references public.profiles(id) on delete cascade,
  len text not null default 'quick' check (len in ('quick','full')),
  seats uuid[] not null default array[null,null,null,null]::uuid[] check (array_length(seats, 1) = 4),
  status text not null default 'wait' check (status in ('wait','play','over','closed')),
  state jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now());
create index if not exists jk_tables_host_idx on public.jk_tables (host, created_at desc);
create table if not exists public.jk_hands (
  table_id bigint not null references public.jk_tables(id) on delete cascade,
  seat smallint not null check (seat between 0 and 3),
  user_id uuid references public.profiles(id) on delete cascade,
  cards jsonb not null default '[]'::jsonb,
  primary key (table_id, seat));
create table if not exists public.jk_moves (
  id bigserial primary key,
  table_id bigint not null references public.jk_tables(id) on delete cascade,
  seat smallint not null check (seat between 0 and 3),
  user_id uuid not null references public.profiles(id) on delete cascade,
  move jsonb not null,
  created_at timestamptz not null default now());
create index if not exists jk_moves_table_idx on public.jk_moves (table_id, id);
alter table public.jk_tables enable row level security;
alter table public.jk_hands enable row level security;
alter table public.jk_moves enable row level security;
create policy "joker tables visible" on public.jk_tables for select using (not public.is_blocked(host, (select auth.uid())));
create policy "open joker table" on public.jk_tables for insert with check (host = (select auth.uid()) and public.can_post() and seats[1] = (select auth.uid()));
create policy "host runs joker table" on public.jk_tables for update using (host = (select auth.uid())) with check (host = (select auth.uid()));
create policy "host closes joker table" on public.jk_tables for delete using (host = (select auth.uid()));
create policy "own hand" on public.jk_hands for select using (user_id = (select auth.uid()) or exists (select 1 from public.jk_tables t where t.id = table_id and t.host = (select auth.uid())));
create policy "host deals" on public.jk_hands for insert with check (exists (select 1 from public.jk_tables t where t.id = table_id and t.host = (select auth.uid())));
create policy "host updates hands" on public.jk_hands for update using (exists (select 1 from public.jk_tables t where t.id = table_id and t.host = (select auth.uid())));
create policy "host clears hands" on public.jk_hands for delete using (exists (select 1 from public.jk_tables t where t.id = table_id and t.host = (select auth.uid())));
create policy "own moves" on public.jk_moves for select using (user_id = (select auth.uid()) or exists (select 1 from public.jk_tables t where t.id = table_id and t.host = (select auth.uid())));
create policy "seated player moves" on public.jk_moves for insert with check (user_id = (select auth.uid()) and exists (select 1 from public.jk_tables t where t.id = table_id and t.status = 'play' and t.seats[seat + 1] = (select auth.uid())));
revoke all on public.jk_tables, public.jk_hands, public.jk_moves from anon;
grant select, delete on public.jk_tables to authenticated;
grant insert (host, len, seats), update (len, seats, status, state, updated_at) on public.jk_tables to authenticated;
grant select, insert, update, delete on public.jk_hands to authenticated;
grant select on public.jk_moves to authenticated;
grant insert (table_id, seat, user_id, move) on public.jk_moves to authenticated;
grant usage on sequence public.jk_tables_id_seq, public.jk_moves_id_seq to authenticated;

create or replace function public.jk_join(p_table bigint)
returns int
language plpgsql
security definer
set search_path to ''
as $function$
declare t record; i int;
begin
  select * into t from public.jk_tables where id = p_table for update;
  if t.id is null or t.status <> 'wait' or public.is_blocked(t.host, auth.uid()) then raise exception 'not_allowed'; end if;
  for i in 1..4 loop if t.seats[i] = auth.uid() then return i - 1; end if; end loop;
  for i in 1..4 loop
    if t.seats[i] is null then
      update public.jk_tables set seats[i] = auth.uid(), updated_at = now() where id = p_table;
      return i - 1;
    end if;
  end loop;
  raise exception 'album_full';
end $function$;
create or replace function public.jk_leave(p_table bigint)
returns void
language plpgsql
security definer
set search_path to ''
as $function$
declare t record; i int;
begin
  select * into t from public.jk_tables where id = p_table for update;
  if t.id is null or t.host = auth.uid() then return; end if;
  for i in 1..4 loop
    if t.seats[i] = auth.uid() and t.status = 'wait' then update public.jk_tables set seats[i] = null, updated_at = now() where id = p_table; end if;
  end loop;
end $function$;
create or replace function public.jk_invite(p_table bigint, p_users uuid[])
returns int
language plpgsql
security definer
set search_path to ''
as $function$
declare t record; u uuid; n int := 0;
begin
  select * into t from public.jk_tables where id = p_table and host = auth.uid() and status = 'wait';
  if t.id is null then raise exception 'not_allowed'; end if;
  foreach u in array p_users loop
    if public.are_friends(auth.uid(), u) and n < 10 then
      perform public.notify(u, auth.uid(), 'jk_invite', jsonb_build_object('table', p_table));
      n := n + 1;
    end if;
  end loop;
  return n;
end $function$;
revoke execute on function public.jk_join(bigint), public.jk_leave(bigint), public.jk_invite(bigint, uuid[]) from public, anon;
grant execute on function public.jk_join(bigint), public.jk_leave(bigint), public.jk_invite(bigint, uuid[]) to authenticated;
alter publication supabase_realtime add table public.jk_tables, public.jk_hands, public.jk_moves;

-- notification groups for the new kinds
create or replace function public.notif_category(k text)
returns text
language sql
immutable
set search_path to ''
as $function$
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
    when k like 'bet\_%' then 'sport'
    when k like 'ride\_%' or k like 'job\_%' then 'deals'
    when k like 'group\_%' then 'groups'
    when k like 'event\_%' or k like 'album\_%' then 'events'
    else 'system' end;
$function$;

create or replace function public.service_counts()
returns jsonb
language sql
stable
security invoker
set search_path to ''
as $function$
  select jsonb_build_object(
    'rooms', (select count(*) from public.rooms r where r.live and r.created_at > now() - interval '12 hours'),
    'events', (select count(*) from public.events e where e.starts_at between now() and now() + interval '7 days'),
    'sport', (select count(*) from public.fixtures f where f.status = 'upcoming' and f.starts_at between now() - interval '3 hours' and now() + interval '7 days'),
    'help', (select count(*) from public.help_requests h where h.status = 'open' and (h.expires_at is null or h.expires_at > now())),
    'rides', (select count(*) from public.rides d where d.status = 'open' and d.depart_at > now()),
    'jobs', (select count(*) from public.jobs j where j.status = 'open'),
    'market', (select count(*) from public.listings l where l.status = 'active'),
    'places', (select count(*) from public.places),
    'groups', (select count(*) from public.groups),
    'pages', (select count(*) from public.pages),
    'albums', (select count(*) from public.albums),
    'toasts', (select count(*) from public.toasts),
    'recipes', (select count(*) from public.recipes)
  );
$function$;

-- the follow limit is a trigger (a policy that counts its own table would recurse)
alter policy "own tags insert" on public.tag_follows with check (user_id = (select auth.uid()));
create or replace function public.tag_follows_cap()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
begin
  if (select count(*) from public.tag_follows where user_id = new.user_id) >= 80 then raise exception 'album_full'; end if;
  new.tag := lower(trim(both '#' from trim(new.tag)));
  return new;
end $function$;
create or replace trigger tag_follows_cap before insert on public.tag_follows for each row execute function public.tag_follows_cap();
-- a trigger function is not something to call over the API
revoke execute on function public.tag_follows_cap() from public, anon, authenticated;
