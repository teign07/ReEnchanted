# Onboarding Celebrations & The Standing Order Paywall — plan

Two workstreams: (A) mini-celebrations that trigger dopamine through onboarding
without going off the rails, and (B) a disclosure-forward, multi-step paywall
with weekly/monthly/annual/à-la-carte plans, a 3-day trial, and revocable
entitlements.

North star (unchanged): read + wonder, lamplight tone. The Book is a witness,
not a slot machine.

---

## A. Celebration pass

### Design rules

1. **Celebrate authorship, not navigation.** A beat fires only when the player
   contributed (typed, chose, kept, rolled) — never on a bare Continue.
2. **House grammar everywhere.** Contribution → `LivingInkBurst` → a character
   margin note echo (`MarginTutorNoteCard` style). Same loop the live app uses
   at keep (`KeepMarginalia`), so onboarding trains the real reward.
3. **No variable-ratio rewards in onboarding.** The one sanctioned variance is
   the Wicker belief-dice roll — variable *outcome*, fixed *reward* (a failed
   roll is written as a beginning). Variety (which voice replies, card seeds)
   is fine; schedules are not. True variable-ratio stays post-onboarding
   (Goblin Market, fae bargains) where consent shapes it.
4. **Act-break animations only, three total:** cover opening (built),
   Glow-waking at belief planting, Bindery sewing before the finale PDF.
5. **Budget:** every beat ≤ 1.2s, tap-to-skip, reduceMotion → fade only,
   never occludes or delays the Continue button. Skip Onboarding stays fast.

### Celebration map (by current step)

| Step | Contribution | Beat |
|---|---|---|
| 0 First Page | keep / "fall in" | **DONE**: KEPT wax badge + `LivingInkBurst` over the card + **Pippa** margin-note echo (seeded copy pool, her canonical first-keep role). First-keep only. |
| 3 Snack | typed answer | margin-ration card settles in with a sparkle (exists; add settle animation) — *not yet* |
| 4 Name | typed name | **DONE**: `OnboardingNameSignatureCard` writes the name on in gold via `WrittenGoldText`, debounced so it signs once when typing settles. |
| 5 Belief | plant 3 Belief | **DONE (act break)**: `plantBeliefWithCeremony` — `LivingInkBurst(.belief)` from the sigil + **Zara** margin note + ~0.95s hold so the Glow wakes before the page turns. |
| 7 First press rehearsal | keep/wait | ink burst exists via `rehearsalInkBurstTrigger`; margin-note echo — *not yet* |
| 8 Photo plate | keep photo | gild sweep across the plate as it "develops" — *not yet* |
| 10 Wicker | mode choice + roll | **DONE**: reuses the live story-page Inkbones (`InkbonesPiece`, now internal) — 5 bones tumble, then a four-tier consequence (`triumph`/`hold`/`glance`/`cost`) settles in. Failure is never a pure loss (cost = "the first page of a grudge"). Rivalry mechanic surfaced as a `threadKept` line. The one sanctioned variable-outcome beat. |
| 15 Finale | bind first edition | **DONE (act break)**: `BinderySewingOverlay` — gold stitches walk a spine, signatures cinch, ~1.2s, before the QuickLook opens on the real PDF. |

**Shared infra built:** `OnboardingMarginEcho` model + `OnboardingEchoSpeaker` (Pippa/Zara copy pools, seeded selection — variety without a schedule) + `onboardingMarginEchoCard` presenter (bottom-pinned, tap or 6s auto-dismiss). Reusable for the remaining step 3/7/8 beats.

Optional, later: step dots become a tiny book spine that gains stitches — a
constant low-level progress cue that rhymes with the Bindery.

### Implementation notes

- `LivingInkBurst` and `MarginTutorNoteCard` already exist; onboarding needs a
  small margin-note presenter of its own (the ContentView one is desk-scoped).
- Margin note copy pools per moment (3–5 variants each) drawn by stable seed —
  variety without a reward schedule.
- Sequencing rule from the live app: "let the ink burst land first; the margin
  note is the echo" (~0.5s stagger).

---

## B. The Standing Order paywall

### Positioning

Not an ad in a box: a **contract letter from the Bindery**, multi-page, with
generous margins and total candor about money. Disclosure-forward trials are
the aggressive play — removing the fear of forgetting to cancel removes the
reason to decline the trial.

### Placement

1. **Primary:** immediately after the finale mini-edition QuickLook closes —
   they are holding their own bound book; the pitch is "the Bindery keeps
   working." Skippable with a warm line ("The free Book remains yours,
   forever.").
2. **Re-surfacing (desire moments, not interstitials):** Bindery physical
   print flow, pack browsing in the Book Shop, monthly binding night, annual
   edition.

### The four pages

1. **What the free Book always does.** Honest, concrete list. (Gating decision
   required — see open questions.)
2. **What the Standing Order adds.** Benefits shown with *their* artifacts —
   their first-edition cover as the page's hero image.
3. **Choose your plan.**
   - Weekly — price anchor (e.g. $3.99/wk)
   - Monthly (e.g. $6.99/mo)
   - Annual $39.99 — default-selected, "2 months free" framing, 3-day free
     trial badge (existing product `…pass.standing-order.annual`)
   - À la carte — link out to packs (existing $4.99/$2.99 products)
   - Localized prices via StoreKit 2 `Product.displayPrice`; computed renewal
     dates shown inline.
4. **The terms, in plain ink.** "Your trial starts today, July 4. On July 7,
   Apple charges $39.99/year unless you cancel. Cancel anytime in Settings →
   Apple ID → Subscriptions — the Book keeps everything you already made.
   We will tap the glass the day before any coin moves." + Restore Purchases +
   privacy/terms links (App Review 3.1.2 requirements).

### Trust mechanics

- **Pre-charge reminder:** schedule a local notification on trial day 2
  ("Your trial ends tomorrow — keep the Standing Order or cancel; either way
  your pages are safe."). This is ours; Apple's receipts are separate.
- **Entitlement reversion:** one `EntitlementLedger` driven by StoreKit 2
  `Transaction.currentEntitlements`, honoring `revocationDate`,
  `expirationDate`, and billing-retry grace. Extends the existing pass
  lapse-revoke path; fan out through `BookShopSheet.onRevoke`. Outright pack
  purchases stay permanent (existing rule in `PagePacks`).
- Server-authoritative only where money meets atoms (Lulu prints — existing
  rule).

### App Store Connect prerequisites

- Create weekly + monthly auto-renewables in the same subscription group as
  the annual pass (upgrade/downgrade proration comes free).
- Configure the 3-day introductory free-trial offer on annual (decide whether
  weekly gets one — see open questions).
- Family Sharing decision per product.

---

## Phasing

1. **Phase 1 — Celebration pass. DONE.** Margin-note presenter + Pippa/Zara/
   Penny copy pools; ink bursts at steps 0/5/7/8; Wicker dice beat; name
   signature; Glow-waking ceremony; Bindery sewing beat.
2. **Phase 2 — Paywall flow. DONE (UI + data + wiring).**
   - `StandingOrderTier` model + `BookShopCatalog.standingOrderTiers`
     (weekly $3.99 / monthly $6.99 / annual $39.99, all 3-day trial) in
     `Shared/PagePacks.swift`.
   - `BookShopCatalog.packID(forProductID:)` resolver — any cadence's receipt
     grants the Standing Order pack; `StoreKitMerchant.restorePurchases` now
     uses it. Tests in `StandingOrderTierTests`.
   - `StandingOrderPricing.load()` (StoreKit 2 intro-offer + displayPrice) in
     `AppSupport.swift`; falls back to fallback prices before ASC products exist.
   - `StandingOrderSheet` four-page walkthrough in `BookShopSheet.swift` (free
     Book → what the Order adds → cadence cards → terms in plain ink with
     computed charge dates + Restore + legal links). Reuses `BookShopTill`.
   - Presented once after onboarding completes (`didOfferStandingOrder`
     AppStorage) via `ContentView`; grants through existing `unlockPack`.
3. **Phase 3 — Entitlement hardening + trust. MOSTLY DONE.**
   - **Trial reminder DONE:** `StandingOrderTrialReminder` (in `AppSupport.swift`)
     schedules a one-shot local notification for trial day −1 at 10am on
     subscribe, independent of the `BookWhispers` Colophon switch (billing
     courtesy, not a story beat). Makes the terms page's promise real.
   - **Lapse/revoke DONE across all cadences:** `restorePurchases` maps every
     cadence → `standingOrderPackID`, so the existing BookShop `.task`
     lapse-check (revoke when not in `currentEntitlements`) now covers weekly/
     monthly/annual uniformly. Outright pack purchases stay permanent.
   - **Hero artifact DONE:** paywall page 2 renders the reader's own first-
     edition cover (`standingOrderHeroArtifact`, built from the onboarding
     result in `completeOnboarding`).
   - *Remaining:* formal `EntitlementLedger` type; re-offer placements (Bindery
     print flow, pack browsing, binding night); on-launch lapse re-check.
4. **Phase 4 — Tuning.** Local funnel counters (views → trial starts →
   conversions); copy iteration after TestFlight.

## Full celebration map — ALL DONE
Steps 0, 3, 4, 5, 7, 8, 10, 15 all have beats. Step 3 (snack) uses
`OnboardingSparkleSettle` (a one-shot sparkle over the margin-ration card).

## App Store Connect prerequisites (before the tiers go live)
- Create **weekly** + **monthly** auto-renewables in the SAME subscription
  group as the existing annual pass (productIDs in `standingOrderTiers`).
- Configure the **3-day introductory free trial** on all three.
- Paste Terms/Privacy URLs into the subscription group localization.
- Until these exist, StoreKit returns no products → the sheet shows fallback
  prices and DEBUG builds fall through to the dev counter (purchase still
  exercises the grant path).

## Decisions (locked 2026-07-04)

1. **Free/paid line:** monthly AND annual bindings stay **free** (they are the
   retention engine). Gated behind the Standing Order: content packs, premium
   stuff (premium cover templates, cast expansions, extra Gemma voices, print
   credits, etc.). Core capture/keep/braid always free. Everything simple,
   clear, fair.
2. **Weekly at launch: yes**, and — unlike the earlier lean — **all three
   tiers get the 3-day free trial** (weekly, monthly, annual). Simplicity over
   trial-gating games.
3. **Prices confirmed:** $3.99/wk, $6.99/mo, $39.99/yr.
4. **Paywall ships in the launch build** so it can be tuned and refined live.

Everything about money stays simple, clear, and fair — that is the brand.
