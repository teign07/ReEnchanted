import SwiftUI

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
    var onHaggle: (MarketWare) -> Int? = { _ in nil }   // spends 1 Warmth; returns discount, or nil if refused
    var onClerkBanter: () async -> String? = { nil }
    var onOpenBargain: (FaeBargain) -> Void = { _ in }
    var onMarkNextMarket: () -> Void = {}

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
    @State private var haggleDiscounts: [String: Int] = [:]
    @State private var haggledWareIDs: Set<String> = []

    private var ownedListings: [BookShopListing] {
        BookShopCatalog.listings.filter { PackEntitlements.isUnlocked($0.packID) }
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
                    }
                    .padding(18)
                }
            }
            .navigationTitle("Goblin Market")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Leave quietly") {
                        BookFeedback.play(.dismissPage)
                        dismiss()
                    }
                }
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
                    Text("The Goblin Market is open.")
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
        HStack(spacing: 10) {
            purseChip(title: "Attention", value: liveAttention, systemImage: "eye", tint: BookPalette.teal)
            purseChip(title: "Belief", value: liveBelief, systemImage: "sparkles", tint: BookPalette.lampGold)
            purseChip(title: "Warmth", value: goblinWarmth, systemImage: "flame", tint: BookPalette.violet)
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
            .font(.caption2.weight(.black))
            .kerning(1)
            .foregroundStyle(BookPalette.nightText.opacity(0.62))
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
                    .buttonStyle(.plain)
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
