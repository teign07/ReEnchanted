import SwiftUI

#if DEBUG && targetEnvironment(simulator)
/// Explicit local-file transport for the isolated Simulator rehearsal. It uses
/// the signed installer and real subscription gate; no hosted proof bypass and
/// no test files or keys are included in the app bundle.
enum MonthlyContentSimulatorRehearsal {
    static func install() async throws {
        let merchant = await StoreKitMerchant().restorePurchases()
        guard PackEntitlements.hasMonthlyContentPackAccess(in: merchant) else {
            throw NSError(domain: "MonthlyRehearsal", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Purchase a local Standing Order in this simulator before rehearsing content."])
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
    }

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
