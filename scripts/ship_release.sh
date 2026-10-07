#!/usr/bin/env bash
#
# ship_release.sh — publish the newest signed monthly candidate in one step.
#
#   scripts/ship_release.sh              # newest candidate with no published.json
#   scripts/ship_release.sh CANDIDATE    # a specific candidate directory
#
# It shows what will change, asks for a yes, runs publish_monthly_release.sh
# --publish (assets first, signed manifest last, then reads the live shelf back
# the way an app does), and writes published.json so the next release knows what
# is live. Rollback is `scripts/publish_monthly_release.sh <previous> --publish`.
#
# Needs `npx wrangler` signed in (it is, if the last publish worked). It never
# reads the signing key and never touches the Worker, so a Worker deploy is only
# needed if docs/physical-book-backend changed since the last one.
set -euo pipefail

RELEASES="$HOME/.reenchanted-publishing/releases"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -n "${1:-}" ]]; then
  CANDIDATE="$(cd "$1" && pwd)"
else
  CANDIDATE=""
  while IFS= read -r dir; do
    [[ -f "$dir/manifest.envelope.json" && ! -f "$dir/published.json" ]] && { CANDIDATE="$dir"; break; }
  done < <(ls -dt "$RELEASES"/*/ 2>/dev/null | sed 's:/$::')
  [[ -n "$CANDIDATE" ]] || { echo "No unpublished candidate in $RELEASES." >&2; exit 1; }
fi
[[ -f "$CANDIDATE/published.json" ]] && { echo "$CANDIDATE is already published." >&2; exit 1; }

echo "Candidate: $CANDIDATE"
python3 - "$CANDIDATE" <<'PY'
import json, sys
report = json.load(open(sys.argv[1] + "/release-report.json"))
print(f"  new on the shelf : {', '.join(a['key'].split('/')[-1] for a in report['upload']) or 'nothing'}")
print(f"  already published: {len(report['reuse'])} assets (re-sent harmlessly, same bytes)")
PY
read -r -p "Publish this to every reader now? Type yes: " answer
[[ "$(printf %s "$answer" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')" == "yes" ]] || { echo "Nothing published."; exit 1; }

"$REPO_ROOT/scripts/publish_monthly_release.sh" "$CANDIDATE" --publish

python3 - "$CANDIDATE" <<'PY'
import hashlib, json, sys, datetime, pathlib
c = pathlib.Path(sys.argv[1])
manifest = c / "manifest.json"
report = json.load(open(c / "release-report.json"))
assets = [{"id": a["key"].split("/")[-1], "byteCount": a["byteCount"], "sha256": a["sha256"]}
          for a in report["upload"] + report["reuse"]]
json.dump({
    "verifiedAt": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "liveEnvelopeMatches": True,
    "signatureVerified": True,
    "manifestSHA256": hashlib.sha256(manifest.read_bytes()).hexdigest(),
    "publishedAt": datetime.date.today().isoformat(),
    "assets": assets,
}, open(c / "published.json", "w"), indent=2)
print("Wrote", c / "published.json")
PY
echo
echo "Live. On Rabbit: open ReEnchanted and the new scenes download with the shelf."
