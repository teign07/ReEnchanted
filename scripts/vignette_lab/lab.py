#!/usr/bin/env python3
"""The Mac mirror of the phone's Story vignettes.

Feeds real Story Page surfaces (dumped by the Swift test) through the same Gemma 4
E2B 4-bit weights with the phone's sampling and no thinking channel.

    VIGNETTE_SURFACES_OUT=/tmp/v.json swift test --filter testWriteTheVignetteSurfacesWhenAsked
    ~/ReEnchanted-models/venv/bin/python scripts/vignette_lab/lab.py /tmp/v.json --arm current --takes 2 --out /tmp/current.json

`--arm current` rebuilds the old `StoryPagePromptBuilder.compactVignettePrompt`
from the surface metadata (the baseline). `--arm device` sends the exact
`VignetteBrief` the phone now builds, which the Swift test writes per row.
"""
import argparse, json, os, re, sys, time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MODEL = os.path.expanduser("~/ReEnchanted-models/gemma-4-e2b-it-4bit")


def swift_string(path: Path, pattern: str) -> str:
    text = path.read_text()
    m = re.search(pattern + r' = """\n(.*?)\n\s*"""', text, re.S)
    if not m:
        sys.exit(f"could not find {pattern} in {path}")
    lines = m.group(1).split("\n")
    indent = min(len(l) - len(l.lstrip()) for l in lines if l.strip())
    return "\n".join(l[indent:] for l in lines)


def current_instructions() -> str:
    narration = swift_string(ROOT / "Shared/LiteraryContinuity.swift", r"static let storyNarration")
    text = swift_string(ROOT / "InsideCoverApp/CapturePageSheet.swift",
                        r"enum StoryPagePromptBuilder \{\n    static let instructions")
    return text.replace("\\(BookVoice.storyNarration)", narration)


ROLE_TITLES = {"sliceOfLife": "Slice of Life", "progressArc": "Progress Arc", "surprise": "Something Surprising"}


def scene_material(text: str) -> str:
    o, c = text.find("“"), text.rfind("”")
    if o != -1 and c != -1 and o < c:
        return text[o + 1:c].strip()
    prefix = "Story Spark from One-Sentence Souvenir:"
    if text.startswith(prefix):
        return text[len(prefix):].strip().strip('"“” ')
    return text.strip()


def current_prompt(m: dict) -> str:
    """StoryPagePromptBuilder.compactVignettePrompt, line for line."""
    cast = ", ".join(x for x in [m.get("storyRecipeLeadName", ""), m.get("storyRecipeCompanionName", "")] if x)
    if m.get("storySettingName"):
        setting = f"{m['storySettingName']}: {m.get('storySettingDetail') or 'Use it as a physical stage.'}"
    else:
        setting = "Choose one concrete room already implied by the recipe."
    material = scene_material(m.get("storyRecipeGrounding", ""))
    use = m.get("storyRecipeGroundingUse") or "echoed"
    kind = m.get("storyRecipeGroundingKind", "")
    if use == "remembered":
        if kind in ("keptPage", "souvenirDoor"):
            gb = f"A cast member may remember one short phrase from this once: “{material}”. The memory must change what they ask, admit, notice, or decide now. Never recite or interpret the whole Page."
        else:
            gb = f"Let this remembered real detail matter once, without claiming the reader did anything else: {material}"
        su = ("Open one concrete image from the kept sentence into tiny magical physics. Use at most one short phrase and never explain its meaning."
              if m.get("storyRecipeID") == "souvenir-door" else m.get("storyRecipeGroundingDirective", ""))
    elif use == "worldLed":
        gb = "The reader's kept Pages stay closed. The Labyrinth is living its own life. Only supplied weather or hour may tint the room."
        su = m.get("storyRecipeGroundingDirective", "")
    else:
        gb = f"Use this only as an echo: borrow one concrete detail or emotional rhyme. Don't quote it, explain it, debate what it means, or make it the problem to solve: {material}"
        su = "The player memory is a seed, not the plot. Transform one useful detail and let the recipe supply the story."
    decisions_raw = m.get("storyRecipeDecisions") or ""
    decisions = json.loads(decisions_raw) if decisions_raw else []
    if len(decisions) == 3:
        dec = "\n".join(f"- {ROLE_TITLES.get(d['role'], d['role'])}: {d['actionTemplate']} Gain: {d['gainTemplate']} Cost: {d['costTemplate']}" for d in decisions)
    else:
        dec = f"{m.get('storyRecipeChoiceDirective', '')} Give every road a clear gain and a clear cost; no road is the correct answer."
    pressure = f"{m.get('storyRecipeLeadName', '')} wants {m.get('storyTurnWant', '')}. In the way: {m.get('storyTurnObstacle', '')}."
    beats = [b for b in (m.get("storyBeats") or "").split("\n") if b.strip()]
    if len(beats) > 2:
        beats = [beats[0], beats[-1]]
    form = f"{m['storyFormName']}: {beats[0] if beats else 'let one situation turn'}" if m.get("storyFormName") else "Story vignette"
    genre = f"{m['storyGenreName']}: {m.get('storyGenreLens', '')}" if m.get("storyGenreName") else ""
    ex = m.get("storyGenreExemplar") or ""
    exemplar = f"\nVOICE SAMPLE FROM ANOTHER STORY: match only its energy and sentence music; reuse none of its people, props, or lines.\n{ex}" if ex else ""
    signals = [s for s in (m.get("realSignals") or "").split("\n") if s.strip()][:2]
    memories = [s for s in (m.get("entityMemories") or "").split("\n") if s.strip()][:2]
    moves = [s for s in (m.get("chapterTalismanMoves") or "").split("\n") if s.strip()][:1]
    continuity = "\n".join(f"- {x}" for x in signals + memories + moves)
    rbeats = [b for b in (m.get("storyRecipeBeats") or "").split("\n") if b.strip()]
    if len(rbeats) > 2:
        rbeats = [rbeats[0], rbeats[-1]]
    opening = rbeats[0] if rbeats else "Begin after the interesting thing has already started."
    cont = f"WORLD CONTINUITY:\n{continuity}" if continuity else ""
    return f"""Write one playable ReEnchanted story vignette.

SCENE: {m.get('storyRecipeName', '')}
Premise: {m.get('storyRecipePremise', '')}
Opening beat: {opening}
Shape: {form}
Mood and play: {m.get('storyRecipeToneDirective', '')}
Character pressure: {pressure}

CAST: {cast}
{m.get('characterCanon', '')}

SETTING: {setting}
PLAYER MEMORY: {gb}
Recipe use: {su}
{cont}

GENRE: {genre}{exemplar}

END AT THESE THREE REAL DECISIONS:
{dec}

OUTPUT EXACTLY:
SCENE:
340-520 words in 4-7 short paragraphs. Start after the interesting thing has begun. Before the decision, add two concrete turns that make the situation funnier, stranger, cozier, or more urgent. Make the cast want things and do things. End at the decision: don't resolve any road. No headings inside the prose.

SLICE_OF_LIFE_CHOICE:
A vivid 2-5 word button for that authored action.
SLICE_OF_LIFE_PROMPT:
One sentence under 18 words naming what the reader does and what it risks.

PROGRESS_ARC_CHOICE:
A vivid 2-5 word button for that authored action.
PROGRESS_ARC_PROMPT:
One sentence under 18 words naming what the reader does and what it risks.

SURPRISE_CHOICE:
A vivid 2-5 word button for that authored action.
SURPRISE_PROMPT:
One sentence under 18 words naming what the reader does and what it risks.

Return no result prose. Don't mention recipes, prompts, grounding, roles, gains, costs, or mechanics."""


class Teller:
    def __init__(self):
        from mlx_lm import load
        self.model, self.tokenizer = load(MODEL)

    def mask(self, brief: str):
        """BraidWornImages, read from the Swift source, spared where the brief carries the word."""
        src = (ROOT / "Shared/BraidScenePlan.swift").read_text()
        block = src[src.index("enum BraidWornImages"):]
        words = re.findall(r'"( [A-Za-z]+)"', block[:block.index("static let pairs")])
        low = brief.lower()
        ids = []
        for w in words:
            if re.search(r"\b" + re.escape(w.strip().lower()) + r"\b", low):
                continue
            toks = self.tokenizer.encode(w, add_special_tokens=False)
            if len(toks) == 1:
                ids.append(toks[0])
        def proc(tokens, logits):
            if ids:
                logits[:, ids] = -1e9
            return logits
        return proc

    def ask(self, system: str, user: str, max_tokens: int, temp: float, top_p: float = 0.9, masked: bool = False) -> dict:
        from mlx_lm import stream_generate
        from mlx_lm.sample_utils import make_sampler
        msgs = ([{"role": "system", "content": system}] if system else []) + [{"role": "user", "content": user}]
        prompt = self.tokenizer.apply_chat_template(msgs, add_generation_prompt=True, tokenize=False, enable_thinking=False)
        text, last = "", None
        procs = [self.mask(user)] if masked else None
        for r in stream_generate(self.model, self.tokenizer, prompt, max_tokens=max_tokens,
                                 sampler=make_sampler(temp=temp, top_p=top_p), logits_processors=procs):
            text += r.text
            last = r
        return {"text": text.strip(), "tokens": getattr(last, "generation_tokens", None),
                "promptTokens": len(self.tokenizer.encode(prompt)), "finish": getattr(last, "finish_reason", None)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("surfaces")
    ap.add_argument("--arm", default="current")
    ap.add_argument("--takes", type=int, default=2)
    ap.add_argument("--only", default="")
    ap.add_argument("--out", required=True)
    ap.add_argument("--print-prompt", action="store_true")
    a = ap.parse_args()
    rows = json.loads(Path(a.surfaces).read_text())
    if a.only:
        keys = a.only.split(",")
        rows = [r for r in rows if any(k in r["name"] for k in keys)]
    if a.print_prompt:
        print(current_instructions()); print("=" * 80); print(current_prompt(rows[0]["metadata"])); return
    teller = Teller()
    system = current_instructions()
    out, t0 = [], time.time()
    for row in rows:
        if a.arm == "device" and "brief" not in row:
            continue
        for k in range(a.takes):
            if a.arm == "device":
                # The exact brief VignetteBrief builds on the phone, masked like the phone.
                r = teller.ask(row["system"], row["brief"], 600, 0.74, masked=True)
                plan = {"lead": row["cast"][0], "companion": (row["cast"][1:] or [""])[0], "turns": row["happenings"]}
            else:
                r = teller.ask(system, current_prompt(row["metadata"]), 1120, 0.74)
                m = row["metadata"]
                plan = {"lead": m.get("storyRecipeLeadName", ""), "companion": m.get("storyRecipeCompanionName", "")}
            out.append({"recipe": row["name"], "take": k + 1, "plan": plan, **r})
            print(f"[{len(out)}/{len(rows) * a.takes}] {row['name']} {r['tokens']} tok, prompt {r['promptTokens']}, {time.time() - t0:.0f}s", flush=True)
            Path(a.out).write_text(json.dumps(out, indent=2))


if __name__ == "__main__":
    main()
