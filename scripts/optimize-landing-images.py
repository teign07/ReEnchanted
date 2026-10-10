#!/usr/bin/env python3
"""Right-size landing raster images after asset syncs; never builds the app.

Keep filenames and transparency intact. Cache by input bytes and policy so a
second publish doesn't repeatedly recompress an already optimized image.
Original app artwork and downloadable PDFs are never modified.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
POLICY = 'landing-v1-1600-q82-samples-q86'


def optimize(site):
    cache = ROOT / 'output/landing-image-cache' / POLICY
    cache.mkdir(parents=True, exist_ok=True)
    registry = cache / 'outputs.json'
    known = set(json.loads(registry.read_text())) if registry.exists() else set()
    before = after = changed = skipped = 0
    for path in sorted((site / 'assets').rglob('*')):
        if path.suffix.lower() not in {'.jpg', '.jpeg', '.png', '.webp'}:
            continue
        source = path.read_bytes()
        before += len(source)
        digest = hashlib.sha256(source).hexdigest()
        if digest in known:
            after += len(source)
            skipped += 1
            continue
        result_path = cache / digest
        if result_path.exists():
            result = result_path.read_bytes()
        else:
            with Image.open(io.BytesIO(source)) as image:
                if getattr(image, 'is_animated', False):
                    after += len(source)
                    continue
                image = ImageOps.exif_transpose(image)
                # Sample Pages contain small print that must survive zooming.
                sample = 'samples' in path.relative_to(site / 'assets').parts
                image.thumbnail((1600, 2000 if sample else 1600), Image.Resampling.LANCZOS)
                fmt = {'.jpg': 'JPEG', '.jpeg': 'JPEG', '.png': 'PNG', '.webp': 'WEBP'}[path.suffix.lower()]
                image = image.convert('RGBA' if 'A' in image.getbands() and fmt != 'JPEG' else 'RGB')
                output = io.BytesIO()
                if fmt == 'PNG':
                    image.save(output, fmt, optimize=True)
                elif fmt == 'JPEG':
                    image.save(output, fmt, quality=86 if sample else 82, optimize=True, progressive=True)
                else:
                    image.save(output, fmt, quality=86 if sample else 82, method=6)
                candidate = output.getvalue()
                # Avoid a quality tradeoff for an insignificant byte saving.
                result = candidate if len(candidate) < len(source) * .85 else source
            result_path.write_bytes(result)
        if result != source:
            path.write_bytes(result)
            changed += 1
        known.add(hashlib.sha256(result).hexdigest())
        after += len(result)
    registry.write_text(json.dumps(sorted(known)))
    print(f'Images: {before / 1048576:.1f} → {after / 1048576:.1f} MB; '
          f'{changed} optimized, {skipped} already optimized. No app build.')
    return {'before': before, 'after': after, 'changed': changed}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--site', type=Path, default=ROOT / 'LandingPage')
    args = parser.parse_args()
    optimize(args.site.resolve())
