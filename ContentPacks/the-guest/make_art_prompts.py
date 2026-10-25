#!/usr/bin/env python3
"""Writes art-prompts.json: every picture November needs, each prompt complete.

Plates print in the books (docs/monthly-edition-plates.md names them); seasonal
drawings decorate the month's leaves and Pagewright's This Month shelf; marks are
the directed margin notes placed at story beats. Paste each prompt with its
listed reference images. Run: python3 ContentPacks/the-guest/make_art_prompts.py
"""
import json
import os
from pathlib import Path

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = "InsideCoverApp/Assets.xcassets"
GOBLIN = f"{ASSETS}/MarginaliaGoblinWritingCrouched.imageset/MarginaliaGoblinWritingCrouched.png"
PIXIE = f"{ASSETS}/PunctuationPixieFront.imageset/PunctuationPixieFront.png"
KITCHEN = f"{ASSETS}/InterleafUnderTheKitchenTable.imageset/InterleafUnderTheKitchenTable.jpg"


def portrait(name):
    directory = f"{ASSETS}/LabyrinthCharacter{name}.imageset"
    root = Path(HERE).parents[1]
    catalog = json.loads((root / directory / "Contents.json").read_text())
    filename = next(image["filename"] for image in catalog["images"] if image.get("filename"))
    return f"{directory}/{filename}"


CAST = {
    "ambrose": ("Ambrose Trencher (big older cook, grey beard, cap, stained canvas apron, sleeves rolled)", portrait("AmbroseTrencher")),
    "serenity": ("Serenity Brown (young woman, long wild dark curls, sea-green coat, a brass compass on a chain; "
                 "moves slightly sideways, always half-seeing something beyond)", portrait("SerenityBrown")),
    "wicker": ("Wicker Eddies (match his reference portrait exactly)", portrait("WickerEddies")),
    "soren": ("Soren Ng (match his reference portrait exactly)", portrait("SorenNg")),
    "penny": ("Penny Blackletter (young woman, dark curls pinned up, round spectacles, dark waistcoat over a white "
              "blouse with a cravat, ink on her fingers; match her reference portrait exactly)", portrait("PennyBlackletter")),
    "boggle": ("Professor Lydia Boggle (match her reference portrait exactly)", portrait("LydiaBoggle")),
    "vellum": ("Dr. Vellum (match the reference portrait exactly)", portrait("DrElowenVellum")),
    "minseo": ("Min-seo Kim (match her reference portrait exactly)", portrait("MinSeoKim")),
}

GUEST = ("The Guest: a small figure, about elbow-height to a grown man, in a long green coat far too big for it with "
         "tarnished brass buttons and a ragged hem, sleeves rolled up four times, the hood always up so no face shows, "
         "only two very clean small hands; it should feel old, polite and faintly uncanny, never cute and never a monster")

PLATE_STYLE = (
    "Use case: illustration-story. Asset type: a full printed plate for the ReEnchanted Book's November 2026 issue, "
    "The Guest Who Came on All Souls, printed in a 6 by 9 inch book on uncoated book paper inside a white mat and a "
    "thin gold rule. Input images are STYLE AND CHARACTER REFERENCES ONLY: match their exquisite hand-drawn "
    "ink-and-watercolour storybook rendering, irregular fine brown pen contours, fine crosshatching, dense lovingly "
    "observed material detail, warm muted washes on cream paper. November's palette: lamplight amber, copper, oatmeal "
    "and flour white, bread-crust browns, holly green, and a cold frost blue that only appears near the west door and "
    "after dark. An old illustrated faerie book, physical and a little feral, warm but with something wrong at the "
    "edge of it, never childish. A full painted scene with its own background whose edges soften into cream paper in "
    "a gentle vignette. No border, no frame, no lettering, no legible words, no labels, no captions, no watermark, no "
    "speech bubbles; any writing in the scene is illegible pen scribble. Print-safe colour for uncoated paper: no pure "
    "black, no neon, no large flat dark areas; keep shadows open and textured. Characters must match their reference "
    "portraits exactly in face, hair and clothing, drawn as real people with weight and warmth, never caricatures. "
    "The reader of the Book is never shown; at most an anonymous hand at the edge of the picture holding an old "
    "leather-bound book. Avoid flat vector art, clipart, glossy 3D, photorealism, anime, gore and modern objects."
)

CUTOUT_STYLE = (
    "Use case: illustration-story. Asset type: a single transparent November marginalia cutout for the ReEnchanted "
    "living Book. Input images 1 and 2 are STYLE REFERENCES ONLY: match their exquisite hand-drawn ink-and-watercolour "
    "storybook rendering, irregular fine brown pen contours, fine crosshatching, dense lovingly observed material "
    "details, warm muted washes: lamplight amber, copper, bread-crust brown, holly green, a little frost blue. These "
    "are tiny kitchen objects that live beside the existing pixie and goblin; do not include those characters. Render "
    "with the same tactile old illustrated faerie-book quality, physical and a little feral, lively but never childish. "
    "One isolated subject, square composition, subject fills approximately 80 percent of frame, all extremities intact "
    "with clear transparent padding. Real alpha transparency outside the painted object, no background, no parchment "
    "rectangle, no border, no lettering, no labels, no watermark. Avoid flat vector icon art, clipart, glossy 3D, "
    "photorealism and cartoon autumn decorations. Preserve detailed texture while keeping a strong small-scale "
    "silhouette."
)


def plate(file, size, subject, cast=(), guest=False, composition="landscape, 3:2"):
    refs = [KITCHEN, GOBLIN] + [CAST[c][1] for c in cast if CAST[c][1]]
    if guest:
        refs.append(portrait("TheGuest"))
    if len(refs) > 5:
        refs.remove(GOBLIN)  # Keep the scene-style reference and every character.
    present = [CAST[c][0] for c in cast] + ([GUEST] if guest else [])
    prompt = f"{PLATE_STYLE}\nComposition: {composition}.\nSubject: {subject}"
    if present:
        prompt += "\nPresent: " + "; ".join(present) + "."
    return {"file": f"plates/{file}", "size": size, "styleReferences": refs, "prompt": prompt}


def cutout(file, subject, folder="seasonal-marginalia"):
    return {"file": f"{folder}/{file}", "size": "1024x1024", "styleReferences": [GOBLIN, PIXIE],
            "transparentBackground": True, "prompt": f"{CUTOUT_STYLE}\nSubject: {subject}"}


SCENE = "the-guest.scene."
PLATES = [
    plate("frontispiece.png", "1500x2250",
          "The frontispiece of November: the Academy Kitchens at night on All Souls' Eve. A long scrubbed pine table runs "
          "into shadow with forty flat soul cakes cooling on trays, each with a cross cut in the top. Copper pots hang over "
          "a banked red fire. At the far west end a low black studded door stands open on wet November dark, frost on its "
          "step, and a small hooded figure in a too-big green coat waits on the threshold holding out two clean hands. "
          "A sack of onions has been pushed aside from the door. Warm inside, cold outside, a faerie tale about who gets "
          "fed.", ["ambrose"], True, "portrait, 2:3"),
    plate(f"scene.{SCENE}the-knock.png", "2400x1600",
          "The moment the west door opens: the big cook with his shoulder still against the stuck black door, the cold "
          "coming in, and on the step the small hooded stranger in the green coat with brass buttons, hands folded. A tray "
          "of soul cakes behind him on the long table, nutmeg-warm light.", ["ambrose"], True),
    plate(f"scene.{SCENE}three-nights.png", "2400x1600",
          "Bonfire Night in the Academy courtyard: a towering bonfire throwing sparks into the black sky, students in scarves "
          "with their breath showing, trestle tables of dark sticky parkin and amber toffee with a little hammer. At the very "
          "edge of the firelight, where the dark starts, the small hooded figure stands alone holding a square of parkin. "
          "Penny holds an old string-bound cookbook open under a lantern.", ["penny", "ambrose"], True),
    plate(f"scene.{SCENE}flat.png", "2400x1600",
          "Martinmas supper in the Great Hall: long tables, roast goose, red cabbage, crisp potatoes, candles, and every "
          "diner frozen mid-bite with a puzzled face. The small hooded figure with a big water jug leans over one plate "
          "like someone smelling a flower. Near the window a young woman with wild dark curls is laughing out loud.",
          ["serenity"], True),
    plate(f"scene.{SCENE}the-rescue.png", "2400x1600",
          "The Kitchens in joyful chaos: students floury to the elbows, scones, a boy crying over an onion, soda bread, "
          "an older cook in the middle with a wooden spoon. A young man in a dark high collar carries a lopsided omelette "
          "down the whole long table. On the dresser, nine teaspoons each with a tiny taste and a folded numbered paper slip.",
          ["ambrose", "wicker", "soren", "boggle"]),
    plate(f"scene.{SCENE}the-offer.png", "2400x1600",
          "Three in the morning in the Kitchens: one low lamp, frost feathering the inside of the west window, a bowl of "
          "soup on the warm corner of the range. A young woman with wild dark curls sits with her spoon stopped halfway. At "
          "the sink the small hooded figure in the green coat, sleeves rolled four times, has turned from scrubbing a clean "
          "pot to face her. The air near it is faintly blue with cold.", ["serenity"], True),
    plate(f"scene.{SCENE}stir-up-sunday.png", "2400x1600",
          "Stir-up Sunday: a queue of students winding out of the Kitchens and up the stairs, each waiting to stir an "
          "enormous brown earthenware pudding bowl with a long wooden spoon, eyes shut, wishing. The small hooded figure "
          "holds the spoon with both clean hands. In the doorway to the stairs, very still, a tall dark woman in a long "
          "black coat watches and does not come in.", ["ambrose"], True),
    plate(f"scene.{SCENE}a-place-at-the-table.png", "2400x1600",
          "Supper at the long table in the Kitchens: every plate in the building, odd and good, candles stuck in saucers "
          "down the middle, soup, ham, a well of mashed potato, cranberry sauce cut with a knife. At the head of the table "
          "one empty chair with a full plate, a candle and a napkin folded into a little hat. The small hooded figure eats "
          "on a bench halfway down, looking almost at home.", ["ambrose", "penny", "serenity"], True),
    plate(f"scene.{SCENE}the-bowl.png", "2400x1600",
          "The last day of November: a quiet empty kitchen, morning light. On the warm hearth stones by a low stool sits a "
          "plain chipped brown bowl of oats with a gold pool of butter and cold cream round the edge, no spoon. The small "
          "hooded figure kneels before it, hood still up. At the range a big man in an apron stands with his back turned, "
          "washing a pan.", ["ambrose"], True),
    plate("cast.ambrose-trencher.png", "1500x2250",
          "Ambrose Trencher in November: reading a small, very old string-bound cookbook by lamplight at the end of the long "
          "table, one big floury hand flat on a page as if feeling it breathe.", ["ambrose"], composition="portrait, 2:3"),
    plate("cast.serenity-brown.png", "1500x2250",
          "Serenity Brown in November: on the Academy roof in the rain at night, face turned up, tongue just out, laughing, "
          "her map case strapped across her with a paper bird tucked under the strap.", ["serenity"], composition="portrait, 2:3"),
    plate("cast.lydia-boggle.png", "1500x2250",
          "Professor Boggle in November: in the Pantry by candlelight, reading a brown-inked handwritten list pinned inside "
          "the door, flour in her eyebrows, a potato in her other hand.", ["boggle"], composition="portrait, 2:3"),
    plate("cast.dr-vellum.png", "1500x2250",
          "Dr. Vellum in November: weighing a bowl of porridge on a brass kitchen scale in the Still Room, notebook ready, "
          "and an unasked-for cup of tea steaming at the elbow.", ["vellum"], composition="portrait, 2:3"),
    plate("cast.min-seo-kim.png", "1500x2250",
          "Min-seo Kim in November: sitting on the Kitchen floor with her knees up beside a low stool, holding out an apple, "
          "listening; only the hem of a green coat at the edge of the picture.", ["minseo"], composition="portrait, 2:3"),
    plate("the-middlemost-cookery.png", "2400x1600",
          "An old estate-sale cookbook lying open on a scrubbed table, spine held with string, pages foxed and food-stained, "
          "handwritten notes in the margins; on the open page several letters are simply missing from the lines of type, "
          "clean small gaps like missing teeth, and three letters look freshly returned, crisp and black."),
    plate("soul-cakes-cooling.png", "2400x1600",
          "Close and warm: forty flat round soul cakes cooling on old metal trays, each with a cross cut in the top, nutmeg "
          "and currants, steam, a folded tea towel, lamplight."),
    plate("the-west-door.png", "1500x2250",
          "The low black iron-studded west door of the Kitchens at night, its painted-over bolts like knuckles, a sack of "
          "onions slumped beside it, frost on the threshold stone and a thin line of blue cold light underneath.",
          composition="portrait, 2:3"),
    plate("kitchen-law.png", "1500x2250",
          "The inside of a Pantry door: an old handwritten list in faded brown ink pinned up beside hanging herbs and jars, "
          "one later line added in pencil, a candle stub burning on the shelf below. All writing illegible scribble.",
          composition="portrait, 2:3"),
    plate("pots-biggest-to-smallest.png", "2400x1600",
          "A row of scrubbed copper and iron pots hanging over a kitchen range, perfectly ordered biggest to smallest, every "
          "handle pointing the same way, early morning light, nobody in the room."),
    plate("the-cold-kitchen.png", "2400x1600",
          "Through a low doorway, a kitchen with no fire in it: a very long table set for a feast nobody is eating, frost "
          "on the plates, candles burning cold blue, silver bowls very fine. Beautiful and wrong. Seen from the warm side of "
          "the door."),
]

SEASONAL = [
    cutout("soul-cake.png", "A single flat round soul cake with a cross cut into the top, currants and a dusting of nutmeg, slightly cracked edge."),
    cutout("parkin.png", "A sticky dark square of parkin, black treacle and oatmeal, a crumb broken off one corner."),
    cutout("toffee-hammer.png", "A shard of amber bonfire toffee with a tiny brass toffee hammer resting against it."),
    cutout("wooden-spoon.png", "A well-used wooden spoon, scorched on one edge, the bowl stained dark from years of soup."),
    cutout("copper-pot.png", "A small dented copper pot with a long iron handle, polished bright in places."),
    cutout("onion.png", "A golden onion with papery skin peeling back, one root tuft, one tear of moisture on it."),
    cutout("garlic.png", "A plump bulb of garlic in its papery coat, two cloves loose beside it."),
    cutout("half-loaf.png", "Half a round country loaf, cut clean across, crust cracked and floury, the crumb soft."),
    cutout("honey-jar.png", "A small jar of honey with a wooden dipper, a slow gold drip running down the side."),
    cutout("apple-star.png", "An apple cut across the middle showing the five-pointed star of seeds inside, both halves."),
    cutout("brass-button.png", "A tarnished brass coat button with a loop of green thread still through it."),
    cutout("iron-latch.png", "An old black iron door latch with frost on it, painted over many times."),
    cutout("black-thorn.png", "A single long black thorn, very sharp, laid on nothing, faintly glossy."),
    cutout("pudding-cloth.png", "A round Christmas pudding tied up in a knotted cloth, steam rising."),
    cutout("numbered-spoon.png", "A teaspoon holding a single blackcurrant, with a tiny folded paper slip beside it marked with an illegible number."),
    cutout("candle-saucer.png", "A short candle stub stuck in a chipped saucer, a small steady flame."),
    cutout("napkin-hat.png", "A white linen napkin folded into a little hat, standing on its own."),
    cutout("brown-bowl.png", "A plain chipped brown earthenware bowl of oats with a pool of melted butter and cream round the edge, no spoon."),
    cutout("flour-handprint.png", "A small scatter of spilled flour with a thumbprint pressed in it, soft and powdery."),
    cutout("tea-ring.png", "A pale brown tea ring stain, slightly uneven, the shape a mug leaves on paper."),
]

MARKS = [
    cutout("soul-cake-cross.png", "A tiny ink note drawing: a soul cake with its cross, and a little arrow pointing at it as if to say look.", "marginalia"),
    cutout("west-door.png", "A tiny ink sketch of a low studded door, slightly open, three small knock marks drawn beside it.", "marginalia"),
    cutout("scrubbed-pots.png", "A tiny ink sketch of three pots hung biggest to smallest, with small shine lines.", "marginalia"),
    cutout("green-button.png", "A tiny ink and green-wash sketch of a brass button hanging by a thread.", "marginalia"),
    cutout("missing-letter.png", "A tiny ink sketch of a line of handwriting with one letter-shaped gap, circled.", "marginalia"),
    cutout("nine-spoons.png", "A tiny ink sketch of nine teaspoons in a row, the seventh one underlined.", "marginalia"),
    cutout("hearth-bowl.png", "A tiny ink sketch of a bowl set on hearth stones, with three small curls of steam.", "marginalia"),
    cutout("the-thorn.png", "A tiny ink sketch of a single thorn beside a delicate white bowl.", "marginalia"),
]


def main():
    out = {
        "date": "2026-10-19",
        "tool": "Built-in image_gen.imagegen",
        "useCase": "illustration-story",
        "about": "Every picture November 2026 (The Guest Who Came on All Souls) needs. Plates print in the books "
                 "(docs/monthly-edition-plates.md); seasonal drawings are transparent cutouts for the month's leaves "
                 "and Pagewright; marks are the directed margin notes. Each prompt is complete: paste it with the "
                 "listed reference images.",
        "plates": PLATES,
        "seasonal": SEASONAL,
        "marks": MARKS,
    }
    path = os.path.join(HERE, "art-prompts.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print(f"wrote {os.path.relpath(path)}: {len(PLATES)} plates, {len(SEASONAL)} seasonal, {len(MARKS)} marks")


if __name__ == "__main__":
    main()
