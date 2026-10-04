# Whispers of Joppa — Game Design Document

## 1. Overview
| | |
|---|---|
| **Genre** | Merge-2 story game (merge items → fill orders → restore a town → unlock story) |
| **Platforms** | iOS and Android, portrait only |
| **Setting** | Joppa, a harbor town on the Mediterranean, around AD 40 (Acts 9–11) |
| **Audience** | Christian women 35+ first; families and faith-based players broadly |
| **Business model** | Free-to-play; in-app purchases, season pass, optional rewarded ads |
| **Core theme** | Gossip destroys; truth restores. Every rumor is resolved with truth, repentance, and reconciliation — never revenge. Anchor verse: Proverbs 16:28. |

## 2. Tone rules (apply to everything)
- Warm drama with cliffhangers. Feels like a faith-based TV drama, never a sermon.
- No profanity. Romance is slow-burn and chaste.
- Scripture is earned and personal (mostly through Esther's letters), not lectured.
- Scripture quotes use the **World English Bible (WEB)** or **KJV** only (public domain).
- Real biblical figures (Peter, Tabitha, Cornelius, Simon the tanner) stay consistent with Acts 9–11.
- Communion elements, crucifixes, and depictions of Jesus are never merge items. They may appear only as story moments or decoration.
- Symbolic items (Armor of God, Fruit of the Spirit) are drawn as glowing, stylized objects, so players read them as spiritual, not literal.

## 3. Core loop
1. Tap a **generator** (costs 1 Manna) → it spawns a tier-1 item on the board.
2. **Merge** two identical items → one item of the next tier.
3. Fill **orders** from characters → earn **Talents** (coins) and **Blessings** (story currency).
4. Spend Blessings on **story tasks** → restore a location and advance the chapter.
5. Finish a chapter → new location, new chain, new characters, a **Crown**, and one of Esther's letters.

## 4. The board — Esther's Rooftop
- Grid: **7 columns × 9 rows** (63 cells). Some cells start covered by **rubble** (broken pottery, fallen palm fronds) and clear when an item is merged next to them.
- **Esther's Basket:** storage for items off the board. Starts with 4 slots; more slots cost Pearls.
- **Selling:** any item can be sold for Talents (small amount, scaled by tier).
- **Item info:** tapping an item shows its chain and the next tier (silhouetted if not yet discovered).
- **Discovery book:** first time a player makes a new item, it's recorded (with a small Talent reward).

## 5. Generators
Each chain has one generator. Generators also merge: two generators of the same level make the next level (max level 5).

| Level | Effect |
|---|---|
| 1 | Spawns tier 1 |
| 2 | 10% chance of tier 2 |
| 3 | 20% chance of tier 2 |
| 4 | 25% chance of tier 2, 5% chance of tier 3 |
| 5 | 30% chance of tier 2, 10% chance of tier 3 |

Extra generators come from chapter rewards, Jars of Clay, and events. All numbers are starting values to tune in playtesting.

## 6. Item chains (launch set)

### 6.1 Literal chains (town restoration orders)
| Chain | Generator | Tiers |
|---|---|---|
| **Bakery** | Grandma's Pantry | 1 Barley sheaf → 2 Flour → 3 Dough → 4 Flatbread → 5 Loaf → 6 Fig cake → 7 Honey cake → 8 **Wedding feast cake** |
| **Tabitha's Loom** | Loom | 1 Wool → 2 Thread → 3 Spindle → 4 Cloth → 5 Tunic → 6 Cloak → 7 Robe → 8 **Tabitha's garments** |
| **House Church** | Elder's Chest | 1 Clay lamp → 2 Oil lamp → 3 Bench → 4 Bread basket → 5 Table for breaking bread → 6 **The upper room** |

### 6.2 Spiritual chains (character "needs" orders)
| Chain | Generator | Tiers |
|---|---|---|
| **Armor of God** (Eph. 6:14–17) | Armor Rack | 1 Belt of Truth → 2 Shoes of Peace → 3 Breastplate of Righteousness → 4 Shield of Faith → 5 Helmet of Salvation → 6 Sword of the Spirit → 7 **Full Armor of God** |
| **Fruit of the Spirit** (Gal. 5:22–23) | Tree of Life | 1 Love → 2 Joy → 3 Peace → 4 Patience → 5 Kindness → 6 Goodness → 7 Faithfulness → 8 Gentleness → 9 Self-Control → 10 **Basket of the Spirit** |
| **The Word** | Scribe's Desk | 1 Reed pen → 2 Ink pot → 3 Papyrus → 4 Scroll → 5 Sealed scroll → 6 Scroll jar → 7 Apostle's letter → 8 **Isaiah scroll** |
| **Anointing Oil** | Olive Press | 1 Olive → 2 Olive branch → 3 Oil flask → 4 Anointing vial → 5 Alabaster jar → 6 **Horn of oil** (1 Sam. 16:13) |

Notes:
- Fruit of the Spirit is drawn as glowing gem-fruit, one distinct shape and color per fruit.
- Every top-tier item is also a **decoration**: it can be placed in a restored location for a permanent visual.

### 6.3 Unlock schedule
| Chapter | Unlocks |
|---|---|
| 1 Homecoming | Bakery, Fruit of the Spirit |
| 2 The Collection | House Church |
| 3 The Tax Collector | Armor of God |
| 4 Tabitha | Tabitha's Loom |
| 5 Caleb's Boat | Anointing Oil |
| 6 The Gentile's Table | The Word |

## 7. Currencies and reward items
| Name | Role | Tiers / details |
|---|---|---|
| **Manna** | Energy. Bar max 100, +1 every 2 minutes. Each generator tap costs 1. | Board item: Manna flake (5) → Handful (15) → Basket (40) → Golden jar of manna (100). Tap to collect. |
| **Talents** | Soft currency (coins) | Widow's mite → Silver coin → Talent → Bag of talents. Tap to collect. |
| **Pearls of Great Price** | Premium currency (Matt. 13:45) | Bought with real money; small amounts earned in play |
| **Blessings** ✦ | Story currency. Earned from orders, spent on story tasks. | Not purchasable |
| **Jars of Clay** | Reward containers (2 Cor. 4:7) | Clay jar → Treasure jar → Golden chest. Contents are shown before opening (no surprise paid contents). |
| **The Five Crowns** | Chapter-milestone collection, not merged | Imperishable (Ch. 1–2), Rejoicing (Ch. 3), Righteousness (Ch. 4), Glory (Ch. 5), Life (Ch. 6) |

## 8. Orders
- Up to **3 order cards** visible at once, each from a character with their portrait.
- An order asks for 1–3 items. Filling it pays Talents + Blessings (sometimes a Jar of Clay).
- **Literal orders** come from the restoration story (e.g., Silas wants 2 loaves for the fishermen).
- **Spiritual orders** come from characters' struggles (e.g., Zilpah needs Gentleness; Marcus needs the Shield of Faith). Filling a spiritual order triggers a short story moment.
- Order tier difficulty rises through each chapter. Orders never ask for an item from a chain not yet unlocked.
- Orders can be skipped once per 30 minutes (free) to avoid dead ends.

## 9. Story tasks and restoration
- Each chapter has **30–40 story tasks** (see STORY_BIBLE for beats; each beat = 2–4 tasks).
- A task costs Blessings (starting at 1, rising to ~5 late in a chapter) and plays a short scene.
- Each chapter restores one location in **5–8 areas**; each area has a "before" and "after" image.
- Completing all tasks completes the chapter.

| Chapter | Location restored |
|---|---|
| 1 | Esther's bakehouse |
| 2 | The town well |
| 3 | The fishing docks |
| 4 | Simon the tanner's house |
| 5 | The house church |
| 6 | The harbor watchtower |

## 10. Esther's letters
- Written on pottery shards (ostraca). 12 at launch, 2 per chapter: one mid-chapter, one at chapter end.
- Each letter = a memory + a verse (WEB/KJV) + one line of reflection. Full texts in STORY_BIBLE.
- Collected in a **keepsake book** players can reread anytime.

## 11. Tutorial (first 10 minutes)
1. Cold open: Naomi arrives at Joppa's harbor at dusk; whispers from the dock workers (3 lines).
2. Esther's rooftop: Silas shows her the board. Forced merge: two barley sheaves → flour.
3. First generator tap (Grandma's Pantry). Free Manna for the tutorial.
4. First order: Silas wants flatbread. Guided merges to tier 4.
5. First Blessing → first task: sweep the bakehouse doorway (before/after swap).
6. Fruit of the Spirit introduced: Naomi finds Esther's first letter; first spiritual order (Love).
7. Hand-off: the player is free; first chapter-goal shown.
No paywall, no ads, no purchase offers during the tutorial.

## 12. Economy starting values (tune in playtesting)
| Setting | Value |
|---|---|
| Max Manna | 100 |
| Manna regen | 1 per 2 minutes |
| Generator tap | 1 Manna |
| Manna refill (full) | 10 Pearls, cost rises with each refill per day (10 → 20 → 40) |
| Basket slot | 10 Pearls, then +10 each |
| Order reward | Talents = 5 × sum of item tiers; Blessings = 1–3 |
| Item sell value | Tier × 2 Talents |
| Order skip | Free, once per 30 min |

All values live in `content/economy.json`, never in code.

## 13. Monetization
**Principles:** paid items always show exactly what you get; no paid random boxes; no purchases offered in the tutorial; ads always optional.

| Product | Details (starting prices, tune later) |
|---|---|
| **Pearl packs** | $0.99, $4.99, $9.99, $19.99, $49.99, $99.99 |
| **Starter pack** | One-time, $1.99: Pearls + Manna + a level-2 generator. Shown after Chapter 1 task 10. |
| **Manna refills** | Bought with Pearls when out of energy |
| **Season pass** | Per event (~4 weeks). Free track + paid track ($4.99). Paid track: more Manna, Pearls, an exclusive decoration. |
| **Rewarded ads** | Watch for +20 Manna (max 5/day), double one order reward (max 3/day), or open a daily clay jar |
| **Remove ads** | Not needed; ads are never forced |

## 14. Live ops (summary — full plan in LIVEOPS_LAUNCH.md)
- One main event every ~4 weeks with its own temporary board and chain.
- Short weekend events between them.
- Seasonal: Christmas, Easter (Resurrection Sunday), Harvest/Feast of Tabernacles.
- New story chapter every 4–6 weeks after launch.
- All events and chapters are delivered from Supabase without an app update.

## 15. Notifications
Gentle and rare. Local reminders (Manna full, daily jar, one come-back reminder after 3 days away) and push for events and new chapters. Max 1 push per day, none overnight, separate on/off toggles. Permission is requested after Chapter 1 task 5, not on first launch. Details in TECH_SPEC 9b.

## 16. Accessibility
- Every tier in a chain has a distinct silhouette (readable without color).
- Text scales with the phone's text-size setting.
- Haptics and sound can be turned off separately.
- Dialogue auto-advance option.

## 17. Out of scope for launch
Social features (friends, gifting, teams), voice acting, localization, tablet-specific layouts, landscape mode.
