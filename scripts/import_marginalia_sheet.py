#!/usr/bin/env python3
"""Cut authored marginalia sheets into losslessly optimized Xcode image sets.

The source art is never redrawn. Each entry names seed points belonging to the
painted object; connected-component masks keep overlapping neighboring studies,
captions, and scale guides out of the crop while retaining the original alpha
fringe around the selected paint.
"""

from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw


@dataclass(frozen=True)
class Cut:
    asset_name: str
    seeds: tuple[tuple[int, int], ...]


SHEETS: dict[str, tuple[Cut, ...]] = {
    "punctuation-pixie": (
        Cut("PunctuationPixieFront", ((180, 250), (85, 340), (275, 355))),
        Cut("PunctuationPixieProfile", ((470, 250),)),
        Cut("PunctuationPixieBack", ((800, 250),)),
        Cut("PunctuationPixieInFlight", ((1200, 250), (1422, 216), (1398, 250))),
        Cut("PunctuationPixieFaceBright", ((125, 590),)),
        Cut("PunctuationPixieFaceWink", ((315, 590),)),
        Cut("PunctuationPixieFaceSurprised", ((500, 590),)),
        Cut("PunctuationPixieFaceLaughing", ((120, 780),)),
        Cut("PunctuationPixieFaceCross", ((310, 790),)),
        Cut("PunctuationPixieFaceThinking", ((500, 790),)),
        Cut("PunctuationPixieWingsOpen", ((750, 650),)),
        Cut("PunctuationPixieWingProfile", ((970, 650),)),
        Cut("PunctuationPixieWingsFolded", ((1080, 650),)),
        Cut("PunctuationPixieQuillHand", ((1190, 700), (1132, 825))),
        Cut("PunctuationPixieNotesBoot", ((1360, 650),)),
        Cut("PunctuationPixieSatchel", ((950, 930),)),
        Cut("PunctuationPixieWingsSmallOpen", ((1130, 950),)),
        Cut("PunctuationPixieWingsSmallFolded", ((1245, 950),)),
        Cut("PunctuationPixieInkBottle", ((90, 980),)),
        Cut("PunctuationCharmComma", ((200, 950),)),
        Cut("PunctuationCharmSemicolon", ((275, 950), (275, 1020))),
        Cut("PunctuationCharmQuestion", ((340, 960), (340, 1020))),
        Cut("PunctuationCharmExclamation", ((407, 960),)),
        Cut("PunctuationCharmAmethyst", ((475, 950),)),
        Cut("PunctuationCharmQuotationMedallion", ((550, 960),)),
        Cut("PunctuationCharmNoteScroll", ((635, 960),)),
        Cut("PunctuationCharmQuotationBook", ((715, 960),)),
        Cut("PunctuationCharmFeather", ((790, 960),)),
    ),
    "marginalia-goblins": (
        Cut("MarginaliaGoblinQuillStanding", ((170, 170),)),
        Cut("MarginaliaGoblinWritingCrouched", ((430, 200),)),
        Cut("MarginaliaGoblinShushing", ((690, 180),)),
        Cut("MarginaliaGoblinQuestioning", ((1020, 180),)),
        Cut("MarginaliaGoblinPageHiding", ((1300, 180),)),
        Cut("MarginaliaGoblinInkCarrier", ((150, 480),)),
        Cut("MarginaliaGoblinReading", ((450, 500),)),
        Cut("MarginaliaGoblinSleeping", ((730, 500), (790, 380), (765, 395))),
        Cut("MarginaliaGoblinFaceGrinning", ((1050, 420),)),
        Cut("MarginaliaGoblinFaceCross", ((1300, 420),)),
        Cut("MarginaliaGoblinFaceSkeptical", ((1010, 560),)),
        Cut("MarginaliaGoblinFaceLaughing", ((1200, 560),)),
        Cut("MarginaliaGoblinFaceSleepy", ((1360, 560),)),
        Cut("MarginaliaGoblinHand", ((100, 700),)),
        Cut("MarginaliaGoblinNoseRound", ((270, 700),)),
        Cut("MarginaliaGoblinNoseLong", ((380, 700),)),
        Cut("MarginaliaGoblinNoseSnub", ((500, 700),)),
        Cut("MarginaliaGoblinEarNarrow", ((630, 700),)),
        Cut("MarginaliaGoblinEarWide", ((760, 700),)),
        Cut("MarginaliaGoblinEarHooped", ((900, 700),)),
        Cut("MarginaliaGoblinBareFoot", ((1040, 700),)),
        Cut("MarginaliaGoblinBrownBoot", ((1200, 700),)),
        Cut("MarginaliaGoblinBlueFoot", ((1360, 700),)),
        Cut("MarginaliaGoblinQuill", ((100, 850), (50, 970))),
        Cut("MarginaliaGoblinBlueInk", ((260, 850),)),
        Cut("MarginaliaGoblinGreenInk", ((410, 850),)),
        Cut("MarginaliaGoblinSealedNote", ((520, 850),)),
        Cut("MarginaliaGoblinCrownedNote", ((635, 850),)),
        Cut("MarginaliaGoblinCrumpledNote", ((730, 850),)),
        Cut("MarginaliaGoblinTiedScroll", ((820, 850),)),
        Cut("MarginaliaGoblinRoyalWaxSeal", ((925, 850),)),
        Cut("MarginaliaGoblinRedRibbon", ((1100, 840),)),
        Cut("MarginaliaGoblinSatchel", ((1320, 930),)),
        Cut("MarginaliaGoblinOpenBook", ((180, 1000),)),
        Cut("MarginaliaGoblinIlluminatedScroll", ((500, 990),)),
        Cut("MarginaliaGoblinCornerFlourish", ((750, 980),)),
        Cut("MarginaliaGoblinComma", ((920, 1010),)),
        Cut("MarginaliaGoblinQuestion", ((1015, 970), (1007, 1045))),
        Cut("MarginaliaGoblinExclamation", ((1115, 970), (1112, 1050))),
    ),
    "academy-notes-one": (
        Cut("AcademyNoteTurnPageBackward", ((100, 80),)),
        Cut("AcademyNoteBookNoticesFirst", ((350, 80),)),
        Cut("AcademyNoteGoblinMarketNewMoon", ((620, 80),)),
        Cut("AcademyNoteShakeTheBook", ((900, 80),)),
        Cut("AcademyNoteDoubleTapIllustration", ((1140, 80),)),
        Cut("AcademyNoteGlowIsBelief", ((1400, 80),)),
        Cut("AcademyNoteLostPage", ((110, 260),)),
        Cut("AcademyNoteWriteToCharacter", ((380, 250),)),
        Cut("AcademyNoteMarginsAlive", ((630, 250),)),
        Cut("AcademyNoteMomortLaughter", ((900, 250),)),
        Cut("AcademyNoteFrogsKnowWeather", ((1140, 250),)),
        Cut("AcademyNoteHoldYourWords", ((1400, 250),)),
        Cut("AcademyNoteLeafGrowsThings", ((120, 430),)),
        Cut("AcademyNoteSayNo", ((380, 420),)),
        Cut("AcademyNotePagesChangeAtNight", ((630, 420),)),
        Cut("AcademyNoteSecretInPhoto", ((870, 430),)),
        Cut("AcademyNoteBindDayDifferently", ((1110, 430),)),
        Cut("AcademyNoteBookMisbehaves", ((1290, 430),)),
        Cut("AcademyNoteBookCanBeWrong", ((1450, 430),)),
        Cut("AcademyNoteMapChangesWalking", ((110, 600),)),
        Cut("AcademyNoteAskBadQuestion", ((380, 600),)),
        Cut("AcademyNotePressImportantThings", ((670, 600),)),
        Cut("AcademyNoteFullMoonDreamPages", ((930, 600),)),
        Cut("AcademyNoteGoblinWarning", ((110, 780),)),
        Cut("AcademyNoteLessonsInStrangePlaces", ((335, 780),)),
        Cut("AcademyNoteSayTheUnsaidThing", ((555, 780),)),
        Cut("AcademyNoteForFutureSelf", ((780, 780),)),
        Cut("AcademyNoteRutColorDraining", ((990, 780),)),
        Cut("AcademyNoteChangeYourMind", ((1210, 780),)),
        Cut("AcademyNoteHardPlaces", ((1430, 780),)),
        Cut("AcademyNoteLeaveNoteForYourself", ((110, 950),)),
        Cut("AcademyNoteLibraryDoor", ((350, 950),)),
        Cut("AcademyNoteFollowTheFox", ((575, 940),)),
        Cut("AcademyNoteNotAllStayInInk", ((780, 950),)),
        Cut("AcademyNoteFlutteringPage", ((995, 950),)),
        Cut("AcademyNoteKeepCameraHandy", ((1200, 950),)),
        Cut("AcademyNoteTrustWonder", ((1430, 950),)),
    ),
    "academy-notes-two": (
        Cut("AcademyWarningBewareTheGoblins", ((180, 150),)),
        Cut("AcademyWarningDontTrustMomort", ((540, 150),)),
        Cut("AcademyWarningBookRemembers", ((900, 150),)),
        Cut("AcademyWarningFollowBlueThread", ((1260, 150),)),
        Cut("AcademyWarningTurnPageAtDusk", ((180, 420),)),
        Cut("AcademyWarningKeepBeliefClose", ((540, 420),)),
        Cut("AcademyWarningLeaveTruthBehind", ((900, 420),)),
        Cut("AcademyWarningDoorsOpenWhenNoticed", ((1260, 420),)),
        Cut("AcademyWarningMarginsListening", ((180, 690),)),
        Cut("AcademyWarningSaferByMoonlight", ((540, 690),)),
        Cut("AcademyWarningWickerWasHere", ((900, 690),)),
        Cut("AcademyWarningYouWereExpected", ((1260, 690),)),
        Cut("AcademyWarningNotEveryGuideIsKind", ((180, 950),)),
        Cut("AcademyWarningLookTwiceAtOrdinary", ((540, 950),)),
        Cut("AcademyWarningComeBackToThis", ((900, 950),)),
        Cut("AcademyWarningQuestionsAreKeys", ((1260, 950),)),
    ),
    "botanicals": (
        Cut("BotanicalViolet", ((129, 160),)),
        Cut("BotanicalLilyOfTheValley", ((374, 143),)),
        Cut("BotanicalBlueStar", ((611, 131),)),
        Cut("BotanicalHeather", ((848, 153),)),
        Cut("BotanicalWoodAnemone", ((1106, 164),)),
        Cut("BotanicalFlyAgaric", ((1341, 146),)),
        Cut("BotanicalFoxglove", ((103, 432),)),
        Cut("BotanicalDaisies", ((365, 407),)),
        Cut("BotanicalRosemary", ((607, 414),)),
        Cut("BotanicalOakAcorns", ((855, 410),)),
        Cut("BotanicalBlackberry", ((1110, 416),)),
        Cut("BotanicalBindweed", ((1333, 425),)),
        Cut("BotanicalSnowdrop", ((119, 696),)),
        # The blown clock scatters four seeds across the gutter toward its
        # neighbour. They are the point of a dandelion, so they are seeded in.
        Cut("BotanicalDandelion", ((357, 680), (459, 564), (487, 597), (448, 639), (451, 678))),
        Cut("BotanicalChineseLantern", ((619, 664),)),
        Cut("BotanicalLavender", ((866, 682),)),
        Cut("BotanicalPoppy", ((1112, 675),)),
        Cut("BotanicalIvy", ((1340, 674),)),
        Cut("BotanicalWhiteBells", ((112, 952),)),
        Cut("BotanicalBorage", ((367, 942),)),
        Cut("BotanicalHellebore", ((618, 919),)),
        Cut("BotanicalFernFiddlehead", ((862, 955),)),
        Cut("BotanicalSycamoreKeys", ((1075, 961),)),
        Cut("BotanicalHolly", ((1339, 944),)),
    ),
}

SHEET_ALPHA_THRESHOLDS = {
    "punctuation-pixie": 8,
    # This sheet carries a broader soft halo; 16 separates neighboring goblin
    # studies while the dilation below still restores their painted fringe.
    "marginalia-goblins": 16,
    "academy-notes-one": 4,
    "academy-notes-two": 4,
    # Neighbouring studies nearly touch on this sheet; 16 keeps a violet
    # from annexing the lily beside it while the dilation restores fringe.
    "botanicals": 16,
}

SHEET_GROUPING = {
    # Join letters, lines, arrows, and small drawn marks into one note without
    # joining the generous gutters between neighboring notes.
    "academy-notes-one": ((11, 7), 2),
    "academy-notes-two": ((11, 7), 2),
}

SHEET_OUTPUT_ALPHA_FLOORS = {
    "academy-notes-one": 4,
    "academy-notes-two": 4,
}


def nearest_label(labels: np.ndarray, seed: tuple[int, int], radius: int = 18) -> int:
    x, y = seed
    height, width = labels.shape
    if 0 <= x < width and 0 <= y < height and labels[y, x] != 0:
        return int(labels[y, x])
    x0, x1 = max(0, x - radius), min(width, x + radius + 1)
    y0, y1 = max(0, y - radius), min(height, y + radius + 1)
    ys, xs = np.nonzero(labels[y0:y1, x0:x1])
    if len(xs) == 0:
        raise ValueError(f"No painted component near seed {seed}")
    distances = (xs + x0 - x) ** 2 + (ys + y0 - y) ** 2
    nearest = int(np.argmin(distances))
    return int(labels[ys[nearest] + y0, xs[nearest] + x0])


def cut_asset(
    source: np.ndarray,
    labels: np.ndarray,
    cut: Cut,
    alpha_floor: int = 8,
) -> Image.Image:
    component_ids = {nearest_label(labels, seed) for seed in cut.seeds}
    selected = np.isin(labels, list(component_ids)).astype(np.uint8)
    # Retain the source's antialiased fringe, but not the broad near-invisible
    # noise that joins otherwise separate studies on an AI-authored sheet.
    selected = cv2.dilate(selected, np.ones((7, 7), np.uint8), iterations=1).astype(bool)
    result = source.copy()
    result[~selected] = 0
    result[result[:, :, 3] < alpha_floor] = 0

    ys, xs = np.nonzero(result[:, :, 3])
    if len(xs) == 0:
        raise ValueError(f"{cut.asset_name} produced an empty crop")
    padding = 6
    x0 = max(0, int(xs.min()) - padding)
    y0 = max(0, int(ys.min()) - padding)
    x1 = min(result.shape[1], int(xs.max()) + padding + 1)
    y1 = min(result.shape[0], int(ys.max()) + padding + 1)
    return Image.fromarray(result[y0:y1, x0:x1], "RGBA")


def write_image_set(output: Path, asset_name: str, image: Image.Image, overwrite: bool) -> Path:
    image_set = output / f"{asset_name}.imageset"
    if image_set.exists() and not overwrite:
        raise FileExistsError(f"Refusing to overwrite {image_set}; pass --overwrite intentionally")
    image_set.mkdir(parents=True, exist_ok=True)
    png_path = image_set / f"{asset_name}.png"
    image.save(png_path, format="PNG", optimize=True, compress_level=9)
    contents = {
        "images": [{"filename": png_path.name, "idiom": "universal", "scale": "1x"}],
        "info": {"author": "xcode", "version": 1},
        "properties": {"preserves-vector-representation": False},
    }
    (image_set / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")
    return png_path


def write_preview(images: list[tuple[str, Image.Image]], destination: Path) -> None:
    cell_width, cell_height = 260, 280
    columns = 4
    rows = (len(images) + columns - 1) // columns
    preview = Image.new("RGB", (cell_width * columns, cell_height * rows), (242, 237, 224))
    draw = ImageDraw.Draw(preview)
    for index, (name, image) in enumerate(images):
        column, row = index % columns, index // columns
        thumb = image.copy()
        thumb.thumbnail((cell_width - 24, cell_height - 48), Image.Resampling.LANCZOS)
        x = column * cell_width + (cell_width - thumb.width) // 2
        y = row * cell_height + 26 + (cell_height - 48 - thumb.height) // 2
        preview.paste(thumb, (x, y), thumb)
        draw.text((column * cell_width + 8, row * cell_height + 7), name, fill=(35, 27, 24))
    destination.parent.mkdir(parents=True, exist_ok=True)
    preview.save(destination, format="PNG", optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sheet", choices=sorted(SHEETS), required=True)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--preview", type=Path)
    parser.add_argument("--overwrite", action="store_true")
    args = parser.parse_args()

    source_image = Image.open(args.source).convert("RGBA")
    source = np.array(source_image)
    alpha = source[:, :, 3]
    alpha_threshold = SHEET_ALPHA_THRESHOLDS.get(args.sheet, 8)
    component_mask = (alpha >= alpha_threshold).astype(np.uint8)
    if args.sheet in SHEET_GROUPING:
        (kernel_width, kernel_height), iterations = SHEET_GROUPING[args.sheet]
        component_mask = cv2.dilate(
            component_mask,
            np.ones((kernel_height, kernel_width), np.uint8),
            iterations=iterations,
        )
    _, labels, _, _ = cv2.connectedComponentsWithStats(
        component_mask,
        8,
    )

    preview_images: list[tuple[str, Image.Image]] = []
    source_bytes = args.source.read_bytes()
    output_alpha_floor = SHEET_OUTPUT_ALPHA_FLOORS.get(args.sheet, 8)
    for cut in SHEETS[args.sheet]:
        image = cut_asset(source, labels, cut, alpha_floor=output_alpha_floor)
        png_path = write_image_set(args.output, cut.asset_name, image, args.overwrite)
        preview_images.append((cut.asset_name, image))
        print(f"{cut.asset_name}: {image.width}x{image.height} {png_path.stat().st_size} bytes")
    if args.source.read_bytes() != source_bytes:
        raise RuntimeError("Source sheet changed during import")
    if args.preview:
        write_preview(preview_images, args.preview)
        print(f"preview: {args.preview}")


if __name__ == "__main__":
    main()
