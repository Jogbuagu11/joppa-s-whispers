# Whispers of Joppa — Full Feature Expansion

This document adds to the original doc set. Everything here is **in scope for launch**.
Where this document and an earlier doc disagree, **this document wins**.

Save it as `docs/EXPANSION.md`.

---

## Part 1 — Changes to the original docs

### GDD changes
| GDD section | Original | Now |
|---|---|---|
| 7. Jars of Clay | Contents shown before opening; no surprise paid contents | Random contents from a published loot table; can be earned or bought with Pearls (see 20.4) |
| 13. Monetization principles | "Paid items always show exactly what you get; no paid random boxes" | No purchases during the tutorial; ads always optional; every random reward (paid or free) shows its odds before the player buys or spins, as Apple and Google require. Full offer and pop-up system in section 21. |
| 13. Season pass | Free track + paid track ($4.99) | Three tiers: Free; **Premium** ($4.99): more Manna, Pearls, merge items, an exclusive decoration; **Premium Plus** ($9.99): everything in Premium + bonus points + an endless reward track after the last milestone |
| 13. New products | — | **Treasure Jar** (piggy bank): fills with Pearls as the player plays; break it open for $2.99–$9.99 depending on size. **Bundles and offers:** section 21. **Paid spins and jars:** Pearls buy extra Blessing Wheel spins and Golden Jars (section 20.4). |
| 13. Rewarded ads | Manna, double reward, daily jar | Also a free wheel spin. Fewer ad placements for players who have paid. |
| 14. Live ops | One main event + weekend events | Several events run at the same time (section 22) |
| 17. Out of scope | Social features out of scope | Social features are in scope (section 23). Still out: voice acting, localization, tablet layouts, landscape. |

### Store listing change (STORE_LISTING.md, age rating)
- Simulated gambling: **infrequent/mild** (Blessing Wheel, dice board game)
- Loot boxes / random paid items: **yes** (Jars of Clay, extra wheel spins), with odds shown in the game

---

## Part 2 — New game features (continues the GDD)

## 18. Player levels and XP
- Every story task gives **XP**. Players level up from 1 to **60 at launch** (more added with each new chapter).
- **Each level-up:** refills Manna to full, gives a small reward (Talents, Pearls, sometimes a generator), and may unlock a feature.
- XP needed rises each level; tuned so level 10 arrives in about 2 sessions.
- Unlock schedule (starting values):

| Level | Unlocks |
|---|---|
| 3 | Daily tasks, daily login calendar |
| 5 | Blessing Wheel, bubbles |
| 7 | First milestone event, Treasure Jar |
| 9 | Order quests |
| 10 | Races, profile and avatar |
| 12 | Friends and gifting |
| 15 | Generator boost (2x), Prayer Circles (teams) |
| 18 | Collect, energy, and order events |
| 20 | Pilgrim's Road board-game event |
| 25 | Keepsake album trading |
| 40 | Generator boost (4x, +2 tiers) |

## 19. Generators: full rules
### 19.1 Generator types
| Type | How it works | Examples |
|---|---|---|
| **Standard** | Costs 1 Manna per tap. Never runs out. | Grandma's Pantry, Armor Rack |
| **Charged** | Gives a set number of items (charges), then rests on a cooldown and recharges. No Manna cost. | Fig tree (6 charges, 2-hour cooldown), Silas's fish basket |
| **Free** | No Manna, auto-produces one item every so often if there's a free cell nearby. | Olive tree in the courtyard |
| **Temporary** | Spawned from a top-tier item or reward. Gives a fixed number of taps, then disappears. | Fishing boat (gives 10 fish, then sails away) |

### 19.2 Generator boost
- Toggle on the board (unlocked at level 15): **2x** spends 2 Manna per tap and gives items 1 tier higher.
- Level 40: **4x** spends 4 Manna per tap and gives items 2 tiers higher.

### 19.3 Rare side chains
Some generators occasionally drop a rare chain (about 10%), worth more in orders and events.
| Generator | Rare chain |
|---|---|
| Grandma's Pantry | Honeycomb → honey jar → honey pot → honeyed feast platter |
| Loom | Purple dye shell → dye pot → purple cloth → royal purple robe (Lydia's trade) |
| Olive Press | Golden olive → golden oil → golden lamp |

### 19.4 Time-skip items
- **Hourglass** (small, medium, large): cuts a cooldown by 15 min, 1 hour, or finishes it.
- Earned from rewards, events, and jars; bought with Pearls.

### 19.5 Energy items
- **Manna jars** on the board can be stored and used later; merging two makes a bigger one.
- **Manna potion** (from events and offers): +100 Manna, can go over the cap.

## 20. Board extras
### 20.1 Bubbles
- After some merges (about 5%), a **bubble** appears holding a copy of the item just made, or occasionally a higher one.
- Pop it with Pearls (cost scales with tier) or watch an ad (low tiers only) to keep the item. If ignored, it pops after 60 seconds and turns into a few Talents.

### 20.2 Locked cells and rubble
- Rubble (as before) plus **sealed jars** on the board that open when an item of a named chain is merged next to them, releasing a reward.

### 20.3 Scissors and wildcards
- **Splitting knife:** splits one item into two of the tier below.
- **Golden Thread (wildcard):** merges with any item to raise it one tier.
- Earned from events, wheel, and jars; bought with Pearls.

### 20.4 Chance-based rewards (casino-style)
All odds are published in a tappable "See odds" panel on every one of these, as Apple and Google require. Paid random items are switched off in countries that ban them (currently Belgium; the list lives in `economy.json`).
| Feature | How it works |
|---|---|
| **Blessing Wheel** | One free spin a day, one more per ad, extra spins for Pearls (cost rises per spin each day). Prizes: Manna, Talents, Pearls, hourglasses, generators, a jackpot Golden Jar. |
| **Jars of Clay** | Random contents. Clay jars come free from orders; Treasure and Golden Jars can also be bought with Pearls. |
| **Lucky boost** | Before a generator tap with boost on, a short spin can land on 1x, 2x, 3x, or 5x the item tier upgrade. |
| **Mystery bubbles** | A rare bubble with a hidden item, revealed when popped. |
| **Pilgrim's Road dice** | Board-game event (section 22). |

## 21. Offers and pop-ups
### 21.1 Offer types
| Offer | When it shows | Price range |
|---|---|---|
| **Starter pack** | Once, after Chapter 1 task 10 | $1.99 |
| **First-purchase bonus** | Before a player's first purchase: double Pearls on any pack | — |
| **Session-start offer** | On opening the app, max once a day | $0.99–$19.99 |
| **Out-of-Manna offer** | When Manna hits 0 (alongside the Pearls refill and ad options) | $0.99–$9.99 |
| **Level-up offer** | Every 5 levels | $2.99–$9.99 |
| **Chapter-complete bundle** | After finishing a chapter | $4.99–$19.99 |
| **Event-ending offer** | Last 24 hours of an event, close to a milestone | $1.99–$9.99 |
| **Price-drop offer** | If an offer isn't bought, the next one is cheaper or bigger | — |
| **Flash sale** | 1–2 hour timer, a few times a week | $0.99–$9.99 |
| **Themed bundles** | Seasonal (feast events), with a hero image | $4.99–$49.99 |
| **Treasure Jar full** | When the piggy bank is full | $2.99–$9.99 |
| **Pass upsell** | When a player reaches a premium-only reward on the season pass | $4.99 / $9.99 |
| **Shop** | Always open from the Pearl counter: Pearl packs, bundles, daily deals (one free, two for Pearls) | — |

### 21.2 Rules
- Max **3 pop-ups per session** and **1 at session start**. Never during the tutorial, a story scene, or a merge.
- Offers adapt by player type: non-payers see small offers ($0.99–$2.99); payers see offers near their past spend.
- Every offer has a countdown timer and a clear "No thanks" button.
- All offers, prices, contents, timing, and targeting come from Supabase (`offers` table), so they can be changed without an app update.

### 21.3 Store products for offers
Apple and Google need each price point as a product, so offers use reusable products whose contents are set from Supabase:
`offer_099`, `offer_199`, `offer_299`, `offer_499`, `offer_999`, `offer_1999`, `offer_4999`, `pass_premium`, `pass_premium_plus`, `treasure_jar_small` ($2.99), `treasure_jar_medium` ($4.99), `treasure_jar_large` ($9.99). Display names: "Special Offer", "Season Pass", "Treasure Jar".

## 22. Events (several run at once)
| Event | How it works | Length |
|---|---|---|
| **Main feast event** | Own board, temporary chain, season pass, exclusive decoration (Boat Festival first) | 3–4 weeks |
| **Milestone event** ("Harvest Gathering") | Earn Talents from orders to hit milestones; difficulty goes up and down in waves | 3–5 days |
| **Race** ("Race to the Harbor") | Compete against 4 other players to finish the goal first; top 3 win prizes | 1–2 days |
| **Collect event** | Gather a special item that drops from merges (some available in offers) | 3 days |
| **Energy event** | Rewards for Manna spent | 2 days |
| **Order event** | Orders give an extra event item | 3 days |
| **Daily tasks** | 5 small goals a day + a chest for finishing all; weekly chest for 5 days completed | Daily |
| **Pilgrim's Road** (board game) | Roll dice (earned from orders, bought in offers) to move around a board of Joppa landmarks. Tiles: rewards, mini-games, "visit a friend" (take a little from a friend's jar), jump ahead. Event shop unlocks in stages; final prize is an exclusive avatar frame and decoration. | 2 weeks |
| **Prayer Circle challenge** | Team goal: everyone's orders add up; team chest at each milestone | 1 week |
| **Global feast goal** | All players together reach a goal; everyone gets the reward | 1 week |

All event types and schedules are configured in Supabase. The admin panel schedules them.

## 23. Social
- **Profile:** name, avatar (unlockable portraits and frames), level, crowns, favorite verse.
- **Friends:** add by friend code, Facebook, or contacts. See friends' levels and towns.
- **Gifting:** send 1 free Manna gift to each friend daily; request items for orders.
- **Prayer Circles (teams):** up to 30 players. Team chat with **preset messages and stickers only** (no free typing, so no moderation burden), team chests, help requests, weekly team challenge.
- **Church Circles:** a church can create an official circle with a code; churches compete on a weekly leaderboard. Built for the marketing plan: whole congregations play together.
- **Report and block** on every player profile (required by Apple and Google for any social feature).

## 24. Story and decorating
- **Decoration choices:** every restored area has **3 designs** to choose from (cedar / stone / painted, for example); players can switch anytime for free. Art: 3 "after" versions per area.
- **Order quests:** long-term goals (e.g. "Furnish Simon's guest room") needing a set of high-tier items, with their own rewards and decoration.
- **Orders on a timer:** a new order appears every few minutes up to the 3-card limit, so harder orders wait for the next session.
- **Story skip:** players can skip any scene; every scene can be replayed from the keepsake book.

## 25. Features better than Gossip Harbor
| Feature | Why it's better |
|---|---|
| **Story choices** | At key moments, the player picks how Naomi responds (gentle, honest, or bold). Choices change a few lines and a relationship score, never the main plot. Gossip Harbor's story is fixed. |
| **Relationship hearts** | Each character has a friendship meter that grows from orders and choices; full hearts unlock a bonus scene and a portrait outfit. |
| **Verse of the Day + daily login calendar** | A 28-day calendar with a reward each day and a short verse; day 7, 14, 21, 28 give big rewards. Builds the daily habit in a way that fits the audience. |
| **Keepsake album** | Collectible card sets (people, places, Bible-era objects) from jars, events, and the wheel. Finish a set for a big prize; trade duplicates with friends. |
| **Church Circles** | Whole congregations as teams (section 23). A marketing channel no competitor has. |
| **Bible study mode** | Each chapter unlocks a short discussion guide (the rumor, the verse, 3 questions) to share with a small group. |
| **Share to Facebook** | Share a before/after restoration or a letter as a picture; each share gives a small reward. |
| **Free Manna links** | Post links on Facebook and Instagram every couple of days that give 25 Manna. Cheap marketing aimed at where the audience already is. |
| **Pet companion** | Joy's cat, Shadow, follows the player around the board; feed it items for small gifts and new looks. |
| **Offline play** | The whole main game works offline; events and social sync when back online. |

All values in sections 18–25 are starting points, stored in content/Supabase, and tuned in playtesting.

---

## Part 3 — New milestones (CLAUDE.md)
Insert these **before "Release builds"**, which becomes the last milestone (40).

| # | Milestone | Done when |
|---|---|---|
| 25 | Player levels & XP | XP from tasks, levels 1–60, level-up refill and rewards, feature unlocks per section 18 |
| 26 | Generator types | Charged, free, and temporary generators with cooldowns; hourglass time-skips; Manna items (section 19) |
| 27 | Boost & rare chains | 2x/4x generator boost, rare side-chain drops (19.2–19.3) |
| 28 | Board extras | Bubbles, sealed jars, splitting knife, Golden Thread (20.1–20.3) |
| 29 | Chance features | Blessing Wheel, random Jars of Clay, lucky boost, mystery bubbles; "See odds" panel on each; country switch for paid random items (20.4) |
| 30 | Offers & pop-ups | Every offer type and rule in section 21, driven by the Supabase `offers` table; reusable offer products; frequency caps |
| 31 | Treasure Jar & pass tiers | Piggy bank; Premium and Premium Plus pass with endless track |
| 32 | Event suite | Milestone, race, collect, energy, order, daily tasks, global goal (section 22), scheduled from the admin panel |
| 33 | Pilgrim's Road | Dice board-game event with tiles, mini-games, staged event shop |
| 34 | Social: profiles & friends | Profiles, avatars, friend codes, Facebook friends, daily gifting, item requests, report and block |
| 35 | Prayer & Church Circles | Teams up to 30, preset-message chat, team chests and challenges, church codes and leaderboard |
| 36 | Decoration choices & order quests | 3 designs per area, switchable; order quests; timed orders; story skip and replay (section 24) |
| 37 | Story choices & hearts | Dialogue choices, relationship meters, bonus scenes and outfits (section 25) |
| 38 | Daily calendar, album, pet | 28-day login calendar with verse of the day, keepsake card album with trading, Shadow the cat |
| 39 | Sharing & Manna links | Share images to Facebook, deep-linked free Manna links with one claim per player, Bible study guides |
| 40 | Release builds | Signed iOS and Android builds for TestFlight and Play internal testing |

---

## Part 4 — Tech additions (TECH_SPEC.md)

**New content files:** `levels.json`, `generator_types.json`, `wheel.json` (prizes + odds), `jars.json` (loot tables + odds), `album.json`, `calendar.json`, `choices.json`, `pet.json`, `blocked_countries.json` (countries where paid random items are off).

**New Supabase tables** (row-level security on all):
| Table | Purpose |
|---|---|
| `offers` | Offer definitions: type, product ID, contents, price tier, timer, targeting rules, start/end |
| `offer_impressions` | Which offers each player saw and bought (frequency caps, price drops) |
| `friends` | Friend links between players |
| `gifts` | Daily gifts and item requests |
| `circles`, `circle_members` | Prayer and Church Circles; `circles.church_code` for churches |
| `circle_messages` | Preset message IDs only, never free text |
| `reports`, `blocks` | Report and block records |
| `race_groups` | 5-player race groups and scores |
| `leaderboards` | Church Circle weekly scores |
| `global_goals` | Global feast goal progress |
| `album_trades` | Card trades between friends |
| `manna_links` | Free Manna link codes, expiry, and claims (one claim per player) |

**Rules:**
- All chance outcomes are rolled on the server (Edge Function `roll`), so they can't be faked and the odds match what's published.
- Social and race data sync when online; the main game stays playable offline.

---

## Part 5 — New store products (SETUP_CHECKLIST.md)
Create these in **App Store Connect and Google Play**, same IDs on both:

| Product ID | Type | Price | Display name |
|---|---|---|---|
| `offer_099` | Consumable | $0.99 | Special Offer |
| `offer_199` | Consumable | $1.99 | Special Offer |
| `offer_299` | Consumable | $2.99 | Special Offer |
| `offer_499` | Consumable | $4.99 | Special Offer |
| `offer_999` | Consumable | $9.99 | Special Offer |
| `offer_1999` | Consumable | $19.99 | Special Offer |
| `offer_4999` | Consumable | $49.99 | Special Offer |
| `pass_premium` | Consumable | $4.99 | Season Pass |
| `pass_premium_plus` | Consumable | $9.99 | Season Pass Plus |
| `treasure_jar_small` | Consumable | $2.99 | Treasure Jar |
| `treasure_jar_medium` | Consumable | $4.99 | Treasure Jar |
| `treasure_jar_large` | Consumable | $9.99 | Treasure Jar |

What each offer contains is set in the Supabase `offers` table, so offers can change without new store products.
