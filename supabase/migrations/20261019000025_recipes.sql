-- Georgian kitchen: recipes with ingredients and steps, "tasty" likes and "I made it too" photos
create table if not exists public.recipes (
  id bigserial primary key,
  author uuid references public.profiles(id) on delete cascade,
  title text not null check (char_length(title) between 2 and 80),
  about text not null default '' check (char_length(about) <= 500),
  photo_url text check (photo_url is null or photo_url ~ '^https://[^\s"''<>()]+$'),
  category text not null default 'სხვა' check (category in ('ცომეული','ხორციანი','ბოსტნეული','წვნიანი','სალათი','ტკბილეული','სოუსი','სხვა')),
  region text not null default '' check (char_length(region) <= 40),
  servings int not null default 4 check (servings between 1 and 40),
  minutes int not null default 60 check (minutes between 1 and 2880),
  ingredients jsonb not null default '[]'::jsonb,
  steps jsonb not null default '[]'::jsonb,
  likes int not null default 0,
  cooks int not null default 0,
  created_at timestamptz not null default now());
create index if not exists recipes_time_idx on public.recipes (created_at desc);
create index if not exists recipes_author_idx on public.recipes (author, created_at desc);
create table if not exists public.recipe_likes (
  recipe_id bigint not null references public.recipes(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (recipe_id, user_id));
create table if not exists public.recipe_cooks (
  id bigserial primary key,
  recipe_id bigint not null references public.recipes(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  photo_url text check (photo_url is null or photo_url ~ '^https://[^\s"''<>()]+$'),
  note text not null default '' check (char_length(note) <= 300),
  created_at timestamptz not null default now());
create index if not exists recipe_cooks_recipe_idx on public.recipe_cooks (recipe_id, created_at desc);

create or replace function public.recipes_before()
returns trigger
language plpgsql
set search_path to ''
as $function$
declare x jsonb; ing jsonb := '[]'::jsonb; st jsonb := '[]'::jsonb;
begin
  if jsonb_typeof(new.ingredients) = 'array' then
    for x in select * from jsonb_array_elements(new.ingredients) limit 40 loop
      if jsonb_typeof(x) = 'object' and length(trim(coalesce(x->>'n', ''))) > 0 then
        ing := ing || jsonb_build_object('n', left(trim(x->>'n'), 60), 'q', left(trim(coalesce(x->>'q', '')), 30));
      end if;
    end loop;
  end if;
  if jsonb_typeof(new.steps) = 'array' then
    for x in select * from jsonb_array_elements(new.steps) limit 30 loop
      if jsonb_typeof(x) = 'string' and length(trim(x #>> '{}')) > 0 then st := st || to_jsonb(left(trim(x #>> '{}'), 600)); end if;
    end loop;
  end if;
  if jsonb_array_length(ing) = 0 or jsonb_array_length(st) = 0 then raise exception 'bad_request'; end if;
  new.ingredients := ing; new.steps := st;
  if tg_op = 'INSERT' then new.likes := 0; new.cooks := 0; new.created_at := now(); end if;
  return new;
end $function$;
create or replace trigger recipes_before before insert or update on public.recipes for each row execute function public.recipes_before();

create or replace function private.recipe_counts()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
declare r bigint := coalesce(new.recipe_id, old.recipe_id); a uuid;
begin
  if tg_table_name = 'recipe_likes' then
    update public.recipes set likes = (select count(*) from public.recipe_likes where recipe_id = r) where id = r;
  else
    update public.recipes set cooks = (select count(*) from public.recipe_cooks where recipe_id = r) where id = r;
    if tg_op = 'INSERT' then
      select author into a from public.recipes where id = r;
      if a is not null and a <> new.user_id then perform public.notify(a, new.user_id, 'recipe_cook', jsonb_build_object('recipe', r)); end if;
    end if;
  end if;
  return null;
end $function$;
revoke execute on function private.recipe_counts() from public, anon, authenticated;
create or replace trigger recipe_likes_count after insert or delete on public.recipe_likes for each row execute function private.recipe_counts();
create or replace trigger recipe_cooks_count after insert or delete on public.recipe_cooks for each row execute function private.recipe_counts();

alter table public.recipes enable row level security;
alter table public.recipe_likes enable row level security;
alter table public.recipe_cooks enable row level security;
create policy "recipes visible" on public.recipes for select using (author is null or not public.is_blocked(author, (select auth.uid())));
create policy "write recipe" on public.recipes for insert with check (author = (select auth.uid()) and public.can_post());
create policy "edit own recipe" on public.recipes for update using (author = (select auth.uid())) with check (author = (select auth.uid()));
create policy "remove recipe" on public.recipes for delete using (author = (select auth.uid()) or public.is_staff());
create policy "likes visible" on public.recipe_likes for select using (true);
create policy "like recipe" on public.recipe_likes for insert with check (user_id = (select auth.uid()));
create policy "unlike recipe" on public.recipe_likes for delete using (user_id = (select auth.uid()));
create policy "cooks visible" on public.recipe_cooks for select using (not public.is_blocked(user_id, (select auth.uid())));
create policy "add cook" on public.recipe_cooks for insert with check (user_id = (select auth.uid()) and public.can_post());
create policy "remove cook" on public.recipe_cooks for delete using (user_id = (select auth.uid()) or public.is_staff());
revoke all on public.recipes, public.recipe_likes, public.recipe_cooks from anon;
grant select, delete on public.recipes, public.recipe_likes, public.recipe_cooks to authenticated;
grant insert (author, title, about, photo_url, category, region, servings, minutes, ingredients, steps), update (title, about, photo_url, category, region, servings, minutes, ingredients, steps) on public.recipes to authenticated;
grant insert (recipe_id, user_id) on public.recipe_likes to authenticated;
grant insert (recipe_id, user_id, photo_url, note) on public.recipe_cooks to authenticated;
grant usage on sequence public.recipes_id_seq, public.recipe_cooks_id_seq to authenticated;
