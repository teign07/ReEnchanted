#!/usr/bin/env python3
"""Blunt counters for vignette takes. Reading them is still the real test.

    python3 scripts/vignette_lab/score.py /tmp/current.json /tmp/sheet.json /tmp/jobs.json
"""
import json, re, sys
from pathlib import Path

STOCK = ["air thick", "air grew", "air shifted", "air itself", "dust mote", "motes", "ozone", "old paper", "shimmer",
         "glimmer", "breath held", "held its breath", "holds its breath", "silence stretch", "silence press",
         "heavy with", "tangible", "palpable", "a sense of", "seemed to", "almost imperceptible", "electric",
         "the weight of", "taut", "pregnant", "hung in the air", "hangs in the air", "beckon"]
CAST = ["Ambrose", "Inkrest", "Vellum", "Villanelle", "Stonebrook", "Permancer", "Wicker", "Serenity", "Finn",
        "Zara", "Pippa", "Thorne", "Euphony", "Min-seo", "Seraphina", "Momort", "Penny"]
POV = re.compile(r"\byou (?:feel|felt|think|thought|nod|nodded|smile|smiled|wonder|wondered|decide|decided|reach|reached|step|stepped|say|said|grab|grabbed|take|took|lean|leaned|watch|watched)\b", re.I)
WANTED = re.compile(r"\b(?:wanted|wants|needed|needs) (?:to|the|a)\b", re.I)
WORD = re.compile(r"[a-z']+")
STOPW = set("the a an and or but of to in on at for with from by as is are was were be it its this that you your i my me "
            "they them he she his her not no so if then than when while one out up down over into very".split())


def scene_of(text: str) -> str:
    return re.split(r"\n\s*(?:SLICE_OF_LIFE|Slice of Life)", text.replace("SCENE:", ""), maxsplit=1)[0].strip()


def content(t):
    return {w for w in WORD.findall(t.lower()) if len(w) > 3 and w not in STOPW}


def score(row) -> dict:
    s = scene_of(row["text"])
    low = s.lower()
    words = len(s.split())
    quotes = len(re.findall(r"[\"“]", s)) // 1
    lines_spoken = len(re.findall(r"[\"“][^\"”]{3,}[\"”]", s))
    stock = sum(low.count(x) for x in STOCK)
    plan = row.get("plan") or {}
    allowed = {w for x in (plan.get("lead", ""), plan.get("companion", "")) for w in x.split()}
    meta_names = row.get("allowedNames") or allowed
    strangers = [n for n in CAST if n in s and n not in meta_names] if meta_names else []
    turns = plan.get("turns") or []
    landed = sum(1 for t in turns if len(content(t) & content(s)) >= max(2, len(content(t)) * 0.4))
    last = s.strip().split("\n")[-1]
    return {
        "words": words, "spoken": lines_spoken, "stock": stock,
        "wanted": len(WANTED.findall(s)), "pov": len(POV.findall(s)),
        "strangers": strangers, "turnsLanded": landed, "turnsPlanned": len(turns),
        "endsOnQuestion": "?" in last[-60:],
    }


def report(path: str):
    rows = json.loads(Path(path).read_text())
    sc = [score(r) for r in rows]
    n = len(sc)
    avg = lambda k: sum(x[k] for x in sc) / n
    print(f"{Path(path).name}: n={n}  words {avg('words'):.0f}  spoken lines {avg('spoken'):.1f}  "
          f"stock {avg('stock'):.2f}  'wanted' {avg('wanted'):.2f}  pov slips {avg('pov'):.2f}  "
          f"strangers {sum(1 for x in sc if x['strangers'])}/{n}  "
          f"ends on question {sum(x['endsOnQuestion'] for x in sc)}/{n}  "
          + (f"turns landed {sum(x['turnsLanded'] for x in sc)}/{sum(x['turnsPlanned'] for x in sc)}" if sc and sc[0]['turnsPlanned'] else ""))
    if rows and "tokens" in rows[0]:
        print(f"   output tokens {sum((r.get('tokens') or 0) for r in rows) / n:.0f}  prompt tokens {sum(r.get('promptTokens', 0) for r in rows) / n:.0f}  calls {sum(r.get('calls', 1) for r in rows) / n:.1f}")


if __name__ == "__main__":
    for p in sys.argv[1:]:
        report(p)
