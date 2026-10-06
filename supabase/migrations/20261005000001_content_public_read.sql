-- Players can play without an account, so content releases must be readable
-- without signing in. (Before this, only signed-in players could see them,
-- and guests silently stayed on the content that shipped in the app.)
-- Content is public game data: item names, dialogue, numbers. Nothing private.

drop policy if exists "Authenticated users can read content versions"
  on content_versions;
create policy "Anyone can read content versions"
  on content_versions for select to anon, authenticated using (true);

create policy "Anyone can read content bundles"
  on storage.objects for select to anon
  using (bucket_id = 'content');
