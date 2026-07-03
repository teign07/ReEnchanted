import SwiftUI
import CryptoKit
import StripePaymentSheet
import UIKit
#if canImport(QuickLook)
import QuickLook
#endif

/// The BookShop: the Marginalia Goblins' living market tucked into the Stacks.
/// One place, three economies — Attention earned from Fae bargains, Belief spent
/// as the world's main sink, and App Store purchases for content packs. Stock
/// rotates with the day and the moon; an under-the-counter shelf appears only
/// when the world leans in.
struct BookShopSheet: View {
    let stall: GoblinStall
    let fae: FaePlayerState
    let attention: Int
    let belief: Int
    let goblinWarmth: Int
    let onBuyWare: (MarketWare) -> Void   // in-world purchase (Attention/Belief)
    let onUnlock: (String) -> Void        // packID, after a verified App Store purchase
    var onOpenArchive: (String) -> Void = { _ in }
    var onHaggle: (MarketWare) -> Int? = { _ in nil }   // spends 1 Warmth; returns discount, or nil if refused
    var onClerkBanter: () async -> String? = { nil }
    var onOpenBargain: (FaeBargain) -> Void = { _ in }
    var onMarkNextMarket: () -> Void = {}

    // The Bindery shelf: sew a finished month (or year) into a keepable chapter.
    var binderyMonthLabel: String = ""
    var binderyMonthPageCount: Int = 0
    var preparedMonthlyEditionURL: URL? = nil
    var preparedAnnualEditionURL: URL? = nil
    var binderyNote: String? = nil
    var preparedPrintInteriorURL: URL? = nil
    var preparedPrintCoverURL: URL? = nil
    var printPreviewEdition: MonthlyEdition? = nil
    var onBindMonth: () -> Void = {}
    var onBindMonthGemma: () -> Void = {}
    var onBindYear: () -> Void = {}
    var onMakePrintReady: (PrintSpec) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var merchantName = ""
    @State private var offers: [BookShopOffer] = []
    @State private var isLoading = true
    @State private var isPurchasing = false
    @State private var isClerkSpeaking = false
    @State private var clerkLine = "The clerk looks up from a ledger longer than the counter."
    @State private var spentAttention = 0
    @State private var spentBelief = 0
    @State private var boughtWareIDs: Set<String> = []
    @State private var boundFreePackIDs: Set<String> = []
    @State private var haggleDiscounts: [String: Int] = [:]
    @State private var haggledWareIDs: Set<String> = []
    @State private var physicalBookStudioContext: PhysicalBookStudioContext?
    @State private var selectedPrintVariantIndex = 0
    @State private var physicalBookQuotePostalCode = ""
    @State private var physicalBookQuoteStateCode = ""
    @State private var physicalBookQuote: PhysicalBookQuote?
    @State private var physicalBookQuoteMessage: String?
    @State private var isLoadingPhysicalBookQuote = false
    @State private var selectedPhysicalBookShippingOptionID: String?
    @State private var physicalBookContactEmail = ""
    @State private var physicalBookRecipientName = ""
    @State private var physicalBookStreet1 = ""
    @State private var physicalBookStreet2 = ""
    @State private var physicalBookCity = ""
    @State private var physicalBookShippingStateCode = ""
    @State private var physicalBookShippingPostalCode = ""
    @State private var physicalBookShippingCountryCode = "US"
    @State private var physicalBookPhoneNumber = ""
    @State private var physicalBookPaymentIntent: PhysicalBookPaymentIntent?
    @State private var physicalBookPaymentSheet: PaymentSheet?
    @State private var physicalBookCheckoutMessage: String?
    @State private var pendingPhysicalBookOrder: PhysicalBookPendingOrderDraft?
    @State private var physicalBookPrintFileChecksums: PhysicalBookPrintFileChecksums?
    @State private var hostedPhysicalBookInteriorURL = ""
    @State private var hostedPhysicalBookCoverURL = ""
    @State private var physicalBookSubmissionMessage: String?
    @State private var submittedPhysicalBookOrder: PhysicalBookOrder?
    @State private var isUploadingPhysicalBookPrintFiles = false
    @State private var isSubmittingPhysicalBookOrder = false
    @State private var isRefreshingPhysicalBookOrder = false
    @State private var isPreparingPhysicalBookCheckout = false
    @State private var physicalBookProofPreviewURL: URL?
    @State private var showPhysicalBookAdvancedFileLinks = false
    @State private var physicalBookThirdPartyPrintConsent = false

    private var ownedListings: [BookShopListing] {
        BookShopCatalog.listings.filter { !$0.comingSoon && PackEntitlements.isUnlocked($0.packID) }
    }
    private var freePacks: [PageArchetypePack] {
        PageArchetypePackRegistry.bundledPacks.filter { ["nocturne-folio", "margins-and-mysteries"].contains($0.id) }
    }
    private var comingSoon: [BookShopListing] {
        BookShopCatalog.listings.filter { $0.comingSoon }
    }
    private var liveAttention: Int { max(0, attention - spentAttention) }
    private var liveBelief: Int { max(0, belief - spentBelief) }

    var body: some View {
        NavigationStack {
            ZStack {
                BookBackground()
                marketAtmosphere
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
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

                        binderySection

                        shelfBlock(title: "The Paid Shelf", subtitle: merchantName.isEmpty ? "The till is waking." : merchantName, symbol: "creditcard.fill", accent: BookPalette.teal) {
                            if !freePacks.isEmpty {
                                subsectionLabel("Free Gifts")
                                ForEach(freePacks) { pack in freePackCard(pack) }
                            }
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
                    }
                    .padding(18)
                }
            }
            .navigationTitle("The Bookshop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Leave quietly") {
                        BookFeedback.play(.dismissPage)
                        dismiss()
                    }
                }
            }
            .fullScreenCover(item: $physicalBookStudioContext) { context in
                physicalBookStudioScreen(edition: context.edition)
            }
            .task {
                let merchant = await BookShopTill.resolveMerchant()
                merchantName = merchant.tillName
                offers = await merchant.offers()
                isLoading = false
            }
        }
    }

    private var marketAtmosphere: some View {
        ZStack {
            LinearGradient(
                colors: [
                    BookPalette.nightPanel.opacity(0.25),
                    BookPalette.violet.opacity(0.20),
                    BookPalette.teal.opacity(0.12),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack {
                HStack {
                    Image(systemName: "seal")
                        .font(.system(size: 120, weight: .thin))
                        .foregroundStyle(BookPalette.lampGold.opacity(0.08))
                        .rotationEffect(.degrees(-12))
                    Spacer()
                }
                Spacer()
            }
            .padding(.top, 18)
            .padding(.leading, -20)
        }
        .ignoresSafeArea()
    }

    private var marketHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [BookPalette.lampGold.opacity(0.95), BookPalette.gold.opacity(0.80)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "storefront.fill")
                        .font(.title2.weight(.black))
                        .foregroundStyle(BookPalette.nightPanel)
                }
                .frame(width: 56, height: 56)
                .rotationEffect(.degrees(-2))
                .shadow(color: BookPalette.lampGold.opacity(0.25), radius: 14, x: 0, y: 8)

                VStack(alignment: .leading, spacing: 5) {
                    Text("THE BOOKSHOP")
                        .font(.caption.weight(.black))
                        .kerning(1.4)
                        .foregroundStyle(BookPalette.lampGold)
                    Text("The Marginalia Goblins keep the shop.")
                        .font(.system(.largeTitle, design: .serif, weight: .bold))
                        .foregroundStyle(BookPalette.nightText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(stall.open ? stall.moodLine : "The stalls are shuttered, but the ledger still breathes under the counter.")
                        .font(.system(.callout, design: .serif))
                        .foregroundStyle(BookPalette.nightText.opacity(0.76))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                marketTag(stall.open ? "Open tonight" : "After-hours ledger", systemImage: stall.open ? "door.left.hand.open" : "lock.open")
                marketTag("\(stall.wares.count + stall.hidden.count) wares", systemImage: "shippingbox")
                marketTag(merchantName.isEmpty ? "Till waking" : merchantName, systemImage: "creditcard")
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(BookPalette.nightPanel.opacity(0.78))
                .overlay(alignment: .bottomTrailing) {
                    Image("MarginaliaStamp")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 132)
                        .opacity(0.13)
                        .rotationEffect(.degrees(11))
                        .offset(x: 18, y: 20)
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [BookPalette.lampGold.opacity(0.58), BookPalette.teal.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        }
    }

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

    private var ledgerActions: some View {
        VStack(spacing: 10) {
            Button {
                BookFeedback.play(.select)
                onMarkNextMarket()
                clerkLine = "The clerk circles a date in the ledger. \u{201C}The new-moon market. Don't be late; the good stalls go first.\u{201D}"
            } label: {
                Label("Mark the next new-moon market", systemImage: "calendar.badge.plus")
                    .font(.caption.weight(.bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(BookPalette.lampGold)

            Button {
                Task { await restore() }
            } label: {
                Label("Ask the ledger about past purchases", systemImage: "arrow.counterclockwise")
                    .font(.caption.weight(.bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(BookPalette.teal)
        }
        .padding(.top, 2)
    }

    private func marketTag(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.black))
            .lineLimit(1)
            .minimumScaleFactor(0.74)
            .foregroundStyle(BookPalette.nightText.opacity(0.88))
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(BookPalette.page.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(BookPalette.lampGold.opacity(0.20), lineWidth: 1)
            }
    }

    private func purseChip(title: String, value: Int, systemImage: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.black))
                Text(title.uppercased())
                    .font(.caption2.weight(.black))
                    .kerning(0.5)
            }
            .foregroundStyle(tint)

            Text("\(value)")
                .font(.system(.title3, design: .serif, weight: .bold))
                .foregroundStyle(BookPalette.nightText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(BookPalette.nightPanel.opacity(0.62), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.28), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func shelfBlock<Content: View>(
        title: String,
        subtitle: String,
        symbol: String,
        accent: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: symbol)
                    .font(.caption.weight(.black))
                    .foregroundStyle(BookPalette.nightPanel)
                    .frame(width: 30, height: 30)
                    .background(accent, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .rotationEffect(.degrees(-2))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title.uppercased())
                        .font(.caption.weight(.black))
                        .kerning(1.2)
                        .foregroundStyle(accent)
                    Text(subtitle)
                        .font(.system(.caption2, design: .serif).italic())
                        .foregroundStyle(BookPalette.nightText.opacity(0.64))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            content()
        }
        .padding(12)
        .background(BookPalette.nightPanel.opacity(0.34), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(accent.opacity(0.20), lineWidth: 1)
        }
    }

    private func subsectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption.weight(.black))
            .kerning(1)
            .foregroundStyle(BookPalette.violet.opacity(0.82))
            .padding(.top, 8)
    }

    private var clerkCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "books.vertical.fill")
                    .font(.caption.weight(.black))
                    .foregroundStyle(BookPalette.nightPanel)
                    .frame(width: 28, height: 28)
                    .background(BookPalette.lampGold, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                Text("THE CLERK")
                    .font(.caption.weight(.black))
                    .kerning(1.2)
                    .foregroundStyle(BookPalette.lampGold)
                Spacer()
                Text("\(stall.mood.rawValue.capitalized)")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(BookPalette.teal)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(BookPalette.teal.opacity(0.10), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            Text(clerkLine)
                .font(.system(.callout, design: .serif))
                .foregroundStyle(BookPalette.ink.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
            Text(stall.moodLine)
                .font(.system(.caption, design: .serif).italic())
                .foregroundStyle(BookPalette.ink.opacity(0.66))
                .fixedSize(horizontal: false, vertical: true)
            Text(stall.windowLine)
                .font(.caption2)
                .foregroundStyle(BookPalette.teal.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Button {
                guard !isClerkSpeaking else { return }
                isClerkSpeaking = true
                BookFeedback.play(.knock)
                Task {
                    let line = await onClerkBanter()
                    if let line, !line.isEmpty { clerkLine = line }
                    isClerkSpeaking = false
                }
            } label: {
                Label(isClerkSpeaking ? "The clerk considers you..." : "Knock for the clerk's read",
                      systemImage: "hand.tap")
                    .font(.caption2.weight(.bold))
            }
            .buttonStyle(.bordered)
            .tint(BookPalette.teal)
            .disabled(isClerkSpeaking)
            .padding(.top, 4)

            if isClerkSpeaking {
                LocalBrainWorkingStatusCard(
                    label: "bookshop-clerk",
                    presentation: .page
                )
                .padding(.top, 4)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [BookPalette.page.opacity(0.98), BookPalette.paper.opacity(0.88)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.4), lineWidth: 1)
        }
    }

    /// The Bindery: the discoverable home for binding a finished month or year
    /// into a chapter the reader can keep, share, or (soon) order in cloth. The
    /// same actions live in the Colophon's workshop; this surfaces them where a
    /// reader will actually find them.
    @ViewBuilder
    private var binderySection: some View {
        shelfBlock(
            title: "The Bindery",
            subtitle: "Sew a finished month into a chapter — keep it, share it, or send it out for a real cloth binding.",
            symbol: "books.vertical.fill",
            accent: BookPalette.lampGold
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(binderyMonthPageCount > 0 ? binderyMonthLabel : "No finished month yet")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(BookPalette.ink)
                        Text(binderyMonthPageCount > 0
                             ? "\(binderyMonthPageCount) \(binderyMonthPageCount == 1 ? "page" : "pages") ready to bind"
                             : "Keep a few pages and a month will be ready to sew.")
                            .font(.caption2)
                            .foregroundStyle(BookPalette.ink.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    if let preparedMonthlyEditionURL {
                        ShareLink(item: preparedMonthlyEditionURL) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(.caption2.weight(.bold))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(BookPalette.lampGold)
                    } else if binderyMonthPageCount > 0 {
                        Menu {
                            Button {
                                BookFeedback.play(.openPage)
                                onBindMonth()
                            } label: {
                                Label("Bind now (fast)", systemImage: "bolt")
                            }
                            Button {
                                BookFeedback.play(.openPage)
                                onBindMonthGemma()
                            } label: {
                                Label("Bind with Gemma's conclusion", systemImage: "sparkles")
                            }
                        } label: {
                            Label("Bind", systemImage: "book.pages")
                                .font(.caption2.weight(.bold))
                        } primaryAction: {
                            BookFeedback.play(.openPage)
                            onBindMonth()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(BookPalette.lampGold)
                    }
                }

                Divider().overlay(BookPalette.ink.opacity(0.12))

                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("The year, bound whole")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(BookPalette.ink)
                        Text("Every kept month, sewn into one volume.")
                            .font(.caption2)
                            .foregroundStyle(BookPalette.ink.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    if let preparedAnnualEditionURL {
                        ShareLink(item: preparedAnnualEditionURL) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(.caption2.weight(.bold))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(BookPalette.lampGold)
                    } else {
                        Button {
                            BookFeedback.play(.openPage)
                            onBindYear()
                        } label: {
                            Label("Bind the year", systemImage: "books.vertical")
                                .font(.caption2.weight(.bold))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(BookPalette.lampGold)
                    }
                }

                if let binderyNote {
                    Text(binderyNote)
                        .font(.system(.caption2, design: .serif).italic())
                        .foregroundStyle(BookPalette.ink.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider().overlay(BookPalette.ink.opacity(0.12))

                if let printPreviewEdition {
                    Button {
                        BookFeedback.play(.openPage)
                        physicalBookStudioContext = PhysicalBookStudioContext(edition: printPreviewEdition)
                    } label: {
                        physicalBookEntryLabel(
                            hint: "Tap to choose a cover, see pricing, and check out.",
                            showChevron: true
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens the full-screen ordering process")
                } else {
                    physicalBookEntryLabel(
                        hint: "Bind a month first, then this shelf opens into cover choices, pricing, and checkout.",
                        showChevron: false
                    )
                }
            }
            .padding(10)
            .background(BookPalette.page.opacity(0.85), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    /// The tappable "A real Book of You" card in the Bindery. The whole card is the
    /// tap target; when a month is ready it opens the full-screen ordering studio.
    private func physicalBookEntryLabel(hint: String, showChevron: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label("A real Book of You", systemImage: "shippingbox")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(BookPalette.violet)
                Spacer(minLength: 8)
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BookPalette.violet.opacity(0.7))
                }
            }
            Text("A made-to-order 6×9 hardcover, dressed like a favorite fantasy novel.")
                .font(.callout)
                .foregroundStyle(BookPalette.ink.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)
            Text(hint)
                .font(.system(.caption, design: .serif).italic())
                .foregroundStyle(BookPalette.ink.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func physicalBookStudioScreen(edition: MonthlyEdition) -> some View {
        let printVariants = PrintSpec.bookOfYouVariants
        let selectedPrintSpec = printVariants[min(selectedPrintVariantIndex, printVariants.count - 1)]

        return NavigationStack {
            ZStack {
                BookBackground()
                LinearGradient(
                    colors: [
                        BookPalette.violet.opacity(0.18),
                        BookPalette.lampGold.opacity(0.12),
                        BookPalette.teal.opacity(0.08),
                        .clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        physicalBookStudioHero(edition: edition, spec: selectedPrintSpec)
                        physicalBookReadinessStrip()
                        physicalBookPendingOrderPanel()
                        physicalBookVariantChooser(edition: edition, variants: printVariants)
                        physicalBookStudioPrintFilesPanel(spec: selectedPrintSpec)
                        physicalBookOrderReviewPanel(edition: edition, spec: selectedPrintSpec)
                        physicalBookStudioCheckoutPanel(edition: edition, spec: selectedPrintSpec)
                        physicalBookSubmissionPanel(edition: edition, spec: selectedPrintSpec)
                    }
                    .padding(18)
                }
            }
            .navigationTitle("Book of You")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: "\(BookThemeEngine.monthKey(for: edition.startDate))|\(selectedPrintSpec.coverTreatment)") {
                loadPendingPhysicalBookOrder(edition: edition, spec: selectedPrintSpec)
            }
            .task(id: physicalBookPrintFilesTaskID) {
                physicalBookThirdPartyPrintConsent = false
                loadPhysicalBookPrintFileChecksums()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        physicalBookStudioContext = nil
                    }
                }
            }
        }
        #if canImport(QuickLook)
        .quickLookPreview($physicalBookProofPreviewURL)
        #endif
    }

    @ViewBuilder
    private func physicalBookPendingOrderPanel() -> some View {
        if let pendingPhysicalBookOrder {
            VStack(alignment: .leading, spacing: 8) {
                subsectionLabel("Order Pending")
                physicalBookReviewRow("Payment", Self.dollars(pendingPhysicalBookOrder.amount), systemImage: "checkmark.circle.fill")
                physicalBookReviewRow("Binding", pendingPhysicalBookOrder.variant.displayName, systemImage: "book.closed")
                physicalBookReviewRow("Receipt", pendingPhysicalBookOrder.contactEmail, systemImage: "envelope")
                physicalBookReviewRow("Status", physicalBookPendingStatusText(pendingPhysicalBookOrder.status), systemImage: "hourglass")
                Text(physicalBookPendingDetailText(pendingPhysicalBookOrder))
                    .font(.caption2)
                    .foregroundStyle(BookPalette.ink.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(BookPalette.teal.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(BookPalette.teal.opacity(0.28), lineWidth: 1)
            }
        }
    }

    private func physicalBookPendingDetailText(_ draft: PhysicalBookPendingOrderDraft) -> String {
        switch draft.status {
        case .paymentReceivedPendingPrintSubmission, .submissionWaitingForLuluCredentials:
            return "This paid order is saved on this device. Final print submission will unlock when Lulu approves API access."
        case .submittedToBackend:
            if draft.submittedOrder?.luluPrintJobID != nil {
                return "This paid order was submitted to Lulu. You can refresh its production and shipping status below."
            }
            return "This paid order was submitted to the backend. Refresh status once Lulu returns a print-job id."
        }
    }

    private func physicalBookPendingStatusText(_ status: PhysicalBookPendingOrderDraft.Status) -> String {
        switch status {
        case .paymentReceivedPendingPrintSubmission:
            return "Payment received"
        case .submissionWaitingForLuluCredentials:
            return "Waiting on Lulu credentials"
        case .submittedToBackend:
            return "Submitted to backend"
        }
    }

    private func physicalBookOrderStatusText(_ status: PhysicalBookOrder.Status) -> String {
        switch status {
        case .paymentPending:
            return "Payment pending"
        case .submittedToLulu:
            return "Submitted to Lulu"
        case .inProduction:
            return "In production"
        case .shipped:
            return "Shipped"
        case .delivered:
            return "Delivered"
        case .cancelled:
            return "Cancelled"
        case .failed:
            return "Failed"
        }
    }

    private func physicalBookReadinessStrip() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            subsectionLabel("Order Readiness")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 8)], spacing: 8) {
                physicalBookReadinessStep(
                    title: "Choose binding",
                    detail: PrintSpec.bookOfYouVariants[min(selectedPrintVariantIndex, PrintSpec.bookOfYouVariants.count - 1)].name,
                    systemImage: "checkmark.seal.fill",
                    isComplete: true
                )
                physicalBookReadinessStep(
                    title: "Make PDFs",
                    detail: physicalBookPrintFilesReady ? "Interior and cover ready" : "Make print PDFs first",
                    systemImage: physicalBookPrintFilesReady ? "doc.richtext.fill" : "doc.badge.plus",
                    isComplete: physicalBookPrintFilesReady
                )
                physicalBookReadinessStep(
                    title: "Get price",
                    detail: physicalBookQuoteReadinessText,
                    systemImage: physicalBookQuote == nil ? "truck.box" : "checkmark.circle.fill",
                    isComplete: physicalBookQuote != nil
                )
                physicalBookReadinessStep(
                    title: "Checkout",
                    detail: physicalBookPaymentSheet == nil ? "Review and pay securely" : "Secure payment ready",
                    systemImage: physicalBookPaymentSheet == nil ? "creditcard" : "lock.fill",
                    isComplete: physicalBookPaymentSheet != nil || pendingPhysicalBookOrder != nil
                )
                physicalBookReadinessStep(
                    title: "Send to print",
                    detail: "Unlocks after proofing",
                    systemImage: "shippingbox",
                    isComplete: false
                )
            }
        }
        .padding(12)
        .background(BookPalette.page.opacity(0.84), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func physicalBookReadinessStep(title: String, detail: String, systemImage: String, isComplete: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.callout.weight(.black))
                Text(title.uppercased())
                    .font(.caption.weight(.black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(isComplete ? BookPalette.teal : BookPalette.violet)

            Text(detail)
                .font(.callout)
                .foregroundStyle(BookPalette.ink.opacity(0.74))
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(9)
        .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
        .background(
            (isComplete ? BookPalette.teal.opacity(0.10) : BookPalette.violet.opacity(0.08)),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
    }

    private func physicalBookStudioHero(edition: MonthlyEdition, spec: PrintSpec) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Bind \(edition.monthName)")
                    .font(.system(.title2, design: .serif, weight: .bold))
                    .foregroundStyle(BookPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("A personal hardcover for the pages worth keeping close.")
                    .font(.system(.callout, design: .serif))
                    .foregroundStyle(BookPalette.ink.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }

            PhysicalBookPreview(edition: edition, spec: spec)
                .frame(maxWidth: .infinity)
        }
        .padding(14)
        .background(BookPalette.page.opacity(0.92), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.24), lineWidth: 1)
        }
    }

    private func physicalBookVariantChooser(edition: MonthlyEdition, variants: [PrintSpec]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            subsectionLabel("Choose Binding")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 10)], spacing: 10) {
                ForEach(variants.indices, id: \.self) { index in
                    physicalBookVariantCard(edition: edition, spec: variants[index], index: index)
                }
            }
        }
    }

    private func physicalBookVariantCard(edition: MonthlyEdition, spec: PrintSpec, index: Int) -> some View {
        let isSelected = selectedPrintVariantIndex == index
        return Button {
            BookFeedback.play(.openPage)
            selectPhysicalBookVariant(index)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    PhysicalBookCoverImage(edition: edition, spec: spec)
                        .frame(height: 210)
                    if isSelected {
                        Label("Selected", systemImage: "checkmark.seal.fill")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(BookPalette.nightText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(BookPalette.violet.opacity(0.88), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .padding(8)
                    }
                }

                Text(spec.name)
                    .font(.system(.subheadline, design: .serif, weight: .bold))
                    .foregroundStyle(BookPalette.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(physicalBookVariantMood(for: spec))
                    .font(.caption2)
                    .foregroundStyle(BookPalette.ink.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
                Text(physicalBookEstimatedPriceLine(edition: edition, spec: spec))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(BookPalette.violet.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? BookPalette.violet.opacity(0.13) : BookPalette.page.opacity(0.84),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? BookPalette.violet.opacity(0.72) : BookPalette.ink.opacity(0.12), lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(spec.name), \(isSelected ? "selected" : "not selected")")
    }

    private func physicalBookStudioPrintFilesPanel(spec: PrintSpec) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            subsectionLabel("Print Files")
            if let interior = preparedPrintInteriorURL, let cover = preparedPrintCoverURL {
                HStack(spacing: 8) {
                    Button {
                        physicalBookProofPreviewURL = interior
                        BookFeedback.play(.openPage)
                    } label: {
                        Label("Proof interior", systemImage: "doc.text.magnifyingglass")
                            .font(.callout.weight(.bold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(BookPalette.violet)

                    Button {
                        physicalBookProofPreviewURL = cover
                        BookFeedback.play(.openPage)
                    } label: {
                        Label("Proof cover", systemImage: "book.closed")
                            .font(.callout.weight(.bold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(BookPalette.violet)
                }
                HStack(spacing: 8) {
                    ShareLink(item: interior) {
                        Label("Share interior", systemImage: "square.and.arrow.up")
                            .font(.caption.weight(.bold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(BookPalette.ink.opacity(0.7))

                    ShareLink(item: cover) {
                        Label("Share cover", systemImage: "square.and.arrow.up")
                            .font(.caption.weight(.bold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(BookPalette.ink.opacity(0.7))
                }
                physicalBookChecksumRows()
                Text("Open both proofs before checkout. These are the exact interior and cover PDFs that will be uploaded for Lulu.")
                    .font(.callout)
                    .foregroundStyle(BookPalette.ink.opacity(0.68))
            } else {
                Button {
                    BookFeedback.play(.openPage)
                    onMakePrintReady(spec)
                } label: {
                    Label("Make print PDFs", systemImage: "hammer")
                        .font(.callout.weight(.bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(BookPalette.violet)
                Text("Creates the Lulu interior and cover files for the selected binding.")
                    .font(.callout)
                    .foregroundStyle(BookPalette.ink.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(BookPalette.page.opacity(0.84), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private func physicalBookChecksumRows() -> some View {
        if let physicalBookPrintFileChecksums {
            VStack(alignment: .leading, spacing: 6) {
                physicalBookChecksumRow(
                    title: "Interior MD5",
                    value: physicalBookPrintFileChecksums.interiorMD5,
                    systemImage: "number"
                )
                physicalBookChecksumRow(
                    title: "Cover MD5",
                    value: physicalBookPrintFileChecksums.coverMD5,
                    systemImage: "number"
                )
            }
            .padding(.vertical, 4)
        } else {
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.mini)
                Text("Reading print-file checksums...")
                    .font(.caption2)
                    .foregroundStyle(BookPalette.ink.opacity(0.55))
            }
            .padding(.vertical, 4)
        }
    }

    private func physicalBookChecksumRow(title: String, value: String, systemImage: String) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.bold))
                .foregroundStyle(BookPalette.violet)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(BookPalette.ink.opacity(0.66))
                Text(value)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(BookPalette.ink.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
            }
            Spacer(minLength: 8)
            Button {
                UIPasteboard.general.string = value
                BookFeedback.play(.select)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.caption.weight(.bold))
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .accessibilityLabel("Copy \(title)")
        }
    }

    private func physicalBookOrderReviewPanel(edition: MonthlyEdition, spec: PrintSpec) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            subsectionLabel("Review")
            physicalBookReviewRow("Binding", spec.name, systemImage: "book.closed")
            physicalBookReviewRow("Pages", "\(PrintGeometry.boundPageCount(rawPages: max(edition.pageCount, 24), spec: spec)) pages", systemImage: "doc.text")
            physicalBookReviewRow("Print files", physicalBookPrintFilesReady ? "Ready to proof" : "Make print PDFs first", systemImage: physicalBookPrintFilesReady ? "checkmark.circle.fill" : "exclamationmark.circle")
            physicalBookReviewRow("Price", physicalBookSelectedTotalText, systemImage: "creditcard")
            physicalBookReviewRow("Ship to", physicalBookShipToReviewText, systemImage: "shippingbox")

            Text(physicalBookReviewNote)
                .font(.callout)
                .foregroundStyle(BookPalette.ink.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .padding(12)
        .background(BookPalette.page.opacity(0.84), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func physicalBookReviewRow(_ title: String, _ value: String, systemImage: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: systemImage)
                .font(.callout.weight(.bold))
                .foregroundStyle(BookPalette.violet)
                .frame(width: 18)
            Text(title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(BookPalette.ink.opacity(0.74))
            Spacer(minLength: 8)
            Text(value)
                .font(.callout.weight(.bold))
                .foregroundStyle(BookPalette.ink)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func physicalBookStudioCheckoutPanel(edition: MonthlyEdition, spec: PrintSpec) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            subsectionLabel("Price & Delivery")
            physicalBookQuotePanel(edition: edition, spec: spec)
        }
        .padding(12)
        .background(BookPalette.page.opacity(0.84), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func physicalBookSubmissionPanel(edition: MonthlyEdition, spec: PrintSpec) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            subsectionLabel("Print Order")
            if let submittedPhysicalBookOrder {
                physicalBookReviewRow("Status", physicalBookOrderStatusText(submittedPhysicalBookOrder.status), systemImage: "shippingbox.fill")
                if let trackingURL = submittedPhysicalBookOrder.trackingURL {
                    Link(destination: trackingURL) {
                        Label("Open tracking", systemImage: "location.fill")
                            .font(.caption2.weight(.bold))
                    }
                }
                Button {
                    Task { await refreshSubmittedPhysicalBookOrderStatus() }
                } label: {
                    if isRefreshingPhysicalBookOrder {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Refresh status", systemImage: "arrow.clockwise")
                            .font(.caption2.weight(.bold))
                    }
                }
                .buttonStyle(.bordered)
                .tint(BookPalette.teal)
                .disabled(isRefreshingPhysicalBookOrder || submittedPhysicalBookOrder.luluPrintJobID == nil)
            } else {
                physicalBookCheckoutNotice(physicalBookSubmissionReadinessText, systemImage: physicalBookSubmissionReady ? "checkmark.seal" : "hourglass")
                physicalBookThirdPartyDisclosure

                Button {
                    Task { await uploadPhysicalBookPrintFiles(edition: edition) }
                } label: {
                    if isUploadingPhysicalBookPrintFiles {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Upload proofs", systemImage: "icloud.and.arrow.up")
                            .font(.callout.weight(.bold))
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(BookPalette.teal)
                .disabled(!canUploadPhysicalBookPrintFiles || isUploadingPhysicalBookPrintFiles)

                physicalBookHostedProofLinks()
                #if DEBUG
                physicalBookAdvancedFileLinks()
                #endif

                HStack(spacing: 8) {
                    Button {
                        Task { await submitPhysicalBookOrder(previewOnly: true, edition: edition, spec: spec) }
                    } label: {
                        if isSubmittingPhysicalBookOrder {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Preview order", systemImage: "doc.text.magnifyingglass")
                                .font(.callout.weight(.bold))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(BookPalette.violet)
                    .disabled(!physicalBookSubmissionReady || isSubmittingPhysicalBookOrder)

                    Button {
                        Task { await submitPhysicalBookOrder(previewOnly: false, edition: edition, spec: spec) }
                    } label: {
                        Label("Submit to Lulu", systemImage: "shippingbox")
                            .font(.callout.weight(.bold))
                    }
                    .buttonStyle(.bordered)
                    .tint(BookPalette.violet)
                    .disabled(!physicalBookSubmissionReady || isSubmittingPhysicalBookOrder)
                }

                if let physicalBookSubmissionMessage {
                    Text(physicalBookSubmissionMessage)
                        .font(.callout)
                        .foregroundStyle(BookPalette.ink.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(12)
        .background(BookPalette.page.opacity(0.84), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var physicalBookThirdPartyDisclosure: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lock.shield")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(BookPalette.violet)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Printing leaves your device")
                        .font(.callout.weight(.bold))
                        .foregroundStyle(BookPalette.ink)
                    Text("To make a physical Book of You, the interior and cover PDFs are uploaded to ReEnchanted's print backend and shared with Lulu, our third-party print-on-demand provider. Payment is handled by Stripe.")
                        .font(.callout)
                        .foregroundStyle(BookPalette.ink.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Toggle(isOn: $physicalBookThirdPartyPrintConsent) {
                Text("I understand Lulu will receive the print files needed to make this book.")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(BookPalette.ink.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .toggleStyle(.switch)
            .tint(BookPalette.teal)
        }
        .padding(10)
        .background(BookPalette.violet.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private func physicalBookHostedProofLinks() -> some View {
        if let files = physicalBookHostedPrintFiles {
            VStack(alignment: .leading, spacing: 7) {
                Text("Uploaded proofs")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(BookPalette.ink)
                Text("These are the files Lulu will print. Open them once before submitting the order.")
                    .font(.callout)
                    .foregroundStyle(BookPalette.ink.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Link(destination: files.interiorSourceURL) {
                        Label("Open interior", systemImage: "doc.text.magnifyingglass")
                            .font(.callout.weight(.bold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(BookPalette.teal)

                    Link(destination: files.coverSourceURL) {
                        Label("Open cover", systemImage: "book.closed")
                            .font(.callout.weight(.bold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(BookPalette.teal)
                }
            }
            .padding(10)
            .background(BookPalette.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(BookPalette.teal.opacity(0.2), lineWidth: 1)
            }
        }
    }

    @ViewBuilder
    private func physicalBookAdvancedFileLinks() -> some View {
        DisclosureGroup(isExpanded: $showPhysicalBookAdvancedFileLinks) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Only use this if upload fails and you need to paste public PDF links manually.")
                    .font(.caption)
                    .foregroundStyle(BookPalette.ink.opacity(0.64))
                    .fixedSize(horizontal: false, vertical: true)
                TextField("Interior PDF link", text: $hostedPhysicalBookInteriorURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                TextField("Cover PDF link", text: $hostedPhysicalBookCoverURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.top, 6)
        } label: {
            Label("Advanced file links", systemImage: "slider.horizontal.3")
                .font(.caption.weight(.bold))
                .foregroundStyle(BookPalette.violet)
        }
        .tint(BookPalette.violet)
    }

    private func selectPhysicalBookVariant(_ index: Int) {
        guard selectedPrintVariantIndex != index else { return }
        selectedPrintVariantIndex = index
        physicalBookQuote = nil
        physicalBookQuoteMessage = nil
        selectedPhysicalBookShippingOptionID = nil
        resetPreparedPhysicalBookCheckout()
    }

    private func physicalBookVariantMood(for spec: PrintSpec) -> String {
        spec.coverTreatment == .linenWrap
            ? "Navy cloth, gold foil, heirloom shelf presence."
            : "Full illustrated wrap, storybook color, more expressive at a glance."
    }

    private func physicalBookShelfEstimateLine(spec: PrintSpec) -> String {
        let value = spec.basePriceUSD + (spec.perPagePriceUSD * Decimal(24))
        return NSDecimalNumber(decimal: value).doubleValue.formatted(.currency(code: "USD"))
    }

    private func physicalBookEstimatedPriceLine(edition: MonthlyEdition, spec: PrintSpec) -> String {
        let pageCount = PrintGeometry.boundPageCount(rawPages: max(edition.pageCount, 24), spec: spec)
        let request = PhysicalBookQuoteRequest(
            editionID: BookThemeEngine.monthKey(for: edition.startDate),
            variant: .from(spec),
            pageCount: pageCount,
            shipTo: PhysicalBookShippingDestination(countryCode: "US", stateCode: nil, postalCode: "00000")
        )
        let price = PhysicalBookPricing.priceBreakdown(request: request, shippingCents: 0)
        return "Starts around \(Self.dollars(price.total)) before shipping/tax."
    }

    private var physicalBookPrintFilesReady: Bool {
        preparedPrintInteriorURL != nil && preparedPrintCoverURL != nil
    }

    private var physicalBookPrintFilesTaskID: String {
        "\(preparedPrintInteriorURL?.absoluteString ?? "missing-interior")|\(preparedPrintCoverURL?.absoluteString ?? "missing-cover")"
    }

    private var physicalBookQuoteReadinessText: String {
        if physicalBookQuote != nil {
            return "Live price selected"
        }
        if !PhysicalBookQuoteClient.isQuoteServiceConfigured {
            return "Live pricing not connected yet"
        }
        return "Enter delivery ZIP"
    }

    private var physicalBookSelectedShippingOption: PhysicalBookShippingOption? {
        guard let physicalBookQuote,
              let selectedID = selectedPhysicalBookShippingOptionID else {
            return nil
        }
        return physicalBookQuote.shippingOptions.first(where: { $0.id == selectedID })
    }

    private var physicalBookSelectedTotalText: String {
        guard let physicalBookQuote,
              let selectedOption = physicalBookSelectedShippingOption else {
            return "Get price first"
        }
        let total = PhysicalBookPricing.priceBreakdown(
            request: physicalBookQuote.request,
            shippingCents: selectedOption.price.cents,
            policy: physicalBookQuote.pricingPolicy
        ).total
        return Self.dollars(total)
    }

    private var physicalBookShipToReviewText: String {
        guard let address = physicalBookShippingAddress else {
            return "Add shipping address"
        }
        let state = address.stateCode.map { ", \($0)" } ?? ""
        return "\(address.city)\(state) \(address.postalCode)"
    }

    private var physicalBookReviewNote: String {
        if !physicalBookPrintFilesReady {
            return "Checkout stays locked until the interior and cover PDFs are made for this binding."
        }
        if !PhysicalBookQuoteClient.isQuoteServiceConfigured {
            return "Live pricing is not connected yet. Add the quote endpoint before taking payment."
        }
        if physicalBookPaymentSheet == nil {
            return "Payment can be prepared after live price, delivery, and receipt details are complete."
        }
        return "Payment is secure. Final print submission still waits on PDF proofing and Lulu API access."
    }

    private func physicalBookQuotePanel(edition: MonthlyEdition, spec: PrintSpec) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !physicalBookPrintFilesReady {
                physicalBookCheckoutNotice("Make print PDFs first. Checkout will unlock after the interior and cover files exist.", systemImage: "doc.badge.plus")
            } else if !PhysicalBookQuoteClient.isQuoteServiceConfigured {
                physicalBookCheckoutNotice("Live pricing is not connected yet. Add the quote endpoint before preparing checkout.", systemImage: "network.badge.shield.half.filled")
            }

            physicalBookShippingForm

            Button {
                Task { await loadPhysicalBookQuote(edition: edition, spec: spec) }
            } label: {
                if isLoadingPhysicalBookQuote {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("Get price", systemImage: "truck.box")
                        .font(.callout.weight(.bold))
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(BookPalette.violet)
            .disabled(isLoadingPhysicalBookQuote || physicalBookShippingAddress == nil)

            if physicalBookShippingAddress == nil {
                Text("Add the delivery address first so Lulu can calculate the real print and shipping price.")
                    .font(.callout)
                    .foregroundStyle(BookPalette.ink.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let physicalBookQuoteMessage {
                Text(physicalBookQuoteMessage)
                    .font(.caption2)
                    .foregroundStyle(BookPalette.ink.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let physicalBookQuote {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(physicalBookQuote.shippingOptions) { option in
                        let total = PhysicalBookPricing.priceBreakdown(
                            request: physicalBookQuote.request,
                            shippingCents: option.price.cents,
                            policy: physicalBookQuote.pricingPolicy
                        ).total
                        Button {
                            selectedPhysicalBookShippingOptionID = option.id
                            physicalBookPaymentIntent = nil
                            physicalBookCheckoutMessage = nil
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Image(systemName: selectedPhysicalBookShippingOptionID == option.id ? "checkmark.circle.fill" : "circle")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(BookPalette.violet)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(option.displayName)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(BookPalette.ink)
                                    Text("\(option.estimatedDaysMin)-\(option.estimatedDaysMax) business days")
                                        .font(.caption2)
                                        .foregroundStyle(BookPalette.ink.opacity(0.56))
                                }
                                Spacer(minLength: 8)
                                Text(Self.dollars(total))
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(BookPalette.violet)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(8)
                        .background(
                            (selectedPhysicalBookShippingOptionID == option.id ? BookPalette.violet.opacity(0.14) : BookPalette.violet.opacity(0.08)),
                            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                        )
                    }
                    Button {
                        Task { await preparePhysicalBookCheckout() }
                    } label: {
                        if isPreparingPhysicalBookCheckout {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Prepare checkout", systemImage: "creditcard")
                                .font(.caption2.weight(.bold))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(BookPalette.violet)
                    .disabled(!canPreparePhysicalBookCheckout || isPreparingPhysicalBookCheckout)

                    if physicalBookPaymentSheet != nil {
                        Button {
                            presentPhysicalBookPaymentSheet()
                        } label: {
                            Label("Pay securely", systemImage: "lock.fill")
                                .font(.caption2.weight(.bold))
                        }
                        .buttonStyle(.bordered)
                        .tint(BookPalette.violet)
                    }

                    if let physicalBookCheckoutMessage {
                        Text(physicalBookCheckoutMessage)
                            .font(.caption2)
                            .foregroundStyle(BookPalette.ink.opacity(0.62))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .onChange(of: selectedPrintVariantIndex) { _, _ in
            physicalBookQuote = nil
            physicalBookQuoteMessage = nil
            selectedPhysicalBookShippingOptionID = nil
            resetPreparedPhysicalBookCheckout()
        }
        .onChange(of: physicalBookShippingFingerprint) { _, _ in
            physicalBookQuote = nil
            physicalBookQuoteMessage = nil
            selectedPhysicalBookShippingOptionID = nil
            resetPreparedPhysicalBookCheckout()
        }
    }

    private func physicalBookCheckoutNotice(_ text: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .font(.callout.weight(.bold))
                .foregroundStyle(BookPalette.violet)
            Text(text)
                .font(.callout)
                .foregroundStyle(BookPalette.ink.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(9)
        .background(BookPalette.violet.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var physicalBookShippingForm: some View {
        VStack(alignment: .leading, spacing: 6) {
            subsectionLabel("Ship To")
            TextField("Name", text: $physicalBookRecipientName)
                .textContentType(.name)
                .textFieldStyle(.roundedBorder)
            TextField("Street address", text: $physicalBookStreet1)
                .textContentType(.streetAddressLine1)
                .textFieldStyle(.roundedBorder)
            TextField("Apt, suite, etc. (optional)", text: $physicalBookStreet2)
                .textContentType(.streetAddressLine2)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 6) {
                TextField("City", text: $physicalBookCity)
                    .textContentType(.addressCity)
                    .textFieldStyle(.roundedBorder)
                TextField("State", text: $physicalBookShippingStateCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .textContentType(.addressState)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 74)
                TextField("ZIP", text: $physicalBookShippingPostalCode)
                    .keyboardType(.numbersAndPunctuation)
                    .textContentType(.postalCode)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 96)
            }

            HStack(spacing: 6) {
                TextField("Country", text: $physicalBookShippingCountryCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .textContentType(.countryName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 96)
                TextField("Phone", text: $physicalBookPhoneNumber)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .textFieldStyle(.roundedBorder)
            }

            TextField("Email for receipt", text: $physicalBookContactEmail)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
        }
    }

    private var canPreparePhysicalBookCheckout: Bool {
        physicalBookPrintFilesReady &&
            physicalBookQuote != nil &&
            selectedPhysicalBookShippingOptionID != nil &&
            physicalBookShippingAddress != nil &&
            physicalBookContactEmail.trimmingCharacters(in: .whitespacesAndNewlines).contains("@")
    }

    private var physicalBookSubmissionReady: Bool {
        pendingPhysicalBookOrder != nil &&
            physicalBookPrintFileChecksums != nil &&
            physicalBookHostedPrintFiles != nil &&
            currentPhysicalBookOrderQuoteRequest != nil &&
            physicalBookThirdPartyPrintConsent &&
            PhysicalBookQuoteClient.isQuoteServiceConfigured
    }

    private var canUploadPhysicalBookPrintFiles: Bool {
        preparedPrintInteriorURL != nil &&
            preparedPrintCoverURL != nil &&
            physicalBookPrintFileChecksums != nil &&
            physicalBookThirdPartyPrintConsent &&
            PhysicalBookQuoteClient.isQuoteServiceConfigured
    }

    private var physicalBookSubmissionReadinessText: String {
        if pendingPhysicalBookOrder == nil {
            return "Checkout creates a saved order before final print submission unlocks."
        }
        if !physicalBookThirdPartyPrintConsent {
            return "Confirm that Lulu will receive the print files before upload or final submission."
        }
        if currentPhysicalBookOrderQuoteRequest == nil {
            return "This paid order needs its original live quote. Get a fresh quote if this was saved before the latest order handoff."
        }
        if physicalBookPrintFileChecksums == nil {
            return "Make print PDFs first so the interior and cover proofs are ready."
        }
        if physicalBookHostedPrintFiles == nil {
            return "Upload the print PDFs so the printer can fetch the interior and cover proofs."
        }
        if !PhysicalBookQuoteClient.isQuoteServiceConfigured {
            return "Connect the physical book service before previewing or submitting the print order."
        }
        return "Ready to preview the print order. Live submit will work once Lulu credentials are active on the backend."
    }

    private var physicalBookHostedPrintFiles: PhysicalBookPrintFiles? {
        guard let checksums = physicalBookPrintFileChecksums,
              let interiorURL = URL(string: hostedPhysicalBookInteriorURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              let coverURL = URL(string: hostedPhysicalBookCoverURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["https", "http"].contains(interiorURL.scheme?.lowercased()),
              ["https", "http"].contains(coverURL.scheme?.lowercased()) else {
            return nil
        }
        return PhysicalBookPrintFiles(
            interiorSourceURL: interiorURL,
            interiorMD5: checksums.interiorMD5,
            coverSourceURL: coverURL,
            coverMD5: checksums.coverMD5
        )
    }

    private var currentPhysicalBookOrderQuoteRequest: PhysicalBookQuoteRequest? {
        pendingPhysicalBookOrder?.quoteRequest ?? physicalBookQuote?.request
    }

    private var physicalBookShippingAddress: PhysicalBookShippingAddress? {
        let name = physicalBookRecipientName.trimmingCharacters(in: .whitespacesAndNewlines)
        let street1 = physicalBookStreet1.trimmingCharacters(in: .whitespacesAndNewlines)
        let street2 = physicalBookStreet2.trimmingCharacters(in: .whitespacesAndNewlines)
        let city = physicalBookCity.trimmingCharacters(in: .whitespacesAndNewlines)
        let stateCode = physicalBookShippingStateCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let countryCode = physicalBookShippingCountryCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let postalCode = physicalBookShippingPostalCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let phoneNumber = physicalBookPhoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty,
              !street1.isEmpty,
              !city.isEmpty,
              !countryCode.isEmpty,
              !postalCode.isEmpty,
              !phoneNumber.isEmpty else {
            return nil
        }

        return PhysicalBookShippingAddress(
            name: name,
            street1: street1,
            street2: street2.isEmpty ? nil : street2,
            city: city,
            stateCode: stateCode.isEmpty ? nil : stateCode,
            countryCode: countryCode,
            postalCode: postalCode,
            phoneNumber: phoneNumber
        )
    }

    private var physicalBookShippingFingerprint: String {
        [
            physicalBookContactEmail,
            physicalBookRecipientName,
            physicalBookStreet1,
            physicalBookStreet2,
            physicalBookCity,
            physicalBookShippingStateCode,
            physicalBookShippingPostalCode,
            physicalBookShippingCountryCode,
            physicalBookPhoneNumber
        ].joined(separator: "|")
    }

    private func resetPreparedPhysicalBookCheckout() {
        physicalBookPaymentIntent = nil
        physicalBookPaymentSheet = nil
        physicalBookCheckoutMessage = nil
        physicalBookSubmissionMessage = nil
        submittedPhysicalBookOrder = nil
    }

    @MainActor
    private func loadPhysicalBookQuote(edition: MonthlyEdition, spec: PrintSpec) async {
        guard let address = physicalBookShippingAddress else {
            physicalBookQuoteMessage = "Add the delivery address first."
            return
        }
        let pageCount = PrintGeometry.boundPageCount(rawPages: max(edition.pageCount, 24), spec: spec)
        let request = PhysicalBookQuoteRequest(
            editionID: BookThemeEngine.monthKey(for: edition.startDate),
            variant: .from(spec),
            pageCount: pageCount,
            shipTo: PhysicalBookShippingDestination(
                countryCode: address.countryCode,
                stateCode: address.stateCode,
                postalCode: address.postalCode,
                city: address.city,
                street1: address.street1,
                street2: address.street2,
                phoneNumber: address.phoneNumber
            )
        )

        isLoadingPhysicalBookQuote = true
        physicalBookQuoteMessage = "Asking the print desk for live shipping..."
        defer { isLoadingPhysicalBookQuote = false }

        do {
            let quote = try await PhysicalBookQuoteClient().quote(request)
            physicalBookQuote = quote
            selectedPhysicalBookShippingOptionID = quote.shippingOptions.first?.id
            resetPreparedPhysicalBookCheckout()
            physicalBookQuoteMessage = "Live quote expires \(quote.expiresAt.formatted(date: .abbreviated, time: .shortened))."
        } catch PhysicalBookQuoteClient.ConfigurationError.missingEndpoint {
            physicalBookQuote = nil
            physicalBookQuoteMessage = "Quote service is not configured yet. Add a PhysicalBookQuoteEndpointURL Info.plist value or set the physicalBookQuoteEndpointURL user default."
        } catch {
            physicalBookQuote = nil
            physicalBookQuoteMessage = "Could not fetch a live quote yet: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func preparePhysicalBookCheckout() async {
        guard let physicalBookQuote,
              let selectedID = selectedPhysicalBookShippingOptionID,
              let selectedOption = physicalBookQuote.shippingOptions.first(where: { $0.id == selectedID }) else {
            return
        }
        let email = physicalBookContactEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard email.contains("@"), physicalBookShippingAddress != nil else { return }

        isPreparingPhysicalBookCheckout = true
        physicalBookCheckoutMessage = "Preparing a secure checkout..."
        defer { isPreparingPhysicalBookCheckout = false }

        do {
            let request = PhysicalBookPaymentIntentRequest(
                quoteID: physicalBookQuote.id,
                quoteRequest: physicalBookQuote.request,
                selectedShippingOption: selectedOption,
                contactEmail: email
            )
            let intent = try await PhysicalBookQuoteClient().paymentIntent(request)
            physicalBookPaymentIntent = intent
            physicalBookPaymentSheet = try makePhysicalBookPaymentSheet(for: intent)
            physicalBookCheckoutMessage = "Checkout is ready for \(Self.dollars(intent.amount))."
        } catch PhysicalBookQuoteClient.ConfigurationError.missingEndpoint {
            physicalBookPaymentIntent = nil
            physicalBookPaymentSheet = nil
            physicalBookCheckoutMessage = "Quote service is not configured yet, so checkout cannot be prepared."
        } catch PhysicalBookQuoteClient.ConfigurationError.missingStripePublishableKey {
            physicalBookPaymentIntent = nil
            physicalBookPaymentSheet = nil
            physicalBookCheckoutMessage = "Stripe publishable key is not configured yet. Add StripePublishableKey to Info.plist or the stripePublishableKey user default."
        } catch {
            physicalBookPaymentIntent = nil
            physicalBookPaymentSheet = nil
            physicalBookCheckoutMessage = "Could not prepare checkout yet: \(error.localizedDescription)"
        }
    }

    private func makePhysicalBookPaymentSheet(for intent: PhysicalBookPaymentIntent) throws -> PaymentSheet {
        let publishableKey = try PhysicalBookQuoteClient.configuredStripePublishableKey()
        STPAPIClient.shared.publishableKey = publishableKey

        var configuration = PaymentSheet.Configuration()
        configuration.merchantDisplayName = "ReEnchanted"
        configuration.allowsDelayedPaymentMethods = false
        return PaymentSheet(paymentIntentClientSecret: intent.clientSecret, configuration: configuration)
    }

    private func presentPhysicalBookPaymentSheet() {
        guard let physicalBookPaymentSheet,
              let presenter = UIApplication.shared.reenchantedTopViewController() else {
            physicalBookCheckoutMessage = "Could not open secure checkout yet."
            return
        }

        physicalBookPaymentSheet.present(from: presenter) { result in
            Task { @MainActor in
                switch result {
                case .completed:
                    savePendingPhysicalBookOrderDraft()
                case .canceled:
                    physicalBookCheckoutMessage = "Checkout was cancelled. Nothing was charged."
                case .failed(let error):
                    physicalBookCheckoutMessage = "Payment failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func loadPendingPhysicalBookOrder(edition: MonthlyEdition, spec: PrintSpec) {
        pendingPhysicalBookOrder = PhysicalBookPendingOrderStore.pendingOrder(
            editionID: BookThemeEngine.monthKey(for: edition.startDate),
            variantID: PhysicalBookVariant.from(spec).id
        )
        submittedPhysicalBookOrder = pendingPhysicalBookOrder?.submittedOrder
    }

    private func loadPhysicalBookPrintFileChecksums() {
        guard let preparedPrintInteriorURL,
              let preparedPrintCoverURL else {
            physicalBookPrintFileChecksums = nil
            return
        }

        do {
            physicalBookPrintFileChecksums = PhysicalBookPrintFileChecksums(
                interiorMD5: try Self.md5Hex(for: preparedPrintInteriorURL),
                coverMD5: try Self.md5Hex(for: preparedPrintCoverURL)
            )
        } catch {
            physicalBookPrintFileChecksums = nil
            physicalBookCheckoutMessage = "Print files are ready, but checksums could not be read yet: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func uploadPhysicalBookPrintFiles(edition: MonthlyEdition) async {
        guard physicalBookThirdPartyPrintConsent else {
            physicalBookSubmissionMessage = "Confirm that Lulu will receive the print files before uploading proofs."
            return
        }
        guard let preparedPrintInteriorURL,
              let preparedPrintCoverURL,
              let checksums = physicalBookPrintFileChecksums else {
            physicalBookSubmissionMessage = "Make print PDFs first, then upload them."
            return
        }

        isUploadingPhysicalBookPrintFiles = true
        physicalBookSubmissionMessage = "Uploading print PDFs..."
        defer { isUploadingPhysicalBookPrintFiles = false }

        do {
            let client = PhysicalBookQuoteClient()
            let editionID = BookThemeEngine.monthKey(for: edition.startDate)
            let interior = try await client.uploadPrintFile(
                kind: .interior,
                fileURL: preparedPrintInteriorURL,
                editionID: editionID,
                md5: checksums.interiorMD5
            )
            let cover = try await client.uploadPrintFile(
                kind: .cover,
                fileURL: preparedPrintCoverURL,
                editionID: editionID,
                md5: checksums.coverMD5
            )
            hostedPhysicalBookInteriorURL = interior.sourceURL.absoluteString
            hostedPhysicalBookCoverURL = cover.sourceURL.absoluteString
            physicalBookSubmissionMessage = "Print PDFs uploaded. Open the proofs, then preview the print order."
        } catch PhysicalBookQuoteClient.ConfigurationError.missingEndpoint {
            physicalBookSubmissionMessage = "Physical book backend is not configured yet."
        } catch {
            physicalBookSubmissionMessage = "Could not upload print PDFs yet: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func submitPhysicalBookOrder(previewOnly: Bool, edition: MonthlyEdition, spec: PrintSpec) async {
        guard physicalBookThirdPartyPrintConsent else {
            physicalBookSubmissionMessage = "Confirm that Lulu will receive the print files before submitting the order."
            return
        }
        guard let orderRequest = makePhysicalBookOrderRequest() else {
            physicalBookSubmissionMessage = physicalBookSubmissionReadinessText
            return
        }

        isSubmittingPhysicalBookOrder = true
        physicalBookSubmissionMessage = previewOnly ? "Preparing print order preview..." : "Submitting to Lulu..."
        defer { isSubmittingPhysicalBookOrder = false }

        do {
            if previewOnly {
                let preview = try await PhysicalBookQuoteClient().previewOrder(orderRequest)
                let packageID = preview.luluPrintJobPayload.lineItems.first?.podPackageID ?? orderRequest.quoteRequest.variant.luluPackageID
                physicalBookSubmissionMessage = "Preview ready: \(preview.luluPrintJobPayload.shippingLevel) shipping, package \(packageID), \(preview.luluPrintJobPayload.lineItems.count) line item."
            } else {
                let order = try await PhysicalBookQuoteClient().createOrder(orderRequest)
                submittedPhysicalBookOrder = order
                saveSubmittedPhysicalBookOrder(order)
                physicalBookSubmissionMessage = "Submitted to Lulu. Status: \(physicalBookOrderStatusText(order.status))."
            }
        } catch PhysicalBookQuoteClient.ConfigurationError.missingEndpoint {
            physicalBookSubmissionMessage = "Physical book backend is not configured yet."
        } catch {
            physicalBookSubmissionMessage = previewOnly
                ? "Could not preview the print order yet: \(error.localizedDescription)"
                : "Could not submit to Lulu yet: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func refreshSubmittedPhysicalBookOrderStatus() async {
        guard let submittedPhysicalBookOrder,
              let luluPrintJobID = submittedPhysicalBookOrder.luluPrintJobID else {
            physicalBookSubmissionMessage = "Submit to Lulu first, then the order can refresh from Lulu's status endpoint."
            return
        }

        isRefreshingPhysicalBookOrder = true
        defer { isRefreshingPhysicalBookOrder = false }

        do {
            let order = try await PhysicalBookQuoteClient().orderStatus(luluPrintJobID: luluPrintJobID)
            self.submittedPhysicalBookOrder = order
            saveSubmittedPhysicalBookOrder(order)
            physicalBookSubmissionMessage = "Status refreshed: \(physicalBookOrderStatusText(order.status))."
        } catch PhysicalBookQuoteClient.ConfigurationError.missingEndpoint {
            physicalBookSubmissionMessage = "Could not refresh status yet: physical book backend URL is not configured."
        } catch {
            physicalBookSubmissionMessage = "Could not refresh status yet: \(error.localizedDescription)"
        }
    }

    private func makePhysicalBookOrderRequest() -> PhysicalBookOrderRequest? {
        guard let pendingPhysicalBookOrder,
              let quoteRequest = currentPhysicalBookOrderQuoteRequest,
              let printFiles = physicalBookHostedPrintFiles else {
            return nil
        }

        return PhysicalBookOrderRequest(
            quoteID: pendingPhysicalBookOrder.quoteID,
            quoteRequest: quoteRequest,
            paymentIntentID: pendingPhysicalBookOrder.paymentIntentID,
            contactEmail: pendingPhysicalBookOrder.contactEmail,
            shippingAddress: pendingPhysicalBookOrder.shippingAddress,
            selectedShippingOptionID: pendingPhysicalBookOrder.selectedShippingOptionID,
            selectedShippingOption: pendingPhysicalBookOrder.selectedShippingOption,
            printFiles: printFiles
        )
    }

    private func saveSubmittedPhysicalBookOrder(_ order: PhysicalBookOrder) {
        guard var pendingPhysicalBookOrder else { return }
        pendingPhysicalBookOrder.status = .submittedToBackend
        pendingPhysicalBookOrder.submittedOrder = order
        pendingPhysicalBookOrder.updatedAt = Date()
        self.pendingPhysicalBookOrder = pendingPhysicalBookOrder
        try? PhysicalBookPendingOrderStore.upsert(pendingPhysicalBookOrder)
    }

    private func savePendingPhysicalBookOrderDraft() {
        guard var draft = makePendingPhysicalBookOrderDraft() else {
            physicalBookCheckoutMessage = "Payment received, but the pending order could not be saved locally."
            return
        }
        draft.updatedAt = Date()
        do {
            try PhysicalBookPendingOrderStore.upsert(draft)
            pendingPhysicalBookOrder = draft
            physicalBookCheckoutMessage = "Payment received. Your print order is saved locally and pending Lulu submission."
        } catch {
            pendingPhysicalBookOrder = draft
            physicalBookCheckoutMessage = "Payment received, but the pending order could not be saved locally: \(error.localizedDescription)"
        }
    }

    private func makePendingPhysicalBookOrderDraft() -> PhysicalBookPendingOrderDraft? {
        guard let physicalBookQuote,
              let physicalBookPaymentIntent,
              let selectedPhysicalBookShippingOptionID,
              let selectedPhysicalBookShippingOption = physicalBookSelectedShippingOption,
              let physicalBookShippingAddress else {
            return nil
        }

        return PhysicalBookPendingOrderDraft(
            id: physicalBookPaymentIntent.id,
            editionID: physicalBookQuote.request.editionID,
            quoteID: physicalBookQuote.id,
            quoteRequest: physicalBookQuote.request,
            paymentIntentID: physicalBookPaymentIntent.id,
            contactEmail: physicalBookContactEmail.trimmingCharacters(in: .whitespacesAndNewlines),
            shippingAddress: physicalBookShippingAddress,
            selectedShippingOptionID: selectedPhysicalBookShippingOptionID,
            selectedShippingOption: selectedPhysicalBookShippingOption,
            variant: physicalBookQuote.request.variant,
            amount: physicalBookPaymentIntent.amount,
            status: .submissionWaitingForLuluCredentials
        )
    }

    private static func dollars(_ amount: MoneyAmount) -> String {
        let value = Decimal(amount.cents) / 100
        return value.formatted(.currency(code: amount.currencyCode))
    }

    private static func md5Hex(for url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let digest = Insecure.MD5.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// The reader's standing with the Book Fae — folded in from the old Margin:
    /// open debts, gifts in hand, and warmth by species.
    private var standingSection: some View {
        let debts = fae.bargains.filter { $0.status != .delivered }
        return VStack(alignment: .leading, spacing: 8) {
            shelfHeader("Your Standing With the Fae")
            if !debts.isEmpty {
                ForEach(debts) { bargain in
                    Button {
                        BookFeedback.play(.openPage)
                        onOpenBargain(bargain)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Label(bargain.faeKind.name, systemImage: bargain.faeKind.symbolName)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(bargain.status == .lapsed ? BookPalette.ink.opacity(0.5) : BookPalette.ink)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(BookPalette.teal.opacity(0.7))
                            }
                            Text(bargain.status == .lapsed
                                 ? "Lapsed — \(bargain.giftName) has gone cold. Tap to repair."
                                 : "Owed: \(bargain.terms)")
                                .font(.caption2)
                                .foregroundStyle(bargain.status == .lapsed ? BookPalette.ink.opacity(0.5) : BookPalette.teal)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(BookPalette.page.opacity(0.85), in: RoundedRectangle(cornerRadius: 8))
                        .overlay { RoundedRectangle(cornerRadius: 8).stroke(BookPalette.teal.opacity(0.3), lineWidth: 1) }
                    }
                    .buttonStyle(.bookPress())
                }
            }
            if fae.gifts.isEmpty {
                Text("No gifts yet — the Fae give first, unprompted. Keep your pages and one will find you.")
                    .font(.caption)
                    .foregroundStyle(BookPalette.ink.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(fae.gifts) { gift in FaeGiftCard(gift: gift, now: Date()) }
            }
            VStack(spacing: 6) {
                ForEach(FaeKind.allCases) { kind in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Label(kind.name, systemImage: kind.symbolName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BookPalette.ink.opacity(0.85))
                            Spacer()
                            Text("\(fae.warmth(for: kind)) Warmth")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(fae.warmth(for: kind) > 0 ? BookPalette.lampGold : BookPalette.ink.opacity(0.5))
                        }
                        HStack(spacing: 8) {
                            Text("Claim \(fae.claim(for: kind))")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(fae.claim(for: kind) >= FaeEconomy.unseelieClaimThreshold ? BookPalette.violet : BookPalette.teal)
                            Text(FaeEconomy.claimBand(for: fae.claim(for: kind)).capitalized)
                                .font(.caption2)
                                .foregroundStyle(BookPalette.ink.opacity(0.55))
                            if kind == .literaryElf {
                                Text("· \(fae.literaryElfCourt().title)")
                                    .font(.caption2)
                                    .foregroundStyle(BookPalette.ink.opacity(0.55))
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(12)
            .background(BookPalette.page.opacity(0.85), in: RoundedRectangle(cornerRadius: 8))
            .overlay { RoundedRectangle(cornerRadius: 8).stroke(BookPalette.ink.opacity(0.12), lineWidth: 1) }
        }
    }

    private func shelfHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption.weight(.black))
            .kerning(1.2)
            .foregroundStyle(BookPalette.nightText.opacity(0.7))
            .padding(.top, 4)
    }

    private func wareCard(_ ware: MarketWare, rare: Bool = false) -> some View {
        let basePrice = GoblinMarketEngine.price(ware, mood: stall.mood, goblinWarmth: goblinWarmth)
        let price = max(1, basePrice - (haggleDiscounts[ware.id] ?? 0))
        let canAfford = ware.currency == .attention ? liveAttention >= price : liveBelief >= price
        let accent = rare ? BookPalette.violet : (ware.currency == .attention ? BookPalette.teal : BookPalette.lampGold)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(accent.opacity(0.18))
                    Image(systemName: ware.currency == .attention ? "eye.fill" : "sparkles")
                        .font(.headline.weight(.black))
                        .foregroundStyle(accent)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text(ware.title)
                        .font(.system(.headline, design: .serif, weight: .bold))
                        .foregroundStyle(BookPalette.ink)
                    Text(rare ? "UNDER-COUNTER WARE" : ware.currency.label.uppercased())
                        .font(.caption2.weight(.black))
                        .kerning(0.8)
                        .foregroundStyle(accent.opacity(0.85))
                }
                Spacer()
                priceTag("\(price)", label: ware.currency.label, tint: accent)
            }
            Text("\u{201C}\(ware.clerkPitch)\u{201D}")
                .font(.system(.caption, design: .serif).italic())
                .foregroundStyle(BookPalette.ink.opacity(0.66))
                .fixedSize(horizontal: false, vertical: true)
            Text(ware.contents)
                .font(.caption)
                .foregroundStyle(BookPalette.ink.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
            Button {
                guard canAfford else {
                    clerkLine = "The clerk taps the price twice. \u{201C}Come back with more \(ware.currency.label).\u{201D}"
                    BookFeedback.play(.error)
                    return
                }
                onBuyWare(ware)
                if ware.currency == .attention { spentAttention += price } else { spentBelief += price }
                boughtWareIDs.insert(ware.id)
                clerkLine = "The clerk wraps \(ware.title) in waxed paper. \u{201C}Bound to you. Mind how you spend it.\u{201D}"
                BookFeedback.play(.braidComplete)
            } label: {
                Label(canAfford ? "Spend \(price) \(ware.currency.label)" : "Need \(price) \(ware.currency.label)",
                      systemImage: ware.currency == .attention ? "eye" : "sparkles")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
            .opacity(canAfford ? 1 : 0.55)

            if goblinWarmth > 0, !haggledWareIDs.contains(ware.id) {
                Button {
                    haggledWareIDs.insert(ware.id)
                    if let cut = onHaggle(ware), cut > 0 {
                        haggleDiscounts[ware.id] = cut
                        clerkLine = "The clerk sucks a tooth, then knocks \(cut) off \(ware.title). \u{201C}For you. Once.\u{201D}"
                        BookFeedback.play(.select)
                    } else {
                        clerkLine = "The clerk waves you off. \u{201C}Not today.\u{201D} Your warmth is spent on the asking."
                        BookFeedback.play(.error)
                    }
                } label: {
                    Label("Haggle — spend 1 Warmth", systemImage: "hand.wave")
                        .font(.caption2.weight(.bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(BookPalette.ink.opacity(0.5))
            }
        }
        .padding(13)
        .background(
            LinearGradient(
                colors: [BookPalette.page.opacity(0.98), BookPalette.paper.opacity(0.88)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(accent.opacity(rare ? 0.5 : 0.18), lineWidth: 1)
        }
    }

    private func offerCard(_ offer: BookShopOffer) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(BookPalette.teal.opacity(0.16))
                    Image(systemName: offerSymbol(for: offer.listing))
                        .font(.headline.weight(.black))
                        .foregroundStyle(BookPalette.teal)
                }
                .frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 3) {
                    Text(offer.listing.title)
                        .font(.system(.headline, design: .serif, weight: .bold))
                        .foregroundStyle(BookPalette.ink)
                    Text(offerShelfLine(for: offer.listing).uppercased())
                        .font(.caption2.weight(.black))
                        .kerning(0.8)
                        .foregroundStyle(BookPalette.teal.opacity(0.82))
                }
                Spacer()
                priceTag(offer.displayPrice, label: nil, tint: BookPalette.teal)
            }
            Text("\u{201C}\(offer.listing.goblinPitch)\u{201D}")
                .font(.system(.caption, design: .serif).italic())
                .foregroundStyle(BookPalette.ink.opacity(0.66))
                .fixedSize(horizontal: false, vertical: true)
            Text(offer.listing.contents)
                .font(.caption)
                .foregroundStyle(BookPalette.ink.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
            Button {
                Task { await buy(offer) }
            } label: {
                Label(isPurchasing ? "Binding..." : "Bind it to my save", systemImage: "seal")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(BookPalette.teal)
            .disabled(isPurchasing || !offer.isPurchasable)
        }
        .padding(13)
        .background(
            LinearGradient(
                colors: [BookPalette.page.opacity(0.98), BookPalette.paper.opacity(0.86), BookPalette.teal.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.teal.opacity(0.24), lineWidth: 1)
        }
    }

    private func offerSymbol(for listing: BookShopListing) -> String {
        switch listing.family {
        case .soundPack: return "radio.fill"
        case .eventPack: return listing.resolvedSaleState == .liveEvent ? "sparkles.rectangle.stack.fill" : "archivebox.fill"
        default: return "shippingbox.fill"
        }
    }

    private func freePackCard(_ pack: PageArchetypePack) -> some View {
        let isBound = PackEntitlements.isUnlocked(pack.id) || boundFreePackIDs.contains(pack.id)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(BookPalette.lampGold.opacity(0.18))
                    Image(systemName: isBound ? "checkmark.seal.fill" : "gift.fill")
                        .font(.headline.weight(.black))
                        .foregroundStyle(BookPalette.lampGold)
                }
                .frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 3) {
                    Text(pack.displayName)
                        .font(.system(.headline, design: .serif, weight: .bold))
                        .foregroundStyle(BookPalette.ink)
                    Text(isBound ? "Bound to your save" : "Free gift")
                        .font(.caption2.weight(.black))
                        .kerning(0.8)
                        .foregroundStyle(BookPalette.lampGold.opacity(0.84))
                }
                Spacer()
                priceTag("$0", label: "gift", tint: BookPalette.lampGold)
            }
            Text("A gift folio of \(pack.archetypes.count) extra page shapes. Bind it here when you want the Book to start using it.")
                .font(.caption)
                .foregroundStyle(BookPalette.ink.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)
            Button {
                guard !isBound else { return }
                boundFreePackIDs.insert(pack.id)
                onUnlock(pack.id)
                clerkLine = "The clerk stamps the gift folio with theatrical reluctance. \"Free. Obviously suspicious. Enjoy it.\""
            } label: {
                Label(isBound ? "Already bound" : "Bind the free gift", systemImage: isBound ? "checkmark.seal.fill" : "seal")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(BookPalette.lampGold)
            .disabled(isBound)
        }
        .padding(13)
        .background(
            LinearGradient(
                colors: [BookPalette.page.opacity(0.98), BookPalette.paper.opacity(0.86), BookPalette.lampGold.opacity(0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.28), lineWidth: 1)
        }
    }

    private func offerShelfLine(for listing: BookShopListing) -> String {
        let family = listing.family.shelfLabel
        let state = listing.resolvedSaleState
        return state == .standard ? family : "\(family) · \(state.shelfLabel)"
    }

    private func priceTag(_ value: String, label: String?, tint: Color) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.caption.weight(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            if let label {
                Text(label.uppercased())
                    .font(.caption2.weight(.black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        }
    }

    private func boundCard(_ listing: BookShopListing) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(BookPalette.lampGold)
            VStack(alignment: .leading, spacing: 3) {
                Text(listing.title)
                    .font(.system(.subheadline, design: .serif, weight: .bold))
                    .foregroundStyle(BookPalette.ink)
                Text(listing.contents)
                    .font(.caption2)
                    .foregroundStyle(BookPalette.ink.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if listing.family == .eventPack {
                Button {
                    onOpenArchive(listing.packID)
                } label: {
                    Image(systemName: "archivebox.fill")
                        .font(.subheadline.weight(.bold))
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 7))
                .tint(BookPalette.lampGold)
                .accessibilityLabel("Open \(listing.title)")
            }
        }
        .padding(11)
        .background(BookPalette.lampGold.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func printingCard(_ listing: BookShopListing) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "hourglass")
                .foregroundStyle(BookPalette.teal.opacity(0.7))
            VStack(alignment: .leading, spacing: 3) {
                Text(listing.title)
                    .font(.system(.subheadline, design: .serif, weight: .bold))
                    .foregroundStyle(BookPalette.ink.opacity(0.8))
                Text("\u{201C}\(listing.goblinPitch)\u{201D}")
                    .font(.system(.caption2, design: .serif).italic())
                    .foregroundStyle(BookPalette.ink.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(11)
        .background(BookPalette.page.opacity(0.7), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func buy(_ offer: BookShopOffer) async {
        guard !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        let merchant = await BookShopTill.resolveMerchant()
        switch await merchant.purchase(productID: offer.id) {
        case .bound:
            onUnlock(offer.listing.packID)
            clerkLine = "The clerk stamps the ledger twice. \u{201C}\(offer.listing.title) is bound to you. No refunds; the ink remembers.\u{201D}"
            BookFeedback.play(.braidComplete)
        case .pending:
            clerkLine = "The clerk squints at the till. \u{201C}The App Store says this purchase is pending. Come back shortly.\u{201D}"
        case .cancelled:
            clerkLine = "The clerk shrugs and re-shelves it without judgment. Mostly without judgment."
            BookFeedback.play(.dismissPage)
        case .failed(let reason):
            clerkLine = "The till jams. \u{201C}\(reason)\u{201D} The clerk apologizes to the till, not to you."
            BookFeedback.play(.error)
        }
    }

    private func restore() async {
        let merchant = await BookShopTill.resolveMerchant()
        let owned = await merchant.restorePurchases()
        for packID in owned { onUnlock(packID) }
        clerkLine = owned.isEmpty
            ? "The ledger finds no prior bindings under your name. The clerk double-checks, sighs theatrically."
            : "The ledger remembers you. \(owned.count) binding\(owned.count == 1 ? "" : "s") restored."
    }

}

private struct PhysicalBookStudioContext: Identifiable {
    let edition: MonthlyEdition

    var id: String {
        BookThemeEngine.monthKey(for: edition.startDate)
    }
}

private struct PhysicalBookShelfPreview: View {
    let edition: MonthlyEdition
    let spec: PrintSpec

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            PhysicalBookCoverImage(edition: edition, spec: spec)
                .frame(width: 124, height: 82)
            VStack(alignment: .leading, spacing: 3) {
                Text(spec.name)
                    .font(.system(.caption, design: .serif, weight: .bold))
                    .foregroundStyle(BookPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(spec.coverTreatment == .linenWrap
                     ? "Cloth, foil, and a quieter heirloom feel."
                     : "Illustrated cover art for a more storybook keepsake.")
                    .font(.caption2)
                    .foregroundStyle(BookPalette.ink.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(BookPalette.violet.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct PhysicalBookCoverImage: View {
    let edition: MonthlyEdition
    let spec: PrintSpec

    private var image: UIImage {
        let pageCount = PrintGeometry.boundPageCount(rawPages: max(edition.pageCount, 24), spec: spec)
        return MonthlyEditionPDFWriter.physicalCoverPreviewImage(edition, spec: spec, pageCount: pageCount)
    }

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(6)
            .background(BookPalette.paper.opacity(0.9), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(BookPalette.ink.opacity(0.14), lineWidth: 1)
            }
    }
}

private struct PhysicalBookPreview: View {
    let edition: MonthlyEdition
    let spec: PrintSpec
    @State private var isPreviewPresented = false

    private var previewImage: UIImage {
        let pageCount = PrintGeometry.boundPageCount(rawPages: max(edition.pageCount, 24), spec: spec)
        return MonthlyEditionPDFWriter.physicalCoverPreviewImage(edition, spec: spec, pageCount: pageCount)
    }

    private var estimatedPriceLine: String {
        let pageCount = PrintGeometry.boundPageCount(rawPages: max(edition.pageCount, 24), spec: spec)
        let request = PhysicalBookQuoteRequest(
            editionID: BookThemeEngine.monthKey(for: edition.startDate),
            variant: .from(spec),
            pageCount: pageCount,
            shipTo: PhysicalBookShippingDestination(countryCode: "US", stateCode: nil, postalCode: "00000")
        )
        let price = PhysicalBookPricing.priceBreakdown(request: request, shippingCents: 0)
        return "Estimated before shipping/tax: \(Self.dollars(price.total.cents))"
    }

    var body: some View {
        return VStack(alignment: .leading, spacing: 6) {
            Button {
                BookFeedback.play(.openPage)
                isPreviewPresented = true
            } label: {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(BookPalette.ink.opacity(0.16), lineWidth: 1)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(BookPalette.nightText)
                            .padding(7)
                            .background(BookPalette.nightPanel.opacity(0.74), in: Circle())
                            .padding(8)
	                    }
	            }
	            .buttonStyle(.plain)
                .accessibilityLabel("\(spec.name) preview for \(edition.monthName)")
                .accessibilityHint("Opens the cover preview full screen")
            Text(spec.coverTreatment == .linenWrap
                 ? "Preview shows navy linen with gold foil stamping."
                 : "Preview shows the generated front cover art wrapped across a printed hardcover.")
                .font(.caption2)
                .foregroundStyle(BookPalette.ink.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
            Text(estimatedPriceLine)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(BookPalette.violet.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
        .fullScreenCover(isPresented: $isPreviewPresented) {
            PhysicalBookCoverPreviewScreen(
                image: previewImage,
                title: spec.name,
                subtitle: edition.monthName
            )
        }
    }

    private static func dollars(_ cents: Int) -> String {
        let value = Decimal(cents) / 100
        return value.formatted(.currency(code: "USD"))
    }
}

private struct PhysicalBookCoverPreviewScreen: View {
    let image: UIImage
    let title: String
    let subtitle: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                BookPalette.nightPanel.ignoresSafeArea()
                ScrollView([.horizontal, .vertical]) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(18)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: Image(uiImage: image), preview: SharePreview(title, image: Image(uiImage: image))) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share cover preview")
                }
            }
        }
    }
}

private struct PhysicalBookQuoteClient {
    enum ConfigurationError: LocalizedError {
        case missingEndpoint
        case missingStripePublishableKey

        var errorDescription: String? {
            switch self {
            case .missingEndpoint:
                return "Physical book quote endpoint is not configured."
            case .missingStripePublishableKey:
                return "Stripe publishable key is not configured."
            }
        }
    }

    enum ResponseError: LocalizedError {
        case invalidResponse(Int)

        var errorDescription: String? {
            switch self {
            case .invalidResponse(let statusCode):
                return "Quote service returned HTTP \(statusCode)."
            }
        }
    }

    var endpointURL: URL? = PhysicalBookQuoteClient.configuredEndpointURL()
    var session: URLSession = .shared

    static var isQuoteServiceConfigured: Bool {
        configuredEndpointURL() != nil
    }

    func quote(_ quoteRequest: PhysicalBookQuoteRequest) async throws -> PhysicalBookQuote {
        guard let endpointURL else {
            throw ConfigurationError.missingEndpoint
        }

        var request = URLRequest(url: endpointURL)
        return try await send(request: &request, body: quoteRequest, responseType: PhysicalBookQuote.self)
    }

    func paymentIntent(_ paymentRequest: PhysicalBookPaymentIntentRequest) async throws -> PhysicalBookPaymentIntent {
        guard let endpointURL else {
            throw ConfigurationError.missingEndpoint
        }

        var request = URLRequest(url: paymentIntentEndpointURL(from: endpointURL))
        return try await send(request: &request, body: paymentRequest, responseType: PhysicalBookPaymentIntent.self)
    }

    func previewOrder(_ orderRequest: PhysicalBookOrderRequest) async throws -> PhysicalBookOrderPreview {
        guard let endpointURL else {
            throw ConfigurationError.missingEndpoint
        }

        var request = URLRequest(url: orderEndpointURL(from: endpointURL, previewOnly: true))
        return try await send(request: &request, body: orderRequest, responseType: PhysicalBookOrderPreview.self)
    }

    func createOrder(_ orderRequest: PhysicalBookOrderRequest) async throws -> PhysicalBookOrder {
        guard let endpointURL else {
            throw ConfigurationError.missingEndpoint
        }

        var request = URLRequest(url: orderEndpointURL(from: endpointURL, previewOnly: false))
        return try await send(request: &request, body: orderRequest, responseType: PhysicalBookOrder.self)
    }

    func orderStatus(luluPrintJobID: String) async throws -> PhysicalBookOrder {
        guard let endpointURL else {
            throw ConfigurationError.missingEndpoint
        }

        var request = URLRequest(url: orderStatusEndpointURL(from: endpointURL, luluPrintJobID: luluPrintJobID))
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        applyConfiguredAPIToken(to: &request)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw ResponseError.invalidResponse((response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PhysicalBookOrder.self, from: data)
    }

    func uploadPrintFile(
        kind: PhysicalBookHostedPrintFile.Kind,
        fileURL: URL,
        editionID: String,
        md5: String
    ) async throws -> PhysicalBookHostedPrintFile {
        guard let endpointURL else {
            throw ConfigurationError.missingEndpoint
        }

        var request = URLRequest(url: printFileUploadEndpointURL(from: endpointURL, kind: kind))
        request.httpMethod = "POST"
        request.setValue("application/pdf", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(editionID, forHTTPHeaderField: "X-Edition-ID")
        request.setValue(md5, forHTTPHeaderField: "X-Source-MD5")
        applyConfiguredAPIToken(to: &request)
        request.httpBody = try Data(contentsOf: fileURL)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw ResponseError.invalidResponse((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try JSONDecoder().decode(PhysicalBookHostedPrintFile.self, from: data)
    }

    private func send<RequestBody: Encodable, ResponseBody: Decodable>(
        request: inout URLRequest,
        body: RequestBody,
        responseType: ResponseBody.Type
    ) async throws -> ResponseBody {
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        applyConfiguredAPIToken(to: &request)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw ResponseError.invalidResponse((response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ResponseBody.self, from: data)
    }

    private static func configuredEndpointURL() -> URL? {
        if let override = UserDefaults.standard.string(forKey: "physicalBookQuoteEndpointURL"),
           let url = URL(string: override),
           !override.isEmpty {
            return url
        }
        if let value = Bundle.main.object(forInfoDictionaryKey: "PhysicalBookQuoteEndpointURL") as? String,
           let url = URL(string: value),
           !value.isEmpty {
            return url
        }
        return nil
    }

    static func configuredStripePublishableKey() throws -> String {
        if let override = UserDefaults.standard.string(forKey: "stripePublishableKey"),
           !override.isEmpty {
            return override
        }
        if let value = Bundle.main.object(forInfoDictionaryKey: "StripePublishableKey") as? String,
           !value.isEmpty {
            return value
        }
        throw ConfigurationError.missingStripePublishableKey
    }

    private func applyConfiguredAPIToken(to request: inout URLRequest) {
        guard let token = PhysicalBookQuoteClient.configuredAPIToken() else { return }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    private static func configuredAPIToken() -> String? {
        if let override = UserDefaults.standard.string(forKey: "physicalBookAPIToken"),
           !override.isEmpty {
            return override
        }
        if let value = Bundle.main.object(forInfoDictionaryKey: "PhysicalBookAPIToken") as? String,
           !value.isEmpty {
            return value
        }
        return nil
    }

    private func paymentIntentEndpointURL(from quoteEndpointURL: URL) -> URL {
        siblingEndpointURL(from: quoteEndpointURL, endpointName: "payment-intents")
    }

    private func orderEndpointURL(from quoteEndpointURL: URL, previewOnly: Bool) -> URL {
        siblingEndpointURL(from: quoteEndpointURL, endpointName: previewOnly ? "orders/preview" : "orders")
    }

    private func orderStatusEndpointURL(from quoteEndpointURL: URL, luluPrintJobID: String) -> URL {
        var allowedCharacters = CharacterSet.urlPathAllowed
        allowedCharacters.remove(charactersIn: "/")
        let escapedID = luluPrintJobID.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? luluPrintJobID
        return siblingEndpointURL(from: quoteEndpointURL, endpointName: "orders/\(escapedID)")
    }

    private func printFileUploadEndpointURL(from quoteEndpointURL: URL, kind: PhysicalBookHostedPrintFile.Kind) -> URL {
        siblingEndpointURL(from: quoteEndpointURL, endpointName: "print-files/\(kind.rawValue)")
    }

    private func siblingEndpointURL(from quoteEndpointURL: URL, endpointName: String) -> URL {
        var components = URLComponents(url: quoteEndpointURL, resolvingAgainstBaseURL: false)
        let rawPath = components?.path ?? quoteEndpointURL.path
        let trimmedPath = rawPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let basePath: String
        if trimmedPath.hasSuffix("quote") {
            basePath = String(trimmedPath.dropLast("quote".count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        } else {
            basePath = trimmedPath
        }
        let nextPath = ([basePath, endpointName].filter { !$0.isEmpty }).joined(separator: "/")
        components?.path = "/" + nextPath
        return components?.url ?? quoteEndpointURL.appendingPathComponent(endpointName)
    }
}

private enum PhysicalBookPendingOrderStore {
    private static let storageKey = "physicalBookPendingOrders.v1"

    static func loadAll() -> [PhysicalBookPendingOrderDraft] {
        guard let data = InsideCoverStore.defaults.data(forKey: storageKey),
              let drafts = try? JSONDecoder().decode([PhysicalBookPendingOrderDraft].self, from: data) else {
            return []
        }
        return drafts.sorted { $0.updatedAt > $1.updatedAt }
    }

    static func pendingOrder(editionID: String, variantID: String? = nil) -> PhysicalBookPendingOrderDraft? {
        loadAll().first { draft in
            draft.editionID == editionID && (variantID == nil || draft.variant.id == variantID)
        }
    }

    static func upsert(_ draft: PhysicalBookPendingOrderDraft) throws {
        var drafts = loadAll()
        if let index = drafts.firstIndex(where: { $0.id == draft.id }) {
            drafts[index] = draft
        } else {
            drafts.append(draft)
        }
        try saveAll(drafts)
    }

    static func remove(id: String) throws {
        try saveAll(loadAll().filter { $0.id != id })
    }

    private static func saveAll(_ drafts: [PhysicalBookPendingOrderDraft]) throws {
        let data = try JSONEncoder().encode(drafts.sorted { $0.updatedAt > $1.updatedAt })
        InsideCoverStore.defaults.set(data, forKey: storageKey)
    }
}

private struct PhysicalBookPrintFileChecksums: Equatable {
    var interiorMD5: String
    var coverMD5: String
}

private extension UIApplication {
    func reenchantedTopViewController() -> UIViewController? {
        let root = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController
        return root?.reenchantedTopPresentedViewController()
    }
}

private extension UIViewController {
    func reenchantedTopPresentedViewController() -> UIViewController {
        if let presentedViewController {
            return presentedViewController.reenchantedTopPresentedViewController()
        }
        if let navigationController = self as? UINavigationController,
           let visibleViewController = navigationController.visibleViewController {
            return visibleViewController.reenchantedTopPresentedViewController()
        }
        if let tabBarController = self as? UITabBarController,
           let selectedViewController = tabBarController.selectedViewController {
            return selectedViewController.reenchantedTopPresentedViewController()
        }
        return self
    }
}
