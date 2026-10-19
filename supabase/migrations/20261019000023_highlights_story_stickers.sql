-- stories stay with their author after 24 hours (the archive); the best go to "highlights" on the profile
alter policy "stories visible" on public.stories using (
  author = (select auth.uid())
  or (expires_at > now() and not public.is_blocked(author, (select auth.uid())) and (audience = 'all' or public.in_close(author))));

create table if not exists public.highlights (
  id bigserial primary key,
  owner uuid not null references public.profiles(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 24),
  cover_url text check (cover_url is null or cover_url ~ '^https://[^\s"''<>()]+$'),
  pos int not null default 0,
  created_at timestamptz not null default now());
create index if not exists highlights_owner_idx on public.highlights (owner, pos, id);
create table if not exists public.highlight_items (
  id bigserial primary key,
  highlight_id bigint not null references public.highlights(id) on delete cascade,
  story_id bigint,
  url text not null check (url ~ '^https://[^\s"''<>()]+$'),
  media_type text not null default 'image' check (media_type in ('image','video')),
  created_at timestamptz not null default now(),
  unique (highlight_id, story_id));
create index if not exists highlight_items_hl_idx on public.highlight_items (highlight_id, created_at);
alter table public.highlights enable row level security;
alter table public.highlight_items enable row level security;
create policy "highlights visible" on public.highlights for select using (not public.is_blocked(owner, (select auth.uid())));
create policy "own highlights insert" on public.highlights for insert with check (owner = (select auth.uid()) and public.can_post());
create policy "own highlights update" on public.highlights for update using (owner = (select auth.uid())) with check (owner = (select auth.uid()));
create policy "own highlights remove" on public.highlights for delete using (owner = (select auth.uid()));
create policy "highlight items visible" on public.highlight_items for select using (exists (select 1 from public.highlights h where h.id = highlight_id and not public.is_blocked(h.owner, (select auth.uid()))));
create policy "own highlight items remove" on public.highlight_items for delete using (exists (select 1 from public.highlights h where h.id = highlight_id and h.owner = (select auth.uid())));
revoke all on public.highlights, public.highlight_items from anon;
grant select, delete on public.highlights, public.highlight_items to authenticated;
grant insert (owner, title, cover_url, pos), update (title, cover_url, pos) on public.highlights to authenticated;
grant usage on sequence public.highlights_id_seq to authenticated;

-- a story is copied into a highlight only by its author; the first one becomes the cover
create or replace function public.add_to_highlight(p_highlight bigint, p_story bigint)
returns bigint
language plpgsql
security definer
set search_path to ''
as $function$
declare h record; s record; n bigint;
begin
  select * into h from public.highlights where id = p_highlight and owner = auth.uid();
  if h.id is null then raise exception 'not_allowed'; end if;
  select * into s from public.stories where id = p_story and author = auth.uid();
  if s.id is null then raise exception 'not_found'; end if;
  if (select count(*) from public.highlight_items where highlight_id = h.id) >= 60 then raise exception 'album_full'; end if;
  insert into public.highlight_items (highlight_id, story_id, url, media_type, created_at)
    values (h.id, s.id, s.media_url, s.media_type, s.created_at)
    on conflict (highlight_id, story_id) do nothing returning id into n;
  if h.cover_url is null and s.media_type = 'image' then update public.highlights set cover_url = s.media_url where id = h.id; end if;
  return coalesce(n, 0);
end $function$;
revoke execute on function public.add_to_highlight(bigint, bigint) from public, anon;
grant execute on function public.add_to_highlight(bigint, bigint) to authenticated;

-- stickers on a story: a person (@), a place, a countdown, a question box
alter table public.stories add column if not exists stickers jsonb;
create or replace function public.stories_before()
returns trigger
language plpgsql
set search_path to ''
as $function$
declare o jsonb := '[]'::jsonb; x jsonb; st jsonb := '[]'::jsonb; px numeric; py numeric; t text;
begin
  if new.poll is not null then
    if jsonb_typeof(new.poll) <> 'object' or jsonb_typeof(new.poll->'opts') <> 'array' then new.poll := null;
    else
      for x in select * from jsonb_array_elements(new.poll->'opts') limit 4 loop
        if jsonb_typeof(x) = 'string' and length(trim(x #>> '{}')) > 0 then o := o || to_jsonb(left(trim(x #>> '{}'), 30)); end if;
      end loop;
      if jsonb_array_length(o) < 2 then new.poll := null;
      else new.poll := jsonb_build_object('q', left(coalesce(trim(new.poll->>'q'), ''), 90), 'opts', o); end if;
    end if;
  end if;
  if new.stickers is not null then
    if jsonb_typeof(new.stickers) = 'array' then
      for x in select * from jsonb_array_elements(new.stickers) limit 6 loop
        if jsonb_typeof(x) <> 'object' then continue; end if;
        t := x->>'t';
        px := case when jsonb_typeof(x->'x') = 'number' then least(.95, greatest(.05, (x->>'x')::numeric)) else .5 end;
        py := case when jsonb_typeof(x->'y') = 'number' then least(.9, greatest(.08, (x->>'y')::numeric)) else .5 end;
        if t = 'mention' and coalesce(x->>'u', '') ~ '^[0-9a-f-]{36}$' and exists (select 1 from public.profiles p where p.id = (x->>'u')::uuid) then
          st := st || jsonb_build_object('t', t, 'u', x->>'u', 'x', px, 'y', py);
        elsif t = 'place' and length(trim(coalesce(x->>'name', ''))) > 0 then
          st := st || jsonb_build_object('t', t, 'name', left(trim(x->>'name'), 40), 'x', px, 'y', py);
        elsif t = 'count' and length(trim(coalesce(x->>'title', ''))) > 0 and coalesce(x->>'at', '') ~ '^\d{4}-\d\d-\d\d' then
          st := st || jsonb_build_object('t', t, 'title', left(trim(x->>'title'), 40), 'at', (x->>'at')::timestamptz, 'x', px, 'y', py);
        elsif t = 'ask' then
          st := st || jsonb_build_object('t', t, 'q', left(coalesce(nullif(trim(x->>'q'), ''), 'მკითხე რამე'), 60), 'x', px, 'y', py);
        end if;
      end loop;
    end if;
    new.stickers := case when jsonb_array_length(st) > 0 then st else null end;
  end if;
  return new;
end $function$;

-- people marked on a story hear about it
create or replace function private.story_mentions()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
declare x jsonb;
begin
  if new.stickers is null then return null; end if;
  for x in select * from jsonb_array_elements(new.stickers) loop
    if x->>'t' = 'mention' and (x->>'u')::uuid <> new.author and not public.is_blocked(new.author, (x->>'u')::uuid) then
      perform public.notify((x->>'u')::uuid, new.author, 'story_mention', jsonb_build_object('story', new.id));
    end if;
  end loop;
  return null;
end $function$;
revoke execute on function private.story_mentions() from public, anon, authenticated;
create or replace trigger stories_mentions after insert on public.stories for each row execute function private.story_mentions();
