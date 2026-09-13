#!/usr/bin/env python3
"""Export the app's marginalia marks and Academy notes for the website.

The site had ten marks and used three of them, so the quiet leaves repeated
every few pages. The app keeps the real shelf in Shared/Illumination.swift,
already sorted into roles by the same registry the folio and the printed
editions read. This exports the marks a leaf can carry on its own and writes a
catalogue the website deals from, so no two leaves wear the same face.

Parts are deliberately left behind. The registry tags eight goblin noses, ears,
a hand and a bare foot as `anatomy`: those are pieces for assembling a goblin,
not marks that stand alone in a margin.

No app build is performed. The deploy script runs this before publishing.
"""
import json
import re
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'InsideCoverApp/Assets.xcassets'
PLATES = ROOT / 'LandingPage/assets/book/marginalia'
NOTES = ROOT / 'LandingPage/assets/book/notes'
CATALOGUE = ROOT / 'LandingPage/marginalia-catalogue.js'

# How wide a mark is ever drawn on the site, doubled for retina.
LONGEST_EDGE = 320
# Notes are pinned wider across a leaf than a mark is.
NOTE_EDGE = 460

FAMILIES = ('Marginalia', 'PunctuationPixie', 'PunctuationCharm')
# The roles a mark can hold, in the order a leaf prefers them.
ROLES = ('portrait', 'fieldNote', 'ornament', 'sigil', 'classic')

source = (ROOT / 'Shared/Illumination.swift').read_text()
entry = re.compile(
    r'themedAsset\("([^"]+)",\s*"([^"]+)",\s*\.(\w+),\s*\[([^\]]*)\],'
    r'\s*([\d.]+),\s*([\d.]+),\s*\.(\w+),')

marks = {}
for slug, asset, _kind, tags, width, height, role in entry.findall(source):
    if not asset.startswith(FAMILIES):
        continue
    tags = [tag.strip().strip('"') for tag in tags.split(',')]
    if 'anatomy' in tags:
        continue
    marks[asset] = dict(id=slug.replace('_', '-'), asset=asset, role=role,
                        w=int(float(width)), h=int(float(height)))

# A handful of older marks predate the registry and the site already leans on
# them. They are whole figures, so they join the deck as `classic`.
for imageset in sorted(ASSETS.glob('Marginalia*.imageset')):
    asset = imageset.name[: -len('.imageset')]
    if asset in marks or re.search(r'Goblin(Ear|Nose|Hand|BareFoot)', asset):
        continue
    with Image.open(next(imageset.glob('*.png'))) as image:
        size = image.size
    slug = re.sub(r'(?<!^)(?=[A-Z])', '-', asset).lower()
    marks[asset] = dict(id=slug, asset=asset, role='classic', w=size[0], h=size[1])

if not marks:
    raise ValueError('Found no marginalia; the registry changed shape.')


def described(mark):
    """An honest alt from the artist's own name for the piece."""
    words = mark['id'].replace('-', ' ')
    for family, lead in (('punctuation pixie', 'The punctuation pixie'),
                         ('punctuation charm', 'A punctuation charm'),
                         ('marginalia goblin', 'A margin goblin'),
                         ('marginalia', 'A margin mark')):
        if words.startswith(family):
            rest = words[len(family):].strip().split()
            # The catalogue names a mood after the part it sits on: "face cross",
            # "wings folded". English wants those the other way round.
            if len(rest) == 2 and rest[0] in ('face', 'wings'):
                rest = [rest[1], rest[0]]
            rest = ' '.join(rest)
            return f'{lead}, {rest}' if rest else lead
    return 'A margin mark, ' + words


PLATES.mkdir(parents=True, exist_ok=True)
written = 0
for mark in marks.values():
    imageset = ASSETS / (mark['asset'] + '.imageset')
    metadata = json.loads((imageset / 'Contents.json').read_text())
    filename = next(image['filename'] for image in metadata['images'] if 'filename' in image)
    origin = imageset / filename
    target = PLATES / (mark['id'] + '.webp')
    if not target.exists() or target.stat().st_mtime < origin.stat().st_mtime:
        with Image.open(origin) as image:
            image = image.convert('RGBA')
            image.thumbnail((LONGEST_EDGE, LONGEST_EDGE))
            image.save(target, 'WEBP', quality=84, method=6)
        written += 1
    with Image.open(target) as image:
        mark['w'], mark['h'] = image.size
    mark['alt'] = described(mark)

# Stale plates would keep being published long after the registry dropped them.
keep = {mark['id'] + '.webp' for mark in marks.values()}
for orphan in PLATES.glob('*.webp'):
    if orphan.name not in keep:
        orphan.unlink()


note_entry = re.compile(r'academy(?:Note|Tip|Warning)Asset\("([^"]+)",\s*"([^"]+)",\s*([\d.]+),\s*([\d.]+),')
notes = {}
for slug, asset, width, height in note_entry.findall(source):
    notes[asset] = dict(id=slug.replace('_', '-'), asset=asset,
                        w=int(float(width)), h=int(float(height)))
if not notes:
    raise ValueError('Found no Academy notes; the registry changed shape.')

NOTES.mkdir(parents=True, exist_ok=True)
for note in notes.values():
    imageset = ASSETS / (note['asset'] + '.imageset')
    metadata = json.loads((imageset / 'Contents.json').read_text())
    filename = next(image['filename'] for image in metadata['images'] if 'filename' in image)
    origin = imageset / filename
    target = NOTES / (note['id'] + '.webp')
    if not target.exists() or target.stat().st_mtime < origin.stat().st_mtime:
        with Image.open(origin) as image:
            image = image.convert('RGBA')
            image.thumbnail((NOTE_EDGE, NOTE_EDGE))
            image.save(target, 'WEBP', quality=84, method=6)
        written += 1
    with Image.open(target) as image:
        note['w'], note['h'] = image.size

keep_notes = {note['id'] + '.webp' for note in notes.values()}
for orphan in NOTES.glob('*.webp'):
    if orphan.name not in keep_notes:
        orphan.unlink()

pinned = [{'id': note['id'], 'src': './assets/book/notes/' + note['id'] + '.webp',
           'w': note['w'], 'h': note['h']}
          for note in sorted(notes.values(), key=lambda n: n['id'])]

deck = []
for role in ROLES:
    for mark in sorted((m for m in marks.values() if m['role'] == role), key=lambda m: m['id']):
        deck.append({'id': mark['id'], 'role': role, 'alt': mark['alt'],
                     'src': './assets/book/marginalia/' + mark['id'] + '.webp',
                     'w': mark['w'], 'h': mark['h']})

CATALOGUE.write_text(
    '// Generated from Shared/Illumination.swift by scripts/sync-web-marginalia.py.\n'
    'window.PublicMarginalia=' + json.dumps({'marks': deck, 'notes': pinned}, indent=1, ensure_ascii=False) + ';\n')

counts = {role: sum(1 for m in deck if m['role'] == role) for role in ROLES}
print('Synced %d marks (%s) and %d Academy notes. %d plates rewritten. No app build.'
      % (len(deck), ', '.join(f'{k} {v}' for k, v in counts.items() if v), len(pinned), written))
