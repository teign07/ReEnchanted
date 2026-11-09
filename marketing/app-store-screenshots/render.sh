#!/usr/bin/env bash
# Renders App Store screenshot panels from panels.tsv with headless Chrome.
#   panels.tsv columns: out-name <TAB> device(phone|pad) <TAB> raw-shot <TAB> headline <TAB> subline
# Raw shots live in raw/; finished panels land in out/phone and out/pad at
# Apple's exact canvases (1320x2868 and 2064x2752).
set -euo pipefail
cd "$(dirname "$0")"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
mkdir -p out/phone out/pad
urlencode() { python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1]))' "$1"; }
while IFS=$'\t' read -r name device shot head sub; do
  [[ -z "${name:-}" || "${name:0:1}" == "#" ]] && continue
  if [[ "$device" == "pad" ]]; then size="2064,2752"; else size="1320,2868"; fi
  url="file://$PWD/panel.html?device=$device&shot=$(urlencode "$PWD/raw/$shot")&head=$(urlencode "$head")&sub=$(urlencode "${sub:-}")"
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
    --allow-file-access-from-files --virtual-time-budget=8000 \
    --window-size="$size" --screenshot="$PWD/out/$device/$name.png" "$url" >/dev/null 2>&1
  echo "rendered out/$device/$name.png"
done < "${PANELS:-panels.tsv}"
