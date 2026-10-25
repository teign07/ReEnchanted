#!/usr/bin/env python3
"""Import original EPUB images beside matching passages, without replacing prose.

Requires Pillow. Run with the original 'The Wonder Compass EBook.epub'. The
default is a placement report; --write copies original bytes and adds metadata.
Fuzzy matching happens only here, at import time; the app uses exact anchors.
"""
import argparse
import difflib
import hashlib
import io
import json
from pathlib import Path
import re
import unicodedata
import xml.etree.ElementTree as ET
import zipfile

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
LIBRARY = ROOT / "Shared/BookReferenceLibrary.json"
IMAGES = ROOT / "InsideCoverApp/WonderCompassImages"
CHAPTER_IDS = {
    **dict.fromkeys(range(1, 5), "read-this-first"),
    5: "introduction",
    **dict(zip(range(6, 20), [
        "chapter1a", "chapter1b", "chapter2", "chapter3", "chapter4a",
        "chapter4b", "chapter5", "chapter6a", "chapter6b", "chapter7",
        "chapter8a", "chapter8b", "chapter9", "chapter10",
    ])),
    20: "chapter11a", 21: "chapter11a",
    **dict(zip(range(22, 42), [
        "chapter11a", "chapter11b", "chapter11c", "chapter11d", "chapter12a",
        "chapter12b", *[f"chapter{n}" for n in range(13, 27)],
    ])),
    42: "chapter26", 43: "chapter26", 44: "chapter26",
    45: "disclaimer-alternative-map",
    **dict(zip(range(46, 51), [f"appendix-{c}" for c in "abcde"])),
    51: "appendix-e", 52: "appendix-f", 53: "appendix-g",
    54: "glossary", 55: "notes-references",
}
PHOTO_TITLES = {
    "IMG_2321_Large.jpeg": "Portrait of bj, the author",
    "IMG_0427.jpeg": "A close encounter with a rabbit",
    "IMG_2297_Large.jpeg": "A couple on the waterfront with a giant yellow duck behind them",
    "IMG_0676_Large.jpeg": "A woman smiling outdoors",
    "IMG_1296_Large.jpeg": "A green-hulled sailboat at the dock",
    "IMG_1232_Large.jpeg": "A computer and shelves lit with purple light",
    "IMG_1161.jpg": "Plants growing in containers beside a porch",
    "IMG_1815.jpg": "A small bird curled up on a red surface",
    "IMG_20190730_202258_Large.jpeg": "A boat glowing with warm light at dusk",
    "IMG_0706_Large.jpeg": "Open water and sky seen from a boat",
    "MVIMG_20190819_191243_Large.jpeg": "An American flag and harbor buildings behind a boat",
    "IMG_1425_Large.jpeg": "A woman laughing with an ice pop on a boat",
    "IMG_2021_Large.jpeg": "Knitted pieces hanging along a dock railing",
    "IMG_3962.jpeg": "Mist rising from still water beside a wooded shore",
    "IMG_1111_Large.jpeg": "Feet up beside a harbor full of boats",
    "IMG_20190819_191600_1_Large.jpeg": "A dog looking out from a boat",
    "IMG_1627.jpg": "A woman holding a small bird close to her face",
    "IMG_2517.jpg": "Two cats curled together on a cushioned chair",
    "IMG_0816_Large.jpeg": "Food cooking over an outdoor fire",
    "IMG_2135_Large.jpeg": "A person holding a rabbit close",
    "IMG_1286_Large.jpeg": "The compact kitchen inside a sailboat",
    "IMG_2311_Large.jpeg": "A close portrait of the author",
    "IMG_1295_Large.jpeg": "A person stretching beside the water at sunset",
    "IMG_1579_Large.jpeg": "A bee exploring the center of a sunflower",
    "IMG_1118_Large.jpeg": "A boat beneath a dramatic cloudy sky",
    "IMG_0732_Large.jpeg": "The author wearing a face shield and respirator at work",
    "IMG_1194_Large.jpeg": "The author seated on rocks beside the ocean",
    "IMG_1736_Large.jpeg": "A white statue beside a waterfront street",
    "image13.jpeg": "A giant yellow duck floating in a harbor",
    "IMG_0425.JPG": "A couple sharing a kiss outdoors",
    "IMG_0430.jpeg": "A woman sitting aboard a sailboat",
    "IMG_1279_Large.jpeg": "A couple together beside the water at sunset",
    "IMG_2100.jpg": "A large cloud of smoke rising over waterfront buildings",
    "IMG_1409_Large.jpeg": "A woman holding a large crustacean on a boat",
    "IMG_1641.jpg": "People seated in a cafe",
    "IMG_2258.jpg": "Sunlight filtering through leaves above an animal's ears",
    "IMG_20190613_132127_Large.jpeg": "Tables, chairs, and shelves inside a cafe",
    "IMG_0850_Large.jpeg": "A person leaning back in a kayak on a harbor",
}


def normalized(text):
    text = unicodedata.normalize("NFKD", text).casefold()
    return " ".join(re.findall(r"\w+", text))


def chapter_events(archive, chapter):
    root = ET.fromstring(archive.read(f"OPS/chapter-{chapter}.xhtml"))
    events = []
    for element in root.iter():
        if element.tag.rsplit("}", 1)[-1] not in {"p", "h1", "h2", "h3"}:
            continue
        text = " ".join("".join(element.itertext()).replace("\ufffc", "").split())
        if text:
            events.append(("text", text))
        events.extend(("image", image.attrib["src"])
                      for image in element.iter() if image.tag.endswith("}img"))
    return events


def cover_placement(archive, snippet):
    filename = "Book_Cover_Final.jpeg"
    data = archive.read(f"OPS/images/{filename}")
    with Image.open(io.BytesIO(data)) as image:
        width, height = image.size
    return {
        "id": "wc-cover",
        "fileName": filename,
        "title": "The Wonder Compass book cover",
        "kind": "cover",
        "pixelWidth": width,
        "pixelHeight": height,
        "anchor": snippet["body"].split("\n\n")[0],
        "placement": "before",
        "sourceChapter": "cover.xhtml",
        "sha256": hashlib.sha256(data).hexdigest(),
    }


def placements(archive, snippets):
    result = {snippet["id"]: [] for snippet in snippets}
    by_id = {snippet["id"]: snippet for snippet in snippets}
    first = by_id["wonder-compass-read-this-first"]
    for chapter, suffix in CHAPTER_IDS.items():
        section_id = f"wonder-compass-{suffix}"
        snippet = by_id[section_id]
        paragraphs = snippet["body"].split("\n\n")
        norm_paragraphs = [normalized(p) for p in paragraphs]
        events = chapter_events(archive, chapter)
        for index, (kind, source_image) in enumerate(events):
            if kind != "image":
                continue
            # A removed caption can sit immediately beside a plate. Search out
            # to the nearest surviving paragraph on either side, preferring an
            # exact match before accepting a substantial editorial revision.
            candidates = []
            for distance in range(1, len(events) + 1):
                for direction in (-1, 1):
                    neighbor = index + distance * direction
                    if not 0 <= neighbor < len(events) or events[neighbor][0] != "text":
                        continue
                    source_text = normalized(events[neighbor][1])
                    if not source_text:
                        continue
                    exact = [i for i, p in enumerate(norm_paragraphs) if p == source_text]
                    if exact:
                        match, score = exact[0], 1.0
                    else:
                        match, score = max(enumerate(
                            difflib.SequenceMatcher(None, source_text, p, autojunk=False).ratio()
                            for p in norm_paragraphs), key=lambda pair: pair[1])
                    if score >= 0.8 and paragraphs.count(paragraphs[match]) == 1:
                        candidates.append((distance + (1 - score) * 5, direction, match, score))
                if candidates and distance > min(c[0] for c in candidates) + 1:
                    break
            # The second Playful Mission page has no prose in the app. It
            # belongs directly after the first plate at the appendix's end.
            if chapter == 51:
                match, direction, score = 0, -1, 1.0
            elif candidates:
                _, direction, match, score = min(candidates)
            else:
                raise ValueError(f"No surviving passage: chapter {chapter}, {source_image}")
            anchor = paragraphs[match]
            before = direction == 1
            # Boundaries are exact, unique text, not character offsets that
            # drift whenever a chapter's earlier paragraphs are edited.
            if paragraphs.count(anchor) != 1:
                raise ValueError(f"Ambiguous passage in {section_id}: {anchor!r}")
            data = archive.read(f"OPS/{source_image}")
            with Image.open(io.BytesIO(data)) as image:
                width, height = image.size
            filename = Path(source_image).name
            is_photo = filename in PHOTO_TITLES
            title = re.sub(r"_Large(?:_2)?$", "", Path(filename).stem).replace("_", " ")
            if is_photo:
                title = PHOTO_TITLES[filename]
            elif filename.startswith("117AC"):
                title = "The Wonder Compass"
            elif filename.startswith("phonto"):
                title = "Why Your Brain Thinks an Email is a Tiger"
            elif filename.startswith("B336"):
                title = "The Doorleedos: Find Wonder Anywhere"
            elif filename == "The__0_Compass_Guide_Large.jpeg":
                title = "The $0 Compass Guide"
            entry = {
                "id": f"wc-{chapter}-{len(result[section_id]) + 1}",
                "fileName": filename,
                "title": title,
                "kind": "photo" if is_photo else ("illustration" if filename.startswith(("117AC", "B336")) else "infographic"),
                "pixelWidth": width,
                "pixelHeight": height,
                "anchor": anchor,
                "placement": "before" if before else "after",
                "sourceChapter": f"chapter-{chapter}.xhtml",
                "sha256": hashlib.sha256(data).hexdigest(),
            }
            result[section_id].append(entry)
            print(f"{section_id:38} {filename:66} {entry['placement']:6} {score:.2f} {anchor[:90]!r}")
    result[first["id"]].insert(0, cover_placement(archive, first))
    for section_id, entries in result.items():
        paragraphs = by_id[section_id]["body"].split("\n\n")
        boundaries = [paragraphs.index(e["anchor"]) + (e["placement"] == "after") for e in entries]
        if boundaries != sorted(boundaries):
            raise ValueError(f"Image order differs from the EPUB in {section_id}: {boundaries}")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("epub", type=Path)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    raw = LIBRARY.read_text()
    payload = json.loads(raw)
    with zipfile.ZipFile(args.epub) as archive:
        entries = placements(archive, payload["wonderCompass"])
        if args.write:
            if any("illustrations" in s for s in payload["wonderCompass"]):
                raise ValueError("Illustrations already imported; review existing anchors before replacing.")
            IMAGES.mkdir(exist_ok=True)
            for section_id, illustrations in entries.items():
                if not illustrations:
                    continue
                for entry in illustrations:
                    destination = IMAGES / entry["fileName"]
                    data = archive.read(f"OPS/images/{entry['fileName']}")
                    if destination.exists() and destination.read_bytes() != data:
                        raise ValueError(f"Refusing to overwrite different image: {destination}")
                    destination.write_bytes(data)
                needle = f'      "id": "{section_id}",'
                encoded = json.dumps(illustrations, ensure_ascii=False, indent=2)
                encoded = encoded.replace("\n", "\n      ")
                assert raw.count(needle) == 1
                raw = raw.replace(needle, needle + '\n      "illustrations": ' + encoded + ',')
            # Prove the import does not replace any of the edited manuscript.
            restored = json.loads(raw)
            for snippet in restored["wonderCompass"]:
                snippet.pop("illustrations", None)
            assert restored == payload
            LIBRARY.write_text(raw)
    print(f"{sum(map(len, entries.values()))} placements in {sum(bool(v) for v in entries.values())} sections")


if __name__ == "__main__":
    main()
