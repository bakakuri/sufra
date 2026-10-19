-- a reply or an emoji on a story arrives in the chat together with the story's picture.
-- the client sends media {story, act}; the server fills in the picture itself, so nobody can attach a foreign address
-- or a story they were not allowed to see.
create or replace function public.messages_before()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
declare t int; sid bigint; surl text; styp text;
begin
  if new.reply_to is not null and not exists(select 1 from public.messages m where m.id = new.reply_to and m.conv_id = new.conv_id) then new.reply_to := null; end if;
  if new.kind <> 'system' then
    select ttl into t from public.conversations where id = new.conv_id;
    if t is not null then new.expires_at := now() + make_interval(secs => t); else new.expires_at := null; end if;
  end if;
  if new.media is not null and jsonb_typeof(new.media) = 'object' and new.media ? 'story' then
    if new.kind = 'text' and coalesce(new.media ->> 'story', '') ~ '^[0-9]{1,18}$' then
      select s.id, s.media_url, s.media_type into sid, surl, styp
        from public.stories s
        where s.id = (new.media ->> 'story')::bigint
          and s.author <> new.sender
          and s.expires_at > now()
          and not public.is_blocked(s.author, new.sender)
          and (s.audience = 'all' or public.in_close(s.author))
          and exists (select 1 from public.conversation_members cm where cm.conv_id = new.conv_id and cm.user_id = s.author);
    end if;
    if sid is null then
      new.media := new.media - 'story' - 'url' - 'type' - 'act';
      if new.media = '{}'::jsonb then new.media := null; end if;
    else
      new.media := jsonb_build_object('story', sid, 'url', surl, 'type', styp,
        'act', case when new.media ->> 'act' = 'react' then 'react' else 'reply' end);
    end if;
  end if;
  new.deleted := false; new.edited_at := null;
  return new;
end $function$;

-- the notification says what happened: an answer to the story or an emoji on it
create or replace function public.trg_message()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
declare m record; txt text;
begin
  update public.conversations set last_message_at = new.created_at where id = new.conv_id;
  if new.kind = 'system' then return new; end if;
  txt := case
    when new.kind = 'voice' then '🎤'
    when new.kind = 'image' then '📷'
    when new.media ? 'story' and new.media ->> 'act' = 'react' then new.body || ' შენს ისტორიაზე'
    when new.media ? 'story' then 'ისტორიაზე: ' || new.body
    else new.body end;
  for m in select user_id, muted_until from public.conversation_members where conv_id = new.conv_id and user_id <> new.sender loop
    if m.muted_until is null or m.muted_until < now() then
      perform public.notify(m.user_id, new.sender, 'message', jsonb_build_object('conv', new.conv_id, 'text', left(txt, 80)));
    end if;
  end loop;
  update public.conversation_members set archived = false
    where conv_id = new.conv_id and archived and (user_id = new.sender or muted_until is null or muted_until < now());
  return new;
end $function$;

-- the emoji now comes as a chat message, so the separate story notification would only repeat it
create or replace function public.trg_story_react()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
begin
  return null;
end $function$;
