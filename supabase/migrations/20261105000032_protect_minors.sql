-- კურსელები: school pupils are here too. An adult and a person under 18 who do not know each other
-- cannot start a chat, add each other to a group chat, send a gift or a friend request, and do not
-- come up for each other in suggestions or people search. "Know each other" means friends, the family
-- tree, or the same class or course group; for a friend request two mutual friends are enough as well.
-- Someone without a birthday counts as an adult here.

create or replace function public.is_minor(u uuid) returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.profiles where id = u and birthday is not null and birthday > (current_date - interval '18 years')::date);
$$;

create or replace function public.knows(a uuid, b uuid) returns boolean language sql stable security definer set search_path = '' as $$
  select public.are_friends(a, b)
      or exists (select 1 from public.kin where status = 'accepted' and ((owner = a and relative = b) or (owner = b and relative = a)))
      or exists (select 1 from public.group_members m1
                 join public.group_members m2 on m2.group_id = m1.group_id and m2.user_id = b
                 join public.groups g on g.id = m1.group_id and g.kind in ('class', 'course')
                 where m1.user_id = a);
$$;

create or replace function public.common_friends(a uuid, b uuid) returns integer language sql stable security definer set search_path = '' as $$
  with fa as (select case when requester = a then addressee else requester end f from public.friendships where status = 'accepted' and a in (requester, addressee)),
       fb as (select case when requester = b then addressee else requester end f from public.friendships where status = 'accepted' and b in (requester, addressee))
  select count(*)::int from fa join fb using (f);
$$;

-- a chat, a group chat, a gift
create or replace function public.may_reach(a uuid, b uuid) returns boolean language sql stable security definer set search_path = '' as $$
  select a = b or public.is_minor(a) = public.is_minor(b) or public.knows(a, b);
$$;
-- a friend request, a suggestion, a search result
create or replace function public.may_befriend(a uuid, b uuid) returns boolean language sql stable security definer set search_path = '' as $$
  select a = b or public.is_minor(a) = public.is_minor(b) or public.knows(a, b) or public.common_friends(a, b) >= 2;
$$;

-- only the functions below use these; nobody calls them directly
revoke execute on function public.common_friends(uuid, uuid) from public, anon, authenticated;
revoke execute on function public.knows(uuid, uuid) from public, anon, authenticated;
revoke execute on function public.may_reach(uuid, uuid) from public, anon, authenticated;
revoke execute on function public.may_befriend(uuid, uuid) from public, anon, authenticated;
revoke execute on function public.is_minor(uuid) from public, anon, authenticated;

-- who of these people the viewer may find (people search, profile buttons)
create or replace function public.reachable(p_ids uuid[]) returns uuid[] language sql stable security definer set search_path = '' as $$
  select coalesce(array_agg(x), '{}') from unnest(coalesce(p_ids, '{}')) x where public.may_befriend(auth.uid(), x);
$$;
revoke execute on function public.reachable(uuid[]) from public, anon;
grant execute on function public.reachable(uuid[]) to authenticated;

-- ============ chats ============
create or replace function public.start_dm(other uuid)
 returns bigint language plpgsql security definer set search_path = '' as $function$
declare c bigint; pr jsonb;
begin
  if auth.uid() is null or other = auth.uid() then raise exception 'bad_request'; end if;
  if not public.can_post() then raise exception 'not_allowed'; end if;
  if public.is_blocked(auth.uid(), other) then raise exception 'blocked'; end if;
  select c1.conv_id into c from public.conversation_members c1
    join public.conversation_members c2 on c2.conv_id = c1.conv_id and c2.user_id = other
    join public.conversations cv on cv.id = c1.conv_id and not cv.is_group
    where c1.user_id = auth.uid() limit 1;
  if c is not null then return c; end if;
  if not public.may_reach(auth.uid(), other) then raise exception 'minor_protected'; end if;
  select privacy into pr from public.profiles where id = other;
  if coalesce(pr->>'dm','all') = 'friends' and not public.are_friends(auth.uid(), other) then raise exception 'dm_friends_only'; end if;
  insert into public.conversations (is_group, created_by) values (false, auth.uid()) returning id into c;
  insert into public.conversation_members (conv_id, user_id) values (c, auth.uid()), (c, other);
  return c;
end $function$;

create or replace function public.create_group_chat(p_title text, p_members uuid[])
 returns bigint language plpgsql security definer set search_path = '' as $function$
declare c bigint; m uuid;
begin
  if not public.can_post() then raise exception 'not_allowed'; end if;
  if coalesce(array_length(p_members, 1), 0) < 1 or array_length(p_members, 1) > 49 then raise exception 'bad_members'; end if;
  insert into public.conversations (is_group, title, created_by) values (true, left(coalesce(nullif(trim(p_title), ''), 'ჯგუფი'), 80), auth.uid()) returning id into c;
  insert into public.conversation_members (conv_id, user_id) values (c, auth.uid());
  foreach m in array p_members loop
    if m <> auth.uid() and not public.is_blocked(auth.uid(), m) and public.may_reach(auth.uid(), m) and exists(select 1 from public.profiles where id = m) then
      insert into public.conversation_members (conv_id, user_id) values (c, m) on conflict do nothing;
    end if;
  end loop;
  insert into public.messages (conv_id, sender, body, kind) values (c, auth.uid(), 'ჯგუფი შეიქმნა', 'system');
  return c;
end $function$;

create or replace function public.add_to_group_chat(c bigint, p_members uuid[])
 returns void language plpgsql security definer set search_path = '' as $function$
declare m uuid;
begin
  if not public.is_member(c) or not exists(select 1 from public.conversations where id = c and is_group) then raise exception 'not_allowed'; end if;
  foreach m in array p_members loop
    if not public.is_blocked(auth.uid(), m) and public.may_reach(auth.uid(), m) and exists(select 1 from public.profiles where id = m) then
      insert into public.conversation_members (conv_id, user_id) values (c, m) on conflict do nothing;
    end if;
  end loop;
end $function$;

-- ============ gifts ============
create or replace function public.send_gift(p_to uuid, p_emoji text)
 returns integer language plpgsql security definer set search_path = '' as $function$
declare cost int := public.gift_cost(p_emoji); bal int;
begin
  if cost is null then raise exception 'bad_gift'; end if;
  if p_to = auth.uid() or public.is_blocked(auth.uid(), p_to) then raise exception 'not_allowed'; end if;
  if not public.may_reach(auth.uid(), p_to) then raise exception 'minor_protected'; end if;
  bal := public.spend_coins(cost, 'საჩუქარი');
  insert into public.gifts (sender, recipient, emoji, cost) values (auth.uid(), p_to, p_emoji, cost);
  perform public.notify(p_to, auth.uid(), 'gift', jsonb_build_object('emoji', p_emoji));
  return bal;
end $function$;

-- ============ friend requests ============
create or replace function public.trg_friend_minor() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if not public.may_befriend(new.requester, new.addressee) then raise exception 'minor_protected'; end if;
  return new;
end $$;
create trigger friendships_minor before insert on public.friendships for each row execute function public.trg_friend_minor();

-- ============ suggestions ============
create or replace function public.friend_suggestions(p_limit integer default 12)
 returns table(id uuid, name text, city text, hue integer, avatar_url text, verified boolean, mutual integer)
 language sql stable security definer set search_path = '' as $function$
  with my_friends as (select case when requester = auth.uid() then addressee else requester end as f from public.friendships where status = 'accepted' and auth.uid() in (requester, addressee)),
  related as (select case when f2.requester = mf.f then f2.addressee else f2.requester end as cand from my_friends mf join public.friendships f2 on f2.status = 'accepted' and mf.f in (f2.requester, f2.addressee))
  select p.id, p.name, p.city, p.hue, p.avatar_url, p.verified, coalesce((select count(*) from related r where r.cand = p.id), 0)::int as mutual
  from public.profiles p
  where p.id <> auth.uid() and p.onboarded and not p.banned
    and not exists(select 1 from public.friendships f where (f.requester = p.id and f.addressee = auth.uid()) or (f.addressee = p.id and f.requester = auth.uid()))
    and not public.is_blocked(p.id, auth.uid())
    and public.may_befriend(auth.uid(), p.id)
  order by mutual desc, (p.city = (select city from public.profiles where id = auth.uid())) desc, p.created_at desc
  limit least(greatest(p_limit, 1), 50);
$function$;
