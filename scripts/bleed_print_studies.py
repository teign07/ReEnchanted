#!/usr/bin/env python3
"""Independent typography studies, never proof of the native Swift PDF writer.

Uses its shared numeric print spec and actual authored content-bank passages.
Reader ink and Book readings below are explicitly synthetic, authored fixtures.
Run with the bundled document Python; no app or Swift build is involved.
"""
from pathlib import Path
import json
import re
from xml.sax.saxutils import escape
from reportlab.platypus import BaseDocTemplate, Frame, PageTemplate, Paragraph, Spacer, KeepTogether
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.colors import HexColor
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from pypdf import PdfReader

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'output' / 'pdf'
OUT.mkdir(parents=True, exist_ok=True)
swift = (ROOT / 'Shared' / 'TheBleed.swift').read_text()
spec_source = swift.split('enum BleedPrintDesign {', 1)[1].split('static func edition', 1)[0]
spec = {name: float(value) for name, value in re.findall(r'static let (\w+) = ([\d.]+)', spec_source)}
W, H, M, G = (spec[k] for k in ['pageWidth', 'pageHeight', 'margin', 'gutter'])
WIDTH, COL = W - 2 * M, (W - 2 * M - G) / 2
FONT_DIR = Path('/System/Library/Fonts/Supplemental')
for name, filename in [('Bleed', 'Georgia.ttf'), ('Bleed-Bold', 'Georgia Bold.ttf'),
                       ('Bleed-Italic', 'Georgia Italic.ttf'), ('Bleed-BoldItalic', 'Georgia Bold Italic.ttf')]:
    pdfmetrics.registerFont(TTFont(name, str(FONT_DIR / filename)))
pdfmetrics.registerFontFamily('Bleed', normal='Bleed', bold='Bleed-Bold', italic='Bleed-Italic', boldItalic='Bleed-BoldItalic')
INK = HexColor('#171717')
pack = json.loads((ROOT / 'ContentPacks/count-unbound/opening.reenchantedevents.json').read_text())
articles = {article['id'].rsplit('.', 1)[-1]: article for article in pack['bleedArticles']}
pulse = pack['events'][0]['phases'][1]['pulses'][0]['text']
old = 'The gate still catches. I lift it before I turn the key.'
new = 'I fixed the gate after lunch. For once, it shut without being lifted.'
question = 'THE PORTRAIT SAID PENNY IS LYING. Punctuate this twice: once so the portrait accuses Penny, once so Penny accuses the portrait. Keep every word in order.'
answer = 'The portrait said, ‘Penny is lying.’ Or: ‘The portrait,’ said Penny, ‘is lying.’ Same words, different accuser. Please check the quotation marks before duelling.'
# These appear verbatim in the authored shipping banks, not model-generated news.
assert question in swift and answer in swift
miniature = re.search(r'\("spare", "The spare", "([^"]+)"\)', swift).group(1)
ad = 'WANTED: A less suspicious word than ‘moist’. Must be willing to work beside cake.'
assert ad in swift

fixtures = {
    'morning': [
        dict(title=articles['jump-complete']['title'], byline=articles['jump-complete']['byline'], body=articles['jump-complete']['body']),
        dict(title='The notice is getting shorter', byline='from the Academy', body=pulse),
        dict(title="A line I wouldn't let go", byline='your words; a reading by the Book',
             quote=f'Your Page · 13 Oct 2026\n“{old}”',
             body="I keep catching on ‘before’. The gate gets its small lift before the key can do anything. I read a whole little negotiation in that order: lift first, turn second. The sentence makes me wait at the latch."),
        dict(title='The small puzzle', byline='the puzzle desk', body=question + '\n\nAnswer in the evening paper.'),
        dict(title='The small ads', byline='an unreasonable correspondence', body=ad),
    ],
    'evening': [
        dict(title=articles['east-stacks']['title'], byline=articles['east-stacks']['byline'], body=articles['east-stacks']['body']),
        dict(title='Two lines, side by side', byline='your words; a reading by the Book',
             quote=f'Your Page · 13 Oct 2026\n“{old}”\n\nYour Page · 16 Oct 2026\n“{new}”',
             body="I read the gate changing jobs between these lines. First it makes you lift; then it gets to shut. ‘For once’ leaves the old nuisance rattling inside the new sentence. Those two small words have kept the squeak."),
        dict(title='The answer, unfolded', byline='the puzzle desk', body=answer),
        dict(title='The spare', byline='a very short fiction', body=miniature),
    ]
}


def safe(text):
    return escape(text).replace('\n', '<br/>')


def make(kind, features, path, stress=False):
    accent = HexColor('#1e4c51' if kind == 'morning' else '#6b1e2e')
    body = ParagraphStyle('Body', fontName='Bleed', fontSize=spec['bodySize'], leading=spec['bodyLeading'],
                          textColor=INK, spaceAfter=8, splitLongWords=True)
    title = ParagraphStyle('Title', parent=body, fontName='Bleed-Bold', fontSize=15, leading=18, spaceBefore=10, spaceAfter=5, keepWithNext=True)
    byline = ParagraphStyle('Byline', parent=body, fontName='Bleed-Italic', fontSize=8.5, leading=11, textColor=accent, spaceAfter=7, keepWithNext=True)
    quote = ParagraphStyle('Quote', parent=body, fontName='Bleed-Italic', fontSize=12, leading=16, spaceAfter=9)
    lead_style = ParagraphStyle('Lead', parent=title, fontSize=25, leading=29, spaceBefore=0)
    lead = Paragraph(safe(features[0]['title']), lead_style)
    _, lead_height = lead.wrap(WIDTH, H)
    lead_byline = Paragraph(safe(features[0]['byline']), byline)
    _, byline_height = lead_byline.wrap(WIDTH, H)
    top = 156 + lead_height + 5 + byline_height + 26
    floor = H - spec['contentBottom']

    def header(c, doc):
        c.setTitle(f'The Bleed - {kind.title()} layout study')
        c.setAuthor('ReEnchanted / design specimen')
        c.setFillColor(INK)
        c.setStrokeColor(INK)
        if doc.page == 1:
            c.setFillColor(accent)
            c.setFont('Helvetica-Bold', 8)
            c.drawString(M, H - 36, kind.upper() + (' EDITION / OPEN THE DAY' if kind == 'morning' else ' EDITION / BRING IT HOME'))
            c.setStrokeColor(INK)
            c.setLineWidth(1.4)
            c.line(M, H - 48, W - M, H - 48)
            c.setFillColor(INK)
            c.setFont('Bleed-Bold', 47)
            c.drawString(M - 1, H - 100, 'THE BLEED')
            c.setFont('Helvetica', 8)
            c.drawString(M, H - 125, f'Issue #24 · Friday, 16 October 2026 · {kind.title()}')
            c.setLineWidth(.7)
            c.line(M, H - 139, W - M, H - 139)
            lead.drawOn(c, M, H - 156 - lead_height)
            lead_byline.drawOn(c, M, H - 156 - lead_height - 5 - byline_height)
            c.line(M, H - top + 14, W - M, H - top + 14)
            frame_top = H - top
        else:
            c.setFillColor(accent)
            c.setFont('Helvetica-Bold', 8)
            c.drawString(M, H - 40, f'THE BLEED / {kind.upper()} / CONTINUED')
            c.line(M, H - 52, W - M, H - 52)
            frame_top = H - 70
        c.setStrokeColor(HexColor('#cccccc'))
        c.setLineWidth(.45)
        c.line(W / 2, floor, W / 2, frame_top)
        c.setStrokeColor(INK)
        c.line(M, 38, W - M, 38)
        c.setFillColor(INK)
        c.setFont('Helvetica', 6.7)
        c.drawString(M, 23, 'LAYOUT STUDY / SYNTHETIC READER INK / AUTHORED PACK EXCERPTS')
        c.drawRightString(W - M, 23, str(doc.page))

    def frames(t):
        return [Frame(M + i * (COL + G), floor, COL, H - t - floor,
                      leftPadding=0, rightPadding=0, topPadding=0, bottomPadding=0, id=f'col-{i}') for i in range(2)]

    doc = BaseDocTemplate(str(path), pagesize=(W, H), leftMargin=M, rightMargin=M,
                           topMargin=top, bottomMargin=floor, title=f'{kind.title()} layout study')
    doc.addPageTemplates([
        PageTemplate(id='first', frames=frames(top), onPage=header, autoNextPageTemplate='continued'),
        PageTemplate(id='continued', frames=frames(70), onPage=header)
    ])
    story = []
    for index, article in enumerate(features):
        piece = []
        if index:
            piece.extend([Paragraph(safe(article['title']), title), Paragraph(safe(article['byline']), byline)])
        if article.get('quote'):
            piece.append(Paragraph(safe(article['quote']), quote))
            piece.append(Paragraph("The Book's reading:", byline))
        for para in article['body'].split('\n\n'):
            printed = safe(para)
            if not article.get('quote') and 'your words' not in article['byline']:
                printed = re.sub(r'\*([^*\n]+)\*', r'<i>\1</i>', printed)
            piece.append(Paragraph(printed, body))
        piece.append(Spacer(1, 10))
        if article.get('quote'):
            story.append(KeepTogether(piece))
        else:
            story.extend(piece)
    story.append(Paragraph('Set in type by P. Blackletter. Corrections welcome.', byline.clone('colophon', keepWithNext=False)))
    doc.build(story)
    reader = PdfReader(str(path))
    extracted = '\n'.join(p.extract_text() for p in reader.pages)
    normalize = lambda t: ' '.join(t.split())
    for article in features:
        if not stress:
            expected = article['body']
            if not article.get('quote') and 'your words' not in article['byline']:
                expected = re.sub(r'\*([^*\n]+)\*', r'\1', expected)
            assert normalize(expected) in normalize(extracted), article['title']
        if article.get('quote'):
            # PDF extraction may insert line breaks. Check all words and punctuation,
            # not the renderer's particular choice of wraps.
            assert normalize(article['quote']) in normalize(extracted), article['title']
    print(f'{path.relative_to(ROOT)}: {len(reader.pages)} pages, {len(extracted)} extracted characters')
    return len(reader.pages)


for kind, features in fixtures.items():
    make(kind, features, OUT / f'bleed-{kind}-layout-study.pdf')
# A separate scratch overflow study exercises this independent renderer only.
# Its page count says nothing about the unbuilt Core Text path.
TMP = ROOT / 'tmp' / 'pdfs'
TMP.mkdir(parents=True, exist_ok=True)
long = fixtures['evening'] * 3
make('evening', long, TMP / 'bleed-overflow-study.pdf', stress=True)
