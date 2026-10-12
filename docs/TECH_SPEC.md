# Whispers of Joppa — Tech Spec

## 1. Stack
| Area | Choice |
|---|---|
| App framework | Flutter (stable) |
| Game engine | Flame (board, items, effects) |
| State | flutter_riverpod |
| Backend | Supabase (auth, cloud save, content, events) |
| Purchases | `in_app_purchase` (official Flutter package) + Supabase Edge Functions for verification |
| Ads | `google_mobile_ads` (rewarded, and one banner under the board) |
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
    bubbles/      # bubbles over the board (a merged item to keep)
    wheel/        # the Blessing Wheel, Jars of Clay, the odds panels
    levels/       # player level badge and level-up message
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
- Generators (Milestone 26): a `generators.json` entry may add `type` (`standard`, `charged`, `free`, `temporary`) with `charges` + `cooldown_seconds`, `interval_seconds` + `max_waiting`, or `taps`. A `starting_board.json` generator may add `level` (the player level it waits for). A chain tier may add `use`: `{manna}` or `{skip_seconds}` / `{skip_all}`; a chain of such gift items has no `generator_id`. `levels.json` levels may add `items` and `generator` (temporary only). Rules: `lib/domain/generator_types.dart`.
- `offers.json` (Milestone 30, first part): `daily_deals` (`pearl_deals_per_day`, `free` and `for_pearls` lists of `{id, name, pearl_price?, manna?, talents?, items?}`), `special` (the Joppa Special: its words, `picture`, and up to three `packs` of `{product_id, name, featured?}` naming Pearl products) and `text`. Checked by `lib/data/offers_validator.dart`.
- `board_text.json`: the few words used on the board (`use_manna`, `use`, `keep`, `hourglass_hint`, `ok`, `sell` with `{talents}`, `boost_hint` with `{boost}`, `knife_hint`, `thread_hint`, `sealed_hint` with `{chain}`, and the bubble words `bubble_label`, `bubble_body`, `bubble_pearls`, `bubble_ad`, `bubble_leave`).
- Boost and rare chains (Milestone 27): a `levels.json` unlock may add `boost`: `{manna_times, tier_bonus}` (offered only if `available`); a `generators.json` entry may add `rare`: `{chain_id, chance}` (chance above 0, at most 0.5; never its own chain). A rare chain has no `generator_id`. Rules: `resolveGeneratorTap` in `lib/domain/generator.dart`.
- Board extras (Milestone 28): a chain tier's `use` may also be `{split: true}` (splitting knife), `{wild: true}` (Golden Thread) or `{opens_with: <chain id>, gives: <item id>}` (a sealed jar, alone in its chain). Exactly one kind per item. Rules: `lib/domain/tools.dart`. The `bubbles` unlock in `levels.json` carries `bubble`: `{chance, higher_chance, seconds, pearls_per_tier, ad_max_tier, talents_per_tier, max_at_once}`; rules in `lib/domain/bubbles.dart`, state in `lib/features/bubbles/`. Bubbles are not saved. Keeping a bubble's item by ad uses the same daily cap as Manna ads; never for a chain without a generator.
- Chance features (Milestone 29): `content/chance.json` holds `paid_blocked_countries` (two-letter codes), `wheel` (`free_spins_per_day`, `ad_spins_per_day`, `pearl_spins_per_day`, `pearl_spin_base`, `pearl_spin_step`, `prizes`), `jars` (`clay_every_orders`, `order_jar`, `kinds`: each `item`, optional `pearl_price`, `prizes`), `lucky_boost.steps` (`times`, `weight`), `mystery_bubble` (`share`, `lifts`: `tiers`, `weight`) and `text`. A prize is `{id, name, weight, manna?, talents?, pearls?, items?, generators?, free_only?}`; a prize of Pearls must be `free_only`, and a jar with a `pearl_price` may hold none. A jar item's `use` is `{jar: <kind>}`. Checked by `lib/data/chance_validator.dart`. Rules: `lib/domain/chance.dart`, `wheel.dart`, `jars.dart`, `lucky.dart`; screens in `lib/features/wheel/`. Outcomes are drawn on the device from the same table the player is shown.
- Selling from the board: an item with a `sell` price can be sold by tapping it if its chain has no `generator_id` or it is the top tier of its chain, unless an order on show asks for it (`BoardGame.canSell`).
- `levels.json` (Milestone 25): `xp_per_task_by_chapter`, `xp_per_task_default`, `levels` (`level`, total `xp` to reach it, `talents` reward), `unlocks` (`level`, `feature`, `name`, `available`), and the `text` of the badge and level-up message. Checked by `lib/data/level_validator.dart`.

## 4. Save data
- Local save file: `save.json` in the app documents folder, written after every meaningful action (debounced 2 seconds) and on app pause.
- Contents: board cells, basket, currencies, Manna and last-regen timestamp, chapter/task progress, discovered items, letters found, crowns, settings, save version.
- `save_version` field + migration functions for every format change. Never break an existing save.
- `extras` (added within version 7): a map of small named records kept by later features (`wheel`: the day and its spins taken). Unknown records are kept untouched.
- Optional fields added within version 7: a generator's `timer` (`left`, `at`), `pending_grants` (gifts waiting for room, as `item:<id>` / `gen:<id>`) and `boost` (the generator boost switched on; 0 = none).
- Current format: version 7. Version 6 added the day's rewarded-ad count; version 7 added `level_rewarded` (the last player level whose rewards were given; XP is not saved, it is worked out from the tasks done). Earlier: Version 2 added `completed_orders`; version 3 added `completed_tasks`; version 4 added the tutorial position, free taps used, chapter endings seen and the content version; version 5 added Pearls, applied store transactions and owned one-time products. Migrations live in `migrateSave` in `lib/domain/save_state.dart`.
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
- On refund: mark the purchase `refunded`, remove the remaining unspent Pearls that purchase really gave (never below zero) and ownership of a one-time product, log in `wallet_grants`. Manna, Talents, items and generator levels stay: once the player has played on, there is no telling which were the purchase's.

### Offers (Milestone 30, EXPANSION section 21)
- Reusable store products `offer_099` … `offer_4999` carry only a price. They are listed in `content/offers.json` (`offer_products`), never in `content/products.json`.
- Table **`offers`**: `id`, `kind` (session_start, out_of_manna, level_up, chapter_complete, flash_sale, themed, fallback), `product_id`, `title`, `subtitle`, `contents` (`{pearls, manna, talents, items[]}`), `audience` (any / non_payer / payer), `min_level`, `next_offer_id` (shown next time if this one is turned down), `duration_seconds` (countdown from first shown), `starts_at`, `ends_at`, `priority`, `is_active`, `is_fallback`, `updated_at` (kept by a trigger). Players can read only rows that are switched on, not fallbacks, and already started. One `is_fallback` row per product is the safety net.
- Table **`offer_impressions`**: `user_id`, `offer_id`, `product_id`, `outcome` (shown / dismissed by the player; bought by the server).
- **`purchases.grant_contents`** is exactly what a purchase gave, decided by `verify-purchase` and written with the purchase; **`purchases.offer_id`** names the offer; **`purchases.first_bonus`** marks the one doubled first Pearl pack per player (a unique index refuses a second).
- The app sends `offer_id` with the purchase. The server believes it only for a real offer at that price, for that kind of player, switched on (or switched off / ended within 7 days). Otherwise: the offer this player was last shown at that price, then the fallback. With no fallback it answers 500 and the purchase is retried, never lost.
- The game gives what `grant_contents` says; a purchase row from before that column gives what its product gives.
- Rules for when offers appear are in `content/offers.json` (`rules`: `max_per_session`, `max_at_session_start`, `session_start_per_day`, `level_every`, `repeat_after_days`) and `lib/domain/offers.dart`. The player's memory of offers is in the save under `extras.offers`.
- **Deploy order (it matters):** 1. migration `…_offers.sql`; 2. the `verify-purchase` function; 3. migration `…_offer_seed.sql`; 4. an app build that knows offers. A build from before offers (20 or earlier) must not be used for purchases once step 2 is live: it would give a single first pack where the server recorded a double.

### Treasure Jar (Milestone 31, EXPANSION sections 13 and 21.1)
- Settings are in `content/offers.json` under `treasure_jar`: `sizes` (`id`, `product_id`, `pearls` held when full, smallest first), `earn` (Pearls saved per `order`, `task` and `level`), and its `text`. It opens at the level named in `content/levels.json` (`treasure_jar`).
- The jar's count is kept in the save under `extras.treasure` (`saved`, `opened`, `told_full`). It only decides when the jar may be opened and what the player sees.
- Opening is a purchase of that size's store product (`treasure_jar_small` / `_medium` / `_large`), possible only when the jar is full. What it gives is decided by `verify-purchase` like any product: the fixed amount in `PRODUCTS` (`rules.ts`), which a server test keeps equal to the content file. It is never doubled by the first-purchase bonus.
- When the purchase is put into the game the wallet tells the jar (`PurchasesController.onApplied`), which becomes an empty jar of the next size; the last size repeats. A jar purchase is not marked as delivered until the jar is there to be emptied.
- Limit: the server does not check that the jar was really full. A tampered app could only pay the full price for the fixed amount.
- Changing a size's Pearls means changing `content/offers.json` AND `PRODUCTS` in `rules.ts`, then redeploying `verify-purchase`.

### Season pass (Milestone 31, EXPANSION section 13)
- An event has a pass if its `config` carries `pass`: `premium` (one reward per milestone, in order: `pearls`, `manna`, `talents`, `items`) and optionally `plus` (`bonus_percent`, and `endless`: `every` N points past the last milestone, with a reward that may not contain Pearls). Checked by `lib/data/season_pass_validator.dart`; a bad pass keeps the event from being shown.
- The pass's two store products and its words are in `content/offers.json` under `season_pass`.
- **Buying:** the app sends the event's id as `offer_id` with the purchase. `verify-purchase` records `grant_contents.pass = {tier, event_id}` (`pass_rules.ts`): the event the app named, or the one it last noted as shown (`offer_impressions`, written before the store opens), if that event is on now and has a pass; otherwise the event with a pass on now that ends soonest (the one the game shows), else the next to start, else the event named, so a late payment is never spent on an event that is over. The pass gives nothing at once.
- **Holding:** the app reads the passes held from the server's purchase list every time it is read (`SeasonPassLedger`, kept in the save under `extras.passes` for offline play). A refunded pass is gone at the next read. Premium bought twice for one event counts as Premium Plus (the same money), which is how Premium is upgraded.
- **Paying:** `EventController.settle()` pays free milestones, Premium rewards for milestones reached, and endless steps, each once (`premium_paid` and `endless_paid` in the event progress file). A pass bought late pays everything already reached. Premium Plus points are the points earned plus the bonus, also for points earned before it was bought.
- Limits: rewards a pass has already paid are not taken back on refund; the exclusive decoration waits for decorations (Milestone 36).
- **Server steps for a pass to work:** deploy `verify-purchase`; add `pass` to the event's `config` in the `events` table (the admin panel's event editor).

### Goal events (Milestone 32 part 1, EXPANSION section 22)
- Short events played on the ordinary board, several at once. They are rows of the same `events` table; what marks one is `config.type`: `milestone` (counts Talents earned from orders), `energy` (Manna spent, on either board), `collect` (a token drops from `drop_percent` of merges), `order` (`per_order` tokens with each order). A row with no `type` is a feast event with its own board.
- `config` also carries `blurb` (what to do), `token` (what is counted, in words) and `milestones` (`points` plus `pearls`, `manna`, `talents`, `items`). Checked by `lib/data/goal_event_validator.dart` and, in the admin panel, `admin/event_rules.js` (kept in step by hand; both have tests).
- Each kind opens at its level in `content/levels.json` (`milestone_event`, `energy_event`, `collect_event`, `order_event`), after the tutorial.
- Progress is in the save under `extras.goal_events` (`{event id: {points, paid}}`); progress in events the server no longer lists is dropped. Rewards are given on the phone, like the feast event's.
- Builds before 26 pass over rows with a `type`.

### Paid chance: the `roll` function (Milestone 29/30)
- A Pearl spin of the Blessing Wheel and a bought Jar of Clay are drawn by the `roll` Edge Function when it can be reached (signed in, online, answer within 4 seconds, same content version); otherwise the phone draws from the same table. Free tries never go to the server.
- The app asks the server FIRST and takes the Pearls (or the jar) only once it has an answer or has given up, in the same step that gives the prize. Closing the game while waiting costs nothing.
- The app accepts only a prize that try could give (`prizeNamed`): never Pearls for a paid try, never an unknown id.
- `supabase/functions/roll/tables.ts` is generated from `content/chance.json` by `tool/sync_server_chance.py`. The app sends `tables_version` (a number at the top of `content/chance.json`); the function draws only if it holds that same number, otherwise it answers 409 and the phone draws. Whenever a prize or a weight changes: raise `tables_version`, run the tool, and redeploy `roll`. Other content changes need nothing.
- The function only draws paid tries, refuses more than 20 draws a minute per player, and records each draw in `rolls` (players read their own rows; only the server writes). The table records draws, not prizes handed over: a draw answered too late is recorded but not used.
- Limits: Pearls and prizes live in the save on the phone, so this does not stop a tampered app; the country switch is applied in the app only.

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
- Rewarded ads, always player-initiated, with daily caps from `economy.json`; and one standard banner (320×50) under the board (`lib/services/google_banner.dart`), shown only after the tutorial, only once consent is settled, and never to a player who has bought anything (`bannerAllowed` in `lib/domain/ads.dart`). No interstitial, native or app-open ads.
- Ad ids: the AdMob app ids are in `ios/Runner/Info.plist` and `android/app/src/main/AndroidManifest.xml`; the four unit ids (rewarded and banner, each platform) are in `tool/release_defines.json`. Without them a build uses Google's public test units. The publisher is in `web/public/app-ads.txt`.
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

## Daily tasks, races and the global goal (Milestone 32)
- `content/daily_tasks.json`: `per_day`, `pool` (`id`, `kind` orders/talents/manna/merges, `target`, `text`, `reward`), `chest`, `weekly` (`days`, `reward`), `text`. Rules in `lib/domain/daily_tasks.dart`; save record `daily_tasks`.
- Race: an `events` row with `config.type` `race`: `goal` (orders), `rivals` (4 of `name`, `hours`), `prizes` (3 rewards). Rules in `lib/domain/race.dart`.
- Global goal: `config.type` `global` with `milestones` on the total of all players. Tables `global_goals`, `global_goal_parts`; function `add_to_global_goal(p_event_id, p_amount)`. Save record `global_goals` (`mine`, `sent`, `total`, `paid`).

## Calendar, album, pet, study guides, order quests, replay (Milestones 36, 38, 39)

All six are content files checked by their own validators (`lib/data/*_validator.dart`)
and mandatory in a bundle from content version 48: `calendar`, `album`, `pet`,
`study_guides`, `quests` (plus three `replay_*` keys in `board_text`). Each keeps one
record in the save's extras: `calendar`, `album`, `pet`, `quests`.

| Feature | Rules (pure Dart) | Where it shows | Unlock |
|---|---|---|---|
| Login calendar | `domain/login_calendar.dart` | strip button `calendar_button` | level 3 |
| Keepsake album | `domain/album.dart`, `features/events/album_drop.dart` | `album_button`; a card may come with a delivered order | level 6 |
| Shadow the cat | `domain/pet.dart`, `features/events/board_gives.dart` | `pet_button` | level 4 |
| Order quests | `domain/order_quests.dart`, `features/events/board_gives.dart` | `quests_button` | level 9 |
| Study guides | `domain/study_guides.dart` | Esther's letters, `study_guides_button` | chapter finished |
| Story replay | `domain/replay.dart` | Esther's letters, `story_replay_button` | task finished |

Anything that takes an item off the board for a reward (feeding Shadow, giving to a
quest) goes through `board_gives.dart`: remove from the board, write the record, then
grant. The pet validator refuses any gift that gives as much Manna as its food costs.

### Free Manna codes (Milestone 39)

Tables `manna_links` (admins only) and `manna_link_claims` (a player reads only their
own); function `claim_manna_link(p_code)` answers `ok`, `used`, `over` or `unknown` and
writes the claim once (primary key `code, user_id`). In the app: `domain/manna_links.dart`
(rules), `data/supabase_manna_links.dart`, `features/settings/manna_link_dialog.dart`
(the pop-up, opened from the board's `manna_link_button`, level 2). Codes are made and
ended (never deleted) on the admin panel's "Free Manna codes" page (`admin/admin_links.js`).
