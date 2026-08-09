import SwiftUI
import Foundation
import CryptoKit
import StripePaymentSheet
import UIKit
import PDFKit
#if canImport(Security)
import Security
#endif
#if canImport(QuickLook)
import QuickLook
import PhotosUI
import StoreKit
#endif

/// The BookShop: the Marginalia Goblins' living market tucked into the Stacks.
/// One place, three economies — Attention earned from Fae bargains, Belief spent
/// as the world's main sink, and App Store purchases for content packs. Stock
/// rotates with the day and the moon; an under-the-counter shelf appears only
/// when the world leans in.
enum BookShopInitialDestination: Hashable {
    case market
    case bindery
    case subscriptions
    case printStudio
}

struct BookShopSheet: View {
    let stall: GoblinStall
    let fae: FaePlayerState
    let attention: Int
    let belief: Int
    let goblinWarmth: Int
    let onBuyWare: (MarketWare) -> Void   // in-world purchase (Attention/Belief)
    let onUnlock: (String) -> Void        // packID, after a verified App Store purchase
    var onRevoke: (String) -> Void = { _ in }   // packID, when the App Store says a lapsed subscription no longer stands
    var onOpenArchive: (String) -> Void = { _ in }
    var onHaggle: (MarketWare) -> Int? = { _ in nil }   // spends 1 Warmth; returns discount, or nil if refused
    var onClerkBanter: () async -> String? = { nil }
    var onOpenBargain: (FaeBargain) -> Void = { _ in }
    var onMarkNextMarket: () -> Void = {}

    // The Bindery shelf: sew a finished month (or year) into a keepable chapter.
    var binderyWeeklyIssueLabel: String = ""
    var binderyWeeklyIssuePageCount: Int = 0
    var preparedWeeklyIssueCardURL: URL? = nil
    var preparedWeeklyIssuePDFURL: URL? = nil
    var binderyMonthLabel: String = ""
    var binderyMonthPageCount: Int = 0
    var preparedMonthlyEditionURL: URL? = nil
    var preparedAnnualEditionURL: URL? = nil
    var binderyNote: String? = nil
    var preparedPrintInteriorURL: URL? = nil
    var preparedPrintCoverURL: URL? = nil
    var printPreviewEdition: MonthlyEdition? = nil
    /// Where the reader asked to enter. The same Bookshop owns every route;
    /// this only opens it at the shelf they deliberately chose.
    var initialDestination: BookShopInitialDestination = .market
    @Binding var weeklyDedicationText: String
    @Binding var monthlyDedicationText: String
    @Binding var annualDedicationText: String
    var onBindWeeklyIssue: (BoundDedication?) -> Void = { _ in }
    /// A volume went away to be printed. The Book presses a Page for it.
    var onPressedVolume: (PressedVolumeKeepsake) -> Void = { _ in }
    /// The membership, mirrored so the Bindery can show what is standing.
    var boundYear: BoundYearMembership? = nil
    /// Stripe's own id for it, kept out of the archive-facing model.
    var boundYearMembershipID: String? = nil
    /// Carries Stripe's id alongside the membership. Without it a cancel would
    /// work in the session that subscribed and then fail forever afterwards,
    /// which is the worst possible shape for a cancel button.
    var onBoundYearChanged: (BoundYearMembership, String?) -> Void = { _, _ in }
    /// The archive records only that the address was confirmed. Stripe keeps
    /// the actual street address; it never enters the Book's memory.
    var onBoundYearAddressConfirmed: () -> Void = {}
    var onBindMonth: (BoundDedication?) -> Void = { _ in }
    var onBindMonthGemma: (BoundDedication?) -> Void = { _ in }
    var onBindYear: (BoundDedication?) -> Void = { _ in }
    /// The chosen cover photograph travels with the request; the print
    /// files are built where the edition lives, not here.
    var onMakePrintReady: (MonthlyEdition, PrintSpec, UIImage?) -> Void = { _, _, _ in }
    var onInvalidatePrintReady: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var merchantName = ""
    @State private var offers: [BookShopOffer] = []
    @State private var isLoading = true
    @State private var isPurchasing = false
    @State private var isClerkSpeaking = false
    @State private var clerkLine = "The clerk looks up from a ledger longer than the counter."
    @State private var spentAttention = 0
    @State private var spentBelief = 0
    @State private var boughtWareIDs: Set<String> = []
    @State private var bindingWareID: String?
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
    @State private var isChangingBoundYear = false
    @State private var boundYearStatusNote: String?
    @State private var boundYearShippingSummary: String?
    @State private var physicalBookOptionCatalogue: PhysicalBookPrintOptionCatalogue?
    /// The reader's chosen cover photograph. Held in memory only — it goes into
    /// the cover PDF and nowhere else, and is never written to the archive.
    @State private var physicalBookCoverPhoto: UIImage?
    @State private var physicalBookDedicationText = ""
    @State private var physicalBookPreparedDedicationText = ""
    @State private var selectedPrintOptionIDs: Set<String> = []
    @State private var isPressingPhysicalBook = false
    @State private var physicalBookPressStage: PhysicalBookPressStage = .idle

    private var ownedListings: [BookShopListing] {
        BookShopCatalog.listings.filter {
            $0.family != .standingOrder && !$0.comingSoon && PackEntitlements.isUnlocked($0.packID)
        }
    }
    private var standingOrderOffers: [BookShopOffer] {
        let order = Dictionary(
            uniqueKeysWithValues: BookShopCatalog.standingOrderTiers.enumerated().map {
                ($0.element.productID, $0.offset)
            }
        )
        return offers
            .filter { $0.listing.family == .standingOrder }
            .sorted { (order[$0.id] ?? .max) < (order[$1.id] ?? .max) }
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
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                        marketHero
                        purseStrip
                        clerkCard

                        let visibleWares = stall.wares.filter { !boughtWareIDs.contains($0.id) }
                        if stall.open, !visibleWares.isEmpty {
                            shelfBlock(title: "The Goblin Market", subtitle: stall.windowLine, symbol: "moon.stars.fill", accent: BookPalette.lampGold) {
                                ForEach(visibleWares) { ware in
                                    wareCard(ware)
                                        .transition(.asymmetric(
                                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                                            removal: .opacity.combined(with: .scale(scale: 0.88))
                                        ))
                                }
                            }
                        }

                        let visibleHidden = stall.hidden.filter { !boughtWareIDs.contains($0.id) }
                        if !visibleHidden.isEmpty {
                            shelfBlock(title: "Under the Counter", subtitle: "The clerk glances around, then slides a tray from beneath the boards.", symbol: "tray.full.fill", accent: BookPalette.violet) {
                                ForEach(visibleHidden) { ware in
                                    wareCard(ware, rare: true)
                                        .transition(.asymmetric(
                                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                                            removal: .opacity.combined(with: .scale(scale: 0.88))
                                        ))
                                }
                            }
                        }

                            binderySection

                        shelfBlock(title: "The Paid Shelf", subtitle: merchantName.isEmpty ? "The till is waking." : merchantName, symbol: "creditcard.fill", accent: BookPalette.teal) {
                            if PackEntitlements.hasStandingOrder {
                                standingOrderActiveCard()
                            } else {
                                ForEach(standingOrderOffers) { offer in
                                    standingOrderCard(offer)
                                }
                            }
                            if !freePacks.isEmpty || !BookShopCatalog.freeGifts.isEmpty {
                                subsectionLabel("Free Gifts")
                                ForEach(freePacks) { pack in freePackCard(pack) }
                                ForEach(BookShopCatalog.freeGifts) { gift in freeGiftCard(gift) }
                            }
                            if isLoading {
                                GoblinTillWakeView()
                                    .transition(BookMotion.riseTransition(reduceMotion: reduceMotion))
                            } else {
                                Group {
                                    let purchasable = offers.filter {
                                        $0.listing.family != .standingOrder && !PackEntitlements.isUnlocked($0.listing.packID)
                                    }
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
                                .transition(BookMotion.riseTransition(reduceMotion: reduceMotion))
                            }
                        }
                        .animation(BookMotion.result(reduceMotion), value: isLoading)

                        ledgerActions

                        standingSection

                        Text("Paid packs use App Store prices and travel with your save. The Standing Order renews monthly or yearly through the App Store and can be cancelled anytime in Settings; packs bought outright are yours forever. The other shelves trade only in things that belong to the Book.")
                            .font(.system(.caption2, design: .serif).italic())
                            .foregroundStyle(BookPalette.nightText.opacity(0.55))

                        legalLinksRow
                        }
                        .padding(18)
                    }
                    .onAppear {
                        guard initialDestination == .subscriptions || initialDestination == .bindery else { return }
                        DispatchQueue.main.async {
                            scrollProxy.scrollTo(
                                initialDestination == .subscriptions ? "bookshop-subscriptions" : "bookshop-bindery",
                                anchor: .top
                            )
                        }
                    }
                    .onChange(of: isLoading) { _, loading in
                        guard !loading,
                              initialDestination == .subscriptions || initialDestination == .bindery else { return }
                        DispatchQueue.main.async {
                            scrollProxy.scrollTo(
                                initialDestination == .subscriptions ? "bookshop-subscriptions" : "bookshop-bindery",
                                anchor: .top
                            )
                        }
                    }
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
                    .onAppear {
                        let existing = context.edition.dedication?.text ?? ""
                        physicalBookDedicationText = existing
                        physicalBookPreparedDedicationText = existing
                    }
                    // The Pressing. The reader has paid and the machine is
                    // working; the stitches follow the work rather than a
                    // timer, so a stall leaves the spine visibly half-sewn.
                    .overlay {
                        if isPressingPhysicalBook || physicalBookPressStage == .gone {
                            BinderySewingOverlay(
                                progress: physicalBookPressStage.progress,
                                caption: physicalBookPressStage.line
                            )
                            .transition(.opacity)
                        }
                    }
                    .animation(.easeInOut(duration: 0.35), value: isPressingPhysicalBook)
                    .animation(.easeInOut(duration: 0.35), value: physicalBookPressStage)
            }
            .task {
                if initialDestination == .printStudio,
                   physicalBookStudioContext == nil,
                   let printPreviewEdition {
                    selectedPrintVariantIndex = 0
                    DispatchQueue.main.async {
                        physicalBookStudioContext = PhysicalBookStudioContext(edition: printPreviewEdition)
                    }
                }
                let merchant = await BookShopTill.resolveMerchant()
                merchantName = merchant.tillName
                offers = await merchant.offers()
                isLoading = false
                // Subscriptions lapse; outright purchases never do. When the
                // real till answered, let the ledger close a Standing Order
                // the App Store no longer vouches for — and only that.
                if !offers.isEmpty, merchant is StoreKitMerchant, PackEntitlements.hasStandingOrder {
                    let owned = await merchant.restorePurchases()
                    if !owned.contains(PackEntitlements.standingOrderPackID) {
                        onRevoke(PackEntitlements.standingOrderPackID)
                    }
                }
                await reconcileBoundYearIfNeeded()
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
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: goblinWarmth > 0 ? "flame.fill" : "books.vertical.fill")
                .font(.headline.weight(.black))
                .foregroundStyle(goblinWarmth > 0 ? BookPalette.violet : BookPalette.lampGold)
                .frame(width: 34, height: 34)
                .background(BookPalette.page.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) {
                Text("THE TILL IS LISTENING")
                    .font(.caption2.weight(.black))
                    .kerning(0.8)
                    .foregroundStyle(BookPalette.lampGold)
                Text(marketPurseLine)
                    .font(.system(.caption, design: .serif).italic())
                    .foregroundStyle(BookPalette.nightText.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(BookPalette.nightPanel.opacity(0.62), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.22), lineWidth: 1)
        }
    }

    private var marketPurseLine: String {
        if liveAttention <= 0, liveBelief <= 0 {
            return "The clerk peers into your pockets, finds only lint, and politely pretends otherwise."
        }
        if goblinWarmth > 0 {
            return "The clerk recognizes you. Some wares may be easier to part with today."
        }
        return "The clerk looks over what the Book has entrusted to you and says nothing about the arithmetic."
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

    /// Terms of Use (EULA) and Privacy Policy — App Review requires both to be
    /// reachable in the binary, near anything that sells a subscription.
    private var legalLinksRow: some View {
        HStack(spacing: 6) {
            Link("Terms of Use", destination: LegalDocuments.termsOfUse)
            Text("·").foregroundStyle(BookPalette.nightText.opacity(0.4))
            Link("Privacy Policy", destination: LegalDocuments.privacyPolicy)
        }
        .font(.system(.caption2, design: .serif).weight(.semibold))
        .tint(BookPalette.teal)
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

    /// What the reader is currently paying for, and the way out of it.
    ///
    /// It sits at the top of the Bindery because that is where somebody goes
    /// when they are thinking about what they have — and because the way out
    /// belongs in the same place as the way in. Before this, the paywall
    /// promised "cancel any time in Settings" and then never mentioned it
    /// again; there was no route to a cancellation anywhere in the app.
    @ViewBuilder
    private var standingRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            subsectionLabel("What You're Paying For")

            HStack(alignment: .top, spacing: 9) {
                Image(systemName: PackEntitlements.hasStandingOrder ? "checkmark.seal.fill" : "seal")
                    .foregroundStyle(PackEntitlements.hasStandingOrder ? BookPalette.violet : BookPalette.ink.opacity(0.4))
                VStack(alignment: .leading, spacing: 2) {
                    Text("The Standing Order")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BookPalette.ink)
                    Text(PackEntitlements.hasStandingOrder
                         ? "Open and standing."
                         : "Not open. The free Book carries on regardless.")
                        .font(.caption2)
                        .foregroundStyle(BookPalette.ink.opacity(0.6))
                }
                Spacer(minLength: 8)
                if PackEntitlements.hasStandingOrder {
                    Button {
                        Task { await openManageSubscriptions() }
                    } label: {
                        Label("Change or stop", systemImage: "gear")
                            .font(.caption2.weight(.bold))
                    }
                    .buttonStyle(.bordered)
                    .tint(BookPalette.violet)
                }
            }

            // Both ways in live here too, not just both ways out. A menu that
            // can only cancel is as lopsided as one that can only sell.
            if !PackEntitlements.hasStandingOrder, !standingOrderOffers.isEmpty {
                ForEach(standingOrderOffers) { offer in
                    standingOrderCard(offer)
                }
            }

            HStack(alignment: .top, spacing: 9) {
                Image(systemName: boundYear?.isCurrent == true ? "shippingbox.fill" : "shippingbox")
                    .foregroundStyle(boundYear?.isCurrent == true ? BookPalette.lampGold : BookPalette.ink.opacity(0.4))
                VStack(alignment: .leading, spacing: 2) {
                    Text("The Bound Year")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BookPalette.ink)
                    Text(boundYearStandingLine)
                        .font(.caption2)
                        .foregroundStyle(BookPalette.ink.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
            }

            if let boundYearShippingSummary {
                Label("Parcels: \(boundYearShippingSummary)", systemImage: "mappin.and.ellipse")
                    .font(.caption2)
                    .foregroundStyle(BookPalette.ink.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if boundYear?.isCurrent == true, boundYear?.endedAt == nil {
                Button {
                    Task { await stopBoundYear() }
                } label: {
                    Label(isChangingBoundYear ? "Closing the ledger…" : "Stop the Bound Year",
                          systemImage: isChangingBoundYear ? "hourglass" : "xmark.circle")
                        .font(.caption2.weight(.bold))
                }
                .buttonStyle(.bordered)
                .tint(BookPalette.lampGold)
                .disabled(isChangingBoundYear)

                boundYearAddressEditor
            } else {
                if boundYear?.isCurrent == true, boundYear?.endedAt != nil {
                    Text("No further charge is scheduled. The paid period and everything it earned still stand.")
                        .font(.caption2)
                        .foregroundStyle(BookPalette.ink.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                    boundYearAddressEditor
                } else {
                    physicalBookShippingForm

                    Toggle(isOn: $physicalBookThirdPartyPrintConsent) {
                        Text("I understand Lulu receives the seasonal print files and delivery address needed to make and post these books.")
                            .font(.caption2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .tint(BookPalette.teal)

                    HStack(spacing: 8) {
                        ForEach(BoundYearMembership.Cadence.allCases, id: \.self) { cadence in
                            Button {
                                Task { await startBoundYear(cadence) }
                            } label: {
                                Text(cadence == .annual ? "$249 / year" : "$24.99 / month")
                                    .font(.caption2.weight(.bold))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(cadence == .annual ? BookPalette.lampGold : BookPalette.ink.opacity(0.5))
                            .disabled(
                                isChangingBoundYear ||
                                physicalBookShippingAddress == nil ||
                                !physicalBookThirdPartyPrintConsent
                            )
                        }
                    }
                }
            }

            if let boundYearStatusNote {
                Text(boundYearStatusNote)
                    .font(.caption2)
                    .foregroundStyle(BookPalette.ink.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(BookPalette.paper.opacity(0.30), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .id("bookshop-subscriptions")
    }

    private var boundYearAddressEditor: some View {
        DisclosureGroup("Change the parcel address") {
            physicalBookShippingForm
            Button {
                Task { await updateBoundYearShippingAddress() }
            } label: {
                Label("Use this address", systemImage: "mappin.circle.fill")
                    .font(.caption2.weight(.bold))
            }
            .buttonStyle(.bordered)
            .tint(BookPalette.teal)
            .disabled(isChangingBoundYear || physicalBookShippingAddress == nil)
        }
        .font(.caption.weight(.bold))
        .tint(BookPalette.teal)
    }

    /// Refreshes the local mirror before showing it as fact. Stripe can change
    /// while the Book is shut; a cancellation or failed renewal must not leave
    /// an old green seal sitting here indefinitely.
    @MainActor
    private func reconcileBoundYearIfNeeded() async {
        guard let membershipID = boundYearMembershipID,
              var updated = boundYear else { return }
        do {
            let remote = try await PhysicalBookQuoteClient().membershipStatus(id: membershipID)
            boundYearShippingSummary = remote.shippingAddressSummary
            if remote.shippingAddressPresent == true {
                onBoundYearAddressConfirmed()
            }
            if let periodEnd = remote.periodEndsAt {
                updated.paidThrough = periodEnd
            }
            if remote.cancelAtPeriodEnd {
                // Stripe still considers it active until the paid period ends.
                // Keep it standing here too, or the UI would offer a duplicate
                // subscription while the old one is still alive.
                updated.status = .active
                updated.endedAt = remote.periodEndsAt
            } else {
                switch remote.status {
                case "active", "trialing":
                    updated.status = .active
                    updated.endedAt = nil
                case "past_due":
                    updated.status = .inGracePeriod
                case "canceled":
                    updated.status = .cancelled
                    updated.endedAt = remote.periodEndsAt ?? updated.endedAt
                default:
                    updated.status = .lapsed
                    updated.endedAt = remote.periodEndsAt ?? updated.endedAt
                }
            }
            if updated != boundYear {
                onBoundYearChanged(updated, membershipID)
            }
        } catch {
            guard initialDestination == .subscriptions else { return }
            boundYearStatusNote = "I couldn't check the outside ledger just now. I'm showing the last line I kept."
        }
    }

    private var boundYearStandingLine: String {
        guard let boundYear, boundYear.isCurrent else {
            return "Not standing. Three seasons in softcover and the year in cloth and foil, posted to your door."
        }
        let cadence = boundYear.cadence == .annual ? "by the year" : "by the month"
        if let ending = boundYear.endedAt {
            return "Standing until \(ending.formatted(date: .abbreviated, time: .omitted)); then it closes without another charge."
        }
        return "Standing, billed \(cadence)."
    }

    /// Opens a membership and pays for it without leaving the Book.
    ///
    /// Legal in-app precisely because it is four printed books: Apple requires
    /// physical goods to use a payment method other than in-app purchase, which
    /// is the same reason the one-off volumes already go through Stripe. One
    /// checkout in the product, not two.
    @MainActor
    private func startBoundYear(_ cadence: BoundYearMembership.Cadence) async {
        let email = physicalBookContactEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard email.contains("@"), let shippingAddress = physicalBookShippingAddress else {
            boundYearStatusNote = "I need the whole door: name, street, town, post code, phone, and email. Parcels are literal-minded beasts."
            return
        }
        guard physicalBookThirdPartyPrintConsent else {
            boundYearStatusNote = "The print-house line needs your mark before any pages or address can leave the Book."
            return
        }
        isChangingBoundYear = true
        boundYearStatusNote = "Opening the ledger…"
        defer { isChangingBoundYear = false }

        do {
            let draft = try await PhysicalBookQuoteClient()
                .openMembership(
                    cadence: cadence.rawValue,
                    contactEmail: email,
                    shippingAddress: shippingAddress,
                    acceptsLuluFulfillment: true
                )
            let sheet = try makeMembershipPaymentSheet(clientSecret: draft.clientSecret)
            guard let presenter = UIApplication.shared.reenchantedTopViewController() else {
                boundYearStatusNote = "Could not open the till just now."
                return
            }
            sheet.present(from: presenter) { result in
                Task { @MainActor in
                    switch result {
                    case .completed:
                        onBoundYearChanged(
                            BoundYearMembership(
                                cadence: cadence,
                                status: .active,
                                startedAt: draft.startedAt
                                    .map { Date(timeIntervalSince1970: TimeInterval($0)) }
                                    ?? Date(),
                                paidThrough: draft.currentPeriodEnd
                                    .map { Date(timeIntervalSince1970: TimeInterval($0)) }
                                    ?? Date()
                            ),
                            draft.membershipID
                        )
                        boundYearShippingSummary = [
                            shippingAddress.city,
                            shippingAddress.stateCode,
                            shippingAddress.postalCode,
                            shippingAddress.countryCode
                        ].compactMap { $0?.nonEmpty }.joined(separator: ", ")
                        onBoundYearAddressConfirmed()
                        boundYearStatusNote = "Standing. The first parcel goes when your first season closes."
                        BookFeedback.play(.braidComplete)
                    case .canceled:
                        boundYearStatusNote = "Left it. Nothing was charged."
                    case .failed(let error):
                        boundYearStatusNote = "The till balked: \(error.localizedDescription)"
                    }
                }
            }
        } catch {
            boundYearStatusNote = "The Bound Year isn't open yet — \(error.localizedDescription)"
        }
    }

    @MainActor
    private func updateBoundYearShippingAddress() async {
        guard let membershipID = boundYearMembershipID,
              let shippingAddress = physicalBookShippingAddress else {
            boundYearStatusNote = "Fill in the whole door first. The parcel refuses riddles."
            return
        }
        isChangingBoundYear = true
        defer { isChangingBoundYear = false }
        do {
            let status = try await PhysicalBookQuoteClient().updateMembershipShipping(
                id: membershipID,
                shippingAddress: shippingAddress
            )
            boundYearShippingSummary = status.shippingAddressSummary
            onBoundYearAddressConfirmed()
            boundYearStatusNote = "Changed. Stripe keeps the street; I only keep the fact that you checked it."
            BookFeedback.play(.select)
        } catch {
            boundYearStatusNote = "That door wouldn't stay in the ledger: \(error.localizedDescription)"
        }
    }

    /// Stops it at the end of what they already paid for. The volumes those
    /// months earned still arrive; nothing is clawed back.
    @MainActor
    private func stopBoundYear() async {
        guard let membershipID = boundYearMembershipID else {
            boundYearStatusNote = "I can't find the ledger line for that one."
            return
        }
        isChangingBoundYear = true
        defer { isChangingBoundYear = false }
        do {
            let status = try await PhysicalBookQuoteClient().cancelMembership(id: membershipID)
            var updated = boundYear
            // `cancel_at_period_end` leaves the subscription active until the
            // reader reaches the end of what they already paid for.
            updated?.status = .active
            updated?.endedAt = status.periodEndsAt
            if let updated { onBoundYearChanged(updated, membershipID) }
            boundYearStatusNote = "Stopped. You keep everything the months you paid for already earned — those volumes still come."
            BookFeedback.play(.dismissPage)
        } catch {
            boundYearStatusNote = "It wouldn't close: \(error.localizedDescription)"
        }
    }

    private func makeMembershipPaymentSheet(clientSecret: String) throws -> PaymentSheet {
        let publishableKey = try PhysicalBookQuoteClient.configuredStripePublishableKey()
        STPAPIClient.shared.publishableKey = publishableKey
        var configuration = PaymentSheet.Configuration()
        configuration.merchantDisplayName = "ReEnchanted"
        configuration.allowsDelayedPaymentMethods = false
        if let merchantID = PhysicalBookQuoteClient.configuredApplePayMerchantIdentifier() {
            configuration.applePay = .init(
                merchantId: merchantID,
                merchantCountryCode: PhysicalBookQuoteClient.configuredApplePayCountryCode()
            )
        }
        return PaymentSheet(paymentIntentClientSecret: clientSecret, configuration: configuration)
    }

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
                standingRow

                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(binderyWeeklyIssuePageCount > 0 ? binderyWeeklyIssueLabel : "No weekly issue yet")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(BookPalette.ink)
                        Text(binderyWeeklyIssuePageCount > 0
                             ? "\(binderyWeeklyIssuePageCount) \(binderyWeeklyIssuePageCount == 1 ? "page" : "pages") gathered into this issue"
                             : "A closed week with enough kept pages becomes a small PDF issue.")
                            .font(.caption2)
                            .foregroundStyle(BookPalette.ink.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    if binderyWeeklyIssuePageCount > 0 {
                        // Read-first: binding opens the issue in-app, where the
                        // card and full-PDF shares live. Once wrapped, the label
                        // reflects that tapping re-opens it to read.
                        let alreadyWrapped = preparedWeeklyIssuePDFURL != nil
                        Button {
                            BookFeedback.play(.openPage)
                            onBindWeeklyIssue(BoundDedication(text: weeklyDedicationText))
                        } label: {
                            Label(alreadyWrapped ? "Read the issue" : "Bind & read", systemImage: "book")
                                .font(.caption2.weight(.bold))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(BookPalette.teal)
                    }
                }
                BindingDedicationEditor(
                    title: "Write inside this issue",
                    text: $weeklyDedicationText
                )

                Divider().overlay(BookPalette.ink.opacity(0.12))

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
                        Button {
                            onBindMonth(BoundDedication(text: monthlyDedicationText))
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Rebind this month")
                    } else if binderyMonthPageCount > 0 {
                        Menu {
                            Button {
                                BookFeedback.play(.openPage)
                                onBindMonth(BoundDedication(text: monthlyDedicationText))
                            } label: {
                                Label("Bind now (fast)", systemImage: "bolt")
                            }
                            Button {
                                BookFeedback.play(.openPage)
                                onBindMonthGemma(BoundDedication(text: monthlyDedicationText))
                            } label: {
                                Label("Bind with Gemma's conclusion", systemImage: "sparkles")
                            }
                        } label: {
                            Label("Bind", systemImage: "book.pages")
                                .font(.caption2.weight(.bold))
                        } primaryAction: {
                            BookFeedback.play(.openPage)
                            onBindMonth(BoundDedication(text: monthlyDedicationText))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(BookPalette.lampGold)
                    }
                }
                BindingDedicationEditor(
                    title: "Write inside this month",
                    text: $monthlyDedicationText
                )

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
                        Button {
                            onBindYear(BoundDedication(text: annualDedicationText))
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Rebind this year")
                    } else {
                        Button {
                            BookFeedback.play(.openPage)
                            onBindYear(BoundDedication(text: annualDedicationText))
                        } label: {
                            Label("Bind the year", systemImage: "books.vertical")
                                .font(.caption2.weight(.bold))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(BookPalette.lampGold)
                    }
                }
                BindingDedicationEditor(
                    title: "Write inside this year",
                    text: $annualDedicationText
                )

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
        .id("bookshop-bindery")
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
            Text("A made-to-order 6×9 book, from travelling softcover to cloth and foil.")
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
        // Softcover first: the seasonal binding and the least costly real book.
        let printVariants = PrintSpec.allPrintableVariants
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
                        BindingDedicationEditor(
                            title: "Write inside this copy",
                            text: $physicalBookDedicationText
                        )
                        .disabled(pendingPhysicalBookOrder != nil)
                        // Straight after choosing the binding, while the reader
                        // is still thinking about the object rather than the
                        // paperwork.
                        physicalBookExtrasPanel(spec: selectedPrintSpec)
                        physicalBookStudioPrintFilesPanel(edition: edition, spec: selectedPrintSpec)
                        physicalBookOrderReviewPanel(edition: edition, spec: selectedPrintSpec)
                        physicalBookStudioCheckoutPanel(edition: edition, spec: selectedPrintSpec)
                        physicalBookSubmissionPanel(edition: edition, spec: selectedPrintSpec)
                    }
                    .padding(18)
                }
            }
            .navigationTitle("Book of You")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: "\(PhysicalBookEditionIdentity.id(for: edition))|\(selectedPrintSpec.coverTreatment)") {
                loadPendingPhysicalBookOrder(edition: edition, spec: selectedPrintSpec)
                // Each binding has its own extras, so the catalogue is fetched
                // per binding and the selection cleared when it changes.
                await loadPhysicalBookOptions(spec: selectedPrintSpec)
            }
            .task(id: physicalBookPrintFilesTaskID) {
                physicalBookThirdPartyPrintConsent = false
                loadPhysicalBookPrintFileChecksums()
            }
            .onChange(of: physicalBookDedicationText) { _, _ in
                guard pendingPhysicalBookOrder == nil else { return }
                guard physicalBookDedicationText != physicalBookPreparedDedicationText else { return }
                onInvalidatePrintReady()
                physicalBookPrintFileChecksums = nil
                hostedPhysicalBookInteriorURL = ""
                hostedPhysicalBookCoverURL = ""
                physicalBookQuote = nil
                selectedPhysicalBookShippingOptionID = nil
                resetPreparedPhysicalBookCheckout()
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
                    detail: PrintSpec.allPrintableVariants[min(selectedPrintVariantIndex, PrintSpec.allPrintableVariants.count - 1)].name,
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
                        .scaleEffect(isSelected && !reduceMotion ? 1.025 : 0.98)
                        .rotation3DEffect(
                            .degrees(isSelected && !reduceMotion ? -3 : 0),
                            axis: (x: 0, y: 1, z: 0),
                            perspective: 0.7
                        )
                        .animation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.78), value: isSelected)
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
                Text(spec.coverTreatment.mood)
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
        .buttonStyle(.bookPress(playsHaptic: false))
        .bookCardHover()
        .accessibilityLabel("\(spec.name), \(isSelected ? "selected" : "not selected")")
    }

    private func physicalBookStudioPrintFilesPanel(edition: MonthlyEdition, spec: PrintSpec) -> some View {
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
                    var dedicatedEdition = edition
                    dedicatedEdition.dedication = BoundDedication(text: physicalBookDedicationText)
                    physicalBookPreparedDedicationText = physicalBookDedicationText
                    onMakePrintReady(dedicatedEdition, spec, physicalBookCoverPhoto)
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
            physicalBookReviewRow("Pages", "\(physicalBookBoundPageCount(edition: edition, spec: spec)) pages", systemImage: "doc.text")
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
        withAnimation(reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.36, dampingFraction: 0.78)) {
            selectedPrintVariantIndex = index
        }
        physicalBookQuote = nil
        physicalBookQuoteMessage = nil
        selectedPhysicalBookShippingOptionID = nil
        resetPreparedPhysicalBookCheckout()
    }

    private func physicalBookShelfEstimateLine(spec: PrintSpec) -> String {
        let value = spec.basePriceUSD + (spec.perPagePriceUSD * Decimal(24))
        return NSDecimalNumber(decimal: value).doubleValue.formatted(.currency(code: "USD"))
    }

    private func physicalBookEstimatedPriceLine(edition: MonthlyEdition, spec: PrintSpec) -> String {
        let pageCount = physicalBookBoundPageCount(edition: edition, spec: spec)
        let request = PhysicalBookQuoteRequest(
            editionID: PhysicalBookEditionIdentity.id(for: edition),
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

    /// Quotes and the order review must describe the PDF that will actually go
    /// to the press. `edition.pageCount` counts kept Pages, not rendered leaves;
    /// cover matter, plates, and the reader's dedication all change the latter.
    /// Before a proof exists we retain the old estimate, then switch to the
    /// authoritative prepared interior as soon as it has been made.
    private func physicalBookBoundPageCount(edition: MonthlyEdition, spec: PrintSpec) -> Int {
        if let preparedPrintInteriorURL,
           let document = PDFDocument(url: preparedPrintInteriorURL),
           document.pageCount > 0 {
            return document.pageCount
        }
        return PrintGeometry.boundPageCount(rawPages: max(edition.pageCount, 24), spec: spec)
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
            estimatedTaxCents: selectedOption.estimatedTax?.cents ?? 0,
            policy: physicalBookQuote.pricingPolicy,
            catalogue: physicalBookOptionCatalogue
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
                            estimatedTaxCents: option.estimatedTax?.cents ?? 0,
                            policy: physicalBookQuote.pricingPolicy,
                            catalogue: physicalBookOptionCatalogue
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

                    // Agreed to while deciding, not after paying.
                    physicalBookThirdPartyDisclosure

                    if physicalBookPressStage != .idle {
                        physicalBookCheckoutNotice(
                            physicalBookPressStage.line,
                            systemImage: physicalBookPressStage == .gone
                                ? "checkmark.seal.fill"
                                : (physicalBookPressStage == .stalled ? "exclamationmark.triangle" : "needle.and.thread")
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
                            presentPhysicalBookPaymentSheet(edition: edition, spec: spec)
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
            physicalBookContactEmail.trimmingCharacters(in: .whitespacesAndNewlines).contains("@") &&
            physicalBookChosenExtrasAreSatisfied &&
            // Consent moved *before* the money rather than after it. It is not
            // weakened — the print house still cannot receive a page without
            // it — but a disclosure the reader agrees to while deciding to buy
            // is meaningful, and one that blocks a button after they have paid
            // is an obstacle wearing a disclosure's coat. It also has to be
            // true by payment time now, because the Pressing runs on its own.
            physicalBookThirdPartyPrintConsent
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
        let pageCount = physicalBookBoundPageCount(edition: edition, spec: spec)
        let request = PhysicalBookQuoteRequest(
            editionID: PhysicalBookEditionIdentity.id(for: edition),
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
            ),
            // Sorted, so the same choices always price the same. The Worker
            // verifies the settled amount against its own arithmetic, and an
            // order that differed only by the order of taps would be refused.
            selectedOptionIDs: selectedPrintOptionIDs.sorted()
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
            let intent = try await PhysicalBookQuoteClient().paymentIntent(
                request,
                checkoutToken: physicalBookQuote.checkoutToken
            )
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

        // Apple Pay when the build has a merchant identifier, and silently not
        // when it does not. This is the single biggest piece of friction in the
        // flow: without it the reader hand-types a card number, an expiry, a
        // CVC and a full postal address to buy a keepsake. With it, Face ID.
        if let merchantID = PhysicalBookQuoteClient.configuredApplePayMerchantIdentifier() {
            configuration.applePay = .init(
                merchantId: merchantID,
                merchantCountryCode: PhysicalBookQuoteClient.configuredApplePayCountryCode()
            )
        }
        return PaymentSheet(paymentIntentClientSecret: intent.clientSecret, configuration: configuration)
    }

    private func presentPhysicalBookPaymentSheet(edition: MonthlyEdition, spec: PrintSpec) {
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
                    await pressPhysicalBook(edition: edition, spec: spec)
                case .canceled:
                    physicalBookCheckoutMessage = "Checkout was cancelled. Nothing was charged."
                case .failed(let error):
                    physicalBookCheckoutMessage = "Payment failed: \(error.localizedDescription)"
                }
            }
        }
    }

    /// The extras shelf. Rendered entirely from what the server sent, so a new
    /// cover appears here the day it is deployed and never needs a release.
    @ViewBuilder
    private func physicalBookExtrasPanel(spec: PrintSpec) -> some View {
        if let catalogue = physicalBookOptionCatalogue,
           catalogue.variantID == PhysicalBookVariant.from(spec).id,
           !catalogue.options.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                subsectionLabel("What Else The Bindery Offers")
                ForEach(catalogue.byFamily, id: \.family) { group in
                    ForEach(group.options) { option in
                        Button {
                            toggle(option, catalogue: catalogue)
                        } label: {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: selectedPrintOptionIDs.contains(option.id)
                                      ? "checkmark.circle.fill" : "circle")
                                    .font(.callout)
                                    .foregroundStyle(BookPalette.violet)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option.title)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(BookPalette.ink)
                                    Text(option.pitch)
                                        .font(.caption2)
                                        .foregroundStyle(BookPalette.ink.opacity(0.62))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 8)
                                Text("+\(Self.dollars(MoneyAmount(currencyCode: "USD", cents: option.priceDeltaCents)))")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(BookPalette.violet)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .overlay(alignment: .bottomLeading) {
                            // An option that needs something from the reader has
                            // to ask for it here. The Worker cannot check whether
                            // a photograph exists — it only sees an id — so this
                            // gate is the client's alone to hold.
                            if option.requiresPhoto, selectedPrintOptionIDs.contains(option.id) {
                                physicalBookCoverPhotoPicker
                                    .padding(.leading, 28)
                                    .padding(.bottom, 6)
                            }
                        }
                        .padding(8)
                        .background(
                            (selectedPrintOptionIDs.contains(option.id)
                             ? BookPalette.violet.opacity(0.14)
                             : BookPalette.violet.opacity(0.06)),
                            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                        )
                    }
                }
            }
        }
    }

    /// Every chosen extra has what it needs.
    ///
    /// The Worker cannot enforce this: it receives an id, not a photograph. So
    /// paying for a cover the Bindery has no picture for is a mistake only the
    /// client can prevent, and it prevents it before the money rather than
    /// discovering it at the press.
    private var physicalBookChosenExtrasAreSatisfied: Bool {
        guard let catalogue = physicalBookOptionCatalogue else { return true }
        let chosen = catalogue.options.filter { selectedPrintOptionIDs.contains($0.id) }
        return chosen.allSatisfy { !$0.requiresPhoto || physicalBookCoverPhoto != nil }
    }

    private var physicalBookCoverPhotoPicker: some View {
        PhotosPicker(
            selection: Binding(
                get: { nil },
                set: { item in
                    guard let item else { return }
                    Task { await loadPhysicalBookCoverPhoto(from: item) }
                }
            ),
            matching: .images,
            photoLibrary: .shared()
        ) {
            Label(
                physicalBookCoverPhoto == nil ? "Choose the photograph" : "Photograph chosen",
                systemImage: physicalBookCoverPhoto == nil ? "photo" : "checkmark.circle.fill"
            )
            .font(.caption2.weight(.bold))
        }
        .buttonStyle(.bordered)
        .tint(BookPalette.violet)
    }

    private func loadPhysicalBookCoverPhoto(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        physicalBookCoverPhoto = image
        // A different cover is a different book, so the quote and the payment
        // sheet are stale. The print files are rebuilt by the owner of the
        // edition when the reader asks for them again.
        physicalBookQuote = nil
        physicalBookPaymentSheet = nil
        BookFeedback.play(.openPage)
    }

    /// Two options that both change the binding would fight over the SKU, so
    /// choosing one drops the other rather than letting the server refuse the
    /// pair after the reader has already picked them.
    private func toggle(_ option: PhysicalBookPrintOption, catalogue: PhysicalBookPrintOptionCatalogue) {
        if selectedPrintOptionIDs.contains(option.id) {
            selectedPrintOptionIDs.remove(option.id)
        } else {
            if option.changesBinding {
                let otherRebinds = catalogue.options.filter { $0.changesBinding && $0.id != option.id }
                for other in otherRebinds { selectedPrintOptionIDs.remove(other.id) }
            }
            selectedPrintOptionIDs.insert(option.id)
        }
        // A changed selection changes the price, so the quote is no longer good.
        physicalBookQuote = nil
        physicalBookPaymentSheet = nil
        BookFeedback.play(.openPage)
    }

    private func loadPhysicalBookOptions(spec: PrintSpec) async {
        let variantID = PhysicalBookVariant.from(spec).id
        guard physicalBookOptionCatalogue?.variantID != variantID else { return }
        selectedPrintOptionIDs = []
        physicalBookOptionCatalogue = try? await PhysicalBookQuoteClient()
            .printOptions(forVariantID: variantID)
    }

    /// Presses a Page for the volume that just went out.
    ///
    /// The destination is coarsened to a region on purpose — the archive has no
    /// business holding a street address, and "bound for Maine" is the part
    /// worth remembering anyway.
    @MainActor
    private func recordPressedVolume(edition: MonthlyEdition, spec: PrintSpec) {
        let region = [physicalBookShippingStateCode, physicalBookShippingCountryCode]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        onPressedVolume(
            PressedVolumeKeepsake(
                id: "\(PhysicalBookEditionIdentity.id(for: edition))-\(PhysicalBookVariant.from(spec).id)",
                coverLine: edition.monthName,
                bindingName: spec.name,
                pressedAt: Date(),
                destinationRegion: region.isEmpty ? nil : region,
                // One copy per order today. Gift copies arrive with the upsell
                // catalogue, and the keepsake already knows how to say "two".
                copies: 1
            )
        )
    }

    /// The Pressing: everything that used to be the reader's homework.
    ///
    /// Paying is the last thing they do. The print files go up and the job goes
    /// in without another button — those steps existed because a print house
    /// needs them, not because anybody buying a book should have to think about
    /// them.
    ///
    /// Nothing here weakens a gate. The Worker still owns the price, still
    /// verifies the settled amount, still serialises submission through its
    /// Durable Object. If any of it fails the money is already taken, so this
    /// says so plainly and leaves the manual controls in reach — and the
    /// Worker's paid-without-print ledger catches it either way.
    @MainActor
    private func pressPhysicalBook(edition: MonthlyEdition, spec: PrintSpec) async {
        isPressingPhysicalBook = true
        defer { isPressingPhysicalBook = false }

        physicalBookPressStage = .sewing
        physicalBookCheckoutMessage = nil
        BookFeedback.play(.braidStart)

        await uploadPhysicalBookPrintFiles(edition: edition)
        guard physicalBookHostedPrintFiles != nil else {
            physicalBookPressStage = .stalled
            physicalBookSubmissionMessage = "You're paid up and the pages are ready, but they wouldn't go over the wire. I've kept everything — send them again below and nothing repeats itself."
            BookFeedback.play(.error)
            return
        }

        physicalBookPressStage = .sending
        await submitPhysicalBookOrder(previewOnly: false, edition: edition, spec: spec)

        if submittedPhysicalBookOrder != nil {
            physicalBookPressStage = .gone
            recordPressedVolume(edition: edition, spec: spec)
            BookFeedback.play(.braidComplete)
            // Let the last stitch land and be seen before the ceremony clears.
            // A seal that vanishes the instant it is drawn was never a seal.
            try? await Task.sleep(for: .milliseconds(1_600))
            physicalBookPressStage = .idle
        } else {
            // Stalled leaves the overlay behind on purpose, so the reader is
            // looking at the retry controls rather than a spine that finished
            // sewing a book which never went anywhere.
            physicalBookPressStage = .stalled
            BookFeedback.play(.error)
        }
    }

    private func loadPendingPhysicalBookOrder(edition: MonthlyEdition, spec: PrintSpec) {
        pendingPhysicalBookOrder = PhysicalBookPendingOrderStore.pendingOrder(
            editionID: PhysicalBookEditionIdentity.id(for: edition),
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
                interiorSHA256: try Self.sha256Hex(for: preparedPrintInteriorURL),
                coverMD5: try Self.md5Hex(for: preparedPrintCoverURL),
                coverSHA256: try Self.sha256Hex(for: preparedPrintCoverURL)
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
        guard let pendingPhysicalBookOrder,
              let checkoutToken = pendingPhysicalBookOrder.checkoutToken,
              !checkoutToken.isEmpty,
              let preparedPrintInteriorURL,
              let preparedPrintCoverURL,
              let checksums = physicalBookPrintFileChecksums else {
            physicalBookSubmissionMessage = "This order needs a fresh secure quote before its print files can leave the Book."
            return
        }

        isUploadingPhysicalBookPrintFiles = true
        physicalBookSubmissionMessage = "Uploading print PDFs..."
        defer { isUploadingPhysicalBookPrintFiles = false }

        do {
            let client = PhysicalBookQuoteClient()
            let editionID = PhysicalBookEditionIdentity.id(for: edition)
            let interior = try await client.uploadPrintFile(
                kind: .interior,
                fileURL: preparedPrintInteriorURL,
                editionID: editionID,
                quoteID: pendingPhysicalBookOrder.quoteID,
                checkoutToken: checkoutToken,
                md5: checksums.interiorMD5,
                sha256: checksums.interiorSHA256
            )
            let cover = try await client.uploadPrintFile(
                kind: .cover,
                fileURL: preparedPrintCoverURL,
                editionID: editionID,
                quoteID: pendingPhysicalBookOrder.quoteID,
                checkoutToken: checkoutToken,
                md5: checksums.coverMD5,
                sha256: checksums.coverSHA256
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
        guard let orderRequest = makePhysicalBookOrderRequest(),
              let checkoutToken = pendingPhysicalBookOrder?.checkoutToken,
              !checkoutToken.isEmpty else {
            physicalBookSubmissionMessage = physicalBookSubmissionReadinessText
            return
        }

        isSubmittingPhysicalBookOrder = true
        physicalBookSubmissionMessage = previewOnly ? "Preparing print order preview..." : "Submitting to Lulu..."
        defer { isSubmittingPhysicalBookOrder = false }

        do {
            if previewOnly {
                let preview = try await PhysicalBookQuoteClient().previewOrder(
                    orderRequest,
                    checkoutToken: checkoutToken
                )
                let packageID = preview.luluPrintJobPayload.lineItems.first?.podPackageID ?? orderRequest.quoteRequest.variant.luluPackageID
                physicalBookSubmissionMessage = "Preview ready: \(preview.luluPrintJobPayload.shippingLevel) shipping, package \(packageID), \(preview.luluPrintJobPayload.lineItems.count) line item."
            } else {
                let order = try await PhysicalBookQuoteClient().createOrder(
                    orderRequest,
                    checkoutToken: checkoutToken
                )
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
              let pendingPhysicalBookOrder,
              let checkoutToken = pendingPhysicalBookOrder.checkoutToken,
              !checkoutToken.isEmpty,
              let luluPrintJobID = submittedPhysicalBookOrder.luluPrintJobID else {
            physicalBookSubmissionMessage = "Submit to Lulu first, then the order can refresh from Lulu's status endpoint."
            return
        }

        isRefreshingPhysicalBookOrder = true
        defer { isRefreshingPhysicalBookOrder = false }

        do {
            let order = try await PhysicalBookQuoteClient().orderStatus(
                luluPrintJobID: luluPrintJobID,
                paymentIntentID: pendingPhysicalBookOrder.paymentIntentID,
                checkoutToken: checkoutToken
            )
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
        // Lulu now owns fulfillment. Do not leave the reader's full shipping
        // address, email, phone, and checkout capability sitting on disk.
        try? PhysicalBookPendingOrderStore.remove(id: pendingPhysicalBookOrder.id)
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
            checkoutToken: physicalBookQuote.checkoutToken,
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

    private static func sha256Hex(for url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// The reader's standing with the Book Fae — folded in from the old Margin:
    /// waiting exchanges, gifts in hand, and warmth by species.
    private var standingSection: some View {
        let waiting = fae.bargains.filter { $0.status == .offered || $0.status == .owed }
        return VStack(alignment: .leading, spacing: 8) {
            shelfHeader("Your Standing With the Fae")
            if !waiting.isEmpty {
                ForEach(waiting) { bargain in
                    Button {
                        BookFeedback.play(.openPage)
                        onOpenBargain(bargain)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Label(bargain.faeKind.name, systemImage: bargain.faeKind.symbolName)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(BookPalette.ink)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(BookPalette.teal.opacity(0.7))
                            }
                            Text(bargain.status == .offered
                                 ? "Offered: \(bargain.giftName)"
                                 : "Waiting for: \(bargain.terms)")
                                .font(.caption2)
                                .foregroundStyle(BookPalette.teal)
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
                        HStack(alignment: .top) {
                            Label(kind.name, systemImage: kind.symbolName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BookPalette.ink.opacity(0.85))
                            Spacer()
                            if kind == .literaryElf {
                                Text(fae.literaryElfCourt().title)
                                    .font(.caption2)
                                    .foregroundStyle(BookPalette.ink.opacity(0.55))
                            }
                        }
                        Text(BookMechanicPresentation.faeStanding(
                            warmth: fae.warmth(for: kind),
                            claim: fae.claim(for: kind)
                        ))
                                .font(.caption2)
                                .foregroundStyle(BookPalette.ink.opacity(0.55))
                                .fixedSize(horizontal: false, vertical: true)
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
        let discount = haggleDiscounts[ware.id] ?? 0
        let price = max(1, basePrice - discount)
        let canAfford = ware.currency == .attention ? liveAttention >= price : liveBelief >= price
        let accent = rare ? BookPalette.violet : (ware.currency == .attention ? BookPalette.teal : BookPalette.lampGold)
        let isBinding = bindingWareID == ware.id
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
                    Text(rare ? "UNDER-COUNTER WARE" : "MARGIN WARE")
                        .font(.caption2.weight(.black))
                        .kerning(0.8)
                        .foregroundStyle(accent.opacity(0.85))
                }
                Spacer()
                Text(canAfford ? "THE TILL NODS" : "THE TILL HESITATES")
                    .font(.caption2.weight(.black))
                    .kerning(0.6)
                    .foregroundStyle(canAfford ? accent : BookPalette.ink.opacity(0.46))
                    .multilineTextAlignment(.trailing)
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
                    clerkLine = "The clerk closes one hand over the ware. \u{201C}Not yet. The till knows what you have.\u{201D}"
                    BookFeedback.play(.error)
                    return
                }
                bindWare(ware, price: price)
            } label: {
                Label(
                    isBinding ? "Wrapping in waxed paper…" : (canAfford ? "Ask the clerk to wrap it" : "The till will not open yet"),
                    systemImage: isBinding ? "seal.fill" : (ware.currency == .attention ? "eye" : "sparkles")
                )
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
            .opacity(canAfford ? 1 : 0.55)
            .disabled(isBinding || bindingWareID != nil)

            if goblinWarmth > 0, !haggledWareIDs.contains(ware.id) {
                Button {
                    haggledWareIDs.insert(ware.id)
                    if let cut = onHaggle(ware), cut > 0 {
                        withAnimation(reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.3, dampingFraction: 0.78)) {
                            haggleDiscounts[ware.id] = cut
                        }
                        clerkLine = "The clerk sucks a tooth, then lowers the price of \(ware.title). \u{201C}For you. Once.\u{201D}"
                        BookFeedback.play(.select)
                    } else {
                        clerkLine = "The clerk waves you off. \u{201C}Not today.\u{201D} The asking leaves the room a little cooler."
                        BookFeedback.play(.error)
                    }
                } label: {
                    Label("Try your standing with the clerk", systemImage: "hand.wave")
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
        .overlay {
            if isBinding {
                Label("BOUND TO YOU", systemImage: "seal.fill")
                    .font(.caption.weight(.black))
                    .tracking(0.8)
                    .foregroundStyle(BookPalette.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(BookPalette.lampGold, in: Capsule())
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .scaleEffect(isBinding && !reduceMotion ? 0.96 : 1)
        .opacity(isBinding && !reduceMotion ? 0.38 : 1)
        .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.74), value: isBinding)
    }

    private func bindWare(_ ware: MarketWare, price: Int) {
        guard bindingWareID == nil else { return }
        withAnimation(reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.30, dampingFraction: 0.70)) {
            bindingWareID = ware.id
        }

        let finishBinding = {
            onBuyWare(ware)
            withAnimation(reduceMotion ? .easeOut(duration: 0.16) : .easeInOut(duration: 0.26)) {
                if ware.currency == .attention { spentAttention += price } else { spentBelief += price }
                boughtWareIDs.insert(ware.id)
                bindingWareID = nil
            }
            clerkLine = "The clerk wraps \(ware.title) in waxed paper. \u{201C}Bound to you. Mind how you spend it.\u{201D}"
            BookFeedback.play(.braidComplete)
        }

        if reduceMotion {
            finishBinding()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.34, execute: finishBinding)
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
                Label(isPurchasing ? "Binding..." : "Bind it to my save — \(offer.displayPrice)", systemImage: "seal")
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

    /// The everything-pass, shelved above the folios it contains.
    private func standingOrderCard(_ offer: BookShopOffer) -> some View {
        let tier = BookShopCatalog.standingOrderTiers.first { $0.productID == offer.id }
        let periodUnit = tier?.periodUnit ?? "year"
        let cadence = tier?.title.lowercased() ?? "annual"
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(BookPalette.violet.opacity(0.18))
                    Image(systemName: "books.vertical.fill")
                        .font(.headline.weight(.black))
                        .foregroundStyle(BookPalette.violet)
                }
                .frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 3) {
                    Text(offer.listing.title)
                        .font(.system(.headline, design: .serif, weight: .bold))
                        .foregroundStyle(BookPalette.ink)
                    Text("EVERY PACK · \(cadence.uppercased()) RENEWAL")
                        .font(.caption2.weight(.black))
                        .kerning(0.8)
                        .foregroundStyle(BookPalette.violet.opacity(0.85))
                }
                Spacer()
                priceTag(offer.displayPrice, label: "per \(periodUnit)", tint: BookPalette.violet)
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
                Label(isPurchasing ? "Binding..." : "Open the \(cadence) order — \(offer.displayPrice)/\(periodUnit)", systemImage: "book.closed.fill")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(BookPalette.violet)
            .disabled(isPurchasing || !offer.isPurchasable)
            Text("Auto-renews \(cadence == "monthly" ? "monthly" : "yearly") through the App Store. Cancel anytime; packs bought outright stay yours forever.")
                .font(.caption2)
                .foregroundStyle(BookPalette.ink.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .background(
            LinearGradient(
                colors: [BookPalette.page.opacity(0.98), BookPalette.paper.opacity(0.86), BookPalette.violet.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.violet.opacity(0.32), lineWidth: 1)
        }
    }

    private func standingOrderActiveCard() -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(BookPalette.violet)
                VStack(alignment: .leading, spacing: 3) {
                    Text("The Standing Order")
                        .font(.system(.subheadline, design: .serif, weight: .bold))
                        .foregroundStyle(BookPalette.ink)
                    Text("Open and standing. Every pack on this shelf — and every new one the Goblins print — binds itself to your save.")
                        .font(.caption2)
                        .foregroundStyle(BookPalette.ink.opacity(0.66))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }

            // The way out, in the same place as the way in.
            //
            // There was no cancellation route anywhere in the app — the paywall
            // promised "cancel any time in Settings" and then left the reader to
            // find Settings on their own. A subscription whose exit is hidden is
            // not simple, clear or fair, and this one is supposed to be all
            // three. `showManageSubscriptions` opens Apple's own sheet, where
            // cancelling actually happens.
            Button {
                Task { await openManageSubscriptions() }
            } label: {
                Label("See it, change it, or stop it", systemImage: "gear")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(BookPalette.violet)
            }
            .buttonStyle(.bordered)
            .tint(BookPalette.violet)

            Text("Stopping keeps everything you've already made. The free Book never closes.")
                .font(.caption2)
                .foregroundStyle(BookPalette.ink.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(BookPalette.violet.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @MainActor
    private func openManageSubscriptions() async {
        guard let scene = UIApplication.shared.reenchantedActiveWindowScene() else { return }
        BookFeedback.play(.openPage)
        try? await AppStore.showManageSubscriptions(in: scene)
    }

    private func offerSymbol(for listing: BookShopListing) -> String {
        switch listing.family {
        case .soundPack: return "radio.fill"
        case .eventPack: return listing.resolvedSaleState == .liveEvent ? "sparkles.rectangle.stack.fill" : "archivebox.fill"
        default: return "shippingbox.fill"
        }
    }

    private func freePackCard(_ pack: PageArchetypePack) -> some View {
        freeGiftCard(
            packID: pack.id,
            title: pack.displayName,
            detail: "A gift folio of \(pack.archetypes.count) extra page shapes. Bind it here when you want me to start using it."
        )
    }

    private func freeGiftCard(_ gift: BookShopFreeGift) -> some View {
        freeGiftCard(
            packID: gift.packID,
            title: gift.title,
            detail: "\(gift.contents) Bind it here when you want me to start using it."
        )
    }

    private func freeGiftCard(packID: String, title: String, detail: String) -> some View {
        let isBound = PackEntitlements.isUnlocked(packID) || boundFreePackIDs.contains(packID)
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
                    Text(title)
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
            Text(detail)
                .font(.caption)
                .foregroundStyle(BookPalette.ink.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)
            Button {
                guard !isBound else { return }
                boundFreePackIDs.insert(packID)
                onUnlock(packID)
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
            clerkLine = offer.listing.family == .standingOrder
                ? "The clerk opens a fresh page and writes your name at the top of the ledger. \u{201C}A standing order. Everything we print finds you now.\u{201D}"
                : "The clerk stamps the ledger twice. \u{201C}\(offer.listing.title) is bound to you. No refunds; the ink remembers.\u{201D}"
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
        PhysicalBookEditionIdentity.id(for: edition)
    }
}

/// Monthly and seasonal volumes can begin in the same month. Carry the end
/// month for multi-month books so pending orders, uploads, and keepsakes cannot
/// mistake a season for its first chapter.
private enum PhysicalBookEditionIdentity {
    static func id(for edition: MonthlyEdition) -> String {
        let start = BookThemeEngine.monthKey(for: edition.startDate)
        let end = BookThemeEngine.monthKey(for: edition.endDate)
        return start == end ? start : "\(start)-through-\(end)"
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
                Text(spec.coverTreatment.mood)
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
            editionID: PhysicalBookEditionIdentity.id(for: edition),
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
            Text(spec.coverTreatment.coverPreviewNote)
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

struct PhysicalBookQuoteClient {
    enum ConfigurationError: LocalizedError {
        case missingEndpoint
        case missingStripePublishableKey
        case invalidStripePublishableKey

        var errorDescription: String? {
            switch self {
            case .missingEndpoint:
                return "Physical book quote endpoint is not configured."
            case .missingStripePublishableKey:
                return "Stripe publishable key is not configured."
            case .invalidStripePublishableKey:
                return "Stripe publishable key does not match the physical-book checkout mode."
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
    private static let sessionAuthorizer = PhysicalBookClientSessionAuthorizer()

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

    /// Opens a Bound Year membership, ready to be paid for in the app.
    func openMembership(
        cadence: String,
        contactEmail: String,
        shippingAddress: PhysicalBookShippingAddress,
        acceptsLuluFulfillment: Bool
    ) async throws -> BoundYearMembershipDraft {
        guard let endpointURL else { throw ConfigurationError.missingEndpoint }
        var request = URLRequest(url: siblingEndpointURL(from: endpointURL, endpointName: "memberships"))
        struct Body: Encodable {
            let cadence: String
            let contactEmail: String
            let shippingAddress: PhysicalBookShippingAddress
            let acceptsLuluFulfillment: Bool
        }
        return try await send(
            request: &request,
            body: Body(
                cadence: cadence,
                contactEmail: contactEmail,
                shippingAddress: shippingAddress,
                acceptsLuluFulfillment: acceptsLuluFulfillment
            ),
            responseType: BoundYearMembershipDraft.self
        )
    }

    func updateMembershipShipping(
        id: String,
        shippingAddress: PhysicalBookShippingAddress
    ) async throws -> BoundYearShippingStatus {
        guard let endpointURL else { throw ConfigurationError.missingEndpoint }
        var request = URLRequest(
            url: siblingEndpointURL(from: endpointURL, endpointName: "memberships/\(id)/shipping")
        )
        struct Body: Encodable { let shippingAddress: PhysicalBookShippingAddress }
        return try await send(
            request: &request,
            body: Body(shippingAddress: shippingAddress),
            responseType: BoundYearShippingStatus.self
        )
    }

    func prepareMembershipDispatch(
        membershipID: String,
        seasonKey: String,
        request body: BoundYearDispatchRequest
    ) async throws -> BoundYearDispatchPreparation {
        guard let endpointURL else { throw ConfigurationError.missingEndpoint }
        var request = URLRequest(url: siblingEndpointURL(
            from: endpointURL,
            endpointName: "memberships/\(membershipID)/dispatches/\(seasonKey)"
        ))
        return try await send(
            request: &request,
            body: body,
            responseType: BoundYearDispatchPreparation.self
        )
    }

    func uploadMembershipDispatchPrintFile(
        kind: PhysicalBookHostedPrintFile.Kind,
        fileURL: URL,
        membershipID: String,
        seasonKey: String,
        editionID: String,
        dispatchToken: String,
        md5: String,
        sha256: String
    ) async throws -> PhysicalBookHostedPrintFile {
        guard let endpointURL else { throw ConfigurationError.missingEndpoint }
        var request = URLRequest(url: siblingEndpointURL(
            from: endpointURL,
            endpointName: "memberships/\(membershipID)/dispatches/\(seasonKey)/print-files/\(kind.rawValue)"
        ))
        request.httpMethod = "POST"
        request.setValue("application/pdf", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(editionID, forHTTPHeaderField: "X-Edition-ID")
        request.setValue(dispatchToken, forHTTPHeaderField: "X-Membership-Dispatch-Token")
        request.setValue(md5, forHTTPHeaderField: "X-Source-MD5")
        request.setValue(sha256, forHTTPHeaderField: "X-Source-SHA256")
        request.httpBody = try Data(contentsOf: fileURL)
        let data = try await authorizedData(for: request)
        return try JSONDecoder().decode(PhysicalBookHostedPrintFile.self, from: data)
    }

    func submitMembershipDispatch(
        membershipID: String,
        seasonKey: String,
        dispatchToken: String
    ) async throws -> PhysicalBookOrder {
        guard let endpointURL else { throw ConfigurationError.missingEndpoint }
        var request = URLRequest(url: siblingEndpointURL(
            from: endpointURL,
            endpointName: "memberships/\(membershipID)/dispatches/\(seasonKey)/orders"
        ))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(dispatchToken, forHTTPHeaderField: "X-Membership-Dispatch-Token")
        request.httpBody = Data("{}".utf8)
        let data = try await authorizedData(for: request)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PhysicalBookOrder.self, from: data)
    }

    /// Stops it at the end of the period already paid for. Never immediate —
    /// those months bought volumes, and the volumes still come.
    func cancelMembership(id: String) async throws -> BoundYearMembershipStatus {
        guard let endpointURL else { throw ConfigurationError.missingEndpoint }
        var request = URLRequest(
            url: siblingEndpointURL(from: endpointURL, endpointName: "memberships/\(id)/cancel")
        )
        struct Empty: Encodable {}
        return try await send(request: &request, body: Empty(), responseType: BoundYearMembershipStatus.self)
    }

    func membershipStatus(id: String) async throws -> BoundYearMembershipStatus {
        guard let endpointURL else { throw ConfigurationError.missingEndpoint }
        var request = URLRequest(
            url: siblingEndpointURL(from: endpointURL, endpointName: "memberships/\(id)")
        )
        request.httpMethod = "GET"
        let data = try await authorizedData(for: request)
        return try JSONDecoder().decode(BoundYearMembershipStatus.self, from: data)
    }

    /// What extras the Bindery is offering for a binding.
    ///
    /// A GET, because the reader is still deciding and nothing is being
    /// created. The prices come back from the server and are never computed
    /// here — that is the whole reason the catalogue lives over there.
    func printOptions(forVariantID variantID: String) async throws -> PhysicalBookPrintOptionCatalogue {
        guard let endpointURL else {
            throw ConfigurationError.missingEndpoint
        }
        var components = URLComponents(
            url: siblingEndpointURL(from: endpointURL, endpointName: "options"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "variantID", value: variantID)]
        guard let url = components?.url else {
            throw ConfigurationError.missingEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let data = try await authorizedData(for: request)
        return try JSONDecoder().decode(PhysicalBookPrintOptionCatalogue.self, from: data)
    }

    func paymentIntent(
        _ paymentRequest: PhysicalBookPaymentIntentRequest,
        checkoutToken: String
    ) async throws -> PhysicalBookPaymentIntent {
        guard let endpointURL else {
            throw ConfigurationError.missingEndpoint
        }

        var request = URLRequest(url: paymentIntentEndpointURL(from: endpointURL))
        applyCheckoutToken(checkoutToken, to: &request)
        return try await send(request: &request, body: paymentRequest, responseType: PhysicalBookPaymentIntent.self)
    }

    func previewOrder(
        _ orderRequest: PhysicalBookOrderRequest,
        checkoutToken: String
    ) async throws -> PhysicalBookOrderPreview {
        guard let endpointURL else {
            throw ConfigurationError.missingEndpoint
        }

        var request = URLRequest(url: orderEndpointURL(from: endpointURL, previewOnly: true))
        applyCheckoutToken(checkoutToken, to: &request)
        return try await send(request: &request, body: orderRequest, responseType: PhysicalBookOrderPreview.self)
    }

    func createOrder(
        _ orderRequest: PhysicalBookOrderRequest,
        checkoutToken: String
    ) async throws -> PhysicalBookOrder {
        guard let endpointURL else {
            throw ConfigurationError.missingEndpoint
        }

        var request = URLRequest(url: orderEndpointURL(from: endpointURL, previewOnly: false))
        applyCheckoutToken(checkoutToken, to: &request)
        return try await send(request: &request, body: orderRequest, responseType: PhysicalBookOrder.self)
    }

    func orderStatus(
        luluPrintJobID: String,
        paymentIntentID: String,
        checkoutToken: String
    ) async throws -> PhysicalBookOrder {
        guard let endpointURL else {
            throw ConfigurationError.missingEndpoint
        }

        var request = URLRequest(url: orderStatusEndpointURL(from: endpointURL, luluPrintJobID: luluPrintJobID))
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(paymentIntentID, forHTTPHeaderField: "X-Payment-Intent-ID")
        applyCheckoutToken(checkoutToken, to: &request)
        let data = try await authorizedData(for: request)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PhysicalBookOrder.self, from: data)
    }

    func uploadPrintFile(
        kind: PhysicalBookHostedPrintFile.Kind,
        fileURL: URL,
        editionID: String,
        quoteID: String,
        checkoutToken: String,
        md5: String,
        sha256: String
    ) async throws -> PhysicalBookHostedPrintFile {
        guard let endpointURL else {
            throw ConfigurationError.missingEndpoint
        }

        var request = URLRequest(url: printFileUploadEndpointURL(from: endpointURL, kind: kind))
        request.httpMethod = "POST"
        request.setValue("application/pdf", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(editionID, forHTTPHeaderField: "X-Edition-ID")
        request.setValue(quoteID, forHTTPHeaderField: "X-Quote-ID")
        request.setValue(md5, forHTTPHeaderField: "X-Source-MD5")
        request.setValue(sha256, forHTTPHeaderField: "X-Source-SHA256")
        applyCheckoutToken(checkoutToken, to: &request)
        request.httpBody = try Data(contentsOf: fileURL)
        let data = try await authorizedData(for: request)
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

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(body)

        let data = try await authorizedData(for: request)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ResponseBody.self, from: data)
    }

    private static func configuredEndpointURL() -> URL? {
        if let override = UserDefaults.standard.string(forKey: "physicalBookQuoteEndpointURL"),
           let url = secureEndpointURL(from: override) {
            return url
        }
        if let value = Bundle.main.object(forInfoDictionaryKey: "PhysicalBookQuoteEndpointURL") as? String,
           let url = secureEndpointURL(from: value) {
            return url
        }
        return nil
    }

    static func configuredStripePublishableKey() throws -> String {
        let key: String
        if let override = UserDefaults.standard.string(forKey: "stripePublishableKey"),
           !override.isEmpty {
            key = override
        } else if let value = Bundle.main.object(forInfoDictionaryKey: "StripePublishableKey") as? String,
                  !value.isEmpty {
            key = value
        } else {
            throw ConfigurationError.missingStripePublishableKey
        }
        let expectedPrefix = configuredCheckoutMode() == "live" ? "pk_live_" : "pk_test_"
        guard key.hasPrefix(expectedPrefix) else {
            throw ConfigurationError.invalidStripePublishableKey
        }
        return key
    }

    /// The Apple Pay merchant identifier, if this build has one.
    ///
    /// Deliberately optional. The merchant id, the Apple Pay capability and the
    /// Stripe certificate all require the paid developer account, so the code
    /// ships ahead of them: with no identifier configured the payment sheet is
    /// exactly what it is today, and the day the identifier lands in Info.plist
    /// Apple Pay appears with no code change and no release of its own.
    static func configuredApplePayMerchantIdentifier() -> String? {
        if let override = UserDefaults.standard.string(forKey: "applePayMerchantIdentifier"),
           !override.isEmpty {
            return override
        }
        if let value = Bundle.main.object(forInfoDictionaryKey: "ApplePayMerchantIdentifier") as? String,
           !value.isEmpty {
            return value
        }
        return nil
    }

    /// Where the reader's card is billed from. Lulu prints and ships from the
    /// region, but the merchant of record is here.
    static func configuredApplePayCountryCode() -> String {
        if let override = UserDefaults.standard.string(forKey: "applePayMerchantCountryCode"),
           !override.isEmpty {
            return override
        }
        if let value = Bundle.main.object(forInfoDictionaryKey: "ApplePayMerchantCountryCode") as? String,
           !value.isEmpty {
            return value
        }
        return "US"
    }

    private func authorizedData(for originalRequest: URLRequest) async throws -> Data {
        guard let endpointURL else {
            throw ConfigurationError.missingEndpoint
        }
        let installationID = PhysicalBookQuoteClient.installationID
        let sessionEndpoint = siblingEndpointURL(from: endpointURL, endpointName: "sessions")

        for attempt in 0..<2 {
            let clientToken = try await PhysicalBookQuoteClient.sessionAuthorizer.token(
                sessionEndpointURL: sessionEndpoint,
                installationID: installationID,
                urlSession: session
            )
            var request = originalRequest
            request.setValue(installationID, forHTTPHeaderField: "X-Installation-ID")
            request.setValue("Bearer \(clientToken)", forHTTPHeaderField: "Authorization")
            let (data, response) = try await session.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            if statusCode == 401, attempt == 0 {
                await PhysicalBookQuoteClient.sessionAuthorizer.invalidate(token: clientToken)
                continue
            }
            guard (200..<300).contains(statusCode) else {
                throw ResponseError.invalidResponse(statusCode)
            }
            return data
        }
        throw ResponseError.invalidResponse(401)
    }

    private static var installationID: String {
        PhysicalBookInstallationIdentity.loadOrCreate()
    }

    private func applyCheckoutToken(_ token: String, to request: inout URLRequest) {
        request.setValue(token, forHTTPHeaderField: "X-Checkout-Token")
    }

    private static func configuredCheckoutMode() -> String {
        if let override = UserDefaults.standard.string(forKey: "physicalBookCheckoutMode")?.lowercased(),
           override == "test" || override == "live" {
            return override
        }
        if let value = (Bundle.main.object(forInfoDictionaryKey: "PhysicalBookCheckoutMode") as? String)?.lowercased(),
           value == "test" || value == "live" {
            return value
        }
        return "test"
    }

    private static func secureEndpointURL(from value: String) -> URL? {
        guard !value.isEmpty,
              let components = URLComponents(string: value),
              components.user == nil,
              components.password == nil,
              let host = components.host,
              !host.isEmpty else {
            return nil
        }
        if components.scheme?.lowercased() == "https" {
            return components.url
        }
        #if DEBUG
        if components.scheme?.lowercased() == "http",
           host == "localhost" || host == "127.0.0.1" || host == "::1" {
            return components.url
        }
        #endif
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

private actor PhysicalBookClientSessionAuthorizer {
    private struct SessionEnvelope: Decodable {
        let token: String
        let expiresAt: Date
    }

    private var cachedSession: SessionEnvelope?

    func token(
        sessionEndpointURL: URL,
        installationID: String,
        urlSession: URLSession
    ) async throws -> String {
        if let cachedSession,
           cachedSession.expiresAt.timeIntervalSinceNow > 60 {
            return cachedSession.token
        }

        var request = URLRequest(url: sessionEndpointURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(installationID, forHTTPHeaderField: "X-Installation-ID")
        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.userAuthenticationRequired)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(SessionEnvelope.self, from: data)
        guard envelope.expiresAt.timeIntervalSinceNow > 0,
              envelope.token.count >= 40 else {
            throw URLError(.cannotParseResponse)
        }
        cachedSession = envelope
        return envelope.token
    }

    func invalidate(token: String) {
        if cachedSession?.token == token {
            cachedSession = nil
        }
    }
}

private enum PhysicalBookInstallationIdentity {
    private static let service = "com.openclaw.enchantify.insidecover.physical-book"
    private static let account = "installation-id"
    private static let legacyDefaultsKey = "physicalBookInstallationID"

    static func loadOrCreate() -> String {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
           let data = result as? Data,
           let identifier = String(data: data, encoding: .utf8),
           isValid(identifier) {
            return identifier
        }

        let legacy = UserDefaults.standard.string(forKey: legacyDefaultsKey)
        let identifier = legacy.flatMap { isValid($0) ? $0 : nil } ?? UUID().uuidString.lowercased()
        let identity: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: Data(identifier.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemUpdate(identity as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addition = identity
            attributes.forEach { addition[$0.key] = $0.value }
            _ = SecItemAdd(addition as CFDictionary, nil)
        }
        UserDefaults.standard.removeObject(forKey: legacyDefaultsKey)
        return identifier
        #else
        if let existing = UserDefaults.standard.string(forKey: legacyDefaultsKey), isValid(existing) {
            return existing
        }
        let identifier = UUID().uuidString.lowercased()
        UserDefaults.standard.set(identifier, forKey: legacyDefaultsKey)
        return identifier
        #endif
    }

    private static func isValid(_ value: String) -> Bool {
        value.range(of: #"^[A-Za-z0-9._-]{16,96}$"#, options: .regularExpression) != nil
    }
}

private enum PhysicalBookPendingOrderStore {
    private static let storageKey = "physicalBookPendingOrders.v1"
    private static let fileName = "physical-book-pending-orders.v2.json"
    private static let retentionInterval: TimeInterval = 7 * 24 * 60 * 60

    private static var fileURL: URL? {
        InsideCoverStore.containerURL?.appendingPathComponent(fileName)
    }

    static func loadAll() -> [PhysicalBookPendingOrderDraft] {
        let data: Data?
        if let fileURL, let protectedData = try? Data(contentsOf: fileURL) {
            data = protectedData
        } else {
            data = InsideCoverStore.defaults.data(forKey: storageKey)
        }
        guard let data,
              let decoded = try? JSONDecoder().decode([PhysicalBookPendingOrderDraft].self, from: data) else {
            return []
        }
        let cutoff = Date().addingTimeInterval(-retentionInterval)
        let drafts = decoded.filter { $0.updatedAt >= cutoff && $0.submittedOrder == nil }
        if drafts.count != decoded.count || InsideCoverStore.defaults.data(forKey: storageKey) != nil {
            try? saveAll(drafts)
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
        guard let fileURL else {
            throw CocoaError(.fileNoSuchFile)
        }
        let data = try JSONEncoder().encode(drafts.sorted { $0.updatedAt > $1.updatedAt })
        try SensitiveFileProtection.write(data, to: fileURL)
        InsideCoverStore.defaults.removeObject(forKey: storageKey)
    }
}

private struct PhysicalBookPrintFileChecksums: Equatable {
    var interiorMD5: String
    var interiorSHA256: String
    var coverMD5: String
    var coverSHA256: String
}

private extension UIApplication {
    /// The scene Apple's own manage-subscriptions sheet needs.
    func reenchantedActiveWindowScene() -> UIWindowScene? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? connectedScenes.compactMap { $0 as? UIWindowScene }.first
    }

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

// MARK: - The Standing Order paywall

/// Only reader-authored, non-sensitive answers cross into the offer. This
/// isn't a marketing profile and never includes people, photos, or inferred
/// sensitive traits. These answers personalize the Book's explanation for the
/// two universal prices; they never change the actual terms.
struct StandingOrderPersonalization: Equatable {
    var readerName: String
    var rutAnswer: String
    var aliveAnswer: String
    var magicAnswer: String
    var appetiteAnswer: String
    var edgeAnswer: String
    var chapterName: String
    var offerReasons: [String]

    static let empty = StandingOrderPersonalization()

    init(
        readerName: String = "",
        rutAnswer: String = "",
        aliveAnswer: String = "",
        magicAnswer: String = "",
        appetiteAnswer: String = "",
        edgeAnswer: String = "",
        chapterName: String = "",
        offerReasons: [String] = [
            "You gave me one honest answer before I asked for anything. The Bindery noticed.",
            "You made it through the First Door. The clerk reluctantly counted that as advance payment."
        ]
    ) {
        self.readerName = readerName
        self.rutAnswer = rutAnswer
        self.aliveAnswer = aliveAnswer
        self.magicAnswer = magicAnswer
        self.appetiteAnswer = appetiteAnswer
        self.edgeAnswer = edgeAnswer
        self.chapterName = chapterName
        self.offerReasons = offerReasons
    }

    init(onboarding result: OnboardingFlowView.Result) {
        readerName = result.name.trimmingCharacters(in: .whitespacesAndNewlines)
        rutAnswer = Self.rutAnswers[result.rutStrongest] ?? ""
        aliveAnswer = Self.aliveAnswers[result.mostAlive] ?? ""
        magicAnswer = Self.magicAnswers[result.magicSource] ?? ""
        appetiteAnswer = Self.appetiteAnswers[result.tastePreference] ?? ""
        edgeAnswer = Self.edgeAnswers[result.comfortBoundary] ?? ""
        chapterName = AcademyChapterRegistry.chapter(id: result.drawnChapterID)?.name ?? ""
        offerReasons = Self.offerReasons(
            hiddenMagicStance: result.hiddenMagicStance,
            magicSource: result.magicSource,
            tastePreference: result.tastePreference,
            chapterName: chapterName,
            sleeveWord: result.sleeveWord,
            wickerRollSucceeded: result.wickerRollSucceeded
        )
    }

    var hasReaderMap: Bool {
        !rutAnswer.isEmpty || !aliveAnswer.isEmpty || !magicAnswer.isEmpty
    }

    var hasStoryDirection: Bool {
        !appetiteAnswer.isEmpty || !edgeAnswer.isEmpty || !chapterName.isEmpty
    }

    private static let rutAnswers = [
        "work": "Work swallows the day",
        "phone": "My phone eats the edges",
        "chores": "Chores all blur together",
        "exhaustion": "I'm tired before I begin",
        "sameness": "My days feel the same",
        "later": "I keep waiting for later"
    ]

    private static let aliveAnswers = [
        "making": "Making something",
        "outside": "Outside somewhere",
        "people": "With people I love",
        "movement": "Moving my body",
        "learning": "Learning something",
        "solitude": "Alone and unhurried",
        "helping": "Helping someone",
        "story": "Lost in a story"
    ]

    private static let magicAnswers = [
        "music": "Music landing just right",
        "weather": "Wild weather",
        "places": "Places with a charge",
        "coincidence": "Strange coincidences",
        "details": "Tiny beautiful details",
        "laughter": "Making someone laugh",
        "imagination": "Dreams and imagination",
        "love": "People I love",
        "unsure": "I'm not sure yet"
    ]

    private static let appetiteAnswers = [
        "letters": "Letters and voices",
        "errands": "Strange errands",
        "cozy": "Cozy noticing",
        "weather-place": "Weather and place",
        "eerie": "Eerie story threads",
        "oddities": "Funny little oddities"
    ]

    private static let edgeAnswers = [
        "gentle": "Invite me",
        "balanced": "Nudge me",
        "strange": "Call me on my nonsense"
    ]

    /// The explanations come only from harmless authored choices. The sheet
    /// rotates this pool on each presentation, while the two real prices remain
    /// identical for every reader.
    private static func offerReasons(
        hiddenMagicStance: String,
        magicSource: String,
        tastePreference: String,
        chapterName: String,
        sleeveWord: String,
        wickerRollSucceeded: Bool
    ) -> [String] {
        var reasons: [String] = []

        if hiddenMagicStance == "prove" {
            reasons.append("You said, “Show me.” Fair. That's the excuse I wrote in the margin: give you time to gather evidence.")
        }

        if chapterName.caseInsensitiveCompare("Duskthorn") == .orderedSame {
            reasons.append("You chose Duskthorn. It's my favorite argument: beauty's allowed to defend itself. Obviously that's the excuse I put on the form.")
        } else if !chapterName.isEmpty {
            reasons.append("You gave \(chapterName) the first word. The Chapter volunteered to be the official excuse for this welcome.")
        }

        switch tastePreference {
        case "letters":
            reasons.append("You asked for letters and voices. One volunteered to carry this welcome to you.")
        case "errands":
            reasons.append("You asked for strange errands. The clerk insists considering this welcome counts as one.")
        case "cozy":
            reasons.append("You asked me to begin gently. Even a welcome offer can take the hint.")
        case "weather-place":
            reasons.append("You asked for weather and places. A favorable wind delivered this welcome.")
        case "eerie":
            reasons.append("You asked for eerie story threads. One got into Accounting and circled this welcome in violet.")
        case "oddities":
            reasons.append("You gave funny little oddities permission to enter. The clerk says this welcome qualifies.")
        default:
            break
        }

        switch magicSource {
        case "details":
            reasons.append("You notice tiny beautiful details. A First Door welcome is a small detail with excellent timing.")
        case "music":
            reasons.append("You said magic starts when the music lands just right. This welcome arrived on the downbeat.")
        case "coincidence":
            reasons.append("You believe strange coincidences might count. Conveniently, this welcome would like to be one.")
        case "unsure":
            reasons.append("You didn't pretend to believe. I respect a reader with terms, so that's the excuse I chose.")
        default:
            break
        }

        let trimmedWord = sleeveWord.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedWord.isEmpty {
            reasons.append("You carried \(trimmedWord.uppercased()) through the First Door. The Bindery filed it as the official excuse for this welcome.")
        }

        if wickerRollSucceeded {
            reasons.append("You won Wicker's little challenge. He denies that's why this welcome found you. The ledger disagrees.")
        }

        if reasons.count < 2 {
            reasons.append("You gave me one honest answer before I asked for anything. The Bindery noticed.")
        }
        if reasons.count < 2 {
            reasons.append("You made it through the First Door. The clerk reluctantly counted that as advance payment.")
        }
        return reasons
    }
}

/// A disclosure-forward, four-page subscription walkthrough — a contract letter
/// from the Bindery rather than an ad in a box. Free capabilities first, then
/// what the Standing Order adds, then the two cadences (monthly/annual), then
/// the terms in plain ink with exact dates, a cancel path, and Restore. Trial
/// language appears only when StoreKit confirms this reader is eligible (or
/// when the debug-only local counter is standing in for StoreKit). Reuses
/// `BookShopTill`/`StoreKitMerchant` so a tap runs the same purchase +
/// entitlement path as the goblin market.
struct StandingOrderSheet: View {
    private enum BargainStrikeStage: Equatable {
        case idle
        case sealing
        case ready
        case opening
    }

    var personalization: StandingOrderPersonalization = .empty
    /// Persist the granted packID (always the Standing Order pack).
    var onSubscribed: (String) -> Void
    /// Marks a newly purchased Standing Order. Restore deliberately doesn't
    /// call this, because restoring an old promise isn't striking a new one.
    var onBargainStruck: () -> Void = {}
    var onDismiss: () -> Void
    var onBrowsePacks: () -> Void = {}
    /// Opens the same in-app subscription ledger used by Glow. The paywall
    /// explains both shapes; neither should become a dead end when chosen.
    var onOpenBoundYear: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0
    @State private var pageDirection = 1
    @State private var selectedTierID = "standing-order-annual"
    /// What the reader is choosing between *first*: what they get, not how
    /// often they are billed. Billing cadence is the least interesting question
    /// on this screen and it used to be the first one asked.
    @State private var chosenShape: PlanShape?

    enum PlanShape: String, Equatable {
        /// Everything the Book does, in the Book. Sold here, through Apple.
        case digital
        /// The same, plus printed volumes in the post. Paid through Stripe in
        /// the Bindery because Apple requires physical goods not to use IAP.
        case printed
    }
    @State private var pricing: [String: StandingOrderTierPricing] = [:]
    @State private var usesDevelopmentTrialFallback = false
    @State private var reminderAuthorization: StandingOrderTrialReminder.AuthorizationState = .unavailable
    @State private var isPurchasing = false
    @State private var statusLine = ""
    @State private var isLivingBookAwake = false
    @State private var isOwnershipSealOpen = false
    @State private var bargainStrikeStage: BargainStrikeStage = .idle
    /// A fresh sheet presentation rotates which harmless onboarding answer the
    /// Book cites on each plan. Stable while this sheet remains open.
    @State private var offerReasonNonce = UUID()

    private let pageCount = 3
    private let tiers = BookShopCatalog.standingOrderTiers

    private var selectedTier: StandingOrderTier {
        tiers.first { $0.id == selectedTierID } ?? tiers[tiers.count - 1]
    }

    private func priceText(for tier: StandingOrderTier) -> String {
        pricing[tier.productID]?.displayPrice ?? tier.fallbackDisplayPrice
    }

    private func valueNote(for tier: StandingOrderTier) -> String? {
        guard tier.cadence == .annual,
              let monthlyTier = tiers.first(where: { $0.cadence == .monthly }),
              let monthlyPrice = pricing[monthlyTier.productID]?.price,
              let annualPrice = pricing[tier.productID]?.price else {
            return tier.valueNote
        }
        let twelveMonths = monthlyPrice * Decimal(12)
        guard twelveMonths > annualPrice, twelveMonths > 0 else { return tier.valueNote }
        let percent = NSDecimalNumber(
            decimal: ((twelveMonths - annualPrice) / twelveMonths) * Decimal(100)
        ).doubleValue
        return "Save \(Int(percent.rounded()))%"
    }

    private func trialDays(for tier: StandingOrderTier) -> Int? {
        if let liveTerms = pricing[tier.productID] {
            return liveTerms.trialDays
        }
        #if DEBUG
        if usesDevelopmentTrialFallback {
            return tier.freeTrialDays
        }
        #endif
        return nil
    }

    private func purchaseButtonTitle(for tier: StandingOrderTier) -> String {
        if let days = trialDays(for: tier) {
            return "Start \(days)-day free trial"
        }
        guard pricing[tier.productID] != nil else {
            return "Continue with Apple"
        }
        return "Subscribe · \(priceText(for: tier)) / \(tier.periodUnit)"
    }

    var body: some View {
        ZStack {
            BookBackground()
                .overlay { Rectangle().fill(BookPalette.nightPanel.opacity(0.5)) }
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            Color.clear
                                .frame(height: 1)
                                .id("standing-order-page-top")

                            Group {
                                switch page {
                                case 0: freePage
                                case 1: addsPage
                                default: plansPage
                                }
                            }
                            .id(page)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 18)
                            .transition(standingOrderPageTransition)
                        }
                    }
                    .onChange(of: page) { _, _ in
                        DispatchQueue.main.async {
                            scrollProxy.scrollTo("standing-order-page-top", anchor: .top)
                        }
                    }
                }
                footer
            }

            if bargainStrikeStage != .idle {
                bargainStrikeOverlay
                    .transition(.opacity.combined(with: .scale(scale: 1.03)))
                    .zIndex(20)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: page)
        .interactiveDismissDisabled(bargainStrikeStage != .idle)
        .task {
            async let loadedPricing = StandingOrderPricing.load()
            async let loadedAuthorization = StandingOrderTrialReminder.authorizationState()
            let (loaded, authorization) = await (loadedPricing, loadedAuthorization)
            reminderAuthorization = authorization
            #if DEBUG
            usesDevelopmentTrialFallback = loaded.isEmpty
            #endif
            if !loaded.isEmpty {
                withAnimation { pricing = loaded }
            }
        }
    }

    private var bargainStrikeOverlay: some View {
        ZStack {
            BookPalette.nightPanel
                .overlay {
                    RadialGradient(
                        colors: [
                            BookPalette.violet.opacity(0.42),
                            BookPalette.nightPanel.opacity(0.16),
                            BookPalette.ink.opacity(0.72)
                        ],
                        center: .center,
                        startRadius: 24,
                        endRadius: 420
                    )
                }
                .ignoresSafeArea()

            ForEach(0..<12, id: \.self) { index in
                Image(systemName: index.isMultiple(of: 3) ? "sparkle" : "diamond.fill")
                    .font(.system(size: index.isMultiple(of: 3) ? 15 : 6, weight: .black))
                    .foregroundStyle(index.isMultiple(of: 2) ? BookPalette.lampGold : BookPalette.teal)
                    .rotationEffect(.degrees(Double(index) * 31))
                    .offset(
                        x: bargainSparkOffset(index: index, horizontal: true),
                        y: bargainSparkOffset(index: index, horizontal: false)
                    )
                    .opacity(bargainStrikeStage == .sealing ? 0.28 : 0.88)
                    .scaleEffect(bargainStrikeStage == .opening ? 1.5 : 1)
            }

            VStack(spacing: 22) {
                bargainBookSeal

                VStack(spacing: 8) {
                    Text(bargainStrikeKicker)
                        .font(.system(size: 11, weight: .black))
                        .tracking(1.4)
                        .foregroundStyle(BookPalette.lampGold)

                    Text(bargainStrikeTitle)
                        .font(.system(.largeTitle, design: .serif).weight(.black))
                        .foregroundStyle(BookPalette.nightText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(bargainStrikeBody)
                        .font(.system(.body, design: .serif).weight(.semibold))
                        .foregroundStyle(BookPalette.nightText.opacity(0.82))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8)
                }

                if bargainStrikeStage == .ready {
                    Button {
                        openStruckBargain()
                    } label: {
                        Label("Open into my story", systemImage: "book.pages.fill")
                            .font(.body.weight(.black))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(BookPalette.lampGold, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                            .foregroundStyle(BookPalette.ink)
                    }
                    .buttonStyle(.plain)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if bargainStrikeStage == .sealing {
                    Label("The ink is learning your name…", systemImage: "signature")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BookPalette.teal)
                } else {
                    Label("I'm keeping my side.", systemImage: "door.left.hand.open")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BookPalette.teal)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 32)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(bargainStrikeTitle). \(bargainStrikeBody)")
    }

    private var bargainBookSeal: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(BookPalette.page)
                .frame(width: 148, height: 198)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(BookPalette.lampGold.opacity(0.20))
                        .frame(width: 7)
                        .padding(.vertical, 8)
                }
                .overlay {
                    VStack(spacing: 8) {
                        Text("THE STANDING ORDER")
                            .font(.system(size: 8, weight: .black))
                            .tracking(1)
                            .foregroundStyle(BookPalette.ink.opacity(0.72))
                        Image(systemName: "leaf.fill")
                            .font(.title2.weight(.black))
                            .foregroundStyle(BookPalette.violet)
                        Text("A PROMISE\nFOR A PROMISE")
                            .font(.system(size: 8, weight: .black, design: .serif))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(BookPalette.ink.opacity(0.76))
                    }
                }
                .shadow(color: BookPalette.lampGold.opacity(0.28), radius: 24, y: 12)

            Image("EnchantedBookCoverPlate")
                .resizable()
                .scaledToFill()
                .frame(width: 148, height: 198)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(BookPalette.lampGold.opacity(0.72), lineWidth: 1.4)
                }
                .rotation3DEffect(
                    .degrees(bargainStrikeStage == .opening ? -82 : 0),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: .leading,
                    perspective: 0.55
                )
                .offset(x: bargainStrikeStage == .opening ? -64 : 0)
                .shadow(color: BookPalette.violet.opacity(0.42), radius: 28, y: 12)

            if bargainStrikeStage != .opening {
                ZStack {
                    Circle()
                        .fill(BookPalette.violet)
                    Circle()
                        .stroke(BookPalette.lampGold, lineWidth: 2)
                        .padding(5)
                    Image(systemName: "seal.fill")
                        .font(.title2.weight(.black))
                        .foregroundStyle(BookPalette.lampGold)
                }
                .frame(width: 66, height: 66)
                .offset(y: 55)
                .scaleEffect(bargainStrikeStage == .sealing ? 1.16 : 1)
                .shadow(color: BookPalette.violet.opacity(0.48), radius: 14, y: 8)
            }
        }
        .frame(height: 220)
        .animation(
            reduceMotion ? nil : .spring(response: 0.85, dampingFraction: 0.68),
            value: bargainStrikeStage
        )
        .accessibilityHidden(true)
    }

    private var bargainStrikeKicker: String {
        switch bargainStrikeStage {
        case .sealing: return "SIGNING"
        case .ready: return "A PROMISE FOR A PROMISE"
        case .opening: return "THE COVER OPENS"
        case .idle: return ""
        }
    }

    private var bargainStrikeTitle: String {
        switch bargainStrikeStage {
        case .sealing: return "The bargain is struck."
        case .ready: return "I give my word."
        case .opening: return "Your story continues."
        case .idle: return ""
        }
    }

    private var bargainStrikeBody: String {
        switch bargainStrikeStage {
        case .sealing:
            return "You made me a promise. I'm writing one back, which is more than most receipts do."
        case .ready:
            return "New doors, new voices, new mysteries — and from here on they remember what you choose."
        case .opening:
            return "Somewhere a faerie is re-reading the terms, annoyed. I couldn't care less. Come in."
        case .idle:
            return ""
        }
    }

    private func bargainSparkOffset(index: Int, horizontal: Bool) -> CGFloat {
        let angle = Double(index) * (.pi * 2 / 12) - .pi / 2
        let radius = bargainStrikeStage == .opening ? 176.0 : 132.0
        return CGFloat((horizontal ? cos(angle) : sin(angle)) * radius)
    }

    @MainActor
    private func strikeBargain() async {
        statusLine = ""
        withAnimation(reduceMotion ? nil : .spring(response: 0.58, dampingFraction: 0.72)) {
            bargainStrikeStage = .sealing
        }
        BookFeedback.play(.braidComplete)
        try? await Task.sleep(for: .milliseconds(reduceMotion ? 350 : 1_150))
        withAnimation(reduceMotion ? nil : .spring(response: 0.62, dampingFraction: 0.76)) {
            bargainStrikeStage = .ready
        }
        BookFeedback.play(.keepPage)
    }

    private func openStruckBargain() {
        guard bargainStrikeStage == .ready else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.82)) {
            bargainStrikeStage = .opening
        }
        BookFeedback.play(.openPage)
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.45 : 1.25)) {
            onDismiss()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "books.vertical.fill")
                .font(.title3.weight(.black))
                .foregroundStyle(BookPalette.lampGold)
            VStack(alignment: .leading, spacing: 1) {
                Text("YOUR STORY · THE BARGAIN")
                    .font(.system(size: 12, weight: .black))
                    .tracking(1.4)
                    .foregroundStyle(BookPalette.lampGold)
                Text(
                    personalization.readerName.isEmpty
                        ? "The Standing Order · A letter from the Bindery"
                        : "The Standing Order · A letter for \(personalization.readerName)"
                )
                    .font(.system(.subheadline, design: .serif).weight(.semibold))
                    .foregroundStyle(BookPalette.nightText.opacity(0.8))
            }
            Spacer(minLength: 0)
            Button {
                BookFeedback.play(.dismissPage)
                onDismiss()
            } label: {
                Text("Not now")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(BookPalette.nightText.opacity(0.7))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            if !statusLine.isEmpty {
                Text(statusLine)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(BookPalette.nightText.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 22)
            }

            HStack(spacing: 6) {
                ForEach(0..<pageCount, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? BookPalette.lampGold : BookPalette.nightText.opacity(0.3))
                        .frame(width: index == page ? 20 : 7, height: 6)
                }
            }

            Text("Pay or don't. Either way you keep me, and everything you make in me.")
                .font(.system(.callout, design: .serif).weight(.semibold))
                .foregroundStyle(BookPalette.nightText.opacity(0.74))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 22)

            HStack(spacing: 10) {
                if page > 0 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            pageDirection = -1
                            page -= 1
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.black))
                            .frame(width: 52, height: 50)
                            .background(BookPalette.paper.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .foregroundStyle(BookPalette.nightText)
                    }
                }

                if page < pageCount - 1 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            pageDirection = 1
                            page += 1
                        }
                        BookFeedback.play(.openPage)
                    } label: {
                        Text(nextPageButtonTitle)
                            .font(.body.weight(.black))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(BookPalette.teal, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .foregroundStyle(BookPalette.nightText)
                    }
                } else if chosenShape == .digital {
                    // Only offered once they have chosen the shape this button
                    // actually buys. Before that it would sell the digital
                    // subscription to someone reading about the printed one.
                    Button {
                        Task { await subscribe() }
                    } label: {
                        Label(
                            isPurchasing ? "Opening the ledger…" : purchaseButtonTitle(for: selectedTier),
                            systemImage: isPurchasing ? "hourglass" : "seal.fill"
                        )
                        .font(.body.weight(.black))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(BookPalette.lampGold, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .foregroundStyle(BookPalette.ink)
                    }
                    .disabled(isPurchasing)
                } else if chosenShape == .printed {
                    Button {
                        BookFeedback.play(.openPage)
                        onOpenBoundYear()
                    } label: {
                        Label("Open the Bound Year", systemImage: "shippingbox.fill")
                            .font(.body.weight(.black))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(BookPalette.lampGold, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .foregroundStyle(BookPalette.ink)
                    }
                }
            }
            .padding(.horizontal, 22)
        }
        .padding(.bottom, 18)
    }

    private var nextPageButtonTitle: String {
        switch page {
        case 0: return "So what costs money?"
        default: return "See the price"
        }
    }

    private var standingOrderPageTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let incoming: Edge = pageDirection >= 0 ? .trailing : .leading
        let outgoing: Edge = pageDirection >= 0 ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: incoming).combined(with: .opacity),
            removal: .move(edge: outgoing).combined(with: .opacity)
        )
    }

    // MARK: Page 1 — the free Book

    private var freePage: some View {
        VStack(alignment: .leading, spacing: 19) {
            pageTitle(
                personalization.readerName.isEmpty
                    ? "That was the free Book."
                    : "\(personalization.readerName), that was the free Book.",
                subtitle: "Everything you just did — all of it is free, and it stays free. Here's what I heard, and then one honest ask."
            )

            bargainStoryCard

            if personalization.hasReaderMap {
                readerMapCard
            }

            ownershipSealCard
        }
    }

    private var bargainStoryCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            Label("THE PART WHERE THERE'S A PRICE", systemImage: "scroll.fill")
                .font(.system(size: 12, weight: .black))
                .tracking(0.8)
                .foregroundStyle(BookPalette.lampGold)

            Text("In every good story, the magic turns out to cost something.")
                .font(.system(.title3, design: .serif).weight(.bold))
                .foregroundStyle(BookPalette.nightText)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Text("This is a small one.")
                .font(.body.weight(.black))
                .foregroundStyle(BookPalette.lampGold)

            Text("You don't pay to use me. You'd be paying to keep new story arriving in me — and only if you want to.")
                .font(.system(.body, design: .serif))
                .foregroundStyle(BookPalette.nightText.opacity(0.88))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 3)
        }
        .padding(17)
        .background(
            // Both stops have to stay opaque enough to carry light text. The
            // violet end was at 0.18, so the bottom of the card was very nearly
            // transparent and `nightText` cream was landing on the pale page
            // behind it — the copy from "This is a small one." down was
            // effectively invisible.
            LinearGradient(
                colors: [
                    BookPalette.nightPanel.opacity(0.94),
                    BookPalette.violet.opacity(0.90)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.38), lineWidth: 1)
        }
    }

    private var ownershipSealCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                BookFeedback.play(isOwnershipSealOpen ? .dismissPage : .keepPage)
                withAnimation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.76)) {
                    isOwnershipSealOpen.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(BookPalette.violet)
                        Circle()
                            .stroke(BookPalette.lampGold, lineWidth: 1.6)
                            .padding(5)
                        Image(systemName: isOwnershipSealOpen ? "checkmark.seal.fill" : "seal.fill")
                            .font(.title3.weight(.black))
                            .foregroundStyle(BookPalette.lampGold)
                    }
                    .frame(width: 50, height: 50)
                    .scaleEffect(isOwnershipSealOpen ? 0.92 : 1)
                    .rotationEffect(.degrees(isOwnershipSealOpen && !reduceMotion ? -6 : 0))
                    .shadow(color: BookPalette.violet.opacity(0.42), radius: 10, y: 6)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("A PROMISE, IN WRITING")
                            .font(.system(size: 11, weight: .black))
                            .tracking(0.8)
                            .foregroundStyle(BookPalette.lampGold)
                        Text("I stay yours, and so does everything you make in me.")
                            .font(.system(.body, design: .serif).weight(.bold))
                            .foregroundStyle(BookPalette.nightText)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(isOwnershipSealOpen ? "Here's what that means." : "Tap the seal for what that means.")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(BookPalette.nightText.opacity(0.72))
                    }

                    Spacer(minLength: 0)

                    Image(systemName: isOwnershipSealOpen ? "chevron.up" : "chevron.down")
                        .font(.body.weight(.black))
                        .foregroundStyle(BookPalette.teal)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("A promise, in writing. I stay yours, and so does everything you make in me.")
            .accessibilityValue(isOwnershipSealOpen ? "Open" : "Closed")
            .accessibilityHint(isOwnershipSealOpen ? "Closes the promise" : "Opens the promise and explains what remains yours")

            if isOwnershipSealOpen {
                Divider()
                    .overlay(BookPalette.lampGold.opacity(0.34))
                    .transition(.opacity)

                freeLoopCard
                    .transition(.move(edge: .top).combined(with: .opacity))

                ownershipPromiseLine(
                    "checkmark.seal.fill",
                    "THE WHOLE LOOP IS FREE",
                    "Notice your life, keep what matters, read what comes back, and bind it into your own monthly and yearly books."
                )

                ownershipPromiseLine(
                    "lock.shield.fill",
                    "NOTHING GETS TAKEN BACK",
                    "Your pages and your editions stay put whether you never subscribe, or subscribe once and stop."
                )

                Text("No trial. No card. No catch.")
                    .font(.body.weight(.black))
                    .foregroundStyle(BookPalette.teal)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .transition(.opacity)
            }
        }
        .padding(17)
        .background(
            LinearGradient(
                colors: [
                    BookPalette.violet.opacity(0.16),
                    BookPalette.nightPanel.opacity(0.88),
                    BookPalette.teal.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isOwnershipSealOpen
                        ? BookPalette.lampGold.opacity(0.58)
                        : BookPalette.teal.opacity(0.30),
                    lineWidth: isOwnershipSealOpen ? 1.4 : 1
                )
        }
    }

    private func ownershipPromiseLine(
        _ symbol: String,
        _ title: String,
        _ body: String
    ) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: symbol)
                .font(.callout.weight(.black))
                .foregroundStyle(BookPalette.lampGold)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: .black))
                    .tracking(0.6)
                    .foregroundStyle(BookPalette.nightText.opacity(0.72))
                Text(body)
                    .font(.system(.body, design: .serif).weight(.semibold))
                    .foregroundStyle(BookPalette.nightText.opacity(0.84))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Page 2 — what the Standing Order adds

    private var addsPage: some View {
        VStack(alignment: .leading, spacing: 19) {
            pageTitle(
                "Anything can turn into wallpaper.",
                subtitle: "Show someone the same pages and the same voices long enough and they stop looking. That's the whole thing I'm trying to beat — so it can't be allowed to stand still."
            )

            livingBookHero

            benefitRow(
                "theatermasks.fill",
                "A story that keeps going",
                "Not a pile of random scenes. One continuing story, arriving in new chapters every month, with characters who remember you, mysteries that take months to open, and choices that come back around a year later. The first campaign is already plotted through December 2027.",
                emphasized: true
            )

            livingStoryScheduleCard

            benefitRow(
                "sparkles.rectangle.stack",
                "Something new every month",
                "New pages, places, people, rituals, music, and things nobody warned you about."
            )

            if personalization.hasStoryDirection {
                personalizedStoryDirectionCard
            }

            VStack(alignment: .leading, spacing: 9) {
                Text("So what's the money for?")
                    .font(.system(.title3, design: .serif).weight(.bold))
                    .foregroundStyle(BookPalette.nightText)
                Text("Not storage. Not your memories. Not permission to open the app.")
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(BookPalette.nightText.opacity(0.84))
                    .fixedSize(horizontal: false, vertical: true)
                Text("It's for new story. That's it.")
                    .font(.body.weight(.black))
                    .foregroundStyle(BookPalette.lampGold)
                    .padding(.top, 3)
            }
            .padding(17)
            .background(BookPalette.nightPanel.opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(BookPalette.lampGold.opacity(0.36), lineWidth: 1)
            }
        }
    }

    private var livingStoryScheduleCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            Label("THE FIRST ONE IS ALREADY WRITTEN", systemImage: "calendar.badge.checkmark")
                .font(.system(size: 12, weight: .black))
                .tracking(0.7)
                .foregroundStyle(BookPalette.lampGold)

            Text("September 2026 → December 2027")
                .font(.system(.title3, design: .serif).weight(.black))
                .foregroundStyle(BookPalette.nightText)

            Text("Sixteen months that belong together. The Dictionary Rebellion opens it in September. At Imbolc the Thorned Bargain starts closing around everyone, and it doesn't finish with you until the end of the following year.")
                .font(.system(.body, design: .serif).weight(.semibold))
                .foregroundStyle(BookPalette.nightText.opacity(0.86))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Text("Plotted in advance, but not on rails. The skeleton is written through December 2027 and it will change as it meets you — what you keep, and the weather and season outside your window, decide which doors open. Only ever using what you've said I can use.")
                .font(.system(.body, design: .serif))
                .foregroundStyle(BookPalette.nightText.opacity(0.80))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                storyMonth("SEP '26", symbol: "door.left.hand.open")
                storyMonthArrow
                storyMonth("FEB '27", symbol: "moon.stars.fill")
                storyMonthArrow
                storyMonth("AUG '27", symbol: "point.topleft.down.to.point.bottomright.curvepath")
                storyMonthArrow
                storyMonth("DEC '27", symbol: "seal.fill")
            }
        }
        .padding(17)
        .background(
            LinearGradient(
                colors: [
                    BookPalette.violet.opacity(0.92),
                    BookPalette.nightPanel.opacity(0.94),
                    BookPalette.violet.opacity(0.88)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.42), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private func storyMonth(_ month: String, symbol: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.callout.weight(.black))
                .foregroundStyle(BookPalette.lampGold)
            Text(month)
                .font(.system(size: 11, weight: .black))
                .tracking(0.5)
                .foregroundStyle(BookPalette.nightText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(BookPalette.paper.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var storyMonthArrow: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 9, weight: .black))
            .foregroundStyle(BookPalette.teal)
            .accessibilityHidden(true)
    }

    private var readerMapCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 10) {
                Image(systemName: "seal.fill")
                    .font(.callout.weight(.black))
                    .foregroundStyle(BookPalette.ink)
                    .frame(width: 34, height: 34)
                    .background(BookPalette.lampGold, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("WHAT THE BOOK HEARD")
                        .font(.system(size: 11, weight: .black))
                        .tracking(0.9)
                        .foregroundStyle(BookPalette.lampGold)
                    Text("No profile, no prediction. Just your own words, kept.")
                        .font(.system(.callout, design: .serif).weight(.semibold))
                        .foregroundStyle(BookPalette.nightText.opacity(0.80))
                }
            }

            if !personalization.rutAnswer.isEmpty {
                readerMapRow(
                    "cloud.fog.fill",
                    "Where the Rut gets in",
                    personalization.rutAnswer
                )
            }
            if !personalization.aliveAnswer.isEmpty {
                readerMapRow(
                    "waveform.path.ecg",
                    "Where life wakes up",
                    personalization.aliveAnswer
                )
            }
            if !personalization.magicAnswer.isEmpty {
                readerMapRow(
                    "sparkles",
                    "What feels magical",
                    personalization.magicAnswer
                )
            }
        }
        .padding(17)
        .background {
            ZStack {
                Image("ParchmentFiber")
                    .resizable()
                    .scaledToFill()
                    .opacity(0.16)
                BookPalette.nightPanel.opacity(0.88)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.38), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.22), radius: 12, y: 7)
        .rotationEffect(.degrees(reduceMotion ? 0 : -0.35))
    }

    private func readerMapRow(_ symbol: String, _ title: String, _ answer: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: symbol)
                .font(.callout.weight(.black))
                .foregroundStyle(BookPalette.lampGold)
                .frame(width: 25, height: 25)
            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .black))
                    .tracking(0.6)
                    .foregroundStyle(BookPalette.nightText.opacity(0.68))
                Text(answer)
                    .font(.system(.body, design: .serif).weight(.semibold))
                    .foregroundStyle(BookPalette.nightText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var freeLoopCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("FREE, ALL OF IT")
                .font(.system(size: 12, weight: .black))
                .tracking(1.0)
                .foregroundStyle(BookPalette.teal)

            HStack(spacing: 5) {
                loopStep("eye.fill", "NOTICE")
                loopArrow
                loopStep("bookmark.fill", "KEEP")
                loopArrow
                loopStep("arrow.uturn.backward", "RETURN")
                loopArrow
                loopStep("books.vertical.fill", "BIND")
            }
        }
        .padding(14)
        .background(BookPalette.page.opacity(0.46), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(BookPalette.teal.opacity(0.34), lineWidth: 1)
        }
    }

    private func loopStep(_ symbol: String, _ title: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.callout.weight(.black))
                .foregroundStyle(BookPalette.ink)
                .frame(width: 34, height: 34)
                .background(BookPalette.teal.opacity(0.92), in: Circle())
            Text(title)
                .font(.system(size: 9, weight: .black))
                .tracking(0.4)
                .foregroundStyle(BookPalette.nightText.opacity(0.76))
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var loopArrow: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 8, weight: .black))
            .foregroundStyle(BookPalette.lampGold.opacity(0.72))
            .accessibilityHidden(true)
    }

    private var livingBookHero: some View {
        HStack(spacing: 10) {
            VStack(spacing: 8) {
                Text("THE SAME TRICK")
                    .font(.system(size: 11, weight: .black))
                    .tracking(0.8)
                    .foregroundStyle(BookPalette.nightText.opacity(0.62))

                ZStack {
                    ForEach(0..<3, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(BookPalette.nightText.opacity(0.08 + Double(index) * 0.025))
                            .overlay {
                                VStack(spacing: 6) {
                                    Capsule()
                                        .fill(BookPalette.nightText.opacity(0.15))
                                        .frame(width: 42, height: 4)
                                    Capsule()
                                        .fill(BookPalette.nightText.opacity(0.10))
                                        .frame(width: 54, height: 3)
                                    Capsule()
                                        .fill(BookPalette.nightText.opacity(0.10))
                                        .frame(width: 46, height: 3)
                                }
                            }
                            .frame(width: 82, height: 112)
                            .rotationEffect(.degrees(Double(index - 1) * 3))
                            .offset(x: CGFloat(index - 1) * 3)
                    }
                    Image(systemName: "cloud.fog.fill")
                        .font(.title2.weight(.black))
                        .foregroundStyle(BookPalette.nightText.opacity(0.30))
                }
            }
            .frame(maxWidth: .infinity)

            Image(systemName: "arrow.right")
                .font(.headline.weight(.black))
                .foregroundStyle(BookPalette.lampGold)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("A LIVING BOOK")
                    .font(.system(size: 11, weight: .black))
                    .tracking(0.8)
                    .foregroundStyle(BookPalette.lampGold)

                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(BookPalette.teal.opacity(0.50))
                        .frame(width: 76, height: 106)
                        .rotationEffect(.degrees(isLivingBookAwake ? -10 : 0), anchor: .bottom)
                        .offset(x: isLivingBookAwake ? -18 : 0, y: 3)
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(BookPalette.violet.opacity(0.54))
                        .frame(width: 76, height: 106)
                        .rotationEffect(.degrees(isLivingBookAwake ? 10 : 0), anchor: .bottom)
                        .offset(x: isLivingBookAwake ? 18 : 0, y: 3)

                    Image("EnchantedBookCoverPlate")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 82, height: 116)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(BookPalette.lampGold.opacity(0.66), lineWidth: 1)
                        }
                        .shadow(color: BookPalette.lampGold.opacity(0.24), radius: 12, y: 7)

                    ForEach(0..<4, id: \.self) { index in
                        Image(systemName: "sparkle")
                            .font(.system(size: index.isMultiple(of: 2) ? 12 : 8, weight: .black))
                            .foregroundStyle(index.isMultiple(of: 2) ? BookPalette.lampGold : BookPalette.teal)
                            .offset(
                                x: isLivingBookAwake ? (index < 2 ? -52 : 52) : 0,
                                y: isLivingBookAwake ? (index.isMultiple(of: 2) ? -38 : 36) : 0
                            )
                            .opacity(isLivingBookAwake ? 1 : 0)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [
                    BookPalette.nightPanel.opacity(0.82),
                    BookPalette.violet.opacity(0.13),
                    BookPalette.nightPanel.opacity(0.88)
                ],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.28), lineWidth: 1)
        }
        .overlay(alignment: .bottom) {
            Label("Tap to wake me again", systemImage: "hand.tap")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(BookPalette.nightText.opacity(0.76))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(BookPalette.nightPanel.opacity(0.82), in: Capsule())
                .offset(y: -6)
        }
        .padding(.bottom, 2)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture {
            BookFeedback.play(.openPage)
            guard !reduceMotion else {
                isLivingBookAwake = true
                return
            }
            withAnimation(.easeOut(duration: 0.12)) {
                isLivingBookAwake = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                withAnimation(.spring(response: 0.72, dampingFraction: 0.68)) {
                    isLivingBookAwake = true
                }
            }
        }
        .onAppear {
            guard !reduceMotion else {
                isLivingBookAwake = true
                return
            }
            isLivingBookAwake = false
            withAnimation(.spring(response: 0.72, dampingFraction: 0.68).delay(0.18)) {
                isLivingBookAwake = true
            }
        }
        .onDisappear {
            isLivingBookAwake = false
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("The same repeated pages fade grey. A living Book opens into fresh colored folios and sparks.")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Wakes the living Book animation")
    }

    private var personalizedStoryDirectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("WHAT YOU ALREADY TOLD IT", systemImage: "pencil.and.scribble")
                .font(.system(size: 12, weight: .black))
                .tracking(0.7)
                .foregroundStyle(BookPalette.teal)

            if !personalization.appetiteAnswer.isEmpty {
                directionRow(
                    "rectangle.stack.badge.play",
                    "Bring this first",
                    personalization.appetiteAnswer
                )
            }
            if !personalization.edgeAnswer.isEmpty {
                directionRow(
                    "slider.horizontal.3",
                    "How hard to press",
                    personalization.edgeAnswer
                )
            }
            if !personalization.chapterName.isEmpty {
                directionRow(
                    "flag.2.crossed.fill",
                    "Your first argument",
                    personalization.chapterName
                )
            }

            Text("Subscribing doesn't overwrite any of that. It just gives your answers more story to push around.")
                .font(.system(.body, design: .serif).weight(.semibold))
                .foregroundStyle(BookPalette.nightText.opacity(0.82))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 3)
        }
        .padding(17)
        .background(BookPalette.teal.opacity(0.09), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(BookPalette.teal.opacity(0.30), lineWidth: 1)
        }
    }

    private func directionRow(_ symbol: String, _ label: String, _ answer: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.callout.weight(.black))
                .foregroundStyle(BookPalette.lampGold)
                .frame(width: 22)
            Text(label)
                .font(.callout.weight(.bold))
                .foregroundStyle(BookPalette.nightText.opacity(0.70))
            Spacer(minLength: 6)
            Text(answer)
                .font(.callout.weight(.black))
                .foregroundStyle(BookPalette.nightText)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Page 3 — the price, and exactly what happens

    /// The printed membership, explained here and opened through the same
    /// subscription ledger as the Glow menu.
    ///
    /// Two problems this solves, and the second is the expensive one.
    ///
    /// **It must not read as a third rung.** Three options on one screen get
    /// read as small, medium and large of the same thing — and then the one
    /// that behaves differently looks like the premium tier. It is not a bigger
    /// Standing Order. It is a different category that happens to contain one:
    /// this page sells what the Book *does*; the Bound Year posts what it
    /// *prints*.
    ///
    /// **And it must say that it contains this.** A reader who buys the annual
    /// and discovers a month later that the printed membership already included
    /// it will feel sold to, correctly. Saying so here costs a little clarity
    /// on this screen and buys back all of it later. Hiding it is the confusing
    /// option, not the tidy one.
    ///
    /// Physical goods are outside in-app purchase by Apple's own rule. The
    /// footer opens the Bindery's Stripe path rather than trying to sell this
    /// shape through the Standing Order's App Store button.
    private var boundYearNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("There's another way to have me, and it comes by post.", systemImage: "shippingbox")
                .font(.system(.callout, design: .serif).weight(.bold))
                .foregroundStyle(BookPalette.nightText.opacity(0.9))

            Text("The Bound Year is $24.99 a month or $249 a year. It prints you three seasons in softcover and the year itself in cloth and foil. It carries everything on this page inside it, so nobody sensible buys both. The Bindery takes payment for the parcels without sending you out of the Book.")
                .font(.footnote)
                .foregroundStyle(BookPalette.nightText.opacity(0.66))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Text("Not a bigger version of this. A different thing that happens to include it.")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(BookPalette.lampGold.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BookPalette.paper.opacity(0.24), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.22), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private func planShapeCard(_ shape: PlanShape) -> some View {
        Button {
            BookFeedback.play(.select)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { chosenShape = shape }
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                Label(
                    shape == .printed ? "The Book, printed and posted" : "Just the Book",
                    systemImage: shape == .printed ? "shippingbox.fill" : "book.closed.fill"
                )
                .font(.system(.title3, design: .serif).weight(.bold))
                .foregroundStyle(BookPalette.nightText)

                Text(shape == .printed
                     ? "Three seasons in softcover, the year in cloth and foil, and everything below it besides. Posted to your door."
                     : "Every paid page, every month, the whole continuing story. It lives in here and nowhere else.")
                    .font(.footnote)
                    .foregroundStyle(BookPalette.nightText.opacity(0.68))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(15)
            .background(
                (shape == .printed ? BookPalette.lampGold.opacity(0.14) : BookPalette.paper.opacity(0.28)),
                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(
                        (shape == .printed ? BookPalette.lampGold : BookPalette.paper).opacity(0.34),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    /// The annual, stated as arithmetic and nothing else.
    ///
    /// No countdown, no "today only", no scarcity of any kind. It is a saving
    /// for paying up front, and it is either worth it to the reader or it is
    /// not — pressure here would be the one place the money stopped being
    /// simple, clear and fair.
    @ViewBuilder
    private var annualSavingNote: some View {
        if let monthly = tiers.first(where: { $0.cadence == .monthly }),
           let annual = tiers.first(where: { $0.cadence == .annual }),
           let saving = annualSavingText(monthly: monthly, annual: annual) {
            Label(saving, systemImage: "equal.circle")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(BookPalette.lampGold.opacity(0.86))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Worked from the displayed prices rather than hard-coded, so it can never
    /// claim a saving the till does not honour.
    private func annualSavingText(monthly: StandingOrderTier, annual: StandingOrderTier) -> String? {
        func cents(_ text: String) -> Int? {
            let digits = text.filter { $0.isNumber || $0 == "." }
            guard let value = Double(digits) else { return nil }
            return Int((value * 100).rounded())
        }
        guard let monthlyCents = cents(priceText(for: monthly)),
              let annualCents = cents(priceText(for: annual)),
              monthlyCents > 0, annualCents > 0 else { return nil }
        let twelve = monthlyCents * 12
        guard twelve > annualCents else { return nil }
        let percent = Int(((Double(twelve - annualCents) / Double(twelve)) * 100).rounded())
        return "Paying by the year is \(percent)% less than paying twelve times. That's the whole offer — no clock on it."
    }

    private var changeShapeButton: some View {
        Button {
            BookFeedback.play(.dismissPage)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { chosenShape = nil }
        } label: {
            Label("Show me the other one", systemImage: "arrow.uturn.backward")
                .font(.caption.weight(.bold))
                .foregroundStyle(BookPalette.nightText.opacity(0.66))
        }
        .buttonStyle(.plain)
    }

    private var plansPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            switch chosenShape {
            case .none:
                pageTitle(
                    "Two ways to have me.",
                    subtitle: "One of them arrives in the post. Pick the shape first — the billing is the boring part and I'll get to it."
                )
                planShapeCard(.printed)
                planShapeCard(.digital)

            case .printed:
                pageTitle(
                    "That one comes by post.",
                    subtitle: "Three seasons in softcover and the year itself in cloth and foil, and everything the Book does besides."
                )
                boundYearNote
                changeShapeButton

            case .digital:
                pageTitle(
                    "Here's the price.",
                    subtitle: "Same story, same monthly packs, either way. You're only picking how often you get billed."
                )

                ForEach(tiers) { tier in
                    tierCard(tier)
                }

                annualSavingNote
                changeShapeButton
            }

            if chosenShape == .digital {
                Text("Everyone sees the same two prices. Your answers only change how I explain myself.")
                .font(.system(.callout, design: .serif).weight(.semibold))
                .foregroundStyle(BookPalette.nightText.opacity(0.72))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 2)

            VStack(alignment: .leading, spacing: 12) {
                Text("And exactly what happens:")
                    .font(.system(.title3, design: .serif).weight(.bold))
                    .foregroundStyle(BookPalette.nightText)

                termsLine("calendar", billingClause)
                if trialDays(for: selectedTier) != nil {
                    termsLine("bell", reminderClause)
                }
                termsLine("xmark.circle", cancellationClause)
                termsLine("lock.shield", "If you stop, the paid pages close. The free Book and everything you made in it stay exactly where they are.")
                termsLine("arrow.clockwise", "Apple charges your Apple ID and renews it automatically unless you cancel at least 24 hours before the period ends.")
            }
            .padding(14)
            .background(BookPalette.page.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            }

            HStack(spacing: 18) {
                Button {
                    Task { await restore() }
                } label: {
                    Label("Restore purchases", systemImage: "arrow.counterclockwise")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(BookPalette.teal)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                Link("Terms", destination: LegalDocuments.termsOfUse)
                Link("Privacy", destination: LegalDocuments.privacyPolicy)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(BookPalette.nightText.opacity(0.6))

            Button {
                BookFeedback.play(.dismissPage)
                onDismiss()
            } label: {
                Text("No thanks — open my free Book")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(BookPalette.paper.opacity(0.38), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .foregroundStyle(BookPalette.nightText.opacity(0.78))
            }
            .buttonStyle(.plain)
        }
    }

    private func tierCard(_ tier: StandingOrderTier) -> some View {
        let selected = tier.id == selectedTierID
        return Button {
            BookFeedback.play(.select)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selectedTierID = tier.id }
        } label: {
            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(selected ? BookPalette.lampGold : BookPalette.nightText.opacity(0.4))

                    Text(tier.title)
                        .font(.title3.weight(.black))
                        .foregroundStyle(BookPalette.nightText)

                    if let note = valueNote(for: tier) {
                        Text(note.uppercased())
                            .font(.system(size: 10, weight: .black))
                            .tracking(0.6)
                            .foregroundStyle(BookPalette.ink)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(BookPalette.lampGold, in: Capsule())
                    }

                    Spacer(minLength: 0)
                }

                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(priceText(for: tier))
                        .font(.system(.largeTitle, design: .serif).weight(.black))
                        .foregroundStyle(selected ? BookPalette.lampGold : BookPalette.nightText)
                    Text("/ \(tier.periodUnit)")
                        .font(.body.weight(.bold))
                        .foregroundStyle(BookPalette.nightText.opacity(0.68))
                    Spacer(minLength: 0)
                }

                Text(tierTermsLine(tier))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(BookPalette.nightText.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)

                Divider()
                    .overlay(BookPalette.lampGold.opacity(0.28))

                VStack(alignment: .leading, spacing: 5) {
                    Label("THE BOOK'S EXCUSE FOR THIS PRICE", systemImage: "tag.fill")
                        .font(.system(size: 11, weight: .black))
                        .tracking(0.6)
                        .foregroundStyle(BookPalette.teal)
                    Text(discountReason(for: tier))
                        .font(.system(.body, design: .serif).weight(.semibold))
                        .italic()
                        .foregroundStyle(BookPalette.nightText.opacity(0.88))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(17)
            .background(
                LinearGradient(
                    colors: selected
                        ? [BookPalette.lampGold.opacity(0.16), BookPalette.violet.opacity(0.18)]
                        : [BookPalette.paper.opacity(0.42), BookPalette.nightPanel.opacity(0.62)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke((selected ? BookPalette.lampGold : BookPalette.nightText.opacity(0.2)), lineWidth: selected ? 1.6 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func discountReason(for tier: StandingOrderTier) -> String {
        let reasons = personalization.offerReasons.isEmpty
            ? StandingOrderPersonalization.empty.offerReasons
            : personalization.offerReasons
        let rotation = abs(offerReasonNonce.uuidString.stableHash) % reasons.count
        let offset = tier.cadence == .monthly ? 0 : 1
        return reasons[(rotation + offset) % reasons.count]
    }

    private func tierTermsLine(_ tier: StandingOrderTier) -> String {
        if let days = trialDays(for: tier) {
            guard pricing[tier.productID] != nil else {
                return "\(days)-day trial preview; Apple confirms live eligibility and price"
            }
            return "\(days)-day free trial, then \(priceText(for: tier)) / \(tier.periodUnit)"
        }
        guard pricing[tier.productID] != nil else {
            return "Apple confirms the current price before purchase"
        }
        return "\(priceText(for: tier)) / \(tier.periodUnit), billed when you confirm"
    }

    private var billingClause: String {
        let start = Date()
        let fmt = Date.FormatStyle.dateTime.month(.wide).day()
        let price = priceText(for: selectedTier)
        guard pricing[selectedTier.productID] != nil else {
            return "Apple will show and confirm the current localized price before you subscribe. The \(price) shown earlier is only my catalog estimate."
        }
        guard let days = trialDays(for: selectedTier) else {
            return "If you confirm today, \(start.formatted(fmt)), Apple charges \(price) for the \(selectedTier.title.lowercased()) Standing Order."
        }
        let charge = Calendar.current.date(byAdding: .day, value: days, to: start) ?? start
        return "Your free trial starts today, \(start.formatted(fmt)). On \(charge.formatted(fmt)), Apple charges \(price) for the \(selectedTier.title.lowercased()) Standing Order unless you cancel first."
    }

    private var reminderClause: String {
        switch reminderAuthorization {
        case .allowed:
            return "Notifications are allowed, so we'll tap the glass the day before your free trial ends."
        case .notDetermined:
            return "If you allow notifications when asked, we'll tap the glass the day before your free trial ends."
        case .unavailable:
            return "Notifications are off, so I can't promise a trial reminder. The charge date is written above."
        }
    }

    private var cancellationClause: String {
        if trialDays(for: selectedTier) != nil {
            return "Cancel anytime in Settings → Apple ID → Subscriptions. Cancel before the trial ends and you are never charged."
        }
        return "Cancel anytime in Settings → Apple ID → Subscriptions. Your access continues through the paid billing period."
    }

    // MARK: Shared bits

    private func pageTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(.title, design: .serif).weight(.bold))
                .foregroundStyle(BookPalette.nightText)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.system(.body, design: .serif))
                .foregroundStyle(BookPalette.nightText.opacity(0.82))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 6)
    }

    private func benefitRow(_ symbol: String, _ title: String, _ body: String, emphasized: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(emphasized ? BookPalette.ink : BookPalette.lampGold)
                .frame(width: 38, height: 38)
                .background((emphasized ? BookPalette.lampGold : BookPalette.nightPanel).opacity(emphasized ? 0.92 : 0.7), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline.weight(.black))
                    .foregroundStyle(BookPalette.nightText)
                Text(body)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(BookPalette.nightText.opacity(0.82))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(BookPalette.page.opacity(emphasized ? 0.6 : 0.4), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke((emphasized ? BookPalette.lampGold : BookPalette.nightText).opacity(emphasized ? 0.4 : 0.12), lineWidth: 1)
        }
    }

    private func termsLine(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.caption.weight(.black))
                .foregroundStyle(BookPalette.lampGold)
                .frame(width: 20)
            Text(text)
                .font(.system(.callout, design: .serif))
                .foregroundStyle(BookPalette.nightText.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func subscribe() async {
        guard !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        let merchant = await BookShopTill.resolveMerchant()
        switch await merchant.purchase(productID: selectedTier.productID) {
        case .bound:
            if let days = trialDays(for: selectedTier) {
                // Schedule the courtesy reminder only for a trial the sheet
                // actually disclosed for this reader.
                let didSchedule = await StandingOrderTrialReminder.scheduleForPurchasedTrial(
                    productID: selectedTier.productID,
                    fallbackTrialDays: days,
                    price: priceText(for: selectedTier),
                    periodUnit: selectedTier.periodUnit
                )
                if !didSchedule {
                    statusLine = "The bargain is struck. Notifications are off, so keep the charge date written above."
                }
            } else {
                StandingOrderTrialReminder.cancel()
            }
            onBargainStruck()
            onSubscribed(PackEntitlements.standingOrderPackID)
            await strikeBargain()
        case .pending:
            statusLine = "The App Store says the order is pending approval. The ledger will wait."
        case .cancelled:
            statusLine = "The clerk re-shelves it without judgment. The free Book remains yours."
            BookFeedback.play(.dismissPage)
        case .failed(let reason):
            statusLine = reason
            BookFeedback.play(.error)
        }
    }

    private func restore() async {
        let merchant = await BookShopTill.resolveMerchant()
        let owned = await merchant.restorePurchases()
        if owned.contains(PackEntitlements.standingOrderPackID) {
            await StandingOrderTrialReminder.reconcileCurrentTrial()
            onSubscribed(PackEntitlements.standingOrderPackID)
            statusLine = "The ledger remembers you. Your Standing Order is restored."
            BookFeedback.play(.braidComplete)
        } else if owned.isEmpty {
            statusLine = "The ledger finds no prior Standing Order under your name."
        } else {
            for packID in owned { onSubscribed(packID) }
            statusLine = "Restored \(owned.count) prior binding\(owned.count == 1 ? "" : "s")."
        }
    }
}

private struct GoblinTillWakeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var counted = false

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { index in
                    ZStack {
                        Circle()
                            .fill(index == 1 ? BookPalette.teal.opacity(0.18) : BookPalette.lampGold.opacity(0.18))
                        Image(systemName: index == 1 ? "key.fill" : "seal.fill")
                            .font(.caption.weight(.black))
                            .foregroundStyle(index == 1 ? BookPalette.teal : BookPalette.lampGold)
                    }
                    .frame(width: 38, height: 38)
                    .rotationEffect(.degrees(reduceMotion || counted ? Double(index - 1) * 4 : -16))
                    .offset(y: reduceMotion || counted ? 0 : 12)
                    .opacity(reduceMotion || counted ? 1 : 0)
                    .animation(
                        BookMotion.deal(delay: Double(index) * 0.09, reduceMotion: reduceMotion),
                        value: counted
                    )
                }
            }

            Text("The Goblins are unlocking the till…")
                .font(.system(.callout, design: .serif).weight(.semibold))
                .foregroundStyle(BookPalette.nightText.opacity(0.76))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .onAppear { counted = true }
        .accessibilityElement(children: .combine)
    }
}

/// A compact working bindery: loose folios gather, the needle traverses their
/// spine, and the wax seal holds. Unlike a generic spinner, every moving part
/// describes the work the reader is waiting for.
private struct BindingFolioGlyph: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stitching = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(BookPalette.page)
                    .frame(width: 62, height: 76)
                    .overlay {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(BookPalette.parchmentEdge.opacity(0.72), lineWidth: 1)
                    }
                    .rotationEffect(.degrees(Double(index - 1) * (stitching && !reduceMotion ? 1.2 : 4.6)))
                    .offset(x: CGFloat(index - 1) * (stitching && !reduceMotion ? 4 : 11))
                    .shadow(color: .black.opacity(0.18), radius: 5, y: 3)
            }

            Capsule()
                .fill(BookPalette.lampGold.opacity(0.72))
                .frame(width: 2, height: 58)
                .offset(x: -26)

            Image(systemName: "needle")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(BookPalette.lampGold)
                .rotationEffect(.degrees(28))
                .offset(x: -26, y: reduceMotion ? 0 : (stitching ? 24 : -24))

            Image(systemName: "seal.fill")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(BookPalette.lampGold)
                .scaleEffect(reduceMotion ? 1 : (stitching ? 1.08 : 0.88))
                .offset(x: 25, y: 25)
                .shadow(color: BookPalette.lampGold.opacity(0.32), radius: 8)
        }
        .frame(width: 112, height: 92)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                stitching = true
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Weekly Issue reader

/// A full-screen binding desk shown while Gemma writes and the PDF/card files
/// are being pressed. It deliberately blocks the underlying menus so the reader
/// cannot start a second bind or open a half-written issue.
struct WeeklyIssueBindingOverlay: View {
    let note: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black.opacity(0.48)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                BindingFolioGlyph()

                VStack(spacing: 7) {
                    Text("Binding the week")
                        .font(.system(.title3, design: .serif).weight(.bold))
                        .foregroundStyle(BookPalette.nightText)
                    Text(note)
                        .font(.callout)
                        .foregroundStyle(BookPalette.nightText.opacity(0.76))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text("The issue will open when the ink is dry.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BookPalette.teal)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 26)
            .frame(maxWidth: 340)
            .background(BookPalette.nightPanel, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(BookPalette.lampGold.opacity(0.36), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.38), radius: 28, y: 12)
        }
        .transition(BookMotion.riseTransition(reduceMotion: reduceMotion))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Binding the weekly issue. (note)")
        .accessibilityAddTraits(.updatesFrequently)
    }
}

/// The one leaf the Book does not write. The draft belongs to an explicit
/// binding target; the finished artifact freezes its own `BoundDedication`.
struct BindingDedicationEditor: View {
    let title: String
    @Binding var text: String

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 6) {
                TextEditor(text: $text)
                    .frame(minHeight: 74)
                    .padding(6)
                    .background(BookPalette.page.opacity(0.76), in: RoundedRectangle(cornerRadius: 7))
                    .onChange(of: text) { _, value in
                        if value.count > BoundDedication.characterLimit {
                            text = String(value.prefix(BoundDedication.characterLimit))
                        }
                    }
                HStack {
                    Text("I won't finish the sentence for you.")
                        .font(.caption2)
                        .foregroundStyle(BookPalette.ink.opacity(0.56))
                    Spacer()
                    Text("\(text.count)/\(BoundDedication.characterLimit)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(BookPalette.ink.opacity(0.52))
                }
            }
            .padding(.top, 5)
        } label: {
            Label(title, systemImage: "text.book.closed")
                .font(.caption.weight(.bold))
                .foregroundStyle(BookPalette.ink.opacity(0.76))
        }
        .tint(BookPalette.lampGold)
    }
}

/// Everything a bound weekly issue needs to be read in-app and shared. Built once
/// per issue when the reader binds it (Gemma's editor's note and closing note
/// baked in), then cached so re-opening the same issue never re-asks the brain.
struct WeeklyIssueReader: Identifiable, Equatable {
    let id: UUID
    var issue: WeeklyIssue
    var card: WeeklyIssueShareCard
    var readerName: String
    var editorialNote: String?
    var closingNote: String?
    var cardURL: URL
    var pdfURL: URL

    init(
        id: UUID = UUID(),
        issue: WeeklyIssue,
        card: WeeklyIssueShareCard,
        readerName: String,
        editorialNote: String?,
        closingNote: String?,
        cardURL: URL,
        pdfURL: URL
    ) {
        self.id = id
        self.issue = issue
        self.card = card
        self.readerName = readerName
        self.editorialNote = editorialNote
        self.closingNote = closingNote
        self.cardURL = cardURL
        self.pdfURL = pdfURL
    }

    /// The editor's note, falling back to the same deterministic lead the PDF uses.
    var editorialLead: String {
        editorialNote?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            ?? (issue.isFirstIssue
                ? "Your first week, bound. Seven days after I opened, \(issue.keptCount) \(issue.keptCount == 1 ? "page" : "pages") had enough ink to become an issue."
                : "Your week became an issue. Another seven days closed, and \(issue.keptCount) \(issue.keptCount == 1 ? "page" : "pages") had enough ink to hold together.")
    }

    /// The closing note, falling back to the PDF's deterministic sign-off.
    var closingLine: String {
        closingNote?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            ?? "The month and the year are still gathering. This week is already whole."
    }
}

/// A bound monthly edition, ready to reopen. The rendered PDF is the canonical
/// artifact — the same leaves the reader would share or print — so the in-app
/// reading presents it directly rather than re-laying the whole month in SwiftUI.
struct MonthlyEditionReader: Identifiable, Equatable {
    let id: UUID
    var edition: MonthlyEdition
    var pdfURL: URL

    init(id: UUID = UUID(), edition: MonthlyEdition, pdfURL: URL) {
        self.id = id
        self.edition = edition
        self.pdfURL = pdfURL
    }

    var monthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return "\(edition.monthName) \(formatter.string(from: edition.startDate))"
    }
}

/// A lightweight PDFKit host so the bound monthly edition reads on the glass with
/// the same layout it prints with. Scrolls vertically as one continuous edition.
private struct MonthlyEditionPDFView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .clear
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document?.documentURL != url {
            uiView.document = PDFDocument(url: url)
        }
    }
}

/// The in-app reading of a bound monthly edition: the real PDF between covers,
/// with the month's name in the bar and the share mark where the weekly reader
/// keeps its own.
struct MonthlyEditionReaderSheet: View {
    let reader: MonthlyEditionReader
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            MonthlyEditionPDFView(url: reader.pdfURL)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(reader.monthLabel)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Text("Done").font(.subheadline.weight(.semibold))
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: reader.pdfURL) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
        }
    }
}

/// The in-app reading of a bound weekly issue: masthead, the Book's editor's note,
/// what's in the issue, the wrapped-week stats, and a closing line — the same
/// leaves the PDF sews, laid out to actually read on the glass. Sharing the card
/// or the full issue lives in the bottom bar, so binding always ends in reading.
struct WeeklyIssueReaderSheet: View {
    let reader: WeeklyIssueReader
    /// Whether the on-device brain is installed, so re-binding can offer to
    /// rewrite the issue in the Book's own words rather than just re-stamp it.
    var brainReady: Bool = false
    var onRebind: () -> Void = {}
    @Environment(\.dismiss) private var dismiss

    private var issue: WeeklyIssue { reader.issue }
    private var card: WeeklyIssueShareCard { reader.card }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    masthead
                    if let dedication = issue.dedication {
                        VStack(spacing: 8) {
                            Text(dedication.text)
                                .font(.system(size: 15, design: .serif).italic())
                                .multilineTextAlignment(.center)
                                .foregroundStyle(BookPalette.ink.opacity(0.86))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 28)
                    }
                    Divider().overlay(BookPalette.gold.opacity(0.5))
                    Text(reader.editorialLead)
                        .font(.system(size: 15, design: .serif))
                        .foregroundStyle(BookPalette.ink.opacity(0.9))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                    if let bindingStory = issue.bindingStory?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("THE WEEK, BOUND")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1.8)
                                .foregroundStyle(BookPalette.gold)
                            Text("A binding of the week's nightly bindings")
                                .font(.system(size: 12, design: .serif))
                                .italic()
                                .foregroundStyle(BookPalette.ink.opacity(0.58))
                            Text(bindingStory)
                                .font(.system(size: 15, design: .serif))
                                .foregroundStyle(BookPalette.ink.opacity(0.92))
                                .lineSpacing(5)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 4)
                    }
                    weekPanel
                    if !issue.highlights.isEmpty { highlightsBlock }
                    if !card.stats.isEmpty { statsBlock }
                    if issue.scrapbookCount > 0 { scrapbookBlock }
                    if let setAside = issue.setAsideLine?.nonEmpty {
                        Text(setAside)
                            .font(.system(size: 12, design: .serif))
                            .italic()
                            .foregroundStyle(BookPalette.ink.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    closingBlock
                    Text("Made with ReEnchanted \u{00B7} reenchanted.app")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(BookPalette.ink.opacity(0.42))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                }
                .padding(24)
            }
            .background(paperBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                        onRebind()
                    } label: {
                        Label(brainReady ? "Rewrite" : "Re-bind", systemImage: "arrow.triangle.2.circlepath")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(BookPalette.gold)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BookPalette.teal)
                }
            }
            .safeAreaInset(edge: .bottom) { actionBar }
        }
    }

    private var masthead: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("THE BOOK OF YOU \u{00B7} WEEKLY ISSUE")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2)
                .foregroundStyle(BookPalette.ink.opacity(0.5))
            Text("Issue No. \(issue.number)")
                .font(.system(size: 40, weight: .bold, design: .serif))
                .foregroundStyle(BookPalette.ink)
            if reader.readerName.nonEmpty != nil {
                Text(reader.readerName)
                    .font(.system(size: 16, design: .serif))
                    .italic()
                    .foregroundStyle(BookPalette.ink.opacity(0.7))
            }
            Text(issue.dateRange)
                .font(.system(size: 11, weight: .semibold))
                .tracking(1)
                .foregroundStyle(BookPalette.gold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var weekPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(card.title)
                .font(.system(size: 19, weight: .bold, design: .serif))
                .foregroundStyle(BookPalette.ink)
            Text(card.subtitle)
                .font(.system(size: 13, design: .serif))
                .italic()
                .foregroundStyle(BookPalette.ink.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
            Text(card.motifLine)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(BookPalette.teal)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BookPalette.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(BookPalette.teal.opacity(0.4), lineWidth: 1)
        }
    }

    private var highlightsBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("In this issue")
                .font(.system(size: 11, weight: .bold))
                .tracking(1)
                .foregroundStyle(BookPalette.gold)
            ForEach(Array(issue.highlights.enumerated()), id: \.offset) { _, line in
                HStack(alignment: .top, spacing: 8) {
                    Text("\u{2022}")
                        .foregroundStyle(BookPalette.gold)
                    Text(line)
                        .font(.system(size: 13, design: .serif))
                        .foregroundStyle(BookPalette.ink.opacity(0.88))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statsBlock: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(Array(card.stats.prefix(4).enumerated()), id: \.offset) { _, stat in
                Text(stat)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(BookPalette.ink.opacity(0.82))
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .padding(.horizontal, 8)
                    .multilineTextAlignment(.center)
                    .background(BookPalette.gold.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(BookPalette.gold.opacity(0.35), lineWidth: 1)
                    }
            }
        }
    }

    private var scrapbookBlock: some View {
        let titles = issue.scrapbookTitles.joined(separator: ", ")
        let word = issue.scrapbookCount == 1 ? "page" : "pages"
        return VStack(alignment: .leading, spacing: 6) {
            Text("Scrapbook plates")
                .font(.system(size: 11, weight: .bold))
                .tracking(1)
                .foregroundStyle(BookPalette.parchmentEdge)
            Text(titles.isEmpty
                 ? "\(issue.scrapbookCount) composed \(word) joined the issue."
                 : titles)
                .font(.system(size: 13, design: .serif))
                .foregroundStyle(BookPalette.ink.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var closingBlock: some View {
        VStack(spacing: 12) {
            Rectangle()
                .fill(BookPalette.gold.opacity(0.4))
                .frame(height: 1.4)
            Text(reader.closingLine)
                .font(.system(size: 12, design: .serif))
                .italic()
                .foregroundStyle(BookPalette.ink.opacity(0.68))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            ShareLink(item: reader.cardURL) {
                Label("Share card", systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(BookPalette.teal)
            ShareLink(item: reader.pdfURL) {
                Label("Full issue", systemImage: "doc.richtext")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(BookPalette.gold)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
    }

    private var paperBackground: some View {
        LinearGradient(
            colors: [BookPalette.page, BookPalette.paper],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
