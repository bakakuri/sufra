-- the site is called Peera: the default note of an admin coin gift
-- (banner, promo brand, the site's channel, group and meeting, broadcasts, notifications and coin log were rewritten once by hand)
CREATE OR REPLACE FUNCTION public.admin_coins(p_user uuid, p_amount integer, p_note text DEFAULT NULL::text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare c int; note text := left(coalesce(nullif(trim(p_note), ''), case when p_amount > 0 then 'Peera-ს საჩუქარი' else 'ადმინისტრაციის კორექცია' end), 80);
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
