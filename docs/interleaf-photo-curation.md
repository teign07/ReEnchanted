# Interleaf photo curation

October 18, 2026. Implemented in source; no app build or device run performed.

## Mix

The existing folio paginator uses a deterministic ten-boundary rhythm: two
photo encounters, three illustration encounters, and five quieter encounters.
The rhythm rotates and reverses from the first document's identity, so adding
Explore deeper Pages preserves the preceding choices. Every five ordinary
boundary positions include a photo slot. Other encounters cycle through a
Reader sentence, a place plate, and three marginalia encounters, using marginalia if personal
material is absent. An actual grimoire residue retains priority at the first
boundary; this one-off encounter can replace a scheduled slot.

Unavailable photos do not silently create extra illustration slots. A photo
leaf can display its existing marginalia fallback while preparation is pending
or if all attempts fail. Thus the ratio describes scheduled encounters, not a
guarantee of successfully rendered photographs.

Illuminated photographs share the illustrations' full-leaf layout: the media
frame uses the stored physical leaf dimensions, navigation floats over the
bottom, and the inner rounded frame is removed. The whole illuminated
composition fits without cropping the photograph or its marginalia.

The photograph, framing, scraps and handwriting reveal as one already-decoded
composition through the same ink-emergence effect as illustrations. There is no
separate paper-first layer or on-arrival pigment decode. A late preparation
starts the whole reveal when its pixels are ready; prewarmed neighbours wait
for visibility, and leaves settled by turning away remain settled on return.
Reduce Motion and VoiceOver retain the shared effect's immediate presentation.

## Selection

The photo catalogue is prepared off the reading actor and refreshed after five
minutes, an authorization change, a shared illumination-history change, or a
request for a newly relevant attached photo. It samples at most 484 candidates:
24 neighbouring-Page photo references, 120 recent images, 100 favourites, 120
spaced archive images, and 40 images around this date in each of the previous
three years. Duplicate IDs are removed. Hidden photos are excluded from normal
queries, screenshots are filtered, and the shorter side must be at least 800px.
Photos access must already be authorized or limited; this path never prompts.

The existing `PhotoCandidateScorer` supplies favourite, recency, dimensions,
aspect, capture season, time-of-day, kept/proposed/dismissed history and place
metadata weights. Dismissed images are excluded. `InterleafPhotoCuration` adds:

- Literal album-subject overlap with the surrounding Pages' tags and motifs.
  Album metadata work is capped at 48 albums and 120 recent members per album.
- A bonus for a photograph explicitly attached to either neighbouring Page.
- A seven-day exclusion for photographs actually shown as interleaves, combined
  with the existing photo-suggestion timestamps, whenever other candidates exist.
- Reservations for other prepared leaves, plus avoidance of captures within
  90 seconds of a recently shown or prepared photograph when alternatives exist.
- A small stable variation that preserves relevance while varying near ties.

Small permitted libraries relax reservations, recency and capture proximity
only when necessary to retain a usable pool. An already prepared boundary keeps
its photograph when its host or pixels must be recreated.

The metadata provides modest relevance, not visual scene understanding. No
image is captioned, classified, or sent to a language model. Marginal copy does
not claim why a photograph matters or what happened in it.

## Local and iCloud delivery

For each photo encounter, attempt the four highest-ranked candidates locally.
If none loads, permit one iCloud-backed request for the highest-ranked image.
If that fails, try up to six further local candidates before showing the
existing marginalia fallback. These final local alternatives may relax recent
and near-capture exclusion when the fresh pool cannot load. PhotoKit itself downloads only when the requested
pixels are unavailable locally. See Apple's `isNetworkAccessAllowed` contract:
https://developer.apple.com/documentation/photos/phimagerequestoptions/isnetworkaccessallowed

Requests preserve aspect ratio at a 1400px target. Local requests time out after
1.5 seconds; the cloud attempt after six seconds. The request wrapper ignores
degraded callbacks, completes its continuation once, and cancels the PhotoKit
request on timeout or cancellation. Failed cloud requests back off for one
minute. Unavailable local assets are skipped for five minutes. Failed leaves
can retry after a minute on a subsequent preparation trigger. Rendering failure
also advances to another candidate.

Only three nearest photo encounters are prepared, with one worker, and stale
downloads are cancelled when their boundary leaves that lookahead. Catalogue
queries happen off the main actor. Preparation never disables page-turn touch.
The leaf and existing inspector consume the same prepared pixels. Transient
interleaves skip `preparePreview`'s durable file write; kept illuminated Pages
retain its existing default persistence behavior.

The decoded-preview cache targets eight images / 48 MiB, protecting up to the
three active encounters. Interleaves no longer render or cache separate pigment
and clock images. Cache limits describe retention; transient rendering memory
still needs profiling.
Recently shown identifiers and dates are stored locally (at most 512 entries,
90 days). Warming neighbours or rendering behind a closed cover does not add
to the shown history. These records do not become Reader-authored material.

## Verification boundary

Five focused Swift regression methods cover mix quotas and drought prevention,
other-slot rotation, bounded local/cloud/local ordering, duplicate attempts,
album and explicit-attachment relevance, recent/reserved exclusion, small
libraries, near-capture avoidance, and deterministic ranking. They are added
to `LeafPresentationTests.swift` but have not been executed, because running
them would compile the package and the user has not requested a build.

Swift frontend syntax parsing and whitespace checks pass. No typecheck, app
build, install, Photos/iCloud runtime test, visual QA or performance measurement
has been performed. Required device cases: full and limited Photos access;
local favourites, iCloud-only library, offline and slow network; permission
changes; rapid/cancelled turns; long Explore deeper bindings; warm revisits;
phone and iPad; Reduce Motion and VoiceOver.

The four existing Python Page Pack authoring checks also pass; they do not
exercise PhotoKit, the new Swift policy tests, rendering, or performance.
