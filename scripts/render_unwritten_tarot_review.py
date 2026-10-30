#!/usr/bin/env python3
"""Typeset card-review pages from illustration + exact native annotation data.

This is a document layout proof, not a generated-image edit, app build or
physical print master. The original illustration files are never modified.
"""
import argparse
import json
import os
import subprocess
from pathlib import Path

from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas
from reportlab.lib.colors import HexColor

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "output/imagegen/unwritten-deck-v2"
FONT = "/System/Library/Fonts/Supplemental/Bradley Hand Bold.ttf"


def wrap(text, size, width, font="MarginHand"):
    lines = [""]
    for word in text.split():
        attempt = (lines[-1] + " " + word).strip()
        if lines[-1] and pdfmetrics.stringWidth(attempt, font, size) > width:
            lines.append(word)
        else:
            lines[-1] = attempt
    return lines


def text(c, content, x, top, width, size, rotation, opacity, max_lines, font="MarginHand"):
    base_size = size
    while len(wrap(content, size, width, font)) > max_lines and size > base_size * .75:
        size *= .98
    lines = wrap(content, size, width, font)
    assert len(lines) <= max_lines, content
    c.saveState()
    c.translate(x, top)
    c.rotate(rotation)
    c.setFillColor(HexColor("#413126"))
    c.setFillAlpha(opacity)
    c.setFont(font, size)
    for index, line in enumerate(lines):
        c.drawString(0, -size * (1 + index * 1.2), line)
    c.restoreState()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, default=DEST,
                        help="Production directory containing jobs.json; defaults to the v2 pass")
    parser.add_argument("card_ids", nargs="*")
    args = parser.parse_args()
    dest = args.directory.resolve()
    jobs = json.loads((dest / "jobs.json").read_text())
    if args.card_ids:
        by_id = {job["id"]: job for job in jobs}
        jobs = [by_id[card_id] for card_id in args.card_ids]
    if not jobs:
        raise SystemExit("No revised cards ready for typesetting")
    pdfmetrics.registerFont(TTFont("MarginHand", FONT))
    out = dest / "typeset-review"
    out.mkdir(exist_ok=True)
    page_width, page_height = 490, 840
    inset = page_width * .018
    footer = page_height * .085
    available_width = page_width - 2 * inset
    available_height = page_height - 2 * inset - footer
    plate_width = min(available_width, available_height * 7 / 12)
    plate_height = plate_width * 12 / 7
    plate_x = (page_width - plate_width) / 2
    plate_y = inset + footer + (available_height - plate_height) / 2
    outputs = []
    for job in jobs:
        card_id = job["id"]
        spec = job["specification"]
        layout = spec.get("annotationLayout", {})
        pdf = out / f"{card_id}.pdf"
        c = canvas.Canvas(str(pdf), pagesize=(page_width, page_height))
        c.setTitle(job["name"] + " - ReEnchanted revision review")
        c.setFillColor(HexColor("#f4ecd6"))
        c.rect(0, 0, page_width, page_height, fill=1, stroke=0)
        c.drawImage(job["master"], plate_x, plate_y, width=plate_width,
                    height=plate_height, preserveAspectRatio=True, anchor="c", mask="auto")
        if layout.get("labelOnPaper"):
            c.saveState()
            c.setFillColor(HexColor("#f4ecd6"))
            c.setFillAlpha(.96)
            c.rect(plate_x + plate_width * (layout.get("labelX", .06) - .008),
                   plate_y + plate_height * (1 - layout.get("labelY", .145)) - plate_width * .052,
                   plate_width * (layout.get("labelWidth", .36) + .016), plate_width * .06,
                   stroke=0, fill=1)
            c.restoreState()
        text(c, spec["marginalLabel"], plate_x + plate_width * layout.get("labelX", .06),
             plate_y + plate_height * (1 - layout.get("labelY", .145)), plate_width * layout.get("labelWidth", .36),
             plate_width * layout.get("labelFontWidthRatio", .043),
             layout.get("labelRotation", 3), .78, 1)
        text(c, spec["readingNote"], plate_x + plate_width * layout.get("noteX", .09),
             plate_y + plate_height * (1 - layout.get("noteY", .91)), plate_width * layout.get("noteWidth", .82),
             plate_width * .052, 1, .86, 2)
        for annotation in spec.get("additionalMarginalia", []):
            font = "Times-Roman" if annotation.get("isInscription") else "MarginHand"
            size = plate_width * annotation.get("fontWidthRatio", .034)
            width = plate_width * annotation["width"]
            max_lines = annotation.get("maxLines", 2)
            base_size = size
            while len(wrap(annotation["text"], size, width, font)) > max_lines and size > base_size * .75:
                size *= .98
            lines = wrap(annotation["text"], size, width, font)
            assert len(lines) <= max_lines, annotation["text"]
            x = plate_x + plate_width * annotation["x"]
            top = plate_y + plate_height * (1 - annotation["y"])
            leader = annotation.get("leader", [])
            if leader:
                c.saveState()
                c.setStrokeColor(HexColor("#413126"))
                c.setFillColor(HexColor("#413126"))
                c.setStrokeAlpha(.55)
                c.setFillAlpha(.55)
                c.setLineWidth(.55)
                path = c.beginPath()
                for index, point in enumerate(leader):
                    px = plate_x + plate_width * point[0]
                    py = plate_y + plate_height * (1 - point[1])
                    if index == 0:
                        path.moveTo(px, py)
                    else:
                        path.lineTo(px, py)
                c.drawPath(path)
                c.circle(px, py, .65, stroke=0, fill=1)
                c.restoreState()
            if annotation.get("onPaper"):
                padding = plate_width * .008
                height = size * (1 + (len(lines) - 1) * 1.2) + padding
                c.saveState()
                c.setFillColor(HexColor("#f4ecd6"))
                c.setFillAlpha(.94)
                c.rect(x - padding, top - height, width + padding * 2,
                       height + padding, fill=1, stroke=0)
                c.restoreState()
            text(c, annotation["text"], x, top, width, size,
                 annotation.get("rotation", 2), .78, max_lines, font)
        c.setFillColor(HexColor("#382c22"))
        title = job["name"].replace("—", "·")
        size = page_width * .054
        while pdfmetrics.stringWidth(title, "Times-Bold", size) > available_width - inset * 4:
            size *= .98
        c.setFont("Times-Bold", size)
        c.drawCentredString(page_width / 2, inset + footer / 2 - size / 3, title)
        c.setStrokeColor(HexColor("#96856d"))
        c.setLineWidth(1)
        c.roundRect(inset, inset, available_width, page_height - 2 * inset, 7, fill=0, stroke=1)
        c.showPage()
        c.save()
        font_cache = out / "font-cache"
        font_cache.mkdir(exist_ok=True)
        font_config = out / "fonts.conf"
        font_config.write_text(f'''<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig><dir>/System/Library/Fonts</dir>
<dir>/System/Library/Fonts/Supplemental</dir>
<cachedir>{font_cache}</cachedir></fontconfig>''')
        result = subprocess.run(["pdftoppm", "-singlefile", "-scale-to", "1680", "-png", str(pdf), str(out / card_id)],
                                env=dict(os.environ, FONTCONFIG_FILE=str(font_config)), capture_output=True)
        (out / f"{card_id}.render.log").write_bytes(result.stderr)
        result.check_returncode()
        outputs.append(str(out / f"{card_id}.png"))
    print(json.dumps(dict(typesetCards=len(outputs), previews=outputs)))


if __name__ == "__main__":
    main()
