-- a comment can carry one of the Georgian stickers or a photo from our storage
alter table public.comments add column if not exists media jsonb;
create or replace function public.comments_media()
returns trigger
language plpgsql
set search_path to ''
as $function$
declare base text := 'https://iasospzhhdedpilykpiu.supabase.co/storage/v1/object/public/media/';
begin
  if new.media is null then return new; end if;
  if jsonb_typeof(new.media) = 'object' and coalesce(new.media->>'sticker', '') ~ '^[a-z0-9_]{1,24}$' then
    new.media := jsonb_build_object('sticker', new.media->>'sticker');
  elsif jsonb_typeof(new.media) = 'object' and left(coalesce(new.media->>'url', ''), length(base)) = base and new.media->>'url' !~ '[\s"''<>()]' then
    new.media := jsonb_strip_nulls(jsonb_build_object('url', new.media->>'url',
      'sm', case when left(coalesce(new.media->>'sm', ''), length(base)) = base and new.media->>'sm' !~ '[\s"''<>()]' then new.media->>'sm' end,
      'w', case when jsonb_typeof(new.media->'w') = 'number' then round((new.media->>'w')::numeric)::int end,
      'h', case when jsonb_typeof(new.media->'h') = 'number' then round((new.media->>'h')::numeric)::int end));
  else
    new.media := null;
  end if;
  if new.media is not null and trim(coalesce(new.body, '')) = '' then new.body := case when new.media ? 'sticker' then '✨' else '📷' end; end if;
  if new.media is null and trim(coalesce(new.body, '')) = '' then raise exception 'bad_request'; end if;
  return new;
end $function$;
create or replace trigger comments_media before insert or update of media on public.comments for each row execute function public.comments_media();

-- folders for saved posts
create table if not exists public.save_folders (
  id bigserial primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 40),
  created_at timestamptz not null default now());
create index if not exists save_folders_user_idx on public.save_folders (user_id, created_at);
alter table public.save_folders enable row level security;
create policy "own folders" on public.save_folders for select using (user_id = (select auth.uid()));
create policy "own folders insert" on public.save_folders for insert with check (user_id = (select auth.uid()));
create policy "own folders update" on public.save_folders for update using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "own folders remove" on public.save_folders for delete using (user_id = (select auth.uid()));
revoke all on public.save_folders from anon;
grant select, insert, update, delete on public.save_folders to authenticated;
grant usage on sequence public.save_folders_id_seq to authenticated;
alter table public.saves add column if not exists folder_id bigint references public.save_folders(id) on delete set null;
create policy "move own save" on public.saves for update using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()) and (folder_id is null or exists (select 1 from public.save_folders f where f.id = folder_id and f.user_id = (select auth.uid()))));
grant update (folder_id) on public.saves to authenticated;

-- followed hashtags shape the "for you" feed
create table if not exists public.tag_follows (
  user_id uuid not null references public.profiles(id) on delete cascade,
  tag text not null check (char_length(tag) between 1 and 40),
  created_at timestamptz not null default now(),
  primary key (user_id, tag));
alter table public.tag_follows enable row level security;
create policy "own tags" on public.tag_follows for select using (user_id = (select auth.uid()));
create policy "own tags insert" on public.tag_follows for insert with check (user_id = (select auth.uid()) and (select count(*) from public.tag_follows t where t.user_id = (select auth.uid())) < 80);
create policy "own tags remove" on public.tag_follows for delete using (user_id = (select auth.uid()));
revoke all on public.tag_follows from anon;
grant select, insert, delete on public.tag_follows to authenticated;
alter policy "save" on public.saves with check (user_id = (select auth.uid()) and (folder_id is null or exists (select 1 from public.save_folders f where f.id = folder_id and f.user_id = (select auth.uid()))));
