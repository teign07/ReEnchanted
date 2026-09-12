#!/usr/bin/env python3
"""Export the app's official cover calendar and optimized plates for the website.

No app build is performed. Run when the Swift catalogue or its artwork changes.
The deployment script runs this before publishing so there is one cover schedule.
"""
import json
import re
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / 'Shared/MonthlyEdition.swift').read_text()
catalogue = source.split('enum PublicationCoverCatalogue {', 1)[1]
plates = {}
for name, body in re.findall(r'static let (\w+) = PublicationCoverPlate\((.*?)\n    \)', catalogue, re.S):
    fields = dict(re.findall(r'(\w+): "([^"]*)"', body))
    fields['includesMatter'] = 'artworkIncludesCoverMatter: true' in body
    plates[name] = fields
schedule = catalogue.split('static let officialMonthlySchedule:', 1)[1].split('\n    ]', 1)[0]
entries = []
for body in re.findall(r'\.init\((.*?)\n        \)', schedule, re.S):
    def field(name):
        match = re.search(r'\b' + name + r':\s*("[^"]*"|\w+)', body)
        if not match:
            raise ValueError('Missing catalogue field: ' + name)
        return match[1].strip('"')
    plate = plates[field('plate')]
    entries.append(dict(year=int(field('year')), month=int(field('month')),
                        subtitle=field('subtitle'), monthLine=field('monthLine'), **plate))
if not entries or len(entries) != schedule.count('.init('):
    raise ValueError('Cover catalogue changed shape; update exporter before publishing.')
fallback = dict(plates['labyrinthOfStories'], subtitle='The month is still gathering ink.', monthLine='Working field book')
destination = ROOT / 'LandingPage/assets/book/covers'
destination.mkdir(parents=True, exist_ok=True)
for plate in [fallback, *entries]:
    asset = ROOT / 'InsideCoverApp/Assets.xcassets' / (plate['assetName'] + '.imageset')
    metadata = json.loads((asset / 'Contents.json').read_text())
    filename = next(image['filename'] for image in metadata['images'] if 'filename' in image)
    target = destination / (plate['id'] + '.webp')
    if not target.exists() or target.stat().st_mtime < (asset / filename).stat().st_mtime:
        with Image.open(asset / filename) as image:
            image = image.convert('RGB')
            image.thumbnail((1300, 1920))
            image.save(target, 'WEBP', quality=88, method=6)
    plate['src'] = './assets/book/covers/' + target.name
    plate['parchmentTitle'] = plate['assetName'] == 'BoundVolumeCoverLabyrinthOfStories'
output = '// Generated from Shared/MonthlyEdition.swift by scripts/sync-web-covers.py.\n'
output += 'window.PublicCoverCatalogue=' + json.dumps(dict(fallback=fallback, schedule=entries), ensure_ascii=False, indent=2) + ';\n'
(ROOT / 'LandingPage/cover-catalogue.js').write_text(output)
print(f'Synced {len(entries)} monthly covers and the app fallback. No app build.')
