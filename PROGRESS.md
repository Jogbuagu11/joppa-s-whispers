# Whispers of Joppa — Progress

## Current milestone: 5 — Content loading (done, waiting for Jennifer's approval before starting 6)

---

## Milestone status

| # | Milestone | Status |
|---|---|---|
| 0 | Project setup | DONE (m0-working) |
| 1 | Empty board | DONE (m1-working) |
| 2 | Drag & drop | DONE (m2-working) |
| 3 | Merging | DONE (m3-working) |
| 4 | Generators | DONE (m4-working) — approved by Jennifer 2026-10-05 |
| 5 | Content loading | DONE (m5-working) — awaiting approval |
| 6 | Energy (Manna) | Not started |
| 7 | Orders | Not started |
| 8 | Save/load (local) | Not started |
| 9 | Story scenes | Not started |
| 10 | Tasks & Blessings | Not started |
| 11 | Restoration scenes | Not started |
| 12 | Chapter 1 playable | Not started |
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
- `board_game.dart` is 282 lines; split drag handling and starting placement out before 300.
- Starter-item placement on the board has no unit test of its own (covered by device tests).
- Energy cost exists in both `generators.json` and `economy.json`; pick one in Milestone 6.
- Generators always start at level 1; add a level to `starting_board.json` when needed.
- TECH_SPEC "Pinned versions" table is still empty (versions are listed above in this file).
- `supabase/.temp/cli-latest` is tracked in git; fruit art is JPEG, spec asks for PNG.

## Assumptions to confirm (added in Milestone 5)

- A new player starts with **10 Manna**. The GDD gives the maximum (100) but no starting amount.
- The three starter tiles are test scaffolding, to be replaced by the Chapter 1 tutorial (M12).
- New content formats: `starting_board.json`, `placeholder_color`, `order_talents_per_tier`.

## Waiting on Jennifer

- Approve Milestone 5 so Milestone 6 (Energy / Manna) can start.
- Approve adding the `image` package so the asset pipeline can be built (or defer it).
- Confirm the assumptions above (starting Manna; test AdMob ID on iOS; minimum iOS 15).

Note: Android Studio is not installed on this Mac. Android is built with the command-line
tools, a Temurin 21 JDK in `~/development/jdk`, and an emulator named `Pixel_Joppa`.
GitHub sign-in on this Mac is through the GitHub CLI in `~/development/gh`.
