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
THEME = ROOT / 'LandingPage/marginalia-theme.json'
MONTHLY = ROOT / 'LandingPage/assets/book/monthly-marginalia'

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
    # Keep logical asset names stable in the app, but give replacement art a
    # fresh public URL. A source such as MarginaliaShell-v2.png exports as
    # marginalia-shell-v2.webp rather than reusing the cached damaged cutout.
    revision = re.fullmatch(re.escape(mark['asset']) + r'(-v\d+)', Path(filename).stem)
    mark['webFile'] = mark['id'] + (revision[1] if revision else '') + '.webp'
    target = PLATES / mark['webFile']
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
keep = {mark['webFile'] for mark in marks.values()}
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
                     'src': './assets/book/marginalia/' + mark['webFile'],
                     'w': mark['w'], 'h': mark['h']})

# The same monthly pack the app imports supplies the seasonal objects. This
# small selection file is deliberately manual: an unfinished future issue
# must not go public merely because the calendar changed.
seasonal = []
theme = None
selection = json.loads(THEME.read_text()) if THEME.exists() else {}
if selection.get('enabled'):
    def local_path(value):
        path = (ROOT / value).resolve()
        if not path.is_relative_to(ROOT):
            raise ValueError('Monthly marginalia paths must stay in the repository.')
        return path

    pack = json.loads(local_path(selection['pack']).read_text())
    art_directory = local_path(selection['artDirectory'])
    theme = {'id': pack['id'], 'label': pack['displayName']}
    MONTHLY.mkdir(parents=True, exist_ok=True)
    for drawing in pack['marginaliaPack']['doodles']:
        if drawing.get('directedOnly') or 'monthly-content' not in drawing.get('tags', []):
            continue
        asset = re.fullmatch(r'\{\{asset-path:([A-Za-z0-9._-]+)\}\}', drawing['assetName'])
        if not asset:
            raise ValueError('Monthly marginalia must name an immutable pack asset.')
        asset_id = asset[1]
        filename = selection.get('files', {}).get(asset_id, asset_id.rsplit('.', 1)[-1] + '.png')
        origin = (art_directory / filename).resolve()
        if not origin.is_relative_to(art_directory):
            raise ValueError('Monthly drawings must stay in the selected art directory.')
        target = MONTHLY / (asset_id + '.webp')
        if not target.exists() or target.stat().st_mtime < origin.stat().st_mtime:
            with Image.open(origin) as image:
                image = image.convert('RGBA')
                image.thumbnail((LONGEST_EDGE, LONGEST_EDGE))
                image.save(target, 'WEBP', quality=84, method=6)
            written += 1
        with Image.open(target) as image:
            width, height = image.size
        seasonal.append({'id': asset_id, 'role': 'seasonal',
                         'alt': 'A monthly margin drawing, ' + origin.stem.replace('-', ' '),
                         'src': './assets/book/monthly-marginalia/' + target.name,
                         'w': width, 'h': height})
    if not seasonal:
        raise ValueError('The selected pack has no monthly marginalia to export.')

if MONTHLY.exists():
    keep_monthly = {mark['id'] + '.webp' for mark in seasonal}
    for orphan in MONTHLY.glob('*.webp'):
        if orphan.name not in keep_monthly:
            orphan.unlink()

CATALOGUE.write_text(
    '// Generated from Shared/Illumination.swift by scripts/sync-web-marginalia.py.\n'
    'window.PublicMarginalia=' + json.dumps({'marks': deck, 'notes': pinned, 'theme': theme, 'seasonal': seasonal}, indent=1, ensure_ascii=False) + ';\n')

counts = {role: sum(1 for m in deck if m['role'] == role) for role in ROLES}
print('Synced %d marks (%s) and %d Academy notes. %d plates rewritten. No app build.'
      % (len(deck), ', '.join(f'{k} {v}' for k, v in counts.items() if v), len(pinned), written))
if theme:
    print('Monthly marginalia: %s — %d drawings.' % (theme['label'], len(seasonal)))
