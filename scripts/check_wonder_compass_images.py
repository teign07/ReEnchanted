#!/usr/bin/env python3
"""Check bundled Wonder Compass plates and exact manuscript anchors; no build.

Pass --epub to also prove every in-text EPUB image was imported in order,
with its original source checksum. Uncorrected source resolution, color profiles
and PNG pixels stay exact; reviewed repairs have their own hashes/dimensions.
The EPUB cover opens Read This First, ahead of all in-text illustrations.
"""
import argparse
from collections import Counter
import hashlib
import io
import json
from pathlib import Path
import xml.etree.ElementTree as ET
import zipfile

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
AUDIT = ROOT / "docs/wonder-compass-infographic-audit.json"


def check(epub=None):
    payload = json.loads((ROOT / "Shared/BookReferenceLibrary.json").read_text())
    snippets = payload["wonderCompass"]
    first = snippets[0]
    links = first.get("contentsLinks", [])
    paragraphs = first["body"].split("\n\n")
    labels = [line.strip() for line in paragraphs[paragraphs.index("Table Of Contents") + 1].split("\n")]
    assert [link["label"] for link in links] == labels, "Contents labels/order differ from the manuscript"
    section_ids = {snippet["id"] for snippet in snippets}
    assert all(link["sectionID"] in section_ids for link in links), "Contents link has no chapter Page"
    entries = []
    for snippet in snippets:
        paragraphs = snippet["body"].split("\n\n")
        boundaries = []
        for plate in snippet.get("illustrations", []):
            assert paragraphs.count(plate["anchor"]) == 1, f"Missing/ambiguous anchor: {plate['id']}"
            assert plate["placement"] in {"before", "after"}, plate["id"]
            boundary = paragraphs.index(plate["anchor"]) + (plate["placement"] == "after")
            boundaries.append(boundary)
            assert plate["fileName"] == Path(plate["fileName"]).name, plate["id"]
            assert plate["title"].strip(), plate["id"]
        assert boundaries == sorted(boundaries), f"Reordered plates: {snippet['id']}"
        entries.extend(snippet.get("illustrations", []))
    assert len(entries) == 101, f"Expected 101 placements, got {len(entries)}"
    first = snippets[0]
    assert first["id"] == "wonder-compass-read-this-first"
    cover = first["illustrations"][0]
    assert cover["id"] == "wc-cover" and cover["kind"] == "cover"
    assert cover["sourceChapter"] == "cover.xhtml"
    assert cover["placement"] == "before" and cover["anchor"] == first["body"].split("\n\n")[0]
    assert len({e["id"] for e in entries}) == len(entries), "Duplicate placement IDs"
    names = {e["fileName"] for e in entries}
    reviewed = {}
    if AUDIT.exists():
        audit = json.loads(AUDIT.read_text())
        reviewed = {image["fileName"]: image for image in audit["images"]}
        infographics = {e["fileName"] for e in entries if e["kind"] == "infographic"}
        assert len(reviewed) == len(audit["images"]), "Duplicate infographic audit entries"
        assert set(reviewed) == infographics, "Infographic audit coverage differs from the bundle"
        for entry in entries:
            if entry["fileName"] not in reviewed:
                continue
            review = reviewed[entry["fileName"]]
            assert review["status"] in {"corrected", "unchanged"}, entry["id"]
            assert entry["sha256"] == review["sha256"], f"Unreviewed infographic change: {entry['id']}"
            assert entry.get("sourceSHA256", entry["sha256"]) == review["sourceSHA256"], entry["id"]
            if review["status"] == "unchanged":
                assert review["sha256"] == review["originalBundledSHA256"], entry["id"]
            else:
                assert review["corrections"] and review["prompt"], entry["id"]
                assert review["sha256"] != review["originalBundledSHA256"], entry["id"]
    folder = ROOT / "InsideCoverApp/WonderCompassImages"
    assert names == {p.name for p in folder.iterdir() if p.is_file()}, "Missing or unused image files"
    for entry in entries:
        path = folder / entry["fileName"]
        assert hashlib.sha256(path.read_bytes()).hexdigest() == entry["sha256"], entry["id"]
        with Image.open(path) as image:
            assert image.size == (entry["pixelWidth"], entry["pixelHeight"]), entry["id"]
            image.verify()
    if epub:
        with zipfile.ZipFile(epub) as archive:
            chapters = sorted(
                (n for n in archive.namelist() if n.startswith("OPS/chapter-") and n.endswith(".xhtml")),
                key=lambda n: int(Path(n).stem.split("-")[-1]),
            )
            cover_root = ET.fromstring(archive.read("OPS/cover.xhtml"))
            expected = [("cover.xhtml", Path(image.attrib["src"]).name)
                        for image in cover_root.iter() if image.tag.endswith("}img")]
            for chapter in chapters:
                root = ET.fromstring(archive.read(chapter))
                for image in root.iter():
                    if image.tag.endswith("}img"):
                        expected.append((Path(chapter).name, Path(image.attrib["src"]).name))
            actual = [(e["sourceChapter"], e["fileName"]) for e in entries]
            # The app keeps Disclaimer after the appendices, but that section
            # has no images. Every illustrated section follows the book order.
            assert actual == expected, "In-text EPUB image coverage/order differs"
            by_name = {e["fileName"]: e for e in entries}
            for name in names:
                entry = by_name[name]
                original_bytes = archive.read(f"OPS/images/{name}")
                assert hashlib.sha256(original_bytes).hexdigest() == entry.get("sourceSHA256", entry["sha256"]), name
                if reviewed.get(name, {}).get("status") == "corrected":
                    # The EPUB remains provenance, not the repaired artwork.
                    # Current checksums/dimensions were verified above. Text
                    # edits can change encoded size, resolution and profile.
                    continue
                bundled_bytes = (folder / name).read_bytes()
                assert len(bundled_bytes) <= len(original_bytes), f"Larger than original: {name}"
                with Image.open(io.BytesIO(original_bytes)) as original, Image.open(folder / name) as bundled:
                    source = ImageOps.exif_transpose(original)
                    assert bundled.size == source.size, f"Resolution changed: {name}"
                    assert bundled.info.get("icc_profile") == original.info.get("icc_profile"), f"Color profile changed: {name}"
                    if original.format == "PNG":
                        assert bundled.convert("RGBA").tobytes() == source.convert("RGBA").tobytes(), f"PNG pixels changed: {name}"
    total_bytes = sum((folder / name).stat().st_size for name in names)
    print(f"OK: {len(entries)} placements, {len(names)} bundled files ({total_bytes:,} bytes), "
          f"{sum(bool(s.get('illustrations')) for s in snippets)} sections; "
          f"{dict(Counter(e['kind'] for e in entries))}; "
          f"{sum(r['status'] == 'corrected' for r in reviewed.values())} corrected infographics")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--epub", type=Path)
    check(parser.parse_args().epub)
