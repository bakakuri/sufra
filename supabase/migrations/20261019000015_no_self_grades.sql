-- people cannot grade their own photos; old self-grades no longer count
create or replace function public.is_post_author(p bigint) returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.posts where id = p and author = auth.uid());
$$;
revoke execute on function public.is_post_author(bigint) from public, anon;
grant execute on function public.is_post_author(bigint) to authenticated;
alter policy "grade" on public.post_grades with check (user_id = (select auth.uid()) and public.can_post() and not public.is_post_author(post_id));
alter policy "regrade" on public.post_grades using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()) and not public.is_post_author(post_id));

create or replace function public.feed_stats(p_ids bigint[]) returns table (post_id bigint, reactions jsonb, my_reaction text, comments int, grade_avg numeric, grade_n int, my_grade text, votes jsonb, my_vote int, saved boolean)
language sql stable security invoker set search_path = '' as $$
  select p.id,
    coalesce((select jsonb_object_agg(x.emoji, x.n) from (select r.emoji, count(*) as n from public.reactions r where r.post_id = p.id group by r.emoji) x), '{}'::jsonb),
    (select r.emoji from public.reactions r where r.post_id = p.id and r.user_id = auth.uid()),
    (select count(*)::int from public.comments c where c.post_id = p.id),
    (select round(avg(case when g.grade = '5+' then 6 else g.grade::int end)::numeric, 1) from public.post_grades g where g.post_id = p.id and g.user_id <> p.author),
    (select count(*)::int from public.post_grades g where g.post_id = p.id and g.user_id <> p.author),
    (select g.grade from public.post_grades g where g.post_id = p.id and g.user_id = auth.uid() and g.user_id <> p.author),
    coalesce((select jsonb_object_agg(y.opt::text, y.n) from (select v.opt, count(*) as n from public.poll_votes v where v.post_id = p.id group by v.opt) y), '{}'::jsonb),
    (select v.opt::int from public.poll_votes v where v.post_id = p.id and v.user_id = auth.uid()),
    exists(select 1 from public.saves s where s.post_id = p.id and s.user_id = auth.uid())
  from unnest(p_ids) as u(id) join public.posts p on p.id = u.id;
$$;
