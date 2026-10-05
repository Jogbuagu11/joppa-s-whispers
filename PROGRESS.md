# Whispers of Joppa — Progress

## Current milestone: 4 — Generators

---

## Milestone status

| # | Milestone | Status |
|---|---|---|
| 0 | Project setup | DONE (m0-working) |
| 1 | Empty board | DONE (m1-working) |
| 2 | Drag & drop | DONE (m2-working) |
| 3 | Merging | DONE (m3-working) |
| 4 | Generators | IN PROGRESS |
| 5 | Content loading | Partially done (ContentLoader built) |
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

Verified on the iOS Simulator (iPhone 17, iOS 26.5): analyze clean, 30 unit tests pass,
smoke test passes, generator tap test passes, board seen on screen.
**Not yet verified on Android** — so the milestone is not done and not tagged.

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

## Waiting on Jennifer

- **Android Studio**: the installed copy is the Intel version and cannot start on this
  Mac. Delete it, download the **Mac with Apple chip** version from
  developer.android.com/studio, run the setup wizard with default choices, and create a
  recent Pixel emulator in Device Manager. Tell me "emulator ready" when done.
