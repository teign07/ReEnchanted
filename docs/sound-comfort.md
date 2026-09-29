# Sound comfort: what we measure and why

The Book's sounds should be warm, and the ones that *mean* something should be clear enough to wake you up
without hurting your ears. `scripts/sound_health.py` measures every rendered cue against the targets below;
`generate_book_sounds.py` shapes each family into one of three profiles at render time.

## What the research says

| Finding | Source | What we do about it |
|---|---|---|
| **Roughness**, amplitude modulation of the envelope at 30-150 Hz, is the acoustic signature of screams and alarms; it drives the brain's aversion network. Dissonant beating (e.g. a mistuned fifth, two notes a whole step apart inside one critical band) lives in the same range. | Arnal et al. 2015, [MPI summary](https://www.aesthetics.mpg.de/en/newsroom/news/news-article/article/scream-if-you-have-to.html), [Neuroscience News](https://neurosciencenews.com/harsh-sound-brain-14953/) | Sparkles use chord tones only (D, F#, A). Runs are built from triads, never adjacent scale steps. The sampler drops recorded notes whose own string-beating scores rough. |
| **Sharpness** (high-frequency weight, in acum) is one of the strongest predictors of annoyance; Zwicker's model starts penalising past ~1.75 acum. The ear is most sensitive around 2-5 kHz. | Zwicker & Fastl, [MetricGate summary](https://metricgate.com/docs/sharpness-acum-din45692/) | Per-profile low-pass and presence tilt; glass and kalimba layers trimmed; mandolin picks rolled off. |
| Warnings work best with components between **0.5 and 4 kHz** and a fundamental of **150-1000 Hz**; anything above **~85 dB SPL** is aversive for most people, especially at 1-2 kHz. Very rapid onsets risk a startle. | Patterson, [auditory warning guidelines](https://www.ioa.org.uk/system/files/publications/RD%20PATTERSON%20GUIDELINES%20FOR%20THE%20DESIGN%20OF%20AUDITORY%20WARNING%20SOUNDS.pdf) | Loudness ceilings per profile; the loudest cue is capped ~-19 dBFS RMS; peaks soft-limited. |
| Waking gently: **melodic, rhythmic** sounds with a **rising** onset reduce sleep inertia; **low-mid frequencies (400-520 Hz)** have the lowest arousal thresholds. | [Sleep-inertia review](https://pmc.ncbi.nlm.nih.gov/articles/PMC7711682/), [arousal thresholds](https://vuir.vu.edu.au/2059/) | "Wake" cues are rising lute/mandolin figures in the 300-1500 Hz range with a swell under them, not a beep. |

## The three profiles

| | warm | wake | ceremony |
|---|---|---|---|
| Used for | taps, selects, turns, toggles, opens, errors, seal/lift/drop | keeps, weaves, arrivals, constellations, jumps | launch overture, Book Today, month bound, notification chime |
| Low-pass | 3.3 kHz | 4.2 kHz | 4.8 kHz |
| Share of A-weighted energy above 2.5 kHz | <= 4.5% | <= 8% | <= 12% |
| Sharpness (1 kHz noise = 1) | <= 1.30 | <= 1.50 | <= 1.65 |
| Roughness (30-150 Hz depth) | <= 0.23 | <= 0.29 | <= 0.33 |
| Active RMS | -33 to -23 dBFS | -28 to -21 | -26 to -19 |
| Peak | <= -9 dBFS | <= -7 | <= -6 |

Calibration (roughness proxy): a 70 Hz-modulated alarm tone 1.22, a clashing whole-step pair 0.81, a pure
500 Hz tone 0.002, recorded lute/mandolin notes 0.07-0.09 (median). The limits sit between "pleasant
instrument" and "alarm".

## Caveats

- The metrics are approximations of Zwicker/ISO 532 and of roughness models, tuned for *relative* comparison
  between cues, not absolute certification. They catch the causes of shrillness; ears decide the rest.
- Real playback level is the reader's volume slider. We set a hierarchy (everyday murmurs quiet, ceremonies
  loud) and cap the top; we cannot set dB SPL.
- Re-run after any change to the generator or the sample bank:

```bash
python3 scripts/generate_book_sounds.py && python3 scripts/sound_health.py
```
