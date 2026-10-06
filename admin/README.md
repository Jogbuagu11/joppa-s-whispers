# Admin panel

`index.html`, `admin.js`, `admin_more.js`, `event_rules.js` and `admin.css` are the
whole admin panel: one page, no build step. `supabase.min.js` is supabase-js 2.45.4,
kept here so the page loads nothing from anywhere else. It signs in
to the game's Supabase project and only works for an account listed in the
`admins` table (see `supabase/migrations/20261006000002_admins.sql`).

- Events: create, edit, switch on/off and delete time-limited events.
- Content: release a content file built with `dart run tool/build_content_bundle.dart`.
- Notifications: send one push a day through the `send-push` function.

A copy is published with the website at `web/public/admin/index.html`
(served at `/admin`). In that copy only, `index.html` names its files from the site's root (`/admin/admin.js` …) so the page works whether or not the address ends in `/index.html`. After changing anything here, copy it
there again: `cp admin/*.js admin/*.css admin/index.html web/public/admin/` (a test,
`test/data/admin_panel_copies_test.dart`, fails if the copy is stale).

The event checks in `event_rules.js` mirror `lib/data/event_validator.dart`;
`deno test --allow-read admin/event_rules_test.ts` keeps them honest.

The page holds no secrets. The key in it is the public one that ships in the
game; everything an admin can do is enforced by the server.
