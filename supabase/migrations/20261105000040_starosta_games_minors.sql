-- Peera: a class or course group chooses its own starosta (up to two, they moderate the group like its admins);
-- and in games an adult and someone under 18 who do not know each other neither talk nor challenge each other.

-- ============ starosta ============
-- any member of a class or course group, signed up at least three days ago, while the group has fewer than two
create or replace function public.claim_starosta(p_group bigint) returns void language plpgsql security definer set search_path = '' as $$
declare me uuid := auth.uid(); k text; n int;
begin
  if me is null or not public.can_post() then raise exception 'not_allowed'; end if;
  select kind into k from public.groups where id = p_group;
  if k is null or k not in ('class', 'course') then raise exception 'not_allowed'; end if;
  if not exists (select 1 from public.group_members where group_id = p_group and user_id = me) then raise exception 'not_member'; end if;
  if exists (select 1 from public.group_members where group_id = p_group and user_id = me and role = 'admin') then return; end if;
  if exists (select 1 from public.profiles where id = me and created_at > now() - interval '3 days') then raise exception 'too_new'; end if;
  perform 1 from public.groups where id = p_group for update;
  select count(*) into n from public.group_members where group_id = p_group and role = 'admin';
  if n >= 2 then raise exception 'starosta_full'; end if;
  update public.group_members set role = 'admin' where group_id = p_group and user_id = me;
end $$;

create or replace function public.leave_starosta(p_group bigint) returns void language plpgsql security definer set search_path = '' as $$
begin
  update public.group_members m set role = 'member'
  from public.groups g
  where m.group_id = p_group and m.user_id = auth.uid() and m.role = 'admin' and g.id = m.group_id and g.kind in ('class', 'course');
end $$;
revoke execute on function public.claim_starosta(bigint) from public, anon;
revoke execute on function public.leave_starosta(bigint) from public, anon;
grant execute on function public.claim_starosta(bigint) to authenticated;
grant execute on function public.leave_starosta(bigint) to authenticated;

-- ============ games: who may talk to and challenge whom ============
-- the stricter check of chats and gifts (friends, family tree, same class or course; or both of the same age group)
create or replace function public.reachable_talk(p_ids uuid[]) returns uuid[] language sql stable security definer set search_path = '' as $$
  select coalesce(array_agg(x), '{}') from unnest(coalesce(p_ids, '{}')) x where public.may_reach(auth.uid(), x);
$$;
revoke execute on function public.reachable_talk(uuid[]) from public, anon;
grant execute on function public.reachable_talk(uuid[]) to authenticated;
