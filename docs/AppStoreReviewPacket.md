# ReEnchanted App Store Review Packet

Last updated: 2026-10-13

The working checklist for TestFlight external testing and first App Review.
Privacy answers live in `docs/AppPrivacyInventory.md`; payment go-live lives in
`docs/going-live-checklist.md`.

## Submission posture

- App name: ReEnchanted. Prepared submission bundle ID `app.reenchanted.book`
  (+ `.widgets`, `.share`). App Group `group.app.reenchanted.book`.
  The rename is staged on `rename/app-reenchanted-book`; the current checkout
  still uses the old ID. Apply it after paid membership activation and preserve
  the existing Book through the sealed-copy migration in the launch checklist.
- Category: Books (`LSApplicationCategoryType = public.app-category.books`);
  secondary Entertainment.
- Minimum OS: iOS 17. iPhone and iPad.
- Account: none.
- Price: **free**. **No In-App Purchases.** The Digital Standing Order is
  retired (`DigitalStandingOrder.isOffered = false`); every reader gets the same
  monthly stories free.
- Money: printed books (single editions, gifts, the Bound Year subscription of
  printed volumes) sold through Stripe. These are **physical goods delivered
  outside the app**, which Guideline 3.1.3(e) requires to use a non-IAP payment
  method. Nothing digital is sold through Stripe.
- Export compliance: `ITSAppUsesNonExemptEncryption = NO` (build setting).
  The app uses HTTPS and Apple's CryptoKit (SHA-256, AES-GCM for gift links),
  both OS-provided standard encryption.
- User-generated content: **none shown**. Public Margins is closed
  (`PublicMarginsAPI.isAvailable = false`): no community text is fetched or
  displayed, and nothing can be offered. Every Book stays its reader's own.

## Things a reviewer will trip on, and the answers

- **The local brain is a ~3.5 GB optional download** of Gemma model weights from
  Hugging Face (data, not code; nothing executable is downloaded). The app must
  be fully usable without it. Smoke-test a fresh install that never downloads it.
- **Printed books open a Stripe payment sheet.** Explain in review notes that
  these are physical books printed and mailed by Lulu.
- **Calendar-gated content.** Monthly scenes and festival pages appear on their
  dates; reviewers will see whatever is live that week.
- **Increased memory entitlement** (`com.apple.developer.kernel.increased-memory-limit`)
  exists for the on-device model. Direct photo vision runs only on ≥8 GB devices.

## Sensitive permissions

| Permission | Why | Control |
| --- | --- | --- |
| HealthKit (read) | Optional Body Pages from movement, sleep, heart, etc. No diagnosis or advice. | Reader taps the Body seal. Body data stays on device unless the reader turns on "Include Fuel & Inner Weather" and orders paper. |
| Location When In Use | Weather, nearby Anchors, Compass Runs. | Reader taps Weather/Location. |
| Photos / Camera | Photos on Pages, Enchantments, Cast portraits. | Reader picks or takes photos. |
| Microphone / Speech | Dictation and kept-voice recordings. | Reader taps the voice control. |
| Calendar / Reminders | Calendar Doorway (off by default); reminders on explicit request. | Toggle / button. |
| Notifications | Local Book whispers. | Off by default. |
| Face ID | Optional Book lock. | Reader enables Protect the Book. |
| Background audio | In-app radio keeps playing. | Reader starts/stops radio. |
| Background processing | Overnight scribe and weather bell (no GPU/model work in background). | System scheduling. |

## After the fee: optional unlocks

- **Apple Pay**: merchant ID + capability + Stripe registration + two plist keys
  (`docs/going-live-checklist.md` §2).
- **Journaling Suggestions**: request the capability, re-add
  `com.apple.developer.journal.allow`, flip `BookNoticesPicker.entitlementProvisioned`.

## App Store Connect tasks

- Enroll as an individual (bj's decision, October 13). Organization enrollment
  is deferred. Seller name is public; EU storefront availability remains a
  separate decision, with public contact details for trader distribution.
- Create the app record and the two extension bundle IDs + App Group.
- Free Apps agreement only (no Paid Apps agreement needed with no IAP).
- Privacy policy URL `https://reenchanted.app/privacy.html`; support URL
  `https://reenchanted.app`; EULA `https://reenchanted.app/terms.html`.
- App Privacy answers from `docs/AppPrivacyInventory.md`.
- Age rating: answer honestly for horror/fear themes (the October Count Unbound
  issue: Dracula, a bite) and "unrestricted web access: no" (web lookups return
  text the app writes into Pages, there is no browser). Expect 12+.
- Screenshots: 6.9" iPhone and 13" iPad. Populated footage must come from a real
  phone (a fresh simulator only shows onboarding).
- TestFlight: internal first (no review), then external (Beta App Review).

## Suggested App Review notes

ReEnchanted is a free, local-first journal that answers back as a living book.
Everything the reader writes stays on the device. There is no account and no
In-App Purchase.

Optional printed books of the reader's own pages are sold as physical goods and
paid with Stripe; Lulu prints and mails them. To see it: Glow menu → Bookshop.
[TestFlight/Review builds: say whether checkout is live or test mode, and give
a Stripe test card if test.]

The on-device writing model is an optional download (about 3.5 GB) offered in
the first minutes; the Book works without it. HealthKit, Location, Photos,
Camera, Microphone, Calendar, Reminders, Notifications and Face ID are each
requested only from a visible action. HealthKit data is used on device to write
private Body Pages; the app offers no diagnosis or medical advice.

## Final pre-submit smoke test

- Fresh install launches; works with every permission denied.
- Fresh install that never downloads the model can write, keep, and read Pages.
- Doorways sheet shows no Public Margins section on a fresh install.
- Bookshop quotes, checks out, and returns a receipt in the build's checkout mode.
- No "(dev)" labels in Release (the `Scrivener's Counter (dev)` till is
  Debug-only).
- App icon, display name "ReEnchanted", version, and build number correct.
