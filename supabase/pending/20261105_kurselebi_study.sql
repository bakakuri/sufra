-- კურსელები: schools and universities on the profile, class and course groups,
-- the lecture timetable, exams and assignments, and files (PDF, Word, PowerPoint) on posts for notes.
-- Not applied until the owner says so ("დაამატე ბაზაში").

-- ============ 1. education on the profile ============
-- up to 8 places: {k:'school'|'uni', n:name, c:city, key:normalised key, y0:from, y1:to, cls:class letter, f:faculty}
alter table public.profiles add column if not exists edu jsonb not null default '[]'::jsonb
  check (jsonb_typeof(edu) = 'array' and jsonb_array_length(edu) <= 8 and pg_column_size(edu) < 6000);
grant select (edu) on public.profiles to authenticated;
grant update (edu) on public.profiles to authenticated;
create index if not exists profiles_edu_idx on public.profiles using gin (edu jsonb_path_ops);

-- ============ 2. school, class, university and course groups, joined like the place groups ============
alter table public.groups drop constraint if exists groups_kind_check;
alter table public.groups add constraint groups_kind_check
  check (kind in ('normal','place','diaspora','surname','school','class','uni','course'));

create or replace function public.join_edu_groups() returns bigint[] language plpgsql security definer set search_path = '' as $$
declare e jsonb; it jsonb; owner_id uuid; ids bigint[] := '{}'; g bigint;
  k text; nm text; key text; y0 int; y1 int; cls text; fac text; city text;
  keys text[]; names text[]; kinds text[]; descs text[]; i int;
begin
  if not public.can_post() then raise exception 'not_allowed'; end if;
  select edu into e from public.profiles where id = auth.uid();
  select id into owner_id from public.profiles where role = 'admin' order by created_at limit 1;
  owner_id := coalesce(owner_id, auth.uid());
  for it in select * from jsonb_array_elements(coalesce(e, '[]'::jsonb)) loop
    k := it->>'k';
    key := left(lower(regexp_replace(coalesce(it->>'key', ''), '[^a-z0-9ა-ჰ:_-]', '', 'g')), 100);
    nm := left(trim(coalesce(it->>'n', '')), 60);
    city := left(trim(coalesce(it->>'c', '')), 30);
    y0 := case when (it->>'y0') ~ '^\d{4}$' then (it->>'y0')::int end;
    y1 := case when (it->>'y1') ~ '^\d{4}$' then (it->>'y1')::int end;
    cls := left(trim(coalesce(it->>'cls', '')), 4);
    fac := left(trim(coalesce(it->>'f', '')), 50);
    if key = '' or nm = '' or k not in ('school', 'uni') then continue; end if;
    keys := '{}'; names := '{}'; kinds := '{}'; descs := '{}';
    if k = 'school' then
      keys := keys || ('school:' || key); names := names || (nm || case when city <> '' then ' · ' || city else '' end); kinds := kinds || 'school'::text; descs := descs || 'სკოლის ყველა თაობა'::text;
      if y1 is not null then
        keys := keys || ('class:' || key || ':' || y1 || case when cls <> '' then ':' || lower(cls) else '' end);
        names := names || (nm || ' · ' || y1 || ' წლის კლასი' || case when cls <> '' then ' „' || cls || '“' else '' end);
        kinds := kinds || 'class'::text; descs := descs || 'კლასელები: ერთად დამთავრებულები'::text;
      end if;
    else
      keys := keys || ('uni:' || key); names := names || nm; kinds := kinds || 'uni'::text; descs := descs || 'უნივერსიტეტის სტუდენტები და კურსდამთავრებულები'::text;
      if fac <> '' and y0 is not null then
        keys := keys || ('course:' || key || ':' || lower(regexp_replace(fac, '\s+', '-', 'g')) || ':' || y0);
        names := names || (fac || ' · ' || y0 || ' · ' || nm);
        kinds := kinds || 'course'::text; descs := descs || 'კურსელები: ერთად ჩარიცხულები'::text;
      end if;
    end if;
    for i in 1 .. coalesce(array_length(keys, 1), 0) loop
      insert into public.groups (owner, name, description, hue, is_private, kind, place_key)
        values (owner_id, left(names[i], 80), descs[i], floor(random() * 360)::int, false, kinds[i], keys[i])
        on conflict (place_key) do nothing;
      select id into g from public.groups where place_key = keys[i];
      insert into public.group_members (group_id, user_id) values (g, auth.uid()) on conflict do nothing;
      ids := ids || g;
    end loop;
  end loop;
  return ids;
end $$;
revoke execute on function public.join_edu_groups() from public, anon;
grant execute on function public.join_edu_groups() to authenticated;

-- ============ 3. the lecture timetable ============
create table if not exists public.lessons (
  id bigint generated always as identity primary key,
  owner uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  group_id bigint references public.groups(id) on delete cascade,
  day smallint not null check (day between 1 and 7),
  starts time not null,
  ends time not null,
  title text not null check (char_length(title) between 1 and 80),
  kind text not null default 'lecture' check (kind in ('lecture','seminar','lab','lesson','other')),
  place text not null default '' check (char_length(place) <= 60),
  teacher text not null default '' check (char_length(teacher) <= 60),
  weeks text not null default 'all' check (weeks in ('all','odd','even')),
  hue int not null default 250 check (hue between 0 and 359),
  created_at timestamptz not null default now(),
  check (ends > starts)
);
create index if not exists lessons_owner_idx on public.lessons (owner);
create index if not exists lessons_group_idx on public.lessons (group_id) where group_id is not null;
alter table public.lessons enable row level security;
create policy "own or group lessons" on public.lessons for select to authenticated
  using (owner = (select auth.uid()) or (group_id is not null and public.is_group_member(group_id)));
create policy "add lesson" on public.lessons for insert to authenticated
  with check (owner = (select auth.uid()) and (group_id is null or public.is_group_member(group_id)));
create policy "edit own lesson" on public.lessons for update to authenticated
  using (owner = (select auth.uid())) with check (owner = (select auth.uid()) and (group_id is null or public.is_group_member(group_id)));
create policy "remove lesson" on public.lessons for delete to authenticated
  using (owner = (select auth.uid()) or (group_id is not null and public.is_group_admin(group_id)));

-- ============ 4. exams and assignments ============
create table if not exists public.deadlines (
  id bigint generated always as identity primary key,
  owner uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  group_id bigint references public.groups(id) on delete cascade,
  kind text not null default 'task' check (kind in ('exam','midterm','quiz','task','project')),
  title text not null check (char_length(title) between 1 and 120),
  subject text not null default '' check (char_length(subject) <= 80),
  due_at timestamptz not null,
  notes text not null default '' check (char_length(notes) <= 1000),
  created_at timestamptz not null default now()
);
create index if not exists deadlines_owner_idx on public.deadlines (owner, due_at);
create index if not exists deadlines_group_idx on public.deadlines (group_id, due_at) where group_id is not null;
alter table public.deadlines enable row level security;
create policy "own or group deadlines" on public.deadlines for select to authenticated
  using (owner = (select auth.uid()) or (group_id is not null and public.is_group_member(group_id)));
create policy "add deadline" on public.deadlines for insert to authenticated
  with check (owner = (select auth.uid()) and (group_id is null or public.is_group_member(group_id)));
create policy "edit own deadline" on public.deadlines for update to authenticated
  using (owner = (select auth.uid())) with check (owner = (select auth.uid()) and (group_id is null or public.is_group_member(group_id)));
create policy "remove deadline" on public.deadlines for delete to authenticated
  using (owner = (select auth.uid()) or (group_id is not null and public.is_group_admin(group_id)));

-- what each person has finished, so a shared assignment can be ticked off by everyone on their own
create table if not exists public.deadline_done (
  user_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  deadline_id bigint not null references public.deadlines(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, deadline_id)
);
alter table public.deadline_done enable row level security;
create policy "own done marks" on public.deadline_done for select to authenticated using (user_id = (select auth.uid()));
create policy "mark done" on public.deadline_done for insert to authenticated with check (user_id = (select auth.uid()));
create policy "unmark done" on public.deadline_done for delete to authenticated using (user_id = (select auth.uid()));

-- ============ 5. files on posts (notes as PDF, Word, PowerPoint, text) ============
update storage.buckets set allowed_mime_types = array(select distinct x from unnest(allowed_mime_types || array[
  'application/pdf',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-powerpoint',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'text/plain']) as x)
where id = 'media';
