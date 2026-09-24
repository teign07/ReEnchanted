#!/usr/bin/env python3
"""Stage Count Unbound's exact source files and a schema-2 delivery template.

A thin wrapper: everything this issue needs is in issue.json, and staging is
`scripts/monthly_issue.py stage`. This does not sign, upload, publish, or make
unfinished Radio ready.
"""

import argparse
from datetime import datetime, timezone
import importlib.util
import json
from pathlib import Path


ROOT = Path(__file__).parent
_SPEC = importlib.util.spec_from_file_location('monthly_issue', ROOT.parents[1] / 'scripts/monthly_issue.py')
_TOOL = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(_TOOL)

CONFIG = json.loads((ROOT / 'issue.json').read_text())
ISSUE_ID = CONFIG['issueID']
PACK = ROOT / 'opening.reenchantedevents.json'
MARGINS = ROOT / 'margins.reenchantedpack.json'
CASEBOOK = ROOT / 'public-record.reenchantedcasebook.json'
AUDIO = CONFIG['audio']['files']


def media_source(asset_id, audio_root):
    return _TOOL.Issue(ROOT).media_source(asset_id, audio_root)


def stage(output, generated_at, allow_missing_audio=False, audio_root=None):
    try:
        return _TOOL.stage([ROOT], output, generated_at, allow_missing_audio,
                           [audio_root] if audio_root is not None else None)
    except _TOOL.IssueError as error:
        raise ValueError(str(error)) from error


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
