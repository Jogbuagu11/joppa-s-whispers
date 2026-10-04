# Joppa's Whispers

Build a website for Whispers of Joppa, a free Christian 2.5D merge-and-story mobile game for iPhone and Android. Domain: whispersofjoppa.com. Support email: support@whispersofjoppa.com.

DESIGN
- Warm, painterly, story-driven feel matching the game's art: sand, terracotta, olive, indigo, sea blue, cream.
- Elegant serif headings (like Cormorant Garamond or Playfair Display), clean readable body text.
- Subtle textures (parchment, sun-washed stone), soft shadows, gentle fade-in animations on scroll.
- Mobile-first. Most visitors will come from phones and Facebook.
- Use the uploaded character images throughout.

PAGES

1. Home (/)
- Hero: game title "Whispers of Joppa", tagline "A merge story of grace", Naomi's character image, and App Store + Google Play badge buttons (link to "#" for now, labeled "Coming soon").
- Short story intro: "Sent away under a cloud of rumor, Naomi returns to the ancient harbor town of Joppa, where her late grandmother left her a crumbling bakehouse and a trail of hidden letters. Restore the town, uncover the truth behind its whispers, and discover what grace can rebuild."
- "How it plays" in 3 illustrated steps: Merge (combine items into greater treasures), Restore (rebuild the bakehouse, the docks, and the harbor), Uncover (reveal the truth behind every rumor).
- "Meet the people of Joppa": cards for Naomi, Esther, Caleb, Joy, Silas with one-line descriptions:
  - Naomi: "A widow with a reputation to restore."
  - Esther: "Her grandmother, whose hidden letters guide the way."
  - Caleb: "A quiet boat builder carrying a painful secret."
  - Joy: "His fearless daughter, who asks the questions no one else will."
  - Silas: "An old fisherman who remembers everything, slowly."
- Faith section: "Rooted in Scripture. Inspired by Acts 9–11 and Proverbs 16:28, 'A whisperer separateth chief friends.' A story about the cost of gossip and the power of truth, forgiveness, and grace."
- "Join the launch list" email signup: name + email, stored in a Supabase table `launch_signups` (name, email, created_at). Show a thank-you message after submitting. Prevent duplicate emails.
- Footer: links to Support, Privacy Policy, Terms of Service, Delete Account; © Whispers of Joppa.

2. Support (/support)
- Contact email.
- FAQ accordion:
  - How do I save my progress? (Progress saves automatically. To keep it when changing phones, go to Settings and connect your Apple, Google, or email account.)
  - I bought something and didn't receive it. (Restart the game while connected to the internet; purchases are delivered automatically. If it still hasn't arrived, email us your player ID from Settings.)
  - How do I restore purchases? (Settings → Restore Purchases.)
  - How does energy (Manna) work? (Tapping a generator uses 1 Manna. Manna refills over time.)
  - How do I turn off notifications? (Settings → Notifications.)
  - How do I delete my account? (Link to /delete-account.)

3. Delete Account (/delete-account)
- Steps to delete in the game: Settings → Account → Delete Account.
- If the player can't access the game: email support@whispersofjoppa.com from the email linked to the account, with their player ID if they have it, and we'll delete it within 30 days.
- What's deleted: account, cloud save, purchase history linked to the account, notification tokens. Note that purchases made through Apple or Google are also recorded by those stores under their own policies.

4. Privacy Policy (/privacy)
Draft a clear plain-English privacy policy for a mobile game that collects and uses: optional account sign-in (Apple, Google, email); cloud save data; in-app purchase records (payments processed by Apple and Google, we never see card details); gameplay analytics and crash reports through Google Firebase; push notifications through Firebase Cloud Messaging; advertising through Google AdMob (rewarded ads only, with consent where required and Apple's App Tracking Transparency prompt on iOS); data stored with Supabase. Include: data retention, account deletion, children (game is not directed at children under 13), users' rights (including California and GDPR), how to contact us. Add a "Last updated" date. Put a clear note at the top of the page in the admin/draft version only: "DRAFT — pending legal review."

5. Terms of Service (/terms)
Draft plain-English terms for a free-to-play mobile game: license to play, virtual items (Pearls, Talents, Manna) have no real-world value and can't be exchanged for money, purchases are final except as required by law or by Apple/Google refund policies, account conduct, termination, disclaimers, limitation of liability, governing law California, contact. Add a "Last updated" date.

6. app-ads.txt
Create a plain text file at the site root, /app-ads.txt (in the public folder so it's served as whispersofjoppa.com/app-ads.txt). Leave it with a single comment line for now: "# AdMob line will be added here". It must be plain text, not an HTML page.

SEO and sharing
- Page titles and meta descriptions for each page.
- Open Graph/Facebook share image using the hero art and title.
- Favicon from a simple olive branch or lamp icon in the game's palette.

Don't add any other pages, logins, or features.

This project was built with [Lovable](https://lovable.dev).

## Build with Lovable

Continue developing this project in the [Lovable editor](https://lovable.dev/projects/1702231b-27df-48e7-aeb4-ad698624d86a).

- **Ship faster**: describe what you want to build and Lovable handles the code.
- **Stay in sync**: every change made in Lovable is committed straight to this repository.
- **Full ownership**: this code is yours. Push to `main` on GitHub and your changes sync back into Lovable, ready for your next prompt.

## Development

Prefer working locally? You need Node.js and npm — [install with nvm](https://github.com/nvm-sh/nvm#installing-and-updating).

```sh
git clone <this-repository-url>
cd <repository-name>
npm i
npm run dev
```
