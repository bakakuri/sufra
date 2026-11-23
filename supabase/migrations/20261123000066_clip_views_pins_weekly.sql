-- Peera 66: who watched a clip (one view per person) and the clips most watched this week; one post pinned on top of
-- one's own profile; and on Monday morning a short summary of the week as a notification.

-- ---------- clip views ----------
create table if not exists public.clip_views (
  post_id bigint not null references public.posts (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  at timestamptz not null default now(),
  primary key (post_id, user_id)
);
create index if not exists clip_views_at_idx on public.clip_views (at);
create index if not exists clip_views_user_idx on public.clip_views (user_id, at desc);
alter table public.clip_views enable row level security;
-- what I watched (the "watched" mark on the clips); a view of a clip I can see, as myself
create policy "my clip views" on public.clip_views for select to authenticated using (user_id = (select auth.uid()));
create policy "add my clip view" on public.clip_views for insert to authenticated
  with check (user_id = (select auth.uid()) and exists (select 1 from public.posts p where p.id = post_id and p.is_clip));
grant select, insert on public.clip_views to authenticated;

-- counted once per person, as myself (the insert policy checks I can see that clip)
create or replace function public.clip_view(p_post bigint)
returns void language sql security invoker set search_path = '' as $$
  insert into public.clip_views (post_id, user_id) values (p_post, (select auth.uid())) on conflict do nothing;
$$;

-- how many people watched each of these clips: {id: n}
create or replace function public.clip_counts(p_ids bigint[])
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_object_agg(x.post_id::text, x.n), '{}'::jsonb)
  from (
    select v.post_id, count(*)::int as n from public.clip_views v
    join public.posts p on p.id = v.post_id and p.is_clip
    where v.post_id = any (coalesce(p_ids, '{}')) group by v.post_id
  ) x;
$$;

-- the clips most watched in the last seven days, most first (the posts themselves come through the posts' own rules)
create or replace function public.trending_clips(p_limit int default 30)
returns bigint[] language sql stable security definer set search_path = '' as $$
  select coalesce(array_agg(x.post_id order by x.n desc, x.post_id desc), '{}')
  from (
    select v.post_id, count(*) as n from public.clip_views v
    join public.posts p on p.id = v.post_id and p.is_clip and not p.hidden and not p.draft
    where v.at > now() - interval '7 days'
    group by v.post_id order by count(*) desc, v.post_id desc limit least(greatest(coalesce(p_limit, 30), 1), 60)
  ) x;
$$;

revoke all on function public.clip_view(bigint), public.clip_counts(bigint[]), public.trending_clips(int) from public, anon;
grant execute on function public.clip_view(bigint), public.clip_counts(bigint[]), public.trending_clips(int) to authenticated;

-- ---------- a pinned post on the profile ----------
alter table public.profiles add column if not exists pinned_post bigint references public.posts (id) on delete set null;
grant select (pinned_post) on public.profiles to authenticated;

-- one of my own posts on my own wall (not in a group or of a page); null takes it down
create or replace function public.pin_post(p_post bigint)
returns void language plpgsql security definer set search_path = '' as $$
declare me uuid := (select auth.uid());
begin
  if me is null then raise exception 'not signed in'; end if;
  if p_post is not null and not exists (
    select 1 from public.posts p where p.id = p_post and p.author = me and p.group_id is null and p.page_id is null and not p.draft
  ) then
    raise exception 'only your own post can be pinned';
  end if;
  update public.profiles set pinned_post = p_post where id = me;
end $$;
revoke all on function public.pin_post(bigint) from public, anon;
grant execute on function public.pin_post(bigint) to authenticated;

-- ---------- the week, on Monday ----------
create or replace function public.notif_category(k text)
returns text language sql immutable set search_path = '' as $$
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
    when k = 'weekly' then 'weekly'
    when k like 'bet\_%' then 'sport'
    when k like 'ride\_%' or k like 'job\_%' then 'deals'
    when k like 'group\_%' then 'groups'
    when k like 'page\_%' then 'pages'
    when k like 'event\_%' or k like 'album\_%' then 'events'
    else 'system' end;
$$;

-- the last seven days for each person: likes and comments others gave their posts, new friends, who looked at the
-- profile, who watched their clips, how many posts they wrote; sent only when something happened, once a week
create or replace function private.weekly_summary()
returns integer language plpgsql security definer set search_path = '' as $$
declare wk text := to_char(date_trunc('week', (now() at time zone 'Asia/Tbilisi')), 'YYYY-MM-DD'); since timestamptz := now() - interval '7 days'; n int;
begin
  insert into public.notifications (user_id, actor, kind, ref)
  select s.id, null, 'weekly', jsonb_build_object('likes', s.likes, 'comments', s.comments, 'friends', s.friends, 'visits', s.visits, 'views', s.views, 'posts', s.posts, 'week', wk)
  from (
    select p.id,
      (select count(*) from public.reactions r join public.posts x on x.id = r.post_id where x.author = p.id and r.user_id <> p.id and r.created_at > since)::int as likes,
      (select count(*) from public.comments c join public.posts x on x.id = c.post_id where x.author = p.id and c.author <> p.id and not c.hidden and c.created_at > since)::int as comments,
      (select count(*) from public.friendships f where f.status = 'accepted' and (f.requester = p.id or f.addressee = p.id) and f.created_at > since)::int as friends,
      (select count(distinct v.visitor) from public.profile_visits v where v.visited = p.id and v.visitor <> p.id and v.visited_at > since)::int as visits,
      (select count(*) from public.clip_views w join public.posts x on x.id = w.post_id where x.author = p.id and w.user_id <> p.id and w.at > since)::int as views,
      (select count(*) from public.posts x where x.author = p.id and not x.draft and x.created_at > since)::int as posts
    from public.profiles p
    where p.onboarded and not p.banned and not public.notif_off(p.id, 'weekly')
      and not exists (select 1 from public.notifications o where o.user_id = p.id and o.kind = 'weekly' and o.ref ->> 'week' = wk)
  ) s
  where s.likes + s.comments + s.friends + s.visits + s.views > 0;
  get diagnostics n = row_count;
  return n;
end $$;
revoke all on function private.weekly_summary() from public, anon, authenticated;

-- Monday 10:00 in Tbilisi
select cron.schedule('peera-weekly', '0 6 * * 1', 'select private.weekly_summary()');
