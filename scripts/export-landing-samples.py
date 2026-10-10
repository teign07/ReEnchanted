#!/usr/bin/env python3
"""Package actual app-exported sample PDFs for the website's Page reader.

Run after --public-sample-editions succeeds. This copies the app PDFs unchanged,
renders their Pages, and publishes only a deliberately chosen source-page set.
"""
import argparse
import hashlib
import json
import shutil
import subprocess
import tempfile
from pathlib import Path
from PIL import Image, ImageDraw
from pypdf import PdfReader

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--proof-directory', type=Path, required=True)
    parser.add_argument('--output', type=Path, default=ROOT / 'LandingPage/assets/samples')
    parser.add_argument('--pdftoppm', default='pdftoppm')
    args = parser.parse_args()
    proof = args.proof_directory
    status = (proof / 'status.txt').read_text()
    if not status.startswith('OK public samples:'):
        raise SystemExit('App sample export has not succeeded: ' + status)
    sample = json.loads((proof / 'sample.json').read_text())
    sources = json.loads((proof / 'sample-source.json').read_text())
    pages_by_id = {page['id']: page for day in sources for page in day['pages']}
    expected_braids = json.loads((ROOT / 'docs/fixtures/real-braids-october-2026.json').read_text())
    for night in expected_braids:
        actual = pages_by_id['real-braid-' + night['day']]
        if actual['userInput'] != night['body'] or actual['tags'] != night['tags']:
            raise SystemExit('Saved braid changed: ' + night['day'])
    # Refuse any unresolved placeholder photo reference in the actual export.
    for page in pages_by_id.values():
        for asset in page.get('mediaAssets', []):
            if asset['kind'] == 'renderedImageFile' and not Path(asset['reference']).is_file():
                raise SystemExit('Missing kept media: ' + asset['reference'])
    destination = args.output
    destination.mkdir(parents=True, exist_ok=True)
    catalogue = {'provenance': sample['provenance'], 'issues': {}, 'keptPages': [], 'pagewright': []}
    descriptions = {
        'weekly': ('The week · October 22–28', 'Seven saved nights, the Reader’s keeps, and two composed Pagewright sheets.'),
        'monthly': ('The month · October 2026', 'Count Unbound, thirty-one saved nights, the month’s keeps, and four composed Pagewright sheets.')
    }
    audit = ROOT / 'output/sample-editions/review'
    audit.mkdir(parents=True, exist_ok=True)
    for kind, name in [('weekly', 'weekly-issue.pdf'), ('monthly', 'monthly-edition.pdf')]:
        pdf = proof / name
        digest = hashlib.sha256(pdf.read_bytes()).hexdigest()
        reader = PdfReader(pdf)
        if not reader.pages:
            raise SystemExit('Empty PDF: ' + name)
        text = '\n'.join(page.extract_text() or '' for page in reader.pages)
        if 'PLATE ·' in text:
            raise SystemExit('A placeholder illustration reached ' + name)
        shutil.copy2(pdf, destination / name)
        page_dir = destination / kind
        page_dir.mkdir(exist_ok=True)
        # A previous export may have had more Pages; do not leave orphan leaves.
        for stale in page_dir.glob('page-*.webp'):
            stale.unlink()
        with tempfile.TemporaryDirectory(prefix='reenchanted-sample-render-') as temporary:
            prefix = Path(temporary) / 'page'
            subprocess.run([args.pdftoppm, '-scale-to', '1260', '-jpeg', '-jpegopt', 'quality=94', str(pdf), str(prefix)], check=True)
            rendered = sorted(Path(temporary).glob('page-*.jpg'))
            if len(rendered) != len(reader.pages):
                raise SystemExit('PDF render count differs from PDF page count')
            pages = []
            for index, file in enumerate(rendered):
                filename = f'page-{index + 1:03d}.webp'
                with Image.open(file) as image:
                    image.convert('RGB').save(page_dir / filename, 'WEBP', quality=86, method=6)
                pages.append({'image': f'./assets/samples/{kind}/{filename}?v={digest[:12]}',
                              'text': reader.pages[index].extract_text() or ''})
            # Every Page appears on a numbered review sheet, in addition to
            # the full-size browser images. Inspect these before deployment.
            for start in range(0, len(rendered), 12):
                canvas = Image.new('RGB', (1080, 4 * 562), '#d8cab1')
                draw = ImageDraw.Draw(canvas)
                for offset, file in enumerate(rendered[start:start + 12]):
                    with Image.open(file) as image:
                        image.thumbnail((340, 526), Image.Resampling.LANCZOS)
                        x, y = (offset % 3) * 360 + 10, (offset // 3) * 562 + 26
                        canvas.paste(image, (x, y))
                        draw.text((x, y - 19), f'{kind} · Page {start + offset + 1}', fill='#38291e')
                canvas.save(audit / f'{kind}-review-{start // 12 + 1:02d}.jpg', quality=92)
        title, description = descriptions[kind]
        catalogue['issues'][kind] = {'title': title, 'description': description,
            'pdf': f'./assets/samples/{name}?v={digest[:12]}', 'sizeLabel': f'{pdf.stat().st_size / 1_000_000:.1f} MB',
            'sha256': digest, 'pages': pages}
        catalogue['issues'][kind]['braidPage'] = next((index + 1 for index, page in enumerate(pages)
            if 'Learned the name of the bakery cat after work.' in page['text']), None)
    selected = json.loads((ROOT / 'docs/fixtures/landing-braid-example-october-2026.json').read_text())
    for page in [selected['earlierPage'], *selected['pages']]:
        if pages_by_id[page['id']]['userInput'] != page['userInput']:
            raise SystemExit('Original landing receipt changed: ' + page['id'])
        kind = 'Book-authored fiction' if page['origin'] == 'generated' else 'Simulated Reader’s own words'
        catalogue['keptPages'].append({'label': f"{page.get('day', selected['day'])} · {kind}", 'text': page['userInput']})
    for sheet in sample['sheets']:
        image_path = proof / f"pagewright-{sheet['id']}.png"
        target = f"pagewright-{sheet['id']}.webp"
        with Image.open(image_path) as image:
            image.save(destination / target, 'WEBP', quality=90, method=6)
        digest = hashlib.sha256(image_path.read_bytes()).hexdigest()
        catalogue['pagewright'].append({'title': sheet['title'], 'image': './assets/samples/' + target + '?v=' + digest[:12],
            'alt': f"{sheet['title']}: an actual Pagewright sheet with {sum(e['kind'] == 'photo' for e in sheet['elements'])} selected photographs, app marginalia, and kept scraps."})
    (destination / 'catalogue.json').write_text(json.dumps(catalogue, ensure_ascii=False, indent=2) + '\n')
    counts = {kind: len(value['pages']) for kind, value in catalogue['issues'].items()}
    print(json.dumps({'pages': counts, 'output': str(destination), 'review': str(audit)}, indent=2))

if __name__ == '__main__':
    main()
