# ReEnchanted App Store Review Packet

Last updated: 2026-06-19

This packet is the working checklist for getting `ReEnchanted` / `InsideCoverApp`
ready for App Review with the BookShop enabled.

## Submission posture

- App name: ReEnchanted
- Bundle ID: `com.openclaw.enchantify.insidecover`
- Category: Entertainment
- Minimum OS: iOS 17
- Account requirement: none
- Purchase model: free app with non-consumable in-app purchases for optional
  digital content packs
- Privacy posture: local-first, opt-in data doors, no third-party advertising,
  no cross-app tracking

## Code decisions already made

- Release builds use StoreKit only. The debug-only `Scrivener's Counter (dev)`
  fallback is excluded from distribution builds.
- HealthKit remains enabled for opt-in Body Pages, but clinical health records
  and HealthKit background delivery are not requested.
- Background modes are limited to bundled radio audio and overnight processing.
  Background location, remote notification, and fetch modes are not declared.

## BookShop products

Create rows marked `Non-consumable` as In-App Purchases in App Store Connect.
The product IDs must match the values in `BookShopCatalog`.

| Product ID | Reference name | In-app title | Type | Price | Status |
| --- | --- | --- | --- | --- | --- |
| `com.openclaw.enchantify.insidecover.pack.nocturne-folio` | Nocturne Folio Pack | The Nocturne Folio | Not IAP | Free gift | Bound manually in Bookshop |
| `com.openclaw.enchantify.insidecover.pack.academy-night-band` | Academy Night Band Pack | Academy Night Band | Non-consumable | TBD | Needed |
| `com.openclaw.enchantify.insidecover.pack.starlit-paper-trial-archive` | Starlit Paper Trial Archive Pack | The Starlit Paper Trial Archive | Non-consumable | USD 1.99 | Ready, not dev |

Do not create IAP products yet for listings marked `comingSoon`:

- `com.openclaw.enchantify.insidecover.pack.saltwater-looms`
- `com.openclaw.enchantify.insidecover.pack.gilded-margins`

## StoreKit acceptance checklist

- Product metadata appears in sandbox and TestFlight.
- Paid shelf shows App Store prices, not `$0.00 dev`.
- Purchase success unlocks the pack and writes it to the save.
- Cancelled purchases leave the pack locked.
- Pending purchases show a non-error pending message.
- Restore purchases works on the original install.
- Restore purchases works after deleting and reinstalling the app.
- Already owned packs move to "Already Bound to You."
- Coming-soon listings cannot be purchased.
- App Review notes explain how to open the BookShop and what each IAP unlocks.

## Sensitive permission justification

Use these justifications in App Review notes and privacy/support copy.

| Permission or capability | Why it exists | User control | Data boundary |
| --- | --- | --- | --- |
| HealthKit read access | Creates optional Body Pages from movement, sleep, heart, respiratory, blood pressure/glucose, body mass, and nutrition quantities. Fuller input can make the app more personally useful, but the app does not diagnose, treat, or prescribe. | User taps the Body seal and approves HealthKit types. | Read on device; translated into private page context. |
| Location When In Use | Fetches local weather and checks whether the reader is near a user-created Anchor. | User taps Weather or Location seals. | Coordinates are used for weather/nearby checks; pages avoid raw coordinates. |
| Photos | Lets the reader choose photos for illuminated pages, custom cast portraits, and artifact export. | User chooses photos or taps save to Photos. | Photo content stays on device unless the user exports/shares it through iOS. |
| Camera | Lets the reader take a photo for a page, enchantment, or cast member. | User taps camera/photo flows. | Captured media stays in app storage unless user saves/shares. |
| Microphone and Speech Recognition | Optional dictation for page text and answers, and optional "kept voice" recordings saved alongside a page's transcript. | User taps the voice input control or the "Keep your voice" control on a page. | Speech fills text fields; kept-voice `.m4a` files stay in app storage and travel only inside a user-initiated Sealed Copy. |
| Journaling Suggestions (`com.apple.developer.journal.allow`) | Optional "What the Book noticed today…" surfaces Apple's on-device Journaling Suggestions (photos, workouts, places, music) as writing prompts. iPhone-only, iOS 17.2+. | User taps the Book-notices control and picks a suggestion in Apple's out-of-process picker. | The picker runs outside the app; the app receives only the single suggestion the user picks, and uses its title/date as prompt seed text on device. |
| Calendar | Optional Calendar Doorway reads upcoming events and explicit buttons add app events such as market windows or festivals. | Disabled by default; user toggles Calendar Doorway or taps add-to-calendar buttons. | Event context stays on device and is summarized as page timing, not uploaded as a calendar dump. |
| Reminders | Adds reminders for user-accepted in-world commitments. | User taps a reminder action. | Writes only the requested reminder. |
| Notifications | Sends local "Book whisper" reminders and test notifications. | Disabled by default; user enables whispers. | Local notifications only. |
| Face ID / Touch ID / passcode | Optional lock for the private book. | User enables Protect the Book. | The app receives only authentication success/failure. |
| Background audio | Keeps the bundled in-app radio playing when the app backgrounds. | User starts/stops radio. | Bundled/local playback; no tracking. |
| Background processing | Allows the overnight scribe to prepare pages opportunistically. | Controlled by app settings and system scheduling. | Uses local save/context. |
| File sharing | Lets users export or import their portable `.reenchanted-save.json` save. | User initiates import/export through iOS Files/share flows. | User-owned save data. |

## Health and medication stance

The app can produce better, more personal reflections when it has body context,
food/fuel notes, and user-entered medication or supplement mentions. That is
worth keeping, with guardrails:

- It must remain optional.
- It must never claim to diagnose, treat, monitor, or replace medical care.
- It should frame body data as "signals" or "weather," not instructions.
- It may help the reader form a question for a doctor or pharmacist.
- It should not request clinical health records unless a specific user-facing
  clinical-record feature exists.
- It should not request HealthKit background delivery unless a specific
  background health feature exists.

## Suggested App Review notes

ReEnchanted is a local-first private journaling and literary reflection app. It
turns user-entered notes, optional HealthKit signals, optional weather/location,
optional photos, optional calendar context, and local app state into private
book pages.

No account is required. Most sensitive data paths are off by default or
user-initiated. The Body seal requests HealthKit read access only to create
private Body Pages; the app does not provide diagnosis, treatment, medication
instructions, or emergency guidance. Location is requested only when the user
taps Weather or Location. Calendar, Reminders, Notifications, Photos, Camera,
Speech, and Face ID are each tied to visible user actions or settings.

The BookShop is opened from the Glow menu or from the BookShop preview page.
Paid packs are non-consumable In-App Purchases using StoreKit. The restore
button is labeled "Ask the ledger about past purchases." The initial paid packs
are The Nocturne Folio, Academy Night Band, and The Starlit Paper Trial Archive.

## Manual App Store Connect tasks

- Enroll and keep Apple Developer Program membership active.
- Accept paid apps / in-app purchase agreements.
- Enter banking and tax information.
- Create the app record for `com.openclaw.enchantify.insidecover`.
- Create the non-consumable IAP products above.
- Add support URL, marketing URL if desired, and privacy policy URL.
- Fill App Privacy details from `docs/PrivacyPolicyDraft.md`.
- Set age rating. Avoid Kids Category.
- Add screenshots for iPhone and iPad.
- Upload a Release archive through Xcode or Transporter.
- Run TestFlight internal testing, then external testing.
- Submit the app and IAP products together for first review.

## Final pre-submit smoke test

- Fresh install launches without a crash.
- Fresh install works with all permissions denied.
- Fresh install works with all requested permissions granted.
- Body, Weather, Location, Calendar, Photos, Camera, Speech, Notifications, and
  Book Lock explain themselves before or during permission prompts.
- BookShop loads real StoreKit products in TestFlight.
- Purchase, cancel, pending, and restore paths work.
- Export/import save works.
- No debug/dev purchase labels appear in Release.
- App icon, launch screen, display name, version, and build number are correct.
