# Interleaf month audit

Current production selection/recipe code, executed in an isolated Swift interpreter harness. No app build or app data access.

4 synthetic scenarios, 31 consecutive days (November 1 through December 1, UTC), 2 openings per day, 10 boundaries per opening: **2,480 interleaves**.

| Scenario | Texts selected (unique IDs) | Illustrations (unique) | Photos (unique) | Maps (unique) | Marginalia recipes (unique marks) | Handwritten captions (unique) |
|---|---:|---:|---:|---:|---:|---:|
| well-stocked | 124 | 49 | 90 | 16 | 304 | 45 |
| limited-material | 8 | 49 | 3 | 2 | 321 | 47 |
| no-personal-material | 0 | 49 | 0 | 0 | 326 | 47 |
| guest-pack-fixture | 124 | 49 | 90 | 16 | 304 | 59 |

## What was exercised

- The existing host encounter store, with a fixture clock and isolated encoded history bytes reloaded on every opening.
- The real 2 photo / 3 illustration / 5 quieter slot policy, text rest, map rest, unseen-first art selection, per-boundary stability, and source-level photo selection.
- Bundled marginalia recipes, handwritten caption ranking, all density ceilings, paper stocks, primary placements, and actual marginalia scale arithmetic.
- New sentence selection, stable decoration choices, recent mark/caption avoidance, and spacing after crowded interleaves. Fixture recipes are treated as placed for history; the actual UIKit collision/visibility path is not simulated.
- All six illuminated-photo templates, shared photo compositor, varied image aspect ratios, distinct decoration selection, and pairwise rotated collision checks.
- A Guest pack fixture using the authored November margins JSON and the four canonical story phases; monthly art identities and gates are exercised, not asset delivery.

## Result and correction


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
- Density ceilings: {'ordinary': 92, 'overdone': 33, 'quiet': 33, 'rich': 90}; size bands: {'larger': 104, 'familiar': 53, 'smaller': 91}.
- Paper stocks: {'archiveFlecked': 36, 'laidCotton': 65, 'ragHandmade': 65, 'rebelWeathered': 24, 'vellum': 58}; primary placement choices: {'faintWatermark': 36, 'lowerOuterCorner': 70, 'middleOuterMargin': 64, 'upperOuterMargin': 78}.
- Most frequent captions: [('The ink has other ideas.', 5), ('For the cabinet of weather.', 4), ('Handle with curiosity.', 4)].
- Proposed discoveries: 6; recipes with a shared drawing/caption subject: 22. Both still require native fitting and visual review.
- Longest adjacent same-primary/same-caption run: 1/1.

### limited-material

- Actual encounter counts: {'illustration': 186, 'map': 10, 'marginalia': 288, 'noticing': 4, 'photo': 124, 'reader-text': 8}.
- Fallback counts: {'map': 52, 'text': 112}.
- Density ceilings: {'ordinary': 100, 'overdone': 59, 'quiet': 49, 'rich': 92}; size bands: {'larger': 128, 'smaller': 122, 'familiar': 50}.
- Paper stocks: {'archiveFlecked': 32, 'laidCotton': 72, 'ragHandmade': 87, 'rebelWeathered': 54, 'vellum': 55}; primary placement choices: {'faintWatermark': 34, 'lowerOuterCorner': 102, 'middleOuterMargin': 79, 'upperOuterMargin': 85}.
- Most frequent captions: [('For the cabinet of weather.', 5), ('I put a little night here.', 5), ('I tucked the roots in first.', 5)].
- Proposed discoveries: 17; recipes with a shared drawing/caption subject: 31. Both still require native fitting and visual review.
- Longest adjacent same-primary/same-caption run: 1/1.

### no-personal-material

- Actual encounter counts: {'illustration': 186, 'marginalia': 434}.
- Fallback counts: {'map': 62, 'photo': 124, 'text': 124}.
- Density ceilings: {'ordinary': 193, 'overdone': 63, 'quiet': 56, 'rich': 122}; size bands: {'larger': 188, 'familiar': 95, 'smaller': 151}.
- Paper stocks: {'archiveFlecked': 36, 'laidCotton': 118, 'ragHandmade': 130, 'rebelWeathered': 73, 'vellum': 77}; primary placement choices: {'faintWatermark': 69, 'lowerOuterCorner': 133, 'middleOuterMargin': 113, 'upperOuterMargin': 119}.
- Most frequent captions: [('A small page returned.', 6), ('Filed under small astonishments.', 6), ('For the cabinet of weather.', 6)].
- Proposed discoveries: 24; recipes with a shared drawing/caption subject: 26. Both still require native fitting and visual review.
- Longest adjacent same-primary/same-caption run: 2/1.

### guest-pack-fixture

- Actual encounter counts: {'illustration': 186, 'map': 62, 'marginalia': 124, 'noticing': 60, 'photo': 124, 'reader-text': 64}.
- Fallback counts: {}.
- Density ceilings: {'ordinary': 91, 'overdone': 45, 'quiet': 31, 'rich': 81}; size bands: {'familiar': 44, 'larger': 104, 'smaller': 100}.
- Paper stocks: {'archiveFlecked': 29, 'laidCotton': 67, 'ragHandmade': 76, 'rebelWeathered': 26, 'vellum': 50}; primary placement choices: {'faintWatermark': 36, 'lowerOuterCorner': 63, 'middleOuterMargin': 68, 'upperOuterMargin': 81}.
- Most frequent captions: [('For the cabinet of weather.', 4), ('I put a little night here.', 4), ('Ink keeps what memory would forget.', 4)].
- Proposed discoveries: 9; recipes with a shared drawing/caption subject: 26. Both still require native fitting and visual review.
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
