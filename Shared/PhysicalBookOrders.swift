import Foundation

/// Shared app/server contract for quoting and ordering a printed Book of You.
/// The app owns PDF generation; the backend owns payment, Lulu credentials, PDF
/// hosting, tax/shipping quotes, and print-job submission.
struct PhysicalBookQuoteRequest: Codable, Equatable {
    var apiVersion: Int
    var editionID: String
    var variant: PhysicalBookVariant
    var pageCount: Int
    var quantity: Int
    var shipTo: PhysicalBookShippingDestination
    var currencyCode: String

    init(
        apiVersion: Int = 1,
        editionID: String,
        variant: PhysicalBookVariant,
        pageCount: Int,
        quantity: Int = 1,
        shipTo: PhysicalBookShippingDestination,
        currencyCode: String = "USD"
    ) {
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

    static func from(_ spec: PrintSpec) -> PhysicalBookVariant {
        PhysicalBookVariant(
            id: spec.coverTreatment == .linenWrap ? "cloth-foil-hardcover-6x9" : "illustrated-hardcover-6x9",
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
    var request: PhysicalBookQuoteRequest
    var manufacturingSubtotal: MoneyAmount
    var shippingOptions: [PhysicalBookShippingOption]
    var pricingPolicy: PhysicalBookPricingPolicy
    var expiresAt: Date
}

struct PhysicalBookShippingOption: Codable, Equatable, Identifiable {
    var id: String
    var displayName: String
    var estimatedDaysMin: Int
    var estimatedDaysMax: Int
    var price: MoneyAmount
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

    enum CodingKeys: String, CodingKey {
        case externalID = "external_id"
        case contactEmail = "contact_email"
        case shippingLevel = "shipping_level"
        case lineItems = "line_items"
        case shippingAddress = "shipping_address"
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
        markupPerCopyCents: 1200,
        paymentFeeBasisPoints: 290,
        paymentFeeFixedCents: 30
    )
}

struct PhysicalBookPriceBreakdown: Codable, Equatable {
    var manufacturingSubtotal: MoneyAmount
    var shipping: MoneyAmount
    var estimatedTax: MoneyAmount
    var markup: MoneyAmount
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

    static func priceBreakdown(
        request: PhysicalBookQuoteRequest,
        shippingCents: Int,
        estimatedTaxCents: Int = 0,
        policy: PhysicalBookPricingPolicy = .standardUS
    ) -> PhysicalBookPriceBreakdown {
        let manufacturing = rawManufacturingSubtotalCents(
            variant: request.variant,
            pageCount: request.pageCount,
            quantity: request.quantity
        )
        let markup = markupSubtotalCents(policy: policy, quantity: request.quantity)
        let subtotalBeforeProcessing = manufacturing + shippingCents + estimatedTaxCents + markup
        let processing = paymentProcessingFeeCents(chargeSubtotalCents: subtotalBeforeProcessing, policy: policy)
        let currency = request.currencyCode
        return PhysicalBookPriceBreakdown(
            manufacturingSubtotal: MoneyAmount(currencyCode: currency, cents: manufacturing),
            shipping: MoneyAmount(currencyCode: currency, cents: shippingCents),
            estimatedTax: MoneyAmount(currencyCode: currency, cents: estimatedTaxCents),
            markup: MoneyAmount(currencyCode: currency, cents: markup),
            paymentProcessingFee: MoneyAmount(currencyCode: currency, cents: processing),
            total: MoneyAmount(currencyCode: currency, cents: subtotalBeforeProcessing + processing)
        )
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
