-- Groups by what they are about, the groups page in one look (FB-like: mine, suggested for me, popular, by category),
-- and "for you" as a mix from everywhere: friends' and public posts, groups (mine and open ones), pages, shared albums
-- and the coming matches, in a random order leaning to what is near me and fresh. "ახალი" stays newest first.

-- ============ 1. a group's category ============
alter table public.groups add column if not exists category text not null default 'other'
  check (category in ('edu', 'place', 'hobby', 'sport', 'food', 'travel', 'tech', 'family', 'work', 'market', 'fun', 'health', 'faith', 'other'));
update public.groups set category = case when kind in ('school', 'class', 'uni', 'course') then 'edu' when kind in ('place', 'diaspora', 'surname') then 'place' else category end
  where category = 'other';
grant insert (category), update (category) on public.groups to authenticated;
create index if not exists groups_category_idx on public.groups (category);

-- ============ 2. the groups page in one look ============
-- every group with its members, last fortnight's posts, my friends in it (up to three named), whether it is mine,
-- how popular it is and how well it fits me (friends in it, the categories of my groups, its size and life, my town)
create or replace function public.group_cards() returns jsonb language sql stable security definer set search_path = '' as $$
  with me as (select auth.uid() as id),
  fr as (
    select case when f.requester = (select id from me) then f.addressee else f.requester end as uid
    from public.friendships f where f.status = 'accepted' and (select id from me) in (f.requester, f.addressee)),
  mine as (select m.group_id from public.group_members m where m.user_id = (select id from me)),
  mycats as (select distinct g.category from public.groups g where (g.id in (select group_id from mine) or g.owner = (select id from me)) and g.category <> 'other'),
  town as (select nullif(btrim(p.home_place), '') as place, nullif(btrim(p.city), '') as city from public.profiles p where p.id = (select id from me)),
  st as (
    select g.id,
      (select count(*) from public.group_members m where m.group_id = g.id)::int as members,
      (select count(*) from public.posts p where p.group_id = g.id and not p.hidden and not p.draft and not p.pending and p.created_at > now() - interval '14 days')::int as posts14,
      (select max(p.created_at) from public.posts p where p.group_id = g.id and not p.hidden and not p.draft and not p.pending) as last_post,
      (select count(*) from public.group_members m where m.group_id = g.id and m.user_id in (select uid from fr))::int as friends,
      (select coalesce(jsonb_agg(x.user_id), '[]') from (select m.user_id from public.group_members m where m.group_id = g.id and m.user_id in (select uid from fr) limit 3) x) as friend_ids
    from public.groups g)
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', g.id, 'name', g.name, 'hue', g.hue, 'avatar_url', g.avatar_url, 'cover_url', g.cover_url, 'is_private', g.is_private,
      'join_mode', g.join_mode, 'category', g.category, 'kind', g.kind, 'description', left(coalesce(g.description, ''), 140), 'owner', g.owner,
      'members', st.members, 'posts14', st.posts14, 'last_post', st.last_post, 'friends', st.friends, 'friend_ids', st.friend_ids,
      'mine', (g.id in (select group_id from mine) or g.owner = (select id from me)),
      'pop', round((ln(1 + st.members) + 1.5 * ln(1 + st.posts14))::numeric, 3),
      'fit', round((3 * st.friends
        + case when g.category in (select category from mycats) then 2 else 0 end
        + ln(1 + st.members) + ln(1 + st.posts14)
        + case when exists (select 1 from town t where (t.place is not null and strpos(lower(g.name), lower(t.place)) > 0) or (t.city is not null and strpos(lower(g.name), lower(t.city)) > 0)) then 1.5 else 0 end
      )::numeric, 3)
    ) order by g.created_at desc), '[]')
  from public.groups g join st on st.id = g.id
  where not public.is_blocked(g.owner, (select id from me));
$$;
revoke execute on function public.group_cards() from public, anon;
grant execute on function public.group_cards() to authenticated;

-- ============ 3. "for you": a mix from everywhere ============
-- p_seen holds what this scroll already showed ('p:12' a post, 'a:3' an album, 'm:9' a match). The posts come in a
-- random order weighted by who and what they are (a friend's, a followed topic, my group's, a followed page's) and
-- how fresh; up to one shared album with new photos and one coming or live match ride along. It runs as the person
-- (security invoker): what they may not see stays out by the tables' own rules.
create or replace function public.feed_mix(p_seen text[] default '{}', p_limit int default 15) returns jsonb
language sql volatile set search_path = '' as $$
  with me as (select auth.uid() as id),
  fr as (
    select case when f.requester = (select id from me) then f.addressee else f.requester end as uid
    from public.friendships f where f.status = 'accepted' and (select id from me) in (f.requester, f.addressee)),
  tg as (select coalesce(array_agg(t.tag), '{}') as tags from public.tag_follows t where t.user_id = (select id from me)),
  mg as (select m.group_id from public.group_members m where m.user_id = (select id from me)),
  pf as (select f.page_id from public.page_follows f where f.user_id = (select id from me)),
  cand as (
    select p.id, p.author, p.group_id, p.page_id, p.tags, p.created_at
    from public.posts p
    where not p.hidden and not p.draft and not p.pending and p.created_at <= now() and p.created_at > now() - interval '180 days'
      and not (('p:' || p.id) = any (coalesce(p_seen, '{}')))
      and (p.repost_of is null or coalesce(p.body, '') <> '')
      and (p.group_id is null or p.group_id in (select group_id from mg)
           or exists (select 1 from public.groups g where g.id = p.group_id and not g.is_private))
    order by p.created_at desc
    limit 800),
  wp as (
    select c.id,
      -ln(greatest(random(), 1e-9)) / (
        (1 + 2.0 * (c.author in (select uid from fr))::int
           + 1.5 * (coalesce(c.tags && (select tags from tg), false))::int
           + 1.2 * (c.group_id is not null and c.group_id in (select group_id from mg))::int
           + 1.2 * (c.page_id is not null and c.page_id in (select page_id from pf))::int)
        * (case when c.author = (select id from me) then 0.35 else 1 end)
        * (0.2 + exp(-extract(epoch from now() - c.created_at) / 86400.0 / 10))
      ) as k
    from cand c),
  ps as (select id, k from wp order by k limit least(greatest(coalesce(p_limit, 15), 1), 40)),
  al as (
    select a.id from public.albums a
    where a.photos > 0 and a.updated_at > now() - interval '60 days' and a.owner <> (select id from me)
      and not (('a:' || a.id) = any (coalesce(p_seen, '{}')))
    order by -ln(greatest(random(), 1e-9)) / (0.2 + exp(-extract(epoch from now() - a.updated_at) / 86400.0 / 7)) limit 1),
  mt as (
    select f.id from public.fixtures f
    where f.status = 'upcoming' and f.starts_at between now() - interval '2 hours' and now() + interval '4 days'
      and coalesce(f.live_state, 'scheduled') not in ('finished', 'postponed', 'cancelled')
      and not (('m:' || f.id) = any (coalesce(p_seen, '{}')))
    order by -ln(greatest(random(), 1e-9)) / (0.3 + exp(-abs(extract(epoch from f.starts_at - now())) / 3600.0 / 24)) limit 1)
  select jsonb_build_object(
    'p', coalesce((select jsonb_agg(id order by k) from ps), '[]'),
    'a', coalesce((select jsonb_agg(id) from al), '[]'),
    'm', coalesce((select jsonb_agg(id) from mt), '[]'));
$$;
revoke execute on function public.feed_mix(text[], int) from public, anon;
grant execute on function public.feed_mix(text[], int) to authenticated;
