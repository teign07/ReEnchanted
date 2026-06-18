#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-/private/tmp/insidecover-module-cache}"
export SWIFTPM_MODULECACHE_OVERRIDE="${SWIFTPM_MODULECACHE_OVERRIDE:-/private/tmp/insidecover-spm-module-cache}"

BUNDLE=".build/arm64-apple-macosx/debug/InsideCoverCorePackageTests.xctest"
XCTEST="/Applications/Xcode.app/Contents/Developer/usr/bin/xctest"
TEST_MODULE="InsideCoverCoreTests"

filter_for() {
  local requested="$1"

  if [[ "$requested" == *"/"* ]]; then
    printf '%s.%s\n' "$TEST_MODULE" "$requested"
    return
  fi

  local test_file="Tests/${TEST_MODULE}/${requested}.swift"
  if [[ ! -f "$test_file" ]]; then
    printf 'No test file found for class filter: %s\n' "$requested" >&2
    printf 'Expected: %s\n' "$test_file" >&2
    exit 2
  fi

  local methods
  methods="$(
    sed -nE 's/^[[:space:]]*func[[:space:]]+(test[A-Za-z0-9_]+)[[:space:]]*\(.*/\1/p' "$test_file"
  )"

  if [[ -z "$methods" ]]; then
    printf 'No XCTest methods found in: %s\n' "$test_file" >&2
    exit 2
  fi

  local joined=""
  local method
  while IFS= read -r method; do
    [[ -z "$method" ]] && continue
    if [[ -n "$joined" ]]; then
      joined+=","
    fi
    joined+="${TEST_MODULE}.${requested}/${method}"
  done <<< "$methods"

  printf '%s\n' "$joined"
}

swift build --build-tests --jobs 1
xattr -dr com.apple.provenance "$BUNDLE" 2>/dev/null || true
codesign --force --sign - "$BUNDLE" >/dev/null

if [[ $# -gt 0 ]]; then
  exec "$XCTEST" -XCTest "$(filter_for "$1")" "$BUNDLE"
fi

exec "$XCTEST" "$BUNDLE"
