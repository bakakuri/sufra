-- ============ name days ============
create table public.name_days (
  id bigint generated always as identity primary key,
  names text[] not null,
  md text not null check (md ~ '^[0-1][0-9]-[0-3][0-9]$'),
  label text not null check (char_length(label) <= 80)
);
create index name_days_md_idx on public.name_days (md);
alter table public.name_days enable row level security;
create policy "name days readable" on public.name_days for select to authenticated using (true);

alter table public.profiles
  add column nameday text check (nameday ~ '^[0-1][0-9]-[0-3][0-9]$'),
  add column nameday_label text not null default '' check (char_length(nameday_label) <= 80),
  add column surname text not null default '' check (char_length(surname) <= 40);
grant select (nameday, nameday_label, surname) on public.profiles to authenticated;
grant update (nameday, nameday_label, surname) on public.profiles to authenticated;
create index profiles_surname_idx on public.profiles (surname) where surname <> '';

-- daily: friends' name days and birthdays, one grouped notification per kind
create or replace function private.daily_celebrations() returns int language plpgsql security definer set search_path = '' as $$
declare today text := to_char((now() at time zone 'Asia/Tbilisi')::date, 'MM-DD'); n int := 0; k int;
begin
  create temp table _cel (uid uuid, kind text, label text) on commit drop;
  insert into _cel
    select p.id, 'nameday', coalesce(nullif(p.nameday_label, ''), 'ანგელოზის დღე') from public.profiles p
    where p.nameday = today and p.onboarded and not p.banned;
  insert into _cel
    select p.id, 'nameday', min(d.label) from public.profiles p
    join public.name_days d on d.md = today and lower(split_part(trim(p.name), ' ', 1)) = any(d.names)
    where p.nameday is null and p.onboarded and not p.banned group by p.id;
  insert into _cel
    select p.id, 'birthday', 'დაბადების დღე' from public.profiles p
    where p.birthday is not null and to_char(p.birthday, 'MM-DD') = today and p.onboarded and not p.banned;

  -- friends
  insert into public.notifications (user_id, actor, kind, ref)
  select x.uid, x.ids[1], x.kind, jsonb_build_object('n', x.cnt, 'label', x.label, 'ids', to_jsonb(x.ids[1:5]), 'day', today)
  from (
    select f.friend as uid, c.kind, count(*)::int as cnt, min(c.label) as label, array_agg(c.uid order by c.uid) as ids
    from _cel c
    join lateral (
      select case when fr.requester = c.uid then fr.addressee else fr.requester end as friend
      from public.friendships fr where fr.status = 'accepted' and (fr.requester = c.uid or fr.addressee = c.uid)
    ) f on true
    group by f.friend, c.kind
  ) x
  where not exists (select 1 from public.notifications o where o.user_id = x.uid and o.kind = x.kind and o.ref->>'day' = today and o.created_at > now() - interval '20 hours');
  get diagnostics k = row_count; n := n + k;

  -- the person celebrating
  insert into public.notifications (user_id, actor, kind, ref)
  select c.uid, null, c.kind || '_me', jsonb_build_object('label', c.label, 'day', today) from _cel c
  where not exists (select 1 from public.notifications o where o.user_id = c.uid and o.kind = c.kind || '_me' and o.ref->>'day' = today and o.created_at > now() - interval '20 hours');
  get diagnostics k = row_count; n := n + k;
  return n;
end $$;
revoke execute on function private.daily_celebrations() from public, anon, authenticated;

-- ============ chat: reply, edit, unsend, pin, disappearing messages ============
alter table public.messages
  add column reply_to bigint references public.messages(id) on delete set null,
  add column edited_at timestamptz,
  add column deleted boolean not null default false,
  add column expires_at timestamptz;
create index messages_expiry_idx on public.messages (expires_at) where expires_at is not null;
alter table public.conversations
  add column pinned_msg bigint references public.messages(id) on delete set null,
  add column ttl int check (ttl in (3600, 86400, 604800));

create or replace function public.messages_before() returns trigger language plpgsql security definer set search_path = '' as $$
declare t int;
begin
  if new.reply_to is not null and not exists(select 1 from public.messages m where m.id = new.reply_to and m.conv_id = new.conv_id) then new.reply_to := null; end if;
  if new.kind <> 'system' then
    select ttl into t from public.conversations where id = new.conv_id;
    if t is not null then new.expires_at := now() + make_interval(secs => t); else new.expires_at := null; end if;
  end if;
  new.deleted := false; new.edited_at := null;
  return new;
end $$;
create trigger messages_before before insert on public.messages for each row execute function public.messages_before();
revoke execute on function public.messages_before() from public, anon, authenticated;

alter policy "read messages" on public.messages using (public.is_member(conv_id) and (expires_at is null or expires_at > now()));

create or replace function public.edit_message(p_id bigint, p_body text) returns void language plpgsql security definer set search_path = '' as $$
begin
  if char_length(trim(coalesce(p_body, ''))) not between 1 and 4000 then raise exception 'bad_request'; end if;
  update public.messages set body = trim(p_body), edited_at = now()
  where id = p_id and sender = auth.uid() and kind = 'text' and not deleted and created_at > now() - interval '48 hours'
    and (media is null or media ? 'link' or media = '{}'::jsonb);
  if not found then raise exception 'not_allowed'; end if;
end $$;
create or replace function public.unsend_message(p_id bigint) returns void language plpgsql security definer set search_path = '' as $$
declare c bigint;
begin
  update public.messages set deleted = true, body = '', media = null where id = p_id and sender = auth.uid() and kind <> 'system' and not deleted returning conv_id into c;
  if c is null then raise exception 'not_allowed'; end if;
  update public.conversations set pinned_msg = null where id = c and pinned_msg = p_id;
end $$;
create or replace function public.pin_message(p_conv bigint, p_msg bigint) returns void language plpgsql security definer set search_path = '' as $$
declare who text;
begin
  if not public.is_member(p_conv) then raise exception 'not_allowed'; end if;
  if p_msg is not null and not exists(select 1 from public.messages where id = p_msg and conv_id = p_conv and not deleted and kind <> 'system') then raise exception 'not_found'; end if;
  update public.conversations set pinned_msg = p_msg where id = p_conv;
  select split_part(name, ' ', 1) into who from public.profiles where id = auth.uid();
  insert into public.messages (conv_id, sender, body, kind) values (p_conv, auth.uid(), who || case when p_msg is null then ' მოხსნა მიმაგრებული შეტყობინება' else ' მიამაგრა შეტყობინება' end, 'system');
end $$;
create or replace function public.set_chat_ttl(p_conv bigint, p_ttl int) returns void language plpgsql security definer set search_path = '' as $$
declare who text;
begin
  if not public.is_member(p_conv) then raise exception 'not_allowed'; end if;
  if p_ttl is not null and p_ttl not in (3600, 86400, 604800) then raise exception 'bad_request'; end if;
  update public.conversations set ttl = p_ttl where id = p_conv;
  select split_part(name, ' ', 1) into who from public.profiles where id = auth.uid();
  insert into public.messages (conv_id, sender, body, kind) values (p_conv, auth.uid(), who || case p_ttl when 3600 then ' ჩართო თვითგაქრობა: 1 საათი' when 86400 then ' ჩართო თვითგაქრობა: 24 საათი' when 604800 then ' ჩართო თვითგაქრობა: 7 დღე' else ' გამორთო თვითგაქრობა' end, 'system');
end $$;
