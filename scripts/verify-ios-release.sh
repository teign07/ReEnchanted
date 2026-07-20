#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DERIVED_DATA="${REENCHANTED_DERIVED_DATA:-/private/tmp/ReEnchanted-ReleaseGate}"
DEVICE_ID="${REENCHANTED_DEVICE_ID:-}"
INSTALL_ON_DEVICE="${REENCHANTED_INSTALL:-0}"
BUILD_LOG="${REENCHANTED_BUILD_LOG:-/private/tmp/ReEnchanted-ReleaseGate-xcodebuild.log}"
TEST_LOG="${REENCHANTED_TEST_LOG:-/private/tmp/ReEnchanted-ReleaseGate-tests.log}"
PROJECT="EnchantifyInsideCover.xcodeproj"
SCHEME="InsideCoverApp"
EXPECTED_APP_ID="com.openclaw.enchantify.insidecover"
EXPECTED_WIDGET_ID="com.openclaw.enchantify.insidecover.widgets"
APP="$DERIVED_DATA/Build/Products/Debug-iphoneos/InsideCoverApp.app"
WIDGET="$APP/PlugIns/ReEnchantedWidgetsExtension.appex"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-/private/tmp/reenchanted-release-module-cache}"
export SWIFTPM_MODULECACHE_OVERRIDE="${SWIFTPM_MODULECACHE_OVERRIDE:-/private/tmp/reenchanted-release-spm-cache}"

mkdir -p "$DERIVED_DATA" "$CLANG_MODULE_CACHE_PATH" "$SWIFTPM_MODULECACHE_OVERRIDE"

fail() {
  printf 'Release gate failed: %s\n' "$1" >&2
  if [[ -f "$BUILD_LOG" ]]; then
    tail -n 160 "$BUILD_LOG" >&2
  fi
  exit 1
}

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2>/dev/null
}

printf '1/4 Core contract tests\n'
if ! scripts/swift-test-resigned.sh >"$TEST_LOG" 2>&1; then
  printf 'Core contract tests failed. Relevant output:\n' >&2
  rg -n ' error: | failed at |XCTAssert' "$TEST_LOG" | tail -n 80 >&2 || tail -n 160 "$TEST_LOG" >&2
  exit 1
fi
rg "Test Suite 'All tests' passed|Executed [0-9]+ tests" "$TEST_LOG" | tail -n 3

printf '2/4 Universal iOS build\n'
if ! xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$DERIVED_DATA" \
  COMPILER_INDEX_STORE_ENABLE=NO \
  -allowProvisioningUpdates \
  build >"$BUILD_LOG" 2>&1; then
  fail "xcodebuild did not complete"
fi

[[ -d "$APP" ]] || fail "app bundle is missing at $APP"
[[ -d "$WIDGET" ]] || fail "widget extension is missing at $WIDGET"

printf '3/4 Bundle, widget, iPhone, and iPad contracts\n'
APP_ID="$(plist_value "$APP/Info.plist" CFBundleIdentifier)"
WIDGET_ID="$(plist_value "$WIDGET/Info.plist" CFBundleIdentifier)"
DEVICE_FAMILY="$(plist_value "$APP/Info.plist" UIDeviceFamily)"
EXTENSION_POINT="$(plist_value "$WIDGET/Info.plist" NSExtension:NSExtensionPointIdentifier)"

[[ "$APP_ID" == "$EXPECTED_APP_ID" ]] || fail "unexpected app bundle id: $APP_ID"
[[ "$WIDGET_ID" == "$EXPECTED_WIDGET_ID" ]] || fail "unexpected widget bundle id: $WIDGET_ID"
[[ "$DEVICE_FAMILY" == *"1"* ]] || fail "app bundle does not declare iPhone support"
[[ "$DEVICE_FAMILY" == *"2"* ]] || fail "app bundle does not declare iPad support"
[[ "$EXTENSION_POINT" == "com.apple.widgetkit-extension" ]] || fail "widget extension point is missing"

APP_SIGNING="$(codesign -dvv "$APP" 2>&1 || true)"
WIDGET_SIGNING="$(codesign -dvv "$WIDGET" 2>&1 || true)"
[[ "$APP_SIGNING" == *"TeamIdentifier=3YH7862K4Q"* ]] || fail "app team identifier is missing or wrong"
[[ "$WIDGET_SIGNING" == *"TeamIdentifier=3YH7862K4Q"* ]] || fail "widget team identifier is missing or wrong"

printf '4/4 Optional Rabbit install\n'
if [[ "$INSTALL_ON_DEVICE" == "1" ]]; then
  [[ -n "$DEVICE_ID" ]] || fail "REENCHANTED_INSTALL=1 requires REENCHANTED_DEVICE_ID"
  xcrun devicectl device install app --device "$DEVICE_ID" "$APP"
  xcrun devicectl device process launch --device "$DEVICE_ID" --terminate-existing "$APP_ID"
else
  printf 'Skipped; set REENCHANTED_INSTALL=1 and REENCHANTED_DEVICE_ID to install.\n'
fi

printf 'Release gate passed: core, iPhone, iPad, widget, signing, and bundle identity.\n'
