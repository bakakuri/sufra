-- ============ help board ============
create table public.help_requests (
  id bigint generated always as identity primary key,
  author uuid not null references public.profiles(id) on delete cascade,
  kind text not null check (kind in ('blood','lost_pet','found_pet','lost_item','found_item','volunteer','other')),
  title text not null check (char_length(title) between 4 and 100),
  body text not null default '' check (char_length(body) <= 1500),
  media jsonb not null default '[]' check (jsonb_typeof(media) = 'array' and jsonb_array_length(media) <= 4),
  region text not null check (char_length(region) between 2 and 60),
  city text not null default '' check (char_length(city) <= 60),
  blood_type text check (blood_type in ('O-','O+','A-','A+','B-','B+','AB-','AB+')),
  contact text not null default '' check (char_length(contact) <= 60),
  urgent boolean not null default false,
  status text not null default 'open' check (status in ('open','resolved')),
  hidden boolean not null default false,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '30 days'
);
create index help_open_idx on public.help_requests (region, created_at desc) where status = 'open' and not hidden;
alter table public.help_requests enable row level security;
create policy "help visible" on public.help_requests for select to authenticated using ((not hidden or author = (select auth.uid()) or public.is_staff()) and not public.is_blocked(author, (select auth.uid())));
create policy "ask for help" on public.help_requests for insert to authenticated with check (author = (select auth.uid()) and public.can_post() and status = 'open' and not hidden);
create policy "edit own help" on public.help_requests for update to authenticated using (author = (select auth.uid())) with check (author = (select auth.uid()));
create policy "remove help" on public.help_requests for delete to authenticated using (author = (select auth.uid()) or public.is_staff());
revoke update on public.help_requests from authenticated;
grant update (title, body, media, city, contact, urgent, status) on public.help_requests to authenticated;

create table public.help_offers (
  request_id bigint not null references public.help_requests(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  note text not null default '' check (char_length(note) <= 300),
  created_at timestamptz not null default now(),
  primary key (request_id, user_id)
);
alter table public.help_offers enable row level security;
create or replace function public.help_author(r bigint) returns uuid language sql stable security definer set search_path = '' as $$
  select author from public.help_requests where id = r;
$$;
create policy "offers visible" on public.help_offers for select to authenticated using (user_id = (select auth.uid()) or public.help_author(request_id) = (select auth.uid()));
create policy "offer help" on public.help_offers for insert to authenticated with check (user_id = (select auth.uid()) and public.can_post() and public.help_author(request_id) <> (select auth.uid()));
create policy "withdraw offer" on public.help_offers for delete to authenticated using (user_id = (select auth.uid()));

create table public.helpers (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  region text not null default '' check (char_length(region) <= 60),
  blood_type text check (blood_type in ('O-','O+','A-','A+','B-','B+','AB-','AB+')),
  notify_blood boolean not null default false,
  notify_pets boolean not null default false,
  notify_volunteer boolean not null default false,
  updated_at timestamptz not null default now()
);
alter table public.helpers enable row level security;
create policy "my helper settings" on public.helpers for select to authenticated using (user_id = (select auth.uid()));
create policy "add helper settings" on public.helpers for insert to authenticated with check (user_id = (select auth.uid()));
create policy "edit helper settings" on public.helpers for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "remove helper settings" on public.helpers for delete to authenticated using (user_id = (select auth.uid()));

create or replace function public.can_donate(d text, r text) returns boolean language sql immutable set search_path = '' as $$
  select (left(d, -1) = 'O' or left(d, -1) = left(r, -1) or left(r, -1) = 'AB')
     and (right(d, 1) = '-' or right(r, 1) = '+');
$$;

create or replace function public.trg_help_request() returns trigger language plpgsql security definer set search_path = '' as $$
declare h record;
begin
  if not public.is_staff() and (select count(*) from public.help_requests where author = new.author and created_at > now() - interval '1 day') > 3 then raise exception 'too_many'; end if;
  for h in
    select hp.user_id from public.helpers hp join public.profiles p on p.id = hp.user_id
    where hp.user_id <> new.author and hp.region = new.region and not p.banned and p.last_seen > now() - interval '90 days'
      and (case new.kind
            when 'blood' then hp.notify_blood and hp.blood_type is not null and (new.blood_type is null or public.can_donate(hp.blood_type, new.blood_type))
            when 'lost_pet' then hp.notify_pets
            when 'found_pet' then hp.notify_pets
            when 'volunteer' then hp.notify_volunteer
            else false end)
      and not public.is_blocked(hp.user_id, new.author)
    order by p.last_seen desc limit 300
  loop
    perform public.notify(h.user_id, new.author, 'help_new', jsonb_build_object('help', new.id, 'kind', new.kind, 'title', left(new.title, 80), 'region', new.region, 'blood', new.blood_type));
  end loop;
  return new;
end $$;
create trigger help_requests_notify after insert on public.help_requests for each row execute function public.trg_help_request();
create or replace function public.trg_help_offer() returns trigger language plpgsql security definer set search_path = '' as $$
declare r record;
begin
  select id, author, title, status into r from public.help_requests where id = new.request_id;
  if r.status <> 'open' then raise exception 'not_allowed'; end if;
  perform public.notify(r.author, new.user_id, 'help_offer', jsonb_build_object('help', r.id, 'title', left(r.title, 80)));
  return new;
end $$;
create trigger help_offers_notify after insert on public.help_offers for each row execute function public.trg_help_offer();
create or replace function public.trg_help_done() returns trigger language plpgsql security definer set search_path = '' as $$
declare o record;
begin
  if new.status = 'resolved' and old.status = 'open' then
    for o in select user_id from public.help_offers where request_id = new.id loop
      perform public.notify(o.user_id, new.author, 'help_done', jsonb_build_object('help', new.id, 'title', left(new.title, 80)));
    end loop;
  end if;
  return new;
end $$;
create trigger help_requests_done after update of status on public.help_requests for each row execute function public.trg_help_done();

-- ============ surname groups and family tree ============
alter table public.groups drop constraint groups_kind_check;
alter table public.groups add constraint groups_kind_check check (kind in ('normal','place','diaspora','surname'));
create or replace function public.join_surname_group() returns bigint language plpgsql security definer set search_path = '' as $$
declare s text; owner_id uuid; g bigint;
begin
  if not public.can_post() then raise exception 'not_allowed'; end if;
  select trim(surname) into s from public.profiles where id = auth.uid();
  if coalesce(s, '') = '' then raise exception 'bad_request'; end if;
  select id into owner_id from public.profiles where role = 'admin' order by created_at limit 1;
  insert into public.groups (owner, name, description, hue, is_private, kind, place_key)
    values (coalesce(owner_id, auth.uid()), left('გვარი · ' || s, 80), 'გვარის საერთო სახლი: ისტორია, ნათესავები, შეხვედრები', floor(random() * 360)::int, false, 'surname', 'surname:' || lower(s))
    on conflict (place_key) do nothing;
  select id into g from public.groups where place_key = 'surname:' || lower(s);
  insert into public.group_members (group_id, user_id) values (g, auth.uid()) on conflict do nothing;
  return g;
end $$;

create table public.kin (
  id bigint generated always as identity primary key,
  owner uuid not null references public.profiles(id) on delete cascade,
  anchor bigint references public.kin(id) on delete cascade,
  relative uuid references public.profiles(id) on delete cascade,
  name text not null default '' check (char_length(name) <= 60),
  relation text not null check (relation in ('parent','child','sibling','spouse')),
  sex text check (sex in ('f','m')),
  born int check (born between 1000 and 2100),
  died int check (died between 1000 and 2100),
  status text not null default 'accepted' check (status in ('pending','accepted')),
  created_at timestamptz not null default now(),
  check (relative is not null or char_length(trim(name)) >= 2),
  check (relative is null or anchor is null),
  check (relative is distinct from owner)
);
create unique index kin_owner_rel_idx on public.kin (owner, relative) where relative is not null;
create index kin_owner_idx on public.kin (owner);
create index kin_relative_idx on public.kin (relative) where relative is not null;
alter table public.kin enable row level security;
create or replace function public.is_kin_of(o uuid) returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.kin where owner = o and relative = auth.uid() and status = 'accepted');
$$;
create policy "family tree visible" on public.kin for select to authenticated using (
  owner = (select auth.uid()) or relative = (select auth.uid())
  or (status = 'accepted' and (public.are_friends(owner, (select auth.uid())) or public.is_kin_of(owner))));
create policy "add to my tree" on public.kin for insert to authenticated with check (owner = (select auth.uid()) and public.can_post());
create policy "edit my tree" on public.kin for update to authenticated using (owner = (select auth.uid())) with check (owner = (select auth.uid()));
create policy "remove from tree" on public.kin for delete to authenticated using (owner = (select auth.uid()) or relative = (select auth.uid()));
revoke update on public.kin from authenticated;
grant update (name, sex, born, died) on public.kin to authenticated;

create or replace function public.kin_before() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if (select count(*) from public.kin where owner = new.owner) >= 200 then raise exception 'too_many'; end if;
  if new.anchor is not null and not exists(select 1 from public.kin where id = new.anchor and owner = new.owner) then raise exception 'bad_request'; end if;
  if new.relative is not null then
    if public.is_blocked(new.owner, new.relative) then raise exception 'blocked'; end if;
    new.name := '';
    -- the other side already confirmed (reciprocal row created on accept): no new request
    new.status := case when exists(select 1 from public.kin where owner = new.relative and relative = new.owner and status = 'accepted') then 'accepted' else 'pending' end;
  else
    new.status := 'accepted';
  end if;
  return new;
end $$;
create trigger kin_before before insert on public.kin for each row execute function public.kin_before();
create or replace function public.kin_after() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' and new.relative is not null and new.status = 'pending' then
    perform public.notify(new.relative, new.owner, 'kin_req', jsonb_build_object('kin', new.id, 'rel', new.relation, 'owner', new.owner));
  elsif tg_op = 'DELETE' and old.relative is not null then
    delete from public.kin where owner = old.relative and relative = old.owner;
  end if;
  return null;
end $$;
create trigger kin_after after insert or delete on public.kin for each row execute function public.kin_after();

create or replace function public.respond_kin(p_id bigint, p_accept boolean) returns void language plpgsql security definer set search_path = '' as $$
declare k record; inv text; sx text;
begin
  select * into k from public.kin where id = p_id and relative = auth.uid() and status = 'pending';
  if k is null then raise exception 'not_found'; end if;
  if not p_accept then delete from public.kin where id = p_id; return; end if;
  update public.kin set status = 'accepted' where id = p_id;
  inv := case k.relation when 'parent' then 'child' when 'child' then 'parent' else k.relation end;
  select case gender when 'f' then 'f' when 'm' then 'm' end into sx from public.profiles where id = k.owner;
  insert into public.kin (owner, relative, relation, sex) values (auth.uid(), k.owner, inv, sx)
    on conflict (owner, relative) where relative is not null do nothing;
  update public.kin set status = 'accepted' where owner = auth.uid() and relative = k.owner;
  perform public.notify(k.owner, auth.uid(), 'kin_ok', jsonb_build_object('owner', k.owner));
end $$;
