#!/usr/bin/env python3
"""Optimize November's generated assets and make review sheets; never generate art.

PNG plates remain native masters. Runtime story copies are JPEGs. Cutouts retain
their complete generated alpha and get transparent breathing room, with originals
preserved in art-masters/. Re-running starts from those originals.
"""

import argparse
from hashlib import sha256
from io import BytesIO
import json
from pathlib import Path
import shutil

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
LIMIT = 2 * 1024 * 1024 - 64 * 1024


def font(size):
    return ImageFont.truetype("/System/Library/Fonts/Supplemental/Georgia.ttf", size)


def jpeg_copy(image, target):
    image = image.convert("RGB")
    # Never invent resolution by upsampling native generated art.
    image.thumbnail((2400, 2400), Image.Resampling.LANCZOS)
    for quality in (94, 90, 86, 82, 78, 74, 70):
        buffer = BytesIO()
        image.save(buffer, format="JPEG", quality=quality, optimize=True, subsampling=0)
        data = buffer.getvalue()
        if len(data) <= LIMIT:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
            return {"quality": quality, "dimensions": list(image.size)}
    raise ValueError(f"{target}: cannot fit below the delivery limit")


def cutout(source):
    master = ROOT / "art-masters" / source.relative_to(ROOT)
    master.parent.mkdir(parents=True, exist_ok=True)
    if not master.exists():
        shutil.copyfile(source, master)
    with Image.open(master) as image:
        if image.mode != "RGBA" or image.getchannel("A").getextrema() != (0, 255):
            raise ValueError(f"{source}: expected genuine generated alpha")
        # Keep every painted pixel, including faint washes. Add room on all sides
        # instead of trying to infer which delicate strokes should be cut off.
        pad = max(24, round(max(image.size) * 0.04))
        padded = Image.new("RGBA", (image.width + pad * 2, image.height + pad * 2))
        padded.paste(image, (pad, pad))
        for edge in (1024, 960, 896, 768):
            exported = padded.copy()
            exported.thumbnail((edge, edge), Image.Resampling.LANCZOS)
            buffer = BytesIO()
            exported.save(buffer, format="PNG", optimize=True, compress_level=9)
            if buffer.tell() <= LIMIT:
                source.write_bytes(buffer.getvalue())
                break
        else:
            raise ValueError(f"{source}: optimized alpha PNG exceeds delivery limit")
        return {"master": str(master.relative_to(ROOT)), "dimensions": list(exported.size),
                "paddingAtNativeSize": pad}


def sheet(name, rows, columns=4):
    width, height = 330, 300 if name == "plates" else 280
    canvas = Image.new("RGB", (columns * width, ((len(rows) + columns - 1) // columns) * height), "#f4eddd")
    draw = ImageDraw.Draw(canvas)
    for index, row in enumerate(rows):
        x, y = index % columns * width, index // columns * height
        with Image.open(ROOT / row["file"]) as original:
            thumb = original.convert("RGBA")
            thumb.thumbnail((width - 24, height - 62), Image.Resampling.LANCZOS)
            canvas.paste(thumb, (x + (width - thumb.width) // 2, y + 8 + (height - 62 - thumb.height) // 2), thumb)
        label = Path(row["file"]).stem.removeprefix("scene.the-guest.scene.")
        draw.text((x + 10, y + height - 47), label, font=font(13), fill="#3b302b")
        delivery_bytes = row.get("publicationBytes", row["bytes"])
        draw.text((x + 10, y + height - 26), f"{row['dimensions'][0]} × {row['dimensions'][1]} · {delivery_bytes//1024} KiB export", font=font(11), fill="#716052")
    target = ROOT / "art-review" / f"{name}-contact-sheet.jpg"
    target.parent.mkdir(exist_ok=True)
    canvas.save(target, quality=91)
    return str(target.relative_to(ROOT))


def prepare(allow_partial=False):
    prompts = json.loads((ROOT / "art-prompts.json").read_text())
    report = {"tool": "Built-in image_gen.imagegen", "assets": [], "missing": [], "reviewSheets": []}
    for group in ("plates", "seasonal", "marks"):
        rows = []
        for brief in prompts[group]:
            source = ROOT / brief["file"]
            if not source.is_file():
                report["missing"].append(brief["file"])
                continue
            row = {"file": brief["file"], "group": group}
            if group != "plates":
                row.update(cutout(source))
            else:
                with Image.open(source) as image:
                    row["dimensions"] = list(image.size)
                    publication = ROOT / "publication-plates" / (source.stem + ".jpg")
                    row["publicationExport"] = str(publication.relative_to(ROOT))
                    row["publicationSettings"] = jpeg_copy(image, publication)
                    row["publicationBytes"] = publication.stat().st_size
                    if source.stem.startswith("scene."):
                        runtime = ROOT / "story-art" / (source.stem + ".jpg")
                        row["runtimeExport"] = str(runtime.relative_to(ROOT))
                        row["runtimeSettings"] = jpeg_copy(image, runtime)
                        row["runtimeBytes"] = runtime.stat().st_size
            row["bytes"] = source.stat().st_size
            row["sha256"] = sha256(source.read_bytes()).hexdigest()
            rows.append(row)
            report["assets"].append(row)
        if rows:
            report["reviewSheets"].append(sheet(group, rows))
    (ROOT / "art-review").mkdir(exist_ok=True)
    (ROOT / "art-review" / "manifest.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f"Prepared {len(report['assets'])}/48 assets; {len(report['missing'])} missing.")
    if report["missing"] and not allow_partial:
        raise ValueError("Art incomplete: " + ", ".join(report["missing"]))
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--allow-partial", action="store_true", help="make an explicitly incomplete work-in-progress review")
    prepare(parser.parse_args().allow_partial)
