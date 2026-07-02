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
        XCTAssertEqual(price.markup.cents, 1200)
        XCTAssertEqual(price.paymentProcessingFee.cents, 149)
        XCTAssertEqual(price.total.cents, 4099)
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
        XCTAssertEqual(price.markup.cents, 2400)
        XCTAssertEqual(price.paymentProcessingFee.cents, 225)
        XCTAssertEqual(price.total.cents, 6696)
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
            expiresAt: Date(timeIntervalSince1970: 1_783_000_000)
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(quote)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(PhysicalBookQuote.self, from: data)

        XCTAssertEqual(decoded, quote)
        XCTAssertEqual(decoded.shippingOptions.first?.id, "MAIL")
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
        XCTAssertEqual(response.amount.cents, 4099)
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
}
