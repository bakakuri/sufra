-- 100 coins as a welcome gift to everyone who finishes signing up, and 100 to the friend who invited them
-- (who sent the link they came by). Both are paid when the new person finishes onboarding (profiles.onboarded
-- turns true), through the usual coin rules, so the admin can change or switch them off in the coin rules.
-- The invite counts only for a new account (made in the last 3 days), once per person, never for oneself;
-- at most 20 paid invites a day per inviter.
insert into public.coin_rules (action, page, label, hint, amount, every_n, day_cap, target_cap, once, uniq, in_max, active, pos) values
 ('welcome', 'coins', 'მისასალმებელი საჩუქარი', 'რეგისტრაციისას, ერთხელ', 100, 1, 0, 0, true, false, false, true, 0),
 ('invite', 'friends', 'მეგობრის მოწვევა', 'მეგობარი შენი ბმულით დარეგისტრირდა', 100, 1, 2000, 0, false, true, false, true, 61)
on conflict (action) do nothing;

create table if not exists public.referrals (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  inviter uuid references public.profiles(id) on delete set null,
  paid boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists referrals_inviter_idx on public.referrals (inviter);
alter table public.referrals enable row level security;
drop policy if exists "own referrals" on public.referrals;
create policy "own referrals" on public.referrals for select to authenticated
  using (inviter = (select auth.uid()) or user_id = (select auth.uid()));

-- pays the inviter of a new person once that person has finished signing up
create or replace function private.pay_referral(p_user uuid) returns void language plpgsql security definer set search_path to '' as $f$
declare r record; v int;
begin
  select * into r from public.referrals where user_id = p_user and not paid for update;
  if r.user_id is null or r.inviter is null then return; end if;
  if not exists (select 1 from public.profiles where id = p_user and onboarded and not banned) then return; end if;
  update public.referrals set paid = true where user_id = p_user;
  v := private.earn(r.inviter, 'invite', p_user::text, null);
  if v > 0 then perform public.notify(r.inviter, p_user, 'coins', jsonb_build_object('coins', v, 'note', 'შენი მოწვევით დარეგისტრირდა')); end if;
end $f$;

-- the link a new person came by: ?i=<username> or ?i=<id>
create or replace function public.claim_invite(p_code text) returns text language plpgsql security definer set search_path to '' as $f$
declare me uuid := auth.uid(); inv uuid; c text := trim(coalesce(p_code, ''));
begin
  if me is null then return 'not_signed_in'; end if;
  if exists (select 1 from public.referrals where user_id = me) then return 'already'; end if;
  if not exists (select 1 from public.profiles where id = me and created_at > now() - interval '3 days') then return 'not_new'; end if;
  if c ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then select id into inv from public.profiles where id = c::uuid and not banned;
  else select id into inv from public.profiles where lower(username) = lower(ltrim(c, '@')) and not banned limit 1; end if;
  if inv is null or inv = me then return 'no_inviter'; end if;
  insert into public.referrals (user_id, inviter) values (me, inv) on conflict do nothing;
  perform private.pay_referral(me);
  return 'ok';
end $f$;
revoke all on function public.claim_invite(text) from public, anon;
grant execute on function public.claim_invite(text) to authenticated;
revoke all on function private.pay_referral(uuid) from public, anon, authenticated;

-- finishing onboarding: the welcome gift, and the inviter's share
create or replace function private.trg_onboarded() returns trigger language plpgsql security definer set search_path to '' as $f$
declare v int;
begin
  if new.onboarded and not coalesce(old.onboarded, false) then
    v := private.earn(new.id, 'welcome', null, null);
    if v > 0 then perform public.notify(new.id, null, 'coins', jsonb_build_object('coins', v, 'note', 'მისასალმებელი საჩუქარი')); end if;
    perform private.pay_referral(new.id);
  end if;
  return null;
end $f$;
drop trigger if exists profiles_onboarded on public.profiles;
create trigger profiles_onboarded after update of onboarded on public.profiles for each row execute function private.trg_onboarded();
