#!/usr/bin/env python3
"""Prepare reproducible, individually generated Unwritten Deck art jobs."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "output/imagegen/unwritten-deck-v1"
RANKS = ["ace", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "page", "knight", "queen", "king"]
MAJORS = ["Fool", "Magician", "HighPriestess", "Empress", "Emperor", "Hierophant", "Lovers", "Chariot", "Strength", "Hermit", "WheelOfFortune", "Justice", "HangedMan", "Death", "Temperance", "Devil", "Tower", "Star", "Moon", "Sun", "Judgement", "World"]
STYLE = """Use case: illustration-story. Asset type: one finished ReEnchanted tarot illustration plate, The Unwritten Deck, compatible with Pamela Colman Smith's Rider-Waite-Smith visual system.
Input image roles: the original RWS card is the COMPOSITION AND SYMBOL reference; Penny Blackletter and Under the Kitchen Table are HOUSE MEDIUM references, not characters to copy. Any accepted Unwritten Deck card is the DECK STYLE reference. Keep the symbolic tableau immediately readable, with the unmistakable physical ink-and-watercolour rendering of the house references.
Style: a physically handled illustrated faerie book, a little feral and never childish. Expressive believable human beings, weight and warmth, fine irregular brown-black pen contours, delicate crosshatching and faint graphite, translucent watercolor blooms and tide marks, cream rag paper and occasional layered paper fragments. A real scene remembered in ink, not glossy fantasy art or a literal photographic collage. Open textured shadows; luminous paper; small jewel-color accents. Human faces, hands and object relationships must be clear and plausible. Varied ages and appearances across the deck. Archetypal unnamed figures, not the established cast.
Composition: portrait 7:12, ideally 1120 by 1920 pixels. The central scene occupies approximately 85 percent of the image and remains readable when small. A few fine observational sketches or related paper traces inhabit the outer edges, leaving the main scene uncluttered. Each marginal mark must relate to THIS card. Keep every required symbolic object away from the outer 5 percent crop-safe edge. No rectangular picture frame, no thick dossier margins, no preprinted card frame. Cream parchment, not an all-over muddy brown filter or burnt-edge template.
No readable text, titles, numerals, labels, lessons, captions, letters, watermark, logo or branding anywhere. The app typesets names. No extra copies of the suit objects in the marginalia: exact symbol counts matter. No magical wand casting, neon, airbrush, anime, plastic faces, gore, random stars or arbitrary decorative clutter. Preserve difficulty and ambiguity; do not turn every scene into comfort.
"""

def jobs():
    source = (ROOT / "docs/tarot-pages-and-unwritten-deck-design.md").read_text()
    rows = re.findall(r"^\| `([^`]+)` \| ([^|]+) \| ([^|]+) \| ([^|]+) \|$", source, re.M)
    result = []
    for authored_id, name, meaning, scene in rows:
        if authored_id.startswith("major-"):
            n = int(authored_id.split("-")[1])
            card_id = f"major-{n:02}"
            asset = f"TarotMajor{n:02}{MAJORS[n]}"
        else:
            suit, rank = authored_id.split("-")
            if rank.isdigit():
                n = int(rank)
                card_id = f"{suit}-{RANKS[n-1]}"
                suffix = f"{n:02}"
            else:
                card_id = authored_id
                suffix = rank.capitalize()
            asset = f"Tarot{suit.capitalize()}{suffix}"
        extra = ""
        if card_id == "major-00":
            extra = "Keep the earlier Fool's impossible library precipice idea: a narrow stone Stacks landing opening into a luminous drop, sunlit pale distant shelves; the human, white dog, white rose, small shoulder bundle and escaping blank page read first. Deep blue coat, unguarded upward gaze, stepping foot at the brink. Limit the library detail near the silhouette. One small margin study of the tugging dog, no extra full dog in the scene."
        palette = {"cups": "sea-glass green and tidal blue", "pentacles": "moss green and muted silver", "swords": "cool sky grey and warm brass", "wands": "ember red and restrained gold"}.get(card_id.split("-")[0], "restrained jewel color appropriate to the scene")
        prompt = STYLE + f"\nCard: {name.strip()}. Emotional structure: {meaning.strip()}.\nREQUIRED SCENE AND SYMBOLS: {scene.strip()}\n{extra}\nPalette accents: {palette}; most of the plate remains cream paper, ink and transparent washes. Deliver this ONE card only, no contact sheet or mockup."
        result.append({"id": card_id, "authoredID": authored_id, "name": name.strip(), "assetName": asset, "requiredScene": scene.strip(), "prompt": prompt, "master": str(DEST / "masters" / f"{card_id}.png"), "promptFile": str(DEST / "prompts" / f"{card_id}.txt"), "compositionReference": str(ROOT / "InsideCoverApp/Assets.xcassets" / f"{asset}.imageset/card.jpg")})
    assert len(result) == 78 and len({j["id"] for j in result}) == 78
    return result

if __name__ == "__main__":
    DEST.mkdir(parents=True, exist_ok=True)
    (DEST / "prompts").mkdir(exist_ok=True)
    records = jobs()
    for job in records:
        Path(job["promptFile"]).write_text(job["prompt"])
    (DEST / "jobs.json").write_text(json.dumps(records, indent=2) + "\n")
    print(f"Prepared {len(records)} individual card jobs at {DEST}")
