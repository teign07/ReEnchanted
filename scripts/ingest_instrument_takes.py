#!/usr/bin/env python3
"""Turn long instrument recordings into a bank of single, pitch-labelled notes.

Drop takes (mp3/wav/m4a) in scripts/instrument_takes/<instrument>/  (lute, mandolin),
then run:

    python3 scripts/ingest_instrument_takes.py            # slice + label + report
    python3 scripts/ingest_instrument_takes.py --selftest # prove the slicer on synthetic takes

For each take it finds every note onset, cuts the note out, measures its pitch
(autocorrelation, with an octave check), rejects notes that are polyphonic,
buried in the previous note's ring, or unclear, trims the tail, and writes
scripts/instrument_bank/<instrument>/<midi>_<cents>_<n>.wav plus bank.json.

generate_book_sounds.py reads that bank: it plays the real notes, re-pitched a
few semitones where needed, in place of its synthesized lute and mandolin.
"""
import argparse
import json
import math
import os
import shutil
import subprocess
import sys
import tempfile
import wave

import numpy as np
from scipy import signal

SR = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
TAKES_DIR = os.path.join(HERE, 'instrument_takes')
BANK_DIR = os.path.join(HERE, 'instrument_bank')

PITCH_RANGE = {'lute': (60, 1100), 'mandolin': (180, 2100),      # Hz, plausible fundamentals
               'mandolin_tremolo': (180, 2100), 'foley': None}
# Instruments whose events are whole gestures (a tremolo swell, a cover creak), not single plucks:
# they are segmented by silence instead of by onsets, and foley carries no pitch.
GESTURES = {'mandolin_tremolo', 'foley'}
MAX_NOTE_S = 1.8


def load(path):
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', path, '-ac', '1', '-ar', str(SR), '-f', 'f32le', '-'],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def envelope_db(x, hop=220, win=882):
    n = (len(x) - win) // hop
    e = np.empty(n)
    for i in range(n):
        seg = x[i * hop:i * hop + win]
        e[i] = np.sqrt(np.mean(seg * seg) + 1e-12)
    return 20 * np.log10(e + 1e-9), hop


def find_onsets(x):
    """Onset = the envelope jumps well above where it was ~60 ms ago, after a quiet-ish lead-in."""
    env, hop = envelope_db(x)
    top = env.max()
    floor = top - 42
    onsets = []
    back = 12                       # 60 ms
    i = back
    while i < len(env) - 2:
        rise = env[i + 1] - env[i - back:i].min()
        if env[i + 1] > floor and rise > 10 and env[i + 1] >= env[i]:
            # walk to the local peak, then step back to the start of the rise
            j = i
            while j > 0 and env[j - 1] < env[j] - 0.5:
                j -= 1
            onsets.append(max(0, j) * hop)
            i += 24                 # refractory: 120 ms
        else:
            i += 1
    # de-duplicate onsets that landed within 100 ms
    out = []
    for o in onsets:
        if not out or o - out[-1] > int(0.1 * SR):
            out.append(o)
    return out


def estimate_f0(seg, lo, hi):
    """Autocorrelation pitch. Returns (f0, confidence) or (None, 0)."""
    n = len(seg)
    if n < 4096:
        return None, 0.0
    w = seg * np.hanning(n)
    spec = np.fft.rfft(w, 2 * n)
    r = np.fft.irfft(np.abs(spec) ** 2)[:n]
    r = r / (r[0] + 1e-12)
    lag_min, lag_max = int(SR / hi), int(SR / lo)
    lag_max = min(lag_max, n - 2)
    window = r[lag_min:lag_max]
    if len(window) < 8:
        return None, 0.0
    peak = window.max()
    if peak < 0.5:
        return None, float(peak)
    # first strong local maximum: avoids picking a sub-octave multiple of the period
    thresh = 0.88 * peak
    lag = None
    for k in range(1, len(window) - 1):
        if window[k] >= thresh and window[k] >= window[k - 1] and window[k] >= window[k + 1]:
            lag = k + lag_min
            break
    if lag is None:
        return None, float(peak)
    a, b, c = r[lag - 1], r[lag], r[lag + 1]
    denom = a - 2 * b + c
    shift = 0.5 * (a - c) / denom if abs(denom) > 1e-12 else 0.0
    return SR / (lag + shift), float(b)


def slice_takes(x, instrument, take_name):
    lo, hi = PITCH_RANGE[instrument]
    onsets = find_onsets(x)
    notes, rejects = [], []
    for idx, o in enumerate(onsets):
        nxt = onsets[idx + 1] if idx + 1 < len(onsets) else len(x)
        start = max(0, o - int(0.006 * SR))
        end = min(nxt - int(0.012 * SR), o + int(MAX_NOTE_S * SR))
        if end - start < int(0.25 * SR):
            rejects.append((o / SR, 'too short (next note came too soon)'))
            continue
        seg = x[start:end]
        # clean lead-in: was the previous note quiet before this one struck?
        lead = x[max(0, o - int(0.09 * SR)):o]
        peak = np.abs(seg).max()
        if len(lead) and np.abs(lead).max() > 0.22 * peak:
            rejects.append((o / SR, 'rings into previous note'))
            continue
        f0, conf = estimate_f0(x[o + int(0.02 * SR):o + int(0.02 * SR) + 8192], lo, hi)
        if f0 is None or conf < 0.72:
            rejects.append((o / SR, f'pitch unclear (conf {conf:.2f})'))
            continue
        # an octave sanity check: energy at f0/2 should be well below f0 for a single string
        spec = np.abs(np.fft.rfft(x[o + int(0.02 * SR):o + int(0.02 * SR) + 8192] * np.hanning(8192)))
        fr = np.fft.rfftfreq(8192, 1 / SR)
        def peak_near(freq, rel):
            band = spec[(fr > freq * (1 - rel)) & (fr < freq * (1 + rel))]
            return band.max() if len(band) else spec[int(np.argmin(np.abs(fr - freq)))]
        e0 = peak_near(f0, 0.05)
        eh = peak_near(f0 / 2, 0.05) if f0 / 2 > 40 else 0
        if eh > 0.5 * e0:
            rejects.append((o / SR, 'sub-octave energy (octave error or chord)'))
            continue
        # trim the tail where it has died to -50 dB, then fade
        env = np.abs(seg)
        env = signal.sosfilt(signal.butter(1, 30 / (SR / 2), output='sos'), env)
        live = np.nonzero(env > env.max() * 10 ** (-50 / 20))[0]
        seg = seg[:live[-1] + int(0.03 * SR)] if len(live) else seg
        fade = int(0.02 * SR)
        seg = seg.copy()
        seg[-fade:] *= np.linspace(1, 0, fade)
        seg = signal.sosfilt(signal.butter(1, 40 / (SR / 2), 'highpass', output='sos'), seg)
        seg = seg / (np.abs(seg).max() + 1e-9) * 0.9
        midi = 69 + 12 * math.log2(f0 / 440.0)
        notes.append({'midi': midi, 'f0': f0, 'conf': conf, 'audio': seg, 'take': take_name, 'at': o / SR})
    return notes, rejects


def slice_gestures(x, instrument, take_name):
    """Whole gestures separated by silence (tremolo swells, foley). Pitch-labelled unless pitchless."""
    env, hop = envelope_db(x)
    top = env.max()
    active = env > top - 34
    regions, start, quiet = [], None, 0
    for i, on in enumerate(active):
        if on:
            if start is None:
                start = i
            quiet = 0
        elif start is not None:
            quiet += 1
            if quiet > 30:                      # 150 ms of quiet ends the gesture
                regions.append((start, i - quiet + 1))
                start = None
    if start is not None:
        regions.append((start, len(active)))
    notes, rejects = [], []
    rng = PITCH_RANGE[instrument]
    for a, b in regions:
        s0 = max(0, a * hop - int(0.01 * SR))
        e0 = min(len(x), b * hop + int(0.04 * SR), s0 + int(5.0 * SR))
        seg = x[s0:e0]
        if len(seg) < int(0.45 * SR):
            rejects.append((s0 / SR, 'too short'))
            continue
        f0 = None
        if rng:
            # pitch from the loudest 0.4 s window
            w = int(0.4 * SR)
            hopw = int(0.05 * SR)
            best = max(range(0, max(1, len(seg) - w), hopw), key=lambda k: np.abs(seg[k:k + w]).max())
            f0, conf = estimate_f0(seg[best:best + 8192], rng[0], rng[1])
            if f0 is None or conf < 0.6:
                rejects.append((s0 / SR, f'pitch unclear (conf {conf:.2f})'))
                continue
        seg = seg.copy()
        fade = int(0.02 * SR)
        seg[:int(0.004 * SR)] *= np.linspace(0, 1, int(0.004 * SR))
        seg[-fade:] *= np.linspace(1, 0, fade)
        seg = signal.sosfilt(signal.butter(1, 40 / (SR / 2), 'highpass', output='sos'), seg)
        seg = seg / (np.abs(seg).max() + 1e-9) * 0.9
        midi = 69 + 12 * math.log2(f0 / 440.0) if f0 else 0.0
        notes.append({'midi': midi, 'f0': f0 or 0.0, 'conf': 1.0, 'audio': seg, 'take': take_name, 'at': s0 / SR})
    return notes, rejects


def _roughness(x):
    """Quality gate: string beating / detuned courses show up as 30-150 Hz envelope modulation, the
    band screams and alarms occupy. The sampler skips the roughest notes. (sound_health.roughness)"""
    sys.path.insert(0, HERE)
    from sound_health import roughness
    return roughness(x)


def write_wav(path, x):
    pcm = (np.clip(x, -1, 1) * 32767).astype('<i2')
    with wave.open(path, 'w') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def ingest(takes_dir, bank_dir, verbose=True):
    if os.path.isdir(bank_dir):
        shutil.rmtree(bank_dir)
    os.makedirs(bank_dir)
    manifest = []
    for instrument in sorted(PITCH_RANGE):
        src = os.path.join(takes_dir, instrument)
        if not os.path.isdir(src):
            continue
        os.makedirs(os.path.join(bank_dir, instrument), exist_ok=True)
        files = sorted(f for f in os.listdir(src) if f.lower().endswith(('.mp3', '.wav', '.m4a', '.flac', '.aif', '.aiff')))
        kept_total = 0
        for name in files:
            x = load(os.path.join(src, name))
            notes, rejects = (slice_gestures if instrument in GESTURES else slice_takes)(x, instrument, name)
            for k, n in enumerate(notes):
                nearest = round(n['midi'])
                cents = int(round((n['midi'] - nearest) * 100))
                stem = f"{nearest}_{cents:+d}_{os.path.splitext(name)[0]}_{k}"
                write_wav(os.path.join(bank_dir, instrument, stem + '.wav'), n['audio'])
                manifest.append({'instrument': instrument, 'file': f'{instrument}/{stem}.wav', 'f0': n['f0'],
                                 'midi': n['midi'], 'dur': len(n['audio']) / SR, 'take': name,
                                 'rough': round(_roughness(n['audio']), 4)})
            kept_total += len(notes)
            if verbose:
                print(f'  {instrument}/{name}: {len(notes)} notes kept, {len(rejects)} rejected')
                for t, why in rejects[:6]:
                    print(f'      x @{t:5.1f}s  {why}')
        if verbose:
            names = 'C C# D D# E F F# G G# A A# B'.split()
            have = sorted({round(m['midi']) for m in manifest if m['instrument'] == instrument})
            print(f'  {instrument}: {kept_total} notes; pitches: ' + ' '.join(f'{names[m % 12]}{m // 12 - 1}' for m in have))
    with open(os.path.join(bank_dir, 'bank.json'), 'w') as f:
        json.dump(manifest, f, indent=1)
    return manifest


def selftest():
    """Synthesize 'recordings' of known notes with silence between them, then check the
    slicer finds them and gets the pitch right. Not a substitute for real takes: it proves
    the machinery (onsets, f0, rejection) before you spend credits."""
    sys.path.insert(0, HERE)
    os.environ['BOOK_SOUNDS_NO_BANK'] = '1'
    import generate_book_sounds as g
    rng = np.random.default_rng(5)
    tmp = tempfile.mkdtemp()
    expected = {}
    for instrument, voice, midis in (('lute', g.lute, [50, 53, 57, 59, 62, 64, 66, 69]),
                                     ('mandolin', g.mandolin, [57, 62, 66, 69, 71, 74, 78, 81])):
        os.makedirs(os.path.join(tmp, 'takes', instrument))
        parts = [np.zeros(int(0.3 * SR))]
        for m in midis:
            f = 440 * 2 ** ((m - 69) / 12)
            note = voice(f, 1.2, rng=rng)
            parts += [note, np.zeros(int(0.55 * SR))]
        audio = np.concatenate(parts)
        audio = audio / np.abs(audio).max() * 0.6 + rng.normal(0, 0.0008, len(audio))
        write_wav(os.path.join(tmp, 'takes', instrument, 'synthetic.wav'), audio)
        expected[instrument] = midis
    manifest = ingest(os.path.join(tmp, 'takes'), os.path.join(tmp, 'bank'), verbose=True)
    ok = True
    for instrument, midis in expected.items():
        got = sorted(round(m['midi']) for m in manifest if m['instrument'] == instrument)
        errs = [abs(m['midi'] - round(m['midi'])) for m in manifest if m['instrument'] == instrument]
        missing = sorted(set(midis) - set(got))
        extra = sorted(set(got) - set(midis))
        print(f'  {instrument}: expected {len(midis)}, found {len(got)}, missing {missing}, unexpected {extra}, '
              f'max cents error {100 * max(errs, default=0):.0f}')
        ok &= not missing and not extra
    print('SELFTEST', 'PASSED' if ok else 'FAILED')
    shutil.rmtree(tmp)
    return 0 if ok else 1


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--selftest', action='store_true')
    args = ap.parse_args()
    if args.selftest:
        sys.exit(selftest())
    if not os.path.isdir(TAKES_DIR):
        print(f'No takes yet. Put recordings in {TAKES_DIR}/lute/ and {TAKES_DIR}/mandolin/ (see docs/instrument-takes.md).')
        sys.exit(1)
    print('Ingesting takes:')
    ingest(TAKES_DIR, BANK_DIR)
