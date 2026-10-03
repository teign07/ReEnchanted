#!/usr/bin/env python3
"""The Mac mirror of the phone's braid.

Runs the exact device briefs through the same Gemma 4 E2B 4-bit weights with the
phone's sampling (temp 0.70, top-p 0.90, 420 tokens), no thinking channel, and
the same worn-image masking, then scores and prints the tellings.

    BRAID_BRIEFS_OUT=/tmp/briefs.json swift test --filter testWriteTheDeviceBriefsWhenAsked
    ~/ReEnchanted-models/venv/bin/python scripts/braid_lab.py /tmp/briefs.json --per-night 2 --out /tmp/tellings.json

Notes that took a day to learn (see the memory "braid-lab-mac-mirror"):
- mlx_lm renders <|think|> by default; enable_thinking=False is what the phone does.
- The 2B model copies anything it can quote, so never put a banned word in a brief.
"""
import argparse, json, os, re, sys, time
from pathlib import Path

MODEL = os.path.expanduser("~/ReEnchanted-models/gemma-4-e2b-it-4bit")
SOURCE = Path(__file__).resolve().parent.parent / "InsideCoverApp" / "LocalBrainServices.swift"

def nightly_instructions() -> str:
    text = SOURCE.read_text()
    m = re.search(r'static let nightlyBookOfYou = """\n(.*?)\n\s*"""', text, re.S)
    if not m:
        sys.exit("could not find BraidInstructions.nightlyBookOfYou")
    lines = m.group(1).split("\n")
    indent = min(len(l) - len(l.lstrip()) for l in lines if l.strip())
    return "\n".join(l[indent:] for l in lines)

ESSAYIST = ["observed", "remarkable", "quite", "somewhat", "perhaps", "nevertheless", "indeed", "profound",
            "whilst", "ultimately", "essentially", "testament", "tapestry", "symphony", "dance"]
STOCK = ["shimmer", "iridescent", "ethereal", "glimmer", "tapestry", "motes", "dust motes", "hazy", "dancing",
         "whispered secrets", "grey sameness", "weight of", "the air was thick", "a sense of", "couldn't help but"]
CONTRACTION = re.compile(r"\b\w+'(?:s|d|t|ll|re|ve|m)\b", re.I)
LEVITY = re.compile(r"\b(amusing|amused|funny|giggl\w*|laugh\w*|delight\w*|silly|comical|cheer\w*|joke\w*|grinn?\w*|smirk\w*|fun)\b", re.I)
INVENTED_READER = re.compile(
    r"\byour (?:hand|hands|shoulders?|face|eyes?|heart|breath|fingers?|smile|jaw|voice|stomach|chest|skin|hair|lips|cheeks?)\b"
    r"|\byou (?:felt|seemed|looked (?:tired|sad|happy|worried)|were (?:nervous|happy|sad|tired|worried|anxious|relieved))\b", re.I)
FILLER = re.compile(r"\b(just|little|quite|suddenly|somehow|seemed|really|very|felt|weird|thick)\b", re.I)
SENSATION = re.compile(r"\b(?:I|my \w+) (?:felt|sensed)\b|\b(?:air|silence|room|quiet) (?:felt|was|grew|seemed) (?:thick|heavy|still|charged)\b|\bI found myself\b", re.I)
WATCHED = re.compile(r"\bI (?:watched|noticed|saw)\b")
POV_SLIP = re.compile(r"\bI (?:found|went|walked|made|had|sat|opened|read|wrote|took)\b")

def score(text: str) -> dict:
    words = re.findall(r"[A-Za-z']+", text)
    n = max(1, len(words))
    low = text.lower()
    sentences = [s.strip().lower() for s in re.split(r"(?<=[.!?])\s+", text) if len(s.split()) > 4]
    return {
        "words": len(words),
        "contractionsPer100": round(len(CONTRACTION.findall(text)) * 100 / n, 1),
        "essayist": [w for w in ESSAYIST if re.search(rf"\b{w}\b", low)],
        "stock": [w for w in STOCK if w in low],
        "povSlip": bool(POV_SLIP.search(text)),
        "levity": LEVITY.findall(text),
        "inventedReader": [m.group(0) for m in INVENTED_READER.finditer(text)],
        "strangeOdd": len(re.findall(r"\b(strange|strangely|odd|oddly)\b", text, re.I)),
        "watched": len(WATCHED.findall(text)),
        "fillerPer100": round(len(FILLER.findall(text)) * 100 / n, 1),
        "sensation": len(SENSATION.findall(text)),
        "thenOpener": bool(re.search(r"(?:^|[.!?] )Then, ", text)),
        "repeatedSentence": len(sentences) != len(set(sentences)),
    }

def report(results):
    n = len(results)
    print(f"\n{n} tellings. contractions/100w avg "
          f"{sum(r['score']['contractionsPer100'] for r in results) / n:.1f}; "
          f"stock {sum(1 for r in results if r['score']['stock'])}/{n}; "
          f"essayist {sum(1 for r in results if r['score']['essayist'])}/{n}; "
          f"levity {sum(1 for r in results if r['score']['levity'])}/{n}; "
          f"invented reader {sum(1 for r in results if r['score']['inventedReader'])}/{n}; "
          f"strange/odd {sum(1 for r in results if r['score']['strangeOdd'])}/{n}; "
          f"I watched/noticed/saw {sum(1 for r in results if r['score']['watched'])}/{n}; "
          f"filler/100w {sum(r['score']['fillerPer100'] for r in results) / n:.1f}; "
          f"sensation-telling {sum(1 for r in results if r['score']['sensation'])}/{n}; "
          f"'Then,' opener {sum(1 for r in results if r['score']['thenOpener'])}/{n}; "
          f"POV slips {sum(1 for r in results if r['score']['povSlip'])}/{n}; "
          f"repeated sentence {sum(1 for r in results if r['score']['repeatedSentence'])}/{n}; "
          f"cut at ceiling {sum(1 for r in results if r['finish'] == 'length')}/{n}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("briefs")
    ap.add_argument("--per-night", type=int, default=2)
    ap.add_argument("--max-tokens", type=int, default=420)
    ap.add_argument("--only", default="", help="substring of a night's name")
    ap.add_argument("--out", default="/tmp/tellings.json")
    ap.add_argument("--extra-mask", default="", help="words to mask on top of the brief's list, separated by | (keep the leading space)")
    ap.add_argument("--rescore", default="", help="score an existing tellings file (e.g. after the Swift scrub) and exit")
    args = ap.parse_args()
    if args.rescore:
        results = json.loads(Path(args.rescore).read_text())
        for r in results:
            r["score"] = score(r["text"])
        report(results)
        return

    import mlx.core as mx
    from mlx_lm import load, stream_generate
    from mlx_lm.sample_utils import make_sampler

    model, tokenizer = load(MODEL)
    instructions = nightly_instructions()
    sampler = make_sampler(temp=0.70, top_p=0.90)

    def single(text):
        ids = tokenizer.encode(text, add_special_tokens=False)
        return ids[0] if len(ids) == 1 else None

    extra = [w for w in args.extra_mask.split("|") if w]
    skipped = [w for w in extra if single(w) is None]
    if skipped:
        print("not single tokens, skipped:", skipped)

    def processor_for(night):
        words = [w for w in night.get("maskWords", "").split("|") if w] + extra
        pairs = [p.split("\u0001") for p in night.get("maskPairs", "").split("|") if p]
        always = [i for i in (single(w) for w in words) if i is not None]
        paired = []
        for after, word in pairs:
            trig = single(after); ids = tokenizer.encode(word, add_special_tokens=False)
            if trig is not None and ids:
                paired.append((trig, ids[0]))
        def proc(tokens, logits):
            if always:
                logits[:, always] = -1e9
            if paired and tokens.size:
                last = int(tokens[-1])
                for trig, banned in paired:
                    if last == trig:
                        logits[:, banned] = -1e9
            return logits
        return proc

    nights = json.loads(Path(args.briefs).read_text())
    if args.only:
        keys = [k for k in args.only.split(",") if k]; nights = [n for n in nights if any(k in n["name"] for k in keys)]
    results = []
    t0 = time.time()
    for night in nights:
        for k in range(args.per_night):
            messages = [{"role": "system", "content": instructions}, {"role": "user", "content": night["brief"]}]
            prompt = tokenizer.apply_chat_template(messages, add_generation_prompt=True, tokenize=False, enable_thinking=False)
            text, last = "", None
            for resp in stream_generate(model, tokenizer, prompt, max_tokens=args.max_tokens, sampler=sampler,
                                        logits_processors=[processor_for(night)]):
                text += resp.text; last = resp
            text = text.strip()
            results.append({"night": night["name"], "take": k + 1, "text": text, "score": score(text),
                            "tokens": getattr(last, "generation_tokens", None),
                            "finish": getattr(last, "finish_reason", None)})
            print(f"[{len(results)}/{len(nights) * args.per_night}] {night['name']} take {k + 1}: "
                  f"{results[-1]['score']['words']} words, {time.time() - t0:.0f}s", flush=True)
    Path(args.out).write_text(json.dumps(results, indent=2))
    report(results)

if __name__ == "__main__":
    main()
