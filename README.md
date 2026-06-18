# ReEnchanted / InsideCover

SwiftUI iOS/iPadOS companion app for Enchantify.

## Requirements

- macOS with Xcode installed
- iOS 17 SDK or newer
- Network access on first build so Xcode can resolve Swift Package dependencies
- An Apple development team only if building to a physical device

The SwiftPM core tests and simulator build do not require a connected iPhone.

## Build And Test

From this directory:

```sh
CLANG_MODULE_CACHE_PATH=/private/tmp/insidecover-module-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/insidecover-spm-module-cache \
swift test
```

From the repository root:

```sh
xcodebuild \
  -project ios/InsideCover/EnchantifyInsideCover.xcodeproj \
  -scheme InsideCoverApp \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/InsideCoverDerivedData \
  build
```

To run on a simulator, open `EnchantifyInsideCover.xcodeproj` in Xcode, select
the `InsideCoverApp` scheme and an iOS simulator, then Run.

To run on a physical device, select your Apple development team for
`InsideCoverApp`. If Xcode cannot use the default bundle identifier with your
team, change it to a unique identifier.

## Notes

- The app falls back gracefully when optional local model assets are missing.
- The bundled sample state is enough for the app to open on a fresh install.
- Personal save data should be imported separately through Files/AirDrop and
  should not be required for a clean build.
