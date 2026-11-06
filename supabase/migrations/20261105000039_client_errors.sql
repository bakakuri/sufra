-- Peera: what breaks on people's phones reaches the admin panel. Each phone sends an error once per visit
-- (at most a few), a person at most 30 an hour; staff read them, admins clear them, they go after 14 days.
create table if not exists public.client_errors (
  id bigint generated always as identity primary key,
  user_id uuid default auth.uid() references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  msg text not null check (char_length(msg) between 1 and 500),
  src text not null default '' check (char_length(src) <= 300),
  line int,
  col int,
  stack text not null default '' check (char_length(stack) <= 2000),
  page text not null default '' check (char_length(page) <= 200),
  ua text not null default '' check (char_length(ua) <= 300),
  ver text not null default '' check (char_length(ver) <= 20)
);
create index if not exists client_errors_time on public.client_errors (created_at desc);
create index if not exists client_errors_user_fk on public.client_errors (user_id);
alter table public.client_errors enable row level security;
create policy "report own errors" on public.client_errors for insert to authenticated with check (user_id = (select auth.uid()));
create policy "staff reads errors" on public.client_errors for select to authenticated using (public.is_staff());
create policy "admin clears errors" on public.client_errors for delete to authenticated using (public.is_admin());
revoke all on public.client_errors from anon;
revoke update on public.client_errors from authenticated;

-- more than 30 an hour from one person are dropped quietly
create or replace function public.trg_client_errors_cap() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if (select count(*) from public.client_errors where user_id = new.user_id and created_at > now() - interval '1 hour') >= 30 then return null; end if;
  return new;
end $$;
create trigger client_errors_cap before insert on public.client_errors for each row execute function public.trg_client_errors_cap();

create or replace function private.housekeeping()
 returns void language plpgsql security definer set search_path to '' as $function$
begin
  delete from public.messages where expires_at is not null and expires_at < now() - interval '2 minutes';
  update public.rooms set live = false, ended_at = now() where live and created_at < now() - interval '12 hours';
  update public.help_requests set status = 'resolved' where status = 'open' and expires_at < now();
  delete from public.client_errors where created_at < now() - interval '14 days';
end $function$;
