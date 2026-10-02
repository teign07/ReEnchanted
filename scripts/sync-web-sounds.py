#!/usr/bin/env python3
"""Decode the app's existing CAF cues to browser WAVs. Never builds the app."""
import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'InsideCoverApp/BookSounds'
OUTPUT = ROOT / 'LandingPage/assets/sounds'
MANIFEST = OUTPUT / 'manifest.json'
FAMILIES = ('open', 'peek', 'close', 'glowopen', 'turn', 'turnback', 'tap',
            'select', 'keep', 'undo', 'ink', 'confirm', 'toggle')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    app = json.loads((SOURCE / 'manifest.json').read_text())
    previous = json.loads(MANIFEST.read_text()) if MANIFEST.exists() else {}
    OUTPUT.mkdir(parents=True, exist_ok=True)
    counts, sources, files = {}, {}, {}
    converted = 0
    for family in FAMILIES:
        counts[family] = app[family]
        for variant in range(app[family]):
            stem = f'{family}-{variant}'
            source, target = SOURCE / f'{stem}.caf', OUTPUT / f'{stem}.wav'
            sources[stem] = digest(source)
            unchanged = (previous.get('sources', {}).get(stem) == sources[stem]
                         and target.exists()
                         and previous.get('files', {}).get(stem) == digest(target))
            if not unchanged:
                subprocess.run(['afconvert', '-f', 'WAVE', '-d', 'LEI16@44100',
                                '-c', '2', str(source), str(target)], check=True)
                converted += 1
            files[stem] = digest(target)
    manifest = dict(counts=counts, sources=sources, files=files)
    MANIFEST.write_text(json.dumps(manifest, indent=2, sort_keys=True) + '\n')
    catalogue = dict(counts=counts, files={k: v[:12] for k, v in files.items()})
    (ROOT / 'LandingPage/sound-catalogue.js').write_text(
        '/* Exported from the app BookSounds; run scripts/sync-web-sounds.py. */\n'
        + 'window.BookSoundCatalogue = ' + json.dumps(catalogue, sort_keys=True) + ';\n')
    print(f'Synced {len(files)} app sound cues; {converted} WAVs decoded. No app build.')


if __name__ == '__main__':
    main()
