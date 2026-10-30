#!/usr/bin/env python3
"""Stage/check Unwritten Deck JPEGs; install only a complete reviewed deck.

No image generation, app compilation, network access or deployment.
Masters and first-generation RWS references remain outside the app bundle.
"""
import argparse
import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image, ImageCms, ImageOps
from prepare_unwritten_tarot import ROOT, DEST, jobs


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")


def preserve_references(records):
    folder = DEST / "rws-reference"
    folder.mkdir(parents=True, exist_ok=True)
    for job in records:
        target = folder / (job["id"] + ".jpg")
        if not target.exists():
            if (ROOT / "docs/unwritten-deck-art-manifest.json").exists():
                raise ValueError("Original RWS reference missing; restore it from the historical import, never label current deck art as RWS")
            shutil.copy2(job["compositionReference"], target)


def stage(job, quality, destination=DEST, *, aspect_ratio_tolerance=0.01):
    # A hash-bound batch review may accept a small uncropped aspect variation.
    # The native renderer fits the complete painting inside its 7:12 plate.
    assert 0.01 <= aspect_ratio_tolerance <= 0.02
    source = Path(job["master"])
    target = destination / "app-exports" / (job["id"] + ".jpg")
    target.parent.mkdir(parents=True, exist_ok=True)
    with Image.open(source) as original:
        original.load()
        image = ImageOps.exif_transpose(original)
        if image.mode == "RGBA":
            paper = Image.new("RGB", image.size, (244, 236, 214))
            paper.paste(image, mask=image.getchannel("A"))
            image = paper
        else:
            image = image.convert("RGB")
        if original.info.get("icc_profile"):
            import io
            image = ImageCms.profileToProfile(image,
                ImageCms.ImageCmsProfile(io.BytesIO(original.info["icc_profile"])),
                ImageCms.createProfile("sRGB"), outputMode="RGB")
        if abs(image.width / image.height - 7 / 12) > aspect_ratio_tolerance:
            raise ValueError(f"Unexpected card ratio for {job['id']}: {image.size}; never crop symbols automatically")
        if min(image.size) < 800:
            raise ValueError(f"Insufficient source resolution for {job['id']}: {image.size}")
        # No resizing, invented detail, sharpening, crop or plate editing.
        profile = ImageCms.ImageCmsProfile(ImageCms.createProfile("sRGB")).tobytes()
        image.save(target, format="JPEG", quality=quality, subsampling=0,
                   optimize=True, progressive=True, icc_profile=profile)
        dimensions = image.size
    with Image.open(target) as check:
        check.load()
        assert check.size == dimensions and check.mode == "RGB"
    return {
        "id": job["id"], "assetName": job["assetName"],
        "master": str(source.relative_to(ROOT)), "masterSHA256": digest(source),
        "export": str(target.relative_to(ROOT)), "exportSHA256": digest(target),
        "pixelWidth": dimensions[0], "pixelHeight": dimensions[1],
        "masterBytes": source.stat().st_size, "exportBytes": target.stat().st_size,
        "jpegQuality": quality, "subsampling": "4:4:4", "colorSpace": "sRGB"
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--quality", type=int, default=78)
    parser.add_argument("--install", action="store_true", help="Install only when all79 masters and production reviews exist")
    args = parser.parse_args()
    if not 60 <= args.quality <= 95:
        parser.error("quality must be60...95")
    records = jobs()
    preserve_references(records)
    back = {"id": "back", "assetName": "TarotBackUnwritten", "master": str(DEST / "masters/back.png")}
    complete = [j for j in records + [back] if Path(j["master"]).exists()
                and (DEST / "receipts" / (j["id"] + ".json")).exists()]
    export_index = DEST / "exports.json"
    previous = {e["id"]: e for e in json.loads(export_index.read_text())} if export_index.exists() else {}
    exports = []
    for job in complete:
        held = previous.get(job["id"])
        target = ROOT / held["export"] if held else None
        if held and target.exists() and held["jpegQuality"] == args.quality \
                and held["masterSHA256"] == digest(Path(job["master"])) \
                and held["exportSHA256"] == digest(target):
            exports.append(held)
        else:
            exports.append(stage(job, args.quality))
    write_json(DEST / "exports.json", exports)
    print(json.dumps({"exported": len(exports), "masterBytes": sum(e["masterBytes"] for e in exports),
                      "appBytes": sum(e["exportBytes"] for e in exports), "installed": False}))
    if not args.install:
        return
    if len(exports) != 79:
        raise SystemExit("Refusing installation: all78 faces and the back must be present")
    review_path = DEST / "production-reviews.json"
    reviews = json.loads(review_path.read_text()) if review_path.exists() else {}
    bad = [e["id"] for e in exports if reviews.get(e["id"], {}).get("status") not in ("accepted", "accepted-adaptation")]
    if bad:
        raise SystemExit("Refusing installation: production review missing for " + ", ".join(bad))
    stale = [e["id"] for e in exports if reviews[e["id"]].get("masterSHA256") != e["masterSHA256"]]
    if stale:
        raise SystemExit("Refusing installation: artwork changed after production review for " + ", ".join(stale))
    # Detect concurrent asset edits before touching any catalog input.
    for job in records:
        current = Path(job["compositionReference"])
        reference = DEST / "rws-reference" / (job["id"] + ".jpg")
        exported = DEST / "app-exports" / (job["id"] + ".jpg")
        if digest(current) not in (digest(reference), digest(exported)):
            raise SystemExit(f"Refusing to overwrite a concurrent asset edit: {current}")
    manifest = {"deckVersion": "unwritten-v1", "generator": "built-in image_gen.imagegen",
                "stylePrompt": __import__("prepare_unwritten_tarot").STYLE,
                "lineage": "Rider–Waite–Smith; Pamela Colman Smith",
                "cards": []}
    for exported in exports:
        folder = ROOT / "InsideCoverApp/Assets.xcassets" / (exported["assetName"] + ".imageset")
        folder.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / exported["export"], folder / "card.jpg")
        assert digest(folder / "card.jpg") == exported["exportSHA256"]
        write_json(folder / "Contents.json", {"images": [{"filename": "card.jpg", "idiom": "universal", "scale": "1x"}],
                                               "info": {"author": "xcode", "version": 1}})
        entry = dict(exported, review=reviews[exported["id"]])
        job = next((j for j in records if j["id"] == exported["id"]), None)
        if job:
            entry.update(requiredScene=job["requiredScene"], authoredID=job["authoredID"],
                         rwsReferenceSHA256=digest(DEST / "rws-reference" / (job["id"] + ".jpg")))
        receipt = DEST / "receipts" / (exported["id"] + ".json")
        if receipt.exists():
            generation = json.loads(receipt.read_text())
            entry["generationReceipt"] = generation
            prompt_file = generation.get("promptFile")
            if prompt_file and Path(prompt_file).exists():
                entry["generationPrompt"] = Path(prompt_file).read_text()
        manifest["cards"].append(entry)
    write_json(ROOT / "docs/unwritten-deck-art-manifest.json", manifest)
    print("Installed78 faces and one back; saved docs/unwritten-deck-art-manifest.json")


if __name__ == "__main__":
    main()
