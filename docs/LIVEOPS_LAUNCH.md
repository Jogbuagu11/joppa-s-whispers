# Whispers of Joppa — Live Ops & Launch Plan

## 1. Content rhythm after launch
| What | How often |
|---|---|
| Main event (own board + temporary chain + season pass) | Every ~4 weeks, lasting ~3 weeks |
| Weekend event (double rewards, bonus orders, mini-goals) | Most weekends between main events |
| New story chapter | Every 4–6 weeks |
| Balance and bug-fix updates | As needed, mostly through content pushes, not app updates |

Rule: the next chapter and the next main event are always finished before the current ones go live.

## 2. Event structure (every main event)
- **Separate event board** (smaller, 5×7) so it doesn't crowd the main board.
- **One temporary chain** with its own generator, 7–8 tiers.
- **Milestone track:** 20–30 reward steps (Manna, Talents, Pearls, generators, decorations).
- **Season pass:** free track + paid track ($4.99) using the same milestones.
- **Exclusive decoration** at the end: a permanent item for the player's town.
- **Short story side-plot:** 3–5 scenes with existing characters.
- Everything is defined in Supabase `events.config`; no app update needed.

## 3. Proposed event themes (approve each before building)
These follow the biblical feast calendar, which fits the setting. Their dates move with the Hebrew calendar each year, so the schedule is set each season.

| Event | Story side-plot | Temporary chain idea |
|---|---|---|
| **Feast of Purim** | Silas tells the story of Queen Esther; Naomi realizes why her grandmother was named Esther | Royal court items ending in Queen Esther's scepter |
| **Passover** | The town prepares together; Marcus's first Passover back with family | Preparation items ending in a Passover table |
| **Pentecost (Shavuot)** | Firstfruits brought to the community; Hannah's sons bring their first harvest | Grain and harvest items ending in a firstfruits offering |
| **Feast of Tabernacles** | Families build booths on the rooftops; Joy builds one with Caleb and Naomi | Booth-building items ending in a finished booth |
| **Winter (Hanukkah/Christmas season)** | Lamps in every window of Joppa | Lamp and light items ending in a lit harbor |
| **Joppa Boat Festival** (original) | Caleb launches the *Leah* | Boatbuilding items ending in a decorated boat |

## 4. Launch phases
| Phase | What happens | Goal |
|---|---|---|
| **1. Internal** | Jennifer and family/friends play on TestFlight and Google Play internal testing | No crashes; first session makes sense |
| **2. Closed beta** | 50–200 testers from church and faith communities | Find confusing spots, pacing problems, theology concerns |
| **3. Soft launch** | Release in 1–2 small English-speaking markets (for example Philippines, New Zealand) | Measure retention and spending before spending on marketing |
| **4. Global launch** | US, Canada, UK, Australia, Nigeria, Ghana, Kenya, South Africa, and other English-speaking markets | Scale players |

**Metrics to watch in soft launch:** day-1, day-7, and day-30 retention; tutorial completion; where players quit; average session length; percentage of players who purchase; revenue per player; crash rate. Decide go/no-go for global launch from real numbers, not guesses.

## 5. Store listing
- **Name:** Whispers of Joppa (subtitle: "A Merge Story of Grace" — trademark-check first)
- **Short description:** Restore a biblical harbor town, uncover the truth behind its rumors, and discover your grandmother's hidden letters.
- **Screenshots (6–8):** board with merges, Naomi + Esther's letter, a story scene, before/after restoration, a character portrait lineup, an event board.
- **Preview video:** 15–30 seconds, recorded from the game's auto-play demo mode.
- **Keywords:** Christian games, Bible games, merge games, story games, faith, church, family-friendly.
- **Age rating:** no longer 4+/Everyone since the chance features (Milestone 29): declare simulated gambling (infrequent/mild) and random paid items (yes), expect about 12+; complete both store questionnaires honestly (mentions of death and grief must be declared).

## 6. Marketing to the faith audience
- **Church networks:** women's ministries, Bible study groups, church newsletters. A one-page "share with your group" flyer.
- **Christian media:** outlets and programs you already have relationships with; pitch the gossip-and-grace angle as a story, not just a game.
- **Faith influencers:** Christian moms, Bible teachers, and Christian gaming creators on Facebook, Instagram, TikTok, and YouTube.
- **Your podcast and existing apps:** cross-promote to existing audiences.
- **Facebook group:** the core audience lives on Facebook. Run a player community there for story discussion and event announcements.
- **Paid ads:** start small during soft launch to measure cost per install; scale only if retention and revenue support it.
- **Small-group angle:** each chapter's theme (gossip, judgment, forgiveness) can become a free downloadable discussion guide for Bible studies.

## 7. Player support
- Support email + in-game "Help" button that attaches player ID and app version.
- FAQ: lost progress, purchases not received, how energy works.
- Restore-purchases and account recovery flows documented.

## 8. What Jennifer owns after launch
- Approving each event theme, chapter, and story text.
- Generating art for new chapters and events (see the art doc).
- Reviewing metrics weekly and deciding balance changes.
- Theological review of new story content.
