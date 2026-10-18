create or replace function public.admin_hide(p_type text, p_id bigint, p_hidden boolean) returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_staff() then raise exception 'staff_only'; end if;
  if p_type = 'post' then update public.posts set hidden = p_hidden where id = p_id;
  elsif p_type = 'comment' then update public.comments set hidden = p_hidden where id = p_id;
  elsif p_type = 'listing' then update public.listings set hidden = p_hidden where id = p_id;
  else raise exception 'bad_type'; end if;
end $$;
create or replace function public.admin_ban(p_user uuid, p_banned boolean) returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_staff() then raise exception 'staff_only'; end if;
  if exists(select 1 from public.profiles where id = p_user and role = 'admin') then raise exception 'cannot_ban_admin'; end if;
  update public.profiles set banned = p_banned where id = p_user;
end $$;
create or replace function public.admin_resolve_report(p_id bigint, p_status text) returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_staff() then raise exception 'staff_only'; end if;
  if p_status not in ('resolved','dismissed','open') then raise exception 'bad_status'; end if;
  update public.reports set status = p_status, resolved_by = auth.uid() where id = p_id;
end $$;
create or replace function public.admin_verify(p_req bigint, p_approve boolean) returns void language plpgsql security definer set search_path = '' as $$
declare u uuid;
begin
  if not public.is_staff() then raise exception 'staff_only'; end if;
  update public.verification_requests set status = case when p_approve then 'approved' else 'rejected' end, reviewed_by = auth.uid() where id = p_req returning user_id into u;
  if u is null then raise exception 'not_found'; end if;
  if p_approve then update public.profiles set verified = true where id = u; end if;
  perform public.notify(u, auth.uid(), case when p_approve then 'verified' else 'verify_rejected' end, '{}');
end $$;
create or replace function public.admin_unverify(p_user uuid) returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_staff() then raise exception 'staff_only'; end if;
  update public.profiles set verified = false where id = p_user;
end $$;
create or replace function public.admin_review_ad(p_ad bigint, p_approve boolean) returns void language plpgsql security definer set search_path = '' as $$
declare a record; owner_id uuid;
begin
  if not public.is_staff() then raise exception 'staff_only'; end if;
  select * into a from public.ads where id = p_ad and status = 'pending';
  if a is null then raise exception 'not_pending'; end if;
  select owner into owner_id from public.pages where id = a.page_id;
  if p_approve then
    update public.ads set status = 'active' where id = p_ad;
  else
    update public.ads set status = 'rejected' where id = p_ad;
    update public.profiles set coins = coins + a.budget where id = owner_id;
    insert into public.coin_log (user_id, amount, label) values (owner_id, a.budget, 'რეკლამის დაბრუნება');
  end if;
  perform public.notify(owner_id, auth.uid(), case when p_approve then 'ad_ok' else 'ad_rejected' end, jsonb_build_object('ad', p_ad));
end $$;
create or replace function public.admin_verify_page(p_page bigint, p_verified boolean) returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_staff() then raise exception 'staff_only'; end if;
  update public.pages set verified = p_verified where id = p_page;
end $$;
create or replace function public.admin_set_role(p_user uuid, p_role text) returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.is_admin() then raise exception 'admin_only'; end if;
  if p_role not in ('user','moderator','admin') then raise exception 'bad_role'; end if;
  if p_user = auth.uid() and p_role <> 'admin' then raise exception 'cannot_demote_self'; end if;
  update public.profiles set role = p_role where id = p_user;
end $$;
create or replace function public.admin_stats() returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_staff() then raise exception 'staff_only'; end if;
  return jsonb_build_object(
    'users', (select count(*) from public.profiles),
    'users_today', (select count(*) from public.profiles where created_at > now() - interval '1 day'),
    'posts_today', (select count(*) from public.posts where created_at > now() - interval '1 day'),
    'open_reports', (select count(*) from public.reports where status = 'open'),
    'pending_verifications', (select count(*) from public.verification_requests where status = 'pending'),
    'pending_ads', (select count(*) from public.ads where status = 'pending'),
    'banned', (select count(*) from public.profiles where banned));
end $$;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('media', 'media', true, 52428800, array['image/jpeg','image/png','image/webp','image/gif','video/mp4','video/webm','video/quicktime','audio/webm','audio/ogg','audio/mpeg','audio/mp4','audio/aac','audio/wav'])
on conflict (id) do nothing;
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('verify', 'verify', false, 10485760, array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;
create policy "media upload to own folder" on storage.objects for insert to authenticated with check (bucket_id = 'media' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "media list own folder" on storage.objects for select to authenticated using (bucket_id = 'media' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "media remove own files" on storage.objects for delete to authenticated using (bucket_id = 'media' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "selfie upload to own folder" on storage.objects for insert to authenticated with check (bucket_id = 'verify' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "selfie read own or staff" on storage.objects for select to authenticated using (bucket_id = 'verify' and ((storage.foldername(name))[1] = (select auth.uid())::text or public.is_staff()));

create table private.config (key text primary key, value text not null);
create or replace function public.push_config() returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_object_agg(key, value), '{}') from private.config;
$$;
revoke execute on function public.push_config() from public, anon, authenticated;
grant execute on function public.push_config() to service_role;
create or replace function public.vapid_public_key() returns text language sql stable security definer set search_path = '' as $$
  select value from private.config where key = 'vapid_public';
$$;
create or replace function private.push_notify() returns trigger language plpgsql security definer set search_path = '' as $$
declare u text; s text;
begin
  if not exists(select 1 from public.push_subs where user_id = new.user_id) then return new; end if;
  select value into u from private.config where key = 'push_url';
  select value into s from private.config where key = 'push_secret';
  if u is null or s is null then return new; end if;
  perform net.http_post(url := u, body := jsonb_build_object('id', new.id), headers := jsonb_build_object('Content-Type', 'application/json', 'x-push-secret', s));
  return new;
end $$;
create trigger notifications_push after insert on public.notifications for each row execute function private.push_notify();
