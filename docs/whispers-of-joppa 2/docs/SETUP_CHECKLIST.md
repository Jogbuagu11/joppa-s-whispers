# Whispers of Joppa — Setup Checklist (End to End)

Do the phases in order; later ones depend on earlier ones.
**You** = Jennifer does it in a website or console. **Claude Code** = tell Claude Code to do it.
Check each box as you go. Claude Code reads this file to know what's ready.

Prices and policies below were correct at writing. Confirm on each site when you sign up.

---

## Phase 0 — Decide these first (You)
- [ ] **Business entity** that will own the app (an existing LLC or a new one). Store accounts, payouts, and taxes go to this entity.
- [ ] **D-U-N-S number** for that entity (free from Dun & Bradstreet). Apple and Google both require it for organization accounts. It can take a week or more, so request it first.
- [ ] **Bundle ID / package name** (same on iOS and Android, can never change): `com.<yourcompany>.whispersofjoppa`
- [ ] **Support email** (e.g., `support@<yourdomain>`)
- [ ] **Domain + simple website** with pages for: privacy policy, terms of service, support, account deletion instructions, and `app-ads.txt` (Phase 9)
- [ ] **Bank account and tax info** for the entity (needed for Apple and Google payouts)
- [ ] **Trademark search** on "Whispers of Joppa"

## Phase 1 — Your Mac (You + Claude Code)
- [ ] Install **Xcode** from the Mac App Store, open it once, accept the license, install the iOS Simulator
- [ ] Install **Android Studio**, then create an emulator (a recent Pixel) in Device Manager
- [ ] **Claude Code:** install Flutter (stable), CocoaPods, and run `flutter doctor` until everything is green
- [ ] Install **Claude Code** and sign in
- [ ] Create a **private GitHub repository** for the project (off-computer backup of every working version)
- [ ] **Claude Code:** connect the project folder to the GitHub repo and push after every working milestone
- [ ] Have **one real iPhone and one cheap Android phone** for testing

## Phase 2 — Apple Developer + App Store Connect (You)
**Cost:** $99/year.
- [ ] Enroll in the **Apple Developer Program as an organization** at developer.apple.com (needs the D-U-N-S number)
- [ ] In App Store Connect → Business: sign the **Paid Applications Agreement**, add **banking** and **tax** forms. In-app purchases won't work until this is active.
- [ ] Enroll in the **App Store Small Business Program** (lower commission if you qualify)
- [ ] In Certificates, Identifiers & Profiles → Identifiers: create an **App ID** with your bundle ID. Turn on these capabilities:
  - [ ] Push Notifications
  - [ ] Sign in with Apple
  - [ ] In-App Purchase
- [ ] Keys → create an **APNs Auth Key (.p8)**. Download it (you can only download once). Write down the **Key ID** and your **Team ID**. Store the file safely.
- [ ] In App Store Connect → Apps → **create the app record** (name, bundle ID, SKU, primary language English)
- [ ] Users and Access → Integrations → **In-App Purchase key**: generate and download it (Supabase uses it to verify purchases with Apple). Note its Key ID and Issuer ID.
- [ ] Users and Access → **Sandbox testers**: create 2 test accounts with new email addresses (for testing purchases)
- [ ] Create **in-app purchase products** with these exact IDs (from TECH_SPEC section 6):
  - [ ] `pearls_tier1` … `pearls_tier6` (Consumable)
  - [ ] `starter_pack` (Non-Consumable)
  - [ ] Season pass products are created per event later
- [ ] App Information → **App Store Server Notifications**: set Version 2 URLs (production and sandbox) to the Supabase `store-notifications-apple` function URL (Claude Code gives you the URL in Phase 7)
- [ ] **TestFlight**: add yourself and internal testers

## Phase 3 — Xcode project settings (Claude Code, You verify)
- [ ] **Claude Code:** set the bundle ID, display name, and version/build numbers
- [ ] **Claude Code:** set **Targeted Device Family = iPhone only**. Otherwise Apple requires iPad screenshots and iPad testing.
- [ ] **Claude Code:** portrait only
- [ ] **You:** in Xcode → Runner → Signing & Capabilities, select your **Team** and turn on **Automatically manage signing** (needs your Apple sign-in)
- [ ] **Claude Code:** add capabilities: Push Notifications, Background Modes → Remote notifications, Sign in with Apple, In-App Purchase
- [ ] **Claude Code:** Info.plist entries:
  - [ ] `ITSAppUsesNonExemptEncryption` = NO (standard HTTPS only; skips the export-compliance question each upload)
  - [ ] `GADApplicationIdentifier` (from Phase 8)
  - [ ] `NSUserTrackingUsageDescription` with a plain explanation (needed for the App Tracking Transparency prompt with ads)
  - [ ] `SKAdNetworkItems` list (from AdMob's docs)
- [ ] **Claude Code:** app icon set from your 1024×1024 icon
- [ ] **You:** run on your real iPhone from Xcode once to confirm signing works

## Phase 4 — Google Play Console (You)
**Cost:** $25 one-time.
- [ ] Create a **Google Play developer account as an organization** (needs the D-U-N-S number; complete identity verification). A personal account has an extra rule: a closed test with at least 12 testers for 14 straight days before you can publish. An organization account avoids that.
- [ ] Set up the **payments profile** (merchant account) with bank and tax info
- [ ] **Create the app** (name, default language, game, free)
- [ ] Turn on **Play App Signing**
- [ ] **Claude Code:** create the **upload keystore**, configure `android/key.properties` (kept out of git), and build the first release `.aab`
- [ ] **You:** back up the upload keystore file and its passwords somewhere safe (password manager + offline copy). Losing it is a major problem.
- [ ] Upload the first `.aab` to **Internal testing** (needed before you can create in-app products)
- [ ] Monetize → Products → create **in-app products** with the same IDs as Apple: `pearls_tier1` … `pearls_tier6`, `starter_pack`
- [ ] Add **license testers** (your Gmail addresses) so purchases are free during testing
- [ ] Copy both **SHA-1 fingerprints** (Setup → App signing: the app signing key AND the upload key). Needed for Google Sign-In (Phase 5).
- [ ] Policy forms (do before first release to testers outside internal):
  - [ ] **Data safety** form (accounts, analytics, crash data, ads, purchases)
  - [ ] **Account deletion URL** (your website page)
  - [ ] **Content rating** questionnaire
  - [ ] **Target audience** (adults; not designed for children under 13)
  - [ ] **Ads** declaration: yes, contains ads
  - [ ] **Privacy policy URL**

## Phase 5 — Google Cloud: Google Sign-In (You)
- [ ] Open the Google Cloud project that Firebase creates (Phase 6), or create one
- [ ] OAuth consent screen: app name, support email, privacy policy URL, your logo
- [ ] Create **OAuth client IDs**:
  - [ ] **Web** client (Supabase uses this one)
  - [ ] **iOS** client (your bundle ID)
  - [ ] **Android** client, once for each SHA-1 from Phase 4
- [ ] Give the Web and iOS client IDs to Claude Code (save them in `.env`, never in chat history you share)

## Phase 6 — Firebase (You + Claude Code)
**Cost:** free plan covers push, Crashlytics, and Analytics.
- [ ] Create a **Firebase project** "Whispers of Joppa" (Google Analytics: on)
- [ ] Add an **iOS app** (your bundle ID) and an **Android app** (same package name)
- [ ] **Claude Code:** run `flutterfire configure` (you'll sign in to Firebase in the browser when asked). This generates the config files.
- [ ] Project Settings → Cloud Messaging → **upload the APNs Auth Key** (.p8, Key ID, Team ID from Phase 2). Without this, iPhone push doesn't work.
- [ ] Turn on **Crashlytics**
- [ ] Project Settings → Service accounts → **generate a private key** (JSON). This lets Supabase send push notifications. Give it to Claude Code to store **only** as a Supabase Edge Function secret.

## Phase 7 — Supabase (You + Claude Code)
**Cost:** free to start. Upgrade to the **Pro plan** before beta: free projects pause after a week without activity, and Pro adds daily backups.
- [ ] Create the **Supabase project** (region: US West)
- [ ] Copy the **Project URL** and **anon key** → Claude Code puts them in `.env`
- [ ] Copy the **service-role key** → store only in Supabase Edge Function secrets, **never** in the app
- [ ] **Claude Code:** create tables from TECH_SPEC section 5 (`profiles`, `saves`, `content_versions`, `events`, `purchases`, `wallet_grants`, `device_tokens`, `notifications_log`) with **row-level security on every table**
- [ ] **Claude Code:** create the Storage bucket for content bundles and art
- [ ] Authentication → Providers:
  - [ ] **Apple**: add your bundle ID as an authorized client ID
  - [ ] **Google**: add the Web client ID (and the iOS client ID in authorized client IDs)
  - [ ] **Email**: on, with email confirmation
- [ ] Authentication → URL configuration: add the app's redirect/deep-link URL (Claude Code tells you the value)
- [ ] **Claude Code:** Edge Functions:
  - [ ] `send-push`: sends notifications through FCM HTTP v1 using the Firebase service account secret
  - [ ] `verify-purchase`: verifies every purchase with Apple/Google and grants items
  - [ ] `store-notifications-apple`: handles Apple refund notifications
  - [ ] `store-notifications-google`: handles Google refund notifications
  - [ ] `delete-account`: deletes the user's profile, save, and tokens
- [ ] **Claude Code:** scheduled job for event start/ending pushes
- [ ] Turn on **daily backups** (Pro plan)

## Phase 8 — Purchase verification setup (You + Claude Code)
**Cost:** free (uses Google Cloud's free tier for Pub/Sub at this scale).
- [ ] **Apple:** give Claude Code the In-App Purchase key (.p8), Key ID, Issuer ID, and bundle ID → stored **only** as Supabase Edge Function secrets
- [ ] **Google:** in Google Cloud (same project as Firebase), create a **service account** for purchase checks and download its JSON key
- [ ] In Google Cloud, **enable the Google Play Android Developer API**
- [ ] In Play Console → Users and permissions → **invite the service account email** with permission to view financial data and manage orders
- [ ] Give the service account JSON to Claude Code → stored **only** as a Supabase Edge Function secret
- [ ] In Google Cloud → **Pub/Sub**: create a topic `play-billing`; grant `google-play-developer-notifications@system.gserviceaccount.com` permission to publish to it
- [ ] Create a **push subscription** on that topic pointing to the Supabase `store-notifications-google` function URL
- [ ] Play Console → Monetize → Monetization setup → **Real-time developer notifications**: enter the topic name and send a test notification
- [ ] **Claude Code:** confirm the test notification arrived in Supabase logs

## Phase 9 — AdMob (You + Claude Code)
- [ ] Create an **AdMob account**, linked to the same Google account as Play Console
- [ ] Add **two apps** (iOS and Android). Link them to the store listings after they're published.
- [ ] Create **rewarded ad units** (one per platform): `manna_bonus`, `double_reward`, `daily_jar`
- [ ] Copy the **App IDs** and **ad unit IDs** → Claude Code puts them in config
- [ ] Privacy & messaging: set up the **GDPR consent message** (required for players in Europe and the UK) and the **IDFA explainer message** for iOS
- [ ] Publish **`app-ads.txt`** on your website root (AdMob gives you the line) and list the same website in both store listings
- [ ] **Claude Code:** use Google's **test ad IDs** in all development builds. Never tap your own real ads; it can get the account suspended.

## Phase 10 — Notifications (Claude Code, You test)
- [ ] **Claude Code:** add `firebase_messaging` + `flutter_local_notifications`
- [ ] **Claude Code:** Android notification channels: Reminders, Events, Story
- [ ] **Claude Code:** in-game explainer + permission request after Chapter 1 task 5 (iOS and Android 13+)
- [ ] **Claude Code:** save each device's FCM token to `device_tokens`; refresh on change; remove on sign-out
- [ ] **Claude Code:** subscribe to FCM topics `events` and `chapters` based on the player's toggles
- [ ] **Claude Code:** local reminders: Manna full, daily jar, one come-back reminder after 3 days
- [ ] **Claude Code:** rules: max 1 push/day, none 9 pm–9 am local time, each type toggleable in Settings
- [ ] **Claude Code:** tapping a notification opens the right screen
- [ ] **Claude Code:** admin panel button to send a push to a topic (with a preview and a confirm step)
- [ ] **You:** test on your real iPhone and Android (simulators don't fully test push):
  - [ ] Permission prompt appears at the right time
  - [ ] Push arrives with the app closed, in the background, and open
  - [ ] Tapping opens the correct screen
  - [ ] Turning a toggle off stops that type

## Phase 11 — Analytics and crash reporting (Claude Code, You verify)
- [ ] **Claude Code:** Firebase Analytics events from TECH_SPEC section 8
- [ ] **Claude Code:** Crashlytics catching all errors; upload iOS dSYM files in release builds
- [ ] **You:** trigger the test crash button (debug builds only) and confirm it shows in the Firebase console

## Phase 12 — Website and legal (You, Claude Code drafts)
- [ ] **Claude Code:** draft the privacy policy and terms (accounts, cloud saves, purchases, ads, analytics, crash data, notifications, account deletion)
- [ ] **You:** have a lawyer review them
- [ ] Publish on your website: privacy policy, terms, support page, account deletion page, `app-ads.txt`
- [ ] **Claude Code:** in-app links to privacy policy, terms, and support in Settings; **Delete account** button in Settings

## Phase 13 — Testing before submission (You)
- [ ] Full first session on a real iPhone and a cheap Android, from fresh install
- [ ] Sign in with Apple, Google, and email; sign out; sign back in; progress restored
- [ ] Buy each product with a **sandbox tester** (iOS) and **license tester** (Android); **Restore purchases** works
- [ ] Rewarded ads show test ads and pay rewards; buttons hide when no ad is available
- [ ] Notifications tested (Phase 10)
- [ ] Delete account works and the account is gone
- [ ] Airplane mode: game still plays; saves sync when back online
- [ ] Theological reviewer has signed off on all shipped story text

## Phase 14 — Store listings and submission (You, Claude Code helps)
**Apple (App Store Connect):**
- [ ] Screenshots for the **6.9-inch iPhone** size (required)
- [ ] App name, subtitle, description, keywords, support URL, privacy policy URL
- [ ] **App Privacy** labels (match the Data safety answers)
- [ ] **Age rating** questionnaire
- [ ] In-app purchases attached to the first version and submitted with it
- [ ] **Review notes:** explain how to reach the shop and that purchases are testable in sandbox
- [ ] **Claude Code:** build, archive, and upload; **You:** select the build and submit

**Google (Play Console):**
- [ ] Phone screenshots, feature graphic (1024×500), icon, short and full description
- [ ] All policy forms from Phase 4 complete
- [ ] Release: internal → closed testing (beta) → production, with a staged rollout (start at 10–20%)

## Phase 15 — Launch day (You)
- [ ] Crashlytics open and watched for the first 48 hours
- [ ] Supabase `purchases` table showing real verified purchases; Apple and Google sales reports matching
- [ ] AdMob apps linked to the live store listings
- [ ] First event and Chapter 2 already finished and loaded in Supabase
- [ ] Support email monitored daily
- [ ] "Event started" push scheduled for the first event

---

## Keys and files inventory
Fill in where each one is stored (password manager recommended). Never paste these into chats you share or into git.

| Item | From | Used by | Where it must live | Stored? |
|---|---|---|---|---|
| Apple Team ID | Apple Developer | Firebase, Xcode | Notes | [ ] |
| APNs Auth Key (.p8) + Key ID | Apple Developer → Keys | Firebase | Password manager | [ ] |
| In-App Purchase key (.p8) + IDs | App Store Connect | Purchase verification | Password manager + Supabase secret | [ ] |
| Android upload keystore + passwords | Claude Code creates | Play uploads | Password manager + offline backup | [ ] |
| SHA-1 fingerprints (2) | Play Console | Google OAuth | Notes | [ ] |
| Google OAuth Web + iOS client IDs | Google Cloud | Supabase, app | `.env` + Supabase | [ ] |
| Firebase config files | `flutterfire configure` | App | Project (generated) | [ ] |
| Firebase service account JSON | Firebase | Push sending | Supabase Edge Function secret only | [ ] |
| Supabase URL + anon key | Supabase | App | `.env` | [ ] |
| Supabase service-role key | Supabase | Edge Functions | Supabase secret only | [ ] |
| Google Play service account JSON | Google Cloud | Purchase verification | Supabase secret only | [ ] |
| AdMob App IDs + ad unit IDs | AdMob | App | Config | [ ] |

## Running costs
| Service | Cost |
|---|---|
| Apple Developer Program | $99/year |
| Google Play | $25 one-time |
| Supabase | Free to start; Pro plan monthly before beta |
| Firebase (push, Crashlytics, Analytics) | Free |
| AdMob | Free (pays you) |
| Domain + website hosting | Small yearly/monthly cost |
| Store commission | Apple and Google take a cut of purchases (15% under the small-business programs) |
