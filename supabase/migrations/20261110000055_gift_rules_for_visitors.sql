-- the sign-in page can say "100 coins as a gift on sign-up" to someone who came by a friend's link:
-- visitors (not signed in) may read the two gift rules, and only while they are switched on.
create policy "gift rules for visitors" on public.coin_rules for select to anon using (action in ('welcome','invite') and active);
