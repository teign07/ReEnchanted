"""Render the instrument notes the Overhead station plays live.

Overhead is the radio station the sky plays (see `RadioSkyVoice` in
InsideCoverApp/AppSupport.swift). The phone composes in real time, but the
notes themselves are the real lute takes from scripts/instrument_bank, rendered
here once through the same `pluck()` the interface sounds use, plus the
electronic pops and leather-cover creaks.

    python3 scripts/render_overhead_bank.py

Writes mono IMA4 .caf files and manifest.json into
InsideCoverApp/RadioAudio/Overhead/. Every file shares one gain, so the levels
between notes are the bank's own. The app lowpasses, envelopes and mixes them.
Prototype of the composers: scripts/weather_station_prototype.py.
"""
import json
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import generate_book_sounds as g  # noqa: E402

OUT = os.path.normpath(os.path.join(HERE, '..', 'InsideCoverApp', 'RadioAudio', 'Overhead'))
WORK = os.path.join(tempfile.gettempdir(), 'overhead-bank')
LUTE_DEGREES = range(-2, 11)       # A3 .. D6: everything with a real take under the roughness gate
TAKES = 2
LUTE_SECONDS = 2.6
POP_DEGREES = [3, 5, 7, 8]         # the chord tones pops may sit on (<= A5)


def write_mono(name, y, gain):
    os.makedirs(WORK, exist_ok=True)
    wav_path = os.path.join(WORK, name + '.wav')
    pcm = (np.clip(y * gain, -1, 1) * 32767).astype('<i2')
    with wave.open(wav_path, 'w') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(g.SR)
        w.writeframes(pcm.tobytes())
    subprocess.run(['afconvert', '-f', 'caff', '-d', 'ima4', wav_path,
                    os.path.join(OUT, name + '.caf')], check=True)


def main():
    os.makedirs(OUT, exist_ok=True)
    for old in os.listdir(OUT):
        if old.endswith('.caf'):
            os.remove(os.path.join(OUT, old))
    sounds = {}
    for d in LUTE_DEGREES:
        for take in range(TAKES):
            rng = np.random.default_rng(1000 + d * 7 + take * 31)
            y = g.pluck(g.deg(d), LUTE_SECONDS, rng=rng)
            sounds[f'lute_{d + 2:02d}_{take}'] = g.fade(y, 0.5, 60)
    for d in POP_DEGREES:
        sounds[f'pop_{d}'] = g.candy_pop(g.deg(d), dur=0.13)
        sounds[f'popfall_{d}'] = g.candy_pop(g.deg(d), falling=True, dur=0.13)
    for k in range(3):
        c = g.creak(0.2, 0.6, rng=np.random.default_rng(40 + k), cutoff=1200)
        if c is not None:
            sounds[f'creak_{k}'] = c
    gaps = {k: sorted(v) for k, v in g.BANK_GAPS.items()}
    if gaps:
        sys.exit(f'bank gaps (would fall back to synth): {gaps}')
    peak = max(np.abs(y).max() for y in sounds.values())
    gain = 0.92 / peak
    for name, y in sounds.items():
        write_mono(name, y, gain)
    manifest = {
        'gain': 1 / gain,          # multiply decoded samples by this to recover pluck() levels
        'luteDegrees': [min(LUTE_DEGREES), max(LUTE_DEGREES)],
        'takes': TAKES,
        'popDegrees': POP_DEGREES,
        'creaks': len([k for k in sounds if k.startswith('creak_')]),
    }
    with open(os.path.join(OUT, 'manifest.json'), 'w') as f:
        json.dump(manifest, f, indent=2)
    size = sum(os.path.getsize(os.path.join(OUT, n)) for n in os.listdir(OUT))
    print(f'{len(sounds)} sounds, {size / 1024:.0f} KB, gain {1 / gain:.3f} -> {OUT}')


if __name__ == '__main__':
    main()
