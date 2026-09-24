import XCTest
@testable import InsideCoverCore

final class PhysicalBookOrdersTests: XCTestCase {
    func testRecoveryPasteAcceptsWrappedMailWithoutChangingTheSecret() throws {
        let secret = String(repeating: "a", count: 42) + "A"
        let code = try XCTUnwrap(BoundYearRecoveryCode(pastedText:
            " \tsub_fixture.\(secret.prefix(12))\r\n\(secret.dropFirst(12))\n"))
        XCTAssertEqual(code.membershipID, "sub_fixture")
        XCTAssertEqual(code.secret, secret)
    }

    func testRecoveryPasteRejectsPartialAmbiguousAndOversizedInput() {
        let valid = "sub_fixture." + String(repeating: "a", count: 43)
        for invalid in [String(valid.dropLast()), valid + "a", valid + ".extra",
                        "Here is your code: " + valid, "sub_bad!." + String(repeating: "a", count: 43),
                        "sub_fixture." + String(repeating: "/", count: 43),
                        valid + String(repeating: " ", count: 2048),
                        valid + "\u{200B}"] {
            XCTAssertNil(BoundYearRecoveryCode(pastedText: invalid))
        }
    }

    func testLegacyOrderWithoutShipmentsStillDecodes() throws {
        let data = Data(#"{"id":"order_old","quoteID":"quote_old","status":"shipped","trackingURL":"https://carrier.example/old","createdAt":0,"updatedAt":0}"#.utf8)
        let order = try JSONDecoder().decode(PhysicalBookOrder.self, from: data)
        XCTAssertNil(order.shipments)
        XCTAssertEqual(order.trackingURL?.absoluteString, "https://carrier.example/old")
    }

    func testPurchaseAttemptSurvivesStoreRecreationUntilCompletion() async throws {
        let suite = "PhysicalBookPurchaseAttemptsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PhysicalBookPurchaseAttemptStore(defaults: defaults)
        let first = await store.attemptID(for: "opaque-request-fingerprint")
        let reopened = PhysicalBookPurchaseAttemptStore(defaults: try XCTUnwrap(UserDefaults(suiteName: suite)))
        let recovered = await reopened.attemptID(for: "opaque-request-fingerprint")
        XCTAssertEqual(first, recovered)
        XCTAssertNotNil(UUID(uuidString: first))
        await reopened.complete(first)
        let next = await store.attemptID(for: "opaque-request-fingerprint")
        XCTAssertNotEqual(first, next)
    }

    func testConcurrentPurchaseRetriesShareAnAttempt() async {
        let suite = "PhysicalBookPurchaseAttemptsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PhysicalBookPurchaseAttemptStore(defaults: defaults)
        async let first = store.attemptID(for: "same-purchase")
        async let second = store.attemptID(for: "same-purchase")
        let ids = await [first, second]
        XCTAssertEqual(ids[0], ids[1])
        let different = await store.attemptID(for: "another-purchase")
        XCTAssertNotEqual(ids[0], different)
    }

    func testOldMembershipStatusDoesNotInventPaymentVerification() throws {
        let data = Data(#"{"membershipID":"sub_old","status":"active","cancelAtPeriodEnd":false,"currentPeriodEnd":1900000000}"#.utf8)
        let decoded = try JSONDecoder().decode(BoundYearMembershipStatus.self, from: data)
        XCTAssertNil(decoded.paymentVerified)
    }

    func testQuoteRequestRoundTripsThroughJSON() throws {
        let request = PhysicalBookQuoteRequest(
            editionID: "edition-2026-06",
            editionTitle: "The Door That Was Only a Door",
            editionKind: .monthly,
            variant: .from(.illustratedHardcover6x9),
            pageCount: 120,
            shipTo: PhysicalBookShippingDestination(countryCode: "US", stateCode: "ME", postalCode: "04915")
        )

        let data = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(PhysicalBookQuoteRequest.self, from: data)

        XCTAssertEqual(decoded, request)
        XCTAssertEqual(decoded.editionTitle, "The Door That Was Only a Door")
        XCTAssertEqual(decoded.editionKind, .monthly)
        XCTAssertEqual(decoded.variant.luluPackageID, "0600X0900.FC.PRE.CW.080CW444.MXX")
        XCTAssertEqual(decoded.currencyCode, "USD")
    }

    func testSavedQuoteWithoutEditionTitleStillDecodes() throws {
        let request = softcoverRequest(options: [])
        let data = try JSONEncoder().encode(request)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNil(object["editionTitle"])
        let decoded = try JSONDecoder().decode(PhysicalBookQuoteRequest.self, from: data)
        XCTAssertNil(decoded.editionTitle)
        XCTAssertEqual(decoded.editionID, request.editionID)
    }

    func testManufacturingSubtotalUsesVerifiedLuluPrices() {
        let cloth = PhysicalBookVariant.from(.clothFoilHardcover6x9)
        let illustrated = PhysicalBookVariant.from(.illustratedHardcover6x9)

        // Premium colour on 80# coated, fitted to Lulu sandbox quotes.
        XCTAssertEqual(PhysicalBookPricing.rawManufacturingSubtotalCents(variant: cloth, pageCount: 120, quantity: 1), 3166)
        XCTAssertEqual(PhysicalBookPricing.rawManufacturingSubtotalCents(variant: illustrated, pageCount: 120, quantity: 1), 2735)
        XCTAssertEqual(PhysicalBookPricing.rawManufacturingSubtotalCents(variant: illustrated, pageCount: 120, quantity: 2), 5470)
    }

    func testDefaultPricingPolicyAddsProfitAndCoversPaymentFee() {
        let request = PhysicalBookQuoteRequest(
            editionID: "edition-2026-06",
            variant: .from(.clothFoilHardcover6x9),
            pageCount: 120,
            shipTo: PhysicalBookShippingDestination(countryCode: "US", stateCode: "ME", postalCode: "04915")
        )

        let price = PhysicalBookPricing.priceBreakdown(request: request, shippingCents: 799)

        XCTAssertEqual(price.manufacturingSubtotal.cents, 3166)
        XCTAssertEqual(price.shipping.cents, 799)
        XCTAssertEqual(price.markup.cents, 6833)
        XCTAssertEqual(price.paymentProcessingFee.cents, 354)
        XCTAssertEqual(price.total.cents, 11152)

        // The numbers above are the arithmetic; this is the promise they exist
        // to keep. The charge must survive Stripe's cut with the subtotal still
        // whole, and must be the *smallest* charge that does - a gross-up that
        // rounds a cent too far is overcharging the reader.
        assertCoversProcessing(total: price.total.cents, subtotal: 1951 + 799 + 8048)
    }

    /// Stripe takes 2.9% + 30c of whatever it settles. Asserts the total clears
    /// that with the subtotal intact, and that one cent less would not.
    private func assertCoversProcessing(
        total: Int,
        subtotal: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        func net(_ charge: Int) -> Double {
            Double(charge) - (Double(charge) * 0.029 + 30)
        }
        XCTAssertGreaterThanOrEqual(
            net(total), Double(subtotal),
            "charging \(total) leaves less than \(subtotal) after processing",
            file: file, line: line
        )
        XCTAssertLessThan(
            net(total - 1), Double(subtotal),
            "charging \(total - 1) would also cover it; the gross-up is a cent too generous",
            file: file, line: line
        )
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

        XCTAssertEqual(price.manufacturingSubtotal.cents, 5470)
        XCTAssertEqual(price.markup.cents, 12528)
        XCTAssertEqual(price.paymentProcessingFee.cents, 599)
        XCTAssertEqual(price.total.cents, 19596)
        assertCoversProcessing(total: price.total.cents, subtotal: 5470 + 999 + 12528)
    }

    func testBoundYearPrintSetCostsLessThanTheSameBindingsALaCarte() {
        let softcover = PhysicalBookVariant.from(.perfectBoundSoftcover6x9)
        let cloth = PhysicalBookVariant.from(.clothFoilHardcover6x9)
        let aLaCarteProductTotal =
            PhysicalBookPricing.minimumProductPriceCentsPerCopy(
                for: softcover,
                editionKind: .seasonal
            )! * 3
            + PhysicalBookPricing.minimumProductPriceCentsPerCopy(for: cloth)!

        XCTAssertEqual(aLaCarteProductTotal, 30_996)
        XCTAssertGreaterThan(aLaCarteProductTotal, BoundYearPricing.monthlyCents * 12)
        XCTAssertGreaterThan(aLaCarteProductTotal, BoundYearPricing.annualCents)
    }

    func testSoftcoverFloorDependsOnEditorialSpan() {
        let softcover = PhysicalBookVariant.from(.perfectBoundSoftcover6x9)

        XCTAssertEqual(
            PhysicalBookPricing.minimumProductPriceCentsPerCopy(for: softcover, editionKind: .monthly),
            4_999
        )
        XCTAssertEqual(
            PhysicalBookPricing.minimumProductPriceCentsPerCopy(for: softcover, editionKind: .seasonal),
            6_999
        )
        XCTAssertEqual(
            PhysicalBookPricing.minimumProductPriceCentsPerCopy(for: softcover),
            7_999,
            "Older saved quotes must retain their original floor"
        )
    }

    func testMonthlyAndSeasonalSoftcoversKeepHealthyContribution() {
        let softcover = PhysicalBookVariant.from(.perfectBoundSoftcover6x9)
        let destination = PhysicalBookShippingDestination(
            countryCode: "US",
            stateCode: "ME",
            postalCode: "04915"
        )
        let monthly = PhysicalBookPricing.priceBreakdown(
            request: PhysicalBookQuoteRequest(
                editionID: "2026-08",
                editionKind: .monthly,
                variant: softcover,
                pageCount: PrintSpec.pageCap(for: .monthly),
                shipTo: destination
            ),
            shippingCents: 0
        )
        let seasonal = PhysicalBookPricing.priceBreakdown(
            request: PhysicalBookQuoteRequest(
                editionID: "2026-06-through-2026-08",
                editionKind: .seasonal,
                variant: softcover,
                pageCount: PrintSpec.pageCap(for: .seasonal),
                shipTo: destination
            ),
            shippingCents: 0
        )

        // At each cap, premium paper still leaves the price at its floor
        // ($49.99 / $69.99) with the contribution intact.
        XCTAssertEqual(monthly.manufacturingSubtotal.cents + monthly.markup.cents, 4_999)
        XCTAssertEqual(seasonal.manufacturingSubtotal.cents + seasonal.markup.cents, 6_999)
        XCTAssertGreaterThanOrEqual(monthly.markup.cents, 3_500)
        XCTAssertGreaterThanOrEqual(seasonal.markup.cents, 3_500)
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

        XCTAssertEqual(price.manufacturingSubtotal.cents, 822)
        XCTAssertEqual(price.markup.cents, 1500)
        XCTAssertEqual(price.paymentProcessingFee.cents, 125)
        XCTAssertEqual(price.total.cents, 3246)
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
        XCTAssertEqual(decoded.quoteRequest.variant.luluPackageID, "0600X0900.FC.PRE.LW.080CW444.MNG")
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
        // Matches testDefaultPricingPolicyAddsProfitAndCoversPaymentFee: same
        // binding, same page count, same 799c shipping.
        XCTAssertEqual(response.amount.cents, 11152)
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
            checkoutToken: "synthetic-status-capability",
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
                status: .shipped,
                shipments: [
                    .init(trackingID: "parcel-one", carrierName: "Carrier One",
                          trackingURLs: [URL(string: "https://carrier.example/one")!]),
                    .init(trackingID: "parcel-two", carrierName: "Carrier Two",
                          trackingURLs: [URL(string: "https://carrier.example/two")!,
                                         URL(string: "https://carrier.example/two/alternate")!])
                ],
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
        XCTAssertEqual(decoded.submittedOrder?.shipments?.count, 2)
        XCTAssertEqual(decoded.submittedOrder?.shipments?.last?.trackingID, "parcel-two")
        XCTAssertEqual(decoded.submittedOrder?.shipments?.last?.trackingURLs.count, 2)
        let receipt = decoded.retainingTrackingOnly()
        XCTAssertEqual(receipt.submittedOrder, decoded.submittedOrder)
        XCTAssertEqual(receipt.paymentIntentID, decoded.paymentIntentID)
        XCTAssertEqual(receipt.checkoutToken, decoded.checkoutToken)
        XCTAssertEqual(receipt.contactEmail, "")
        XCTAssertEqual(receipt.shippingAddress.name, "")
        XCTAssertEqual(receipt.shippingAddress.street1, "")
        XCTAssertEqual(receipt.shippingAddress.postalCode, "")
        XCTAssertNil(receipt.shippingAddress.phoneNumber)
        XCTAssertNil(receipt.shippingAddress.recipientTaxID)
        XCTAssertNil(receipt.quoteRequest)
        XCTAssertNil(receipt.selectedShippingOption)
        XCTAssertEqual(try decoder.decode(PhysicalBookPendingOrderDraft.self,
                                        from: encoder.encode(receipt)), receipt)
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
                "pod_package_id": "0600X0900.FC.PRE.LW.080CW444.MNG",
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
        XCTAssertEqual(preview.luluPrintJobPayload.lineItems.first?.podPackageID, "0600X0900.FC.PRE.LW.080CW444.MNG")
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
            foilStampAuthorText: "READER EXAMPLE",
            editionTitle: "The Year of Small Doors"
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
