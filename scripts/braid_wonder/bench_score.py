#!/usr/bin/env python3
"""Score the current braid and the small-jobs braid on the same simulated days.

    python3 scripts/braid_wonder/bench_score.py bench.json base_scrubbed.json new_a.json [new_b.json ...]

bench.json   the simulated days ({"date", "pages", "scenes"?})
base         lab tellings (scrubbed), one or more per night, named day-<date>
new_*        small_jobs.py --briefs output (one per mode)

Everything is mechanical and deliberately blunt; the real judge is reading them.
"""
import difflib, json, re, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import small_jobs as sj  # noqa: E402

AGENCY = re.compile(r"\b(?:the|a|an|that|this)\s+(?:[a-z]+\s+){0,2}[a-z]+\s+"
                    r"(?:wanted|decided|had decided|had been|was in the middle|refused|promised|knew|hoped|waited|listened|"
                    r"held (?:its|his|her|their)|thought about|had heard|kept (?:a|its|the|one)|was (?:only|timing|saving)|"
                    r"had opinions|stood on|did not (?:once )?complain|had (?:never|always|long|once))\b", re.I)


def sentences(t):
    return [x.strip() for x in re.split(r"(?<=[.!?])\s+", re.sub(r"\s+", " ", t)) if x.strip()]


def strip_passages(text, passages):
    for p in passages:
        text = text.replace(p, " ")
    return text


def score(text, day):
    passages = [s["text"] for s in day.get("scenes", [])]
    body = strip_passages(text, passages)
    reader = " ".join(p["text"] for p in day["pages"])
    ss = sentences(body)
    # The Book may say "I". What the lab calls a slip is the Book standing in for the reader's acts: "I watched / I went".
    first = sum(1 for x in ss if re.search(r"\bI (?:watched|noticed|saw|found|went|walked|made|had|sat|opened|read|wrote|took|felt|sensed)\b", x)
                or (sj.FIRST.search(x) and not re.search(r"\bI\b|\bmy\b|\bme\b", x, re.I) is None and False))
    stock = sum(1 for x in ss if sj.STOCK.search(x))
    reader_you = sj.you(reader)
    inv = 0
    ok = {sj.stem(w) for w in re.findall(r"[a-z']+", reader_you.lower())}
    ok |= {"were", "was", "had", "did", "didn't", "could", "would", "saw", "just", "still", "also", "may", "might", "have", "don't",
           "can", "never", "always", "only", "even", "all", "ever", "got"}
    for x in ss:
        if sj.INVENTED_READER.search(x) and not sj.INVENTED_READER.search(reader_you):
            inv += 1
            continue
        for verb in re.findall(r"\byou(?:'d|'ve)?\s+(\w+)", x, re.I):
            if sj.stem(verb.lower()) not in ok and verb.lower() not in ok:
                inv += 1
                break
    keeps = []
    for p in day["pages"]:
        need = sj.words(p["text"])
        if need:
            keeps.append(len(need & sj.words(body)) / len(need))
    reflected = 0
    rs = sentences(reader_you)
    for r in rs:
        if any(difflib.SequenceMatcher(None, sj.norm(r), sj.norm(x)).ratio() > 0.85 for x in ss):
            reflected += 1
    agency = len(AGENCY.findall(body))
    return {"words": len(body.split()), "first_person": first, "stock": stock, "invented_reader": inv,
            "reader_kept": sum(keeps) / len(keeps) if keeps else 1.0, "reflected": reflected / len(rs) if rs else 0,
            "agency": agency, "dupes": len(ss) - len({sj.norm(x) for x in ss})}


def bind_passages(text, passages):
    """Mimic the app's binding for the current braid: drop echoed copies, then put the passages after paragraph one."""
    text = strip_passages(text, passages)
    paras = [p.strip() for p in re.split(r"\n\s*\n", text) if p.strip()]
    if not passages:
        return "\n\n".join(paras)
    if len(paras) < 2:
        ss = sentences(paras[0]) if paras else []
        paras = [" ".join(ss[:3]), " ".join(ss[3:])] if len(ss) > 3 else paras
    return "\n\n".join(paras[:1] + passages + paras[1:])


def main():
    days = {d["date"]: d for d in json.loads(Path(sys.argv[1]).read_text())}
    sets = {}
    base = json.loads(Path(sys.argv[2]).read_text())
    base = base if isinstance(base, list) else base["tellings"]
    rows = []
    for t in base:
        date = t["night"].replace("day-", "")
        d = days[date]
        rows.append((date, bind_passages(t["text"], [s["text"] for s in d.get("scenes", [])]), d))
    sets["current braid"] = rows
    for path in sys.argv[3:]:
        new = json.loads(Path(path).read_text())
        sets[Path(path).stem] = [(n["date"], n["text"], days[n["date"]]) for n in new if not n["hard"] and n["text"]]
    hard = {d for d, day in days.items()}
    print(f"{'set':<18}{'n':>3}{'words':>7}{'1st':>6}{'stock':>7}{'inv':>6}{'kept':>7}{'refl':>7}{'agency':>8}{'dupes':>7}")
    for name, rows in sets.items():
        sc = [score(text, d) for _, text, d in rows if text]
        n = len(sc)
        avg = lambda k: sum(x[k] for x in sc) / n
        print(f"{name:<18}{n:>3}{avg('words'):>7.0f}{avg('first_person'):>6.2f}{avg('stock'):>7.2f}{avg('invented_reader'):>6.2f}"
              f"{avg('reader_kept'):>7.2f}{avg('reflected'):>7.2f}{avg('agency'):>8.2f}{avg('dupes'):>7.2f}")
    print("\n1st=first-person sentences, stock=cliche/filler sentences, inv=invented reader acts, kept=reader's words kept,")
    print("refl=reader sentences echoed near-verbatim, agency=sentences where a thing wants/decides/knows, per telling.")


if __name__ == "__main__":
    main()
