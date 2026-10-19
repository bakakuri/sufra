-- read marks use the server clock, so "seen" compares cleanly with message times
create or replace function public.cm_seen() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'UPDATE' and new.last_read_at is distinct from old.last_read_at then
    new.last_read_at := greatest(coalesce(old.last_read_at, '-infinity'::timestamptz), now());
  end if;
  if coalesce((select privacy->>'read' from public.profiles where id = new.user_id), 'true') = 'false' then new.seen_at := null;
  else new.seen_at := new.last_read_at;
  end if;
  return new;
end $$;
revoke execute on function public.cm_seen() from public, anon, authenticated;
