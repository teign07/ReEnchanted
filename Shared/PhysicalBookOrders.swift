import Foundation

/// Shared app/server contract for quoting and ordering a printed Book of You.
/// The app owns PDF generation; the backend owns payment, Lulu credentials, PDF
/// hosting, tax/shipping quotes, and print-job submission.
/// A membership opened but not yet paid for. The client secret is confirmed
/// with the same Stripe sheet the one-off books use: there is one checkout in
/// this product, not two.
struct BoundYearMembershipDraft: Codable, Equatable {
    var membershipID: String
    var customerID: String
    var cadence: String
    var status: String
    var clientSecret: String
    var currentPeriodEnd: Int?
    var startedAt: Int?
}

/// What the Worker knows about a membership right now.
struct BoundYearMembershipStatus: Codable, Equatable {
    var membershipID: String
    var status: String
    var cancelAtPeriodEnd: Bool
    var currentPeriodEnd: Int?
    var shippingAddressPresent: Bool? = nil
    var shippingAddressSummary: String? = nil

    var periodEndsAt: Date? {
        currentPeriodEnd.map { Date(timeIntervalSince1970: TimeInterval($0)) }
    }

    /// Stripe keeps a cancelled subscription `active` until the period the
    /// reader already paid for runs out, which is exactly the behaviour we
    /// want: the volumes those months earned still arrive.
    var isStanding: Bool { status == "active" || status == "trialing" || status == "past_due" }
}

struct BoundYearShippingStatus: Codable, Equatable {
    var membershipID: String
    var shippingAddressPresent: Bool
    var shippingAddressSummary: String?
}

struct BoundYearDispatchPreparation: Codable, Equatable {
    var membershipID: String
    var seasonKey: String
    var editionID: String?
    var dispatchToken: String?
    var alreadySubmitted: Bool
    var shippingAddressSummary: String?
    var order: PhysicalBookOrder?
    /// Lulu's page-count- and SKU-specific one-piece cover canvas. The app
    /// renders against this authority after the interior reveals its final
    /// page count instead of guessing the spine or jacket width locally.
    var coverDimensions: PhysicalBookCoverDimensions? = nil
}

struct PhysicalBookCoverDimensions: Codable, Equatable {
    var widthPoints: Double
    var heightPoints: Double
}

struct BoundYearDispatchRequest: Codable, Equatable {
    var editionID: String
    var variant: PhysicalBookVariant
    var pageCount: Int
    var selectedOptionIDs: [String]
    /// Used only for Lulu linen-with-dust-jacket SKUs. Lulu stamps these two
    /// fields on the cloth spine; the uploaded cover PDF is the jacket.
    var foilStampTitleText: String? = nil
    var foilStampAuthorText: String? = nil
}

/// An extra the Bindery is offering, as the Worker described it.
///
/// Everything here: the title, the pitch, and above all the price: arrives
/// from the server. The app renders what it is sent and never decides what an
/// option costs, which is what lets a new cover ship the same day instead of
/// waiting on an App Store review.
struct PhysicalBookPrintOption: Codable, Equatable, Identifiable {
    enum Family: String, Codable, Equatable {
        case binding
        case finish
        case cover
        case copies
    }

    var id: String
    var family: Family
    var title: String
    /// The Bindery's own line about it.
    var pitch: String
    var priceDeltaCents: Int
    /// Nil means every binding.
    var appliesToVariantIDs: [String]?
    /// Things the reader must supply first: "photo" for a cover from their
    /// own camera roll.
    var requires: [String]
    /// Set when choosing this option changes the binding itself.
    var resultingVariantID: String?

    var requiresPhoto: Bool { requires.contains("photo") }
    var changesBinding: Bool { resultingVariantID != nil }
}

struct PhysicalBookPrintOptionCatalogue: Codable, Equatable {
    var variantID: String
    var options: [PhysicalBookPrintOption]

    /// Grouped the way the shop shows them: covers first, because they are the
    /// personal ones and they cost the Bindery nothing to make.
    var byFamily: [(family: PhysicalBookPrintOption.Family, options: [PhysicalBookPrintOption])] {
        let order: [PhysicalBookPrintOption.Family] = [.cover, .binding, .finish, .copies]
        return order.compactMap { family in
            let matching = options.filter { $0.family == family }
            return matching.isEmpty ? nil : (family, matching)
        }
    }
}

struct PhysicalBookQuoteRequest: Codable, Equatable {
    var apiVersion: Int
    var editionID: String
    var variant: PhysicalBookVariant
    var pageCount: Int
    var quantity: Int
    var shipTo: PhysicalBookShippingDestination
    var currencyCode: String
    /// Extras the reader chose, by id only. The app never sends a price: the
    /// Worker resolves these against its own catalogue and refuses anything it
    /// does not recognise, so an id is all it is safe to say.
    ///
    /// Sorted and deduplicated at the point of choosing, because the same
    /// choices must always produce the same amount or the settled-amount check
    /// will reject an order that differed only by the order of taps.
    var selectedOptionIDs: [String]

    init(
        apiVersion: Int = 1,
        editionID: String,
        variant: PhysicalBookVariant,
        pageCount: Int,
        quantity: Int = 1,
        shipTo: PhysicalBookShippingDestination,
        currencyCode: String = "USD",
        selectedOptionIDs: [String] = []
    ) {
        self.selectedOptionIDs = selectedOptionIDs
        self.apiVersion = apiVersion
        self.editionID = editionID
        self.variant = variant
        self.pageCount = pageCount
        self.quantity = quantity
        self.shipTo = shipTo
        self.currencyCode = currencyCode
    }
}

struct PhysicalBookVariant: Codable, Equatable, Identifiable {
    var id: String
    var displayName: String
    var luluPackageID: String
    var coverTreatment: PrintSpec.CoverTreatment
    var manufacturingBasePriceCentsUSD: Int
    var manufacturingPerPagePriceTenThousandthsUSD: Int

    /// The catalogue id for a spec.
    ///
    /// This was a binary `coverTreatment == .linenWrap ? … : …`, which silently
    /// mislabelled every spec that was not one of the two original hardcovers -
    /// and the id is what the Worker checks against its allowlist, so a
    /// mislabel is a rejected order. An exhaustive switch means adding a
    /// binding is a compile error here instead of a runtime surprise there.
    static func id(for treatment: PrintSpec.CoverTreatment) -> String {
        switch treatment {
        case .linenWrap: return "cloth-foil-hardcover-6x9"
        case .caseWrap: return "illustrated-hardcover-6x9"
        case .perfectBound: return "perfect-bound-softcover-6x9"
        case .saddleStitch: return "saddle-stitched-weekly-6x9"
        }
    }

    static func from(_ spec: PrintSpec) -> PhysicalBookVariant {
        PhysicalBookVariant(
            id: id(for: spec.coverTreatment),
            displayName: spec.name,
            luluPackageID: spec.luluPackageID,
            coverTreatment: spec.coverTreatment,
            manufacturingBasePriceCentsUSD: spec.basePriceCentsUSD,
            manufacturingPerPagePriceTenThousandthsUSD: spec.perPagePriceTenThousandthsUSD
        )
    }
}

struct PhysicalBookShippingDestination: Codable, Equatable {
    var countryCode: String
    var stateCode: String?
    var postalCode: String
    var city: String?
    var street1: String?
    var street2: String?
    var phoneNumber: String?
    /// Customs identity required by Lulu for a small set of destinations.
    /// It lives only in the short-lived checkout record and is erased after
    /// the printer accepts the parcel.
    var recipientTaxID: String?

    init(
        countryCode: String,
        stateCode: String? = nil,
        postalCode: String,
        city: String? = nil,
        street1: String? = nil,
        street2: String? = nil,
        phoneNumber: String? = nil,
        recipientTaxID: String? = nil
    ) {
        self.countryCode = countryCode
        self.stateCode = stateCode
        self.postalCode = postalCode
        self.city = city
        self.street1 = street1
        self.street2 = street2
        self.phoneNumber = phoneNumber
        self.recipientTaxID = recipientTaxID
    }
}

struct PhysicalBookShippingAddress: Codable, Equatable {
    var name: String
    var street1: String
    var street2: String?
    var city: String
    var stateCode: String?
    var countryCode: String
    var postalCode: String
    var phoneNumber: String?
    var recipientTaxID: String? = nil
}

struct PhysicalBookPrintFiles: Codable, Equatable {
    var interiorSourceURL: URL
    var interiorMD5: String
    var coverSourceURL: URL
    var coverMD5: String
}

struct PhysicalBookHostedPrintFile: Codable, Equatable {
    enum Kind: String, Codable, Equatable {
        case interior
        case cover
    }

    var kind: Kind
    var sourceURL: URL
    var md5: String
    var byteCount: Int
}

struct PhysicalBookQuote: Codable, Equatable, Identifiable {
    var id: String
    /// A short-lived, quote-scoped capability. It authorizes only this checkout
    /// and replaces treating one extractable app-wide bearer token as identity.
    var checkoutToken: String = ""
    var request: PhysicalBookQuoteRequest
    var manufacturingSubtotal: MoneyAmount
    var shippingOptions: [PhysicalBookShippingOption]
    var pricingPolicy: PhysicalBookPricingPolicy
    var expiresAt: Date
    /// Lulu's authoritative one-piece canvas for this SKU and final rendered
    /// page count. Optional keeps quotes minted before the press contract
    /// changed decodable; checkout must refresh an older quote before upload.
    var coverDimensions: PhysicalBookCoverDimensions? = nil
}

struct PhysicalBookShippingOption: Codable, Equatable, Identifiable {
    var id: String
    var displayName: String
    var estimatedDaysMin: Int
    var estimatedDaysMax: Int
    var price: MoneyAmount
    var estimatedTax: MoneyAmount? = nil
}

struct PhysicalBookOrderRequest: Codable, Equatable {
    var quoteID: String
    var quoteRequest: PhysicalBookQuoteRequest
    var paymentIntentID: String
    var contactEmail: String
    var shippingAddress: PhysicalBookShippingAddress
    var selectedShippingOptionID: String
    var selectedShippingOption: PhysicalBookShippingOption?
    var printFiles: PhysicalBookPrintFiles
}

struct PhysicalBookOrderPreview: Codable, Equatable {
    var mode: String
    var quoteID: String
    var luluPrintJobPayload: LuluPrintJobPayload
}

struct LuluPrintJobPayload: Codable, Equatable {
    var externalID: String
    var contactEmail: String
    var shippingLevel: String
    var lineItems: [LuluPrintJobLineItem]
    var shippingAddress: LuluShippingAddress
    var recipientTaxID: String? = nil

    enum CodingKeys: String, CodingKey {
        case externalID = "external_id"
        case contactEmail = "contact_email"
        case shippingLevel = "shipping_level"
        case lineItems = "line_items"
        case shippingAddress = "shipping_address"
        case recipientTaxID = "recipient_tax_id"
    }
}

struct LuluPrintJobLineItem: Codable, Equatable {
    var externalID: String
    var podPackageID: String
    var quantity: Int
    var interior: LuluPrintJobFile
    var cover: LuluPrintJobFile

    enum CodingKeys: String, CodingKey {
        case externalID = "external_id"
        case podPackageID = "pod_package_id"
        case quantity
        case interior
        case cover
    }
}

struct LuluPrintJobFile: Codable, Equatable {
    var sourceURL: URL
    var sourceMD5: String

    enum CodingKeys: String, CodingKey {
        case sourceURL = "source_url"
        case sourceMD5 = "source_md5sum"
    }
}

struct LuluShippingAddress: Codable, Equatable {
    var name: String
    var street1: String
    var street2: String?
    var city: String
    var stateCode: String?
    var countryCode: String
    var postcode: String
    var phoneNumber: String?

    enum CodingKeys: String, CodingKey {
        case name
        case street1
        case street2
        case city
        case stateCode = "state_code"
        case countryCode = "country_code"
        case postcode
        case phoneNumber = "phone_number"
    }
}

struct PhysicalBookPaymentIntentRequest: Codable, Equatable {
    var quoteID: String
    var quoteRequest: PhysicalBookQuoteRequest
    var selectedShippingOption: PhysicalBookShippingOption
    var contactEmail: String
}

struct PhysicalBookPaymentIntent: Codable, Equatable, Identifiable {
    var id: String
    var clientSecret: String
    var amount: MoneyAmount
    var quoteID: String
    var selectedShippingOptionID: String
}

struct PhysicalBookOrder: Codable, Equatable, Identifiable {
    enum Status: String, Codable, Equatable {
        case paymentPending
        case submittedToLulu
        case inProduction
        case shipped
        case delivered
        case cancelled
        case failed
    }

    var id: String
    var quoteID: String
    var luluPrintJobID: String?
    var status: Status
    var trackingURL: URL?
    var createdAt: Date
    var updatedAt: Date
}

struct PhysicalBookPendingOrderDraft: Codable, Equatable, Identifiable {
    enum Status: String, Codable, Equatable {
        case paymentReceivedPendingPrintSubmission
        case submissionWaitingForLuluCredentials
        case submittedToBackend
    }

    var id: String
    var createdAt: Date
    var updatedAt: Date
    var editionID: String
    var quoteID: String
    /// Older drafts decode without this value and must be re-quoted before they
    /// can reach the hardened backend.
    var checkoutToken: String?
    var quoteRequest: PhysicalBookQuoteRequest?
    var paymentIntentID: String
    var contactEmail: String
    var shippingAddress: PhysicalBookShippingAddress
    var selectedShippingOptionID: String
    var selectedShippingOption: PhysicalBookShippingOption?
    var variant: PhysicalBookVariant
    var amount: MoneyAmount
    var status: Status
    var submittedOrder: PhysicalBookOrder?

    init(
        id: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        editionID: String,
        quoteID: String,
        checkoutToken: String? = nil,
        quoteRequest: PhysicalBookQuoteRequest? = nil,
        paymentIntentID: String,
        contactEmail: String,
        shippingAddress: PhysicalBookShippingAddress,
        selectedShippingOptionID: String,
        selectedShippingOption: PhysicalBookShippingOption? = nil,
        variant: PhysicalBookVariant,
        amount: MoneyAmount,
        status: Status = .paymentReceivedPendingPrintSubmission,
        submittedOrder: PhysicalBookOrder? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.editionID = editionID
        self.quoteID = quoteID
        self.checkoutToken = checkoutToken
        self.quoteRequest = quoteRequest
        self.paymentIntentID = paymentIntentID
        self.contactEmail = contactEmail
        self.shippingAddress = shippingAddress
        self.selectedShippingOptionID = selectedShippingOptionID
        self.selectedShippingOption = selectedShippingOption
        self.variant = variant
        self.amount = amount
        self.status = status
        self.submittedOrder = submittedOrder
    }
}

struct MoneyAmount: Codable, Equatable {
    var currencyCode: String
    var cents: Int

    var decimalValue: Decimal {
        Decimal(cents) / 100
    }
}

struct PhysicalBookPricingPolicy: Codable, Equatable {
    /// Per-copy contribution margin before payment processing. Shipping and tax
    /// remain pass-through line items; this is the actual product profit target.
    var markupPerCopyCents: Int
    /// Domestic card/wallet processing fee in basis points, e.g. 2.9% = 290.
    var paymentFeeBasisPoints: Int
    /// Fixed domestic card/wallet processing fee, e.g. Stripe standard US $0.30.
    var paymentFeeFixedCents: Int

    static let standardUS = PhysicalBookPricingPolicy(
        markupPerCopyCents: 3500,
        paymentFeeBasisPoints: 290,
        paymentFeeFixedCents: 30
    )
}

struct PhysicalBookPriceBreakdown: Codable, Equatable {
    var manufacturingSubtotal: MoneyAmount
    var shipping: MoneyAmount
    var estimatedTax: MoneyAmount
    var markup: MoneyAmount
    /// What the chosen extras added, itemised rather than folded silently into
    /// the markup. Money stays simple, clear and fair, and that includes the
    /// upsells. Optional so breakdowns computed before extras existed decode.
    var printOptions: MoneyAmount? = nil
    var selectedOptionIDs: [String]? = nil
    var paymentProcessingFee: MoneyAmount
    var total: MoneyAmount
}

enum PhysicalBookPricing {
    static func rawManufacturingSubtotalCents(variant: PhysicalBookVariant, pageCount: Int, quantity: Int) -> Int {
        let perCopyTenThousandths = variant.manufacturingBasePriceCentsUSD * 100
            + pageCount * variant.manufacturingPerPagePriceTenThousandthsUSD
        let perCopyCents = (perCopyTenThousandths + 50) / 100
        return perCopyCents * max(0, quantity)
    }

    static func markupSubtotalCents(policy: PhysicalBookPricingPolicy = .standardUS, quantity: Int) -> Int {
        policy.markupPerCopyCents * max(0, quantity)
    }

    /// Grosses up the charge so the payment fee is covered by the total. For
    /// example, a $31.51 subtotal at 2.9% + $0.30 charges $32.77, leaving about
    /// $31.52 after processing.
    static func paymentProcessingFeeCents(chargeSubtotalCents: Int, policy: PhysicalBookPricingPolicy = .standardUS) -> Int {
        guard chargeSubtotalCents > 0 else { return 0 }
        let denominator = 10_000 - policy.paymentFeeBasisPoints
        guard denominator > 0 else { return policy.paymentFeeFixedCents }
        let grossTotal = ((chargeSubtotalCents + policy.paymentFeeFixedCents) * 10_000 + denominator - 1) / denominator
        return grossTotal - chargeSubtotalCents
    }

    /// The display estimate, mirroring the Worker's arithmetic exactly.
    ///
    /// `catalogue` supplies the prices for whatever extras the reader chose.
    /// The app cannot know what an option costs on its own: that is the point
    /// of the catalogue living on the server, so the caller passes back what
    /// the server told it. Get this wrong and the till shows one number while
    /// the card is charged another, which is the single worst bug this screen
    /// could have.
    static func priceBreakdown(
        request: PhysicalBookQuoteRequest,
        shippingCents: Int,
        estimatedTaxCents: Int = 0,
        policy: PhysicalBookPricingPolicy = .standardUS,
        catalogue: PhysicalBookPrintOptionCatalogue? = nil
    ) -> PhysicalBookPriceBreakdown {
        let manufacturing = rawManufacturingSubtotalCents(
            variant: request.variant,
            pageCount: request.pageCount,
            quantity: request.quantity
        )
        let chosen = chosenOptions(request: request, catalogue: catalogue)
        let extras = chosen.reduce(0) { $0 + $1.priceDeltaCents } * max(0, request.quantity)
        let markup = markupSubtotalCents(policy: policy, quantity: request.quantity) + extras
        let subtotalBeforeProcessing = manufacturing + shippingCents + estimatedTaxCents + markup
        let processing = paymentProcessingFeeCents(chargeSubtotalCents: subtotalBeforeProcessing, policy: policy)
        let currency = request.currencyCode
        return PhysicalBookPriceBreakdown(
            manufacturingSubtotal: MoneyAmount(currencyCode: currency, cents: manufacturing),
            shipping: MoneyAmount(currencyCode: currency, cents: shippingCents),
            estimatedTax: MoneyAmount(currencyCode: currency, cents: estimatedTaxCents),
            markup: MoneyAmount(currencyCode: currency, cents: markup),
            printOptions: MoneyAmount(currencyCode: currency, cents: extras),
            selectedOptionIDs: chosen.map(\.id),
            paymentProcessingFee: MoneyAmount(currencyCode: currency, cents: processing),
            total: MoneyAmount(currencyCode: currency, cents: subtotalBeforeProcessing + processing)
        )
    }

    /// Only options the catalogue actually offers for this binding count. An id
    /// with no catalogue entry is worth nothing here rather than being guessed
    /// at, and the Worker will refuse it outright at quote time anyway.
    static func chosenOptions(
        request: PhysicalBookQuoteRequest,
        catalogue: PhysicalBookPrintOptionCatalogue?
    ) -> [PhysicalBookPrintOption] {
        guard let catalogue, catalogue.variantID == request.variant.id else { return [] }
        let selected = Set(request.selectedOptionIDs)
        return catalogue.options.filter { selected.contains($0.id) }
    }
}

extension PrintSpec {
    var basePriceCentsUSD: Int {
        NSDecimalNumber(decimal: basePriceUSD * 100).rounding(accordingToBehavior: nil).intValue
    }

    var perPagePriceTenThousandthsUSD: Int {
        NSDecimalNumber(decimal: perPagePriceUSD * 10000).rounding(accordingToBehavior: nil).intValue
    }
}
