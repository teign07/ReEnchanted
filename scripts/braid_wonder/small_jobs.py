#!/usr/bin/env python3
"""Prototype: a braid made of small jobs, with authored 'wonder lines' for ordinary things.

The 2B model connects and follows well but cannot invent. So the invention is authored
(lines.json: what an ordinary thing wanted or did), and Gemma's job in each paragraph is
small: tell ONE true thing from the reader's day in plain words, then lead into the
authored line and keep it word for word. Authored scene passages go in verbatim between
paragraphs. Every paragraph is checked (line kept verbatim, no first person, reader's words
kept, no stock) and re-asked up to four times; if it still fails, it is assembled without
Gemma. Nothing here touches the app.

    ~/ReEnchanted-models/venv/bin/python scripts/braid_wonder/small_jobs.py day.json --takes 3

day.json: {"date": "2026-10-02",
           "pages":  [{"time": "08:12", "type": "diary", "text": "..."}],
           "scenes": [{"id": "...", "text": "authored braid line"}],      # optional
           "tale":   "the day's Tale pulse"}                                # optional
"""
import argparse, hashlib, json, os, re, sys, time
from pathlib import Path

HERE = Path(__file__).resolve().parent
MODEL = os.path.expanduser("~/ReEnchanted-models/gemma-4-e2b-it-4bit")

SYSTEM = ("You write one paragraph of a contemporary domestic faerie tale: exact, physical, a little funny, sometimes cozy, "
          "sometimes terrible. Plain words, contractions, past tense. You tell it to the reader as 'you'. "
          "Never invent people, places, objects or feelings that are not given. Never write 'I' or 'my'.")

STOCK = re.compile(r"\b(shimmer\w*|iridescent|ethereal|glimmer\w*|tapestry|motes?|suddenly|seemed|couldn't help|a sense of|"
                   r"whispered secrets|dancing|dance|symphony|testament|witness|monument|felt|feeling|whisper\w*|hush\w*|echo\w*|"
                   r"canine|ballet|sanctuary|haven|cocoon|embrace\w*|veil|savou?ry|palpable|profound\w*|somehow)\b", re.I)
FIRST = re.compile(r"\b(I|I'm|I've|I'd|I'll|my|me|myself)\b")
STOP = set("the a an and or but of to in on at for with from by as is are was were be been it its this that these those you your "
           "i my me we our they them he she his her not no so if then than when while where which who what into out up down over "
           "under again once each every one two just have has had do does did will would could should can may might about after "
           "before through across along around near tonight today".split())


def you(text: str) -> str:
    t = text
    for a, b in [(r"\bI'm\b", "you're"), (r"\bI've\b", "you've"), (r"\bI'd\b", "you'd"), (r"\bI'll\b", "you'll"),
                 (r"\bmyself\b", "yourself"), (r"\bmy\b", "your"), (r"\bme\b", "you"), (r"\bI\b", "you")]:
        t = re.sub(a, b, t)
    return t


def words(t):
    return {w for w in re.findall(r"[a-z']+", t.lower()) if len(w) >= 4 and w not in STOP}


def norm(t):
    return re.sub(r"\s+", " ", t.replace("’", "'").replace("“", '"').replace("”", '"')).strip().lower()


LINES = json.loads((HERE / "lines.json").read_text())
# Setting nouns appear in passing ("on the sofa", "across the tiles"). They only speak when nothing on the page acts.
WEAK = {"window", "floor", "rug", "carpet", "tiles", "chair", "chairs", "sofa", "table", "desk", "door", "doors", "wall", "gate",
        "fence", "road", "street", "pavement", "bed", "lamp", "lights", "bag", "bags", "sky", "park", "bench", "shop", "sink",
        "plates", "dishes", "cup", "mug", "pan", "bin", "rubbish", "lane", "market", "store",
        "morning", "mornings", "night", "midnight", "bedtime", "autumn", "october", "smell", "smelled", "smells", "smelt", "noise",
        "sound", "sounds", "sleep", "asleep", "nap", "tired", "water", "shadow", "shadows", "silence", "quiet", "stillness", "list",
        "note", "notes", "kitchen", "hall", "hallway", "bathroom", "office", "meeting", "emails", "email", "school", "dust", "floor"}


def _forms(noun):
    return {noun, noun + "s", noun + "es", noun + "ed", noun + "ing"} if " " not in noun else {noun}


def _present(noun, low, toks):
    if " " in noun or "-" in noun:
        return re.search(r"\b" + re.escape(noun) + r"s?\b", low) is not None
    return bool(_forms(noun) & toks)


def matches(text: str):
    low = text.lower()
    toks = set(re.findall(r"[a-z]+", low))
    groups = {}
    for ln in LINES:
        if not any(_present(n, low, toks) for n in ln["nouns"]):
            continue
        needs = ln.get("needs")
        if needs and not any(_present(w, low, toks) for w in needs):
            continue
        groups.setdefault((tuple(ln["nouns"]), bool(needs)), []).append(ln)
    return groups


def pick(groups, date, used, text="", limit=1):
    """Up to two lines per page, in the order the nouns appear, rotating on the date so a noun
    does not say the same thing twice in a row."""
    low = text.lower()
    def first_at(key):
        spots = [m.start() for n in key[0] for m in re.finditer(r"\b" + re.escape(n), low)]
        return min(spots) if spots else 10**6
    choices = []
    strong = {k: v for k, v in groups.items() if not (set(k[0]) <= WEAK)}
    pool = strong or groups
    # a line written for this very situation beats a general one; then the order the nouns appear in
    for key, lines in sorted(pool.items(), key=lambda kv: (not kv[0][1], first_at(kv[0]))):
        h = int(hashlib.sha256((date + "|".join(key[0])).encode()).hexdigest(), 16)
        ordered = lines[h % len(lines):] + lines[:h % len(lines)]
        for ln in ordered:
            if ln["id"] not in used:
                choices.append(ln)
                break
        if len(choices) == limit:
            break
    return choices


class Teller:
    def __init__(self):
        from mlx_lm import load, stream_generate
        from mlx_lm.sample_utils import make_sampler
        self.model, self.tok = load(MODEL)
        self.stream = stream_generate
        self.sampler = make_sampler(temp=0.70, top_p=0.90)

    def ask(self, user: str, max_tokens=170) -> str:
        msgs = [{"role": "system", "content": SYSTEM}, {"role": "user", "content": user}]
        prompt = self.tok.apply_chat_template(msgs, add_generation_prompt=True, tokenize=False, enable_thinking=False)
        out = ""
        for r in self.stream(self.model, self.tok, prompt, max_tokens=max_tokens, sampler=self.sampler):
            out += r.text
        return out.strip().split("\n\n")[0].strip()


MODE = "keep"
INVENTED_READER = re.compile(
    r"\byour (?:hand|hands|shoulders?|face|eyes?|heart|breath|fingers?|smile|jaw|voice|stomach|chest|skin|hair|lips|cheeks?)\b"
    r"|\byou (?:felt|seemed|noticed|realised|realized|wondered|thought|decided|drifted|dozed|smiled|sighed|laughed|were (?:nervous|happy|sad|tired|worried|anxious|relieved))\b", re.I)


SYSTEM_BOOK = ("You are the Book: an old, mischievous, good-hearted book who keeps a day and has business of its own. "
               "Short plain words, contractions, past tense. You say 'I' for yourself and 'you' for the reader. "
               "You cannot touch or smell or taste: you only notice, and you read, and you listen to the building. "
               "Never describe your body or your feelings. Never invent people. State odd things as plain fact.")


def book_job(teller, opening, ask, tries=4):
    """A short paragraph in the Book's own voice that begins with an authored sentence and goes one step further."""
    best = None
    for _ in range(tries):
        msgs = [{"role": "system", "content": SYSTEM_BOOK},
                {"role": "user", "content": f'Begin with this sentence exactly: "{opening}"\n{ask}\n'
                                              "Write 25-45 words, 2 or 3 sentences, one paragraph, past tense. Add one small odd thing, stated as fact. "
                                              "Do not solve or finish anything."}]
        prompt = teller.tok.apply_chat_template(msgs, add_generation_prompt=True, tokenize=False, enable_thinking=False)
        out = ""
        for r in teller.stream(teller.model, teller.tok, prompt, max_tokens=120, sampler=teller.sampler):
            out += r.text
        text = out.strip().split("\n\n")[0].strip()
        n = len(text.split())
        if norm(opening) in norm(text) and 18 <= n <= 60 and not STOCK.search(text) and not re.search(r"\bdid [a-z]+\b", text, re.I) \
                and not re.search(r"\b(felt|smell\w*|tast\w*|my (?:fingers?|hands?|eyes?|teeth|skin|heart))\b", text, re.I):
            return text, True
        best = best or text
    return opening, False


def weather_mode(date: str) -> str:
    """Weather is a beat that comes round regularly but not every night: a one-sentence mention or its own short
    paragraph, never two nights running and never more than three nights without. Stateless: the sequence is walked
    forward from a fixed anchor, so the same date always gets the same answer."""
    from datetime import date as _d, timedelta
    day = _d.fromisoformat(date)
    cursor = _d(2026, 9, 1)
    gap, last = 0, "skip"
    while True:
        h = int(hashlib.sha256(("weather|" + cursor.isoformat()).encode()).hexdigest(), 16) % 100
        if last != "skip":
            mode = "skip"
        elif gap >= 3:
            mode = "mention" if h < 45 else "beat"
        else:
            mode = "skip" if h < 50 else ("mention" if h < 78 else "beat")
        gap = 0 if mode != "skip" else gap + 1
        last = mode
        if cursor >= day:
            return mode
        cursor += timedelta(days=1)


def weather_sentence(teller, world):
    """One sentence, in the Book's voice, of the weather doing one small odd thing."""
    for _ in range(4):
        msgs = [{"role": "system", "content": SYSTEM_BOOK},
                {"role": "user", "content": f"The weather tonight: {world}\nWrite ONE sentence, 12-22 words, past tense, of the Book noticing it at the window, "
                                            "with one small odd thing the weather did. Do not say how it felt or smelled."}]
        prompt = teller.tok.apply_chat_template(msgs, add_generation_prompt=True, tokenize=False, enable_thinking=False)
        out = ""
        for r in teller.stream(teller.model, teller.tok, prompt, max_tokens=60, sampler=teller.sampler):
            out += r.text
        text = out.strip().split("\n")[0].strip()
        n = len(text.split())
        # Weather is real data: the sentence must use the tag's own words and must not invent sky the tag does not have.
        tag = {stem(w) for w in re.findall(r"[a-z]+", world.lower()) if len(w) >= 4 and w not in STOP}
        contradicts = re.search(r"\b(stars?|sun|sunny|sunshine|blue)\b", text, re.I) and re.search(r"overcast|rain|grey|gray|cloud", world, re.I)
        if 9 <= n <= 28 and text.count(".") <= 1 and not STOCK.search(text) and not contradicts \
                and any(stem(w) in tag for w in re.findall(r"[a-z]+", text.lower())) \
                and not re.search(r"\bdid [a-z]+\b|\b(felt|smell\w*|tast\w*)\b", text, re.I):
            return text
    return None


def play_job(teller, details, tale, seeds, tries=4):
    """Thin days get room to play: one longer paragraph where the Book lets an ordinary thing from the day have
    an adventure in the building. Warmer sampling, softer cliche rules; it still never invents what the reader did."""
    from mlx_lm.sample_utils import make_sampler
    warm = make_sampler(temp=0.95, top_p=0.95)
    told = " ".join(you(d).rstrip(".") + "." for d in details)
    idea = (" One idea you may use, bend, or beat: " + seeds[0]) if seeds else ""
    ask = ((f"Already told, do not repeat it: {told}\n") +
           (f"The Labyrinth's odd news, to carry on from: {tale}\n" if tale else "") + idea.strip() + ("\n" if idea else "") +
           "Write 55-85 words, one paragraph, past tense: what happened NEXT. Follow the odd news (or one ordinary thing) as it wandered "
           "off through the building and got into small, funny, impossible trouble. Be specific and a bit silly, with a named object or two. "
           "You may say 'I' as the Book watching, but never say what the reader did or felt beyond what is given.")
    ok_stem = {stem(w) for d in details for w in re.findall(r"[a-z']+", you(d).lower())}
    best = None
    for _ in range(tries):
        msgs = [{"role": "system", "content": SYSTEM_BOOK}, {"role": "user", "content": ask}]
        prompt = teller.tok.apply_chat_template(msgs, add_generation_prompt=True, tokenize=False, enable_thinking=False)
        out = ""
        for r in teller.stream(teller.model, teller.tok, prompt, max_tokens=170, sampler=warm):
            out += r.text
        text = out.strip().split("\n\n")[0].strip()
        n = len(text.split())
        bad_you = [v for v in re.findall(r"\byou(?:'d|'ve)?\s+(\w+)", text, re.I)
                   if stem(v.lower()) not in ok_stem and v.lower() not in {"were", "was", "had", "did", "could", "would", "saw", "watched", "looked", "heard", "might", "may", "can", "didn't"}]
        hard = re.search(r"\b(shimmer\w*|iridescent|ethereal|tapestry|motes?|suddenly|testament|symphony|palpable|felt|smell\w*|tast\w*)\b", text, re.I)
        tic = len(re.findall(r"\bdid [a-z]+\b", text, re.I)) > 1
        if 40 <= n <= 110 and not bad_you and not hard and not tic and not re.search(r"\bseeds?\b", text, re.I):
            return text, True
        best = best or text
    return None, False


def job_prompt(detail, lines, tale):
    parts = [f"Something true from the reader's day: {you(detail)}"]
    for line in lines:
        if MODE == "free":
            parts.append(f'A seed for the small impossible thing an ordinary object here might have done or wanted: "{line}" '
                         "Use it, bend it, or invent a better one of your own. Have fun with it.")
        else:
            parts.append(f'A line already written for this, to keep exactly as it is, word for word: "{line}"')
    if tale:
        parts.append(f"Something odd also happened nearby, to work in as one sentence: {tale}")
    parts.append("Write 40-60 words, 3 or 4 sentences, one paragraph, in the past tense, to the reader as 'you'. "
                 "Tell the true thing in your own plain words" +
                 ((", then lead into the written line(s) and include each exactly" if MODE != "free" else
                   ", then let one ordinary thing in it do or want one small impossible thing, stated as plain fact") if lines else "") +
                 (". Add nothing else that happens." if MODE != "free" else ". Do not invent anything the reader did or felt."))
    return "\n".join(parts)


SPARE = set("then there later nearby still only while another meanwhile always never about could would also even over under into onto "
            "through around after before until because though though something nothing everything anyone someone nobody everyone "
            "first last next same other whole more most much many some such very like what with without within that this those these "
            "stopped started kept came went took made said told asked looked turned held stayed lay sat stood".split())


IRREGULAR = {"saw": "see", "took": "take", "went": "go", "came": "come", "got": "get", "made": "make", "found": "find", "ran": "run",
             "sat": "sit", "stood": "stand", "fell": "fall", "held": "hold", "kept": "keep", "left": "leave", "told": "tell", "said": "say",
             "had": "have", "did": "do", "heard": "hear", "knew": "know", "gave": "give", "brought": "bring", "bought": "buy",
             "thought": "think", "rang": "ring", "wrote": "write", "ate": "eat", "drank": "drink", "slept": "sleep", "met": "meet",
             "spilled": "spill", "dropped": "drop", "stopped": "stop", "lay": "lie", "spent": "spend", "lost": "lose", "won": "win"}


def stem(w):
    w = IRREGULAR.get(w, w)
    for suf in ("ing", "ed", "es", "s", "ly", "er", "e"):
        if w.endswith(suf) and len(w) - len(suf) >= 3:
            w = w[: -len(suf)]
            break
    if len(w) > 3 and w[-1] == w[-2] and w[-1] not in "aeiouls":
        w = w[:-1]
    return w


def grounded(text, sources):
    """Content words that came from nowhere: not the reader's page, not an authored line, not the Tale beat."""
    have = {stem(w) for src in sources for w in re.findall(r"[a-z']+", src.lower())}
    stray = []
    for w in re.findall(r"[a-z]+", text.lower()):
        if len(w) < 4 or w in STOP or w in SPARE:
            continue
        if stem(w) not in have and stem(w).rstrip("e") not in have:
            stray.append(w)
    return stray


def check(text, detail, lines, tale):
    problems = []
    n = len(text.split())
    if n < 22 or n > 95:
        problems.append(f"length {n}")
    if FIRST.search(text):
        problems.append("first person")
    if STOCK.search(text):
        problems.append("stock")
    if MODE != "free":
        if any(norm(line) not in norm(text) for line in lines):
            problems.append("line not kept")
        stray = grounded(text, [you(detail), detail, tale or ""] + list(lines))
        if len(stray) > 1:
            problems.append("invented: " + ",".join(stray[:6]))
    else:
        if INVENTED_READER.search(text) and not INVENTED_READER.search(you(detail)):
            problems.append("invented reader")
        # Gemma may invent what the objects do. What *you* did comes from the reader's page only.
        ok = {stem(w) for w in re.findall(r"[a-z']+", (you(detail) + " " + (tale or "")).lower())}
        ok |= {"were", "was", "had", "did", "didn't", "could", "would", "saw", "just", "still", "also", "may", "might", "have",
               "don't", "can", "never", "always", "only", "even", "all", "ever", "got"}
        ok |= {"watched", "saw", "looked", "heard", "stood", "sat", "went", "watch", "see", "look", "hear", "stand", "sit", "go"}
        for verb in re.findall(r"\byou(?:'d|'ve)?\s+(\w+)", text, re.I):
            if stem(verb.lower()) not in ok and verb.lower() not in ok:
                problems.append("you " + verb)
                break
    sentences = [norm(x) for x in re.split(r"(?<=[.!?])\s+", text) if x.strip()]
    if len(sentences) != len(set(sentences)):
        problems.append("repeated sentence")
    need = words(detail)
    if need and len(need & words(text)) / len(need) < 0.4:
        problems.append("reader's words lost")
    if tale:
        key = [w for w in words(tale)][:3]
        if key and not any(k in words(text) for k in key):
            problems.append("tale beat lost")
    return problems


def repair(text, detail, lines, tale):
    """The app's scrub does this for the current braid: drop the sentence that carries the cliche, keep the rest."""
    keep = []
    for sent in re.split(r"(?<=[.!?])\s+", text):
        if STOCK.search(sent) and not any(norm(l) in norm(sent) for l in lines):
            continue
        keep.append(sent)
    fixed = " ".join(keep).strip()
    return fixed if fixed and fixed != text else None


def tell(day, teller, tries=4):
    date = day["date"]
    used = set()
    beats = []
    for page in day["pages"]:
        groups = matches(page["text"])
        picked = pick(groups, date, used, page["text"])
        for ln in picked:
            used.add(ln["id"])
        beats.append({"detail": page["text"], "lines": [ln["line"] for ln in picked]})
    # a night needs wonder in its beats: keep pages that matched, then fill with the rest, at most four paragraphs
    beats.sort(key=lambda b: not b["lines"])
    beats = beats[:4]
    tale = day.get("tale")
    paragraphs, report = [], []
    for i, b in enumerate(beats):
        beat_tale = tale if i == 1 or (i == 0 and len(beats) == 1) else None
        best, why, attempts = None, [], []
        for attempt in range(tries):
            text = teller.ask(job_prompt(b["detail"], b["lines"], beat_tale))
            problems = check(text, b["detail"], b["lines"], beat_tale)
            if problems and any(x == "stock" for x in problems):
                fixed = repair(text, b["detail"], b["lines"], beat_tale)
                if fixed and not check(fixed, b["detail"], b["lines"], beat_tale):
                    text, problems = fixed, []
            attempts.append((text, problems))
            if not problems:
                best = text
                break
            why.append(problems)
        if best is None:
            # the cleanest attempt that has no HARD failure beats assembling without Gemma
            HARD = ("first person", "invented reader", "you ", "repeated sentence", "line not kept", "invented:")
            usable = [(len([x for x in pr if not x.startswith(HARD)]) + 5 * len([x for x in pr if x.startswith(HARD)]), t)
                      for t, pr in attempts if not any(x.startswith(HARD) for x in pr)]
            if usable:
                best = min(usable)[1]
        fallback = best is None
        if fallback:
            d = you(b["detail"]).strip().rstrip(".")
            best = d[0].upper() + d[1:] + "." + "".join(" " + l for l in b["lines"])
        paragraphs.append(best)
        report.append({"line": " / ".join(b["lines"]) or None, "tries": len(why) + (0 if fallback else 1), "fallback": fallback, "why": why})
    # A thin day gets room to play, because there is little else to carry the page.
    play = None
    if len(beats) <= 2:
        seeds = [b["lines"][0] for b in beats if b["lines"]]
        play, ok = play_job(teller, [b["detail"] for b in beats], tale, seeds)
        report.append({"line": "play", "tries": 1, "fallback": not ok, "why": []})
    scenes = [s["text"] for s in day.get("scenes", [])]
    out = []
    for i, p in enumerate(paragraphs):
        out.append(p)
        if i < len(scenes):
            out.append(scenes[i])
    out.extend(scenes[len(paragraphs):])
    if play:
        out.append(play)
    # The Book's own business: its authored line, then one small step of the hunt in its own voice.
    if day.get("business"):
        text, ok = book_job(teller, day["business"], "Say one small thing the hunt turned up. It is not the answer.")
        out.append(text)
        report.append({"line": day["business"], "tries": 1, "fallback": not ok, "why": []})
    # The weather, when it is its night: not every night, never two in a row, thin days included.
    mode = weather_mode(day["date"]) if day.get("world") else "skip"
    if mode == "beat":
        text, ok = book_job(teller, day["world"], "Say what the sky was doing, plainly, and one odd small thing the dark did about it.")
        out.insert(max(1, len(out) - 1), text)
        report.append({"line": "weather beat", "tries": 1, "fallback": not ok, "why": []})
    elif mode == "mention":
        sentence = weather_sentence(teller, day["world"])
        if sentence:
            out[0] = out[0] + " " + sentence
        report.append({"line": "weather mention", "tries": 1, "fallback": sentence is None, "why": []})
    return "\n\n".join(out), report


def run_bench(a):
    days = json.loads(Path(a.day).read_text())
    briefs = {n["name"]: n for n in json.loads(Path(a.briefs).read_text())}
    teller = Teller()
    out = []
    for day in days:
        meta = briefs.get("day-" + day["date"], {})
        hard = meta.get("hardNight") == "true"
        tale = meta.get("tale") or ""
        d = dict(day)
        d["tale"] = tale or None
        d["world"] = day.get("world")
        m = re.search(r"My own business tonight \(a thread I may follow if I like\): (.+)", meta.get("brief", ""))
        d["business"] = m.group(1).strip() if m else None
        for k in range(a.takes):
            if hard:
                out.append({"date": day["date"], "take": k + 1, "hard": True, "text": None, "report": []})
                continue
            t0 = time.time()
            text, rep = tell(d, teller)
            out.append({"date": day["date"], "take": k + 1, "hard": False, "text": text, "report": rep})
            print(f"{day['date']} take {k + 1}: {time.time() - t0:.0f}s fallbacks {sum(r['fallback'] for r in rep)}/{len(rep)}", flush=True)
    Path(a.out).write_text(json.dumps(out, indent=1))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("day")
    ap.add_argument("--briefs", default="")
    ap.add_argument("--takes", type=int, default=1)
    ap.add_argument("--out", default="")
    ap.add_argument("--mode", choices=["keep", "free"], default="keep")
    a = ap.parse_args()
    global MODE
    MODE = a.mode
    if a.briefs:
        return run_bench(a)
    day = json.loads(Path(a.day).read_text())
    teller = Teller()
    results = []
    for t in range(a.takes):
        t0 = time.time()
        text, rep = tell(day, teller)
        print(f"=== take {t + 1}  ({time.time() - t0:.0f}s)  fallbacks {sum(r['fallback'] for r in rep)}/{len(rep)}  "
              f"tries {[r['tries'] for r in rep]}\n\n{text}\n")
        results.append({"text": text, "report": rep})
    if a.out:
        Path(a.out).write_text(json.dumps(results, indent=1))


if __name__ == "__main__":
    main()
