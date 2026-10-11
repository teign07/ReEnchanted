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
    # The month's commissioned plates, exactly as the pack ships them. The exporter uses only
    # these real plates in a public issue, never placeholders.
    plates = ROOT / 'ContentPacks/count-unbound/plates'
    if plates.is_dir():
        shutil.rmtree(target / 'plates', ignore_errors=True)
        shutil.copytree(plates, target / 'plates')
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
    # Each sheet is laid out by hand, the way a Reader would: its own paper,
    # its own arrangement, and real app marginalia taped and tucked around the
    # photographs. Elements are drawn in list order, so stains go first and
    # tape goes after the photograph it holds down. x/y are the element's
    # centre and width its share of the canvas, as in PagewrightCanvasElement.
    def photo(ref, x, y, width, rotation): return {'kind': 'photo', 'ref': ref, 'x': x, 'y': y, 'width': width, 'rotation': rotation}
    def mark(ref, x, y, width, rotation): return {'kind': 'mark', 'ref': ref, 'x': x, 'y': y, 'width': width, 'rotation': rotation}
    def scrap(ref, x, y, width, rotation): return {'kind': 'scrap', 'ref': ref, 'x': x, 'y': y, 'width': width, 'rotation': rotation}
    def note(text, style, x, y, width, rotation): return {'kind': 'note', 'ref': text, 'style': style, 'x': x, 'y': y, 'width': width, 'rotation': rotation}
    sheets = [
        {'id': 'floating-home', 'day': 10, 'title': 'A small floating home',
         'note': 'The galley. The window. Things with a place to live.',
         'paper': 'parchment', 'background': 'laidCotton', 'marginalia': 'tornTape',
         'elements': [
             mark('IlluminationStain05', 0.62, 0.96, 0.24, 0),
             photo('selected-02', 0.29, 0.52, 0.44, -4),
             photo('selected-03', 0.71, 0.37, 0.46, 5),
             mark('IlluminationScrapS02_28', 0.27, 0.27, 0.22, -9),
             mark('IlluminationScrapS02_03', 0.92, 0.24, 0.20, 38),
             scrap('682EC52C-F4EE-4BD5-B8B1-EB07D0BA4358', 0.68, 0.72, 0.46, 3),
             scrap('E6B22A06-6D3C-47B4-AB63-8996E9EA1935', 0.33, 0.89, 0.46, -2),
             mark('MarginaliaCompass', 0.90, 0.60, 0.15, 12),
             mark('MarginaliaShell', 0.08, 0.76, 0.12, -18),
             mark('MarginaliaGoblinInkCarrier', 0.86, 0.92, 0.17, 4)]},
        {'id': 'cabin-light', 'day': 20, 'title': 'Room for the light',
         'note': 'A blue curtain, a little lamp, and somewhere to put a book.',
         'paper': 'roseDust', 'background': 'vellum', 'marginalia': 'waxSeal',
         'elements': [
             mark('IlluminationFlourish05', 0.82, 0.22, 0.40, 0),
             photo('selected-05', 0.70, 0.47, 0.40, 4),
             photo('selected-04', 0.27, 0.50, 0.40, -6),
             photo('selected-07', 0.50, 0.80, 0.46, -2),
             mark('IlluminationScrapS03_19', 0.40, 0.68, 0.32, -6),
             scrap('DFCDE322-55B6-48E8-B8C9-B25112F01FE8', 0.80, 0.86, 0.34, 6),
             note('Keep the lamp on', 'sticky', 0.12, 0.80, 0.20, -8),
             mark('MarginaliaGoblinSleeping', 0.14, 0.95, 0.20, 0),
             mark('MarginaliaGoblinRoyalWaxSeal', 0.86, 0.26, 0.13, 10),
             mark('IlluminationFlourish18', 0.90, 0.64, 0.12, 0)]},
        {'id': 'outside-slowly', 'day': 24, 'title': 'Outside, slowly',
         'note': 'Water and the way through the trees. I wanted both.',
         'paper': 'paleTeal', 'background': 'archiveFlecked', 'marginalia': 'inkStars',
         'elements': [
             mark('IlluminationScrapS03_11', 0.30, 0.40, 0.42, -8),
             photo('selected-01', 0.42, 0.36, 0.62, -3),
             photo('selected-06', 0.78, 0.62, 0.36, 6),
             photo('selected-08', 0.33, 0.70, 0.48, 4),
             mark('IlluminationScrapS02_17', 0.42, 0.215, 0.36, 2),
             scrap('1E525384-20E7-4597-A7EB-FA9D83104AF2', 0.30, 0.92, 0.40, -4),
             scrap('E7B3B2B3-6C23-4F6C-B0E2-2CDFB6454C20', 0.74, 0.92, 0.42, 3),
             mark('PunctuationPixieInFlight', 0.88, 0.28, 0.20, 8),
             mark('MarginaliaFeather', 0.06, 0.60, 0.12, -20),
             mark('IlluminationFlourish17', 0.09, 0.33, 0.14, 0),
             mark('MarginaliaLavender', 0.95, 0.88, 0.09, 10)]},
        {'id': 'people-and-pets', 'day': 26, 'title': 'These ones stay',
         'note': 'Together by the water. Together with the animals.',
         'paper': 'cottonCream', 'background': 'rebelWeathered', 'marginalia': 'pressedFlower',
         'elements': [
             photo('selected-09', 0.27, 0.43, 0.38, -5),
             photo('selected-10', 0.70, 0.38, 0.34, 4),
             photo('selected-11', 0.36, 0.76, 0.36, 3),
             photo('selected-12', 0.74, 0.74, 0.36, -4),
             mark('IlluminationScrapS02_28', 0.70, 0.20, 0.20, 6),
             mark('IlluminationScrapS02_03', 0.18, 0.58, 0.18, -35),
             mark('MarginaliaSeal', 0.52, 0.58, 0.12, 0),
             scrap('07941FC9-B688-4E45-8AD8-817FAC189E39', 0.22, 0.97, 0.40, -3),
             mark('IlluminationScrapS02_24', 0.88, 0.95, 0.20, -8),
             mark('PunctuationPixieFaceLaughing', 0.93, 0.55, 0.11, 8),
             mark('MarginaliaStar', 0.07, 0.25, 0.10, 0)]}
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
    known = {photo['id'] for photo in photos}
    for sheet in sheets:
        for element in sheet['elements']:
            if element['kind'] == 'photo' and element['ref'] not in known:
                raise SystemExit(f"{sheet['id']}: unknown photo {element['ref']}")
    print(f'Prepared {len(photos)} photographs and {len(sheets)} Pagewright compositions in {target}')

if __name__ == '__main__':
    main()
