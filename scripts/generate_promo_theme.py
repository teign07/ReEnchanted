#!/usr/bin/env python3
"""Synthesize the ReEnchanted promo's musical bed. Pure Python, reproducible.

An upbeat, catchy "ordinary-magic" theme: a bright C-G-Am-F hook carried by a
glockenspiel-ish bell lead over a felt-pluck arpeggio, a bouncing bass, and a
light groove (soft kick + shaker). Warm and storybook, not club — but it moves,
and the melody is meant to stick. Arranged to follow the promo's seven scenes:
a hinted intro, the hook landing, a lifted middle, a final bright statement.

Usage: python3 scripts/generate_promo_theme.py
Writes RemotionPromo/public/audio/promo-theme.wav (stereo, 48 kHz).
"""
import math
import os
import random
import struct
import wave

SR = 48000
random.seed(20260614)
DUR = 55.0
BPM = 110.0
BEAT = 60.0 / BPM
BAR = BEAT * 4
MASTER = 0.40

OUT = os.path.join(os.path.dirname(__file__), "..", "RemotionPromo", "public", "audio", "promo-theme.wav")

NOTE = {
    "C2": 65.41, "E2": 82.41, "F2": 87.31, "G2": 98.00, "A2": 110.00, "B2": 123.47,
    "C3": 130.81, "D3": 146.83, "E3": 164.81, "F3": 174.61, "G3": 196.00, "A3": 220.00,
    "B3": 246.94, "C4": 261.63, "D4": 293.66, "E4": 329.63, "F4": 349.23, "G4": 392.00,
    "A4": 440.00, "B4": 493.88, "C5": 523.25, "D5": 587.33, "E5": 659.25, "G5": 783.99,
}

# I - V - vi - IV in C major: the catchy one. One chord per bar.
PROGRESSION = [
    {"root": "C2", "pad": ["C3", "E3", "G3"], "arp": ["C4", "E4", "G4", "C5"]},
    {"root": "G2", "pad": ["G2", "B3", "D4"], "arp": ["G3", "B3", "D4", "G4"]},
    {"root": "A2", "pad": ["A2", "C4", "E4"], "arp": ["A3", "C4", "E4", "A4"]},
    {"root": "F2", "pad": ["F3", "A3", "C4"], "arp": ["F3", "A3", "C4", "F4"]},
]

# The hook: (beat-within-4-bar-phrase, note, duration-in-beats). Syncopated,
# rising and resolving — built to be hummable.
HOOK = [
    (0.0, "G4", 0.5), (0.5, "A4", 0.5), (1.0, "C5", 1.0), (2.0, "B4", 0.5),
    (2.5, "A4", 0.5), (3.0, "G4", 1.0),
    (4.0, "G4", 0.5), (4.5, "A4", 0.5), (5.0, "B4", 1.0), (6.0, "D5", 0.5),
    (6.5, "B4", 0.5), (7.0, "A4", 1.0),
    (8.0, "E4", 0.5), (8.5, "G4", 0.5), (9.0, "A4", 1.0), (10.0, "C5", 0.5),
    (10.5, "B4", 0.5), (11.0, "A4", 1.0),
    (12.0, "F4", 0.5), (12.5, "A4", 0.5), (13.0, "C5", 1.0), (14.0, "A4", 0.5),
    (14.5, "G4", 0.5), (15.0, "E4", 1.0),
]

# A sparser high counter-line for the lifted final section.
COUNTER = [
    (1.0, "E5", 0.5), (3.0, "D5", 1.0),
    (5.0, "G5", 0.5), (7.0, "E5", 1.0),
    (9.0, "E5", 0.5), (11.0, "C5", 1.0),
    (13.0, "E5", 0.5), (15.0, "C5", 1.0),
]


def lowpass(samples, cutoff):
    a = min(1.0, 2 * math.pi * cutoff / SR)
    y, out = 0.0, []
    for x in samples:
        y += a * (x - y)
        out.append(y)
    return out


def scale_to(samples, peak):
    m = max((abs(x) for x in samples), default=0.0) or 1.0
    return [x / m * peak for x in samples]


def bell(duration, freq, peak):
    # Glockenspiel-ish: a strong fundamental plus a bright inharmonic partial,
    # quick attack, medium decay. Magical sparkle without being harsh.
    n = int(SR * duration)
    out = []
    for i in range(n):
        t = i / SR
        env = math.exp(-5.0 * t)
        env2 = math.exp(-9.0 * t)
        s = (math.sin(2 * math.pi * freq * t)
             + 0.5 * env2 / max(env, 1e-6) * math.sin(2 * math.pi * freq * 2.76 * t)
             + 0.25 * math.sin(2 * math.pi * freq * 2.0 * t))
        out.append(s * env)
    atk = int(SR * 0.004)
    for i in range(min(atk, len(out))):
        out[i] *= i / atk
    return scale_to(lowpass(out, 6500), peak)


def felt_pluck(duration, freq, peak):
    n = int(SR * duration)
    out = []
    for i in range(n):
        t = i / SR
        env = math.exp(-5.0 * t)
        s = (math.sin(2 * math.pi * freq * t)
             + 0.4 * math.sin(2 * math.pi * 2 * freq * t)
             + 0.15 * math.sin(2 * math.pi * 3 * freq * t))
        out.append(s * env)
    out = lowpass(out, 3000)
    atk = int(SR * 0.005)
    for i in range(min(atk, len(out))):
        out[i] *= i / atk
    return scale_to(out, peak)


def pad_voice(duration, freq, peak):
    n = int(SR * duration)
    out = []
    for i in range(n):
        t = i / SR
        s = (math.sin(2 * math.pi * freq * t)
             + 0.35 * math.sin(2 * math.pi * 2 * freq * t))
        out.append(s)
    out = lowpass(out, 2200)
    a, r = int(n * 0.12), int(n * 0.3)
    for i in range(a):
        out[i] *= i / a
    for i in range(r):
        out[n - 1 - i] *= i / r
    return scale_to(out, peak)


def bass_voice(duration, freq, peak):
    n = int(SR * duration)
    out = []
    for i in range(n):
        t = i / SR
        s = math.sin(2 * math.pi * freq * t) + 0.22 * math.sin(2 * math.pi * 2 * freq * t)
        out.append(s)
    out = lowpass(out, 900)
    a, r = int(n * 0.04), int(n * 0.25)
    for i in range(a):
        out[i] *= i / a
    for i in range(r):
        out[n - 1 - i] *= i / r
    return scale_to(out, peak)


def kick(peak):
    dur = 0.18
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        f = 120 * math.exp(-22 * t) + 48     # pitch drop
        env = math.exp(-13 * t)
        out.append(math.sin(2 * math.pi * f * t) * env)
    return scale_to(out, peak)


def shaker(peak):
    dur = 0.06
    n = int(SR * dur)
    noise = [random.uniform(-1, 1) for _ in range(n)]
    # band-ish: highpass via subtracting a lowpass
    low = lowpass(noise, 4000)
    hp = [x - l for x, l in zip(noise, low)]
    out = []
    for i, x in enumerate(hp):
        out.append(x * math.exp(-45 * (i / SR)))
    return scale_to(out, peak)


def add(buf, samples, start, gain=1.0, pan=0.5):
    gl = gain * math.cos(pan * math.pi / 2)
    gr = gain * math.sin(pan * math.pi / 2)
    total = len(buf[0])
    for i, x in enumerate(samples):
        j = start + i
        if 0 <= j < total:
            buf[0][j] += x * gl
            buf[1][j] += x * gr


def main():
    total = int(SR * DUR)
    buf = [[0.0] * total, [0.0] * total]
    n_bars = int(DUR / BAR) + 1

    KICK = kick(0.9)

    for bar in range(n_bars):
        chord = PROGRESSION[bar % len(PROGRESSION)]
        bar_start = int(bar * BAR * SR)
        prog = (bar * BAR) / DUR  # 0..1 through the piece

        # Pad bed throughout.
        for note in chord["pad"]:
            add(buf, pad_voice(BAR, NOTE[note], peak=0.4), bar_start, gain=0.42, pan=0.5)

        # Bouncing bass: root on 1 and 3, fifth-ish lift on the and-of-2.
        add(buf, bass_voice(BEAT * 1.5, NOTE[chord["root"]], 0.6), bar_start, gain=0.85, pan=0.5)
        add(buf, bass_voice(BEAT * 1.0, NOTE[chord["root"]], 0.5),
            bar_start + int(2 * BEAT * SR), gain=0.8, pan=0.5)

        # Arpeggio: steady eighths give it motion.
        for s in range(8):
            note = chord["arp"][s % len(chord["arp"])]
            t0 = bar_start + int(s * (BAR / 8) * SR)
            pan = 0.4 + 0.2 * ((s % 4) / 3.0)
            add(buf, felt_pluck(0.45, NOTE[note], 0.22), t0, gain=0.9, pan=pan)

        # Groove enters after the intro and rests for the final button.
        if 0.10 < prog < 0.92:
            for b in (0, 2):  # kick on 1 and 3
                add(buf, KICK, bar_start + int(b * BEAT * SR), gain=0.5, pan=0.5)
            for b in (1, 3):  # shaker on the backbeats
                add(buf, shaker(0.16), bar_start + int(b * BEAT * SR), gain=0.5, pan=0.55)
            add(buf, shaker(0.10), bar_start + int(2.5 * BEAT * SR), gain=0.4, pan=0.45)

    # The hook: hinted softly in the intro, full in the body, a last bright pass.
    phrase_bars = 4
    phrase_len = BAR * phrase_bars
    n_phrases = int(DUR / phrase_len) + 1
    for p in range(n_phrases):
        p_start = p * phrase_len
        prog = p_start / DUR
        if prog > 0.95:
            break
        # Lead gain arc: soft intro, strong middle, bright end.
        if prog < 0.12:
            lead_gain = 0.45
        elif prog < 0.82:
            lead_gain = 1.0
        else:
            lead_gain = 0.9
        for (beat, note, dur) in HOOK:
            t0 = int((p_start + beat * BEAT) * SR)
            length = max(0.3, dur * BEAT * 0.95)
            peak = 0.34 * lead_gain
            add(buf, bell(length, NOTE[note], peak), t0, gain=1.0, pan=0.5)
        # Counter-line only in the lifted late-middle.
        if 0.45 <= prog <= 0.85:
            for (beat, note, dur) in COUNTER:
                t0 = int((p_start + beat * BEAT) * SR)
                add(buf, bell(max(0.3, dur * BEAT * 0.9), NOTE[note], 0.16), t0, gain=0.8, pan=0.62)

    # A little stereo air.
    for ch in (0, 1):
        src = list(buf[ch])
        for delay_s, fb in ((0.19, 0.16), (0.33, 0.10)):
            d = int(delay_s * SR)
            for i in range(d, total):
                buf[ch][i] += src[i - d] * fb

    # Master envelope: quick lift-in, bright through, gentle resolve-out.
    fade_in = int(SR * 1.5)
    fade_out = int(SR * 4.5)
    for i in range(total):
        g = MASTER
        if i < fade_in:
            g *= (i / fade_in) ** 1.2
        if i > total - fade_out:
            g *= ((total - i) / fade_out) ** 1.2
        buf[0][i] *= g
        buf[1][i] *= g

    peak = max(max((abs(x) for x in buf[0]), default=0.0),
               max((abs(x) for x in buf[1]), default=0.0)) or 1.0
    norm = min(1.0, 0.95 / peak)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with wave.open(OUT, "w") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for i in range(total):
            for ch in (0, 1):
                v = max(-1.0, min(1.0, buf[ch][i] * norm))
                frames += struct.pack("<h", int(v * 32767))
        w.writeframes(bytes(frames))
    print(f"wrote {OUT} ({DUR:.0f}s, {SR} Hz stereo, {BPM:.0f} BPM)")


if __name__ == "__main__":
    main()
