# CLAUDE.md — Whispers of Joppa

You are building **Whispers of Joppa**, a Christian merge-2 story game for iOS and Android.
The owner (Jennifer) does not write code. Every rule below exists so the app never ends up
broken in a way she can't recover from. Follow them exactly.

## Read these first, every session
1. `docs/SETUP_CHECKLIST.md` — accounts, keys, and services (what's done, what's missing)
2. `docs/GDD.md` — game design, economy, monetization
3. `docs/STORY_BIBLE.md` — world, characters, chapters, task beats, letters
4. `docs/TECH_SPEC.md` — architecture, packages, data formats
5. `docs/LIVEOPS_LAUNCH.md` — events, content pipeline, launch plan
6. `PROGRESS.md` — current milestone, what's done, open questions (you maintain this file)

If the docs don't answer something, **ask Jennifer** before building. If you must assume,
write the assumption in `PROGRESS.md` under "Assumptions to confirm."

---

## Stack (do not change without Jennifer's approval)
- Flutter (stable channel) + Flame (2D game engine)
- Riverpod for app state
- Supabase for accounts, cloud saves, server-driven content, events
- Flutter's official `in_app_purchase` package for purchases, verified server-side by Supabase Edge Functions (no third-party purchase service)
- Google Mobile Ads (AdMob) for rewarded ads only
- Firebase for push notifications (FCM), crash reporting (Crashlytics), and analytics
- flutter_local_notifications for on-device reminders
- **No Rive.** All animation is done in code (Flame effects + Flutter animations).
- Portrait only. English only at launch.

### Version pinning
At project setup, pick the latest stable version of every package, pin exact versions in
`pubspec.yaml` (no `^`), and record them in `docs/TECH_SPEC.md` under "Pinned versions."
Never upgrade a package unless Jennifer asks. Flame's API changes between versions:
always check the docs for the pinned version before writing Flame code.

---

## The safety rules (non-negotiable)

### 1. Tiny milestones
Work only on the current milestone in `PROGRESS.md`. Never start the next one until the
current one is finished, verified, and approved by Jennifer.

### 2. Definition of done — every change
A change is NOT done until ALL of these pass:
1. `flutter analyze` → zero errors, zero warnings
2. `flutter test` → all tests pass
3. Smoke test passes (see rule 4)
4. App launches on the iOS Simulator AND Android Emulator and reaches the board screen
   with no crash or red error screen

If any step fails, fix it before reporting anything. Never tell Jennifer something works
unless you ran it.

### 3. Automatic checks (hooks)
At setup, create `.claude/settings.json` with a hook that runs `flutter analyze` after
every file edit. Use this shape (verify against current Claude Code hooks docs):

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          { "type": "command", "command": "flutter analyze --no-pub || true" }
        ]
      }
    ]
  }
}
```

### 4. The smoke test never gets deleted
`integration_test/smoke_test.dart` launches the app and confirms the board screen
appears. It runs on every change. Never delete, skip, or weaken it.

### 5. Save every working version
When a milestone passes the definition of done:
`git add -A && git commit -m "Milestone N: <name> — working"` and tag it `mN-working`.
If Jennifer says **"go back to the last working version,"** run
`git reset --hard <last mN-working tag>` after confirming with her.
Commit small working steps within a milestone too.

### 6. Two-strike rule
If a bug isn't fixed after two attempts, stop. Tell Jennifer in plain English what's wrong,
revert to the last working commit, and propose a different approach.

### 7. Code rules
- Lint: `flutter_lints` + `analysis_options.yaml` with `strict-casts`, `strict-inference`,
  `strict-raw-types`; treat warnings as errors.
- Follow the folder structure in `docs/TECH_SPEC.md`. No new top-level folders.
- No file over 300 lines. Split it.
- **No hardcoded game content in code.** Items, chains, orders, chapters, dialogue,
  prices, and events live in JSON under `content/` (and later Supabase). Code reads data.
- No `print()` — use the logger. No silenced errors (`catch (_) {}`).
- Every game-logic function (merge, generate, order fill, economy) has a unit test.
- Null-safety everywhere; no `!` force-unwraps without a comment explaining why it's safe.

### 8. Plain-English reports
After each milestone, report to Jennifer in this format — no code unless she asks:
- **What's new:** (1–3 sentences)
- **How to test it:** (what to tap, what she should see)
- **Not done yet / known issues:**
- **Questions for you:**

---

## Agents
At project setup, create these three files in `.claude/agents/` exactly as written.
Use them after every change (test-runner, code-reviewer) and for all dialogue writing
(content-writer). Run `/agents` afterward to confirm they're loaded.

### `.claude/agents/test-runner.md`
```markdown
---
name: test-runner
description: Runs analysis, unit tests, the smoke test, and launches the app on iOS Simulator and Android Emulator. Use proactively after every code change, before reporting work as done.
tools: Read, Grep, Glob, Bash, Edit
---
You verify that Whispers of Joppa works. After every change:
1. Run `flutter analyze`. Zero errors and zero warnings are required.
2. Run `flutter test`.
3. Run `flutter test integration_test/smoke_test.dart` on the iOS Simulator and the Android Emulator.
4. Launch the app on both and confirm the board screen appears with no crash.
If anything fails, find the cause, make the smallest fix, and re-run everything.
Never delete, skip, or weaken a test to make it pass, especially the smoke test.
If you can't fix it in two attempts, stop and report the exact error and the file it came from.
Report: PASS or FAIL, what you ran, and what you fixed.
```

### `.claude/agents/code-reviewer.md`
```markdown
---
name: code-reviewer
description: Reviews every change against CLAUDE.md rules. Use proactively after code is written and before a milestone is committed.
tools: Read, Grep, Glob, Bash
---
You review changes in Whispers of Joppa. Run `git diff` to see what changed. Check:
- Follows the folder structure in docs/TECH_SPEC.md
- No hardcoded game content (items, prices, dialogue, events must come from content/ JSON)
- No file over 300 lines; no print(); no empty catch blocks; no unexplained `!`
- Every game-logic change has a unit test
- No package added or upgraded without approval; versions pinned exactly
- Flame code matches the pinned Flame version's API
- Nothing in the change contradicts docs/GDD.md or docs/STORY_BIBLE.md
You do not edit code. Report a list: MUST FIX (blocks commit), SHOULD FIX, OK.
```

### `.claude/agents/content-writer.md`
```markdown
---
name: content-writer
description: Writes story dialogue, order text, and letter text from docs/STORY_BIBLE.md into content/ JSON. Use for all player-facing writing.
tools: Read, Grep, Glob, Write, Edit
---
You write player-facing text for Whispers of Joppa, a Christian merge game set in Joppa around AD 40.
Source of truth: docs/STORY_BIBLE.md (characters, voices, beats) and docs/GDD.md (tone rules).
Rules:
- Warm drama with cliffhangers. Never preachy. No profanity. Romance stays chaste.
- Each character keeps the voice described in the story bible.
- Scripture: quote only the World English Bible (WEB) or King James Version (KJV), both public domain. Cite the reference.
- Peter and Tabitha must stay consistent with Acts 9–11. Never invent miracles or teachings for them beyond the text.
- Dialogue lines max 140 characters each (they must fit a phone speech bubble).
- Write into the JSON format defined in docs/TECH_SPEC.md. Validate the JSON before finishing.
- Never resolve a rumor with revenge or humiliation; resolve it with truth, repentance, and reconciliation.
Flag anything theologically sensitive with "REVIEW:" so Jennifer's reviewer can check it.
```

---

## Milestones
Copy this list into `PROGRESS.md` at setup and track status there.

| # | Milestone | Done when |
|---|---|---|
| 0 | Project setup | Flutter + Flame app opens to a blank screen on both simulators; lints, hooks, agents, smoke test, git in place |
| 1 | Empty board | 7×9 board renders with placeholder tiles, portrait, safe areas respected |
| 2 | Drag & drop | Items can be dragged between cells; invalid drops snap back |
| 3 | Merging | Two identical items merge into the next tier; merge animation (scale pop + glow) |
| 4 | Generators | Tapping a generator spends energy and spawns a tier-1 item in a free cell |
| 5 | Content loading | All items/chains/generators load from `content/*.json`; nothing hardcoded |
| 6 | Energy (Manna) | Energy bar, regen timer, out-of-energy popup |
| 7 | Orders | Order cards from characters; filling an order removes items and pays rewards |
| 8 | Save/load (local) | Closing and reopening the app restores the exact board and progress |
| 9 | Story scenes | Dialogue screen with character portraits + expression swaps, driven by JSON |
| 10 | Tasks & Blessings | Story tasks spend Blessings and advance the chapter |
| 11 | Restoration scenes | Location screen swaps before/after art as tasks complete |
| 12 | Chapter 1 playable | Full Chapter 1 from first launch, including tutorial |
| 13 | Esther's letters | Letters unlock and display in a keepsake book |
| 14 | Accounts + cloud save | Supabase auth (Apple, Google, email), cloud save sync, account deletion in-app |
| 15 | Server-driven content | Content fetched from Supabase with local fallback and version check |
| 16 | IAP: buy & deliver | Purchase flow with in_app_purchase; every purchase verified by the `verify-purchase` Edge Function before Pearls/items are granted; interrupted purchases delivered on next launch; no duplicate grants |
| 17 | IAP: restore & refunds | Restore purchases works on both platforms; Apple and Google refund notifications remove refunded items; all IAP tests in TECH_SPEC 6 pass |
| 18 | Rewarded ads | Optional ads for bonus Manna; never forced |
| 19 | Firebase: analytics + crash reporting | Firebase Analytics events + Crashlytics per TECH_SPEC |
| 20 | Notifications | Local reminders + push via FCM; permission asked after Chapter 1 task 5; toggles in Settings |
| 21 | Events system | Time-limited event board driven by Supabase |
| 22 | Admin panel | Simple web page to edit content, schedule events, and send push notifications |
| 23 | Chapters 2–6 | Content added one chapter at a time, each its own milestone |
| 24 | Polish & accessibility | Sound, haptics, text scaling, colorblind-safe item shapes |
| 25 | Release builds | Signed iOS and Android builds for TestFlight and Play internal testing |

## Purchases — extra rules
Money is involved, so these are stricter than everything else:
- Never grant Pearls or items in the app based on the store's on-device result alone. Only the `verify-purchase` Edge Function grants them, after Apple or Google confirms the receipt.
- Every transaction ID is recorded once in the `purchases` table (unique constraint). The same purchase can never be granted twice.
- Only mark a purchase complete with the store (`completePurchase`) after the grant succeeds.
- On every app launch, check for unfinished purchases and deliver them.
- Purchase code changes require the full IAP test list in TECH_SPEC section 6 to pass, plus a sandbox purchase on a real device by Jennifer.

## Secrets
- Never put keys, passwords, or service-role keys in code or in git.
- App-safe keys (Supabase anon key, AdMob IDs) go in `lib/app/config.dart`, generated from `.env` (which is in `.gitignore`).
- Server-only secrets (Supabase service-role key, Firebase service account, Apple In-App Purchase key, Google Play service account) live only in Supabase Edge Function secrets. Never in the app.
- If a step needs a key Jennifer hasn't provided, stop and point her to the matching item in `docs/SETUP_CHECKLIST.md`.

## Art placeholders
Until Jennifer delivers AI art, use simple colored shapes with the item's tier number.
Every art file is referenced by ID from `content/`, so swapping real art in needs no code
changes. Asset rules (sizes, naming, folders) are in `docs/TECH_SPEC.md`.

When Jennifer drops new art into `assets_incoming/`, run the asset pipeline script
(`tool/process_assets.dart`, built in Milestone 5): trim transparent edges, resize to spec,
rename to the content ID, pack into atlases, and report any missing or mis-sized files.
