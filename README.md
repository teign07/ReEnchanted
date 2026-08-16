# ReEnchanted

**A living storybook for the day you actually lived.**

**[Meet the Book at reenchanted.app →](https://reenchanted.app)**

ReEnchanted turns ordinary daily material — notes, moods, weather, walks, meals,
photos, the people who pass through, the choices you make — into a private,
illustrated book that remembers you and returns. Open it and the day arrives as
small keepable pages. Keep what's true, let the rest wait, and each night the
Book braids your real day into a chapter of a continuing Faerie tale: *the Book of
You.*

Those chapters can leave the screen. A remarkable week can become a
saddle-stitched issue; a month or season can become a softcover; a year can end
as a cloth-and-gold-foil hardcover with the reader's name on its spine. Together
they form an actual Faerie-tale series of an ordinary life, made to live on a
shelf. Digital PDFs are free, physical Books can be ordered à la carte, and the
optional Bound Year sends three seasonal softcovers and the year's final
hardcover.

It is not a journal app, a habit tracker, a chatbot, or a game UI wearing a
storybook skin. It is a storybook interface for *attention* — and a small living
world that reaches gently off the screen into your real days.

> ReEnchanted is its own thing. *Enchantify Academy* is the fictional school you
> fall into inside the Book — the setting, not a separate product.

---

## The thesis

> Real life is the best-written chapter in the book. The most sensory, the most
> alive. The app's job is not to optimize, score, or diagnose you — it is to
> notice your life with you, like a careful book, until ordinary days become
> worth keeping.

The Book speaks in character and forms careful literary opinions about your
story — *"this person appears when you describe safety," "harbors and rain keep
gathering," "this belief has been in the margins for months"* — but the
machinery underneath stays local, structured, and explicit. Observations, never
clinical claims.

**Design principles**

- **Memory over novelty.** New systems should deepen existing memory before
  adding another disconnected feature. The goal isn't more page types — it's a
  better *reader*.
- **Kept pages are canonical.** You decide what becomes real archive. The Book is
  built on consent and taste.
- **Local first.** Private Book material stays on device. The free app requires
  no ReEnchanted login, and the generative "local brain" runs on the phone
  itself. Optional purchases use an Apple account or a limited Stripe payment
  and delivery record; neither receives the private Book archive.
- **Structured before generated.** Typed events, ledgers, memories, and source
  IDs give generated prose rails, so the world reflects what you actually kept
  and did.
- **In-world, not dashboard.** Data shows up as pages, letters, margins, star
  charts, and bound editions — not charts for their own sake.
- **No dark patterns.** No streaks, no guilt, no notifications begging you back.

## The daily loop

```
surface → keep / let it wait → archive → event & memory → curation → return
```

The Book surfaces a small set of candidate pages, chosen by a curator that
weighs your attention, fatigue, time of day, and what's alive right now. You keep
what matters. Kept pages persist into the archive and can mint narrative events,
character memories, belief, and continuity signals — which feed the next day's
pages, letters, and stories. Nothing vanishes into a feed.

## What's inside

**Capture, lightly.** Inner weather, one-sentence souvenirs, body and fuel notes,
the day's sky, places, and a craft helper that nudges you toward one true,
concrete sentence before any model embellishes it.

**The Book of You.** A nightly braid that weaves the day's kept pages — what you
noticed, ate, walked, and chose — into a short personal chapter, with a quality
loop that learns from your feedback and rewrites closer to your day.

**A book that remembers.** *The Book Remembered* resurfaces old pages when today
rhymes with them. *The Book Notices* surfaces patterns, absences, and durations.
Surviving threads become named **constellations**; the Book even seals dated
wagers in the margins and owns the result when it's wrong.

**Bound editions.** A week can close as a saddle-stitched issue. Each month's
kept pages bind into a themed **PDF edition** with its own cover and a foreword
the Book writes about the month. Three months gather into a seasonal softcover;
a year becomes an **annual volume** of twelve chapters, available as an
illustrated hardcover or in cloth, gold foil, and a printed dust jacket.

**A living world.** Character letters that remember your choices; *Story Pages*
that braid your real day with fictional choices; gossip between characters; *Ask
the Book*; *Two Readings* where the cast disagrees and you decide. Your real
world bleeds in — your steps set how lively the halls are, poor sleep quiets the
world, the weather outside is the weather in the Stacks.

**The Outer Stacks.** Anchor a real GPS place and the Book grows it a room with
its own story that deepens every time you return — a fairy-tale answer to
location games.

**The Book Fae.** Old-law creatures who've read the world but never touched it.
They never want belief — they want *noticing*; you pay bargains in sensory field
reports, and parley with rules that bend the world.

**The Pact War & the Chapters.** Five Academy Chapters — five wagers about what a
life *is* — contest belief across the Book; you're eventually sorted by the pages
you keep. Whichever ascends colors the scenes, tone, and choices the Book writes.

**Atmosphere & ritual.** ReEnchanted Radio (stations that tint the feed), the
Almanac (the Wheel of the Year and lunar esbats), Today's Sky, the Wonder Compass,
photo Enchantments, and the Margins Atlas — a relationship graph drawn as a
living loom.

**The local brain.** On-device generation (Gemma/MLX) does the writing. Every
model call is user-initiated, and everything stays usable with graceful fallbacks
when the model is missing or busy.

For the full product and architecture map, read [`PROJECT_OVERVIEW.md`](PROJECT_OVERVIEW.md).

## Privacy & your data

The most personal app on your phone shouldn't feel like a surveillance product.
ReEnchanted is **local-first**: no ReEnchanted account is required for the free
app, and there are no ads, attention-selling analytics, or remote copies of the
private Book. Body, weather, location, calendar, and other signals come through
explicit, revocable permissions. Your archive, memories, belief ledgers, and
custom cast are *your save* — portable via `.reenchanted-save.json` export/import.

Optional digital subscriptions are recorded by Apple. Optional physical orders
use Stripe for the email, payment, and parcel details needed to print and ship a
Book. Neither doorway receives the reader's private archive. Paid additions are
ReEnchanted's own digital chapters, world packs, and printed editions—not ads or
outside-vendor offers.

## Status

**In active development.** Visit **[reenchanted.app](https://reenchanted.app)**
for the full illustrated tour and TestFlight invitation. You can also star or
watch this repository, or follow development on
[Patreon](https://www.patreon.com/thedoobaleedoos).

## Architecture

The codebase carries the working codename **InsideCover**.

- `EnchantifyInsideCover.xcodeproj` — the iOS/iPadOS app project.
- `InsideCoverApp/` — the SwiftUI app: surfaces, sheets, app services, PDF export,
  local-brain integration, and device-only affordances.
- `Shared/` — the SwiftPM core (`InsideCoverCore`): typed models, curation, source
  adapters, story systems, archive/search/export logic, page packs, and world
  systems.
- `Tests/InsideCoverCoreTests/` — coverage for the shared policy and domain systems.
- `LandingPage/` and `RemotionPromo/` — promotional surfaces, not app runtime code.

## License

The **source code** is open source under the **Mozilla Public License 2.0**
(MPL-2.0) — see [`LICENSE`](LICENSE). You're free to read, audit, modify, and
redistribute it; changes to MPL-licensed files stay open under the same license,
but you can combine the code with your own files under another license. MPL is
also App Store–friendly, unlike GPL/AGPL.

The app's **content is proprietary and not open source**: artwork, illustrations,
talismans, audio/radio tracks, paid content packs and world-event packs, and the
ReEnchanted name and branding are All Rights Reserved. MPL grants no trademark
rights, so any fork must be renamed and rebranded. Reader save data belongs to
the reader. See [`NOTICE`](NOTICE) for the full code-vs-content breakdown.

In short: the engine is open; the art, audio, and content are ours; your saves
are yours.

## Requirements

- macOS with Xcode installed
- iOS 17 SDK or newer
- Network access on first build if Xcode needs to resolve packages
- An Apple development team only for physical-device builds

The shared SwiftPM tests and simulator build do not require a connected iPhone.
The local brain is designed for physical devices; simulator builds compile and
exercise fake/fallback paths.

## Build And Test

Run shared-core tests from the repository root:

```sh
CLANG_MODULE_CACHE_PATH=/private/tmp/insidecover-module-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/insidecover-spm-module-cache \
swift test
```

Build the app for iOS Simulator:

```sh
xcodebuild \
  -project EnchantifyInsideCover.xcodeproj \
  -scheme InsideCoverApp \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/InsideCoverDerivedData \
  build
```

There is also a helper for the shared test bundle when local signing/provenance
gets in the way:

```sh
scripts/swift-test-resigned.sh
```

You can pass a test class or a single XCTest filter to the helper:

```sh
scripts/swift-test-resigned.sh BookCuratorTests
scripts/swift-test-resigned.sh BookCuratorTests/testWorldEventDoorSurfacesFieldworkDuringActiveEvent
```

## Running The App

To run on a simulator, open `EnchantifyInsideCover.xcodeproj` in Xcode, select
the `InsideCoverApp` scheme and an iOS simulator, then Run.

To run on a physical device, select the `InsideCoverApp` target, set your Apple
development team, and change the bundle identifier if Xcode asks for a unique one.

## Notes

- Bundle ID: `com.openclaw.enchantify.insidecover`
- App target: `InsideCoverApp`
- Shared package: `InsideCoverCore`
- Supported runtime target: iOS 17+
- App Store readiness notes live in `docs/AppStoreReviewPacket.md`,
  `docs/PrivacyPolicyDraft.md`, and `docs/AppPrivacyInventory.md`.
- The old widget source is intentionally detached from this project and lives
  outside the app target.
- The app should remain usable when optional local model assets are missing,
  busy, or unavailable.
- Personal save data is portable through `.reenchanted-save.json` export/import
  and should not be required for a clean build.
