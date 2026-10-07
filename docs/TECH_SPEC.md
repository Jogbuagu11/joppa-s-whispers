# Whispers of Joppa — Tech Spec

## 1. Stack
| Area | Choice |
|---|---|
| App framework | Flutter (stable) |
| Game engine | Flame (board, items, effects) |
| State | flutter_riverpod |
| Backend | Supabase (auth, cloud save, content, events) |
| Purchases | `in_app_purchase` (official Flutter package) + Supabase Edge Functions for verification |
| Ads | `google_mobile_ads` (rewarded only) |
| Crash reporting | Firebase Crashlytics (`firebase_crashlytics`) |
| Analytics | Firebase Analytics (`firebase_analytics`) |
| Push notifications | Firebase Cloud Messaging (`firebase_messaging`) |
| Local notifications | `flutter_local_notifications` |
| Audio | `flame_audio` |
| Local storage | JSON save file via `path_provider` |
| Sign-in | Supabase auth with `sign_in_with_apple` and `google_sign_in`; email as fallback |
| Logging | `logging` package |
| Animation | Flame effects + Flutter implicit/explicit animations. **No Rive.** |

### Pinned versions
_Filled in at Milestone 0. Exact versions only, no `^`._

| Package | Version |
|---|---|
| flutter | |
| flame | |
| … | |

## 2. Folder structure
```
lib/
  main.dart
  app/            # app shell, routing, theme
  game/           # Flame: board, item components, effects
    board/
    items/
    effects/
  features/       # Flutter UI screens, one folder per feature
    ads/          # optional rewarded ads (bonus Manna)
    orders/
    story/        # dialogue scenes
    restoration/  # location screens
    letters/      # keepsake book
    shop/
    events/
    settings/
  domain/         # pure Dart game logic, no Flutter imports (fully unit tested)
    merge.dart
    generator.dart
    orders.dart
    economy.dart
    progression.dart
  data/           # content loading, save/load, Supabase, repositories
  services/       # purchases, ads, analytics, crash reporting, audio
content/          # all game data as JSON (bundled fallback)
assets/
  items/ generators/ characters/ locations/ ui/ audio/
assets_incoming/  # Jennifer drops raw AI art here
tool/             # scripts: process_assets.dart, validate_content.dart
test/             # unit tests (mirror lib/domain and lib/data)
integration_test/ # smoke_test.dart + flow tests
admin/            # web admin panel (Milestone 22); published copy in web/public/admin
web/              # marketing website (Lovable / TanStack Start + Vite), deployed by Vercel with Root Directory = web
```
Rule: `domain/` has zero Flutter or Flame imports, so all game rules are testable without a phone.

## 3. Content data (JSON)
All content lives in `content/` and is validated by `tool/validate_content.dart` (run in tests).
IDs are lowercase snake_case and never change once shipped.

### `content/chains.json`
```json
[
  {
    "id": "bakery",
    "name": "Bakery",
    "kind": "literal",
    "generator_id": "gen_pantry",
    "unlock_chapter": 1,
    "tiers": [
      { "tier": 1, "item_id": "bakery_01", "name": "Barley sheaf", "sell": 2 },
      { "tier": 2, "item_id": "bakery_02", "name": "Flour", "sell": 4 }
    ]
  }
]
```

### `content/generators.json`
```json
[
  {
    "id": "gen_pantry",
    "name": "Grandma's Pantry",
    "chain_id": "bakery",
    "levels": [
      { "level": 1, "odds": { "1": 1.0 } },
      { "level": 2, "odds": { "1": 0.9, "2": 0.1 } }
    ]
  }
]
```

A generator tap costs `generator_tap_cost` from `economy.json`. A generator may add
`"energy_cost": <number>` to override that for itself (for example an event generator).

### `content/starting_board.json`
The board a brand-new player sees. Columns count 0–6 from the left, rows 0–8 from the top.
```json
{
  "manna": 10,
  "generators": [{ "generator_id": "gen_pantry", "col": 2, "row": 8 }],
  "items": [{ "item_id": "bakery_01", "col": 0, "row": 0 }]
}
```
- A generator entry may carry `"chapter": N`: it is not on a new game's board but arrives when the story reaches chapter N (at that cell, or the nearest free one). It must match the generator's `unlock_chapter` in `generators.json`.
- Orders wait for their chapter: an order with `"chapter": N` is not dealt until every task of the earlier chapters is done. Each chapter's own orders must pay enough Blessings for its own tasks (the validator checks).

### Placeholder colours
Each chain in `chains.json` also has `"placeholder_color": "#RRGGBB"`, the colour of its
tiles until real art is in place. Each tier's `"sell"` is the Talents earned for selling it.

### `content/orders.json`
```json
[
  {
    "id": "ch1_o_003",
    "chapter": 1,
    "character_id": "silas",
    "kind": "literal",
    "items": [{ "item_id": "bakery_04", "count": 2 }],
    "rewards": { "talents": 40, "blessings": 1 },
    "text": "Two flatbreads for the night crew, little loaf?",
    "scene_id": null
  }
]
```
Spiritual orders set `"kind": "spiritual"` and a `scene_id` that plays on completion.

### `content/chapters.json`
```json
[
  {
    "id": "ch1",
    "number": 1,
    "title": "Homecoming",
    "location_id": "bakehouse",
    "unlocks_chains": ["bakery", "fruit"],
    "crown_id": null,
    "tasks": [
      {
        "id": "ch1_t_01",
        "beat": 2,
        "title": "Clear the doorway",
        "cost_blessings": 1,
        "scene_id": "ch1_s_02a",
        "restores_area": "bakehouse_door",
        "letter_id": null
      }
    ]
  }
]
```

### `content/scenes.json` (dialogue)
```json
[
  {
    "id": "ch1_s_01",
    "background": "loc_harbor_dusk",
    "lines": [
      { "speaker": "dockworker", "expression": "neutral", "text": "That's the widow they sent away from Caesarea." },
      { "speaker": "silas", "expression": "happy", "text": "Little loaf. You came." }
    ]
  }
]
```

### Other files
- `characters.json`: id, name, list of expression IDs (`neutral`, `happy`, `sad`, `angry`, `surprised`, `thinking`, plus extras per character)
- `locations.json`: id, name, areas (each with `before` and `after` image IDs)
- `letters.json`: id, chapter, title, body, reference
- `economy.json`: every number from GDD Section 12
- `products.json`: IAP product IDs mapped to contents
- `events.json`: local fallback for events (live events come from Supabase)
  - One event = `{id, name, starts_at, ends_at, config}`; `config` = `{board: {cols, rows}, chain: <a chains.json entry>, generator: <a generators.json entry + col, row>, milestones: [{points, manna?, talents?}]}`. Checked by `lib/data/event_validator.dart`; a faulty event is left out, never shown.
  - On the phone: `events_cache.json` (the server's last list) and `event_progress_<id>.json` (board, points, reward steps paid).
- `tutorial.json`: first-session hints in order: id, speaker, text, `done_when` (`merge`, `generator_tap`, `order_delivered` + id, `task_done` + id, or `tap`), `free_manna`
- `endings.json`: the message shown when a chapter's last task is done: chapter_id, title, body, button

## 4. Save data
- Local save file: `save.json` in the app documents folder, written after every meaningful action (debounced 2 seconds) and on app pause.
- Contents: board cells, basket, currencies, Manna and last-regen timestamp, chapter/task progress, discovered items, letters found, crowns, settings, save version.
- `save_version` field + migration functions for every format change. Never break an existing save.
- Current format: version 5. Version 2 added `completed_orders`; version 3 added `completed_tasks`; version 4 added the tutorial position, free taps used, chapter endings seen and the content version; version 5 added Pearls, applied store transactions and owned one-time products. Migrations live in `migrateSave` in `lib/domain/save_state.dart`.
- Cloud save (Milestone 14): same JSON stored in Supabase `saves` table. On conflict, keep the save with more progress and ask the player only if both have progressed.

## 5. Supabase
| Table | Purpose |
|---|---|
| `profiles` | user id, display name, created date |
| `saves` | user id, save JSON, save version, updated at |
| `content_versions` | content bundle version + storage path |
| `events` | id, name, start, end, config JSON |
| `purchases` | user id, platform, product id, transaction id (unique), status (granted / refunded), raw verification result, timestamps |
| `wallet_grants` | every Pearl/item grant and removal tied to a purchase (audit trail) |
| `device_tokens` | user id, FCM token, platform, notification settings, updated at |
| `notifications_log` | every push sent: type, audience, time (for frequency caps) |
| `admins` | accounts allowed to use the admin panel (rows added from the server side only) |

- Row-level security on every table: users read/write only their own rows.
- **Server-driven content:** the app bundles `content/` as a fallback. On launch it checks `content_versions`; if newer, it downloads the bundle (JSON + new art) from Supabase Storage, validates it, and switches over. If download or validation fails, it keeps the current content. A bad content push must never crash the app.
- **Account deletion** is available in Settings (required by Apple). It deletes the profile and save.

## 6. Purchases (no third-party service)
| Product ID | Type |
|---|---|
| `pearls_tier1` … `pearls_tier6` | Consumable |
| `starter_pack` | Non-consumable (one-time) |
| `season_pass_<event_id>` | Consumable, tied to an event |

### Purchase flow
1. App loads products from the store with `in_app_purchase`; prices shown are the store's localized prices (never hardcoded).
2. Player taps buy → store payment sheet.
3. App sends the purchase token/receipt to the **`verify-purchase`** Edge Function.
4. Edge Function verifies it directly with the store:
   - **Apple:** App Store Server API, using the In-App Purchase key (.p8) stored as a secret
   - **Google:** Google Play Developer API (purchases.products), using the Play service account stored as a secret
5. If valid and the transaction ID is new: insert into `purchases`, grant contents to the player's save, log in `wallet_grants`, return success.
6. App updates the wallet, then calls `completePurchase`. For Google consumables, the Edge Function also consumes the purchase after granting.
7. If verification fails: grant nothing, show "Purchase couldn't be verified," keep it pending for retry.

### Interrupted purchases
On every launch and when the app returns to the foreground, read the purchase stream for pending or unfinished purchases and run steps 3–6. Delivery is safe to retry because transaction IDs are unique.

### Restore purchases
"Restore purchases" in Settings calls `restorePurchases()`. Only the non-consumable `starter_pack` is restored (consumables can't be). Also restored automatically when a player signs in on a new device, from the `purchases` table.

### Refunds
- **Apple:** App Store Server Notifications V2 sent to the **`store-notifications-apple`** Edge Function (URL set in App Store Connect).
- **Google:** Real-time developer notifications via a Google Cloud Pub/Sub push subscription to the **`store-notifications-google`** Edge Function; plus a daily check of the Voided Purchases API.
- On refund: mark the purchase `refunded`, remove the remaining unspent Pearls from that purchase (never below zero), remove the starter-pack items if unused, log in `wallet_grants`.

### IAP tests (all must pass before Milestone 17 is done)
- Unit tests: grant logic, duplicate transaction ignored, refund removal never goes below zero
- Edge Function tests with recorded valid/invalid/duplicate receipts
- Sandbox (iOS) and license-tester (Android) on real devices:
  - [ ] Buy each Pearl pack → correct amount granted once
  - [ ] Buy starter pack → granted; second purchase blocked
  - [ ] Kill the app mid-purchase → delivered on next launch
  - [ ] Turn on airplane mode right after paying → delivered when back online
  - [ ] Restore purchases on a fresh install → starter pack restored
  - [ ] Cancel at the payment sheet → nothing granted, no error screen
  - [ ] Refund test (Google: refund from Play Console order management; Apple: sandbox refund) → Pearls removed

## 7. Ads
- Rewarded ads only, always player-initiated, with daily caps from `economy.json`.
- No ads before the end of the tutorial.
- If an ad fails to load, hide the button; never block gameplay.

## 8. Analytics events (Firebase Analytics)
`tutorial_step`, `tutorial_complete`, `merge` (sampled), `generator_tap` (sampled), `order_complete`, `task_complete`, `chapter_complete`, `out_of_energy`, `purchase_started`, `purchase_complete`, `ad_watched`, `letter_opened`, `session_start`, `session_end`.
Never send personal data in events.

## 9. Crash reporting (Firebase Crashlytics)
- Capture all uncaught errors (Flutter and Dart zones).
- Attach app version, content version, current chapter. No personal data.

## 9b. Notifications
**Local (scheduled on the device, no server):**
| Type | When |
|---|---|
| Manna full | When Manna will reach max (only if the player was low when they left) |
| Daily clay jar ready | Once a day at the player's usual play time |
| Come back | After 3 days away, one gentle reminder with a story teaser; never repeated more than weekly |

**Push (sent from Supabase through FCM):**
| Type | When |
|---|---|
| Event started | Start of each main event (FCM topic `events`) |
| Event ending | 24 hours before a main event ends, only to players who joined it |
| New chapter | When a new chapter goes live (topic `chapters`) |

**Rules:**
- Ask permission after Chapter 1 task 5 with an in-game explainer first, never on first launch (iOS only lets you ask once).
- Android 13+ requires the `POST_NOTIFICATIONS` permission; same timing.
- Settings has separate toggles: reminders, events, new chapters. The same screen also holds Sound, Vibration and "Numbers on items" (Milestone 24), kept on the phone in `comfort.json`.
- Max 1 push per day per player; no notifications 9 pm–9 am in the player's time zone.
- Pushes are sent by a Supabase Edge Function using the FCM HTTP v1 API, triggered from the admin panel or on a schedule. The Firebase service account key lives only in Edge Function secrets.
- As built (Milestone 22): `send-push` accepts only a signed-in admin, sends to the `events` or `chapters` topic, and the database (`reserve_push`) allows one push per 24 hours for the whole game. Per-player sending, scheduled pushes and time-zone quiet hours are not built.
- Admin panel: `admin/` (plain HTML + JavaScript, no build step; supabase-js 2.45.4 kept beside it).
- Tapping a notification opens the matching screen (event board, new chapter, rooftop board).

## 10. Art asset specs
| Type | Size (px) | Format | Naming |
|---|---|---|---|
| Item | 256 × 256 | PNG, transparent | `item_<chain>_<tier 2-digit>.png` → `item_bakery_04.png` |
| Generator (per level) | 256 × 256 | PNG, transparent | `gen_<id>_l<level>.png` → `gen_pantry_l2.png` |
| Currency / reward item | 256 × 256 | PNG, transparent | `cur_<name>_<tier>.png` → `cur_manna_03.png` |
| Character portrait (per expression) | 1024 × 1536 | PNG, transparent | `char_<id>_<expression>.png` → `char_naomi_happy.png` |
| Location area (before/after) | 1290 × 2796 | PNG or WebP | `loc_<location>_<area>_<before|after>.png` |
| Scene background | 1290 × 2796 | PNG or WebP | `bg_<id>.png` |
| UI elements | as needed | PNG, transparent | `ui_<name>.png` |
| App icon | 1024 × 1024 | PNG, no transparency | `app_icon.png` |

**Pipeline (`tool/process_assets.dart`):** reads `assets_incoming/`, trims transparent margins, centers on canvas, resizes to spec, renames if a mapping file is provided, packs item/generator sprites into atlases, and prints a report: missing assets (by content ID), wrong sizes, and unused files.

## 11. Testing
- **Unit tests:** every function in `domain/` (merge, odds, orders, economy, progression, save migrations).
- **Content tests:** `validate_content.dart` runs in `flutter test`; it fails if any ID is missing, any chain skips a tier, any order requests a locked chain, or any dialogue line exceeds 140 characters.
- **Smoke test:** `integration_test/smoke_test.dart` launches the app and finds the board screen.
- **Flow tests:** first-session tutorial; fill an order; complete a task; save → restart → restore.
- **Devices:** iOS Simulator + Android Emulator every change. Jennifer tests on her real devices at every milestone.

## 12. Performance targets
- 60 fps on the board on mid-range phones; no drop below 30 fps on low-end Android.
- Cold start to board under 4 seconds on mid-range phones.
- App download size under 150 MB; extra art arrives with content bundles.
