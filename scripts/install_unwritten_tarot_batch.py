#!/usr/bin/env python3
"""Install an explicitly approved art batch into the existing complete deck.

Uses the established JPEG optimizer. No generation, build or deployment.
Each batch has hash-bound reviews and a snapshot of the current catalog;
unselected cards and the back are preserved. This does not enable v2 installs.
"""
import argparse
import json
import re
import shutil
from pathlib import Path

from optimize_unwritten_tarot import ROOT, digest, stage, write_json

MARKER = r"    // BEGIN AUTHORED UNWRITTEN MARGINALIA.*?    // END AUTHORED UNWRITTEN MARGINALIA"
EDITION = "unwritten-v3"


def quoted(value):
    return json.dumps(value, ensure_ascii=False)


def swift_marginalia(card):
    spec = card["authoredSpecification"]
    layout = spec.get("annotationLayout", {})
    args = [f'label: {quoted(spec["marginalLabel"])}', f'note: {quoted(spec["readingNote"])}']
    for key in ("labelX", "labelY", "labelWidth", "labelOnPaper", "noteX", "noteY", "noteWidth",
                "labelFontWidthRatio"):
        if key in layout:
            args.append(f"{key}: {quoted(layout[key])}")
    if "labelRotation" in layout:
        args.append(f'labelRotation: {-layout["labelRotation"]}')
    annotations = []
    for annotation in spec.get("additionalMarginalia", []):
        parts = [f"{key}: {quoted(annotation[key])}" for key in ("text", "x", "y", "width")]
        if "fontWidthRatio" in annotation:
            parts.append(f'fontWidthRatio: {annotation["fontWidthRatio"]}')
        if "rotation" in annotation:
            parts.append(f'rotation: {-annotation["rotation"]}')
        for key in ("onPaper", "maxLines"):
            if key in annotation:
                parts.append(f"{key}: {quoted(annotation[key])}")
        if annotation.get("leader"):
            points = ", ".join(f".init(x: {x}, y: {y})" for x, y in annotation["leader"])
            parts.append(f"leader: [{points}]")
        if annotation.get("isInscription"):
            parts.append("isInscription: true")
        annotations.append(".init(" + ", ".join(parts) + ")")
    if annotations:
        args.append("additional: [" + ", ".join(annotations) + "]")
    args.append(f'sceneDescription: {quoted(spec["sceneDescription"])}')
    if spec.get("marginaliaTranscript"):
        transcript = "In the margin: " + " ".join(
            value if value.endswith((".", "?", "!")) else value + "."
            for value in spec["marginaliaTranscript"])
        args.append(f'transcriptOverride: {quoted(transcript)}')
    return "        " + quoted(card["id"]) + ": .init(" + ", ".join(args) + "),"


def native_source(source, cards, version):
    revised = [card for card in cards if card.get("artworkVersion") == EDITION]
    lines = ["    // BEGIN AUTHORED UNWRITTEN MARGINALIA",
             "    private static let printedMarginalia: [String: Marginalia] = ["]
    lines.extend(swift_marginalia(card) for card in revised)
    lines += ["    ]", "    private static let illustratedSubjects: [String: [String]] = ["]
    for card in revised:
        values = ", ".join(quoted(s) for s in card["illustratedSubjects"])
        lines.append(f'        {quoted(card["id"])}: [{values}],')
    lines += ["    ]", "    // END AUTHORED UNWRITTEN MARGINALIA"]
    source, count = re.subn(MARKER, lambda _: "\n".join(lines), source, flags=re.S)
    if count != 1:
        raise ValueError("Authored source marker missing or ambiguous")
    source, count = re.subn(r'    static let version = "unwritten-v[^"\n]+"',
                            f'    static let version = "{version}"', source, count=1)
    if count != 1:
        raise ValueError("Installed deck version missing")
    return source


def validate_spec(spec):
    assert spec["marginalLabel"].strip() and spec["readingNote"].strip()
    assert spec["sceneDescription"].strip() and spec["requiredSymbols"]
    layout = spec.get("annotationLayout", {})
    for prefix, default_width in (("label", .36), ("note", .82)):
        x = layout.get(prefix + "X", .06 if prefix == "label" else .09)
        y = layout.get(prefix + "Y", .145 if prefix == "label" else .91)
        width = layout.get(prefix + "Width", default_width)
        assert 0 <= x < 1 and 0 <= y < 1 and 0 < width <= 1 - x
    for annotation in spec.get("additionalMarginalia", []):
        assert annotation["text"].strip()
        assert 0 <= annotation["x"] < 1 and 0 <= annotation["y"] < 1
        assert 0 < annotation["width"] <= 1 - annotation["x"]
        assert .015 <= annotation.get("fontWidthRatio", .034) <= .06
        assert 1 <= annotation.get("maxLines", 2) <= 3
        assert all(0 <= coordinate <= 1 for point in annotation.get("leader", []) for coordinate in point)
    assert all(re.fullmatch(r"[a-z]+(?:-[a-z]+)*", s) for s in spec["newSubjects"])
    suit, rank = spec["id"].split("-", 1)
    if suit in ("wands", "cups", "swords", "pentacles"):
        expected = {"ace": 1, "two": 2, "three": 3, "four": 4, "five": 5,
                    "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10}.get(rank, 1)
        assert spec["expectedSuitCount"] == expected, spec["id"]


def prepare_batch(production, name, card_ids):
    """Snapshot only explicitly selected, hash-reviewed, uninstalled cards."""
    assert re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", name), name
    assert card_ids and len(card_ids) == len(set(card_ids))
    dest = production / "batches" / name
    if dest.exists():
        raise SystemExit("Preserve existing batch history: " + str(dest))
    manifest_path = ROOT / "docs/unwritten-deck-art-manifest.json"
    manifest = json.loads(manifest_path.read_text())
    installed = {c["id"]: c for c in manifest["cards"]}
    reviews = json.loads((production / "production-reviews.json").read_text())
    jobs = []
    selected_reviews = {}
    for card_id in card_ids:
        if installed[card_id].get("artworkVersion") == EDITION:
            raise SystemExit("Card already has accepted v3 artwork; preserve it: " + card_id)
        job = json.loads((production / "ready" / f"{card_id}.json").read_text())
        spec_path = production / "specs" / f"{card_id}.json"
        spec = json.loads(spec_path.read_text())
        assert job["specification"] == spec
        validate_spec(spec)
        review = reviews[card_id]
        assert review["status"] in ("accepted", "accepted-adaptation")
        assert review["specSHA256"] == digest(spec_path)
        assert review["masterSHA256"] == digest(Path(job["master"]))
        job.setdefault("receiptPath", str(production / "receipts" / f"{card_id}.json"))
        assert Path(job["receiptPath"]).is_file() and Path(job["promptFile"]).is_file()
        jobs.append(job)
        selected_reviews[card_id] = review
    assets = {}
    for card in manifest["cards"]:
        relative = f"InsideCoverApp/Assets.xcassets/{card['assetName']}.imageset/card.jpg"
        assets[relative] = digest(ROOT / relative)
        assert assets[relative] == card["exportSHA256"], "Catalog differs from manifest: " + card["id"]
    assert len(assets) == 79
    for job in jobs:
        target = dest / "specs" / f"{job['id']}.json"
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(production / "specs" / target.name, target)
    write_json(dest / "jobs.json", jobs)
    write_json(dest / "production-reviews.json", selected_reviews)
    write_json(dest / "integration-baseline.json", dict(
        assets=assets, manifestSHA256=digest(manifest_path), sourceSHA256=digest(ROOT / "Shared/Tarot.swift")))
    print(json.dumps(dict(prepared=len(jobs), directory=str(dest), installed=False)))


def refresh_installed_index(manifest, receipt, dest):
    path = ROOT / "docs/unwritten-tarot-installed-revision.json"
    index = json.loads(path.read_text()) if path.exists() else {}
    revised = [c for c in manifest["cards"] if c.get("artworkVersion") == EDITION]
    directory = str(dest.relative_to(ROOT))
    directories = list(index.get("productionDirectories", [index.get("productionDirectory")]))
    directories = [d for d in directories if d]
    if directory not in directories:
        directories.append(directory)
    index.update(receipt)
    index.update(installedCardIDs=[c["id"] for c in revised],
                 latestInstalledCardIDs=receipt["installedCardIDs"],
                 productionDirectories=directories, latestProductionDirectory=directory,
                 exports=[{key: c[key] for key in ("id", "assetName", "masterSHA256", "exportSHA256")}
                          for c in revised])
    write_json(path, index)


def validate_installed_batch(manifest, exports, baseline):
    """Check the actual catalog after replacement; this is not native UI QA."""
    from PIL import Image

    selected_paths = {
        f"InsideCoverApp/Assets.xcassets/{entry['assetName']}.imageset/card.jpg"
        for entry in exports
    }
    changed = {
        relative for relative, before in baseline["assets"].items()
        if digest(ROOT / relative) != before
    }
    assert changed == selected_paths, "Installed asset delta differs from approved batch"
    assert len(manifest["cards"]) == len({c["id"] for c in manifest["cards"]}) == 79
    for card in manifest["cards"]:
        target = ROOT / "InsideCoverApp/Assets.xcassets" / (card["assetName"] + ".imageset/card.jpg")
        assert digest(target) == card["exportSHA256"], card["id"]
    for entry in exports:
        assert digest(ROOT / entry["master"]) == entry["masterSHA256"], entry["id"]
        target = ROOT / "InsideCoverApp/Assets.xcassets" / (entry["assetName"] + ".imageset/card.jpg")
        with Image.open(target) as image:
            image.load()
            assert image.mode == "RGB" and image.size == (entry["pixelWidth"], entry["pixelHeight"])
            assert image.info.get("icc_profile"), entry["id"]
    return dict(newlyInstalled=[entry["id"] for entry in exports],
                totalRevised=manifest["revisedFaces"], remaining=manifest["heldFaces"],
                changedOnlySelectedAssets=True, previousAcceptedAndBackPreserved=True,
                mastersUntouched=True, decodeDimensionsAndICC="passed",
                masterBytes=sum(entry["masterBytes"] for entry in exports),
                exportBytes=sum(entry["exportBytes"] for entry in exports),
                swiftSyntaxParse="not-run-by-installer", appBuilt=False, nativeRuntimeQA=False)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, required=True)
    parser.add_argument("--quality", type=int, default=78)
    parser.add_argument("--install", action="store_true")
    parser.add_argument("--prepare-batch", metavar="NAME",
                        help="Snapshot selected accepted ready jobs and a fresh catalog baseline")
    parser.add_argument("--card-ids", nargs="+", help="Explicit approved cards for --prepare-batch")
    args = parser.parse_args()
    if not 60 <= args.quality <= 95:
        parser.error("quality must be 60...95")
    dest = args.directory.resolve()
    if args.prepare_batch:
        if args.install or not args.card_ids:
            parser.error("--prepare-batch needs --card-ids and cannot install")
        prepare_batch(dest, args.prepare_batch, args.card_ids)
        return
    jobs = json.loads((dest / "jobs.json").read_text())
    reviews = json.loads((dest / "production-reviews.json").read_text())
    baseline = json.loads((dest / "integration-baseline.json").read_text())
    manifest_path = ROOT / "docs/unwritten-deck-art-manifest.json"
    source_path = ROOT / "Shared/Tarot.swift"
    old_manifest = json.loads(manifest_path.read_text())
    original = {card["id"]: card for card in old_manifest["cards"]}
    assert len(original) == 79 and "back" in original
    catalog_paths = {
        f"InsideCoverApp/Assets.xcassets/{card['assetName']}.imageset/card.jpg"
        for card in original.values()
    }
    assert set(baseline["assets"]) == catalog_paths, "Batch needs a complete 79-asset baseline"
    assert len(jobs) == len({job["id"] for job in jobs}) > 0
    exports = []
    replacements = {}
    for job in jobs:
        card_id = job["id"]
        assert card_id != "back" and original[card_id]["assetName"] == job["assetName"]
        if original[card_id].get("artworkVersion") == EDITION:
            raise SystemExit("Card already has accepted v3 artwork; preserve it: " + card_id)
        spec_path = dest / "specs" / f"{card_id}.json"
        spec = json.loads(spec_path.read_text())
        assert spec == job["specification"] and spec["id"] == card_id
        validate_spec(spec)
        review = reviews[card_id]
        assert review["status"] in ("accepted", "accepted-adaptation"), card_id
        assert review["masterSHA256"] == digest(Path(job["master"])), card_id
        assert review["specSHA256"] == digest(spec_path), card_id
        assert Path(job["receiptPath"]).is_file() and Path(job["promptFile"]).is_file()
        tolerance = review.get("aspectRatioTolerance", 0.01)
        if tolerance != 0.01:
            assert review.get("aspectRatioApproval", "").strip(), card_id
        exported = stage(job, args.quality, dest, aspect_ratio_tolerance=tolerance)
        exports.append(exported)
        receipt = json.loads(Path(job["receiptPath"]).read_text())
        replacement = dict(exported, artworkVersion=EDITION, authoredID=job["authoredID"],
                           requiredScene=spec["bookishScene"], requiredSymbols=spec["requiredSymbols"],
                           expectedSuitCount=spec.get("expectedSuitCount"), authoredSpecification=spec,
                           illustratedSubjects=spec["newSubjects"],
                           generationPrompt=Path(job["promptFile"]).read_text(),
                           generationReceipt=receipt, review=review,
                           rwsReferenceSHA256=digest(ROOT / "output/imagegen/unwritten-deck-v1/rws-reference" / f"{card_id}.jpg"))
        if receipt.get("sourceReceipt"):
            replacement["sourceGenerationReceipt"] = json.loads(Path(receipt["sourceReceipt"]).read_text())
        replacements[card_id] = replacement
    write_json(dest / "exports.json", exports)
    cards = [replacements.get(card["id"], card) for card in old_manifest["cards"]]
    count = sum(c.get("artworkVersion") == EDITION for c in cards if c["id"] != "back")
    version = EDITION if count == 78 else EDITION + "-partial"
    manifest = dict(old_manifest, deckVersion=version, revisedFaces=count, heldFaces=78 - count,
                    heldBack=True, cards=cards,
                    styleDirection="docs/unwritten-tarot-wild-library-direction.md",
                    lettering="Authored native text with accessible scene and complete marginalia transcript")
    current_source = source_path.read_text()
    expected_current = native_source(current_source, old_manifest["cards"], old_manifest["deckVersion"])
    if re.search(MARKER, current_source, flags=re.S).group() != re.search(MARKER, expected_current, flags=re.S).group():
        raise SystemExit("Authored native mapping differs from installed manifest; review concurrent changes")
    source = native_source(current_source, cards, version)
    (dest / "Tarot.generated.swift").write_text(source)
    write_json(dest / "manifest.staged.json", manifest)
    if not args.install:
        print(json.dumps(dict(staged=len(exports), installed=False, nativeSource=str(dest / "Tarot.generated.swift"))))
        return
    # Validate the whole catalog and source before changing the first file.
    for relative, expected in baseline["assets"].items():
        if digest(ROOT / relative) != expected:
            raise SystemExit("Concurrent asset edit: " + relative)
    if digest(manifest_path) != baseline["manifestSHA256"] or digest(source_path) != baseline["sourceSHA256"]:
        raise SystemExit("Concurrent manifest or Tarot source edit; refresh and review the batch baseline")
    backup = dest / "baseline"
    backup.mkdir(exist_ok=True)
    shutil.copy2(manifest_path, backup / "manifest.json")
    shutil.copy2(source_path, backup / "Tarot.pre-install.swift")
    for exported in exports:
        target = ROOT / "InsideCoverApp/Assets.xcassets" / (exported["assetName"] + ".imageset/card.jpg")
        shutil.copy2(target, backup / (exported["id"] + ".jpg"))
    for exported in exports:
        target = ROOT / "InsideCoverApp/Assets.xcassets" / (exported["assetName"] + ".imageset/card.jpg")
        shutil.copy2(ROOT / exported["export"], target)
        assert digest(target) == exported["exportSHA256"]
    write_json(manifest_path, manifest)
    source_path.write_text(source)
    receipt = dict(
        deckVersion=version, installedCardIDs=[j["id"] for j in jobs], revisedFaces=count,
        heldFaces=78 - count, heldBack=True, manifestSHA256=digest(manifest_path),
        sourceSHA256=digest(source_path), nativeQA=False, appBuilt=False)
    write_json(dest / "installation-receipt.json", receipt)
    write_json(dest / "validation.json", validate_installed_batch(manifest, exports, baseline))
    refresh_installed_index(manifest, receipt, dest)
    print(json.dumps(dict(installed=len(exports), revisedFaces=count, heldFaces=78 - count,
                          deckVersion=version, appBuilt=False)))


if __name__ == "__main__":
    main()
