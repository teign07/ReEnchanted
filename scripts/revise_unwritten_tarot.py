#!/usr/bin/env python3
"""Review/stage/install the authored ReEnchanted revision; never build an app.

Exact lettering remains native text. HTML review uses the same relative plate
coordinates and system handwriting face, independently of image generation.
"""
import argparse
import html
import json
import re
import shutil
from pathlib import Path

from optimize_unwritten_tarot import ROOT, digest, stage, write_json

DEST = ROOT / "output/imagegen/unwritten-deck-v2"
BASE = ROOT / "output/imagegen/unwritten-deck-v1"
PROTOTYPES = ["wands-ten", "major-00", "swords-three", "pentacles-eight", "cups-queen", "major-18"]


def records():
    originals = json.loads((BASE / "jobs.json").read_text())
    result = []
    for original in originals:
        card_id = original["id"]
        spec_path = DEST / "specs" / f"{card_id}.json"
        master = DEST / "masters" / f"{card_id}.png"
        receipt = DEST / "receipts" / f"{card_id}.json"
        if not all(p.exists() for p in (spec_path, master, receipt)):
            continue
        spec = json.loads(spec_path.read_text())
        assert spec["id"] == card_id
        for key in ("bookishScene", "marginalLabel", "readingNote"):
            assert isinstance(spec[key], str) and spec[key].strip(), (card_id, key)
        assert 1 <= len(spec["readingNote"].split()) <= 12, card_id
        assert 1 <= len(spec["marginalLabel"].split()) <= 5, card_id
        assert spec["requiredSymbols"] and isinstance(spec["requiredSymbols"], list), card_id
        assert isinstance(spec["newSubjects"], list) and spec["newSubjects"], card_id
        layout = spec.get("annotationLayout", {})
        for key, default in (("labelX", .06), ("labelY", .145), ("labelWidth", .36),
                             ("noteX", .09), ("noteY", .91), ("noteWidth", .82)):
            assert 0 <= layout.get(key, default) <= 1, (card_id, key)
        assert layout.get("labelX", .06) + layout.get("labelWidth", .36) <= 1, card_id
        assert layout.get("noteX", .09) + layout.get("noteWidth", .82) <= 1, card_id
        spec["newSubjects"] = [re.sub(r"\s+", "-", s.strip().lower()) for s in spec["newSubjects"]]
        for subject in spec["newSubjects"]:
            assert re.fullmatch(r"[a-z]+(?:-[a-z]+)*", subject), (card_id, subject)
        suit = card_id.split("-")[0]
        if suit in ("wands", "swords", "pentacles", "cups"):
            rank = card_id.split("-")[1]
            count = {"ace": 1, "two": 2, "three": 3, "four": 4, "five": 5,
                     "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10}.get(rank, 1)
            assert spec.get("expectedSuitCount", count) == count, card_id
            spec["expectedSuitCount"] = count
        if suit in ("wands", "swords", "pentacles"):
            spec["newSubjects"].append({"wands": "pen", "swords": "paper-knife", "pentacles": "book-clasp"}[suit])
        spec["newSubjects"] = sorted(set(spec["newSubjects"]))
        generation = json.loads(receipt.read_text())
        prompt_file = Path(generation.get("promptFile", DEST / "prompts" / f"{card_id}.txt"))
        assert prompt_file.is_file(), (card_id, "actual prompt missing")
        result.append(dict(original, master=str(master), specification=spec,
                           requiredScene=spec["bookishScene"],
                           legacyRequiredScene=original["requiredScene"],
                           prompt=prompt_file.read_text(), promptFile=str(prompt_file),
                           receiptPath=str(receipt)))
    return result


def review_html(jobs):
    by_id = {j["id"]: j for j in jobs}
    source_path = ROOT / "Shared/Tarot.swift"
    source = source_path.read_text()
    marker = r"    // BEGIN AUTHORED UNWRITTEN MARGINALIA.*?    // END AUTHORED UNWRITTEN MARGINALIA"
    if len(re.findall(marker, source, flags=re.S)) != 1:
        raise SystemExit("Authored source marker missing or ambiguous")
    if source.count('static let version = "unwritten-v1"') + source.count('static let version = "unwritten-v2"') != 1:
        raise SystemExit("Installed source version missing or ambiguous")
    order = [i for i in PROTOTYPES if i in by_id] + [j["id"] for j in jobs if j["id"] not in PROTOTYPES]
    cards = []
    for card_id in order:
        job = by_id[card_id]
        spec = job["specification"]
        name = html.escape(job["name"])
        layout = spec.get("annotationLayout", {})
        cards.append(f'''<article id="{card_id}"><div class="plate">
<img src="masters/{card_id}.png" alt="{html.escape(spec['bookishScene'], quote=True)}">
<span class="label" style="left:{layout.get('labelX', .06)*100}%;top:{layout.get('labelY', .145)*100}%;width:{layout.get('labelWidth', .36)*100}%;background:{'#f4ecd6' if layout.get('labelOnPaper') else 'transparent'}">{html.escape(spec['marginalLabel'])}</span>
<span class="note" style="left:{layout.get('noteX', .09)*100}%;top:{layout.get('noteY', .91)*100}%;width:{layout.get('noteWidth', .82)*100}%">{html.escape(spec['readingNote'])}</span>
</div><footer>{name}</footer></article>''')
    source = '''<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>The Unwritten Deck · ReEnchanted revision</title>
<style>
*{box-sizing:border-box}body{margin:0;padding:32px;background:#ebe4d4;color:#382c22;font-family:Georgia,serif}
header{max-width:1050px;margin:0 auto 28px}h1{font-weight:normal;font-size:29px;margin:0 0 8px}p{line-height:1.5;margin:5px 0}
main{display:grid;grid-template-columns:repeat(auto-fit,minmax(270px,1fr));gap:28px;max-width:1240px;margin:auto}
article{background:#f4ecd6;border:1px solid #96856d;border-radius:9px;padding:5px;overflow:hidden}
.plate{position:relative;aspect-ratio:7/12;container-type:inline-size}.plate img{width:100%;height:100%;object-fit:contain;display:block}
.label,.note{position:absolute;font-family:"Bradley Hand", "Noteworthy", cursive;font-weight:bold;color:#413126;transform-origin:left top;line-height:1.2}
.label{left:6%;top:14.5%;width:36%;font-size:4.3cqw;transform:rotate(-3deg);opacity:.78}
.note{left:9%;top:91%;width:82%;height:7.5%;font-size:5.2cqw;transform:rotate(-1deg);opacity:.86}
footer{text-align:center;padding:10px 4px;font-size:16px;min-height:40px}
body.single{padding:0;background:transparent}body.single header{display:none}body.single main{display:block;width:490px;margin:0}
body.single article{display:none}body.single article.selected{display:block}
</style>
<header><h1>The Unwritten Deck · ReEnchanted</h1><p>Bookcraft, ink, library life and authored marginalia.</p>
<p>Production artwork review. This browser composition checks lettering and placement; it is not a native app or print proof.</p></header><main>'''
    source += "\n".join(cards) + '''</main><script>
const card=new URLSearchParams(location.search).get('card');
if(card){document.body.classList.add('single');document.getElementById(card)?.classList.add('selected')}
</script></html>'''
    (DEST / "review.html").write_text(source)
    write_json(DEST / "jobs.json", jobs)


def install(jobs, exports):
    direction_path = DEST / "art-direction-decision.json"
    if direction_path.exists() and not json.loads(direction_path.read_text()).get("installationAllowed", False):
        raise SystemExit("Refusing installation: this art direction was superseded by the reader")
    if len(jobs) != 78 or len(exports) != 78:
        raise SystemExit("Refusing installation: all 78 revised faces need a master, specification and receipt")
    reviews = json.loads((DEST / "production-reviews.json").read_text())
    for exported in exports:
        review = reviews.get(exported["id"], {})
        if review.get("status") != "accepted" or review.get("masterSHA256") != exported["masterSHA256"]:
            raise SystemExit("Refusing installation: missing/stale acceptance for " + exported["id"])
        if review.get("specSHA256") != digest(DEST / "specs" / (exported["id"] + ".json")):
            raise SystemExit("Refusing installation: authored annotation changed after review for " + exported["id"])
    baseline = json.loads((DEST / "integration-baseline.json").read_text())
    # Check the whole set before changing any file, including the held back.
    exported_by_asset = {e["assetName"]: e for e in exports}
    for relative, expected in baseline["assets"].items():
        path = ROOT / relative
        held = exported_by_asset.get(path.parent.stem)
        allowed = {expected}
        if held:
            allowed.add(held["exportSHA256"])
        if digest(path) not in allowed:
            raise SystemExit("Concurrent asset edit: " + relative)
    old_manifest = json.loads((ROOT / "docs/unwritten-deck-art-manifest.json").read_text())
    if old_manifest["deckVersion"] not in ("unwritten-v1", "unwritten-v2"):
        raise SystemExit("Unexpected installed deck revision")
    installed_receipt = DEST / "installation-receipt.json"
    allowed_manifests = {baseline["manifestSHA256"]}
    if installed_receipt.exists():
        allowed_manifests.add(json.loads(installed_receipt.read_text())["manifestSHA256"])
    if digest(ROOT / "docs/unwritten-deck-art-manifest.json") not in allowed_manifests:
        raise SystemExit("Concurrent installed manifest edit")
    by_id = {j["id"]: j for j in jobs}
    for job in jobs:
        receipt = json.loads(Path(job["receiptPath"]).read_text())
        prompt_file = receipt.get("promptFile")
        if not prompt_file or not Path(prompt_file).is_file():
            raise SystemExit("Actual prompt file missing: " + job["id"])
    cards = []
    for exported in exports:
        job = by_id[exported["id"]]
        spec = job["specification"]
        folder = ROOT / "InsideCoverApp/Assets.xcassets" / (job["assetName"] + ".imageset")
        shutil.copy2(ROOT / exported["export"], folder / "card.jpg")
        assert digest(folder / "card.jpg") == exported["exportSHA256"]
        receipt = json.loads(Path(job["receiptPath"]).read_text())
        prompt_file = receipt["promptFile"]
        cards.append(dict(exported, authoredID=job["authoredID"],
                          requiredScene=spec["bookishScene"], requiredSymbols=spec["requiredSymbols"],
                          expectedSuitCount=spec.get("expectedSuitCount"),
                          marginalia=dict(label=spec["marginalLabel"], note=spec["readingNote"]),
                          annotationLayout=spec.get("annotationLayout", {}),
                          illustratedSubjects=spec["newSubjects"],
                          generationPrompt=Path(prompt_file).read_text(), generationReceipt=receipt,
                          review=reviews[job["id"]]))
    back = next(c for c in old_manifest["cards"] if c["id"] == "back")
    cards.append(back)
    write_json(ROOT / "docs/unwritten-deck-art-manifest.json", dict(
        deckVersion="unwritten-v2", generator="built-in image_gen.imagegen",
        lineage="Rider–Waite–Smith; Pamela Colman Smith; ReEnchanted bookcraft reinterpretation",
        lettering="Authored native text; illustration masters intentionally contain no generated lettering",
        annotationLayout=dict(label=dict(x=.06,y=.145,width=.36,fontWidthRatio=.043,rotation=-3),
                              note=dict(x=.09,y=.91,width=.82,height=.075,fontWidthRatio=.052,rotation=-1)),
        cards=cards))
    quote = lambda text: json.dumps(text, ensure_ascii=False)
    lines = ["    // BEGIN AUTHORED UNWRITTEN MARGINALIA",
             "    private static let printedMarginalia: [String: Marginalia] = ["]
    for job in jobs:
        spec = job["specification"]
        layout = spec.get("annotationLayout", {})
        suffix = "".join(f", {key}: {str(layout[key]).lower()}" for key in ("labelX", "labelY", "labelWidth", "labelOnPaper", "noteX", "noteY", "noteWidth") if key in layout)
        lines.append(f'        {quote(job["id"])}: .init(label: {quote(spec["marginalLabel"])}, note: {quote(spec["readingNote"])}{suffix}),')
    lines += ["    ]", "    private static let illustratedSubjects: [String: [String]] = ["]
    for job in jobs:
        values = ", ".join(quote(s) for s in sorted(set(job["specification"]["newSubjects"])))
        lines.append(f'        {quote(job["id"])}: [{values}],')
    lines += ["    ]", "    // END AUTHORED UNWRITTEN MARGINALIA"]
    source, count = re.subn(marker, lambda _: "\n".join(lines), source, flags=re.S)
    assert count == 1
    source = source.replace('static let version = "unwritten-v1"', 'static let version = "unwritten-v2"', 1)
    source_path.write_text(source)
    write_json(DEST / "installation-receipt.json", dict(
        deckVersion="unwritten-v2", revisedFaces=78, heldBack=True,
        manifestSHA256=digest(ROOT / "docs/unwritten-deck-art-manifest.json")))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--install", action="store_true")
    parser.add_argument("--quality", type=int, default=78)
    args = parser.parse_args()
    assert 60 <= args.quality <= 95
    jobs = records()
    review_html(jobs)
    index = DEST / "exports.json"
    previous = {e["id"]: e for e in json.loads(index.read_text())} if index.exists() else {}
    exports = []
    for job in jobs:
        old = previous.get(job["id"])
        if old and old["masterSHA256"] == digest(Path(job["master"])) and old["jpegQuality"] == args.quality \
                and (ROOT / old["export"]).exists() and old["exportSHA256"] == digest(ROOT / old["export"]):
            exports.append(old)
        else:
            exports.append(stage(job, args.quality, DEST))
    write_json(index, exports)
    if args.install:
        install(jobs, exports)
    print(json.dumps(dict(revisedFaces=len(jobs), installed=args.install,
                          masterBytes=sum(e["masterBytes"] for e in exports),
                          imageBytes=sum(e["exportBytes"] for e in exports),
                          review=str(DEST / "review.html"))))


if __name__ == "__main__":
    main()
