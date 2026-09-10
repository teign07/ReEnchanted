import SwiftUI
import StripePaymentSheet
import UIKit
import CryptoKit
#if canImport(Security)
import Security
#endif

/// A claimed press pass kept on this installation until its one book has gone
/// to the printer. The token is a capability, so it belongs in Keychain rather
/// than the Book's archive or ordinary preferences.
struct StoredBookGiftClaim: Codable, Equatable, Identifiable {
    var id: String { pressPass.giftID }
    var claimToken: String
    var pressPass: BookGiftPressPass
    var claimedAt: Date
    var suggestedShippingAddress: PhysicalBookShippingAddress? = nil
}

struct PendingBookGiftSeal: Codable, Equatable {
    var purchase: BookGiftBookPurchaseRequest
    var checkoutToken: String
    var editionKind: PublicationEditionKind? = nil
    var variantID: String? = nil
}

struct PendingBookGiftPurchase: Codable, Equatable {
    var bookSeal: PendingBookGiftSeal?
    var boundYear: BookGiftBoundYearDraft?
}

enum BookGiftClaimStore {
    private static let service = "app.reenchanted.book-gifts"
    private static let claimAccount = "claimed-press-passes"
    private static let purchaseAccount = "unfinished-purchase"
    private static let lastGiftAccount = "last-created-gift"

    static var pendingMembership: BoundYearPurchaseRequest? {
        guard let data = readData(account: "membership-request-" + PhysicalBookQuoteClient.checkoutScope) else { return nil }
        return try? JSONDecoder().decode(BoundYearPurchaseRequest.self, from: data)
    }

    static func savePendingMembership(_ purchase: BoundYearPurchaseRequest?) throws {
        try writeData(JSONEncoder().encode(purchase), account: "membership-request-" + PhysicalBookQuoteClient.checkoutScope)
    }

    static var pendingBoundYearRequest: BookGiftBoundYearPurchaseRequest? {
        guard let data = readData(account: "gift-request-" + PhysicalBookQuoteClient.checkoutScope) else { return nil }
        return try? JSONDecoder().decode(BookGiftBoundYearPurchaseRequest.self, from: data)
    }

    static func savePendingBoundYearRequest(_ purchase: BookGiftBoundYearPurchaseRequest?) throws {
        try writeData(JSONEncoder().encode(purchase), account: "gift-request-" + PhysicalBookQuoteClient.checkoutScope)
    }

    static var lastCreatedGift: BookGiftCreated? {
        guard let data = readData(account: lastGiftAccount) else { return nil }
        return try? JSONDecoder().decode(BookGiftCreated.self, from: data)
    }

    static func saveCreatedGift(_ gift: BookGiftCreated) throws {
        try writeData(JSONEncoder().encode(gift), account: lastGiftAccount)
    }

    static var claims: [StoredBookGiftClaim] {
        guard let data = readData(account: claimAccount),
              let decoded = try? JSONDecoder().decode([StoredBookGiftClaim].self, from: data) else {
            return []
        }
        return decoded
    }

    static func eligibleClaim(
        editionKind: PublicationEditionKind,
        variantID: String,
        pageCount: Int
    ) -> StoredBookGiftClaim? {
        claims.first {
            ($0.pressPass.includedEditionKind ?? .monthly) == editionKind
                && $0.pressPass.includedVariantID == variantID
                && pageCount <= $0.pressPass.maximumPageCount
        }
    }

    static func save(claimToken: String, pressPass: BookGiftPressPass) throws {
        var updated = claims.filter { $0.pressPass.giftID != pressPass.giftID }
        updated.append(StoredBookGiftClaim(
            claimToken: claimToken,
            pressPass: pressPass,
            claimedAt: Date(),
            suggestedShippingAddress: try? BookGiftAddressSeal.open(
                pressPass.deliveryEnvelope,
                claimToken: claimToken
            )
        ))
        try writeData(JSONEncoder().encode(updated), account: claimAccount)
        NotificationCenter.default.post(name: .bookGiftClaimsChanged, object: nil)
    }

    static func remove(giftID: String) {
        let updated = claims.filter { $0.pressPass.giftID != giftID }
        if let data = try? JSONEncoder().encode(updated) {
            try? writeData(data, account: claimAccount)
        }
        NotificationCenter.default.post(name: .bookGiftClaimsChanged, object: nil)
    }

    static var pendingPurchase: PendingBookGiftPurchase? {
        guard let data = readData(account: purchaseAccount) else { return nil }
        guard let purchase = try? JSONDecoder().decode(PendingBookGiftPurchase.self, from: data),
              purchase.bookSeal != nil || purchase.boundYear != nil else { return nil }
        return purchase
    }

    static func savePendingPurchase(_ purchase: PendingBookGiftPurchase) throws {
        try writeData(JSONEncoder().encode(purchase), account: purchaseAccount)
    }

    static func clearPendingPurchase() {
#if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: purchaseAccount,
        ]
        SecItemDelete(query as CFDictionary)
#else
        UserDefaults.standard.removeObject(forKey: service + "." + purchaseAccount)
#endif
    }

    private static func readData(account: String) -> Data? {
#if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else {
            return nil
        }
        return result as? Data
#else
        return UserDefaults.standard.data(forKey: service + "." + account)
#endif
    }

    private static func writeData(_ data: Data, account: String) throws {
#if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var insertion = query
            insertion[kSecValueData as String] = data
            insertion[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(insertion as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw StoreError.keychain(addStatus) }
        } else if status != errSecSuccess {
            throw StoreError.keychain(status)
        }
#else
        UserDefaults.standard.set(data, forKey: service + "." + account)
#endif
    }

    enum StoreError: LocalizedError {
        case keychain(OSStatus)

        var errorDescription: String? {
            switch self {
            case .keychain(let status): return "The gift could not be kept safely on this device (\(status))."
            }
        }
    }
}

private enum BookGiftAddressSeal {
    private static let authenticatedLabel = Data("reenchanted-gift-address-v1".utf8)

    static func open(
        _ envelope: BookGiftDeliveryEnvelope?,
        claimToken: String
    ) throws -> PhysicalBookShippingAddress? {
        guard let envelope else { return nil }
        guard envelope.algorithm == "A256GCM",
              let nonceData = data(fromBase64URL: envelope.nonce),
              let combined = data(fromBase64URL: envelope.sealedAddress),
              combined.count > 16 else {
            throw SealError.invalidEnvelope
        }
        let key = SymmetricKey(data: SHA256.hash(data: Data(claimToken.utf8)))
        let nonce = try AES.GCM.Nonce(data: nonceData)
        let ciphertext = combined.dropLast(16)
        let tag = combined.suffix(16)
        let box = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
        let clear = try AES.GCM.open(box, using: key, authenticating: authenticatedLabel)
        return try JSONDecoder().decode(PhysicalBookShippingAddress.self, from: clear)
    }

    private static func data(fromBase64URL value: String) -> Data? {
        var base64 = value.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = (4 - base64.count % 4) % 4
        base64 += String(repeating: "=", count: padding)
        return Data(base64Encoded: base64)
    }

    enum SealError: Error { case invalidEnvelope }
}

extension Notification.Name {
    static let bookGiftClaimsChanged = Notification.Name("reenchanted.book-gift-claims-changed")
}

/// The Gift Shelf has two short paths:
///
/// - send a copy of an edition already in this Book;
/// - buy a sealed promise which the recipient claims for their own Book.
///
/// The first path hands back to the existing print studio. The second owns only
/// names, a note, destination facts and payment state. It never asks the giver
/// to see, choose, or upload anything from the recipient's Book.
struct BookGiftSheet: View {
    let editions: [MonthlyEdition]
    var initialClaimToken: String? = nil
    var onSendExistingEdition: (MonthlyEdition) -> Void
    var onClaimBoundYear: (BoundYearMembership, String) -> Void
    var onClaimBoundYearDigitalAccess: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var route: Route = .shelf
    @State private var senderName = ""
    @State private var recipientName = ""
    @State private var giftMessage = ""
    @State private var contactEmail = ""
    @State private var countryCode = "US"
    @State private var stateCode = ""
    @State private var postalCode = ""
    @State private var street1 = ""
    @State private var street2 = ""
    @State private var city = ""
    @State private var phoneNumber = ""
    @State private var recipientTaxID = ""
    @State private var acceptsFulfillment = false

    @State private var quote: PhysicalBookQuote?
    @State private var selectedShippingOptionID: String?
    @State private var isWorking = false
    @State private var statusMessage: String?
    @State private var createdGift: BookGiftCreated? = BookGiftClaimStore.lastCreatedGift
    @State private var pendingPurchase = BookGiftClaimStore.pendingPurchase
    @State private var pendingBoundYearRequest = BookGiftClaimStore.pendingBoundYearRequest
    @State private var claimToken = ""
    @State private var claimSummary: BookGiftSummary?
    @State private var claimedGift: BookGiftClaimResponse?
    @State private var selectedGiftEditionKind: PublicationEditionKind = .monthly
    @State private var selectedGiftVariantID = PhysicalBookVariant.from(
        PrintSpec.perfectBoundSoftcover6x9
    ).id

    private enum Route: Hashable {
        case shelf
        case sendMine
        case giveTheirs
        case oneBook
        case boundYear
        case claim
        case share
        case claimed
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BookBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        switch route {
                        case .shelf: shelf
                        case .sendMine: sendMine
                        case .giveTheirs: giveTheirs
                        case .oneBook: oneBook
                        case .boundYear: boundYear
                        case .claim: claim
                        case .share: share
                        case .claimed: claimed
                        }
                    }
                    .padding(18)
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(route == .shelf ? "Done" : "Back") {
                        if route == .shelf {
                            dismiss()
                        } else if route == .share || route == .claimed {
                            dismiss()
                        } else {
                            statusMessage = nil
                            route = .shelf
                        }
                    }
                }
            }
            .onAppear {
                if let initialClaimToken,
                   !initialClaimToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    claimToken = initialClaimToken
                    route = .claim
                    return
                }
                if pendingPurchase?.bookSeal != nil {
                    if let waiting = pendingPurchase?.bookSeal {
                        selectedGiftEditionKind = waiting.editionKind ?? .monthly
                        if let variantID = waiting.variantID {
                            selectedGiftVariantID = variantID
                        }
                    }
                    route = .oneBook
                    statusMessage = "Payment is safe. The gift only needs its seal."
                } else if pendingPurchase?.boundYear != nil || pendingBoundYearRequest != nil {
                    route = .boundYear
                    statusMessage = "A Bound Year checkout is waiting where you left it."
                }
            }
            .task(id: route) {
                guard route == .claim else { return }
                await loadClaim()
            }
        }
    }

    private var navigationTitle: String {
        switch route {
        case .claim, .claimed: return "A Gift Found You"
        case .share: return "Ready to Send"
        default: return "The Gift Shelf"
        }
    }

    private var shelf: some View {
        VStack(alignment: .leading, spacing: 16) {
            giftHero(
                eyebrow: "THE GIFT SHELF",
                title: "Mine, or theirs?",
                detail: "Send a finished piece of your Book. Or give them room for a Book that stays entirely their own."
            )

            if let createdGift {
                Button("Open your last gift link for \(createdGift.gift.recipientName)") {
                    route = .share
                }
                .buttonStyle(.bordered)
            }

            giftChoice(
                title: "Send one of mine",
                detail: "Choose one of your finished editions. Add a dedication. We post that exact Book to them.",
                systemImage: "book.closed.fill",
                accent: BookPalette.lampGold
            ) {
                route = .sendMine
            }

            giftChoice(
                title: "Give them one of their own",
                detail: "They claim it in ReEnchanted. Their Pages never pass through your hands.",
                systemImage: "sparkles.rectangle.stack.fill",
                accent: BookPalette.violet
            ) {
                route = .giveTheirs
            }

            Button {
                route = .claim
            } label: {
                Label("I have a gift link", systemImage: "seal.fill")
                    .font(.callout.weight(.bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(BookPalette.teal)

            giftFinePrint
        }
    }

    private var sendMine: some View {
        VStack(alignment: .leading, spacing: 14) {
            giftHero(
                eyebrow: "A COPY OF YOUR BOOK",
                title: "Choose the one that goes.",
                detail: "The ordinary Bindery does the rest: cover, dedication, proof, their address, one complete price."
            )

            if editions.isEmpty {
                giftPanel {
                    Label("No finished edition is waiting yet.", systemImage: "books.vertical")
                        .font(.headline)
                    Text("Bind a weekly issue, month, season, or year first. Then it can be sent as a real object.")
                        .font(.callout)
                        .foregroundStyle(BookPalette.ink.opacity(0.68))
                }
            } else {
                ForEach(Array(editions.enumerated()), id: \.offset) { _, edition in
                    Button {
                        onSendExistingEdition(edition)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "book.pages.fill")
                                .foregroundStyle(BookPalette.lampGold)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(edition.title)
                                    .font(.system(.headline, design: .serif, weight: .bold))
                                    .foregroundStyle(BookPalette.ink)
                                Text("\(edition.pageCount) kept \(edition.pageCount == 1 ? "Page" : "Pages")")
                                    .font(.caption)
                                    .foregroundStyle(BookPalette.ink.opacity(0.60))
                                Text(PrintSpec.printableVariants(for: edition).map(\.giftShelfName).joined(separator: " · "))
                                    .font(.caption2)
                                    .foregroundStyle(BookPalette.violet.opacity(0.82))
                                    .lineLimit(2)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(BookPalette.ink.opacity(0.38))
                        }
                        .padding(13)
                        .background(BookPalette.page.opacity(0.96), in: RoundedRectangle(cornerRadius: 11))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var giveTheirs: some View {
        VStack(alignment: .leading, spacing: 16) {
            giftHero(
                eyebrow: "THEIR BOOK. THEIR KEY.",
                title: "What kind of Book?",
                detail: "You pay. They choose what belongs in it. The Book keeps its nose out."
            )

            giftChoice(
                title: "One edition of their own",
                detail: "Choose a week, month, season, or year. Then choose its binding. They fill it with their own Pages.",
                systemImage: "book.closed.fill",
                accent: BookPalette.gold,
                badge: "YOU CHOOSE THE BOOK"
            ) {
                resetCheckout()
                route = .oneBook
            }

            giftChoice(
                title: "The Bound Year",
                detail: "One prepaid year: monthly digital gifts, three seasonal books, then the cloth-and-foil year. It does not renew.",
                systemImage: "shippingbox.fill",
                accent: BookPalette.violet,
                badge: BoundYearPricing.annualDisplayPrice
            ) {
                resetCheckout()
                route = .boundYear
            }
        }
    }

    private var oneBook: some View {
        VStack(alignment: .leading, spacing: 14) {
            giftHero(
                eyebrow: "ONE EDITION OF THEIR OWN",
                title: "Choose its bones. They give it a life.",
                detail: "You choose the span and the binding. They choose every Page inside it."
            )

            giftEditionAndBindingChooser

            if pendingPurchase?.bookSeal != nil {
                giftPanel {
                    Label("Payment received", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(BookPalette.violet)
                    Text("No card again. The Book only needs to finish sealing the share link.")
                        .font(.caption)
                        .foregroundStyle(BookPalette.ink.opacity(0.66))
                    Button {
                        Task { await finalizePendingBookGift() }
                    } label: {
                        workingLabel("Seal the paid gift", systemImage: "seal.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(BookPalette.gold)
                    .disabled(isWorking)
                }
            }

            namesAndNote

            giftPanel {
                sectionLabel("Receipt")
                TextField("Your email", text: $contactEmail)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .giftField()
            }

            giftPanel {
                sectionLabel("Where it will go")
                Text("The printer needs a real destination to price the post. The address is sealed with the gift key and its readable server copy is erased. It prefills their parcel label when they claim.")
                    .font(.caption)
                    .foregroundStyle(BookPalette.ink.opacity(0.62))
                TextField("Street", text: $street1).textContentType(.streetAddressLine1).giftField()
                TextField("Apartment, suite, etc. (optional)", text: $street2).textContentType(.streetAddressLine2).giftField()
                TextField("City", text: $city).textContentType(.addressCity).giftField()
                HStack {
                    TextField("Country", text: $countryCode)
                        .textInputAutocapitalization(.characters)
                        .giftField()
                    if countryCode.uppercased() == "US" {
                        TextField("State", text: $stateCode)
                            .textInputAutocapitalization(.characters)
                            .giftField()
                    }
                }
                TextField("Postal code", text: $postalCode)
                    .textContentType(.postalCode)
                    .textInputAutocapitalization(.characters)
                    .giftField()
                TextField("Phone for the parcel", text: $phoneNumber)
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
                    .giftField()
                if ["BR", "CL", "MX"].contains(countryCode.uppercased()) {
                    TextField("Customs tax ID", text: $recipientTaxID).giftField()
                }

                Button {
                    Task { await fetchBookGiftQuote() }
                } label: {
                    workingLabel("Find the complete price", systemImage: "truck.box")
                }
                .buttonStyle(.borderedProminent)
                .tint(BookPalette.violet)
                .disabled(isWorking || !canQuoteBookGift || pendingPurchase != nil)
            }

            if let quote {
                giftPanel {
                    sectionLabel("Choose the post")
                    ForEach(quote.shippingOptions) { option in
                        shippingChoice(option, quote: quote)
                    }

                    Button {
                        Task { await beginBookGiftPayment() }
                    } label: {
                        workingLabel("Give this Book · \(selectedBookGiftTotal)", systemImage: "gift.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(BookPalette.gold)
                    .disabled(isWorking || selectedShippingOptionID == nil || !validNamesAndReceipt || pendingPurchase != nil)
                }
            }

            statusLine
            giftFinePrint
        }
        .onChange(of: bookGiftDestinationSignature) { _, _ in
            guard quote != nil, pendingPurchase?.bookSeal == nil else { return }
            resetCheckout()
            statusMessage = "The parcel label changed. Find the complete price again."
        }
    }

    private var giftEditionAndBindingChooser: some View {
        VStack(alignment: .leading, spacing: 12) {
            giftPanel {
                sectionLabel("1 · What does it hold?")
                ForEach(BookGiftEditionAllowance.giftableKinds, id: \.rawValue) { kind in
                    Button {
                        selectGiftEdition(kind)
                    } label: {
                        giftSelectionRow(
                            title: giftEditionName(kind),
                            detail: giftEditionDetail(kind),
                            isSelected: selectedGiftEditionKind == kind
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(pendingPurchase?.bookSeal != nil)
                }
            }

            giftPanel {
                sectionLabel("2 · How does it stand?")
                ForEach(Array(giftablePrintSpecs.enumerated()), id: \.offset) { _, spec in
                    let variantID = PhysicalBookVariant.from(spec).id
                    Button {
                        selectGiftBinding(spec)
                    } label: {
                        giftSelectionRow(
                            title: spec.giftShelfName,
                            detail: spec.coverTreatment.mood,
                            isSelected: selectedGiftVariantID == variantID
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(pendingPurchase?.bookSeal != nil)
                }
            }

            Text("This gift pays for one \(giftEditionName(selectedGiftEditionKind).lowercased()) as a \(selectedGiftPrintSpec.giftShelfName.lowercased()), up to \(selectedGiftMaximumPageCount) finished pages. Delivery is included in the price below.")
                .font(.caption)
                .foregroundStyle(BookPalette.nightText.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
            if selectedGiftEditionKind == .annual {
                Text("This is one annual pressing. The Bound Year is the separate four-parcel gift with three seasonal books and the year at the end.")
                    .font(.caption)
                    .foregroundStyle(BookPalette.nightText.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var boundYear: some View {
        VStack(alignment: .leading, spacing: 14) {
            giftHero(
                eyebrow: "A WHOLE BOUND YEAR",
                title: "One year. No trailing bill.",
                detail: "You pay \(BoundYearPricing.annualDisplayPrice) once. The membership stops after that paid year instead of renewing."
            )

            if let waiting = pendingPurchase?.boundYear {
                giftPanel {
                    Label("Checkout waiting", systemImage: "creditcard")
                        .font(.headline)
                        .foregroundStyle(BookPalette.violet)
                    Text("For \(waiting.gift.gift.recipientName), from \(waiting.gift.gift.senderName). Continue the same secure payment; a second year will not be opened.")
                        .font(.caption)
                        .foregroundStyle(BookPalette.ink.opacity(0.66))
                    Button {
                        resumeBoundYearGiftPayment(waiting)
                    } label: {
                        workingLabel("Continue checkout", systemImage: "arrow.right.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(BookPalette.violet)
                    .disabled(isWorking)
                }
            } else if let waiting = pendingBoundYearRequest {
                giftPanel {
                    Text("A purchase for \(waiting.recipientName) is waiting. Its original details are kept here.")
                    Button("Continue this gift") {
                        Task { await beginBoundYearGiftPayment() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isWorking)
                }
            }

            if pendingPurchase?.boundYear != nil || pendingBoundYearRequest != nil {
                Button("Close unpaid checkout") {
                    Task { await closeUnpaidGift() }
                }
                .buttonStyle(.bordered)
                .disabled(isWorking)
            }

            namesAndNote

            giftPanel {
                sectionLabel("Receipt")
                TextField("Your email", text: $contactEmail)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .giftField()
            }

            giftPanel {
                sectionLabel("Their delivery address")
                Text("The Bound Year begins now, so the first parcel needs its address now. They can change it later.")
                    .font(.caption)
                    .foregroundStyle(BookPalette.ink.opacity(0.62))
                TextField("Name on parcel", text: $recipientName).textContentType(.name).giftField()
                TextField("Street", text: $street1).textContentType(.streetAddressLine1).giftField()
                TextField("Apartment, suite, etc. (optional)", text: $street2).textContentType(.streetAddressLine2).giftField()
                TextField("City", text: $city).textContentType(.addressCity).giftField()
                HStack {
                    TextField("State / region", text: $stateCode).textContentType(.addressState).giftField()
                    TextField("Postal code", text: $postalCode).textContentType(.postalCode).giftField()
                }
                TextField("Country code", text: $countryCode)
                    .textContentType(.countryName)
                    .textInputAutocapitalization(.characters)
                    .giftField()
                TextField("Phone for the parcel", text: $phoneNumber).textContentType(.telephoneNumber).keyboardType(.phonePad).giftField()
                if ["BR", "CL", "MX"].contains(countryCode.uppercased()) {
                    TextField("Customs tax ID", text: $recipientTaxID).giftField()
                }

                Toggle(isOn: $acceptsFulfillment) {
                    Text("I agree that the address and finished print files may be sent to Lulu only to print and deliver the books.")
                        .font(.caption)
                        .foregroundStyle(BookPalette.ink.opacity(0.72))
                }
                .tint(BookPalette.violet)
            }

            Button {
                Task { await beginBoundYearGiftPayment() }
            } label: {
                workingLabel("Give the Bound Year · \(BoundYearPricing.annualDisplayPrice)", systemImage: "gift.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(BookPalette.violet)
            .disabled(isWorking || !canBuyBoundYearGift || pendingPurchase != nil || pendingBoundYearRequest != nil)

            statusLine
            giftFinePrint
        }
    }

    private var claim: some View {
        VStack(alignment: .leading, spacing: 14) {
            giftHero(
                eyebrow: "A SEALED THING",
                title: claimSummary.map { "\($0.senderName) sent this." } ?? "Let me sniff the seal.",
                detail: "Claiming tells the gift which installation is yours. It does not show the sender a single Page."
            )

            if initialClaimToken == nil {
                giftPanel {
                    sectionLabel("Gift code")
                    TextField("Paste the code or link", text: $claimToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .giftField()
                    Button {
                        claimToken = Self.token(from: claimToken)
                        Task { await loadClaim() }
                    } label: {
                        workingLabel("Open the seal", systemImage: "seal.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(BookPalette.teal)
                    .disabled(isWorking || Self.token(from: claimToken).isEmpty)
                }
            }

            if let claimSummary {
                giftPanel {
                    Text(giftTitle(claimSummary.kind))
                        .font(.system(.title3, design: .serif, weight: .bold))
                        .foregroundStyle(BookPalette.ink)
                    Text("For \(claimSummary.recipientName)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BookPalette.violet)
                    if let object = giftObjectDescription(claimSummary) {
                        Text(object)
                            .font(.caption)
                            .foregroundStyle(BookPalette.ink.opacity(0.68))
                    }
                    if let message = claimSummary.message, !message.isEmpty {
                        Text("“\(message)”")
                            .font(.system(.body, design: .serif).italic())
                            .foregroundStyle(BookPalette.ink.opacity(0.82))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    claimStatusView(claimSummary)
                }

                if claimSummary.status == .readyToClaim {
                    Button {
                        Task { await acceptClaim() }
                    } label: {
                        workingLabel("Claim it", systemImage: "key.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(BookPalette.gold)
                    .disabled(isWorking)

                    Button(role: .destructive) {
                        Task { await declineClaim() }
                    } label: {
                        Text("No thank you")
                            .font(.callout.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isWorking)
                } else if claimSummary.status == .claimed {
                    Button {
                        Task { await acceptClaim() }
                    } label: {
                        workingLabel("Restore it on this Book", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(BookPalette.violet)
                    .disabled(isWorking)
                } else if claimSummary.status == .paymentPending {
                    Button {
                        Task { await loadClaim() }
                    } label: {
                        workingLabel("Check the payment again", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .tint(BookPalette.teal)
                    .disabled(isWorking)
                }
            }

            statusLine
        }
    }

    private var share: some View {
        VStack(alignment: .leading, spacing: 16) {
            giftHero(
                eyebrow: "PAID. SEALED. READY.",
                title: "Now send the key.",
                detail: "The link contains no Pages. It only lets \(createdGift?.gift.recipientName ?? "them") claim the thing you bought."
            )

            if let createdGift {
                giftPanel {
                    Text(giftTitle(createdGift.gift.kind))
                        .font(.system(.title3, design: .serif, weight: .bold))
                    Text("For \(createdGift.gift.recipientName), from \(createdGift.gift.senderName)")
                        .font(.callout)
                        .foregroundStyle(BookPalette.ink.opacity(0.72))
                    if let object = giftObjectDescription(createdGift.gift) {
                        Text(object)
                            .font(.caption)
                            .foregroundStyle(BookPalette.ink.opacity(0.68))
                    }
                    ShareLink(
                        item: createdGift.shareURL,
                        subject: Text("A ReEnchanted gift"),
                        message: Text("A Book-shaped thing has found you.")
                    ) {
                        Label("Send the gift link", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(BookPalette.violet)

                    Button {
                        UIPasteboard.general.url = createdGift.shareURL
                        statusMessage = "Gift link copied."
                    } label: {
                        Label("Copy link", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }

            statusLine
            Text("Keep the link until they have claimed it. If they decline, the original purchaser can ask for a refund under the Gift & Print Return Policy.")
                .font(.caption)
                .foregroundStyle(BookPalette.nightText.opacity(0.70))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var claimed: some View {
        VStack(alignment: .leading, spacing: 16) {
            giftHero(
                eyebrow: "THE KEY TURNED",
                title: "It belongs to your Book now.",
                detail: claimedGift?.pressPass == nil
                    ? "The Bound Year is standing. The first digital gifts can come in; its parcels will follow their seasons."
                    : "When an edition is ready, open Bind Physical. The gift will be waiting at checkout."
            )

            giftPanel {
                Label(
                    claimedGift?.pressPass == nil ? "Bound Year claimed" : "One pressing claimed",
                    systemImage: "checkmark.seal.fill"
                )
                .font(.system(.title3, design: .serif, weight: .bold))
                .foregroundStyle(BookPalette.violet)

                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(BookPalette.gold)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var namesAndNote: some View {
        giftPanel {
            sectionLabel("The little label on the parcel")
            TextField("Your name", text: $senderName).textContentType(.name).giftField()
            TextField("Their name", text: $recipientName).textContentType(.name).giftField()
            TextField("A short note (optional)", text: $giftMessage, axis: .vertical)
                .lineLimit(2...5)
                .giftField()
            HStack {
                Spacer()
                Text("\(min(giftMessage.count, 280))/280")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(BookPalette.ink.opacity(0.48))
            }
            .onChange(of: giftMessage) { _, value in
                if value.count > 280 { giftMessage = String(value.prefix(280)) }
            }
        }
    }

    private var giftFinePrint: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Gifts never reveal the recipient's Book to the sender. Custom books can be cancelled until they go to press; damaged, defective, wrong, or lost books are replaced or refunded under the Gift & Print Return Policy.")
            if let url = URL(string: "https://reenchanted.app/returns.html") {
                Link("Read the return policy", destination: url)
                    .fontWeight(.bold)
            }
        }
        .font(.caption2)
        .foregroundStyle(BookPalette.nightText.opacity(0.66))
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var statusLine: some View {
        if let statusMessage {
            Text(statusMessage)
                .font(.caption)
                .foregroundStyle(BookPalette.nightText.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var canQuoteBookGift: Bool {
        !street1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !postalCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && countryCode.trimmingCharacters(in: .whitespacesAndNewlines).count == 2
            && (!["BR", "CL", "MX"].contains(countryCode.uppercased())
                || !recipientTaxID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private var bookGiftDestinationSignature: String {
        [
            street1,
            street2,
            city,
            stateCode,
            countryCode,
            postalCode,
            phoneNumber,
            recipientTaxID,
        ].joined(separator: "\u{1F}")
    }

    private var validNamesAndReceipt: Bool {
        !senderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !recipientName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && contactEmail.contains("@")
    }

    private var canBuyBoundYearGift: Bool {
        validNamesAndReceipt
            && !street1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !postalCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && countryCode.trimmingCharacters(in: .whitespacesAndNewlines).count == 2
            && (!["BR", "CL", "MX"].contains(countryCode.uppercased())
                || !recipientTaxID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            && acceptsFulfillment
    }

    private var selectedBookGiftTotal: String {
        guard let quote,
              let selectedShippingOptionID,
              let option = quote.shippingOptions.first(where: { $0.id == selectedShippingOptionID }) else {
            return "Choose shipping"
        }
        return Self.money(PhysicalBookPricing.priceBreakdown(
            request: quote.request,
            shippingCents: option.price.cents,
            estimatedTaxCents: option.estimatedTax?.cents ?? 0,
            policy: quote.pricingPolicy
        ).total)
    }

    @MainActor
    private func fetchBookGiftQuote() async {
        isWorking = true
        statusMessage = "The Bindery is weighing the \(giftEditionName(selectedGiftEditionKind).lowercased())..."
        defer { isWorking = false }
        do {
            let spec = selectedGiftPrintSpec
            let request = PhysicalBookQuoteRequest(
                editionID: "gift-pass-\(selectedGiftEditionKind.rawValue)-\(UUID().uuidString.lowercased())",
                editionKind: selectedGiftEditionKind,
                variant: .from(spec),
                pageCount: selectedGiftMaximumPageCount,
                shipTo: PhysicalBookShippingDestination(
                    countryCode: countryCode.uppercased(),
                    stateCode: nilIfEmpty(stateCode.uppercased()),
                    postalCode: postalCode.trimmingCharacters(in: .whitespacesAndNewlines),
                    city: city.trimmingCharacters(in: .whitespacesAndNewlines),
                    street1: street1.trimmingCharacters(in: .whitespacesAndNewlines),
                    street2: nilIfEmpty(street2),
                    phoneNumber: phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines),
                    recipientTaxID: nilIfEmpty(recipientTaxID)
                )
            )
            let quote = try await PhysicalBookQuoteClient().quote(request)
            self.quote = quote
            selectedShippingOptionID = quote.shippingOptions.first?.id
            statusMessage = quote.shippingOptions.isEmpty
                ? "No delivery route was found for that destination."
                : "Complete prices found. Pick the post you want."
        } catch {
            quote = nil
            statusMessage = "The price would not come out yet: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func beginBookGiftPayment() async {
        guard let quote,
              let selectedShippingOptionID,
              let option = quote.shippingOptions.first(where: { $0.id == selectedShippingOptionID }) else { return }
        isWorking = true
        statusMessage = "Opening the secure till..."
        defer { isWorking = false }
        do {
            let client = PhysicalBookQuoteClient()
            let payment = try await client.paymentIntent(
                PhysicalBookPaymentIntentRequest(
                    quoteID: quote.id,
                    quoteRequest: quote.request,
                    selectedShippingOption: option,
                    contactEmail: contactEmail.trimmingCharacters(in: .whitespacesAndNewlines)
                ),
                checkoutToken: quote.checkoutToken
            )
            let sheet = try makePaymentSheet(clientSecret: payment.clientSecret)
            present(sheet) { result in
                guard result == .completed else {
                    statusMessage = result.message
                    return
                }
                Task { @MainActor in
                    let seal = PendingBookGiftSeal(
                        purchase: BookGiftBookPurchaseRequest(
                            quoteID: quote.id,
                            paymentIntentID: payment.id,
                            contactEmail: contactEmail.trimmingCharacters(in: .whitespacesAndNewlines),
                            selectedShippingOptionID: option.id,
                            senderName: senderName.trimmingCharacters(in: .whitespacesAndNewlines),
                            recipientName: recipientName.trimmingCharacters(in: .whitespacesAndNewlines),
                            message: nilIfEmpty(giftMessage)
                        ),
                        checkoutToken: quote.checkoutToken,
                        editionKind: quote.request.editionKind,
                        variantID: quote.request.variant.id
                    )
                    let pending = PendingBookGiftPurchase(bookSeal: seal, boundYear: nil)
                    let wasSaved: Bool
                    do {
                        try BookGiftClaimStore.savePendingPurchase(pending)
                        pendingPurchase = pending
                        wasSaved = true
                    } catch {
                        wasSaved = false
                    }
                    await finalizeBookGift(seal, wasSavedForRetry: wasSaved)
                }
            }
        } catch {
            statusMessage = "The till stayed shut: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func finalizeBookGift(
        _ seal: PendingBookGiftSeal,
        wasSavedForRetry: Bool = true
    ) async {
        isWorking = true
        statusMessage = "Payment found. Sealing the gift..."
        defer { isWorking = false }
        do {
            createdGift = try await PhysicalBookQuoteClient().finalizeBookGift(
                seal.purchase,
                checkoutToken: seal.checkoutToken
            )
            if let createdGift { try BookGiftClaimStore.saveCreatedGift(createdGift) }
            BookGiftClaimStore.clearPendingPurchase()
            pendingPurchase = nil
            statusMessage = nil
            route = .share
        } catch {
            statusMessage = wasSavedForRetry
                ? "Payment was received and kept safely. Tap Seal the paid gift to try the doorway again: \(error.localizedDescription)"
                : "Payment was received, but this device could not keep the retry key. Keep this screen open and contact the Bindery if the seal will not finish: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func finalizePendingBookGift() async {
        guard let seal = pendingPurchase?.bookSeal else { return }
        await finalizeBookGift(seal)
    }

    @MainActor
    private func beginBoundYearGiftPayment() async {
        guard !isWorking else { return }
        let purchase: BookGiftBoundYearPurchaseRequest
        if let saved = pendingBoundYearRequest {
            purchase = saved
        } else {
            guard let address = boundYearAddress else { return }
            purchase = BookGiftBoundYearPurchaseRequest(
                contactEmail: contactEmail.trimmingCharacters(in: .whitespacesAndNewlines),
                shippingAddress: address, acceptsLuluFulfillment: acceptsFulfillment,
                senderName: senderName.trimmingCharacters(in: .whitespacesAndNewlines),
                recipientName: recipientName.trimmingCharacters(in: .whitespacesAndNewlines),
                message: nilIfEmpty(giftMessage)
            )
        }
        isWorking = true
        statusMessage = "Opening one paid year..."
        defer { isWorking = false }
        do {
            try BookGiftClaimStore.savePendingBoundYearRequest(purchase)
            pendingBoundYearRequest = purchase
            let draft = try await PhysicalBookQuoteClient().openBoundYearGift(purchase)
            let pending = PendingBookGiftPurchase(bookSeal: nil, boundYear: draft)
            try BookGiftClaimStore.savePendingPurchase(pending)
            pendingPurchase = pending
            try BookGiftClaimStore.savePendingBoundYearRequest(nil)
            pendingBoundYearRequest = nil
            resumeBoundYearGiftPayment(draft)
        } catch {
            if let failure = error as? PhysicalBookQuoteClient.ResponseError, failure.permitsCorrectedPurchase {
                do {
                    try BookGiftClaimStore.savePendingBoundYearRequest(nil)
                    pendingBoundYearRequest = nil
                } catch { /* Keep the saved request if Keychain could not clear it. */ }
            }
            statusMessage = "The Bound Year stayed shut: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func closeUnpaidGift() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let id = try await PhysicalBookQuoteClient().closeUnpaidGift(
                pendingBoundYearRequest,
                attemptID: pendingPurchase?.boundYear?.membership.purchaseAttemptID
            )
            try BookGiftClaimStore.savePendingBoundYearRequest(nil)
            // Write an empty purchase through the checked Keychain path; a
            // failed deletion must not silently discard the only recovery key.
            try BookGiftClaimStore.savePendingPurchase(PendingBookGiftPurchase(bookSeal: nil, boundYear: nil))
            pendingBoundYearRequest = nil
            pendingPurchase = nil
            await PhysicalBookQuoteClient.completePurchaseAttempt(id)
            statusMessage = "Closed. That checkout cannot take a payment now."
        } catch {
            statusMessage = "The gift is still saved: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func resumeBoundYearGiftPayment(_ draft: BookGiftBoundYearDraft) {
        Task { @MainActor in
            isWorking = true
            do {
                let summary = try await PhysicalBookQuoteClient().giftSummary(claimToken: draft.gift.claimToken)
                if [.readyToClaim, .claimed, .redeemed].contains(summary.status) {
                    try await finishBoundYearGift(draft, summary: summary)
                    isWorking = false
                    return
                }
                guard summary.status == .paymentPending else {
                    isWorking = false
                    statusMessage = "That gift has closed. The Bindery can check its receipt."
                    return
                }
                let sheet = try makePaymentSheet(clientSecret: draft.membership.clientSecret)
                present(sheet) { result in
                    Task { @MainActor in
                        defer { isWorking = false }
                        guard result == .completed else { statusMessage = result.message; return }
                        do {
                            let paid = try await PhysicalBookQuoteClient().giftSummary(claimToken: draft.gift.claimToken)
                            guard [.readyToClaim, .claimed, .redeemed].contains(paid.status) else {
                                statusMessage = "The till is still checking the receipt. This gift is saved; continue it in a moment."
                                return
                            }
                            try await finishBoundYearGift(draft, summary: paid)
                        } catch {
                            statusMessage = "The receipt wouldn't open. This gift is saved; continue it when the connection returns."
                        }
                    }
                }
            } catch {
                isWorking = false
                statusMessage = "The secure till would not reopen: \(error.localizedDescription)"
            }
        }
    }

    @MainActor
    private func finishBoundYearGift(_ draft: BookGiftBoundYearDraft, summary: BookGiftSummary) async throws {
        var gift = draft.gift
        gift.gift = summary
        try BookGiftClaimStore.saveCreatedGift(gift)
        createdGift = gift
        BookGiftClaimStore.clearPendingPurchase()
        pendingPurchase = nil
        await PhysicalBookQuoteClient.completePurchaseAttempt(draft.membership.purchaseAttemptID)
        statusMessage = nil
        route = .share
    }

    @MainActor
    private func loadClaim() async {
        let token = Self.token(from: claimToken)
        guard !token.isEmpty else { return }
        isWorking = true
        statusMessage = "Listening at the seal..."
        defer { isWorking = false }
        do {
            claimToken = token
            claimSummary = try await PhysicalBookQuoteClient().giftSummary(claimToken: token)
            statusMessage = nil
        } catch {
            claimSummary = nil
            statusMessage = "That seal would not open: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func acceptClaim() async {
        let token = Self.token(from: claimToken)
        guard !token.isEmpty else { return }
        isWorking = true
        statusMessage = "Turning the key..."
        defer { isWorking = false }
        do {
            let response = try await PhysicalBookQuoteClient().claimGift(claimToken: token)
            if let pressPass = response.pressPass {
                try BookGiftClaimStore.save(claimToken: token, pressPass: pressPass)
            }
            if let membershipID = response.membershipID,
               let startedAt = response.membershipStartedAt,
               let paidThrough = response.membershipPaidThrough {
                let membership = BoundYearMembership(
                    cadence: .annual,
                    status: .active,
                    startedAt: Date(timeIntervalSince1970: TimeInterval(startedAt)),
                    paidThrough: Date(timeIntervalSince1970: TimeInterval(paidThrough)),
                    endedAt: Date(timeIntervalSince1970: TimeInterval(paidThrough))
                )
                onClaimBoundYear(membership, membershipID)
                onClaimBoundYearDigitalAccess()
            }
            claimedGift = response
            route = .claimed
            statusMessage = nil
        } catch {
            statusMessage = "The key did not turn yet: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func declineClaim() async {
        let token = Self.token(from: claimToken)
        guard !token.isEmpty else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            claimSummary = try await PhysicalBookQuoteClient().declineGift(claimToken: token)
            statusMessage = "Declined. The purchaser can ask for the payment back."
        } catch {
            statusMessage = "The gift could not be declined yet: \(error.localizedDescription)"
        }
    }

    private var boundYearAddress: PhysicalBookShippingAddress? {
        guard canBuyBoundYearGift else { return nil }
        return PhysicalBookShippingAddress(
            name: recipientName.trimmingCharacters(in: .whitespacesAndNewlines),
            street1: street1.trimmingCharacters(in: .whitespacesAndNewlines),
            street2: nilIfEmpty(street2),
            city: city.trimmingCharacters(in: .whitespacesAndNewlines),
            stateCode: nilIfEmpty(stateCode.uppercased()),
            countryCode: countryCode.uppercased(),
            postalCode: postalCode.trimmingCharacters(in: .whitespacesAndNewlines),
            phoneNumber: nilIfEmpty(phoneNumber),
            recipientTaxID: nilIfEmpty(recipientTaxID)
        )
    }

    private func makePaymentSheet(clientSecret: String) throws -> PaymentSheet {
        STPAPIClient.shared.publishableKey = try PhysicalBookQuoteClient.configuredStripePublishableKey()
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

    @MainActor
    private func present(_ sheet: PaymentSheet, completion: @escaping @MainActor (GiftPaymentResult) -> Void) {
        guard let presenter = UIApplication.shared.reenchantedTopViewController() else {
            completion(.failed("Secure checkout could not open."))
            return
        }
        sheet.present(from: presenter) { result in
            Task { @MainActor in
                switch result {
                case .completed: completion(.completed)
                case .canceled: completion(.cancelled)
                case .failed(let error): completion(.failed(error.localizedDescription))
                }
            }
        }
    }

    private func resetCheckout() {
        quote = nil
        selectedShippingOptionID = nil
        statusMessage = nil
    }

    private var giftablePrintSpecs: [PrintSpec] {
        PrintSpec.printableVariants(for: selectedGiftEditionKind)
    }

    private var selectedGiftPrintSpec: PrintSpec {
        giftablePrintSpecs.first {
            PhysicalBookVariant.from($0).id == selectedGiftVariantID
        } ?? giftablePrintSpecs.first ?? .perfectBoundSoftcover6x9
    }

    private var selectedGiftMaximumPageCount: Int {
        BookGiftEditionAllowance.maximumPageCount(for: selectedGiftEditionKind)
            ?? selectedGiftPrintSpec.maximumPages
    }

    private func selectGiftEdition(_ kind: PublicationEditionKind) {
        guard pendingPurchase?.bookSeal == nil else { return }
        selectedGiftEditionKind = kind
        if let first = PrintSpec.printableVariants(for: kind).first {
            selectedGiftVariantID = PhysicalBookVariant.from(first).id
        }
        resetCheckout()
    }

    private func selectGiftBinding(_ spec: PrintSpec) {
        guard pendingPurchase?.bookSeal == nil else { return }
        selectedGiftVariantID = PhysicalBookVariant.from(spec).id
        resetCheckout()
    }

    private func giftSelectionRow(
        title: String,
        detail: String,
        isSelected: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? BookPalette.violet : BookPalette.ink.opacity(0.34))
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.bold))
                    .foregroundStyle(BookPalette.ink)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(BookPalette.ink.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }

    private func giftEditionName(_ kind: PublicationEditionKind) -> String {
        switch kind {
        case .weekly: return "Weekly issue"
        case .monthly: return "Monthly edition"
        case .seasonal: return "Seasonal book"
        case .annual: return "Annual"
        case .special: return "Special edition"
        }
    }

    private func giftEditionDetail(_ kind: PublicationEditionKind) -> String {
        switch kind {
        case .weekly: return "One closed week, slim and quick to post."
        case .monthly: return "One whole month with room for its proper chapters."
        case .seasonal: return "A season gathered into one volume."
        case .annual: return "Their year, caught before it can run off."
        case .special: return "A named gathering from their Book."
        }
    }

    private func giftObjectDescription(_ summary: BookGiftSummary) -> String? {
        guard summary.kind == .bookOfRecipient,
              let variantID = summary.includedVariantID,
              let maximumPageCount = summary.includedPageCount else { return nil }
        let kind = summary.includedEditionKind ?? .monthly
        let binding = PrintSpec.giftableBookSpecs.first {
            PhysicalBookVariant.from($0).id == variantID
        }?.giftShelfName ?? "chosen binding"
        return "One \(giftEditionName(kind).lowercased()) · \(binding) · up to \(maximumPageCount) pages"
    }

    private func shippingChoice(_ option: PhysicalBookShippingOption, quote: PhysicalBookQuote) -> some View {
        let total = PhysicalBookPricing.priceBreakdown(
            request: quote.request,
            shippingCents: option.price.cents,
            estimatedTaxCents: option.estimatedTax?.cents ?? 0,
            policy: quote.pricingPolicy
        ).total
        return Button {
            selectedShippingOptionID = option.id
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: selectedShippingOptionID == option.id ? "checkmark.circle.fill" : "circle")
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.displayName).font(.caption.weight(.bold))
                    Text("\(option.estimatedDaysMin)-\(option.estimatedDaysMax) business days")
                        .font(.caption2)
                        .foregroundStyle(BookPalette.ink.opacity(0.56))
                }
                Spacer()
                Text(Self.money(total)).font(.caption.weight(.bold))
            }
            .foregroundStyle(BookPalette.ink)
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func claimStatusView(_ summary: BookGiftSummary) -> some View {
        switch summary.status {
        case .paymentPending:
            Label("The purchaser's payment is still settling.", systemImage: "hourglass")
        case .readyToClaim:
            Label("Paid and ready for you.", systemImage: "checkmark.seal.fill")
        case .claimed:
            Label("Already claimed on an installation.", systemImage: "key.fill")
        case .redeemed:
            Label("This gift has already gone to press.", systemImage: "shippingbox.fill")
        case .declined:
            Label("This gift was declined.", systemImage: "hand.raised.fill")
        case .refunded:
            Label("This gift was refunded.", systemImage: "arrow.uturn.backward.circle.fill")
        }
    }

    private func giftTitle(_ kind: BookGiftKind) -> String {
        switch kind {
        case .copyOfGiverBook: return "A copy of their Book"
        case .bookOfRecipient: return "One edition of your own"
        case .boundYear: return "The Bound Year"
        }
    }

    private func giftHero(eyebrow: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(eyebrow)
                .font(.caption.weight(.black))
                .kerning(1.2)
                .foregroundStyle(BookPalette.lampGold)
            Text(title)
                .font(.system(.largeTitle, design: .serif, weight: .bold))
                .foregroundStyle(BookPalette.nightText)
            Text(detail)
                .font(.system(.body, design: .serif))
                .foregroundStyle(BookPalette.nightText.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func giftChoice(
        title: String,
        detail: String,
        systemImage: String,
        accent: Color,
        badge: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(BookPalette.nightPanel)
                    .frame(width: 44, height: 44)
                    .background(accent, in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(title)
                            .font(.system(.headline, design: .serif, weight: .bold))
                        Spacer()
                        if let badge {
                            Text(badge)
                                .font(.caption2.weight(.black))
                                .foregroundStyle(accent)
                        }
                    }
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(BookPalette.ink.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BookPalette.ink.opacity(0.38))
            }
            .foregroundStyle(BookPalette.ink)
            .padding(13)
            .background(BookPalette.page.opacity(0.96), in: RoundedRectangle(cornerRadius: 11))
            .overlay { RoundedRectangle(cornerRadius: 11).stroke(accent.opacity(0.30), lineWidth: 1) }
        }
        .buttonStyle(.plain)
    }

    private func giftPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10, content: content)
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BookPalette.page.opacity(0.96), in: RoundedRectangle(cornerRadius: 11))
            .overlay { RoundedRectangle(cornerRadius: 11).stroke(BookPalette.ink.opacity(0.12), lineWidth: 1) }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2.weight(.black))
            .kerning(0.8)
            .foregroundStyle(BookPalette.violet)
    }

    @ViewBuilder
    private func workingLabel(_ text: String, systemImage: String) -> some View {
        if isWorking {
            ProgressView().controlSize(.small).frame(maxWidth: .infinity)
        } else {
            Label(text, systemImage: systemImage)
                .font(.callout.weight(.bold))
                .frame(maxWidth: .infinity)
        }
    }

    private func nilIfEmpty(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func money(_ amount: MoneyAmount) -> String {
        (Decimal(amount.cents) / 100).formatted(.currency(code: amount.currencyCode))
    }

    private static func token(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), let fragment = url.fragment, !fragment.isEmpty {
            return fragment
        }
        if let url = URL(string: trimmed), url.scheme == "reenchanted" {
            return url.pathComponents.dropFirst().first ?? url.host ?? ""
        }
        return trimmed
    }
}

private enum GiftPaymentResult: Equatable {
    case completed
    case cancelled
    case failed(String)

    var message: String {
        switch self {
        case .completed: return "Payment complete."
        case .cancelled: return "Checkout closed. Nothing was charged."
        case .failed(let reason): return "Payment failed: \(reason)"
        }
    }
}

private extension View {
    func giftField() -> some View {
        self
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(BookPalette.ink.opacity(0.055), in: RoundedRectangle(cornerRadius: 8))
    }
}
