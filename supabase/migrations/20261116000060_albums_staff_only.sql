-- Shared albums are made by the staff (admins and moderators) only, an event's album too; everyone else adds photos
-- to the ones they are in, and an owner still edits or removes their own. A person's own photos and albums are in
-- photos / photo_albums (migration 59).
drop policy if exists "create album" on public.albums;
create policy "create album" on public.albums for insert to authenticated with check (
  owner = (select auth.uid()) and public.can_post() and public.is_staff());
