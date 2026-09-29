#!/usr/bin/env python3
"""Psychoacoustic health check for the interface sounds.

Measures every rendered cue against comfort targets drawn from the psychoacoustics literature
(see docs/sound-comfort.md) and flags anything likely to feel shrill, rough, or too loud.

    python3 scripts/sound_health.py            # check the last render (temp dir)
    python3 scripts/sound_health.py --json     # machine-readable

Metrics (all computed on the active part of the sound, both channels summed):
  rms_db      active RMS in dBFS (how loud it feels relative to the other cues)
  peak_db     sample peak in dBFS
  centroid    spectral centroid in Hz (warmth: lower is warmer)
  hi_share    fraction of A-weighted energy above 2.5 kHz, where the ear is most sensitive
  sharp       approximate Zwicker/von Bismarck sharpness, normalised so 1 kHz noise = 1.0 "acum"
  rough       roughness proxy: modulation depth of the 800-5000 Hz envelope at 30-150 Hz
              (Arnal 2015: the band screams and alarms occupy), steady-state frames only
  attack_ms   10%-90% rise time of the amplitude envelope (fast = startling)

Profiles (each cue family is assigned one in generate_book_sounds.py):
  warm      taps, selects, turns, toggles, errors: a soft murmur under the reader's fingers
  wake      keeps, weaves, arrivals, the notification: melodic and clear, but never harsh
  ceremony  launch, Book Today, month bound: the loudest and brightest things the Book does
"""
import argparse
import glob
import json
import math
import os
import sys
import tempfile
import wave

import numpy as np
from scipy import signal

SR = 44100
WORK_DIR = os.path.join(tempfile.gettempdir(), 'book-sounds-v2')

# limits per profile: (max centroid Hz, max hi_share, max sharpness, max roughness, min attack ms,
#                       rms range dBFS, max peak dBFS)
# Calibrated against references (see docs/sound-comfort.md): a 70 Hz-modulated alarm scores rough~1.25,
# a clashing whole-tone pair ~0.82, a pure 500 Hz tone ~0.002, real lute/mandolin notes ~0.07-0.09 (median).
# Sharpness is normalised so 1 kHz noise = 1.0; Zwicker's annoyance model starts penalising at ~1.75.
LIMITS = {
    'warm':     dict(centroid=1700, hi=0.045, sharp=1.30, rough=0.230, attack=1.5, rms=(-33, -23), peak=-9),
    'wake':     dict(centroid=2000, hi=0.080, sharp=1.50, rough=0.290, attack=1.5, rms=(-28, -21), peak=-7),
    'ceremony': dict(centroid=2300, hi=0.120, sharp=1.65, rough=0.330, attack=1.5, rms=(-26, -19), peak=-6),
}

BARK_EDGES = [20, 100, 200, 300, 400, 510, 630, 770, 920, 1080, 1270, 1480, 1720, 2000, 2320, 2700,
              3150, 3700, 4400, 5300, 6400, 7700, 9500, 12000, 15500]


def a_weight_db(f):
    f = np.maximum(f, 1.0)
    f2 = f * f
    ra = (12194 ** 2 * f2 * f2) / ((f2 + 20.6 ** 2) * np.sqrt((f2 + 107.7 ** 2) * (f2 + 737.9 ** 2)) * (f2 + 12194 ** 2))
    return 20 * np.log10(ra + 1e-12) + 2.0


def load(path):
    with wave.open(path) as w:
        n = w.getnframes()
        x = np.frombuffer(w.readframes(n), dtype='<i2').reshape(-1, w.getnchannels()).astype(np.float64) / 32768
    return x.sum(axis=1) / x.shape[1] if x.ndim > 1 else x


def sharpness(x):
    spec = np.abs(np.fft.rfft(x * np.hanning(len(x)))) ** 2
    fr = np.fft.rfftfreq(len(x), 1 / SR)
    spec = spec * 10 ** (a_weight_db(fr) / 10)
    num = den = 0.0
    for z in range(24):
        band = spec[(fr >= BARK_EDGES[z]) & (fr < BARK_EDGES[z + 1])].sum()
        nprime = (band + 1e-18) ** 0.23
        g = 1.0 if z + 0.5 < 15.8 else 0.15 * math.exp(0.42 * (z + 0.5 - 15.8)) + 0.85
        num += nprime * g * (z + 0.5)
        den += nprime
    return 0.11 * num / den


_NORM = None


def sharp_norm():
    """Scale so a narrowband noise at 1 kHz measures 1.0 (the acum definition), keeping values comparable."""
    global _NORM
    if _NORM is None:
        rng = np.random.default_rng(0)
        n = rng.normal(0, 1, SR)
        sos = signal.butter(4, [900 / (SR / 2), 1100 / (SR / 2)], 'bandpass', output='sos')
        _NORM = 1.0 / sharpness(signal.sosfilt(sos, n))
    return _NORM


def roughness(x):
    """Modulation depth at 30-150 Hz of the 800-5000 Hz envelope, energy-weighted over the sustained
    frames (skipping the strike). Frames whose band energy is far below the loudest are ignored: the
    near-silent tail of a fast-decaying pluck is noise, and a ratio against a near-zero DC inflates."""
    sos = signal.butter(2, [800 / (SR / 2), 5000 / (SR / 2)], 'bandpass', output='sos')
    band = signal.sosfilt(sos, x)
    env = np.abs(signal.hilbert(band))
    win = int(0.12 * SR)
    hop = int(0.06 * SR)
    skip = int(0.06 * SR)
    frames = []
    for s in range(skip, len(env) - win, hop):
        frames.append((s, float(np.sqrt(np.mean(band[s:s + win] ** 2)))))
    if not frames:
        return 0.0
    top = max(e for _, e in frames) + 1e-12
    num = den = 0.0
    for s, e in frames:
        if e < top * 0.2:
            continue
        seg = env[s:s + win]
        dc = seg.mean() + 1e-12
        m = np.abs(np.fft.rfft((seg - dc) * np.hanning(win))) / (win / 4)
        fr = np.fft.rfftfreq(win, 1 / SR)
        band_m = m[(fr >= 30) & (fr <= 150)]
        num += e * np.sqrt(np.sum(band_m ** 2)) / dc
        den += e
    depth = float(num / den) if den else 0.0
    # A low note's upper harmonics sit one fundamental apart (D3: ~147 Hz), so the band envelope pulses at
    # f0 by construction: that is pitch, not roughness. Weight by how much of the (A-weighted) sound is
    # actually up there; a pure alarm has ~100% of its energy in the band and is unaffected.
    spec = np.abs(np.fft.rfft(x * np.hanning(len(x)))) ** 2
    fr = np.fft.rfftfreq(len(x), 1 / SR)
    spec = spec * 10 ** (a_weight_db(fr) / 10)
    share = spec[(fr >= 800) & (fr <= 5000)].sum() / (spec.sum() + 1e-18)
    return depth * math.sqrt(min(1.0, share))


def attack_ms(x):
    env = np.abs(signal.hilbert(x))
    env = signal.sosfilt(signal.butter(2, 400 / (SR / 2), output='sos'), env)
    pk = env.max()
    i10 = int(np.argmax(env > 0.1 * pk))
    i90 = int(np.argmax(env > 0.9 * pk))
    return max(0.0, (i90 - i10) / SR * 1000)


def measure(path):
    x = load(path)
    peak = np.abs(x).max() + 1e-12
    active = x[np.abs(x) > 0.01 * peak]
    fr = np.fft.rfftfreq(len(x), 1 / SR)
    mag = np.abs(np.fft.rfft(x * np.hanning(len(x))))
    p = mag ** 2
    pa = p * 10 ** (a_weight_db(fr) / 10)
    return dict(
        rms_db=20 * math.log10(np.sqrt(np.mean(active ** 2)) + 1e-12),
        peak_db=20 * math.log10(peak),
        centroid=float((fr * mag).sum() / mag.sum()),
        hi_share=float(pa[fr > 2500].sum() / pa.sum()),
        sharp=sharpness(x) * sharp_norm(),
        rough=roughness(x),
        attack_ms=attack_ms(x),
        dur=len(x) / SR,
    )


def verdicts(m, profile):
    lim = LIMITS[profile]
    out = []
    if m['centroid'] > lim['centroid']:
        out.append('bright')
    if m['hi_share'] > lim['hi']:
        out.append('shrill(>2.5k)')
    if m['sharp'] > lim['sharp']:
        out.append('sharp')
    if m['rough'] > lim['rough']:
        out.append('rough')
    if m['rms_db'] > lim['rms'][1]:
        out.append('loud')
    if m['rms_db'] < lim['rms'][0]:
        out.append('quiet')
    if m['peak_db'] > lim['peak']:
        out.append('hot-peak')
    return out


def main():
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    ap = argparse.ArgumentParser()
    ap.add_argument('--json', action='store_true')
    ap.add_argument('--dir', default=WORK_DIR)
    args = ap.parse_args()
    from generate_book_sounds import PROFILE_OF
    rows = []
    for path in sorted(glob.glob(os.path.join(args.dir, '*.wav'))):
        stem = os.path.basename(path)[:-4]
        fam = stem.rsplit('-', 1)[0]
        profile = PROFILE_OF.get(fam, 'warm')
        m = measure(path)
        rows.append((stem, profile, m, verdicts(m, profile)))
    if args.json:
        print(json.dumps([{'name': s, 'profile': p, **m, 'flags': v} for s, p, m, v in rows], indent=1))
        return
    print('%-18s %-8s %5s %6s %6s %5s %5s %5s %6s  %s' % ('cue', 'profile', 'sec', 'rms', 'peak', 'cent', 'hi', 'sharp', 'rough', 'flags'))
    bad = 0
    for s, p, m, v in rows:
        bad += bool(v)
        print('%-18s %-8s %5.2f %6.1f %6.1f %5.0f %5.3f %5.2f %6.3f  %s' % (
            s, p, m['dur'], m['rms_db'], m['peak_db'], m['centroid'], m['hi_share'], m['sharp'], m['rough'], ' '.join(v)))
    print(f'\n{len(rows) - bad}/{len(rows)} cues within their profile limits ({bad} flagged)')


if __name__ == '__main__':
    main()
