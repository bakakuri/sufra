-- online joker: when the host's app is gone, a player still at the table takes over running the game.
-- Allowed only at a joker table in play, to someone seated there, when the host named is still the host
-- and the table has not been written for 20 seconds (a host who is still there keeps writing it).
-- The new host can then read the hands and moves, as the host always could.
create or replace function public.jk_take_host(p_table bigint, p_old uuid)
returns boolean language plpgsql security definer set search_path to '' as $f$
declare t record;
begin
  select * into t from public.jk_tables where id = p_table for update;
  if t.id is null or t.status is distinct from 'play' or t.host is distinct from p_old or t.host = auth.uid()
     or not coalesce(auth.uid() = any(t.seats), false) or coalesce(t.state->>'g','joker') <> 'joker'
     or t.updated_at > now() - interval '20 seconds' then return false; end if;
  update public.jk_tables set host = auth.uid(), updated_at = now() where id = p_table;
  return true;
end $f$;
revoke all on function public.jk_take_host(bigint,uuid) from public, anon;
grant execute on function public.jk_take_host(bigint,uuid) to authenticated;
