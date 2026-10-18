alter table public.push_subs
  add column id bigint generated always as identity primary key,
  add column user_id uuid not null references public.profiles(id) on delete cascade,
  add column endpoint text not null unique,
  add column p256dh text not null,
  add column auth text not null,
  add column created_at timestamptz not null default now();
create index if not exists push_subs_user_idx on public.push_subs (user_id);
create policy "my push subscriptions" on public.push_subs for select to authenticated using (user_id = (select auth.uid()));
create policy "add push subscription" on public.push_subs for insert to authenticated with check (user_id = (select auth.uid()));
create policy "remove push subscription" on public.push_subs for delete to authenticated using (user_id = (select auth.uid()));

-- a push problem must never block the notification (and the like, comment or message behind it)
create or replace function private.push_notify() returns trigger language plpgsql security definer set search_path = '' as $$
declare u text; s text;
begin
  begin
    if not exists(select 1 from public.push_subs where user_id = new.user_id) then return new; end if;
    select value into u from private.config where key = 'push_url';
    select value into s from private.config where key = 'push_secret';
    if u is null or s is null then return new; end if;
    perform net.http_post(url := u, body := jsonb_build_object('id', new.id), headers := jsonb_build_object('Content-Type', 'application/json', 'x-push-secret', s));
  exception when others then
    raise warning 'push_notify skipped: %', sqlerrm;
  end;
  return new;
end $$;
