#!/usr/bin/env python3
"""Local, read-only structural check against a saved ReEnchanted printer quote.

No network, manuscript text, addresses, payment secrets or capability URLs are
included in the report. A pass is not visual QA or Lulu manufacturing approval.
Requires pypdf. CLI exits 0 for structural pass, 1 for findings, 2 for invalid input.
"""
import argparse
import hashlib
import io
import json
import logging
import math
from pathlib import Path

from pypdf import PdfReader
from pypdf.generic import ContentStream

# Parser diagnostics may include source bytes. Findings below use fixed codes.
_pdf_log = logging.getLogger('pypdf')
_pdf_log.handlers = [logging.NullHandler()]
_pdf_log.propagate = False

TOLERANCE_PT = 0.1
MAX_BYTES = 100 * 1024 * 1024


def obj(value):
    return value.get_object() if hasattr(value, 'get_object') else value


def quote_expectations(payload):
    quote = payload.get('quote', payload)
    request = quote['request']
    count = request['pageCount']
    if type(count) is not int or not 1 <= count <= 800:
        raise ValueError('invalid quoted page count')
    # All currently offered ReEnchanted bindings use this trim. Never infer a
    # cover width from page count; only use the provider's returned dimensions.
    if not request['variant']['luluPackageID'].startswith('0600X0900.'):
        raise ValueError('unsupported trim size')
    dimensions = quote['coverDimensions']
    width, height = dimensions['widthPoints'], dimensions['heightPoints']
    if any(type(n) not in (int, float) or not math.isfinite(n) or n <= 0 for n in (width, height)):
        raise ValueError('invalid quoted cover dimensions')
    return {'interiorPages': count, 'interiorSizePoints': [450, 666], 'coverSizePoints': [width, height]}


def used_fonts(stream, resources, reader, active=None, depth=0):
    """Follow text actually painted and Form XObjects, ignoring unused fonts."""
    if stream is None:
        return []
    if depth > 30:
        raise ValueError('resource recursion limit')
    active = set() if active is None else active
    stream = obj(stream)
    marker = id(stream)
    if marker in active:
        raise ValueError('cyclic form resources')
    active.add(marker)
    fonts, stack, current = [], [], None
    resources = obj(resources) or {}
    try:
        content = ContentStream(stream, reader)
        for operands, operator in content.operations:
            if operator == b'q':
                stack.append(current)
            elif operator == b'Q':
                current = stack.pop() if stack else None
            elif operator == b'Tf':
                current = operands[0]
            elif operator in (b'Tj', b'TJ', b"'", b'"'):
                font = obj(obj(resources.get('/Font', {})).get(current))
                fonts.append(font)
            elif operator == b'Do':
                form = obj(obj(resources.get('/XObject', {})).get(operands[0]))
                if form and form.get('/Subtype') == '/Form':
                    fonts.extend(used_fonts(form, form.get('/Resources', resources), reader, active, depth + 1))
        return fonts
    finally:
        active.remove(marker)


def embedded(font):
    if not font:
        return False
    if font.get('/Subtype') == '/Type0':
        descendants = obj(font.get('/DescendantFonts', []))
        return bool(descendants) and all(embedded(obj(f)) for f in descendants)
    if font.get('/Subtype') == '/Type3':
        return bool(obj(font.get('/CharProcs', {})))
    descriptor = obj(font.get('/FontDescriptor', {}))
    return any(key in descriptor and bool(obj(descriptor[key]).get_data())
               for key in ('/FontFile', '/FontFile2', '/FontFile3'))


def inspect_pdf(data, role, expected_pages, expected_size):
    result = {'role': role, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(), 'errors': []}
    errors = result['errors']
    if not data or len(data) > MAX_BYTES:
        errors.append({'code': 'invalid_file_size'})
        return result
    try:
        reader = PdfReader(io.BytesIO(data), strict=True)
        if reader.is_encrypted:
            errors.append({'code': 'encrypted_pdf'})
            return result
        result['pages'] = len(reader.pages)
        if len(reader.pages) != expected_pages:
            errors.append({'code': 'page_count_mismatch', 'expected': expected_pages, 'actual': len(reader.pages)})
        if len(reader.pages) > 800:
            errors.append({'code': 'page_limit_exceeded'})
            return result
        for number, page in enumerate(reader.pages, 1):
            box = page.mediabox
            actual = [float(box.width), float(box.height)]
            if any(not math.isfinite(n) or abs(n - want) > TOLERANCE_PT for n, want in zip(actual, expected_size)):
                errors.append({'code': 'page_size_mismatch', 'page': number, 'expected': expected_size, 'actual': [n if math.isfinite(n) else None for n in actual]})
            if page.rotation % 360 != 0 or float(page.get('/UserUnit', 1)) != 1:
                errors.append({'code': 'page_transform_requires_review', 'page': number})
            # A smaller CropBox may hide bleed during rendering even when the
            # MediaBox dimensions appear correct.
            if any(not math.isfinite(float(a)) or abs(float(a) - float(b)) > TOLERANCE_PT for a, b in zip(page.cropbox, box)):
                errors.append({'code': 'crop_box_differs_from_media_box', 'page': number})
            if any(obj(a).get('/Subtype') == '/Widget' for a in obj(page.get('/Annots', []))):
                errors.append({'code': 'interactive_form_requires_flattening', 'page': number})
            fonts = used_fonts(page.get_contents(), page.get('/Resources'), reader)
            if any(not embedded(font) for font in fonts):
                errors.append({'code': 'used_font_not_embedded', 'page': number})
    except Exception:
        # Parser errors can contain input bytes or object strings. Do not log
        # the original exception, metadata or extracted manuscript text.
        errors.append({'code': 'pdf_could_not_be_fully_checked'})
    return result


def check_pair(interior, cover, quote):
    expected = quote_expectations(quote)
    files = [inspect_pdf(interior, 'interior', expected['interiorPages'], expected['interiorSizePoints']),
             inspect_pdf(cover, 'cover', 1, expected['coverSizePoints'])]
    return {'schemaVersion': 1, 'structuralChecksPassed': all(not f['errors'] for f in files),
            'visualProofPassed': False, 'providerValidationPerformed': False, 'expectations': expected, 'files': files,
            'remainingChecks': ['Visual layout, bleed artwork and safety margins',
                                'Image resolution, transparency and color reproduction',
                                'Narrative/page ordering and cover/spine/foil placement',
                                'Lulu validation and physical proof']}


def bounded_read(path):
    with Path(path).open('rb') as stream:
        return stream.read(MAX_BYTES + 1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--quote', required=True, help='Saved server quote JSON, or rehearsal state containing quote')
    parser.add_argument('--interior', required=True)
    parser.add_argument('--cover', required=True)
    parser.add_argument('--report', help='Optional JSON report file; input PDFs are never modified')
    args = parser.parse_args()
    try:
        report = check_pair(bounded_read(args.interior), bounded_read(args.cover), json.loads(bounded_read(args.quote)))
    except Exception:
        print(json.dumps({'error': 'invalid_input', 'message': 'Check the PDF paths and saved quote with exact cover dimensions.'}))
        return 2
    rendered = json.dumps(report, indent=2, allow_nan=False) + '\n'
    if args.report:
        output = Path(args.report).resolve()
        inputs = [Path(p).resolve() for p in (args.quote, args.interior, args.cover)]
        if output in inputs or (output.exists() and any(output.samefile(p) for p in inputs)):
            print(json.dumps({'error': 'report_would_overwrite_input'}))
            return 2
        try:
            output.write_text(rendered)
        except OSError:
            print(json.dumps({'error': 'report_could_not_be_saved'}))
            return 2
    print(rendered, end='')
    return 0 if report['structuralChecksPassed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
