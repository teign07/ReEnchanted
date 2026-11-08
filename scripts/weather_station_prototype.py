"""Weather station prototype: the sky plays the Book's own instruments.

Offline sketch only. Real lute samples + electronic pops from the interface
sound generator, D major pentatonic throughout, chord tones (D F# A) for
anything that rings together. Each weather is its own little composer.
"""
import math
import os
import sys
import wave

import numpy as np

REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
sys.path.insert(0, os.path.join(REPO, 'scripts'))
import generate_book_sounds as g  # noqa: E402

SR = g.SR
deg = g.deg
OUT = os.path.join(os.environ.get('TMPDIR', '/tmp'), 'weather-station')
os.makedirs(OUT, exist_ok=True)
CHORD = [0, 2, 3]          # degrees of D, F#, A inside one octave (D=0, F#=2, A=3)


def chord_tone(rng, lo, hi):
    """A chord-tone degree between lo and hi (inclusive)."""
    opts = [d for d in range(lo, hi + 1) if d % 5 in CHORD]
    return int(rng.choice(opts))


def walk(rng, cur, lo, hi, leap=2):
    nxt = cur + int(rng.integers(-leap, leap + 1))
    return max(lo, min(hi, nxt))


def note(f, dur, rng, cutoff=None, reverse=False):
    if reverse:
        y = g.sample_note('lute', f, dur, rng, reverse=True, fade_ms=40)
        if y is None:
            y = g.pluck(f, dur, rng=rng)[::-1].copy()
        y = y * 1.2
    else:
        y = g.pluck(f, dur, rng=rng)
    if cutoff:
        y = g.sos_filter(y, 'lowpass', cutoff, order=2)
    return y


def sub(f, dur, attack=0.006, tau=None):
    """The low end: a round electronic sub on a chord root (the low lute
    takes are too rough to use). Pure sine plus a soft second harmonic."""
    t = g.tt(dur)
    tau = tau or dur * 0.4
    # A pure sine: a harmonic an octave up shares the critical band at these
    # pitches and beats against the root (sound_health reads it as rough).
    y = np.sin(2 * np.pi * f * t)
    env = np.minimum(t / attack, 1.0) * np.exp(-t / tau)
    return g.fade(g.sos_filter(y * env, 'lowpass', 520, order=2), 0.5, 30)


def wind_voice(dur, gust, centres=(146.83, 220.0, 369.99), q=0.035, rng=None):
    """Wind singing in a resonant body: noise through narrow bands tuned to
    D3, A3, F#4, swelling with the gust envelope. Not a harp: no plucks."""
    rng = rng or np.random.default_rng(5)
    n = int(SR * dur)
    noise = rng.normal(0, 1, n)
    y = np.zeros(n)
    for c in centres:
        band = g.sos_filter(noise, 'bandpass', [c * (1 - q), c * (1 + q)], order=2)
        y += band / (np.std(band) + 1e-9)
    air = g.sos_filter(noise, 'bandpass', [200, 800], order=2)
    y = y + 0.25 * air / (np.std(air) + 1e-9)
    return g.sos_filter(y * gust[:n], 'lowpass', 1100, order=2)


def gusts(dur, rng, rate=0.18, depth=1.0, floor=0.15):
    """A slow, uneven gust envelope 0..1."""
    n = int(SR * dur)
    pts = int(dur * rate * 4) + 3
    raw = rng.uniform(0, 1, pts) ** 1.6
    x = np.interp(np.linspace(0, pts - 1, n), np.arange(pts), raw)
    x = g.sos_filter(x, 'lowpass', 0.6, order=1)
    x = (x - x.min()) / (x.max() - x.min() + 1e-9)
    return floor + (1 - floor) * x * depth


def thump(rng, strength=1.0):
    """A lightning hit: sub drop on D, a short dark crash, a rumble."""
    t = g.tt(2.6)
    f = 73.42 * (1 + 1.2 * np.exp(-t / 0.04))
    sub = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.55)
    crash = rng.normal(0, 1, len(t)) * np.exp(-t / 0.09)
    crash = g.sos_filter(crash, 'lowpass', 1100, order=2)
    rumble = g.sos_filter(rng.normal(0, 1, len(t)), 'lowpass', 120, order=2)
    rumble = rumble / (np.std(rumble) + 1e-9) * np.minimum(t / 0.25, 1) * np.exp(-t / 0.9)
    return (sub * 1.0 + crash * 0.55 + rumble * 0.25) * strength


def lightning_times(start, dur, seed=0x5707):
    """Same windowing as SkyField.lightning: uneven strikes, never a rhythm."""
    def scramble(v):
        z = (v + 0x9e3779b97f4a7c15) & 0xFFFFFFFFFFFFFFFF
        z = ((z ^ (z >> 30)) * 0xbf58476d1ce4e5b9) & 0xFFFFFFFFFFFFFFFF
        z = ((z ^ (z >> 27)) * 0x94d049bb133111eb) & 0xFFFFFFFFFFFFFFFF
        return z ^ (z >> 31)
    out = []
    window = 9.0
    for index in range(int(start // window), int((start + dur) // window) + 1):
        def unit(salt):
            return (scramble((seed + index * 6007 + salt * 92821) & 0xFFFFFFFFFFFFFFFF) % 10000) / 9999
        if unit(1) >= 0.66:
            continue
        at = index * window + 1 + unit(2) * (window - 2.5)
        if start <= at < start + dur:
            out.append((at - start, 0.65 + unit(3) * 0.35))
    return out


def master(tr, *, t60, wet, lowpass=None, peak=0.5, drive=1.1):
    st = tr.stereo()
    st = g.reverb(st, t60=t60, wet=wet, seed=23, damp=4200)
    if lowpass:
        st = np.stack([g.sos_filter(st[c], 'lowpass', lowpass, order=2) for c in range(2)])
    st = np.stack([g.sos_filter(st[c], 'highpass', 45, order=1) for c in range(2)])
    st = g.saturate(st / (np.abs(st).max() or 1), drive)
    return st / (np.abs(st).max() or 1) * peak


# ------------------------------------------------------------ the skies ---

def clear_day(dur, rng):
    tr = g.Track(dur + 3)
    beat = 60 / 76
    cur = 5
    t = 0.4
    bar = 0
    while t < dur:
        for step in range(8):
            at = t + step * beat / 2
            if at >= dur:
                break
            if step == 0:
                tr.add(sub(deg(-5 + (0 if bar % 4 != 3 else 3)), 1.6), at, gain=0.5)
            if rng.uniform() < (0.62 if step % 2 == 0 else 0.3):
                cur = walk(rng, cur, 2, 9)
                tr.add(note(deg(cur), 0.6, rng), at, pan=float(rng.uniform(-0.5, 0.5)), gain=0.5)
        if rng.uniform() < 0.5:
            g.add_pops(tr, [chord_tone(rng, 5, 8), chord_tone(rng, 5, 8)], t + beat * 3.5, gain=0.14)
        t += beat * 4
        bar += 1
    return master(tr, t60=1.2, wet=0.28)


def clear_night(dur, rng):
    tr = g.Track(dur + 5)
    t = 0.6
    while t < dur:
        d = chord_tone(rng, 5, 8)
        tr.add(note(deg(d), 2.4, rng, cutoff=2200), t, pan=float(rng.uniform(-0.8, 0.8)), gain=0.42)
        if rng.uniform() < 0.35:
            tr.add(g.candy_pop(deg(min(d, 8)), dur=0.12), t + 0.9, pan=float(rng.uniform(-0.8, 0.8)), gain=0.12)
        if rng.uniform() < 0.3:
            tr.add(sub(deg(-10), 2.2, attack=0.02), t + 0.2, gain=0.45)      # a low heartbeat
        t += float(rng.uniform(2.2, 5.5))                                       # long silences
    return master(tr, t60=3.2, wet=0.55, peak=0.42)


def rain(dur, rng, amount=0.7):
    tr = g.Track(dur + 3)
    rate = 0.8 + 6.0 * amount          # drops per second
    t = 0.2
    cur = 6
    while t < dur:
        # Drops cluster: rain comes in waves.
        wave_gain = 0.55 + 0.45 * math.sin(2 * math.pi * t / 11.0) ** 2
        # Drops ring into each other under the reverb, so they keep to
        # chord tones: adjacent steps sounding together beat.
        cur = chord_tone(rng, 3, 8)
        f = deg(cur)
        if rng.uniform() < 0.68:
            tr.add(g.soft(f, 0.32, rng=rng, cutoff=2400), t, pan=float(rng.uniform(-0.9, 0.9)), gain=0.36 * wave_gain)
        else:
            tr.add(g.candy_pop(deg(chord_tone(rng, 5, 8)), dur=0.1), t, pan=float(rng.uniform(-0.9, 0.9)), gain=0.16 * wave_gain)
        t += float(rng.exponential(1 / rate))
    beat = 60 / 64
    for k in range(int(dur / (beat * 4)) + 1):     # a low pedal under the weather
        tr.add(sub(deg(-5 if k % 3 else -2), 3.0, attack=0.04), 0.3 + k * beat * 4, gain=0.45)
    return master(tr, t60=1.6, wet=0.34)


def storm(dur, rng, start=26.0, amount=0.9):
    tr = g.Track(dur + 4)
    # Wind under everything.
    tr.add(wind_voice(dur + 2, gusts(dur + 2, rng, rate=0.35, floor=0.3), rng=rng) * 0.05, 0, gain=1.0)
    # Driving ostinato on low D-A, faster when the storm is heavier.
    beat = 60 / (96 + 30 * amount)
    pattern = [-5, -2, -5, 0, -5, -2, 2, -2]
    k = 0
    t = 0.1
    while t < dur:
        d = pattern[k % len(pattern)]
        tr.add(sub(deg(d), 0.4, tau=0.12), t, gain=0.55)
        if k % 2 == 0:
            tr.add(note(deg(d + 5), 0.4, rng, cutoff=1500), t, pan=-0.2 if k % 4 else 0.2, gain=0.32)
        k += 1
        t += beat / 2
    # Dense rain on top.
    t = 0.0
    while t < dur:
        tr.add(g.soft(deg(chord_tone(rng, 3, 8)), 0.25, rng=rng, cutoff=2200), t, pan=float(rng.uniform(-1, 1)), gain=0.2)
        t += float(rng.exponential(1 / 7))
    # Every strike: a hit on the very instant, then a tumbling fall of notes.
    for at, strength in lightning_times(start, dur):
        tr.add(thump(rng, strength), at, gain=0.9)
        top = 10
        for j in range(7):
            tr.add(note(deg(top - j * 2), 0.5, rng, cutoff=2400), at + 0.12 + j * 0.07,
                   pan=(-0.7 + 0.2 * j), gain=0.45 * (1 - j * 0.08))
        g.add_pops(tr, [8, 7, 5, 3], at + 0.05, gap=0.035, gain=0.18, falling=True)
    return master(tr, t60=1.4, wet=0.3, peak=0.55, drive=1.3)


def windy(dur, rng):
    tr = g.Track(dur + 3)
    gust = gusts(dur + 2, rng, rate=0.22, floor=0.12)
    tr.add(wind_voice(dur + 2, gust, rng=rng) * 0.075, 0)
    beat = 60 / 70
    cur = 4
    for k in range(int(dur / (beat / 2))):
        at = k * beat / 2
        push = gust[min(len(gust) - 1, int(at * SR))]
        if rng.uniform() < 0.25 + 0.4 * push:
            cur = walk(rng, cur, 0, 7)
            jitter = float(rng.normal(0, 0.03 + 0.12 * push))     # blown off the beat
            pan = float(np.clip((push - 0.5) * 1.6 + rng.normal(0, 0.2), -1, 1))
            tr.add(note(deg(cur), 0.7, rng, cutoff=2000), max(0, at + jitter), pan=pan, gain=0.45)
    return master(tr, t60=1.5, wet=0.3)


def snow(dur, rng):
    tr = g.Track(dur + 5)
    beat = 60 / 48
    cur = 3
    t = 0.5
    while t < dur:
        if rng.uniform() < 0.7:
            cur = walk(rng, cur, -2, 6, leap=1)
            tr.add(note(deg(cur), 1.8, rng, cutoff=900), t, pan=float(rng.uniform(-0.4, 0.4)), gain=0.55)
        if rng.uniform() < 0.18:
            c = g.creak(0.2, 0.6, rng=rng, cutoff=1200)
            if c is not None:
                tr.add(c, t + 0.3, pan=float(rng.uniform(-0.6, 0.6)), gain=0.35)
        if rng.uniform() < 0.22:
            tr.add(g.candy_pop(deg(chord_tone(rng, 3, 6)), dur=0.14), t + beat * 0.5, gain=0.1)
        t += beat
    return master(tr, t60=2.4, wet=0.4, lowpass=1100, peak=0.45)


def fog(dur, rng):
    tr = g.Track(dur + 5)
    # Notes come out of the fog backwards, and the phrase keeps repeating
    # with a note missing each time, as if half-heard.
    phrase = [chord_tone(rng, 0, 6) for _ in range(5)]
    beat = 60 / 54
    t = 0.4
    rep = 0
    while t < dur:
        missing = int(rng.integers(0, len(phrase)))
        for i, d in enumerate(phrase):
            if i == missing:
                continue
            backwards = (i + rep) % 3 == 0
            tr.add(note(deg(d), 1.4, rng, cutoff=1000, reverse=backwards), t + i * beat,
                   pan=float(rng.uniform(-0.7, 0.7)), gain=0.5 if not backwards else 0.42)
        t += beat * (len(phrase) + 2)
        rep += 1
        if rep % 2 == 0:
            phrase[int(rng.integers(0, len(phrase)))] = chord_tone(rng, 0, 6)
    return master(tr, t60=3.6, wet=0.6, lowpass=1400, peak=0.45)


SKIES = [
    ('1-clear-day', clear_day),
    ('2-clear-night', clear_night),
    ('3-rain', rain),
    ('4-storm', storm),
    ('5-windy', windy),
    ('6-snow', snow),
    ('7-fog', fog),
]


def write_wav(path, st):
    st = np.clip(st, -1, 1)
    data = (st.T * 32767).astype('<i2').tobytes()
    with wave.open(path, 'wb') as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)


def main():
    dur = 30.0
    parts = []
    for name, fn in SKIES:
        rng = np.random.default_rng(sum(map(ord, name)))
        st = fn(dur, rng)
        st = st[:, :int(SR * (dur + 2))]
        fade_n = int(SR * 1.5)
        st[:, -fade_n:] *= np.linspace(1, 0, fade_n)
        write_wav(os.path.join(OUT, f'{name}.wav'), st)
        parts.append(st)
        parts.append(np.zeros((2, int(SR * 1.2))))
        print('rendered', name)
    write_wav(os.path.join(OUT, 'weather-station.wav'), np.concatenate(parts, axis=1))
    if g.BANK_GAPS:
        print('bank gaps (synth fallback):', {k: sorted(v) for k, v in g.BANK_GAPS.items()})


if __name__ == '__main__':
    main()
