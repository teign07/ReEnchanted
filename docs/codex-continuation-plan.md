# Continuation plan — the addictive-loop work

Written 2026-07-26 for whoever picks this up next. Everything below is verified
against the working tree at that date: core package builds clean, `swift test`
reports **1733 tests / 0 failures**, and the app installs to a device.

## Where the thesis stands

The project decided to stop refusing optimization and instead change the
objective function: make the loop as compelling as any consumer app, but train
it on evidence of lived aliveness rather than attention captured. Two rules
survive that shift and are load-bearing, not decoration:

1. **Never fake a world condition.** The product's whole asset is a narrator the
   reader believes. Designed ritual scarcity (a page stays wet until midnight) is
   fine because it is an openly declared rule. A fabricated "the tide is
   turning" is not, and one caught fabrication re-reads every true thing the
   Book ever said as machinery.
2. **Vary the form and depth of a reward, never whether the reader's moment was
   received.** Intermittent reinforcement on *what a moment becomes* trains
   noticing. Intermittent reinforcement on *whether the Book acknowledged it*
   trains gambling.

The honest north star is `ReaderMomentumMetrics.unpromptedCaptureRatePercent`.
It is the only metric here that falls when the Book pushes harder.

## Already done — do not redo

- **Claim tiers.** `Shared/BookClaimTier.swift`. The 50-kept-page lock on Book
  Remembered / Book Connections / Margins Atlas is gone; those adapters always
  self-gated on real material, so the counter only ever silenced a page that had
  something to say. Claims now scale (glimmer → gathering → established) with
  evidence weight *and distinct days*, so a single long session cannot buy a
  larger sentence. `BookMemoryGate` now governs only `.patreon` / `.quip`.
- **Crossing signals in the taste model.** `ReaderLearningAffinity` counts
  `acted`, `broughtFromElsewhere`, `followedThread`, `keepsakeEarned` and ranks
  them to match the causal layer (keepsake > later return > loved > kept >
  acted). `crossingAdjustment` sits outside the saturating taste clamp, so
  `scoreAdjustment` reaches `maximumAdjustment = 18` only on real-life evidence —
  no amount of in-app approval gets above 12.
- **`followedThread` emit sites** (`ContentView.swift:4354`, `:8915`).
- **Share Extension.** `ReEnchantedShare/`, `Shared/ExternalShareInbox.swift`,
  `.broughtFromElsewhere` weighted 5.
- **Lock Screen question widget shell.** `ReEnchantedQuestionWidget`,
  `.accessoryInline/.accessoryCircular/.accessoryRectangular`.
- **Momentum-only exclusion.** The keep-fallback `.acted` carries
  `momentumOnlyTag` and is refused at `SurfaceAndCurator.swift:3425`.

**Closed as misdiagnosed:** "hedge the evidence, not the address" as a prompt
rewrite. `InsideCoverStore.swift:934` and `NarrativeCore.swift:293` are Dr.
Selene Inkrest's narrative-therapy Office Hours prompt, where tentative
interpretation is correct practice. No general Book-voice hedging law exists.
The intended effect shipped as `BookClaimTier.evidenceQualifier`, which attaches
uncertainty to literal counts ("on 3 threads across 3 days") rather than to the
Book's address of the reader. **Do not soften Inkrest.**

---

## 1. The live interruption window — highest value, genuinely untouched

The premise of the whole design ("the light will be gone in eleven minutes") is
currently *architecturally impossible*, not merely throttled.
`Shared/BookInterruptionBudget.swift` is 40 lines: `BookInterruptionWindow` is
`{morning, evening}`, `plan()` grants at most one winner per `dayID|window`, and
`externalAnchorNotificationsEnabled` is `false`. Morning and evening are a
newsletter schedule — the two times of day least likely to contain a live
opening.

**Build:**

- Add `case live` to `BookInterruptionWindow`. It is condition-triggered, not
  clock-triggered.
- Give it its own budget rather than folding it into the `dayID|window` grouping
  (which would cap it at one per calendar day *shared with* the scheduled
  windows). Start at one live knock per day, tunable.
- **Expiry is the whole point.** A live candidate must carry `expiresAt`. If the
  condition lapses before delivery, the knock is *dropped*, never queued. A
  notification about fog that has already lifted is the fabrication rule above,
  violated by latency instead of intent.
- Do **not** widen volume for existing readers by default. `BookWhisperCadence`
  is `{morning, evening, both, inside}` and readers chose it under the old
  meaning. Add a separate opt-in permission for live knocks so nobody's phone
  gets louder without them asking. The in-world framing the design wants is an
  intensity pact — Whisper / Knock / Rattle the Windows / Drag Me Into My Life,
  the last being explicitly temporary and self-expiring.
- Revisit `externalAnchorNotificationsEnabled`. The comment says foreground
  location cannot guarantee a delivered global cap. That is a real constraint —
  solve the cap honestly or leave the flag off; do not just flip it.

**Acceptance:** a knock fires within minutes of a real condition, never fires for
a lapsed one, respects a per-day cap, and cannot reach a reader who has not
opted in.

## 2. Borrowed wonder vs witnessed wonder

The Share Extension works but is currently a save-to-Pocket clone. The idea that
makes it the product's own is scorekeeping:

> "You have brought me nine things other people made this week, and one thing
> you saw yourself."

Not scolding — Duskthorn can be delighted about it. `ExternalShareCapture`
already records `wasRecentlyPromptedByBook`; add the borrowed/witnessed split
and surface it as a Book Notice with the usual spoke-tag rest so it cannot
nag. The strongest version converts a shared item into a specific errand:
someone else's video of bioluminescent water becomes *"Where is your version of
this, and how far away is it?"* with the real distance filled in.

Also: the share sheet's response is currently the generic "Pressed into the
Book." The design calls for an instant, *specific*, deterministic acknowledgment
that quotes the thing back. That is the entire reward at the moment of capture.

## 3. The open-question substrate

The widget shell exists and has nothing behind it. Build **one** engine that
maintains the Book's current unresolved question — a question the *world* can
answer, not a task — and render it in three places: end of every session, the
Lock Screen widget, and notification subtitles. Never end a session closed; the
open loop is what the reader carries out the door.

## 4. Causal cold start

`ReaderAlivenessModel.curationMultiplier` returns a flat `1.18` when it has no
observations and ignores anything with `abs(impact) < 25`
(`LiteraryContinuity.swift:5784`). So the good causal layer is inert for a new
reader — exactly the first weeks the claim-tier work just opened up. The taste
model now points the right way in the meantime, but the causal layer should wake
up sooner.

## 5. Verify Belief is genuinely one-way

"Reality mints, fiction spends" is the strongest anti-consumption mechanism in
the design and I never confirmed it is actually enforced. Check that no path
lets money or in-app activity mint ordinary Belief.

## 6. Untouched, lower priority

- **Human witness.** Zero social surface anywhere. Highest ceiling, nothing
  built. Even one-way (a souvenir card naming another person) beats none.
- **Notification → capture in one gesture.** `UNTextInputNotificationAction`
  exists at `ContentView.swift`/`AppSupport.swift` but serves only
  `promptCategoryIdentifier`. Generalize it, add a camera action. The metric is
  seconds from cue to capture.

---

## Repo traps that will cost you an hour each

- **Adding a `Shared/*.swift` needs three registrations,** not one: the
  `sources:` array in `Package.swift`, and *four* separate insertions in
  `EnchantifyInsideCover.xcodeproj/project.pbxproj` — `PBXBuildFile`,
  `PBXFileReference`, the group child list, and the Sources build phase. IDs
  follow `0200000000000000000001XX` (fileRef) / `0200000000000000000002XX`
  (buildFile). Copy an adjacent entry.
- **Synthesized `Decodable` ignores property defaults.** Any new stored property
  on a persisted model breaks decoding of existing Books unless you write
  `init(from:)` by hand with `decodeIfPresent`. `ReaderLearningAffinity` and
  `ReaderLearningModel` already do this; follow that pattern. `contentAffinities`
  was made Optional for the same reason.
- **Bump the version and replay.** `ReaderLearningModel.currentVersion` is `3`;
  `init(from:)` calls `rebuildAffinitiesFromEvents()` when it decodes something
  older. Fidelity is bounded by `maxEvents = 800`.
- **Respect the learning scopes.** Any new consumer of `ReaderLearningEvent` must
  honour `isMomentumOnly` and `allowsCurationLearning`, or momentum telemetry
  will silently start teaching taste.
- **Curation clamps saturate fast.** Family is ±8 and `loved` is worth 6, so two
  loves peg a family at the ceiling. If you add a new positive signal and want it
  to actually reach the desk, it needs headroom outside that clamp — see
  `crossingAdjustment`.
- **Don't reach for `git status` to find recent work.** Substantial changes here
  live uncommitted in the working tree for long stretches.

## Verification

```bash
swift build && swift test
```

Device build and install (device id from `xcrun devicectl list devices`):

```bash
xcodebuild -project EnchantifyInsideCover.xcodeproj -scheme InsideCoverApp -configuration Debug -destination 'id=<DEVICE_ID>' -derivedDataPath /tmp/dd build
```

```bash
xcrun devicectl device install app --device <DEVICE_ID> /tmp/dd/Build/Products/Debug-iphoneos/InsideCoverApp.app
```

The iOS Simulator live panel cannot drive a physical device; use the two
commands above for on-device work.
