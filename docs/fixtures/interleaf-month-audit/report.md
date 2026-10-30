# Interleaf month audit

Current production selection/recipe code, executed in an isolated Swift interpreter harness. No app build or app data access.

4 synthetic scenarios, 31 consecutive days (November 1 through December 1, UTC), 2 openings per day, 10 boundaries per opening: **2,480 interleaves**.

| Scenario | Texts selected (unique IDs) | Illustrations (unique) | Photos (unique) | Maps (unique) | Marginalia recipes (unique marks) | Handwritten captions (unique) |
|---|---:|---:|---:|---:|---:|---:|
| well-stocked | 124 | 49 | 90 | 16 | 191 | 30 |
| limited-material | 8 | 49 | 3 | 2 | 206 | 32 |
| no-personal-material | 0 | 49 | 0 | 0 | 209 | 35 |
| guest-pack-fixture | 124 | 49 | 90 | 16 | 217 | 39 |

## What was exercised

- The existing host encounter store, with a fixture clock and isolated encoded history bytes reloaded on every opening.
- The real 2 photo / 3 illustration / 5 quieter slot policy, text rest, map rest, unseen-first art selection, per-boundary stability, and source-level photo selection.
- Bundled marginalia recipes, handwritten caption ranking, all density ceilings, paper stocks, primary placements, and actual marginalia scale arithmetic.
- All six illuminated-photo templates, shared photo compositor, varied image aspect ratios, distinct decoration selection, and pairwise rotated collision checks.
- A Guest pack fixture using the authored November margins JSON and the four canonical story phases; monthly art identities and gates are exercised, not asset delivery.

## Result and correction

- well-stocked: distinct handwritten captions **12 → 30**.
- limited-material: distinct handwritten captions **17 → 32**.
- no-personal-material: distinct handwritten captions **17 → 35**.

The audit found that `book`/`margin` container tags made two captions dominate. Those tags no longer count as subject evidence in handwritten caption ranking; literal subject matches remain preferred.

Recorded selection/geometry invariant failures: 0.
Selected bundled art with missing image files: none.

## Well-stocked month

| Day | Reader text | Findings | Illustrations | Photos | Maps | Pure marginalia |
|---|---:|---:|---:|---:|---:|---:|
| 1 | 2 | 2 | 6 | 4 | 2 | 4 |
| 2 | 2 | 2 | 6 | 4 | 2 | 4 |
| 3 | 1 | 3 | 6 | 4 | 2 | 4 |
| 4 | 2 | 2 | 6 | 4 | 2 | 4 |
| 5 | 2 | 2 | 6 | 4 | 2 | 4 |
| 6 | 0 | 4 | 6 | 4 | 2 | 4 |
| 7 | 2 | 2 | 6 | 4 | 2 | 4 |
| 8 | 0 | 4 | 6 | 4 | 2 | 4 |
| 9 | 2 | 2 | 6 | 4 | 2 | 4 |
| 10 | 0 | 4 | 6 | 4 | 2 | 4 |
| 11 | 0 | 4 | 6 | 4 | 2 | 4 |
| 12 | 1 | 3 | 6 | 4 | 2 | 4 |
| 13 | 3 | 1 | 6 | 4 | 2 | 4 |
| 14 | 3 | 1 | 6 | 4 | 2 | 4 |
| 15 | 1 | 3 | 6 | 4 | 2 | 4 |
| 16 | 3 | 1 | 6 | 4 | 2 | 4 |
| 17 | 2 | 2 | 6 | 4 | 2 | 4 |
| 18 | 3 | 1 | 6 | 4 | 2 | 4 |
| 19 | 2 | 2 | 6 | 4 | 2 | 4 |
| 20 | 0 | 4 | 6 | 4 | 2 | 4 |
| 21 | 1 | 3 | 6 | 4 | 2 | 4 |
| 22 | 2 | 2 | 6 | 4 | 2 | 4 |
| 23 | 0 | 4 | 6 | 4 | 2 | 4 |
| 24 | 2 | 2 | 6 | 4 | 2 | 4 |
| 25 | 4 | 0 | 6 | 4 | 2 | 4 |
| 26 | 4 | 0 | 6 | 4 | 2 | 4 |
| 27 | 4 | 0 | 6 | 4 | 2 | 4 |
| 28 | 4 | 0 | 6 | 4 | 2 | 4 |
| 29 | 4 | 0 | 6 | 4 | 2 | 4 |
| 30 | 4 | 0 | 6 | 4 | 2 | 4 |
| 31 | 4 | 0 | 6 | 4 | 2 | 4 |

## Breadth and limits

### well-stocked

- Actual encounter counts: {'illustration': 186, 'map': 62, 'marginalia': 124, 'noticing': 60, 'photo': 124, 'reader-text': 64}.
- Fallback counts: {}.
- Density ceilings: {'ordinary': 72, 'overdone': 37, 'quiet': 33, 'rich': 106}; size bands: {'larger': 104, 'familiar': 53, 'smaller': 91}.
- Paper stocks: {'archiveFlecked': 36, 'laidCotton': 65, 'ragHandmade': 65, 'rebelWeathered': 24, 'vellum': 58}; primary placement choices: {'faintWatermark': 27, 'lowerOuterCorner': 71, 'middleOuterMargin': 66, 'upperOuterMargin': 84}.
- Most frequent captions: [('This edge remembers.', 20), ('For the cabinet of weather.', 18), ('Handle with curiosity.', 13)].
- Longest adjacent same-primary/same-caption run: 2/2.

### limited-material

- Actual encounter counts: {'illustration': 186, 'map': 10, 'marginalia': 288, 'noticing': 4, 'photo': 124, 'reader-text': 8}.
- Fallback counts: {'map': 52, 'text': 112}.
- Density ceilings: {'ordinary': 62, 'overdone': 67, 'quiet': 49, 'rich': 122}; size bands: {'larger': 128, 'smaller': 122, 'familiar': 50}.
- Paper stocks: {'archiveFlecked': 32, 'laidCotton': 72, 'ragHandmade': 87, 'rebelWeathered': 54, 'vellum': 55}; primary placement choices: {'faintWatermark': 23, 'lowerOuterCorner': 109, 'middleOuterMargin': 81, 'upperOuterMargin': 87}.
- Most frequent captions: [('Handle with curiosity.', 27), ('This edge remembers.', 22), ('Water holding small weather.', 16)].
- Longest adjacent same-primary/same-caption run: 1/2.

### no-personal-material

- Actual encounter counts: {'illustration': 186, 'marginalia': 434}.
- Fallback counts: {'map': 62, 'photo': 124, 'text': 124}.
- Density ceilings: {'ordinary': 119, 'overdone': 92, 'quiet': 56, 'rich': 167}; size bands: {'larger': 188, 'familiar': 95, 'smaller': 151}.
- Paper stocks: {'archiveFlecked': 36, 'laidCotton': 118, 'ragHandmade': 130, 'rebelWeathered': 73, 'vellum': 77}; primary placement choices: {'faintWatermark': 46, 'lowerOuterCorner': 136, 'middleOuterMargin': 128, 'upperOuterMargin': 124}.
- Most frequent captions: [('Handle with curiosity.', 43), ('This edge remembers.', 26), ('For the cabinet of weather.', 21)].
- Longest adjacent same-primary/same-caption run: 2/2.

### guest-pack-fixture

- Actual encounter counts: {'illustration': 186, 'map': 62, 'marginalia': 124, 'noticing': 60, 'photo': 124, 'reader-text': 64}.
- Fallback counts: {}.
- Density ceilings: {'ordinary': 69, 'overdone': 54, 'quiet': 31, 'rich': 94}; size bands: {'familiar': 44, 'larger': 104, 'smaller': 100}.
- Paper stocks: {'archiveFlecked': 29, 'laidCotton': 67, 'ragHandmade': 76, 'rebelWeathered': 26, 'vellum': 50}; primary placement choices: {'faintWatermark': 28, 'lowerOuterCorner': 65, 'middleOuterMargin': 71, 'upperOuterMargin': 84}.
- Most frequent captions: [('For the cabinet of weather.', 16), ('Let wonder interrupt the usual.', 15), ('This edge remembers.', 15)].
- Longest adjacent same-primary/same-caption run: 1/1.

## What this does not establish

- These are recipe/selection results, not rendered phone or iPad leaves. Native collision fitting can omit proposed marks.
- UIKit typography, clipping, Dynamic Type, VoiceOver, tapping the quotation, page curling, and reveal timing were not executed.
- No PhotoKit permission, real library queries, iCloud delivery, decoded pixel cache, installed pack entitlement, live Gazetteer ranking, or full XCTest run was exercised.
- Reader text, finding lines, place candidates and photo metadata are explicitly synthetic fixtures. Real keep provenance/source-opening routes are not replaced or claimed tested by these fixture adapters.
- Small libraries necessarily repeat photos. Depleted text/map pools yield marginalia; the audit does not invent more personal material.

History writes were also asserted off the main thread. Suspended-write reopening, ordered persistence/reload, and actual binding-key equality after exposure were checked with fixture adapters. These are regression probes, not device frame-time measurements.

Reproduce: `python3 scripts/audit_interleaf_month.py`.

Raw evidence: `summary.json`, `encounters.json`, `source-manifest.json`, and baseline equivalents. The manifest fingerprints extracted source declarations and lists adaptations.
