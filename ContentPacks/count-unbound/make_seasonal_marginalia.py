#!/usr/bin/env python3
"""Validate generated October art, refresh its review sheet and cabinet metadata.

The twenty PNGs are authored with built-in image generation; this script never
redraws or overwrites them. Exact prompts live in seasonal-art-prompts.json.
Only review-sheet thumbnails are resized; the original alpha and pixels stay intact.
"""

from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "seasonal-marginalia"
INK = (46, 39, 51, 242)

SUBJECTS = {
    "bat-in-flight": ("ornament", ["bat", "night", "halloween", "flight"], True),
    "black-cat": ("scribble", ["cat", "familiar", "creature", "halloween"], True),
    "witch-hat": ("ornament", ["witch", "hat", "halloween", "magic"], True),
    "harvest-pumpkin": ("botanical", ["pumpkin", "harvest", "autumn"], True),
    "jack-o-lantern": ("ornament", ["pumpkin", "lantern", "halloween"], False),
    "lantern": ("sigil", ["lantern", "light", "threshold", "night"], True),
    "broom": ("scribble", ["broom", "witch", "halloween"], False),
    "cauldron": ("ornament", ["cauldron", "witch", "halloween"], False),
    "spiderweb": ("ornament", ["web", "spider", "halloween"], False),
    "candle": ("sigil", ["candle", "remembrance", "samhain", "light"], True),
    "old-key": ("sigil", ["key", "door", "threshold", "samhain"], False),
    "crow": ("scribble", ["crow", "bird", "night", "autumn"], False),
    "night-moth": ("botanical", ["moth", "night", "creature", "autumn"], False),
    "crescent-moon": ("ornament", ["moon", "night", "halloween"], False),
    "oak-leaf": ("botanical", ["oak", "leaf", "autumn"], False),
    "maple-leaf": ("botanical", ["maple", "leaf", "fall", "autumn"], False),
    "acorn": ("botanical", ["acorn", "oak", "seed", "autumn"], False),
    "apple": ("botanical", ["apple", "harvest", "samhain"], False),
    "mushroom": ("botanical", ["mushroom", "toadstool", "autumn"], False),
    "marigold": ("botanical", ["marigold", "flower", "remembrance", "samhain"], False),
}


MARKS = tuple(SUBJECTS)


def main():
    OUT.mkdir(exist_ok=True)
    sheet = Image.new("RGBA", (5 * 240, 4 * 270), (245, 237, 220, 255))
    draw_sheet = ImageDraw.Draw(sheet)
    font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Georgia.ttf", 16)
    for index, name in enumerate(MARKS):
        source = OUT / f"{name}.png"
        with Image.open(source) as original:
            if original.mode != "RGBA" or original.getchannel("A").getextrema()[0] != 0:
                raise ValueError(f"{source}: expected generated RGBA art with transparent background")
            image = original.copy()
        image.thumbnail((220, 220), Image.Resampling.LANCZOS)
        x, y = (index % 5) * 240, (index // 5) * 270
        sheet.alpha_composite(image, (x + (240-image.width)//2, y + 5 + (220-image.height)//2))
        draw_sheet.text((x + 13, y + 228), name.replace("-", " "), font=font, fill=INK)
    sheet.convert("RGB").save(ROOT / "seasonal-marginalia-contact-sheet.jpg", quality=85)

    pack_path = ROOT / "margins.reenchantedpack.json"
    pack = json.loads(pack_path.read_text())
    pack["version"] = 2
    margins = pack["marginaliaPack"]
    margins["displayName"] = "October 2026 · The Count Unbound"
    margins["version"] = "1.2"
    margins["doodles"] = [asset for asset in margins["doodles"]
                          if not asset["id"].startswith("october_2026_")]
    for name in MARKS:
        role, subjects, generic = SUBJECTS[name]
        margins["doodles"].append({
            "id": "october_2026_" + name.replace("-", "_"),
            "assetName": "{{asset-path:count-unbound.seasonal.v2." + name + "}}",
            "kind": "doodle",
            "tags": ["monthly-content", "october-2026", "autumn"]
                    + (["generic"] if generic else []) + subjects,
            "supportedTemplates": margins["supportedTemplates"],
            "defaultOpacity": 0.96,
            "canTint": False,
            "placementTrigger": {"months": [10], "issueYear": 2026},
            "leafTraits": {
                "semanticRole": role,
                "aspectRatio": 1.0,
                "preferredAnchors": ["middleLeading", "lowerLeading", "lowerField"],
                "blend": "normal",
                "visualWeight": 0.93,
                "allowsTextOverlap": False,
                "tintStrength": 0.0,
                "subjectTags": subjects,
            },
        })
    pack_path.write_text(json.dumps(pack, indent=2, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
