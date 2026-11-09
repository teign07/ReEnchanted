# ReEnchanted App Store Review Packet

Last updated: 2026-10-13

The working checklist for TestFlight external testing and first App Review.
Privacy answers live in `docs/AppPrivacyInventory.md`; payment go-live lives in
`docs/going-live-checklist.md`.

## Submission posture

- App name: ReEnchanted. Prepared submission bundle ID `app.reenchanted.book`
  (+ `.widgets`, `.share`). App Group `group.app.reenchanted.book`.
  Applied on main 2026-11-08 (3c690ba3) and registered in the developer portal
  under team 3YH7862K4Q. Existing Books move through the sealed-copy migration
  in the launch checklist.
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
- User-generated content: **none shown**. There is no community feature
  (Public Margins was removed from the app on 2026-11-01): no other reader's
  text is fetched or displayed, and nothing can be offered. Every Book stays
  its reader's own.

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
| Location When In Use | Where a kept Page happened (place label + weather), weather, nearby Anchors, Compass Runs. | First keep: the Book asks in-app ("Can I write down where we are?") before iOS does; "Not now" rests 3 days. Otherwise the reader taps Weather/Location. |
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
  text the app writes into Pages, there is no browser). Let's Chat is an
  on-device AI chat: answer the AI/chatbot question yes. Expect 13+.
- Screenshots: 6.9" iPhone and 13" iPad. Populated footage must come from a real
  phone (a fresh simulator only shows onboarding).
- TestFlight: internal first (no review), then external (Beta App Review).

## Suggested App Review notes

Paste into App Store Connect → App Review Information → Notes (and TestFlight →
Test Information → Beta App Review notes). Updated 2026-11-08.

> ReEnchanted is a free, local-first journal that answers back as a living book.
> Everything the reader writes stays on the device. There is no account, no
> sign-in, no In-App Purchase, and nothing shared between readers.
>
> **Printed books.** Readers can order printed books of their own pages. These
> are physical goods printed and mailed by Lulu and paid with Stripe (Guideline
> 3.1.3(e)); nothing digital is sold. In this build paper ordering is closed:
> the Bookshop (Glow menu → Bookshop) says "Paper opens soon", and no payment
> can be started. Making a PDF of your own pages is free and works.
>
> **The on-device model.** An optional ~3.5 GB download (Gemma, from Hugging
> Face) is offered during onboarding. It is model weights, not executable code,
> and it runs entirely on the device. The app is fully usable without it; you
> can tap "Not yet" and keep writing.
>
> **Let's Chat** is a conversation with that on-device model. Nothing typed
> there leaves the phone. Every conversation says the replies come from an AI
> model and can be wrong; holding a reply offers "Erase this reply" and
> "Report it" (a pre-filled email to hello@reenchanted.app that the reader
> chooses to send).
>
> **Permissions** are each requested from a visible action, with the reason
> said first: HealthKit (optional Body Pages, read only, no diagnosis or
> advice), Location (weather), Photos and Camera (pictures on pages), Microphone
> and Speech (dictation), Calendar and Reminders (optional), Notifications
> (off by default), Face ID (optional lock). Everything works with every
> permission denied.
>
> **Health data and print.** Health-derived pages are excluded from printed
> books by default. Only if the reader turns on "Include Fuel & Inner Weather"
> for their own printed volume, and then orders it, does a summary of those
> pages appear in the PDF sent to the printer, to be mailed to that reader.
> It is never used for advertising, marketing, or anything else.
>
> **Public-web lookups** (off by default) use Wikipedia's search API, the GDELT
> news index, and public research APIs, and return text the app writes into the
> reader's pages. There is no in-app browser.

## Final pre-submit smoke test

- Fresh install launches; works with every permission denied.
- Fresh install that never downloads the model can write, keep, and read Pages.
- Bookshop: a Release build not set to live says "Paper opens soon" and starts
  no payment; a live build quotes, checks out, and returns a receipt.
- No "(dev)" labels in Release (the `Scrivener's Counter (dev)` till is
  Debug-only).
- App icon, display name "ReEnchanted", version, and build number correct.
