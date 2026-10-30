#!/usr/bin/env python3
"""Check November art integrity and pack wiring without compiling the app."""

from pathlib import Path
import json
import sys

from PIL import Image

REPO = Path(__file__).resolve().parents[1]
PACK = REPO / "ContentPacks/the-guest"
sys.path.insert(0, str(PACK))
sys.path.insert(0, str(REPO / "scripts"))
from content_art import STORY_PLATES  # noqa: E402
from monthly_issue import Issue, PLATE_LIMIT_BYTES  # noqa: E402


def check():
    errors, warnings = [], []
    prompts = json.loads((PACK / "art-prompts.json").read_text())
    issue = Issue(PACK)
    issue.validate()
    runtime = issue.pack
    margins = json.loads((PACK / "margins.reenchantedpack.json").read_text())
    cabinet = margins["marginaliaPack"]
    # EditionPlates derives its slot from the exact suffix after '.plate.'.
    # A version inserted after that marker silently turns a frontispiece into
    # a general plate, even though every media file resolves successfully.
    for brief in prompts["plates"]:
        stem = Path(brief["file"]).stem
        delivery_id = issue.config["plates"]["prefix"] + stem
        if delivery_id.split(".plate.", 1)[-1] != stem:
            errors.append(f"Publication plate cannot resolve its edition slot: {delivery_id}")
    by_id = {asset["id"]: asset for asset in cabinet["doodles"]}
    if len(by_id) != 28:
        errors.append("Expected 28 unique cabinet assets")
    for group in ("plates", "seasonal", "marks"):
        for brief in prompts[group]:
            path = PACK / brief["file"]
            for reference in brief["styleReferences"]:
                if not (REPO / reference).is_file():
                    errors.append(f"Missing art reference: {reference}")
            if not path.is_file():
                errors.append(f"Missing art: {brief['file']}")
                continue
            with Image.open(path) as image:
                image.load()
                if group != "plates":
                    if image.mode != "RGBA" or image.getchannel("A").getextrema() != (0, 255):
                        errors.append(f"Missing alpha: {brief['file']}")
                    elif any(image.getchannel("A").getpixel(point) for point in
                             [(0, 0), (image.width - 1, 0), (0, image.height - 1), (image.width - 1, image.height - 1)]):
                        errors.append(f"Opaque cutout corners: {brief['file']}")
                    if path.stat().st_size > PLATE_LIMIT_BYTES:
                        errors.append(f"Oversize cutout: {brief['file']}")
                else:
                    wanted = tuple(map(int, brief["size"].split("x")))
                    if abs(image.width / image.height - wanted[0] / wanted[1]) > 0.015:
                        errors.append(f"Wrong plate aspect: {brief['file']}")
                    if image.width < wanted[0] or image.height < wanted[1]:
                        warnings.append(f"{brief['file']}: native {image.width}×{image.height}; brief asks {brief['size']}")
                    publication = PACK / issue.config["plates"]["directory"] / (path.stem + ".jpg")
                    if not publication.is_file() or publication.stat().st_size > PLATE_LIMIT_BYTES:
                        errors.append(f"Missing or oversize publication export: {publication.name}")

    scenes = {scene["id"]: scene for scene in runtime["storyScenes"]}
    for name, (node_name, _) in STORY_PLATES.items():
        scene = scenes[f"the-guest.scene.{name}"]
        if scene.get("illustration"):
            errors.append(f"Scene-wide illustration could leak onto branches: {name}")
        attached = [node for node in scene["nodes"] if node.get("illustration")]
        if [node["id"] for node in attached] != [scene["id"] + "." + node_name]:
            errors.append(f"Plate on wrong passage: {name}")
    atoms = {atom["id"]: atom for manifest in runtime["authoringManifests"] for atom in manifest["content"]}
    for mark in runtime["marginalia"]:
        if mark["assetID"] not in by_id or not by_id[mark["assetID"]].get("directedOnly"):
            errors.append(f"Directed mark escapes story gating: {mark['id']}")
        dependencies = atoms[mark["id"]]["dependencies"]
        if not dependencies or any(dep["requiredState"] != "completed" or dep["failurePolicy"] != "wait" for dep in dependencies):
            errors.append(f"Mark can precede its witnessed scene: {mark['id']}")
    for asset_id in issue.references():
        path, _ = issue.media_source(asset_id)
        if not path.is_file():
            errors.append(f"Unresolved delivery reference: {asset_id}")
        elif path.stat().st_size > PLATE_LIMIT_BYTES:
            errors.append(f"Oversize runtime media: {asset_id}")
    for name in ("OfficialCoverPlaceAtTheTableNovember2026", "OfficialCoverTheGuestNovember2026"):
        folder = REPO / "InsideCoverApp/Assets.xcassets" / (name + ".imageset")
        catalog = json.loads((folder / "Contents.json").read_text())
        for entry in catalog["images"]:
            if not (folder / entry["filename"]).is_file():
                errors.append(f"Missing cover catalog image: {name}")

    result = {"errors": errors, "printResolutionWarnings": warnings,
              "runtimeReferences": len(issue.references()), "expectedArtAssets": 48,
              "scope": "Offline source and image integrity; no app build or device rendering"}
    (PACK / "art-review").mkdir(exist_ok=True)
    (PACK / "art-review" / "validation.json").write_text(json.dumps(result, indent=2) + "\n")
    for error in errors:
        print("ERROR:", error)
    print(f"{len(errors)} errors; {len(warnings)} native print-resolution warnings; {len(issue.references())} runtime media references.")
    return not errors


if __name__ == "__main__":
    raise SystemExit(0 if check() else 1)
