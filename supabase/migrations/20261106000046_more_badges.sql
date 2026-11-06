-- Peera: eleven more badges, from bronze to diamond. The hardest one earned shows next to the username.
create or replace function public.check_achievements()
 returns text[] language plpgsql security definer set search_path to '' as $function$
declare me uuid := auth.uid(); got text[] := '{}'; c record; ok boolean;
begin
  if me is null then return got; end if;
  for c in select * from (values ('post1',10,'პირველი პოსტი'),('story1',10,'პირველი ისტორია'),('friends10',20,'10 მეგობარი'),('grader',20,'შემფასებელი'),
      ('star',30,'ვარსკვლავი'),('host',20,'მასპინძელი'),('tamada',30,'წამყვანი'),('supra',15,'ოთახის გამხსნელი'),('nardi',30,'ნარდის ოსტატი'),
      ('helper',20,'კეთილი გული'),('cook',15,'კონსპექტის ავტორი'),('verified',10,'ვერიფიცირებული'),('album',10,'მემატიანე'),
      ('clip1',10,'პირველი კლიპი'),('class1',10,'კლასელი'),('starosta',25,'სტაროსტა'),('kin5',20,'ოჯახის ხე'),
      ('posts50',30,'ავტორი'),('friends50',30,'პოპულარული'),('likes100',30,'საყვარელი'),('notes10',30,'ფრიადოსანი'),('year1',40,'ერთი წელი'),
      ('master',60,'გროსმაისტერი'),('legend',100,'ლეგენდა')) v(code, coins, title) loop
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
      when 'clip1' then exists (select 1 from public.posts where author = me and is_clip and not draft and not hidden)
      when 'class1' then exists (select 1 from public.group_members m join public.groups g on g.id = m.group_id where m.user_id = me and g.kind in ('class', 'course'))
      when 'starosta' then exists (select 1 from public.group_members m join public.groups g on g.id = m.group_id where m.user_id = me and m.role = 'admin' and g.kind in ('class', 'course'))
      when 'kin5' then (select count(*) from public.kin where owner = me and (relative is null or status = 'accepted')) >= 5
      when 'posts50' then (select count(*) from public.posts where author = me and not draft and repost_of is null) >= 50
      when 'friends50' then (select count(*) from public.friendships where status = 'accepted' and (requester = me or addressee = me)) >= 50
      when 'likes100' then (select count(*) from public.reactions r join public.posts p on p.id = r.post_id where p.author = me and r.user_id <> me) >= 100
      when 'notes10' then (select count(*) from public.recipes where author = me) >= 10
      when 'year1' then coalesce((select created_at from public.profiles where id = me), now()) < now() - interval '1 year'
      when 'master' then coalesce((select max(rating) from public.game_ratings where user_id = me), 0) >= 1800
      when 'legend' then (select count(*) from public.achievements where user_id = me) >= 15
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
