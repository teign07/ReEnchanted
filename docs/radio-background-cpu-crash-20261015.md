# Radio listening and background CPU termination — 15 October 2026

The Reader reported a crash after listening to Fae Fi for a while. Rabbit's new fatal resource report, `InsideCoverApp.cpu_resource_fatal-2026-10-15-141414.ips`, records a different failure from the Keep/Contents stack overflow: iOS killed the process after 48 CPU seconds over 57 elapsed seconds, exceeding its background CPU allowance. Samples describe a non-frontmost, idle app. Footprint peaked at about 220 MB in this report. The separately inspected 16:17 jetsam report killed `mDNSResponder`; it does not establish an app memory termination.

The report's debug-image UUID `E096DC6E-9B6F-3FC1-B6F4-BAAFBD1977E5` matches the existing Rabbit Debug binary under `/private/tmp/ReEnchanted-Rabbit-Ink-Seals-Debug-20261013-ockiq_wt/DerivedData/`. Symbolication of the heaviest stack resolves to:

`ContentView.computeSurfaceBuild → makeSurfaceBuildResult → BookCurator.surfacedPages → candidatePool → StudentNotePageSourceAdapter → StudentNotePageGenerator → MeaningfulPassageSelector.rankedSelections/bestPassage → NaturalLanguageStacksEmbeddingScorer.similarity → StacksSemanticScoreMemo → NLEmbedding/CoreNLP/BNNS`.

The sampled expensive work is passage curation, not audio decoding. The report does not identify the station or prove audio playback caused the computation; background audio provides a plausible reason the process remained runnable long enough for that computation to exceed the CPU allowance.

## Source repair

- Leaving the active scene now invokes the existing curator pause/cancellation boundary before background bookkeeping. That cancels ordinary surface rebuilds and launch enrichment. The current cancellation handler forwards cancellation to their detached workers, and passage scoring checks cancellation between candidates/native calls.
- `rebuildSurfaceCache` defers new work while the scene is inactive/backgrounded, and launch enrichment requires an active scene before it starts. The existing foreground refresh requests a fresh pass on return.
- Playback, station selection, DJ conditions, authored receipt validation, and semantic ranking while active retain their existing paths. No audio player changes were needed for this evidence.

Changed Swift source passed syntax parsing and `git diff --check`. No app build, installation, native test execution or device playback verification was performed. The repair needs an authorized build/install followed by sustained Fae Fi listening with the app backgrounded or the screen locked, a foreground-return check, and a fresh fatal-resource/crash inventory.

Raw reports and the task's source baseline are in `/private/tmp/reenchanted-radio-crash-20261015/`.

## Requested Release installation

The subsequent authorized Release build succeeded, with all 1,558 app inputs unchanged. The app and both extensions passed strict signature, bundle-identity and Rabbit provisioning checks; installation on Rabbit succeeded. The initial launch was blocked by the phone's lock. After the Reader unlocked Rabbit, launch succeeded and process 13977 was confirmed running from the installed bundle. The immediate post-launch inventory contained no new app crash reports. Sustained background playback and a post-playback crash check remain unverified. Deployment report: `/private/tmp/ReEnchanted-Rabbit-Release-20261015-kmmfizs2/deployment-report.json`.
