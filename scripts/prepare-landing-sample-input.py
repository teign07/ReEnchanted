#!/usr/bin/env python3
"""Prepare isolated Photos exports for the app's public-sample proof seam.

No vault is read, no PDF is simulated, and no app is built by this script.
The original simulated Pages and saved braids remain separate, unchanged inputs.
"""
import argparse
import json
import shutil
from pathlib import Path
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--selection', type=Path, default=ROOT / 'output/sample-editions/photo-selection.json')
    parser.add_argument('--output', type=Path, default=ROOT / 'output/sample-editions/input')
    args = parser.parse_args()
    selection = json.loads(args.selection.read_text())
    target = args.output
    (target / 'photos').mkdir(parents=True, exist_ok=True)
    for source, name in [
        (ROOT / 'docs/fixtures/october-simulation-kept-pages.json', 'october-days.json'),
        (ROOT / 'docs/fixtures/real-braids-october-2026.json', 'real-braids-october-2026.json'),
        (ROOT / 'docs/fixtures/weekly-sample-editorial-notes.json', 'weekly-tale-notes.json'),
        (ROOT / 'ContentPacks/count-unbound/opening.reenchantedevents.json', 'opening.reenchantedevents.json')
    ]:
        shutil.copy2(source, target / name)
    photos = []
    # Reuse photographs across their keeps and composed sheets, as the app does.
    days = [2, 4, 9, 12, 16, 18, 19, 21, 24, 26, 27, 30]
    for item, day in zip(selection['photos'], days, strict=True):
        relative = f"photos/selected-{item['number']:02d}.jpg"
        with Image.open(args.selection.parent / item['file']) as original:
            image = ImageOps.exif_transpose(original).convert('RGB')
            image.thumbnail((1800, 1800), Image.Resampling.LANCZOS)
            # Export the pixels only: original capture dates and GPS do not belong
            # to the simulated Reader's timeline or to the public website.
            image.save(target / relative, quality=90, optimize=True)
        photos.append({'id': f"selected-{item['number']:02d}", 'file': relative,
                       'day': day, 'caption': item['subject']})
    sheets = [
        {'id': 'floating-home', 'day': 10, 'title': 'A small floating home',
         'note': 'The galley. The window. Things with a place to live.',
         'photos': ['selected-02', 'selected-03'],
         'sourceIDs': ['682EC52C-F4EE-4BD5-B8B1-EB07D0BA4358'],
         'marks': ['MarginaliaCompass', 'MarginaliaShell'], 'paper': 'parchment'},
        {'id': 'cabin-light', 'day': 13, 'title': 'Room for the light',
         'note': 'A blue curtain, a little lamp, and somewhere to put a book.',
         'photos': ['selected-04', 'selected-05'], 'sourceIDs': [],
         'marks': ['MarginaliaFeather', 'MarginaliaLavender'], 'paper': 'cottonCream'},
        {'id': 'outside-slowly', 'day': 24, 'title': 'Outside, slowly',
         'note': 'Water and the way through the trees. I wanted both.',
         'photos': ['selected-01', 'selected-06'], 'sourceIDs': [],
         'marks': ['IlluminationScrapS03_10', 'MarginaliaScrap'], 'paper': 'paleTeal'},
        {'id': 'people-and-pets', 'day': 26, 'title': 'These ones stay',
         'note': 'Together by the water. Together with the animals.',
         'photos': ['selected-09', 'selected-10', 'selected-11', 'selected-12'],
         'sourceIDs': [], 'marks': ['IlluminationScrapS03_28', 'IlluminationScrapS03_27'], 'paper': 'cottonCream'}
    ]
    manifest = {'readerName': 'Wren', 'photos': photos, 'sheets': sheets,
                'provenance': 'A simulated October 2026 Reader, saved local-model braids, '
                              'and real photographs selected from the maker’s library. '
                              'The photographs were taken across several years. '
                              'Photo keeps and Pagewright compositions were added for this sample '
                              'after the saved braids; they did not feed those earlier braids.'}
    (target / 'sample.json').write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + '\n')
    required = ['october-days.json', 'real-braids-october-2026.json',
                'weekly-tale-notes.json', 'opening.reenchantedevents.json']
    missing = [name for name in required if not (target / name).is_file()]
    if missing:
        raise SystemExit('Missing original simulation inputs: ' + ', '.join(missing))
    print(f'Prepared {len(photos)} photographs and {len(sheets)} Pagewright compositions in {target}')

if __name__ == '__main__':
    main()
