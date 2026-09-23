#!/usr/bin/env python3
"""Stage Count Unbound's exact source files and a schema-2 delivery template.

This does not sign, upload, publish, or make unfinished Radio ready.
"""

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import shutil
import tempfile


ROOT = Path(__file__).parent
ISSUE_ID = "count-unbound-2026-10"
PACK = ROOT / "opening.reenchantedevents.json"
MARGINS = ROOT / "margins.reenchantedpack.json"
CASEBOOK = ROOT / "public-record.reenchantedcasebook.json"
AUDIO = {
    "count-unbound.audio.thornwave-corners": "DJ_thornwave_count_unbound_corners_01.mp3",
    "count-unbound.audio.four-came-home": "DJ_mothlight_count_unbound_four_home_01.mp3",
    "count-unbound.audio.serenity-awake": "DJ_faefi_count_unbound_serenity_awake_01.mp3",
    "count-unbound.audio.wicker-one-sentence": "DJ_thornwave_count_unbound_one_sentence_01.mp3",
    "count-unbound.audio.protocols": "DJ_faefi_count_unbound_protocols_01.mp3",
}


def references(path):
    return set(re.findall(r"\{\{asset-path:([^}]+)\}\}", path.read_text()))


def media_source(asset_id, audio_root):
    if asset_id in AUDIO:
        return audio_root / AUDIO[asset_id], ".mp3"
    if asset_id.startswith("count-unbound.mark."):
        return ROOT / "marginalia" / (asset_id.removeprefix("count-unbound.mark.") + ".png"), ".png"
    if asset_id.startswith("count-unbound.seasonal."):
        return ROOT / "seasonal-marginalia" / (asset_id.removeprefix("count-unbound.seasonal.") + ".png"), ".png"
    raise ValueError(f"Unmapped media ID: {asset_id}")


def stage(output, generated_at, allow_missing_audio=False, audio_root=None):
    output = Path(output).absolute()
    audio_root = Path(audio_root) if audio_root is not None else ROOT / "audio"
    if output.exists() or output.is_symlink():
        raise ValueError(f"Refusing to overwrite {output}")
    if not output.parent.is_dir():
        raise ValueError(f"Missing output parent: {output.parent}")
    pack = json.loads(PACK.read_text())
    casebook = json.loads(CASEBOOK.read_text())
    if pack["id"] != casebook["packID"] or casebook["runID"] != "count-unbound:2026":
        raise ValueError("Casebook does not match the October run")
    refs = references(PACK) | references(MARGINS)
    if refs & set(AUDIO) != set(AUDIO):
        raise ValueError("The Radio media references differ from the recording sheet")
    missing_audio = sorted(asset_id for asset_id in AUDIO if not media_source(asset_id, audio_root)[0].is_file())
    if missing_audio and not allow_missing_audio:
        raise ValueError("Missing recordings: " + ", ".join(missing_audio))
    stage_dir = Path(tempfile.mkdtemp(prefix=".count-release-", dir=output.parent))
    try:
        sources = stage_dir / "sources" / ISSUE_ID
        sources.mkdir(parents=True)
        assets = []

        def add(asset_id, kind, scope, source, filename):
            if not source.is_file():
                if allow_missing_audio and asset_id in AUDIO:
                    pass
                else:
                    raise ValueError(f"Missing source for {asset_id}: {source}")
            else:
                shutil.copyfile(source, sources / filename)
            assets.append(dict(id=asset_id, kind=kind, scope=scope,
                               fileName=filename, isRequired=True))

        add("count-unbound.runtime.v1", "worldEventPack", "runtime", PACK,
            "count-unbound.reenchantedevents.json")
        add("count-unbound.margins.v1", "pageArchetypePack", "runtime", MARGINS,
            "count-unbound.reenchantedpack.json")
        for asset_id in sorted(refs):
            source, suffix = media_source(asset_id, audio_root)
            add(asset_id, "media", "runtime", source, asset_id + suffix)
        add("count-unbound.casebook.public-record", "casebook", "casebook", CASEBOOK,
            "count-unbound.reenchantedcasebook.json")
        manifest = {
            "schemaVersion": 2,
            "generatedAt": generated_at,
            "allowedAssetHosts": [],
            "issues": [{
                "id": ISSUE_ID,
                "packID": pack["id"],
                "title": "The Count Unbound",
                "foreshadowStartsAt": "2026-09-24T00:00:00Z",
                "liveStartsAt": "2026-10-01T00:00:00Z",
                "liveEndsAt": "2026-11-01T00:00:00Z",
                "residueEndsAt": "2026-11-08T00:00:00Z",
                "casebookAvailableAt": casebook["publishedAt"],
                "assets": assets,
            }],
        }
        (stage_dir / "delivery-template.json").write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
        (stage_dir / "missing-recordings.json").write_text(
            json.dumps(missing_audio, indent=2) + "\n")
        stage_dir.rename(output)
    except BaseException:
        shutil.rmtree(stage_dir)
        raise
    return len(assets), missing_audio


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--generated-at", default=datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z"))
    parser.add_argument("--allow-missing-audio", action="store_true")
    args = parser.parse_args()
    try:
        assets, missing = stage(args.output, args.generated_at, args.allow_missing_audio)
    except (OSError, ValueError, KeyError) as error:
        parser.exit(1, f"Count release draft refused: {error}\n")
    print(f"Staged {assets} declared assets. Missing recordings: {len(missing)}. Nothing signed or uploaded.")


if __name__ == "__main__":
    main()
