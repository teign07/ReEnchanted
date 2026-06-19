# ReEnchanted / InsideCover

ReEnchanted is a SwiftUI iOS/iPadOS app for Enchantify. It turns daily material
such as kept notes, moods, weather, body/fuel logs, photos, places, choices,
letters, and story fragments into a private illustrated book that remembers and
returns.

The short version of the architecture:

- `EnchantifyInsideCover.xcodeproj` is the iOS app project.
- `InsideCoverApp/` contains the SwiftUI app, sheets, app services, PDF export,
  local-brain integration, and device-only affordances.
- `Shared/` contains the SwiftPM core: typed models, curation, source adapters,
  story systems, archive/search/export logic, page packs, and world systems.
- `Tests/InsideCoverCoreTests/` covers the shared policy and domain systems.
- `RemotionPromo/` and `LandingPage/` are separate promotional surfaces, not app
  runtime code.

For the full product and architecture map, read `PROJECT_OVERVIEW.md`.

## License

The **source code** is open source under the **Mozilla Public License 2.0**
(MPL-2.0) — see `LICENSE`. You're free to read, audit, modify, and redistribute
it; changes to MPL-licensed files stay open under the same license, but you can
combine the code with your own files under another license. MPL is also
App Store–friendly, unlike GPL/AGPL.

The app's **content is proprietary and not open source**: artwork, illustrations,
talismans, audio/radio tracks, paid content packs and world-event packs, and the
"ReEnchanted"/"Enchantify" names and branding are All Rights Reserved. MPL grants
no trademark rights, so any fork must be renamed and rebranded. Reader save data
belongs to the reader. See `NOTICE` for the full code-vs-content breakdown.

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
development team, and change the bundle identifier if Xcode asks for a unique
one.

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
