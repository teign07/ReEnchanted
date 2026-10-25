#!/usr/bin/env python3
"""Compress bundled plates from their EPUB masters, never from prior outputs.

Keeps filenames, resolution, color profiles, orientation, PNG transparency,
and chapter positions. Reviewed infographic repairs retain their current bytes
instead of being restored from EPUB masters. Requires Pillow. No app build.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import re
import zipfile

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
LIBRARY = ROOT / "Shared/BookReferenceLibrary.json"
FOLDER = ROOT / "InsideCoverApp/WonderCompassImages"
AUDIT = ROOT / "docs/wonder-compass-infographic-audit.json"
MINIMUM_SAVING = 0.05


def digest(data):
    return hashlib.sha256(data).hexdigest()


def encode(source, kind):
    with Image.open(io.BytesIO(source)) as original:
        image = ImageOps.exif_transpose(original)
        output = io.BytesIO()
        profile = original.info.get("icc_profile")
        if original.format == "PNG":
            # Preserve RGBA; these menus have real semitransparent pixels.
            image.save(output, "PNG", optimize=True, icc_profile=profile)
        elif original.format == "JPEG":
            image.convert("RGB").save(
                output, "JPEG", quality=84 if kind == "photo" else 85,
                # Keep color edges in infographic lettering at full resolution.
                subsampling=2 if kind == "photo" else 0,
                optimize=True, progressive=True, icc_profile=profile,
            )
        else:
            raise ValueError(f"Unsupported original format: {original.format}")
        candidate = output.getvalue()
        return candidate if len(candidate) <= len(source) * (1 - MINIMUM_SAVING) else source


def optimize(epub):
    raw = LIBRARY.read_text()
    payload = json.loads(raw)
    entries = [e for s in payload["wonderCompass"] for e in s.get("illustrations", [])]
    # An EPUB master must never silently restore the errors repaired in-app.
    corrections = {e["fileName"]: e for e in json.loads(AUDIT.read_text())["images"]
                   if e["status"] == "corrected"} if AUDIT.exists() else {}
    outputs = {}
    before = after = changed = 0
    with zipfile.ZipFile(epub) as archive:
        for entry in entries:
            name = entry["fileName"]
            if name in outputs:
                continue
            assert Path(name).name == name, "Unsafe image name"
            original = archive.read(f"OPS/images/{name}")
            assert digest(original) == entry.get("sourceSHA256", entry["sha256"]), name
            current = (FOLDER / name).read_bytes()
            assert digest(current) == entry["sha256"], f"Unexpected local image edits: {name}"
            if name in corrections:
                assert digest(current) == corrections[name]["sha256"], f"Unreviewed correction: {name}"
                result = current
            else:
                result = encode(original, entry["kind"])
            with Image.open(io.BytesIO(result)) as decoded:
                assert decoded.size == (entry["pixelWidth"], entry["pixelHeight"]), name
                decoded.verify()
            outputs[name] = (original, result)
            before += len(current)
            after += len(result)
            changed += current != result

    for entry in entries:
        original, result = outputs[entry["fileName"]]
        entry["sourceSHA256"] = digest(original)
        entry["sha256"] = digest(result)

    # Replace only the illustration arrays. Prose and unrelated local work
    # retain their exact bytes, including formatting.
    arrays = {s["illustrations"][0]["id"]: s["illustrations"]
              for s in payload["wonderCompass"] if s.get("illustrations")}
    decoder = json.JSONDecoder()
    for match in reversed(list(re.finditer(r'^      "illustrations": ', raw, re.MULTILINE))):
        previous, length = decoder.raw_decode(raw[match.end():])
        replacement = json.dumps(arrays[previous[0]["id"]], ensure_ascii=False, indent=2)
        replacement = replacement.replace("\n", "\n      ")
        raw = raw[:match.end()] + replacement + raw[match.end() + length:]
    assert json.loads(raw) == payload

    for name, (_, result) in outputs.items():
        destination = FOLDER / name
        if destination.read_bytes() != result:
            temporary = destination.with_suffix(destination.suffix + ".tmp")
            temporary.write_bytes(result)
            temporary.replace(destination)
    LIBRARY.write_text(raw)
    print(f"{changed}/{len(outputs)} files changed: {before:,} -> {after:,} bytes "
          f"({100 * (1 - after / before):.1f}% smaller this run). "
          f"{len(corrections)} reviewed corrections preserved. Resolution unchanged.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("epub", type=Path)
    optimize(parser.parse_args().epub)
