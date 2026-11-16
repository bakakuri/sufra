-- Comments as Facebook threads them: an answer to a comment sits one step in, an answer to that answer one step
-- further; an answer to one of those stays on that second step (it does not go in a third time) and names whom it
-- answers. parent_id is the comment it hangs under (two steps at most); reply_to is the comment it actually answers,
-- for the line over it ("პასუხი · …") and for whom the notification goes to.
alter table public.comments add column if not exists reply_to bigint references public.comments(id) on delete set null;
create index if not exists comments_reply_to_idx on public.comments (reply_to) where reply_to is not null;

-- what the app and the site send as parent_id is the comment being answered; here it is put where it hangs
create or replace function public.comments_before() returns trigger
language plpgsql security definer set search_path = '' as $f$
declare par record; up bigint;
begin
  new.likes := 0;
  new.reply_to := null;
  if new.parent_id is not null then
    select id, post_id, parent_id into par from public.comments where id = new.parent_id;
    if par.id is null or par.post_id <> new.post_id then
      new.parent_id := null;
    else
      new.reply_to := par.id;
      if par.parent_id is not null then
        -- answering an answer: under it when it is on the first step, beside it when it is already on the second
        select parent_id into up from public.comments where id = par.parent_id;
        new.parent_id := case when up is null then par.id else par.parent_id end;
      end if;
    end if;
  end if;
  return new;
end $f$;

-- the answered comment's author is told (not the one it hangs under), then the post's author, then who is named
create or replace function public.trg_comment() returns trigger
language plpgsql security definer set search_path = '' as $f$
declare pa uuid; pg bigint; ca uuid; u uuid;
begin
  select author, group_id into pa, pg from public.posts where id = new.post_id;
  if new.parent_id is not null then
    select author into ca from public.comments where id = coalesce(new.reply_to, new.parent_id);
    perform public.notify(ca, new.author, 'comment_reply', jsonb_build_object('post', new.post_id, 'comment', coalesce(new.reply_to, new.parent_id), 'text', left(new.body, 80)));
  end if;
  if ca is null or pa is distinct from ca then
    perform public.notify(pa, new.author, 'comment', jsonb_build_object('post', new.post_id, 'text', left(new.body, 80)));
  end if;
  foreach u in array public.mention_ids(new.body) loop
    continue when u = new.author or u = pa or u = ca;
    continue when not public.group_open_to(pg, u);
    perform public.notify(u, new.author, 'mention', jsonb_build_object('post', new.post_id, 'comment', new.id, 'text', left(new.body, 80)));
  end loop;
  return new;
end $f$;

-- the answers there already answered the comment they hang under
update public.comments set reply_to = parent_id where parent_id is not null and reply_to is null;
