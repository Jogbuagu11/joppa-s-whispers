# Whispers of Joppa — Progress

## Current milestone: 12 — Chapter 1 playable (done; next is 13 — Esther's letters)

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
| 13 | Esther's letters | Not started |
| 14 | Accounts + cloud save | Not started |
| 15 | Server-driven content | Not started |
| 16 | IAP: buy & deliver | Not started |
| 17 | IAP: restore & refunds | Not started |
| 18 | Rewarded ads | Not started |
| 19 | Firebase: analytics + crash reporting | Not started |
| 20 | Notifications | Not started |
| 21 | Events system | Not started |
| 22 | Admin panel | Not started |
| 23 | Chapters 2–6 | Not started |
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
| firebase_crashlytics | 5.4.0 |
| firebase_analytics | 12.6.0 |
| firebase_messaging | 16.7.0 |
| flutter_local_notifications | 22.3.1 |
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

DONE. Verified on the iOS Simulator and Android Emulator: analyze clean, 248 unit tests
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
- Free Manna covers only the first three hints, so it cannot be used to play free forever.
- Chapter 1 needs about 162 generator taps in all; with 100 Manna to start and 1 back
  every 2 minutes, a player finishes it over a couple of sessions.

Content notes for Jennifer's reviewer (flagged "REVIEW:" by the content writer):
- tut_love has Naomi say "Tree of Life" and call the glowing fruit "Love" (never "Fruit of
  the Spirit"). Confirm that is fine for a tutorial hint.
- "A Blessing for one flatbread" / "Fill orders for Blessings" could read as blessings
  earned by works; wording follows the GDD's currency name.
- Scene order: the tutorial happens on the rooftop board before task 1's scene, which ends
  with Silas inviting Naomi up to the roof.

Not in this milestone:
- No device test plays the entire chapter by hand gestures (the rules-level playthrough
  test covers completability; device tests cover each step type).
- No pointing hand or highlight on the thing to tap; hints are text only.
- The GDD's 30–40 tasks per chapter, Kindness order, Jars of Clay and rubble cells are not built.
- Analytics events `tutorial_step` / `tutorial_complete` come with Milestone 19.

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

- In Vercel: Project → Settings → Build and Deployment → Root Directory → `web`, then redeploy.
- Confirm the assumptions above (starting Manna; test AdMob ID on iOS; minimum iOS 15).

Note: Android Studio is not installed on this Mac. Android is built with the command-line
tools, a Temurin 21 JDK in `~/development/jdk`, and an emulator named `Pixel_Joppa`.
GitHub sign-in on this Mac is through the GitHub CLI in `~/development/gh`.
