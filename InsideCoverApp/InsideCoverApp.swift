import SwiftUI

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
    }

    var body: some Scene {
        WindowGroup {
            LockedBookRoot()
                // The whole Book is a night-palette surface (nightPanel/nightText
                // everywhere). Pin the color scheme so any text that inherits the
                // default `.primary` renders light — never black-on-dark in a
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
