#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSET_ROOT="$ROOT/InsideCoverApp/Assets.xcassets"
MANIFEST="$ROOT/docs/rws-temporary-asset-manifest.tsv"
RELEASE_URL="https://github.com/metabismuth/tarot-json/releases/download/v0/cards.zip"
ARCHIVE="${1:-$(mktemp -t reenchanted-rws).zip}"
WORK="$(mktemp -d -t reenchanted-rws)"
DOWNLOADED_ARCHIVE=false

cleanup() {
    rm -rf "$WORK"
    if [[ "$DOWNLOADED_ARCHIVE" == true ]]; then
        rm -f "$ARCHIVE"
    fi
}
trap cleanup EXIT

if [[ ! -s "$ARCHIVE" ]]; then
    DOWNLOADED_ARCHIVE=true
    curl -L --fail --retry 4 --retry-all-errors \
        --user-agent "ReEnchanted/1.0 temporary-RWS-asset-import" \
        --output "$ARCHIVE" "$RELEASE_URL"
fi

unzip -q "$ARCHIVE" -d "$WORK"

card_count="$(find "$WORK" -maxdepth 1 -type f -name '*.jpg' | wc -l | tr -d ' ')"
if [[ "$card_count" != "78" ]]; then
    echo "Expected 78 Rider-Waite-Smith files; archive contained $card_count." >&2
    exit 1
fi

rank_name() {
    case "$1" in
        01) printf 'Ace' ;;
        02|03|04|05|06|07|08|09|10) printf '%s' "$1" ;;
        11) printf 'Page' ;;
        12) printf 'Knight' ;;
        13) printf 'Queen' ;;
        14) printf 'King' ;;
        *) return 1 ;;
    esac
}

major_name() {
    case "$1" in
        00) printf 'Fool' ;;
        01) printf 'Magician' ;;
        02) printf 'HighPriestess' ;;
        03) printf 'Empress' ;;
        04) printf 'Emperor' ;;
        05) printf 'Hierophant' ;;
        06) printf 'Lovers' ;;
        07) printf 'Chariot' ;;
        08) printf 'Strength' ;;
        09) printf 'Hermit' ;;
        10) printf 'WheelOfFortune' ;;
        11) printf 'Justice' ;;
        12) printf 'HangedMan' ;;
        13) printf 'Death' ;;
        14) printf 'Temperance' ;;
        15) printf 'Devil' ;;
        16) printf 'Tower' ;;
        17) printf 'Star' ;;
        18) printf 'Moon' ;;
        19) printf 'Sun' ;;
        20) printf 'Judgement' ;;
        21) printf 'World' ;;
        *) return 1 ;;
    esac
}

asset_name() {
    local filename="$1"
    local family="${filename:0:1}"
    local number="${filename:1:2}"

    case "$family" in
        m) printf 'TarotMajor%s%s' "$number" "$(major_name "$number")" ;;
        c) printf 'TarotCups%s' "$(rank_name "$number")" ;;
        p) printf 'TarotPentacles%s' "$(rank_name "$number")" ;;
        s) printf 'TarotSwords%s' "$(rank_name "$number")" ;;
        w) printf 'TarotWands%s' "$(rank_name "$number")" ;;
        *) return 1 ;;
    esac
}

find "$ASSET_ROOT" -maxdepth 1 -type d -name 'Tarot*.imageset' -exec rm -rf {} +

{
    printf 'asset_name\tarchive_file\tsource_url\tlicense\tartist\tdeck\n'
    while IFS= read -r source; do
        filename="$(basename "$source")"
        name="$(asset_name "$filename")"
        imageset="$ASSET_ROOT/$name.imageset"
        mkdir -p "$imageset"
        cp "$source" "$imageset/card.jpg"
        jq -n '{
            images: [
                {
                    filename: "card.jpg",
                    idiom: "universal",
                    scale: "1x"
                }
            ],
            info: {
                author: "xcode",
                version: 1
            }
        }' > "$imageset/Contents.json"
        printf '%s\t%s\t%s\tPublic domain\tPamela Colman Smith\tRider-Waite-Smith (1910)\n' \
            "$name" "$filename" "$RELEASE_URL"
    done < <(find "$WORK" -maxdepth 1 -type f -name '*.jpg' | sort)
} > "$MANIFEST"

downloaded_count="$(find "$ASSET_ROOT" -maxdepth 1 -type d -name 'Tarot*.imageset' | wc -l | tr -d ' ')"
if [[ "$downloaded_count" != "78" ]]; then
    echo "Expected 78 generated image sets; found $downloaded_count." >&2
    exit 1
fi

echo "Installed 78 temporary public-domain RWS card images."
echo "Asset catalog: $ASSET_ROOT"
echo "Provenance manifest: $MANIFEST"
