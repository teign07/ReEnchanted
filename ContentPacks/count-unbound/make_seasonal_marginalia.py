#!/usr/bin/env python3
"""Draw the October cabinet's twenty small transparent ink-and-wash marks."""

from pathlib import Path
import json
from math import cos, sin, pi
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "seasonal-marginalia"
S = 3
INK = (46, 39, 51, 242)
RUST = (150, 68, 42, 220)
GOLD = (182, 128, 52, 215)
MOSS = (73, 89, 60, 205)
PLUM = (84, 61, 91, 205)
PALE = (195, 154, 108, 95)


def p(points):
    return [(round(x * S), round(y * S)) for x, y in points]


def line(d, points, color=INK, width=3):
    d.line(p(points), fill=color, width=width * S, joint="curve")


def polygon(d, points, fill, outline=INK, width=3):
    d.polygon(p(points), fill=fill)
    d.line(p(points + [points[0]]), fill=outline, width=width * S, joint="curve")


def ellipse(d, box, fill=None, outline=INK, width=3):
    d.ellipse(tuple(round(v * S) for v in box), fill=fill,
              outline=outline, width=width * S)


def arc(d, box, start, end, color=INK, width=3):
    d.arc(tuple(round(v * S) for v in box), start, end,
          fill=color, width=width * S)


def bat(d):
    polygon(d, [(111,91),(91,73),(62,72),(44,91),(29,85),(38,120),(57,109),
                (75,126),(94,114),(109,125),(127,113),(146,127),(163,108),
                (184,120),(193,84),(177,91),(160,72),(131,73)], PLUM)
    polygon(d, [(102,92),(99,68),(110,80),(121,68),(118,92)], INK)
    ellipse(d, (104,100,108,104), GOLD, None)
    ellipse(d, (115,100,119,104), GOLD, None)


def black_cat(d):
    polygon(d, [(64,87),(65,48),(88,69),(112,59),(137,69),(160,47),
                (160,93),(151,118),(127,129),(92,126)], INK)
    ellipse(d, (72,108,153,187), INK, None)
    arc(d, (119,111,209,193), 12, 285, INK, 9)
    ellipse(d, (91,93,103,100), GOLD, None)
    ellipse(d, (126,93,138,100), GOLD, None)
    line(d, [(115,105),(111,114),(119,114)], RUST, 2)
    line(d, [(111,116),(90,113)], PALE, 2)
    line(d, [(119,116),(141,112)], PALE, 2)


def witch_hat(d):
    polygon(d, [(46,151),(85,130),(117,34),(138,112),(173,145)], PLUM)
    polygon(d, [(72,140),(84,129),(157,132),(170,145)], INK)
    polygon(d, [(101,93),(136,101),(144,116),(93,108)], GOLD, None)
    ellipse(d, (112,99,125,111), RUST, None)
    arc(d, (28,140,197,175), 0, 178, INK, 4)


def pumpkin(d, face=False):
    ellipse(d, (43,76,178,171), RUST)
    arc(d, (63,76,119,170), 72, 290, INK, 3)
    arc(d, (100,76,154,170), 250, 108, INK, 3)
    line(d, [(110,78),(116,53),(130,51)], MOSS, 6)
    arc(d, (126,48,156,75), 120, 340, MOSS, 3)
    if face:
        polygon(d, [(72,112),(87,104),(86,122)], INK, None)
        polygon(d, [(136,105),(150,115),(134,122)], INK, None)
        polygon(d, [(82,140),(104,148),(132,143),(147,136),(137,152),(92,157)], INK, None)


def lantern(d):
    polygon(d, [(80,66),(141,66),(158,91),(152,161),(67,161),(62,91)], GOLD)
    polygon(d, [(88,83),(132,83),(141,98),(136,145),(83,145),(78,98)], PALE)
    line(d, [(110,89),(110,139)], RUST, 4)
    polygon(d, [(110,91),(99,120),(111,115),(122,122)], RUST, None)
    arc(d, (84,35,136,85), 180, 360, INK, 4)
    line(d, [(63,161),(157,161)], INK, 5)


def broom(d):
    line(d, [(67,39),(126,139)], MOSS, 7)
    polygon(d, [(111,130),(141,121),(171,179),(147,176),(137,187),(130,175),(110,181)], GOLD)
    line(d, [(116,142),(145,135)], RUST, 3)
    for x in (126,139,152): line(d, [(x,148),(x+10,174)], INK, 2)


def cauldron(d):
    ellipse(d, (53,78,168,106), PLUM)
    polygon(d, [(53,91),(67,157),(149,157),(168,91)], INK)
    arc(d, (55,88,165,169), 5, 174, GOLD, 3)
    line(d, [(76,157),(70,174)], INK, 6)
    line(d, [(144,157),(151,174)], INK, 6)
    for x,y,r in [(87,66,7),(115,53,9),(141,70,5)]: ellipse(d,(x-r,y-r,x+r,y+r),None,MOSS,2)


def web(d):
    center=(111,115)
    for a in (0,45,90,135,180,225,270,315):
        t=a*pi/180
        line(d,[center,(111+82*cos(t),115+82*sin(t))],INK,2)
    for r in (27,51,75):
        pts=[(111+r*cos(a*pi/180),115+r*sin(a*pi/180)) for a in range(0,361,45)]
        line(d,pts,PLUM,2)
    ellipse(d,(105,109,117,121),INK,None)


def candle(d):
    polygon(d,[(87,82),(133,82),(129,174),(91,174)],PALE)
    for x,y in [(96,114),(121,135)]: line(d,[(x,y),(x,y+20)],RUST,3)
    line(d,[(110,82),(110,67)],INK,3)
    polygon(d,[(110,42),(102,61),(110,75),(119,61)],GOLD)
    ellipse(d,(64,169,155,178),MOSS,None)


def old_key(d):
    ellipse(d,(37,54,100,117),None,GOLD,8)
    ellipse(d,(55,72,82,99),None,INK,3)
    line(d,[(89,105),(169,176)],INK,9)
    line(d,[(145,154),(157,137)],INK,8)
    line(d,[(158,166),(173,150)],INK,8)


def crow(d):
    polygon(d,[(70,130),(60,91),(84,67),(126,72),(147,85),(170,82),
               (151,99),(151,143),(129,159),(104,145)],INK)
    polygon(d,[(93,113),(39,139),(62,149),(113,140)],PLUM)
    line(d,[(114,149),(104,183)],INK,4)
    line(d,[(139,146),(149,183)],INK,4)
    ellipse(d,(126,87,134,95),GOLD,None)


def moth(d):
    polygon(d,[(108,103),(54,60),(36,83),(49,131),(99,124)],PALE)
    polygon(d,[(114,103),(168,60),(186,83),(173,131),(123,124)],PALE)
    polygon(d,[(100,117),(61,129),(71,162),(106,142)],PLUM)
    polygon(d,[(122,117),(161,129),(151,162),(116,142)],PLUM)
    ellipse(d,(102,83,121,156),INK,None)
    ellipse(d,(61,86,78,103),RUST,None)
    ellipse(d,(145,86,162,103),RUST,None)
    line(d,[(107,87),(92,62)],INK,3)
    line(d,[(117,87),(133,62)],INK,3)


def moon(d):
    ellipse(d,(58,45,161,155),GOLD)
    ellipse(d,(91,30,180,134),(0,0,0,0),None)
    for x,y,r in [(53,87,3),(164,65,3),(139,173,4),(74,167,2)]:
        line(d,[(x-r,y),(x+r,y)],INK,2)
        line(d,[(x,y-r),(x,y+r)],INK,2)


def oak_leaf(d):
    polygon(d,[(111,34),(91,57),(74,55),(65,76),(79,89),(54,100),(63,122),
               (87,122),(80,146),(101,157),(112,144),(125,159),(148,143),
               (140,121),(161,120),(168,100),(144,88),(156,72),(135,58)],MOSS)
    line(d,[(111,48),(112,182)],INK,3)
    for y,x in [(83,79),(108,65),(134,90)]: line(d,[(111,y+13),(x,y)],INK,2)
    for y,x in [(83,145),(108,157),(134,137)]: line(d,[(112,y+13),(x,y)],INK,2)


def maple_leaf(d):
    polygon(d,[(111,35),(99,66),(80,53),(83,80),(45,72),(63,99),(50,112),
               (89,130),(80,158),(107,145),(111,183),(117,145),(145,158),
               (135,130),(173,112),(160,98),(178,72),(139,80),(143,53),(122,66)],RUST)
    line(d,[(111,64),(113,183)],INK,3)


def acorn(d):
    ellipse(d,(79,80,145,171),GOLD)
    polygon(d,[(71,92),(84,65),(136,65),(153,93),(141,106),(80,106)],MOSS)
    for x in (85,105,125,143): line(d,[(x,80),(x+5,93)],INK,2)
    line(d,[(110,66),(115,46),(135,41)],INK,3)


def apple(d):
    ellipse(d,(51,77,169,169),RUST)
    arc(d,(70,74,152,166),110,260,INK,3)
    line(d,[(112,80),(114,48)],INK,4)
    polygon(d,[(116,55),(145,44),(158,55),(136,72)],MOSS)


def mushroom(d):
    polygon(d,[(89,104),(131,104),(138,167),(84,167)],PALE)
    polygon(d,[(48,112),(60,82),(83,62),(111,55),(139,61),(163,80),(176,112)],RUST)
    line(d,[(48,112),(176,112)],INK,4)
    for x,y,r in [(83,83,7),(117,75,8),(148,91,5)]: ellipse(d,(x-r,y-r,x+r,y+r),PALE,None)
    line(d,[(66,171),(157,171)],MOSS,3)


def wheat(d):
    line(d,[(100,182),(118,49)],MOSS,4)
    line(d,[(131,182),(113,69)],MOSS,3)
    for i in range(7):
        y=60+i*14
        ellipse(d,(106-i*2,y,121-i*2,y+12),GOLD,None)
        ellipse(d,(120-i*2,y+2,135-i*2,y+14),GOLD,None)
    line(d,[(92,143),(132,148)],RUST,3)


def marigold(d):
    for i in range(12):
        a=2*pi*i/12
        x=111+27*cos(a); y=99+27*sin(a)
        ellipse(d,(x-18,y-18,x+18,y+18),GOLD,RUST,2)
    ellipse(d,(91,79,131,119),RUST,INK,2)
    line(d,[(111,120),(111,180)],MOSS,5)
    polygon(d,[(110,151),(82,135),(72,141),(100,163)],MOSS,None)
    polygon(d,[(112,163),(137,137),(150,143),(120,173)],MOSS,None)


MARKS = {
    "bat-in-flight": bat,
    "black-cat": black_cat,
    "witch-hat": witch_hat,
    "harvest-pumpkin": pumpkin,
    "jack-o-lantern": lambda d: pumpkin(d, True),
    "lantern": lantern,
    "broom": broom,
    "cauldron": cauldron,
    "spiderweb": web,
    "candle": candle,
    "old-key": old_key,
    "crow": crow,
    "night-moth": moth,
    "crescent-moon": moon,
    "oak-leaf": oak_leaf,
    "maple-leaf": maple_leaf,
    "acorn": acorn,
    "apple": apple,
    "mushroom": mushroom,
    "marigold": marigold,
}

# Subject words are deliberately distinct: they help a mark find a fitting
# leaf without turning every October Page into the same pumpkin border.
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


def main():
    OUT.mkdir(exist_ok=True)
    sheet = Image.new("RGBA", (5 * 240, 4 * 270), (245, 237, 220, 255))
    draw_sheet = ImageDraw.Draw(sheet)
    font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Georgia.ttf", 16)
    for index, (name, render) in enumerate(MARKS.items()):
        image = Image.new("RGBA", (220 * S, 220 * S), (0, 0, 0, 0))
        render(ImageDraw.Draw(image))
        image = image.resize((220, 220), Image.Resampling.LANCZOS)
        image.save(OUT / f"{name}.png", optimize=True)
        x, y = (index % 5) * 240, (index // 5) * 270
        sheet.alpha_composite(image, (x + 10, y + 5))
        draw_sheet.text((x + 13, y + 228), name.replace("-", " "), font=font, fill=INK)
    sheet.convert("RGB").save(ROOT / "seasonal-marginalia-contact-sheet.jpg", quality=85)

    pack_path = ROOT / "margins.reenchantedpack.json"
    pack = json.loads(pack_path.read_text())
    pack["version"] = 2
    margins = pack["marginaliaPack"]
    margins["displayName"] = "October 2026 · The Count Unbound"
    margins["version"] = "1.1"
    margins["doodles"] = [asset for asset in margins["doodles"]
                          if not asset["id"].startswith("october_2026_")]
    for name in MARKS:
        role, subjects, generic = SUBJECTS[name]
        margins["doodles"].append({
            "id": "october_2026_" + name.replace("-", "_"),
            "assetName": "{{asset-path:count-unbound.seasonal." + name + "}}",
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
