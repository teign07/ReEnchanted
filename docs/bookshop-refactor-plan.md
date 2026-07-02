# BookShop clarity pass — implementation plan

Goal: make the BookShop stop reading as "four shops in one scroll." Establish one
identity, lead with the whimsy market, explain the currencies in a line, and demote
the heavy physical-book checkout to an entry point (its full-screen studio already
exists — we just stop inlining it).

All edits are in **one file**: `InsideCoverApp/BookShopSheet.swift`
(the sheet is presented from `InsideCoverApp/ContentView.swift:949`, which does **not** need changes).

## Ground rules for the implementer

- These are surgical find/replace edits. Read the file first, then apply each block.
- **Do NOT delete or move** any of: `physicalBookStudioScreen`, the
  `.fullScreenCover(item: $physicalBookStudioContext)`, any `physicalBook*` `@State`
  property, any `physicalBook*` method, or the `PhysicalBook*` structs at the bottom
  of the file. That whole physical-order flow is a deliberately staged phase — we are
  only changing how the shop *presents* it, not the flow itself.
- **Keep the Bindery in the shop.** Its month/year binding is meant to live here; only
  the "A real Book of You" sub-block gets slimmed.
- After **each** task, do a compile check (see "Verify" at the bottom). Each task
  leaves the app buildable on its own.
- Sentence-case any new copy; match the surrounding `BookPalette` / font style.

Apply the tasks in order (1 → 5). Task 5 is optional polish.

---

## Task 1 — One line that explains the three currencies

Replace the whole `purseStrip` computed property.

**Find:**
```swift
    private var purseStrip: some View {
        HStack(spacing: 10) {
            purseChip(title: "Attention", value: liveAttention, systemImage: "eye", tint: BookPalette.teal)
            purseChip(title: "Belief", value: liveBelief, systemImage: "sparkles", tint: BookPalette.lampGold)
            purseChip(title: "Warmth", value: goblinWarmth, systemImage: "flame", tint: BookPalette.violet)
        }
    }
```

**Replace with:**
```swift
    private var purseStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                purseChip(title: "Attention", value: liveAttention, systemImage: "eye", tint: BookPalette.teal)
                purseChip(title: "Belief", value: liveBelief, systemImage: "sparkles", tint: BookPalette.lampGold)
                purseChip(title: "Warmth", value: goblinWarmth, systemImage: "flame", tint: BookPalette.violet)
            }
            Text("Attention is earned from Fae bargains. Belief is the world's coin, spent on the shelves. Warmth softens a goblin's price.")
                .font(.system(.caption2, design: .serif).italic())
                .foregroundStyle(BookPalette.nightText.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
```

**Acceptance:** three currency chips now have one italic caption under them.

---

## Task 2 — One name for the place

The place is **The Bookshop**; the rotating stall is tonight's **Goblin Market**.
Two small edits (the stall rename itself happens in Task 3).

**2a. Nav title.** Find:
```swift
            .navigationTitle("Goblin Market")
```
Replace with:
```swift
            .navigationTitle("The Bookshop")
```

**2b. Hero headline.** Find:
```swift
                    Text("The Goblin Market is open.")
```
Replace with:
```swift
                    Text("The Marginalia Goblins keep the shop.")
```
(The `THE BOOKSHOP` eyebrow just above it stays as-is.)

**Acceptance:** nav bar reads "The Bookshop"; hero reads THE BOOKSHOP / "The Marginalia Goblins keep the shop."

---

## Task 3 — Lead with the market; demote the Fae standing

Reorder the scroll so the delight (the stall) comes right after the clerk, the Bindery
drops below the market, and the "Your standing with the Fae" dashboard moves to the
bottom (it isn't shopping). This also renames the stall shelf to "The Goblin Market".

Replace the whole children block of the main `VStack` (starts at `marketHero`, ends at
the trailing disclaimer `Text`).

**Find:**
```swift
                        marketHero
                        purseStrip
                        clerkCard

                        binderySection

                        if !freePacks.isEmpty {
                            shelfBlock(title: "Free First Folio", subtitle: "One shelf is a gift. The clerk calls it a customer acquisition hex.", symbol: "gift.fill", accent: BookPalette.lampGold) {
                                ForEach(freePacks) { pack in freePackCard(pack) }
                            }
                        }

                        let visibleWares = stall.wares.filter { !boughtWareIDs.contains($0.id) }
                        if stall.open, !visibleWares.isEmpty {
                            shelfBlock(title: "Tonight's Stall", subtitle: stall.windowLine, symbol: "moon.stars.fill", accent: BookPalette.lampGold) {
                                ForEach(visibleWares) { wareCard($0) }
                            }
                        }

                        let visibleHidden = stall.hidden.filter { !boughtWareIDs.contains($0.id) }
                        if !visibleHidden.isEmpty {
                            shelfBlock(title: "Under the Counter", subtitle: "The clerk glances around, then slides a tray from beneath the boards.", symbol: "tray.full.fill", accent: BookPalette.violet) {
                                ForEach(visibleHidden) { wareCard($0, rare: true) }
                            }
                        }

                        shelfBlock(title: "The Paid Shelf", subtitle: merchantName.isEmpty ? "The till is waking." : merchantName, symbol: "creditcard.fill", accent: BookPalette.teal) {
                            if isLoading {
                                ProgressView("The Goblins are unlocking the till...")
                                    .tint(BookPalette.lampGold)
                                    .foregroundStyle(BookPalette.nightText.opacity(0.7))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                            } else {
                                let purchasable = offers.filter { !PackEntitlements.isUnlocked($0.listing.packID) }
                                ForEach(purchasable) { offer in offerCard(offer) }
                                if !ownedListings.isEmpty {
                                    subsectionLabel("Already Bound to You")
                                    ForEach(ownedListings) { boundCard($0) }
                                }
                                if !comingSoon.isEmpty {
                                    subsectionLabel("Being Printed")
                                    ForEach(comingSoon) { printingCard($0) }
                                }
                            }
                        }

                        standingSection

                        ledgerActions

                        Text("Paid packs use App Store prices and travel with your save. Attention and Belief are only spent inside the Book.")
                            .font(.system(.caption2, design: .serif).italic())
                            .foregroundStyle(BookPalette.nightText.opacity(0.55))
```

**Replace with:**
```swift
                        marketHero
                        purseStrip
                        clerkCard

                        let visibleWares = stall.wares.filter { !boughtWareIDs.contains($0.id) }
                        if stall.open, !visibleWares.isEmpty {
                            shelfBlock(title: "The Goblin Market", subtitle: stall.windowLine, symbol: "moon.stars.fill", accent: BookPalette.lampGold) {
                                ForEach(visibleWares) { wareCard($0) }
                            }
                        }

                        let visibleHidden = stall.hidden.filter { !boughtWareIDs.contains($0.id) }
                        if !visibleHidden.isEmpty {
                            shelfBlock(title: "Under the Counter", subtitle: "The clerk glances around, then slides a tray from beneath the boards.", symbol: "tray.full.fill", accent: BookPalette.violet) {
                                ForEach(visibleHidden) { wareCard($0, rare: true) }
                            }
                        }

                        if !freePacks.isEmpty {
                            shelfBlock(title: "Free First Folio", subtitle: "One shelf is a gift. The clerk calls it a customer acquisition hex.", symbol: "gift.fill", accent: BookPalette.lampGold) {
                                ForEach(freePacks) { pack in freePackCard(pack) }
                            }
                        }

                        binderySection

                        shelfBlock(title: "The Paid Shelf", subtitle: merchantName.isEmpty ? "The till is waking." : merchantName, symbol: "creditcard.fill", accent: BookPalette.teal) {
                            if isLoading {
                                ProgressView("The Goblins are unlocking the till...")
                                    .tint(BookPalette.lampGold)
                                    .foregroundStyle(BookPalette.nightText.opacity(0.7))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                            } else {
                                let purchasable = offers.filter { !PackEntitlements.isUnlocked($0.listing.packID) }
                                ForEach(purchasable) { offer in offerCard(offer) }
                                if !ownedListings.isEmpty {
                                    subsectionLabel("Already Bound to You")
                                    ForEach(ownedListings) { boundCard($0) }
                                }
                                if !comingSoon.isEmpty {
                                    subsectionLabel("Being Printed")
                                    ForEach(comingSoon) { printingCard($0) }
                                }
                            }
                        }

                        ledgerActions

                        standingSection

                        Text("Paid packs use App Store prices and travel with your save. Attention and Belief are only spent inside the Book.")
                            .font(.system(.caption2, design: .serif).italic())
                            .foregroundStyle(BookPalette.nightText.opacity(0.55))
```

Target order, for reference: hero → purse → clerk → **Goblin Market stall → Under the Counter → Free First Folio** → Bindery → Paid Shelf → ledger → **standing (bottom)** → disclaimer.

**Acceptance:** after the clerk, the first shelf is "The Goblin Market" (the stall), not the Bindery. The Fae standing block is now just above the closing disclaimer.

---

## Task 4 — Slim "A real Book of You" to an entry point (+ coming-soon gate)

This is the big win. The full order flow already lives in `physicalBookStudioScreen`
(opened via `physicalBookStudioContext`). We replace the redundant inline
preview/estimate/make/share block inside `binderySection` with a single button that
opens that studio — and show a quiet "coming soon" when the backend isn't wired up.

In `binderySection`, replace the entire `VStack(alignment: .leading, spacing: 6) { … }`
(the third sub-block, the one starting with `let printVariants = PrintSpec.bookOfYouVariants`).
Do **not** touch the `.padding(10)` / `.background(...)` lines right after it.

**Find:**
```swift
                VStack(alignment: .leading, spacing: 6) {
                    let printVariants = PrintSpec.bookOfYouVariants
                    let selectedPrintSpec = printVariants[min(selectedPrintVariantIndex, printVariants.count - 1)]
                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Label("A real Book of You", systemImage: "shippingbox")
                                .font(.callout.weight(.bold))
                                .foregroundStyle(BookPalette.violet)
                            Text("A made-to-order 6×9 hardcover, dressed like a favorite fantasy novel.")
                                .font(.callout)
                                .foregroundStyle(BookPalette.ink.opacity(0.68))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 8)
                        if let printPreviewEdition {
                            Button {
                                BookFeedback.play(.openPage)
                                physicalBookStudioContext = PhysicalBookStudioContext(edition: printPreviewEdition)
                            } label: {
                                Label("Choose", systemImage: "book.closed")
                                    .font(.callout.weight(.bold))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(BookPalette.violet)
                        } else if preparedPrintInteriorURL == nil {
                            Button {
                                BookFeedback.play(.openPage)
                                onMakePrintReady(selectedPrintSpec)
                            } label: {
                                Label("Make", systemImage: "hammer")
                                    .font(.callout.weight(.bold))
                            }
                            .buttonStyle(.bordered)
                            .tint(BookPalette.violet)
                        }
                    }

                    if let printPreviewEdition {
                        PhysicalBookShelfPreview(edition: printPreviewEdition, spec: selectedPrintSpec)
                        Button {
                            BookFeedback.play(.openPage)
                            physicalBookStudioContext = PhysicalBookStudioContext(edition: printPreviewEdition)
                        } label: {
                            Label("Choose my copy", systemImage: "sparkles")
                                .font(.callout.weight(.bold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(BookPalette.violet)
                    } else {
                        Text("When a month is ready, this shelf opens into cover previews, pricing, and checkout.")
                            .font(.callout)
                            .foregroundStyle(BookPalette.ink.opacity(0.68))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text("\(selectedPrintSpec.name). Estimated before delivery: \(physicalBookShelfEstimateLine(spec: selectedPrintSpec)).")
                        .font(.callout)
                        .foregroundStyle(BookPalette.ink.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)

                    if let interior = preparedPrintInteriorURL, let cover = preparedPrintCoverURL {
                        HStack(spacing: 8) {
                            ShareLink(item: interior) {
                                Label("Interior PDF", systemImage: "doc.richtext")
                                    .font(.callout.weight(.bold))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(BookPalette.violet)
                            ShareLink(item: cover) {
                                Label("Cover PDF", systemImage: "book.closed")
                                    .font(.callout.weight(.bold))
                            }
                            .buttonStyle(.bordered)
                            .tint(BookPalette.violet)
                        }
                        Text("Proof them free in Lulu's online previewer before you order.")
                            .font(.callout)
                            .foregroundStyle(BookPalette.ink.opacity(0.68))
                    } else if printPreviewEdition != nil {
                        Button {
                            BookFeedback.play(.openPage)
                            onMakePrintReady(selectedPrintSpec)
                        } label: {
                            Label("Make print PDFs", systemImage: "hammer")
                                .font(.callout.weight(.bold))
                        }
                        .buttonStyle(.bordered)
                        .tint(BookPalette.violet)
                    }
                }
```

**Replace with:**
```swift
                VStack(alignment: .leading, spacing: 8) {
                    Label("A real Book of You", systemImage: "shippingbox")
                        .font(.callout.weight(.bold))
                        .foregroundStyle(BookPalette.violet)
                    Text("A made-to-order 6×9 hardcover, dressed like a favorite fantasy novel.")
                        .font(.callout)
                        .foregroundStyle(BookPalette.ink.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)

                    if !PhysicalBookQuoteClient.isQuoteServiceConfigured {
                        Text("Cloth-bound copies are coming soon.")
                            .font(.system(.caption, design: .serif).italic())
                            .foregroundStyle(BookPalette.ink.opacity(0.6))
                    } else if let printPreviewEdition {
                        Button {
                            BookFeedback.play(.openPage)
                            physicalBookStudioContext = PhysicalBookStudioContext(edition: printPreviewEdition)
                        } label: {
                            Label("Order a physical copy", systemImage: "book.closed")
                                .font(.callout.weight(.bold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(BookPalette.violet)
                    } else {
                        Text("Bind a month first, then this shelf opens into cover choices, pricing, and checkout.")
                            .font(.callout)
                            .foregroundStyle(BookPalette.ink.opacity(0.68))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
```

**Note (optional cleanup):** after this, `physicalBookShelfEstimateLine(spec:)` and the
`PhysicalBookShelfPreview` struct are no longer referenced and the compiler may warn
they're unused. Leaving them is harmless (warning, not error). If you want a clean
build, delete `private func physicalBookShelfEstimateLine(...)` and the
`private struct PhysicalBookShelfPreview: View { … }`. Don't remove anything else.

**Acceptance:** the Bindery shows month-bind, year-bind, then a single
"Order a physical copy" button (or "Cloth-bound copies are coming soon." when the
backend isn't configured). Tapping the button still opens the full-screen Book of You
studio. Nothing about the studio itself changed.

---

## Task 5 (optional) — Hide the developer-only "advanced file links" box

The "paste public PDF links manually" disclosure inside the studio is a fallback for
failed uploads, not something a normal reader should see. Gate it behind `#if DEBUG`.

In `physicalBookSubmissionPanel`, find:
```swift
                physicalBookHostedProofLinks()
                physicalBookAdvancedFileLinks()
```
Replace with:
```swift
                physicalBookHostedProofLinks()
                #if DEBUG
                physicalBookAdvancedFileLinks()
                #endif
```

**Acceptance:** release builds no longer show the "Advanced file links" box; debug builds still do.

---

## Verify (run after each task, and once at the end)

This is an Xcode iOS app target (not the SwiftPM package), so verify with a build:

```sh
xcodebuild -list -project EnchantifyInsideCover.xcodeproj          # find the app scheme name
xcodebuild -project EnchantifyInsideCover.xcodeproj \
  -scheme "<AppSchemeName>" \
  -destination 'generic/platform=iOS Simulator' build
```

Or open the project in Xcode and press ⌘B. A clean compile is the bar; these are
layout/copy changes with no logic to unit-test. If you can boot a simulator, open the
BookShop sheet and eyeball the new order and the "Order a physical copy" button.

The SwiftPM core tests should be untouched, but they're quick insurance:
```sh
swift test
```

## Done means

- One name in the chrome ("The Bookshop"); the stall shelf is "The Goblin Market".
- A one-line currency legend under the purse.
- Scroll leads with the market, Bindery sits below it, Fae standing is at the bottom.
- "A real Book of You" is a single button into the existing studio (or a coming-soon line).
- Build is green.
