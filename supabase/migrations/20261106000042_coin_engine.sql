-- Peera coins, stage 1: one engine pays a few coins for activity on every page.
--
-- One balance, two parts:
--   coins       everything the person has
--   coins_cash  the part that can later be paid out in lari (10,000 = 1 ₾); never more than coins
-- Activity pays into coins always, and also into coins_cash while the admin's promotion is running.
-- Spending uses the other coins first, so coins_cash only drops when nothing else is left.
-- Balances from before the promotion stay spendable but are not cash.
--
-- Each kind of activity is a row in coin_rules: how many coins, a daily cap, a cap per post or person,
-- "every N" (5 messages = 1 coin), once ever, once per thing. All activity together pays at most
-- daily_max a day (150 by default). Coins for something deleted or hidden within 24 hours go back.

-- 1. the balance ---------------------------------------------------------------------------------

alter table public.profiles
  add column if not exists coins_cash integer not null default 0,
  add column if not exists bonus_streak smallint not null default 0;
alter table public.profiles drop constraint if exists profiles_coins_cash_check;
alter table public.profiles add constraint profiles_coins_cash_check check (coins_cash >= 0);

-- whatever changes coins, cash can never be more than the whole balance
create or replace function private.coins_clamp() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.coins_cash := greatest(0, least(coalesce(new.coins_cash, 0), coalesce(new.coins, 0)));
  return new;
end $$;
drop trigger if exists profiles_coins_clamp on public.profiles;
create trigger profiles_coins_clamp before insert or update of coins, coins_cash on public.profiles
  for each row execute function private.coins_clamp();

-- the history: how much of each line was cash, and one line a day per kind of activity (n = how many times)
alter table public.coin_log
  add column if not exists cash integer not null default 0,
  add column if not exists action text,
  add column if not exists n integer not null default 1;
create index if not exists coin_log_action_idx on public.coin_log (user_id, action, created_at desc) where action is not null;

-- 2. settings and rules --------------------------------------------------------------------------

insert into public.app_settings (key, value)
values ('coins', jsonb_build_object('on', false, 'until', null, 'daily_max', 150, 'rate', 10000, 'min_out', 10000, 'gift_share', 0.5, 'shop_fee', 0.1))
on conflict (key) do nothing;

create table if not exists public.coin_rules (
  action     text primary key,
  page       text not null,
  label      text not null,
  hint       text not null default '',
  amount     integer not null check (amount between 0 and 1000),
  every_n    integer not null default 1 check (every_n between 1 and 100),
  day_cap    integer not null default 0 check (day_cap between 0 and 5000),
  target_cap integer not null default 0 check (target_cap between 0 and 5000),
  once       boolean not null default false,
  uniq       boolean not null default false,
  in_max     boolean not null default true,
  active     boolean not null default true,
  pos        integer not null default 0
);
comment on table public.coin_rules is 'How many coins each activity pays. day_cap: coins a day from this activity; target_cap: coins a day from one post, chat or person; every_n: pays on every Nth time; once: once ever; uniq: once per thing; in_max: counts toward the daily maximum.';
alter table public.coin_rules enable row level security;
drop policy if exists "coin rules readable" on public.coin_rules;
create policy "coin rules readable" on public.coin_rules for select to authenticated using (true);
revoke insert, update, delete, truncate on public.coin_rules from anon, authenticated;

insert into public.coin_rules (pos, action, page, label, hint, amount, every_n, day_cap, target_cap, once, uniq, in_max) values
  ( 1, 'daily',        'coins',    'დღიური ბონუსი',            'დღეში ერთხელ',                   5, 1,  5, 0, false, true,  false),
  ( 2, 'streak7',      'coins',    '7 დღე ზედიზედ',            'მე-7 დღეს, ბონუსის გარდა',       10, 1, 10, 0, false, true,  false),
  (10, 'post',         'home',     'პოსტი',                    'ტექსტი, ფოტო ან გამოკითხვა',      3, 1,  9, 0, false, true,  true),
  (11, 'comment',      'home',     'კომენტარი',                'ერთ პოსტზე დღეში 2-მდე',          1, 1, 20, 2, false, true,  true),
  (12, 'grade',        'home',     'ფოტოს შეფასება',           'სხვის ფოტოზე',                    1, 1, 20, 0, false, true,  true),
  (13, 'got_grade',    'home',     'შენი ფოტო შეაფასეს',       'ერთი ადამიანისგან დღეში 1',       1, 1, 20, 1, false, true,  true),
  (14, 'react',        'home',     'მოწონებები',               'ყოველ 5 მოწონებაზე',              1, 5,  5, 0, false, false, true),
  (15, 'poll_vote',    'home',     'ხმა გამოკითხვაში',         '',                                1, 1,  3, 0, false, true,  true),
  (20, 'msg',          'chat',     'შეტყობინებები',            'ყოველ 5 შეტყობინებაზე',           1, 5, 10, 4, false, false, true),
  (30, 'story',        'stories',  'ისტორია',                  '',                                1, 1,  3, 0, false, true,  true),
  (31, 'story_react',  'stories',  'რეაქცია ისტორიაზე',        '',                                1, 1,  5, 0, false, true,  true),
  (40, 'clip',         'clips',    'კლიპი',                    '',                                5, 1, 10, 0, false, true,  true),
  (50, 'group_post',   'groups',   'პოსტი ჯგუფში',             '',                                2, 1,  6, 0, false, true,  true),
  (51, 'group_join',   'groups',   'ჯგუფში გაწევრიანება',      '',                                1, 1,  3, 0, false, true,  true),
  (60, 'friend',       'friends',  'ახალი მეგობარი',           '',                                2, 1, 10, 0, false, true,  true),
  (70, 'predict',      'sport',    'პროგნოზი',                 'უფასო პროგნოზიც ითვლება',         1, 1,  5, 0, false, true,  true),
  (71, 'predict_win',  'sport',    'სწორი პროგნოზი',           '',                                5, 1, 25, 0, false, true,  true),
  (72, 'fx_chat',      'sport',    'მატჩის ჩატი',              'ყოველ 5 შეტყობინებაზე',           1, 5,  3, 0, false, false, true),
  (80, 'game_win',     'games',    'მოგება ონლაინ',            'ერთ მოწინააღმდეგესთან დღეში 4-მდე', 2, 1, 20, 4, false, true,  true),
  (81, 'bot_win',      'games',    'მოგება ბოტთან',            '',                                1, 1,  5, 0, false, false, true),
  (90, 'recipe',       'recipes',  'რეცეპტი',                  '',                                3, 1,  6, 0, false, true,  true),
  (91, 'recipe_cook',  'recipes',  '„მოვამზადე“',              'სხვის რეცეპტზე',                  2, 1,  4, 0, false, true,  true),
  (100,'help_offer',   'help',     'დახმარების შეთავაზება',    '',                                2, 1,  6, 0, false, true,  true),
  (110,'place',        'places',   'ახალი ადგილი',             '',                                3, 1,  6, 0, false, true,  true),
  (111,'place_review', 'places',   'ადგილის შეფასება',         '',                                2, 1,  6, 0, false, true,  true),
  (120,'album_photo',  'albums',   'ფოტო ალბომში',             '',                                1, 1,  5, 0, false, true,  true),
  (130,'event',        'events',   'შეხვედრის შექმნა',         '',                                3, 1,  3, 0, false, true,  true),
  (131,'rsvp',         'events',   '„მოვდივარ“ შეხვედრაზე',    '',                                1, 1,  3, 0, false, true,  true),
  (140,'toast',        'toasts',   'სადღეგრძელო',              '',                                2, 1,  4, 0, false, true,  true),
  (150,'listing',      'market',   'განცხადება ბაზრობაზე',     '',                                2, 1,  4, 0, false, true,  true),
  (160,'job',          'jobs',     'ვაკანსია',                 '',                                2, 1,  4, 0, false, true,  true),
  (161,'job_apply',    'jobs',     'განაცხადი ვაკანსიაზე',     '',                                1, 1,  3, 0, false, true,  true),
  (170,'ride',         'rides',    'მგზავრობის დამატება',      '',                                2, 1,  4, 0, false, true,  true),
  (171,'ride_book',    'rides',    'ადგილის დაჯავშნა',         '',                                1, 1,  2, 0, false, true,  true),
  (180,'kin',          'tree',     'ნათესავი ოჯახის ხეში',     '',                                1, 1,  5, 0, false, true,  true),
  (190,'lessons',      'schedule', 'ლექციების ცხრილი',         'ერთხელ, პირველ ლექციაზე',         5, 1,  0, 0, true,  false, true),
  (191,'task_done',    'exams',    'შესრულებული დავალება',     '',                                1, 1,  3, 0, false, true,  true),
  (200,'profile_photo','me',       'პროფილის ფოტო',            'ერთხელ',                         10, 1,  0, 0, true,  false, true),
  (201,'profile_bio',  'me',       'ბიოგრაფია',                'ერთხელ, 20 სიმბოლოდან',           5, 1,  0, 0, true,  false, true),
  (202,'verified',     'me',       'ვერიფიკაცია',              'ერთხელ',                         20, 1,  0, 0, true,  false, false)
on conflict (action) do nothing;

-- 3. what was paid, for the limits and for taking coins back ------------------------------------

create table if not exists private.earn_events (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  action     text not null,
  ref        text,
  target     text,
  amount     integer not null,
  cash       integer not null default 0,
  day        date not null,
  undone     boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists earn_events_day_idx on private.earn_events (user_id, day);
create index if not exists earn_events_ref_idx on private.earn_events (user_id, action, ref);
create index if not exists earn_events_all_day_idx on private.earn_events (day);

-- "every N": how many times today, so the 5th message pays
create table if not exists private.earn_counts (
  user_id uuid not null references public.profiles(id) on delete cascade,
  action  text not null,
  day     date not null,
  n       integer not null default 0,
  primary key (user_id, action, day)
);
revoke all on private.earn_events, private.earn_counts from anon, authenticated;

-- 4. helpers -----------------------------------------------------------------------------------

-- the day in Georgia, so "today" turns over at midnight in Tbilisi
create or replace function private.tday() returns date
language sql stable set search_path = '' as $$ select (now() at time zone 'Asia/Tbilisi')::date $$;

create or replace function private.coin_cfg() returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce((select value from public.app_settings where key = 'coins'), '{}'::jsonb) $$;

create or replace function private.promo_on() returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce((c ->> 'on')::boolean, false) and coalesce((c ->> 'until')::timestamptz, '-infinity'::timestamptz) > now()
  from (select private.coin_cfg() as c) x $$;

-- add coins (and, of those, p_cash cash coins); activity lines are merged into one line a day
create or replace function private.credit(p_user uuid, p_amount integer, p_label text, p_cash integer default 0, p_action text default null)
returns integer language plpgsql security definer set search_path = '' as $$
declare v_cash int := greatest(0, least(coalesce(p_cash, 0), p_amount)); v_bal int; v_line bigint;
begin
  if p_amount is null or p_amount <= 0 then return null; end if;
  update public.profiles set coins = coins + p_amount, coins_cash = coins_cash + v_cash where id = p_user returning coins into v_bal;
  if v_bal is null then return null; end if;
  if p_action is not null then
    select l.id into v_line from public.coin_log l
      where l.user_id = p_user and l.action = p_action and l.amount > 0
        and l.created_at >= (private.tday()::timestamp at time zone 'Asia/Tbilisi')
      order by l.created_at desc limit 1;
    if v_line is not null then
      update public.coin_log set amount = amount + p_amount, cash = cash + v_cash, n = n + 1, created_at = now() where id = v_line;
    end if;
  end if;
  if v_line is null then
    insert into public.coin_log (user_id, amount, label, cash, action) values (p_user, p_amount, left(p_label, 80), v_cash, p_action);
  end if;
  return v_bal;
end $$;

-- take coins, the other coins first; o_cash says how much of the payment was cash (gifts and the shop pass that part on)
create or replace function private.spend(p_user uuid, p_amount integer, p_label text, out o_bal integer, out o_cash integer)
language plpgsql security definer set search_path = '' as $$
declare v_before int;
begin
  if p_amount is null or p_amount <= 0 then raise exception 'bad_amount'; end if;
  select coins_cash into v_before from public.profiles where id = p_user for update;
  update public.profiles set coins = coins - p_amount where id = p_user and coins >= p_amount returning coins, coins_cash into o_bal, o_cash;
  if o_bal is null then raise exception 'not_enough_coins'; end if;
  o_cash := coalesce(v_before, 0) - o_cash;
  insert into public.coin_log (user_id, amount, label, cash) values (p_user, -p_amount, left(p_label, 80), -o_cash);
end $$;

-- 5. the engine --------------------------------------------------------------------------------

-- pay p_user for p_action; p_ref is the thing (a comment, a post), p_target the post, chat or person the caps count by.
-- returns the coins paid (0 when a limit is reached)
create or replace function private.earn(p_user uuid, p_action text, p_ref text default null, p_target text default null)
returns integer language plpgsql security definer set search_path = '' as $$
declare r public.coin_rules; v_day date := private.tday(); v_cfg jsonb := private.coin_cfg();
  v_max int; v_all int; v_act int; v_tgt int; v_amt int; v_cash int; v_n int;
begin
  if p_user is null then return 0; end if;
  select * into r from public.coin_rules where action = p_action and active;
  if not found or r.amount <= 0 then return 0; end if;
  if not exists (select 1 from public.profiles where id = p_user and onboarded and not banned) then return 0; end if;
  -- one person's coins are counted one at a time, so two comments at once cannot both slip under a cap
  perform pg_advisory_xact_lock(hashtextextended('earn:' || p_user::text, 0));
  if r.once and exists (select 1 from private.earn_events where user_id = p_user and action = p_action) then return 0; end if;
  if r.uniq and p_ref is not null and exists (select 1 from private.earn_events where user_id = p_user and action = p_action and ref = p_ref) then return 0; end if;
  if r.every_n > 1 then
    insert into private.earn_counts as c (user_id, action, day, n) values (p_user, p_action, v_day, 1)
      on conflict (user_id, action, day) do update set n = c.n + 1
      returning c.n into v_n;
    if v_n % r.every_n <> 0 then return 0; end if;
  end if;
  v_max := coalesce((v_cfg ->> 'daily_max')::int, 150);
  select coalesce(sum(e.amount) filter (where coalesce(q.in_max, true)), 0),
         coalesce(sum(e.amount) filter (where e.action = p_action), 0),
         coalesce(sum(e.amount) filter (where e.action = p_action and e.target = p_target), 0)
    into v_all, v_act, v_tgt
    from private.earn_events e left join public.coin_rules q on q.action = e.action
    where e.user_id = p_user and e.day = v_day and not e.undone;
  v_amt := r.amount;
  if r.day_cap > 0 then v_amt := least(v_amt, r.day_cap - v_act); end if;
  if r.target_cap > 0 and p_target is not null then v_amt := least(v_amt, r.target_cap - v_tgt); end if;
  if r.in_max then v_amt := least(v_amt, v_max - v_all); end if;
  if v_amt <= 0 then return 0; end if;
  v_cash := case when private.promo_on() then v_amt else 0 end;
  insert into private.earn_events (user_id, action, ref, target, amount, cash, day)
    values (p_user, p_action, p_ref, p_target, v_amt, v_cash, v_day);
  perform private.credit(p_user, v_amt, r.label, v_cash, p_action);
  return v_amt;
end $$;

-- the thing was deleted or hidden: within 24 hours its coins go back
create or replace function private.earn_undo(p_user uuid, p_action text, p_ref text)
returns integer language plpgsql security definer set search_path = '' as $$
declare v_amt int; v_cash int; v_label text;
begin
  if p_user is null or p_ref is null then return 0; end if;
  with x as (
    update private.earn_events set undone = true
      where user_id = p_user and action = p_action and ref = p_ref and not undone and created_at > now() - interval '24 hours'
      returning amount, cash)
  select coalesce(sum(amount), 0), coalesce(sum(cash), 0) into v_amt, v_cash from x;
  if v_amt <= 0 then return 0; end if;
  update public.profiles set coins = greatest(0, coins - v_amt), coins_cash = greatest(0, coins_cash - v_cash) where id = p_user;
  if found then
    select label into v_label from public.coin_rules where action = p_action;
    insert into public.coin_log (user_id, amount, label, cash) values (p_user, -v_amt, left('წაიშალა: ' || coalesce(v_label, p_action), 80), -v_cash);
  end if;
  return v_amt;
end $$;

-- 6. paying on every page -----------------------------------------------------------------------

create or replace function private.jlen(x jsonb) returns integer
language sql immutable set search_path = '' as $$
  select case jsonb_typeof(x) when 'array' then jsonb_array_length(x) when 'object' then 1 else 0 end $$;

-- a row counts while it is visible: not hidden, not a draft, not waiting for approval, not deleted
create or replace function private.earn_vis(p_t text, x jsonb) returns boolean
language sql immutable set search_path = '' as $$
  select case p_t
    when 'friendships' then x ->> 'status' = 'accepted'
    when 'event_rsvps' then x ->> 'status' = 'yes'
    else not (coalesce((x ->> 'hidden')::boolean, false) or coalesce((x ->> 'draft')::boolean, false)
           or coalesce((x ->> 'pending')::boolean, false) or coalesce((x ->> 'deleted')::boolean, false)) end $$;

-- one trigger for every table: becoming visible pays, being deleted or hidden takes back.
-- never on your own post, story, recipe, place, event, job or ride; never stops the action itself.
create or replace function private.earn_trg() returns trigger
language plpgsql security definer set search_path = '' as $$
declare t text := tg_table_name; j jsonb; o jsonb; v_mode text; u uuid; u2 uuid; v_owner uuid;
  v_act text; v_ref text; v_ref2 text; v_tgt text; v_parent boolean := true;
begin
  j := case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end;
  if tg_op = 'INSERT' then
    v_mode := case when private.earn_vis(t, j) then 'earn' end;
  elsif tg_op = 'DELETE' then
    v_mode := case when private.earn_vis(t, j) then 'undo' end;
  else
    o := to_jsonb(old);
    v_mode := case when not private.earn_vis(t, o) and private.earn_vis(t, j) then 'earn'
                   when private.earn_vis(t, o) and not private.earn_vis(t, j) then 'undo' end;
  end if;
  if v_mode is null then return null; end if;
  begin
    case t
    when 'posts' then
      if j ->> 'repost_of' is not null then return null; end if;
      if v_mode = 'earn' and length(trim(coalesce(j ->> 'body', ''))) < 10 and private.jlen(j -> 'media') = 0
         and jsonb_typeof(j -> 'poll') is distinct from 'object' then return null; end if;
      u := (j ->> 'author')::uuid; v_ref := 'p:' || (j ->> 'id');
      v_act := case when coalesce((j ->> 'is_clip')::boolean, false) then 'clip' when j ->> 'group_id' is not null then 'group_post' else 'post' end;
    when 'comments' then
      if v_mode = 'earn' and length(trim(coalesce(j ->> 'body', ''))) < 2 and private.jlen(j -> 'media') = 0 then return null; end if;
      u := (j ->> 'author')::uuid; v_act := 'comment'; v_ref := 'c:' || (j ->> 'id'); v_tgt := 'p:' || (j ->> 'post_id');
      v_parent := exists (select 1 from public.posts where id = (j ->> 'post_id')::bigint);
    when 'post_grades' then
      -- paying for grades happens in grade_reward; here only taking back when a grade is removed
      if v_mode <> 'undo' then return null; end if;
      u := (j ->> 'user_id')::uuid; v_act := 'grade'; v_ref := 'g:' || (j ->> 'post_id');
      select author into u2 from public.posts where id = (j ->> 'post_id')::bigint;
      v_parent := u2 is not null; v_ref2 := 'gg:' || (j ->> 'post_id') || ':' || (j ->> 'user_id');
    when 'messages' then
      if v_mode <> 'earn' or (length(trim(coalesce(j ->> 'body', ''))) < 2 and private.jlen(j -> 'media') = 0) then return null; end if;
      u := (j ->> 'sender')::uuid; v_act := 'msg'; v_tgt := 'cv:' || (j ->> 'conv_id');
    when 'reactions' then
      if v_mode <> 'earn' then return null; end if;
      u := (j ->> 'user_id')::uuid; v_act := 'react';
      select author into v_owner from public.posts where id = (j ->> 'post_id')::bigint;
    when 'poll_votes' then
      if v_mode <> 'earn' then return null; end if;
      u := (j ->> 'user_id')::uuid; v_act := 'poll_vote'; v_ref := 'pv:' || (j ->> 'post_id');
      select author into v_owner from public.posts where id = (j ->> 'post_id')::bigint;
    when 'stories' then
      u := (j ->> 'author')::uuid; v_act := 'story'; v_ref := 's:' || (j ->> 'id');
    when 'story_reactions', 'story_votes' then
      if v_mode <> 'earn' then return null; end if;
      u := (j ->> 'user_id')::uuid; v_act := 'story_react'; v_ref := 's:' || (j ->> 'story_id');
      select author into v_owner from public.stories where id = (j ->> 'story_id')::bigint;
    when 'group_members' then
      if j ->> 'role' = 'owner' then return null; end if;
      u := (j ->> 'user_id')::uuid; v_act := 'group_join'; v_ref := 'gm:' || (j ->> 'group_id');
      select owner into v_owner from public.groups where id = (j ->> 'group_id')::bigint;
      v_parent := found;
    when 'friendships' then
      u := (j ->> 'requester')::uuid; u2 := (j ->> 'addressee')::uuid; v_act := 'friend';
      v_ref := 'f:' || u2; v_ref2 := 'f:' || u;
    when 'fixture_chat' then
      if v_mode <> 'earn' or length(trim(coalesce(j ->> 'body', ''))) < 2 then return null; end if;
      u := (j ->> 'user_id')::uuid; v_act := 'fx_chat'; v_tgt := 'fx:' || (j ->> 'fixture_id');
    when 'recipes' then
      u := (j ->> 'author')::uuid; v_act := 'recipe'; v_ref := 'r:' || (j ->> 'id');
    when 'recipe_cooks' then
      u := (j ->> 'user_id')::uuid; v_act := 'recipe_cook'; v_ref := 'rc:' || (j ->> 'recipe_id');
      select author into v_owner from public.recipes where id = (j ->> 'recipe_id')::bigint;
      v_parent := found;
    when 'help_offers' then
      u := (j ->> 'user_id')::uuid; v_act := 'help_offer'; v_ref := 'ho:' || (j ->> 'request_id');
      select author into v_owner from public.help_requests where id = (j ->> 'request_id')::bigint;
      v_parent := found;
    when 'places' then
      u := (j ->> 'created_by')::uuid; v_act := 'place'; v_ref := 'pl:' || (j ->> 'id');
    when 'place_reviews' then
      u := (j ->> 'author')::uuid; v_act := 'place_review'; v_ref := 'pr:' || (j ->> 'place_id');
      select created_by into v_owner from public.places where id = (j ->> 'place_id')::bigint;
      v_parent := found;
    when 'album_photos' then
      u := (j ->> 'added_by')::uuid; v_act := 'album_photo'; v_ref := 'ap:' || (j ->> 'id');
      v_parent := exists (select 1 from public.albums where id = (j ->> 'album_id')::bigint);
    when 'events' then
      u := (j ->> 'host')::uuid; v_act := 'event'; v_ref := 'ev:' || (j ->> 'id');
    when 'event_rsvps' then
      u := (j ->> 'user_id')::uuid; v_act := 'rsvp'; v_ref := 'er:' || (j ->> 'event_id');
      select host into v_owner from public.events where id = (j ->> 'event_id')::bigint;
      v_parent := found;
    when 'toasts' then
      u := (j ->> 'author')::uuid; v_act := 'toast'; v_ref := 't:' || (j ->> 'id');
    when 'listings' then
      u := (j ->> 'seller')::uuid; v_act := 'listing'; v_ref := 'l:' || (j ->> 'id');
    when 'jobs' then
      u := (j ->> 'poster')::uuid; v_act := 'job'; v_ref := 'j:' || (j ->> 'id');
    when 'job_applications' then
      u := (j ->> 'user_id')::uuid; v_act := 'job_apply'; v_ref := 'ja:' || (j ->> 'job_id');
      select poster into v_owner from public.jobs where id = (j ->> 'job_id')::bigint;
      v_parent := found;
    when 'rides' then
      u := (j ->> 'driver')::uuid; v_act := 'ride'; v_ref := 'rd:' || (j ->> 'id');
    when 'ride_bookings' then
      u := (j ->> 'user_id')::uuid; v_act := 'ride_book'; v_ref := 'rb:' || (j ->> 'ride_id');
      select driver into v_owner from public.rides where id = (j ->> 'ride_id')::bigint;
      v_parent := found;
    when 'kin' then
      u := (j ->> 'owner')::uuid; v_act := 'kin'; v_ref := 'k:' || (j ->> 'id');
    when 'lessons' then
      if v_mode <> 'earn' then return null; end if;
      u := (j ->> 'owner')::uuid; v_act := 'lessons';
    when 'deadline_done' then
      if v_mode <> 'earn' then return null; end if;
      u := (j ->> 'user_id')::uuid; v_act := 'task_done'; v_ref := 'dd:' || (j ->> 'deadline_id');
    else
      return null;
    end case;
    if u is null or (v_owner is not null and v_owner = u) then return null; end if;
    if v_mode = 'earn' then
      perform private.earn(u, v_act, v_ref, v_tgt);
      if t = 'friendships' then perform private.earn(u2, v_act, v_ref2, null); end if;
    elsif v_parent then
      -- a comment that disappears because its post was deleted does not cost the commenter
      perform private.earn_undo(u, v_act, v_ref);
      if t = 'friendships' then perform private.earn_undo(u2, v_act, v_ref2);
      elsif t = 'post_grades' then perform private.earn_undo(u2, 'got_grade', v_ref2);
      end if;
    end if;
  exception when others then
    raise warning 'earn %/% failed: %', t, tg_op, sqlerrm;
  end;
  return null;
end $$;

do $$
declare x record;
begin
  for x in select * from (values
    ('posts',            'insert or update of draft, pending, hidden or delete'),
    ('comments',         'insert or update of hidden or delete'),
    ('post_grades',      'delete'),
    ('messages',         'insert'),
    ('reactions',        'insert'),
    ('poll_votes',       'insert'),
    ('stories',          'insert or delete'),
    ('story_reactions',  'insert'),
    ('story_votes',      'insert'),
    ('group_members',    'insert or delete'),
    ('friendships',      'insert or update of status or delete'),
    ('fixture_chat',     'insert'),
    ('recipes',          'insert or delete'),
    ('recipe_cooks',     'insert or delete'),
    ('help_offers',      'insert or delete'),
    ('places',           'insert or update of hidden or delete'),
    ('place_reviews',    'insert or update of hidden or delete'),
    ('album_photos',     'insert or delete'),
    ('events',           'insert or delete'),
    ('event_rsvps',      'insert or update of status or delete'),
    ('toasts',           'insert or update of hidden or delete'),
    ('listings',         'insert or update of hidden or delete'),
    ('jobs',             'insert or update of hidden or delete'),
    ('job_applications', 'insert or delete'),
    ('rides',            'insert or delete'),
    ('ride_bookings',    'insert or delete'),
    ('kin',              'insert or delete'),
    ('lessons',          'insert'),
    ('deadline_done',    'insert')) v(t, ev)
  loop
    execute format('drop trigger if exists %I on public.%I', x.t || '_earn', x.t);
    execute format('create trigger %I after %s on public.%I for each row execute function private.earn_trg()', x.t || '_earn', x.ev, x.t);
  end loop;
end $$;

-- the profile: a photo, a few words about yourself and verification pay once
create or replace function private.earn_profile() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  begin
    if coalesce(new.avatar_url, '') <> '' and coalesce(old.avatar_url, '') = '' then perform private.earn(new.id, 'profile_photo'); end if;
    if length(trim(coalesce(new.bio, ''))) >= 20 and length(trim(coalesce(old.bio, ''))) < 20 then perform private.earn(new.id, 'profile_bio'); end if;
    if new.verified and not coalesce(old.verified, false) then perform private.earn(new.id, 'verified'); end if;
  exception when others then
    raise warning 'earn profile failed: %', sqlerrm;
  end;
  return null;
end $$;
drop trigger if exists profiles_earn on public.profiles;
create trigger profiles_earn after update of avatar_url, bio, verified on public.profiles
  for each row execute function private.earn_profile();

-- grading a photo: 1 to the one who grades, 1 to the author (once a day from the same person)
create or replace function private.grade_reward() returns trigger
language plpgsql security definer set search_path = '' as $$
declare a uuid; img boolean; amt int := 0;
begin
  select p.author,
         exists (select 1 from jsonb_array_elements(case when jsonb_typeof(p.media) = 'array' then p.media else '[]'::jsonb end) m where m ->> 'type' = 'image')
    into a, img
    from public.posts p where p.id = new.post_id;
  if a is null or a = new.user_id or not img or public.is_blocked(new.user_id, a) then return null; end if;
  begin
    perform private.earn(new.user_id, 'grade', 'g:' || new.post_id, 'u:' || a);
    amt := coalesce(private.earn(a, 'got_grade', 'gg:' || new.post_id || ':' || new.user_id, 'u:' || new.user_id), 0);
    if amt > 0 then update public.post_grades set paid = amt where post_id = new.post_id and user_id = new.user_id; end if;
  exception when others then
    raise warning 'grade earn failed: %', sqlerrm;
  end;
  if new.grade = '5+' then
    perform public.notify(a, new.user_id, 'grade_plus', jsonb_build_object('post', new.post_id, 'coins', amt));
  end if;
  return null;
end $$;

-- 7. the existing ways to get and spend coins ----------------------------------------------------

create or replace function public.spend_coins(p_amount integer, p_label text) returns integer
language plpgsql security definer set search_path = '' as $$
declare v_bal int;
begin
  if auth.uid() is null then raise exception 'not_signed_in'; end if;
  select o_bal into v_bal from private.spend(auth.uid(), p_amount, p_label);
  return v_bal;
end $$;

-- the daily bonus: 5, and 10 more on the 7th day in a row
drop function if exists public.daily_bonus();
create function public.daily_bonus() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); v_day date := private.tday(); v_last date; v_st int; v_got int := 0; v_bal int; v_cash int;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  select last_bonus, bonus_streak into v_last, v_st from public.profiles where id = me for update;
  if not found then raise exception 'not_found'; end if;
  if v_last is not null and v_last >= v_day then raise exception 'already_claimed'; end if;
  v_st := case when v_last = v_day - 1 then (coalesce(v_st, 0) % 7) + 1 else 1 end;
  update public.profiles set last_bonus = v_day, bonus_streak = v_st where id = me;
  v_got := coalesce(private.earn(me, 'daily', 'd:' || v_day), 0);
  if v_st = 7 then v_got := v_got + coalesce(private.earn(me, 'streak7', 'st:' || v_day), 0); end if;
  select coins, coins_cash into v_bal, v_cash from public.profiles where id = me;
  return jsonb_build_object('coins', v_bal, 'cash', v_cash, 'got', v_got, 'streak', v_st);
end $$;
revoke all on function public.daily_bonus() from public, anon;
grant execute on function public.daily_bonus() to authenticated;

-- a win against the computer (the phone reports it, so it pays little)
create or replace function public.game_result(p_game text, p_win boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare c int; r int; reward int := 0;
begin
  if auth.uid() is null then raise exception 'not_signed_in'; end if;
  if p_win then reward := coalesce(private.earn(auth.uid(), 'bot_win'), 0); end if;
  select coins, rating into c, r from public.profiles where id = auth.uid();
  return jsonb_build_object('rating', r, 'coins', c, 'reward', reward);
end $$;

-- an online win (the server decides it); the same rating code as before, the coins through the engine
create or replace function private.match_apply(p_id bigint, p_res smallint) returns void
language plpgsql security definer set search_path = '' as $$
declare m public.game_matches; ra public.game_ratings; rb public.game_ratings; s1 numeric; e1 numeric; k1 int; k2 int; v1 int := 0; v2 int := 0;
  cur text := to_char(now() at time zone 'Asia/Tbilisi', 'YYYY-MM'); w uuid; l uuid;
begin
  select * into m from public.game_matches where id = p_id for update;
  if m.id is null or m.result is not null then return; end if;
  if p_res is null or p_res not in (1,-1,2) then update public.game_matches set result = 0, d1 = 0, d2 = 0, finished_at = now() where id = m.id; return; end if;
  if not (m.rated and m.seen1 and m.seen2) then update public.game_matches set result = p_res, d1 = 0, d2 = 0, finished_at = now() where id = m.id; return; end if;
  insert into public.game_ratings (user_id, game) values (m.p1, m.game), (m.p2, m.game) on conflict do nothing;
  select * into ra from public.game_ratings where user_id = m.p1 and game = m.game for update;
  select * into rb from public.game_ratings where user_id = m.p2 and game = m.game for update;
  s1 := case p_res when 1 then 1 when -1 then 0 else 0.5 end;
  e1 := 1 / (1 + power(10::numeric, (rb.rating - ra.rating) / 400.0));
  k1 := case when ra.games < 20 then 32 else 20 end;
  k2 := case when rb.games < 20 then 32 else 20 end;
  v1 := round(k1 * (s1 - e1)); v2 := round(k2 * ((1 - s1) - (1 - e1)));
  update public.game_ratings set rating = greatest(100, rating + v1), games = games + 1, wins = wins + (p_res = 1)::int,
    season_pts = (case when season = cur then season_pts else 0 end) + v1, season_games = (case when season = cur then season_games else 0 end) + 1, season = cur, updated_at = now()
    where user_id = m.p1 and game = m.game;
  update public.game_ratings set rating = greatest(100, rating + v2), games = games + 1, wins = wins + (p_res = -1)::int,
    season_pts = (case when season = cur then season_pts else 0 end) + v2, season_games = (case when season = cur then season_games else 0 end) + 1, season = cur, updated_at = now()
    where user_id = m.p2 and game = m.game;
  update public.game_matches set result = p_res, d1 = v1, d2 = v2, finished_at = now() where id = m.id;
  update public.profiles p set rating = (select max(g.rating) from public.game_ratings g where g.user_id = p.id) where p.id in (m.p1, m.p2);
  if p_res in (1,-1) then
    w := case when p_res = 1 then m.p1 else m.p2 end;
    l := case when p_res = 1 then m.p2 else m.p1 end;
    perform private.earn(w, 'game_win', 'm:' || m.id, 'u:' || l);
  end if;
end $$;

-- predictions: free ones are allowed and pay 1; a stake comes only from coins that are not cash,
-- so the pool never turns lari into a bet. Pool winnings are not cash either.
alter table public.predictions drop constraint if exists predictions_stake_check;
alter table public.predictions add constraint predictions_stake_check check (stake between 0 and 1000);

create or replace function public.predict(p_fixture bigint, p_pick text, p_stake integer) returns integer
language plpgsql security definer set search_path = '' as $$
declare f record; v_bal int; v_free int;
begin
  if not public.can_post() then raise exception 'not_allowed'; end if;
  select * into f from public.fixtures where id = p_fixture;
  if f.id is null or f.status <> 'upcoming' or f.starts_at <= now() then raise exception 'match_started'; end if;
  if p_pick not in ('1','X','2') or p_stake is null or p_stake < 0 or p_stake > 1000 then raise exception 'bad_request'; end if;
  if exists (select 1 from public.predictions where fixture_id = p_fixture and user_id = auth.uid()) then raise exception 'already_predicted'; end if;
  if p_stake > 0 then
    select coins - coins_cash into v_free from public.profiles where id = auth.uid() for update;
    if coalesce(v_free, 0) < p_stake then raise exception 'bonus_only'; end if;
    perform public.spend_coins(p_stake, 'პროგნოზი: ' || f.home || ' – ' || f.away);
  end if;
  insert into public.predictions (fixture_id, user_id, pick, stake) values (p_fixture, auth.uid(), p_pick, p_stake);
  perform private.earn(auth.uid(), 'predict', 'fx:' || p_fixture);
  select coins into v_bal from public.profiles where id = auth.uid();
  return v_bal;
end $$;

create or replace function public.admin_settle_fixture(p_fixture bigint, p_home integer, p_away integer) returns void
language plpgsql security definer set search_path = '' as $$
declare f record; res text; total int; win int; p record; pay int; got int;
begin
  if not public.is_staff() then raise exception 'staff_only'; end if;
  select * into f from public.fixtures where id = p_fixture for update;
  if f.id is null or f.status <> 'upcoming' then raise exception 'not_pending'; end if;
  if p_home < 0 or p_away < 0 then raise exception 'bad_request'; end if;
  res := case when p_home > p_away then '1' when p_home = p_away then 'X' else '2' end;
  select coalesce(sum(stake), 0), coalesce(sum(stake) filter (where pick = res), 0) into total, win from public.predictions where fixture_id = p_fixture;
  for p in select * from public.predictions where fixture_id = p_fixture loop
    pay := case when win = 0 then p.stake when p.pick = res then floor(p.stake::numeric * total / win)::int else 0 end;
    got := 0;
    update public.predictions set payout = pay where fixture_id = p_fixture and user_id = p.user_id;
    if pay > 0 then
      update public.profiles set coins = coins + pay where id = p.user_id;
      insert into public.coin_log (user_id, amount, label) values (p.user_id, pay, case when win = 0 then 'პროგნოზის დაბრუნება' else 'მოგება: ' || f.home || ' – ' || f.away end);
    end if;
    if p.pick = res then got := coalesce(private.earn(p.user_id, 'predict_win', 'fx:' || p_fixture), 0); end if;
    perform public.notify(p.user_id, null,
      case when p.pick = res then 'bet_won' when win = 0 and p.stake > 0 then 'bet_refund' else 'bet_lost' end,
      jsonb_build_object('fixture', p_fixture, 'match', f.home || ' – ' || f.away, 'score', p_home || ':' || p_away, 'coins', pay + got));
  end loop;
  update public.fixtures set status = 'finished', home_score = p_home, away_score = p_away where id = p_fixture;
end $$;

create or replace function public.admin_cancel_fixture(p_fixture bigint) returns void
language plpgsql security definer set search_path = '' as $$
declare f record; p record;
begin
  if not public.is_staff() then raise exception 'staff_only'; end if;
  select * into f from public.fixtures where id = p_fixture for update;
  if f.id is null or f.status <> 'upcoming' then raise exception 'not_pending'; end if;
  for p in select * from public.predictions where fixture_id = p_fixture loop
    update public.predictions set payout = p.stake where fixture_id = p_fixture and user_id = p.user_id;
    if p.stake > 0 then
      update public.profiles set coins = coins + p.stake where id = p.user_id;
      insert into public.coin_log (user_id, amount, label) values (p.user_id, p.stake, 'პროგნოზის დაბრუნება');
      perform public.notify(p.user_id, null, 'bet_refund', jsonb_build_object('fixture', p_fixture, 'match', f.home || ' – ' || f.away, 'coins', p.stake));
    end if;
  end loop;
  update public.fixtures set status = 'cancelled' where id = p_fixture;
end $$;

-- game styles: paid like everything else, the other coins first
create or replace function public.buy_item(p_item text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); price int; c int;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  price := case p_item when 'nardi:orn' then 300 when 'joker:geo' then 250 when 'chess:carved' then 200 when 'chess:modern' then 300 else null end;
  if price is null then raise exception 'bad_item'; end if;
  if exists (select 1 from public.game_items where user_id = me and item = p_item) then
    select coins into c from public.profiles where id = me; return jsonb_build_object('coins', c, 'owned', true);
  end if;
  select o_bal into c from private.spend(me, price, 'სტილი: ' || p_item);
  insert into public.game_items (user_id, item) values (me, p_item);
  return jsonb_build_object('coins', c, 'owned', true);
end $$;

-- 8. what the person sees -----------------------------------------------------------------------

-- my balance, today's coins by activity, and the promotion
create or replace function public.my_coins() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare me uuid := auth.uid(); v_day date := private.tday(); v_cfg jsonb := private.coin_cfg(); p record;
begin
  if me is null then raise exception 'not_signed_in'; end if;
  select coins, coins_cash, last_bonus, bonus_streak into p from public.profiles where id = me;
  return jsonb_build_object(
    'coins', coalesce(p.coins, 0), 'cash', coalesce(p.coins_cash, 0),
    'last_bonus', p.last_bonus, 'streak', coalesce(p.bonus_streak, 0), 'day', v_day,
    'promo', private.promo_on(), 'until', v_cfg -> 'until',
    'rate', coalesce((v_cfg ->> 'rate')::int, 10000), 'min_out', coalesce((v_cfg ->> 'min_out')::int, 10000),
    'daily_max', coalesce((v_cfg ->> 'daily_max')::int, 150),
    'today', (select coalesce(sum(e.amount), 0) from private.earn_events e join public.coin_rules r on r.action = e.action
              where e.user_id = me and e.day = v_day and not e.undone and r.in_max),
    'by', (select coalesce(jsonb_object_agg(action, n), '{}'::jsonb) from (
             select action, sum(amount) n from private.earn_events where user_id = me and day = v_day and not undone group by action) x),
    'done', (select coalesce(jsonb_agg(distinct e.action), '[]'::jsonb) from private.earn_events e join public.coin_rules r on r.action = e.action
             where e.user_id = me and r.once));
end $$;
revoke all on function public.my_coins() from public, anon;
grant execute on function public.my_coins() to authenticated;

-- 9. the admin's controls -----------------------------------------------------------------------

-- start (for p_months), add months, or stop the promotion
create or replace function public.admin_coin_promo(p_do text, p_months integer default 1) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v jsonb := private.coin_cfg(); v_until timestamptz;
begin
  if not public.is_admin() then raise exception 'admin_only'; end if;
  if p_do not in ('start', 'extend', 'stop') or coalesce(p_months, 1) not between 1 and 12 then raise exception 'bad_request'; end if;
  v_until := (v ->> 'until')::timestamptz;
  if p_do = 'start' then
    if private.promo_on() then raise exception 'already_on'; end if;
    v := v || jsonb_build_object('on', true, 'until', now() + make_interval(months => coalesce(p_months, 1)), 'started_at', now());
  elsif p_do = 'extend' then
    v := v || jsonb_build_object('on', true, 'until', greatest(coalesce(v_until, now()), now()) + make_interval(months => coalesce(p_months, 1)));
  else
    v := v || jsonb_build_object('on', false, 'until', least(coalesce(v_until, now()), now()));
  end if;
  insert into public.app_settings (key, value) values ('coins', v) on conflict (key) do update set value = excluded.value;
  return v || jsonb_build_object('promo', private.promo_on());
end $$;

-- change one activity's coins, its daily cap, or switch it off
create or replace function public.admin_coin_rule(p_action text, p_amount integer, p_day_cap integer, p_active boolean) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_admin() then raise exception 'admin_only'; end if;
  if p_amount is null or p_amount not between 0 and 1000 or p_day_cap is null or p_day_cap not between 0 and 5000 then raise exception 'bad_request'; end if;
  update public.coin_rules set amount = p_amount, day_cap = p_day_cap, active = coalesce(p_active, true) where action = p_action;
  if not found then raise exception 'not_found'; end if;
  perform private.admin_log('coin_rule', p_action, jsonb_build_object('amount', p_amount, 'day_cap', p_day_cap, 'active', p_active));
end $$;

-- the most anyone can earn from activity in a day
create or replace function public.admin_coin_max(p_max integer) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v jsonb := private.coin_cfg();
begin
  if not public.is_admin() then raise exception 'admin_only'; end if;
  if p_max is null or p_max not between 10 and 5000 then raise exception 'bad_request'; end if;
  v := v || jsonb_build_object('daily_max', p_max);
  insert into public.app_settings (key, value) values ('coins', v) on conflict (key) do update set value = excluded.value;
  return v;
end $$;

-- how much cash is out there (what would be owed in lari), and who earns most today
create or replace function public.admin_coin_stats() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v_day date := private.tday();
begin
  if not public.is_admin() then raise exception 'admin_only'; end if;
  return jsonb_build_object(
    'cfg', private.coin_cfg(), 'promo', private.promo_on(), 'day', v_day,
    'coins', (select coalesce(sum(coins), 0) from public.profiles),
    'cash', (select coalesce(sum(coins_cash), 0) from public.profiles),
    'today', (select coalesce(sum(amount), 0) from private.earn_events where day = v_day and not undone),
    'today_cash', (select coalesce(sum(cash), 0) from private.earn_events where day = v_day and not undone),
    'week_cash', (select coalesce(sum(cash), 0) from private.earn_events where day > v_day - 7 and not undone),
    'earners', (select count(distinct user_id) from private.earn_events where day = v_day and not undone),
    'top', (select coalesce(jsonb_agg(jsonb_build_object('u', x.user_id, 'n', x.n, 'c', x.c) order by x.n desc), '[]'::jsonb) from (
              select user_id, sum(amount) n, sum(cash) c from private.earn_events where day = v_day and not undone
              group by user_id order by 2 desc limit 10) x),
    'by', (select coalesce(jsonb_object_agg(action, n), '{}'::jsonb) from (
             select action, sum(amount) n from private.earn_events where day = v_day and not undone group by action) x));
end $$;

do $$
declare f text;
begin
  foreach f in array array['public.admin_coin_promo(text,integer)', 'public.admin_coin_rule(text,integer,integer,boolean)',
                           'public.admin_coin_max(integer)', 'public.admin_coin_stats()'] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $$;

-- 10. live coins on the phone, and tidying up ----------------------------------------------------

do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'coin_log') then
    alter publication supabase_realtime add table public.coin_log;
  end if;
end $$;

select cron.schedule('peera-coins-prune', '17 3 * * *', $$delete from private.earn_counts where day < current_date - 3$$);
