#!/usr/bin/env python3
"""Render the eight October pencil marks as small transparent, reproducible art."""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "marginalia"
FONT = "/System/Library/Fonts/Supplemental/Bradley Hand Bold.ttf"
INK = (47, 43, 57, 239)
FAINT = (86, 72, 82, 150)
RED = (121, 65, 74, 215)
S = 3

MARKS = {
    "listening-door": ("Some doors have started\nlistening back.", "door"),
    "count-shadows": ("Count names. Count shadows.\nDo both.", "ticks"),
    "complete-sits-down": ("The list is full.\nLook under it.", "roster"),
    "person-not-clue": ("Put the map down.\nAsk Serenity.", "map"),
    "closed-books-loud": ("I heard that one.\nIt's shut.", "book"),
    "three-books": ("Three books want this corridor\nmoved. None will take it.", "three"),
    "invitation-furniture": ("The chair's asking\nwithout a mouth.", "chair"),
    "still-serenity": ("NIGHTBOUND. Serenity's handwriting.\nLeave it that way.", "name"),
}


def path(draw, points, fill=INK, width=3):
    draw.line([(int(x*S), int(y*S)) for x, y in points], fill=fill,
              width=width*S, joint="curve")


def motif(draw, kind):
    if kind == "door":
        path(draw, [(32, 167), (33, 48), (103, 43), (103, 167)], width=3)
        path(draw, [(39, 165), (41, 54), (96, 49), (95, 168)], fill=FAINT, width=2)
        path(draw, [(103, 57), (114, 46), (123, 55), (117, 74), (104, 86)], width=3)
        draw.ellipse((82*S, 103*S, 88*S, 109*S), fill=RED)
        path(draw, [(26, 171), (113, 171)], fill=FAINT, width=2)
    elif kind == "ticks":
        for x, y in [(34, 70), (52, 68), (71, 72), (92, 69)]:
            path(draw, [(x, y), (x-2, y+57)], width=3)
        path(draw, [(24, 88), (102, 108)], fill=FAINT, width=2)
        path(draw, [(123, 103), (121, 156)], fill=RED, width=5)
    elif kind == "roster":
        path(draw, [(31, 53), (103, 49), (110, 143), (35, 147), (31, 53)], width=2)
        for y in (73, 93, 113):
            path(draw, [(42, y), (92, y-2)], fill=FAINT, width=2)
        path(draw, [(88, 141), (108, 123), (111, 147), (89, 147)], fill=RED, width=2)
        path(draw, [(91, 148), (88, 173)], width=3)
        path(draw, [(108, 148), (112, 172)], width=3)
    elif kind == "map":
        path(draw, [(22, 83), (61, 68), (92, 87), (121, 73), (116, 142), (87, 151), (59, 133), (25, 148), (22, 83)], width=2)
        path(draw, [(61, 68), (59, 133)], fill=FAINT, width=2)
        path(draw, [(92, 87), (87, 151)], fill=FAINT, width=2)
        path(draw, [(29, 156), (80, 164), (83, 160)], fill=RED, width=4)
        path(draw, [(83, 160), (91, 165)], fill=FAINT, width=2)
    elif kind == "book":
        path(draw, [(28, 82), (100, 76), (117, 90), (117, 146), (45, 150), (28, 136), (28, 82)], width=3)
        path(draw, [(45, 94), (45, 150)], fill=FAINT, width=2)
        path(draw, [(29, 138), (105, 133), (117, 146)], fill=RED, width=3)
        path(draw, [(27, 159), (119, 155)], fill=FAINT, width=2)
    elif kind == "three":
        for x, y in ((21, 73), (55, 57), (89, 76)):
            path(draw, [(x, y+7), (x+15, y), (x+33, y+7), (x+33, y+46), (x+15, y+39), (x, y+46), (x, y+7)], width=2)
            path(draw, [(x+15, y), (x+15, y+39)], fill=FAINT, width=2)
        path(draw, [(13, 161), (45, 152), (72, 165), (102, 150), (126, 159)], fill=RED, width=3)
    elif kind == "chair":
        path(draw, [(61, 59), (108, 72), (101, 136), (55, 123), (61, 59)], width=3)
        path(draw, [(54, 123), (91, 138), (120, 123)], width=3)
        path(draw, [(62, 129), (54, 175)], width=3)
        path(draw, [(110, 130), (119, 174)], width=3)
        path(draw, [(33, 144), (51, 139)], fill=FAINT, width=2)
    elif kind == "name":
        path(draw, [(25, 75), (119, 75)], fill=FAINT, width=2)
        draw.text((26*S, 85*S), "S", font=ImageFont.truetype(FONT, 64*S), fill=INK)
        path(draw, [(35, 154), (119, 151)], fill=RED, width=2)
        path(draw, [(22, 176), (101, 171)], fill=FAINT, width=2)


def render(name, text, kind):
    image = Image.new("RGBA", (780*S, 220*S), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    motif(draw, kind)
    font_size = 32 if name in ("three-books", "still-serenity") else 37
    font = ImageFont.truetype(FONT, font_size*S)
    for i, line in enumerate(text.split("\n")):
        draw.text((155*S, (60+i*57)*S), line, font=font, fill=INK,
                  stroke_width=0)
    path(draw, [(152, 174), (503, 176), (542, 173)], fill=FAINT, width=1)
    image.resize((780, 220), Image.Resampling.LANCZOS).save(OUT / f"{name}.png", optimize=True)


if __name__ == "__main__":
    OUT.mkdir(exist_ok=True)
    for name, (text, kind) in MARKS.items():
        render(name, text, kind)
    preview = Image.new("RGB", (800, len(MARKS)*250), (236, 226, 205))
    preview_draw = ImageDraw.Draw(preview)
    label_font = ImageFont.truetype(FONT, 13)
    for index, name in enumerate(sorted(MARKS)):
        note = Image.open(OUT / f"{name}.png")
        preview.paste(note, (10, index*250+15), note)
        preview_draw.text((12, index*250+222), name, font=label_font, fill=(86, 72, 82))
    preview.save(ROOT / "marginalia-contact-sheet.png", optimize=True)
