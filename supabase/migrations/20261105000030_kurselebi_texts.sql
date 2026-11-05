-- the names of badges and the default note of a coin gift, in the words of კურსელები
-- (the old texts already in the tables — banner, broadcasts, notifications, coin log, promo brand,
-- the site's channel, group and meeting, and one welcome post — were rewritten once by hand)
CREATE OR REPLACE FUNCTION public.check_achievements()
 RETURNS text[]
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare me uuid := auth.uid(); got text[] := '{}'; c record; ok boolean;
begin
  if me is null then return got; end if;
  for c in select * from (values ('post1',10,'პირველი პოსტი'),('story1',10,'პირველი ისტორია'),('friends10',20,'10 მეგობარი'),('grader',20,'შემფასებელი'),
      ('star',30,'ვარსკვლავი'),('host',20,'მასპინძელი'),('tamada',30,'წამყვანი'),('supra',15,'ოთახის გამხსნელი'),('nardi',30,'ნარდის ოსტატი'),
      ('helper',20,'კეთილი გული'),('cook',15,'კონსპექტის ავტორი'),('verified',10,'ვერიფიცირებული'),('album',10,'მემატიანე')) v(code, coins, title) loop
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

CREATE OR REPLACE FUNCTION public.admin_coins(p_user uuid, p_amount integer, p_note text DEFAULT NULL::text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare c int; note text := left(coalesce(nullif(trim(p_note), ''), case when p_amount > 0 then 'კურსელების საჩუქარი' else 'ადმინისტრაციის კორექცია' end), 80);
begin
  if not public.is_admin() then raise exception 'admin_only'; end if;
  if p_amount is null or p_amount = 0 or abs(p_amount) > 100000 then raise exception 'bad_request'; end if;
  update public.profiles set coins = greatest(0, coins + p_amount) where id = p_user returning coins into c;
  if c is null then raise exception 'not_found'; end if;
  insert into public.coin_log (user_id, amount, label) values (p_user, p_amount, note);
  insert into public.notifications (user_id, actor, kind, ref) values (p_user, null, 'admin_coins', jsonb_build_object('coins', p_amount, 'note', note));
  perform private.admin_log('coins', p_user::text, jsonb_build_object('amount', p_amount, 'note', note));
  return c;
end $function$;
