# Rabbit Weather Page stall investigation — 12 October 2026

The reader reported a Weather Page waiting indefinitely before any generation
preview, followed by Place and Capture menus refusing to open. The investigation
did not build, install, or switch models. Source repairs described below were
subsequently made at the reader's request; Rabbit still has the earlier build.

## Confirmed device evidence

- Rabbit is the connected iPhone 15 (`iPhone15,4`). Its active-model marker still
  selects `mlx-community/gemma-4-e2b-it-4bit`, activated September 26, revision
  `238767527555cb75a05732a84dff5d6ba0dd6809`.
- The current local `LocalBrainServices.swift`, `InsideCoverStore.swift`, and
  `ContentView.swift` matched the source hashes captured for today's installed
  Release build.
- A Time Profiler capture of app PID 2849, 15:29:14–15:29:35 EDT, contains 21,812
  running CPU samples at 1 ms each. 20,585 samples include
  `NaturalLanguageStacksEmbeddingScorer.similarity`; 20,632 include the student
  note passage-selection path. These are about 94% of running samples. They are
  CPU sample proportions, not percentages of wall time or proof of GPU idleness.
- The hot call chain is `ContentView.computeSurfaceBuild` / launch enrichment →
  `makeSurfaceBuildResult` → `BookCurator.candidatePool` →
  `StudentNotePageSourceAdapter` → `MeaningfulPassageSelector.bestPassage` →
  `NLEmbedding.distance` → Apple's CoreNLP/BNNS sentence embedding work.
- Both ordinary surface builds and launch enrichment appear in the trace.
- Instruments reports **Serious** thermal state for the full 21.4-second capture.
- Gemma generation frames were not observed in these running CPU samples. This
  does not establish the weather task's exact suspended stage.

Saved evidence is under `/private/tmp`: `rabbit-gemma-stall-20261012.trace`, its
`-profile.xml`, `-logs.xml`, and `-thermal.xml` exports; `rabbit-active-model-20261012.json`;
and the installed build's `source-before.json` / `deployment-report.json` in
`ReEnchanted-Rabbit-Release-20261012-v274dezw`.

## Confirmed source defects and risks

1. `pressWeatherSeal()` holds the shared `busySealID = "weather"` until the whole
   `openManualPage(.weather)` operation returns. `presentInputChoices()` and
   `presentLocationSealChoices()` both refuse while any seal is busy. The Place
   tab is also disabled while weather holds that flag. This explains how one
   pending weather operation can make both menus appear broken.
2. Dismissing the compact reading sheet invalidates its presentation ticket but
   does not cancel the operation that is fetching weather or generating prose.
   The busy flag therefore remains until that operation eventually returns.
3. `OneShotLocationReader.location()` has no cancellation handler or deadline for
   its checked continuation. An unanswered location request can wait indefinitely.
   This is a possible pre-generation stall, not a confirmed stage of this incident.
4. Surface refresh tokens prevent stale results from publishing; they do not stop
   superseded detached CPU work. The traced note selector scores passages across
   up to 80 kept pages, including adjacent sentence pairs, with a fresh native
   embedding distance call for each passage. The scorer serializes native calls
   but does not cache the repeated query or passage results.
5. The manual arrival sheet does not observe streamed Gemma progress. On that
   route, its waiting animation remains above the global preview until the
   completed page is published. Seeing that animation alone cannot establish
   that no generation has started.

## Repair and verification boundaries

Keep the current model and existing page routes. Decouple opening Place/Capture
menus from a long-running weather action; make cancellation release only the
request's own busy state; add bounded, cancellation-aware location waiting.
Coalesce/cancel stale curator work, propagate cancellation into passage scoring,
and keep background semantic enrichment from competing with an explicit reader
request. Cache repeated embedding work while preserving ranking semantics.
Expose the current weather stage / existing generation preview through its
arrival presentation.

## Source repairs

- Weather no longer holds the shared seal busy flag. Place/Capture menu opening
  is independent of long weather work, and only the Weather menu action is
  disabled while weather or incompatible Gemma work is already active.
- Manual page opening owns a cancellable task. Closing the arrival sheet by its
  button or swipe cancels that task as well as invalidating its presentation.
  Page preparation forwards cancellation into its detached worker.
- The arrival leaf now shows the weather stage and the existing live generation
  card once Gemma is working, with an accessible close action throughout.
- One-shot location waiting completes exactly once, handles cancellation even
  before continuation registration, and times out after 20 seconds once iOS
  location permission is resolved. Permission decisions have no deadline. The
  forecast URL request also has a 20-second timeout and cancellation checks.
- Ordinary curator rebuilds and launch enrichment have owned task handles.
  Superseded work is cancelled; detached surface workers receive that
  cancellation. Explicit page requests and active Gemma work suspend those
  background jobs, with a deferred rebuild after the request ends.
- Passage selection stops at its next scoring boundary after cancellation and
  discards partial rankings. Curator adapters stop admitting work after
  cancellation. A native distance call already in progress must still finish.
- The native scorer keeps a bounded, process-local memo of exact model/query/
  passage scores, including unavailable scores. Concurrent identical misses
  share one native call; cached scores do not wait behind unrelated native
  work. The existing native serialization and ranking/score calculation remain
  intact. No vectors, model settings, memory limits, or passage rules changed.
- Gemma checks cancellation before admission, after loading, while streaming,
  and before publishing completion. Added location/forecast, model-load,
  stream-request, and first-text diagnostics report stages/timings without
  logging the reader's prose.

Validation: Swift frontend parsing passed for the seven changed implementation
files and two focused test files. `git diff --check` and focused source checks of
the menu, preview, task ownership, cancellation, and deadline wiring also passed.
The tests cover exact-score reuse across
concurrent refreshes, edited text/model invalidation, nil-score memoization,
cancelled cache use, and interruption during passage ranking. They have not
been executed because that would compile the package. No build, installation,
or post-fix device performance/interaction claim has been made.

Verify cold and repeated Weather Page requests with separate location/network,
model-load, prefill, first-text, and total timings. Check dismissal, immediate
retry, Place/Capture access, thermal state, and passage-selection quality. Native
build and device validation require a new user build request.

A second capture with Thread State Trace failed while saving because the Mac
ran out of disk space. It is not usable performance evidence. Its 4.1 GB temporary
recording and 1 GB of completed task-local compilation intermediates were removed;
the successful Release product and first trace were retained. Earlier morning
crash diagnostics are not evidence of a crash during this stalled generation.

## Authorized device verification follow-up

On October 12, the reader requested verification on Rabbit. The focused
`StacksSemanticScoreMemoTests` (3), `MeaningfulPassageSurfaceTests` (7), and
`StacksEmbeddingConcurrencyTests` (1) all passed: 11 tests, zero failures.
Release build, bundle/signing checks for the app and both extensions, install,
and launch passed. All 1,556 app build inputs and HEAD stayed unchanged. A
separate source snapshot and deployment report are under
`/private/tmp/ReEnchanted-Rabbit-Weather-Release-20261012-vz1dg5jn`.

Through iPhone Mirroring, Place opened before generation; the Weather Page
completed with the plain forecast and Gemma translation visible. Capture then
opened its Photo/Text/Audio choices, and Place reopened. The reader independently
reported that it now works. The cold request took 0.734 seconds for location and
forecast, 6.568 seconds for model loading, and 3.083 seconds from stream request
to first text. First text arrived 11.114 seconds after the weather request;
completion arrived at 18.763 seconds. These are console checkpoint timings for
one cold request, not a warm-run benchmark.

The attempted post-fix Time Profiler capture failed with “Cannot find process
for provided pid: 3406,” so there is no valid post-fix CPU/thermal comparison.
Mid-generation dismissal and visible mid-stream preview were not separately
exercised/captured on device; the cancellation tests and source wiring passed,
and first text was logged. No additional rebuild followed this validation.
