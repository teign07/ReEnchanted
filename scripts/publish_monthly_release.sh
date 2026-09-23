#!/usr/bin/env bash
#
# publish_monthly_release.sh — upload a prepared, signed monthly shelf.
#
# Input is a directory made by prepare_monthly_release.py and then signed with
# sign_monthly_issue_manifest.swift: manifest.json, manifest.envelope.json and
# assets/ASSET_ID. Assets go up first and the signed envelope last, so a reader
# never sees a manifest naming a file that is not there yet. Asset IDs are
# immutable storage keys; changed bytes must carry a new ID.
#
# Usage:
#   scripts/publish_monthly_release.sh RELEASE_DIR            # dry run: list what would upload
#   scripts/publish_monthly_release.sh RELEASE_DIR --publish  # upload, then verify live
#
# The private signing key is never read here and never uploaded.
set -euo pipefail

BUCKET="reenchanted-monthly-issues"
ORIGIN="https://reenchanted-physical-books.snow-potions.workers.dev"
PUBLIC_KEY="qlO/TluW8kH+biDJa+eJoWu6BY7a6WKduKF3LNhCBw4="
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND="$REPO_ROOT/docs/physical-book-backend"

RELEASE="${1:?usage: publish_monthly_release.sh RELEASE_DIR [--publish]}"
PUBLISH=0
[[ "${2:-}" == "--publish" ]] && PUBLISH=1
RELEASE="$(cd "$RELEASE" && pwd)"

[[ -f "$RELEASE/manifest.json" && -f "$RELEASE/manifest.envelope.json" && -d "$RELEASE/assets" ]] ||
  { echo "error: $RELEASE needs manifest.json, manifest.envelope.json and assets/" >&2; exit 1; }
find "$RELEASE" -name "*.key" | grep -q . && { echo "error: a key file is inside the release directory" >&2; exit 1; }

# The envelope must verify against the app's public key and carry exactly the
# manifest bytes, and every declared asset must match its size and digest.
node - "$RELEASE" "$PUBLIC_KEY" <<'EOF'
const { createPublicKey, verify, createHash } = require('crypto');
const fs = require('fs');
const [dir, publicKey] = process.argv.slice(2);
const envelope = JSON.parse(fs.readFileSync(`${dir}/manifest.envelope.json`));
const payload = Buffer.from(envelope.payload, 'base64');
const key = createPublicKey({ format: 'der', type: 'spki',
  key: Buffer.concat([Buffer.from('302a300506032b6570032100', 'hex'), Buffer.from(publicKey, 'base64')]) });
if (!verify(null, payload, key, Buffer.from(envelope.signature, 'base64'))) throw Error('envelope signature does not verify');
if (!payload.equals(fs.readFileSync(`${dir}/manifest.json`))) throw Error('envelope was not signed from this manifest.json');
const manifest = JSON.parse(payload);
for (const issue of manifest.issues) for (const asset of issue.assets) {
  const bytes = fs.readFileSync(`${dir}/assets/${asset.id}`);
  if (bytes.length !== asset.byteCount) throw Error(`${asset.id}: size ${bytes.length} != ${asset.byteCount}`);
  if (createHash('sha256').update(bytes).digest('hex') !== asset.sha256.toLowerCase()) throw Error(`${asset.id}: digest mismatch`);
}
console.log(`Verified envelope (${envelope.keyID}) and ${manifest.issues.reduce((n, i) => n + i.assets.length, 0)} assets.`);
EOF

ASSETS=()
while IFS= read -r id; do ASSETS+=("$id"); done < <(cd "$RELEASE/assets" && ls)
echo "Assets to upload: ${#ASSETS[@]}, then manifest.envelope.json -> r2://$BUCKET"
if [[ $PUBLISH -eq 0 ]]; then
  printf '  %s\n' "${ASSETS[@]}"
  echo "Dry run. Re-run with --publish to upload."
  exit 0
fi

cd "$BACKEND"
for id in "${ASSETS[@]}"; do
  npx wrangler r2 object put "$BUCKET/assets/$id" --file "$RELEASE/assets/$id" \
    --content-type application/octet-stream --remote >/dev/null
  echo "  uploaded assets/$id"
done
npx wrangler r2 object put "$BUCKET/manifest.envelope.json" --file "$RELEASE/manifest.envelope.json" \
  --content-type application/json --remote >/dev/null
echo "  uploaded manifest.envelope.json (last)"

# Read it back the way an app does. The Worker caches verified inventory for
# up to 30 seconds, so wait that out before comparing.
sleep 31
INSTALLATION="publish-check-$(uuidgen)"
json() { python3 -c "import sys,json;print(json.load(sys.stdin)['$1'])"; }
DESK=$(curl -sf -X POST "$ORIGIN/sessions" -H "X-Installation-ID: $INSTALLATION" \
  -H 'Content-Type: application/json' -d '{}' | json token)
SHELF=$(curl -sf -X POST "$ORIGIN/monthly-issues/session" -H "X-Installation-ID: $INSTALLATION" \
  -H "Authorization: Bearer $DESK" -H 'Content-Type: application/json' -d '{"signedTransactions":[]}' | json token)
curl -sf "$ORIGIN/monthly-issues/manifest" -H "X-Installation-ID: $INSTALLATION" \
  -H "Authorization: Bearer $SHELF" | cmp -s - "$RELEASE/manifest.envelope.json" &&
  echo "Live manifest matches the release." ||
  { echo "error: live manifest differs from $RELEASE/manifest.envelope.json" >&2; exit 1; }
