# Whispers of Joppa — Progress

## Current milestone: 23 — Chapters 2–6, one at a time. Chapters 2–5 are built; Chapter 6 (the last of Season 1) is next. Milestones 14 and 16–22 are built and awaiting Jennifer's checks.

---

## Milestone status

| # | Milestone | Status |
|---|---|---|
| 0 | Project setup | DONE (m0-working) |
| 1 | Empty board | DONE (m1-working) |
| 2 | Drag & drop | DONE (m2-working) |
| 3 | Merging | DONE (m3-working) |
| 4 | Generators | DONE (m4-working) — approved by Jennifer 2026-10-05 |
| 5 | Content loading | DONE (m5-working) — approved by Jennifer 2026-10-05 |
| 6 | Energy (Manna) | DONE (m6-working) |
| 7 | Orders | DONE (m7-working) |
| 8 | Save/load (local) | DONE (m8-working) |
| 9 | Story scenes | DONE (m9-working) |
| 10 | Tasks & Blessings | DONE (m10-working) |
| 11 | Restoration scenes | DONE (m11-working) |
| 12 | Chapter 1 playable | DONE (m12-working) |
| 13 | Esther's letters | DONE (m13-working) |
| 14 | Accounts + cloud save | BUILT — not tagged: real sign-in not yet verified |
| 15 | Server-driven content | DONE (m15-working) — verified against the live server |
| 16 | IAP: buy & deliver | BUILT — not tagged: needs store products and a sandbox purchase by Jennifer |
| 17 | IAP: restore & refunds | BUILT — not tagged: functions deployed; needs store keys on the server and real purchase + refund tests by Jennifer |
| 18 | Rewarded ads | BUILT — not tagged: a real (test) ad has not yet been watched on a phone |
| 19 | Firebase: analytics + crash reporting | BUILT — not tagged: Jennifer has not yet confirmed events and a test crash in the Firebase console |
| 20 | Notifications | BUILT — not tagged: no real notification has been seen on a phone; push needs Jennifer's Apple push key |
| 21 | Events system | BUILT — not tagged: the Joppa Boat Festival is live on the server (to 2026-10-27); Jennifer has not yet seen it on a phone |
| 22 | Admin panel | BUILT — not tagged: Jennifer has not yet signed in and used it; push needs the Firebase key on the server |
| 23 | Chapters 2–6 | IN PROGRESS — Chapters 2–5 built (not tagged: Jennifer has not played them). Chapter 6 to do |
| 24 | Polish & accessibility | Not started |
| 25 | Release builds | Not started |

---

## What's done (Milestone 0)

- Flutter project created with bundle ID `com.whispersofjoppa.game`
- All packages added with exact pinned versions (no `^`)
- Folder structure matches TECH_SPEC.md
- `analysis_options.yaml` with strict-casts, strict-inference, strict-raw-types
- `lib/app/config.dart` with Supabase URL + anon key (app-safe)
- `lib/main.dart` — initializes Supabase + Riverpod, runs app
- `lib/app/app.dart` — MaterialApp, portrait lock
- `lib/game/board/board_screen.dart` — blank board screen (Key: 'board_screen')
- `integration_test/smoke_test.dart` — confirms board screen appears
- `.claude/settings.json` — PostToolUse hook runs flutter analyze
- `.claude/agents/` — test-runner, code-reviewer, content-writer
- `content/` — all placeholder JSON files
- `.gitignore` — secrets, service account JSON, .env, keystore excluded
- GitHub repo: https://github.com/Jogbuagu11/joppa-s-whispers.git

## Packages (pinned versions)

| Package | Version |
|---|---|
| flame | 1.38.2 |
| flame_audio | 2.12.2 |
| flutter_riverpod | 3.4.3 |
| supabase_flutter | 2.18.0 |
| in_app_purchase | 3.3.1 |
| google_mobile_ads | 9.1.0 |
| firebase_core | 4.15.0 |
| firebase_crashlytics | 5.4.0 |
| firebase_analytics | 12.6.0 |
| firebase_messaging | 16.7.0 |
| flutter_local_notifications | 22.3.1 |
| timezone | 0.11.1 |
| path_provider | 2.1.6 |
| sign_in_with_apple | 8.2.0 |
| google_sign_in | 7.2.0 |
| logging | 1.3.0 |

## Assumptions to confirm

- Bundle ID `com.whispersofjoppa.game` used as given (SETUP_CHECKLIST says to choose one — Jennifer provided it).
- App Store App ID `6819075333` noted. Xcode signing will be set up when Jennifer signs in to Xcode with her Apple ID (SETUP_CHECKLIST Phase 3).
- Firebase config files (GoogleService-Info.plist and google-services.json) are in the project root — they need to be moved to the correct platform folders at Milestone 19 when Firebase is wired up.
- The Firebase service account JSON in the project root (`whispers-of-joppa-firebase-adminsdk-fbsvc-e2d2604c8c.json`) is excluded from git and will be stored as a Supabase Edge Function secret at Milestone 19.
- `flutterfire configure` will be run at Milestone 19 to generate proper Firebase config files.

## Machine move (2026-10-04)

The project folder was copied to a new Mac (user `mini`) with no build tools, no git
history, no `assets/` folder, and no root `CLAUDE.md`.

- Restored from the GitHub backup: `assets/` (121 files), `CLAUDE.md`, iOS Google client plist.
- Flutter 3.44.0 (same version as before) installed at `~/development/flutter`.
- `.claude/settings.json` hook no longer points at the old Mac's folder.
- Git history re-attached from GitHub (2026-10-05); `m0-working`…`m3-working` tags recreated locally (not pushed).

## Milestone 4 — state (2026-10-05)

DONE. Verified on the iOS Simulator (iPhone 17, iOS 26.5) AND the Android Emulator
(Pixel 9, API 36): analyze clean, 41 unit tests pass, smoke test passes, generator tap
test passes, board seen on screen on both, generator taps seen spawning items on Android.
Code review run; its two blocking findings are fixed (no unexplained `!`; generator-tap
rules moved into tested `resolveGeneratorTap` in `lib/domain/generator.dart`).

Carried forward from the code review (not blocking):
- Starting Manna (10), generator placements and starter items are set in
  `board_screen.dart` as temporary setup → move to content in Milestones 5/6.
- `generator_tap_test.dart` checks the Manna count only and assumes the current layout;
  rework when placements come from content (M5).
- Energy cost exists in both `generators.json` and `economy.json`; pick one before M6.
- Generators are looked up by ID; needs a per-tile ID before generators can merge.
- `board_game.dart` is 271 lines; split drag handling out before it reaches 300.
- `supabase/.temp/cli-latest` is tracked in git and should be ignored.
- Fruit item art is JPEG (~500 KB each); TECH_SPEC asks for 256×256 transparent PNG.

Fixed while getting it running:
- `content/generators.json`: level 4 and 5 odds added up to more than 100%, so tier-3
  items could never spawn. Now match GDD section 5 (L4: 70/25/5, L5: 60/30/10).
- Board showed a red error at launch (starter items placed before the board was built).
  Items are now queued until the board is ready.
- Smoke test passed even with that error on screen, and hung once the board really ran.
  It now also requires the board itself to be visible with no error.
- New `integration_test/generator_tap_test.dart`: tapping a generator spends 1 Manna.
- Manna counter sat under the status bar; generator names spilled out of their tiles.
- iOS project: bundle ID was `com.whispersofjoppa.whispersOfJoppa`, now
  `com.whispersofjoppa.game` (confirmed by Jennifer); minimum iOS raised 13 → 15
  (required by Firebase); `build/` excluded from analysis.

## Assumptions to confirm (added 2026-10-05)

- iOS `Info.plist` uses Google's public **test** AdMob app ID (same approach as Android)
  because the ads library closes the app at launch without one. Replace with the real
  ID at Milestone 18.
- Minimum iOS version is now 15.0.

## Milestone 5 — state (2026-10-05)

DONE. Verified on the iOS Simulator and Android Emulator: analyze clean, 62 unit tests
pass, content validator reports "Content OK", smoke test and generator tap test pass on
both, board seen on screen on both. Code review run; its three blocking findings are fixed.

What moved out of code and into content:
- Starting Manna, generator positions and starter tiles → `content/starting_board.json`.
- Placeholder tile colours → `placeholder_color` in `content/chains.json`.
- Item sell values now read from `sell` in `chains.json`; the order reward multiplier is
  `order_talents_per_tier` in `content/economy.json`.
- New content checker: `lib/data/content_validator.dart`, run by
  `dart run tool/validate_content.dart` and by the unit tests.
- TECH_SPEC section 3 now documents the two new formats.

Resolved from the Milestone 4 carry-forward list: starting Manna/placements/starter items
in content; `generator_tap_test.dart` reads the layout from content.

Carried forward (not blocking):
- `tool/process_assets.dart` (asset pipeline) is NOT built: it needs an image-processing
  package, and new packages need Jennifer's approval. Real item art is not shown yet.
- The validator covers the 4 content files the game loads today (chains, generators,
  economy, starting_board). The other 8 are still empty; add checks as each is used.
- The validator is not run when the app loads content; wire it in before server content (M15).
- Starter-item placement on the board has no unit test of its own (covered by device tests).
- Generators always start at level 1; add a level to `starting_board.json` when needed.
- TECH_SPEC "Pinned versions" table is still empty (versions are listed above in this file).
- `supabase/.temp/cli-latest` is tracked in git; fruit art is JPEG, spec asks for PNG.

## Assumptions to confirm (added in Milestone 5)

- A new player starts with **10 Manna**. The GDD gives the maximum (100) but no starting amount.
- The three starter tiles are test scaffolding, to be replaced by the Chapter 1 tutorial (M12).
- New content formats: `starting_board.json`, `placeholder_color`, `order_talents_per_tier`.

## Milestone 6 — state (2026-10-05)

DONE. Verified on the iOS Simulator and Android Emulator: analyze clean, 81 unit tests
pass, content validator OK, smoke / generator tap / out-of-Manna tests pass on both, and
the bar and popup were seen on screen.

- Manna bar (count, progress bar, "+1 in m:ss" countdown) replaces the plain counter.
- Manna regenerates +1 every `manna_regen_seconds` up to `max_manna` (both from economy.json).
- Tapping a generator with too little Manna shows an "Out of Manna" popup; nothing is spent.
- Tap cost now has one source: `generator_tap_cost` in economy.json. A generator may
  override it with its own `energy_cost` (none do today).
- Drag handling moved to `board_game_drag.dart`; `board_game.dart` is back to ~213 lines.

Carried forward from the code review (nothing blocking):
- Move Manna state to a Riverpod provider outside `game/board` before Orders/Save need it.
- `out_of_manna_test.dart` assumes the starting bar is not full and that the taps fit on
  the board; rework if starting Manna changes a lot.
- The Manna bar may overlap the top-right cell on tablet-shaped screens (not checked).
- Theme colours are repeated in several files; collect them in `lib/app`.

Not in this milestone:
- Manna is not saved between app launches yet (Milestone 8), so it resets to the starting
  amount each time the app is opened.
- The popup has no "refill with Pearls" or "watch an ad" buttons yet (Milestones 16 and 18).
- The popup and bar wording is written in code, not in content; move it if a strings
  file is introduced.

## Milestone 7 — state (2026-10-05)

DONE. Verified on the iOS Simulator and Android Emulator: analyze clean, 138 unit tests
pass, content validator OK, four device tests pass on both (smoke, generator tap,
out-of-Manna, orders), and the order cards were seen on screen.

- Up to 3 order cards (`order_slots` in economy.json) above the board: who is asking, what
  they say, the items wanted with how many you have, the reward, Deliver and Skip.
- Deliver is only active when the board holds every item; it removes them, pays Talents
  and Blessings, and the next order takes the card.
- Skip swaps an order for the next one, once per `order_skip_cooldown_seconds` (30 min).
- 12 Chapter 1 orders and 17 characters written by the content-writer agent into
  `content/orders.json` and `content/characters.json`; both are checked by the validator
  (talents must equal 5 × item tiers, text ≤ 140 characters, items unlocked, and so on).
- Talents and Blessings counters top-left.

Content notes for Jennifer's reviewer (flagged "REVIEW:" by the content writer):
- ch1_o_003: "That takes more love than fear" alludes to 1 John 4:18 without quoting it.
- ch1_o_003/006/009/011 use the plain words love, joy, peace, patience (no "Fruit of the Spirit").
- ch1_o_006: "Papa says I'm his joy" plays on the child's name and the Joy item.
- ch1_o_012: "the widows' table" means care for widows, not communion.
- Two spiritual orders are Naomi speaking to herself (the story bible gives her Love and
  Patience in Chapter 1). Elder Amos appears in the last order before his story entrance.

Carried forward from the code review (its two blocking findings are fixed):
- The Skip button does not reappear by itself when the 30 minutes are up (it does on the
  next board change), and there is no countdown shown for it.
- Story order: the bible gives Naomi a Kindness order in Chapter 1 that is not written yet,
  and some orders are visible before their character's story entrance. Sort out when the
  tutorial gates orders in Milestone 12.
- "1–3 items" is read as 1–3 different items; an order may ask for 2 of each.
- The 140-character limit, 1–3 items and 1–3 blessings rules live in the validator code.

Not in this milestone:
- Portraits on cards (a coloured initial for now; character art names need fixing first).
- The story moment after a spiritual order (`scene_id`; Milestone 9).
- Jar of Clay rewards; doubling a reward with an ad (Milestone 18).
- Talents, Blessings and order progress are not saved between launches (Milestone 8).
- When all 12 orders are delivered the cards simply run out (more come with Chapter 1, M12).
- Manna, orders and wallet are plain ChangeNotifier controllers, not Riverpod providers yet.

## Milestone 8 — state (2026-10-05)

DONE. Verified on the iOS Simulator and Android Emulator: analyze clean, 163 unit tests
pass, five device tests pass on both (smoke, generator tap, out-of-Manna, orders,
save/load), and on Android the app was force-closed and reopened with the board, Manna,
Talents, Blessings and order cards exactly as left.

- `save.json` in the app documents folder holds: every item and generator with its cell,
  Manna and its regen clock, Talents, Blessings, the order cards and queue, and a
  `save_version`.
- Written 2 seconds after any change (one write per burst) and at once when the app goes
  to the background. Written to a temporary file and swapped in, so a crash mid-write
  cannot damage the save.
- Manna that regenerated while the app was closed is added on reopening.
- A damaged save is set aside as `save.corrupt.json` and a new game starts; a save from a
  newer app version is not loaded. Anything in a save that the content no longer knows
  (an item, generator or order) is dropped instead of crashing.
- `migrateSave` is where format changes go. The format is at version 2 (version 2 added
  the list of delivered orders; version 1 saves are upgraded on load).
- Orders added to content later join the queue of an existing save; a card left empty by
  a removed order is refilled; a generator lost from a save is put back from the starting
  board. A burst of changes is written within 10 seconds at most.
- A save that cannot be read is kept as `save.corrupt.<time>.json`.
- `BoardSession` now assembles the game (content + save + board + Manna + orders + saver).

Carried forward from the code review (its blocking finding, missing restore tests, is fixed):
- After an unreadable save, the new game overwrites `save.json` about 2 seconds later
  (the bad file is kept aside first). Consider asking the player instead.
- Manna is capped at the maximum on load; revisit if bought/ad Manna may exceed 100 (M18).
- The clock can be set forward for free Manna; use server time once accounts exist (M14).
- Leaving the board screen does not wait for the last write; matters once there are
  several screens (Milestone 9 onwards).
- The true force-close check was done by hand on Android only.

Not in this milestone:
- Basket, chapter/task progress, discovered items, letters, crowns and settings are not in
  the save yet because those features do not exist yet; add each with its milestone and
  bump `save_version` when the format changes.
- Cloud save (Milestone 14).
- No "start over" button; clearing the app's data starts a new game.

## Milestone 9 — state (2026-10-05)

DONE. Verified on the iOS Simulator and Android Emulator: analyze clean, 180 unit tests
pass, content validator OK, six device tests pass on both (smoke, scene, generator tap,
out-of-Manna, orders, save/load), and the opening scene was seen on screen on both.

- Scene screen: the speaker's portrait in a framed card, their name, the line in a speech
  bubble, tap anywhere for the next line, Skip top-right. The portrait changes with each
  line's speaker and expression (falls back to neutral, then to no picture).
- 13 Chapter 1 scenes (121 lines) written by the content-writer agent into
  `content/scenes.json`, one or two per story beat, ending on the Chapter 1 cliffhanger.
- A brand-new game opens with the scene named by `opening_scene` in
  `content/starting_board.json` (ch1_s_01), then shows the board.
- The validator checks scenes: known speakers, expressions each character has, text ≤ 140
  characters, `loc_` backgrounds, unique ids.

Content notes for Jennifer's reviewer (flagged "REVIEW:" by the content writer):
- ch1_s_03b quotes 1 John 4:18 (KJV) as the story bible's Letter 1 specifies, but the
  bible's own period rule says Esther's letters quote only the Hebrew Scriptures or
  sayings of Jesus (1 John was not written by AD 40). Kept as the bible says; needs a
  decision. The same echo is in order ch1_o_003.
- ch1_s_09b splits Lamentations 3:22–23 (KJV) over two bubbles, each with its own citation.
- ch1_s_03b: "I am already Home" and Naomi speaking to Esther in grief (not prayer).
- ch1_s_04: "I'd answer to Mara" alludes to Ruth 1:20 without quoting.
- ch1_s_03a: an invented saying for Esther ("Small things joined make bigger things").
- ch1_s_11: Amos neither confirms nor denies theft, so he does not lie.

- ch1_s_06: Naomi says "Patience, Naomi. And peace enough not to bite." — ordinary words,
  not naming the Fruit of the Spirit chain.

Carried forward from the code review (its blocking finding, an over-long test file, is fixed):
- Scene backgrounds are looked up as `assets/locations/bg_<background id>.png|webp|jpg`.
- "Opening scene only on a new game" is covered by reading the code, not by a test.
- Android back / iOS swipe dismiss a scene the same as Skip; Milestone 10 must tell
  "finished" from "dismissed" if finishing a scene has consequences.
- Portrait file naming is written in two places (`asset_names.dart`, `scenes.dart`).
- In ch1_s_07 several lines share the single Dock Worker speaker.

Not in this milestone:
- Only the opening scene plays so far. The other 12 scenes are triggered by story tasks
  (Milestone 10) and spiritual orders.
- No location art: scenes use a warm dusk wash until `assets/locations/bg_<background>.png`
  files exist (5 backgrounds are named: harbor dusk, bakehouse outside and inside,
  rooftop night, market).
- No portrait for the Dock Worker, Simon or Tobiah (no art); they show name and words only.
- Portraits are opaque white-background pictures, so they are shown in a framed card.
- Quitting during the opening scene replays it next launch (nothing is saved until the
  first change on the board).

## Milestone 10 — state (2026-10-05)

DONE. Verified on the iOS Simulator and Android Emulator: analyze clean, 214 unit tests
pass, content validator OK, seven device tests pass on both (smoke, scene, tasks,
generator tap, out-of-Manna, orders, save/load), and the task bar was seen on screen.

- Task bar above the orders: chapter name and progress (0/12), the next task's title, and
  a button showing its cost in Blessings. The button is active only when affordable.
- Doing a task spends the Blessings, marks it done, plays its scene, and the next task
  appears. Tasks are done strictly in story order.
- Chapter 1 has 12 tasks (`content/chapters.json`), costing 18 Blessings in total; the 12
  orders pay 19. The validator refuses a chapter whose tasks cost more than its orders pay.
- Task progress is saved (save format version 3; older saves are upgraded).
- `content/locations.json` (7 bakehouse areas) and `content/letters.json` (Esther's two
  Chapter 1 letters) are written and validated, ready for Milestones 11 and 13.

Decisions:
- Blessings are spent when the task button is tapped, before its scene plays, so skipping
  or backing out of a scene never loses or duplicates anything.
- One task (ch1_t_06) was lowered from 2 to 1 Blessing so the chapter has 1 to spare.
- `crown_id` for Chapter 1 is null: the story bible awards the Imperishable crown after
  Chapter 2 (the GDD says "Ch. 1–2").

Open question for Jennifer's reviewer:
- The story bible contradicts itself on Letter 1: section 1 says Esther's letters quote only
  the Hebrew Scriptures or sayings of Jesus, but Letter 1 quotes 1 John 4:18. The content
  follows the letter as written. If it changes, `content/letters.json`, scene `ch1_s_03b`
  and order `ch1_o_003` change together.

Carried forward from the code review (nothing blocking):
- The Blessings margin is 1 (orders pay 19, tasks cost 18): any change to Chapter 1 orders
  or tasks must keep orders ≥ tasks (the validator enforces it).
- Theme colours are repeated across several files; collect them in `lib/app`.
- No widget test for the task bar's "Chapter complete" state (covered at controller level).

Not in this milestone:
- Restored areas are recorded but not shown yet (Milestone 11); letters found are recorded
  but there is no keepsake book yet (Milestone 13).
- 12 tasks, not the GDD's 30–40 per chapter: more tasks need more orders and scenes
  (Milestone 12, "Chapter 1 playable").
- Finishing the chapter just shows "Chapter complete"; no crown or chapter-end screen.
- Blessings still live in the orders controller; a separate wallet is tidier.

## Milestone 11 — state (2026-10-05)

DONE. Verified on the iOS Simulator and Android Emulator: analyze clean, 219 unit tests
pass, content validator OK, eight device tests pass on both (smoke, scene, tasks,
restoration, generator tap, out-of-Manna, orders, save/load), and the location screen was
seen on Android with the Doorway restored.

- Location screen ("Esther's Bakehouse"): one card per area showing its before picture
  until its task is done, then its after picture, with "Not yet" / "Restored" and a count
  ("1 of 7 restored"). An area just restored is shown in its old state first and then
  fades to the new one in front of the player.
- Opens from the building button on the task bar, and by itself after a task that
  restores an area, so the player sees the change.
- Art is looked up as `assets/locations/<image id>.png|webp|jpg` using the before/after
  ids in `content/locations.json` (for example `loc_bakehouse_door_after.png`).

Not in this milestone:
- No location art exists yet. Each area shows a grey "under repair" tile before and a
  warm sunlit tile after. Dropping the 14 pictures (7 areas × before/after) into
  `assets/locations/` with the names above makes them appear with no code change.
- The spec describes one full-screen location picture with areas swapped inside it; this
  screen shows the areas as separate cards, which works without knowing where each area
  sits in a larger picture. Revisit when the art exists.
- Wording on this screen ("Restored", "Not yet", "N of M restored", "Back to the
  rooftop", "See what you have restored") is in code.
- Location art may be `.jpg` as well as the spec's PNG/WebP (same as scene backgrounds).
- A finished chapter's location cannot be revisited from the button once the next
  chapter starts (matters from Milestone 23).

## Milestone 12 — state (2026-10-05)

DONE. Verified on the iOS Simulator and Android Emulator: analyze clean, 263 unit tests
pass, content validator OK, nine device tests pass on both (smoke, scene, tutorial, tasks,
restoration, generator tap, out-of-Manna, orders, save/load), and the first tutorial hint
was seen on screen.

From first launch a new player now gets:
1. The opening scene at the harbor.
2. Six tutorial hints from Silas and Naomi above the board (`content/tutorial.json`):
   merge two barley sheaves, tap Grandma's Pantry, make and deliver Silas's flatbread,
   spend the first Blessing on the doorway, deliver Love, then a hand-off.
   A hint goes away when the player does what it asks; hints for things already done are
   skipped. Generator taps are free during the first three hints.
3. 12 orders, 12 story tasks with their scenes, and the bakehouse restoring area by area.
4. A closing message when the last task is done (`content/endings.json`).

- A test plays the whole chapter with the real rules and content
  (`test/data/chapter_playthrough_test.dart`): every order can be made with the generators
  the player has, fits on the board, and the Blessings always cover the next task.
- Tutorial progress is saved (save format version 4; older saves skip the tutorial).

Decisions:
- The tutorial guides rather than forces: the player can do other things, and nothing can
  get stuck. The GDD says "forced merge"; a locked-down version can be added later.
- Free generator taps are given only on the first three hints and only 12 in total
  (`tutorial_free_taps` in economy.json; a flatbread needs 8). After that taps cost Manna
  even if the player never finishes the tutorial.
- Orders cannot be skipped until the tutorial is over, so its orders stay on screen.
- A chapter's closing message is shown once; if the app closes before it appears, it is
  shown at the next launch.
- Chapter 1 needs about 162 generator taps in all; with 100 Manna to start and 1 back
  every 2 minutes, a player finishes it over a couple of sessions.

Content notes for Jennifer's reviewer (flagged "REVIEW:" by the content writer):
- tut_love has Naomi say "Tree of Life" and call the glowing fruit "Love" (never "Fruit of
  the Spirit"). Confirm that is fine for a tutorial hint.
- "A Blessing for one flatbread" / "Fill orders for Blessings" could read as blessings
  earned by works; wording follows the GDD's currency name.
- Scene order: the tutorial happens on the rooftop board before task 1's scene, which ends
  with Silas inviting Naomi up to the roof.

Carried forward from the code review (its blocking finding, unlimited free Manna, is fixed):
- The tutorial device test covers the first two hints (merge, generator tap, free tap).
  The later hints are covered by unit tests of the rules and controller, not on a device.
- The tutorial position is saved as a step number; save the step id before tutorial
  content can change after launch (Milestone 15).
- Android back closes the chapter-ending message like its button does.
- The playthrough test proves Blessings and board space; it does not model Manna.
- `content_validator.dart` is close to 300 lines; split before adding to it.

Not in this milestone:
- No device test plays the entire chapter by hand gestures (the rules-level playthrough
  test covers completability; device tests cover each step type).
- No pointing hand or highlight on the thing to tap; hints are text only.
- The GDD's 30–40 tasks per chapter, Kindness order, Jars of Clay and rubble cells are not built.
- Analytics events `tutorial_step` / `tutorial_complete` come with Milestone 19.

## Milestone 13 — state (2026-10-05)

- Keepsake book ("Esther's Letters"), opened from the envelope button on the task bar:
  one page per letter in story order, "N of M found". A letter not yet found is a locked
  page; a found letter shows its title and opens on a parchment page with the full text
  and its scripture reference.
- A letter is found when the task that reveals it is done (`letter_id` in
  `content/chapters.json`): Letter 1 at task 3 (the oven niche), Letter 2 at task 10
  (the loose brick). Nothing extra is saved: found letters follow from task progress.
- `content/letters.json` holds the two Chapter 1 letters word for word from the story
  bible (1 John 4:18 KJV; Lamentations 3:22–23 KJV).

Verified on the iOS Simulator and Android Emulator: analyze clean, 270 unit tests pass, content
validator OK, ten device tests pass on both (the nine from Milestone 12 plus letters).
The code review found nothing blocking.

Carried forward from the code review:
- The scripture reference shows twice on a letter page (inside the letter as the story
  bible writes it, and again as the citation line).
- TECH_SPEC section 4 lists "letters found" in the save; they are derived from finished
  tasks instead, so nothing separate needs saving or syncing.
- Loading content twice in one run would duplicate list-type content (letters, orders,
  chapters); make the loader clear its lists before Milestone 15 re-loads content.
- Locked letter pages use low-contrast grey text (Milestone 24 accessibility pass).

Not in this milestone:
- The book does not open by itself when a letter is found (the scene already reads the
  letter aloud); a "new letter" badge on the envelope button would help.
- Letters for Chapters 2–6 come with those chapters (Milestone 23).
- The Letter 1 scripture question (1 John vs the story bible's period rule) is still open.

## Milestone 14 — state (2026-10-05)

BUILT, NOT TAGGED. Analyze clean, 311 unit tests pass, eleven device tests pass on the iOS
Simulator and Android Emulator. The account flow is tested end to end with stand-in
sign-in and cloud services. **No real account has signed in yet**, so `m14-working` is
not tagged until one has.

What is built:
- Account screen (person button, top-left of the board): email + password sign-in and
  sign-up, Continue with Google, Continue with Apple (iPhone only), Sync now, Sign out,
  Delete account (with a confirmation step).
- Playing without an account still works exactly as before.
- Cloud save in the Supabase `saves` table: checked at launch and at sign-in; new local
  saves are uploaded while playing (at most every 20 seconds).
- Sync rule (TECH_SPEC section 4): whichever side changed since the last sync wins; a new
  phone with an unplayed game takes the account's game; if both moved on, the player is
  shown both and chooses.
- Account deletion calls the deployed `delete-account` function, then signs out.
- Google client IDs are in `lib/app/config.dart` and `ios/Runner/Info.plist`.

Live backend checked (read-only) on 2026-10-05:
- Email, Google and Apple providers are ON. Sign-ups are allowed.
- **Email confirmation is required**: a new email account must click the link in the
  confirmation email before it can sign in.
- The `saves` table and the `delete-account` function respond.

Still needed before real sign-in can be verified:
- **Email:** Jennifer creates an account in the app with a real address and clicks the
  confirmation link (or turns off "Confirm email" in Supabase for testing).
- **Google on Android:** Google Cloud needs an Android OAuth client for package
  `com.whispersofjoppa.game` with this Mac's debug fingerprint (SHA-1)
  `80:19:37:CF:28:68:3B:9A:BA:9F:CA:C9:E8:D4:0C:16:3D:B8:DF:6C`. The release and Play
  signing fingerprints are added later (SETUP_CHECKLIST Phase 4/5).
- **Google on iPhone:** should work as is; needs a real Google account to try.
- **Apple:** needs the Apple Developer Program, the "Sign in with Apple" capability on
  the App ID, and Jennifer's Team selected in Xcode. The entitlement is not added to the
  project yet because adding it without a Team breaks device builds.

Fixed after the code review (it found two ways a cloud save could be silently lost):
- Uploads while playing are now conditional: the cloud refuses a save if another phone has
  saved since this phone last synced, and this phone then compares again instead.
- An unplayed game on the phone (new phone, or a lost or reset save) never replaces real
  progress in the cloud; the cloud game is brought down instead.
- Coming back to the app re-checks the account; leaving the app sends the latest save.
- A game brought from the account is only recorded as "held" after it is written to the
  phone; if that write fails the old game stays and the player is told.
- Switching or deleting the account clears what the phone assumed about being in step.
- Device tests switch accounts off (`WhispersApp.accountsEnabled = false`) so a test run can
  never sign in to, or change anything in, the live backend.

Carried forward from the code review:
- When Apple sign-in goes live, account deletion must also revoke the Apple token
  (App Store guideline 5.1.1(v)).
- Signing out then into a different account with no cloud save uploads the game on the
  phone to that account without asking (nothing is lost; matters on a shared phone).
- The "has my game changed" check compares the whole save; a content or save-format update
  can make it look changed and cause an unnecessary "which game?" question.
- `SupabaseAuthService` and `SupabaseCloudSaveStore` have no automated tests (they need the
  real backend); the app-side flow is tested with stand-ins.
- The account link is a static in `lib/app/app.dart`; a Riverpod provider would be tidier.

Decisions:
- Sign-in is optional and never shown at launch.
- Apple and Google sign-in do not use a nonce (Supabase's "Skip nonce checks" is on for
  Google); add one with the `crypto` package if wanted.
- Signing out leaves the game on the phone.
- Letters found are not stored separately in the cloud: they follow from task progress.

Not in this milestone:
- No password reset or "resend confirmation email" button.
- Uploads are throttled, not guaranteed on app close; the next launch syncs.
- The clock used for Manna and order-skip is still the phone's, not the server's.

## Milestone 15 — state (2026-10-05)

DONE. Analyze clean, 351 unit tests pass, eleven device tests pass on the iOS Simulator and
Android Emulator, and it was verified end to end against the live server on 2026-10-05:
a test release (version 2, same content) was published; the real app on Android logged
"Using content v1" then "Downloaded content v2 for next launch", and after a full close
the next launch logged "Using content v2".

Live server state:
- Migration `20261005000001_content_public_read` is applied (guests can read releases).
- Release 2 is published: file `content_v2.json` in the `content` bucket and a row in
  `content_versions`. The app itself still ships version 1, so every install of this
  build downloads version 2 once. The next real release must be version 3 or higher.

Fixed after the code review (it found two serious problems):
- Content that passes the checks but will not actually load can no longer lock a phone on
  an error screen: downloads are test-loaded before being kept, and if downloaded content
  ever fails at launch it is deleted and the app's own content is used.
- Saves now record the content version they were played with. A phone running older
  content refuses to take over or upload such a game (it would have to drop the parts it
  does not know) and tells the player to restart the app instead.
- The validator now checks two fields the loader needs (location name, order scene_id).

What is built:
- All content is treated as one bundle with a version (`content/version.json`, now 1).
- At launch the game uses downloaded content if it is newer than the app's own AND passes
  every content check; otherwise the app's own content. A bad or damaged download is
  deleted and ignored. A bad content release can never crash the game.
- After the board is up, the app asks the server (`content_versions` table) whether a newer
  release exists; if so it downloads the bundle from the `content` storage bucket, checks
  it, and keeps it for the NEXT launch (content never changes under a game in progress).
- `dart run tool/build_content_bundle.dart` validates `content/` and writes
  `build/content/content_v<version>.json`, the file to upload for a release.

To release new content (until the admin panel exists, Milestone 22):
1. Edit files in `content/`, raise `version` in `content/version.json`.
2. Run `dart run tool/build_content_bundle.dart` (it refuses if anything is wrong).
3. Upload the file to the Supabase `content` storage bucket.
4. Add a row to `content_versions` with that version and the file's path.


Decisions:
- New content applies from the next launch, not mid-game.
- Only JSON content is delivered this way; new art still ships in an app update.
- `format` in the bundle lets a future app refuse content made for a newer version.

Not in this milestone:
- Downloading new art with a release.
- Telling the player that new content is ready, or forcing a restart.
- Recalling a release: phones that already downloaded it keep it, so publish a higher
  version with the fix rather than deleting the row.
- A release is not compared with the previous one: removing or renaming an order, task or
  item id erases that progress for players. Never remove or rename shipped ids.
- A rejected release is downloaded and checked again at every launch until replaced.
- No size limit on a download; it is checked on the main thread at launch.
- Anyone can read `content_versions.notes` and every file in the `content` bucket.

## Milestone 16 — state (2026-10-05)

BUILT, NOT TAGGED. Analyze clean, 401 unit tests pass, twelve device tests pass on the iOS
Simulator and Android Emulator, and the real app launches on both with the real store
service attached. The whole purchase flow is tested with a stand-in store and server.
**No real purchase has been made.** CLAUDE.md requires a sandbox purchase on a real device
by Jennifer before purchase code counts as working, so `m16-working` is not tagged.

What is built:
- Pearl shop (tap the Pearls count on the board): the store's own product titles and
  prices, exactly what each product gives, Buy, and Restore purchases. It is not offered
  until the tutorial is over (GDD: no purchase offers in the tutorial).
- Pearls are a third currency in the wallet and in the save (save format version 5).
- The purchase rule, enforced in `lib/app/purchase_coordinator.dart` and unit tested:
  1. the store reports a purchase;
  2. it is sent to the `verify-purchase` server function;
  3. the app then reads the purchases the server has recorded for THIS player and puts
     in the game only those not already applied (each transaction id once, kept in the
     save);
  4. only then is the store told the purchase is finished.
  The store's on-device word, and even the server's reply, are never enough alone.
- Interrupted purchases: at every launch and return to the app, unfinished store
  purchases are re-checked and anything the server holds for the player is delivered.
- A rejected or unverifiable purchase grants nothing and is left unfinished for retry.
- The starter pack gives Pearls and Manna and raises generators to level 2; it can be
  bought once.
- Products are in `content/products.json` (now validated and part of the content bundle).

Decisions:
- **Buying needs an account.** The server records purchases against a player, so a
  signed-out player is asked to sign in before the payment sheet opens. (Supabase
  anonymous sign-in could remove that step later.)
- The starter pack's "level-2 generator" raises the generators already on the board to
  level 2, because generators are not yet loose items that can be handed out.
- Bought Manna may go above the 100 bar; the bar just stops refilling until it is used.
- On Android a Pearl pack is consumed by the app after the server confirms it. TECH_SPEC
  says the server function should consume it; the deployed function does not.
- The app's own content is now version 3 (products added), newer than test release 2 on
  the server, so this build ignores that release. The next real release must be 4+.
- Added `in_app_purchase_android 0.5.3` to pubspec (it was already installed as part of
  `in_app_purchase`; it is needed to consume a Google Play purchase).

Needed before this can be verified for real (SETUP_CHECKLIST Phases 2 and 4):
- Apple: Paid Applications Agreement active, products `pearls_tier1`…`pearls_tier6` and
  `starter_pack` created in App Store Connect, a sandbox tester, the In-App Purchase key
  stored as a Supabase secret, and signing with Jennifer's Team.
- Google: the app uploaded to Internal testing, the same products created, license
  testers added, and the Play service account stored as a Supabase secret.
- Then Jennifer buys each product once on a real phone.

Code review (2026-10-05) and what was done about it:
- It found the deployed `verify-purchase` function unsafe: on Android one paid purchase
  could be replayed for unlimited Pearls (the transaction id was taken from the app, not
  from Google), and on iPhone every purchase would be rejected after payment (Apple's
  reply was read wrongly). No real player or real money is involved yet.
- The function is REWRITTEN in the repo (`supabase/functions/verify-purchase/`), with its
  decisions in `rules.ts` and 20 tests in `rules_test.ts`
  (`~/development/deno/deno test --allow-read --allow-net=deno.land
  supabase/functions/verify-purchase/rules_test.ts`). **It is NOT deployed**: the live
  server still runs the old version. Deploy needs Jennifer's OK, and it can only be
  proven with a real sandbox purchase.
- App side fixed and tested: correct iPhone purchase call; undelivered purchases retried
  on return to the app; the game is saved before the store is told a purchase is done;
  purchases carry the player's account id; one-time products apply once in total; store
  re-sends are silent; a game running on older content is not written over the full one.
- Analyze clean, 420 unit tests, 20 server rule tests, twelve device tests on both phones.

Store products:
- `tool/create_store_products.ts` (run with Deno) creates the products in App Store
  Connect and Google Play from `tool/store_products.json`; descriptions take their Pearl
  and Manna amounts from `content/products.json`. Nothing has been created yet.
- Pearl amounts decided 2026-10-05 (Jennifer asked for a recommendation; her new list was
  adopted): 25 / 140 / 300 / 650 / 1,750 / 3,750 for $0.99 … $99.99. Changed in
  `content/products.json` and the server's `rules.ts`; a test keeps the two equal.
  Content version is now 4. Why: at the old amounts $0.99 bought five Manna refills and
  the $1.99 starter pack was no better value than the cheapest pack; at the new amounts
  the starter pack is about twice the value of any other pack, as a starter offer should be.
- **Apple: all seven products created in App Store Connect on 2026-10-05** (app
  6819075333): English name and description, US price, Apple's prices elsewhere,
  available in 175 countries. Their status is "Missing Metadata" because each still
  needs a review screenshot (Jennifer asked to add those once the shop screen exists;
  it exists now). Product IDs on Apple are permanent.
- Google: nothing created. The app is not in Play Console yet; it needs a first build
  uploaded and a Play service account file (path goes in `.env`). Then run
  `deno run -A tool/create_store_products.ts --apply --google`.
- The Apple API key can see all of Jennifer's apps; only Whispers of Joppa is touched.
- Apple key `AuthKey_3RX9BR6Z6S.p8` is in the project folder (ignored by git); its path
  and Key ID are in `.env` (ignored by git).

Known limits (from the review):
- Pearls live in the player's save, which the player's own account can write. An honest
  app only adds Pearls from server-recorded purchases, but a determined player could edit
  their cloud save. Server-side Pearl balances would close this (matters for refunds, M17).
- The starter pack is offered as soon as the tutorial ends; the GDD says after task 10.
- `SupabasePurchaseBackend` and `InAppPurchaseStore` have no automated tests (they need
  the real services); the flow around them is tested with stand-ins.

Not in this milestone:
- Nothing spends Pearls yet (Manna refills and basket slots come later).
- Refunds and automatic restore on a new phone are Milestone 17.
- Pearls live in the local/cloud save. Choosing an older game in the "which game?"
  question can lose unspent Pearls from the newer one; purchases themselves are never
  lost, because the server list re-delivers any transaction a save has not applied.

## Milestone 17 — state (2026-10-05)

BUILT, NOT TAGGED. Analyze clean, 441 unit tests, 29 server rule tests, twelve device
tests on the iOS Simulator and Android Emulator. **Nothing here has been tried with a real
purchase or a real refund.** (The server functions were deployed later the same day; see below.)

What is built:
- Refunds in the app (`lib/domain/refunds.dart`, `PurchasesController.applyRefunds`): each
  time the app reads the player's purchases from the server (launch, return to the app,
  after the account screen, Restore), a purchase the server marks refunded has its Pearls
  taken back, never below zero, exactly once. A refunded starter pack can be bought again.
- Restore: "Restore purchases" in the Pearl shop; and purchases are brought over
  automatically after signing in (new phone) — the app checks as soon as the account
  screen closes.
- Server (in the repo, NOT deployed): `store-notifications-apple` and
  `store-notifications-google` rewritten; shared code in `supabase/functions/_shared/`.
  Neither trusts what a notification says. Apple's only names a transaction, and Apple is
  then asked directly whether it was refunded. Google's only triggers a read of Google's
  own list of voided purchases. A refund is recorded once (`recordRefund`).
- `verify-purchase` now treats "Apple is busy/down" as "try again later" instead of
  "unknown purchase".

Decisions (differences from TECH_SPEC section 6 — **assumptions to confirm**):
- A refunded starter pack loses its Pearls and can be bought again, but the Manna and the
  generator level it gave stay: once the player has played on there is no telling which
  Manna was the pack's.
- A refund takes Pearls from whatever the player holds (up to the pack's amount), not
  only "Pearls from that purchase" — Pearls are not tracked per purchase.
- Signing in on a new phone delivers every purchase the account holds that this game has
  not applied, Pearl packs included (not only the starter pack). Pearls live in the save,
  so a fresh game on the same account would otherwise have lost them.
- A starter pack paid for twice (iPhone and Android) and refunded once is kept.
- "Restore purchases" stays in the Pearl shop; there is no general Settings screen yet.
- Refunds are silent in the game (no message when Pearls are taken back).

Known limits:
- A refund only reaches the game when the player is signed in and online. A player who
  stays signed out keeps the Pearls. Server-held Pearl balances would close this.
- If Apple reverses a refund (REFUND_REVERSED), the purchase is not given back
  automatically; it would need a manual fix in the `purchases` table.
- The Apple notification address is open to anyone. A forged call cannot refund anything
  (only Apple's own answer counts), but a flood of them could use up our Apple API
  allowance. Checking Apple's signature on the notification would close this.
- Google's shared secret travels in the address (`?key=`); if it leaked, the only effect
  is extra reads of Google's voided list.
- The daily Google check (`?sweep=1`) is written but **not scheduled**; it must be set up
  at deploy time (a Supabase scheduled job). It matters: it catches a missed notification.
- The `wallet_grants` refund line records the pack's full Pearls, the most that can be
  removed; the game removes only what is left.
- No automated test of the two notification functions end to end or of `recordRefund`
  (they need the live database and stores); their decisions are tested in
  `_shared/refund_rules_test.ts`.

**Deployed 2026-10-05** (Jennifer: "deploy"): `verify-purchase`,
`store-notifications-apple` and `store-notifications-google` are live on the Whispers of
Joppa project, replacing the old unsafe versions. `STORE_NOTIFY_SECRET` is set on the
server (a copy is in `.env`, not in git). Checked with harmless calls: no sign-in → refused;
Google function without the secret → refused; a non-refund notice → accepted, nothing
changed. Until the Apple and Google keys are stored as server secrets, every purchase
check answers "try again later" (nothing can be granted wrongly).

Still needed to finish (Jennifer's OK required for each live change):
1. (done) Deploy the three functions.
2. Supabase secrets: Apple In-App Purchase key (id, issuer, key), Play service account
   JSON, and a new random `STORE_NOTIFY_SECRET`.
3. App Store Connect → App Store Server Notifications → the Apple function's address.
4. Google Cloud Pub/Sub topic + push subscription to the Google function's address with
   `?key=<secret>`; Play Console → Monetization setup → Real-time developer notifications.
   The Play service account needs "View financial data" for the voided-purchases list.
5. Schedule the daily `?sweep=1` call.
6. The real-device list in TECH_SPEC section 6 (buy each pack, kill the app mid-purchase,
   airplane mode, restore on a fresh install, cancel, refund on each store).

## Milestone 18 — state (2026-10-05)

BUILT, NOT TAGGED. Analyze clean, 462 unit tests, thirteen device tests on the iOS
Simulator and Android Emulator (the new one, `rewarded_ad_test`, uses a stand-in ad), and
the real app launches on both with the real ad service switched on. **No real ad has been
seen on screen yet** — that needs someone to finish the tutorial, run out of Manna and tap
the button.

What is built:
- When the player is out of Manna, the popup offers "Watch an ad for +20 Manna (N left
  today)". It appears only if an ad is loaded and ready, the tutorial is over, and fewer
  than 5 have been watched today. OK always closes the popup. Nothing ever plays by itself.
- The Manna is given only when the ad is watched to the end. Amount and daily limit come
  from `content/economy.json` (`rewarded_ad_manna_bonus`, `rewarded_ad_manna_daily_cap`).
- Today's count is in the save (format version 6; older saves upgrade automatically).
- If no ad can be loaded the button simply is not there; loading is retried quietly.
- Rules in `lib/domain/ads.dart`; `lib/features/ads/ad_rewards_controller.dart`;
  the AdMob part in `lib/services/google_rewarded_ads.dart`.

Decisions:
- Only the Manna ad is in this milestone. The GDD's other two ad rewards (double an order
  reward, daily clay jar) come with the features they belong to.
- The ad is offered in the out-of-Manna popup only (the moment it is useful).
- The day is the phone's own calendar day. Changing the phone's clock resets the limit;
  accepted (at most 100 Manna, and Manna regen already trusts the clock).
- The app uses Google's public TEST ad units by default: sample ads, no earnings.

Needed before real ads (SETUP_CHECKLIST Phase 9; all for Jennifer / Milestone 25):
- Real AdMob app ids (AndroidManifest.xml, ios Info.plist) and real rewarded unit ids,
  passed at build time as `ADMOB_REWARDED_UNIT_IOS` / `ADMOB_REWARDED_UNIT_ANDROID`.
  **A release built without them shows test ads.**
- Privacy: the consent prompt for European players (Google UMP), Apple's tracking
  permission text and SKAdNetwork list in Info.plist. None of these exist yet.

Review notes carried forward:
- `google_rewarded_ads.dart` has no automated test (it wraps the AdMob plugin). It guards
  against an ad that never appears (10 s), a reward reported just after closing (1 s
  wait), and stale ads (reloaded after 50 minutes) — all unproven until a real ad runs.
- `board_session.dart` is at exactly 300 lines: split it before adding anything.

## Milestone 19 — state (2026-10-06)

BUILT, NOT TAGGED. Analyze clean, 473 unit tests, fourteen device tests on the iOS
Simulator and Android Emulator (the new one, `analytics_test`, records events with a
stand-in), and the real app starts Firebase and Crashlytics on both (seen in the device
logs). **Nobody has yet looked in the Firebase console to confirm events and a test crash
arrive.**

What is built:
- Events (TECH_SPEC 8): tutorial_step, tutorial_complete, merge and generator_tap (one in
  ten sent), order_complete, task_complete, chapter_complete, out_of_energy,
  purchase_started, purchase_complete, ad_watched, letter_opened, session_end.
- No personal data: an event may carry only a short list of game ids and numbers
  (`allowedParamKeys` in `lib/domain/analytics_events.dart`); anything else is dropped. No
  account id is ever given to Firebase.
- Crash reports: every uncaught error goes to Crashlytics with the content version and
  current chapter (app version is added by Crashlytics itself).
- A "Test crash (debug only)" button on the Account screen (signed in, debug builds).
- If Firebase cannot start, the game runs exactly the same without it.
- Device tests switch all of this off; they send nothing.
- `lib/app/game_analytics.dart` listens to the game; `lib/app/crash_reporting.dart` starts
  Firebase; `lib/services/firebase_analytics_service.dart` sends.

Decisions / assumptions to confirm:
- `session_start` is NOT sent by the game: Firebase records it by itself and refuses
  that name from an app. `session_end` (with the session's length) is ours.
- `purchase_complete` means "a purchase was put into this game". Restoring old purchases
  on a new phone reports them again, so it over-counts as a sales figure; the `purchases`
  table is the true record of sales.
- `lib/firebase_options.dart` was written from the two Firebase config files already in
  the project (the same values `flutterfire configure` produces), because the iOS config
  file is not attached to the Xcode project. These identify the app; they are not
  secrets. It sits outside `lib/app/config.dart`, the usual home for app-safe keys.
- `firebase_core 4.15.0` is now listed in pubspec (it was already installed as part of
  the other Firebase packages, at that version).
- Debug builds on a developer's machine DO report to the live Firebase project (needed
  for the test-crash check). Filter by app version in the console if that gets noisy.

Review notes carried forward:
- `GameAnalytics.attach` (the wiring to a live game) is covered only by the device test
  (session, generator tap, out of energy), not by unit tests: it needs a whole session.
- iOS crash reports will not show readable code locations until the Crashlytics
  "upload symbols" build step is added (Milestone 25, release builds).
- Crash reports carry the error's own text; an error message that happened to include
  an email address would be uploaded as written.
- `account_screen.dart` (298 lines) and `purchase_coordinator.dart` (299) are at the
  size limit: split before adding to them.

## Milestone 20 — state (2026-10-06)

BUILT, NOT TAGGED. Analyze clean, 508 unit tests, fifteen device tests on the iOS
Simulator and Android Emulator (the new one, `notifications_test`, uses a stand-in for the
phone's notifications), and the real app launches on both with no permission prompt at
start. **No real notification has been seen on a phone yet.**

What is built:
- The question: after Chapter 1 task 5 the game asks, in its own words, whether the
  player would like notifications. Only a yes brings up the phone's own prompt (an iPhone
  only allows that once). A no is remembered and never asked again; closing it with the
  back button is not an answer, so it is asked again after the next task.
- A bell button on the board opens three switches: gentle reminders, event news, new
  chapters. Turning one on later asks the phone then. If the phone itself has
  notifications off for the game, the screen says so.
- Reminders scheduled on the phone as the player leaves, and cleared when they return:
  "Manna is full" (only if Manna was at or below 20% on leaving) and one come-back
  reminder after 3 days, never repeated within a week. Nothing is ever set for 9 pm–9 am
  (the phone's own time): it waits until 9 am.
- Push: the phone joins the `events` and `chapters` topics according to the switches,
  and a signed-in player's push address and choices are stored in `device_tokens`.
- All wording, the task to ask after, quiet hours and the numbers are in
  `content/notifications.json` (written by the content-writer; validated). Content is now
  version 5; the next server release must be 6 or higher and include this file.
- Rules in `lib/domain/reminders.dart`; `lib/features/settings/notifications_controller.dart`
  and `notification_settings_screen.dart`; the phone part in
  `lib/services/device_notification_service.dart`.

Decisions / assumptions to confirm:
- Not in this milestone: the "daily clay jar" reminder (the jar does not exist yet);
  SENDING pushes (events are Milestone 21, the admin panel 22 — `send-push` on the server
  is still the first-draft version); opening a particular screen when a notification is
  tapped (there is only the board so far).
- A player already past task 5 (an existing save) is asked after their next task. A
  player with no tasks left is never asked; the bell is always there.
- `timezone 0.11.1` is now listed in pubspec (already installed as part of
  flutter_local_notifications, at that version). Reminders are scheduled as exact moments,
  so the phone's time-zone name is not needed.
- Reminders may arrive a few minutes late on Android (no special alarm permission is
  requested).

Needed from Jennifer for iPhone push (SETUP_CHECKLIST Phase 6):
- An APNs key uploaded to Firebase, her Apple Team for signing, and the Push
  Notifications capability switched on for the app. Until then iPhones get the scheduled
  reminders but no push. Android push works once pushes are being sent.

Review notes carried forward:
- The review caught reminders ignoring quiet hours in some time zones (times loaded from
  a save are in UTC); fixed, with tests.
- The board flow "ask after task 5" is covered by unit tests of the rule and the
  controller, not by a device test that plays five tasks.
- A phone left idle still shows its reminders while the player plays on a second phone.
- A second account on the same phone leaves the first account's `device_tokens` row.
- Android shows the app icon as the small notification icon (may look like a blank
  square); a proper small icon and a keep-rule for it belong with the release build
  (Milestone 25).
- `ContentLoader.notifications` is parsed but the board reads the same data from the
  content bundle (board_session.dart is at the 300-line limit); tidy when that file is split.

## Milestone 21 — state (2026-10-06)

BUILT, NOT TAGGED. Analyze clean, 547 unit tests, sixteen device tests on the iOS
Simulator and Android Emulator (the new one, `event_test`, plays a made-up "Joppa Boat
Festival" from a stand-in server), and the real app launches on both. **No real event
exists, so players see nothing new yet.**

What is built:
- While an event is on (and the tutorial is over) a banner on the board shows its name
  and time left. Tapping it opens the event's own smaller board (size set by the event,
  5×7 in the plan) with the event's own chain and generator.
- The event board spends the player's ordinary Manna. Each merge earns points (the tier
  made); points climb a track of reward steps that pay Manna and Talents into the main
  game straight away, each step once.
- Events come from the server's `events` table (rows switched on), then the last list
  the server gave (for offline play), then the app's own `content/events.json` (empty).
- Every event is checked before it is shown (`lib/data/event_validator.dart`) and its
  board is trial-built; a faulty event is simply left out. A picture the installed app
  does not have shows the coloured placeholder.
- Event progress (board, points, steps paid) is kept on the phone, one file per event.
- The main board can now be any size (`BoardGame.gridCols/gridRows`); the main game is
  unchanged at 7×9.
- Rules in `lib/domain/events.dart`; `lib/features/events/`; `lib/data/events_repository.dart`.

The event format (`events.config`, also an entry of `content/events.json`):
`{ "board": {"cols":5,"rows":7}, "chain": {…as in chains.json…}, "generator": {…as in
generators.json…, "col":2, "row":6}, "milestones": [{"points":10,"manna":10}, {"points":30,
"talents":50}, …] }` plus the row's `id` (lowercase letters, digits, _), `name`,
`starts_at`, `ends_at`. A full example is `test/support/event_fixtures.dart`.

Decisions / assumptions to confirm:
- NOT in this milestone: the season pass (a purchase), the exclusive decoration, the
  story side-plot scenes, Pearl rewards (Pearls only come from verified purchases),
  event art, weekend events, "event started/ending" pushes, and event progress in the
  cloud save. Each is a piece of LIVEOPS section 2 still to build.
- No real event is included: LIVEOPS says each theme needs Jennifer's approval.
- Rules for running events: never re-use an event id; on a live event only ADD reward
  steps at the end (do not insert or reorder); give dates with a time zone.
- Points per merge = the tier made (not yet settable per event).

Needed before a real event can be seen (each needs Jennifer's OK):
1. Apply `supabase/migrations/20261006000001_events_public_read.sql` (lets signed-out
   players read switched-on events; today only signed-in players can read events).
2. Choose the first event theme; then the chain, rewards and dates go into an `events` row.

Known limits (from the review; accepted for now):
- Event progress lives on the phone only: reinstalling, or a second phone on the same
  account, lets a player earn an event's rewards again (capped by the checks: at most
  500 Manna / 5,000 Talents a step). Proper fix: progress in the cloud save.
- Whether an event is on goes by the phone's clock.
- For up to 20 seconds after an event ends, taps on its board still spend Manna for no
  points; then the board closes itself.
- No unit test builds a non-7×9 board or a merge on one; the device test covers the
  5×7 board and generator taps, not merges or rewards (those are unit tested in
  `event_controller_test.dart`).
- Review fixes made: faulty server data can no longer leave the event screen stuck;
  Manna spent on the event board is now saved like any other change; an account sync
  cannot swap the game under an open event; a cancelled saver can never write.

## Milestone 22 — state (2026-10-06)

BUILT, NOT TAGGED. Jennifer's instructions (2026-10-06): the admin is only her; first
event is the Boat Festival ("you can choose from now on" — Claude chooses later themes);
yes to applying the server change.

Done on the LIVE server (project sincvubcsnqzjefzsifq):
- Migration `20261006000001_events_public_read.sql` applied (every player can read
  switched-on events).
- Migration `20261006000002_admins.sql` applied: an `admins` table and `is_admin()`;
  admins can manage events, add content releases and upload bundle files, and read the
  record of pushes sent. Nobody can make themselves an admin (rows are added only from
  the server side).
- One admin account created for Jennifer (her own email address) with a generated password. The
  password is in `~/Downloads/WhispersofJoppa-admin-login.txt` on this Mac ONLY (not in
  the project, not in git, never shown in chat). She should change it at first sign-in.
- `send-push` rewritten and deployed: only a signed-in admin may call it; event-news or
  new-chapter audience only; at most one push per 24 hours; recorded in
  `notifications_log`. It answers "Push is not set up yet" until the Firebase service
  account JSON is stored as the `FIREBASE_SERVICE_ACCOUNT` secret.
- The first event row, `boat_festival_2026` ("Joppa Boat Festival", 2026-10-06 to
  2026-10-27 UTC), switched on. Same content as `content/events.json`.
- Checked on the live server: a visitor cannot add or delete events, add a content
  release or add an admin; the admin can add, see and delete events and cannot add
  another admin; send-push refuses anyone not signed in.

The panel (`admin/index.html`, `admin.js`, `admin.css`; no build step):
- Events: list, create from a template, edit, switch on/off, delete. It runs the same
  checks as the game before saving (the game checks again on every phone).
- Content: release a content file built with `dart run tool/build_content_bundle.dart`
  (must be a higher version than the last release; cannot be undone from the panel).
- Notifications: title, message, audience; the list of what was sent.
- Account: change password.
- Published with the website at https://joppa-s-whispers.vercel.app/admin/index.html
  (copies in `web/public/admin/`; sign-in required; search engines told not to list it)
  and copied to `~/Downloads/WhispersofJoppa-Admin/` (open `index.html`).
- "Edit content" here means releasing a content file Claude has built and checked;
  editing individual items or dialogue in the browser is not built.

The Joppa Boat Festival (first event):
- 5×7 board; chain "Boatbuilding": Cedar log → Sawn plank → Keel → Planked hull →
  Ribbed hull → Sealed hull → Mast and sail → Festival boat; generator "Caleb's
  Boatyard" (1 Manna a tap; tier 1 85%, tier 2 15%); 20 reward steps
  paying 10–50 Manna or 20–300 Talents. Names by the content-writer.
- (Reward steps now run from 25 to 7,000 points; see the review notes below.)
- Decisions: tier 8 is "Festival boat", not "The Leah" (Caleb only begins the Leah in
  Chapter 5; naming it would spoil that). No art yet: coloured placeholders.
- Content-writer notes for Jennifer's reviewer: shell-first building order (planked
  hull before ribs) is period-correct; cedar/oak are plausible, not certain; avoid
  painted prow "eyes" in the art (a protective charm in the period).

Security review (2026-10-06) and what was done:
- It found no way for a visitor or an ordinary signed-in player to become an admin or
  to change anything. Re-tested on the live server with a throw-away player account
  (since deleted): cannot add, change or delete events, add a release, upload a file,
  read the admin list or the push record, or send a push. The admin can upload a bundle
  file but cannot overwrite or delete one.
- One push a day is now enforced in the database (`reserve_push`, migration
  `20261006000003_push_limit.sql`, applied): the record is written before sending, under
  a lock, so two requests at once cannot both pass.
- The page loads nothing from other websites (supabase-js 2.45.4 is kept beside it), has
  a strict content policy, refuses to run inside another page's frame, and keeps the
  sign-in in memory only: **closing or reloading the page signs out.**
- The page's event checks mirror the game's and are tested (`admin/event_rules_test.ts`);
  a test fails if the published copy in `web/public/admin` is stale.
- The Boat Festival's reward track was lengthened (last step 7,000 points, was 2,600):
  the review estimated a normal player would have finished the shorter one in 4–7 days
  of a three-week event. Rough guide: about 3 points per Manna spent.

Assumptions to confirm / known gaps:
- Quiet hours (no pushes 9 pm–9 am in the player's own time zone) cannot be enforced for
  a push sent to everyone at once; the page only reminds the sender. One push a day is
  for the whole game, not per player. Scheduled pushes and "event ending, only to
  players who joined" are not built.
- The admin account has a password only (no second step). Worth turning on later.
- The panel is on the same web address as the marketing site; a dedicated address would
  separate them further.
- If a release stops half way (file uploaded, release not recorded) pressing Release
  again finishes it.
- `send-push` no longer uses a `FIREBASE_PROJECT_ID` secret (the project comes from the
  Firebase key itself). Only the rules in `send-push/rules.ts` are unit tested, not the
  function's sign-in checks end to end (those were tested live, above).
- The Boat Festival has no season pass, decoration, side-plot scenes or art yet (see
  Milestone 21's list).
- The app's own `content/events.json` carries the same event as the offline fallback.

Not verified: nobody has clicked through the admin page in a browser yet (its scripts
were syntax-checked, its event checks tested, and every server permission it relies on
tested directly).

## Milestone 23, Chapter 2 "The Collection" — state (2026-10-06)

BUILT, NOT TAGGED. Analyze clean, 573 unit tests (including a play-through of both
chapters with the real rules), seventeen device tests on the iOS Simulator and Android
Emulator (the chapter test, now `chapters_test`, starts from a finished chapter). Nobody has
played Chapter 2 by hand yet, and none of its pictures exist.

Also on this date: Jennifer added art for The Word and Anointing Oil chains (14 items);
processed and wired in. Every item chain now has art.

What is built:
- Chapter 2 content (content-writer, checked by the validator): 12 tasks at the town
  well covering the story bible's 11 beats, 12 scenes, 12 orders (8 ordinary, 4
  spiritual: Peace for Amos, Faithfulness for Hannah), the well with 7 areas to restore,
  Letters 3 and 4 word for word, a new Chapter 1 ending that leads to the well, and a
  Chapter 2 ending. Content is version 7.
- Orders now wait for their chapter: Chapter 2's orders appear only when Chapter 1's
  tasks are all done. Each chapter's own orders pay enough Blessings for its own tasks
  (Chapter 1: 19 for 18; Chapter 2: 31 for 26, and it can be finished without Hannah's).
- A new chapter brings its generator: the Elder's Chest (House Church chain) arrives on
  the board when Chapter 2 is reached, at its home cell or the nearest free one; if the
  board is full it arrives as soon as a cell opens. It comes at the level the player's
  other generators have all reached (so a starter-pack owner gets it at level 2).
- A game saved by an earlier build loads at any stage (mid Chapter 1, or Chapter 1
  finished) and picks up from there.
- Content format is now 2: an older app will refuse a version-7+ release instead of
  misplaying it. **Do not publish content 7+ to the server expecting old builds to use
  it; players need this build or newer.**

Decisions / assumptions to confirm:
- 12 tasks a chapter (the story bible imagines 30–40). Kept short and in step with
  Chapter 1; easy to lengthen later with more tasks per beat.
- The Elder's Chest arrives at the start of the chapter, not at beat 4 as the bible has it.
- The "Imperishable" crown for Chapter 2 is not awarded: crowns are not built.
- Players who already saw the old Chapter 1 ending will not see the reworded one.
- A Chapter 1 order left unfinished waits behind Chapter 2's on the cards; the last
  cards of a chapter cannot be skipped (nothing to swap them for).
- No message announces the new generator; it simply appears.
- Two lines were adjusted after review: the closing scene no longer hints that the new
  toll collector informs to Rome (that rumour belongs to Chapter 3), and Amos owns his
  silence without asking forgiveness for it ("That part is mine. The rest I forgive,
  all of it.").

For Jennifer's reviewer (content-writer's flags):
- Zilpah calls Amos a "shepherd" who "should lay down the staff", wanting a new elder
  "by the Sabbath" (ch2_s_05).
- "Meeting night" and "no bread broken" for the believers' gathering (ch2_s_04).
- Hannah's sons faced debt servitude "for years"; no number is given (ch2_s_08).
- Small invented details: Amos's vineyard is "the one my father planted"; he was "seen
  at the moneylender's gate"; Letter 4 is a carved shard behind the foundation stone.
- The townsfolk at the well are voiced by the two dock-worker characters.

Art missing for Chapter 2:
- 14 well pictures: lip, bucket stone, rope, trough, bench, foundation and paving, each
  "before" and "after" (`loc_well_<part>_before` / `_after`).
- 4 scene backgrounds: the well in the morning, the well at dawn, Amos's house,
  Hannah's house (plus the harbour at dusk from Chapter 1's list).
- Marcus still has only a neutral portrait (he appears in the last scene).

Review notes carried forward:
- `wireChapters` and `BoardGame.addGenerator` are covered by the device test only (no
  unit test builds a board); the "board full, generator waits" path is covered by the
  rule's unit tests but not end to end.
- Selling items and Esther's Basket are still not built, so the only way to free a cell
  is to merge or deliver. A full board always holds a mergeable pair with today's
  chains, so this cannot lock the game.
- A finished chapter's location cannot be revisited.
- Hannah's Faithfulness order needs 64 Manna of Fruit taps for 35 Talents and 3
  Blessings: the poorest return in the game, by design the hardest and optional. Raise
  its Blessings if it plays as a wall.
- `board_session.dart` (295 lines) and `board_game.dart` (286) are near the size limit.

## Milestone 23, Chapter 3 "The Tax Collector" — state (2026-10-06)

BUILT, NOT TAGGED. Analyze clean, 578 unit tests (with a play-through of all three
chapters), seventeen device tests on both the iOS Simulator and the Android Emulator
(`chapters_test` covers finishing Chapter 1 and finishing Chapter 2). Not played by hand.
Content is version 8 (format 2), in the app only; nothing published to the server.

What is built:
- 12 tasks at the fishing docks covering the 11 beats, 12 scenes, 12 orders (7 ordinary,
  5 spiritual, including Belt of Truth and Shield of Faith for Marcus), the docks with 7
  areas, Letters 5 and 6 word for word, a Chapter 2 ending that now leads to the docks,
  and a Chapter 3 ending. Silas's line is exact: "Every runaway sails from Joppa. Some
  sail home."
- The Armor Rack (Armor of God) arrives on the board when Chapter 3 is reached.
- A new speaking character, the Chief Collector (no portrait; name and words only).
- Blessings: orders pay 33, tasks cost 28; the chapter can be finished without the two
  hardest orders. About 294 generator taps in all (Chapter 1: 162; Chapter 2: 242).

Decisions / assumptions to confirm:
- 12 tasks (as Chapters 1–2). The "Rejoicing" crown is not awarded (crowns not built).
- The Armor Rack arrives at the chapter's start, not at beat 5; the Shield of Faith
  order is the last card rather than at beat 5.
- Letter 5 is found "In Savta's shard basket" (the bible only says "never sent").
- Edits after review: the Shield of Faith and Belt of Truth order texts were reworded
  so they are true whenever the card is seen and do not give away the ending; Marcus's
  bread order now comes after Zilpah's so his warm "Nomi" cannot appear before the
  boat-shed scene; "months" became "weeks" (Marcus has only just arrived); Naomi now
  clears Marcus from what Silas's crew actually paid ("Nine baskets landed. You wrote
  six, and six is what he paid."), since two unequal columns alone would also fit a
  cheat; a few filler "Hm."s were cut.

For Jennifer's reviewer:
- Invented toll details: tolls per boat on the landed catch, a rate raised by Caesarea
  at the new year, a "toll roll", a strongbox Marcus tops up from his wages, a three-day
  audit by a chief collector, dismissal and forfeited wages. The falsified roll is
  sympathetic but is named false and punished.
- Luke 15:20 in Letter 5 (as the story bible prescribes): Luke's Gospel was not written
  by AD 40, so it stands as a saying of Jesus passed along. Same question as Letter 1.
- Tabitha is only spoken of: "clothed half the widows in Joppa", "Esther's dearest
  friend" (Acts 9:36–39 says she was full of good works; "collapsed" is the bible's beat).
- Invented backstory: Marcus left at eighteen, eight years ago; Esther's monthly shards
  went up the coast with any boat that would carry one; Letter 5 was written the week
  she took ill; a grain ship for Cyprus.
- Demas is left unresolved (his own story is Chapter 5).

Art needed for Chapter 3:
- 14 docks pictures: mooring posts, planking, slipway, fish table, net racks, lantern
  post and Silas's net box, each "before" and "after"
  (`loc_docks_<posts|planking|slipway|table|racks|lantern|netbox>_<before|after>`).
- The Armor Rack generator (all seven generators are still missing).
- Optional: a Chief Collector portrait (neutral and thinking are used) and a Dock
  Worker portrait (he now gives an order).
- Backgrounds: none — all five used already exist.

Note: `content/scenes.json` (about 1,650 lines) and `content/orders.json` are long
single files; splitting them per chapter would need a loader change.

## Milestone 23, Chapter 4 "Tabitha" — state (2026-10-06)

BUILT, NOT TAGGED. Analyze clean, 583 unit tests (with a play-through of all four
chapters), seventeen device tests on both the iOS Simulator and the Android Emulator
(`chapters_test` now covers three chapter changes). Not played by hand. Content is
version 9, in the app only. NOT in build 4 (that bundle has Chapters 1–3).

What is built:
- 12 tasks at Simon the tanner's house covering the 11 beats, 12 scenes, 12 orders (8
  ordinary, 4 spiritual), 7 areas, Letters 7 and 8 word for word, a Chapter 3 ending
  that leads to Tabitha, and a Chapter 4 ending.
- The Loom (Tabitha's Loom) arrives on the board when Chapter 4 is reached.
- Blessings: the first ten orders pay 30, tasks cost 26. The last two orders
  (Gentleness, Self-Control for Zilpah) are deliberately long hauls (128 and 256 Fruit
  taps) and are not needed to finish the chapter.
- `board_game.dart` was split (art loading is now `board_game_art.dart`).

How Acts 9:36–43 is handled (for Jennifer's reviewer — please check each):
- Tabitha speaks four gentle lines in the first scene only (she asks Naomi to finish the
  widows' tunics). No teaching, prophecy or miracle is given to her. She is silent after
  she is raised, as in Acts.
- Her death is reported, briefly: "Tabitha died in the night." / "The women have washed
  her and laid her in the upper room." ("in the night", "the women" are additions.)
- Two men, Caleb and Marcus, are sent to Lydda: "come to us, and do not delay."
- The raising is heard from the stair outside. Hannah: "He was kneeling to pray as I
  shut the door." Naomi: "He's praying. I can't make out the words." Peter's only words:
  "Tabitha, arise." Then: he has her by the hand; he calls them in, "the widows and all";
  she is alive, standing. The prayer itself is not written. Her opening her eyes and
  sitting up are not shown (every witness is outside).
- Afterwards: "It's known in every street"; a townsman asks Hannah, "tell me about this
  Lord of yours". Hannah credits prayer, not Peter: "Peter knelt and prayed. He called us
  in, and she was alive."
- Peter lodges with Simon the tanner "many days". He has three ordinary lines there
  ("Peace, friends. Is that bread? …", "Thank you, Naomi. I was a fisherman. …", "Sit
  down, friend. …") and no teaching. Nothing from Acts 10–11 appears.
- The closing scene: Joy asks Peter whether he can bring her mother back. Peter says
  nothing ("He's come down to her height, eye to eye. He hasn't said a word."), Caleb
  walks out, Demas looks away. No adult endorses the idea that Peter did it. Reviewer to
  decide whether a gentle correcting line is wanted anywhere.
- Zilpah's backstory gives Tabitha two invented deeds from the story bible: she took
  Zilpah in and made her clothes. Simon the tanner's character, and Esther's weekly
  visits to him with bread, are invented.
- Letter 8 introduces Isaiah 61:3 with "The Lord came" (the story bible's wording).

Decisions / assumptions to confirm:
- Tabitha gives no order card. (Her one order was moved to Hannah after review: a card
  from Tabitha could have stayed on screen after her death.) Peter gives none.
- All of the first ten orders pay 3 Blessings (earlier chapters start at 2).
- The Loom arrives at the chapter's start; the "Righteousness" crown is not awarded.
- The loom scenes use the upper-room picture; in the story the loom is in the weaving
  room next door, not where Tabitha is laid.
- Zilpah asks forgiveness of Naomi first, then Amos and Marcus (the three she is shown
  gossiping about in Chapters 1–3).

Art needed for Chapter 4:
- 14 pictures of Simon the tanner's house: courtyard, guest room, cistern, drying racks,
  doorstep, rooftop and gate lamp, each "before" and "after"
  (`loc_tanner_<courtyard|guestroom|cistern|racks|doorstep|rooftop|lamp>_<before|after>`).
- A Simon the Tanner portrait (neutral, happy, sad and thinking are used).
- Optional: a weaving-room background with a loom.
- The Loom generator is already in.

## Milestone 23, Chapter 5 "Caleb's Boat" — state (2026-10-06)

BUILT, NOT TAGGED. Analyze clean, 585 unit tests (with a play-through of all five
chapters); all seventeen device tests on the iOS Simulator; on the Android Emulator the
chapter, smoke, scene and orders tests (content-only change since the last full Android
run). Not played by hand. Content is version 10. NOT in build 5.

What is built:
- 12 tasks building the house for the church (cornerstone, walls, doorway, roof,
  benches, lamps, table), 12 scenes, 12 orders (7 ordinary, 5 spiritual incl. Love for
  Joy, Goodness for Demas, Horn of Oil for Caleb), Letters 9 and 10 word for word, a
  Chapter 4 ending that leads to Caleb, and a Chapter 5 ending.
- The Olive Press (Anointing Oil) arrives when Chapter 5 is reached.
- Exact line kept: Joy, "Did Papa kill Mama?" The rumour is shown being told by Demas
  before it is undone. Leah is never shown and never speaks; her death is not graphic.
- Blessings: tasks cost 25; the first nine orders already pay 25, so the Demas and
  Caleb orders are optional.

Decisions / invented details to confirm:
- Demas cannot swim and froze on the beach; his guilt became the tale about Caleb.
- Caleb has blamed himself for a sprung plank on the boat Leah took; Tobiah tells him it
  held — it was the rocks.
- Silas saw her go that night and has kept silent, doubting his own eyes.
- Tobiah gave up fishing, twists rope past the north beach, and told people he swam in.
- The watchtower beacon had blown out that night (it is relit in Chapter 6).
- Esther chose the cornerstone years ago and sealed Letter 10 in it; the potter gave the
  plot; Zilpah's bangles paid for the roof timber.
- A purpose-built meeting house around AD 40 is early historically; it is the story
  bible's own beat and is kept plain (no cross, altar, pulpit).
- The "Glory" crown is not awarded (crowns not built). The location screen says
  "restored" although this house is being built.

For Jennifer's reviewer:
- Peter does not speak in this chapter. He is mentioned when Joy recalls her question
  ("He didn't say yes. He didn't say no. He just got down low and looked at me.") and in
  ch5_s_11 ("I asked Peter to bring her back. She isn't back. But now I know who she
  was."). Nobody says he could or could not, and "why Tabitha and not Mama" is left
  unanswered on purpose.
- The closing scene follows Acts 10:7, 9, 17–18: past noon, Peter "up on the roof to
  pray, since noon"; three men at the gate, one a soldier; Lucius: "We have come from
  Caesarea. Is Simon, who is surnamed Peter, lodged here?" No vision, no Cornelius by
  name, no "bread woman". The servant's name (Lucius) is the story bible's invention.
  Chapter 6 must have Peter come down himself (Acts 10:21).
- Amos anoints the doorpost and the cornerstone with oil and says only Psalm 127:1
  (first clause, KJV). Anointing a building is not in Acts (compare Genesis 28:18).
- John 15:13 in Letter 9 (John's Gospel not yet written in AD 40; a saying passed
  along, as with Letters 1 and 5). Isaiah 43:2 in Letter 10 sits beside a drowning.
- Romance: Caleb asks Naomi to bake the launching loaf, "If you'd come."; she says yes.

Art for Chapter 5 (generated, approved by Jennifer 2026-10-06, now in the game; build 6
`dist/whispers-of-joppa-1.0.0-6.aab` has Chapters 1–5 and all of it):
- 14 pictures of the house church as "not yet built" / "built" pairs; a tanner's-gate
  background, now used by the closing scene;
  six Tobiah portraits (with a coil of rope, not a net).

## App icons, more portraits, store art (2026-10-06)

- `tool/make_app_icons.py <picture>` (Jennifer asked for a Python script) makes every
  icon size from the one app-icon picture: iOS set, classic and modern (adaptive)
  Android icons, plus `dist/store/play_icon_512.png` and `app_store_icon_1024.png`.
  Checked on the emulator: the launcher shows Naomi's face in a circle. Her source
  picture is 921 px; 1024 or larger would be a little sharper.
- Jennifer's own portraits filed: Amos sad, Esther happy, Naomi happy (they were in
  the top of `assets_incoming`, named differently).
- Generated, then APPROVED by Jennifer and now in the game / store folder: `portraits/` — Dock Worker, Dock Worker 2 and Simon the Tanner,
  six expressions each, and Demas happy; `store-and-icon/` — a Play Store banner (no
  title text on it yet) and the notification icon glyph (a white clay lamp).
- The notification icon is made by `tool/make_notification_icon.dart` (white shape,
  five sizes, with a keep-rule for release builds) and is what notifications now use.
  Store art is in `dist/store/` and copied to `~/Downloads/WhispersofJoppa-store-art/`:
  Play icon 512, App Store icon 1024, Play feature graphic 1024×500 (no title text).
- Build 5 (`dist/whispers-of-joppa-1.0.0-5.aab`, in Downloads) has Chapters 1–4 and all
  the art; its release build was installed on the emulator and opened.
- Every character who speaks now has portraits except the Chief Collector (optional)
  and Tobiah (Chapter 5).
- Still to do: store screenshots (real captures; Apple needs a 6.9-inch simulator) —
  Milestone 25.

## Generated art and build 5 (2026-10-06)

- Jennifer asked whether Claude could generate the missing pictures itself. She supplied
  a Google AI Studio key (in `.env` as `GOOGLE_AI_API_KEY`, never in git; billing had to
  be switched on first) and her Google Flow prompt. Tools: `tool/generate_art.py` (makes
  pictures into `~/Downloads/WhispersofJoppa-art-review/<job>/` ONLY), 
  `tool/art_overview.dart` (one overview picture per folder), `tool/accept_art.py`
  (files approved pictures into `assets_incoming/`). Job files with every prompt are in
  `tool/art_jobs/`. Model: gemini-3-pro-image, with her own pictures attached as style
  references; each "before" is the "after" picture edited, so pairs line up.
- Rule agreed with Jennifer: nothing generated goes into the game until she has looked
  at it and said yes. She keeps the character portraits for herself.
- Approved and in the game: 14 docks pictures; 14 tanner's-house pictures; the 8 Boat
  Festival items and Caleb's Boatyard; backgrounds "outside the bakehouse" and "rooftop
  at night" (her daytime rooftop turned to night); Olive Press level 3.
- The Boat Festival items now name their art, in `content/events.json` and in the live
  `events` row (older builds simply show placeholders).
- Every location (bakehouse, well, docks, tanner's house), every scene background in
  use, every item and every generator level now has art.
- Bundle `dist/whispers-of-joppa-1.0.0-5.aab` (build 5: Chapters 1–4 and all this art)
  replaces build 4 in Downloads.
- Art still missing: portraits (Naomi, Esther and Demas happy; Amos sad; Dock Worker;
  Simon the Tanner; optional Chief Collector) — Jennifer is doing these; the Android
  notification icon; store screenshots and the Play feature graphic.

## Bakehouse art (2026-10-06)

- Jennifer added the 14 bakehouse before/after pictures (in the backgrounds folder, named
  doorway / kneading / ovenwall; mapped to door / table / wall in `tool/art_names.json`
  and moved to `assets_incoming/locations/`). The bakehouse and the well are complete.
- Two extra wide views of the bakehouse (derelict, and restored with the oven lit) are
  left unused in `assets_incoming/backgrounds/`.
- No docks pictures were found (only the docks scene background from before).

## Generator art and build 4 (2026-10-06)

- Jennifer had put the generator pictures in `assets/items` (named `gen_<name>_l<level>`):
  pantry, tree, chest, armour rack, scribe's desk (as `gen_desk`), loom and olive press,
  five levels each, except Olive Press level 3. Moved to `assets_incoming/generators/`,
  processed to `assets/generators/` (34 pictures). Claude at first reported them missing,
  having searched the incoming folder only.
- The board now draws each generator's picture for its current level (a missing level
  falls back to the nearest lower one; no picture at all keeps the plain tile).
- Found by the device tests: asking Flutter for a picture that is not in the app raises
  an error even when caught. The board now loads only pictures listed in the app's own
  asset list. This also covers an event naming art the installed app does not have.
- `board_game.dart` is at 298 lines: split it before the next change.
- Bundle `dist/whispers-of-joppa-1.0.0-4.aab` (build 4) replaces build 3 in Downloads.
- Noticed in the art (Jennifer's call): pantry level 3 has "LVL 3" and level 4 has
  "LEVEL 1" written on it; the anointing vial has a cross and a paper label; the reed
  pen has "REEDPEN" written on it; the apostle's letter is drawn as an envelope.
- Art still missing: Olive Press level 3; 14 bakehouse and 14 docks before/after
  pictures; backgrounds "outside the bakehouse" and "rooftop at night"; portraits Naomi,
  Esther and Demas happy, Amos sad, Dock Worker, Chief Collector (optional), Simon,
  Tobiah; Boat Festival items and boatyard; Android notification icon; store art.

## Art delivery and second Android bundle (2026-10-06)

- Jennifer delivered: Marcus's five missing portraits (he now has all six), all 14 well
  before/after pictures, 17 scene backgrounds, and an app icon (Naomi with a lamp).
- `tool/process_assets.dart` now also handles location pictures and backgrounds;
  `tool/art_names.json` says which raw file is which picture (her background files
  have descriptive names; two well "lip" files were both named "after" — the cracked one
  is the "before"). Backgrounds for later chapters are stored ready: docks, church
  inside, tanner's rooftop, boatyard, storm at the harbour, upper room, boat shed at
  night, watchtower, feast table, rooftop by day.
- App icon set on both platforms (source: `assets/ui/app_icon.png`).
- Bundle `dist/whispers-of-joppa-1.0.0-3.aab` (build 3, with Chapter 3) is the one in
  Downloads for Jennifer; it replaced build 2 there (build 2 stays in `dist/`). Build 3
  differs from build 2 only in content; the release launch check was done on build 2.
- Bundle `dist/whispers-of-joppa-1.0.0-2.aab` (build 2). Signed
  with the same upload key. The release build was installed on the emulator and opened.
  Contains Chapter 2, events, notifications, ads (test units), analytics.
- Still missing for Chapters 1–2: the 14 bakehouse before/after pictures; backgrounds
  "outside the bakehouse" and "rooftop at night" (the rooftop picture delivered is a
  daytime one); all 7 generators; portraits for Naomi/Esther/Demas happy, Amos sad,
  Simon, Tobiah, Dock Worker; Boat Festival items; the Android notification icon.

## First Android bundle for Google Play (2026-10-05)

Jennifer asked for a bundle to upload to Google Play ahead of Milestone 25.

- Upload signing key created: `android/app/upload-keystore.jks`, alias
  `upload`; passwords in `android/key.properties`. Both are gitignored and
  exist ONLY on this Mac until Jennifer backs them up.
- Upload key SHA-1 `22:6B:92:F5:44:C5:0D:A5:A2:5C:B4:3C:4A:0B:74:92:76:4E:F0:2D`
  SHA-256 `CA:5D:32:47:2E:D9:82:18:BD:53:8C:87:59:99:B0:51:FF:F5:78:93:3D:D4:EA:37:61:B0:FD:59:F4:8E:6B:3B`.
- `android/app/build.gradle.kts` signs release builds with that key (falls
  back to the debug key when `key.properties` is absent).
- The first release build crashed at launch: the code shrinker removed the
  WorkManager database class the ads library needs. Fixed with
  `android/app/proguard-rules.pro`. The release build was then installed on
  the Android emulator and opened to the first story scene.
- Bundle: `dist/whispers-of-joppa-1.0.0-1.aab` (version 1.0.0, build 1;
  `dist/` is gitignored). Rebuild with `flutter build appbundle --release`.
  Every later upload needs a higher build number in `pubspec.yaml`.
- Good for Play **internal testing** only. Before a public release: real
  AdMob app id (still Google's test id), a real app icon (still the Flutter
  default), and the items under "Waiting on Jennifer".
- After Play accepts it, Google shows an "app signing key" SHA-1 in Play
  Console (Setup > App signing). Google sign-in on store-installed builds
  needs an Android OAuth client with THAT SHA-1 (plus the upload one above
  for builds installed directly).

## Decisions made for Jennifer (2026-10-05)

Jennifer said: "you decide. you can continue on the milestones. dont ask permission".
From here on, milestones proceed without waiting for approval and design choices are
recorded here instead of asked.

- **Starting Manna: 100** (a full bar), in `content/starting_board.json`.
- **Item art shown as cards.** Her item art is opaque JPEG on light grey, so each item is
  drawn as a rounded card filling its tile. If transparent PNGs are delivered later, the
  pipeline keeps them as PNG and no code changes are needed.
- **Art pipeline built** (`dart run tool/process_assets.dart`): raw art goes in
  `assets_incoming/items/` (not uploaded to GitHub), is renamed, shrunk to 256 px and
  written to `assets/items/` (19 MB → under 1 MB). It reports items with no art.
  Added dev package `image 4.10.1`. Not built: atlas packing, margin trimming
  (pointless for opaque art), and character/generator/location art handling.
- 39 of 53 items have art. Missing: all of Word (8) and Oil (6). No generator art yet.
- Character portraits processed by the pipeline: names fixed (`suprised`→`surprised`,
  `mad`→`angry`, `nuetral`→`neutral`, `naiomi`→`naomi`, doubled endings), shrunk to
  512 px wide (29 MB → 5.5 MB), 75 files in `assets/characters/`. Raw originals are in
  `assets_incoming/characters/`. Demas had two different neutral pictures; the first was
  kept. Still missing: Naomi happy, Esther happy, Amos sad, Demas happy, and everything
  but neutral for Marcus. Order cards now show the character's portrait.

## Website (2026-10-05)

The marketing website (built in Lovable, deployed by Vercel) originally lived at the top of
this GitHub repo. It was overwritten on 2026-10-04 when the game was force-pushed over it.
Recovered in full (104 files, 14 versions) and, at Jennifer's choice, placed in `web/`
beside the game with its history kept. A backup of the original is in the GitHub branch
`website-original` — do not delete it.

- `web/` is not part of the Flutter app and is not covered by the game's milestones or checks.
- It builds locally with `bun install && bun run build` (bun is in `~/development/bun`).
- It uses its own Supabase project (Lovable's), separate from the game's.
- Vercel must have **Root Directory = web** or every deploy fails with "vite: command not found".
- Lovable expects the site at the top of the repo, so Lovable sync is probably broken now.
- Never force-push this repo again.

## Waiting on Jennifer

**To do next (added 2026-10-05, for 2026-10-06) — Google Play, after the first bundle upload:**
- Milestone 22: sign in at https://joppa-s-whispers.vercel.app/admin/index.html with the
  details in `Downloads/WhispersofJoppa-admin-login.txt`, change the password, and look
  at the Events tab (the Boat Festival should be listed as "Yes, now").
- For pushes: Firebase console → Project settings → Service accounts → Generate new
  private key; tell Claude the file name so it can be stored on the server.
- Milestone 21: choose the first event theme (LIVEOPS section 3) and say whether Claude
  may apply the small server change that lets all players see switched-on events.
- Milestone 20 check: on a phone, tap the bell, turn on "Gentle reminders", allow
  notifications, use up your Manna, close the game and wait for the "Manna is full"
  notification (it will not arrive between 9 pm and 9 am).
- Milestone 19 check: open the Firebase console → Analytics → Realtime (or DebugView)
  while playing and confirm events arrive; then Crashlytics after a test crash.
- Milestone 18 check: after the tutorial, run out of Manna, tap "Watch an ad" in the
  popup, watch the sample ad to the end and confirm +20 Manna (and that closing it early
  gives nothing).
- Play Console → Testing → Internal testing → Testers: add her Gmail address, then open
  the opt-in link on her Android phone and install the game.
- Play Console → Settings → License testing: add the same Gmail address (so test
  purchases are not charged).
- Create a Play service account (SETUP_CHECKLIST Phase 4), give it access to Whispers of
  Joppa only, download its JSON file into Downloads and tell Claude the file name. Claude
  then creates the seven Pearl products on Google.
- Send Claude the SHA-1 shown under Play Console → Setup → App signing → "App signing key
  certificate" (needed for Google sign-in on the store-installed game).
- Move the `WhispersofJoppa-signing-key-BACKUP` folder out of Downloads to a safe,
  private place.

- Try real sign-in (see "Milestone 14 — state" for what each method needs).
- In Vercel: Project → Settings → Build and Deployment → Root Directory → `web`, then redeploy.
- Decide the Letter 1 scripture question (1 John 4:18 vs the story bible's period rule).
- Art still missing: Word and Oil item chains, all generators, bakehouse before/after
  pictures, scene backgrounds, and a few portraits (listed under "Decisions made").

Note: the Supabase CLI is at `~/development/supabase/supabase`, signed in by Jennifer and
linked to the Whispers of Joppa project only. Her account has seven other projects; never
touch them.

Note: Android Studio is not installed on this Mac. Android is built with the command-line
tools, a Temurin 21 JDK in `~/development/jdk`, and an emulator named `Pixel_Joppa`.
GitHub sign-in on this Mac is through the GitHub CLI in `~/development/gh`.
