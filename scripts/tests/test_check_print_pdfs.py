"""In-memory PDF fixtures: no files are printed, uploaded, or rewritten."""
import importlib.util
import io
from pathlib import Path
import unittest

from pypdf import PdfWriter
from pypdf.generic import DictionaryObject, NameObject, DecodedStreamObject, RectangleObject

spec = importlib.util.spec_from_file_location('preflight', Path(__file__).parents[1] / 'check_print_pdfs.py')
preflight = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preflight)


def pdf(pages=2, size=(450, 666), encrypt=False, rotate=False, crop=False, font=None, form=False):
    writer = PdfWriter()
    for _ in range(pages):
        page = writer.add_blank_page(*size)
        if rotate:
            page.rotate(90)
        if crop:
            page.cropbox = RectangleObject([9, 9, size[0] - 9, size[1] - 9])
        if font:
            unembedded = DictionaryObject({NameObject('/Type'): NameObject('/Font'), NameObject('/Subtype'): NameObject('/Type1'), NameObject('/BaseFont'): NameObject('/Helvetica')})
            resources = DictionaryObject({NameObject('/Font'): DictionaryObject({NameObject('/F1'): writer._add_object(unembedded)})})
            content = DecodedStreamObject()
            content.set_data(b'BT /F1 12 Tf 10 10 Td (PRIVATE MANUSCRIPT) Tj ET' if font == 'used' else b'BT /F1 12 Tf ET')
            if form:
                content.update({NameObject('/Type'): NameObject('/XObject'), NameObject('/Subtype'): NameObject('/Form'),
                                NameObject('/BBox'): RectangleObject([0, 0, 100, 100]), NameObject('/Resources'): resources})
                page[NameObject('/Resources')] = DictionaryObject({NameObject('/XObject'): DictionaryObject({NameObject('/Fm1'): writer._add_object(content)})})
                outer = DecodedStreamObject(); outer.set_data(b'/Fm1 Do')
                page[NameObject('/Contents')] = writer._add_object(outer)
            else:
                page[NameObject('/Resources')] = resources
                page[NameObject('/Contents')] = writer._add_object(content)
    if encrypt:
        writer.encrypt('private-password')
    output = io.BytesIO(); writer.write(output)
    return output.getvalue()


def quote():
    return {'request': {'pageCount': 2, 'variant': {'luluPackageID': '0600X0900.FC.STD.PB.060UW444.MXX'}},
            'coverDimensions': {'widthPoints': 892, 'heightPoints': 666}, 'checkoutToken': 'PRIVATE CAPABILITY',
            'shippingAddress': 'PRIVATE ADDRESS'}


class PrintPDFTests(unittest.TestCase):
    def check(self, interior=None, cover=None, saved=None):
        return preflight.check_pair(interior or pdf(), cover or pdf(1, (892, 666)), saved or quote())

    def codes(self, report):
        return {e['code'] for f in report['files'] for e in f['errors']}

    def test_quote_matched_pair_never_claims_visual_or_provider_proof(self):
        report = self.check()
        self.assertTrue(report['structuralChecksPassed'])
        self.assertFalse(report['visualProofPassed'])
        self.assertFalse(report['providerValidationPerformed'])
        self.assertNotIn('PRIVATE', str(report))

    def test_interior_count_must_match_quote(self):
        self.assertIn('page_count_mismatch', self.codes(self.check(interior=pdf(3))))

    def test_cover_must_be_one_spread(self):
        self.assertIn('page_count_mismatch', self.codes(self.check(cover=pdf(2, (892, 666)))))

    def test_trim_only_interior_is_missing_bleed(self):
        self.assertIn('page_size_mismatch', self.codes(self.check(interior=pdf(size=(432, 648)))))

    def test_cover_must_use_provider_width(self):
        self.assertIn('page_size_mismatch', self.codes(self.check(cover=pdf(1, (890, 666)))))

    def test_encrypted_pdf_is_rejected(self):
        self.assertIn('encrypted_pdf', self.codes(self.check(interior=pdf(encrypt=True))))

    def test_cropped_or_rotated_pages_require_review(self):
        self.assertIn('crop_box_differs_from_media_box', self.codes(self.check(interior=pdf(crop=True))))
        self.assertIn('page_transform_requires_review', self.codes(self.check(interior=pdf(rotate=True))))

    def test_only_fonts_actually_used_for_text_are_required(self):
        self.assertIn('used_font_not_embedded', self.codes(self.check(interior=pdf(font='used'))))
        self.assertTrue(self.check(interior=pdf(font='unused'))['structuralChecksPassed'])

    def test_nested_form_fonts_are_checked_without_leaking_text(self):
        report = self.check(interior=pdf(font='used', form=True))
        self.assertIn('used_font_not_embedded', self.codes(report))
        self.assertNotIn('PRIVATE', str(report))

    def test_malformed_pdf_fails_without_echoing_input(self):
        report = self.check(interior=b'%PDF-1.7\nPRIVATE MANUSCRIPT')
        self.assertFalse(report['structuralChecksPassed'])
        self.assertNotIn('PRIVATE', str(report))

    def test_cover_dimensions_cannot_be_estimated_or_nonfinite(self):
        for dimensions in [None, {'widthPoints': float('nan'), 'heightPoints': 666}]:
            q = quote(); q['coverDimensions'] = dimensions
            with self.assertRaises((ValueError, TypeError)):
                self.check(saved=q)

    def test_saved_rehearsal_wrapper_is_supported(self):
        self.assertTrue(self.check(saved={'quote': quote()})['structuralChecksPassed'])


if __name__ == '__main__':
    unittest.main()
