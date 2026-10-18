create table public.groups (
  id bigint generated always as identity primary key,
  owner uuid not null references public.profiles(id) on delete cascade,
  name text not null check (char_length(name) between 2 and 80),
  description text not null default '' check (char_length(description) <= 500),
  hue int not null default 150,
  is_private boolean not null default false,
  created_at timestamptz not null default now()
);
create table public.group_members (
  group_id bigint not null references public.groups(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('member','admin')),
  created_at timestamptz not null default now(),
  primary key (group_id, user_id)
);
create table public.pages (
  id bigint generated always as identity primary key,
  owner uuid not null references public.profiles(id) on delete cascade,
  kind text not null check (kind in ('channel','business')),
  name text not null check (char_length(name) between 2 and 80),
  category text not null default '',
  description text not null default '' check (char_length(description) <= 500),
  hue int not null default 200,
  avatar_url text,
  verified boolean not null default false,
  created_at timestamptz not null default now()
);
create table public.page_follows (
  page_id bigint not null references public.pages(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (page_id, user_id)
);
create table public.posts (
  id bigint generated always as identity primary key,
  author uuid not null references public.profiles(id) on delete cascade,
  body text not null default '' check (char_length(body) <= 2000),
  media jsonb not null default '[]',
  poll jsonb,
  tags text[] not null default '{}',
  group_id bigint references public.groups(id) on delete cascade,
  page_id bigint references public.pages(id) on delete cascade,
  is_clip boolean not null default false,
  hidden boolean not null default false,
  created_at timestamptz not null default now()
);
create index posts_created_idx on public.posts (created_at desc);
create index posts_author_idx on public.posts (author, created_at desc);
create index posts_tags_idx on public.posts using gin (tags);
create index posts_group_idx on public.posts (group_id);
create index posts_page_idx on public.posts (page_id);
create table public.comments (
  id bigint generated always as identity primary key,
  post_id bigint not null references public.posts(id) on delete cascade,
  author uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 1000),
  hidden boolean not null default false,
  created_at timestamptz not null default now()
);
create index comments_post_idx on public.comments (post_id, created_at);
create table public.reactions (
  post_id bigint not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  emoji text not null check (emoji in ('👍','❤️','😂','😮','😢','😡')),
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);
create table public.post_grades (
  post_id bigint not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  grade text not null check (grade in ('1','2','3','4','5','5+')),
  primary key (post_id, user_id)
);
create table public.poll_votes (
  post_id bigint not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  opt smallint not null check (opt between 0 and 9),
  primary key (post_id, user_id)
);
create table public.saves (
  user_id uuid not null references public.profiles(id) on delete cascade,
  post_id bigint not null references public.posts(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)
);
create table public.stories (
  id bigint generated always as identity primary key,
  author uuid not null references public.profiles(id) on delete cascade,
  media_url text not null,
  media_type text not null default 'image' check (media_type in ('image','video')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '24 hours'
);
create table public.story_views (
  story_id bigint not null references public.stories(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  seen_at timestamptz not null default now(),
  primary key (story_id, user_id)
);
create table public.profile_visits (
  visitor uuid not null references public.profiles(id) on delete cascade,
  visited uuid not null references public.profiles(id) on delete cascade,
  visited_at timestamptz not null default now(),
  primary key (visitor, visited),
  check (visitor <> visited)
);
create table public.friendships (
  requester uuid not null references public.profiles(id) on delete cascade,
  addressee uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted')),
  created_at timestamptz not null default now(),
  primary key (requester, addressee),
  check (requester <> addressee)
);

alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.pages enable row level security;
alter table public.page_follows enable row level security;
alter table public.posts enable row level security;
alter table public.comments enable row level security;
alter table public.reactions enable row level security;
alter table public.post_grades enable row level security;
alter table public.poll_votes enable row level security;
alter table public.saves enable row level security;
alter table public.stories enable row level security;
alter table public.story_views enable row level security;
alter table public.profile_visits enable row level security;
alter table public.friendships enable row level security;

create or replace function public.is_group_member(g bigint) returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.group_members where group_id = g and user_id = auth.uid());
$$;
create or replace function public.group_visible(g bigint) returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.groups where id = g and (not is_private or owner = auth.uid())) or public.is_group_member(g);
$$;
create or replace function public.owns_page(p bigint) returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.pages where id = p and owner = auth.uid());
$$;
create or replace function public.are_friends(a uuid, b uuid) returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.friendships where status = 'accepted' and ((requester = a and addressee = b) or (requester = b and addressee = a)));
$$;
create or replace function public.post_tags() returns trigger language plpgsql set search_path = '' as $$
begin
  new.tags := coalesce((select array_agg(distinct lower(m[1])) from regexp_matches(new.body, '#([A-Za-z0-9_ა-ჿ]{2,40})', 'g') as m), '{}');
  new.tags := new.tags[1:10];
  return new;
end $$;
create trigger posts_tags before insert or update of body on public.posts for each row execute function public.post_tags();

-- groups
create policy "groups visible" on public.groups for select to authenticated using (not is_private or owner = (select auth.uid()) or public.is_group_member(id));
create policy "create group" on public.groups for insert to authenticated with check (owner = (select auth.uid()) and public.can_post());
create policy "owner edits group" on public.groups for update to authenticated using (owner = (select auth.uid())) with check (owner = (select auth.uid()));
create policy "owner or staff removes group" on public.groups for delete to authenticated using (owner = (select auth.uid()) or public.is_staff());
create policy "members visible" on public.group_members for select to authenticated using (public.group_visible(group_id));
create policy "join public group" on public.group_members for insert to authenticated with check (user_id = (select auth.uid()) and role = 'member' and exists(select 1 from public.groups g where g.id = group_id and (not g.is_private or g.owner = (select auth.uid()))));
create policy "leave group" on public.group_members for delete to authenticated using (user_id = (select auth.uid()) or exists(select 1 from public.groups g where g.id = group_id and g.owner = (select auth.uid())));

-- pages
create policy "pages visible" on public.pages for select to authenticated using (true);
create policy "create page" on public.pages for insert to authenticated with check (owner = (select auth.uid()) and public.can_post() and verified = false);
create policy "owner edits page" on public.pages for update to authenticated using (owner = (select auth.uid())) with check (owner = (select auth.uid()));
create policy "owner or staff removes page" on public.pages for delete to authenticated using (owner = (select auth.uid()) or public.is_staff());
revoke update on public.pages from authenticated;
grant update (name, category, description, hue, avatar_url) on public.pages to authenticated;
create policy "follows visible" on public.page_follows for select to authenticated using (true);
create policy "follow page" on public.page_follows for insert to authenticated with check (user_id = (select auth.uid()));
create policy "unfollow page" on public.page_follows for delete to authenticated using (user_id = (select auth.uid()));

-- posts
create policy "posts visible" on public.posts for select to authenticated using (
  (not hidden or author = (select auth.uid()) or public.is_staff())
  and not public.is_blocked(author, (select auth.uid()))
  and (group_id is null or public.group_visible(group_id)));
create policy "create post" on public.posts for insert to authenticated with check (
  author = (select auth.uid()) and public.can_post() and hidden = false
  and (group_id is null or public.is_group_member(group_id) or exists(select 1 from public.groups g where g.id = group_id and g.owner = (select auth.uid())))
  and (page_id is null or public.owns_page(page_id)));
create policy "author edits post" on public.posts for update to authenticated using (author = (select auth.uid())) with check (author = (select auth.uid()));
create policy "author or staff removes post" on public.posts for delete to authenticated using (author = (select auth.uid()) or public.is_staff());
revoke update on public.posts from authenticated;
grant update (body, media, poll) on public.posts to authenticated;

-- comments
create policy "comments visible" on public.comments for select to authenticated using (
  (not hidden or author = (select auth.uid()) or public.is_staff()) and not public.is_blocked(author, (select auth.uid()))
  and exists(select 1 from public.posts p where p.id = post_id));
create policy "write comment" on public.comments for insert to authenticated with check (
  author = (select auth.uid()) and public.can_post() and hidden = false and exists(select 1 from public.posts p where p.id = post_id));
create policy "remove comment" on public.comments for delete to authenticated using (
  author = (select auth.uid()) or public.is_staff() or exists(select 1 from public.posts p where p.id = post_id and p.author = (select auth.uid())));
revoke update on public.comments from authenticated;

-- reactions, grades, polls, saves
create policy "reactions visible" on public.reactions for select to authenticated using (true);
create policy "react" on public.reactions for insert to authenticated with check (user_id = (select auth.uid()) and public.can_post());
create policy "change reaction" on public.reactions for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "remove reaction" on public.reactions for delete to authenticated using (user_id = (select auth.uid()));
create policy "grades visible" on public.post_grades for select to authenticated using (true);
create policy "grade" on public.post_grades for insert to authenticated with check (user_id = (select auth.uid()) and public.can_post());
create policy "regrade" on public.post_grades for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "votes visible" on public.poll_votes for select to authenticated using (true);
create policy "vote" on public.poll_votes for insert to authenticated with check (user_id = (select auth.uid()) and public.can_post());
create policy "change vote" on public.poll_votes for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "own saves" on public.saves for select to authenticated using (user_id = (select auth.uid()));
create policy "save" on public.saves for insert to authenticated with check (user_id = (select auth.uid()));
create policy "unsave" on public.saves for delete to authenticated using (user_id = (select auth.uid()));

-- stories
create policy "stories visible" on public.stories for select to authenticated using (expires_at > now() and not public.is_blocked(author, (select auth.uid())));
create policy "post story" on public.stories for insert to authenticated with check (author = (select auth.uid()) and public.can_post());
create policy "author or staff removes story" on public.stories for delete to authenticated using (author = (select auth.uid()) or public.is_staff());
create policy "story views visible" on public.story_views for select to authenticated using (user_id = (select auth.uid()) or exists(select 1 from public.stories s where s.id = story_id and s.author = (select auth.uid())));
create policy "mark story seen" on public.story_views for insert to authenticated with check (user_id = (select auth.uid()));
create policy "mark story seen again" on public.story_views for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

-- guests
create policy "see my guests" on public.profile_visits for select to authenticated using (visited = (select auth.uid()) or visitor = (select auth.uid()));
create policy "record visit" on public.profile_visits for insert to authenticated with check (visitor = (select auth.uid()));
create policy "refresh visit" on public.profile_visits for update to authenticated using (visitor = (select auth.uid())) with check (visitor = (select auth.uid()));

-- friendships
create policy "friendships visible" on public.friendships for select to authenticated using (status = 'accepted' or requester = (select auth.uid()) or addressee = (select auth.uid()));
create policy "send request" on public.friendships for insert to authenticated with check (requester = (select auth.uid()) and status = 'pending' and public.can_post() and not public.is_blocked(requester, addressee));
create policy "accept request" on public.friendships for update to authenticated using (addressee = (select auth.uid())) with check (addressee = (select auth.uid()) and status = 'accepted');
create policy "remove friendship" on public.friendships for delete to authenticated using (requester = (select auth.uid()) or addressee = (select auth.uid()));
