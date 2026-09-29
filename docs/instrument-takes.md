# Real lute and mandolin for the interface sounds

The interface sounds (`scripts/generate_book_sounds.py`) play **real recorded lute and mandolin notes**,
re-pitched, trimmed and layered by the generator, with the synthesized voices as a fallback for any pitch
the bank doesn't cover.

## Where the notes came from

Generated 2026-09-29 in ElevenLabs Sound Effects (text-to-sound-effect, 19 s, prompt influence 79%, four
variations per request, downloaded as 48 kHz WAV). Prompt shape that works (dry, isolated notes):

> Solo renaissance lute, only the lowest bass strings, single deep plucked notes played one at a time, a new
> note about every one and a half seconds, each note left to ring and fade out before the next, close-miked,
> completely dry, no reverb, no echo, no other instruments, no background noise, no chords, no strumming.

Registers requested: lute pentatonic / low / high / mid-low; mandolin mid / high / low. The model ignores
requested pitches and plays sparsely, so the slicer measures the pitch of whatever comes out.

**Licensing:** these are outputs from the ElevenLabs account; confirm the plan's commercial-use terms cover
shipping them in the app.

## Workflow

```bash
# 1. put takes (wav/mp3) in scripts/instrument_takes/lute/ and scripts/instrument_takes/mandolin/   (git-ignored, ~94 MB)
python3 scripts/ingest_instrument_takes.py            # slice, pitch-label, reject unclear/overlapping notes -> scripts/instrument_bank/
python3 scripts/ingest_instrument_takes.py --selftest # proves the slicer on synthetic takes
python3 scripts/generate_book_sounds.py               # renders every cue; prints "bank gap" for pitches with no real note nearby
BOOK_SOUNDS_NO_BANK=1 python3 scripts/generate_book_sounds.py   # render with the synthesized voices only
```

The sampler re-pitches a real note by at most 3.5 semitones (`MAX_SHIFT`); farther than that it falls back to
the synth so nothing sounds chipmunked or slowed.
