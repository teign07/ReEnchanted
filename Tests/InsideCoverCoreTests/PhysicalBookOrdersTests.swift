import XCTest
@testable import InsideCoverCore

final class PhysicalBookOrdersTests: XCTestCase {
    func testQuoteRequestRoundTripsThroughJSON() throws {
        let request = PhysicalBookQuoteRequest(
            editionID: "edition-2026-06",
            variant: .from(.illustratedHardcover6x9),
            pageCount: 120,
            shipTo: PhysicalBookShippingDestination(countryCode: "US", stateCode: "ME", postalCode: "04915")
        )

        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(PhysicalBookQuoteRequest.self, from: data)

        XCTAssertEqual(decoded, request)
        XCTAssertEqual(decoded.variant.luluPackageID, "0600X0900.FC.STD.CW.060UW444.MXX")
        XCTAssertEqual(decoded.currencyCode, "USD")
    }

    func testManufacturingSubtotalUsesVerifiedLuluPrices() {
        let cloth = PhysicalBookVariant.from(.clothFoilHardcover6x9)
        let illustrated = PhysicalBookVariant.from(.illustratedHardcover6x9)

        XCTAssertEqual(PhysicalBookPricing.rawManufacturingSubtotalCents(variant: cloth, pageCount: 120, quantity: 1), 1951)
        XCTAssertEqual(PhysicalBookPricing.rawManufacturingSubtotalCents(variant: illustrated, pageCount: 120, quantity: 1), 1536)
        XCTAssertEqual(PhysicalBookPricing.rawManufacturingSubtotalCents(variant: illustrated, pageCount: 120, quantity: 2), 3072)
    }

    func testDefaultPricingPolicyAddsProfitAndCoversPaymentFee() {
        let request = PhysicalBookQuoteRequest(
            editionID: "edition-2026-06",
            variant: .from(.clothFoilHardcover6x9),
            pageCount: 120,
            shipTo: PhysicalBookShippingDestination(countryCode: "US", stateCode: "ME", postalCode: "04915")
        )

        let price = PhysicalBookPricing.priceBreakdown(request: request, shippingCents: 799)

        XCTAssertEqual(price.manufacturingSubtotal.cents, 1951)
        XCTAssertEqual(price.shipping.cents, 799)
        XCTAssertEqual(price.markup.cents, 8048)
        XCTAssertEqual(price.paymentProcessingFee.cents, 355)
        XCTAssertEqual(price.total.cents, 11153)
    }

    func testDefaultPricingPolicyScalesMarkupByQuantity() {
        let request = PhysicalBookQuoteRequest(
            editionID: "edition-2026-06",
            variant: .from(.illustratedHardcover6x9),
            pageCount: 120,
            quantity: 2,
            shipTo: PhysicalBookShippingDestination(countryCode: "US", stateCode: "ME", postalCode: "04915")
        )

        let price = PhysicalBookPricing.priceBreakdown(request: request, shippingCents: 999)

        XCTAssertEqual(price.manufacturingSubtotal.cents, 3072)
        XCTAssertEqual(price.markup.cents, 14926)
        XCTAssertEqual(price.paymentProcessingFee.cents, 601)
        XCTAssertEqual(price.total.cents, 19598)
    }

    func testBoundYearPrintSetCostsLessThanTheSameBindingsALaCarte() {
        let softcover = PhysicalBookVariant.from(.perfectBoundSoftcover6x9)
        let cloth = PhysicalBookVariant.from(.clothFoilHardcover6x9)
        let aLaCarteProductTotal =
            PhysicalBookPricing.minimumProductPriceCentsPerCopy(for: softcover)! * 3
            + PhysicalBookPricing.minimumProductPriceCentsPerCopy(for: cloth)!

        XCTAssertEqual(aLaCarteProductTotal, 33_996)
        XCTAssertGreaterThan(aLaCarteProductTotal, BoundYearPricing.monthlyCents * 12)
        XCTAssertGreaterThan(aLaCarteProductTotal, BoundYearPricing.annualCents)
    }

    func testWeeklyIssueKeepsSmallerMagazineMarginAndPrice() {
        let request = PhysicalBookQuoteRequest(
            editionID: "weekly-2026-08-15",
            variant: .from(.saddleStitchedWeekly6x9),
            pageCount: 32,
            shipTo: PhysicalBookShippingDestination(
                countryCode: "US",
                stateCode: "ME",
                postalCode: "04915"
            )
        )

        let price = PhysicalBookPricing.priceBreakdown(request: request, shippingCents: 799)

        XCTAssertEqual(price.manufacturingSubtotal.cents, 480)
        XCTAssertEqual(price.markup.cents, 1519)
        XCTAssertEqual(price.paymentProcessingFee.cents, 115)
        XCTAssertEqual(price.total.cents, 2913)
    }

    func testOrderRequestCarriesPaymentShippingAndHostedPrintFiles() throws {
        let quoteRequest = PhysicalBookQuoteRequest(
            editionID: "edition-2026-06",
            variant: .from(.clothFoilHardcover6x9),
            pageCount: 120,
            shipTo: PhysicalBookShippingDestination(countryCode: "US", stateCode: "ME", postalCode: "04915")
        )
        let shippingOption = PhysicalBookShippingOption(
            id: "MAIL",
            displayName: "Mail",
            estimatedDaysMin: 5,
            estimatedDaysMax: 10,
            price: MoneyAmount(currencyCode: "USD", cents: 799)
        )
        let order = PhysicalBookOrderRequest(
            quoteID: "quote-123",
            quoteRequest: quoteRequest,
            paymentIntentID: "pi_123",
            contactEmail: "reader@example.com",
            shippingAddress: PhysicalBookShippingAddress(
                name: "Reader",
                street1: "1 Harbor St",
                street2: nil,
                city: "Belfast",
                stateCode: "ME",
                countryCode: "US",
                postalCode: "04915",
                phoneNumber: nil
            ),
            selectedShippingOptionID: "MAIL",
            selectedShippingOption: shippingOption,
            printFiles: PhysicalBookPrintFiles(
                interiorSourceURL: URL(string: "https://example.com/interior.pdf")!,
                interiorMD5: "0123456789abcdef0123456789abcdef",
                coverSourceURL: URL(string: "https://example.com/cover.pdf")!,
                coverMD5: "abcdef0123456789abcdef0123456789"
            )
        )

        let data = try JSONEncoder().encode(order)
        let decoded = try JSONDecoder().decode(PhysicalBookOrderRequest.self, from: data)

        XCTAssertEqual(decoded, order)
        XCTAssertEqual(decoded.quoteRequest.variant.luluPackageID, "0600X0900.FC.STD.LW.060UW444.MNG")
        XCTAssertEqual(decoded.selectedShippingOptionID, "MAIL")
        XCTAssertEqual(decoded.selectedShippingOption?.price.cents, 799)
        XCTAssertEqual(decoded.printFiles.coverMD5.count, 32)
    }

    func testQuoteResponseCarriesShippingOptionsAndExpiry() throws {
        let quote = PhysicalBookQuote(
            id: "quote-123",
            request: PhysicalBookQuoteRequest(
                editionID: "edition-2026-06",
                variant: .from(.clothFoilHardcover6x9),
                pageCount: 120,
                shipTo: PhysicalBookShippingDestination(countryCode: "US", stateCode: "ME", postalCode: "04915")
            ),
            manufacturingSubtotal: MoneyAmount(currencyCode: "USD", cents: 1951),
            shippingOptions: [
                PhysicalBookShippingOption(
                    id: "MAIL",
                    displayName: "Mail",
                    estimatedDaysMin: 5,
                    estimatedDaysMax: 10,
                    price: MoneyAmount(currencyCode: "USD", cents: 799)
                )
            ],
            pricingPolicy: .standardUS,
            expiresAt: Date(timeIntervalSince1970: 1_783_000_000),
            coverDimensions: PhysicalBookCoverDimensions(widthPoints: 1_192, heightPoints: 666)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(quote)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(PhysicalBookQuote.self, from: data)

        XCTAssertEqual(decoded, quote)
        XCTAssertEqual(decoded.shippingOptions.first?.id, "MAIL")
        XCTAssertEqual(decoded.coverDimensions?.widthPoints, 1_192)
    }

    func testPaymentIntentContractCarriesServerCalculatedAmount() throws {
        let quoteRequest = PhysicalBookQuoteRequest(
            editionID: "edition-2026-06",
            variant: .from(.clothFoilHardcover6x9),
            pageCount: 120,
            shipTo: PhysicalBookShippingDestination(countryCode: "US", stateCode: "ME", postalCode: "04915")
        )
        let shippingOption = PhysicalBookShippingOption(
            id: "MAIL",
            displayName: "Mail",
            estimatedDaysMin: 5,
            estimatedDaysMax: 10,
            price: MoneyAmount(currencyCode: "USD", cents: 799)
        )
        let request = PhysicalBookPaymentIntentRequest(
            quoteID: "quote-123",
            quoteRequest: quoteRequest,
            selectedShippingOption: shippingOption,
            contactEmail: "reader@example.com"
        )
        let response = PhysicalBookPaymentIntent(
            id: "pi_123",
            clientSecret: "pi_123_secret_abc",
            amount: PhysicalBookPricing.priceBreakdown(request: quoteRequest, shippingCents: shippingOption.price.cents).total,
            quoteID: request.quoteID,
            selectedShippingOptionID: shippingOption.id
        )

        let encoder = JSONEncoder()
        let requestData = try encoder.encode(request)
        let responseData = try encoder.encode(response)

        let decoder = JSONDecoder()
        XCTAssertEqual(try decoder.decode(PhysicalBookPaymentIntentRequest.self, from: requestData), request)
        XCTAssertEqual(try decoder.decode(PhysicalBookPaymentIntent.self, from: responseData), response)
        XCTAssertEqual(response.amount.cents, 9092)
    }

    func testPendingOrderDraftPersistsPaidOrderHandoff() throws {
        let quoteRequest = PhysicalBookQuoteRequest(
            editionID: "edition-2026-06",
            variant: .from(.illustratedHardcover6x9),
            pageCount: 120,
            shipTo: PhysicalBookShippingDestination(countryCode: "US", stateCode: "ME", postalCode: "04915")
        )
        let createdAt = Date(timeIntervalSince1970: 1_783_000_000)
        let draft = PhysicalBookPendingOrderDraft(
            id: "pi_123",
            createdAt: createdAt,
            updatedAt: createdAt,
            editionID: "edition-2026-06",
            quoteID: "quote-123",
            quoteRequest: quoteRequest,
            paymentIntentID: "pi_123",
            contactEmail: "reader@example.com",
            shippingAddress: PhysicalBookShippingAddress(
                name: "Reader",
                street1: "1 Harbor St",
                street2: nil,
                city: "Belfast",
                stateCode: "ME",
                countryCode: "US",
                postalCode: "04915",
                phoneNumber: "844-212-0689"
            ),
            selectedShippingOptionID: "MAIL",
            selectedShippingOption: PhysicalBookShippingOption(
                id: "MAIL",
                displayName: "Mail",
                estimatedDaysMin: 5,
                estimatedDaysMax: 10,
                price: MoneyAmount(currencyCode: "USD", cents: 799)
            ),
            variant: .from(.illustratedHardcover6x9),
            amount: MoneyAmount(currencyCode: "USD", cents: 3682),
            status: .submittedToBackend,
            submittedOrder: PhysicalBookOrder(
                id: "quote-123",
                quoteID: "quote-123",
                luluPrintJobID: "print-job-123",
                status: .submittedToLulu,
                trackingURL: nil,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(draft)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(PhysicalBookPendingOrderDraft.self, from: data)

        XCTAssertEqual(decoded, draft)
        XCTAssertEqual(decoded.quoteRequest, quoteRequest)
        XCTAssertEqual(decoded.paymentIntentID, "pi_123")
        XCTAssertEqual(decoded.status, .submittedToBackend)
        XCTAssertEqual(decoded.submittedOrder?.luluPrintJobID, "print-job-123")
    }

    func testOrderPreviewDecodesLuluPrintJobPayload() throws {
        let json = """
        {
          "mode": "preview",
          "quoteID": "quote-123",
          "luluPrintJobPayload": {
            "external_id": "quote-123",
            "contact_email": "reader@example.com",
            "shipping_level": "MAIL",
            "line_items": [
              {
                "external_id": "quote-123-item-1",
                "pod_package_id": "0600X0900.FC.STD.LW.060UW444.MNG",
                "quantity": 1,
                "interior": {
                  "source_url": "https://cdn.example.com/interior.pdf",
                  "source_md5sum": "0123456789abcdef0123456789abcdef"
                },
                "cover": {
                  "source_url": "https://cdn.example.com/cover.pdf",
                  "source_md5sum": "abcdef0123456789abcdef0123456789"
                }
              }
            ],
            "shipping_address": {
              "name": "Reader",
              "street1": "1 Harbor St",
              "city": "Belfast",
              "state_code": "ME",
              "country_code": "US",
              "postcode": "04915",
              "phone_number": "844-212-0689"
            }
          }
        }
        """

        let preview = try JSONDecoder().decode(PhysicalBookOrderPreview.self, from: Data(json.utf8))

        XCTAssertEqual(preview.mode, "preview")
        XCTAssertEqual(preview.quoteID, "quote-123")
        XCTAssertEqual(preview.luluPrintJobPayload.externalID, "quote-123")
        XCTAssertEqual(preview.luluPrintJobPayload.lineItems.first?.podPackageID, "0600X0900.FC.STD.LW.060UW444.MNG")
        XCTAssertEqual(preview.luluPrintJobPayload.lineItems.first?.cover.sourceMD5, "abcdef0123456789abcdef0123456789")
        XCTAssertEqual(preview.luluPrintJobPayload.shippingAddress.postcode, "04915")
    }

    // MARK: Extras

    private var catalogue: PhysicalBookPrintOptionCatalogue {
        PhysicalBookPrintOptionCatalogue(
            variantID: "perfect-bound-softcover-6x9",
            options: [
                PhysicalBookPrintOption(
                    id: "photo-cover", family: .cover,
                    title: "Your own photograph on the cover",
                    pitch: "One of yours, on the front.",
                    priceDeltaCents: 900, appliesToVariantIDs: nil,
                    requires: ["photo"], resultingVariantID: nil
                ),
                PhysicalBookPrintOption(
                    id: "upgrade-hardcover", family: .binding,
                    title: "Bind it hard instead",
                    pitch: "Boards, and a spine that stands up.",
                    priceDeltaCents: 1800,
                    appliesToVariantIDs: ["perfect-bound-softcover-6x9"],
                    requires: [], resultingVariantID: "illustrated-hardcover-6x9"
                )
            ]
        )
    }

    private func softcoverRequest(options: [String]) -> PhysicalBookQuoteRequest {
        PhysicalBookQuoteRequest(
            editionID: "edition-2026-06",
            variant: .from(.perfectBoundSoftcover6x9),
            pageCount: 120,
            shipTo: PhysicalBookShippingDestination(countryCode: "US", stateCode: "ME", postalCode: "04915"),
            selectedOptionIDs: options
        )
    }

    /// The till showing one number while the card is charged another is the
    /// worst bug this screen could have, so the extras are itemised and the
    /// arithmetic mirrors the Worker's exactly.
    func testExtrasAreItemisedAndAddedToTheTotal() {
        let plain = PhysicalBookPricing.priceBreakdown(
            request: softcoverRequest(options: []), shippingCents: 799, catalogue: catalogue
        )
        let withPhoto = PhysicalBookPricing.priceBreakdown(
            request: softcoverRequest(options: ["photo-cover"]), shippingCents: 799, catalogue: catalogue
        )
        XCTAssertEqual(plain.printOptions?.cents, 0)
        XCTAssertEqual(withPhoto.printOptions?.cents, 900)
        XCTAssertEqual(withPhoto.selectedOptionIDs, ["photo-cover"])
        XCTAssertGreaterThan(withPhoto.total.cents, plain.total.cents + 900,
                             "The extra is charged and the processing fee is grossed up over it.")
    }

    /// An id with no catalogue entry is worth nothing here. The Worker refuses
    /// it outright at quote time; the estimate must never price it optimistically.
    func testAnUnknownOptionIsWorthNothingRatherThanGuessed() {
        let invented = PhysicalBookPricing.priceBreakdown(
            request: softcoverRequest(options: ["free-gold-plating"]), shippingCents: 799, catalogue: catalogue
        )
        XCTAssertEqual(invented.printOptions?.cents, 0)
        XCTAssertEqual(invented.selectedOptionIDs, [])
    }

    /// A catalogue fetched for one binding must not price another.
    func testACatalogueForADifferentBindingPricesNothing() {
        let mismatched = PhysicalBookPricing.priceBreakdown(
            request: PhysicalBookQuoteRequest(
                editionID: "edition-2026-06",
                variant: .from(.clothFoilHardcover6x9),
                pageCount: 120,
                shipTo: PhysicalBookShippingDestination(countryCode: "US", stateCode: "ME", postalCode: "04915"),
                selectedOptionIDs: ["photo-cover"]
            ),
            shippingCents: 799,
            catalogue: catalogue
        )
        XCTAssertEqual(mismatched.printOptions?.cents, 0)
    }

    func testWithNoCatalogueNothingIsCharged() {
        let none = PhysicalBookPricing.priceBreakdown(
            request: softcoverRequest(options: ["photo-cover"]), shippingCents: 799
        )
        XCTAssertEqual(none.printOptions?.cents, 0)
    }

    func testMembershipPressContractCarriesExactCoverCanvasAndFoilFields() throws {
        let request = BoundYearDispatchRequest(
            editionID: "annual-linen-jacket",
            variant: .from(.clothFoilHardcover6x9),
            pageCount: 144,
            selectedOptionIDs: [],
            foilStampTitleText: "BOOK OF YOU",
            foilStampAuthorText: "READER EXAMPLE"
        )
        XCTAssertEqual(try JSONDecoder().decode(
            BoundYearDispatchRequest.self,
            from: JSONEncoder().encode(request)
        ), request)

        let preparation = BoundYearDispatchPreparation(
            membershipID: "sub_member",
            seasonKey: "2027-S05",
            editionID: request.editionID,
            dispatchToken: "parcel-token",
            alreadySubmitted: false,
            shippingAddressSummary: "Belfast, ME, US",
            order: nil,
            coverDimensions: PhysicalBookCoverDimensions(widthPoints: 1_192, heightPoints: 666)
        )
        XCTAssertEqual(try JSONDecoder().decode(
            BoundYearDispatchPreparation.self,
            from: JSONEncoder().encode(preparation)
        ).coverDimensions, preparation.coverDimensions)
    }
}
