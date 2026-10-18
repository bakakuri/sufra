revoke select on public.profiles from anon, authenticated;
grant select (id, username, name, bio, city, hue, avatar_url, cover_url, lang, privacy, dating, gender, seeking, dating_bio, interests, is_business, verified, role, banned, rating, last_seen, onboarded, created_at) on public.profiles to authenticated;

create or replace function public.my_profile() returns jsonb language sql stable security definer set search_path = '' as $$
  select to_jsonb(p) from public.profiles p where p.id = auth.uid();
$$;

create or replace function public.friend_birthdays() returns table (id uuid, name text, hue int, avatar_url text, month int, day int)
language sql stable security definer set search_path = '' as $$
  select p.id, p.name, p.hue, p.avatar_url, extract(month from p.birthday)::int, extract(day from p.birthday)::int
  from public.profiles p
  where p.birthday is not null and p.id <> auth.uid() and public.are_friends(auth.uid(), p.id);
$$;

create or replace function public.dating_feed(p_limit int default 20) returns table (id uuid, name text, age int, city text, hue int, avatar_url text, dating_bio text, interests text[], verified boolean, gender text, liked_me boolean)
language sql stable security definer set search_path = '' as $$
  with me as (select * from public.profiles where id = auth.uid())
  select p.id, p.name, extract(year from age(p.birthday))::int, p.city, p.hue, p.avatar_url, p.dating_bio, p.interests, p.verified, p.gender,
         exists(select 1 from public.swipes s where s.swiper = p.id and s.target = auth.uid() and s.kind in ('like','super'))
  from public.profiles p, me
  where public.is_adult(auth.uid()) and me.dating and p.dating and p.id <> me.id and not p.banned and public.is_adult(p.id)
    and not exists(select 1 from public.swipes s where s.swiper = me.id and s.target = p.id)
    and not public.is_blocked(me.id, p.id)
    and (me.seeking is null or me.seeking = 'all' or p.gender = me.seeking)
    and (p.seeking is null or p.seeking = 'all' or me.gender = p.seeking)
  order by (p.city = me.city) desc, random()
  limit least(greatest(p_limit, 1), 50);
$$;

create or replace function public.feed_stats(p_ids bigint[]) returns table (post_id bigint, reactions jsonb, my_reaction text, comments int, grade_avg numeric, grade_n int, my_grade text, votes jsonb, my_vote int, saved boolean)
language sql stable security invoker set search_path = '' as $$
  select p.id,
    coalesce((select jsonb_object_agg(x.emoji, x.n) from (select r.emoji, count(*) as n from public.reactions r where r.post_id = p.id group by r.emoji) x), '{}'::jsonb),
    (select r.emoji from public.reactions r where r.post_id = p.id and r.user_id = auth.uid()),
    (select count(*)::int from public.comments c where c.post_id = p.id),
    (select round(avg(case when g.grade = '5+' then 6 else g.grade::int end)::numeric, 1) from public.post_grades g where g.post_id = p.id),
    (select count(*)::int from public.post_grades g where g.post_id = p.id),
    (select g.grade from public.post_grades g where g.post_id = p.id and g.user_id = auth.uid()),
    coalesce((select jsonb_object_agg(y.opt::text, y.n) from (select v.opt, count(*) as n from public.poll_votes v where v.post_id = p.id group by v.opt) y), '{}'::jsonb),
    (select v.opt::int from public.poll_votes v where v.post_id = p.id and v.user_id = auth.uid()),
    exists(select 1 from public.saves s where s.post_id = p.id and s.user_id = auth.uid())
  from unnest(p_ids) as u(id) join public.posts p on p.id = u.id;
$$;

create or replace function public.my_conversations() returns table (conv_id bigint, is_group boolean, title text, last_message_at timestamptz, last_body text, last_kind text, last_sender uuid, unread int, members uuid[])
language sql stable security invoker set search_path = '' as $$
  select c.id, c.is_group, c.title, c.last_message_at, lm.body, lm.kind, lm.sender,
    (select count(*)::int from public.messages m where m.conv_id = c.id and m.created_at > cm.last_read_at and m.sender is distinct from auth.uid()),
    (select array_agg(x.user_id) from public.conversation_members x where x.conv_id = c.id and x.user_id <> auth.uid())
  from public.conversation_members cm
  join public.conversations c on c.id = cm.conv_id
  left join lateral (select m.body, m.kind, m.sender from public.messages m where m.conv_id = c.id order by m.created_at desc limit 1) lm on true
  where cm.user_id = auth.uid()
  order by c.last_message_at desc
  limit 100;
$$;


do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as sig, p.proname
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname in (
      'ad_impression','add_to_group_chat','admin_ban','admin_hide','admin_resolve_report','admin_review_ad','admin_set_role','admin_stats','admin_unverify','admin_verify','admin_verify_page',
      'are_friends','can_post','complete_onboarding','create_ad','create_group_chat','daily_bonus','friend_suggestions','game_result','group_visible',
      'is_admin','is_adult','is_blocked','is_group_member','is_member','is_staff','likes_me_count','mutual_friends','owns_page','send_gift','start_dm','swipe','trending_tags','vapid_public_key','gift_cost','post_tags',
      'my_profile','friend_birthdays','dating_feed','feed_stats','my_conversations')
  loop
    execute format('revoke execute on function %s from public, anon', f.sig);
    if f.proname <> 'post_tags' then
      execute format('grant execute on function %s to authenticated', f.sig);
    end if;
  end loop;
end $$;
alter default privileges in schema public revoke execute on functions from public, anon;
