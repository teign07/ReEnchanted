#!/usr/bin/env python3
"""Synthesize ReEnchanted's interface sounds. Reproducible; numpy + scipy.

Usage:
    python3 scripts/generate_book_sounds.py            # render + convert to CAF
    python3 scripts/generate_book_sounds.py --audition # also write the audition page
    python3 scripts/generate_book_sounds.py --only keep,select   # re-render some families

Writes WAVs to a temp dir, converts them to IMA4 CAF (4:1, the format Apple's own
system sounds use) in InsideCoverApp/BookSounds/,
and writes BookSounds/manifest.json (family -> variant count) for the Swift side.

DESIGN LANGUAGE — "moth-lit music box"
  The radio plays acoustic medieval plucks under electronica. The interface
  speaks the same language in miniature: every sound is a *note*, never a noise.
    - kalimba / music-box tines   the everyday voice (taps, selects)
    - lute: the only acoustic voice (simple plucks: warmth and weight)
    - electronic pops, bloops and pop flurries: the ear candy, richer than the plucks
    - glass FM bell               sparkle, the "ear candy" on top
    - wooden tok                  the tactile transient (a knuckle, a stamp)
    - electronic blips + echo     the folktronica glue: pitch glides, ping-pong
    - a little room               small reverb so nothing sounds dry
  Paper is a texture UNDER the notes (a few ms, dull, ~-24 dB), never the star:
  broadband noise swells are what read as a sneeze.

  Everything sits in D pentatonic (D E F# A B). Any two cues that overlap are
  consonant, and it lives comfortably inside the keys the radio tracks use.
  Phone speakers roll off under ~250 Hz, so the content lives at 400 Hz - 6 kHz.

  Families render several variants (round-robin so no two consecutive plays are
  identical) or tiers (the select ladder climbs; the keep streak escalates).
"""
import argparse
import base64
import json
import math
import os
import struct
import subprocess
import tempfile
import wave
from fractions import Fraction

import numpy as np
from scipy import signal

SR = 44100
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'InsideCoverApp', 'BookSounds')
OUT_DIR = os.path.normpath(OUT_DIR)
WORK_DIR = os.path.join(tempfile.gettempdir(), 'book-sounds-v2')

# ---------------------------------------------------------------- pitch ---

PENTA = [0, 2, 4, 7, 9]  # D major pentatonic, semitones above D


def deg(i, octave_base=62):
    """Scale degree i (0 = D4, 5 = D5, -1 = B3 ...) as a frequency in Hz."""
    octave, step = divmod(i, 5)
    midi = octave_base + 12 * octave + PENTA[step]
    return 440.0 * 2 ** ((midi - 69) / 12)


def midi_hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


# ----------------------------------------------------------- primitives ---

def tt(dur):
    return np.arange(int(SR * dur)) / SR


def sos_filter(x, kind, cutoff, order=2):
    nyq = SR / 2
    if isinstance(cutoff, (list, tuple)):
        wn = [min(c / nyq, 0.999) for c in cutoff]
    else:
        wn = min(cutoff / nyq, 0.999)
    sos = signal.butter(order, wn, btype=kind, output='sos')
    return signal.sosfilt(sos, x)


def fade(x, in_ms=1.0, out_ms=8.0):
    x = x.copy()
    a = max(1, int(SR * in_ms / 1000))
    b = max(1, int(SR * out_ms / 1000))
    a, b = min(a, len(x)), min(b, len(x))
    x[:a] *= np.linspace(0, 1, a)
    x[-b:] *= np.linspace(1, 0, b)
    return x


def click(dur_ms=3.0, low=1500, high=6000, level=1.0, rng=None):
    """A few-ms tick of band-limited noise: the physical 'touch' of a note."""
    rng = rng or np.random.default_rng(1)
    n = max(8, int(SR * dur_ms / 1000))
    x = rng.uniform(-1, 1, n)
    x = sos_filter(x, 'bandpass', [low, high])
    return x * np.exp(-np.arange(n) / (n * 0.28)) * level


def kalimba(f, dur=0.6, bright=1.0, decay=5.5, rng=None):
    """Music-box / kalimba tine: fundamental plus inharmonic bar modes that die fast."""
    rng = rng or np.random.default_rng(int(f))
    t = tt(dur)
    modes = [(0.5, 0.34, decay * 1.4), (1.0, 1.00, decay), (2.76, 0.14 * bright, decay * 3.6),
             (5.40, 0.04 * bright, decay * 8), (8.93, 0.01 * bright, decay * 13)]
    y = np.zeros_like(t)
    for ratio, amp, d in modes:
        if f * ratio > 15000:
            continue
        y += amp * np.sin(2 * np.pi * f * ratio * t + rng.uniform(0, 0.4)) * np.exp(-d * t)
    tick = click(2.5, 1000, 3600, 0.07 * bright, rng)
    y[:len(tick)] += tick
    return fade(y, 0.6, 10)


def _string(f, dur, rng, *, pos, rolloff, base_decay, decay_slope, stretch, detune_cents=0.0):
    """Additive plucked string: partials with their own decay, pluck-position comb."""
    t = tt(dur)
    y = np.zeros_like(t)
    for n in range(1, 30):
        fn = f * n * math.sqrt(1 + stretch * n * n)
        if fn > 13000:
            break
        amp = (n ** -rolloff) * abs(math.sin(math.pi * n * pos))
        d = base_decay + decay_slope * n ** 1.05
        y += amp * np.sin(2 * np.pi * fn * t + rng.uniform(0, 6.28)) * np.exp(-d * t)
    return y


def _synth_lute(f, dur=0.9, tone=0.55, rng=None):
    """Renaissance lute (synthesized fallback): gut strings, plucked near the rose, a wooden soundboard.
    Octave-doubled in the bass (as real lute courses are); nasal, warm, short-lived."""
    rng = rng or np.random.default_rng(int(f) + 7)
    y = _string(f, dur, rng, pos=0.13, rolloff=1.55, base_decay=2.8, decay_slope=1.5, stretch=0.0002)
    if f < 260:      # bass courses carry an octave string: this is what a phone speaker can voice
        y += 0.42 * _string(f * 2, dur, rng, pos=0.13, rolloff=1.5, base_decay=3.4, decay_slope=1.8, stretch=0.0002)
    # soundboard: two broad resonances, ~tone-scaled, so it sounds like wood, not a synth string
    body = sos_filter(y, 'bandpass', [200, 520]) * (0.85 + 0.5 * tone) \
        + sos_filter(y, 'bandpass', [700, 1500]) * 0.30
    y = y + body
    thumb = click(5, 400, 2000, 0.16, rng)           # fingertip on gut, soft
    y[:len(thumb)] += thumb
    return fade(y, 0.9, 14)


# ------------------------------------------------ real instrument samples ---
# scripts/ingest_instrument_takes.py slices recorded lute takes into a
# bank of single, pitch-labelled notes. When the bank has a note within MAX_SHIFT
# semitones of what a cue asks for, that real note plays (re-pitched, trimmed,
# level-matched to the synth so every mix balance holds). Anywhere the bank has no
# nearby note, the synthesized voice covers, and the gap is reported at the end.

BANK_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'instrument_bank')
USE_BANK = os.environ.get('BOOK_SOUNDS_NO_BANK') != '1'
MAX_SHIFT = 3.5          # semitones a sample may be re-pitched DOWN before we distrust it
MAX_UP = 6.0             # ...and UP
_BANK = {}
ROUGH_MAX = {'lute': 0.20, 'foley': 9.0}   # see sound_health.py
BANK_GAPS = {}           # instrument -> set of midi notes asked for but not covered


def _load_bank():
    if _BANK or not os.path.exists(os.path.join(BANK_DIR, 'bank.json')):
        return
    with open(os.path.join(BANK_DIR, 'bank.json')) as f:
        for entry in json.load(f):
            with wave.open(os.path.join(BANK_DIR, entry['file'])) as w:
                x = np.frombuffer(w.readframes(w.getnframes()), dtype='<i2').astype(np.float64) / 32768
            if entry['instrument'] not in ('lute', 'foley'):
                continue           # the mandolin is retired: lute and electronics only
            if entry.get('rough', 0.0) > ROUGH_MAX.get(entry['instrument'], 0.24):
                continue           # quality gate: a note with natural string-beating stays out of the mix
            _BANK.setdefault(entry['instrument'], []).append((entry['midi'], entry['f0'], x))


def sample_note(instrument, f, dur, rng, reverse=False, fade_ms=25):
    """A real recorded note at frequency f, `dur` seconds long (or None if the bank
    has nothing close enough). Picks randomly among the two nearest takes, so repeated
    cues get different physical plucks."""
    if not USE_BANK:
        return None
    _load_bank()
    notes = _BANK.get(instrument)
    if not notes:
        return None
    target = 69 + 12 * math.log2(f / 440.0)
    ranked = sorted(notes, key=lambda n: abs(n[0] - target))
    # a note pitched UP shortens and brightens (fine for plucks, up to ~6 st); pitched DOWN it slows (3.5 st)
    close = [n for n in ranked[:4] if -MAX_SHIFT <= target - n[0] <= MAX_UP]
    if not close:
        BANK_GAPS.setdefault(instrument, set()).add(round(target))
        return None
    midi, f0, x = close[int(rng.integers(0, min(2, len(close))))]
    ratio = Fraction(f0 / f).limit_denominator(2000)          # new length = old * f0/f
    y = signal.resample_poly(x, ratio.numerator, ratio.denominator)
    y = y[:int(SR * dur)]
    fade_n = min(len(y), int(SR * fade_ms / 1000))
    if fade_n:
        y = y.copy()
        y[-fade_n:] *= np.linspace(1, 0, fade_n)
    return y[::-1].copy() if reverse else y


def _match_level(real, ref):
    """Scale a real recording to the synth's loudness over the note's first 300 ms, so
    swapping voices never changes a cue's internal balance."""
    n = min(len(real), len(ref), int(SR * 0.3))
    r = np.sqrt(np.mean(real[:n] ** 2)) + 1e-9
    t = np.sqrt(np.mean(ref[:n] ** 2)) + 1e-9
    return real * (t / r)


def lute(f, dur=0.9, tone=0.55, rng=None):
    rng = rng or np.random.default_rng(int(f) + 7)
    ref = _synth_lute(f, dur, tone, np.random.default_rng(int(f) + 7))
    real = sample_note('lute', f, dur, rng)
    return ref if real is None else _match_level(real, ref)


def sample_gesture(instrument, f, lead, tail, rng, prefer_late_peak=True, fade_in_ms=8, fade_out_ms=40):
    """A slice of a recorded gesture (tremolo swell, foley creak) around its loudest moment:
    `lead` seconds before the peak, `tail` after. Re-pitched to f when the gesture is pitched
    (pass f=None for foley). Returns None if the bank has nothing usable."""
    if not USE_BANK:
        return None
    _load_bank()
    notes = _BANK.get(instrument)
    if not notes:
        return None
    if f:
        target = 69 + 12 * math.log2(f / 440.0)
        cands = [n for n in notes if abs(n[0] - target) <= MAX_SHIFT]
        if not cands:
            BANK_GAPS.setdefault(instrument, set()).add(round(target))
            return None
    else:
        cands = notes

    def peak_frac(n):
        x = n[2]
        env = np.sqrt(np.convolve(x * x, np.ones(2205) / 2205, mode='same'))
        return int(np.argmax(env)) / max(1, len(x))
    if prefer_late_peak:
        late = [n for n in cands if peak_frac(n) > 0.45]
        cands = late or cands
    midi, f0, x = cands[int(rng.integers(0, len(cands)))]
    if f:
        ratio = Fraction(f0 / f).limit_denominator(2000)
        x = signal.resample_poly(x, ratio.numerator, ratio.denominator)
    env = np.sqrt(np.convolve(x * x, np.ones(1323) / 1323, mode='same'))
    peak = int(np.argmax(env))
    a = max(0, peak - int(lead * SR))
    b = min(len(x), peak + int(tail * SR))
    y = x[a:b].copy()
    fi, fo = int(SR * fade_in_ms / 1000), int(SR * fade_out_ms / 1000)
    if len(y) > fi + fo:
        y[:fi] *= np.linspace(0, 1, fi)
        y[-fo:] *= np.linspace(1, 0, fo)
    return y


def swell(step, lead, tail, rng):
    """An electronic bloom that peaks `lead` seconds in: a cascade of tiny pops climbing the triad,
    quickening and growing. (It replaces the mandolin tremolo swell.) `step` is a scale degree."""
    n = int((lead + tail) * SR)
    out = np.zeros(n)
    tones = [d for d in (0, 2, 3, 5, 7, 8, 10) if d >= step - 5][:7]
    pops = max(6, int(lead / 0.06))
    at = 0.0
    for k in range(pops):
        frac = k / max(1, pops - 1)
        pop = candy_pop(deg(tones[min(len(tones) - 1, int(frac * (len(tones) - 1) + 0.5))]), dur=0.09)
        g = 0.15 + 0.85 * frac ** 1.3
        i0 = int(at * SR)
        if i0 >= n:
            break
        seg = pop[:n - i0]
        out[i0:i0 + len(seg)] += seg * g
        at += 0.095 - 0.055 * frac                       # quickening
    return fade(out, 4, 60)


def creak(lead=0.3, tail=0.5, rng=None, cutoff=2400):
    """A slice of real leather-cover foley, darkened so it reads as wood and hide, not hiss."""
    rng = rng or np.random.default_rng(3)
    y = sample_gesture('foley', None, lead, tail, rng, prefer_late_peak=False, fade_in_ms=30, fade_out_ms=120)
    if y is None:
        return None
    return sos_filter(y, 'lowpass', cutoff, order=2)


def plop(f_hi, f_lo=None, dur=0.16, tau=0.032, rising=False):
    """A round little bubble: a sine that glides down (plop) or up (pop) and dies fast. Ear candy on
    tiny gestures; pitched, so a run of them is a soft xylophone of bubbles, not clicks."""
    f_lo = f_lo or f_hi * 0.55
    t = tt(dur)
    a, b = (f_lo, f_hi) if rising else (f_hi, f_lo)
    f = b + (a - b) * np.exp(-t / 0.018)
    phase = 2 * np.pi * np.cumsum(f) / SR
    y = np.sin(phase) + 0.18 * np.sin(2 * phase)
    env = np.minimum(t / 0.002, 1.0) * np.exp(-t / tau)
    return fade(sos_filter(y * env, 'lowpass', 2600, order=2), 0.5, 12)


def candy_pop(f, at_peak=1.0, falling=False, dur=0.13):
    """Electronic ear candy: one rounded sine bubble with a soft sub under it. Laid a beat after an acoustic
    note, at the note's own pitch, so it reads as the tail of the pluck turning into a synth. Rounded:
    lowpassed hard, no click. `falling` gives the low 'boop' used for closing."""
    hi = f
    lo = f * 0.62
    y = plop(hi, lo, dur=dur, tau=0.034, rising=not falling)
    sub = plop(hi * 0.5, lo * 0.5, dur=dur, tau=0.04, rising=not falling) * 0.45
    out = sos_filter(y + sub, 'lowpass', 1700, order=4)
    return out * at_peak


PLUCK_LEAD = 1.25


def soft(f, dur=0.35, rng=None, cutoff=3000):
    """A short, rounded lute pluck: the everyday note."""
    return sos_filter(pluck(f, dur, rng=rng), 'lowpass', cutoff, order=2)


def pluck(f, dur=0.9, tone=0.55, rng=None):
    """The Book's plucked voice: lute, simple and warm, at every pitch (the recorded bank reaches D6).
    No harp and no mandolin: bj's ear. The brightness comes from the electronic pops instead."""
    y = lute(f, dur, tone, rng) * PLUCK_LEAD
    if f >= 500:     # a lute pitched up past its middle gets wiry and beats; round it the way the mandolin was rounded
        y = sos_filter(y, 'lowpass', 2500 if f < 700 else 2000, order=3) * 1.15
    return y


def lute_led(f, dur=0.9, tone=0.55, rng=None):
    """The lute at any pitch (kept as a name: the everyday cues call it)."""
    return pluck(f, dur, tone, rng)


def add_pops(tr, steps, at, gap=0.045, gain=0.2, crescendo=False, falling=False, width=0.6, dur=0.11, lp=1800):
    """Lay several tiny electronic pops onto a Track, tumbling together across the stereo field: the
    'more complex' half of the sound language (the lute stays simple). `steps` are scale degrees;
    pops are pitched at the lute's own chord tones so nothing beats."""
    for k, st in enumerate(steps):
        frac = k / max(1, len(steps) - 1)
        g = gain * ((0.55 + 0.45 * frac) if crescendo else 1.0)
        pan = width * (-1 if k % 2 == 0 else 1) * (0.35 + 0.65 * frac)
        tr.add(candy_pop(deg(st), falling=falling, dur=dur), at + gap * k, pan=pan, gain=g)


BELL_TRIM = 0.62      # glass is garnish: lute leads, pops sparkle
SPARKLE_TRIM = 0.65


def bell(f, dur=1.0, index=2.6, ratio=3.5, tau=0.35, rng=None):
    index = index * 0.75
    """Glass FM bell: bright at the strike, mellowing as the index falls."""
    t = tt(dur)
    idx = index * np.exp(-t / 0.10)
    y = np.sin(2 * np.pi * f * t + idx * np.sin(2 * np.pi * f * ratio * t))
    y += 0.35 * np.sin(2 * np.pi * f * 2.0 * t) * np.exp(-t / (tau * 0.4))
    y = sos_filter(y * np.exp(-t / tau), 'lowpass', 3800, order=2) * BELL_TRIM
    return fade(y, 0.6, 14)


def wood(f, dur=0.14, drop=0.30, tau=0.028, click_level=0.35, rng=None):
    """A wooden tok: a pitched body that sags a little, plus a knuckle of noise."""
    rng = rng or np.random.default_rng(int(f) + 3)
    t = tt(dur)
    fm = f * (1 + drop * np.exp(-t / 0.010))
    phase = 2 * np.pi * np.cumsum(fm) / SR
    y = np.sin(phase) * np.exp(-t / tau)
    y += 0.42 * np.sin(2.32 * phase) * np.exp(-t / (tau * 0.55))
    y += 0.18 * np.sin(4.1 * phase) * np.exp(-t / (tau * 0.30))
    tick = click(2.2, 900, 3600, click_level, rng)
    y[:len(tick)] += tick
    return fade(y, 0.4, 8)


def blip(f0, f1, dur=0.16, vib=0.0, tone=0.5):
    """Electronic pitch glide: the folktronica glue. Soft triangle-ish, filtered."""
    t = tt(dur)
    shape = (t / dur) ** 0.7
    f = f0 + (f1 - f0) * shape
    phase = 2 * np.pi * np.cumsum(f * (1 + vib * np.sin(2 * np.pi * 9 * t))) / SR
    y = np.sin(phase) + 0.30 * np.sin(2 * phase) + 0.10 * np.sin(3 * phase) * tone
    env = np.minimum(t / 0.006, 1.0) * np.exp(-t / (dur * 0.55))
    return fade(y * env, 0.5, 10)


def pad(freqs, dur=1.6, attack=0.25, cutoff=2400):
    """Soft detuned sine pad for ceremonies. Slow in, slow out."""
    t = tt(dur)
    y = np.zeros_like(t)
    for f in freqs:
        for cents in (-6, 0, 7):
            fd = f * 2 ** (cents / 1200)
            y += np.sin(2 * np.pi * fd * t + fd) + 0.25 * np.sin(4 * np.pi * fd * t)
    env = np.minimum(t / attack, 1.0) * np.exp(-t / (dur * 0.5))
    return sos_filter(y * env, 'lowpass', cutoff)


def sparkle(rng, count=6, span=0.16, lo=None, hi=None, tau=0.14, level=0.4):
    """A scatter of tiny electronic pops: ear candy (it was glass notes, which were the bright part).
    Chord tones only (A, D, F#, A, D across two octaves), so no two pops ever sit a whole step apart inside
    one critical band. Returns [(mono, offset)]."""
    notes = []
    tones = [3, 5, 7, 8, 10]                  # A4 D5 F#5 A5 D6
    last = -1
    for k in range(count):
        pick = int(rng.integers(0, len(tones)))
        if pick == last:
            pick = (pick + 2) % len(tones)    # never the same tone twice running
        last = pick
        pop = candy_pop(deg(tones[pick]), falling=bool(rng.integers(0, 2)), dur=float(rng.uniform(0.08, 0.12)))
        slot = span / max(1, count)           # evenly spaced with a little jitter: pops tumble but never stack
        notes.append((pop * level * 3.2, k * slot + float(rng.uniform(0, 0.4 * slot))))
    return notes


# --------------------------------------------------------------- mixing ---

class Track:
    """A stereo mixing bed. Every voice is placed at a time, pan and gain."""

    def __init__(self, dur):
        self.n = int(SR * dur)
        self.l = np.zeros(self.n)
        self.r = np.zeros(self.n)

    def add(self, mono, at=0.0, pan=0.0, gain=1.0, haas=0.0):
        """pan -1..1 (equal power). haas: ms of width delay on the far side."""
        start = int(SR * at)
        if start >= self.n:
            return
        seg = mono[:self.n - start] * gain
        theta = (pan + 1) * math.pi / 4
        gl, gr = math.cos(theta), math.sin(theta)
        self.l[start:start + len(seg)] += seg * gl
        rseg = seg * gr
        if haas > 0:
            d = int(SR * haas / 1000)
            rseg = np.concatenate([np.zeros(d), rseg])[:len(seg)]
        self.r[start:start + len(seg)] += rseg
        return self

    def stereo(self):
        return np.stack([self.l, self.r])


def make_ir(t60, seed, predelay_ms=6, damp=6500):
    rng = np.random.default_rng(seed)
    n = int(SR * (t60 * 1.15))
    ir = []
    for _ in range(2):
        noise = rng.normal(0, 1, n)
        t = np.arange(n) / SR
        env = np.exp(-6.9 * t / t60)
        ch = sos_filter(noise * env, 'lowpass', damp)
        ch = sos_filter(ch, 'highpass', 220)
        ir.append(ch)
    pd = int(SR * predelay_ms / 1000)
    ir = np.stack(ir)
    ir = np.concatenate([np.zeros((2, pd)), ir], axis=1)
    return ir / (np.sqrt(np.sum(ir ** 2, axis=1, keepdims=True)) + 1e-9)


_IR_CACHE = {}


def reverb(stereo, t60=0.5, wet=0.22, seed=11, damp=5200, tail=None):
    key = (t60, seed, damp)
    if key not in _IR_CACHE:
        _IR_CACHE[key] = make_ir(t60, seed, damp=damp)
    ir = _IR_CACHE[key]
    tail = t60 * 1.1 if tail is None else tail
    pad_n = int(SR * tail)
    dry = np.concatenate([stereo, np.zeros((2, pad_n))], axis=1)
    wet_sig = np.stack([signal.fftconvolve(dry[c], ir[c])[:dry.shape[1]] for c in range(2)])
    return dry + wet * wet_sig * 0.35


def pingpong(stereo, delay=0.16, feedback=0.42, taps=4, cutoff=4200, wet=0.5):
    """Folktronica echo bouncing left/right, each repeat a little darker."""
    mono = stereo.sum(axis=0) * 0.5
    extra = int(SR * delay * (taps + 1))
    out = np.concatenate([stereo, np.zeros((2, extra))], axis=1)
    cur = mono
    for k in range(1, taps + 1):
        cur = sos_filter(cur, 'lowpass', max(1200, cutoff * (0.82 ** k)), order=1)
        gain = (feedback ** k) * wet
        s = int(SR * delay * k)
        ch = 0 if k % 2 == 1 else 1
        out[ch, s:s + len(cur)] += cur[:out.shape[1] - s] * gain
        # leak a little into the other side so it doesn't feel hard-panned
        out[1 - ch, s:s + len(cur)] += cur[:out.shape[1] - s] * gain * 0.22
    return out


def saturate(stereo, drive=1.0):
    return np.tanh(stereo * drive) / math.tanh(drive)


def finish(stereo, peak, dc_hz=70, tail_db=-48, out_ms=30):
    """DC-block, trim the dead tail, fade, soft-limit, normalise to `peak`."""
    stereo = np.stack([sos_filter(stereo[c], 'highpass', dc_hz, order=1) for c in range(2)])
    mag = np.max(np.abs(stereo), axis=0)
    top = mag.max() or 1.0
    live = np.nonzero(mag > top * 10 ** (tail_db / 20))[0]
    if len(live):
        stereo = stereo[:, :live[-1] + int(SR * 0.02)]
    stereo = np.stack([sos_filter(stereo[c], 'lowpass', 6200, order=2) for c in range(2)])
    warm = np.stack([sos_filter(stereo[c], 'bandpass', [180, 650], order=1) for c in range(2)])
    stereo = stereo + 0.34 * warm      # rounded: a bed of low-mid body under everything
    stereo = np.stack([fade(stereo[c], 0.5, out_ms) for c in range(2)])
    stereo = saturate(stereo / (np.abs(stereo).max() or 1.0), 1.15)
    stereo = stereo / (np.abs(stereo).max() or 1.0) * peak
    return stereo


# ------------------------------------------------------------ rendering ---

RENDERED = {}     # family -> [file stems], filled as we go
AUDITION = []     # (family, stem, wav_path)


# (low-pass Hz, presence tilt, active-RMS range dBFS, peak ceiling). Ranges mirror sound_health.LIMITS;
# the research behind them is in docs/sound-comfort.md.
PROFILE_SHAPE = {
    'warm':     (3300, 0.30, (-33.0, -24.0), 0.33),
    'wake':     (4200, 0.16, (-28.0, -22.0), 0.42),
    'ceremony': (4800, 0.10, (-26.0, -20.0), 0.50),
    # everyday touches (taps, selections, opening a card, a small success): pleasing and low key
    'soft':     (3200, 0.30, (-37.0, -31.0), 0.22),
    # the Book waking: warm, low and enveloping, like a hearth, with no glitter
    'hearth':   (2500, 0.40, (-31.0, -24.0), 0.40),
    # small pleasures that repeat or follow a big moment (Book Today, Pagewright): a wink, not a statement
    'candy':    (3400, 0.30, (-36.0, -29.0), 0.22),
    # under-the-reading sounds (page turns): felt more than heard
    'whisper':  (2800, 0.35, (-40.0, -33.0), 0.14),
}


def comfort_shape(stereo, profile):
    """Roll off the ear's most sensitive, most fatiguing region (2.5-5 kHz), then hold the cue's
    loudness inside its profile's range and soft-limit any hot peak. Never boost."""
    lp, tilt, (lo, hi), cap = PROFILE_SHAPE[profile]
    y = np.stack([sos_filter(stereo[c], 'lowpass', lp, order=2) for c in range(2)])
    if tilt:
        y = y - tilt * np.stack([sos_filter(y[c], 'highpass', 1800, order=1) for c in range(2)])
    mono = y.mean(axis=0)
    peak = np.abs(mono).max() + 1e-9
    act = mono[np.abs(mono) > 0.01 * peak]
    rms_db = 20 * math.log10(np.sqrt(np.mean(act ** 2)) + 1e-9)
    target = min(max(rms_db, lo + 0.8), hi - 0.8)
    y = y * 10 ** ((target - rms_db) / 20)
    y = cap * np.tanh(y / cap)
    # the soft limiter shaved a little level: aim once more, then limit again
    mono = y.mean(axis=0)
    act = mono[np.abs(mono) > 0.01 * (np.abs(mono).max() + 1e-9)]
    now = 20 * math.log10(np.sqrt(np.mean(act ** 2)) + 1e-9)
    y = y * 10 ** (min(3.0, max(-3.0, target - now)) / 20)
    return cap * np.tanh(y / cap)


def write(family, index, stereo):
    stereo = comfort_shape(stereo, PROFILE_OF.get(family, 'warm'))
    os.makedirs(WORK_DIR, exist_ok=True)
    os.makedirs(OUT_DIR, exist_ok=True)
    stem = f'{family}-{index}'
    wav_path = os.path.join(WORK_DIR, f'{stem}.wav')
    pcm = np.clip(stereo.T, -1, 1)
    pcm = (pcm * 32767).astype('<i2')
    with wave.open(wav_path, 'w') as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    subprocess.run(['afconvert', '-f', 'caff', '-d', 'ima4', wav_path,
                    os.path.join(OUT_DIR, f'{stem}.caf')], check=True)
    RENDERED.setdefault(family, []).append(stem)
    AUDITION.append((family, stem, wav_path))
    print(f'  {stem}.caf  {stereo.shape[1] / SR * 1000:.0f}ms  peak {np.abs(stereo).max():.2f}')


def rng_for(family, i):
    return np.random.default_rng(hash_seed(family) + i * 101)


def hash_seed(s):
    h = 2166136261
    for ch in s:
        h = ((h ^ ord(ch)) * 16777619) & 0xFFFFFFFF
    return h


# Which comfort profile each family answers to (limits live in sound_health.py; the research behind them
# in docs/sound-comfort.md). warm = murmur under the fingers; wake = melodic and clear, never harsh;
# ceremony = the loudest, brightest things the Book does, and rare.
PROFILE_OF = {
    **{f: 'warm' for f in ('press', 'open', 'knock', 'knockreply', 'ink', 'nothing', 'belief')},
    **{f: 'soft' for f in ('tap', 'select', 'dismiss', 'close', 'glowopen', 'undo', 'refresh', 'error', 'toggle', 'seal',
                            'peek', 'confirm', 'begin')},
    **{f: 'whisper' for f in ('turn', 'turnback')},
    **{f: 'candy' for f in ('today', 'lift', 'drop')},
    **{f: 'wake' for f in ('keep', 'braidstart', 'braidcomplete', 'rise', 'constellation', 'fae', 'jump',
                            'radiolock')},
    **{f: 'hearth' for f in ('overture',)},
    **{f: 'ceremony' for f in ('ceremony', 'whisper')},
}


FAMILIES = {}


def family(name):
    def deco(fn):
        FAMILIES[name] = fn
        return fn
    return deco


# ------------------------------------------------------- everyday cues ---

@family('press')
def press():
    """Touch-down: a tiny wooden 'thip'. Barely there; the release carries the note."""
    for i in range(4):
        rng = rng_for('press', i)
        f = [560, 640, 520, 600][i]
        tr = Track(0.09)
        tr.add(wood(f, 0.07, drop=0.18, tau=0.014, click_level=0.09, rng=rng), 0, pan=[-0.15, 0.1, -0.05, 0.15][i])
        write('press', i, finish(reverb(tr.stereo(), 0.18, 0.10), 0.10))


@family('tap')
def tap():
    """The everyday confirm: one kalimba tine with a wooden knuckle under it."""
    for i, d in enumerate([2, 3, 4, 5]):   # F#4 A4 B4 D5: a step lower than before, where the lute is rounder
        rng = rng_for('tap', i)
        tr = Track(0.36)
        tr.add(sos_filter(lute_led(deg(d), 0.30, rng=rng), 'lowpass', 2000, order=4), 0,
               pan=[-0.2, 0.15, -0.1, 0.2][i], haas=0.6, gain=0.95)
        tr.add(kalimba(deg(d), 0.24, bright=0.35, decay=9, rng=rng), 0, gain=0.10)
        tr.add(wood(deg(d - 5) * 2, 0.06, drop=0.2, tau=0.012, click_level=0.12, rng=rng), 0, gain=0.30)
        tr.add(candy_pop(deg(d + 5)), 0.15, pan=[0.25, -0.2, 0.15, -0.25][i], gain=0.20)   # the electronica tail
        write('tap', i, finish(reverb(tr.stereo(), 0.28, 0.20), 0.30))


@family('select')
def select():
    """The ladder: ten rising notes. Swift climbs it while you keep choosing."""
    for i in range(10):
        rng = rng_for('select', i)
        f = deg(-3 + i)         # F#3 up to E5: the lute's warm range; the old ladder's F#5 top was the bright part
        tr = Track(0.55)
        pan = -0.35 + 0.7 * ((i % 4) / 3)
        cutoff = (2200, 2200, 2100, 2100, 2000, 1900, 1800, 1700, 1600, 1500)[i]   # darker as it climbs, never brighter
        tr.add(sos_filter(lute_led(f, 0.45, rng=rng), 'lowpass', cutoff, order=4), 0,
               pan=pan, haas=0.8, gain=1.0)
        tr.add(kalimba(f, 0.30, bright=0.3, decay=8, rng=rng), 0.0, pan=-pan, gain=0.07)   # a whisper of tine; no glass
        tr.add(candy_pop(f * (2 if i < 6 else 1)), 0.2, pan=-pan, gain=0.17)   # the electronica tail: an octave up, unison at the top (no beating)
        if i >= 5:                       # the upper half of the climb tumbles: a second, smaller pop follows
            tr.add(candy_pop(f * (2 if i < 6 else 1) * 1.5, dur=0.09), 0.27, pan=pan, gain=0.11)
        out = reverb(tr.stereo(), 0.34, 0.22)
        if i >= 7:                       # only the summit echoes
            out = pingpong(out, 0.12, 0.42, 2, wet=0.14)
        write('select', i, finish(out, 0.32))


@family('open')
def open_page():
    """A leaf opens: a quick lute run up the D-major triad (D F# A D' F# A'), then a little tumble of
    electronic pops carrying on up the triad. Triad tones are a minor third or more apart, so nothing inside the run beats."""
    triad = [0, 2, 3, 5, 7, 8, 10]                    # D4 F#4 A4 D5 F#5 A5 D6
    shapes = [(0, 1, 3), (1, 2, 4), (0, 2, 3), (2, 3, 5), (1, 3, 4)]
    for i, sh in enumerate(shapes):
        rng = rng_for('open', i)
        tr = Track(1.0)
        tr.add(click(9, 600, 2000, 0.08, rng), 0, pan=0.1, gain=0.5)                  # cover leaf flick, dull
        for k, j in enumerate(sh):
            tr.add(pluck(deg(triad[j]), 0.7, rng=rng), 0.018 + 0.052 * k,
                   pan=-0.3 + 0.3 * k, gain=0.9 - 0.08 * k, haas=0.7)
        start = min(sh[-1] + 1, len(triad) - 4)            # three distinct triad tones above the run (topping at A5)
        nxt = triad[start:start + 3]
        add_pops(tr, nxt, 0.018 + 0.052 * len(sh) + 0.02, gap=0.05, gain=0.20, crescendo=True)
        out = pingpong(reverb(tr.stereo(), 0.55, 0.28), 0.14, 0.36, 3, wet=0.18)
        write('open', i, finish(out, 0.34))


@family('dismiss')
def dismiss():
    """A leaf closes: two soft falling notes, muted, with a small wooden settle."""
    for i in range(4):
        rng = rng_for('dismiss', i)
        tr = Track(0.7)
        top = 5 + i
        p1 = sos_filter(pluck(deg(top), 0.4, tone=0.3, rng=rng), 'lowpass', 2600)
        p2 = sos_filter(pluck(deg(top - 2), 0.5, tone=0.3, rng=rng), 'lowpass', 2200)
        tr.add(p1, 0.0, pan=0.2, gain=0.9)
        tr.add(p2, 0.075, pan=-0.2, gain=0.85)
        tr.add(wood(deg(top - 5) , 0.08, drop=0.25, tau=0.02, click_level=0.15, rng=rng), 0.075, gain=0.30)
        write('dismiss', i, finish(reverb(tr.stereo(), 0.38, 0.20), 0.28))


@family('close')
def close_room():
    """Closing a room (the Glow menu's X): low and dark, falling, with a wooden latch, like a lid settling.
    Nothing rises and nothing sparkles, so it cannot be mistaken for opening (a rising glass ping) or for
    choosing (the lute ladder in the middle of the staff)."""
    for i, (a, b) in enumerate([(-5, -7), (-5, -6), (-3, -5)]):      # D3>A2  D3>B2  F#3>D3
        rng = rng_for('close', i)
        tr = Track(0.75)
        tr.add(wood(300 + 25 * i, 0.09, drop=0.3, tau=0.03, click_level=0.16, rng=rng), 0.0, gain=0.55)
        tr.add(sos_filter(lute_led(deg(a), 0.5, tone=0.35, rng=rng), 'lowpass', 1500, order=2), 0.0, pan=0.12, gain=0.9)
        tr.add(sos_filter(lute_led(deg(b), 0.6, tone=0.3, rng=rng), 'lowpass', 1300, order=2), 0.11, pan=-0.12, gain=0.85)
        tr.add(candy_pop(deg(b + 5), falling=True, dur=0.16), 0.30, pan=0.0, gain=0.22)   # a low rounded 'boop' settling
        write('close', i, finish(reverb(tr.stereo(), 0.4, 0.18), 0.26))


@family('glowopen')
def glow_open():
    """Opening the Glow menu: the close's counterpart. A soft wooden unlatch, two lute plucks climbing a
    fifth or a third (nothing mandolin, nothing glass), and the rounded electronic pop rising at the end.
    Warm and mid-staff; the old open was a wiry glass ping."""
    for i, (a, b) in enumerate([(0, 3), (-2, 2), (2, 5)]):        # D4>A4   A3>F#4   F#4>D5
        rng = rng_for('glowopen', i)
        tr = Track(0.85)
        tr.add(wood(330 + 20 * i, 0.07, drop=0.28, tau=0.026, click_level=0.14, rng=rng), 0.0, gain=0.45)
        tr.add(sos_filter(lute_led(deg(a), 0.45, tone=0.4, rng=rng), 'lowpass', 2000, order=4), 0.02, pan=-0.15, gain=0.95)
        tr.add(sos_filter(lute_led(deg(b), 0.6, tone=0.4, rng=rng), 'lowpass', 1900, order=4), 0.13, pan=0.15, gain=0.95)
        tr.add(candy_pop(deg(b + 5)), 0.30, pan=0.0, gain=0.21)       # the electronica tail, rising
        write('glowopen', i, finish(reverb(tr.stereo(), 0.45, 0.20), 0.28))


@family('keep')
def keep():
    """Keeping a page: eight tiers that climb with the day's keeps (the first keep of the day is tier 0;
    the eighth and every later one is tier 7). A stamp, a rising chord-tone run, a shimmer; later
    tiers double the run a lute-octave lower, slip an electronic pop-flurry under it, and end on a
    rolled chord. Each keep of the day is a little bigger than the last."""
    body = [-5, 0, 2, 3, 5, 7, 8, 10]                   # D3 D4 F#4 A4 D5 F#5 A5 D6: chord tones only
    for tier in range(8):
        rng = rng_for('keep', tier)
        run = body[:min(len(body), 4 + tier)]
        gap = 0.062 if tier < 5 else 0.05               # the flourish quickens
        dur = 1.5 + 0.22 * tier
        tr = Track(dur)
        # the stamp: a lute-body thump + wooden knock, weight for the phone speaker's low-mids
        tr.add(pluck(deg(-5), 0.55, tone=0.8, rng=rng), 0.0, gain=0.95)
        tr.add(wood(300, 0.11, drop=0.35, tau=0.035, click_level=0.3, rng=rng), 0.0, gain=0.7)
        # the rising run
        for k, step in enumerate(run[1:]):
            at = 0.085 + gap * k
            pan = -0.45 + 0.9 * (k / max(1, len(run) - 2))
            tr.add(pluck(deg(step), 0.9, rng=rng), at, pan=pan, gain=0.85, haas=0.9)
            if tier >= 5 and step >= 2:                 # the same climb, a lute-octave below
                tr.add(pluck(deg(step - 5), 0.9, rng=rng), at + 0.004, pan=-pan * 0.6, gain=0.42)
        end = 0.085 + gap * len(run)
        tr.add(bell(deg(run[-1]), 1.0, index=1.6, ratio=3.5, tau=0.55, rng=rng), end - 0.03, pan=0.0, gain=0.34)
        if tier >= 2:
            for mono, off in sparkle(rng, count=2 + tier, span=0.10 + 0.06 * tier, level=0.24 + 0.02 * tier):
                tr.add(mono, end + off, pan=float(rng.uniform(-0.8, 0.8)), gain=1.0)
        if tier >= 4:
            tr.add(pad([deg(3), deg(5), deg(7)], 1.4, attack=0.12, cutoff=3000), end - 0.05, gain=0.06)
        if tier >= 1:                                   # the pops tumble out of the run, more of them each tier
            add_pops(tr, [5, 7, 8, 10, 12][:2 + tier // 2 + (tier >= 4)], end - 0.02, gap=0.045, gain=0.18, crescendo=True)
        if tier >= 6:                                   # a pop flurry blooming under the top, quickening
            tr.add(swell(5, 0.55, 0.10, rng), max(0.0, end - 0.55), pan=0.0, gain=0.36)
        if tier >= 7:                                   # the last flourish: a rolled D chord
            for j, step in enumerate([-5, 3, 5, 7]):
                tr.add(pluck(deg(step), 1.3, rng=rng), end + 0.06 + 0.035 * j, pan=-0.5 + 0.33 * j, gain=0.8, haas=0.8)
        out = reverb(tr.stereo(), 0.7 + 0.1 * tier, 0.28 + 0.02 * tier)
        out = pingpong(out, 0.15, 0.42, 3 + (tier >= 3), wet=0.20 + 0.02 * tier)
        # each keep of the day is a little bigger than the last: ~-1.5 dB for the first, ~+1.5 dB for the eighth
        write('keep', tier, finish(out, 0.44 + 0.02 * tier) * 10 ** ((-1.5 + 0.43 * tier) / 20))


@family('undo')
def undo():
    """Undo: a quick electronic 'bwip' sliding down into a pluck. Rewinding, lightly."""
    for i in range(3):
        rng = rng_for('undo', i)
        tr = Track(0.55)
        f = deg(4 + i)
        tr.add(blip(f * 1.2, f * 0.75, 0.12, vib=0.0, tone=0.0), 0, pan=0.1, gain=0.4)
        tr.add(pluck(deg(2 + i), 0.5, tone=0.4, rng=rng), 0.08, pan=-0.2, gain=0.95)
        write('undo', i, finish(reverb(tr.stereo(), 0.3, 0.18), 0.28))


@family('braidstart')
def braid_start():
    """The weave begins: six alternating tines climbing, hard L/R, unresolved."""
    for i in range(2):
        rng = rng_for('braidstart', i)
        tr = Track(1.0)
        seq = [3, 5, 7, 8, 7, 5] if i == 0 else [5, 7, 8, 10, 8, 7]     # chord tones: A D F# A ...
        for k, s in enumerate(seq):
            tr.add(soft(deg(s), 0.4, rng), 0.06 * k,
                   pan=(-0.7 if k % 2 == 0 else 0.7), gain=0.85 + 0.03 * k, haas=0.4)
        tr.add(blip(deg(0), deg(5), 0.32, vib=0.01, tone=0.2), 0, pan=0, gain=0.14)
        out = pingpong(reverb(tr.stereo(), 0.45, 0.22), 0.09, 0.45, 3, wet=0.25)
        write('braidstart', i, finish(out, 0.30))


@family('braidcomplete')
def braid_complete():
    """The weave lands: a full arpeggio resolving onto a held chord. Three cadences."""
    cadences = [
        [0, 2, 3, 5, 7],
        [1, 3, 5, 6, 8],
        [0, 3, 5, 7, 10],
    ]
    for i, c in enumerate(cadences):
        rng = rng_for('braidcomplete', i)
        tr = Track(2.4)
        for k, s in enumerate(c):
            tr.add(pluck(deg(2 + s), 1.2, rng=rng), 0.075 * k,
                   pan=-0.5 + k * 0.25, gain=0.85, haas=0.8)
        land = 0.075 * len(c)
        tr.add(pad([deg(2 + c[-1]), deg(2 + c[-1] - 3), deg(2 + c[-1] - 1)], 1.8, attack=0.18), land - 0.05, gain=0.09)
        tr.add(bell(deg(2 + c[-1]), 1.6, index=1.6, ratio=3.5, tau=0.75, rng=rng), land, gain=0.38)
        for mono, off in sparkle(rng, count=7, span=0.4, level=0.24):
            tr.add(mono, land + 0.05 + off, pan=float(rng.uniform(-0.9, 0.9)))
        out = pingpong(reverb(tr.stereo(), 1.2, 0.34), 0.18, 0.45, 4, wet=0.22)
        write('braidcomplete', i, finish(out, 0.46))


@family('refresh')
def refresh():
    """Something arrives: a tiny upward blip, a lute note, and a three-pop tumble like a signal locking."""
    for i in range(4):
        rng = rng_for('refresh', i)
        tr = Track(0.9)
        f = deg(2 + i)
        tr.add(blip(f * 0.75, f, 0.07, tone=0.0), 0, gain=0.18)
        tr.add(pluck(f, 0.6, rng=rng), 0.04, pan=[-0.3, 0.3, -0.15, 0.2][i], gain=0.9)
        add_pops(tr, [2 + i, 3 + i, 5 + i], 0.11, gap=0.06, gain=0.20, crescendo=True)
        out = pingpong(reverb(tr.stereo(), 0.5, 0.25), 0.15, 0.42, 3, wet=0.26)
        write('refresh', i, finish(out, 0.28))


@family('error')
def error():
    """'Not that.' Two falling wooden notes: a shake of the head, never a buzzer."""
    for i in range(3):
        rng = rng_for('error', i)
        tr = Track(0.7)
        hi = [deg(3), deg(4), deg(3)][i]
        lo = [deg(2), deg(3), deg(1)][i]
        tr.add(wood(hi, 0.14, drop=0.25, tau=0.045, click_level=0.22, rng=rng), 0, pan=0.12)
        tr.add(wood(lo, 0.20, drop=0.25, tau=0.06, click_level=0.2, rng=rng), 0.12, pan=-0.12, gain=0.95)
        tr.add(sos_filter(pluck(lo / 2, 0.4, tone=0.25, rng=rng), 'lowpass', 1600), 0.12, gain=0.40)
        write('error', i, finish(reverb(tr.stereo(), 0.28, 0.16), 0.30))


@family('knock')
def knock_family():
    """Your knuckle on the cover. Modal wood: mostly 300-900 Hz so a phone can voice it."""
    for i in range(3):
        rng = rng_for('knock', i)
        base = [330, 305, 355][i]
        t = tt(0.24)
        body = np.zeros_like(t)
        for ratio, amp, d in [(1, 0.7, 42), (2.42, 0.7, 62), (3.9, 0.42, 90), (6.1, 0.16, 130)]:
            body += amp * np.sin(2 * np.pi * base * ratio * t) * np.exp(-d * t)
        thud = click(4, 250, 2400, 0.7, rng)
        body[:len(thud)] += thud
        tr = Track(0.4)
        tr.add(fade(body, 0.3, 20), 0, gain=0.9)
        write('knock', i, finish(reverb(tr.stereo(), 0.3, 0.14), 0.34))


@family('knockreply')
def knock_reply():
    """The Book knocks back from inside: two muffled knocks, then one glint of magic."""
    for i in range(2):
        rng = rng_for('knockreply', i)
        tr = Track(1.5)
        for k, (at, base) in enumerate([(0.0, 190 + 8 * i), (0.22, 172 + 8 * i)]):
            t = tt(0.24)
            body = np.zeros_like(t)
            for ratio, amp, d in [(1, 1.0, 34), (2.42, 0.5, 60), (3.9, 0.22, 95)]:
                body += amp * np.sin(2 * np.pi * base * ratio * t) * np.exp(-d * t)
            body = sos_filter(body, 'lowpass', 1500)
            tr.add(fade(body, 0.4, 20), at, gain=0.85 - 0.1 * k, pan=-0.1 + 0.2 * k)
        tr.add(pluck(deg(4 + i), 1.0, rng=rng), 0.46, pan=0.2, gain=0.55)
        tr.add(bell(deg(9 + i), 1.0, index=1.2, ratio=3.5, tau=0.42, rng=rng), 0.46, pan=0.2, gain=0.18)
        for mono, off in sparkle(rng, count=4, span=0.25, level=0.14):
            tr.add(mono, 0.55 + off, pan=float(rng.uniform(-0.7, 0.7)))
        out = pingpong(reverb(tr.stereo(), 0.8, 0.30), 0.19, 0.45, 3, wet=0.22)
        write('knockreply', i, finish(out, 0.38))


# ----------------------------------------------- moments that had no sound ---

def damped(y, tau=0.075, cutoff=1900):
    """Palm-mute a pluck: a fast, dark decay, so it lands as a soft 'tok' with a pitch, then is gone."""
    t = np.arange(len(y)) / SR
    return fade(sos_filter(y, 'lowpass', cutoff, order=2) * np.exp(-t / tau), 1.5, 20)


@family('turn')
def turn():
    """Page turn forward: ONE soft, damped lute note. Nothing else. Five pitches from the
    D-major triad so a run of flips is a gentle, uneven murmur; every note is round and short."""
    for i, step in enumerate([-2, 0, 2, 3, 0]):                    # A3 D4 F#4 A4 D4
        rng = rng_for('turn', i)
        tr = Track(0.32)
        tr.add(damped(pluck(deg(step), 0.3, tone=0.5, rng=rng)), 0.0, pan=[-0.1, 0.1, -0.05, 0.12, 0.0][i])
        write('turn', i, finish(reverb(tr.stereo(), 0.22, 0.10), 0.16))


@family('turnback')
def turn_back():
    """Turning back: the same single note, a touch lower and darker."""
    for i, step in enumerate([-3, -2, 0]):                          # F#3 A3 D4
        rng = rng_for('turnback', i)
        tr = Track(0.32)
        tr.add(damped(pluck(deg(step), 0.3, tone=0.4, rng=rng), tau=0.08, cutoff=1600), 0.0, pan=[0.1, -0.1, 0.05][i])
        write('turnback', i, finish(reverb(tr.stereo(), 0.2, 0.09), 0.15))


@family('toggle')
def toggle():
    """On rises, off falls. Two variants each; index 0-1 = on, 2-3 = off."""
    for i in range(4):
        on = i < 2
        rng = rng_for('toggle', i)
        tr = Track(0.5)
        r = 4 + (i % 2)
        lo, hi = (deg(r), deg(r + 2))
        first, second = (lo, hi) if on else (hi, lo)
        tr.add(wood(first * 0.5, 0.05, drop=0.15, tau=0.012, click_level=0.12, rng=rng), 0, gain=0.45)
        tr.add(soft(first, 0.25, rng), 0, pan=-0.1, gain=0.85)
        tr.add(soft(second, 0.36, rng), 0.07, pan=0.15, gain=0.95)
        write('toggle', i, finish(reverb(tr.stereo(), 0.3, 0.2), 0.25))


@family('ink')
def ink():
    """Sentence-end while writing: the quill lifts. One soft plink, five pitches."""
    for i in range(5):
        rng = rng_for('ink', i)
        tr = Track(0.6)
        f = deg(2 + i)        # a step lower than it was: the lute is rounder there
        tr.add(soft(f, 0.45, rng), 0, pan=[-0.2, 0.1, 0.25, -0.1, 0.15][i], haas=0.7, gain=1.1)
        tr.add(candy_pop(f * 0.5, dur=0.09), 0.09, pan=-0.1, gain=0.16)   # a tiny low pop under the plink's tail, in place of the glass
        write('ink', i, finish(reverb(tr.stereo(), 0.4, 0.24), 0.185))


@family('radiolock')
def radio_lock():
    """A station locks: bip-bip and a little chord. The dial's own voice."""
    rng = rng_for('radiolock', 0)
    tr = Track(1.0)
    tr.add(blip(deg(5), deg(6), 0.05, tone=0.1), 0.0, gain=0.5, pan=-0.3)
    tr.add(blip(deg(6), deg(8), 0.05, tone=0.1), 0.05, gain=0.55, pan=0.3)
    tr.add(blip(deg(8), deg(10), 0.06, tone=0.1), 0.11, gain=0.6, pan=-0.2)
    for j, s in enumerate((5, 7, 8)):
        tr.add(pluck(deg(s), 0.7, rng=rng), 0.22 + 0.012 * j, gain=0.7, pan=(-0.3, 0, 0.3)[j])
    out = pingpong(reverb(tr.stereo(), 0.6, 0.26), 0.13, 0.45, 3, wet=0.25)
    write('radiolock', 0, finish(out, 0.32))


# -------------------------------------------------------- the Cast, arriving ---

@family('fae')
def fae():
    """Arrivals, one per kind. Timed to the haptic rhythms already in AppSupport."""
    kinds = ['generic', 'pixie', 'goblin', 'sprite', 'salamander', 'dwarf', 'unseelie']
    for i, kind in enumerate(kinds):
        rng = rng_for('fae', i)
        tr = Track(2.0)
        if kind == 'pixie':          # haptic: 0, .045, .14, .20
            for k, (at, s) in enumerate([(0, 5), (0.045, 7), (0.14, 8), (0.20, 10), (0.26, 12)]):   # D5 F#5 A5 D6 F#6 (chord tones)
                tr.add(soft(deg(s), 0.4, rng), at, pan=[-0.8, 0.7, -0.4, 0.8, 0.0][k], gain=0.8)
                tr.add(bell(deg(s), 0.5, index=1.0, ratio=3.0, tau=0.13, rng=rng), at,
                       pan=[-0.8, 0.7, -0.4, 0.8, 0.0][k], gain=0.35)
            for mono, off in sparkle(rng, count=9, span=0.35, level=0.2):
                tr.add(mono, 0.28 + off, pan=float(rng.uniform(-0.9, 0.9)))
        elif kind == 'goblin':       # haptic: 0, .09, .17 — heavy, cheeky
            for at, f, g in [(0, 110, 0.9), (0.09, 92, 0.75), (0.17, 124, 0.85)]:
                tr.add(wood(f * 2, 0.13, drop=0.3, tau=0.04, click_level=0.3, rng=rng), at, gain=g)
                tr.add(pluck(f, 0.4, tone=0.85, rng=rng), at, gain=0.5)
            tr.add(kalimba(deg(1), 0.5, decay=6, rng=rng), 0.30, gain=0.5, pan=0.3)
            tr.add(kalimba(deg(0), 0.6, decay=6, rng=rng), 0.38, gain=0.55, pan=-0.3)
        elif kind == 'sprite':       # haptic: rising 0, .07, .15, .25
            for k, at in enumerate([0, 0.07, 0.15, 0.25]):   # rising chord tones A5 D6 F#6 A6, plucked, glass behind
                tr.add(soft(deg([7, 8, 10, 12][k]), 0.6, rng), at, pan=-0.6 + 0.4 * k, gain=0.85)
                tr.add(bell(deg([7, 8, 10, 12][k]), 0.7, index=1.0, ratio=3.5, tau=0.3, rng=rng), at,
                       pan=-0.6 + 0.4 * k, gain=0.32)
            tr.add(blip(deg(5), deg(12), 0.3, vib=0.01, tone=0.1), 0, gain=0.10)
        elif kind == 'salamander':   # warm, ember-crackle
            for k, at in enumerate([0, 0.07, 0.14, 0.22]):
                tr.add(pluck(deg(-2 + 2 * k), 0.9, tone=0.9, rng=rng), at, gain=0.85, pan=-0.3 + 0.2 * k)
            for _ in range(14):
                tr.add(click(3, 1500, 7000, 0.5, rng), float(rng.uniform(0.05, 0.9)),
                       pan=float(rng.uniform(-0.8, 0.8)), gain=float(rng.uniform(0.05, 0.16)))
        elif kind == 'dwarf':        # haptic: 0, .28 — anvil, low
            tr.add(pluck(deg(-5), 1.2, tone=0.95, rng=rng), 0, gain=0.9)
            tr.add(bell(midi_hz(62), 1.2, index=3.5, ratio=2.4, tau=0.4, rng=rng), 0, gain=0.55)
            tr.add(wood(330, 0.12, drop=0.3, tau=0.04, click_level=0.5, rng=rng), 0, gain=0.7)
            tr.add(pluck(deg(-3), 1.2, tone=0.95, rng=rng), 0.28, gain=0.85)
            tr.add(bell(midi_hz(59), 1.2, index=3.2, ratio=2.4, tau=0.35, rng=rng), 0.28, gain=0.45)
        elif kind == 'unseelie':     # minor, hollow, a reversed bell
            f0 = midi_hz(57)   # A3
            for at, m, g in [(0, 57, 0.9), (0.13, 60, 0.75), (0.41, 63, 0.85)]:   # A C Eb: diminished cloud
                tr.add(pluck(midi_hz(m), 1.0, tone=0.35, rng=rng), at, gain=g, pan=(-0.3 if m == 57 else 0.3))
            rev = bell(midi_hz(75), 1.0, index=2.2, ratio=3.5, tau=0.5, rng=rng)[::-1]
            tr.add(rev, 0.0, gain=0.30)
            tr.add(pad([f0, midi_hz(63)], 1.6, attack=0.4, cutoff=1400), 0.1, gain=0.07)
        else:                        # generic fae: wonder chord, up and open
            for k, at in enumerate([0, 0.13, 0.26]):
                tr.add(pluck(deg(3 + 2 * k), 1.0, rng=rng), at, gain=0.85, pan=-0.4 + 0.4 * k)
            tr.add(bell(deg(11), 1.2, index=1.8, ratio=3.5, tau=0.5, rng=rng), 0.28, gain=0.36)
            for mono, off in sparkle(rng, count=5, span=0.3, level=0.18):
                tr.add(mono, 0.3 + off, pan=float(rng.uniform(-0.8, 0.8)))
        out = pingpong(reverb(tr.stereo(), 0.9, 0.30), 0.17, 0.42, 3, wet=0.2)
        write('fae', i, finish(out, 0.42))


@family('constellation')
def constellation():
    """n stars found, n = 2...7. One glass note per star, 70 ms apart, then a wide bloom."""
    for n in range(2, 8):
        rng = rng_for('constellation', n)
        tr = Track(2.2)
        ladder = [5, 7, 8, 10, 12, 13, 15]          # D5 F#5 A5 D6 F#6 A6 D7: chord tones, no whole steps
        for k in range(n):
            tr.add(soft(deg(ladder[k]), 0.7, rng), 0.07 * k, pan=-0.7 + 1.4 * (k / max(1, n - 1)), gain=0.85)
            tr.add(bell(deg(ladder[k]), 0.9, index=1.2, ratio=3.5, tau=0.36, rng=rng), 0.07 * k,
                   pan=-0.7 + 1.4 * (k / max(1, n - 1)), gain=0.42)
        bloom = 0.07 * n + 0.10
        tr.add(pad([deg(ladder[n - 1]), deg(ladder[max(0, n - 3)])], 1.5, attack=0.2, cutoff=2600), bloom, gain=0.06)
        for mono, off in sparkle(rng, count=6, span=0.5, level=0.18):
            tr.add(mono, bloom + off, pan=float(rng.uniform(-0.9, 0.9)))
        out = pingpong(reverb(tr.stereo(), 1.1, 0.34), 0.2, 0.46, 4, wet=0.22)
        write('constellation', n - 2, finish(out, 0.38))


@family('belief')
def belief():
    """Belief given: 1-5 coin-bright plinks (75 ms apart), then a warm settling note."""
    for amount in range(1, 6):
        rng = rng_for('belief', amount)
        tr = Track(1.4)
        for k in range(amount):
            tr.add(soft(deg([5, 7, 8, 10, 12][k]), 0.4, rng), 0.075 * k,
                   pan=-0.4 + 0.2 * k, gain=0.9)
            tr.add(bell(deg([10, 12, 13, 15, 17][k]), 0.35, index=0.8, ratio=3.0, tau=0.08, rng=rng), 0.075 * k + 0.004, gain=0.10)
        settle = 0.075 * amount + 0.12
        tr.add(pluck(deg(3), 0.9, rng=rng), settle, gain=0.85)
        tr.add(bell(deg(8), 0.9, index=1.0, ratio=3.5, tau=0.38, rng=rng), settle, gain=0.22)
        out = pingpong(reverb(tr.stereo(), 0.7, 0.26), 0.16, 0.4, 3, wet=0.2)
        write('belief', amount - 1, finish(out, 0.34))


@family('rise')
def rise():
    """A page rises out of the pile. Tier 0 common ... 2 rare (rarity >= 80 gets a coda)."""
    for tier in range(3):
        rng = rng_for('rise', tier)
        tr = Track(1.6)
        for k, at in enumerate([0, 0.06, 0.13]):
            tr.add(soft(deg([3, 5, 7][k] + (1 if tier == 2 else 0) * 0), 0.5, rng), at, pan=-0.3 + 0.3 * k, gain=0.9)
        tr.add(blip(deg(2), deg(9 + tier), 0.22, vib=0.008, tone=0.1), 0, gain=0.12)
        if tier >= 1:
            tr.add(bell(deg(11 + tier), 0.9, index=1.8, ratio=3.5, tau=0.4, rng=rng), 0.16, gain=0.30)
        if tier >= 2:      # the coda at 0.34 s, matching the extra haptic
            tr.add(pluck(deg(3), 1.0, rng=rng), 0.34, gain=0.8)
            tr.add(pad([deg(3), deg(5), deg(7)], 1.2, attack=0.15, cutoff=3000), 0.34, gain=0.07)
            for mono, off in sparkle(rng, count=6, span=0.4, level=0.2):
                tr.add(mono, 0.36 + off, pan=float(rng.uniform(-0.8, 0.8)))
        out = pingpong(reverb(tr.stereo(), 0.8, 0.28), 0.16, 0.42, 3, wet=0.2)
        write('rise', tier, finish(out, 0.30 + 0.05 * tier))


@family('jump')
def jump():
    """Book-jumping: 0 start, 1 deeper, 2 stabilize, 3 return. Timed to the haptics."""
    # start: an accelerating flutter of tines ending in a hard wooden landing at 0.31 s
    rng = rng_for('jump', 0)
    tr = Track(1.6)
    for k, at in enumerate([0, 0.06, 0.12, 0.19]):
        tr.add(kalimba(deg(3 + k), 0.4, decay=8, rng=rng), at, pan=-0.5 + 0.35 * k, gain=0.6 + 0.08 * k)
    tr.add(blip(deg(0), deg(10), 0.3, vib=0.012, tone=0.4), 0, gain=0.20)
    tr.add(wood(300, 0.18, drop=0.4, tau=0.06, click_level=0.6, rng=rng), 0.31, gain=0.95)
    tr.add(pluck(deg(0), 1.0, tone=0.9, rng=rng), 0.31, gain=0.8)
    tr.add(bell(deg(10), 1.0, index=2.0, ratio=3.5, tau=0.45, rng=rng), 0.31, gain=0.30)
    write('jump', 0, finish(pingpong(reverb(tr.stereo(), 0.9, 0.3), 0.18, 0.42, 3, wet=0.2), 0.42))
    # deeper: dark descending glass, slow
    tr = Track(1.5)
    tr.add(pluck(deg(-4), 1.2, tone=0.7, rng=rng), 0, gain=0.8)
    tr.add(bell(deg(3), 1.0, index=2.4, ratio=3.5, tau=0.5, rng=rng), 0.0, gain=0.4)
    tr.add(pluck(deg(-5), 1.2, tone=0.7, rng=rng), 0.16, gain=0.8)
    tr.add(bell(deg(1), 1.0, index=2.4, ratio=3.5, tau=0.5, rng=rng), 0.16, gain=0.32)
    write('jump', 1, finish(reverb(tr.stereo(), 1.0, 0.34), 0.34))
    # stabilize: four dwindling taps at 0, .12, .24, .39
    tr = Track(1.2)
    for k, (at, s) in enumerate([(0, 5), (0.12, 4), (0.24, 3), (0.39, 5)]):
        tr.add(kalimba(deg(s), 0.5, decay=6, rng=rng), at, pan=-0.2 + 0.13 * k, gain=0.9 - 0.15 * k)
    tr.add(pad([deg(3), deg(5)], 1.0, attack=0.1, cutoff=2600), 0.39, gain=0.05)
    write('jump', 2, finish(pingpong(reverb(tr.stereo(), 0.7, 0.28), 0.15, 0.4, 3, wet=0.2), 0.32))
    # return home: warm descending arpeggio
    tr = Track(1.8)
    for k, (at, s) in enumerate([(0, 8), (0.10, 7), (0.20, 5), (0.34, 3), (0.52, 0)]):
        tr.add(pluck(deg(s), 1.0, rng=rng), at, pan=0.4 - 0.2 * k, gain=0.8)
    tr.add(bell(deg(5), 1.4, index=1.5, ratio=3.5, tau=0.7, rng=rng), 0.52, gain=0.32)
    write('jump', 3, finish(pingpong(reverb(tr.stereo(), 1.0, 0.32), 0.19, 0.42, 3, wet=0.2), 0.36))


@family('nothing')
def nothing():
    """The Nothing presses in. Levels 1-4. Hollow and low; a fold in the air."""
    for lvl in range(1, 5):
        rng = rng_for('nothing', lvl)
        tr = Track(1.6)
        tr.add(pluck(midi_hz(50), 1.0, tone=0.5, rng=rng), 0, gain=0.85)
        tr.add(wood(200, 0.16, drop=0.4, tau=0.05, click_level=0.3, rng=rng), 0, gain=0.7)
        if lvl >= 2:
            tr.add(pluck(midi_hz(49), 1.0, tone=0.5, rng=rng), 0.19, gain=0.8)
        if lvl >= 4:
            tr.add(pluck(midi_hz(46), 1.2, tone=0.4, rng=rng), 0.58, gain=0.8)
        rev = bell(midi_hz(72), 1.0, index=2.0, ratio=3.5, tau=0.4, rng=rng)[::-1]
        tr.add(rev, 0.0, gain=0.14 + 0.03 * lvl)
        write('nothing', lvl - 1, finish(reverb(tr.stereo(), 1.0, 0.36, damp=3800), 0.34))


@family('ceremony')
def ceremony():
    """0: month bound (sewn, warm, long). 1: press ready (foil stamp, metallic)."""
    rng = rng_for('ceremony', 0)
    # haptic: seven beats 0 .10 .20 .30 .46 .68 .94(the big one)
    tr = Track(4.2)
    for k, (at, s) in enumerate([(0, 0), (0.10, 2), (0.20, 3), (0.30, 5), (0.46, 7), (0.68, 8)]):
        tr.add(pluck(deg(s), 1.2, rng=rng), at, pan=-0.6 + 0.24 * k, gain=0.8)
    tr.add(pluck(deg(-5), 2.0, tone=0.9, rng=rng), 0.94, gain=1.0)
    tr.add(wood(230, 0.16, drop=0.35, tau=0.05, click_level=0.5, rng=rng), 0.94, gain=0.8)
    tr.add(pad([deg(0), deg(2), deg(3), deg(5)], 3.0, attack=0.3, cutoff=3000), 0.94, gain=0.11)
    tr.add(bell(deg(10), 2.4, index=2.0, ratio=3.5, tau=1.0, rng=rng), 0.94, gain=0.38)
    for mono, off in sparkle(rng, count=14, span=1.2, level=0.24):
        tr.add(mono, 1.0 + off, pan=float(rng.uniform(-0.9, 0.9)))
    write('ceremony', 0, finish(pingpong(reverb(tr.stereo(), 1.6, 0.36), 0.21, 0.46, 5, wet=0.22), 0.50))
    # press ready: approach, hard stamp at .18, release, confirming stamp, metallic settle
    tr = Track(2.4)
    tr.add(blip(midi_hz(45), midi_hz(57), 0.16, tone=0.3), 0, gain=0.35)
    tr.add(wood(170, 0.2, drop=0.4, tau=0.07, click_level=0.9, rng=rng), 0.18, gain=1.0)
    tr.add(pluck(deg(-5), 1.0, tone=0.95, rng=rng), 0.18, gain=0.9)
    tr.add(bell(midi_hz(62), 1.6, index=3.4, ratio=2.7, tau=0.55, rng=rng), 0.18, gain=0.4)
    tr.add(wood(230, 0.10, drop=0.3, tau=0.03, click_level=0.6, rng=rng), 0.31, gain=0.7)
    for k, s in enumerate([5, 7, 10]):
        tr.add(bell(deg(s), 1.4, index=1.6, ratio=3.5, tau=0.6, rng=rng), 0.5 + 0.09 * k, pan=-0.3 + 0.3 * k, gain=0.34)
    write('ceremony', 1, finish(pingpong(reverb(tr.stereo(), 1.1, 0.3), 0.17, 0.42, 3, wet=0.18), 0.48))



# ------------------------------------------------ the everyday register ---
# Three levels of voice. Fills (open, braidcomplete, keep, overture...) are for impactful moments:
# opening the app, keeping a page, opening a major room, binding an edition. Everything ordinary
# (selecting, opening a card inside a room, a small success, a small start) gets one of these: a
# single pleasing gesture that never asks for attention.

@family('peek')
def peek():
    """Opening something inside a room: one soft note that scoops up into pitch, like a page lifting."""
    for i, step in enumerate([0, 2, 3, -2, 5]):                      # D4 F#4 A4 A3 D5
        rng = rng_for('peek', i)
        f = deg(step)
        tr = Track(0.5)
        scoop = blip(f * 0.84, f, 0.05, vib=0.0, tone=0.0)
        tr.add(scoop, 0.0, pan=[-0.1, 0.1, 0.0, -0.05, 0.1][i], gain=0.12)
        tr.add(damped(pluck(f, 0.4, tone=0.5, rng=rng), tau=0.11, cutoff=2300), 0.03, pan=[-0.1, 0.1, 0.0, -0.05, 0.1][i], gain=0.95)
        write('peek', i, finish(reverb(tr.stereo(), 0.3, 0.14), 0.2))


@family('confirm')
def confirm():
    """A small success: two soft notes, root then a fifth up, the second left to breathe."""
    for i, (a, b) in enumerate([(0, 3), (-2, 2), (2, 5), (3, 7)]):    # D4>A4  A3>F#4  F#4>D5  A4>F#5
        rng = rng_for('confirm', i)
        tr = Track(0.7)
        tr.add(damped(pluck(deg(a), 0.3, rng=rng), tau=0.1, cutoff=2400), 0.0, pan=-0.12, gain=0.75)
        tr.add(damped(pluck(deg(b), 0.5, rng=rng), tau=0.16, cutoff=2600), 0.085, pan=0.12, gain=0.95)
        tr.add(bell(deg(b), 0.5, index=0.6, ratio=2.0, tau=0.14, rng=rng), 0.09, pan=0.2, gain=0.07)
        write('confirm', i, finish(reverb(tr.stereo(), 0.4, 0.16), 0.22))


@family('begin')
def begin():
    """Something is starting: a single low note leaning forward."""
    for i, step in enumerate([-2, 0, 2]):                              # A3 D4 F#4
        rng = rng_for('begin', i)
        f = deg(step)
        tr = Track(0.45)
        tr.add(damped(pluck(f, 0.35, tone=0.45, rng=rng), tau=0.12, cutoff=2000), 0.0, pan=[-0.08, 0.08, 0.0][i], gain=0.9)
        tr.add(blip(f, f * 1.19, 0.10, vib=0.0, tone=0.0), 0.05, gain=0.10)
        write('begin', i, finish(reverb(tr.stereo(), 0.28, 0.12), 0.18))


# ----------------------------------------------- the launch, and the day ---

@family('overture')
def overture():
    """The Book waking, warm and comforting, in three beats timed to OpeningBookLoadingView:
    0 appear + title writing (t=0, ~0.65 s lead-in), 1 cover opens (0.45 s reveal; the chord lands at
    ~0.4 s), 2 'found your place' as the desk fades in. Low lute, a soft hum underneath, no glass,
    no sparkle, almost no echo: a hearth, not a fanfare."""
    # 0: a candle catches; the title is written in four unhurried strokes
    rng = rng_for('overture', 0)
    tr = Track(1.8)
    tr.add(pluck(deg(-5), 1.2, tone=0.6, rng=rng), 0.0, gain=0.8)
    tr.add(pad([deg(-5), deg(-2)], 1.6, attack=0.45, cutoff=1500), 0.0, gain=0.10)
    for k, (at, step) in enumerate([(0.12, 0), (0.26, 2), (0.42, 3), (0.60, 5)]):     # D4 F#4 A4 D5
        tr.add(soft(deg(step), 0.6, rng, cutoff=2200), at, pan=-0.25 + 0.17 * k, gain=0.55 + 0.05 * k, haas=0.5)
    out = reverb(tr.stereo(), 1.2, 0.26, damp=3200)
    write('overture', 0, finish(out, 0.30))

    # 1: the cover swings, warm light spills: a leather creak, a low open chord, a long soft hum
    rng = rng_for('overture', 1)
    tr = Track(3.0)
    cr = creak(0.25, 0.55, rng, cutoff=1700)
    if cr is not None:
        tr.add(cr, 0.0, gain=0.30)
    tr.add(pluck(deg(-5), 1.6, tone=0.6, rng=rng), 0.0, gain=0.85)
    tr.add(wood(300, 0.12, drop=0.35, tau=0.04, click_level=0.2, rng=rng), 0.0, gain=0.35)
    sw = swell(0, 0.34, 0.06, rng)
    tr.add(sos_filter(sw, 'lowpass', 1800, order=2), 0.05, pan=0.0, gain=0.34)
    for k, (at, step) in enumerate([(0.36, -5), (0.40, -2), (0.44, 0), (0.48, 2), (0.52, 3)]):   # D3 A3 D4 F#4 A4, rolled
        tr.add(pluck(deg(step), 1.6, tone=0.55, rng=rng), at, pan=-0.35 + 0.17 * k, gain=0.85, haas=0.8)
    tr.add(pad([deg(-5), deg(-2), deg(0), deg(2)], 2.5, attack=0.30, cutoff=1700), 0.34, gain=0.14)
    out = pingpong(reverb(tr.stereo(), 1.7, 0.34, damp=3000), 0.24, 0.32, 2, wet=0.07)
    write('overture', 1, finish(out, 0.46))

    # 2: 'Found your place.'
    rng = rng_for('overture', 2)
    tr = Track(1.6)
    tr.add(soft(deg(0), 0.8, rng, cutoff=2300), 0.0, pan=-0.15, gain=0.85)
    tr.add(soft(deg(3), 0.9, rng, cutoff=2400), 0.12, pan=0.15, gain=0.9)
    tr.add(pad([deg(-2), deg(0)], 1.2, attack=0.25, cutoff=1500), 0.0, gain=0.06)
    write('overture', 2, finish(reverb(tr.stereo(), 0.9, 0.24, damp=3200), 0.26))


@family('today')
def today():
    """Book Today surfaces: a soft answer to the expressive opening, not a second fanfare. A low lute
    breath and a slow three-note climb up the triad, a single grain of glass. Three roots to rotate."""
    for i, climb in enumerate([(3, 5, 7), (2, 3, 5), (5, 7, 8)]):    # A D F# | F# A D | D F# A
        rng = rng_for('today', i)
        tr = Track(1.6)
        tr.add(pluck(deg(-5 + (0, 2, 3)[i]), 0.9, tone=0.6, rng=rng), 0.0, gain=0.55)
        for k, step in enumerate(climb):
            tr.add(soft(deg(step), 0.6, rng, cutoff=2600), 0.07 + 0.13 * k, pan=-0.3 + 0.3 * k, gain=0.7 + 0.1 * k, haas=0.6)
        tr.add(bell(deg(climb[-1] + 5), 0.8, index=0.8, ratio=3.0, tau=0.3, rng=rng), 0.07 + 0.13 * 2, pan=0.25, gain=0.12)
        out = pingpong(reverb(tr.stereo(), 0.7, 0.20), 0.2, 0.35, 2, wet=0.14)
        write('today', i, finish(out, 0.3))


@family('seal')
def seal():
    """The dismiss threshold: engaged (0) is a crisp wooden latch with a lute glint;
    released (1) is a soft, lower tock. Mid-gesture, so tiny."""
    rng = rng_for('seal', 0)
    tr = Track(0.5)
    tr.add(wood(700, 0.06, drop=0.2, tau=0.016, click_level=0.18, rng=rng), 0.0, gain=0.8)
    tr.add(pluck(deg(7), 0.3, rng=rng), 0.012, gain=0.65, pan=0.15)
    write('seal', 0, finish(reverb(tr.stereo(), 0.25, 0.16), 0.20))
    tr = Track(0.3)
    tr.add(wood(620, 0.05, drop=0.2, tau=0.014, click_level=0.2, rng=rng), 0.0, gain=0.7)
    tr.add(pluck(deg(4), 0.2, tone=0.3, rng=rng), 0.01, gain=0.3, pan=-0.1)
    write('seal', 1, finish(reverb(tr.stereo(), 0.18, 0.12), 0.14))


@family('lift')
def lift():
    """Pagewright: a mark leaves the paper. A little rising 'pop', pitched, with a wink of lute."""
    for i, f in enumerate([deg(2), deg(3), deg(4), deg(5), deg(7)]):
        rng = rng_for('lift', i)
        tr = Track(0.35)
        tr.add(plop(f, f * 0.6, 0.11, tau=0.024, rising=True), 0.0, pan=[-0.15, 0.1, 0.15, -0.1, 0.05][i], gain=0.9)
        tr.add(soft(f * 2, 0.16, rng, cutoff=1800), 0.012, gain=0.15)
        write('lift', i, finish(reverb(tr.stereo(), 0.2, 0.10), 0.16))


@family('drop')
def drop():
    """Pagewright: a mark lands on the paper. A round 'plop', pitched a little lower, with a soft lute thud."""
    for i, f in enumerate([deg(1), deg(2), deg(3), deg(4), deg(5)]):
        rng = rng_for('drop', i)
        tr = Track(0.4)
        tr.add(plop(f * 1.2, f * 0.6, 0.16, tau=0.034), 0.0, pan=[0.1, -0.1, 0.15, -0.15, 0.0][i], gain=0.9)
        tr.add(damped(pluck(f * 0.5, 0.2, tone=0.5, rng=rng), tau=0.06, cutoff=1500), 0.004, gain=0.35)
        write('drop', i, finish(reverb(tr.stereo(), 0.22, 0.10), 0.18))


@family('whisper')
def whisper():
    """The Book's own notification chime (installed as Library/Sounds/BookWhisper.caf)."""
    rng = rng_for('whisper', 0)
    tr = Track(3.6)
    tr.add(pluck(deg(-5), 1.4, tone=0.8, rng=rng), 0.0, gain=0.8)
    for k, s_ in enumerate([3, 5, 7, 8, 7, 5]):
        tr.add(pluck(deg(s_), 1.0, rng=rng), 0.16 + 0.13 * k, pan=-0.5 + 0.2 * k, gain=0.8, haas=0.8)
    tr.add(bell(deg(10), 2.2, index=2.0, ratio=3.5, tau=1.0, rng=rng), 0.16 + 0.13 * 6, gain=0.36)
    for mono, off in sparkle(rng, count=10, span=0.9, level=0.2):
        tr.add(mono, 1.0 + off, pan=float(rng.uniform(-0.9, 0.9)))
    out = pingpong(reverb(tr.stereo(), 1.6, 0.34), 0.2, 0.44, 5, wet=0.22)
    write('whisper', 0, finish(out, 0.60))


# ------------------------------------------------------------------ main ---

def write_manifest():
    manifest_path = os.path.join(OUT_DIR, 'manifest.json')
    existing = {}
    if os.path.exists(manifest_path):
        with open(manifest_path) as f:
            existing = json.load(f)
    for name, stems in RENDERED.items():
        existing[name] = len(stems)
    with open(manifest_path, 'w') as f:
        json.dump(dict(sorted(existing.items())), f, indent=2)
        f.write('\n')


def clean_stale(active):
    """Remove renders from earlier palettes so the bundle carries only what plays."""
    keep = {f'{s}.caf' for stems in RENDERED.values() for s in stems} | {'manifest.json'}
    if active is not None:
        return  # partial run: leave everything else alone
    for name in os.listdir(OUT_DIR):
        if name not in keep and (name.endswith('.caf')):
            os.remove(os.path.join(OUT_DIR, name))
            print(f'  removed stale {name}')


def write_audition(path):
    rows = {}
    for fam, stem, wav in AUDITION:
        mp3 = wav[:-4] + '.mp3'
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', wav, '-b:a', '160k', mp3], check=True)
        with open(mp3, 'rb') as f:
            rows.setdefault(fam, []).append((stem, base64.b64encode(f.read()).decode()))
    html = ['<!doctype html><meta charset=utf-8><meta name=viewport content="width=device-width,initial-scale=1">',
            '<title>Book Sounds</title><style>',
            ':root{--bg:#f4ecdc;--ink:#2b2119;--mut:#7a6a58;--chip:#e6d9bf;--hot:#8a4b22}',
            '@media(prefers-color-scheme:dark){:root{--bg:#1c1712;--ink:#efe4cf;--mut:#a89880;--chip:#332a20;--hot:#e0a35b}}',
            'body{margin:0;padding:20px 16px 80px;background:var(--bg);color:var(--ink);font:16px/1.4 Georgia,serif}',
            'h1{font-size:22px;margin:0 0 4px}p.s{color:var(--mut);margin:0 0 18px;font-size:14px}',
            'h2{font-size:13px;letter-spacing:.08em;text-transform:uppercase;color:var(--mut);margin:22px 0 8px}',
            '.row{display:flex;flex-wrap:wrap;gap:8px}',
            'button{font:inherit;font-size:15px;padding:10px 14px;border:0;border-radius:999px;background:var(--chip);color:var(--ink);min-width:48px}',
            'button:active,button.on{background:var(--hot);color:var(--bg)}',
            '</style><h1>Book Sounds</h1><p class=s>Tap to hear. Use headphones once for the stereo, then the phone speaker: that is where these live.</p>']
    for fam, items in rows.items():
        html.append(f'<h2>{fam}</h2><div class=row>')
        for stem, b64 in items:
            idx = stem.rsplit('-', 1)[1]
            html.append(f'<button data-a="{b64}">{idx}</button>')
        html.append('</div>')
    html.append('''<script>
const ctx=new (window.AudioContext||window.webkitAudioContext)();
const cache=new Map();
document.querySelectorAll('button').forEach(b=>b.addEventListener('click',async()=>{
  await ctx.resume();
  let buf=cache.get(b);
  if(!buf){const bin=atob(b.dataset.a);const u=new Uint8Array(bin.length);for(let i=0;i<bin.length;i++)u[i]=bin.charCodeAt(i);buf=await ctx.decodeAudioData(u.buffer);cache.set(b,buf)}
  const s=ctx.createBufferSource();s.buffer=buf;s.connect(ctx.destination);s.start();
  b.classList.add('on');setTimeout(()=>b.classList.remove('on'),buf.duration*1000);
}));
</script>''')
    with open(path, 'w') as f:
        f.write('\n'.join(html))
    print(f'audition page: {path}')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--only', help='comma-separated family names to (re)render')
    ap.add_argument('--audition', nargs='?', const=os.path.join(WORK_DIR, 'audition.html'))
    args = ap.parse_args()
    only = set(args.only.split(',')) if args.only else None
    print("Synthesizing the Book's voice (D pentatonic, moth-lit music box):")
    for name, fn in FAMILIES.items():
        if only and name not in only:
            continue
        print(f'[{name}]')
        fn()
    write_manifest()
    clean_stale(only)
    if args.audition:
        write_audition(args.audition)
    if BANK_GAPS:
        names = 'C C# D D# E F F# G G# A A# B'.split()
        for inst, ms in BANK_GAPS.items():
            print(f'  bank gap: {inst} has no take near ' + ' '.join(f'{names[m % 12]}{m // 12 - 1}' for m in sorted(ms)) + ' (synth covered)')
    total = sum(os.path.getsize(os.path.join(OUT_DIR, f)) for f in os.listdir(OUT_DIR) if f.endswith('.caf'))
    print(f'done — {sum(len(v) for v in RENDERED.values())} sounds rendered; bundle now {total / 1e6:.1f} MB of CAF')


if __name__ == '__main__':
    main()
