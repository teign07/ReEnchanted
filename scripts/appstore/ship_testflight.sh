#!/usr/bin/env bash
# Archive, sign, export and upload one TestFlight build of ReEnchanted.
#
#   scripts/appstore/ship_testflight.sh 6        # build number = next unused
#
# Why not Xcode's Organizer: Xcode's account sign-in is broken on this Mac, and
# `xcodebuild -allowProvisioningUpdates -authenticationKey*` rejects the API key
# ("bearer token") even though altool and the REST API accept it. So signing is
# manual: signing.xcconfig gives each app target its "<bundle id> AppStore"
# profile and leaves SwiftPM targets unsigned; ExportOptions.plist maps the same
# profiles. Profiles + the Apple Distribution cert expire 2027-11-08.
set -euo pipefail
cd "$(dirname "$0")/../.."
BUILD="${1:?usage: ship_testflight.sh <build-number>  (check scripts/appstore/status.py for the last one)}"
HERE=scripts/appstore
ENV_FILE="$HOME/.appstoreconnect/reenchanted.env"
# shellcheck disable=SC1090
source "$ENV_FILE"
OUT="${SHIP_DIR:-$HOME/Library/Developer/ReEnchantedShip}/build-$BUILD"
mkdir -p "$OUT"

# A first Release archive needs ~6 GB; an incremental one (Release intermediates
# still in DerivedData) needs far less, so MIN_FREE_GB can lower the bar.
free_gb=$(df -g / | awk 'NR==2 {print $4}')
if [ "$free_gb" -lt "${MIN_FREE_GB:-6}" ]; then
  echo "Only ${free_gb} GB free; an archive needs about ${MIN_FREE_GB:-6} GB. Clear space first (see docs/apple-developer-handoff.md)." >&2
  exit 1
fi

echo "== $(git rev-parse --short HEAD) $(git status --porcelain | wc -l | tr -d ' ') uncommitted paths; build $BUILD -> $OUT"

xcodebuild -project EnchantifyInsideCover.xcodeproj -scheme InsideCoverApp \
  -configuration Release -destination generic/platform=iOS \
  -archivePath "$OUT/ReEnchanted-1.0-$BUILD.xcarchive" \
  -xcconfig "$HERE/signing.xcconfig" \
  -skipPackagePluginValidation -skipMacroValidation \
  COMPILER_INDEX_STORE_ENABLE=NO CURRENT_PROJECT_VERSION="$BUILD" \
  archive > "$OUT/archive.log" 2>&1 || { grep -E "error:" "$OUT/archive.log" | head -20; echo "archive failed: $OUT/archive.log" >&2; exit 1; }
echo "archived"

xcodebuild -exportArchive -archivePath "$OUT/ReEnchanted-1.0-$BUILD.xcarchive" \
  -exportOptionsPlist "$HERE/ExportOptions.plist" -exportPath "$OUT/export" \
  > "$OUT/export.log" 2>&1 || { tail -20 "$OUT/export.log"; exit 1; }
echo "exported"

xcrun altool --upload-app -f "$OUT/export/InsideCoverApp.ipa" -t ios \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID" 2>&1 | tee "$OUT/upload.log" | grep -E "UPLOAD SUCCEEDED|ERROR|error" || true
grep -q "UPLOAD SUCCEEDED" "$OUT/upload.log" || { echo "upload failed: $OUT/upload.log" >&2; exit 1; }
echo "uploaded build $BUILD; Apple processes it for ~10-30 min (scripts/appstore/status.py)."
echo "The archive is $(du -sh "$OUT" | cut -f1); delete $OUT once the build shows VALID."
