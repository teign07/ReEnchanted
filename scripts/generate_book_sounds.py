#!/usr/bin/env python3
"""Synthesize ReEnchanted's bookish UI sounds. Pure Python, reproducible.

Usage: python3 scripts/generate_book_sounds.py
Writes WAVs to /tmp/book-sounds, converts to CAF in InsideCoverApp/BookSounds/.
Design language: paper, ink, soft covers, and small plucked glints — short,
quiet, tactile. Never loud, never synthetic-bright.
"""
import math
import os
import random
import struct
import subprocess
import wave

SR = 44100
random.seed(20260611)  # reproducible foley
MASTER = 0.55  # global gain: the Book murmurs, it never announces


def lowpass(samples, cutoff):
    a = min(1.0, 2 * math.pi * cutoff / SR)
    y, out = 0.0, []
    for x in samples:
        y += a * (x - y)
        out.append(y)
    return out


def highpass(samples, cutoff):
    low = lowpass(samples, cutoff)
    return [x - l for x, l in zip(samples, low)]


def bandnoise(duration, low, high):
    n = int(SR * duration)
    noise = [random.uniform(-1, 1) for _ in range(n)]
    return highpass(lowpass(noise, high), low)


def env_swoosh(n, peak_at=0.4):
    out = []
    for i in range(n):
        t = i / n
        if t < peak_at:
            v = (t / peak_at) ** 1.6
        else:
            v = (1 - (t - peak_at) / (1 - peak_at)) ** 2.2
        out.append(v)
    return out


def damped_sine(duration, freq, decay, drop=0.0):
    n = int(SR * duration)
    out, phase = [], 0.0
    for i in range(n):
        t = i / SR
        f = freq * (1 - drop * t / duration)
        phase += 2 * math.pi * f / SR
        out.append(math.sin(phase) * math.exp(-decay * t))
    return out


def pluck(duration, freq, brightness=0.996):
    """Karplus-Strong: warm harp-like pluck."""
    n = int(SR * duration)
    period = int(SR / freq)
    buf = [random.uniform(-1, 1) for _ in range(period)]
    buf = lowpass(buf, 4200)  # soften the attack
    out = []
    for i in range(n):
        j = i % period
        nxt = (j + 1) % period
        buf[j] = brightness * 0.5 * (buf[j] + buf[nxt])
        out.append(buf[j])
    return out


def mix(*tracks):
    n = max(int(SR * off) + len(t) for t, off in tracks)
    out = [0.0] * n
    for track, offset_s in tracks:
        start = int(SR * offset_s)
        for i, v in enumerate(track):
            out[start + i] += v
    return out


def shape(samples, peak, fade_ms=6):
    biggest = max(abs(v) for v in samples) or 1.0
    samples = [v / biggest * peak * MASTER for v in samples]
    fade = int(SR * fade_ms / 1000)
    for i in range(min(fade, len(samples))):
        samples[i] *= i / fade
        samples[-1 - i] *= i / fade
    return samples


def write(name, samples):
    os.makedirs('/tmp/book-sounds', exist_ok=True)
    path = f'/tmp/book-sounds/{name}.wav'
    with wave.open(path, 'w') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b''.join(
            struct.pack('<h', max(-32767, min(32767, int(v * 32767)))) for v in samples
        ))
    out_dir = 'InsideCoverApp/BookSounds'
    os.makedirs(out_dir, exist_ok=True)
    subprocess.run(['afconvert', '-f', 'caff', '-d', 'LEI16', path, f'{out_dir}/{name}.caf'], check=True)
    print(f'  {name}.caf ({len(samples) / SR * 1000:.0f}ms)')


def paper_tick(duration, band_low, band_high, peak):
    noise = bandnoise(duration, band_low, band_high)
    n = len(noise)
    env = [math.exp(-i / n * 9) for i in range(n)]
    return shape([v * e for v, e in zip(noise, env)], peak, fade_ms=2)


def page_swoosh(duration, rising=True, peak=0.4):
    n = int(SR * duration)
    noise = [random.uniform(-1, 1) for _ in range(n)]
    out, y = [], 0.0
    for i, x in enumerate(noise):
        t = i / n
        sweep = t if rising else (1 - t)
        cutoff = 700 + 3200 * sweep
        a = min(1.0, 2 * math.pi * cutoff / SR)
        y += a * (x - y)
        out.append(y)
    out = highpass(out, 500)
    env = env_swoosh(n, peak_at=0.42 if rising else 0.3)
    out = [v * e for v, e in zip(out, env)]
    # a few paper crackles near the peak
    for _ in range(5):
        at = int(n * random.uniform(0.3, 0.6))
        for k, v in enumerate(paper_tick(0.012, 1500, 6000, 0.5)):
            if at + k < n:
                out[at + k] += v * 0.4
    return shape(out, peak)


def book_thump(peak=0.5):
    body = damped_sine(0.32, 98, 14, drop=0.25)
    knock = paper_tick(0.02, 300, 2200, 1.0)
    return shape(mix((body, 0), (knock, 0)), peak)


def knock(freq, decay, surface_peak, body_peak):
    body = damped_sine(0.16, freq, 22, drop=0.3)
    surface = paper_tick(0.018, 400, 2600, surface_peak)
    return mix((body, 0), (surface, 0))


print('Synthesizing the Book\'s voice:')
write('tap', paper_tick(0.07, 900, 4200, 0.30))
write('select', shape(mix((paper_tick(0.05, 1300, 5200, 1.0), 0), (paper_tick(0.05, 1600, 6000, 0.7), 0.03)), 0.32))
write('open-page', page_swoosh(0.34, rising=True, peak=0.40))
write('dismiss-page', page_swoosh(0.26, rising=False, peak=0.36))
write('keep-page', shape(mix((book_thump(1.0), 0), (pluck(0.5, 880), 0.13)), 0.46))
write('undo', page_swoosh(0.2, rising=False, peak=0.3))

scratches = []
for i in range(9):
    scratches.append((paper_tick(random.uniform(0.015, 0.05), 1800, 7000, random.uniform(0.4, 1.0)),
                      0.03 + i * random.uniform(0.03, 0.05)))
write('braid-start', shape(mix(*scratches), 0.32))

write('braid-complete', shape(mix(
    (pluck(0.7, 587.33), 0.0),    # D5
    (pluck(0.7, 739.99), 0.13),   # F#5
    (pluck(0.9, 880.00), 0.26),   # A5
    (paper_tick(0.06, 800, 3000, 0.25), 0.75),
), 0.48))

write('source-refresh', shape(mix(
    (pluck(0.45, 587.33), 0.0),
    (paper_tick(0.05, 1200, 5000, 0.5), 0.02),
), 0.38))

write('error', shape(mix(
    (damped_sine(0.22, 72, 18, drop=0.2), 0.0),
    (damped_sine(0.26, 68, 16, drop=0.2), 0.13),
    (bandnoise(0.1, 200, 900), 0.0),
), 0.40))
# The knock: your knuckle on the cover.
write('knock', shape(knock(118, 22, 1.0, 0.9), 0.42))

# The reply: two knocks from inside — deeper, muffled, very slightly uneven.
reply_one = knock(82, 26, 0.35, 1.0)
reply_two = knock(76, 26, 0.3, 0.95)
write('knock-reply', shape(mix((reply_one, 0.0), (reply_two, 0.22)), 0.40))

print('done — bound into InsideCoverApp/BookSounds/')
