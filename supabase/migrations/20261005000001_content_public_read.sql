-- Players can play without an account, so content releases must be readable
-- without signing in. (Before this, only signed-in players could see them,
-- and guests silently stayed on the content that shipped in the app.)
-- Content is public game data: item names, dialogue, numbers. Nothing private.
-- Note: this makes every row of content_versions (including "notes") and
-- every file in the "content" bucket readable by anyone, so keep both free of
-- anything internal, and upload a bundle only when it is ready to release.
-- Safe to run more than once.

drop policy if exists "Authenticated users can read content versions"
  on content_versions;
drop policy if exists "Anyone can read content versions" on content_versions;
create policy "Anyone can read content versions"
  on content_versions for select to anon, authenticated using (true);

drop policy if exists "Anyone can read content bundles" on storage.objects;
create policy "Anyone can read content bundles"
  on storage.objects for select to anon
  using (bucket_id = 'content');
