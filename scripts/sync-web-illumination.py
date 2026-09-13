#!/usr/bin/env python3
"""Export the app's illumination shelf and paper for the website.

The site draws every leaf on one photograph of paper with nothing on it. The app
keeps 49 flourishes, 43 stains, five paper stocks and 33 page tints, and it also
keeps the rules for using them: each mark declares its own opacity, blend mode,
preferred anchors, and whether prose may sit on top of it. Those rules come
across with the pictures, so the website places a mark the way the app would
rather than the way I guessed.

Two things the registry is firm about and this exporter preserves:

  * `allowsTextOverlap` splits the stains in two. Fourteen are watermarks that
    a page may be printed over. The other 29, and all 49 flourishes, must keep
    out of the text.
  * A paper stock belongs to the Page, not the leaf: "Every leaf in one Page
    therefore came from the same bundle of paper." The catalogue carries the
    stocks; the website deals them per chapter, not per leaf.

No app build is performed. The deploy script runs this before publishing.
"""
import json
import re
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'InsideCoverApp/Assets.xcassets'
MARKS = ROOT / 'LandingPage/assets/book/illumination'
STOCKS = ROOT / 'LandingPage/assets/book/stock'
CATALOGUE = ROOT / 'LandingPage/illumination-catalogue.js'

MARK_EDGE = 320       # a flourish is never drawn wider than a leaf margin
STOCK_EDGE = 640      # material maps tile, so they do not need their full 1024

registry = (ROOT / 'Shared/Illumination.swift').read_text()
surfaces = (ROOT / 'InsideCoverApp/BookSurfaceViews.swift').read_text()

# ── the marks, with the placement rules they were registered with ──
entry = re.compile(
    r'asset\(\s*"([^"]+)",\s*"(Illumination(?:Flourish|Stain)\d+)",\s*\.(\w+),'
    r'\s*\[([^\]]*)\]([\s\S]{0,600}?)\)\s*,\s*\n')

marks = []
for match in entry.finditer(registry):
    slug, asset, _kind, tags, tail = match.groups()

    def trait(name):
        found = re.search(name + r':\s*\.?([^,\n\)]+)', tail)
        return found.group(1).strip() if found else None

    anchors = re.search(r'preferredAnchors:\s*\[([^\]]*)\]', tail)
    marks.append(dict(
        id=re.sub(r'(\d+)$', r'-\1', slug).replace('_', '-'),
        asset=asset,
        family='flourish' if 'Flourish' in asset else 'stain',
        role=trait('semanticRole'),
        opacity=float(trait('opacity') or 0.8),
        blend=trait('blend') or 'multiply',
        overlaps=trait('allowsTextOverlap') == 'true',
        anchors=[a.strip().lstrip('.') for a in anchors.group(1).split(',')] if anchors else [],
        tags=[t.strip().strip('"') for t in tags.split(',')]))

if len(marks) < 80:
    raise ValueError('Illumination registry changed shape; found %d marks.' % len(marks))

# ── the paper stocks, named by the app's own enum ──
stock_block = registry.split('enum LeafPaperStock', 1)[1].split('var base', 1)[0]
stocks = [dict(id=re.sub(r'(?<!^)(?=[A-Z])', '-', case).lower(), asset=asset)
          for case, asset in re.findall(r'case \.(\w+): return "(\w+)"', stock_block)]
if not stocks:
    raise ValueError('Could not read LeafPaperStock.')

# ── the page tints: a three-stop paper gradient and an accent per Page type ──
PALETTE = {'gold': (0.72, 0.43, 0.16), 'lampGold': (0.95, 0.73, 0.43),
           'violet': (0.36, 0.19, 0.30), 'page': (0.97, 0.91, 0.78),
           'paper': (0.91, 0.82, 0.64)}


def hexed(literal):
    literal = literal.strip()
    named = re.match(r'BookPalette\.(\w+)', literal)
    channels = re.match(r'Color\(red:\s*([\d.]+),\s*green:\s*([\d.]+),\s*blue:\s*([\d.]+)\)', literal)
    if named and named.group(1) in PALETTE:
        values = PALETTE[named.group(1)]
    elif channels:
        values = [float(v) for v in channels.groups()]
    else:
        return None
    return '#%02x%02x%02x' % tuple(round(v * 255) for v in values)


tints = []
styles = surfaces.split('func style(for type: BookPageType)', 1)[1][:30000]
for block in re.split(r'\n        case ', styles)[1:]:
    types, _, body = block.partition(':')
    fields = {}
    for field in ('paperTop', 'paperMiddle', 'paperBottom', 'accent'):
        found = re.search(field + r':\s*(Color\([^)]*\)|BookPalette\.\w+)', body)
        if found:
            fields[field] = hexed(found.group(1))
    if not all(fields.get(f) for f in ('paperTop', 'paperMiddle', 'paperBottom')):
        continue
    pages = [t.strip().lstrip('.') for t in types.replace('\n', ' ').split(',') if t.strip().startswith('.')]
    tints.append(dict(id=pages[0], pages=pages, top=fields['paperTop'],
                      middle=fields['paperMiddle'], bottom=fields['paperBottom'],
                      accent=fields.get('accent') or fields['paperBottom']))
if len(tints) < 20:
    raise ValueError('Page tint palette changed shape; found %d tints.' % len(tints))


def export(asset, target, longest):
    imageset = ASSETS / (asset + '.imageset')
    metadata = json.loads((imageset / 'Contents.json').read_text())
    filename = next(image['filename'] for image in metadata['images'] if 'filename' in image)
    origin = imageset / filename
    if not target.exists() or target.stat().st_mtime < origin.stat().st_mtime:
        with Image.open(origin) as image:
            image = image.convert('RGBA' if image.mode in ('RGBA', 'LA', 'P') else 'RGB')
            image.thumbnail((longest, longest))
            image.save(target, 'WEBP', quality=82, method=6)
        return True
    return False


MARKS.mkdir(parents=True, exist_ok=True)
STOCKS.mkdir(parents=True, exist_ok=True)
written = 0
for mark in marks:
    target = MARKS / (mark['id'] + '.webp')
    written += export(mark['asset'], target, MARK_EDGE)
    with Image.open(target) as image:
        mark['w'], mark['h'] = image.size
    mark['src'] = './assets/book/illumination/' + mark['id'] + '.webp'
    del mark['asset']
for stock in stocks:
    target = STOCKS / (stock['id'] + '.webp')
    written += export(stock['asset'], target, STOCK_EDGE)
    stock['src'] = './assets/book/stock/' + stock['id'] + '.webp'
    del stock['asset']

for folder, keep in ((MARKS, {m['id'] + '.webp' for m in marks}),
                     (STOCKS, {s['id'] + '.webp' for s in stocks})):
    for orphan in folder.glob('*.webp'):
        if orphan.name not in keep:
            orphan.unlink()

catalogue = {
    # Marks a page may be printed over, and marks that must keep off the prose.
    'watermarks': [m for m in marks if m['overlaps']],
    'edgeMarks': sorted((m for m in marks if not m['overlaps']), key=lambda m: m['id']),
    'stocks': stocks,
    'tints': tints,
}
CATALOGUE.write_text(
    '// Generated from Shared/Illumination.swift and InsideCoverApp/BookSurfaceViews.swift\n'
    '// by scripts/sync-web-illumination.py.\n'
    'window.PublicIllumination=' + json.dumps(catalogue, indent=1, ensure_ascii=False) + ';\n')

print('Synced %d watermarks, %d edge marks, %d paper stocks and %d page tints. '
      '%d plates rewritten. No app build.'
      % (len(catalogue['watermarks']), len(catalogue['edgeMarks']),
         len(stocks), len(tints), written))
