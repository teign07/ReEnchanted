import SwiftUI

#if DEBUG && targetEnvironment(simulator)
/// Explicit local-file transport for the isolated Simulator rehearsal. It uses
/// the signed installer and the current monthly-access gate; no hosted proof bypass and
/// no test files or keys are included in the app bundle.
enum MonthlyContentSimulatorRehearsal {
    static func install() async throws {
        if DigitalStandingOrder.isOffered {
            let merchant = await StoreKitMerchant().restorePurchases()
            guard PackEntitlements.hasMonthlyContentPackAccess(in: merchant) else {
                throw NSError(domain: "MonthlyRehearsal", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Restore a local Standing Order before rehearsing paid content."])
            }
        }
        let files = FileManager.default
        let source = files.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MonthlyRehearsal", isDirectory: true)
        let key = try Data(contentsOf: source.appendingPathComponent("public-key.bin"))
        let envelope = try Data(contentsOf: source.appendingPathComponent("manifest.envelope.json"))
        let manifest = try MonthlyIssueManifestVerifier.verify(envelopeData: envelope, publicKeyRawRepresentation: key)
        guard manifest.issues.allSatisfy({ $0.id == "school-door-simulator" }),
              manifest.allowedAssetHosts == ["rehearsal.invalid"] else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let root = files.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(MonthlyIssueDeliveryPolicy.supportDirectoryName)
        let plan = MonthlyIssueDeliveryPlanner.plan(manifest: manifest, now: Date(),
            hasMonthlyAccess: true, manifestHost: "rehearsal.invalid")
        _ = try await MonthlyIssueAssetInstaller.install(plan: plan,
            documentsURL: root.appendingPathComponent(MonthlyIssueDeliveryPolicy.managedContentDirectoryName),
            stateURL: root.appendingPathComponent("installation-state.json"), fetch: { url in
                guard url.host == "rehearsal.invalid" else { throw URLError(.unsupportedURL) }
                return try Data(contentsOf: source.appendingPathComponent(url.lastPathComponent))
            })
    }
}
#endif

final class InsideCoverAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        LocalModelBackgroundURLSessionEvents.shared.setCompletionHandler(
            completionHandler,
            for: identifier
        )
        // Recreating the session under this identifier is what lets iOS deliver
        // the finished downloads; without it the handler above is never called.
        LocalModelFileDownloader.reconnectIfNeeded(identifier: identifier)
    }
}

@main
struct InsideCoverApp: App {
    @UIApplicationDelegateAdaptor(InsideCoverAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    init() {
        OvernightScribe.register()
        WeatherBell.register()
        BookWhispers.configureForegroundPresentation()
        Self.warmReferenceLibrary()
        #if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--smoke-observation-pair-pdf") {
            Self.exportObservationPairProof()
        }
        EditionProofHarness.runIfRequested()
        #endif
    }

    #if DEBUG && targetEnvironment(simulator)
    /// Local print proof with synthetic Reader sentences. No account, purchase,
    /// network request, or private vault content enters these PDFs.
    private static func exportObservationPairProof() {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let statusURL = directory.appendingPathComponent("observation-pair-proof-status.txt")
        do {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            func date(_ day: Int) -> Date {
                calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: 12))!
            }
            func source(_ id: String, text: String, day: Int) -> BookPage {
                BookPage(id: id, type: .narrativeOS, createdAt: date(day), promptText: "Notice",
                         userInput: "The Book asked for one detail.", playerReply: text, origin: .generated)
            }
            func revisit(_ id: String, first: BookPage, firstText: String,
                         secondText: String, day: Int) throws -> BookPage {
                var page = source(id, text: secondText, day: day)
                let anchor = AuthoredReaderAnchor(pageID: first.id, contributionIndex: 0, text: firstText)
                page.tags.append(AuthoredObservationPair.tagPrefix
                    + (try JSONEncoder().encode(anchor)).base64EncodedString())
                return page
            }
            let firstLine = "A moth sat on the blue sill."
            let first = source("proof-first", text: firstLine, day: 4)
            let second = try revisit("proof-return", first: first, firstText: firstLine,
                                     secondText: "Only its dust was left.", day: 25)
            let longLine = String(repeating: "The rain stayed on the glass while the street changed below it; ", count: 64)
                + "the last drop finally moved."
            let longFirst = source("proof-long-first", text: longLine, day: 6)
            let longSecond = try revisit("proof-long-return", first: longFirst, firstText: longLine,
                                         secondText: "The pane was dry, and the road was not.", day: 26)
            let days = [first, longFirst, second, longSecond].map { page in
                BookDay(id: BookDay.id(for: page.createdAt, calendar: calendar),
                        date: calendar.startOfDay(for: page.createdAt), pages: [page])
            }
            let month = MonthlyEditionBuilder.edition(
                from: days, readerName: "Proof Reader", startDate: date(1),
                endDate: date(31).addingTimeInterval(43_199), generatedAt: date(31), calendar: calendar
            )
            let pairCount = month.sections.flatMap(\.items).filter { $0.observationPair != nil }.count
            guard pairCount == 2 else {
                throw NSError(domain: "ObservationProof", code: pairCount,
                              userInfo: [NSLocalizedDescriptionKey: "Expected two bound pairs; found \(pairCount)."])
            }
            let monthURL = directory.appendingPathComponent("observation-pair-monthly-proof.pdf")
            let seasonURL = directory.appendingPathComponent("observation-pair-seasonal-proof.pdf")
            try MonthlyEditionPDFWriter.writePrintInterior(month, spec: .hardcover6x9, to: monthURL)
            var season = AnnualEdition(
                title: "Proof Season", subtitle: "", year: 2026, readerName: "Proof Reader",
                generatedAt: date(31), startDate: date(1), endDate: date(31),
                dayCount: month.dayCount, pageCount: month.pageCount, foreword: "",
                chapters: [month], constellations: [], wagers: [], closing: "",
                continuity: month.continuity, memorySpine: nil
            )
            season.publicationKind = .seasonal
            try MonthlyEditionPDFWriter.writeVolumePrintInterior(
                season, spec: .perfectBoundSoftcover6x9, to: seasonURL)
            let issue = WeeklyIssue(number: 4, startDate: calendar.startOfDay(for: date(22)),
                                    endDate: calendar.startOfDay(for: date(29)), dateRange: "Oct 22–28",
                                    keptCount: 1, highlights: [], pages: [second])
            let matter = WeeklyPublicationMatter(issue: issue,
                                                 card: WeeklyIssueShareCard.make(issue: issue),
                                                 readerName: "Proof Reader", editorialNote: nil,
                                                 closingNote: nil)
            let weekURL = directory.appendingPathComponent("observation-pair-weekly-qa.pdf")
            try WeeklyIssuePDFWriter.writePrintInterior(
                matter, dedication: nil, spec: .saddleStitchedWeekly6x9, to: weekURL)
            try "OK: \(pairCount) pairs; weekly PDF".write(to: statusURL, atomically: true, encoding: .utf8)
            print("OBSERVATION_PAIR_PDF_PROOF_OK pairs=\(pairCount) monthly=\(monthURL.path) seasonal=\(seasonURL.path)")
        } catch {
            try? "FAILED: \(error)".write(to: statusURL, atomically: true, encoding: .utf8)
            print("OBSERVATION_PAIR_PDF_PROOF_FAILED \(error)")
        }
    }
    #endif

    /// The Wonder Compass Book and the Labyrinth lore are one and three quarter
    /// megabytes of JSON, and nothing touched them until the first desk build
    /// asked for a passage — so the reader watched the decode happen, inside the
    /// wait for their first Pages. It is a `static let`, so the first toucher
    /// pays and everyone after finds it ready; starting it here spends the
    /// opening flourish on it instead of the empty desk.
    private static func warmReferenceLibrary() {
        Task.detached(priority: .utility) {
            _ = BookReferenceCatalog.wonderCompass.count
        }
    }

    var body: some Scene {
        WindowGroup {
            LockedBookRoot()
                // The whole Book is a night-palette surface (nightPanel/nightText
                // everywhere). Pin the color scheme so any text that inherits the
                // default `.primary` renders light, never black-on-dark in a
                // device set to Light Mode.
                .preferredColorScheme(.dark)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                OvernightScribe.scheduleNext()
                WeatherBell.scheduleNext()
            }
        }
    }
}

struct LockedBookRoot: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appLock = BookAppLock()
    @AppStorage("bookAppLockEnabled") private var appLockEnabled = false

    var body: some View {
        ZStack {
            if !appLockEnabled || appLock.isUnlocked {
                ContentView()
                    .transition(.opacity.combined(with: .scale(scale: 1.012)))
            } else {
                BookLockView(appLock: appLock)
                    .transition(.opacity)
            }

            if scenePhase != .active {
                BookPrivacyShield()
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: appLock.isUnlocked)
        .task {
            if appLockEnabled {
                await appLock.authenticate()
            }
        }
        .task {
            await MainActor.run { StoreKitTransactionObserver.start() }
            await StandingOrderTrialReminder.reconcileCurrentTrial()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .inactive, .background:
                if appLockEnabled {
                    appLock.lock()
                }
            case .active:
                if appLockEnabled && !appLock.isUnlocked {
                    Task { await appLock.authenticate() }
                }
            default:
                break
            }
        }
        .onChange(of: appLockEnabled) { _, enabled in
            if !enabled { appLock.acceptCurrentAuthorization() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .bookAppLockAuthorized)) { _ in
            appLock.acceptCurrentAuthorization()
        }
        .onOpenURL { url in
            guard ReEnchantedWidgetDeepLinkStore.enqueue(url) else { return }
            NotificationCenter.default.post(name: .reEnchantedWidgetDeepLinkReceived, object: nil)
        }
    }
}

private struct BookPrivacyShield: View {
    var body: some View {
        ZStack {
            BookPalette.nightPanel.ignoresSafeArea()
            Image(systemName: "book.closed.fill")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(BookPalette.lampGold.opacity(0.8))
                .accessibilityLabel("The Book is closed")
        }
    }
}

private struct BookLockView: View {
    @ObservedObject var appLock: BookAppLock

    var body: some View {
        ZStack {
            BookBackground()
                .ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()

                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(BookPalette.nightPanel.opacity(0.88))
                        Circle()
                            .stroke(BookPalette.lampGold.opacity(0.62), lineWidth: 2)
                        Image(systemName: "lock.shield")
                            .font(.system(size: 42, weight: .bold))
                            .foregroundStyle(BookPalette.lampGold)
                    }
                    .frame(width: 92, height: 92)
                    .shadow(color: BookPalette.lampGold.opacity(0.22), radius: 22, x: 0, y: 10)

                    VStack(spacing: 8) {
                        Text("ReEnchanted")
                            .font(.system(.largeTitle, design: .serif, weight: .bold))
                            .foregroundStyle(BookPalette.nightText)
                        Text("The Book knows better than to open for just anyone.")
                            .font(.system(.callout, design: .serif))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(BookPalette.nightText.opacity(0.76))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button {
                        Task { await appLock.authenticate() }
                    } label: {
                        Label(appLock.isAuthenticating ? "Listening for the key..." : "Open the Book",
                              systemImage: appLock.isAuthenticating ? "ellipsis" : "faceid")
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(BookPalette.lampGold)
                    .disabled(appLock.isAuthenticating)
                    .padding(.top, 8)

                    Text(appLock.message)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BookPalette.nightText.opacity(0.58))
                        .multilineTextAlignment(.center)
                }
                .padding(22)
                .background(BookPalette.nightPanel.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(BookPalette.lampGold.opacity(0.28), lineWidth: 1)
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
    }
}
