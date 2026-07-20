import SwiftUI
import OSLog
import Darwin.Mach
#if canImport(AudioToolbox)
import AudioToolbox
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(Photos)
import Photos
#endif
#if canImport(PhotosUI)
import PhotosUI
#endif
#if canImport(CoreLocation)
import CoreLocation
#endif
#if canImport(HealthKit)
import HealthKit
#endif
#if canImport(Vision)
import Vision
#endif
#if canImport(StoreKit)
import StoreKit
#endif
#if NATIVE_LOCAL_BRAIN && canImport(MLXLLM)
import MLXLLM
#endif
#if NATIVE_LOCAL_BRAIN && canImport(MLXVLM)
import MLXVLM
#endif
#if NATIVE_LOCAL_BRAIN && canImport(MLXLMCommon)
import MLXLMCommon
#endif
#if NATIVE_LOCAL_BRAIN && canImport(MLXLMTokenizers)
import MLXLMTokenizers
#endif
#if NATIVE_LOCAL_BRAIN && canImport(MLXLMHFAPI)
import MLXLMHFAPI
#endif
#if NATIVE_LOCAL_BRAIN && canImport(MLX)
import MLX
#endif

private struct GlowPillRevealAura: View {
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var orbit = false

    var body: some View {
        ZStack {
            if isActive {
                Capsule(style: .continuous)
                    .stroke(BookPalette.lampGold.opacity(0.78), lineWidth: 1.6)
                    .blur(radius: 0.3)
                    .shadow(color: BookPalette.lampGold.opacity(0.72), radius: 16)
                    .scaleEffect(orbit && !reduceMotion ? 1.18 : 0.92)
                    .opacity(orbit ? 0 : 1)

                ForEach(0..<7, id: \.self) { index in
                    Image(systemName: index.isMultiple(of: 2) ? "sparkle" : "plus")
                        .font(.system(size: index.isMultiple(of: 2) ? 9 : 6, weight: .black))
                        .foregroundStyle(BookPalette.lampGold)
                        .offset(sparkleOffset(index: index, expanded: orbit && !reduceMotion))
                        .opacity(orbit ? 0.18 : 0.95)
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: isActive) { _, active in
            guard active else {
                orbit = false
                return
            }
            orbit = false
            withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .easeOut(duration: 1.3)) {
                orbit = true
            }
        }
    }

    private func sparkleOffset(index: Int, expanded: Bool) -> CGSize {
        let angle = Double(index) * (.pi * 2 / 7) - .pi / 2
        let xRadius: Double = expanded ? 70 : 38
        let yRadius: Double = expanded ? 28 : 13
        return CGSize(width: cos(angle) * xRadius, height: sin(angle) * yRadius)
    }
}

private struct CastAgencyMovementRow: View {
    let movement: CastAgencyMovement
    let timestamp: String

    private var accent: Color {
        movement.kind == .relationship ? BookPalette.lampGold : BookPalette.teal
    }

    private var iconName: String {
        movement.kind == .relationship ? "person.2" : "rectangle.stack"
    }

    private var kindLabel: String {
        movement.kind == .relationship ? "Loom" : "Pages"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.caption.weight(.black))
                .foregroundStyle(accent)
                .frame(width: 28, height: 28)
                .background(accent.opacity(0.13), in: Circle())
                .overlay {
                    Circle().stroke(accent.opacity(0.28), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(movement.line)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(BookPalette.ink.opacity(0.86))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Text(timestamp)
                    Text(kindLabel)
                    Text(movement.targetName)
                        .lineLimit(1)
                }
                .font(.caption2.weight(.bold))
                .foregroundStyle(BookPalette.ink.opacity(0.52))
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(BookPalette.paper.opacity(0.82), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(accent.opacity(0.16), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A page that has already been kept or dismissed but remains mounted long
/// enough to reserve its exact desk slot while the curator prepares the next
/// page. The mounted card is hidden and inert; the retirement reconciler swaps
/// every pending slot in one non-animated publication.
private struct PendingSurfaceRetirement {
    var surface: SurfacePage
}

/// The persistent places that become first-class destinations in the iPad
/// edition. The iPhone keeps its existing stack-and-sheet flow; iPad gives the
/// same Book a stable spine so these rooms do not have to masquerade as modals.
private enum BookPadDestination: String, CaseIterable, Identifiable {
    case today
    case stacks
    case almanac

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Today"
        case .stacks: return "Search the Stacks"
        case .almanac: return "The Almanac"
        }
    }

    var symbolName: String {
        switch self {
        case .today: return "sparkles.rectangle.stack"
        case .stacks: return "sparkle.magnifyingglass"
        case .almanac: return "calendar.badge.clock"
        }
    }

    var keyboardNumber: KeyEquivalent {
        switch self {
        case .today: return "1"
        case .stacks: return "2"
        case .almanac: return "3"
        }
    }

    var keyboardLabel: String {
        switch self {
        case .today: return "⌘1"
        case .stacks: return "⌘2"
        case .almanac: return "⌘3"
        }
    }
}

private enum BookPadOverviewAnchor: String {
    case archive
    case colophon
}

struct ContentView: View {
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #if canImport(StoreKit)
    @Environment(\.requestReview) var requestReview
    #endif

    @State var days: [BookDay] = [BookDay.today()]
    @State var generation = GenerationCoordinator()
    @State var selectedSurface: SurfacePage?
    @State var pactVerdictSurface: SurfacePage?
    @State var pactErrandSurface: SurfacePage?
    @State var radioManager = BookRadioManager.shared
    @State var isInstallingModel = false
    @State var didRunSmokeBraid = false
    @State var statusMessage = ""
    @State var purchaseThankYouSurface: SurfacePage?
    @State var latestBraidSharePageID: String?
    @State var latestBraidShareCardURL: URL?
    /// An edition-binding celebration (monthly bind, print-ready, or onboarding's
    /// first edition), present only while it plays. Its own peak, distinct from
    /// the keep ink burst and the braid completion.
    @State var editionCelebration: EditionCelebrationInfo?
    /// The reader's name for a first-edition celebration owed once the Standing
    /// Order paywall is dismissed — so onboarding ends on the celebration, after
    /// the offer, not on the paywall. Nil means none is owed.
    @State var pendingFirstEditionReaderName: String?
    @State var latestBraidShareMessage = ""
    @State var isPressingLatestBraidShareCard = false
    @State var latestBraidRevealPageID: String?
    @State var latestBraidRevealVideoURL: URL?
    @State var isPressingLatestBraidRevealVideo = false
    @State var latestBraidPDFPageID: String?
    @State var latestBraidPDFURL: URL?
    @State var isBindingLatestBraidPDF = false
    @State var installMessage = ""
    @State var installProgress: Double?
    @State var modelReport = Self.placeholderModelReport
    @State var storeReport = Self.placeholderStoreReport
    @State var databaseReport = Self.placeholderDatabaseReport
    @State var resurfacedPages: [BookPage] = []
    @State var returnedStackCards: [ReturnedStackCard] = []
    @State var surfacedPages: [SurfacePage] = []
    /// The imported widget/companion state is a launch input, not a render-time
    /// data source. Reading and decoding it from the app-group defaults every
    /// time `sourceInputs` was evaluated made ordinary SwiftUI updates perform
    /// synchronous I/O. Hydration replaces this cheap seed once, off-main.
    @State var insideCoverState: InsideCoverState = .fallback
    @State var selfFacts: [SelfFact] = []
    @State var narrativeEvents: [NarrativeEvent] = []
    @State var entityMemories: [NarrativeEntityMemory] = []
    @State var cachedNarrativeSourceSnapshot = NarrativeSourceSnapshot(
        activeThreadCount: 0,
        relationshipCount: 0,
        beliefWeight: nil
    )
    @State var cachedQuietDayCount = 0
    @State var cachedBleedIssueNumber = 1
    @State var customCastMembers: [CustomCastMember] = []
    @State var facultyEntries: [FacultyEntry] = []
    @State var bodySignal: BodySourceSignal?
    @State var weatherSignal: WeatherSourceSignal?
    @State var enchantedWeather: EnchantedWeatherSignal?
    @State var weatherPageSignal: WeatherSourceSignal?
    @State var isRequestingWeather = false
    @State var anchorLedger = AnchorRegistry.defaultAnchors
    @State var nearbyAnchor: AnchorProximity?
    @State var preparedAnchorSurface: SurfacePage?
    @State var isCheckingAnchors = false
    @State var selectedWonderCompassSnippet: ReferenceSnippet?
    @State var selectedWonderCompassSelector: String?
    @State var isChoosingWonderCompassPassage = false
    @State var isRequestingHealthKit = false
    @State var isSourceSettingsPresented = false
    @State var isCustomCastSheetPresented = false
    @State var isBraidingTablePresented = false
    @State var surfaceRefreshDate = Date()
    @State var suppressNextSurfaceRefresh = false
    @State var isRetiringKeptSurface = false
    @State private var pendingSurfaceRetirements: [String: PendingSurfaceRetirement] = [:]
    @State private var surfaceRetirementRevision: UInt64 = 0
    @State private var arrivingSurfaceIDs: Set<String> = []
    /// The enriched curator keeps a deeper, already-ranked candidate bench so
    /// a deliberate keep/swipe can refill its exact slot without rebuilding the
    /// whole archive while the reader waits.
    @State private var curatedSurfaceBench: [SurfacePage] = []
    @State private var keepInkBurstTrigger = 0
    @State private var keepInkBurstText = "KEPT"
    @State private var keepMarginNote: KeepMarginalia.Note?
    @State private var keepMarginNoteTicket = 0
    @State private var shadowWonderUnlockNote: KeepMarginalia.Note?
    @State var marginaliaAchievementUnlockNote: KeepMarginalia.Note?
    @State var marginaliaAchievementUnlockTitle = ""
    @State var didSeedBookwideMarginaliaAchievements = false
    /// The faint echo the retired margin toast leaves tucked at the page edge, so
    /// the settled desk still carries the keep for a breath after the toast lands.
    @State private var keepMarginTrace: KeepMarginalia.Note?
    @State private var keepArtifactQuote: String?
    @State private var keepArtifactPageType: BookPageType = .diary
    @State private var keepArtifactCardURL: URL?
    @State private var isShowingKeepArtifactCard = false
    @State var undoSurface: SurfacePage?
    @State var undoDayID: String?
    @State private var undoSurfaceSlotIndex: Int?
    @State private var undoSurfaceReplacementID: String?
    @State private var undoSurfaceDismissalKeys: Set<String> = []
    @State var undoRemovedPage: BookPage?
    @State var undoRemovedPageDayID: String?
    @State var userPhotoIlluminationFallbackAllowed = false
    @AppStorage("didRequestHealthKitBodySignal") var didRequestHealthKitBodySignal = false
    @AppStorage("didRequestWeatherLocation") var didRequestWeatherLocation = false
    @AppStorage("didRequestAnchorLocation") var didRequestAnchorLocation = false
    @AppStorage("didGrantLocationContextAccess") var didGrantLocationContextAccess = false
    @AppStorage("dismissedBookOfYouHeroPageID") var dismissedBookOfYouHeroPageID = ""
    var vault: PlayerVault { PlayerVault.shared }
    var anchorLedgerData: String {
        get {
            guard let data = try? JSONEncoder().encode(vault.data.anchors),
                  let encoded = String(data: data, encoding: .utf8) else { return "" }
            return encoded
        }
        nonmutating set {
            guard let data = newValue.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([AnchorRecord].self, from: data) else { return }
            vault.data.anchors = decoded
            vault.save()
        }
    }
    @AppStorage("dismissedSurfaceLedgerV2") var dismissedSurfaceLedgerV2 = "{}"
    @AppStorage("pocketLedger") var pocketLedgerData = "{}"
    @AppStorage("chosenQuill") var chosenQuillData = ""
    @AppStorage("sourcePreferenceLedger") var sourcePreferenceLedger = "{}"
    @AppStorage("illuminatedPhotoHistory") var illuminatedPhotoHistoryData = "{}"
    @AppStorage("lastAutomaticBodySourceRefreshSlot") var lastAutomaticBodySourceRefreshSlot = ""
    @AppStorage("lastAutomaticWeatherSourceRefreshSlot") var lastAutomaticWeatherSourceRefreshSlot = ""
    @AppStorage(PublicMarginsAPI.incomingOptInKey) var publicMarginsIncomingOptIn = false
    @AppStorage(PublicMarginsAPI.outgoingOptInKey) var publicMarginsOutgoingOptIn = false
    @AppStorage("lastPublicMarginsRefreshSlot") var lastPublicMarginsRefreshSlot = ""
    @State var publicMarginsSnapshot: PublicMarginsSnapshot?
    @AppStorage("beliefScore") var beliefScore = 30
    @AppStorage("scrapbookCompletedMarginaliaAchievements") var completedMarginaliaAchievementLedger = ""
    @AppStorage("bookHapticMode") var bookHapticMode = BookFeedback.HapticMode.full.rawValue
    @AppStorage("completedCompassRunLedger") var completedCompassRunLedger = ""
    var entityBeliefLedgerData: String {
        get {
            guard let data = try? JSONEncoder().encode(vault.data.entityBelief),
                  let encoded = String(data: data, encoding: .utf8) else { return "{}" }
            return encoded
        }
        nonmutating set {
            guard let data = newValue.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String: Int].self, from: data) else { return }
            vault.data.entityBelief = decoded
            vault.save()
        }
    }
    var pageBeliefLedgerData: String {
        get {
            guard let data = try? JSONEncoder().encode(vault.data.pageBelief),
                  let encoded = String(data: data, encoding: .utf8) else { return "{}" }
            return encoded
        }
        nonmutating set {
            guard let data = newValue.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String: Int].self, from: data) else { return }
            vault.data.pageBelief = decoded
            vault.save()
        }
    }
    var electiveLedgerData: String {
        get {
            guard let data = try? JSONEncoder().encode(vault.data.electives),
                  let encoded = String(data: data, encoding: .utf8) else { return "[]" }
            return encoded
        }
        nonmutating set {
            guard let data = newValue.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([UnwrittenElective].self, from: data) else { return }
            vault.data.electives = decoded
            vault.save()
        }
    }
    @AppStorage("didCompleteStoryOnboarding") var didCompleteStoryOnboarding = false
    @AppStorage("didRevealGlowPill") var didRevealGlowPill = false
    @AppStorage("didRequestFirstDoorAppReview") var didRequestFirstDoorAppReview = false
    @AppStorage("didOfferStandingOrder") var didOfferStandingOrder = false
    @State var showStandingOrderPaywall = false
    @State var standingOrderHeroArtifact: BookOfYouShareArtifact?
    var marginTutorSeenData: String {
        get { MarginTutorLedger.encode(Set(vault.data.tutorSeen)) }
        nonmutating set {
            vault.data.tutorSeen = Array(MarginTutorLedger.seenIDs(from: newValue)).sorted()
            vault.save()
        }
    }
    @AppStorage("bookWhispersEnabled") var bookWhispersEnabled = false
    @AppStorage("promptWhispersEnabled") var promptWhispersEnabled = false
    var bookWhisperCadence: BookWhisperCadence {
        BookWhisperCadence.resolved(
            bookWhispersEnabled: bookWhispersEnabled,
            promptWhispersEnabled: promptWhispersEnabled
        )
    }
    @AppStorage("bookCalendarEnabled") var bookCalendarEnabled = false
    @AppStorage("bookAppLockEnabled") var bookAppLockEnabled = false
    @AppStorage(VellumNutritionist.keyStorageKey) var usdaKey = ""
    @AppStorage(RedditSourceAccount.clientIDStorageKey) var redditClientID = ""
    @State var calendarEvents: [CalendarEventSignal] = []
    @State var nearbyPlaces: [LocalPlaceSignal] = []
    @State var preparedSaveFileURL: URL?
    @State var preparedPlainInkURL: URL?
    @State var preparedContinuityURL: URL?
    @State var preparedMonthlyEditionURL: URL?
    @State var preparedWeeklyIssuePDFURL: URL?
    @State var preparedWeeklyIssueCardURL: URL?
    /// Drives the in-app weekly issue reader sheet; nil when closed.
    @State var weeklyIssueReader: WeeklyIssueReader?
    /// Drives the in-app monthly edition reader sheet; nil when closed.
    @State var monthlyEditionReader: MonthlyEditionReader?
    /// The last-built reader, kept so re-opening the same issue skips Gemma.
    @State var cachedWeeklyIssueReader: WeeklyIssueReader?
    /// Non-nil while a weekly issue is being bound (waiting on Gemma + PDF write);
    /// drives the binding progress overlay so the wait is visible on every path.
    @State var weeklyIssueBindingNote: String?
    @State var preparedPagewrightPDFURL: URL?
    @State var preparedPagewrightPNGURL: URL?
    @State var preparedAnnualEditionURL: URL?
    /// The two files a print-on-demand house needs: a full-bleed interior and a
    /// spine-aware cover wrap, ready to share or hand-upload to a printer.
    @State var preparedPrintInteriorURL: URL?
    @State var preparedPrintCoverURL: URL?
    /// The month the player has chosen to bind. `nil` means "let the Book choose"
    /// — the most recent month that kept pages.
    @State var selectedEditionMonth: Date?
    @AppStorage("includePrivateWeatherInMonthlyBinding") var includePrivateWeatherInMonthlyBinding = false
    /// An in-character line the Colophon's binding desk speaks back to the player.
    @State var colophonBindingNote: String?
    @State var bookJumpCustomTitle: String = ""
    @State var preparedBleedPDFURL: URL?
    @State var isSaveImporterPresented = false
    @State var isConnectionsPresented = false
    @State var activeTutorNote: MarginTutorNote?
    @AppStorage("isOpeningShelfExpanded") var isBookTodayShelfExpanded = true
    @AppStorage("isTodaysMarginsExpanded") var isTodaysMarginsExpanded = false
    @AppStorage("isCastLedgerExpanded") var isCastLedgerExpanded = true
    @AppStorage("isReturnedStacksExpanded") var isReturnedStacksExpanded = false
    @AppStorage("isBookOfYouShelfExpanded") var isBookOfYouShelfExpanded = false
    @AppStorage("isQuietMechanicsExpanded") var isQuietMechanicsExpanded = false
    @AppStorage("isLabPanelExpanded") var isLabPanelExpanded = false
    @State var healthKitMessage = HealthKitBodyReader.isAvailable
        ? "If you open the door, the Book can listen for the body's weather without showing the numbers."
        : "This room has no HealthKit doorway."
    @State var weatherMessage = WeatherLocationReader.isAvailable
        ? "If you lend the Book your place, it can translate the sky without naming the watcher."
        : "This room cannot hear the local sky yet."
    @State var anchorMessage = AnchorLocationReader.isAvailable
        ? "The Book can check nearby known Anchors and open the right Outer Stacks room."
        : "This room cannot hear the nearby ley line yet."
    @State var braidingQuipIndex = 0
    @State var localBrainTelemetry = LocalBrainTelemetryState()
    @State var localBrainProgress = LocalBrainProgressViewState()
    @State var isOpeningMovieVisible = true
    @State var didReachOpeningHold = false
    @State var didPrepareLaunchDesk = false
    @State var isLaunchDeskCurating = true
    @State var isSettlingLaunchDesk = false
    @State var isLaunchPresentationReady = false
    @State var isLaunchAmbientMotionPaused = true
    @State var launchDeskRitualVariant: LaunchDeskRitualVariant = .bookmarks
    @State var didSelectLaunchDeskRitual = false
    @State var didHydrateLaunchDecorations = false
    @AppStorage("launchDeskRitualLastVariant") var launchDeskRitualLastVariant = -1
    @State var activeGreeting: BookGreeting?
    @State var didShowGreetingThisLaunch = false
    // Cached literary-continuity digest + motif clusters. Recomputing these over
    // the whole archive on every `sourceInputs` access (including from rendered
    // views) caused main-thread freezes as history grew; they are now refreshed
    // only when the underlying data changes (see refreshContinuityCache).
    @State var cachedContinuityDigest: LiteraryContinuityDigest = .empty
    @State var cachedMotifClusters: [BookMotifCluster] = []
    @State var continuityCacheSignature = ""
    @State var bookPersistenceRevision: UInt64 = 0
    @State var isGlowMenuPresented = false
    @State var didRevealGlowPillInCurrentOnboarding = false
    @State var isGlowPillRevealing = false
    @State var isStacksSearchPresented = false
    @State var isAlmanacPresented = false
    @State private var padDestination: BookPadDestination = .today
    @State private var padColumnVisibility: NavigationSplitViewVisibility = .all
    @State private var padSearchFocusRequest = 0
    @State private var padSelectedSurfaceByDestination: [BookPadDestination: SurfacePage] = [:]
    @State private var padSelectedStacksResultID: String?
    @State private var padSelectedAlmanacPageID: String?
    @State private var padStacksQuery = ""
    @State private var padAlmanacMonthAnchor: Date?
    @State private var padAlmanacSelectedDay: Date?
    @State private var padOverviewAnchor: BookPadOverviewAnchor?
    @State private var padOverviewScrollRequest = 0
    @State var isBookShopPresented = false
    @State var isPagewrightPresented = false
    @State var pagewrightInitialPageIDs: [String] = []
    @State var currentStall: GoblinStall?
    @State var isPactMapPresented = false
    @State var isPeopleOfTheBookPresented = false
    @State var isLocationSealChoicesPresented = false
    @State var isInputChoicesPresented = false
    @State var isPlainPagePresented = false
    @State var plainPageAutoRecord = false
    @State var busySealID: String?
    @State var bannerSeed = Int.random(in: 0..<10_000)
    @State var openingVoiceSeed = Int.random(in: 0..<10_000)
    @State var lastKnockAt: Date?
    @State var knocksThisSession = 0
    @State var bookKnockNote: String?
    @State var bannerShudder = false
    @State var lastAnchorReadingLatitude: Double?
    @State var lastAnchorReadingLongitude: Double?
    @State var isAnchoringPlace = false
    @State var didHydrateLaunchState = false
    @State var didRunPostLaunchTasks = false
    @State var didRunIdleLocationRefresh = false
    @State var surfaceBuildToken = 0
    @State private var isRefreshingSurfaceDesk = false
    @State var isChangingAppLock = false

    let braider: Braider
    let wonderCompassChooser: WonderCompassPassageChoosing
    let weatherEnchanter: WeatherEnchanting
    let surfaceDismissalTTL: TimeInterval = 90 * 60
    let bookOfYouHeroTTL: TimeInterval = 3 * 3600
    // The braid nudge ("Book of You") is a gentle daily reminder, so after a swipe
    // it returns sooner than ordinary cards — but only while the day is unbraided
    // (the adapter hides it once `day.bookOfYou` exists). ~20 min is "later, not
    // instant" without being naggy.
    let braidCardDismissalTTL: TimeInterval = 20 * 60
    let surfaceRefreshCadence: Duration = .seconds(20 * 60)
    let braidingQuipCadence: Duration = .seconds(3)
    private static let localBrainWorkShelfScrollID = "local-brain-work-shelf"

    static var placeholderModelReport: LocalModelReport {
        LocalModelReport(
            state: .unavailable,
            preferredModelID: LocalModelManager.preferredModelID,
            fallbackModelID: LocalModelManager.fallbackModelID,
            preferredModelSource: LocalModelManager.preferredModel.sourceURL,
            fallbackModelSource: LocalModelManager.compactModel.sourceURL,
            installPath: LocalModelManager.modelsDirectory.path,
            detail: "ReEnchanted is opening the cover before checking the local brain.",
            deviceSummary: LocalModelManager.deviceSummary
        )
    }

    static var placeholderStoreReport: BookStore.Report {
        let today = BookDay.today()
        return BookStore.Report(
            schemaVersion: BookStore.schemaVersion,
            storagePath: BookStore.fileURL.path,
            dayCount: 1,
            pageCount: 0,
            todayID: today.id,
            todayPageCount: 0,
            todayBookOfYouCount: 0,
            loadSource: .fallbackToday,
            lastError: nil
        )
    }

    static var placeholderDatabaseReport: BookDatabase.Report {
        BookDatabase.Report(
            schemaVersion: BookDatabase.schemaVersion,
            storagePath: BookDatabase.storeURL.path,
            dayCount: 1,
            pageCount: 0,
            loadSource: .fallbackJSON,
            lastError: nil,
            backupCount: 0,
            lastBackupPath: nil
        )
    }

    var today: BookDay {
        BookStore.today(from: days)
    }

    var latestBookOfYouPage: BookPage? {
        days
            .flatMap(\.pages)
            .filter { $0.type == .bookOfYou }
            .max { $0.createdAt < $1.createdAt }
    }

    var bookOfYouHeroPage: BookPage? {
        guard let latest = latestBookOfYouPage,
              latest.id != dismissedBookOfYouHeroPageID,
              Date().timeIntervalSince(latest.createdAt) <= bookOfYouHeroTTL else {
            return nil
        }
        return latest
    }

    var workBlockingState: WorkBlockingState {
        WorkBlockingState(
            isLocalBrainWorking: localBrainTelemetry.isWorking,
            localBrainStatus: localBrainTelemetry.currentWorkStatus,
            isBraiding: generation.isBraiding,
            isPreparingAutomaticIllumination: generation.isPreparingAutomaticIllumination,
            isPreparingStoryPage: generation.isPreparingStoryPage,
            isPreparingGossipPage: generation.isPreparingGossipPage,
            isPreparingFacultyResearchPage: generation.isPreparingFacultyResearchPage,
            isPreparingLetterPage: generation.isPreparingLetterPage,
            isPreparingBleedEdition: generation.isPreparingBleedEdition,
            isRequestingWeather: isRequestingWeather
        )
    }

    var sourceInputs: BookSourceInputs {
        var inputs = BookSourceInputs.from(insideCover: insideCoverState)
        inputs.days = days
        inputs.bookInterior = vault.data.bookInterior ?? .unawakened
        inputs.magicMoment = vault.data.magicMoment ?? MagicMomentState()
        inputs.bookObservations = vault.data.bookObservations ?? []
        inputs.bookReadingBoundaries = vault.data.bookReadingBoundaries ?? []
        inputs.overnightConnectionDrafts = vault.data.overnightConnectionDrafts ?? []
        inputs.chosenQuill = vault.data.chosenQuill
        inputs.body = bodySignal
        if let currentWeather = weatherPageSignal ?? weatherSignal {
            inputs.weather = currentWeather
        }
        inputs.enchantedWeather = enchantedWeather
        inputs.anchors = anchorLedger
        inputs.nearbyAnchor = nearbyAnchor
        inputs.electives = electives
        inputs.entityBeliefOffsets = entityBeliefLedger
        inputs.relationshipField = vault.data.relationshipField ?? [:]
        inputs.faeState = vault.data.fae ?? FaePlayerState()
        inputs.pactWar = vault.data.pactWar ?? PactWarState()
        inputs.radio = vault.data.radio ?? .off
        inputs.openWorldEventArchive = vault.data.openWorldEventArchive
        inputs.ownedPackIDs = Set(vault.data.ownedPacks ?? [])
        inputs.hemisphere = Hemisphere.from(latitude: lastAnchorReadingLatitude)
        inputs.surfaceHistory = vault.data.surfaceHistory ?? [:]
        inputs.firstRunEngagedKeys = Set(vault.data.firstRunEngaged ?? [])
        inputs.readerLearning = vault.data.readerLearning ?? ReaderLearningModel()
        inputs.learnedBraidNotes = vault.data.learnedBraidNotes ?? []
        inputs.readerBeliefScore = beliefScore
        inputs.pocket = decodedPocketLedger()
        inputs.chosenQuill = decodedChosenQuill()
        inputs.people = vault.data.people ?? PeopleLedger()
        inputs.publicMargins = publicMarginsIncomingOptIn ? publicMarginsSnapshot : nil
        inputs.calendarEvents = calendarEvents
        inputs.calendarIntegrationEnabled = bookCalendarEnabled
        inputs.nearbyPlaces = nearbyPlaces
        inputs.resurfacingCandidates = resurfacedPages
        inputs.quietDays = cachedQuietDayCount
        inputs.nothingGreyOffset = vault.data.nothingGreyOffset ?? 0
        inputs.storyRecipeBoosts = vault.data.storyRecipeBoosts ?? [:]
        inputs.storyMotifs = vault.data.storyMotifs ?? [:]
        inputs.storyRituals = vault.data.storyRituals ?? [:]
        inputs.storySettingAffinities = vault.data.storySettingAffinities ?? [:]
        inputs.storySceneBiases = vault.data.storySceneBiases ?? [:]
        inputs.bookNoticeEvidence = vault.data.bookNoticeEvidence ?? 0
        inputs.magicMoment = vault.data.magicMoment ?? MagicMomentState()
        inputs.bookObservations = vault.data.bookObservations ?? []
        inputs.bookReadingBoundaries = vault.data.bookReadingBoundaries ?? []
        inputs.overnightConnectionDrafts = vault.data.overnightConnectionDrafts ?? []
        inputs.currentArc = vault.data.currentArc
        inputs.recentNarrativeEvents = narrativeEvents
        // Read the cached digest/clusters (refreshed on data change), not a fresh
        // whole-archive recompute on every access.
        inputs.continuity = cachedContinuityDigest
        inputs.constellations = vault.data.constellations ?? []
        inputs.wagers = vault.data.wagers ?? []
        inputs.themes = vault.data.themes ?? []
        inputs.clusters = cachedMotifClusters
        inputs.bleedIssueNumber = cachedBleedIssueNumber
        inputs.preparedBleedEditionSurface = generation.preparedBleedEditionSurface
        inputs.bookJump = vault.data.bookJump ?? BookJumpState()
        inputs.readerLexicon = vault.data.readerLexicon ?? ReaderLexicon()
        inputs.preparedAnchorSurface = preparedAnchorSurface
        inputs.selectedWonderCompass = selectedWonderCompassSnippet
        inputs.selectedWonderCompassSelector = selectedWonderCompassSelector
        inputs.preparedIlluminatedPhotoSurface = generation.automaticIlluminatedSurface
        inputs.preparedStoryPageSurface = generation.preparedStoryPageSurface
        inputs.preparedGossipPageSurface = generation.preparedGossipPageSurface
        inputs.preparedFacultyResearchSurface = generation.preparedFacultyResearchSurface
        inputs.preparedLetterSurface = generation.preparedLetterSurface
        inputs.userPhotoIlluminationFallbackAllowed = userPhotoIlluminationFallbackAllowed
        inputs.localBrainIsReady = modelReport.state == .ready
        inputs.selfFacts = selfFacts
        inputs.facultyEntries = facultyEntries
        inputs.customCastMembers = customCastMembers.map { member in
            var adjusted = member
            let currentGlow = max(0, min(100, member.baseBelief + (entityBeliefLedger[member.id] ?? 0)))
            adjusted.baseBelief = currentGlow
            return adjusted
        }
        inputs.narrative = cachedNarrativeSourceSnapshot
        return inputs
    }

    var keptPageCount: Int {
        days.reduce(0) { $0 + $1.pages.count }
    }

    func isMemoryPageLocked(_ type: BookPageType) -> Bool {
        BookMemoryGate.locks(type, keptPageCount: keptPageCount)
    }

    func showMemoryPageLockedMessage(for type: BookPageType) {
        BookFeedback.play(.error)
        statusMessage = BookMemoryGate.message(for: type, keptPageCount: keptPageCount)
    }

    /// Manual page types that only exist when their content pack is owned. They
    /// are hidden from the Pages menu (and blocked from manual open) unless the
    /// entitlement is present, so a locked season leaves no dangling page type.
    static let contentPackGatedPageTypes: [BookPageType: String] = [
        .wordNegotiation: "dictionary-rebellion"
    ]

    func isContentPackLocked(_ type: BookPageType) -> Bool {
        guard let packID = Self.contentPackGatedPageTypes[type] else { return false }
        return !PackEntitlements.isUnlocked(packID)
    }

    var selectedCuratorSurfaces: [SurfacePage] {
        buildCuratorSurfaces(now: surfaceRefreshDate)
    }

    var surfaces: [SurfacePage] {
        var pages = surfacedPages
        if let purchaseThankYouSurface {
            pages.removeAll { $0.id == purchaseThankYouSurface.id }
            pages.insert(purchaseThankYouSurface, at: 0)
        }
        return Array(pages.prefix(3))
    }

    func buildCuratorSurfaces(now: Date) -> [SurfacePage] {
        let inputs = sourceInputs
        let preferences = CuratorSurfacePreferences(
            dismissedSurfaceIDs: dismissedSurfaceIDs(for: today.id, now: now),
            disabledSourceIDs: disabledSourceIDs(),
            pageBeliefProfiles: Dictionary(
                uniqueKeysWithValues: pageBeliefProfiles.map { ($0.sourceID, $0) }
            ),
            readerLearning: vault.data.readerLearning ?? ReaderLearningModel()
        )

        if let firstRunSurfaces = FirstRunPageSequence.surfaces(
            for: today,
            context: CuratorContext.make(for: today),
            inputs: inputs,
            now: now
        ) {
            let allowed = firstRunSurfaces.filter { preferences.allows($0) }
            // Only let the first-run sequence own the desk while it still has a
            // greeting card to show. The local brain install no longer gates the
            // desk — it rides beside the ordinary feed below.
            if !allowed.isEmpty {
                return allowed
            }
        }

        let feed = BookCurator.surfacedPages(
            for: today,
            inputs: inputs,
            now: now,
            limit: 3,
            preferences: preferences
        )
        let upgrade = FirstRunPageSequence.pendingLocalBrainUpgrade(inputs: inputs)
        if let upgrade, preferences.allows(upgrade) {
            return FirstRunPageSequence.mergingUpgradeRider(upgrade, into: feed, limit: 3)
        }
        return feed
    }

    var enabledActiveSourceCount: Int {
        BookPageSourceRegistry.activeSources.filter { isSourceEnabled(sourceID: $0.id) }.count
    }

    var entityBeliefLedger: [String: Int] {
        (try? JSONDecoder().decode([String: Int].self, from: Data(entityBeliefLedgerData.utf8))) ?? [:]
    }

    var pageBeliefLedger: [String: Int] {
        (try? JSONDecoder().decode([String: Int].self, from: Data(pageBeliefLedgerData.utf8))) ?? [:]
    }

    var pageBeliefProfiles: [PageBeliefProfile] {
        BookPageSourceRegistry.beliefProfiles(ledger: pageBeliefLedger)
    }

    var glowEntityMenuItems: [GlowEntityMenuItem] {
        let ledger = entityBeliefLedger
        return (NarrativePackRegistry.entities + customCastMembers.map(\.entity))
            .filter { !Self.pageEntityIDsInPagesMenu.contains($0.id) }
            .map { entity in
                let glow = max(0, min(100, entity.belief + (ledger[entity.id] ?? 0)))
                return GlowEntityMenuItem(
                    id: entity.id,
                    name: entity.name,
                    kind: entity.kind.rawValue,
                    glow: glow,
                    line: glowLine(for: entity)
                )
            }
            .sorted { left, right in
                if left.glow == right.glow {
                    return left.name < right.name
                }
                return left.glow > right.glow
            }
    }

    static let pageEntityIDsInPagesMenu: Set<String> = [
        "body-page",
        "weather-page"
    ]

    var glowPageMenuItems: [GlowPageMenuItem] {
        pageBeliefProfiles
            .filter { !isContentPackLocked($0.type) }
            .map { profile in
            let source = BookPageSourceRegistry.source(id: profile.sourceID, fallbackType: profile.type)
            return GlowPageMenuItem(
                id: profile.sourceID,
                type: profile.type,
                sourceID: profile.sourceID,
                title: profile.title,
                detail: "\(profile.cadence). \(profile.note)",
                symbolName: source.symbolName,
                glow: profile.belief,
                narrativeWeight: profile.narrativeWeight
            )
        }
        .sorted { left, right in
            if left.curationWeight == right.curationWeight {
                return left.title < right.title
            }
            return left.curationWeight > right.curationWeight
        }
    }

    var glowBookSectionMenuItems: [GlowBookSectionMenuItem] {
        BookReferenceCatalog.wonderCompass.map { snippet in
            GlowBookSectionMenuItem(
                id: snippet.id,
                title: snippet.title,
                detail: snippet.prompt
            )
        }
    }

    var glowEnchantmentMenuItems: [GlowEnchantmentMenuItem] {
        StoryEnchantmentCatalog.spells.map {
            GlowEnchantmentMenuItem(id: $0.id, title: $0.title, detail: $0.detail)
        }
    }

    init() {
        #if NATIVE_LOCAL_BRAIN && canImport(MLXLLM) && canImport(MLXVLM) && canImport(MLXLMCommon) && canImport(MLXLMTokenizers) && canImport(MLXLMHFAPI) && canImport(MLX) && !targetEnvironment(simulator)
        braider = AppBraider(local: MLXBookBraider())
        wonderCompassChooser = AppWonderCompassChooser(local: MLXWonderCompassChooser())
        weatherEnchanter = AppWeatherEnchanter(local: MLXWeatherEnchanter())
        #else
        braider = ResilientBraider()
        wonderCompassChooser = ResilientWonderCompassChooser()
        weatherEnchanter = ResilientWeatherEnchanter()
        #endif
    }

    @ViewBuilder
    private var rootStack: some View {
        ZStack {
                if localBrainTelemetry.isReading {
                    LocalBrainReadingRoom(isPaused: shouldPauseAmbientMotion)
                } else {
                    // Also quiet while the opening movie covers this layer, so
                    // ambient ticking never competes with launch work.
                    BookBackground(isQuiet: shouldPauseAmbientMotion || isOpeningMovieVisible)

                    // The book flourish settles into an opaque hold before we
                    // mount this desk. That lets its first layout happen out of
                    // sight, and the final page turn only begins after the first
                    // home frame is ready underneath it.
                    if didPrepareLaunchDesk {
                        preparedBookWorkspace
                            .accessibilityHidden(isOpeningMovieVisible || isStoryOnboardingActive)
                        .task {
                            await settleLaunchDeskAfterMountIfNeeded()
                        }
                    }
                }

                if let activeTutorNote {
                    VStack {
                        Spacer()
                        MarginTutorNoteCard(note: activeTutorNote) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                                self.activeTutorNote = nil
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 18)
                    }
                    .zIndex(17)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: activeTutorNote.id) {
                        try? await Task.sleep(for: .seconds(12))
                        guard !Task.isCancelled else { return }
                        withAnimation(.easeOut(duration: 0.5)) {
                            self.activeTutorNote = nil
                        }
                    }
                }

                if !didCompleteStoryOnboarding && !isOpeningMovieVisible {
                    OnboardingFlowView(
                        onGlowUnlocked: revealGlowPillIfNeeded,
                        onKeepIlluminatedPhoto: { draft, renderedURL in
                            keepOnboardingIlluminatedPhoto(draft: draft, renderedURL: renderedURL)
                        },
                        onUnlockPack: { packID in
                            unlockPack(packID)
                        }
                    ) { result in
                        completeOnboarding(result)
                    }
                    .onAppear {
                        didRevealGlowPillInCurrentOnboarding = false
                        isGlowMenuPresented = false
                        isGlowPillRevealing = false
                    }
                    .zIndex(18)
                }

                if isOpeningMovieVisible {
                    OpeningBookLoadingView(
                        isReadyToReveal: isLaunchPresentationReady,
                        onReachedHold: {
                            didReachOpeningHold = true
                        },
                        onFinished: {
                            finishOpeningMovie()
                        }
                    )
                    .transition(.opacity)
                    .zIndex(20)
                }

                if let activeGreeting {
                    BookGreetingOverlay(greeting: activeGreeting) {
                        withAnimation(.easeOut(duration: 0.4)) { self.activeGreeting = nil }
                    }
                    .zIndex(19)
                }

                if let weeklyIssueBindingNote {
                    WeeklyIssueBindingOverlay(note: weeklyIssueBindingNote)
                        .zIndex(30)
                        .transition(.opacity)
                }

                if isGlowMenuPresented && canOpenGlowMenu {
                    GlowCommandMenu(
                        score: beliefScore,
                        surfaceCount: surfaces.count,
                        capturedPageCount: today.capturedPages.count,
                        entities: glowEntityMenuItems,
                        pageTypes: glowPageMenuItems,
                        bookSections: glowBookSectionMenuItems,
                        enchantments: glowEnchantmentMenuItems,
                        canBindWeeklyIssue: currentWeeklyIssue != nil,
                        canBindMonthlyEdition: !bindableEditionMonths.isEmpty,
                        preparedPagewrightPDFURL: preparedPagewrightPDFURL,
                        preparedWeeklyIssueCardURL: preparedWeeklyIssueCardURL,
                        preparedWeeklyIssuePDFURL: preparedWeeklyIssuePDFURL,
                        preparedMonthlyEditionURL: preparedMonthlyEditionURL,
                        preparedAnnualEditionURL: preparedAnnualEditionURL,
                        preparedPlainInkURL: preparedPlainInkURL,
                        preparedSaveFileURL: preparedSaveFileURL,
                        onCreateCastMember: {
                            BookFeedback.play(.openPage)
                            isCustomCastSheetPresented = true
                        },
                        onClose: closeGlowMenu,
                        onSelectAction: handleGlowMenuAction
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.82, anchor: .topTrailing)
                            .combined(with: .move(edge: .trailing))
                            .combined(with: .opacity),
                        removal: .scale(scale: 0.96, anchor: .topTrailing)
                            .combined(with: .opacity)
                    ))
                    .zIndex(15)
                }

                LivingInkBurst(
                    trigger: keepInkBurstTrigger,
                    text: keepInkBurstText,
                    mood: .kept,
                    intensity: 0.82,
                    isPaused: shouldPauseAmbientMotion
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 34)
                .padding(.bottom, 84)
                .zIndex(16)

                if let celebration = editionCelebration {
                    EditionCelebration(info: celebration) {
                        withAnimation(.easeOut(duration: 0.4)) { editionCelebration = nil }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
                    .zIndex(30)
                }

                if let note = keepMarginNote {
                    Button {
                        pressKeepArtifactCard()
                    } label: {
                        KeepMarginNoteToast(note: note, showsPressHint: keepArtifactQuote != nil)
                    }
                    .buttonStyle(.plain)
                    .disabled(keepArtifactQuote == nil)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 140)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(17)
                } else if let trace = keepMarginTrace {
                    KeepMarginTrace(note: trace)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(.trailing, 20)
                        .padding(.bottom, 148)
                        .transition(.opacity)
                        .zIndex(17)
                        .allowsHitTesting(false)
                }

                if let note = shadowWonderUnlockNote {
                    Button {
                        withAnimation(.easeOut(duration: 0.35)) {
                            shadowWonderUnlockNote = nil
                        }
                    } label: {
                        KeepMarginNoteToast(
                            note: note,
                            announcementTitle: "SHADOW WONDER UNLOCKED!"
                        )
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 140)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(19)
                    .task {
                        try? await Task.sleep(for: .seconds(8))
                        guard !Task.isCancelled else { return }
                        withAnimation(.easeOut(duration: 0.45)) {
                            shadowWonderUnlockNote = nil
                        }
                    }
                    .accessibilityHint("Double-tap to dismiss")
                }

                if let note = marginaliaAchievementUnlockNote {
                    Button {
                        withAnimation(.easeOut(duration: 0.35)) {
                            marginaliaAchievementUnlockNote = nil
                        }
                    } label: {
                        KeepMarginNoteToast(
                            note: note,
                            announcementTitle: marginaliaAchievementUnlockTitle
                        )
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.horizontal, 28)
                    .padding(.bottom, shadowWonderUnlockNote == nil ? 140 : 292)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(20)
                    .task(id: marginaliaAchievementUnlockTitle) {
                        try? await Task.sleep(for: .seconds(9))
                        guard !Task.isCancelled else { return }
                        withAnimation(.easeOut(duration: 0.45)) {
                            marginaliaAchievementUnlockNote = nil
                        }
                    }
                    .accessibilityHint("Double-tap to dismiss")
                }
        }
    }

    private var usesPadWorkspace: Bool {
        #if canImport(UIKit)
        UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular
        #else
        false
        #endif
    }

    @ViewBuilder
    private var preparedBookWorkspace: some View {
        if usesPadWorkspace {
            iPadWorkspace
        } else {
            compactDeskWorkspace
        }
    }

    /// The existing phone desk is intentionally kept intact. It also becomes
    /// the narrow Stage Manager/Split View fallback when the iPad window no
    /// longer has enough horizontal room for real columns.
    private var compactDeskWorkspace: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 26) {
                    AnyView(localBrainWorkShelf)
                        .id(Self.localBrainWorkShelfScrollID)
                    AnyView(surfaceShelf)
                    AnyView(marginaliaSealsRow)
                    AnyView(bookTodayShelf)
                    AnyView(castLedgerShelf)
                    AnyView(todayFragments)
                    AnyView(resurfacedShelf)
                    AnyView(archiveShelf)
                    AnyView(sourceControlsShelf)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .frame(maxWidth: 920)
                .frame(maxWidth: .infinity)
            }
            .refreshable {
                await refreshAllSurfaceCards()
            }
            .onChange(of: localBrainTelemetry.isWorking) { _, isWorking in
                guard isWorking else { return }
                scrollToLocalBrainWorkShelf(scrollProxy)
            }
            .background {
                LocalBrainPreviewStartObserver(
                    progress: localBrainProgress,
                    isWorking: localBrainTelemetry.isWorking
                ) {
                    scrollToLocalBrainWorkShelf(scrollProxy)
                }
            }
        }
    }

    private var iPadWorkspace: some View {
        NavigationSplitView(columnVisibility: $padColumnVisibility) {
            padSidebar
                .navigationSplitViewColumnWidth(min: 210, ideal: 245, max: 285)
        } content: {
            padWorkspaceContent
                .navigationSplitViewColumnWidth(min: 330, ideal: 410, max: 500)
        } detail: {
            padWorkspaceDetail
                .toolbar {
                    ToolbarItem(placement: .secondaryAction) {
                        padCommandMenu
                    }
                }
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: selectedSurface?.id) { _, _ in
            padSelectedSurfaceByDestination[padDestination] = selectedSurface
        }
    }

    private var padSidebar: some View {
        List {
            padSidebarBookplate
                .listRowInsets(EdgeInsets(top: 12, leading: 14, bottom: 16, trailing: 14))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            Section {
                ForEach(BookPadDestination.allCases) { destination in
                    padSidebarDestinationButton(destination)
                }
            } header: {
                Text("Book").sectionRuneLabel()
            }

            Section {
                Button {
                    BookFeedback.play(.openPage)
                    isConnectionsPresented = true
                } label: {
                    Label("Connections", systemImage: "point.3.connected.trianglepath.dotted")
                }

                Button {
                    BookFeedback.play(.openPage)
                    isPeopleOfTheBookPresented = true
                } label: {
                    Label("People", systemImage: "person.2")
                }

                Button {
                    BookFeedback.play(.openPage)
                    isPactMapPresented = true
                } label: {
                    Label("Pact Map", systemImage: "map")
                }
            } header: {
                Text("World").sectionRuneLabel()
            }

            Section {
                Button {
                    BookFeedback.play(.openPage)
                    isPagewrightPresented = true
                } label: {
                    Label("Scrapbook Studio", systemImage: "scissors")
                }

                Button {
                    isBookOfYouShelfExpanded = true
                    showPadOverview(.archive)
                } label: {
                    Label("Book of You", systemImage: "books.vertical")
                }
            } header: {
                Text("Make & Bind").sectionRuneLabel()
            }

            Section {
                Button {
                    BookFeedback.play(.openPage)
                    currentStall = buildGoblinStall()
                    isBookShopPresented = true
                } label: {
                    Label("Bookshop", systemImage: "storefront")
                }

                Button {
                    isQuietMechanicsExpanded = true
                    showPadOverview(.colophon)
                } label: {
                    Label("Colophon", systemImage: "gearshape.2")
                }
            } header: {
                Text("Services").sectionRuneLabel()
            }

        }
        .foregroundStyle(BookPalette.nightText.opacity(0.82))
        .buttonStyle(.plain)
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(BookPalette.nightPanel.opacity(0.98))
        .tint(BookPalette.lampGold)
        .navigationTitle("The Book")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            padQuickPageButton
        }
    }

    private var padSidebarBookplate: some View {
        let moon = MoonPhaseCalendar.phase()
        let keptCount = days.lazy.flatMap(\.pages).count
        let glow = BeliefLexicon.glowName(for: beliefScore)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 11) {
                Image(systemName: moon.symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(BookPalette.nightPanel)
                    .frame(width: 40, height: 40)
                    .background(BookPalette.lampGold, in: Circle())
                    .shadow(color: BookPalette.lampGold.opacity(0.28), radius: 10)

                VStack(alignment: .leading, spacing: 2) {
                    Text("ReEnchanted")
                        .font(.system(.headline, design: .serif, weight: .bold))
                        .foregroundStyle(BookPalette.nightText)
                    Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(BookPalette.nightText.opacity(0.58))
                        .lineLimit(1)
                }
            }

            HStack(spacing: 8) {
                Label(glow, systemImage: "sparkles")
                Spacer(minLength: 4)
                Label("\(keptCount)", systemImage: "book.pages")
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(BookPalette.lampGold.opacity(0.9))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(BookPalette.lampGold.opacity(0.10), in: Capsule())
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("ReEnchanted. \(moon.name). Glow: \(glow). \(keptCount) kept pages.")
    }

    private func padSidebarDestinationButton(_ destination: BookPadDestination) -> some View {
        let isSelected = padDestination == destination

        return Button {
            BookFeedback.play(.select)
            selectPadDestination(destination)
        } label: {
            HStack(spacing: 10) {
                Label(destination.title, systemImage: destination.symbolName)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(destination.keyboardLabel)
                    .font(.caption2.monospaced().weight(.semibold))
                    .foregroundStyle(BookPalette.nightText.opacity(isSelected ? 0.72 : 0.38))
            }
            .contentShape(Rectangle())
        }
        .foregroundStyle(isSelected ? BookPalette.lampGold : BookPalette.nightText.opacity(0.82))
        .listRowBackground(isSelected ? BookPalette.lampGold.opacity(0.14) : Color.clear)
        .hoverEffect(.highlight)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("Keyboard shortcut \(destination.keyboardLabel)")
    }

    private var padQuickPageButton: some View {
        Button {
            presentPlainPage()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "square.and.pencil")
                    .font(.headline)
                Text("New Plain Page")
                    .font(.subheadline.weight(.bold))
                Spacer()
                Text("⌘N")
                    .font(.caption2.monospaced().weight(.bold))
                    .opacity(0.7)
            }
            .foregroundStyle(BookPalette.nightPanel)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(BookPalette.lampGold, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .shadow(color: .black.opacity(0.22), radius: 12, y: 5)
        }
        .buttonStyle(.bookPress())
        .bookCardHover()
        .padding(12)
        .background(BookPalette.nightPanel.opacity(0.96))
        .accessibilityHint("Keyboard shortcut Command N")
    }

    @ViewBuilder
    private var padWorkspaceContent: some View {
        switch padDestination {
        case .today:
            padTodayColumn
        case .stacks:
            SearchTheStacksSheet(
                dataset: stacksSearchDataset,
                datasetRevision: bookPersistenceRevision,
                isLocalBrainWorking: localBrainTelemetry.isWorking,
                localBrainWorkLabel: localBrainTelemetry.currentLabel,
                localBrainWorkStartedAt: localBrainTelemetry.startedAt,
                isEmbedded: true,
                focusRequest: padSearchFocusRequest,
                selectedResultID: padSelectedStacksResultID,
                initialQuery: padStacksQuery,
                onQueryChange: { padStacksQuery = $0 },
                onOpen: { result in
                    padSelectedStacksResultID = result.id
                    openSearchResult(result)
                }
            )
        case .almanac:
            AlmanacSheet(
                days: days,
                isEmbedded: true,
                selectedPageID: padSelectedAlmanacPageID,
                initialMonthAnchor: padAlmanacMonthAnchor,
                initialSelectedDay: padAlmanacSelectedDay,
                onNavigationChange: { month, day in
                    padAlmanacMonthAnchor = month
                    padAlmanacSelectedDay = day
                },
                onOpen: { page in
                    padSelectedAlmanacPageID = page.id
                    openKeptPage(page)
                }
            )
        }
    }

    @ViewBuilder
    private var padWorkspaceDetail: some View {
        Group {
            if let selectedSurface {
                captureSheet(
                    for: selectedSurface,
                    isEmbedded: true,
                    onDismissRequest: closePadDetail
                )
                .id(selectedSurface.id)
            } else {
                switch padDestination {
                case .today:
                    padTodayOverview
                case .stacks:
                    padWorkspacePlaceholder(
                        title: "The reading stand is ready",
                        message: "Search the Stacks or choose a result. The index will stay open while the page arrives here.",
                        systemImage: "book.pages"
                    )
                case .almanac:
                    padWorkspacePlaceholder(
                        title: "Choose a lit day",
                        message: "Select a marked date, then choose a kept page. The calendar will remain open beside it.",
                        systemImage: "calendar"
                    )
                }
            }
        }
        .navigationTitle(padDetailTitle)
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(BookPalette.lampGold.opacity(0.12))
                .frame(width: 1)
                .allowsHitTesting(false)
        }
    }

    private var padDetailTitle: String {
        if let selectedSurface {
            return selectedSurface.prompt
        }
        switch padDestination {
        case .today: return "The Open Desk"
        case .stacks: return "Reading Stand"
        case .almanac: return "Almanac Reading Stand"
        }
    }

    private func closePadDetail() {
        selectedSurface = nil
        switch padDestination {
        case .today:
            break
        case .stacks:
            padSelectedStacksResultID = nil
        case .almanac:
            padSelectedAlmanacPageID = nil
        }
    }

    private func selectPadDestination(_ destination: BookPadDestination) {
        guard destination != padDestination else { return }
        padSelectedSurfaceByDestination[padDestination] = selectedSurface
        padDestination = destination
        selectedSurface = padSelectedSurfaceByDestination[destination]
    }

    private var padTodayColumn: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    padTodayPulse
                    AnyView(localBrainWorkShelf)
                        .id(Self.localBrainWorkShelfScrollID)
                    AnyView(surfaceShelf)
                }
                .padding(20)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .refreshable {
                await refreshAllSurfaceCards()
            }
            .onChange(of: localBrainTelemetry.isWorking) { _, isWorking in
                guard isWorking else { return }
                scrollToLocalBrainWorkShelf(scrollProxy)
            }
            .background {
                LocalBrainPreviewStartObserver(
                    progress: localBrainProgress,
                    isWorking: localBrainTelemetry.isWorking
                ) {
                    scrollToLocalBrainWorkShelf(scrollProxy)
                }
            }
            .navigationTitle("Today")
        }
    }

    private var padTodayPulse: some View {
        let moon = MoonPhaseCalendar.phase()

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(.caption.weight(.black))
                        .tracking(0.6)
                        .foregroundStyle(BookPalette.teal)
                    Text("The Book is awake")
                        .font(.system(.title2, design: .serif, weight: .bold))
                        .foregroundStyle(BookPalette.nightText)
                }

                Spacer()

                Image(systemName: moon.symbolName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(BookPalette.lampGold)
                    .frame(width: 42, height: 42)
                    .background(BookPalette.lampGold.opacity(0.12), in: Circle())
                    .accessibilityLabel(moon.name)
            }

            Text(openingVoice.heroLine)
                .font(.system(.callout, design: .serif, weight: .semibold))
                .foregroundStyle(BookPalette.nightText.opacity(0.76))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                padPulseBadge(
                    title: "\(surfaces.count) rising",
                    systemImage: "sparkles.rectangle.stack",
                    accent: BookPalette.lampGold
                )
                padPulseBadge(
                    title: "\(today.capturedPages.count) kept today",
                    systemImage: "tray.full",
                    accent: BookPalette.teal
                )
            }
        }
        .padding(16)
        .background(BookPalette.nightPanel.opacity(0.62), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.18), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private func padPulseBadge(title: String, systemImage: String, accent: Color) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.bold))
            .foregroundStyle(accent)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(accent.opacity(0.10), in: Capsule())
    }

    private var padTodayOverview: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    AnyView(topBanner)
                    AnyView(hero)

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 310), spacing: 20, alignment: .top)],
                        alignment: .leading,
                        spacing: 20
                    ) {
                        AnyView(marginaliaSealsRow)
                        AnyView(castLedgerShelf)
                        AnyView(todayFragments)
                        AnyView(resurfacedShelf)
                    }

                    AnyView(archiveShelf)
                        .id(BookPadOverviewAnchor.archive.rawValue)
                    AnyView(sourceControlsShelf)
                        .id(BookPadOverviewAnchor.colophon.rawValue)
                }
                .padding(24)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .task(id: padOverviewScrollRequest) {
                guard let anchor = padOverviewAnchor else { return }
                await Task.yield()
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.32)) {
                    scrollProxy.scrollTo(anchor.rawValue, anchor: .top)
                }
            }
        }
        .background(BookBackground(isQuiet: true, showsAmbientLetters: false))
        .navigationTitle("The Open Desk")
    }

    private func showPadOverview(_ anchor: BookPadOverviewAnchor) {
        selectPadDestination(.today)
        padSelectedSurfaceByDestination[.today] = nil
        selectedSurface = nil
        padOverviewAnchor = anchor
        padOverviewScrollRequest &+= 1
    }

    private func padWorkspacePlaceholder(
        title: String,
        message: String,
        systemImage: String
    ) -> some View {
        ZStack {
            BookBackground(isQuiet: true, showsAmbientLetters: false)

            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .fill(BookPalette.lampGold.opacity(0.14))
                        .frame(width: 92, height: 92)
                    Image(systemName: systemImage)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(BookPalette.lampGold)
                    MarginaliaImage(name: "MarginaliaFeather", width: 58, opacity: 0.26)
                        .rotationEffect(.degrees(-15))
                        .offset(x: 54, y: 36)
                        .accessibilityHidden(true)
                }

                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(.title2, design: .serif, weight: .bold))
                        .foregroundStyle(BookPalette.ink)
                    Text(message)
                        .font(.system(.callout, design: .serif))
                        .foregroundStyle(BookPalette.ink.opacity(0.68))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    Button {
                        if padDestination == .stacks {
                            padSearchFocusRequest &+= 1
                        } else {
                            selectPadDestination(.today)
                        }
                    } label: {
                        Label(
                            padDestination == .stacks ? "Focus Search" : "Return to Today",
                            systemImage: padDestination == .stacks ? "magnifyingglass" : "sparkles.rectangle.stack"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(BookPalette.teal)

                    Button {
                        presentPlainPage()
                    } label: {
                        Label("New Page", systemImage: "square.and.pencil")
                    }
                    .buttonStyle(.bordered)
                    .tint(BookPalette.gold)
                }
            }
            .padding(30)
            .frame(maxWidth: 480)
            .parchmentSurface(accent: BookPalette.lampGold.opacity(0.72), isActive: false)
            .padding(36)
            .accessibilityElement(children: .contain)
        }
    }

    private var padCommandMenu: some View {
        Menu {
            ForEach(BookPadDestination.allCases) { destination in
                Button {
                    selectPadDestination(destination)
                } label: {
                    Label(destination.title, systemImage: destination.symbolName)
                }
                .keyboardShortcut(destination.keyboardNumber, modifiers: .command)
            }

            Divider()

            Button {
                selectPadDestination(.stacks)
                padSearchFocusRequest &+= 1
            } label: {
                Label("Find in the Stacks", systemImage: "magnifyingglass")
            }
            .keyboardShortcut("f", modifiers: .command)

            Button {
                presentPlainPage()
            } label: {
                Label("New Plain Page", systemImage: "square.and.pencil")
            }
            .keyboardShortcut("n", modifiers: .command)
        } label: {
            Label("Book Commands", systemImage: "keyboard")
        }
    }

    var body: some View {
        Group {
            if usesPadWorkspace {
                presentationRoot
            } else {
                NavigationStack {
                    presentationRoot
                }
            }
        }
        .keepsFocusedTextInputVisible()
    }

    // The view body is split into layered computed properties — rootStack →
    // chromeRoot → presentationRoot → body — so each is type-checked as its own
    // small expression. Keep it this way: a single inlined chain of this many
    // modifiers sits right at the Swift type-checker's complexity ceiling.
    private var chromeLaunchRoot: AnyView {
        AnyView(
            rootStack
            .navigationTitle("ReEnchanted")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar((isGlowMenuPresented || isOpeningMovieVisible || (isStoryOnboardingActive && !didRevealGlowPillInCurrentOnboarding)) ? .hidden : .visible, for: .navigationBar)
            .task {
                #if canImport(UserNotifications)
                BookWhisperPresenter.shared.onPromptReply = { whisper, answer in
                    keepPromptWhisperReply(whisper, answer: answer)
                }
                #endif
                // The first interactive desk must be truthful and stable. Mount
                // a noninteractive ritual beneath the cover, then hydrate and
                // run the quick curator while the book opens. The overlay may
                // reveal the ritual if the work outlasts the flourish, but it
                // never reveals stale cards that can disappear under a finger.
                await waitForOpeningHold()
                prepareLaunchDeskIfNeeded()
                await curateLaunchDeskIfNeeded()
                await waitForOpeningMovieToFinish()
                await runPostLaunchTasksIfNeeded()
                handlePendingRadioWidgetCommand()
                handlePendingCompassWidgetCommand()
                handlePendingWidgetDeepLink()
                handlePendingSiriCommand()
            }
            .task(id: generation.isBraiding) {
                guard generation.isBraiding else { return }
                while !Task.isCancelled && generation.isBraiding {
                    try? await Task.sleep(for: braidingQuipCadence)
                    guard !Task.isCancelled && generation.isBraiding else { return }
                    withAnimation(.easeInOut(duration: 0.32)) {
                        braidingQuipIndex = (braidingQuipIndex + 1) % BraidingQuips.lines.count
                    }
                }
            }
        )
    }

    private var chromeBrainRoot: AnyView {
        AnyView(
            chromeLaunchRoot
            .onReceive(NotificationCenter.default.publisher(for: .localBrainDidWake)) { _ in
                localBrainTelemetry.wake()
                AppMemoryLedger.record("reading-room-enter")
            }
            .onReceive(NotificationCenter.default.publisher(for: .localBrainDidRest)) { _ in
                localBrainTelemetry.rest()
                AppMemoryLedger.record("reading-room-exit")
            }
            .onReceive(NotificationCenter.default.publisher(for: .localBrainWorkDidChange)) { notification in
                guard let snapshot = notification.object as? LocalBrainWorkSnapshot else { return }
                if snapshot.isWorking {
                    let isNewWork = !localBrainTelemetry.isWorking
                        || localBrainTelemetry.currentLabel != (snapshot.label ?? "the Book")
                    _ = localBrainTelemetry.beginOrUpdateWork(
                        label: snapshot.label,
                        promptCharacters: snapshot.promptCharacters,
                        queuedCount: snapshot.queuedCount
                    )
                    if isNewWork {
                        localBrainProgress.reset()
                    }
                } else {
                    localBrainTelemetry.finishWork()
                    localBrainProgress.reset()
                    radioManager.resumeAfterMemoryPressureIfNeeded()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .localBrainGenerationDidProgress)) { notification in
                guard let snapshot = notification.object as? LocalBrainGenerationProgressSnapshot else { return }
                guard localBrainTelemetry.isWorking else { return }
                // A rejected overlapping request briefly publishes "busy".
                // Restore the active task's real descriptor on its next progress
                // snapshot without putting the growing preview back in this
                // large value-state graph.
                if !snapshot.label.isEmpty,
                   snapshot.label != localBrainTelemetry.currentLabel {
                    _ = localBrainTelemetry.beginOrUpdateWork(
                        label: snapshot.label,
                        promptCharacters: localBrainTelemetry.currentPromptCharacters,
                        queuedCount: localBrainTelemetry.currentQueuedCount
                    )
                }
                localBrainProgress.update(snapshot)
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task {
                        await reloadDaysFromArchive()
                        refreshBookInterior()
                        refreshOpeningVoice()
                        BookWhispers.refreshPromptWhispers(
                            enabled: promptWhispersEnabled,
                            cadence: bookWhisperCadence,
                            day: today,
                            inputs: sourceInputs,
                            whisperController: whisperController,
                            whisperSovereign: whisperSovereign,
                            eventWhisper: worldEventWhisperToday
                        )
                        handlePendingRadioWidgetCommand()
                        handlePendingCompassWidgetCommand()
                        handlePendingWidgetDeepLink()
                        handlePendingSiriCommand()
                    }
                    return
                }
                writeWidgetSnapshot()
                resetTransientWorkStateForBackgrounding()
            }
        )
    }

    private var chromeRoot: AnyView {
        AnyView(
            chromeBrainRoot
            .onReceive(NotificationCenter.default.publisher(for: .promptWhisperKept)) { _ in
                Task {
                    await reloadDaysFromArchive()
                    statusMessage = "A prompt whisper is tucked into Today's Margins."
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .bookMemoryPressure)) { _ in
                AppMemoryLedger.record("memory-warning")
                if localBrainTelemetry.isWorking {
                    radioManager.pauseForMemoryPressureDuringGeneration()
                }
                #if NATIVE_LOCAL_BRAIN && canImport(MLXLLM) && canImport(MLXVLM) && canImport(MLXLMCommon) && canImport(MLXLMTokenizers) && canImport(MLX) && !targetEnvironment(simulator)
                Task { await LocalBrainModelCache.shared.unload() }
                #endif
            }
            .onChange(of: didHydrateLaunchState) { _, _ in
                if !isOpeningMovieVisible && !isLaunchDeskCurating {
                    rebuildSurfaceCache()
                }
                refreshBookwideMarginaliaAchievements(announce: didHydrateLaunchState)
                handlePendingRadioWidgetCommand()
                handlePendingCompassWidgetCommand()
                handlePendingWidgetDeepLink()
                handlePendingSiriCommand()
                writeWidgetSnapshot()
            }
            .onChange(of: isOpeningMovieVisible) { _, visible in
                guard !visible, didHydrateLaunchState, !isLaunchDeskCurating else { return }
                rebuildSurfaceCache()
            }
            .onChange(of: bookwideMarginaliaAchievementSignature) { _, _ in
                refreshBookwideMarginaliaAchievements(
                    announce: didHydrateLaunchState && !isOpeningMovieVisible
                )
            }
            .onChange(of: surfacedPages) { _, pages in
                // Keep a tiny, already-curated desk available for the next
                // launch. Encoding and defaults I/O stay off the main actor.
                let snapshot = Array(pages.prefix(3))
                let dayID = today.id
                Task.detached(priority: .utility) {
                    LaunchDeskSnapshotStore.save(snapshot, dayID: dayID)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .reEnchantedWidgetDeepLinkReceived)) { _ in
                handlePendingWidgetDeepLink()
                handlePendingSiriCommand()
            }
            .onChange(of: surfaceRefreshDate) { _, _ in
                if suppressNextSurfaceRefresh {
                    suppressNextSurfaceRefresh = false
                    return
                }
                rebuildSurfaceCache()
                writeWidgetSnapshot()
            }
            .onChange(of: isTodaysMarginsExpanded) { _, expanded in
                if expanded { tutorTouch("todays-margins") }
            }
            .onChange(of: isReturnedStacksExpanded) { _, expanded in
                if expanded { tutorTouch("returned-stacks") }
            }
            .onChange(of: isQuietMechanicsExpanded) { _, expanded in
                if expanded { tutorTouch("colophon") }
            }
        )
    }

    private var selectedSurfacePresentation: Binding<SurfacePage?> {
        Binding(
            get: { usesPadWorkspace ? nil : selectedSurface },
            set: { selectedSurface = $0 }
        )
    }

    private var stacksSheetPresentation: Binding<Bool> {
        Binding(
            get: { !usesPadWorkspace && isStacksSearchPresented },
            set: { isStacksSearchPresented = $0 }
        )
    }

    private var almanacSheetPresentation: Binding<Bool> {
        Binding(
            get: { !usesPadWorkspace && isAlmanacPresented },
            set: { isAlmanacPresented = $0 }
        )
    }

    private var presentationReadingRoot: AnyView {
        AnyView(
            chromeRoot
            .sheet(item: $pactVerdictSurface) { surface in
                PactVerdictSheet(surface: surface) { winner, loser in
                    rulePactVerdict(
                        winnerTalismanID: winner,
                        loserTalismanID: loser,
                        territoryID: surface.payload.metadata["territoryID"] ?? "",
                        pageID: surface.payload.metadata["pageID"] ?? ""
                    )
                    dismissSurface(surface)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $pactErrandSurface) { surface in
                PactErrandSheet(surface: surface) { report in
                    payPactErrand(errandID: surface.payload.metadata["errandID"] ?? "", report: report)
                    dismissSurface(surface)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: selectedSurfacePresentation) { surface in
                captureSheet(for: surface)
            }
            .sheet(item: $weeklyIssueReader) { reader in
                WeeklyIssueReaderSheet(reader: reader, brainReady: LocalModelManager.report().isReady) {
                    // Re-bind: drop the cached copy and rebuild from scratch,
                    // asking the Book to rewrite it if the local brain is ready.
                    // Give the reader sheet time to leave before the progress
                    // overlay and replacement reader arrive.
                    cachedWeeklyIssueReader = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                        exportWeeklyIssuePDF(forceRebind: true)
                    }
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $monthlyEditionReader) { reader in
                MonthlyEditionReaderSheet(reader: reader)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        )
    }

    private var presentationInputRoot: AnyView {
        AnyView(
            presentationReadingRoot
            .confirmationDialog(
                "Location",
                isPresented: $isLocationSealChoicesPresented,
                titleVisibility: .visible
            ) {
                Button("Weather Page") {
                    Task { await pressWeatherSeal() }
                }
                Button("Nearby Anchor") {
                    Task { await pressAnchorSeal() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Choose what the Location seal should read.")
            }
            .confirmationDialog(
                "Input",
                isPresented: $isInputChoicesPresented,
                titleVisibility: .visible
            ) {
                Button("Photo") {
                    Task { await pressGlassSeal() }
                }
                Button("Text") {
                    plainPageAutoRecord = false
                    isPlainPagePresented = true
                }
                Button("Audio") {
                    plainPageAutoRecord = true
                    isPlainPagePresented = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Choose what the Input seal should hand to the Book.")
            }
            .sheet(isPresented: $isPlainPagePresented) {
                PlainPageSheet(autoRecord: plainPageAutoRecord) { text, media in
                    keepPlainPage(text: text, media: media)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $isSourceSettingsPresented) {
                SourceSettingsSheet(
                    sources: BookPageSourceRegistry.sources,
                    preferences: decodedSourcePreferenceLedger(),
                    publicMarginsIncomingOptIn: $publicMarginsIncomingOptIn,
                    publicMarginsOutgoingOptIn: $publicMarginsOutgoingOptIn
                ) { sourceID, isEnabled in
                    setSourceEnabled(sourceID: sourceID, isEnabled: isEnabled)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .fileImporter(
                isPresented: $isSaveImporterPresented,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                if case let .success(urls) = result, let url = urls.first {
                    importSaveFile(from: url)
                }
            }
        )
    }

    private var presentationMakingRoot: AnyView {
        AnyView(
            presentationInputRoot
            .sheet(isPresented: $isBookShopPresented) { bookShopSheet }
            .fullScreenCover(isPresented: $isPagewrightPresented) {
                PagewrightSheet(
                    keptPages: pagewrightCandidatePages,
                    bookwideAchievementContext: bookwideMarginaliaAchievementContext,
                    initialPageIDs: pagewrightInitialPageIDs,
                    initialPDFURL: preparedPagewrightPDFURL,
                    initialPNGURL: preparedPagewrightPNGURL,
                    onExportPDF: { draft in exportPagewrightPDF(draft) },
                    onExportPNG: { draft in exportPagewrightPNG(draft) },
                    onKeep: { draft, pdfURL, pngURL in keepPagewrightPage(draft, pdfURL: pdfURL, pngURL: pngURL) }
                )
            }
            .sheet(isPresented: $showStandingOrderPaywall, onDismiss: { firePendingFirstEditionCelebration() }) {
                StandingOrderSheet(
                    heroArtifact: standingOrderHeroArtifact,
                    onSubscribed: { packID in unlockPack(packID) },
                    onDismiss: { showStandingOrderPaywall = false }
                )
            }
            .sheet(isPresented: $isShowingKeepArtifactCard) {
                if let url = keepArtifactCardURL, let image = UIImage(contentsOfFile: url.path) {
                    VStack(spacing: 16) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .padding(.horizontal, 20)
                        ShareLink(item: url) {
                            Label("Share the card", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, 24)
                    .presentationDetents([.medium, .large])
                }
            }
            .sheet(isPresented: $isBraidingTablePresented) {
                BraidingTableSheet(
                    fragmentCount: today.capturedPages.count,
                    braidCount: today.pages.filter { $0.type == .bookOfYou }.count,
                    onBraidNew: { Task { await braidToday(openWhenComplete: true) } },
                    onReBraidLast: { Task { await reBraidLast() } },
                    onOpenLatest: { if let braid = today.bookOfYou { openKeptPage(braid) } }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        )
    }

    private var presentationRoot: AnyView {
        AnyView(
            presentationMakingRoot
            .sheet(isPresented: $isPactMapPresented) { pactMapSheet }
            .sheet(isPresented: $isPeopleOfTheBookPresented) { peopleOfTheBookSheet }
            .sheet(isPresented: stacksSheetPresentation) {
                SearchTheStacksSheet(
                    dataset: stacksSearchDataset,
                    isLocalBrainWorking: localBrainTelemetry.isWorking,
                    localBrainWorkLabel: localBrainTelemetry.currentLabel,
                    localBrainWorkStartedAt: localBrainTelemetry.startedAt,
                    onOpen: { result in
                        isStacksSearchPresented = false
                        openSearchResult(result)
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: almanacSheetPresentation) {
                AlmanacSheet(days: days) { page in
                    isAlmanacPresented = false
                    openKeptPage(page)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $isCustomCastSheetPresented) {
                CustomCastMemberSheet { draft in
                    saveCustomCastMember(draft)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $isConnectionsPresented) {
                BookConnectionsSheet(
                    days: days,
                    inputs: sourceInputs
                ) { page in
                    isConnectionsPresented = false
                    openKeptPage(page)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .toolbar { mainToolbar }
        )
        }

    private var bookShopSheet: some View {
        let fae = vault.data.fae ?? FaePlayerState()
        return BookShopSheet(
            stall: currentStall ?? buildGoblinStall(),
            fae: fae,
            attention: fae.attention,
            belief: beliefScore,
            goblinWarmth: fae.warmth(for: .goblin),
            onBuyWare: { buyMarketWare($0) },
            onUnlock: { unlockPack($0) },
            onRevoke: { revokePack($0) },
            onOpenArchive: { activateWorldEventArchive(packID: $0) },
            onHaggle: { haggleWare($0) },
            onClerkBanter: { await goblinClerkBanter() },
            onOpenBargain: { openFaeBargainPage($0) },
            onMarkNextMarket: { Task { await addNextMarketToCalendar() } },
            binderyWeeklyIssueLabel: currentWeeklyIssue.map { "Issue No. \($0.number) \u{00B7} \($0.dateRange)" } ?? "",
            binderyWeeklyIssuePageCount: currentWeeklyIssue?.keptCount ?? 0,
            preparedWeeklyIssueCardURL: preparedWeeklyIssueCardURL,
            preparedWeeklyIssuePDFURL: preparedWeeklyIssuePDFURL,
            binderyMonthLabel: bindableEditionMonths.first?.label ?? "",
            binderyMonthPageCount: bindableEditionMonths.first?.pageCount ?? 0,
            preparedMonthlyEditionURL: preparedMonthlyEditionURL,
            preparedAnnualEditionURL: preparedAnnualEditionURL,
            binderyNote: colophonBindingNote,
            preparedPrintInteriorURL: preparedPrintInteriorURL,
            preparedPrintCoverURL: preparedPrintCoverURL,
            printPreviewEdition: printPreviewEdition,
            onBindWeeklyIssue: { exportWeeklyIssuePDF() },
            onBindMonth: { exportMonthlyEdition() },
            onBindMonthGemma: { exportMonthlyEdition(useGemmaClosing: true) },
            onBindYear: { exportAnnualEdition() },
            onMakePrintReady: { exportPrintReadyEdition(spec: $0) }
        )
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var pactMapSheet: some View {
        PactMapSheet(
            pactWar: vault.data.pactWar ?? PactWarState(),
            boundTalismanID: boundTalismanID,
            onPressClaim: { territoryID in
                if let talismanID = boundTalismanID {
                    pressPactClaim(talismanID: talismanID, territoryID: territoryID)
                }
            },
            pendingVerdict: pendingPactVerdictSurface,
            onRuleVerdict: { winner, loser in
                guard let verdict = pendingPactVerdictSurface else { return }
                rulePactVerdict(
                    winnerTalismanID: winner,
                    loserTalismanID: loser,
                    territoryID: verdict.payload.metadata["territoryID"] ?? "",
                    pageID: verdict.payload.metadata["pageID"] ?? ""
                )
                dismissSurface(verdict)
            }
        )
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var peopleOfTheBookSheet: some View {
        PeopleOfTheBookSheet(
            ledger: vault.data.people ?? PeopleLedger(),
            castMemberIDs: Set(customCastMembers.map(\.id)),
            days: days + [today],
            now: Date(),
            onWriteIntoStory: { slug in statusMessage = writeThreadIntoStory(slug: slug) },
            onUpdateWords: { slug, words in updatePersonWords(slug: slug, words: words) },
            onUpdateRelationship: { slug, profile in updatePersonRelationship(slug: slug, profile: profile) },
            onRest: { slug in restPersonThread(slug: slug) },
            onWake: { slug in wakePersonThread(slug: slug) },
            onIntroduce: { name, words, contactIdentifier in
                statusMessage = introducePerson(name: name, words: words, contactIdentifier: contactIdentifier)
            },
            onWakeDeclinedName: { slug in wakeDeclinedName(slug: slug) }
        )
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    @ToolbarContentBuilder
    private var mainToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if !isStoryOnboardingActive && !usesPadWorkspace {
                HStack(spacing: 14) {
                    Button {
                        presentStacks()
                    } label: {
                        Image(systemName: "sparkle.magnifyingglass")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(BookPalette.lampGold)
                    }
                    .accessibilityLabel("Search the Stacks")

                    Button {
                        presentAlmanac()
                    } label: {
                        Image(systemName: "calendar.badge.clock")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(BookPalette.lampGold)
                    }
                    .accessibilityLabel("The Almanac")
                }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            if shouldShowGlowPill {
                Button {
                    toggleGlowMenu()
                } label: {
                    BeliefScoreBadge(score: beliefScore, isPaused: shouldPauseAmbientMotion)
                        .overlay {
                            GlowPillRevealAura(isActive: isGlowPillRevealing && !shouldPauseAmbientMotion)
                        }
                        .scaleEffect(isGlowPillRevealing && !reduceMotion && !shouldPauseAmbientMotion ? 1.08 : 1.0)
                }
                .buttonStyle(.bookPress())
                .accessibilityLabel(isGlowMenuPresented ? "Close Glow menu" : "Open Glow menu")
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.5)),
                    removal: .opacity
                ))
            }
        }
    }

    private func presentStacks() {
        BookFeedback.play(.openPage)
        tutorTouch("search-stacks")
        if usesPadWorkspace {
            selectPadDestination(.stacks)
            padSearchFocusRequest &+= 1
        } else {
            isStacksSearchPresented = true
        }
    }

    private func presentAlmanac() {
        BookFeedback.play(.openPage)
        if usesPadWorkspace {
            selectPadDestination(.almanac)
        } else {
            isAlmanacPresented = true
        }
    }

    private func presentPlainPage() {
        BookFeedback.play(.openPage)
        plainPageAutoRecord = false
        isPlainPagePresented = true
    }

    @MainActor
    var shouldShowGlowPill: Bool {
        if isStoryOnboardingActive {
            return didRevealGlowPillInCurrentOnboarding
        }

        return didCompleteStoryOnboarding || didRevealGlowPill
    }

    @MainActor
    var isStoryOnboardingActive: Bool {
        !didCompleteStoryOnboarding && !isOpeningMovieVisible
    }

    @MainActor
    var canOpenGlowMenu: Bool {
        // The menu opens once onboarding is done and the Book Brain is ready.
        // It is deliberately NOT gated on a regular page currently being
        // surfaced — a quiet desk must never lock the reader out of the menu.
        didCompleteStoryOnboarding
            && modelReport.state == .ready
    }

    @MainActor
    func revealGlowPillIfNeeded() {
        guard !didRevealGlowPillInCurrentOnboarding else { return }

        BookFeedback.play(.braidStart)
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.55, dampingFraction: 0.62)) {
            didRevealGlowPillInCurrentOnboarding = true
            didRevealGlowPill = true
            isGlowPillRevealing = true
        }

        guard !reduceMotion else {
            isGlowPillRevealing = false
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            withAnimation(.easeOut(duration: 0.35)) {
                isGlowPillRevealing = false
            }
        }
    }

    @MainActor
    struct LaunchHydrationPayload: @unchecked Sendable {
        var insideCoverState: InsideCoverState
        var days: [BookDay]
        var resurfacedPages: [BookPage]
        var selfFacts: [SelfFact]
        var narrativeEvents: [NarrativeEvent]
        var entityMemories: [NarrativeEntityMemory]
        var narrativeSnapshot: NarrativeSourceSnapshot
        var customCastMembers: [CustomCastMember]
        var facultyEntries: [FacultyEntry]
        var modelReport: LocalModelReport
    }

    @MainActor
    struct LaunchDecorationPayload: @unchecked Sendable {
        var storeReport: BookStore.Report
        var databaseReport: BookDatabase.Report
        var returnedStackCards: [ReturnedStackCard]
    }

    func hydrateLaunchStateIfNeeded() async {
        guard !didHydrateLaunchState else { return }

        // Only inputs that can change which Pages rise belong on this critical
        // path. Reports, Returned Stacks decoration, GPS, calendars, and daily
        // world chores stay deferred until a truthful desk is interactive.
        // A detached database handle keeps every call here genuinely
        // nonisolated — routing through the @MainActor BookDatabase statics
        // would hop this work right back onto the main thread.
        AppMemoryLedger.record("launch-critical-hydration-start")
        let launchBeliefScore = beliefScore
        let payload = await Task.detached(priority: .utility) { () -> LaunchHydrationPayload in
            let database = BookDatabase.detachedDatabase()
            let initialDays = database.loadDays(migratingFrom: BookStore.loadDays())
            let resurfacingCandidates = (try? database.resurfacingCandidates(before: Date(), limit: 64)) ?? []
            let events = (try? database.narrativeEvents(limit: 160)) ?? []
            let memories = NarrativeEntityMemoryConsolidator.consolidate(
                (try? database.entityMemories(entityIDs: nil, limit: 240)) ?? []
            )
            return LaunchHydrationPayload(
                insideCoverState: InsideCoverStore.load(),
                days: initialDays,
                resurfacedPages: resurfacingCandidates,
                selfFacts: (try? database.selfFacts()) ?? [],
                narrativeEvents: events,
                entityMemories: memories,
                narrativeSnapshot: NarrativeSourceSnapshotBuilder.snapshot(
                    from: events,
                    memories: memories,
                    beliefWeight: launchBeliefScore
                ),
                customCastMembers: (try? database.customCastMembers(limit: 200)) ?? [],
                facultyEntries: (try? database.facultyEntries(kind: nil, dayIDs: nil, since: nil, limit: 160)) ?? [],
                modelReport: LocalModelManager.report()
            )
        }.value

        guard !didHydrateLaunchState else { return }
        surfaceRefreshDate = Date()
        insideCoverState = payload.insideCoverState
        days = payload.days
        resurfacedPages = payload.resurfacedPages
        selfFacts = payload.selfFacts
        PersonalNameGuard.update(from: payload.selfFacts)
        narrativeEvents = payload.narrativeEvents
        entityMemories = payload.entityMemories
        cachedNarrativeSourceSnapshot = payload.narrativeSnapshot
        customCastMembers = payload.customCastMembers
        facultyEntries = payload.facultyEntries
        modelReport = payload.modelReport
        didHydrateLaunchState = true
        AppMemoryLedger.record("launch-critical-hydration-finished")
        // The daily ticks and the whole-archive continuity projection are heavy
        // and only feed the home desk. The closed cover first reaches its cheap,
        // opaque hold; initial curation then runs off-main and the desk mounts
        // underneath it. Daily ticks still wait until after the reveal.
    }

    @MainActor
    func hydrateLaunchDecorationsIfNeeded(days launchDays: [BookDay]) async {
        guard !didHydrateLaunchDecorations else { return }
        let payload = await Task.detached(priority: .utility) { () -> LaunchDecorationPayload in
            let database = BookDatabase.detachedDatabase()
            return LaunchDecorationPayload(
                storeReport: BookStore.report(for: launchDays),
                databaseReport: database.report(for: launchDays),
                returnedStackCards: (try? database.returnedStacksCards(
                    from: launchDays,
                    now: Date(),
                    limit: 3
                )) ?? []
            )
        }.value
        guard !didHydrateLaunchDecorations else { return }
        storeReport = payload.storeReport
        databaseReport = payload.databaseReport
        returnedStackCards = payload.returnedStackCards
        didHydrateLaunchDecorations = true
    }

    @MainActor
    func waitForOpeningHold() async {
        while !didReachOpeningHold && !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    /// Mounts a living, noninteractive desk ritual while the first real
    /// curation runs. Cached cards remain useful as a private diagnostic
    /// snapshot, but are never made tappable during launch.
    @MainActor
    func prepareLaunchDeskIfNeeded() {
        guard isOpeningMovieVisible,
              didReachOpeningHold,
              !didPrepareLaunchDesk else { return }

        if !didSelectLaunchDeskRitual {
            launchDeskRitualVariant = LaunchDeskRitualVariant.next(
                avoidingRawValue: launchDeskRitualLastVariant
            )
            launchDeskRitualLastVariant = launchDeskRitualVariant.rawValue
            didSelectLaunchDeskRitual = true
        }

        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            surfacedPages = []
            curatedSurfaceBench = []
            didPrepareLaunchDesk = true
            isLaunchDeskCurating = true
        }
    }

    /// Publishes one cheap but genuine curated desk, then lets the enriched
    /// continuity pass deepen the candidate bench without evicting anything the
    /// reader can already see.
    @MainActor
    func curateLaunchDeskIfNeeded() async {
        guard isLaunchDeskCurating else { return }
        await hydrateLaunchStateIfNeeded()
        guard !Task.isCancelled, didHydrateLaunchState else { return }
        refreshBookInterior(now: surfaceRefreshDate)

        surfaceBuildToken &+= 1
        let token = surfaceBuildToken
        let request = makeSurfaceBuildRequest(now: surfaceRefreshDate, surfaceLimit: 12)
        AppMemoryLedger.record("launch-quick-curation-start")
        let stage = await ContentView.computeQuickSurfaceBuild(
            request,
            priority: .userInitiated
        )
        guard !Task.isCancelled, token == surfaceBuildToken else { return }

        applySurfaceBuildMetadata(stage.result)
        curatedSurfaceBench = stage.result.surfaces
        recordServedSurfaces(Array(stage.result.surfaces.prefix(3)))
        withAnimation(.easeOut(duration: 0.32)) {
            surfacedPages = Array(stage.result.surfaces.prefix(3))
            isLaunchDeskCurating = false
        }
        AppMemoryLedger.record("launch-quick-curation-published")

        let launchDays = days
        Task { @MainActor in
            await hydrateLaunchDecorationsIfNeeded(days: launchDays)
        }

        Task { @MainActor in
            let result = await ContentView.computeEnrichedSurfaceBuild(
                request,
                foundation: stage.foundation
            )
            guard token == surfaceBuildToken else { return }
            applySurfaceBuildMetadata(result)
            curatedSurfaceBench = result.surfaces
            surfacedPages = BookCurator.stabilizedDeskOrder(
                previous: surfacedPages,
                rebuilt: result.surfaces
            )
            recordServedSurfaces(surfacedPages)
            AppMemoryLedger.record("launch-enriched-curation-published")
        }
    }

    @MainActor
    private func applySurfaceBuildMetadata(_ result: SurfaceBuildResult) {
        if result.didRecomputeDigest {
            continuityCacheSignature = result.signature
            cachedContinuityDigest = result.digest
            cachedMotifClusters = result.clusters
        }
        cachedNarrativeSourceSnapshot = result.narrativeSnapshot
        cachedQuietDayCount = result.quietDayCount
        cachedBleedIssueNumber = result.bleedIssueNumber
    }

    /// `onAppear` precedes the first committed frame. Yield once, allow a short
    /// layout settle, then arm the final page turn. Any mount hitch therefore
    /// lands on a deliberately still hold frame rather than in the reveal.
    @MainActor
    func settleLaunchDeskAfterMountIfNeeded() async {
        guard isOpeningMovieVisible,
              didPrepareLaunchDesk,
              !isLaunchPresentationReady,
              !isSettlingLaunchDesk else { return }

        isSettlingLaunchDesk = true
        defer { isSettlingLaunchDesk = false }

        await Task.yield()
        try? await Task.sleep(for: .milliseconds(100))
        await Task.yield()

        guard !Task.isCancelled,
              isOpeningMovieVisible,
              didPrepareLaunchDesk else { return }
        isLaunchPresentationReady = true
    }

    @MainActor
    func finishOpeningMovie() {
        guard isOpeningMovieVisible, isLaunchPresentationReady else { return }

        withAnimation(.easeInOut(duration: 0.28)) {
            isOpeningMovieVisible = false
        }

        // Greeting composition and first-use feedback can both initialize work
        // on the main actor. Keep them comfortably beyond the reveal instead of
        // making the last page-turn frame pay for them.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(360))
            guard !isOpeningMovieVisible else { return }
            presentReturningGreetingIfNeeded()

            try? await Task.sleep(for: .milliseconds(160))
            isLaunchAmbientMotionPaused = false

            try? await Task.sleep(for: .milliseconds(200))
            guard !isOpeningMovieVisible else { return }
            BookFeedback.play(.openPage)
        }
    }

    @MainActor
    func waitForLaunchStateHydration() async {
        while !didHydrateLaunchState && !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    @MainActor
    struct ArchiveReloadPayload: @unchecked Sendable {
        var days: [BookDay]
        var storeReport: BookStore.Report
        var databaseReport: BookDatabase.Report
    }

    @MainActor
    func reloadDaysFromArchive() async {
        // Like hydrateLaunchStateIfNeeded, the whole-archive load runs off the
        // main actor so foregrounding never stalls the desk.
        let payload = await Task.detached(priority: .userInitiated) { () -> ArchiveReloadPayload in
            let database = BookDatabase.detachedDatabase()
            let loadedDays = database.loadDays(migratingFrom: BookStore.loadDays())
            return ArchiveReloadPayload(
                days: loadedDays,
                storeReport: BookStore.report(for: loadedDays),
                databaseReport: database.report(for: loadedDays)
            )
        }.value
        days = payload.days
        storeReport = payload.storeReport
        databaseReport = payload.databaseReport
        refreshResurfacedPages()
        surfaceRefreshDate = Date()
    }

    @MainActor
    func waitForOpeningMovieToFinish() async {
        while isOpeningMovieVisible && !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    @MainActor
    func runPostLaunchTasksIfNeeded() async {
        guard !didRunPostLaunchTasks else { return }
        await waitForLaunchStateHydration()
        // The opening book animates on the main actor, so any launch chore
        // running underneath it shows up as a stalled frame. Hold every
        // noncritical follow-up until the prepared desk has been revealed.
        await waitForOpeningMovieToFinish()
        guard !Task.isCancelled, !didRunPostLaunchTasks else { return }
        // Leave the final fade and returning greeting a clean runway before the
        // remaining launch chores begin.
        try? await Task.sleep(for: .milliseconds(900))

        didRunPostLaunchTasks = true
        AppMemoryLedger.record("app-launch-idle")
        // Deferred out of hydration so they never run under the opening movie.
        runBeliefEconomyDailyTick()
        runCastAgencyTurnIfNeeded()
        tendBookJump()
        restoreRadioIfNeeded()
        if generation.preparedStoryPageSurface == nil,
           let overnight = OvernightScribe.adoptDraft() {
            generation.preparedStoryPageSurface = overnight
            surfaceRefreshDate = Date()
            statusMessage = "The Book wrote a Story Page while you slept."
        }
        let overnightConnections = OvernightScribe.adoptConnectionDrafts()
        if !overnightConnections.isEmpty {
            let existing = vault.data.overnightConnectionDrafts ?? []
            let incomingKeys = Set(overnightConnections.map(\.observationKey))
            vault.data.overnightConnectionDrafts = Array(
                (existing.filter { !incomingKeys.contains($0.observationKey) } + overnightConnections)
                    .sorted { $0.generatedAt < $1.generatedAt }
                    .suffix(40)
            )
            vault.save()
            surfaceRefreshDate = Date()
        }
        loadAnchorLedger()
        if didCompleteStoryOnboarding {
            BookWhispers.refreshSchedule(enabled: bookWhispersEnabled, cadence: bookWhisperCadence, electives: electives, whisperController: whisperController, festivalWhisper: festivalWhisperToday, bookInterior: sourceInputs.bookInterior)
            BookWhispers.refreshPromptWhispers(enabled: promptWhispersEnabled, cadence: bookWhisperCadence, day: today, inputs: sourceInputs, whisperController: whisperController, whisperSovereign: whisperSovereign, eventWhisper: worldEventWhisperToday)
            BookWhispers.refreshAnchorDoorbells(enabled: promptWhispersEnabled, anchors: anchorLedger)
        }
        if bookCalendarEnabled {
            calendarEvents = await CalendarDoorway.upcomingEvents()
            surfaceRefreshDate = Date()
        }
        if didCompleteStoryOnboarding {
            BookWhispers.refreshPersonCharges(
                enabled: promptWhispersEnabled,
                ledger: vault.data.people ?? PeopleLedger(),
                events: calendarEvents
            )
        }
        PackEntitlements.ownedPackIDs = Set(vault.data.ownedPacks ?? [])
        tendArc()
        tendAlmanac()
        tendFae()
        tendPact()
        tendConstellations()
        maybeRequestFirstDoorAppReview()
        nearbyPlaces = LocalPlacesScout.cachedPlaces()
        await runLaunchSmokeTestIfRequested()

        // Location is the heaviest launch chore (GPS wake + map searches) and
        // the reader never needs it in the opening moments — defer it to a
        // genuine idle gap so it never competes with launch or an active braid.
        scheduleIdleLocationRefreshIfNeeded()
    }

    @MainActor
    func scheduleIdleLocationRefreshIfNeeded() {
        guard didGrantLocationContextAccess, !didRunIdleLocationRefresh else { return }
        Task { await runIdleLocationRefreshIfNeeded() }
    }

    /// The Book only reaches for GPS once the desk is quiet — after the opening
    /// movie, after onboarding, and while nothing is braiding or reading. This
    /// keeps the location ping (and its map-search follow-up) off the launch path.
    @MainActor
    func runIdleLocationRefreshIfNeeded() async {
        guard didGrantLocationContextAccess, !didRunIdleLocationRefresh else { return }
        await waitForIdleMoment()
        guard !Task.isCancelled,
              didGrantLocationContextAccess,
              !didRunIdleLocationRefresh else { return }
        didRunIdleLocationRefresh = true

        nearbyPlaces = await LocalPlacesScout.refreshIfNeeded()
        await refreshAnchorProximity(isUserInitiated: false)
    }

    /// Holds until the app is genuinely idle: a short settle, then a wait for a
    /// frame with no movie, no onboarding, and nothing braiding/reading/installing.
    @MainActor
    func waitForIdleMoment() async {
        try? await Task.sleep(for: .seconds(2))
        while !Task.isCancelled && !isAppIdleForBackgroundWork {
            try? await Task.sleep(for: .milliseconds(400))
        }
    }

    @MainActor
    var isAppIdleForBackgroundWork: Bool {
        scenePhase == .active
            && !isOpeningMovieVisible
            && didCompleteStoryOnboarding
            && !generation.isBraiding
            && !localBrainTelemetry.isReading
            && !isInstallingModel
    }

    @MainActor
    func maybeRequestFirstDoorAppReview() {
        guard didCompleteStoryOnboarding, !didRequestFirstDoorAppReview else { return }
        let daysWithPages = days.filter { !$0.pages.isEmpty }.count
        let keptPages = days.reduce(0) { $0 + $1.pages.count }
        guard daysWithPages >= 2, keptPages >= 5 else { return }
        didRequestFirstDoorAppReview = true
        #if canImport(StoreKit)
        requestReview()
        #endif
    }

    /// Snapshot of the inputs the off-main surface build needs, captured on the
    /// main actor. Shared by the full rebuild and the dismissal replacement.
    @MainActor
    func makeSurfaceBuildRequest(now: Date, surfaceLimit: Int = 3) -> SurfaceBuildRequest {
        let entityBelief = entityBeliefLedger
        let pageBelief = pageBeliefLedger
        let signature = continuityCacheSignatureString(
            entityBeliefCount: entityBelief.count,
            pageBeliefCount: pageBelief.count
        )
        return SurfaceBuildRequest(
            today: today,
            inputs: sourceInputs,
            preferences: CuratorSurfacePreferences(
                dismissedSurfaceIDs: dismissedSurfaceIDs(for: today.id, now: now),
                disabledSourceIDs: disabledSourceIDs(),
                pageBeliefProfiles: Dictionary(
                    uniqueKeysWithValues: pageBeliefProfiles.map { ($0.sourceID, $0) }
                ),
                readerLearning: vault.data.readerLearning ?? ReaderLearningModel()
            ),
            now: now,
            needsDigest: signature != continuityCacheSignature,
            signature: signature,
            cachedDigest: cachedContinuityDigest,
            cachedClusters: cachedMotifClusters,
            days: days,
            events: narrativeEvents,
            entityMemories: entityMemories,
            entityBelief: entityBelief,
            pageBelief: pageBelief,
            hasActiveQuietingGift: vault.data.fae?.activeGifts.contains { $0.effect == .quieting } == true,
            surfaceLimit: surfaceLimit
        )
    }

    @MainActor
    func rebuildSurfaceCache() {
        guard didHydrateLaunchState else {
            surfacedPages = []
            return
        }
        // The launch coordinator owns the first build under the opaque opening
        // hold. Ordinary refreshes stay out until the movie has cleared.
        guard !isOpeningMovieVisible else { return }
        guard !isLaunchDeskCurating else { return }
        guard !isRetiringKeptSurface else {
            return
        }
        // A retirement build owns the desk until it can replace every hidden
        // outgoing slot atomically. Letting an ordinary rebuild publish while a
        // slot is pending can change the outgoing card's identity and strand an
        // invisible placeholder.
        guard pendingSurfaceRetirements.isEmpty else { return }

        refreshBookInterior(now: surfaceRefreshDate)

        // Snapshot the inputs on the main actor (cheap value copies), then run the
        // whole-archive continuity projection + curation OFF the main thread so the
        // UI never freezes. A token supersedes any in-flight build, and results are
        // applied back on the main actor. The signature gate means an unchanged
        // archive reuses the cached digest and only re-runs the (lighter) curator.
        surfaceBuildToken &+= 1
        let token = surfaceBuildToken
        let now = surfaceRefreshDate
        let request = makeSurfaceBuildRequest(now: now, surfaceLimit: 12)

        Task {
            let result = await ContentView.computeSurfaceBuild(request)
            guard token == surfaceBuildToken else { return }
            applySurfaceBuildMetadata(result)
            curatedSurfaceBench = result.surfaces
            let previousTopID = surfacedPages.first?.id
            // Stabilize the desk: shown cards stay put no matter what bumped
            // surfaceRefreshDate — only the reader's own keep/swipe removes a
            // card (replaceDismissedSurfaceInCache refills that one slot). The
            // rebuild here only refreshes a shown card's content in place and
            // fills empty slots; see BookCurator.stabilizedDeskOrder.
            surfacedPages = BookCurator.stabilizedDeskOrder(
                previous: surfacedPages,
                rebuilt: result.surfaces
            )
            if let top = surfacedPages.first, previousTopID != nil, top.id != previousTopID {
                BookFeedback.pageRising(rarity: top.score)
            }
            recordServedSurfaces(surfacedPages)
        }
    }

    /// Pulling from the top is an explicit request to turn over the whole desk,
    /// so it deliberately bypasses the ordinary stability contract that keeps
    /// cards fixed during background refreshes. The new trio is computed off
    /// the main actor and committed in one publication.
    @MainActor
    private func refreshAllSurfaceCards() async {
        guard didHydrateLaunchState,
              !isOpeningMovieVisible,
              !isLaunchDeskCurating,
              !isRetiringKeptSurface,
              pendingSurfaceRetirements.isEmpty,
              !isRefreshingSurfaceDesk else { return }

        isRefreshingSurfaceDesk = true
        defer { isRefreshingSurfaceDesk = false }

        surfaceBuildToken &+= 1
        let token = surfaceBuildToken
        let now = Date()
        let request = makeSurfaceBuildRequest(now: now, surfaceLimit: 18)
        let existingBench = curatedSurfaceBench
        let result = await ContentView.computeSurfaceBuild(
            request,
            performsHeavyEnrichment: false,
            priority: .userInitiated
        )
        guard !Task.isCancelled, token == surfaceBuildToken else { return }

        applySurfaceBuildMetadata(result)
        let candidates = (result.surfaces + existingBench).reduce(into: [SurfacePage]()) { pages, candidate in
            guard !pages.contains(where: { $0.id == candidate.id }) else { return }
            pages.append(candidate)
        }
        let refreshed = BookCurator.refreshedDeskOrder(
            previous: surfacedPages,
            rebuilt: candidates
        )
        let previousIDs = Set(surfacedPages.map(\.id))
        let arrivingIDs = Set(refreshed.map(\.id)).subtracting(previousIDs)

        curatedSurfaceBench = result.surfaces.filter { candidate in
            !refreshed.contains(where: { $0.id == candidate.id })
        }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.28)) {
            surfacedPages = refreshed
            arrivingSurfaceIDs.formUnion(arrivingIDs)
        }
        suppressNextSurfaceRefresh = true
        surfaceRefreshDate = now
        recordServedSurfaces(refreshed, now: now)
        if !arrivingIDs.isEmpty {
            BookFeedback.pageRising(rarity: refreshed.first?.score ?? 0)
        }
    }

    /// Immutable snapshot handed to the detached surface build. Every field is a
    /// value type captured on the main actor; `@unchecked Sendable` matches the
    /// existing LaunchHydrationPayload pattern (read-only across the boundary).
    struct SurfaceBuildRequest: @unchecked Sendable {
        var today: BookDay
        var inputs: BookSourceInputs
        var preferences: CuratorSurfacePreferences
        var now: Date
        var needsDigest: Bool
        var signature: String
        var cachedDigest: LiteraryContinuityDigest
        var cachedClusters: [BookMotifCluster]
        var days: [BookDay]
        var events: [NarrativeEvent]
        var entityMemories: [NarrativeEntityMemory]
        var entityBelief: [String: Int]
        var pageBelief: [String: Int]
        var hasActiveQuietingGift: Bool
        var surfaceLimit: Int
    }

    struct SurfaceBuildResult: @unchecked Sendable {
        var digest: LiteraryContinuityDigest
        var clusters: [BookMotifCluster]
        var surfaces: [SurfacePage]
        var narrativeSnapshot: NarrativeSourceSnapshot
        var quietDayCount: Int
        var bleedIssueNumber: Int
        var didRecomputeDigest: Bool
        var signature: String
    }

    struct SurfaceBuildFoundation: @unchecked Sendable {
        var inputs: BookSourceInputs
        var narrativeSnapshot: NarrativeSourceSnapshot
        var quietDayCount: Int
        var bleedIssueNumber: Int
    }

    struct StagedSurfaceBuild: @unchecked Sendable {
        var foundation: SurfaceBuildFoundation
        var result: SurfaceBuildResult
    }

    /// Launch computes the shared narrative/quiet-day foundation once. The
    /// cheap curator can publish immediately, and the enriched continuation
    /// reuses that exact foundation instead of repeating all of the setup work.
    nonisolated static func computeQuickSurfaceBuild(
        _ request: SurfaceBuildRequest,
        priority: TaskPriority = .userInitiated
    ) async -> StagedSurfaceBuild {
        await Task.detached(priority: priority) {
            let foundation = makeSurfaceBuildFoundation(request)
            return StagedSurfaceBuild(
                foundation: foundation,
                result: makeSurfaceBuildResult(
                    request,
                    foundation: foundation,
                    performsHeavyEnrichment: false
                )
            )
        }.value
    }

    nonisolated static func computeEnrichedSurfaceBuild(
        _ request: SurfaceBuildRequest,
        foundation: SurfaceBuildFoundation,
        priority: TaskPriority = .medium
    ) async -> SurfaceBuildResult {
        let base = await Task.detached(priority: priority) {
            makeSurfaceBuildResult(
                request,
                foundation: foundation,
                performsHeavyEnrichment: true
            )
        }.value
        return await addingBookFoundGift(
            to: base,
            request: request,
            foundation: foundation
        )
    }

    /// The heavy lifting: whole-archive continuity projection + motif clusters +
    /// curation, all off the main actor. Pure functions over value types, so it is
    /// `nonisolated` and runs on a detached medium-priority executor so its
    /// archive/embedding work never steals the animation and gesture runway.
    nonisolated static func computeSurfaceBuild(
        _ request: SurfaceBuildRequest,
        performsHeavyEnrichment: Bool = true,
        priority: TaskPriority = .medium
    ) async -> SurfaceBuildResult {
        let foundationAndResult = await Task.detached(priority: priority) {
            let foundation = makeSurfaceBuildFoundation(request)
            return (
                foundation,
                makeSurfaceBuildResult(
                    request,
                    foundation: foundation,
                    performsHeavyEnrichment: performsHeavyEnrichment
                )
            )
        }.value
        guard performsHeavyEnrichment else { return foundationAndResult.1 }
        return await addingBookFoundGift(
            to: foundationAndResult.1,
            request: request,
            foundation: foundationAndResult.0
        )
    }

    /// The pure curator decides what kind of interruption is needed before the
    /// app opens the network window. A successful finding is intentionally put
    /// at the head of the deep bench; ordinary desk stabilization still keeps
    /// it from barging over a Page the reader is already looking at.
    private nonisolated static func addingBookFoundGift(
        to base: SurfaceBuildResult,
        request: SurfaceBuildRequest,
        foundation: SurfaceBuildFoundation
    ) async -> SurfaceBuildResult {
        let context = CuratorContext.make(for: request.today)
        guard !context.distress.isActive,
              FirstRunPageSequence.surfaces(
                for: request.today,
                context: context,
                inputs: foundation.inputs,
                now: request.now
              ) == nil,
              let plan = BookFoundGiftEngine.plan(
                  for: request.today,
                  interior: foundation.inputs.bookInterior,
                  surfaceHistory: foundation.inputs.surfaceHistory,
                  keptPageCount: foundation.inputs.keptPageCount,
                  people: foundation.inputs.people,
                  now: request.now
              ),
              let thing = await BookFoundGiftFinder.shared.find(for: plan, now: request.now),
              let gift = BookFoundGiftEngine.surface(for: plan, thing: thing, now: request.now),
              request.preferences.allows(gift),
              CuratorMood.make(
                inputs: foundation.inputs,
                distressActive: false,
                now: request.now
              ).allows(gift) else {
            return base
        }

        let blocked = gift.curatorDeskExclusionKeys
        let survivors = base.surfaces.filter { candidate in
            candidate.id != gift.id
                && candidate.sourceID != gift.sourceID
                && blocked.isDisjoint(with: candidate.curatorDeskExclusionKeys)
        }
        var enriched = base
        enriched.surfaces = Array(([gift] + survivors).prefix(max(1, request.surfaceLimit)))
        return enriched
    }

    private nonisolated static func makeSurfaceBuildFoundation(
        _ request: SurfaceBuildRequest
    ) -> SurfaceBuildFoundation {
        var inputs = request.inputs
        let narrativeSnapshot = NarrativeSourceSnapshotBuilder.snapshot(
            from: request.events,
            memories: request.entityMemories,
            beliefWeight: request.inputs.readerBeliefScore
        )
        inputs.narrative = narrativeSnapshot
        var quietDayCount = NothingTide.quietDays(
            in: request.days,
            today: request.today.id
        )
        // A warm Quieting gift literally holds Routine back.
        if request.hasActiveQuietingGift {
            quietDayCount = max(0, quietDayCount - 2)
        }
        inputs.quietDays = quietDayCount
        let bleedIssueNumber = request.days.reduce(1) { issueNumber, day in
            issueNumber + day.pages.lazy.filter { $0.type == .theBleed }.count
        }
        inputs.bleedIssueNumber = bleedIssueNumber
        return SurfaceBuildFoundation(
            inputs: inputs,
            narrativeSnapshot: narrativeSnapshot,
            quietDayCount: quietDayCount,
            bleedIssueNumber: bleedIssueNumber
        )
    }

    private nonisolated static func makeSurfaceBuildResult(
        _ request: SurfaceBuildRequest,
        foundation: SurfaceBuildFoundation,
        performsHeavyEnrichment: Bool
    ) -> SurfaceBuildResult {
        let digest: LiteraryContinuityDigest
        let clusters: [BookMotifCluster]
        if performsHeavyEnrichment, request.needsDigest {
            var built = LiteraryContinuityProjector.digest(
                days: request.days,
                events: request.events,
                entityMemories: request.entityMemories,
                entityBelief: request.entityBelief,
                pageBelief: request.pageBelief,
                now: request.now
            )
            built.signals += RadioStationRegistry.listeningSignals(
                state: request.inputs.radio,
                unlockedPackIDs: request.inputs.ownedPackIDs,
                now: request.now
            )
            digest = built
            clusters = BookMotifClusterEngine.clusters(
                from: built,
                constellations: request.inputs.constellations,
                themes: request.inputs.themes,
                now: request.now
            )
        } else {
            digest = request.cachedDigest
            clusters = request.cachedClusters
        }

        var inputs = foundation.inputs
        inputs.continuity = digest
        inputs.clusters = clusters
        // NLEmbedding is not free. The launch desk first uses the pure fallback,
        // then this enriched continuation adds semantic evidence to the bench.
        if performsHeavyEnrichment {
            inputs.semanticNoticePairing = SemanticNoticePairing.find(
                days: request.days + [request.today],
                scorer: SemanticKeepEcho.keepTimeScorer,
                now: request.now
            )
            inputs.semanticPassageSelectionEnabled = true
        } else {
            inputs.semanticNoticePairing = nil
            inputs.semanticPassageSelectionEnabled = false
        }

        let surfaces: [SurfacePage]
        let firstRun = FirstRunPageSequence.surfaces(
            for: request.today,
            context: CuratorContext.make(for: request.today),
            inputs: inputs,
            now: request.now
        )
        let allowedFirstRun = firstRun?.filter { request.preferences.allows($0) } ?? []
        if !allowedFirstRun.isEmpty {
            surfaces = allowedFirstRun
        } else {
            let feed = BookCurator.surfacedPages(
                for: request.today,
                inputs: inputs,
                now: request.now,
                limit: request.surfaceLimit,
                preferences: request.preferences
            )
            let upgrade = FirstRunPageSequence.pendingLocalBrainUpgrade(inputs: inputs)
            if let upgrade, request.preferences.allows(upgrade) {
                surfaces = FirstRunPageSequence.mergingUpgradeRider(
                    upgrade,
                    into: feed,
                    limit: request.surfaceLimit
                )
            } else {
                surfaces = feed
            }
        }

        return SurfaceBuildResult(
            digest: digest,
            clusters: clusters,
            surfaces: surfaces,
            narrativeSnapshot: foundation.narrativeSnapshot,
            quietDayCount: foundation.quietDayCount,
            bleedIssueNumber: foundation.bleedIssueNumber,
            didRecomputeDigest: performsHeavyEnrichment && request.needsDigest,
            signature: request.signature
        )
    }

    @MainActor
    func replaceDismissedSurfaceInCache(_ surface: SurfacePage, now: Date) {
        guard pendingSurfaceRetirements[surface.id] == nil,
              surfacedPages.contains(where: { $0.id == surface.id }) else {
            return
        }

        // Supersede any ordinary build captured before the keep/dismissal. A
        // separate retirement revision owns pending slots so later refreshes
        // cannot strand one by cancelling its only replacement task.
        surfaceBuildToken &+= 1
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            pendingSurfaceRetirements[surface.id] = PendingSurfaceRetirement(surface: surface)
        }

        if resolvePendingSurfaceRetirementsFromBench(now: now) {
            // Replenish the bench in the background. The visible desk is already
            // complete, so the full curator may take its time and cannot evict it.
            surfaceRefreshDate = now
            return
        }
        scheduleSurfaceRetirementReconciliation(now: now)
    }

    /// The enriched launch/refresh pass normally leaves enough ranked candidates
    /// to make a reader-triggered refill immediate. Publish only when every
    /// pending slot can be satisfied atomically; otherwise keep the placeholders
    /// and fall through to the existing lightweight curator.
    @MainActor
    private func resolvePendingSurfaceRetirementsFromBench(now: Date) -> Bool {
        guard !pendingSurfaceRetirements.isEmpty, !curatedSurfaceBench.isEmpty else {
            return false
        }
        let pending = pendingSurfaceRetirements
        let pendingIDs = Set(pending.keys)
        let blockedOutgoingKeys = Set(
            pending.values.flatMap { $0.surface.curatorDeskExclusionKeys }
        )
        let preferences = CuratorSurfacePreferences(
            dismissedSurfaceIDs: dismissedSurfaceIDs(for: today.id, now: now),
            disabledSourceIDs: disabledSourceIDs(),
            pageBeliefProfiles: Dictionary(
                uniqueKeysWithValues: pageBeliefProfiles.map { ($0.sourceID, $0) }
            ),
            readerLearning: vault.data.readerLearning ?? ReaderLearningModel()
        )
        let candidates = curatedSurfaceBench.filter { preferences.allows($0) }
        let resolution = BookCurator.resolvingRetiredDeskSlots(
            previous: surfacedPages,
            retiringIDs: pendingIDs,
            rebuilt: candidates,
            additionallyBlockedKeys: blockedOutgoingKeys,
            limit: 3
        )
        guard resolution.replacesAll(pendingIDs) else {
            return false
        }
        publishSurfaceRetirementResolution(
            resolution,
            pendingIDs: pendingIDs,
            now: now
        )
        return true
    }

    /// Rebuilds against every currently pending retirement, then replaces all
    /// outgoing slots in one publication. A second quick swipe restarts this
    /// batch with both holes, so two independent tasks can never choose the same
    /// replacement or leave the older slot hidden forever.
    @MainActor
    private func scheduleSurfaceRetirementReconciliation(now: Date) {
        guard !pendingSurfaceRetirements.isEmpty else { return }

        surfaceRetirementRevision &+= 1
        let revision = surfaceRetirementRevision
        let cacheToken = surfaceBuildToken
        // Ask for a deeper bench than the three visible cards. The survivors
        // already occupy two slots and may conflict with the highest-ranked
        // candidates, so a three-card result is not enough to guarantee a
        // quick valid replacement.
        let request = makeSurfaceBuildRequest(now: now, surfaceLimit: 12)

        Task {
            // Swipe replacement is an interaction response, not an enrichment
            // pass. Reuse the cached continuity state and skip embeddings; the
            // normal background rebuild owns that deeper work.
            let result = await ContentView.computeSurfaceBuild(
                request,
                performsHeavyEnrichment: false,
                priority: .userInitiated
            )
            guard revision == surfaceRetirementRevision else { return }

            // A retirement result is still useful for its candidate pages after
            // an unrelated cache build, but only the latest ordinary token may
            // publish continuity-cache metadata.
            if cacheToken == surfaceBuildToken, result.didRecomputeDigest {
                continuityCacheSignature = result.signature
                cachedContinuityDigest = result.digest
                cachedMotifClusters = result.clusters
            }
            if cacheToken == surfaceBuildToken {
                cachedNarrativeSourceSnapshot = result.narrativeSnapshot
                cachedQuietDayCount = result.quietDayCount
                cachedBleedIssueNumber = result.bleedIssueNumber
            }

            let pending = pendingSurfaceRetirements
            let pendingIDs = Set(pending.keys)
            let blockedOutgoingKeys = Set(
                pending.values.flatMap { $0.surface.curatorDeskExclusionKeys }
            )
            let preferences = CuratorSurfacePreferences(
                dismissedSurfaceIDs: dismissedSurfaceIDs(for: today.id, now: now),
                disabledSourceIDs: disabledSourceIDs(),
                pageBeliefProfiles: Dictionary(
                    uniqueKeysWithValues: pageBeliefProfiles.map { ($0.sourceID, $0) }
                ),
                readerLearning: vault.data.readerLearning ?? ReaderLearningModel()
            )
            let candidates = result.surfaces.filter { preferences.allows($0) }
            let resolution = BookCurator.resolvingRetiredDeskSlots(
                previous: surfacedPages,
                retiringIDs: pendingIDs,
                rebuilt: candidates,
                additionallyBlockedKeys: blockedOutgoingKeys,
                limit: 3
            )
            curatedSurfaceBench = result.surfaces
            publishSurfaceRetirementResolution(
                resolution,
                pendingIDs: pendingIDs,
                now: now
            )
        }
    }

    @MainActor
    private func publishSurfaceRetirementResolution(
        _ resolution: BookCurator.DeskRetirementResolution,
        pendingIDs: Set<String>,
        now: Date
    ) {
        let arrivingIDs = Set(resolution.replacementIDByRetiringID.values)
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            arrivingSurfaceIDs.formUnion(arrivingIDs)
            surfacedPages = resolution.pages
            if let undoID = undoSurface?.id,
               pendingIDs.contains(undoID) {
                undoSurfaceReplacementID = resolution.replacementIDByRetiringID[undoID]
            }
            pendingSurfaceRetirements.removeAll()
            let visibleIDs = Set(surfacedPages.map(\.id))
            curatedSurfaceBench.removeAll { visibleIDs.contains($0.id) }
        }
        recordServedSurfaces(surfacedPages, now: now)

        guard !arrivingIDs.isEmpty else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.1))
            var cleanupTransaction = Transaction(animation: nil)
            cleanupTransaction.disablesAnimations = true
            withTransaction(cleanupTransaction) {
                arrivingSurfaceIDs.subtract(arrivingIDs)
            }
        }
    }

    /// Cancels a still-pending retirement (normally an Undo). If other quick
    /// dismissals are still pending, restart one batch for the remaining holes.
    @MainActor
    private func cancelPendingSurfaceRetirement(surfaceID: String, now: Date) {
        guard pendingSurfaceRetirements[surfaceID] != nil else { return }

        surfaceRetirementRevision &+= 1
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            pendingSurfaceRetirements[surfaceID] = nil
        }
        if !pendingSurfaceRetirements.isEmpty {
            scheduleSurfaceRetirementReconciliation(now: now)
        }
    }

    /// The strengthened desk stabilizer deliberately preserves a full desk, so
    /// Undo must restore the original slot directly rather than merely asking a
    /// later curator rebuild to rediscover it.
    @MainActor
    private func restoreUndoneSurfaceOnDesk(
        _ surface: SurfacePage,
        replacing replacementID: String?,
        preferredIndex: Int?
    ) {
        let restored = BookCurator.restoringRetiredDeskSlot(
            current: surfacedPages,
            surface: surface,
            replacementID: replacementID,
            preferredIndex: preferredIndex,
            limit: 3
        )
        guard restored.map(\.id) != surfacedPages.map(\.id) else { return }

        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            surfacedPages = restored
        }
    }

    private func clearSurfaceUndoContext() {
        undoSurface = nil
        undoDayID = nil
        undoSurfaceSlotIndex = nil
        undoSurfaceReplacementID = nil
        undoSurfaceDismissalKeys = []
    }

    /// Recompute the continuity digest + motif clusters over the whole archive,
    /// but only when the underlying data actually changed. This is the single
    /// place that pays for the projection; everything else reads the cache.
    /// Cheap fingerprint of the archive inputs the continuity projection reads.
    /// Belief-ledger counts are passed in so callers that already decoded the
    /// ledgers (the off-main surface build) don't pay for the decode twice.
    func continuityCacheSignatureString(entityBeliefCount: Int, pageBeliefCount: Int) -> String {
        [
            "\(days.count)",
            "\(days.last?.pages.count ?? 0)",
            "\(narrativeEvents.count)",
            "\(entityMemories.count)",
            "\(entityBeliefCount)",
            "\(pageBeliefCount)",
            "\(vault.data.constellations?.count ?? 0)",
            "\(vault.data.themes?.count ?? 0)"
        ].joined(separator: "-")
    }

    func refreshContinuityCache(force: Bool = false) {
        let signature = continuityCacheSignatureString(
            entityBeliefCount: entityBeliefLedger.count,
            pageBeliefCount: pageBeliefLedger.count
        )
        guard force || signature != continuityCacheSignature else { return }
        continuityCacheSignature = signature

        let started = Date()
        defer {
            let ms = Date().timeIntervalSince(started) * 1000
            appLog.info("Continuity cache refreshed in \(ms, format: .fixed(precision: 1))ms; days: \(days.count, privacy: .public); events: \(narrativeEvents.count, privacy: .public)")
        }

        var digest = LiteraryContinuityProjector.digest(
            days: days,
            events: narrativeEvents,
            entityMemories: entityMemories,
            entityBelief: entityBeliefLedger,
            pageBelief: pageBeliefLedger,
            now: surfaceRefreshDate
        )
        // Stations the reader keeps returning to surface as continuity signals,
        // so The Book Notices can voice them and they can grow into companions.
        digest.signals += RadioStationRegistry.listeningSignals(
            state: vault.data.radio ?? .off,
            unlockedPackIDs: Set(vault.data.ownedPacks ?? []),
            now: surfaceRefreshDate
        )
        cachedContinuityDigest = digest
        cachedMotifClusters = BookMotifClusterEngine.clusters(
            from: digest,
            constellations: vault.data.constellations ?? [],
            themes: vault.data.themes ?? [],
            now: surfaceRefreshDate
        )
    }

    /// First-run script steps advance only when the reader engages a card —
    /// opens it or deliberately swipes it away — never because a desk rebuild
    /// happened to flash it past. The calendar door is the one script card
    /// without `firstRunStep` metadata, so it is matched by its own marker.
    func markFirstRunEngaged(_ surface: SurfacePage) {
        guard surface.payload.metadata["firstRunStep"] != nil
                || surface.payload.metadata["calendarDoorPreview"] == "true" else { return }
        var engaged = Set(vault.data.firstRunEngaged ?? [])
        let keys = surface.curatorServedHistoryKeys
        guard !keys.allSatisfy(engaged.contains) else { return }
        engaged.formUnion(keys)
        vault.data.firstRunEngaged = engaged.sorted()
        vault.save()
    }

    /// The curator remembers what it put on the desk, so it stops repeating
    /// itself. Only newly-shown content keys are written (30-minute grace).
    func recordServedSurfaces(_ pages: [SurfacePage], now: Date = Date()) {
        let history = vault.data.surfaceHistory ?? [:]
        let servedKeys = pages
            .filter { $0.type != .bookOfYou }
            .flatMap(\.curatorServedHistoryKeys)
        let newKeys = servedKeys.filter { key in
            guard let record = history[key] else { return true }
            return now.timeIntervalSince(record.lastShownAt) > 30 * 60
        }
        guard !newKeys.isEmpty else { return }
        vault.data.surfaceHistory = CuratorVarietyGovernor.recordingServed(keys: newKeys, into: history, now: now)
        for page in pages where page.curatorServedHistoryKeys.contains(where: { newKeys.contains($0) }) {
            recordReaderLearning(surface: page, action: .surfaced, now: now, saveImmediately: false)
        }
        vault.save()
    }

    func recordReaderLearning(
        surface: SurfacePage,
        action: ReaderLearningAction,
        now: Date = Date(),
        evidence: String? = nil,
        saveImmediately: Bool = true
    ) {
        var learning = vault.data.readerLearning ?? ReaderLearningModel()
        learning.record(
            ReaderLearningEvent(
                dayID: today.id,
                occurredAt: now,
                action: action,
                surfaceID: surface.id,
                sourceID: surface.sourceID,
                type: surface.type,
                varietyKey: surface.varietyKey,
                hour: Calendar.current.component(.hour, from: now),
                tags: surface.readerLearningTags,
                evidence: evidence
            )
        )
        vault.data.readerLearning = learning
        if saveImmediately {
            vault.save()
        }
    }

    func recordReaderLearning(
        page: BookPage,
        dayID: String,
        action: ReaderLearningAction,
        now: Date = Date(),
        evidence: String? = nil
    ) {
        var learning = vault.data.readerLearning ?? ReaderLearningModel()
        learning.record(
            ReaderLearningEvent(
                dayID: dayID,
                occurredAt: now,
                action: action,
                surfaceID: page.id,
                sourceID: page.sourceID,
                type: page.type,
                varietyKey: "source:\(page.sourceID)",
                hour: Calendar.current.component(.hour, from: page.createdAt),
                tags: page.tags,
                evidence: evidence ?? page.userInput
            )
        )
        vault.data.readerLearning = learning
        vault.save()
    }

    func recordMomentaryPageOpened(_ surface: SurfacePage, at now: Date) {
        recordReaderLearning(
            surface: surface,
            action: .opened,
            now: now,
            evidence: "The Page became readable."
        )
        if surface.payload.metadata["momentaryThreadFollowUp"] == "true" {
            recordReaderLearning(
                surface: surface,
                action: .followedThread,
                now: now,
                evidence: surface.payload.metadata["threadWord"]
            )
        }
    }

    func recordMomentaryAction(
        on surface: SurfacePage,
        evidence: String,
        at now: Date
    ) -> MomentaryActionOutcome {
        let learningBefore = vault.data.readerLearning ?? ReaderLearningModel()
        let stage = ReaderAttentionMasteryStage.current(for: learningBefore)
        let recognition = MomentaryAttentionEngine.recognition(for: evidence, stage: stage)

        recordReaderLearning(
            surface: surface,
            action: .acted,
            now: now,
            evidence: evidence
        )
        recordMeaningfulAttention(
            key: "micro:\(surface.id)",
            now: now
        )
        recordReaderLearning(
            surface: surface,
            action: .recognized,
            now: now,
            evidence: recognition
        )

        let keepsakeLine = awardAttentionKeepsakeIfEarned(
            from: surface,
            evidence: evidence,
            at: now
        )
        return MomentaryActionOutcome(
            recognitionLine: recognition,
            keepsakeLine: keepsakeLine
        )
    }

    /// Keeps make the actual native Page interaction legible to the private
    /// momentum ledger. This replaces dependence on the generic capture field
    /// that no longer appears on Pages, and never changes curation affinity.
    func recordNativePageActionIfNeeded(
        on surface: SurfacePage,
        evidence: String,
        at now: Date
    ) {
        let learning = vault.data.readerLearning ?? ReaderLearningModel()
        guard learning.needsNativeAction(for: surface.id) else { return }
        recordReaderLearning(
            surface: surface,
            action: .acted,
            now: now,
            evidence: evidence,
            saveImmediately: false
        )
    }

    @discardableResult
    func awardAttentionKeepsakeIfEarned(
        from surface: SurfacePage,
        evidence: String,
        at now: Date
    ) -> String? {
        let learning = vault.data.readerLearning ?? ReaderLearningModel()
        guard AttentionKeepsakeGovernor.isEarned(in: learning) else { return nil }
        let keepsake = PartingWhisper.keepsake(from: surface, evidence: evidence)
        pressKeepsakeIntoPocket(keepsake, from: surface, at: now)
        recordReaderLearning(
            surface: surface,
            action: .keepsakeEarned,
            now: now,
            evidence: keepsake.title
        )
        BookFeedback.play(.braidComplete)
        return "Your attention pressed “\(keepsake.title)” into the Book’s Pocket."
    }

    func toggleGlowMenu() {
        guard canOpenGlowMenu else {
            BookFeedback.play(.dismissPage)
            statusMessage = glowMenuLockedMessage
            return
        }

        BookFeedback.play(isGlowMenuPresented ? .dismissPage : .sourceRefresh)
        withAnimation(.spring(response: 0.48, dampingFraction: 0.78)) {
            isGlowMenuPresented.toggle()
        }
        if isGlowMenuPresented {
            tutorTouch("glow-menu")
        }
    }

    var glowMenuLockedMessage: String {
        if !didCompleteStoryOnboarding {
            return "Your Glow is awake, but the menu opens after the Academy finishes showing you the first pages."
        }

        return "Your Glow is awake. The menu opens after the Book Brain is downloaded and ready."
    }

    /// First-touch margin notes: the exploratory tutorial that follows the
    /// story onboarding. Each explainable thing speaks up exactly once.
    func tutorTouch(_ id: String) {
        guard didCompleteStoryOnboarding else { return }
        var seen = MarginTutorLedger.seenIDs(from: marginTutorSeenData)
        guard !seen.contains(id), let note = MarginTutorCatalog.note(for: id) else { return }
        seen.insert(id)
        marginTutorSeenData = MarginTutorLedger.encode(seen)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            activeTutorNote = note
        }
    }

    func closeGlowMenu() {
        BookFeedback.play(.dismissPage)
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            isGlowMenuPresented = false
        }
    }

    func handleGlowMenuAction(_ action: GlowMenuAction) {
        switch action {
        case let .giveBelief(entity):
            giveBelief(to: entity)
        case let .takeBelief(entity):
            takeBelief(from: entity)
        case let .givePageBelief(page):
            givePageBelief(to: page)
        case let .takePageBelief(page):
            takePageBelief(from: page)
        case .spellCompass:
            selectedSurface = compassRunSurface()
            closeGlowMenu()
        case .openAlmanac:
            selectedSurface = almanacSurface()
            closeGlowMenu()
        case let .openEnchantment(enchantment):
            selectedSurface = enchantmentSurface(enchantment)
            closeGlowMenu()
        case let .openPage(type):
            Task { await openManualPage(type) }
            closeGlowMenu()
        case .openFlyleaf:
            selectedSurface = flyleafSurface()
            closeGlowMenu()
        case .openPagewright:
            isPagewrightPresented = true
            closeGlowMenu()
        case .bindWeeklyIssue:
            exportWeeklyIssuePDF()
            closeGlowMenu()
        case .rebindWeeklyIssue:
            exportWeeklyIssuePDF(forceRebind: true)
            closeGlowMenu()
        case .bindMonthlyEdition:
            exportMonthlyEdition()
            closeGlowMenu()
        case .bindAnnualEdition:
            exportAnnualEdition()
            closeGlowMenu()
        case .exportPlainInk:
            exportPlainInk()
            closeGlowMenu()
        case .exportSealedCopy:
            exportSaveFile()
            closeGlowMenu()
        case .openBookShop:
            currentStall = buildGoblinStall()
            isBookShopPresented = true
            closeGlowMenu()
        case .openPactMap:
            isPactMapPresented = true
            closeGlowMenu()
        case .openPeopleOfTheBook:
            isPeopleOfTheBookPresented = true
            closeGlowMenu()
        case let .openBookSection(sectionID):
            selectedSurface = readingSurface(forWonderCompassSectionID: sectionID)
            closeGlowMenu()
        }
    }

    func glowLine(for entity: NarrativeWorldEntity) -> String {
        if let descriptor = compactCastDescriptor(for: entity.id) {
            return descriptor
        }

        let source: String
        if !entity.traits.isEmpty {
            source = entity.traits.prefix(2).joined(separator: ", ")
        } else if let interest = entity.unwrittenInterest?.trimmingCharacters(in: .whitespacesAndNewlines), !interest.isEmpty {
            source = interest
        } else if let goal = entity.goals.first {
            source = goal
        } else if let belief = entity.beliefs.first {
            source = belief
        } else {
            source = entity.kind.rawValue
        }
        return compactGlowLine(source)
    }

    func compactCastDescriptor(for id: String) -> String? {
        switch id {
        case "the-book":
            return "Attentive living book"
        case "penny-blackletter":
            return "Sharp student editor"
        case "dr-inkrest":
            return "Gentle narrative therapist"
        case "dr-vellum":
            return "Precise longevity physician"
        case "headmistress-thorne":
            return "Watchful headmistress"
        case "orion-blackthorn":
            return "Stern impossible architect"
        case "zara-finch":
            return "Loyal house guide"
        case "wicker-eddies":
            return "Sharp belief challenger"
        case "serenity-brown":
            return "Spontaneous Tidecrest friend"
        case "finn-bridges":
            return "Honorable Emberheart rival"
        case "lysander-mosswood":
            return "Thoughtful trail guide"
        case "damien-nights":
            return "Divided shadow student"
        case "melisande-blackwood":
            return "Ruthless crew strategist"
        case "min-seo-kim":
            return "Gentle Mossbloom conscience"
        case "gwendolyn-mythwright":
            return "Steadfast cryptid scholar"
        case "lydia-boggle":
            return "Wry glint professor"
        case "professor-kyle-momort":
            return "Kinetic wayfinding professor"
        case "professor-eleanor-euphony":
            return "Resonant senses professor"
        case "professor-vivian-villanelle":
            return "Exacting ink-binding professor"
        case "professor-cedric-stonebrook":
            return "Grounded rest professor"
        case "professor-luna-wispwood":
            return "Playful enchantments professor"
        case "professor-permancer":
            return "Careful Book Jumping professor"
        case "soren-ng":
            return "Quiet riddle cartographer"
        case "weather-page":
            return "Atmospheric weather page"
        case "body-page":
            return "Humane body pacing"
        default:
            return nil
        }
    }

    func compactGlowLine(_ source: String) -> String {
        let separators = CharacterSet(charactersIn: ",;.-")
        let fragments = source
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let phrase = fragments.first ?? source.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = phrase.split(separator: " ")
        if words.count <= 4 {
            return phrase
        }
        return words.prefix(4).joined(separator: " ")
    }

    func giveBelief(to entity: GlowEntityMenuItem) {
        let spend = min(3, beliefScore)
        guard spend > 0 else {
            statusMessage = "Your own Glow is too dim to give right now. Keep something real or answer the Book to rekindle it."
            return
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
            beliefScore = max(0, beliefScore - spend)
        }
        adjustEntityBelief(entity, delta: spend, kind: .beliefInvested, playerBeliefDelta: -spend)
        BookFeedback.beliefTransferred(amount: spend, recipientGlow: entity.glow + spend)
        statusMessage = spend == 3
            ? "\(entity.name) takes on three brighter points of Glow, passed from your own."
            : "\(entity.name) takes the last \(spend) point\(spend == 1 ? "" : "s") of Glow you could spare."
    }

    func givePageBelief(to page: GlowPageMenuItem) {
        let spend = min(3, beliefScore)
        guard spend > 0 else {
            statusMessage = "Your own Glow is too dim to give right now. Keep something real or answer the Book to rekindle it."
            return
        }
        let applied = adjustPageBelief(page, delta: spend)
        guard applied > 0 else {
            statusMessage = "\(page.title) already glows as bright as it can."
            return
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
            beliefScore = max(0, beliefScore - applied)
        }
        BookFeedback.beliefTransferred(amount: applied, recipientGlow: page.glow + applied)
        statusMessage = "\(page.title) takes on \(applied) brighter point\(applied == 1 ? "" : "s") of Glow, passed from your own."
    }

    func takePageBelief(from page: GlowPageMenuItem) {
        let applied = adjustPageBelief(page, delta: -3)
        guard applied < 0 else {
            statusMessage = "\(page.title) has no Glow left to take."
            return
        }
        let gained = -applied
        withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
            beliefScore = min(100, beliefScore + gained)
        }
        statusMessage = "You draw \(gained) point\(gained == 1 ? "" : "s") of Glow back from \(page.title). The Book will still remember it can surface."
    }

    func takeBelief(from entity: GlowEntityMenuItem) {
        let attack = BeliefCombatResolver.resolve(
            attackerName: "The reader",
            attackerKind: .player,
            attackerBelief: beliefScore,
            targetName: entity.name,
            targetKind: .entity,
            targetBelief: entity.glow,
            spend: 3,
            difficulty: BeliefCombatResolver.difficulty(forTargetBelief: entity.glow)
        )
        let playerDelta = attack.attackerBeliefAfter - attack.attackerBeliefBefore
        let entityDelta = attack.targetBeliefAfter - attack.targetBeliefBefore
        if entityDelta != 0 {
            adjustEntityBelief(entity, delta: entityDelta, kind: .beliefAttacked, playerBeliefDelta: playerDelta)
        } else {
            recordGlowBeliefEvent(entity: entity, delta: 0, kind: .beliefAttacked, playerBeliefDelta: playerDelta)
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
            beliefScore = min(100, max(0, attack.attackerBeliefAfter))
        }
        if attack.backlash > 0 {
            statusMessage = "\(entity.name)'s Glow snaps back. \(attack.summaryLine)"
        } else if attack.dealt > 0 {
            statusMessage = "The attack lands. \(attack.summaryLine)"
        } else {
            statusMessage = "\(entity.name)'s Glow holds. \(attack.summaryLine)"
        }
    }

    func adjustEntityBelief(
        _ entity: GlowEntityMenuItem,
        delta: Int,
        kind: NarrativeEventKind,
        playerBeliefDelta: Int = 0
    ) {
        var ledger = entityBeliefLedger
        let previousOffset = ledger[entity.id] ?? 0
        ledger[entity.id, default: 0] += delta
        if let data = try? JSONEncoder().encode(ledger),
           let encoded = String(data: data, encoding: .utf8) {
            entityBeliefLedgerData = encoded
        }
        recordGlowBeliefEvent(entity: entity, delta: delta, kind: kind, playerBeliefDelta: playerBeliefDelta)
        if entity.id == ShadowWonder.duskThornTalismanID,
           previousOffset <= 0,
           (ledger[entity.id] ?? 0) > 0,
           kind == .beliefInvested {
            selectedWonderCompassSnippet = nil
            selectedWonderCompassSelector = nil
            surfaceRefreshDate = Date()
            statusMessage = "The Dusk Thorn warms. Shadow Wonder can now surface in quips, lore, missions, and souvenirs after dark or when Duskthorn is ascendant."
            let note = KeepMarginalia.Note(
                castSlug: "wicker-eddies",
                castName: "Wicker Eddies",
                assetName: "LabyrinthCharacterWickerEddies",
                line: "There. You fed the Dusk Thorn, and it answered. The Book can stop pretending wonder only happens in bright places.",
                carryOutLine: "Violet Shadow Wonder pages can now surface after dark, under Duskthorn, or when the day shows its worn edge."
            )
            withAnimation(.spring(response: 0.48, dampingFraction: 0.8)) {
                shadowWonderUnlockNote = note
            }
        }
    }

    /// Returns the new member's id on success (nil if the save failed), so
    /// callers like the person-thread crossing can link back to it.
    @discardableResult
    func saveCustomCastMember(_ draft: CustomCastMemberDraft) -> String? {
        let now = Date()
        let id = "user-cast-\(slug(for: draft.name))-\(UUID().uuidString.prefix(8))"
        let imageAsset = saveCustomCastImage(data: draft.imageData, entityID: id, name: draft.name)
        let inferredTags = Array(Set(
            draft.tags +
            draft.traits.map { $0.lowercased() } +
            [draft.kind.rawValue, "custom-cast", "belief"]
        )).sorted()
        let member = CustomCastMember(
            id: id,
            name: draft.name,
            kind: draft.kind,
            meaning: draft.meaning,
            description: draft.description,
            traits: draft.traits,
            beliefs: draft.beliefs,
            goals: draft.goals,
            tags: inferredTags,
            baseBelief: min(100, max(0, draft.startingGlow ?? 25)),
            narrativeWeight: 22,
            createdAt: now,
            updatedAt: now,
            imageAsset: imageAsset
        )

        do {
            try BookDatabase.upsertCustomCastMember(member)
            customCastMembers = try BookDatabase.customCastMembers(limit: 200)
            let menuItem = GlowEntityMenuItem(
                id: member.id,
                name: member.name,
                kind: member.kind.rawValue,
                glow: member.baseBelief,
                line: member.meaning
            )
            adjustEntityBelief(menuItem, delta: 3, kind: .beliefInvested)
            statusMessage = "\(member.name) has entered the Cast."
            surfaceRefreshDate = Date()
            rebuildSurfaceCache()
            closeGlowMenu()
            return member.id
        } catch {
            statusMessage = "The new Cast Member would not settle yet: \(error.localizedDescription)"
            return nil
        }
    }

    func saveCustomCastImage(data: Data?, entityID: String, name: String) -> BookPageMediaAsset? {
        guard let data else { return nil }
        do {
            let baseURL = InsideCoverStore.containerURL
                ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            let directory = baseURL.appendingPathComponent("CustomCastImages", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("\(entityID).jpg")
            try data.write(to: url, options: [.atomic])
            return BookPageMediaAsset(
                kind: .renderedImageFile,
                reference: url.path,
                caption: name,
                sourceID: BookPageSourceRegistry.source(for: .illustration).id,
                metadata: ["entityID": entityID]
            )
        } catch {
            statusMessage = "The Cast Member was named, but the photo slipped: \(error.localizedDescription)"
            return nil
        }
    }

    func slug(for value: String) -> String {
        let words = value
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
        let slug = words.prefix(5).joined(separator: "-")
        return slug.isEmpty ? "entry" : slug
    }

    func recordGlowBeliefEvent(
        entity: GlowEntityMenuItem,
        delta: Int,
        kind: NarrativeEventKind,
        playerBeliefDelta: Int = 0
    ) {
        let event = NarrativeEvent(
            id: "glow-\(kind.rawValue)-\(entity.id)-\(UUID().uuidString)",
            kind: kind,
            sourcePageType: nil,
            sourcePageID: nil,
            createdAt: Date(),
            summary: delta > 0
                ? "The reader gave \(entity.name) \(delta) Belief through the Glow menu."
                : (delta < 0 ? "The reader took \(abs(delta)) Belief from \(entity.name) through the Glow menu." : "The reader tested \(entity.name)'s Belief through the Glow menu."),
            tags: ["glow", "belief", "entity:\(entity.id)"],
            effect: NarrativeEventEffect(
                beliefDelta: playerBeliefDelta,
                entityWeightDeltas: [entity.id: delta]
            )
        )
        do {
            try BookDatabase.upsertNarrativeEvent(event)
            narrativeEvents = try BookDatabase.narrativeEvents(limit: 160)
        } catch {
            statusMessage = "The Glow moved, but the hidden ledger missed a line: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func adjustPageBelief(_ page: GlowPageMenuItem, delta: Int) -> Int {
        var ledger = pageBeliefLedger
        let source = BookPageSourceRegistry.source(id: page.sourceID, fallbackType: page.type)
        let defaultBelief = BookPageSourceRegistry.defaultBelief(for: source)
        let currentDelta = ledger[page.sourceID] ?? 0
        let currentBelief = max(0, min(100, defaultBelief + currentDelta))
        let nextBelief = max(0, min(100, currentBelief + delta))
        let applied = nextBelief - currentBelief
        ledger[page.sourceID] = nextBelief - defaultBelief
        if ledger[page.sourceID] == 0 {
            ledger[page.sourceID] = nil
        }
        if let data = try? JSONEncoder().encode(ledger),
           let encoded = String(data: data, encoding: .utf8) {
            pageBeliefLedgerData = encoded
        }
        recordGlowPageBeliefEvent(page: page, delta: applied, playerBeliefDelta: -applied)
        surfaceRefreshDate = Date()
        rebuildSurfaceCache()
        return applied
    }

    func recordGlowPageBeliefEvent(page: GlowPageMenuItem, delta: Int, playerBeliefDelta: Int = 0) {
        let event = NarrativeEvent(
            id: "glow-page-belief-\(page.sourceID)-\(UUID().uuidString)",
            kind: delta >= 0 ? .beliefInvested : .beliefAttacked,
            sourcePageType: page.type,
            sourcePageID: nil,
            createdAt: Date(),
            summary: delta >= 0
                ? "The reader gave \(page.title) \(delta) Page Belief through the Glow menu."
                : "The reader took \(abs(delta)) Page Belief from \(page.title) through the Glow menu.",
            tags: ["glow", "belief", "page:\(page.sourceID)", "page-type:\(page.type.rawValue)"],
            effect: NarrativeEventEffect(beliefDelta: playerBeliefDelta)
        )
        do {
            try BookDatabase.upsertNarrativeEvent(event)
            narrativeEvents = try BookDatabase.narrativeEvents(limit: 160)
        } catch {
            statusMessage = "The Page Glow moved, but the hidden ledger missed a line: \(error.localizedDescription)"
        }
    }

    func compassRunSurface() -> SurfacePage {
        BookPageSourceAdapters.manualSurface(
            for: .wonderCompass,
            day: today,
            context: CuratorContext.make(for: today),
            inputs: sourceInputs,
            now: Date()
        )
    }

    func flyleafSurface() -> SurfacePage {
        ElectivePageSourceAdapter().flyleafSurface(
            for: today,
            inputs: sourceInputs,
            now: Date()
        )
    }

    /// The Living Almanac door. Shows the real active/archived world event (or
    /// the "quiet" card). In DEBUG, when nothing is in season, falls back to a
    /// season-agnostic preview so the full event machinery is always reachable.
    func almanacSurface() -> SurfacePage {
        let adapter = WorldEventPageSourceAdapter()
        let context = CuratorContext.make(for: today)
        let now = Date()
        let real = adapter.manualSurface(for: today, context: context, inputs: sourceInputs, now: now)
        #if DEBUG
        let hasReal = !WorldEventResolver.activeEvents(now: now, day: today, inputs: sourceInputs).isEmpty
            || !WorldEventResolver.archivedEvents(now: now, day: today, inputs: sourceInputs).isEmpty
        if !hasReal,
           let preview = adapter.previewSurface(for: today, context: context, inputs: sourceInputs, now: now) {
            return preview
        }
        #endif
        return real
    }

    func enchantmentSurface(_ enchantment: GlowEnchantmentMenuItem) -> SurfacePage {
        SurfacePage(
            id: "manual-enchantment-\(enchantment.id)-\(today.id)-\(Int(Date().timeIntervalSince1970))",
            type: .enchantment,
            sourceID: BookPageSourceRegistry.source(for: .enchantment).id,
            intent: .capture,
            renderStyle: .promptCard,
            score: 64,
            reason: "An Enchantment needs a chosen photo before the Book counts it.",
            prompt: enchantment.title,
            detail: enchantment.detail,
            payload: BookPagePayload(
                headline: "Enchantment Page: \(enchantment.title)",
                body: "\(enchantment.detail)\n\nChoose a photo. The spell will illuminate the real subject and write the result into the margins.",
                metadata: [
                    "source": "enchantment",
                    "enchantmentID": enchantment.id,
                    "enchantmentName": enchantment.title,
                    "placeholder": "Choose a photo to cast \(enchantment.title).",
                    "tags": "enchantment,proof,real-world-magic,\(enchantment.id)"
                ]
            )
        )
    }

    func surface(forManualPageType type: BookPageType) -> SurfacePage {
        return freshManualSurface(for: type)
    }

    func freshManualSurface(for type: BookPageType) -> SurfacePage {
        BookPageSourceAdapters.manualSurface(
            for: type,
            day: today,
            context: CuratorContext.make(for: today),
            inputs: sourceInputs,
            now: Date()
        )
    }

    func freshStudentNoteDraft(fallback: SurfacePage? = nil) -> SurfacePage {
        if let fallback,
           fallback.type == .note,
           fallback.payload.metadata["senderID"]?.nonEmpty != nil {
            return fallback
        }
        return StudentNotePageGenerator.draftCandidate(for: today, inputs: sourceInputs, now: Date())
            ?? fallback
            ?? freshManualSurface(for: .note)
    }

    func freshCameraFirstSurface() -> SurfacePage {
        let base = freshManualSurface(for: .illuminatedPhoto)
        let metadata = [
            "cameraFirst": "true",
            "source": "camera-seal",
            "surfaceLabel": "Camera",
            "symbol": "camera.fill",
            "tags": "camera-seal,manual-photo",
            "privacy": "private local capture"
        ]
        return SurfacePage(
            id: "camera-seal-\(today.id)-\(Int(Date().timeIntervalSince1970))",
            type: .illuminatedPhoto,
            sourceID: "camera-seal",
            intent: .capture,
            renderStyle: .illuminatedPhoto,
            score: base.score,
            reason: "A photo taken now can become an illuminated page or an Enchantment.",
            prompt: "Camera Page",
            detail: "Take a photo and keep the exact image you chose before and after the Book writes on it.",
            payload: BookPagePayload(
                headline: "Camera Page",
                body: "The lens is ready. Take a photo, then choose whether Penny illuminates it or an Enchantment wakes inside it.",
                metadata: metadata
            )
        )
    }

    func restoreRadioIfNeeded() {
        refreshRadioWorld()
        guard !radioManager.isPlaying else { return }
        radioManager.restore(
            state: vault.data.radio ?? .off,
            unlockedPackIDs: Set(vault.data.ownedPacks ?? [])
        )
    }

    /// Push the live Nothing-grey and festival state into the radio so banter
    /// conditions (e.g. Penny's festival-only news) respond to the real world.
    /// Cheap; grey/festival change at most daily. Grey is mapped to the 0–100
    /// scale the banter conditions use.
    func refreshRadioWorld() {
        let inputs = sourceInputs
        let hemisphere = Hemisphere.from(latitude: lastAnchorReadingLatitude)
        let greyLevel = NothingTide.greyLevel(
            quietDays: inputs.quietDays,
            narrativeHeat: narrativeEvents.prefix(24).count,
            distressActive: DistressSignals.evaluate(day: today).isActive,
            celebrationGreyShift: Almanac.greyShift(on: Date(), hemisphere: hemisphere) + inputs.nothingGreyOffset
        )
        let festival = Almanac.active(on: Date(), hemisphere: hemisphere) != nil
        radioManager.updateWorldState(
            grey: greyLevel * 33,
            festivalActive: festival,
            pageContext: radioPageContext(now: Date())
        )
    }

    func radioPageContext(now: Date = Date(), calendar: Calendar = .current) -> RadioPageContext {
        let startOfToday = calendar.startOfDay(for: now)
        let recentStart = calendar.date(byAdding: .day, value: -7, to: now) ?? now.addingTimeInterval(-7 * 24 * 3600)
        let recentPages = days
            .flatMap(\.pages)
            .filter { $0.createdAt >= recentStart && $0.createdAt <= now }
            .sorted { $0.createdAt > $1.createdAt }

        let recentTypeCounts = recentPages.reduce(into: [BookPageType: Int]()) { counts, page in
            counts[page.type, default: 0] += 1
        }
        let keptToday = recentPages.filter { $0.createdAt >= startOfToday }.count
        let recentSourceIDs = Set(recentPages.map(\.sourceID))
        let recentTags = Set(recentPages.flatMap(\.tags))
        let weatherTags = RadioPageContext.weatherTags(
            weather: weatherPageSignal,
            enchanted: enchantedWeather
        )
        let activeEvents = sourceInputs.resolvingWorldEvents(for: today, now: now).activeWorldEvents

        return RadioPageContext(
            keptToday: keptToday,
            recentPageTypeCounts: recentTypeCounts,
            recentSourceIDs: recentSourceIDs,
            recentTags: recentTags.union(activeEvents.eventTags),
            lastKeptPageType: recentPages.first?.type,
            weatherTags: weatherTags
        )
    }

    func tuneRadio(stationID: String) {
        refreshRadioWorld()
        radioManager.tune(
            stationID: stationID,
            unlockedPackIDs: Set(vault.data.ownedPacks ?? [])
        )
        vault.data.radio = radioManager.playback
        vault.save()
        surfaceRefreshDate = Date()
    }

    func stopRadio() {
        radioManager.stop()
        vault.data.radio = .off
        vault.save()
        surfaceRefreshDate = Date()
    }

    func handlePendingRadioWidgetCommand() {
        guard didHydrateLaunchState,
              let command = ReEnchantedRadioWidgetCommandStore.load() else { return }
        ReEnchantedRadioWidgetCommandStore.clear(id: command.id)

        switch command.action {
        case .tune:
            guard let stationID = command.stationID else { return }
            tuneRadio(stationID: stationID)
            let station = RadioStationRegistry.station(
                id: stationID,
                unlockedPackIDs: Set(vault.data.ownedPacks ?? [])
            )
            statusMessage = "\(station?.title ?? "The station") is on the air."
        case .stop:
            stopRadio()
            statusMessage = "The radio dial is cold."
        }

        writeWidgetSnapshot()
    }

    func handlePendingCompassWidgetCommand() {
        guard didHydrateLaunchState,
              let command = ReEnchantedCompassWidgetRunStore.loadCommand() else { return }
        ReEnchantedCompassWidgetRunStore.clearCommand(id: command.id)

        switch command.action {
        case .openRun:
            selectedSurface = compassRunSurface()
            statusMessage = "The Wonder Compass is open. Keep one true sentence."
        }

        writeWidgetSnapshot()
    }

    func handlePendingSiriCommand() {
        guard didHydrateLaunchState,
              let command = ReEnchantedSiriCommandStore.load() else { return }
        ReEnchantedSiriCommandStore.clear(id: command.id)

        switch command.action {
        case .capturePage:
            let text = command.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if text.isEmpty {
                statusMessage = "Siri opened the Book, but there was no page text to keep."
            } else {
                keepPlainPage(text: text, media: [])
                statusMessage = "Siri tucked a plain page into the Book."
            }

        case .openArchive:
            selectedSurface = freshManualSurface(for: .inventory)
            isReturnedStacksExpanded = true
            presentStacks()
            statusMessage = "The Stacks are open."

        case .openPage:
            selectedSurface = freshManualSurface(for: .inventory)
            isReturnedStacksExpanded = true
            presentStacks()
            let pageName = command.text?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let pageName, !pageName.isEmpty {
                statusMessage = "The Stacks are open near \(pageName)."
            } else {
                statusMessage = "The Stacks are open near that page."
            }
        }

        writeWidgetSnapshot()
    }

    func handlePendingWidgetDeepLink() {
        guard didHydrateLaunchState,
              let request = ReEnchantedWidgetDeepLinkStore.load(),
              let url = URL(string: request.urlString),
              url.scheme?.lowercased() == "reenchanted" else { return }

        let route = ([url.host].compactMap { $0 } + url.pathComponents.filter { $0 != "/" })
            .map { $0.removingPercentEncoding ?? $0 }
        guard let destination = route.first?.lowercased() else {
            ReEnchantedWidgetDeepLinkStore.clear(id: request.id)
            return
        }

        switch destination {
        case "radio":
            let action = route.dropFirst().first?.lowercased()
            if action == "tune", let stationID = route.dropFirst(2).first {
                tuneRadio(stationID: stationID)
                let station = RadioStationRegistry.station(
                    id: stationID,
                    unlockedPackIDs: Set(vault.data.ownedPacks ?? [])
                )
                statusMessage = "\(station?.title ?? "The station") is on the air."
            } else if action == "stop" {
                stopRadio()
                statusMessage = "The radio dial is cold."
            }
            selectedSurface = freshManualSurface(for: .radio)

        case "compass":
            selectedSurface = compassRunSurface()
            statusMessage = "The Wonder Compass is open. Keep one true sentence."

        case "capture":
            if route.dropFirst().first?.lowercased() == "souvenir" {
                selectedSurface = freshManualSurface(for: .souvenir)
                statusMessage = "The Book is ready for one true sentence."
            }

        case "enchantment":
            let requestedID = route.dropFirst().first
            if let enchantment = glowEnchantmentMenuItems.first(where: { $0.id == requestedID })
                ?? glowEnchantmentMenuItems.first {
                selectedSurface = enchantmentSurface(enchantment)
                statusMessage = "\(enchantment.title) is ready for a photo."
            }

        case "remembered":
            if isMemoryPageLocked(.bookRemembered) {
                showMemoryPageLockedMessage(for: .bookRemembered)
            } else {
                selectedSurface = freshManualSurface(for: .bookRemembered)
            }

        case "glow":
            selectedSurface = freshManualSurface(for: .glowInvitation)

        case "today":
            selectedSurface = surfaces.first

        default:
            if let type = BookPageType.legacyCompatible(rawValue: destination) {
                if isContentPackLocked(type) {
                    selectedSurface = surfaces.first
                } else if isMemoryPageLocked(type) {
                    showMemoryPageLockedMessage(for: type)
                } else {
                    selectedSurface = freshManualSurface(for: type)
                }
            } else {
                selectedSurface = surfaces.first
            }
        }

        ReEnchantedWidgetDeepLinkStore.clear(id: request.id)
        writeWidgetSnapshot()
    }

    @MainActor
    func openManualPage(_ type: BookPageType) async {
        if isContentPackLocked(type) { return }
        if isMemoryPageLocked(type) {
            showMemoryPageLockedMessage(for: type)
            return
        }

        switch type {
        case .narrativeOS:
            if let prepared = generation.preparedStoryPageSurface {
                selectedSurface = prepared
            } else if let draft = storyFieldPreviewSurface {
                await generateAndOpenSurface(draft)
            } else {
                statusMessage = "The Story Field needs one kept thread before it can open a door."
            }
        case .gossip:
            if let prepared = generation.preparedGossipPageSurface {
                selectedSurface = prepared
            } else {
                await generateAndOpenSurface(freshManualSurface(for: .gossip))
            }
        case .note:
            await generateAndOpenSurface(freshStudentNoteDraft())
        case .facultyResearch:
            if generation.preparedFacultyResearchSurface == nil {
                statusMessage = "The faculty folio is asking Gemma to read the clippings..."
                _ = await prepareFacultyResearchPageIfPossible(force: true)
            }
            selectedSurface = generation.preparedFacultyResearchSurface ?? localBrainIssueSurface(
                type: type,
                title: "Faculty Research",
                action: "write a Faculty Research Page"
            )
        case .bookFae:
            await generateAndOpenSurface(freshManualSurface(for: .bookFae))
        case .letter:
            selectedSurface = freshManualSurface(for: .letter)
        case .bookOfYou:
            // The Braiding Table lets the reader braid, re-braid (replace the
            // last), braid another beside it, or open today's braid.
            isBraidingTablePresented = true
        case .bookConnections:
            isConnectionsPresented = true
        case .weather:
            if weatherPageSignal == nil || enchantedWeather == nil {
                statusMessage = "The Weather Page is asking the sky, then Gemma."
                _ = await refreshWeatherSignal(isUserInitiated: true, shouldEnchant: true)
            }
            if weatherPageSignal != nil, enchantedWeather != nil {
                selectedSurface = freshManualSurface(for: type)
            } else {
                selectedSurface = localBrainIssueSurface(
                    type: type,
                    title: "Weather Page",
                    action: "translate the weather"
                )
            }
        default:
            selectedSurface = surface(forManualPageType: type)
        }
    }

    /// Replace the most recent braid with a fresh weave of today's fragments.
    /// (Used by the Braiding Table's "Re-braid the last" action.) Braids first,
    /// then drops the prior braid only once a new one has landed — so a failed
    /// braid never loses the existing page.
    @MainActor
    func reBraidLast() async {
        let priorBraidID = today.bookOfYou?.id
        await braidToday(openWhenComplete: true)
        guard let priorBraidID,
              let newBraid = today.bookOfYou,
              newBraid.id != priorBraidID else { return }
        var day = today
        day.pages.removeAll { $0.type == .bookOfYou && $0.id == priorBraidID }
        persist(day: day, message: "The last braid was re-woven.")
    }

    func localBrainIssueSurface(type: BookPageType, title: String, action: String) -> SurfacePage {
        let detail = localBrainTelemetry.lastError ?? localBrainTelemetry.currentWorkStatus ?? "The local model did not return a page."
        return SurfacePage(
            id: "local-brain-issue-\(type.rawValue)-\(Int(Date().timeIntervalSince1970))",
            type: type,
            sourceID: "local-brain",
            intent: .reflect,
            renderStyle: .promptCard,
            score: 1,
            reason: "The local model did not finish this generated Page.",
            prompt: "\(title) could not be generated yet.",
            detail: detail,
            payload: BookPagePayload(
                headline: "\(title) Still Waking",
                body: "Gemma tried to \(action), but did not finish.\n\n\(detail)",
                metadata: [
                    "source": "local-brain",
                    "status": "failed",
                    "pageType": type.rawValue
                ]
            )
        )
    }

    func readingSurface(forWonderCompassSectionID sectionID: String) -> SurfacePage {
        let snippet = BookReferenceCatalog.wonderCompass.first { $0.id == sectionID }
            ?? BookReferenceCatalog.wonderCompass.first
            ?? ReferenceSnippet(
                id: "wonder-compass-empty",
                sourceID: "wonder-compass",
                title: "The Wonder Compass",
                prompt: "Read the source text.",
                body: "The Wonder Compass text is not bundled in this build.",
                tags: ["wonder-compass"]
            )
        let source = BookPageSourceRegistry.source(for: .wonderCompass)
        return SurfacePage(
            id: "\(source.id)-reading-\(snippet.id)",
            type: .wonderCompass,
            sourceID: source.id,
            intent: .importReference,
            renderStyle: .quoteCard,
            score: 70,
            reason: "Opened from the Wonder Compass table of contents.",
            prompt: "Reading Page",
            detail: snippet.title,
            payload: BookPagePayload(
                headline: snippet.title,
                body: snippet.body,
                metadata: [
                    "source": source.id,
                    "snippetID": snippet.id,
                    "tags": snippet.tags.joined(separator: ","),
                    "readingPage": "true"
                ]
            )
        )
    }

    func openKeptPage(_ page: BookPage) {
        BookFeedback.play(.openPage)
        selectedSurface = keptSurface(for: page)
    }

    @ViewBuilder
    func latestBraidSharePanel(for page: BookPage) -> some View {
        let surface = keptSurface(for: page)
        let details = BraidPageDetails.details(for: page)
        let shareText = "\(surface.prompt)\n\n\(surface.payload.body)"
        let isToday = Calendar.current.isDateInToday(page.createdAt)
        let title = isToday ? "Tonight's Book of You is illuminated" : "Last night's Book of You is waiting"
        let subtitle = "Share from Apple's sheet, bind a private PDF, or open the full page."
        let wordCount = details.body.split { !$0.isLetter && !$0.isNumber }.count
        let pressedURL = latestBraidSharePageID == page.id
            && latestBraidShareCardURL.map { FileManager.default.fileExists(atPath: $0.path) } == true
            ? latestBraidShareCardURL
            : nil
        let revealURL = latestBraidRevealPageID == page.id
            && latestBraidRevealVideoURL.map { FileManager.default.fileExists(atPath: $0.path) } == true
            ? latestBraidRevealVideoURL
            : nil
        let pdfURL = latestBraidPDFPageID == page.id
            && latestBraidPDFURL.map { FileManager.default.fileExists(atPath: $0.path) } == true
            ? latestBraidPDFURL
            : nil
        let artifact = BookOfYouShareArtifact.make(from: surface)

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(BookPalette.lampGold)
                    .frame(width: 30, height: 30)
                    .background(BookPalette.lampGold.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(BookPalette.nightText)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(BookPalette.nightText.opacity(0.70))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let artifact {
                BookOfYouPressedPageSpotlight(
                    artifact: artifact,
                    isWorking: isPressingLatestBraidShareCard || isPressingLatestBraidRevealVideo
                )
            }

            HStack(spacing: 8) {
                bookOfYouArrivalBadge("bound", systemImage: "seal.fill")
                bookOfYouArrivalBadge("\(wordCount) words", systemImage: "text.alignleft")
                if !page.mediaAssets.isEmpty {
                    bookOfYouArrivalBadge("\(page.mediaAssets.count) keepsakes", systemImage: "photo.stack")
                }
            }

            HStack(spacing: 8) {
                Button {
                    openKeptPage(page)
                } label: {
                    bookOfYouArrivalActionLabel("Open", systemImage: "book.pages")
                }
                .buttonStyle(.plain)
                .foregroundStyle(BookPalette.lampGold)
                .background(BookPalette.lampGold.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                Menu {
                    if let pressedURL {
                        ShareLink(item: pressedURL) {
                            Label("Share pressed page", systemImage: "square.and.arrow.up")
                        }
                    } else if artifact != nil {
                        Button {
                            Task { await prepareLatestBraidShareCard(for: page, force: true) }
                        } label: {
                            Label(isPressingLatestBraidShareCard ? "Pressing page..." : "Prepare pressed page", systemImage: "wand.and.sparkles")
                        }
                        .disabled(isPressingLatestBraidShareCard)
                    }

                    if let revealURL {
                        ShareLink(item: revealURL) {
                            Label("Share reveal video", systemImage: "play.rectangle")
                        }
                    } else if artifact != nil {
                        Button {
                            Task { await prepareLatestBraidRevealVideo(for: page, force: true) }
                        } label: {
                            Label(isPressingLatestBraidRevealVideo ? "Pressing reveal..." : "Prepare reveal video", systemImage: "play.rectangle")
                        }
                        .disabled(isPressingLatestBraidRevealVideo || isPressingLatestBraidShareCard)
                    }

                    Divider()

                    ShareLink(item: shareText) {
                        Label("Share text", systemImage: "text.quote")
                    }
                } label: {
                    bookOfYouArrivalActionLabel("Share", systemImage: "square.and.arrow.up")
                }
                .foregroundStyle(BookPalette.lampGold)
                .background(BookPalette.lampGold.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                Menu {
                    if let pdfURL {
                        ShareLink(item: pdfURL) {
                            Label("Share full braid PDF", systemImage: "doc.richtext")
                        }
                    } else {
                        Button {
                            prepareLatestBraidPDF(for: page, force: true)
                        } label: {
                            Label(isBindingLatestBraidPDF ? "Binding PDF..." : "Bind full braid PDF", systemImage: "doc.richtext")
                        }
                        .disabled(isBindingLatestBraidPDF)
                    }
                } label: {
                    bookOfYouArrivalActionLabel("Bind", systemImage: "seal")
                }
                .foregroundStyle(BookPalette.teal)
                .background(BookPalette.teal.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            if latestBraidSharePageID == page.id, !latestBraidShareMessage.isEmpty {
                Text(latestBraidShareMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BookPalette.nightText.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(BookPalette.nightPanel.opacity(0.92), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.32), lineWidth: 1)
        }
        .task(id: page.id) {
            await prepareLatestBraidShareCard(for: page, force: false)
        }
    }

    private func bookOfYouArrivalActionLabel(_ title: String, systemImage: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.callout.weight(.bold))
            Text(title)
                .font(.caption2.weight(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
    }

    private func bookOfYouArrivalBadge(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption2.weight(.black))
            .foregroundStyle(BookPalette.lampGold.opacity(0.86))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(BookPalette.lampGold.opacity(0.10), in: Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous)
                    .stroke(BookPalette.lampGold.opacity(0.22), lineWidth: 1)
            }
    }

    /// Presents an edition-binding celebration. The haptic fires inside the
    /// ceremony, timed to the seal, so it isn't played here.
    @MainActor
    func presentEditionCelebration(_ info: EditionCelebrationInfo) {
        withAnimation(.easeIn(duration: 0.3)) { editionCelebration = info }
    }

    /// The Monthly Binding's own ceremonial celebration — the month sewn into a PDF.
    @MainActor
    func celebrateMonthlyBinding(monthName: String, pageCount: Int) {
        presentEditionCelebration(
            EditionCelebrationInfo(
                kind: .sewn,
                coverKicker: "THE BOOK OF YOU",
                coverTitle: monthName,
                headline: "\(monthName) is bound",
                subtitle: "\(pageCount) \(pageCount == 1 ? "page" : "pages") sewn between covers."
            )
        )
    }

    /// The print-ready export's own ceremonial celebration — a month set for the press.
    @MainActor
    func celebratePrintReady(monthName: String, subtitle: String) {
        presentEditionCelebration(
            EditionCelebrationInfo(
                kind: .press,
                coverKicker: "READY FOR THE PRESS",
                coverTitle: monthName,
                headline: "\(monthName) is ready for the press",
                subtitle: subtitle
            )
        )
    }

    /// Fires the first-edition celebration owed after the Standing Order paywall
    /// closes, so onboarding ends on the peak rather than the offer.
    @MainActor
    func firePendingFirstEditionCelebration() {
        guard let readerName = pendingFirstEditionReaderName else { return }
        pendingFirstEditionReaderName = nil
        // Let the paywall sheet finish dismissing before the ceremony rises.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            celebrateFirstEdition(readerName: readerName)
        }
    }

    /// The onboarding finale — the reader's own first edition, bound. The last
    /// beat of onboarding, shown after any Standing Order offer has closed.
    @MainActor
    func celebrateFirstEdition(readerName: String) {
        let owner = readerName.trimmingCharacters(in: .whitespacesAndNewlines)
        presentEditionCelebration(
            EditionCelebrationInfo(
                kind: .firstEdition,
                coverKicker: owner.isEmpty ? "FIRST EDITION" : "\(owner.uppercased())\u{2019}S FIRST EDITION",
                coverTitle: "The First Door",
                headline: owner.isEmpty ? "Your first edition is bound" : "\(owner), your first edition is bound",
                subtitle: "One true thing, kept before anyone explained keeping."
            )
        )
    }

    @MainActor
    func celebrateBookOfYouCompletion(page: BookPage) {
        latestBraidSharePageID = page.id
        latestBraidShareCardURL = nil
        latestBraidRevealPageID = page.id
        latestBraidRevealVideoURL = nil
        latestBraidPDFPageID = page.id
        latestBraidPDFURL = nil
        latestBraidShareMessage = "Bound. The pressed page is being illuminated for sharing."
        keepInkBurstText = "BOUND"
        keepInkBurstTrigger += 1
    }

    @MainActor
    func prepareLatestBraidShareCard(for page: BookPage, force: Bool = false) async {
        let surface = keptSurface(for: page)
        if latestBraidSharePageID != page.id {
            latestBraidSharePageID = page.id
            latestBraidShareCardURL = nil
            latestBraidShareMessage = ""
            latestBraidRevealPageID = nil
            latestBraidRevealVideoURL = nil
            latestBraidPDFPageID = nil
            latestBraidPDFURL = nil
        }
        guard !isPressingLatestBraidShareCard else { return }
        guard force || latestBraidShareCardURL == nil else { return }
        guard let artifact = BookOfYouShareArtifact.make(from: surface) else {
            latestBraidShareMessage = "This braid can still be shared as text."
            return
        }
        isPressingLatestBraidShareCard = true
        if force {
            latestBraidShareMessage = "The Book is pressing one safe page for the outside world."
        }
        defer { isPressingLatestBraidShareCard = false }
        latestBraidSharePageID = page.id
        latestBraidShareCardURL = BookOfYouShareCardRenderer.render(artifact: artifact)
        latestBraidShareMessage = latestBraidShareCardURL == nil
            ? "The page did not finish pressing. Text sharing still works."
            : "Ready to share. The full braid stays private."
        if force, latestBraidShareCardURL != nil {
            BookFeedback.play(.braidComplete)
        }
    }

    @MainActor
    func prepareLatestBraidRevealVideo(for page: BookPage, force: Bool = false) async {
        let surface = keptSurface(for: page)
        if latestBraidRevealPageID != page.id {
            latestBraidRevealPageID = page.id
            latestBraidRevealVideoURL = nil
        }
        guard !isPressingLatestBraidRevealVideo else { return }
        guard force || latestBraidRevealVideoURL == nil else { return }
        guard let artifact = BookOfYouShareArtifact.make(from: surface) else {
            latestBraidShareMessage = "This braid can still be shared as text."
            return
        }

        isPressingLatestBraidRevealVideo = true
        latestBraidSharePageID = page.id
        latestBraidShareMessage = "The Book is pressing a short reveal for Stories."
        defer { isPressingLatestBraidRevealVideo = false }

        latestBraidRevealVideoURL = await BookOfYouPageRevealVideoRenderer.render(artifact: artifact)
        latestBraidShareMessage = latestBraidRevealVideoURL == nil
            ? "The reveal did not finish pressing. The still page is ready to share."
            : "Reveal ready. The full braid stays private."
        if latestBraidRevealVideoURL != nil {
            BookFeedback.play(.braidComplete)
        }
    }

    @MainActor
    func prepareLatestBraidPDF(for page: BookPage, force: Bool = false) {
        let surface = keptSurface(for: page)
        if latestBraidPDFPageID != page.id {
            latestBraidPDFPageID = page.id
            latestBraidPDFURL = nil
        }
        guard !isBindingLatestBraidPDF else { return }
        guard force || latestBraidPDFURL == nil else { return }

        isBindingLatestBraidPDF = true
        latestBraidSharePageID = page.id
        latestBraidShareMessage = "The Book is binding the full braid as a PDF."
        defer { isBindingLatestBraidPDF = false }

        latestBraidPDFURL = BookOfYouPDFRenderer.render(page: page, surface: surface)
        latestBraidShareMessage = latestBraidPDFURL == nil
            ? "The PDF did not finish binding. Text sharing still works."
            : "Full braid PDF ready. Share it only where you mean to."
        if latestBraidPDFURL != nil {
            BookFeedback.play(.braidComplete)
        }
    }

    func keptSurface(for page: BookPage) -> SurfacePage {
        let text = page.userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = text.isEmpty ? page.promptText : text
        let source = BookPageSourceRegistry.source(id: page.sourceID, fallbackType: page.type)
        let braidDetails = page.type == .bookOfYou ? BraidPageDetails.details(for: page) : nil
        let title = braidDetails?.title ?? page.type.title
        let displayBody = braidDetails?.body ?? body
        let prompt = page.promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? title
            : page.promptText

        var metadata = [
            "source": source.id,
            "keptPageID": page.id,
            "keptPage": "true",
            "tags": page.tags.joined(separator: ",")
        ]
        if let artifact = page.tarotReadingArtifact,
           let data = try? JSONEncoder().encode(artifact),
           let encoded = String(data: data, encoding: .utf8) {
            metadata[TarotReadingArtifact.metadataKey] = encoded
            metadata["tarotSpread"] = artifact.spread.rawValue
            metadata["tarotDeckVersion"] = artifact.deckVersion
            metadata["tarotAuroraReading"] = artifact.auroraReading?.isEmpty == false ? "true" : "false"
            metadata["tarotContextSourceCount"] = "\(artifact.contextReceipt?.sources.count ?? 0)"
            metadata["tarotContextEdgeCount"] = "\(artifact.contextReceipt?.edges.count ?? 0)"
            metadata["tarotRetrievalMode"] = artifact.contextReceipt?.retrievalMode ?? "cards-only"
            if let receipt = artifact.contextReceipt {
                metadata["tarotContextSourceIDs"] = receipt.sources.map(\.referenceID).joined(separator: ",")
                metadata["tarotContextEdgeKinds"] = Array(Set(receipt.edges.map(\.kind))).sorted().joined(separator: ",")
            }
        }
        if page.type == .letter {
            metadata["letterProse"] = displayBody
            metadata["proseStatus"] = "kept"
            metadata["playerReply"] = page.playerReply
            if !page.playerReply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                metadata["letterSealed"] = "true"
            }
            if let senderID = page.tags.first(where: { $0.hasPrefix("sender:") })?.dropFirst("sender:".count) {
                metadata["senderID"] = String(senderID)
            }
            if let senderName = letterSenderName(from: page) {
                metadata["senderName"] = senderName
            }
        } else if page.type == .note {
            metadata["noteProse"] = displayBody
            metadata["proseStatus"] = "kept"
            metadata["playerReply"] = page.playerReply
            if !page.playerReply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                metadata["noteReplied"] = "true"
            }
            if let senderID = page.tags.first(where: { $0.hasPrefix("sender:") })?.dropFirst("sender:".count) {
                metadata["senderID"] = String(senderID)
            }
            if let senderName = noteSenderName(from: page) {
                metadata["senderName"] = senderName
            }
        }
        metadata.merge(keptPageMediaMetadata(for: page), uniquingKeysWith: { current, _ in current })

        return SurfacePage(
            id: "kept-\(page.id)",
            type: page.type,
            sourceID: source.id,
            intent: .importReference,
            renderStyle: .quoteCard,
            score: 80,
            reason: "This Page is already kept in the Book.",
            prompt: prompt,
            detail: "Kept \(page.createdAt.formatted(date: .abbreviated, time: .omitted))",
            payload: BookPagePayload(
                headline: title,
                body: displayBody,
                metadata: metadata
            )
        )
    }

    func letterSenderName(from page: BookPage) -> String? {
        let candidates = [page.promptText, page.tags.first(where: { $0.hasPrefix("sender-name:") })]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty }
        for candidate in candidates {
            if candidate.hasPrefix("sender-name:") {
                return String(candidate.dropFirst("sender-name:".count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .nonEmpty
            }
            if let range = candidate.range(of: "letter from ", options: [.caseInsensitive]) {
                return String(candidate[range.upperBound...])
                    .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
                    .nonEmpty
            }
        }
        return nil
    }

    func noteSenderName(from page: BookPage) -> String? {
        let candidates = [page.promptText, page.tags.first(where: { $0.hasPrefix("sender-name:") })]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty }
        for candidate in candidates {
            if candidate.hasPrefix("sender-name:") {
                return String(candidate.dropFirst("sender-name:".count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .nonEmpty
            }
            if let range = candidate.range(of: "note from ", options: [.caseInsensitive]) {
                return String(candidate[range.upperBound...])
                    .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
                    .nonEmpty
            }
        }
        return nil
    }

    func markLovedBraid(pageID: String) -> String {
        updateBraidFeedback(
            pageID: pageID,
            tagsToAdd: [BraidLearningLoop.lovedItTag],
            message: "The Book marked this as a true page. It will not tug the next Braid away from what worked."
        )
    }

    func markBraidMissedMe(pageID: String) -> String {
        updateBraidFeedback(
            pageID: pageID,
            tagsToAdd: [BraidLearningLoop.missedMeTag, BraidLearningLoop.improvedTag],
            message: nil
        )
    }

    func recordBookNoticeFeedback(surface: SurfacePage, choice: BookNoticeFeedbackChoice) -> String {
        let action: ReaderLearningAction
        let observationStatus: BookObservationStatus
        let evidence: String
        let message: String

        switch choice {
        case .trueReading:
            action = .loved
            observationStatus = .confirmed
            evidence = "Reader confirmed this Book Notices reading."
            message = "Marked true. The Book will trust this kind of noticing a little more."
            vault.data.bookObservations = BookObservationLedger.recording(
                surface: surface,
                status: .confirmed,
                in: vault.data.bookObservations ?? []
            )
        case .notQuite:
            action = .missed
            observationStatus = .notQuite
            evidence = "Reader said this Book Notices reading was not quite right."
            message = "Marked not quite. This exact reading will not return; new evidence may ask a better question."
            vault.data.bookObservations = BookObservationLedger.recording(
                surface: surface,
                status: .questioned,
                in: vault.data.bookObservations ?? []
            )
        case .doNotReadThisWay:
            action = .dismissed
            observationStatus = .doNotRead
            evidence = "Reader asked the Book not to read them this way."
            message = "Marked off-limits. The Book will not bring this reading back."
            vault.data.bookObservations = BookObservationLedger.recording(
                surface: surface,
                status: .forbidden,
                in: vault.data.bookObservations ?? []
            )
            if let key = BookObservationLedger.key(for: surface) {
                var boundaries = vault.data.bookReadingBoundaries ?? []
                if !boundaries.contains(where: { $0.id == key }) {
                    boundaries.append(BookReadingBoundary(id: key, createdAt: Date()))
                    vault.data.bookReadingBoundaries = Array(boundaries.suffix(200))
                }
            }
        }

        let now = Date()
        recordReaderLearning(surface: surface, action: action, now: now, evidence: evidence, saveImmediately: false)
        vault.data.bookObservations = BookObservationLedger.recording(
            surface: surface,
            status: observationStatus,
            in: vault.data.bookObservations ?? [],
            now: now
        )
        if observationStatus == .doNotRead,
           let key = BookObservationLedger.key(for: surface),
           !(vault.data.bookReadingBoundaries ?? []).contains(where: { $0.id == key }) {
            vault.data.bookReadingBoundaries = Array(
                ((vault.data.bookReadingBoundaries ?? []) + [BookReadingBoundary(id: key, createdAt: now)])
                    .suffix(200)
            )
        }
        if surface.payload.metadata["magicMoment"] == "true" {
            let key = BookObservationLedger.key(for: surface) ?? surface.id
            vault.data.magicMoment = MagicMomentGovernor.consuming(
                vault.data.magicMoment ?? MagicMomentState(),
                key: key,
                now: now
            )
        }
        vault.save()
        statusMessage = message
        surfaceRefreshDate = Date()
        return message
    }

    func handleBookNoticeAdaptiveAction(surface: SurfacePage, action: BookNoticeAdaptiveAction) -> String {
        switch action {
        case .scrapbookPage:
            recordReaderLearning(surface: surface, action: .loved, evidence: "Reader chose to scrapbook this Notice thread.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                selectedSurface = nil
                isPagewrightPresented = true
            }
            return "Opening the Scrapbook Page maker."
        case .bindWeeklyIssue:
            recordReaderLearning(surface: surface, action: .kept, evidence: "Reader chose to bind the week from a Notice.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                selectedSurface = nil
                exportWeeklyIssuePDF()
            }
            return currentWeeklyIssue == nil
                ? "The Book will check whether a weekly issue is ready."
                : "Binding this week."
        case .letPatternRest:
            return recordBookNoticeFeedback(surface: surface, choice: .doNotReadThisWay)
        case .openPersonThread:
            switch confirmPersonThread(from: surface) {
            case .missing:
                return "The Book reached for the name, but the page had let it go."
            case .already(let name):
                return "A thread for \(name) is already in the Book's keeping."
            case .opened(let name):
                recordReaderLearning(surface: surface, action: .loved, evidence: "Reader opened a thread for a recurring name.")
                return "A thread for \(name) is open. I will keep their pages the way I keep your places. If you ever want them in the story too, that door is yours."
            }
        case .confirmPersonContext:
            let slug = surface.payload.metadata["personSlug"] ?? ""
            let kind = surface.payload.metadata["personContextKind"] ?? ""
            let value = surface.payload.metadata["personContextValue"] ?? ""
            guard !slug.isEmpty, !kind.isEmpty, !value.isEmpty else {
                return "The relationship clue slipped before the Book could press it."
            }
            var ledger = vault.data.people ?? PeopleLedger()
            guard let index = ledger.threads.firstIndex(where: { $0.id == "person:\(slug)" }) else {
                return "That person's thread is no longer open."
            }
            var profile = ledger.threads[index].relationship ?? PersonRelationshipProfile()
            switch PeopleOfTheBook.RelationshipHypothesis.Kind(rawValue: kind) {
            case .role:
                profile.roles.append(value)
            case .setting:
                guard let setting = PersonRelationshipSetting(rawValue: value) else {
                    return "The Book could not read that setting clearly enough to keep it."
                }
                profile.settings.append(setting)
            case .channel:
                guard let channel = PersonContactChannel(rawValue: value) else {
                    return "The Book could not read that channel clearly enough to keep it."
                }
                profile.channels.append(channel)
            case .sharedInterest:
                profile.sharedInterests.append(value)
            case .none:
                return "The Book could not read that relationship clue clearly enough to keep it."
            }
            ledger.threads[index].relationship = PeopleOfTheBook.readerConfirmedProfile(profile, onDay: today.id)
            vault.data.people = ledger
            vault.save()
            recordReaderLearning(surface: surface, action: .loved, evidence: "Reader confirmed a sourced relationship-context question.")
            surfaceRefreshDate = Date()
            return "Kept as something you confirmed — not something I guessed."
        case .openPeopleOfTheBook:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                selectedSurface = nil
                isPeopleOfTheBookPresented = true
            }
            return "Opening the People of the Book so you can teach me what is true."
        case .writePersonIntoStory:
            // The crossing: make sure the witness thread exists (the real
            // pages keep accruing to it), then mint the linked cast member.
            if case .missing = confirmPersonThread(from: surface) {
                return "The Book reached for the name, but the page had let it go."
            }
            let slug = surface.payload.metadata["personSlug"] ?? ""
            let message = writeThreadIntoStory(slug: slug)
            recordReaderLearning(surface: surface, action: .loved, evidence: "Reader wrote a recurring name into the story.")
            return message
        case .letPersonRest:
            let slug = surface.payload.metadata["personSlug"] ?? ""
            guard !slug.isEmpty else {
                return "The Book reached for the name, but the page had let it go."
            }
            var ledger = vault.data.people ?? PeopleLedger()
            if !ledger.restingNames.contains(slug) {
                ledger.restingNames.append(slug)
            }
            vault.data.people = ledger
            vault.save()
            return "The name can rest. I will not ask about it again — unless you bring it to me yourself."
        case .restPersonThread:
            let slug = surface.payload.metadata["personSlug"] ?? ""
            var ledger = vault.data.people ?? PeopleLedger()
            guard let index = ledger.threads.firstIndex(where: { $0.id == "person:\(slug)" }) else {
                return "That thread had already slipped from the Book's keeping."
            }
            ledger.threads[index] = PeopleOfTheBook.rested(ledger.threads[index], onDay: today.id)
            vault.data.people = ledger
            vault.save()
            return "The thread is resting. I will keep its pages gently, and say no more."
        }
    }

    private enum PersonThreadConfirmation {
        case missing
        case already(String)
        case opened(String)
    }

    /// Opens the witness thread a suggestion notice describes, if it is not
    /// already kept. Shared by "open a thread" and the story crossing.
    private func confirmPersonThread(from surface: SurfacePage) -> PersonThreadConfirmation {
        let name = surface.payload.metadata["personName"] ?? ""
        let slug = surface.payload.metadata["personSlug"] ?? ""
        guard !name.isEmpty, !slug.isEmpty else { return .missing }
        var ledger = vault.data.people ?? PeopleLedger()
        if ledger.thread(slug: slug) != nil { return .already(name) }
        let suggestion = PeopleOfTheBook.PersonSuggestion(
            name: name,
            slug: slug,
            mentionPageCount: Int(surface.payload.metadata["personMentions"] ?? "") ?? 0,
            distinctDayCount: Int(surface.payload.metadata["personDays"] ?? "") ?? 0,
            firstDayID: surface.payload.metadata["personFirstDay"] ?? today.id,
            lastDayID: surface.payload.metadata["personLastDay"] ?? today.id,
            evidencePageIDs: (surface.payload.metadata["evidencePageIDs"] ?? "")
                .split(separator: ",").map(String.init),
            sampleQuote: ""
        )
        ledger.restingNames.removeAll { $0 == slug }
        ledger.threads.append(PeopleOfTheBook.confirmed(suggestion, onDay: today.id))
        vault.data.people = ledger
        vault.save()
        return .opened(name)
    }

    // MARK: - People of the Book — thread-centric actions (the flyleaf)
    //
    // The suggestion notice and the People flyleaf both act on threads by
    // slug, so the crossing / rest / wake / introduce logic lives here once.

    /// The crossing by slug: mint (or reuse) the linked cast member so a real
    /// person walks the halls. The witness thread is untouched otherwise.
    @discardableResult
    func writeThreadIntoStory(slug: String) -> String {
        var ledger = vault.data.people ?? PeopleLedger()
        guard let index = ledger.threads.firstIndex(where: { $0.id == "person:\(slug)" }) else {
            return "The thread slipped before the ink dried — try again."
        }
        let thread = ledger.threads[index]
        if let existing = thread.castMemberID,
           customCastMembers.contains(where: { $0.id == existing }) {
            return "\(thread.name) already walks the halls."
        }
        let who = thread.readerWords.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = who.isEmpty
            ? "Drawn from the reader's kept pages about \(thread.name). The story may imagine them from here; the kept pages remain the reader's record of the real one."
            : "\(who) Drawn from the reader's kept pages about \(thread.name); the story may imagine them from here, while the kept pages remain the reader's record of the real one."
        let draft = CustomCastMemberDraft(
            name: thread.name,
            kind: .character,
            meaning: who.isEmpty ? "A real person from the reader's days, written into the story by the reader's own hand." : who,
            description: description,
            traits: [],
            beliefs: [],
            goals: [],
            tags: ["people-of-the-book", "real-person", "reader-invited"],
            imageData: nil,
            startingGlow: 30
        )
        guard let castID = saveCustomCastMember(draft) else {
            return "The Cast page would not take the name yet — try again in a moment."
        }
        ledger.threads[index] = PeopleOfTheBook.invitedIntoStory(thread, castMemberID: castID, onDay: today.id)
        vault.data.people = ledger
        vault.save()
        surfaceRefreshDate = Date()
        return "\(thread.name) steps into the story — the halls will learn their name. Your thread still keeps the real pages, in your own words."
    }

    /// The reader's own line about who a person is (`readerWords`), which also
    /// colors the cast member if they are later written into the story.
    func updatePersonWords(slug: String, words: String) {
        var ledger = vault.data.people ?? PeopleLedger()
        guard let index = ledger.threads.firstIndex(where: { $0.id == "person:\(slug)" }) else { return }
        ledger.threads[index].readerWords = words.trimmingCharacters(in: .whitespacesAndNewlines)
        vault.data.people = ledger
        vault.save()
    }

    /// Relationship context is reader-confirmed evidence, separate from the
    /// fictional Cast crossing. It changes which real-world favors fit this
    /// person without making a claim about what that person thinks or feels.
    func updatePersonRelationship(slug: String, profile: PersonRelationshipProfile) {
        var ledger = vault.data.people ?? PeopleLedger()
        guard let index = ledger.threads.firstIndex(where: { $0.id == "person:\(slug)" }) else { return }
        let confirmed = PeopleOfTheBook.readerConfirmedProfile(profile, onDay: today.id)
        ledger.threads[index].relationship = confirmed.isEmpty ? nil : confirmed
        vault.data.people = ledger
        vault.save()
        surfaceRefreshDate = Date()
    }

    func restPersonThread(slug: String) {
        var ledger = vault.data.people ?? PeopleLedger()
        guard let index = ledger.threads.firstIndex(where: { $0.id == "person:\(slug)" }) else { return }
        ledger.threads[index] = PeopleOfTheBook.rested(ledger.threads[index], onDay: today.id)
        vault.data.people = ledger
        vault.save()
        surfaceRefreshDate = Date()
    }

    /// Wake a resting thread: the Book resumes noticing it (and may remark on
    /// its quiets and returns again).
    func wakePersonThread(slug: String) {
        var ledger = vault.data.people ?? PeopleLedger()
        guard let index = ledger.threads.firstIndex(where: { $0.id == "person:\(slug)" }) else { return }
        ledger.threads[index].resting = false
        ledger.threads[index].restDay = nil
        vault.data.people = ledger
        vault.save()
        surfaceRefreshDate = Date()
    }

    /// The reader introduces someone the Book has not suggested — the
    /// deliberate front door. Reuses any pages already naming them so the
    /// thread starts with honest history.
    @discardableResult
    func introducePerson(name: String, words: String, contactIdentifier: String? = nil) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let slug = PeopleOfTheBook.slug(for: trimmed)
        guard !slug.isEmpty else { return "" }
        var ledger = vault.data.people ?? PeopleLedger()
        if let index = ledger.threads.firstIndex(where: { $0.id == "person:\(slug)" }) {
            // Already known — just update who they are and wake if resting.
            if !words.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ledger.threads[index].readerWords = words.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let contactIdentifier, !contactIdentifier.isEmpty {
                var profile = ledger.threads[index].relationship ?? PersonRelationshipProfile()
                profile.contactIdentifier = contactIdentifier
                ledger.threads[index].relationship = PeopleOfTheBook.readerConfirmedProfile(profile, onDay: today.id)
            }
            ledger.threads[index].resting = false
            vault.data.people = ledger
            vault.save()
            return "\(trimmed) is already in your book."
        }
        // Count any existing mentions so the thread starts honest.
        let probe = PersonThread(
            id: "person:\(slug)", name: trimmed, introducedDay: today.id,
            readerWords: "", firstMentionDay: today.id, lastMentionDay: today.id, mentionPageCount: 0
        )
        let mentions = PeopleOfTheBook.mentions(of: probe, in: days)
        let mentionDayIDs = mentions.pageDates.map { BookDay.id(for: $0) }
        var thread = PersonThread(
            id: "person:\(slug)",
            name: trimmed,
            introducedDay: today.id,
            readerWords: words.trimmingCharacters(in: .whitespacesAndNewlines),
            firstMentionDay: mentionDayIDs.first ?? today.id,
            lastMentionDay: mentionDayIDs.last ?? today.id,
            mentionPageCount: mentions.pageDates.count
        )
        if let contactIdentifier, !contactIdentifier.isEmpty {
            var profile = PersonRelationshipProfile()
            profile.contactIdentifier = contactIdentifier
            thread.relationship = PeopleOfTheBook.readerConfirmedProfile(profile, onDay: today.id)
        }
        ledger.restingNames.removeAll { $0 == slug }
        ledger.threads.append(thread)
        vault.data.people = ledger
        vault.save()
        surfaceRefreshDate = Date()
        return "\(trimmed) is in your book now. I will keep their pages — and if you want them in the story, that door is yours."
    }

    /// Un-decline a name the reader had let rest, so the Book may suggest it
    /// again on new evidence.
    func wakeDeclinedName(slug: String) {
        var ledger = vault.data.people ?? PeopleLedger()
        ledger.restingNames.removeAll { $0 == slug }
        vault.data.people = ledger
        vault.save()
    }

    func updateBraidFeedback(pageID: String, tagsToAdd: Set<String>, message: String?) -> String {
        guard let dayIndex = days.firstIndex(where: { day in
            day.pages.contains { $0.id == pageID && $0.type == .bookOfYou }
        }),
              let pageIndex = days[dayIndex].pages.firstIndex(where: { $0.id == pageID }) else {
            BookFeedback.play(.error)
            statusMessage = "The Book reached for that page, but it had already moved."
            return "The Book reached for that page, but it had already moved."
        }

        var day = days[dayIndex]
        var page = day.pages[pageIndex]
        let lesson = message ?? BraidLearningLoop.publicLesson(for: page)
        var tags = Set(page.tags)
        tags.formUnion(tagsToAdd)
        page.tags = tags.sorted()
        day.pages[pageIndex] = page
        persist(day: day, message: lesson)
        if tagsToAdd.contains(BraidLearningLoop.missedMeTag) {
            recordReaderLearning(page: page, dayID: day.id, action: .missed, evidence: lesson)
        } else if tagsToAdd.contains(BraidLearningLoop.lovedItTag) {
            recordReaderLearning(page: page, dayID: day.id, action: .loved, evidence: lesson)
        }

        if selectedSurface?.payload.metadata["keptPageID"] == pageID {
            selectedSurface = keptSurface(for: page)
        }

        surfaceRefreshDate = Date()
        return lesson
    }

    func keptPageMediaMetadata(for page: BookPage) -> [String: String] {
        var metadata: [String: String] = [:]
        for asset in page.mediaAssets where !asset.isPagewrightPDF {
            switch asset.kind {
            case .bundledImage:
                metadata["assetName"] = asset.reference
                metadata["imageAssetKind"] = asset.kind.rawValue
                metadata["imageAssetReference"] = asset.reference
            case .renderedImageFile:
                metadata["renderedPreviewPath"] = asset.reference
                metadata["proofImagePath"] = asset.reference
                metadata["proofCaption"] = asset.caption
            case .photoLibraryAsset:
                metadata["assetLocalIdentifier"] = asset.reference
            case .audioFile:
                metadata["keptVoicePath"] = asset.reference
            }
            if !asset.caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                metadata["imageCaption"] = asset.caption
            }
        }
        if let pdf = page.mediaAssets.first(where: \.isPagewrightPDF) {
            metadata["pagewrightPDFPath"] = pdf.reference
        }
        return metadata
    }

    func resetTransientWorkStateForBackgrounding() {
        let hasInFlightWork = localBrainTelemetry.isWorking
            || generation.isBraiding
            || generation.isPreparingStoryPage
            || generation.isPreparingGossipPage
            || generation.isPreparingFacultyResearchPage
            || generation.isPreparingLetterPage
            || generation.isPreparingAutomaticIllumination
            || generation.isPreparingBleedEdition
        guard !hasInFlightWork else {
            AppMemoryLedger.record("backgrounded-with-work-in-flight")
            return
        }

        localBrainTelemetry.resetTransientWork()
        localBrainProgress.reset()
        generation.isBraiding = false
        generation.braidingStartedAt = nil
        generation.isPreparingStoryPage = false
        generation.isPreparingGossipPage = false
        generation.isPreparingFacultyResearchPage = false
        generation.isPreparingLetterPage = false
        generation.isPreparingAutomaticIllumination = false
    }

    @ViewBuilder
    var localBrainWorkShelf: some View {
        if localBrainTelemetry.isWorking {
            LiveLocalBrainWorkingStatusCard(
                progress: localBrainProgress,
                label: localBrainTelemetry.currentLabel,
                startedAt: localBrainTelemetry.startedAt,
                queuedCount: localBrainTelemetry.currentQueuedCount,
                presentation: .shelf
            )
            .transition(.opacity.combined(with: .move(edge: .top)))
        } else if generation.isBraiding {
            BraidingStatusCard(
                quip: BraidingQuips.lines[braidingQuipIndex],
                startedAt: generation.braidingStartedAt
            )
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    @ViewBuilder
    var bookTodayAmbientShelf: some View {
        if !localBrainTelemetry.isWorking && !generation.isBraiding {
            if let ember = BraidEmber.evening(for: today, previousDays: days) {
                BraidEmberStatusCard(ember: ember)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else if Calendar.current.isDateInWeekend(Date()),
                      let line = EditionCurator.weeklySignatureLine(monthPages: currentMonthPages) {
                WeeklySignatureCard(line: line)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func scrollToLocalBrainWorkShelf(_ scrollProxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.easeInOut(duration: 0.28)) {
                scrollProxy.scrollTo(Self.localBrainWorkShelfScrollID, anchor: .top)
            }
        }
    }

    private var currentMonthPages: [BookPage] {
        let calendar = Calendar.current
        let now = Date()
        return days
            .flatMap(\.pages)
            .filter { calendar.isDate($0.createdAt, equalTo: now, toGranularity: .month) }
    }

    static let bannerCameos: [(asset: String, name: String)] = [
        ("LabyrinthCharacterPennyBlackletter", "Penny Blackletter"),
        ("LabyrinthCharacterZaraFinch", "Zara Finch"),
        ("LabyrinthCharacterDrSeleneInkrest", "Dr. Selene Inkrest"),
        ("LabyrinthCharacterHeadmistressSeraphinaThorne", "Headmistress Thorne"),
        ("LabyrinthCharacterOrionBlackthorn", "Orion Blackthorn"),
        ("LabyrinthCharacterSerenityBrown", "Serenity Brown")
    ]

    var bannerTimeWash: LinearGradient {
        let hour = Calendar.current.component(.hour, from: Date())
        let colors: [Color]
        switch hour {
        case 5..<9:
            colors = [Color(red: 0.96, green: 0.62, blue: 0.46).opacity(0.16), .clear]
        case 9..<17:
            colors = [.clear, .clear]
        case 17..<21:
            colors = [Color(red: 0.82, green: 0.46, blue: 0.30).opacity(0.20), Color(red: 0.30, green: 0.22, blue: 0.46).opacity(0.14)]
        default:
            colors = [Color(red: 0.12, green: 0.14, blue: 0.32).opacity(0.30), Color(red: 0.10, green: 0.10, blue: 0.24).opacity(0.16)]
        }
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    /// A fresh variation every app open: rotating epigraph, time-of-day
    /// light wash, tonight's actual moon stamped in the corner, and sometimes
    /// a cast member visiting the margin.
    var topBanner: some View {
        let epigraph = openingVoice.epigraph
        let cameo = bannerSeed % 5 < 2
            ? Self.bannerCameos[bannerSeed % Self.bannerCameos.count]
            : nil
        let moon = MoonPhaseCalendar.phase()
        let interior = vault.data.bookInterior ?? .unawakened

        return Image("ReEnchantedTopBanner")
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: 142)
            // Keep a generous crop reserve at the smallest part of the breath.
            // This banner's near-edge composition can otherwise reveal the image
            // boundary when the horizontal drift reaches its outward extreme.
            .ambientKenBurns(
                minScale: 1.08,
                maxScale: 1.115,
                drift: CGSize(width: 2, height: 1),
                isPaused: shouldPauseAmbientMotion
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                bannerTimeWash
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(BookPalette.lampGold.opacity(0.28), lineWidth: 1)
            }
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [
                        .clear,
                        BookPalette.nightPanel.opacity(0.56)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomLeading) {
                Text("“\(epigraph)”")
                    .font(.system(.caption, design: .serif).italic().weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .shadow(color: .black.opacity(0.7), radius: 3, x: 0, y: 1)
                    .lineLimit(2)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                    .padding(.trailing, cameo == nil ? 12 : 64)
            }
            .overlay(alignment: .topTrailing) {
                VStack(spacing: 6) {
                    Image(systemName: moon.symbolName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(BookPalette.lampGold.opacity(0.85))
                        .shadow(color: .black.opacity(0.6), radius: 2)
                        .accessibilityLabel(moon.name)
                    if let ascendant = ascendantTalisman,
                       let chapter = AcademyChapterRegistry.chapter(forTalismanID: ascendant.id) {
                        Image(systemName: chapter.symbolName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(BookPalette.teal.opacity(0.9))
                            .shadow(color: .black.opacity(0.6), radius: 2)
                            .accessibilityLabel("\(ascendant.name) is ascendant")
                    }
                }
                .padding(10)
            }
            .overlay(alignment: .topLeading) {
                Group {
                    if let secret = interior.secret, secret.status == .ready {
                        Label("SEALED LEAF", systemImage: "seal.fill")
                            .accessibilityLabel("One of the Book's sealed leaves is ready to open")
                    } else if interior.favorite?.firstPresentedAt == nil, interior.favorite != nil {
                        Label("DOG-EARED", systemImage: "bookmark.fill")
                            .accessibilityLabel("The Book has dog-eared a favorite Page")
                    } else if interior.promise?.status == .keeping {
                        Label("KEEPING WATCH", systemImage: "bookmark")
                            .accessibilityLabel("The Book is keeping an unfinished promise")
                    } else if interior.opinion?.strength == .reconsidering,
                              interior.opinion?.firstPresentedAt == nil {
                        Label("REVISING", systemImage: "eraser.fill")
                            .accessibilityLabel("The Book has revised an opinion")
                    } else if let game = interior.longGame, game.phasePresentedAt == nil {
                        Label("LONG GAME", systemImage: "map.fill")
                            .accessibilityLabel("The Book's long game has entered \(game.phase.title)")
                    }
                }
                .font(.system(size: 9, weight: .black, design: .serif))
                .foregroundStyle(BookPalette.lampGold)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(BookPalette.nightPanel.opacity(0.86), in: Capsule())
                .overlay { Capsule().stroke(BookPalette.lampGold.opacity(0.5), lineWidth: 1) }
                .padding(9)
                .shadow(color: .black.opacity(0.45), radius: 3, y: 1)
            }
            .overlay(alignment: .bottomTrailing) {
                if let cameo {
                    Image(cameo.asset)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 46, height: 46)
                        .clipShape(Circle())
                        .overlay {
                            Circle()
                                .stroke(BookPalette.lampGold.opacity(0.8), lineWidth: 1.4)
                        }
                        .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                        .padding(8)
                        .accessibilityLabel("\(cameo.name) is visiting the margin today")
                }
            }
            .overlay(alignment: .bottom) {
                if let bookKnockNote {
                    Text(bookKnockNote)
                        .font(.system(.caption, design: .serif).italic().weight(.semibold))
                        .foregroundStyle(BookPalette.lampGold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(BookPalette.nightPanel.opacity(0.96), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(BookPalette.lampGold.opacity(0.5), lineWidth: 1)
                        }
                        .padding(.bottom, -16)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(-1)
                        .accessibilityLabel("A note from inside the Book: \(bookKnockNote)")
                }
            }
            .rotationEffect(.degrees(bannerShudder ? 0.7 : 0))
            .contentShape(Rectangle())
            .onTapGesture {
                knockOnTheCover()
            }
            .shadow(color: .black.opacity(0.3), radius: 18, x: 0, y: 12)
            .accessibilityLabel("An open enchanted book surrounded by field notes, ink, compass art, and marginalia. \(epigraph)")
            .accessibilityHint("The cover can be knocked on.")
    }

    var hero: some View {
        VStack(alignment: .leading, spacing: 20) {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Real Life,\nReEnchanted")
                        .font(.system(size: 40, weight: .semibold, design: .serif))
                        .lineLimit(2)
                        .minimumScaleFactor(0.54)
                        .frame(maxWidth: 330, alignment: .leading)
                        .padding(.trailing, 86)

                    Text(openingVoice.heroLine)
                        .font(.system(.callout, design: .serif, weight: .semibold))
                        .foregroundStyle(BookPalette.nightText.opacity(0.78))
                        .lineSpacing(2)
                        // These updates are authored to be read in full. Let the
                        // card grow with the copy instead of replacing its ending
                        // with an ellipsis on narrower phone widths.
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 280, alignment: .leading)
                        .padding(.top, 10)
                }
                .foregroundStyle(BookPalette.lampGold)
                .shadow(color: BookPalette.lampGold.opacity(0.18), radius: 10, x: 0, y: 3)
                .frame(maxWidth: .infinity, alignment: .leading)

                LivingMarginaliaImage(name: "MarginaliaCompass", width: 42, opacity: 0.42, glow: false, isPaused: shouldPauseAmbientMotion)
                    .frame(width: 58, height: 58)
                    .padding(.top, 8)
                    .padding(.trailing, 8)
                    .accessibilityHidden(true)
            }

            if let bookPage = bookOfYouHeroPage {
                SwipeDismissBookOfYouHero {
                    latestBraidSharePanel(for: bookPage)
                } onDismiss: {
                    dismissBookOfYouHero(bookPage)
                }
            } else {
                HStack(spacing: 10) {
                    Label("\(today.capturedPages.count) fragment\(today.capturedPages.count == 1 ? "" : "s") in the margins", systemImage: "tray.full")
                    Spacer()
                    Text("The Book is listening.")
                        .ambientPulse(dimmed: 0.5, bright: 1.0, period: 3.6, isPaused: shouldPauseAmbientMotion)
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(BookPalette.ink.opacity(0.68))
                .padding(14)
                .background(BookPalette.paper.opacity(0.82), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(BookPalette.nightPanel.opacity(0.44))
                .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 10)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.22), lineWidth: 1)
        }
        .overlay(alignment: .bottomLeading) {
            LivingMarginaliaImage(name: "MarginaliaFeather", width: 46, opacity: 0.46, isPaused: shouldPauseAmbientMotion, sway: 2.4)
                .rotationEffect(.degrees(-10))
                .offset(x: -4, y: 16)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .topTrailing) {
            LivingMarginaliaImage(name: "MarginaliaStamp", width: 70, opacity: 0.20, glow: false, isPaused: shouldPauseAmbientMotion)
                .rotationEffect(.degrees(8))
                .offset(x: -2, y: 8)
                .allowsHitTesting(false)
        }
    }

    var bookTodayShelf: some View {
        foldedShelf(
            title: "The Book Today",
            accent: BookPalette.lampGold,
            isExpanded: $isBookTodayShelfExpanded
        ) {
            VStack(alignment: .leading, spacing: 20) {
                topBanner
                hero
                bookTodayAmbientShelf
            }
        }
    }

    var surfaceShelf: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Pages Rising")
                    .sectionRuneLabel()

                Spacer()

                Text(isLaunchDeskCurating ? "choosing" : "\(surfaces.count)/3")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(BookPalette.teal)
            }

            if isLaunchDeskCurating {
                LaunchDeskRitualView(
                    variant: launchDeskRitualVariant,
                    isPaused: shouldPauseAmbientMotion
                )
                .transition(.opacity.combined(with: .scale(scale: 0.985)))
            } else {
                if surfaces.isEmpty {
                    EmptyBookCard(
                        title: "The desk is clear",
                        message: "No page is tapping the glass just now."
                    )
                }

                // There are at most three cards. Keeping them eagerly mounted
                // makes the pending retirement slot a reliable layout
                // placeholder and avoids lazy-stack measurement corrections.
                VStack(spacing: 12) {
                    ForEach(surfaces) { surface in
                        SwipeDismissSurfaceCard(
                            surface: surface,
                            isBusy: workBlockingState.surfaceBusyIndicator(for: surface.type),
                            isRetiring: pendingSurfaceRetirements[surface.id] != nil,
                            animatesArrival: arrivingSurfaceIDs.contains(surface.id)
                        ) {
                            openDeskSurface(surface)
                        } onDismiss: {
                            dismissSurface(surface)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(
                                    usesPadWorkspace && padDestination == .today && selectedSurface?.id == surface.id
                                        ? BookPalette.lampGold.opacity(0.78)
                                        : Color.clear,
                                    lineWidth: 2
                                )
                                .allowsHitTesting(false)
                        }
                        .contextMenu {
                            Button {
                                openDeskSurface(surface)
                            } label: {
                                Label("Open on Reading Stand", systemImage: "book.pages")
                            }

                            Button {
                                dismissSurface(surface)
                            } label: {
                                Label("Let This Page Wait", systemImage: "arrow.uturn.backward")
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            if !statusMessage.isEmpty {
                StatusBanner(
                    message: statusMessage,
                    actionTitle: statusActionTitle,
                    action: statusAction
                )
            }
        }
        .animation(.easeOut(duration: 0.32), value: isLaunchDeskCurating)
    }

    private func openDeskSurface(_ surface: SurfacePage) {
        BookFeedback.play(surface.type == .bookOfYou ? .tap : .openPage)
        switch SurfaceActionRouter(workState: workBlockingState).decision(
            for: surface.type,
            readiness: SurfaceReadinessState(surface: surface)
        ) {
        case .blocked(let message):
            BookFeedback.play(.error)
            statusMessage = message
        case .braid:
            Task { await braidToday(openWhenComplete: true) }
        case .open:
            if isMemoryPageLocked(surface.type) {
                showMemoryPageLockedMessage(for: surface.type)
                return
            }
            recordMagicMomentInteraction(surface, status: .asked)
            markFirstRunEngaged(surface)
            if SurfaceReadinessState(surface: surface).needsLocalBrainToOpen {
                Task { await generateAndOpenSurface(surface) }
            } else if surface.type == .bookConnections {
                isConnectionsPresented = true
            } else if surface.type == .pactVerdict {
                pactVerdictSurface = surface
            } else if surface.type == .pactErrand {
                pactErrandSurface = surface
            } else if surface.payload.metadata["opensBookShop"] == "true" {
                currentStall = buildGoblinStall()
                isBookShopPresented = true
            } else if surface.payload.metadata["opensPagewright"] == "true" {
                pagewrightInitialPageIDs = surface.payload.metadata["pagewrightPageIDs"]?
                    .split(separator: ",")
                    .map(String.init) ?? []
                isPagewrightPresented = true
            } else if surface.payload.metadata["requiresCalendarPermission"] == "true" {
                Task { await openCalendarDoorway(from: surface) }
            } else if surface.type == .faeBargain {
                openFaeBargainSurface(surface)
            } else {
                selectedSurface = surface
            }
        }
    }

    var statusActionTitle: String? {
        if undoRemovedPage != nil {
            return "Put it back"
        }
        if undoSurface != nil {
            return "Call it back"
        }
        return generation.braidRecovery.retryActionTitle
    }

    var statusAction: (() -> Void)? {
        if undoRemovedPage != nil {
            return { restoreLastRemovedPage() }
        }
        if undoSurface != nil {
            return { undoLastSurfaceDismissal() }
        }
        if generation.braidRecovery.canRetry {
            return {
                Task { await braidToday() }
            }
        }
        return nil
    }

    func foldedShelf<Content: View>(
        title: String,
        status: String? = nil,
        accent: Color = BookPalette.gold,
        isExpanded: Binding<Bool>,
        onToggle: ((Bool) -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                BookFeedback.play(.tap)
                let nextValue = !isExpanded.wrappedValue
                onToggle?(nextValue)
                withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                    isExpanded.wrappedValue = nextValue
                }
            } label: {
                HStack(spacing: 10) {
                    Text(title)
                        .sectionRuneLabel()

                    Spacer()

                    if let status {
                        Text(status)
                            .font(.caption.monospacedDigit().weight(.bold))
                            .foregroundStyle(accent.opacity(0.95))
                    }

                    Text(isExpanded.wrappedValue ? "open" : "folded")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(BookPalette.gold.opacity(0.78))

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(accent)
                        .rotationEffect(.degrees(isExpanded.wrappedValue ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.bookPress())
            .accessibilityLabel(isExpanded.wrappedValue ? "Hide \(title)" : "Show \(title)")

            if isExpanded.wrappedValue {
                VStack(alignment: .leading, spacing: 12) {
                    content()
                }
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    )
                )
            }
        }
        .padding(14)
        .background(BookPalette.nightPanel.opacity(0.36), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(accent.opacity(isExpanded.wrappedValue ? 0.28 : 0.13), lineWidth: 1)
        )
    }


    var storyFieldPreviewSurface: SurfacePage? {
        if let prepared = generation.preparedStoryPageSurface {
            return prepared
        }
        var inputs = sourceInputs
        inputs.preparedStoryPageSurface = nil
        return NarrativeOSPageSourceAdapter.draftCandidate(
            for: today,
            inputs: inputs,
            now: surfaceRefreshDate
        )
    }

    var labPanelShelf: some View {
        let eligibleBraidCount = today.capturedPages.filter { !$0.usedInBookOfYou }.count
        let queuedGeneratedPages = [
            generation.preparedStoryPageSurface,
            generation.preparedGossipPageSurface,
            generation.preparedFacultyResearchSurface,
            generation.preparedLetterSurface,
            generation.automaticIlluminatedSurface
        ].compactMap(\.self)

        return foldedShelf(
            title: "Lab Panel",
            status: databaseReport.loadSource.rawValue,
            accent: BookPalette.teal,
            isExpanded: $isLabPanelExpanded
        ) {
            VStack(alignment: .leading, spacing: 10) {
                diagnosticRow("model", modelReport.title)
                diagnosticRow("preferred", modelReport.preferredModelID)
                diagnosticRow("device", modelReport.deviceSummary)
                diagnosticRow("store", "\(storeReport.loadSource.rawValue) · \(storeReport.dayCount)d · \(storeReport.pageCount)p")
                diagnosticRow("database", "v\(databaseReport.schemaVersion) · \(databaseReport.loadSource.rawValue) · \(databaseReport.backupCount) backups")
                diagnosticRow("today", "\(today.pages.count)p · \(today.capturedPages.count) captured · \(eligibleBraidCount) eligible")
                diagnosticRow("book of you", today.bookOfYou == nil ? "not kept today" : "kept today")
                diagnosticRow("surfaces", surfaces.map(\.id).joined(separator: " | "))
                diagnosticRow("sources", "\(enabledActiveSourceCount)/\(BookPageSourceRegistry.activeSources.count) active")
                diagnosticRow("faculty", "\(facultyEntries.count) entries")
                diagnosticRow("resurfacing", "\(returnedStackCards.count) returns · \(resurfacedPages.count) candidates")
                diagnosticRow("queued", queuedGeneratedPages.map(\.type.shortTitle).joined(separator: " | "))
                diagnosticRow("work", labWorkStatus)
                diagnosticRow("last brain", labLastBrainStatus)
                diagnosticRow("last braid", generation.lastBraidDuration.map { "\(Int($0.rounded()))s" } ?? "none")

                if let lastError = localBrainTelemetry.lastError {
                    diagnosticRow("brain error", lastError, isWarning: true)
                }
                if let lastError = databaseReport.lastError ?? storeReport.lastError {
                    diagnosticRow("shelf error", lastError, isWarning: true)
                }
                if let lastBackupPath = databaseReport.lastBackupPath {
                    diagnosticRow("last backup", lastBackupPath)
                }
            }
        }
    }

    var labWorkStatus: String {
        workBlockingState.labWorkStatus
    }

    var labLastBrainStatus: String {
        localBrainTelemetry.lastWorkStatus { Self.labTimestampFormatter.string(from: $0) }
    }

    static let labTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    static let castLedgerTodayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    static let castLedgerDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM d h:mm a")
        return formatter
    }()

    func diagnosticRow(_ label: String, _ value: String, isWarning: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.caption2.monospaced().weight(.bold))
                .foregroundStyle(BookPalette.gold.opacity(0.78))
                .frame(width: 82, alignment: .leading)

            Text(value.isEmpty ? "none" : value)
                .font(.caption.monospaced())
                .foregroundStyle(isWarning ? .red.opacity(0.86) : BookPalette.nightText.opacity(0.76))
                .lineLimit(3)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    var castLedgerMovements: [CastAgencyMovement] {
        Array((vault.data.castAgency?.recentMovements ?? [])
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(4))
    }

    @ViewBuilder
    var castLedgerShelf: some View {
        let movements = castLedgerMovements
        if !movements.isEmpty {
            foldedShelf(
                title: "Cast Ledger",
                status: "\(movements.count)",
                accent: BookPalette.teal,
                isExpanded: $isCastLedgerExpanded
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(movements) { movement in
                        CastAgencyMovementRow(
                            movement: movement,
                            timestamp: castLedgerTimestamp(for: movement.createdAt)
                        )
                    }
                }
            }
        }
    }

    func castLedgerTimestamp(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return Self.castLedgerTodayFormatter.string(from: date)
        }
        return Self.castLedgerDateFormatter.string(from: date)
    }

    var openingVoice: BookOpenVoice {
        BookOpenVoiceComposer.compose(openingVoiceContext)
    }

    var openingVoiceContext: WorldChargeContext {
        let now = Date()
        var quietDays = NothingTide.quietDays(in: days, today: today.id)
        if (vault.data.fae?.activeGifts.contains { $0.effect == .quieting }) == true {
            quietDays = max(0, quietDays - 2)
        }
        let hemisphere = Hemisphere.from(latitude: lastAnchorReadingLatitude)
        let greyLevel = NothingTide.greyLevel(
            quietDays: quietDays,
            narrativeHeat: narrativeEvents.prefix(24).count,
            distressActive: DistressSignals.evaluate(day: today).isActive,
            celebrationGreyShift: Almanac.greyShift(on: now, hemisphere: hemisphere) + (vault.data.nothingGreyOffset ?? 0)
        )

        return WorldChargeContext(
            keptToday: today.capturedPages.count,
            availablePages: surfaces.count,
            resurfacedPages: returnedStackCards.count,
            weatherPhrase: weatherPageSignal?.phrase ?? weatherSignal?.phrase,
            enchantedWeatherLine: enchantedWeather?.enchantified ?? enchantedWeather?.summary,
            moonName: MoonPhaseCalendar.phase(on: now).name,
            celebrationTitle: Almanac.active(on: now, hemisphere: hemisphere)?.academyTitle,
            greyLevel: greyLevel,
            hour: Calendar.current.component(.hour, from: now),
            seed: openingVoiceSeed,
            openBargainFae: vault.data.fae?.openBargains.first?.faeKind.name,
            pactLine: vault.data.pactWar?.pendingDispatches.last?.line,
            tunedStationTitle: tunedStationTitle,
            recentPageTypes: recentKeptPageTypes,
            hasBookOfYou: today.bookOfYou != nil,
            quietDays: quietDays,
            ascendantTalismanName: ascendantTalismanName,
            boundTalismanName: boundTalismanName,
            castActionLine: recentCastActionLine,
            relationshipLine: recentRelationshipLine,
            beliefMovementLine: recentBeliefMovementLine,
            readerBelief: beliefScore,
            bookRelationship: BookRelationshipLedger.snapshot(inputs: sourceInputs, now: now),
            bookInterior: sourceInputs.bookInterior
        )
    }

    var tunedStationTitle: String? {
        RadioStationRegistry.station(
            id: radioManager.playback.activeStationID,
            unlockedPackIDs: Set(vault.data.ownedPacks ?? [])
        )?.title
    }

    var recentKeptPageTypes: [BookPageType] {
        days
            .flatMap(\.pages)
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(4)
            .map(\.type)
    }

    var ascendantTalismanName: String? {
        guard let talisman = ascendantTalisman else { return nil }
        return AcademyChapterRegistry.chapter(forTalismanID: talisman.id)?.talismanName ?? talisman.name
    }

    var boundTalismanName: String? {
        boundTalismanID.flatMap { AcademyChapterRegistry.chapter(forTalismanID: $0)?.talismanName }
    }

    var recentRelationshipLine: String? {
        castLedgerMovements.first { $0.kind == .relationship }?.line
    }

    var recentCastActionLine: String? {
        castLedgerMovements.first?.line
    }

    var recentBeliefMovementLine: String? {
        guard let movement = vault.data.beliefEconomy?.recentMovements
            .sorted(by: { $0.createdAt > $1.createdAt })
            .first else { return nil }
        let verb = movement.delta >= 0 ? "brightened" : "cooled"
        let amount = abs(movement.delta)
        let movementLine = "\(movement.targetName) \(verb) by \(amount)."
        return movement.note.isEmpty ? movementLine : "\(movementLine) \(movement.note)"
    }

    func refreshOpeningVoice() {
        bannerSeed = Int.random(in: 0..<10_000)
        openingVoiceSeed = Int.random(in: 0..<10_000)
        knocksThisSession = 0
        withAnimation(.easeOut(duration: 0.22)) {
            bookKnockNote = nil
        }
    }

    var todayFragments: some View {
        foldedShelf(
            title: "Today's Margins",
            status: "\(today.capturedPages.count)",
            accent: BookPalette.gold,
            isExpanded: $isTodaysMarginsExpanded
        ) {
            if today.capturedPages.isEmpty {
                EmptyBookCard(
                    title: "No fragments yet",
                    message: "A tired day can give one word. The Book will take it."
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(today.capturedPages.sorted { $0.createdAt > $1.createdAt }) { page in
                        FragmentRow(page: page) {
                            openKeptPage(page)
                        } onRemove: {
                            removeKeptPage(page)
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                    }
                }
            }
        }
    }

    var resurfacedShelf: some View {
        foldedShelf(
            title: "Returned From The Stacks",
            status: returnedStackCards.isEmpty ? "quiet" : "\(returnedStackCards.count) until midnight",
            accent: BookPalette.gold,
            isExpanded: $isReturnedStacksExpanded
        ) {
            if returnedStackCards.isEmpty {
                EmptyBookCard(
                    title: "No old pages stirring yet",
                    message: "Once a few days are kept, the Book can invite a useful memory back into the room."
                )
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ReturnedStacksDailyHeader(cards: returnedStackCards)

                    ForEach(Array(returnedStackCards.enumerated()), id: \.element.id) { index, card in
                        ResurfacedPageRow(card: card, revealIndex: index) {
                            openKeptPage(card.page)
                        }
                    }
                }
            }
        }
    }

    var archiveShelf: some View {
        let keptPages = days
            .flatMap(\.pages)
            .filter { $0.type == .bookOfYou }
            .sorted { $0.createdAt > $1.createdAt }
        let keptIssuePages = days
            .flatMap(\.pages)
            .filter { $0.weeklyIssueArtifact != nil }
            .sorted { $0.createdAt > $1.createdAt }
        let keptMonthlyPages = days
            .flatMap(\.pages)
            .filter { $0.monthlyEditionArtifact != nil }
            .sorted { $0.createdAt > $1.createdAt }
        let status = ([
            "\(keptPages.count) daily",
            keptIssuePages.isEmpty ? nil : "\(keptIssuePages.count) weekly",
            keptMonthlyPages.isEmpty ? nil : "\(keptMonthlyPages.count) monthly"
        ] as [String?])
            .compactMap { $0 }
            .joined(separator: " · ")

        return foldedShelf(
            title: "The Book of You",
            status: status,
            accent: BookPalette.teal,
            isExpanded: $isBookOfYouShelfExpanded
        ) {
            VStack(alignment: .leading, spacing: 10) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // Weekly issues and monthly editions appear here only once
                        // bound; tapping opens the kept copy, never re-binds. New
                        // bindings are made from the Bindery, not this shelf.
                        ForEach(keptIssuePages) { page in
                            if let artifact = page.weeklyIssueArtifact {
                                WeeklyIssueArchiveCard(artifact: artifact) {
                                    openKeptWeeklyIssue(page)
                                }
                            }
                        }

                        ForEach(keptMonthlyPages) { page in
                            if let artifact = page.monthlyEditionArtifact {
                                MonthlyEditionArchiveCard(artifact: artifact) {
                                    openKeptMonthlyEdition(page)
                                }
                            }
                        }

                        ForEach(keptPages.prefix(8)) { page in
                            ArchiveCard(page: page) {
                                openKeptPage(page)
                            }
                        }
                    }
                    .padding(.bottom, 2)
                }

                if keptPages.isEmpty && keptIssuePages.isEmpty && keptMonthlyPages.isEmpty {
                    Text("When the first nightly braid dries, its daily binding will join the issue and monthly braid here.")
                        .font(.caption)
                        .foregroundStyle(BookPalette.nightText.opacity(0.58))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    var sourceControlsShelf: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                BookFeedback.play(.tap)
                withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                    isQuietMechanicsExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Text("Colophon")
                        .sectionRuneLabel()

                    Spacer()

                    Text(isQuietMechanicsExpanded ? "visible" : "folded")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(BookPalette.gold.opacity(0.82))

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BookPalette.gold)
                        .rotationEffect(.degrees(isQuietMechanicsExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.bookPress())
            .accessibilityLabel(isQuietMechanicsExpanded ? "Hide Colophon" : "Show Colophon")

            if isQuietMechanicsExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    ModelStatusCard(
                        report: modelReport,
                        isInstalling: isInstallingModel,
                        installMessage: installMessage,
                        installProgress: installProgress
                    ) {
                        modelReport = LocalModelManager.report()
                    } onInstall: {
                        Task { await installModel() }
                    }

                    LabStatusCard(
                        report: modelReport,
                        storeReport: storeReport,
                        databaseReport: databaseReport,
                        lastBraidDuration: generation.lastBraidDuration
                    )

                    let taughtRules = TaughtReading.rules(
                        learnedBraidNotes: vault.data.learnedBraidNotes ?? [],
                        days: days,
                        learning: vault.data.readerLearning ?? ReaderLearningModel()
                    )
                    if !taughtRules.isEmpty {
                        ColophonTaughtReadingCard(rules: taughtRules)
                    }

                    ColophonDedicationCard()

                    HStack {
                        Text("Doorway settings live here now.")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BookPalette.nightText.opacity(0.62))
                        Spacer()
                        Button {
                            BookFeedback.play(.openPage)
                            isSourceSettingsPresented = true
                        } label: {
                            Label("Doorways", systemImage: "slider.horizontal.3")
                                .font(.caption.weight(.bold))
                        }
                        .buttonStyle(.bordered)
                        .tint(BookPalette.teal)
                        .accessibilityLabel("Page source settings")

                        Button {
                            BookFeedback.play(.sourceRefresh)
                            marginTutorSeenData = "[]"
                            statusMessage = "Zara re-tucked her margin notes. She will reintroduce things as you touch them."
                        } label: {
                            Label("Re-tuck notes", systemImage: "arrow.counterclockwise")
                                .font(.caption.weight(.bold))
                        }
                        .buttonStyle(.bordered)
                        .tint(BookPalette.lampGold)
                        .accessibilityLabel("Reset first-touch margin notes")
                    }

                    Toggle(isOn: $bookWhispersEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Whispers from the Book")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(BookPalette.nightText.opacity(0.86))
                            Text("The evening braid and rare waiting favors — one chosen return window.")
                                .font(.caption2)
                                .foregroundStyle(BookPalette.nightText.opacity(0.58))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .tint(BookPalette.teal)
                    .onChange(of: bookWhispersEnabled) { _, enabled in
                        BookFeedback.play(enabled ? .sourceRefresh : .dismissPage)
                        BookWhispers.refreshSchedule(enabled: enabled, cadence: bookWhisperCadence, electives: electives, whisperController: whisperController, festivalWhisper: festivalWhisperToday, bookInterior: sourceInputs.bookInterior)
                        statusMessage = enabled
                            ? "The Book may whisper now: the evening braid and waiting favors."
                            : "The Book will keep its voice inside the covers."
                    }

                    Toggle(isOn: $promptWhispersEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Prompts to keep")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(BookPalette.nightText.opacity(0.86))
                            Text("One morning prompt you can answer right from the notification.")
                                .font(.caption2)
                                .foregroundStyle(BookPalette.nightText.opacity(0.58))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .tint(BookPalette.lampGold)
                    .onChange(of: promptWhispersEnabled) { _, enabled in
                        BookFeedback.play(enabled ? .sourceRefresh : .dismissPage)
                        BookWhispers.refreshPromptWhispers(enabled: enabled, cadence: bookWhisperCadence, day: today, inputs: sourceInputs, whisperController: whisperController, whisperSovereign: whisperSovereign, eventWhisper: worldEventWhisperToday)
                        statusMessage = enabled
                            ? "The Book may tap the glass with keepable prompts."
                            : "Keepable prompt whispers are quiet now."
                    }

                    Toggle(isOn: Binding(
                        get: { bookAppLockEnabled },
                        set: { requested in
                            guard requested != bookAppLockEnabled else { return }
                            if requested {
                                isChangingAppLock = true
                                Task { @MainActor in
                                    let verifier = BookAppLock()
                                    let authorized = await verifier.authenticate()
                                    if authorized {
                                        NotificationCenter.default.post(name: .bookAppLockAuthorized, object: nil)
                                    }
                                    bookAppLockEnabled = authorized
                                    isChangingAppLock = false
                                    statusMessage = authorized
                                        ? "The cover will now ask for your device key when the Book opens."
                                        : "The cover lock was not enabled."
                                }
                            } else {
                                bookAppLockEnabled = false
                                statusMessage = "The Book will open without asking for your device key."
                                BookFeedback.play(.dismissPage)
                            }
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Protect the Book")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(BookPalette.nightText.opacity(0.86))
                            Text("Require Face ID, Touch ID, or the device passcode whenever ReEnchanted returns from the background.")
                                .font(.caption2)
                                .foregroundStyle(BookPalette.nightText.opacity(0.58))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .tint(BookPalette.teal)
                    .disabled(isChangingAppLock)
                    .accessibilityHint("Uses the device's owner authentication. Your biometric data is never available to the app.")

                    VStack(alignment: .leading, spacing: 7) {
                        Text("Tactile enchantment")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(BookPalette.nightText.opacity(0.86))
                        Picker("Tactile enchantment", selection: $bookHapticMode) {
                            ForEach(BookFeedback.HapticMode.allCases) { mode in
                                Text(mode.title).tag(mode.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: bookHapticMode) { _, rawValue in
                            let mode = BookFeedback.HapticMode(rawValue: rawValue) ?? .full
                            BookFeedback.hapticMode = mode
                            if mode != .off {
                                BookFeedback.chapterBinding()
                            }
                            statusMessage = mode == .off
                                ? "The Book will keep still in your hands."
                                : "The Book's touch is now \(mode.title.lowercased())."
                        }
                        Text("Full uses the complete tactile language. Gentle keeps its shape at a quieter strength.")
                            .font(.caption2)
                            .foregroundStyle(BookPalette.nightText.opacity(0.58))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button {
                        BookFeedback.play(.knock)
                        BookWhispers.sendTestWhisper()
                        statusMessage = "A test whisper is on its way — it should arrive in about ten seconds."
                    } label: {
                        Label("Send a test whisper", systemImage: "bell.badge")
                            .font(.caption.weight(.bold))
                    }
                    .buttonStyle(.bordered)
                    .tint(BookPalette.teal)
                    .accessibilityLabel("Send a test notification in ten seconds")

                    Toggle(isOn: $bookCalendarEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Calendar Doorway")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(BookPalette.nightText.opacity(0.86))
                            Text("The Book reads the day's hinges and folds a corner before each one. Events stay on this device.")
                                .font(.caption2)
                                .foregroundStyle(BookPalette.nightText.opacity(0.58))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .tint(BookPalette.teal)
                    .onChange(of: bookCalendarEnabled) { _, enabled in
                        BookFeedback.play(enabled ? .sourceRefresh : .dismissPage)
                        if enabled {
                            Task {
                                calendarEvents = await CalendarDoorway.upcomingEvents()
                                surfaceRefreshDate = Date()
                                statusMessage = calendarEvents.isEmpty
                                    ? "The Calendar Doorway is open, but no hinges are inked yet."
                                    : "The Book can see \(calendarEvents.count) inked hour\(calendarEvents.count == 1 ? "" : "s") ahead."
                            }
                        } else {
                            calendarEvents = []
                            surfaceRefreshDate = Date()
                            statusMessage = "The Calendar Doorway is closed."
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Vellum's ledger key (USDA FoodData)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(BookPalette.nightText.opacity(0.86))
                        TextField("DEMO_KEY (limited) — paste a free key from fdc.nal.usda.gov", text: $usdaKey)
                            .font(.caption)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .dictationInput(text: $usdaKey)
                        Text("Fuel pages get rough calorie and macro estimates, penciled in moments after you keep them. Entries never leave the device except as anonymous food-name lookups.")
                            .font(.caption2)
                            .foregroundStyle(BookPalette.nightText.opacity(0.55))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: RedditSourceAccount.isConfigured ? "checkmark.seal.fill" : "antenna.radiowaves.left.and.right")
                                .foregroundStyle(RedditSourceAccount.isConfigured ? BookPalette.teal : BookPalette.gold.opacity(0.84))
                            Text("Optional Reddit source")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(BookPalette.nightText.opacity(0.86))
                            Spacer()
                            Text(RedditSourceAccount.isConfigured ? "automatic" : "fallback")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(BookPalette.nightText.opacity(0.58))
                        }

                        TextField("Approved Reddit installed-app client ID", text: $redditClientID)
                            .font(.caption)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .dictationInput(text: $redditClientID)

                        Text("Reader's Shelf works without Reddit by using DuckDuckGo and open-web fallbacks. If you have a Reddit-approved installed-app client ID, paste it here or bundle it in the app; Reddit then adds public community clippings without signing into a reader's account.")
                            .font(.caption2)
                            .foregroundStyle(BookPalette.nightText.opacity(0.55))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            Text("Seal a copy.")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BookPalette.nightText.opacity(0.62))
                            Spacer()
                            if let preparedSaveFileURL {
                                ShareLink(item: preparedSaveFileURL) {
                                    Label("Share the sealed copy", systemImage: "square.and.arrow.up")
                                        .font(.caption.weight(.bold))
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(BookPalette.teal)
                            } else {
                                Button {
                                    BookFeedback.play(.sourceRefresh)
                                    exportSaveFile()
                                } label: {
                                    Label("Seal a copy", systemImage: "book.closed")
                                        .font(.caption.weight(.bold))
                                }
                                .buttonStyle(.bordered)
                                .tint(BookPalette.teal)
                            }
                            Button {
                                BookFeedback.play(.openPage)
                                isSaveImporterPresented = true
                            } label: {
                                Label("Open a sealed copy", systemImage: "square.and.arrow.down")
                                    .font(.caption.weight(.bold))
                            }
                            .buttonStyle(.bordered)
                            .tint(BookPalette.lampGold)
                        }

                        Text("A complete copy of the Book — pages, photographs, and all. Keep it somewhere safe; iCloud Drive counts.")
                            .font(.caption2)
                            .foregroundStyle(BookPalette.nightText.opacity(0.55))
                            .fixedSize(horizontal: false, vertical: true)

                        if let sealed = lastSealedCopyDescription {
                            Text(sealed)
                                .font(.caption2)
                                .foregroundStyle(BookPalette.nightText.opacity(0.45))
                        }

                        HStack(spacing: 10) {
                            Text("Or as plain text.")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BookPalette.nightText.opacity(0.62))
                            Spacer()
                            if let preparedPlainInkURL {
                                ShareLink(item: preparedPlainInkURL) {
                                    Label("Share plain ink", systemImage: "square.and.arrow.up")
                                        .font(.caption.weight(.bold))
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(BookPalette.teal)
                            } else {
                                Button {
                                    BookFeedback.play(.sourceRefresh)
                                    exportPlainInk()
                                } label: {
                                    Label("Copy out in plain ink", systemImage: "doc.plaintext")
                                        .font(.caption.weight(.bold))
                                }
                                .buttonStyle(.bordered)
                                .tint(BookPalette.teal)
                            }
                        }

                        Text("Every kept page as ordinary text, readable anywhere, forever.")
                            .font(.caption2)
                            .foregroundStyle(BookPalette.nightText.opacity(0.55))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 10) {
                        Text("Book continuity.")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BookPalette.nightText.opacity(0.62))
                        Spacer()
                        Button {
                            if isMemoryPageLocked(.bookConnections) {
                                showMemoryPageLockedMessage(for: .bookConnections)
                            } else {
                                BookFeedback.play(.openPage)
                                isConnectionsPresented = true
                            }
                        } label: {
                            Label("Open connections", systemImage: "sparkles.rectangle.stack")
                                .font(.caption.weight(.bold))
                        }
                        .buttonStyle(.bordered)
                        .tint(BookPalette.lampGold)
                        if let preparedContinuityURL {
                            ShareLink(item: preparedContinuityURL) {
                                Label("Share continuity", systemImage: "square.and.arrow.up")
                                    .font(.caption.weight(.bold))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(BookPalette.teal)
                        } else {
                            Button {
                                BookFeedback.play(.sourceRefresh)
                                exportContinuityFile()
                            } label: {
                                Label("Export continuity", systemImage: "point.3.connected.trianglepath.dotted")
                                    .font(.caption.weight(.bold))
                            }
                            .buttonStyle(.bordered)
                            .tint(BookPalette.teal)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Text("Make a share page.")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BookPalette.nightText.opacity(0.62))
                            Spacer()
                            if let preparedPagewrightPDFURL {
                                ShareLink(item: preparedPagewrightPDFURL) {
                                    Label("Share last Page", systemImage: "square.and.arrow.up")
                                        .font(.caption.weight(.bold))
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(BookPalette.lampGold)
                            }
                            Button {
                                BookFeedback.play(.openPage)
                                isPagewrightPresented = true
                            } label: {
                                Label("Open Pagewright", systemImage: "scissors")
                                    .font(.caption.weight(.bold))
                            }
                            .buttonStyle(.bordered)
                            .tint(BookPalette.teal)
                        }

                        Text("Choose a few kept pages and bind them into a small scrapbook PDF. Only the pages you select leave the Book.")
                            .font(.caption2)
                            .foregroundStyle(BookPalette.nightText.opacity(0.55))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Text("Bind a week.")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BookPalette.nightText.opacity(0.62))
                            Spacer()
                            if currentWeeklyIssue != nil {
                                // Read-first: binding opens the issue in-app, where
                                // the card and full-PDF shares live.
                                Button {
                                    BookFeedback.play(.sourceRefresh)
                                    exportWeeklyIssuePDF()
                                } label: {
                                    Label(preparedWeeklyIssuePDFURL != nil ? "Read the issue" : "Bind & read", systemImage: "book")
                                        .font(.caption.weight(.bold))
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(BookPalette.teal)
                            } else {
                                Text("No closed issue yet")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(BookPalette.nightText.opacity(0.42))
                            }
                        }

                        if let issue = currentWeeklyIssue {
                            Text("Issue No. \(issue.number) covers \(issue.dateRange) with \(issue.keptCount) \(issue.keptCount == 1 ? "page" : "pages").")
                                .font(.caption2)
                                .foregroundStyle(BookPalette.nightText.opacity(0.55))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Text("Bind a month.")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BookPalette.nightText.opacity(0.62))
                            Spacer()
                            if let preparedMonthlyEditionURL {
                                ShareLink(item: preparedMonthlyEditionURL) {
                                    Label("Share monthly edition", systemImage: "square.and.arrow.up")
                                        .font(.caption.weight(.bold))
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(BookPalette.lampGold)
                            } else {
                                Menu {
                                    Button {
                                        BookFeedback.play(.sourceRefresh)
                                        exportMonthlyEdition()
                                    } label: {
                                        Label("Bind now (fast)", systemImage: "bolt")
                                    }
                                    Button {
                                        BookFeedback.play(.sourceRefresh)
                                        exportMonthlyEdition(useGemmaClosing: true)
                                    } label: {
                                        Label("Bind with Gemma's conclusion", systemImage: "sparkles")
                                    }
                                } label: {
                                    Label("Bind monthly edition", systemImage: "book.pages")
                                        .font(.caption.weight(.bold))
                                } primaryAction: {
                                    BookFeedback.play(.sourceRefresh)
                                    exportMonthlyEdition()
                                }
                                .menuStyle(.borderlessButton)
                                .buttonStyle(.bordered)
                                .tint(BookPalette.lampGold)
                            }
                        }

                        if localBrainTelemetry.isWorking,
                           localBrainTelemetry.currentLabel == "monthly-closing" {
                            LiveLocalBrainWorkingStatusCard(
                                progress: localBrainProgress,
                                label: "monthly-closing",
                                startedAt: localBrainTelemetry.startedAt,
                                queuedCount: localBrainTelemetry.currentQueuedCount,
                                presentation: .page
                            )
                        }

                        let months = bindableEditionMonths
                        if !months.isEmpty {
                            Menu {
                                Button {
                                    selectedEditionMonth = nil
                                    preparedMonthlyEditionURL = nil
                                    colophonBindingNote = nil
                                } label: {
                                    if selectedEditionMonth == nil {
                                        Label("Most recent month", systemImage: "checkmark")
                                    } else {
                                        Text("Most recent month")
                                    }
                                }
                                Divider()
                                ForEach(months, id: \.start) { month in
                                    Button {
                                        selectedEditionMonth = month.start
                                        preparedMonthlyEditionURL = nil
                                        colophonBindingNote = nil
                                    } label: {
                                        let title = "\(month.label) · \(month.pageCount) \(month.pageCount == 1 ? "page" : "pages")"
                                        if selectedEditionMonth == month.start {
                                            Label(title, systemImage: "checkmark")
                                        } else {
                                            Text(title)
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "calendar")
                                        .font(.caption2.weight(.bold))
                                    Text(selectedEditionMonthLabel)
                                        .font(.caption2.weight(.bold))
                                        .lineLimit(1)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 9, weight: .bold))
                                }
                                .foregroundStyle(BookPalette.lampGold.opacity(0.9))
                            }
                        }

                        Toggle(isOn: $includePrivateWeatherInMonthlyBinding) {
                            Label("Include Fuel & Inner Weather", systemImage: "heart.text.square")
                                .font(.caption2.weight(.semibold))
                        }
                        .toggleStyle(.switch)
                        .tint(BookPalette.lampGold)
                        .font(.caption2)
                        .foregroundStyle(BookPalette.nightText.opacity(0.72))
                        .onChange(of: includePrivateWeatherInMonthlyBinding) { _, _ in
                            preparedMonthlyEditionURL = nil
                            preparedPrintInteriorURL = nil
                            preparedPrintCoverURL = nil
                            colophonBindingNote = nil
                        }

                        if let colophonBindingNote {
                            StatusBanner(message: colophonBindingNote)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .animation(shouldPauseAmbientMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85), value: colophonBindingNote)

                    HStack(spacing: 10) {
                        Text("Bind the year.")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BookPalette.nightText.opacity(0.62))
                        Spacer()
                        if let preparedAnnualEditionURL {
                            ShareLink(item: preparedAnnualEditionURL) {
                                Label("Share the annual", systemImage: "square.and.arrow.up")
                                    .font(.caption.weight(.bold))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(BookPalette.lampGold)
                        } else {
                            Button {
                                BookFeedback.play(.sourceRefresh)
                                exportAnnualEdition()
                            } label: {
                                Label("Bind the annual", systemImage: "books.vertical")
                                    .font(.caption.weight(.bold))
                            }
                            .buttonStyle(.bordered)
                            .tint(BookPalette.lampGold)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Open any book.")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BookPalette.nightText.opacity(0.62))
                        if let active = vault.data.bookJump?.active {
                            Text("A jump into \(active.title) is already open — finish it from the feed first.")
                                .font(.caption2)
                                .foregroundStyle(BookPalette.nightText.opacity(0.5))
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            HStack(spacing: 10) {
                                TextField("Name a public-domain book…", text: $bookJumpCustomTitle)
                                    .textFieldStyle(.plain)
                                    .font(.caption)
                                    .foregroundStyle(BookPalette.nightText)
                                    .padding(8)
                                    .background(BookPalette.nightPanel.opacity(0.7), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                Button {
                                    BookFeedback.play(.sourceRefresh)
                                    openCustomBookJump()
                                } label: {
                                    Label("Open the Spine", systemImage: "book.closed")
                                        .font(.caption.weight(.bold))
                                }
                                .buttonStyle(.bordered)
                                .tint(BookPalette.lampGold)
                                .disabled(bookJumpCustomTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                        if let rules = vault.data.bookJump?.activeBorrowedRules(at: Date()), !rules.isEmpty {
                            Text("Rules you're carrying: " + rules.map { "“\($0.text)” (\($0.bookTitle))" }.joined(separator: "; "))
                                .font(.caption2.italic())
                                .foregroundStyle(BookPalette.lampGold.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    HStack(spacing: 10) {
                        Text("Today's paper.")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BookPalette.nightText.opacity(0.62))
                        Spacer()
                        if let preparedBleedPDFURL {
                            ShareLink(item: preparedBleedPDFURL) {
                                Label("Share The Bleed", systemImage: "square.and.arrow.up")
                                    .font(.caption.weight(.bold))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(BookPalette.lampGold)
                        } else {
                            Button {
                                BookFeedback.play(.sourceRefresh)
                                exportBleedPDF()
                            } label: {
                                Label("Bind The Bleed as PDF", systemImage: "newspaper")
                                    .font(.caption.weight(.bold))
                            }
                            .buttonStyle(.bordered)
                            .tint(BookPalette.lampGold)
                        }
                    }

                    labPanelShelf

                    BodySourceCard(
                        bodySignal: bodySignal,
                        message: healthKitMessage,
                        isRequesting: isRequestingHealthKit,
                        hasRequested: didRequestHealthKitBodySignal,
                        isAvailable: HealthKitBodyReader.isAvailable
                    ) {
                        BookFeedback.play(.sourceRefresh)
                        Task { await requestHealthKitBodySignal() }
                    }

                    WeatherSourceCard(
                        weatherSignal: weatherPageSignal,
                        message: weatherMessage,
                        isRequesting: isRequestingWeather || !workBlockingState.canRequestWeather,
                        hasRequested: didRequestWeatherLocation,
                        isAvailable: WeatherLocationReader.isAvailable
                    ) {
                        guard workBlockingState.canRequestWeather else {
                            weatherMessage = "The Book is already using the local brain. Let that ink dry first."
                            return
                        }
                        BookFeedback.play(.sourceRefresh)
                        Task { await requestWeatherSignal() }
                    }

                    AnchorSourceCard(
                        proximity: nearbyAnchor,
                        message: anchorMessage,
                        isChecking: isCheckingAnchors,
                        hasRequested: didRequestAnchorLocation,
                        isAvailable: AnchorLocationReader.isAvailable
                    ) {
                        BookFeedback.play(.sourceRefresh)
                        Task { await refreshAnchorProximity(isUserInitiated: true) }
                    }

                    StoryFieldStatusCard(
                        surface: storyFieldPreviewSurface,
                        events: narrativeEvents,
                        isPreparing: generation.isPreparingStoryPage
                    )
                }
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    )
                )
            }
        }
        .padding(14)
        .background(BookPalette.nightPanel.opacity(0.46), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(BookPalette.gold.opacity(isQuietMechanicsExpanded ? 0.28 : 0.14), lineWidth: 1)
        )
    }

    private func presentKeepMarginNote(
        _ note: KeepMarginalia.Note,
        semanticUpgrade: (@Sendable () async -> KeepMarginalia.Note?)? = nil
    ) {
        keepMarginNoteTicket += 1
        let ticket = keepMarginNoteTicket
        keepMarginTrace = nil
        Task { @MainActor in
            var presented = note
            if let semanticUpgrade {
                // The Stacks get the ink-burst beat (plus a small grace) to look
                // for a deeper rhyme; a slow search never stalls the toast.
                let search = Task.detached(priority: .userInitiated) { await semanticUpgrade() }
                try? await Task.sleep(nanoseconds: 900_000_000)
                let upgraded: KeepMarginalia.Note? = await withTaskGroup(of: KeepMarginalia.Note?.self) { group in
                    group.addTask { await search.value }
                    group.addTask {
                        try? await Task.sleep(nanoseconds: 600_000_000)
                        return nil
                    }
                    let first = await group.next() ?? nil
                    group.cancelAll()
                    return first
                }
                if var upgradedNote = upgraded {
                    // The deeper recognition replaces the voice, not the moment:
                    // the ripple and carry-out lines belong to the keep itself.
                    upgradedNote.findingLine = note.findingLine
                    upgradedNote.rippleLine = note.rippleLine
                    upgradedNote.carryOutLine = note.carryOutLine
                    upgradedNote.findingLine = note.findingLine
                    upgradedNote.braidThreadLine = note.braidThreadLine
                    upgradedNote.consequenceLines = note.consequenceLines
                    presented = upgradedNote
                }
            } else {
                // Let the ink burst land first; the margin note is the echo.
                try? await Task.sleep(nanoseconds: 900_000_000)
            }
            guard ticket == keepMarginNoteTicket else { return }
            withAnimation(.spring(duration: 0.5)) { keepMarginNote = presented }
            // A duet carries two voices; give the reader time to hear both.
            let holdNanoseconds: UInt64 = presented.rejoinderLine == nil ? 5_200_000_000 : 8_200_000_000
            try? await Task.sleep(nanoseconds: holdNanoseconds)
            guard ticket == keepMarginNoteTicket else { return }
            // The toast retires into a faint tucked trace — the keep lingers on the
            // settled desk instead of snapping back to a neutral surface.
            withAnimation(.easeOut(duration: 0.4)) {
                keepMarginNote = nil
                keepMarginTrace = presented
            }
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard ticket == keepMarginNoteTicket else { return }
            withAnimation(.easeOut(duration: 0.8)) { keepMarginTrace = nil }
        }
    }

    private var keepMarginaliaBeliefMap: [String: Int] {
        Dictionary(uniqueKeysWithValues: KeepMarginalia.voices.map {
            ($0.slug, effectiveCastBelief(for: $0.slug))
        })
    }

    /// The Thread-of-the-Month keepsake note, when a substantial keep first
    /// lights today and that pushes the month's lit-day count across a milestone.
    /// `days` already holds the freshly kept page by the time this is called, so
    /// the current count includes today; the day was unlit before it, hence
    /// `from: litDays - 1`. Nil when no threshold falls in that step or the keep
    /// is too thin/private to warrant the beat.
    private func threadMilestoneNote(justLitToday input: String, pageType: BookPageType) -> KeepMarginalia.Note? {
        guard KeepMarginalia.isEligible(input: input, pageType: pageType) else { return nil }
        let calendar = Calendar.current
        let litDays = ThreadOfTheMonth.litDayCount(inMonthContaining: Date(), days: days, calendar: calendar)
        guard ThreadOfTheMonth.milestoneCrossed(from: litDays - 1, to: litDays) != nil else { return nil }
        let seal = ThreadOfTheMonth.seal(forLitDays: litDays)
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "MMMM"
        let monthName = formatter.string(from: Date())
        return KeepMarginalia.threadNote(litDays: litDays, seal: seal, monthName: monthName)
    }

    /// A quote earns the card press when it has enough body to gild.
    private func quoteWorthKeeping(_ text: String) -> Bool {
        StorySpark.score(text) >= 5 || text.split { !$0.isLetter && !$0.isNumber }.count >= 8
    }

    private func pressKeepArtifactCard() {
        guard let quote = keepArtifactQuote else { return }
        let url = IlluminatedQuoteCardRenderer.render(
            quote: quote,
            sourceTitle: keepArtifactPageType.title,
            weatherLine: "",
            dateLine: Date().formatted(date: .abbreviated, time: .omitted),
            style: PageVisualStyle.style(for: keepArtifactPageType),
            seed: quote.stableHash
        )
        guard let url else {
            BookFeedback.play(.error)
            return
        }
        keepArtifactCardURL = url
        isShowingKeepArtifactCard = true
        BookFeedback.play(.braidComplete)
    }

    func savePage(surface: SurfacePage, input: String, tags: [String], extraMedia: [BookPageMediaAsset] = []) {
        if surface.type == .bookJump {
            let depth = Int(surface.payload.metadata["bookJumpDepth"] ?? "") ?? 1
            let requiredBelief: Int
            switch surface.payload.metadata["bookJumpAction"] {
            case "start":
                requiredBelief = BookJumpEngine.startCost
            case "advance":
                requiredBelief = BookJumpEngine.advanceCost(depth: depth)
            default:
                requiredBelief = 0
            }
            guard beliefScore >= requiredBelief else {
                statusMessage = "That door needs \(requiredBelief) Belief. Attend to the real world and bring the Book another ember first."
                BookFeedback.play(.error)
                return
            }
        }
        BookFeedback.play(.keepPage)
        let keptAt = Date()
        let keptMedia = surface.mediaAssets + extraMedia
        let keptTags = tags
        keepInkBurstText = input.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? surface.type.shortTitle
        keepInkBurstTrigger += 1
        tutorTouch("keep-page")
        isRetiringKeptSurface = true
        defer { isRetiringKeptSurface = false }
        let refreshDateBeforeKeeping = surfaceRefreshDate
        let reflectablePageCountBeforeKeeping = FirstReading.reflectablePages(in: days).count
        let greyBeforeKeeping = NothingTide.greyLevel(
            quietDays: NothingTide.quietDays(in: days, today: today.id),
            narrativeHeat: narrativeEvents.prefix(24).count,
            distressActive: false,
            celebrationGreyShift: vault.data.nothingGreyOffset ?? 0
        )
        var day = today
        if surface.type == .illuminatedPhoto {
            markAutomaticIlluminatedSurfaceKept(surface)
        }
        if surface.type == .anchor {
            checkInAnchorIfNeeded(surface, tags: tags)
        }
        acceptElectiveIfNeeded(surface: surface)
        applyBookJumpActionIfNeeded(surface: surface, input: input)
        applyBookFaeChoiceIfNeeded(surface: surface, tags: tags)
        if surface.payload.metadata["chapterBinding"] == "true" {
            BookFeedback.chapterBinding()
        }
        clearPreparedSurfaceIfNeeded(surface)
        let tarotReadingArtifact = surface.payload.metadata[TarotReadingArtifact.metadataKey]
            .flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONDecoder().decode(TarotReadingArtifact.self, from: $0) }
        let page = BookPage(
            type: surface.type,
            createdAt: keptAt,
            promptText: surface.prompt,
            userInput: input,
            playerReply: surface.payload.metadata["playerReply"] ?? "",
            tags: keptTags,
            sourceID: surface.sourceID,
            origin: surface.origin,
            privacy: surface.privacy,
            mediaAssets: keptMedia,
            tarotReadingArtifact: tarotReadingArtifact,
            externalReference: BookPageExternalReference.from(surface: surface),
            relationshipReceipt: RelationshipPageReceipt.from(surface: surface, readerInput: input)
        )
        if let encodedQuill = surface.payload.metadata[QuillChoosing.metadataKey],
           let data = encodedQuill.data(using: .utf8),
           let chosen = try? JSONDecoder().decode(ChosenQuill.self, from: data) {
            vault.data.chosenQuill = chosen
            vault.save()
            // The instrument that chose the reader joins the Cast for real:
            // an entity the story engine can seat in scenes, warm with
            // belief, and weave into the relationship field.
            let member = chosen.castMember(now: keptAt)
            if !customCastMembers.contains(where: { $0.id == member.id }) {
                do {
                    try BookDatabase.upsertCustomCastMember(member)
                    customCastMembers = try BookDatabase.customCastMembers(limit: 200)
                } catch {
                    // Non-fatal: the quill still rides in the vault and keeps
                    // its voice; only the Cast seat is missed.
                }
            }
        }
        day.pages.append(page)
        applyWordNegotiationIfNeeded(surface: surface, page: page)
        recordNarrativeEvent(for: page)
        let keptInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if page.origin == .userAuthored,
           KeepMarginalia.isEligible(input: keptInput, pageType: page.type) {
            recordMeaningfulAttention(key: "keep:\(page.id)", now: keptAt)
        }
        let sparked = page.type == .souvenir && StorySpark.score(keptInput) >= 7

        // Belief ripple: the first page today that touches a cast member warms
        // their glow by one, visibly. Derived from the day's pages — no stored
        // counters.
        var rippleLine: String?
        if page.origin == .userAuthored, !keptInput.isEmpty, !page.type.suppressesCastBeliefRipple {
            let touched = RelationshipFieldEngine.entityIDs(fromTags: page.tags)
            if let entityID = touched.first,
               !day.pages.contains(where: { $0.id != page.id && $0.tags.contains("entity:\(entityID)") }) {
                applyEntityBeliefLedgerDelta(entityID: entityID, delta: 1)
                let name = (NarrativePackRegistry.entities + customCastMembers.map(\.entity))
                    .first(where: { $0.id == entityID })?.name
                if let name {
                    rippleLine = BeliefRipple.line(entityName: name, effectiveBelief: effectiveCastBelief(for: entityID))
                }
            }
        }

        let celebration = Almanac.active(on: Date(), hemisphere: Hemisphere.from(latitude: lastAnchorReadingLatitude))
        let isFirstKeepToday = !day.pages.contains { $0.id != page.id && $0.origin == .userAuthored }

        let priorMarginDays = BookStore.upsert(today, in: days)
        let priorKeeps = KeepMarginalia.eligibleKeepCount(in: priorMarginDays)
        let recentKeepMarginSlugs = Set(KeepMarginalia.recentCastSlugs(
            in: priorMarginDays,
            limit: 1,
            beliefBySlug: keepMarginaliaBeliefMap
        ))
        if sparked {
            surfaceRefreshDate = Date()
        }

        var keepNote: KeepMarginalia.Note?
        // The semantic echo may only outrank the ordinary tiers (word echo,
        // cast note) — never a first-friend claim, thread milestone, spark,
        // or festival gift.
        var semanticUpgradeEligible = false
        let afterglowLine = BookAfterglow.line(for: keptInput, pageType: page.type, pageID: page.id)
        if priorKeeps < 2 {
            // The first-friend claim and the duet outrank every other margin voice.
            keepNote = KeepMarginalia.note(
                for: keptInput,
                pageType: page.type,
                pageID: page.id,
                beliefBySlug: keepMarginaliaBeliefMap,
                priorKeepCount: priorKeeps
            )
        }
        if keepNote == nil, isFirstKeepToday,
           let threadNote = threadMilestoneNote(justLitToday: keptInput, pageType: page.type) {
            // Lighting a new day this month may cross a Thread-of-the-Month
            // milestone; that keepsake beat outranks the ordinary belief roll.
            keepNote = threadNote
        }
        if keepNote == nil {
            if sparked {
                keepNote = KeepMarginalia.sparkNote
            } else if let celebration, isFirstKeepToday, !keptInput.isEmpty {
                keepNote = KeepMarginalia.festivalNote(celebrationID: celebration.id, commonName: celebration.commonName)
            } else if let echo = KeepEcho.find(for: keptInput, pageID: page.id, in: days) {
                keepNote = KeepEcho.note(from: echo)
                semanticUpgradeEligible = true
            } else if let quill = vault.data.chosenQuill,
                      let quillNote = QuillChoosing.marginNote(quill: quill, for: keptInput, pageType: page.type, pageID: page.id) {
                // The chosen quill takes roughly one margin in five for itself;
                // the roll lives inside marginNote so the cast keeps the rest.
                keepNote = quillNote
            } else {
                keepNote = KeepMarginalia.note(
                    for: keptInput,
                    pageType: page.type,
                    pageID: page.id,
                    beliefBySlug: keepMarginaliaBeliefMap,
                    priorKeepCount: priorKeeps,
                    avoidingCastSlugs: recentKeepMarginSlugs
                )
                semanticUpgradeEligible = keepNote != nil
            }
        }
        if keepNote == nil {
            // A public keep too thin for a full cast voice still gets the Book's
            // own quiet acknowledgement — the keep moment is never met in silence.
            keepNote = KeepMarginalia.floorNote(for: keptInput, pageType: page.type, pageID: page.id)
        }
        if var note = keepNote {
            note.rippleLine = rippleLine
            note.carryOutLine = afterglowLine
            let keptEarlierToday = day.capturedPages.filter { $0.id != page.id }.count
            note.braidThreadLine = KeepMarginalia.braidGatheringLine(
                keptEarlierToday: keptEarlierToday,
                currentInput: keptInput
            )
            keepArtifactQuote = quoteWorthKeeping(keptInput) ? keptInput : nil
            keepArtifactPageType = surface.type
            keepNote = note
        }
        recordPenPalReplyMemory(for: page, surface: surface)
        recordStudentNoteReplyMemory(for: page, surface: surface)
        weaveRelationshipField(for: page)
        applyGossipRelationshipMoves(from: surface)
        applyGossipPageBeliefMoves(from: surface)
        saveSelfFactIfNeeded(surface: surface, answer: input)
        adoptChosenQuillIfNeeded(surface: surface)
        saveFacultyEntryIfNeeded(surface: surface, page: page, answer: input, tags: tags, dayID: day.id)
        recordNativePageActionIfNeeded(
            on: surface,
            evidence: keptInput.nonEmpty ?? "Kept the Page.",
            at: keptAt
        )
        recordReaderLearning(surface: surface, action: .kept, evidence: keptInput, saveImmediately: false)
        let attentionKeepsakeLine = awardAttentionKeepsakeIfEarned(
            from: surface,
            evidence: keptInput.nonEmpty ?? surface.prompt,
            at: keptAt
        )
        let causalFollowUp = MomentaryThreadFollowUp.surface(
            after: page,
            keptFrom: surface,
            learning: vault.data.readerLearning ?? ReaderLearningModel()
        )
        let beliefDelta = awardBelief(for: surface)
        warmPageSourceForKeptSurface(surface)
        applyGeneratedChapterTalismanDeltas(from: surface)

        let reflectablePageCountAfterKeeping = FirstReading.reflectablePages(
            in: BookStore.upsert(day, in: days)
        ).count
        let firstReadingAwakened = reflectablePageCountBeforeKeeping < 3
            && reflectablePageCountAfterKeeping >= 3
        if var note = keepNote {
            note.consequenceLines = KeepConsequenceReceipt.lines(
                beliefDelta: beliefDelta,
                firstReadingAwakened: firstReadingAwakened,
                keepsakeLine: attentionKeepsakeLine
            )
            keepNote = note

            if semanticUpgradeEligible {
                let echoDays = days
                let echoPageID = page.id
                let echoPageType = page.type
                presentKeepMarginNote(note) {
                    guard let echo = SemanticKeepEcho.find(
                        for: keptInput,
                        pageType: echoPageType,
                        pageID: echoPageID,
                        in: echoDays,
                        scorer: SemanticKeepEcho.keepTimeScorer
                    ) else { return nil }
                    await MainActor.run {
                        recordSemanticEcho(echo, onPageID: echoPageID)
                    }
                    return SemanticKeepEcho.note(from: echo)
                }
            } else {
                presentKeepMarginNote(note)
            }
        }
        if surfaceRefreshDate != refreshDateBeforeKeeping {
            suppressNextSurfaceRefresh = true
        }
        let baseKeptMessage: String
        if today.capturedPages.isEmpty, let returnLine = NothingTide.returnLine(forGreyLevel: greyBeforeKeeping) {
            baseKeptMessage = returnLine
        } else {
            baseKeptMessage = "The Book tucked the \(surface.type.shortTitle.lowercased()) page into the margin."
        }
        var keptMessage = keepNote == nil ? "\(baseKeptMessage) \(afterglowLine)" : baseKeptMessage
        if let attentionKeepsakeLine {
            keptMessage += " \(attentionKeepsakeLine)"
        }
        persist(day: day, message: keptMessage, requestsFreshKeepContext: true)
        retireKeptSurfaceFromRising(surface, preferredReplacement: causalFollowUp)
    }

    func recordSemanticEcho(_ echo: SemanticKeepEcho.Echo, onPageID pageID: String) {
        guard let dayIndex = days.firstIndex(where: { day in
            day.pages.contains { $0.id == pageID }
        }),
              let pageIndex = days[dayIndex].pages.firstIndex(where: { $0.id == pageID }) else {
            return
        }

        var day = days[dayIndex]
        var page = day.pages[pageIndex]
        var tags = Set(page.tags)
        let before = tags
        tags.formUnion(SemanticKeepEcho.tags(for: echo))
        guard tags != before else { return }

        page.tags = tags.sorted()
        day.pages[pageIndex] = page
        persist(day: day, message: "The Book found a deeper echo for that page.")
    }

    /// The sacred dumb door's keep: saves a Plain Page *quietly*. Unlike
    /// `savePage`, it summons no cast voice, no belief ripple, no afterglow —
    /// the entry moment is not processed. The page still enters the archive as
    /// a real `.plainPage`, so the magic can find it later, if ever.
    func keepPlainPage(text: String, media: [BookPageMediaAsset]) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !media.isEmpty else { return }
        let hasPhoto = media.contains { asset in
            switch asset.kind {
            case .bundledImage, .renderedImageFile, .photoLibraryAsset:
                return true
            case .audioFile:
                return false
            }
        }
        var tags = ["plain", "unsorted", "private"]
        if hasPhoto {
            tags.append(contentsOf: ["photo", "plain-photo", "unedited-photo"])
        }
        BookFeedback.play(.keepPage)
        let page = BookPage(
            type: .plainPage,
            promptText: trimmed.isEmpty && hasPhoto ? "Original photograph" : "",
            userInput: trimmed,
            tags: tags,
            sourceID: "plain-page",
            origin: .userAuthored,
            privacy: .privateLocal,
            mediaAssets: media
        )
        var day = today
        day.pages.append(page)
        persist(
            day: day,
            message: "Tucked into the Book, unsorted.",
            requestsFreshKeepContext: true
        )
    }

    /// The reader's living Lexicon, hoisted out of the view body so the
    /// `??` coalescing doesn't add to the body's type-check budget.
    private var activeReaderLexicon: ReaderLexicon {
        vault.data.readerLexicon ?? ReaderLexicon()
    }

    /// Hoisted out of the `body` modifier chain: computing this inline twice in
    /// the Pact Map sheet pushed the body over the type-checker's budget.
    private var pendingPactVerdictSurface: SurfacePage? {
        surfaces.first { $0.type == .pactVerdict }
    }

    /// Hoisted out of the Capture sheet's argument list so that giant call stays
    /// under the type-checker's budget once it gained the `readerLexicon` arg.
    private var inventoryKeptPagesSorted: [BookPage] {
        days.flatMap(\.pages).sorted { $0.createdAt > $1.createdAt }
    }

    private var inventoryStoryObjectList: [CustomCastMember] {
        customCastMembers.filter { $0.kind == .object }
    }

    /// The Capture sheet, lifted out of `body` so its ~40-argument call is
    /// type-checked in isolation. Inlining it kept the whole `body` expression at
    /// the Swift type-checker's complexity ceiling, where adding even one argument
    /// (`readerLexicon`) tipped it into "unable to type-check in reasonable time".
    @ViewBuilder
    private func captureSheet(
        for surface: SurfacePage,
        isEmbedded: Bool = false,
        onDismissRequest: (() -> Void)? = nil
    ) -> some View {
        CapturePageSheet(
            surface: surface,
            day: today,
            isLocalBrainWorking: localBrainTelemetry.isWorking,
            localBrainWorkLabel: localBrainTelemetry.currentLabel,
            localBrainWorkStartedAt: localBrainTelemetry.startedAt,
            localBrainQueuedCount: localBrainTelemetry.currentQueuedCount,
            localBrainProgress: localBrainProgress,
            localBrainIsReady: modelReport.state == .ready,
            isInstallingLocalBrain: isInstallingModel,
            localBrainInstallMessage: installMessage,
            localBrainInstallProgress: installProgress,
            onInstallLocalBrain: {
                Task { await installModel() }
            },
            onReplaceIlluminatedSurface: { replacement in
                generation.automaticIlluminatedSurface = replacement
                surfaceRefreshDate = Date()
            },
            onNavigateToSurface: { nextSurface in
                selectedSurface = nextSurface
            },
            onCompleteCompassRun: { completedSurface in
                completeCompassRunIfNeeded(completedSurface)
            },
            compassAnchors: anchorLedger,
            onStoryMechanicCompleted: { completedSurface, outcome in
                openStoryMechanicReturnPage(from: completedSurface, outcome: outcome)
            },
            onGenerateLetter: { draft in
                Task { await generateLetterFromSheet(draft) }
            },
            onGenerateNote: { draft in
                Task { await generateNoteFromSheet(draft) }
            },
            onGeneratePlayfulMission: { draft in
                Task { await generatePlayfulMissionFromSheet(draft) }
            },
            onRequestTarotReading: { reading, includeArchive in
                await requestAuroraTarotReading(reading, includeArchive: includeArchive)
            },
            readerBeliefScore: beliefScore,
            onSpendBeliefForGeneration: { kind in
                spendBeliefForGeneration(kind)
            },
            onRefundBeliefForGeneration: { kind in
                refundBeliefForGeneration(kind)
            },
            onAnchorPlace: { draft in
                Task { await anchorPlace(from: draft) }
            },
            onBindChapter: { acceptance in
                bindChapter(acceptance: acceptance)
            },
            activeElectives: electives.filter(\.isActive),
            onCompleteElective: { electiveID, proof, photoURL, locationSummary in
                completeElective(id: electiveID, proof: proof, photoURL: photoURL, locationSummary: locationSummary)
            },
            onPayFaeBargain: { bargainID, report, faeResponse in
                payFaeBargain(bargainID: bargainID, report: report, faeResponse: faeResponse)
            },
            onTwoReadingsSided: { chosenID, chosenName, otherID, otherName in
                applyTwoReadingsSiding(chosenID: chosenID, chosenName: chosenName, otherID: otherID, otherName: otherName)
            },
            radioPlayback: vault.data.radio ?? .off,
            onTuneRadio: { stationID in
                tuneRadio(stationID: stationID)
            },
            onStopRadio: {
                stopRadio()
            },
            inventoryKeptPages: inventoryKeptPagesSorted,
            inventoryStoryObjects: inventoryStoryObjectList,
            inventoryObjectBeliefOffsets: entityBeliefLedger,
            onUseInventoryGift: { giftID, targetID in
                useInventoryGift(giftID: giftID, targetID: targetID)
            },
            onOpenInventoryMarket: {
                selectedSurface = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    currentStall = buildGoblinStall()
                    isBookShopPresented = true
                }
            },
            onOpenInventoryBargain: { bargain in
                selectedSurface = nil
                let fae = vault.data.fae ?? FaePlayerState()
                let bargainSurface = FaeBargainPageSourceAdapter.surface(for: bargain, state: fae)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    selectedSurface = bargainSurface
                }
            },
            onLoveBraid: { pageID in
                markLovedBraid(pageID: pageID)
            },
            onBraidMissedMe: { pageID in
                markBraidMissedMe(pageID: pageID)
            },
            onImproveNextBraid: { pageID in
                await improveNextBraidFromMiss(pageID: pageID)
            },
            onRewriteBraid: { pageID in
                await rewriteBraid(pageID: pageID)
            },
            onBookNoticeFeedback: { notice, choice in
                recordBookNoticeFeedback(surface: notice, choice: choice)
            },
            onBookNoticeAdaptiveAction: { notice, action in
                handleBookNoticeAdaptiveAction(surface: notice, action: action)
            },
            onKeepPlainPhoto: { asset in
                keepPlainPage(text: "", media: [asset])
            },
            weatherSignal: weatherPageSignal,
            readerLearning: vault.data.readerLearning ?? ReaderLearningModel(),
            onPageOpened: { openedSurface, openedAt in
                recordMomentaryPageOpened(openedSurface, at: openedAt)
            },
            onMomentaryAction: { actedSurface, evidence, actedAt in
                recordMomentaryAction(on: actedSurface, evidence: evidence, at: actedAt)
            },
            readerLexicon: activeReaderLexicon,
            bookRelationship: BookRelationshipLedger.snapshot(inputs: sourceInputs, now: Date()),
            bookInterior: sourceInputs.bookInterior,
            askTheBookMemoryLookup: { query, turns in
                await AskTheBookArchiveMemoryReader.shared.retrieve(
                    query: query,
                    previousTurns: turns,
                    baseline: stacksSearchDataset
                )
            },
            isShadowWonderActive: ShadowWonder.state(inputs: sourceInputs, now: Date()).isActive,
            isEmbedded: isEmbedded,
            onDismissRequest: onDismissRequest
        ) { savedSurface, input, tags, extraMedia in
            savePage(surface: savedSurface, input: input, tags: tags, extraMedia: extraMedia)
        }
        .id(surface.id)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    func applyWordNegotiationIfNeeded(surface: SurfacePage, page: BookPage) {
        guard surface.type == .wordNegotiation else { return }
        let metadata = surface.payload.metadata
        let isMissingSeed = metadata["wordNegotiationIsMissingSeed"] == "true"
        var lexicon = vault.data.readerLexicon ?? ReaderLexicon()
        if isMissingSeed {
            lexicon.bargainSeedSurfaced = true
        }

        guard let word = metadata["wordNegotiationWord"]?.nonEmpty,
              let originalSense = metadata["wordNegotiationOriginalSense"]?.nonEmpty else {
            vault.data.readerLexicon = lexicon
            vault.save()
            return
        }
        let rulingTag = page.tags.first { $0.hasPrefix("word-ruling:") }
        let rulingRaw = rulingTag.map { String($0.dropFirst("word-ruling:".count)) }
            ?? metadata["wordNegotiationDefaultRuling"]?.nonEmpty
        guard let rulingRaw,
              let ruling = WordRuling(rawValue: rulingRaw) else {
            vault.data.readerLexicon = lexicon
            vault.save()
            return
        }

        let choicePrefix = "wordNegotiationChoice.\(ruling.rawValue)"
        let categoryRaw = page.tags
            .first { $0.hasPrefix("lexicon-category:") }
            .map { String($0.dropFirst("lexicon-category:".count)) }
            ?? metadata["\(choicePrefix).category"]?.nonEmpty
            ?? metadata["wordNegotiationCategory"]?.nonEmpty
        let category = categoryRaw.flatMap(LexiconCategory.init(rawValue:)) ?? .theme
        let newSense = ruling == .recalled
            ? nil
            : (metadata["\(choicePrefix).sense"]?.nonEmpty ?? metadata["wordNegotiationNewSense"]?.nonEmpty)
        let origin = metadata["wordNegotiationOrigin"]
            .flatMap(LexiconOrigin.init(rawValue:)) ?? .rebellion
        let entry = LexiconEntry(
            id: metadata["wordNegotiationWordID"]?.nonEmpty,
            word: word,
            originalSense: originalSense,
            newSense: newSense,
            ruling: ruling,
            category: category,
            origin: origin,
            ledAt: page.createdAt,
            sourcePageID: page.id
        )
        lexicon.upsert(entry)
        // Recompute the Treaty live: nil until `minimumRulings` rebellion rulings
        // exist, then it tracks the player's running tilt (order/reform/chaos) and
        // naturally holds its final value once rulings stop. The Thorned Bargain
        // reads `treaty == .secession` in Feb. (Switch to lock-at-season-end later
        // if aftermath pages should not key off it mid-season.)
        lexicon.treaty = lexicon.treatyOutcome()
        vault.data.readerLexicon = lexicon
        vault.save()
    }

    func applyBookFaeChoiceIfNeeded(surface: SurfacePage, tags: [String]) {
        guard surface.type == .bookFae,
              let kind = FaeKind(rawValue: surface.payload.metadata["faeKind"] ?? "") else {
            return
        }
        guard let choiceTag = tags.first(where: { $0.hasPrefix("choice:") }) else { return }
        let choiceID = String(choiceTag.dropFirst("choice:".count))
        var state = vault.data.fae ?? FaePlayerState()
        FaeEconomy.applyInteractionChoice(choiceID, kind: kind, into: &state)
        vault.data.fae = state
        vault.save()
        BookFeedback.faeArrival(kind: kind.rawValue, court: surface.payload.metadata["faeCourt"])
    }

    func applyBookJumpActionIfNeeded(surface: SurfacePage, input: String) {
        guard surface.type == .bookJump,
              let rawAction = surface.payload.metadata["bookJumpAction"],
              let action = BookJumpAction(rawValue: rawAction) else {
            return
        }
        let current = vault.data.bookJump ?? BookJumpState()
        let activeBefore = current.active
        let next: BookJumpState
        switch action {
        case .start:
            next = BookJumpEngine.start(from: surface)
            BookFeedback.bookJump(.start)
        case .advance:
            next = BookJumpEngine.advance(current, line: surface.payload.headline, direction: surface.payload.metadata["bookJumpChosenDirection"]?.nonEmpty)
            BookFeedback.bookJump(.deeper)
        case .stabilize:
            next = BookJumpEngine.stabilize(current, line: input)
            BookFeedback.bookJump(.stabilize)
        case .return:
            next = BookJumpEngine.return(current, souvenir: input, outcome: surface.payload.headline)
            BookFeedback.bookJump(.returnHome)
        }
        vault.data.bookJump = next
        vault.save()
        if action == .return, let active = activeBefore {
            applyBookJumpReturnEffects(active: active, souvenir: input, next: next)
        }
        surfaceRefreshDate = Date()
    }

    /// A safe return leaves marks on the living world: the guide who traveled
    /// with you deepens, a companion-flavored rule warms the cast web, and the
    /// borrowed rule is announced.
    func applyBookJumpReturnEffects(active: ActiveBookJump, souvenir: String, next: BookJumpState) {
        // The guide shared an adventure; their standing rises a little.
        let cast = NarrativePackRegistry.entities + customCastMembers.map(\.entity)
        if let guide = cast.first(where: { $0.name == active.guide }) {
            applyEntityEconomyDelta(
                entityID: guide.id,
                name: guide.name,
                delta: 2,
                sourcePageType: .bookJump,
                note: "\(guide.name) guided you into \(active.title) and came back changed by the trip."
            )
        }

        let granted = next.borrowedRules.first { $0.bookID == active.bookID }
        // A companionship rule warms the thread between the guide and the cast.
        if granted?.effect == .warmTheCast, let guide = cast.first(where: { $0.name == active.guide }) {
            let other = cast.first { $0.id != guide.id && $0.kind == .character }
            if let other {
                var field = vault.data.relationshipField ?? [:]
                RelationshipFieldEngine.weave(into: &field, entityIDs: [guide.id, other.id], warmth: 3, familiarity: 1)
                vault.data.relationshipField = field
                vault.save()
            }
        }

        if let rule = granted {
            statusMessage = "You carried a rule home from \(rule.bookTitle): \u{201C}\(rule.text)\u{201D} — \(rule.effect.title) holds for a few days."
        }
    }

    func applyGeneratedChapterTalismanDeltas(from surface: SurfacePage) {
        guard [.gossip, .narrativeOS, .letter].contains(surface.type),
              let raw = surface.payload.metadata["chapterTalismanDeltas"]?.nonEmpty else { return }
        guard surface.type != .gossip || !gossipBeliefMovesAlreadyResolved(for: surface) else { return }
        let deltas = raw
            .split(separator: ",")
            .compactMap { token -> (String, Int)? in
                let parts = token.split(separator: ":", maxSplits: 1).map(String.init)
                guard parts.count == 2, let delta = Int(parts[1]), delta != 0 else { return nil }
                return (parts[0], delta)
            }
        guard !deltas.isEmpty else { return }

        for (talismanID, delta) in deltas {
            guard let chapter = AcademyChapterRegistry.chapter(forTalismanID: talismanID) else { continue }
            let talisman = GlowEntityMenuItem(
                id: chapter.talismanID,
                name: chapter.talismanName,
                kind: "talisman",
                glow: 0,
                line: chapter.philosophy
            )
            adjustEntityBelief(
                talisman,
                delta: delta,
                kind: delta > 0 ? .beliefInvested : .beliefAttacked
            )
        }
    }

    func recordNarrativeEvent(for page: BookPage) {
        do {
            let consequenceWorld = storyConsequenceWorldSnapshot()
            let events = NarrativeEventResolver.events(forKept: page, world: consequenceWorld)
            for event in events {
                try BookDatabase.upsertNarrativeEvent(event)
                for memory in NarrativeEntityMemoryResolver.memories(for: event) {
                    try BookDatabase.upsertEntityMemory(memory)
                }
            }
            applyStoryConsequences(for: page, world: consequenceWorld)
            narrativeEvents = try BookDatabase.narrativeEvents(limit: 160)
            entityMemories = NarrativeEntityMemoryConsolidator.consolidate(try BookDatabase.entityMemories(limit: 240))
        } catch {
            statusMessage = "The page is kept, but one hidden margin note slipped: \(error.localizedDescription)"
        }
        tendArc()
        tendAlmanac()
        tendFae()
        tendPact()
        tendConstellations()
    }

    func storyConsequenceWorldSnapshot() -> StoryConsequenceWorldSnapshot {
        StoryConsequenceWorldSnapshot(storyRituals: vault.data.storyRituals ?? [:])
    }

    func applyStoryConsequences(for page: BookPage, world: StoryConsequenceWorldSnapshot? = nil) {
        let consequences = StoryConsequenceResolver.resolvedConsequences(
            forKept: page,
            world: world ?? storyConsequenceWorldSnapshot()
        )
        guard !consequences.isEmpty else { return }

        var state = StoryConsequenceApplicationState(
            relationshipField: vault.data.relationshipField ?? [:],
            storyRecipeBoosts: vault.data.storyRecipeBoosts ?? [:],
            storyMotifs: vault.data.storyMotifs ?? [:],
            storyRituals: vault.data.storyRituals ?? [:],
            storySettingAffinities: vault.data.storySettingAffinities ?? [:],
            storySceneBiases: vault.data.storySceneBiases ?? [:],
            bookNoticeEvidence: vault.data.bookNoticeEvidence ?? 0,
            nothingGreyOffset: vault.data.nothingGreyOffset ?? 0,
            fae: vault.data.fae ?? FaePlayerState()
        )
        StoryConsequenceApplicator.apply(consequences, to: &state)

        for (entityID, delta) in state.entityBeliefDeltas {
            applyEntityBeliefLedgerDelta(entityID: entityID, delta: delta)
        }

        let oldRelationshipField = vault.data.relationshipField ?? [:]
        let oldRecipeBoosts = vault.data.storyRecipeBoosts ?? [:]
        let oldMotifs = vault.data.storyMotifs ?? [:]
        let oldRituals = vault.data.storyRituals ?? [:]
        let oldSettingAffinities = vault.data.storySettingAffinities ?? [:]
        let oldSceneBiases = vault.data.storySceneBiases ?? [:]
        let oldBookNoticeEvidence = vault.data.bookNoticeEvidence ?? 0
        let oldNothingGreyOffset = vault.data.nothingGreyOffset ?? 0
        let oldFae = vault.data.fae ?? FaePlayerState()

        let shouldSaveVault = state.relationshipField != oldRelationshipField ||
            state.storyRecipeBoosts != oldRecipeBoosts ||
            state.storyMotifs != oldMotifs ||
            state.storyRituals != oldRituals ||
            state.storySettingAffinities != oldSettingAffinities ||
            state.storySceneBiases != oldSceneBiases ||
            state.bookNoticeEvidence != oldBookNoticeEvidence ||
            state.nothingGreyOffset != oldNothingGreyOffset ||
            state.fae != oldFae

        if shouldSaveVault {
            vault.data.relationshipField = state.relationshipField
            vault.data.storyRecipeBoosts = state.storyRecipeBoosts
            vault.data.storyMotifs = state.storyMotifs
            vault.data.storyRituals = state.storyRituals
            vault.data.storySettingAffinities = state.storySettingAffinities
            vault.data.storySceneBiases = state.storySceneBiases
            vault.data.bookNoticeEvidence = state.bookNoticeEvidence
            vault.data.nothingGreyOffset = state.nothingGreyOffset
            vault.data.fae = state.fae
            vault.save()
        }
    }

    /// When the reader seals and sends a reply to a letter, the sender remembers
    /// it for good: an oblique entity memory that future letters glance at through
    /// the per-sender memory packet (StoryEngine.memoryPacket).
    func recordPenPalReplyMemory(for page: BookPage, surface: SurfacePage) {
        let reply = page.playerReply.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reply.isEmpty,
              let senderID = surface.payload.metadata["senderID"]?.nonEmpty else { return }
        let senderName = surface.payload.metadata["senderName"]?.nonEmpty ?? "They"
        let memory = NarrativeEntityMemory(
            id: "pen-pal-reply-\(page.id)-\(senderID)",
            entityID: senderID,
            sourceEventID: "pen-pal-reply-\(page.id)",
            sourcePageID: page.id,
            summary: CharacterLetterPageGenerator.penPalReplyMemorySummary(senderName: senderName, reply: reply),
            tags: ["letter", "reply", "pen-pal", "sender:\(senderID)"],
            narrativeWeight: 5,
            createdAt: page.createdAt
        )
        do {
            try BookDatabase.upsertEntityMemory(memory)
            entityMemories = NarrativeEntityMemoryConsolidator.consolidate(try BookDatabase.entityMemories(limit: 240))
        } catch {
            statusMessage = "Your reply is sealed, but one margin note slipped: \(error.localizedDescription)"
        }
    }

    func recordStudentNoteReplyMemory(for page: BookPage, surface: SurfacePage) {
        let reply = page.playerReply.trimmingCharacters(in: .whitespacesAndNewlines)
        guard surface.type == .note,
              !reply.isEmpty,
              let senderID = surface.payload.metadata["senderID"]?.nonEmpty else { return }
        let senderName = surface.payload.metadata["senderName"]?.nonEmpty ?? "They"
        let memory = NarrativeEntityMemory(
            id: "student-note-reply-\(page.id)-\(senderID)",
            entityID: senderID,
            sourceEventID: "student-note-reply-\(page.id)",
            sourcePageID: page.id,
            summary: StudentNotePageGenerator.noteReplyMemorySummary(senderName: senderName, reply: reply),
            tags: ["note", "reply", "student-note", "sender:\(senderID)"],
            narrativeWeight: 4,
            createdAt: page.createdAt
        )
        do {
            try BookDatabase.upsertEntityMemory(memory)
            entityMemories = NarrativeEntityMemoryConsolidator.consolidate(try BookDatabase.entityMemories(limit: 240))
        } catch {
            statusMessage = "Your note is folded, but one margin memory slipped: \(error.localizedDescription)"
        }
    }

    /// The ArcKeeper checks the field whenever events land: promotion,
    /// phase turns, and completion all announce themselves in-world.
    @MainActor
    func tendArc(now: Date = Date()) {
        let (arc, announcement) = ArcKeeper.evaluate(
            current: vault.data.currentArc,
            events: narrativeEvents,
            lastCompletedThreadID: vault.data.lastCompletedArcThreadID,
            now: now
        )
        let completed = vault.data.currentArc != nil && arc == nil
        if completed {
            vault.data.lastCompletedArcThreadID = vault.data.currentArc?.threadID
        }
        if arc != vault.data.currentArc {
            vault.data.currentArc = arc
            vault.save()
            surfaceRefreshDate = now
        }
        if let announcement {
            statusMessage = announcement
            BookFeedback.play(.sourceRefresh)
        }
    }

    /// The Fae give first. This sweeps lapsed debts (colding their fronted gifts
    /// and closing that market) and, when eligible, fronts a fresh bargain.
    func tendFae(now: Date = Date()) {
        guard scenePhase == .active else { return }
        var state = vault.data.fae ?? FaePlayerState()
        var changed = false
        if !FaeEconomy.sweepLapses(into: &state, now: now).isEmpty {
            changed = true
        }
        if !FaeEconomy.expireStaleOffers(into: &state, now: now).isEmpty {
            changed = true
        }
        if FaeEconomy.canOfferBargain(state: state, now: now) {
            let slot = BookDay.id(for: now)
            let kind = FaeEconomy.chooseFae(state: state, slot: slot)
            FaeEconomy.offerBargain(into: &state, kind: kind, slot: slot, now: now)
            changed = true
        }
        if changed {
            vault.data.fae = state
            vault.save()
            surfaceRefreshDate = now
        }
    }

    /// The Talisman that holds the Whisper Channel (Controlled+), if any — it
    /// recolors the Book's notifications.
    var whisperController: String? {
        let war = vault.data.pactWar ?? PactWarState()
        return war.tier(of: "integ-notifications") >= .controlled
            ? war.controller(of: "integ-notifications")
            : nil
    }

    /// True when a Talisman reigns Sovereign over the Whisper Channel — it earns
    /// an extra unprompted whisper.
    var whisperSovereign: Bool {
        (vault.data.pactWar ?? PactWarState()).tier(of: "integ-notifications") == .sovereign
    }

    /// Tonight's festival, phrased as a whisper, if the Wheel is keeping a feast.
    var festivalWhisperToday: (title: String, body: String)? {
        guard let celebration = Almanac.active(on: Date(), hemisphere: Hemisphere.from(latitude: lastAnchorReadingLatitude)) else { return nil }
        return (title: "Tonight: \(celebration.academyTitle)", body: celebration.invitation)
    }

    /// Today's active authored world event, phrased as a whisper.
    var worldEventWhisperToday: (title: String, body: String)? {
        let events = sourceInputs.resolvingWorldEvents(for: today, now: Date()).activeWorldEvents
        guard let event = events.first,
              let body = events.widgetWhisperLine else { return nil }
        return (title: event.title, body: body)
    }

    /// The Talisman of the Chapter the reader is Bound to, if any — gets a
    /// home-field bonus in the Pact War.
    var boundTalismanID: String? {
        guard let fact = selfFacts.first(where: { $0.questionID == "chapter-binding" }) else { return nil }
        let chapter = AcademyChapterRegistry.chapter(named: fact.answer)
            ?? AcademyChapterRegistry.chapters.first { fact.tags.contains($0.id) }
        return chapter?.talismanID
    }

    /// Stir the Pact War one tick (daily, distress-gated). Pure local sim — no
    /// model call, runs alongside tendArc/tendFae.
    func tendPact(now: Date = Date()) {
        guard scenePhase == .active else { return }
        var state = vault.data.pactWar ?? PactWarState()
        let distress = DistressSignals.evaluate(day: today).isActive
        let dispatchesBefore = Set(state.pendingDispatches.map(\.id))
        let records = PactWarEngine.tick(
            into: &state,
            entityBeliefOffsets: entityBeliefLedger,
            boundTalismanID: boundTalismanID,
            now: now,
            distressActive: distress
        )

        // Errands age and arrive independently of the once-a-day tick, but stay
        // silent under distress like the rest of the war. A talisman with a real
        // foothold sends the reader out; an unpaid errand eventually lapses.
        var changed = !records.isEmpty
        if !distress {
            if !PactWarEngine.sweepErrandLapses(into: &state, now: now).isEmpty { changed = true }
            if PactWarEngine.offerErrand(into: &state, now: now) != nil { changed = true }
        }
        guard changed else { return }
        vault.data.pactWar = state

        // A Talisman reaching Sovereign is "something significant" — the rare
        // moment the Marginalia Clans appear. Front a goblin bargain if the
        // reader has no open one. Pure local; no model call.
        let newSovereign = state.pendingDispatches.contains {
            $0.kind == .sovereign && !dispatchesBefore.contains($0.id)
        }
        if newSovereign {
            var fae = vault.data.fae ?? FaePlayerState()
            if FaeEconomy.canOfferBargain(state: fae, now: now) {
                FaeEconomy.offerBargain(into: &fae, kind: .goblin, slot: "sovereign-\(BookDay.id(for: now))", now: now)
                vault.data.fae = fae
            }
        }

        vault.save()
        surfaceRefreshDate = now
    }

    /// Greet a returning reader by name with a rotating opener and one remembered
    /// line. Live world-state belongs in the hero subtitle; this first-open note
    /// is for being known, welcomed, and gently invited back into noticing.
    func presentReturningGreetingIfNeeded() {
        guard didCompleteStoryOnboarding, !didShowGreetingThisLaunch else { return }
        didShowGreetingThisLaunch = true

        let inputs = sourceInputs
        let context = BookGreetingContext(
            name: CharacterLetterPageGenerator.preferredPlayerName(inputs: inputs),
            rememberedFactLines: greetingRememberedFactLines(),
            recentKeptLines: greetingRecentKeptLines(),
            keptPageCount: keptPageCount,
            quietDays: inputs.quietDays,
            seed: Int(Date().timeIntervalSince1970 / 60),
            relationship: BookRelationshipLedger.snapshot(inputs: inputs),
            interior: inputs.bookInterior
        )
        let greeting = BookGreetingComposer.compose(context)
        withAnimation(.spring(response: 0.6, dampingFraction: 0.82)) {
            activeGreeting = greeting
        }
        BookFeedback.play(.openPage)
        Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled, activeGreeting == greeting else { return }
            withAnimation(.easeOut(duration: 0.5)) { activeGreeting = nil }
        }
    }

    /// Larger readings warm only when the reader gives the Book substantive
    /// attention. App foregrounding never calls this path.
    func recordMeaningfulAttention(key: String, now: Date = Date()) {
        guard didCompleteStoryOnboarding, !key.isEmpty else { return }
        let current = vault.data.magicMoment ?? MagicMomentState()
        let updated = MagicMomentGovernor.recordingMeaningfulAction(
            current,
            key: key,
            now: now
        )
        guard updated != current else { return }
        vault.data.magicMoment = updated
        vault.save()
        surfaceRefreshDate = now
    }

    /// Opening or deliberately passing an earned reveal counts as receiving
    /// the moment. It also records the exact evidence-scoped reading so the
    /// Book never repeats the conversation as though it were new.
    func recordMagicMomentInteraction(
        _ surface: SurfacePage,
        status: BookObservationStatus,
        now: Date = Date()
    ) {
        guard BookObservationLedger.key(for: surface) != nil else { return }
        vault.data.bookObservations = BookObservationLedger.recording(
            surface: surface,
            status: status,
            in: vault.data.bookObservations ?? [],
            now: now
        )
        if surface.payload.metadata["magicMoment"] == "true" {
            let key = BookObservationLedger.key(for: surface) ?? surface.id
            vault.data.magicMoment = MagicMomentGovernor.consuming(
                vault.data.magicMoment ?? MagicMomentState(),
                key: key,
                now: now
            )
        }
        vault.save()
    }

    func greetingRememberedFactLines() -> [String] {
        selfFacts
            .filter { $0.usePermission != .doNotUse }
            .filter { !$0.tags.contains("name") && !$0.questionID.lowercased().contains("name") && $0.questionID != "called" }
            .sorted { $0.updatedAt > $1.updatedAt }
            .compactMap { fact in
                if let translation = fact.bookTranslation.nonEmpty {
                    return translation.bookPreviewSentenceLimit(1)
                }
                if fact.usePermission == .quoteAllowed {
                    return fact.answer.nonEmpty?.bookPreviewSentenceLimit(1)
                }
                return nil
            }
            .prefix(5)
            .map { $0 }
    }

    func greetingRecentKeptLines() -> [String] {
        let pages = (days.flatMap(\.capturedPages) + today.capturedPages)
            .sorted { $0.createdAt > $1.createdAt }
        var seen = Set<String>()
        return pages.compactMap { page in
            let line = page.archivePreviewText?
                .bookPreviewSentenceLimit(1)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let line, seen.insert(line).inserted else { return nil }
            return line
        }
        .prefix(5)
        .map { $0 }
    }

    /// The Wheel stirs the Fae: Samhain opens the door for a Marginalia Clan
    /// (goblin) bargain; the full moon opens a window for any fae. Pure local;
    /// no model call. `canOfferBargain` keeps it to one at a time.
    func tendAlmanac(now: Date = Date()) {
        guard scenePhase == .active else { return }
        var fae = vault.data.fae ?? FaePlayerState()
        guard FaeEconomy.canOfferBargain(state: fae, now: now) else { return }
        let hemisphere = Hemisphere.from(latitude: lastAnchorReadingLatitude)
        let active = Almanac.celebrations(on: now, hemisphere: hemisphere)
        let slotDay = BookDay.id(for: now)
        if active.contains(where: { $0.id == "sabbat-samhain" }) {
            FaeEconomy.offerBargain(into: &fae, kind: .goblin, slot: "samhain-\(slotDay)", now: now)
        } else if active.contains(where: { $0.id == "esbat-full" }) {
            let kind = FaeEconomy.chooseFae(state: fae, slot: "fullmoon-\(slotDay)")
            FaeEconomy.offerBargain(into: &fae, kind: kind, slot: "fullmoon-\(slotDay)", now: now)
        } else {
            return
        }
        vault.data.fae = fae
        vault.save()
        surfaceRefreshDate = now
    }

    /// Invest Belief to press a Talisman's claim on a territory (player as
    /// combatant). Adds Control Belief directly and warms the Talisman.
    func pressPactClaim(talismanID: String, territoryID: String, now: Date = Date()) {
        var state = vault.data.pactWar ?? PactWarState()
        let key = PactWarState.key(talismanID, territoryID)
        state.control[key] = max(0, min(100, (state.control[key] ?? 0) + 4))
        vault.data.pactWar = state
        vault.save()
        if let chapter = AcademyChapterRegistry.chapter(forTalismanID: talismanID) {
            let talisman = GlowEntityMenuItem(id: talismanID, name: chapter.talismanName, kind: "talisman", glow: 0, line: chapter.philosophy)
            adjustEntityBelief(talisman, delta: 1, kind: .beliefInvested)
        }
        surfaceRefreshDate = now
        BookFeedback.play(.select)
    }

    /// Rule a contested reading: the reader decides which Talisman's philosophy
    /// truly read one of their real kept pages. The winner gains ground on the
    /// territory that governs that page, the loser gives a little, and the verdict
    /// can seize a territory or crown a Sovereign — the reader, not the simulation,
    /// driving the war. Pure local; no model call.
    func rulePactVerdict(winnerTalismanID: String, loserTalismanID: String, territoryID: String, pageID: String, now: Date = Date()) {
        var state = vault.data.pactWar ?? PactWarState()
        let before = state
        state.adjust(winnerTalismanID, territoryID, by: 6)
        state.adjust(loserTalismanID, territoryID, by: -2)

        let winnerName = AcademyChapterRegistry.chapter(forTalismanID: winnerTalismanID)?.talismanName ?? winnerTalismanID
        let territoryName = PactTerritoryRegistry.territory(id: territoryID)?.name ?? "this territory"
        let record = PactActionRecord(
            id: "\(territoryID)-\(winnerTalismanID)-\(Int(now.timeIntervalSince1970))-verdict",
            talismanID: winnerTalismanID,
            territoryID: territoryID,
            kind: .verdict,
            at: now,
            line: "\(winnerName) wins your reading of the day, and gains \(territoryName)."
        )
        state.log = ([record] + state.log).prefix(24).map { $0 }

        let newSovereign = PactWarEngine.detectCrossings(before: before, into: &state, now: now)
        vault.data.pactWar = state

        // A reader-made Sovereign crossing fronts a goblin bargain, exactly like the tick.
        if newSovereign {
            var fae = vault.data.fae ?? FaePlayerState()
            if FaeEconomy.canOfferBargain(state: fae, now: now) {
                FaeEconomy.offerBargain(into: &fae, kind: .goblin, slot: "verdict-sovereign-\(BookDay.id(for: now))", now: now)
                vault.data.fae = fae
            }
        }
        vault.save()

        // Warm the winning Talisman as a believed-in entity (mirrors pressPactClaim).
        if let chapter = AcademyChapterRegistry.chapter(forTalismanID: winnerTalismanID) {
            let talisman = GlowEntityMenuItem(id: winnerTalismanID, name: chapter.talismanName, kind: "talisman", glow: 0, line: chapter.philosophy)
            adjustEntityBelief(talisman, delta: 1, kind: .beliefInvested)
        }

        // Tag the original kept page so this reading is never re-asked.
        if let dayIndex = days.firstIndex(where: { $0.pages.contains { $0.id == pageID } }),
           let pageIndex = days[dayIndex].pages.firstIndex(where: { $0.id == pageID }) {
            var day = days[dayIndex]
            var page = day.pages[pageIndex]
            if !page.tags.contains("pact-verdict:\(pageID)") {
                page.tags = Set(page.tags).union(["pact-verdict:\(pageID)"]).sorted()
                day.pages[pageIndex] = page
                persist(day: day, message: "You ruled the reading. \(winnerName) gains \(territoryName).")
            }
        }

        surfaceRefreshDate = now
        BookFeedback.play(.braidComplete)
    }

    /// Pay a Talisman's Errand with a real field report: the talisman gains Control
    /// Belief on its territory, may seize it or crown a Sovereign, and warms as a
    /// believed-in entity. The reader's lived noticing becomes the war's ground.
    func payPactErrand(errandID: String, report: String, now: Date = Date()) {
        var state = vault.data.pactWar ?? PactWarState()
        let talismanID = state.errands.first { $0.id == errandID }?.talismanID
        let newSovereign = PactWarEngine.deliverErrand(errandID: errandID, report: report, into: &state, now: now)
        vault.data.pactWar = state

        if newSovereign {
            var fae = vault.data.fae ?? FaePlayerState()
            if FaeEconomy.canOfferBargain(state: fae, now: now) {
                FaeEconomy.offerBargain(into: &fae, kind: .goblin, slot: "errand-sovereign-\(BookDay.id(for: now))", now: now)
                vault.data.fae = fae
            }
        }
        vault.save()

        if let talismanID, let chapter = AcademyChapterRegistry.chapter(forTalismanID: talismanID) {
            let talisman = GlowEntityMenuItem(id: talismanID, name: chapter.talismanName, kind: "talisman", glow: 0, line: chapter.philosophy)
            adjustEntityBelief(talisman, delta: 1, kind: .beliefInvested)
        }
        surfaceRefreshDate = now
        BookFeedback.play(.braidComplete)
    }

    /// Pay (or repair) a Fae Bargain: closes the debt, thaws the fronted gift,
    /// and pays warmth and attention. The fae's spoken reply is the reward.
    func payFaeBargain(bargainID: String, report: String, faeResponse: String, now: Date = Date()) {
        var state = vault.data.fae ?? FaePlayerState()
        FaeEconomy.deliver(
            bargainID: bargainID,
            report: report,
            faeResponse: faeResponse,
            reward: faeResponse,
            into: &state,
            now: now
        )
        vault.data.fae = state
        vault.save()
        surfaceRefreshDate = now
        BookFeedback.play(.braidComplete)
    }

    /// Write the next new-moon Goblin Market window into the real Calendar.
    /// User-initiated; no model call.
    @MainActor
    func addNextMarketToCalendar() async {
        let newMoon = MoonPhaseCalendar.nextNewMoon(after: Date())
        let start = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: newMoon) ?? newMoon
        let end = start.addingTimeInterval(3_600)
        let ok = await EventKitWriter.addEvent(
            title: "The Goblin Market opens",
            notes: "New moon. The Goblin Market is open in ReEnchanted — spend Attention on a Fae gift.",
            start: start,
            end: end
        )
        statusMessage = ok
            ? "The next Goblin Market is marked on your calendar (new moon)."
            : "The market could not be added (check Calendar permission in Settings)."
        BookFeedback.play(ok ? .select : .error)
    }

    /// A kept page that holds two or more characters weaves them in the
    /// relationship field. A story scene escalates whatever dynamic already
    /// exists between a pair — two characters in conflict grow *more* tense, not
    /// warmer — while gossip and co-occurrence build familiarity and warmth.
    func weaveRelationshipField(for page: BookPage) {
        let ids = RelationshipFieldEngine.entityIDs(fromTags: page.tags)
        guard ids.count >= 2 else { return }
        var field = vault.data.relationshipField ?? [:]
        switch page.type {
        case .narrativeOS:
            // Per pair: deepen the dominant tone so a scene's conflicts bite.
            let conflict = page.tags.contains { $0.hasPrefix("choice:") && ($0.contains("conflict") || $0.contains("progressarc") || $0.contains("surprise")) }
            let sorted = Array(Set(ids)).sorted()
            for i in sorted.indices {
                for j in sorted.indices where j > i {
                    let key = NarrativeGraphData.relationshipPairKey(sorted[i], sorted[j])
                    let tie = field[key] ?? .zero
                    if conflict || tie.tension > tie.warmth {
                        RelationshipFieldEngine.weave(into: &field, entityIDs: [sorted[i], sorted[j]], tension: 1, familiarity: 1)
                    } else {
                        RelationshipFieldEngine.weave(into: &field, entityIDs: [sorted[i], sorted[j]], warmth: 1, familiarity: 1)
                    }
                }
            }
        case .gossip:
            RelationshipFieldEngine.weave(into: &field, entityIDs: ids, warmth: 1, familiarity: 1)
        default:
            RelationshipFieldEngine.weave(into: &field, entityIDs: ids, familiarity: 1)
        }
        vault.data.relationshipField = field
        vault.save()
    }

    func runCastAgencyTurnIfNeeded(now: Date = Date()) {
        guard didCompleteStoryOnboarding else { return }
        let slotID = SurfaceCadence.slotID(for: now, hours: 4)
        var state = vault.data.castAgency ?? CastAgencyState()
        guard !state.hasResolved(slotID: slotID) else { return }

        let inputs = sourceInputs
        let hasStoryMaterial = !today.capturedPages.isEmpty
            || inputs.weather != nil
            || inputs.body != nil
            || inputs.narrative?.recentTags.isEmpty == false
        guard hasStoryMaterial else { return }

        let context = CuratorContext.make(for: today)
        guard !context.distress.isActive else { return }

        var draftInputs = inputs
        draftInputs.preparedGossipPageSurface = nil
        let surface = GossipSimulationBuilder.surface(for: today, inputs: draftInputs, now: now)
        let movement = applySingleCastAgencyMove(from: surface, slotID: slotID, now: now)
        let recentSlots = recentCastAgencySlots(around: now)
        if let movement {
            state.remember(movement, keepingRecentSlots: recentSlots)
            isCastLedgerExpanded = true
            statusMessage = "Cast turn: \(movement.line)"
            surfaceRefreshDate = now
        } else {
            state.markEmptySlot(slotID, keepingRecentSlots: recentSlots)
        }
        vault.data.castAgency = state
        vault.save()
    }

    func recentCastAgencySlots(around now: Date) -> Set<String> {
        let calendar = Calendar.current
        return Set((0..<12).map { offset in
            let date = calendar.date(byAdding: .hour, value: -4 * offset, to: now) ?? now
            return SurfaceCadence.slotID(for: date, hours: 4)
        })
    }

    func gossipBeliefMovesAlreadyResolved(for surface: SurfacePage) -> Bool {
        guard surface.type == .gossip else { return false }
        return (vault.data.castAgency ?? CastAgencyState()).hasResolved(slotID: surface.payload.metadata["slotID"])
    }

    func applySingleCastAgencyMove(from surface: SurfacePage, slotID: String, now: Date) -> CastAgencyMovement? {
        let relationshipTokens = surface.payload.metadata["relationshipMoves"]?
            .split(separator: "|")
            .map(String.init)
            .filter { !$0.isEmpty } ?? []
        let pageTokens = surface.payload.metadata["pageBeliefMoves"]?
            .split(separator: "|")
            .map(String.init)
            .filter { !$0.isEmpty } ?? []
        let preferRelationship = abs("\(slotID)-cast-agency".stableHash) % 2 == 0

        if preferRelationship, let token = relationshipTokens.first,
           let movement = applyGossipRelationshipMoveTokens(token, sourcePageType: .gossip, limit: 1, slotID: slotID, now: now).first {
            return movement
        }
        if let token = pageTokens.first,
           let movement = applyGossipPageBeliefMoveTokens(token, sourcePageType: .gossip, limit: 1, slotID: slotID, now: now).first {
            return movement
        }
        if let token = relationshipTokens.first,
           let movement = applyGossipRelationshipMoveTokens(token, sourcePageType: .gossip, limit: 1, slotID: slotID, now: now).first {
            return movement
        }
        return nil
    }

    /// Apply the character-to-character Belief moves a gossip page recorded:
    /// invest warms the pair and lifts the target's Belief; attack tenses them
    /// and chips it. Pure local; the structured tokens drive it, not the prose.
    func applyGossipRelationshipMoves(from surface: SurfacePage) {
        guard surface.type == .gossip,
              let raw = surface.payload.metadata["relationshipMoves"]?.nonEmpty else { return }
        guard !gossipBeliefMovesAlreadyResolved(for: surface) else { return }
        _ = applyGossipRelationshipMoveTokens(raw, sourcePageType: surface.type)
    }

    @discardableResult
    func applyGossipRelationshipMoveTokens(
        _ raw: String,
        sourcePageType: BookPageType?,
        limit: Int? = nil,
        slotID: String? = nil,
        now: Date = Date()
    ) -> [CastAgencyMovement] {
        var field = vault.data.relationshipField ?? [:]
        var movements: [CastAgencyMovement] = []
        var applied = 0
        for token in raw.split(separator: "|") {
            if let limit, applied >= limit { break }
            // format: actorID>targetID:kind:amount
            let halves = token.split(separator: ":")
            guard halves.count == 3,
                  let amount = Int(halves[2]) else { continue }
            let pair = halves[0].split(separator: ">").map(String.init)
            guard pair.count == 2 else { continue }
            let (actorID, targetID) = (pair[0], pair[1])
            let kind = String(halves[1])
            let actorName = castName(for: actorID)
            let target = GlowEntityMenuItem(id: targetID, name: castName(for: targetID), kind: "character", glow: 0, line: "")
            let actorGlow = effectiveCastBelief(for: actorID)
            let actorSpend = BeliefEconomyEngine.castSpendDelta(actorBelief: actorGlow, requested: amount)
            // The actor can only move as much Belief as they can actually spend
            // (down to their floor). Conserve it: an investor never mints Belief.
            let spent = -actorSpend
            if actorSpend != 0 {
                applyEntityEconomyDelta(
                    entityID: actorID,
                    name: actorName,
                    delta: actorSpend,
                    sourcePageType: sourcePageType,
                    note: "\(actorName) spent \(spent) Belief moving the cast web."
                )
            }
            var line: String
            if kind == GossipRelationshipMoveKind.invest.rawValue {
                // Invest is a transfer: the target gains exactly what the actor
                // paid. A depleted actor can't gift Belief they don't have.
                guard spent > 0 else {
                    RelationshipFieldEngine.weave(into: &field, entityIDs: [actorID, targetID], familiarity: 1)
                    line = "\(actorName) tried to talk up \(target.name), but only a little familiarity moved."
                    if let slotID {
                        movements.append(CastAgencyMovement(slotID: slotID, kind: .relationship, actorID: actorID, actorName: actorName, targetID: target.id, targetName: target.name, amount: 0, line: line, createdAt: now))
                    }
                    applied += 1
                    continue
                }
                applyEntityEconomyDelta(
                    entityID: target.id,
                    name: target.name,
                    delta: spent,
                    sourcePageType: sourcePageType,
                    note: "\(actorName) invested \(spent) Belief in \(target.name)."
                )
                RelationshipFieldEngine.weave(into: &field, entityIDs: [actorID, targetID], warmth: spent, familiarity: 1)
                line = "\(actorName) invested \(spent) Belief in \(target.name)."
            } else {
                applyEntityEconomyDelta(
                    entityID: target.id,
                    name: target.name,
                    delta: -amount,
                    sourcePageType: sourcePageType,
                    note: "\(actorName) chipped \(amount) Belief from \(target.name)."
                )
                RelationshipFieldEngine.weave(into: &field, entityIDs: [actorID, targetID], tension: amount, familiarity: 1)
                line = "\(actorName) chipped \(amount) Belief from \(target.name)."
            }
            if let slotID {
                movements.append(CastAgencyMovement(slotID: slotID, kind: .relationship, actorID: actorID, actorName: actorName, targetID: target.id, targetName: target.name, amount: amount, line: line, createdAt: now))
            }
            applied += 1
        }
        vault.data.relationshipField = field
        vault.save()
        return movements
    }

    /// Apply the Cast-to-Page Belief moves a gossip page recorded. Cast members
    /// can now contest actual Page sources: investing spends their Glow into a
    /// Page kind, while attacking cools that Page kind and can feed the actor.
    func applyGossipPageBeliefMoves(from surface: SurfacePage) {
        guard surface.type == .gossip,
              let raw = surface.payload.metadata["pageBeliefMoves"]?.nonEmpty else { return }
        guard !gossipBeliefMovesAlreadyResolved(for: surface) else { return }
        _ = applyGossipPageBeliefMoveTokens(raw, sourcePageType: surface.type)
    }

    @discardableResult
    func applyGossipPageBeliefMoveTokens(
        _ raw: String,
        sourcePageType: BookPageType?,
        limit: Int? = nil,
        slotID: String? = nil,
        now: Date = Date()
    ) -> [CastAgencyMovement] {
        var movements: [CastAgencyMovement] = []
        var appliedCount = 0
        for token in raw.split(separator: "|") {
            if let limit, appliedCount >= limit { break }
            // format: actorID>sourceID:kind:amount
            let halves = token.split(separator: ":")
            guard halves.count == 3,
                  let amount = Int(halves[2]) else { continue }
            let pair = halves[0].split(separator: ">").map(String.init)
            guard pair.count == 2 else { continue }
            let (actorID, sourceID) = (pair[0], pair[1])
            let kind = String(halves[1])
            let actorName = castName(for: actorID)
            let source = BookPageSourceRegistry.source(id: sourceID)

            if kind == GossipPageBeliefMoveKind.invest.rawValue {
                let actorGlow = effectiveCastBelief(for: actorID)
                let actorSpend = BeliefEconomyEngine.castSpendDelta(actorBelief: actorGlow, requested: amount)
                let offered = -actorSpend
                guard offered > 0 else { continue }
                let applied = applyPageEconomyDelta(
                    sourceID: source.id,
                    name: source.title,
                    delta: offered,
                    sourcePageType: sourcePageType,
                    note: "\(actorName) gave \(offered) Belief to \(source.title) Pages.",
                    actorID: actorID
                )
                if applied > 0 {
                    applyEntityEconomyDelta(
                        entityID: actorID,
                        name: actorName,
                        delta: -applied,
                        sourcePageType: sourcePageType,
                        note: "\(actorName) spent \(applied) Belief making \(source.title) Pages more real."
                    )
                    if let slotID {
                        movements.append(CastAgencyMovement(slotID: slotID, kind: .pageSource, actorID: actorID, actorName: actorName, targetID: source.id, targetName: source.title, amount: applied, line: "\(actorName) gave \(applied) Belief to \(source.title) Pages.", createdAt: now))
                    }
                    appliedCount += 1
                }
            } else {
                let applied = applyPageEconomyDelta(
                    sourceID: source.id,
                    name: source.title,
                    delta: -amount,
                    sourcePageType: sourcePageType,
                    note: "\(actorName) tried to take \(amount) Belief from \(source.title) Pages.",
                    actorID: actorID
                )
                let taken = -applied
                if taken > 0 {
                    applyEntityEconomyDelta(
                        entityID: actorID,
                        name: actorName,
                        delta: taken,
                        sourcePageType: sourcePageType,
                        note: "\(actorName) took \(taken) Belief from \(source.title) Pages."
                    )
                    if let slotID {
                        movements.append(CastAgencyMovement(slotID: slotID, kind: .pageSource, actorID: actorID, actorName: actorName, targetID: source.id, targetName: source.title, amount: taken, line: "\(actorName) took \(taken) Belief from \(source.title) Pages.", createdAt: now))
                    }
                    appliedCount += 1
                }
            }
        }
        vault.save()
        return movements
    }

    /// Display name for a cast entity id (bundled or custom).
    func castName(for id: String) -> String {
        NarrativePackRegistry.entities.first { $0.id == id }?.name
            ?? customCastMembers.first { $0.id == id }?.name
            ?? id
    }

    /// The reader sided in The Two Readings: the chosen character gains Belief
    /// (and the reader spends one to give it), the other cools a little, and the
    /// disagreement is recorded so it echoes among the three.
    func applyTwoReadingsSiding(chosenID: String, chosenName: String, otherID: String, otherName: String) {
        let chosen = GlowEntityMenuItem(id: chosenID, name: chosenName, kind: "character", glow: 0, line: "")
        adjustEntityBelief(chosen, delta: 2, kind: .beliefInvested, playerBeliefDelta: -1)
        if !otherID.isEmpty {
            let other = GlowEntityMenuItem(id: otherID, name: otherName, kind: "character", glow: 0, line: "")
            adjustEntityBelief(other, delta: -1, kind: .beliefAttacked)
            // Judging their disagreement tenses the thread between the two in the Loom.
            var field = vault.data.relationshipField ?? [:]
            RelationshipFieldEngine.weave(into: &field, entityIDs: [chosenID, otherID], tension: 3, familiarity: 1)
            vault.data.relationshipField = field
            vault.save()
            surfaceRefreshDate = Date()
        }
        statusMessage = "You sided with \(chosenName). They warm by two; \(otherName) cools by one; you spent a point of Belief — and a thread tightens between them in the Loom."
        BookFeedback.play(.braidComplete)
    }

    /// Spend Attention at the Goblin Market for a gift. Pure local economy — no
    /// model call.
    /// Build today's living Goblin Market stall from the world's current state.
    func buildGoblinStall(now: Date = Date()) -> GoblinStall {
        let fae = vault.data.fae ?? FaePlayerState()
        let hemisphere = Hemisphere.from(latitude: lastAnchorReadingLatitude)
        let grey = NothingTide.greyLevel(
            quietDays: sourceInputs.quietDays,
            narrativeHeat: narrativeEvents.prefix(24).count,
            distressActive: DistressSignals.evaluate(day: today).isActive,
            celebrationGreyShift: Almanac.greyShift(on: now, hemisphere: hemisphere) + (vault.data.nothingGreyOffset ?? 0)
        )
        // The Goblins push the rare shelf out after a recent Book Jump collapse.
        let recentCollapse = (vault.data.bookJump?.returned.first { $0.souvenir.isEmpty })
            .map { now.timeIntervalSince($0.returnedAt) < 3 * 86_400 } ?? false
        return GoblinMarketEngine.stall(
            on: now,
            fae: fae,
            belief: beliefScore,
            greyLevel: grey,
            hemisphere: hemisphere,
            recentBookJumpCollapse: recentCollapse,
            ownedPackIDs: Set(vault.data.ownedPacks ?? [])
        )
    }

    /// Open a Fae bargain from the home desk. Opening is the moment of consent:
    /// if the bargain is still a proposal (.offered), accepting it here is what
    /// fronts the gift, pays the Claim, and starts the clock. Swiping the preview
    /// away instead never reaches this, so an untouched offer costs nothing.
    @MainActor
    func openFaeBargainSurface(_ surface: SurfacePage) {
        let metadata = surface.payload.metadata
        if metadata["status"] == FaeBargainStatus.offered.rawValue,
           let bargainID = metadata["bargainID"] {
            var state = vault.data.fae ?? FaePlayerState()
            if let accepted = FaeEconomy.acceptBargain(bargainID: bargainID, into: &state) {
                vault.data.fae = state
                vault.save()
                BookFeedback.faeArrival(kind: accepted.faeKind.rawValue, court: metadata["faeCourt"])
                surfaceRefreshDate = Date()
                selectedSurface = FaeBargainPageSourceAdapter.surface(for: accepted, state: state)
                return
            }
        }
        selectedSurface = surface
    }

    /// Open a specific owed/lapsed Fae bargain's page from the BookShop standing
    /// section: close the shop, then present the bargain so it can be paid.
    func openFaeBargainPage(_ bargain: FaeBargain) {
        isBookShopPresented = false
        let fae = vault.data.fae ?? FaePlayerState()
        let surface = FaeBargainPageSourceAdapter.surface(for: bargain, state: fae)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            selectedSurface = surface
        }
    }

    /// A unified in-world purchase: spend Attention or Belief, grant the good,
    /// and ripple into the living world (Warmth with the Goblins, a word to the
    /// cast). Money packs go through the StoreKit path in the sheet.
    func buyMarketWare(_ ware: MarketWare, now: Date = Date()) {
        var fae = vault.data.fae ?? FaePlayerState()
        let price = GoblinMarketEngine.price(ware, mood: FaeEconomy.mood(for: now), goblinWarmth: fae.warmth(for: .goblin))

        switch ware.currency {
        case .attention:
            guard fae.attention >= price else { BookFeedback.play(.error); return }
            fae.attention -= price
        case .belief:
            guard beliefScore >= price else { BookFeedback.play(.error); return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                beliefScore = max(0, beliefScore - price)
            }
        case .money:
            return // handled by StoreKit in the sheet
        }

        switch ware.good {
        case let .gift(effect, kind):
            fae.gifts.append(FaeGift(
                id: "shop-\(ware.id)-\(Int(now.timeIntervalSince1970))",
                faeKind: kind, name: ware.title, descriptionText: ware.contents,
                effect: effect, isCold: false, acquiredAt: now,
                chargesRemaining: effect == .callingCard ? 1 : nil, boundSourceID: nil
            ))
        case .warmWord:
            if let target = warmWordTarget() {
                applyEntityEconomyDelta(
                    entityID: target.id, name: target.name, delta: 1,
                    sourcePageType: nil,
                    note: "A warm word bought at the Goblin Market reached \(target.name)."
                )
            }
        case .pack:
            break
        case .pocketSunshine:
            vault.data.nothingGreyOffset = max(-10, (vault.data.nothingGreyOffset ?? 0) - 2)
            statusMessage = "The Pocket Sunshine opens in your coat. The grey backs up two careful steps."
        case .hummingJar:
            fae.attention += 3
            radioManager.tune(stationID: "fae-fi", unlockedPackIDs: Set(vault.data.ownedPacks ?? []))
            vault.data.radio = radioManager.playback
            statusMessage = "The Humming Jar pays out 3 Attention and finds Fae-Fi on the dial."
        case .porchlightLamp:
            radioManager.tune(stationID: "mothlight-beats", unlockedPackIDs: Set(vault.data.ownedPacks ?? []))
            vault.data.radio = radioManager.playback
            selectedSurface = freshManualSurface(for: .bookRemembered)
            statusMessage = "The Porchlight & Moth lamp comes on. Mothlight answers, and Book Remembered opens."
        case .rememberingBell:
            fae.warmth[FaeKind.literaryElf.rawValue, default: 0] += 2
            selectedSurface = freshManualSurface(for: .bookRemembered)
            statusMessage = "The Remembering Bell rings back. The Literary Elves warm by two, and Book Remembered opens."
        case .bramblewineDram:
            fae.attention += 5
            vault.data.nothingGreyOffset = min(10, (vault.data.nothingGreyOffset ?? 0) + 1)
            radioManager.tune(stationID: "thornwave", unlockedPackIDs: Set(vault.data.ownedPacks ?? []))
            vault.data.radio = radioManager.playback
            statusMessage = "The Bramblewine pays out 5 Attention. Thornwave catches, and the grey leans one shade closer."
        case .afterHoursCard:
            fae.lastMarketCardAt = now
            fae.warmth[FaeKind.goblin.rawValue, default: 0] += 2
            statusMessage = "Melisande stamps the card. Today's side door stays open, and the Goblins warm by two."
        }

        // Ripple: the Goblins warm to a paying customer, and they talk.
        fae.warmth["goblin", default: 0] += 1
        vault.data.fae = fae
        vault.save()
        recordGoblinPurchaseGossip(ware: ware, now: now)
        surfaceRefreshDate = now
        BookFeedback.play(.select)
    }

    /// Haggle: spend 1 Warmth with the Goblins for a discount. A feverish-mood
    /// goblin refuses and pockets the warmth anyway — the stake. Returns the
    /// discount, or nil if refused.
    func haggleWare(_ ware: MarketWare, now: Date = Date()) -> Int? {
        var fae = vault.data.fae ?? FaePlayerState()
        guard fae.warmth(for: .goblin) > 0 else { return nil }
        fae.warmth["goblin", default: 0] -= 1
        vault.data.fae = fae
        vault.save()
        // Feverish goblins are unreliable; otherwise standing earns a real cut.
        if FaeEconomy.mood(for: now) == .feverish { return nil }
        return 2
    }

    /// The Goblin clerk speaks — mercantile, precise, unpredictable — reacting to
    /// mood, the reader's standing, and the night. The shop's one model call,
    /// button-triggered.
    @MainActor
    func goblinClerkBanter(now: Date = Date()) async -> String? {
        let fae = vault.data.fae ?? FaePlayerState()
        let stall = currentStall ?? buildGoblinStall(now: now)
        let prompt = """
        You are a Marginalia Goblin clerk running the BookShop inside ReEnchanted — mercantile, precise, dryly funny, a little unpredictable. Speak ONE or TWO sentences directly to the reader, in character. No quotes, no headings.

        Tonight: \(stall.moodLine)
        \(stall.windowLine)
        The reader holds \(fae.attention) Attention, \(beliefScore) Belief, and \(fae.warmth(for: .goblin)) Warmth with you.
        React to their standing and the night. Do not invent specific wares or prices. Be brief and characterful.
        """
        let line = await LocalBrainProse.write(
            prompt: prompt,
            instructions: "You are a Marginalia Goblin shopkeeper. One or two sentences, in character, prose only.",
            maxTokens: 120,
            sourceID: "goblin-clerk",
            tags: ["goblin-market", "clerk", "fae"]
        )
        guard let line, !line.hasPrefix("{") else { return nil }
        return line.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Who a "warm word" lands on: the most-believed character in the cast.
    private func warmWordTarget() -> (id: String, name: String)? {
        let cast = (NarrativePackRegistry.entities + customCastMembers.map(\.entity))
            .filter { $0.kind == .character }
        guard let top = cast.max(by: { effectiveCastBelief(for: $0.id) < effectiveCastBelief(for: $1.id) }) else { return nil }
        return (top.id, top.name)
    }

    /// The Goblins gossip a purchase to the cast — a small narrative event.
    private func recordGoblinPurchaseGossip(ware: MarketWare, now: Date) {
        let event = NarrativeEvent(
            id: "goblin-purchase-\(ware.id)-\(UUID().uuidString)",
            kind: .pageKept,
            sourcePageType: nil,
            sourcePageID: nil,
            createdAt: now,
            summary: "The Marginalia Goblins mention, to anyone who'll listen, that the reader bought \(ware.title).",
            tags: ["goblin-market", "gossip", "fae"],
            effect: NarrativeEventEffect()
        )
        try? BookDatabase.upsertNarrativeEvent(event)
        narrativeEvents = (try? BookDatabase.narrativeEvents(limit: 160)) ?? narrativeEvents
    }

    func buyFaeGift(offerID: String, now: Date = Date()) {
        var state = vault.data.fae ?? FaePlayerState()
        guard FaeEconomy.purchase(offerID: offerID, into: &state, now: now) != nil else {
            BookFeedback.play(.error)
            return
        }
        vault.data.fae = state
        vault.save()
        surfaceRefreshDate = now
        BookFeedback.play(.select)
    }

    func useInventoryGift(giftID: String, targetID: String?, now: Date = Date()) {
        var state = vault.data.fae ?? FaePlayerState()
        guard let index = state.gifts.firstIndex(where: { $0.id == giftID }),
              !state.gifts[index].isCold else {
            BookFeedback.play(.error)
            return
        }

        let gift = state.gifts[index]
        var summary: String
        switch gift.effect {
        case .quieting:
            state.gifts[index].activatedAt = now
            state.gifts[index].expiresAt = now.addingTimeInterval(24 * 3600)
            summary = "The reader invoked \(gift.name); its Quieting holds for one day."
        case .reshelving:
            guard let targetID,
                  BookPageSourceRegistry.sources.contains(where: { $0.id == targetID && FaeGiftEffects.reshelfEligible.contains($0.type) }) else {
                BookFeedback.play(.error)
                return
            }
            state.gifts[index].boundSourceID = targetID
            let title = BookPageSourceRegistry.source(id: targetID).title
            summary = "The reader bound \(gift.name) to \(title), calling that kind of Page back to the shelf."
        case .longMemory:
            guard let targetID,
                  days.flatMap(\.pages).contains(where: { $0.id == targetID }) else {
                BookFeedback.play(.error)
                return
            }
            state.gifts[index].boundSourceID = targetID
            summary = "The reader bound \(gift.name) to a kept Page. The Book marked it for Long Memory."
        case .callingCard:
            summary = "The reader presented \(gift.name) at the Goblin Market."
        case .loosePage:
            summary = "The reader turned \(gift.name), and found that it had revised itself."
        case .unspokenPen:
            summary = "The reader uncapped \(gift.name), and Gemma wrote one sentence meant never to have been spoken before."
        }

        vault.data.fae = state
        vault.save()
        let event = NarrativeEvent(
            id: "inventory-gift-\(giftID)-\(UUID().uuidString)",
            kind: .pageKept,
            sourcePageType: .inventory,
            sourcePageID: nil,
            createdAt: now,
            summary: summary,
            tags: ["inventory", "fae-gift", "gift:\(gift.effect.rawValue)"],
            effect: NarrativeEventEffect()
        )
        try? BookDatabase.upsertNarrativeEvent(event)
        narrativeEvents = (try? BookDatabase.narrativeEvents(limit: 160)) ?? narrativeEvents
        surfaceRefreshDate = now
        statusMessage = summary
        BookFeedback.play(.select)
    }

    func saveSelfFactIfNeeded(surface: SurfacePage, answer: String) {
        guard surface.type == .aboutYou else { return }
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let metadata = surface.payload.metadata
        let questionID = metadata["questionID"] ?? surface.id
        let question = SelfKnowledgePackRegistry.question(id: questionID) ?? AboutYouQuestion(
            id: questionID,
            packID: metadata["packID"] ?? SelfKnowledgePackRegistry.corePackID,
            prompt: surface.prompt,
            detail: surface.detail,
            placeholder: surface.payload.body,
            sensitivity: SelfFactSensitivity(rawValue: metadata["sensitivity"] ?? "") ?? .delight,
            defaultUsePermission: SelfFactUsePermission(rawValue: metadata["usePermission"] ?? "") ?? .privateContext,
            tags: metadata["tags"]?.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) } ?? [],
            priority: 0
        )
        let now = Date()
        let existing = selfFacts.first { $0.questionID == questionID }
        let fact = SelfFact(
            id: existing?.id ?? "\(question.packID):\(question.id)",
            questionID: question.id,
            question: question.prompt,
            answer: trimmed,
            bookTranslation: SelfKnowledgePackRegistry.translation(for: question, answer: trimmed),
            sensitivity: question.sensitivity,
            usePermission: question.defaultUsePermission,
            tags: question.tags,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now
        )

        do {
            try BookDatabase.upsertSelfFact(fact)
            selfFacts = (try? BookDatabase.selfFacts()) ?? (selfFacts.filter { $0.id != fact.id } + [fact])
        } catch {
            appLog.error("Self fact save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func saveFacultyEntryIfNeeded(
        surface: SurfacePage,
        page: BookPage,
        answer: String,
        tags: [String],
        dayID: String
    ) {
        let metadata = surface.payload.metadata
        let kind: FacultyEntryKind?
        if let metadataKind = metadata["facultyKind"].flatMap(FacultyEntryKind.init(rawValue:)) {
            kind = metadataKind
        } else if surface.type == .fuel || surface.sourceID == "fuel-log" {
            kind = .fuel
        } else if surface.type == .mood || surface.sourceID == "inner-weather" {
            kind = .innerWeather
        } else {
            kind = nil
        }
        guard let kind else { return }

        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let window = FacultyLogCadence.currentWindow(for: page.createdAt)
        let entry = FacultyEntry(
            id: "faculty-entry-\(page.id)",
            kind: kind,
            facultyID: metadata["facultyID"],
            dayID: dayID,
            sourcePageID: page.id,
            createdAt: page.createdAt,
            windowID: metadata["facultyWindowID"] ?? window.id,
            windowName: metadata["facultyWindowName"] ?? window.name,
            rawText: trimmed,
            tags: Array(Set(tags + [
                "faculty-kind:\(kind.rawValue)",
                "faculty-window:\(metadata["facultyWindowID"] ?? window.id)",
                kind.facultyID
            ])).sorted()
        )

        do {
            try BookDatabase.upsertFacultyEntry(entry)
            facultyEntries = (try? BookDatabase.facultyEntries(limit: 160)) ?? (facultyEntries.filter { $0.id != entry.id } + [entry])
        } catch {
            appLog.error("Faculty entry save failed: \(error.localizedDescription, privacy: .public)")
        }

        if kind == .fuel {
            enrichFuelEntry(entry)
        }
    }

    @MainActor
    func spendBeliefForGeneration(_ kind: BeliefGenerationKind) -> Bool {
        guard beliefScore >= kind.cost else {
            let needed = kind.cost - beliefScore
            statusMessage = "The \(kind.title) needs \(needed) more Belief before its ink can wake."
            BookFeedback.play(.error)
            return false
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
            beliefScore = max(0, beliefScore - kind.cost)
        }
        statusMessage = "\(kind.cost) Belief moved into the \(kind.title)."
        BookFeedback.play(.select)
        return true
    }

    @MainActor
    func refundBeliefForGeneration(_ kind: BeliefGenerationKind) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
            beliefScore = min(100, beliefScore + kind.cost)
        }
        statusMessage = "The \(kind.title) did not finish, so its \(kind.cost) Belief returned to your Glow."
    }

    @MainActor
    func reserveBeliefForGeneration(
        _ surface: SurfacePage
    ) -> (surface: SurfacePage, kind: BeliefGenerationKind?)? {
        guard let kind = BeliefEconomyPolicy.generationKind(for: surface) else {
            return (surface, nil)
        }
        guard spendBeliefForGeneration(kind) else { return nil }
        return (surface.recordingBeliefGenerationPayment(kind), kind)
    }

    @discardableResult
    func awardBelief(for surface: SurfacePage) -> Int {
        let delta: Int
        if surface.type == .wonderCompass, surface.payload.metadata["runID"] != nil {
            delta = 0
        } else if surface.type == .bookJump {
            let depth = Int(surface.payload.metadata["bookJumpDepth"] ?? "") ?? 1
            switch surface.payload.metadata["bookJumpAction"] {
            case "start":
                delta = -BookJumpEngine.startCost
            case "advance":
                delta = -BookJumpEngine.advanceCost(depth: depth)
            case "return":
                delta = BookJumpEngine.returnReward(
                    depth: depth,
                    hasSouvenir: surface.payload.metadata["bookJumpHasSouvenir"] == "true"
                )
            default:
                delta = 0
            }
        } else {
            delta = BeliefEconomyPolicy.keepReward(for: surface)
        }
        guard delta != 0 else { return 0 }
        let newScore = min(100, max(0, beliefScore + delta))
        let appliedDelta = newScore - beliefScore
        guard appliedDelta != 0 else { return 0 }
        // The badge owns its score-change pop locally. Publishing this through a
        // root animation transaction can also animate a new hero line (and its
        // height) when Belief crosses a voice threshold, shifting every shelf.
        beliefScore = newScore
        return appliedDelta
    }

    /// The open shelf: turn any title the reader names into an improvised Book
    /// Jump door, anchored to their real day and guided by their brightest cast.
    func openCustomBookJump() {
        let current = vault.data.bookJump ?? BookJumpState()
        guard current.active == nil else {
            statusMessage = "Finish the open jump before opening another door."
            return
        }
        guard let work = BookJumpEngine.improvisedWork(title: bookJumpCustomTitle, author: "", gutenbergID: "") else { return }
        let guide = (NarrativePackRegistry.entities + customCastMembers.map(\.entity))
            .filter { $0.kind == .character }
            .max { effectiveCastBelief(for: $0.id) < effectiveCastBelief(for: $1.id) }?
            .name ?? "the Book"
        let anchor = today.capturedPages.last?.userInput.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let next = BookJumpEngine.startCustom(
            work: work,
            anchor: anchor,
            intention: "bring back a sentence that still belongs to real life",
            guide: guide,
            into: current
        )
        vault.data.bookJump = next
        vault.save()
        bookJumpCustomTitle = ""
        statusMessage = "The Spine opens onto \(work.title). Find the jump in your feed to step through."
        BookFeedback.play(.braidComplete)
        surfaceRefreshDate = Date()
    }

    /// Once a day, an unstabilized Book Jump lets Routine gain a margin; if
    /// it overruns, the jump collapses — you lose the staked Belief and the book
    /// goes cold. Also prunes expired Borrowed Rules.
    func tendBookJump(now: Date = Date()) {
        let current = vault.data.bookJump ?? BookJumpState()
        guard current.active != nil || !current.borrowedRules.isEmpty else { return }
        let result = BookJumpEngine.dailyDecay(current, now: now)
        vault.data.bookJump = result.state
        vault.save()
        if result.collapsed {
            if result.lostBelief > 0 {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                    beliefScore = max(0, beliefScore - result.lostBelief)
                }
            }
            statusMessage = "\(result.bookTitle) collapsed into Routine overnight. You slipped back empty-handed; the book is cold for a while."
            BookFeedback.nothingPressure(4)
            BookFeedback.play(.error)
            surfaceRefreshDate = now
        }
    }

    func runBeliefEconomyDailyTick(now: Date = Date()) {
        let result = BeliefEconomyEngine.dailyTick(BeliefEconomyDailyContext(
            now: now,
            days: days,
            entities: NarrativePackRegistry.entities + customCastMembers.map(\.entity),
            entityBelief: entityBeliefLedger,
            pageBelief: pageBeliefLedger,
            readerBelief: beliefScore,
            events: narrativeEvents,
            state: vault.data.beliefEconomy ?? BeliefEconomyState()
        ))
        applyBeliefEconomyResult(result, now: now)
    }

    func applyBeliefEconomyResult(_ result: BeliefEconomyDailyResult, now: Date = Date()) {
        guard result.readerDelta != 0 || !result.entityDeltas.isEmpty || !result.pageDeltas.isEmpty || result.state != (vault.data.beliefEconomy ?? BeliefEconomyState()) else {
            vault.data.beliefEconomy = result.state
            vault.save()
            return
        }

        if result.readerDelta != 0 {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                beliefScore = min(100, max(0, beliefScore + result.readerDelta))
            }
        }
        for (entityID, delta) in result.entityDeltas where delta != 0 {
            applyEntityBeliefLedgerDelta(entityID: entityID, delta: delta)
        }
        for (sourceID, delta) in result.pageDeltas where delta != 0 {
            applyPageBeliefLedgerDelta(sourceID: sourceID, delta: delta)
        }
        vault.data.beliefEconomy = result.state
        vault.save()
        surfaceRefreshDate = now

        if let digest = beliefEconomyOvernightDigest(result) {
            statusMessage = digest
        }
    }

    /// Turn the overnight Belief movements into one legible, in-world line so the
    /// economy is visible instead of silent bookkeeping. Reader first, then a
    /// couple of the most notable Cast/page shifts.
    func beliefEconomyOvernightDigest(_ result: BeliefEconomyDailyResult) -> String? {
        guard !result.movements.isEmpty else { return nil }
        var parts: [String] = []

        if result.readerDelta > 0 {
            parts.append("your Glow caught \(result.readerDelta) point\(result.readerDelta == 1 ? "" : "s")")
        } else if result.readerDelta < 0 {
            parts.append("your Glow settled by \(abs(result.readerDelta))")
        }

        let others = result.movements
            .filter { $0.targetKind != .reader && $0.delta != 0 }
            .sorted { abs($0.delta) > abs($1.delta) }
            .prefix(2)
        for move in others {
            let verb = move.delta > 0 ? "brightened" : "cooled"
            parts.append("\(move.targetName) \(verb) \(abs(move.delta))")
        }

        guard !parts.isEmpty else { return nil }
        let body = parts.count == 1 ? parts[0] : parts.dropLast().joined(separator: ", ") + ", and " + parts.last!
        return "Overnight: \(body)."
    }

    func warmPageSourceForKeptSurface(_ surface: SurfacePage, now: Date = Date()) {
        let result = BeliefEconomyEngine.sourceKeep(
            source: surface.source,
            dayID: today.id,
            now: now,
            pageBelief: pageBeliefLedger,
            state: vault.data.beliefEconomy ?? BeliefEconomyState()
        )
        vault.data.beliefEconomy = result.state
        if result.delta != 0 {
            applyPageBeliefLedgerDelta(sourceID: surface.sourceID, delta: result.delta)
            surfaceRefreshDate = now
        }
        vault.save()
    }

    func coolPageSourceForDismissedSurface(_ surface: SurfacePage, now: Date = Date()) {
        let result = BeliefEconomyEngine.sourceDismissed(
            source: surface.source,
            dayID: today.id,
            now: now,
            pageBelief: pageBeliefLedger,
            state: vault.data.beliefEconomy ?? BeliefEconomyState()
        )
        vault.data.beliefEconomy = result.state
        if result.delta != 0 {
            applyPageBeliefLedgerDelta(sourceID: surface.sourceID, delta: result.delta)
            surfaceRefreshDate = now
        }
        vault.save()
    }

    func effectiveCastBelief(for entityID: String) -> Int {
        let entity = (NarrativePackRegistry.entities + customCastMembers.map(\.entity)).first { $0.id == entityID }
        let base = entity?.belief ?? 20
        return max(0, min(100, base + (entityBeliefLedger[entityID] ?? 0)))
    }

    func applyEntityBeliefLedgerDelta(entityID: String, delta: Int) {
        guard delta != 0 else { return }
        var ledger = entityBeliefLedger
        let base = (NarrativePackRegistry.entities + customCastMembers.map(\.entity)).first { $0.id == entityID }?.belief ?? 20
        let current = max(0, min(100, base + (ledger[entityID] ?? 0)))
        let next = max(0, min(100, current + delta))
        ledger[entityID] = next - base
        if ledger[entityID] == 0 {
            ledger[entityID] = nil
        }
        if let data = try? JSONEncoder().encode(ledger),
           let encoded = String(data: data, encoding: .utf8) {
            entityBeliefLedgerData = encoded
        }
    }

    @discardableResult
    func applyPageBeliefLedgerDelta(sourceID: String, delta: Int) -> Int {
        guard delta != 0 else { return 0 }
        var ledger = pageBeliefLedger
        let source = BookPageSourceRegistry.source(id: sourceID)
        let base = BookPageSourceRegistry.defaultBelief(for: source)
        let current = max(0, min(100, base + (ledger[sourceID] ?? 0)))
        let next = max(0, min(100, current + delta))
        let applied = next - current
        guard applied != 0 else { return 0 }
        ledger[sourceID] = next - base
        if ledger[sourceID] == 0 {
            ledger[sourceID] = nil
        }
        if let data = try? JSONEncoder().encode(ledger),
           let encoded = String(data: data, encoding: .utf8) {
            pageBeliefLedgerData = encoded
        }
        return applied
    }

    func applyEntityEconomyDelta(entityID: String, name: String, delta: Int, sourcePageType: BookPageType?, note: String) {
        guard delta != 0 else { return }
        applyEntityBeliefLedgerDelta(entityID: entityID, delta: delta)
        let event = NarrativeEvent(
            id: "belief-economy-\(entityID)-\(UUID().uuidString)",
            kind: delta > 0 ? .beliefInvested : .beliefAttacked,
            sourcePageType: sourcePageType,
            sourcePageID: nil,
            createdAt: Date(),
            summary: note,
            tags: ["belief", "belief-economy", "entity:\(entityID)"],
            effect: NarrativeEventEffect(entityWeightDeltas: [entityID: delta])
        )
        do {
            try BookDatabase.upsertNarrativeEvent(event)
            narrativeEvents = try BookDatabase.narrativeEvents(limit: 160)
        } catch {
            statusMessage = "The Belief moved, but the hidden ledger missed a line: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func applyPageEconomyDelta(
        sourceID: String,
        name: String,
        delta: Int,
        sourcePageType: BookPageType?,
        note: String,
        actorID: String? = nil
    ) -> Int {
        let applied = applyPageBeliefLedgerDelta(sourceID: sourceID, delta: delta)
        guard applied != 0 else { return 0 }
        let source = BookPageSourceRegistry.source(id: sourceID)
        let actorTags = actorID.map { ["actor:\($0)"] } ?? []
        let event = NarrativeEvent(
            id: "belief-economy-page-\(sourceID)-\(UUID().uuidString)",
            kind: applied > 0 ? .beliefInvested : .beliefAttacked,
            sourcePageType: sourcePageType ?? source.type,
            sourcePageID: nil,
            createdAt: Date(),
            summary: note,
            tags: ["belief", "belief-economy", "page:\(sourceID)", "page-type:\(source.type.rawValue)"] + actorTags,
            effect: NarrativeEventEffect()
        )
        do {
            try BookDatabase.upsertNarrativeEvent(event)
            narrativeEvents = try BookDatabase.narrativeEvents(limit: 160)
        } catch {
            statusMessage = "The Page Belief moved, but the hidden ledger missed a line: \(error.localizedDescription)"
        }
        surfaceRefreshDate = Date()
        return applied
    }

    func completeCompassRunIfNeeded(_ surface: SurfacePage) {
        guard surface.type == .wonderCompass,
              surface.payload.metadata["compassStep"] == "rest",
              let runID = surface.payload.metadata["runID"] else {
            return
        }
        var completed = Set(completedCompassRunLedger
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty })
        guard !completed.contains(runID) else { return }
        completed.insert(runID)
        completedCompassRunLedger = completed.sorted().joined(separator: ",")
        recordMeaningfulAttention(key: "compass:\(runID)")
        let newScore = min(100, max(0, beliefScore + BeliefEconomyPolicy.compassRunReward))
        guard newScore != beliefScore else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
            beliefScore = newScore
        }
    }

    func openStoryMechanicReturnPage(from completedSurface: SurfacePage, outcome: String) {
        guard completedSurface.payload.metadata["storyMechanicReturn"] == "true" else { return }
        Task { await prepareAndOpenStoryMechanicReturnPage(from: completedSurface, outcome: outcome) }
    }

    @MainActor
    func prepareAndOpenStoryMechanicReturnPage(from completedSurface: SurfacePage, outcome: String) async {
        guard !localBrainTelemetry.isWorking else {
            statusMessage = "The Story Page heard the result. Let the current ink dry, then continue the thread."
            return
        }

        let returnSurface = storyMechanicReturnSurface(from: completedSurface, outcome: outcome)
        let returnsToAcademy = returnSurface.type == .academyClass
        statusMessage = returnsToAcademy
            ? "The Academy is opening the door for a fieldwork debrief..."
            : "The Story Page is folding the \(completedSurface.prompt) result back into the thread..."

        do {
            if returnsToAcademy {
                selectedSurface = await academyClassSurfaceWithProse(from: returnSurface)
                statusMessage = "The class has received the practice and moved one beat forward."
                return
            }
            let prose: StoryPageProse
            #if NATIVE_LOCAL_BRAIN && canImport(MLXLLM) && canImport(MLXVLM) && canImport(MLXLMCommon) && canImport(MLXLMTokenizers) && canImport(MLXLMHFAPI) && canImport(MLX) && !targetEnvironment(simulator)
            prose = try await MLXStoryPageWriter().write(surface: returnSurface)
            #else
            prose = try await FakeStoryPageWriter().write(surface: returnSurface)
            #endif
            let prepared = returnSurface.preparedStoryPageCopy(
                prose: prose,
                slotID: "mechanic-return-\(Int(Date().timeIntervalSince1970))"
            )
            selectedSurface = prepared
            statusMessage = "The mechanic result has become the next Story Page."
        } catch {
            selectedSurface = localBrainIssueSurface(
                type: returnsToAcademy ? .academyClass : .narrativeOS,
                title: returnsToAcademy ? "Academy Return" : "Story Page",
                action: returnsToAcademy ? "return the fieldwork to the class" : "fold the mechanic result back into the story"
            )
            statusMessage = returnsToAcademy
                ? "The class could not receive the fieldwork yet."
                : "The Story Page could not fold the mechanic result yet."
        }
    }

    func storyMechanicReturnSurface(from completedSurface: SurfacePage, outcome: String) -> SurfacePage {
        let metadata = completedSurface.payload.metadata
        let returnsToAcademy = metadata["academyActivityReturn"] == "true"
        let mechanic = metadata["storyMechanicKind"] ?? "story-mechanic"
        let thread = metadata["storyThread"] ?? "Ordinary Magic"
        let choiceTitle = metadata["storyChoiceTitle"] ?? completedSurface.prompt
        let choicePrompt = metadata["storyChoicePrompt"] ?? completedSurface.detail
        let choiceEffect = metadata["storyChoiceEffect"] ?? "The mechanic result changes what the thread can do next."
        let priorScene = metadata["storyScene"] ?? "A previous Story Page asked for a real mechanic before the thread moved on."
        let outcomeText = outcome.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? completedSurface.payload.body
        let recipePackID = metadata["storyRecipePackID"] ?? ""
        let recipeID = metadata["storyRecipeID"] ?? ""
        let lowered = outcomeText.lowercased()
        let outcomeTier: String
        if lowered.contains("critical success") { outcomeTier = "bright-success" }
        else if lowered.contains("near miss") || lowered.contains("critical failure") { outcomeTier = "complication" }
        else if lowered.contains("failure") { outcomeTier = "complication" }
        else if lowered.contains("success") { outcomeTier = "costly-success" }
        else { outcomeTier = "unresolved" }
        let source = BookPageSourceRegistry.source(for: returnsToAcademy ? .academyClass : .narrativeOS)
        let continuation = """
        \(returnsToAcademy ? "An Academy session assigned a field practice." : "A Story Page choice asked for \(mechanic).")

        Previous \(returnsToAcademy ? "classroom scene" : "scene"):
        \(priorScene)

        Chosen \(returnsToAcademy ? "Academy practice" : "story action"):
        \(choiceTitle) — \(choicePrompt)

        Intended movement:
        \(choiceEffect)

        Completed mechanic page:
        \(completedSurface.prompt)

        Player-kept result:
        \(outcomeText)

        \(returnsToAcademy ? "Continue the same lesson one beat later. Let the leader receive the evidence, answer it specifically, and give the class a new small social or conceptual turn. Do not restart the lesson or claim any extra real-world action beyond this result." : "Continue the thread from the real completed mechanic. Do not claim any extra real-world action beyond this result.")
        """

        var returnMetadata: [String: String] = [
            "source": source.id,
            "selectedThreads": thread,
            "selectedEntities": returnsToAcademy ? (metadata["academyReturn_sessionLeaderEntityID"] ?? "the-book") : "the-book",
            "realSignals": "A completed \(mechanic) page is feeding back into the \(returnsToAcademy ? "Academy session" : "story").",
            "relationshipPressures": returnsToAcademy
                ? "The leader and room must receive the reader's fieldwork before offering the next choice."
                : "The Story Page must honor the mechanic result before offering the next choice.",
            "storyContinuationContext": continuation,
            "storyRecipePackID": recipePackID,
            "storyRecipeID": recipeID,
            "storyMechanicOutcomeTier": outcomeTier,
            "tags": returnsToAcademy
                ? "academy-return,academy-activity,academy-activity:\(metadata["academyActivityID"] ?? "practice"),story-mechanic-return"
                : "story-mechanic-return,story-mechanic,story-mechanic:\(mechanic),\(mechanic)"
        ]
        if returnsToAcademy {
            for key in [
                "sessionID", "sessionKind", "sessionName", "sessionLeader", "sessionLeaderEntityID", "sessionRoom",
                "sessionCompanions", "sessionTeaches", "sessionStyle", "sessionSubjectThreadID", "lessonModuleID",
                "lessonTitle", "lessonRealSubject", "lessonConcept", "lessonLectureBeats", "lessonDemonstration",
                "lessonInteractionPrompt", "lessonRealWorldPractice", "sessionBlock"
            ] {
                if let value = metadata["academyReturn_\(key)"]?.nonEmpty {
                    returnMetadata[key] = value
                }
            }
            returnMetadata["academyLessonPage"] = "true"
            returnMetadata["academyActivityID"] = metadata["academyActivityID"] ?? ""
            returnMetadata["academyActivityTitle"] = metadata["academyActivityTitle"] ?? "Field practice"
            returnMetadata["academyActivityOutcome"] = outcomeText
        }

        return SurfacePage(
            id: "\(returnsToAcademy ? "academy" : "story")-mechanic-return-\(completedSurface.id)-\(Int(Date().timeIntervalSince1970))",
            type: returnsToAcademy ? .academyClass : .narrativeOS,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .promptCard,
            score: max(completedSurface.score, 74),
            reason: returnsToAcademy
                ? "The completed field practice is ready for the class to receive."
                : "A completed mechanic is ready to become the next Story Page beat.",
            prompt: returnsToAcademy ? "Return to \(metadata["academyReturn_sessionName"] ?? "the Academy")" : "Story Page Return",
            detail: returnsToAcademy
                ? "Bring the result back to \(metadata["academyReturn_sessionLeader"] ?? "the room")."
                : "The thread continues from \(completedSurface.prompt).",
            payload: BookPagePayload(
                headline: returnsToAcademy ? "Fieldwork Return" : "Story Page Return",
                body: continuation.bookPreviewSentenceLimit(2),
                metadata: returnMetadata
            )
        )
    }

    @MainActor
    func generateAndOpenSurface(_ surface: SurfacePage) async {
        if isMemoryPageLocked(surface.type) {
            showMemoryPageLockedMessage(for: surface.type)
            return
        }

        recordBookInteriorSurfaceOpened(surface)

        switch surface.type {
        case .narrativeOS:
            guard let reservation = reserveBeliefForGeneration(surface) else { return }
            statusMessage = "The Story Page is calling the local Book brain..."
            let succeeded = await prepareStoryPageIfPossible(force: true, draftOverride: reservation.surface)
            if !succeeded, let kind = reservation.kind {
                refundBeliefForGeneration(kind)
            }
            selectedSurface = succeeded
                ? generation.preparedStoryPageSurface
                : localBrainIssueSurface(
                    type: surface.type,
                    title: "Story Page",
                    action: "write a Story Page"
                )
        case .gossip:
            guard let reservation = reserveBeliefForGeneration(surface) else { return }
            statusMessage = "The Gossip Page is waking the whisper engine..."
            let succeeded = await prepareGossipPageIfPossible(force: true)
            if !succeeded, let kind = reservation.kind {
                refundBeliefForGeneration(kind)
            }
            let preparedGossip = succeeded
                ? generation.preparedGossipPageSurface.map { prepared in
                    reservation.kind.map { prepared.recordingBeliefGenerationPayment($0) } ?? prepared
                }
                : nil
            if let preparedGossip {
                generation.preparedGossipPageSurface = preparedGossip
            }
            selectedSurface = preparedGossip ?? localBrainIssueSurface(
                type: surface.type,
                title: "Gossip Page",
                action: "write a Gossip Page"
            )
        case .note:
            guard let reservation = reserveBeliefForGeneration(surface) else { return }
            let draft = freshStudentNoteDraft(fallback: reservation.surface)
            statusMessage = "\(draft.payload.metadata["senderName"] ?? "Someone") is folding a note..."
            let prepared = await studentNoteSurfaceWithProse(from: draft)
            let failed = SurfaceReadinessState(surface: prepared).needsLocalBrainToOpen
            if failed, let kind = reservation.kind {
                refundBeliefForGeneration(kind)
            } else {
                statusMessage = ""
            }
            selectedSurface = prepared
        case .theBleed:
            statusMessage = "The presses are running. Penny is setting type..."
            _ = await prepareBleedEditionIfPossible(from: surface)
            selectedSurface = generation.preparedBleedEditionSurface ?? localBrainIssueSurface(
                type: surface.type,
                title: "The Bleed",
                action: "print the edition"
            )
        case .facultyResearch:
            statusMessage = "The faculty folio is asking Gemma to read the clippings..."
            _ = await prepareFacultyResearchPageIfPossible(force: true)
            selectedSurface = generation.preparedFacultyResearchSurface ?? localBrainIssueSurface(
                type: surface.type,
                title: "Faculty Research",
                action: "write a Faculty Research Page"
            )
        case .letter:
            selectedSurface = surface
        case .weather:
            statusMessage = "The Weather Page is asking the sky, then Gemma."
            let shouldRefreshWeather = surface.payload.metadata["requiresWeatherRefresh"] == "true"
            if shouldRefreshWeather || weatherPageSignal == nil {
                _ = await refreshWeatherSignal(isUserInitiated: true, shouldEnchant: true)
            } else if enchantedWeather == nil {
                _ = await prepareWeatherPageIfPossible()
            }
            selectedSurface = enchantedWeather == nil
                ? localBrainIssueSurface(type: surface.type, title: "Weather Page", action: "translate the weather")
                : freshManualSurface(for: .weather)
        case .supportGuild:
            statusMessage = "The Support Guild is convening over the charts..."
            selectedSurface = await supportGuildSurfaceWithProse(from: surface)
            statusMessage = ""
        case .twoReadings:
            statusMessage = "\(surface.payload.metadata["entityAName"] ?? "Two readers") and \(surface.payload.metadata["entityBName"] ?? "another") are arguing it out..."
            selectedSurface = await twoReadingsSurfaceWithProse(from: surface)
            statusMessage = ""
        case .castBond:
            if surface.payload.metadata["tags", default: ""].contains(QuillChoosing.chosenTag) {
                statusMessage = "The Quillquarium is holding its breath while \(surface.payload.metadata["quillName"] ?? "one patient pen") chooses..."
            } else {
                statusMessage = "The Loom is staging what changed between \(surface.payload.metadata["entityAName"] ?? "two figures") and \(surface.payload.metadata["entityBName"] ?? "another")..."
            }
            selectedSurface = await castBondSurfaceWithProse(from: surface)
            statusMessage = ""
        case .bookJump:
            statusMessage = "The Spine is opening to \(surface.payload.metadata["bookTitle"] ?? "the public stacks")..."
            selectedSurface = await bookJumpSurfaceWithProse(from: surface)
            statusMessage = ""
        case .academyClass:
            statusMessage = "The classroom door is opening..."
            selectedSurface = await academyClassSurfaceWithProse(from: surface)
            statusMessage = ""
        case .bookFae:
            guard let reservation = reserveBeliefForGeneration(surface) else { return }
            statusMessage = "The Book is calling Gemma to receive \(surface.payload.metadata["faeName"] ?? "a visitor from the margins")..."
            let prepared = await bookFaeSurfaceWithProse(from: reservation.surface)
            let failed = SurfaceReadinessState(surface: prepared).needsLocalBrainToOpen
            if failed, let kind = reservation.kind {
                refundBeliefForGeneration(kind)
            } else {
                statusMessage = ""
            }
            selectedSurface = prepared
            BookFeedback.faeArrival(
                kind: surface.payload.metadata["faeKind"] ?? "fae",
                court: surface.payload.metadata["faeCourt"]
            )
        case .elective where surface.payload.metadata["electiveOffer"] == "true":
            if surface.payload.metadata["electivePrepared"] == "true" {
                selectedSurface = surface
            } else {
                statusMessage = "\(surface.payload.metadata["senderName"] ?? "Someone") is writing out the quest..."
                selectedSurface = await electiveOfferSurfaceWithAsk(from: surface)
                statusMessage = ""
            }
        case .packPage where surface.payload.metadata["packPrompt"]?.isEmpty == false:
            statusMessage = "An installed page is asking the Book to write..."
            selectedSurface = await packPageSurfaceWithProse(from: surface)
            statusMessage = ""
        case .bookConnections:
            isConnectionsPresented = true
        case .glowInvitation:
            selectedSurface = nil
            tutorTouch("glow-menu")
            BookFeedback.play(.sourceRefresh)
            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                isGlowMenuPresented = true
            }
        case .illuminatedPhoto:
            if surface.payload.metadata["cameraFirst"] == "true" {
                selectedSurface = surface
            } else {
                statusMessage = "Penny is asking Gemma to illuminate a photo."
                _ = await prepareAutomaticIlluminatedPageIfPossible()
                selectedSurface = generation.automaticIlluminatedSurface ?? localBrainIssueSurface(
                    type: surface.type,
                    title: "Illuminated Photo",
                    action: "illuminate a photo"
                )
            }
        default:
            selectedSurface = surface
        }
    }

    @MainActor
    func generateLetterFromSheet(_ draft: SurfacePage) async {
        guard let reservation = reserveBeliefForGeneration(draft) else { return }
        statusMessage = "A Letter Page is opening through the public stacks..."
        let succeeded = await prepareLetterPageIfPossible(force: true, draftOverride: reservation.surface)
        if !succeeded, let kind = reservation.kind {
            refundBeliefForGeneration(kind)
        }
        if succeeded, let preparedLetterSurface = generation.preparedLetterSurface {
            selectedSurface = preparedLetterSurface
        } else {
            selectedSurface = localBrainIssueSurface(
                type: .letter,
                title: "Letter Page",
                action: "open and read a researched Letter Page"
            )
        }
    }

    @MainActor
    func generateNoteFromSheet(_ draft: SurfacePage) async {
        guard let reservation = reserveBeliefForGeneration(draft) else { return }
        statusMessage = "\(reservation.surface.payload.metadata["senderName"] ?? "Someone") is unfolding a note..."
        let prepared = await studentNoteSurfaceWithProse(from: freshStudentNoteDraft(fallback: reservation.surface))
        if SurfaceReadinessState(surface: prepared).needsLocalBrainToOpen,
           let kind = reservation.kind {
            refundBeliefForGeneration(kind)
        }
        selectedSurface = prepared
        if !SurfaceReadinessState(surface: prepared).needsLocalBrainToOpen {
            statusMessage = ""
        }
    }

    @MainActor
    func generatePlayfulMissionFromSheet(_ draft: SurfacePage) async {
        guard !localBrainTelemetry.isWorking else {
            statusMessage = "The Book is already writing. One moment, please."
            return
        }
        statusMessage = "Gemma is inventing a fresh South = Sense mission..."
        let mission = await PlayfulMissionWriter().mission(from: draft)
        selectedSurface = draft.withPlayfulMission(mission, slotID: SurfaceCadence.slotID(for: surfaceRefreshDate, hours: 2))
        statusMessage = ""
    }

    @MainActor
    func requestAuroraTarotReading(
        _ original: TarotReadingArtifact,
        includeArchive: Bool
    ) async -> TarotReadingArtifact {
        guard !localBrainTelemetry.isWorking else { return original }
        var reading = original
        let receipt = includeArchive ? tarotContextReceipt(for: reading) : nil
        reading.contextReceipt = receipt

        #if NATIVE_LOCAL_BRAIN && canImport(MLXLLM) && canImport(MLXVLM) && canImport(MLXLMCommon) && canImport(MLXLMTokenizers) && canImport(MLXLMHFAPI) && canImport(MLX) && !targetEnvironment(simulator)
        do {
            reading.auroraReading = try await MLXTarotReadingWriter().read(
                reading: reading,
                receipt: receipt
            )
        } catch {
            appLog.error("Aurora Tarot reading failed: \(error.localizedDescription, privacy: .public)")
        }
        #endif
        return reading
    }

    private func tarotContextReceipt(for reading: TarotReadingArtifact) -> TarotReadingContextReceipt? {
        let cardTerms = reading.cards.compactMap { drawn -> String? in
            guard let card = TarotDeck.card(id: drawn.cardID) else { return nil }
            return ([card.name, drawn.position.title] + card.keywords).joined(separator: " ")
        }
        let query = ([reading.question] + cardTerms)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: " · ")
        guard !query.isEmpty else { return nil }

        let scorer = StacksSearchEngine.defaultSemanticScorer()
        let graph = StacksSearchEngine.buildSearchGraph(from: stacksSearchDataset)
        let results = StacksSearchEngine.hybridSearch(
            query,
            in: stacksSearchDataset,
            extraTerms: reading.cards.flatMap { drawn in
                TarotDeck.card(id: drawn.cardID)?.keywords ?? []
            },
            limit: 24,
            semanticScorer: scorer,
            prebuiltGraph: graph
        )
        let selected = Array(
            results
                .filter { $0.kind == .keptPage }
                .prefix(5)
        )
        guard !selected.isEmpty else { return nil }

        let selectedDocumentIDs = Set(selected.map(\.id))
        let connectedEdges = graph.links
            .filter { selectedDocumentIDs.contains($0.fromID) || selectedDocumentIDs.contains($0.toID) }
            .sorted { $0.weight > $1.weight }
            .prefix(16)
            .map {
                TarotReadingEdgeReceipt(
                    fromID: $0.fromID,
                    toID: $0.toID,
                    kind: $0.kind.rawValue,
                    weight: $0.weight
                )
            }
        let sources = selected.map {
            TarotReadingSourceReceipt(
                documentID: $0.id,
                referenceID: $0.referenceID,
                kind: $0.kind.title,
                title: $0.title,
                excerpt: $0.snippet,
                dateLabel: $0.dateLabel,
                relevance: $0.score
            )
        }
        return TarotReadingContextReceipt(
            query: query,
            retrievalMode: scorer == nil ? "labeled-lexical-graph" : "hybrid-semantic-labeled-graph",
            embeddingModelID: scorer?.modelID,
            sources: sources,
            edges: Array(connectedEdges),
            preparedAt: Date()
        )
    }

    @discardableResult
    func prepareAutomaticIlluminatedPageIfPossible() async -> Bool {
        #if canImport(Photos) && canImport(UIKit)
        guard generation.automaticIlluminatedSurface == nil,
              !generation.isPreparingAutomaticIllumination,
              !localBrainTelemetry.isWorking,
              isSourceEnabled(sourceID: "illuminated-photos") else {
            return false
        }

        let library = PhotoLibraryService()
        let status = library.authorizationStatus()
        let finalStatus: PHAuthorizationStatus
        if status == .notDetermined {
            statusMessage = "The Book needs permission before Penny can find photos in the margins."
            finalStatus = await library.requestAuthorization()
        } else {
            finalStatus = status
        }

        guard finalStatus == .authorized || finalStatus == .limited else {
            if finalStatus == .denied || finalStatus == .restricted {
                statusMessage = "Penny cannot choose from Photos yet. Choose one by hand, or open Photos access in Settings."
                userPhotoIlluminationFallbackAllowed = true
            }
            return false
        }

        generation.isPreparingAutomaticIllumination = true
        defer { generation.isPreparingAutomaticIllumination = false }

        do {
            let history = decodedIlluminatedPhotoHistory()
            let assets = try await library.fetchRecentPhotoAssets(
                lookbackHours: PhotoSuggestionSettings.default.lookbackHours,
                favoritesOnly: PhotoSuggestionSettings.default.favoritesOnly,
                includeScreenshots: PhotoSuggestionSettings.default.includeScreenshots
            )
            let illuminationContext = PhotoIlluminationContext.current(
                weatherText: [weatherPageSignal?.phrase, enchantedWeather?.summary].compactMap { $0 }.joined(separator: " "),
                themeTags: (selectedWonderCompassSnippet?.tags ?? []) + [selectedWonderCompassSelector].compactMap { $0 },
                now: surfaceRefreshDate
            )
            let candidates = PhotoCandidateScorer().scoreAssets(assets, history: history, context: illuminationContext)
            let candidate = preferredIlluminatedPhotoCandidate(from: candidates, history: history)
            guard let candidate,
                  let asset = PHAsset.fetchAssets(withLocalIdentifiers: [candidate.assetLocalIdentifier], options: nil).firstObject else {
                statusMessage = "Penny checked recent photos, but the margins were quiet."
                userPhotoIlluminationFallbackAllowed = true
                return false
            }

            let image = try await library.requestFullImage(for: asset, targetSize: CGSize(width: 1400, height: 1400))
            let analysis = PhotoAnalysis.contextualPreview(context: illuminationContext)
            let draft = IlluminatedPageComposer.compose(
                analysis: analysis,
                sourceAssetName: "IlluminatedPhotoSource",
                seed: abs(candidate.assetLocalIdentifier.stableHash ^ today.id.stableHash ^ Int(Date().timeIntervalSinceReferenceDate * 1000)),
                assetLocalIdentifier: candidate.assetLocalIdentifier
            )
            let renderedURL = IlluminatedPageRenderer.renderPreview(draft: draft, sourceImage: image)
            guard let renderedURL else {
                statusMessage = "Penny found a photo, but the illuminated plate did not finish drying."
                userPhotoIlluminationFallbackAllowed = true
                return false
            }
            guard let surface = SurfacePage.illuminatedPhotoSurface(
                draft: draft,
                renderedURL: renderedURL,
                idSuffix: SurfaceCadence.slotID(for: surfaceRefreshDate, hours: 6)
            ) else {
                return false
            }

            var updatedHistory = history
            updatedHistory.proposedAssetIdentifiers.insert(candidate.assetLocalIdentifier)
            updatedHistory.lastSuggestedAtByAsset[candidate.assetLocalIdentifier] = Date()
            illuminatedPhotoHistoryData = encodedIlluminatedPhotoHistory(updatedHistory)
            generation.automaticIlluminatedSurface = surface
            userPhotoIlluminationFallbackAllowed = false
            surfaceRefreshDate = Date()
            localBrainTelemetry.clearError()
            statusMessage = "Penny prepared an illuminated photo page. It is ready if the curator lets it rise."
            return true
        } catch {
            appLog.error("Automatic illuminated page preparation failed: \(error.localizedDescription, privacy: .public)")
            localBrainTelemetry.recordError("illumination: \(error.localizedDescription)")
            statusMessage = "Penny tried to prepare an illuminated photo page, but the press snagged: \(error.localizedDescription)"
            userPhotoIlluminationFallbackAllowed = true
            return false
        }
        #else
        return false
        #endif
    }

    @MainActor
    @discardableResult
    func prepareStoryPageIfPossible(force: Bool = false, draftOverride: SurfacePage? = nil) async -> Bool {
        let slot = SurfaceCadence.slotID(for: surfaceRefreshDate, hours: 4)
        if force {
            guard !generation.isPreparingStoryPage, !localBrainTelemetry.isWorking else {
                return false
            }
        } else {
            guard generation.storyPageRecovery.shouldBegin(
                isPreparing: generation.isPreparingStoryPage,
                isLocalBrainWorking: localBrainTelemetry.isWorking,
                preparedSurface: generation.preparedStoryPageSurface,
                slotID: slot,
                requiredMetadataKey: "storyScene",
                now: surfaceRefreshDate
            ) else {
                return false
            }
        }

        let draft: SurfacePage
        if let draftOverride, draftOverride.type == .narrativeOS {
            draft = draftOverride
        } else {
            var draftInputs = sourceInputs
            draftInputs.preparedStoryPageSurface = nil
            draft = NarrativeOSPageSourceAdapter.draftCandidate(
                for: today,
                inputs: draftInputs,
                now: surfaceRefreshDate
            )
        }

        generation.isPreparingStoryPage = true
        defer { generation.isPreparingStoryPage = false }

        do {
            let prose: StoryPageProse
            #if NATIVE_LOCAL_BRAIN && canImport(MLXLLM) && canImport(MLXVLM) && canImport(MLXLMCommon) && canImport(MLXLMTokenizers) && canImport(MLXLMHFAPI) && canImport(MLX) && !targetEnvironment(simulator)
            prose = try await MLXStoryPageWriter().write(surface: draft)
            #else
            prose = try await FakeStoryPageWriter().write(surface: draft)
            #endif
            generation.preparedStoryPageSurface = draft.preparedStoryPageCopy(prose: prose, slotID: slot)
            surfaceRefreshDate = Date()
            generation.storyPageRecovery.recordSuccess()
            localBrainTelemetry.clearError()
            statusMessage = "The Story Page has dried and is waiting for the curator."
            return true
        } catch {
            appLog.error("Prepared Story Page failed: \(error.localizedDescription, privacy: .public)")
            localBrainTelemetry.recordError("story page: \(error.localizedDescription)")
            generation.preparedStoryPageSurface = nil
            generation.storyPageRecovery.recordFailure()
            statusMessage = "The Story Page did not finish drying. The Book will try again later."
            return false
        }
    }

    @MainActor
    func bookFaeSurfaceWithProse(from draft: SurfacePage) async -> SurfacePage {
        guard draft.type == .bookFae else { return draft }
        guard SurfaceReadinessState(surface: draft).needsLocalBrainToOpen else { return draft }

        do {
            let prose: StoryPageProse
            #if NATIVE_LOCAL_BRAIN && canImport(MLXLLM) && canImport(MLXVLM) && canImport(MLXLMCommon) && canImport(MLXLMTokenizers) && canImport(MLXLMHFAPI) && canImport(MLX) && !targetEnvironment(simulator)
            prose = try await MLXStoryPageWriter().write(surface: draft)
            #else
            prose = try await FakeStoryPageWriter().write(surface: draft)
            #endif
            localBrainTelemetry.clearError()
            return draft.preparedStoryPageCopy(
                prose: prose,
                slotID: "book-fae-\(draft.id)-\(Int(Date().timeIntervalSince1970))"
            )
        } catch {
            appLog.error("Book Fae Page failed: \(error.localizedDescription, privacy: .public)")
            localBrainTelemetry.recordError("book fae page: \(error.localizedDescription)")
            return localBrainIssueSurface(
                type: .bookFae,
                title: "Book Fae Page",
                action: "write the visitation at the margin"
            )
        }
    }

    @MainActor
    func studentNoteSurfaceWithProse(from draft: SurfacePage) async -> SurfacePage {
        guard draft.type == .note else { return draft }
        guard SurfaceReadinessState(surface: draft).needsLocalBrainToOpen else { return draft }
        guard !localBrainTelemetry.isWorking else {
            return localBrainIssueSurface(
                type: .note,
                title: "Notes",
                action: "fold the note"
            )
        }

        let slot = SurfaceCadence.slotID(for: surfaceRefreshDate, hours: 3)
        let prose = await StudentNoteWriter().write(surface: draft)
        localBrainTelemetry.clearError()
        surfaceRefreshDate = Date()
        return draft.preparedNoteCopy(prose: prose, slotID: slot)
    }

    @MainActor
    @discardableResult
    func prepareGossipPageIfPossible(force: Bool = false) async -> Bool {
        let slot = SurfaceCadence.slotID(for: surfaceRefreshDate, hours: 4)
        if force {
            guard !generation.isPreparingGossipPage, !localBrainTelemetry.isWorking else {
                return false
            }
        } else {
            guard generation.gossipPageRecovery.shouldBegin(
                isPreparing: generation.isPreparingGossipPage,
                isLocalBrainWorking: localBrainTelemetry.isWorking,
                preparedSurface: generation.preparedGossipPageSurface,
                slotID: slot,
                requiredMetadataKey: "gossipProse",
                now: surfaceRefreshDate
            ) else {
                return false
            }
        }

        var draftInputs = sourceInputs
        draftInputs.preparedGossipPageSurface = nil
        let hasStoryMaterial = !today.capturedPages.isEmpty
            || draftInputs.weather != nil
            || draftInputs.body != nil
            || draftInputs.narrative?.recentTags.isEmpty == false
        guard hasStoryMaterial else { return false }

        generation.isPreparingGossipPage = true
        defer { generation.isPreparingGossipPage = false }

        var draft = GossipPageSourceAdapter.draftCandidate(
            for: today,
            inputs: draftInputs,
            now: surfaceRefreshDate
        )
        let realInterestClippings = await RealInterestGossipSearcher().clippings(
            from: selfFacts,
            dayID: today.id,
            slotID: slot
        )
        draft = draft.withRealInterestGossip(realInterestClippings)

        do {
            let prose: String
            #if NATIVE_LOCAL_BRAIN && canImport(MLXLLM) && canImport(MLXVLM) && canImport(MLXLMCommon) && canImport(MLXLMTokenizers) && canImport(MLXLMHFAPI) && canImport(MLX) && !targetEnvironment(simulator)
            prose = try await MLXGossipPageWriter().write(surface: draft)
            #else
            prose = try await FakeGossipPageWriter().write(surface: draft)
            #endif
            generation.preparedGossipPageSurface = draft.preparedGossipPageCopy(prose: prose, slotID: slot)
            surfaceRefreshDate = Date()
            generation.gossipPageRecovery.recordSuccess()
            localBrainTelemetry.clearError()
            statusMessage = "A Gossip Page has dried. The margins are pretending they did not gossip."
            return true
        } catch {
            appLog.error("Prepared Gossip Page failed: \(error.localizedDescription, privacy: .public)")
            localBrainTelemetry.recordError("gossip page: \(error.localizedDescription)")
            generation.preparedGossipPageSurface = nil
            generation.gossipPageRecovery.recordFailure()
            statusMessage = "The Gossip Page lost its whisper. The Book will try again later."
            return false
        }
    }

    @MainActor
    @discardableResult
    func prepareFacultyResearchPageIfPossible(force: Bool = false) async -> Bool {
        let slot = SurfaceCadence.slotID(for: surfaceRefreshDate, hours: 12)
        if force {
            guard !generation.isPreparingFacultyResearchPage, !localBrainTelemetry.isWorking else {
                return false
            }
        } else {
            guard generation.facultyResearchRecovery.shouldBegin(
                isPreparing: generation.isPreparingFacultyResearchPage,
                isLocalBrainWorking: localBrainTelemetry.isWorking,
                preparedSurface: generation.preparedFacultyResearchSurface,
                slotID: slot,
                requiredMetadataKey: "researchProse",
                now: surfaceRefreshDate
            ) else {
                return false
            }
        }

        var draftInputs = sourceInputs
        draftInputs.preparedFacultyResearchSurface = nil
        guard var draft = FacultyResearchNoteGenerator.draftCandidate(for: today, inputs: draftInputs, now: surfaceRefreshDate),
              isSourceEnabled(sourceID: draft.sourceID) else {
            return false
        }

        generation.isPreparingFacultyResearchPage = true
        defer { generation.isPreparingFacultyResearchPage = false }

        do {
            let facultyID = draft.payload.metadata["facultyID"] ?? ""
            let clippings = await ScholarlyFacultyResearcher().clippings(
                for: facultyResearchQueries(for: draft),
                facultyID: facultyID,
                limit: 3
            )
            draft = draft.withFacultyResearchClippings(clippings)
            let prose: String
            #if NATIVE_LOCAL_BRAIN && canImport(MLXLLM) && canImport(MLXVLM) && canImport(MLXLMCommon) && canImport(MLXLMTokenizers) && canImport(MLXLMHFAPI) && canImport(MLX) && !targetEnvironment(simulator)
            prose = try await MLXFacultyResearchWriter().write(surface: draft)
            #else
            prose = try await FallbackFacultyResearchWriter().write(surface: draft)
            #endif
            generation.preparedFacultyResearchSurface = draft.preparedFacultyResearchCopy(prose: prose, slotID: slot)
            surfaceRefreshDate = Date()
            generation.facultyResearchRecovery.recordSuccess()
            localBrainTelemetry.clearError()
            statusMessage = "\(draft.payload.metadata["facultyName"] ?? "The Support Guild") prepared a research folio for tonight."
            return true
        } catch {
            appLog.error("Prepared faculty research failed: \(error.localizedDescription, privacy: .public)")
            localBrainTelemetry.recordError("faculty research: \(error.localizedDescription)")
            generation.preparedFacultyResearchSurface = nil
            generation.facultyResearchRecovery.recordFailure()
            statusMessage = "The faculty research folio lost its place. The Book will try again later."
            return false
        }
    }

    func facultyResearchQueries(for surface: SurfacePage) -> [String] {
        let facultyID = surface.payload.metadata["facultyID"] ?? ""
        if facultyID == "dr-vellum" {
            return [
                "longevity research sleep exercise nutrition 2026",
                "meal timing protein energy mood nutrition behavior research",
                "nutrition tracking self monitoring behavior change research",
                "medication adherence health behavior research",
                "heart rate variability recovery longevity study"
            ]
        }
        return [
            "narrative psychology reauthoring self distancing research",
            "consciousness attention rumination self distancing study",
            "expressive writing narrative identity mental health research"
        ]
    }

    @MainActor
    @discardableResult
    func prepareLetterPageIfPossible(force: Bool = false, draftOverride: SurfacePage? = nil) async -> Bool {
        let slot = SurfaceCadence.slotID(for: surfaceRefreshDate, hours: 12)
        if force {
            guard !generation.isPreparingLetterPage, !localBrainTelemetry.isWorking else {
                return false
            }
        } else {
            guard generation.letterPageRecovery.shouldBegin(
                isPreparing: generation.isPreparingLetterPage,
                isLocalBrainWorking: localBrainTelemetry.isWorking,
                preparedSurface: generation.preparedLetterSurface,
                slotID: slot,
                requiredMetadataKey: "letterProse",
                now: surfaceRefreshDate
            ) else {
                return false
            }
        }

        var draftInputs = sourceInputs
        draftInputs.preparedLetterSurface = nil
        guard var draft = draftOverride ?? CharacterLetterPageGenerator.draftCandidate(for: today, inputs: draftInputs, now: surfaceRefreshDate),
              draft.type == .letter,
              isSourceEnabled(sourceID: draft.sourceID) else {
            return false
        }

        generation.isPreparingLetterPage = true
        defer { generation.isPreparingLetterPage = false }

        do {
            let clippings = await RealInterestGossipSearcher().clippings(
                for: letterResearchQueries(for: draft),
                limit: 4
            )
            draft = draft.withLetterResearchClippings(clippings)
            let prose = await CharacterLetterWriter().write(surface: draft)
            generation.preparedLetterSurface = draft.preparedLetterCopy(prose: prose, slotID: slot)
            surfaceRefreshDate = Date()
            generation.letterPageRecovery.recordSuccess()
            localBrainTelemetry.clearError()
            statusMessage = "\(draft.payload.metadata["senderName"] ?? "Someone") sent a letter through the margins."
            return true
        } catch {
            appLog.error("Prepared letter page failed: \(error.localizedDescription, privacy: .public)")
            localBrainTelemetry.recordError("letter page: \(error.localizedDescription)")
            generation.preparedLetterSurface = nil
            generation.letterPageRecovery.recordFailure()
            statusMessage = "The letter lost its address. The Book will try again later."
            return false
        }
    }

    func letterResearchQueries(for surface: SurfacePage) -> [String] {
        let query = surface.payload.metadata["researchQuery"]?.nonEmpty
        let interest = surface.payload.metadata["unwrittenInterest"]?.nonEmpty ?? "ordinary wonder"
        let home = surface.payload.metadata["homeContext"]?.nonEmpty ?? "local home"
        return [
            query,
            "\(interest) \(home)",
            "\(interest) local history ecology culture",
            "\(home) local history folklore nature"
        ].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty }
    }

    func markAutomaticIlluminatedSurfaceKept(_ surface: SurfacePage) {
        guard let assetID = surface.payload.metadata["assetLocalIdentifier"] else {
            return
        }
        var history = decodedIlluminatedPhotoHistory()
        history.keptAssetIdentifiers.insert(assetID)
        illuminatedPhotoHistoryData = encodedIlluminatedPhotoHistory(history)
        if generation.automaticIlluminatedSurface?.id == surface.id {
            generation.automaticIlluminatedSurface = nil
        }
    }

    func retireKeptSurfaceFromRising(
        _ surface: SurfacePage,
        preferredReplacement: SurfacePage? = nil
    ) {
        clearSurfaceUndoContext()
        let now = Date()
        var ledger = decodedDismissalLedger()
        dismissSurfaceFamily(surface, in: &ledger, at: now)
        if surface.type == .twoReadings {
            var history = vault.data.surfaceHistory ?? [:]
            history = CuratorVarietyGovernor.recordingServed(
                keys: [
                    "source:\(surface.sourceID)",
                    surface.varietyKey,
                    CuratorVarietyGovernor.typeKey(for: surface.type)
                ],
                into: history,
                now: now
            )
            vault.data.surfaceHistory = history
            vault.save()
        }
        ledger.prune(now: now, ttl: surfaceDismissalTTL)
        dismissedSurfaceLedgerV2 = encodedDismissalLedger(ledger)
        if let preferredReplacement {
            curatedSurfaceBench.removeAll { $0.id == preferredReplacement.id }
            curatedSurfaceBench.insert(preferredReplacement, at: 0)
        }
        replaceDismissedSurfaceInCache(surface, now: now)
    }

    func dismissSurfaceFamily(_ surface: SurfacePage, in ledger: inout SurfaceDismissalLedger, at now: Date) {
        for key in surface.curatorDeskExclusionKeys {
            ledger.dismiss(surfaceID: key, dayID: today.id, at: now)
        }
    }

    func clearPreparedSurfaceIfNeeded(_ surface: SurfacePage) {
        if generation.automaticIlluminatedSurface?.id == surface.id {
            generation.automaticIlluminatedSurface = nil
        }
        if generation.preparedStoryPageSurface?.id == surface.id {
            generation.preparedStoryPageSurface = nil
        }
        if generation.preparedGossipPageSurface?.id == surface.id {
            generation.preparedGossipPageSurface = nil
        }
        if generation.preparedFacultyResearchSurface?.id == surface.id {
            generation.preparedFacultyResearchSurface = nil
        }
        if generation.preparedLetterSurface?.id == surface.id {
            generation.preparedLetterSurface = nil
        }
        if preparedAnchorSurface?.id == surface.id {
            preparedAnchorSurface = nil
            nearbyAnchor = nil
        }
    }

    func decodedIlluminatedPhotoHistory() -> IlluminatedPhotoHistory {
        guard let data = illuminatedPhotoHistoryData.data(using: .utf8),
              let history = try? JSONDecoder().decode(IlluminatedPhotoHistory.self, from: data) else {
            return IlluminatedPhotoHistory()
        }
        return history
    }

    func encodedIlluminatedPhotoHistory(_ history: IlluminatedPhotoHistory) -> String {
        guard let data = try? JSONEncoder().encode(history),
              let encoded = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return encoded
    }

    func removeKeptPage(_ page: BookPage) {
        BookFeedback.play(.dismissPage)
        var day = today
        guard let index = day.pages.firstIndex(where: { $0.id == page.id }) else {
            statusMessage = "That page has already left the margin."
            return
        }

        let removedPage = day.pages.remove(at: index)
        undoRemovedPage = removedPage
        undoRemovedPageDayID = day.id
        clearSurfaceUndoContext()
        persist(day: day, message: "The \(removedPage.type.shortTitle.lowercased()) page left Today's Margins.")
    }

    func restoreLastRemovedPage() {
        guard let page = undoRemovedPage,
              let dayID = undoRemovedPageDayID,
              var day = days.first(where: { $0.id == dayID }) ?? (dayID == today.id ? today : nil) else {
            undoRemovedPage = nil
            undoRemovedPageDayID = nil
            return
        }

        BookFeedback.play(.undo)
        guard !day.pages.contains(where: { $0.id == page.id }) else {
            undoRemovedPage = nil
            undoRemovedPageDayID = nil
            statusMessage = "That page is already back in the margins."
            return
        }

        day.pages.append(page)
        day.pages.sort { $0.createdAt < $1.createdAt }
        undoRemovedPage = nil
        undoRemovedPageDayID = nil
        persist(day: day, message: "The \(page.type.shortTitle.lowercased()) page returned to Today's Margins.")
    }

    func dismissBookOfYouHero(_ page: BookPage) {
        BookFeedback.play(.dismissPage)
        dismissedBookOfYouHeroPageID = page.id
        statusMessage = "The Book of You preview slips back onto the shelf."
    }

    func dismissSurface(_ surface: SurfacePage) {
        tutorTouch("dismiss-surface")
        markFirstRunEngaged(surface)
        recordMagicMomentInteraction(surface, status: .questioned)
        BookFeedback.play(.dismissPage)
        if let favorID = surface.payload.metadata["bookFavorID"] {
            let base = vault.data.bookInterior ?? BookInteriorState(awakenedAt: Date())
            vault.data.bookInterior = BookInteriorEngine.recordingFavorReleased(
                base,
                favorID: favorID
            )
            vault.save()
            statusMessage = "Not today. The Book closes the favor without making your no mean anything else."
        }
        if surface.payload.metadata["bookInteriorSurface"] == "true" {
            let base = vault.data.bookInterior ?? BookInteriorState(awakenedAt: Date())
            vault.data.bookInterior = BookInteriorEngine.recordingSurfaceOpened(
                base,
                secretID: surface.payload.metadata["bookSecretID"],
                favoriteID: surface.payload.metadata["bookFavoriteID"],
                quirkID: surface.payload.metadata["bookQuirkID"],
                opinionID: surface.payload.metadata["bookOpinionID"],
                longGamePhase: surface.payload.metadata["bookLongGamePhase"]
            )
            vault.save()
        }
        if surface.payload.metadata["purchaseThankYou"] == "true" {
            purchaseThankYouSurface = nil
            if selectedSurface?.id == surface.id {
                selectedSurface = nil
            }
            statusMessage = ""
            return
        }
        if surface.type == .bookOfYou {
            // The braid nudge can now be swiped away. It returns on its own shorter
            // window (braidCardDismissalTTL) unless the day gets braided first — the
            // adapter hides it once `day.bookOfYou` exists. Record only the card's
            // own id (not the whole source family) so that short window governs when
            // it comes back.
            undoRemovedPage = nil
            undoRemovedPageDayID = nil
            var ledger = decodedDismissalLedger()
            let now = Date()
            ledger.dismiss(surfaceID: surface.id, dayID: today.id, at: now)
            ledger.prune(now: now, ttl: surfaceDismissalTTL)
            dismissedSurfaceLedgerV2 = encodedDismissalLedger(ledger)
            undoSurface = surface
            undoDayID = today.id
            undoSurfaceSlotIndex = surfacedPages.firstIndex(where: { $0.id == surface.id })
            undoSurfaceReplacementID = nil
            undoSurfaceDismissalKeys = [surface.id]
            statusMessage = "The braid nudge steps back for a while."
            recordReaderLearning(surface: surface, action: .dismissed, now: now)
            replaceDismissedSurfaceInCache(surface, now: now)
            return
        }
        undoRemovedPage = nil
        undoRemovedPageDayID = nil
        var ledger = decodedDismissalLedger()
        let now = Date()
        dismissSurfaceFamily(surface, in: &ledger, at: now)
        ledger.prune(now: now, ttl: surfaceDismissalTTL)
        dismissedSurfaceLedgerV2 = encodedDismissalLedger(ledger)
        if surface.type == .illuminatedPhoto,
           let assetID = surface.payload.metadata["assetLocalIdentifier"] {
            var history = decodedIlluminatedPhotoHistory()
            history.dismissedAssetIdentifiers.insert(assetID)
            illuminatedPhotoHistoryData = encodedIlluminatedPhotoHistory(history)
        }
        clearPreparedSurfaceIfNeeded(surface)
        if selectedSurface?.id == surface.id {
            selectedSurface = nil
        }
        undoSurface = surface
        undoDayID = today.id
        undoSurfaceSlotIndex = surfacedPages.firstIndex(where: { $0.id == surface.id })
        undoSurfaceReplacementID = nil
        undoSurfaceDismissalKeys = surface.curatorDeskExclusionKeys
        statusMessage = "The \(surface.type.shortTitle.lowercased()) page slipped back into the stacks for a while."
        // Dismissal stays warm but never pays a variable reward. Permanent
        // fragments are earned by attention, not by cycling Pages away.
        if let closingLine = PartingWhisper.closingLine(for: surface) {
            statusMessage = closingLine
        }
        if surface.payload.metadata["bookFavorID"] != nil {
            statusMessage = "Not today. The Book closes the favor without making your no mean anything else."
        }
        recordReaderLearning(surface: surface, action: .dismissed, now: now, saveImmediately: false)
        coolPageSourceForDismissedSurface(surface, now: now)
        replaceDismissedSurfaceInCache(surface, now: now)
    }

    func undoLastSurfaceDismissal() {
        guard let surface = undoSurface,
              let dayID = undoDayID else {
            return
        }

        BookFeedback.play(.undo)
        var ledger = decodedDismissalLedger()
        let keysToRestore = undoSurfaceDismissalKeys.isEmpty
            ? Set([surface.id])
            : undoSurfaceDismissalKeys
        for key in keysToRestore {
            ledger.restore(surfaceID: key, dayID: dayID)
        }
        dismissedSurfaceLedgerV2 = encodedDismissalLedger(ledger)
        let now = Date()
        if dayID == today.id {
            cancelPendingSurfaceRetirement(surfaceID: surface.id, now: now)
            restoreUndoneSurfaceOnDesk(
                surface,
                replacing: undoSurfaceReplacementID,
                preferredIndex: undoSurfaceSlotIndex
            )
        } else if pendingSurfaceRetirements[surface.id] != nil {
            // A stale undo action must never put yesterday's card onto today's
            // desk. Retire its old placeholder and restart any other pending
            // replacements against the current day instead.
            surfaceRetirementRevision &+= 1
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                pendingSurfaceRetirements[surface.id] = nil
                surfacedPages.removeAll { $0.id == surface.id }
            }
            if !pendingSurfaceRetirements.isEmpty {
                scheduleSurfaceRetirementReconciliation(now: now)
            }
        }
        clearSurfaceUndoContext()
        surfaceRefreshDate = now
        statusMessage = dayID == today.id
            ? "The \(surface.type.shortTitle.lowercased()) page found its way back."
            : "That page returned to yesterday's stacks. Today's desk stayed where it belongs."
    }

    /// The braid card's stable surface id (it omits an explicit id, so it falls
    /// back to "<sourceID>-<intent>"). Used to give it a shorter dismissal window.
    var braidCardSurfaceID: String {
        "\(BookPageSourceRegistry.source(for: .bookOfYou).id)-\(BookPageIntent.braid.rawValue)"
    }

    func dismissedSurfaceIDs(for dayID: String, now: Date) -> Set<String> {
        var ledger = decodedDismissalLedger()
        ledger.prune(now: now, ttl: surfaceDismissalTTL)
        var active = ledger.activeDismissedSurfaceIDs(for: dayID, now: now, ttl: surfaceDismissalTTL)
        // The braid nudge returns on its own shorter window: if its last swipe is
        // older than braidCardDismissalTTL, stop treating it as dismissed so it can
        // surface again (the adapter still hides it once the day has been braided).
        if active.contains(braidCardSurfaceID),
           !ledger.activeDismissedSurfaceIDs(for: dayID, now: now, ttl: braidCardDismissalTTL)
               .contains(braidCardSurfaceID) {
            active.remove(braidCardSurfaceID)
        }
        return active
    }

    func decodedDismissalLedger() -> SurfaceDismissalLedger {
        guard let data = dismissedSurfaceLedgerV2.data(using: .utf8),
              let ledger = try? JSONDecoder().decode(SurfaceDismissalLedger.self, from: data) else {
            return SurfaceDismissalLedger()
        }
        return ledger
    }

    func encodedDismissalLedger(_ ledger: SurfaceDismissalLedger) -> String {
        guard let data = try? JSONEncoder().encode(ledger),
              let encoded = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return encoded
    }

    func decodedPocketLedger() -> PocketLedger {
        guard let data = pocketLedgerData.data(using: .utf8),
              let ledger = try? JSONDecoder().decode(PocketLedger.self, from: data) else {
            return PocketLedger()
        }
        return ledger
    }

    func decodedChosenQuill() -> ChosenQuill? {
        guard let data = chosenQuillData.data(using: .utf8), !chosenQuillData.isEmpty else { return nil }
        return try? JSONDecoder().decode(ChosenQuill.self, from: data)
    }

    /// Keeping the Quillquarium's choosing page accepts the instrument: the
    /// minted quill rides in the page's metadata and is persisted here, from
    /// which point it tints story prompts and takes the occasional margin.
    func adoptChosenQuillIfNeeded(surface: SurfacePage) {
        guard decodedChosenQuill() == nil,
              let quillJSON = surface.payload.metadata[QuillChoosing.metadataKey]?.nonEmpty else { return }
        chosenQuillData = quillJSON
        if let quillName = surface.payload.metadata["quillName"]?.nonEmpty {
            statusMessage = "\(quillName) has taken its post in the spine."
        }
    }

    func encodedPocketLedger(_ ledger: PocketLedger) -> String {
        guard let data = try? JSONEncoder().encode(ledger),
              let encoded = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return encoded
    }

    /// Presses a fragment earned through attention into the Book's Pocket,
    /// where it stays for good. The id folds in the timestamp so two fragments
    /// from the same surface never collide.
    func pressKeepsakeIntoPocket(_ keepsake: PartingWhisper.Keepsake, from surface: SurfacePage, at now: Date) {
        var pocket = decodedPocketLedger()
        pocket.press(PocketKeepsake(
            id: "\(surface.id)-\(now.timeIntervalSince1970)",
            dayID: today.id,
            pageType: surface.type,
            object: keepsake.object,
            glyph: keepsake.glyph,
            foundAt: now,
            sourceSurfaceID: surface.id,
            title: keepsake.title,
            excerpt: keepsake.excerpt,
            reason: keepsake.reason,
            mediaAssets: keepsake.mediaAssets
        ))
        pocketLedgerData = encodedPocketLedger(pocket)
    }

    func isSourceEnabled(sourceID: String) -> Bool {
        let defaultValue = BookPageSourceRegistry.sources.first { $0.id == sourceID }?.isActive ?? true
        return decodedSourcePreferenceLedger()[sourceID] ?? defaultValue
    }

    func disabledSourceIDs() -> Set<String> {
        Set(BookPageSourceRegistry.sources.compactMap { source in
            isSourceEnabled(sourceID: source.id) ? nil : source.id
        })
    }

    func setSourceEnabled(sourceID: String, isEnabled: Bool) {
        var ledger = decodedSourcePreferenceLedger()
        ledger[sourceID] = isEnabled
        sourcePreferenceLedger = encodedSourcePreferenceLedger(ledger)
        statusMessage = isEnabled ? "That doorway is open again." : "That doorway has been softened for now."
    }

    func decodedSourcePreferenceLedger() -> [String: Bool] {
        guard let data = sourcePreferenceLedger.data(using: .utf8),
              let ledger = try? JSONDecoder().decode([String: Bool].self, from: data) else {
            return [:]
        }
        return ledger
    }

    func encodedSourcePreferenceLedger(_ ledger: [String: Bool]) -> String {
        guard let data = try? JSONEncoder().encode(ledger),
              let encoded = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return encoded
    }

    func braidToday(openWhenComplete: Bool = false) async {
        guard !generation.isBraiding else { return }
        guard workBlockingState.canStartBraid else {
            BookFeedback.play(.error)
            statusMessage = "The Book is already writing one page. Let that ink dry first."
            return
        }
        let braidDay = today
        guard !braidDay.capturedPages.isEmpty else {
            BookFeedback.play(.error)
            statusMessage = "The Book needs one true fragment before it can braid tonight."
            return
        }
        BookFeedback.play(.braidStart)
        generation.braidRecovery.beginAttempt()
        let start = Date()
        generation.isBraiding = true
        generation.braidingStartedAt = start
        braidingQuipIndex = Int.random(in: 0..<BraidingQuips.lines.count)
        statusMessage = "The Book is drawing today's fragments into thread..."
        defer {
            generation.lastBraidDuration = Date().timeIntervalSince(start)
            generation.braidingStartedAt = nil
            generation.isBraiding = false
        }

        do {
            var braidInputs = sourceInputs
            // A POI scout list is useful for quests, but it is not evidence of
            // where the reader is standing. Before each nightly braid, use one
            // fresh GPS reading (when the reader has already opened that
            // doorway) to recognize Home/a saved place and fetch local weather.
            braidInputs.nearbyAnchor = nil
            if didGrantLocationContextAccess,
               let liveContext = try? await NightlyBraidContextReader.request(anchors: anchorLedger) {
                braidInputs.currentLocationLabel = liveContext.locationLabel
                braidInputs.nearbyAnchor = liveContext.anchorProximity
                lastAnchorReadingLatitude = liveContext.latitude
                lastAnchorReadingLongitude = liveContext.longitude
                nearbyAnchor = liveContext.anchorProximity
                if let currentWeather = liveContext.weather {
                    braidInputs.weather = currentWeather
                    braidInputs.enchantedWeather = nil
                    weatherSignal = currentWeather
                    weatherPageSignal = currentWeather
                    enchantedWeather = nil
                    didRequestWeatherLocation = true
                }
            }
            let resolvedWorldEvents = braidInputs
                .resolvingWorldEvents(for: braidDay, now: Date())
                .activeWorldEvents
            let braidContext = LocalModelManager.braidContext(
                for: braidDay,
                days: days,
                themes: vault.data.themes ?? [],
                entityBeliefOffsets: entityBeliefLedger,
                learnedNotes: vault.data.learnedBraidNotes ?? [],
                nowPlaying: RadioStationRegistry.atmosphereLine(
                    state: vault.data.radio ?? .off,
                    unlockedPackIDs: Set(vault.data.ownedPacks ?? []),
                    worldEvents: resolvedWorldEvents
                ),
                activeWorldEvents: resolvedWorldEvents,
                readerLexicon: vault.data.readerLexicon ?? ReaderLexicon(),
                readerLearning: vault.data.readerLearning ?? ReaderLearningModel()
            )
            var braid = try await braider.braid(day: braidDay, context: braidContext)
            let headerContext = BraidPageDetails.HeaderContext.make(for: braid, day: braidDay, inputs: braidInputs)
            braid = BraidPageDetails.annotated(braid, context: braidContext, headerContext: headerContext)
            braid = BraidPageDetails.withPromiseEcho(braid, line: BraidEmber.keptPromiseLine(for: braidDay))
            braid.mediaAssets = braidDay.capturedPages.flatMap(\.mediaAssets)
            let day = BraidRecoveryState.dayByMarkingCapturedPagesUsed(braidDay, braid: braid)
            if braid.tags.contains("local-model-missing") {
                persist(day: day, message: "The Book kept today's page in its fallback hand. The local brain is still waking.")
            } else if braid.tags.contains("mlx-hook") {
                persist(day: day, message: "The model doorway answered. On your device, the braid will be local.")
            } else {
                persist(day: day, message: "The ink dried. Today's Book of You page is kept.")
            }
            // The day now holds a braid, so rebuild the desk to retire the braid
            // nudge (its adapter returns nothing once `day.bookOfYou` exists).
            surfaceRefreshDate = Date()
            if openWhenComplete {
                selectedSurface = keptSurface(for: braid)
            }
            BookFeedback.play(.braidComplete)
            celebrateBookOfYouCompletion(page: braid)
            modelReport = LocalModelManager.report()
            localBrainTelemetry.clearError()
            generation.braidRecovery.recordSuccess()
        } catch {
            BookFeedback.play(.error)
            localBrainTelemetry.recordError("braid: \(error.localizedDescription)")
            generation.braidRecovery.recordFailure(error.localizedDescription, day: braidDay)
            statusMessage = "The braid snagged, but nothing was lost. Let the page breathe, then try again. \(error.localizedDescription)"
        }
    }

    @MainActor
    func autoBraidIfNeeded(now: Date = Date()) async {
        guard BookSchedule.shouldAutoBraid(now),
              generation.didAutoBraidTodayID != today.id,
              today.bookOfYou == nil,
              !today.capturedPages.isEmpty,
              !generation.isBraiding else {
            return
        }

        generation.didAutoBraidTodayID = today.id
        statusMessage = "The hour has grown quiet; the Book is braiding today for you."
        await braidToday()
    }

    func runLaunchSmokeTestIfRequested() async {
        if ProcessInfo.processInfo.arguments.contains("--smoke-open-book-section") {
            let sections = glowBookSectionMenuItems
            appLog.info("Smoke: \(sections.count) book sections; opening first")
            if let first = sections.first {
                handleGlowMenuAction(.openBookSection(first.id))
                appLog.info("Smoke: book section surface presented: \(self.selectedSurface?.id ?? "nil", privacy: .public)")
            }
        }

        guard !didRunSmokeBraid,
              ProcessInfo.processInfo.arguments.contains("--smoke-braid") else {
            return
        }

        didRunSmokeBraid = true
        var day = today
        if day.capturedPages.isEmpty {
            day.pages.append(
                BookPage(
                    type: .mood,
                    promptText: "What is the weather inside?",
                    userInput: "Bright: A little electric, but hopeful.",
                    tags: ["bright"]
                )
            )
            persist(day: day, message: "A test fragment was tucked into the margin.")
        }

        await braidToday()
    }

    /// Captures only coarse, already-authorized context. This deliberately
    /// leaves out coordinates, calendar titles, and raw Health metrics; later
    /// connection-finding needs "rain / busy / lower body signal," not a second
    /// surveillance record.
    func pageContextSnapshot(at date: Date) -> BookPageContextSnapshot {
        let calendar = Calendar.current
        let weather = weatherPageSignal ?? weatherSignal ?? BookSourceInputs.from(insideCover: InsideCoverStore.load()).weather
        let weatherTags = RadioPageContext.weatherTags(
            weather: weather,
            enchanted: enchantedWeather
        )
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        let eventCount = bookCalendarEnabled
            ? calendarEvents.filter { event in
                let eventEnd = event.endsAt ?? event.startsAt
                return event.startsAt < end && eventEnd >= start
            }.count
            : nil
        let nearbyPlace = nearbyAnchor.flatMap { proximity in
            proximity.isInsideRadius ? proximity.anchor : nil
        }
        let chartEntriesSoFar = facultyEntries
            .filter {
                calendar.isDate($0.createdAt, inSameDayAs: date)
                    && $0.createdAt <= date
            }
            .sorted { $0.createdAt > $1.createdAt }
        let innerWeatherEntryID = chartEntriesSoFar
            .first(where: { $0.kind == .innerWeather })?
            .id
        let fuelEntryID = chartEntriesSoFar
            .first(where: { $0.kind == .fuel })?
            .id
        return BookPageContextSnapshot(
            at: date,
            calendar: calendar,
            weatherTags: Array(weatherTags),
            bodyScore: bodySignal?.isAvailable == true ? bodySignal?.score : nil,
            calendarEventCount: eventCount,
            nearbyAnchorID: nearbyPlace?.id,
            locationLabel: nearbyPlace?.name,
            innerWeatherEntryID: innerWeatherEntryID,
            fuelEntryID: fuelEntryID
        )
    }

    func persist(
        day incomingDay: BookDay,
        message: String,
        requestsFreshKeepContext: Bool = false
    ) {
        var day = incomingDay
        let alreadyStoredPageIDs = Set(days.flatMap(\.pages).map(\.id))
        let now = Date()
        var snapshot = pageContextSnapshot(at: now)
        if requestsFreshKeepContext {
            // Never mistake the last idle/weather refresh for evidence of this
            // Keep. These fields stay empty until its one-shot reading returns.
            snapshot.weatherTags = []
            snapshot.nearbyAnchorID = nil
            snapshot.locationLabel = nil
        }
        var newlyKeptPageIDs = Set<String>()
        for index in day.pages.indices {
            guard !alreadyStoredPageIDs.contains(day.pages[index].id),
                  abs(day.pages[index].createdAt.timeIntervalSince(now)) <= 10 * 60 else {
                continue
            }
            newlyKeptPageIDs.insert(day.pages[index].id)
            if day.pages[index].context == nil {
                day.pages[index].context = snapshot
            }
            if day.pages[index].attentionFingerprint == nil {
                day.pages[index].attentionFingerprint = AttentionFingerprint.make(from: day.pages[index])
            }
        }

        let previousDays = days
        let updatedDays = BookStore.upsert(day, in: days)
        // Process-wide monotonic time keeps ordering valid even if SwiftUI
        // recreates the root view while the shared writer actor survives.
        let revision = max(
            bookPersistenceRevision &+ 1,
            DispatchTime.now().uptimeNanoseconds
        )
        bookPersistenceRevision = revision

        // Reflect the keep immediately. The durable SwiftData transaction,
        // full-archive JSON encode/write, and resurfacing query are serialized
        // by BookPersistenceWriter away from MainActor.
        days = updatedDays
        statusMessage = message
        // Mark the projection stale. The next desk rebuild computes it on the
        // detached surface-builder executor; never project the whole archive on
        // the UI actor at the end of a keep.
        continuityCacheSignature = ""
        rebuildSurfaceCache()

        // A Keep should describe where it actually happened, not wherever the
        // last weather/Anchor refresh happened. Save first so location,
        // reverse-geocoding, or weather latency can never swallow the page;
        // then enrich precisely these new pages from one fresh GPS reading.
        // Coordinates remain transient and are never copied into page context.
        if requestsFreshKeepContext, !newlyKeptPageIDs.isEmpty {
            Task {
                await enrichKeptPagesWithFreshLocation(
                    pageIDs: newlyKeptPageIDs,
                    dayID: day.id,
                    message: message
                )
            }
        }

        let backgroundTask = BookPersistenceBackgroundTask()
        Task {
            defer { backgroundTask.finish() }
            do {
                guard let result = try await BookPersistenceWriter.shared.persist(
                    revision: revision,
                    day: day,
                    fallbackDays: updatedDays
                ) else { return }
                guard result.revision == bookPersistenceRevision else { return }

                days = result.days
                storeReport = result.storeReport
                databaseReport = result.databaseReport
                resurfacedPages = result.resurfacedPages
                returnedStackCards = result.returnedStackCards
                statusMessage = result.usedFallbackStore
                    ? "\(message) The shelves stumbled, so the Book kept a backup copy."
                    : message

                // The database can normalize or merge days. Rebuild from the
                // durable result, then refresh the widget with matching shelves.
                continuityCacheSignature = ""
                rebuildSurfaceCache()
                writeWidgetSnapshot()
            } catch {
                guard revision == bookPersistenceRevision else { return }
                days = previousDays
                storeReport = BookStore.report(for: previousDays)
                databaseReport = BookDatabase.report(for: previousDays)
                statusMessage = "The page would not settle yet: \(error.localizedDescription)"
                continuityCacheSignature = ""
                rebuildSurfaceCache()
                writeWidgetSnapshot()
            }
        }
    }

    @MainActor
    func enrichKeptPagesWithFreshLocation(
        pageIDs: Set<String>,
        dayID: String,
        message: String
    ) async {
        guard WeatherLocationReader.isAvailable else {
            appLog.info("Keep context: location services unavailable; page kept without a fresh place reading")
            return
        }

        do {
            let liveContext = try await NightlyBraidContextReader.request(anchors: anchorLedger)

            // These coordinates are useful only while resolving the reading.
            // The durable page stores a place label/Anchor reference and coarse
            // weather, never latitude or longitude.
            didGrantLocationContextAccess = true
            didRequestAnchorLocation = true
            lastAnchorReadingLatitude = liveContext.latitude
            lastAnchorReadingLongitude = liveContext.longitude
            nearbyAnchor = liveContext.anchorProximity

            var freshWeatherTags: [String]?
            if let currentWeather = liveContext.weather {
                weatherSignal = currentWeather
                weatherPageSignal = currentWeather
                enchantedWeather = nil
                didRequestWeatherLocation = true
                let resolvedTags = RadioPageContext.weatherTags(
                    weather: currentWeather,
                    enchanted: nil
                )
                if !resolvedTags.isEmpty {
                    freshWeatherTags = Array(resolvedTags)
                }
            }

            guard let dayIndex = days.firstIndex(where: { $0.id == dayID }) else {
                return
            }
            var enrichedDay = days[dayIndex]
            var didEnrichPage = false
            for pageIndex in enrichedDay.pages.indices
            where pageIDs.contains(enrichedDay.pages[pageIndex].id) {
                var page = enrichedDay.pages[pageIndex]
                var context = page.context ?? pageContextSnapshot(at: page.createdAt)
                context.locationLabel = liveContext.locationLabel.nonEmpty
                context.nearbyAnchorID = liveContext.anchorProximity?.anchor.id
                if let freshWeatherTags {
                    context.weatherTags = freshWeatherTags
                }
                page.context = context
                // The fingerprint may have been made during the optimistic
                // save, before this exact place/weather reading arrived.
                page.attentionFingerprint = AttentionFingerprint.make(from: page)
                enrichedDay.pages[pageIndex] = page
                didEnrichPage = true
            }

            guard didEnrichPage else { return }
            persist(day: enrichedDay, message: message)
        } catch {
            // A denied or unavailable reading never rolls back a Keep. The page
            // retains its time, chart references, and any already-known coarse
            // context, while the next Keep will make a fresh attempt.
            appLog.info("Keep context: fresh location was not available: \(error.localizedDescription, privacy: .private)")
        }
    }

    func refreshResurfacedPages() {
        resurfacedPages = (try? BookDatabase.resurfacingCandidates(limit: 64)) ?? []
        returnedStackCards = (try? BookDatabase.returnedStacksCards(from: days, limit: 3)) ?? []
    }

    func writeWidgetSnapshot() {
        // Hold the encode + App Group write until the opening movie clears; it is
        // run from the post-reveal launch pass and on every later surface refresh.
        guard didHydrateLaunchState, !isOpeningMovieVisible else { return }
        ReEnchantedWidgetSnapshotWriter.write(
            today: today,
            surfaces: surfaces,
            resurfacedPages: returnedStackCards.map(\.page),
            selfFacts: selfFacts,
            beliefScore: beliefScore,
            radio: radioManager.playback,
            radioIsPlaying: radioManager.isPlaying,
            activeWorldEvents: sourceInputs.resolvingWorldEvents(for: today, now: Date()).activeWorldEvents,
            bookInterior: sourceInputs.bookInterior
        )
    }

    @MainActor
    func loadAnchorLedger() {
        guard let data = anchorLedgerData.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([AnchorRecord].self, from: data),
              !decoded.isEmpty else {
            // A local-anchors.json in Documents seeds a fresh install
            // with the player's own places — save data, not binary data.
            if let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
               let seedData = try? Data(contentsOf: documents.appendingPathComponent("local-anchors.json")),
               let seeded = try? JSONDecoder().decode([AnchorRecord].self, from: seedData),
               !seeded.isEmpty {
                anchorLedger = seeded.filter { !AnchorRegistry.retiredAnchorIDs.contains($0.id) }
                saveAnchorLedger()
                return
            }
            anchorLedger = AnchorRegistry.defaultAnchors
            return
        }
        let active = decoded.filter { !AnchorRegistry.retiredAnchorIDs.contains($0.id) }
        anchorLedger = active.isEmpty ? AnchorRegistry.defaultAnchors : active
        if active.count != decoded.count {
            saveAnchorLedger()
        }
    }

    @MainActor
    func saveAnchorLedger() {
        guard let data = try? JSONEncoder().encode(anchorLedger),
              let encoded = String(data: data, encoding: .utf8) else {
            return
        }
        anchorLedgerData = encoded
    }

    @MainActor
    func checkInAnchorIfNeeded(_ surface: SurfacePage, tags: [String] = []) {
        guard let anchorID = surface.payload.metadata["anchorID"],
              let index = anchorLedger.firstIndex(where: { $0.id == anchorID }) else {
            return
        }
        let beliefGiven = min(AnchorRegistry.checkInBeliefReward, max(0, beliefScore))
        let previousMiniStory = anchorLedger[index].miniStory
        var updatedAnchor = anchorLedger[index].checkedIn(on: Date(), beliefGiven: beliefGiven)
        if let landing = AnchorMiniStory.landing(from: surface.payload.metadata, tags: tags) {
            updatedAnchor.miniStory = AnchorMiniStory.advanced(previous: previousMiniStory, landing: landing)
        }
        anchorLedger[index] = updatedAnchor
        beliefScore = max(0, beliefScore - beliefGiven)
        saveAnchorLedger()
        if beliefGiven > 0 {
            BookFeedback.beliefTransferred(amount: beliefGiven, recipientGlow: updatedAnchor.belief)
            anchorMessage = "\(updatedAnchor.name) kept the visit and took \(beliefGiven) Belief from your Glow."
        } else {
            anchorMessage = "Your Glow is too dim to feed \(updatedAnchor.name) today, but the visit still counts."
        }
        if nearbyAnchor?.anchor.id == anchorID {
            nearbyAnchor = nil
        }
    }

    @discardableResult
    @MainActor
    func refreshAnchorProximity(isUserInitiated: Bool) async -> Bool {
        guard !isCheckingAnchors else { return false }
        guard AnchorLocationReader.isAvailable else {
            if isUserInitiated {
                anchorMessage = "This device cannot check for nearby Anchors yet."
            }
            return false
        }

        isCheckingAnchors = true
        if isUserInitiated {
            anchorMessage = "The Book is listening for the nearest Anchor..."
        }
        defer {
            isCheckingAnchors = false
        }

        do {
            AppMemoryLedger.record("anchor-before-location")
            let coordinate = try await AnchorLocationReader.requestLocation()
            AppMemoryLedger.record("anchor-after-location")
            didRequestAnchorLocation = true
            didGrantLocationContextAccess = true
            lastAnchorReadingLatitude = coordinate.latitude
            lastAnchorReadingLongitude = coordinate.longitude
            if let proximity = AnchorRegistry.nearestAnchor(
                to: coordinate.latitude,
                longitude: coordinate.longitude,
                anchors: anchorLedger
            ) {
                nearbyAnchor = proximity
                let source = OuterStacksAnchorPageSourceAdapter()
                var draftInputs = sourceInputs
                draftInputs.nearbyAnchor = proximity
                preparedAnchorSurface = source.manualSurface(
                    for: today,
                    context: CuratorContext.make(for: today),
                    inputs: draftInputs,
                    now: Date()
                )
                anchorMessage = "\(proximity.anchor.name) is \(Int(proximity.distanceMeters.rounded()))m away. The Outer Stacks page is awake."
            } else {
                nearbyAnchor = nil
                preparedAnchorSurface = nil
                anchorMessage = "No known Anchor lit within two hundred meters. This may become a future Anchor site."
            }
            surfaceRefreshDate = Date()
            return true
        } catch is CancellationError {
            if isUserInitiated {
                anchorMessage = "The ley line went quiet before the reading finished. Tap once more."
            }
            return false
        } catch {
            didRequestAnchorLocation = true
            if isUserInitiated {
                anchorMessage = error.localizedDescription
            }
            return false
        }
    }

    @MainActor
    func requestWeatherSignal() async {
        await refreshWeatherSignal(isUserInitiated: true, shouldEnchant: true)
    }

    @MainActor
    func openCalendarDoorway(from surface: SurfacePage? = nil) async {
        guard CalendarDoorway.isAvailable else {
            statusMessage = "This build cannot open the Calendar Doorway."
            return
        }

        bookCalendarEnabled = true
        statusMessage = "Bellkeeper Elian is opening the Calendar Doorway..."
        let events = await CalendarDoorway.upcomingEvents()
        calendarEvents = events
        let now = Date()
        surfaceRefreshDate = now
        if let surface {
            clearSurfaceUndoContext()
            replaceDismissedSurfaceInCache(surface, now: now)
        }
        statusMessage = events.isEmpty
            ? "The Calendar Doorway is open, but no hinges are inked yet."
            : "The Book can see \(events.count) inked hour\(events.count == 1 ? "" : "s") ahead."
    }

    @MainActor
    func refreshDynamicSourcesIfNeeded(
        now: Date = Date(),
        allowsGeneratedWork: Bool = true
    ) async {
        let refreshSlot = SurfaceCadence.slotID(for: now, hours: 4)

        if didRequestHealthKitBodySignal,
           isSourceEnabled(sourceID: "body-page"),
           lastAutomaticBodySourceRefreshSlot != refreshSlot {
            if await refreshHealthKitBodySignal(isUserInitiated: false) {
                lastAutomaticBodySourceRefreshSlot = refreshSlot
            }
        }

        if bookCalendarEnabled {
            calendarEvents = await CalendarDoorway.upcomingEvents(now: now)
        }
        if publicMarginsIncomingOptIn,
           lastPublicMarginsRefreshSlot != refreshSlot {
            do {
                publicMarginsSnapshot = try await PublicMarginsAPI.fetchSnapshot()
                lastPublicMarginsRefreshSlot = refreshSlot
            } catch {
                // A public doorway may be quiet or offline. The private Book
                // remains untouched, and the next ordinary refresh can retry.
            }
        }
        if didRequestWeatherLocation,
           isSourceEnabled(sourceID: "weather-page"),
           lastAutomaticWeatherSourceRefreshSlot != refreshSlot {
            if await refreshWeatherSignal(isUserInitiated: false, shouldEnchant: allowsGeneratedWork) {
                lastAutomaticWeatherSourceRefreshSlot = refreshSlot
            }
        }

        if allowsGeneratedWork {
            runCastAgencyTurnIfNeeded(now: now)
        }
    }

    @discardableResult
    @MainActor
    func refreshWeatherSignal(isUserInitiated: Bool, shouldEnchant: Bool) async -> Bool {
        guard !isRequestingWeather else { return false }
        guard !shouldEnchant || workBlockingState.canRequestWeather else {
            if isUserInitiated {
                weatherMessage = "The Book is already writing. Let that ink dry, then ask the sky again."
            }
            return false
        }
        isRequestingWeather = true
        if isUserInitiated {
            weatherMessage = "The Book is leaning toward the window..."
        }
        defer {
            isRequestingWeather = false
        }

        do {
            AppMemoryLedger.record("weather-before-location")
            let signal = try await WeatherLocationReader.requestWeatherSignal()
            AppMemoryLedger.record("weather-after-location")
            didRequestWeatherLocation = true
            didGrantLocationContextAccess = true
            weatherSignal = signal
            weatherPageSignal = signal
            if shouldEnchant {
                enchantedWeather = nil
                if isUserInitiated {
                    weatherMessage = "The sky has been read. The Book is finding its weather-words..."
                }
                AppMemoryLedger.record("weather-before-gemma")
                let enchanted = try await weatherEnchanter.enchantWeather(weather: signal, day: today)
                AppMemoryLedger.record("weather-after-gemma")
                enchantedWeather = enchanted
            } else if enchantedWeather?.summary != signal.phrase {
                enchantedWeather = nil
            }
            surfaceRefreshDate = Date()
            weatherMessage = shouldEnchant
                ? "The Weather Page is ready; the forecast remains plain enough to trust."
                : "The sky refreshed its note. The Weather Page has fresh air in it."
            if isUserInitiated {
                lastAutomaticWeatherSourceRefreshSlot = SurfaceCadence.slotID(for: Date(), hours: 4)
            }
            return true
        } catch is CancellationError {
            didRequestWeatherLocation = true
            if isUserInitiated {
                weatherMessage = "The window closed before the Book finished listening. Tap once more."
            }
            return false
        } catch {
            didRequestWeatherLocation = true
            if isUserInitiated {
                weatherPageSignal = nil
                enchantedWeather = nil
                weatherMessage = "The sky would not come through yet: \(error.localizedDescription)"
            }
            return false
        }
    }

    @MainActor
    @discardableResult
    func prepareWeatherPageIfPossible() async -> Bool {
        guard let signal = sourceInputs.weather,
              signal.isAvailable,
              enchantedWeather == nil,
              workBlockingState.canRequestWeather else {
            return false
        }

        do {
            AppMemoryLedger.record("weather-before-curator-gemma")
            let enchanted = try await weatherEnchanter.enchantWeather(weather: signal, day: today)
            AppMemoryLedger.record("weather-after-curator-gemma")
            weatherPageSignal = signal
            enchantedWeather = enchanted
            surfaceRefreshDate = Date()
            localBrainTelemetry.clearError()
            statusMessage = "The Weather Page has dried. The curator can let it rise."
            return true
        } catch {
            localBrainTelemetry.recordError("weather page: \(error.localizedDescription)")
            statusMessage = "The Weather Page could not finish translating yet."
            return false
        }
    }

    @MainActor
    func refreshWonderCompassSelection() async {
        _ = await prepareWonderCompassSelectionIfPossible(force: true)
    }

    @MainActor
    @discardableResult
    func prepareWonderCompassSelectionIfPossible(force: Bool = false) async -> Bool {
        guard isSourceEnabled(sourceID: "wonder-compass"),
              !isChoosingWonderCompassPassage else {
            return false
        }
        if !force, selectedWonderCompassSnippet != nil, selectedWonderCompassSelector == "gemma" {
            return false
        }

        isChoosingWonderCompassPassage = true
        defer { isChoosingWonderCompassPassage = false }

        let inputsWithoutSelection: BookSourceInputs = {
            var inputs = sourceInputs
            inputs.selectedWonderCompass = nil
            return inputs
        }()
        let candidates = BookReferenceCatalog.relevantWonderCompassSnippets(
            for: today,
            inputs: inputsWithoutSelection,
            now: surfaceRefreshDate,
            limit: 8
        )
        guard !candidates.isEmpty else { return false }

        do {
            selectedWonderCompassSnippet = try await wonderCompassChooser.chooseWonderCompassSnippet(
                day: today,
                inputs: inputsWithoutSelection,
                candidates: candidates
            )
            selectedWonderCompassSelector = "gemma"
            surfaceRefreshDate = Date()
            localBrainTelemetry.clearError()
            return true
        } catch {
            localBrainTelemetry.recordError("wonder compass: \(error.localizedDescription)")
            selectedWonderCompassSnippet = nil
            selectedWonderCompassSelector = nil
            return false
        }
    }

    @MainActor
    func requestHealthKitBodySignal() async {
        await refreshHealthKitBodySignal(isUserInitiated: true)
    }

    @discardableResult
    @MainActor
    func refreshHealthKitBodySignal(isUserInitiated: Bool) async -> Bool {
        guard !isRequestingHealthKit else { return false }
        isRequestingHealthKit = true
        if isUserInitiated {
            healthKitMessage = "The Book is listening for the body's quiet weather..."
        }
        defer {
            isRequestingHealthKit = false
        }

        do {
            let signal = try await HealthKitBodyReader.requestBodySignal()
            didRequestHealthKitBodySignal = true
            bodySignal = signal
            surfaceRefreshDate = Date()
            healthKitMessage = "The Body Page is awake. The Book will name the response, not the source."
            if isUserInitiated {
                lastAutomaticBodySourceRefreshSlot = SurfaceCadence.slotID(for: Date(), hours: 4)
            }
            return true
        } catch is CancellationError {
            didRequestHealthKitBodySignal = true
            if isUserInitiated {
                bodySignal = nil
                healthKitMessage = "The health doorway closed before the Book finished listening. Tap once more."
            }
            return false
        } catch {
            didRequestHealthKitBodySignal = true
            if isUserInitiated {
                bodySignal = nil
                healthKitMessage = "Permission was given, but the body page stayed quiet: \(error.localizedDescription)"
            }
            return false
        }
    }

    func installModel() async {
        guard !isInstallingModel else { return }
        isInstallingModel = true
        installMessage = "Preparing model download..."
        installProgress = nil
        appLog.info("Gemma install requested")

        let previousIdleTimerState = UIApplication.shared.isIdleTimerDisabled
        UIApplication.shared.isIdleTimerDisabled = true
        let backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "Install Gemma") {
            appLog.error("Gemma install background task expired")
        }
        defer {
            UIApplication.shared.isIdleTimerDisabled = previousIdleTimerState
            if backgroundTaskID != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
            }
            isInstallingModel = false
            modelReport = LocalModelManager.report()
        }

        #if NATIVE_LOCAL_BRAIN && canImport(MLXLMHFAPI)
        do {
            let model = LocalModelManager.preferredModel
            let modelID = model.modelID
            appLog.info("Starting streaming Hugging Face download for \(modelID, privacy: .public)")
            let directory = LocalModelManager.modelDirectory(for: modelID)
            installMessage = "Clearing old local models before downloading \(model.label)..."
            LocalModelManager.removeKnownLocalModels()
            try await LocalModelStreamingInstaller.download(
                modelID: modelID,
                revision: model.revision,
                to: directory
            ) { progress in
                let percent = Int(progress.fraction * 100)
                installProgress = progress.fraction
                installMessage = "Downloading \(model.label)... \(percent)%"
            }
            try LocalModelManager.activateModel(
                modelID: modelID,
                directory: directory
            )
            LocalModelManager.removeSupersededModels(for: modelID, preserving: directory)
            appLog.info("Gemma install completed at \(directory.path, privacy: .private)")
            installProgress = 1
            installMessage = "\(model.label) is installed. The old local model was cleared if it was still on the shelf."
            modelReport = LocalModelManager.report()
            surfaceRefreshDate = Date()
            rebuildSurfaceCache()
        } catch {
            appLog.error("Gemma install failed: \(error.localizedDescription, privacy: .public)")
            installProgress = nil
            installMessage = "Model install failed: \(error.localizedDescription)"
        }
        #else
        installProgress = nil
        installMessage = "The Hugging Face downloader is not linked in this build."
        #endif
    }
}

private struct LocalModelDownloadProgress: Sendable {
    var completedBytes: Int64
    var totalBytes: Int64

    var fraction: Double {
        guard totalBytes > 0 else { return 0 }
        return min(max(Double(completedBytes) / Double(totalBytes), 0), 1)
    }
}

private enum LocalModelStreamingInstaller {
    struct RepoInfo: Decodable {
        var siblings: [Sibling]
    }

    struct Sibling: Decodable {
        var rfilename: String
        var size: Int64?
    }

    static func download(
        modelID: String,
        revision: String,
        to directory: URL,
        progressHandler: @MainActor @Sendable @escaping (LocalModelDownloadProgress) -> Void
    ) async throws {
        let files = try await filesToDownload(modelID: modelID, revision: revision)
        let totalBytes = files.reduce(Int64(0)) { $0 + ($1.size ?? 1) }
        var completedBytes = Int64(0)
        let fileManager = FileManager.default

        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        for file in files {
            try Task.checkCancellation()
            let destination = directory.appendingPathComponent(file.rfilename)
            try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)

            let expectedSize = file.size
            if let expectedSize,
               let currentSize = existingFileSize(at: destination),
               currentSize == expectedSize {
                completedBytes += expectedSize
                await progressHandler(LocalModelDownloadProgress(completedBytes: completedBytes, totalBytes: totalBytes))
                continue
            }

            let temporaryURL = destination
                .deletingLastPathComponent()
                .appendingPathComponent(".\(destination.lastPathComponent).download")
            try? fileManager.removeItem(at: temporaryURL)

            let startingBytes = completedBytes
            let downloader = LocalModelFileDownloader(destination: temporaryURL) { bytesWritten, expectedBytes in
                let fileBytes = expectedSize ?? expectedBytes
                let downloadTotal = max(totalBytes - (expectedSize ?? 1) + fileBytes, 1)
                let downloadProgress = LocalModelDownloadProgress(
                    completedBytes: startingBytes + min(bytesWritten, fileBytes),
                    totalBytes: downloadTotal
                )
                Task { @MainActor in
                    progressHandler(downloadProgress)
                }
            }
            try await downloader.download(from: resolveURL(modelID: modelID, revision: revision, path: file.rfilename))

            if let expectedSize {
                let actualSize = fileSize(from: try fileManager.attributesOfItem(atPath: temporaryURL.path)[.size])
                guard actualSize == expectedSize else {
                    try? fileManager.removeItem(at: temporaryURL)
                    throw CocoaError(.fileReadCorruptFile)
                }
            }

            try? fileManager.removeItem(at: destination)
            try fileManager.moveItem(at: temporaryURL, to: destination)
            completedBytes += expectedSize ?? (existingFileSize(at: destination) ?? 1)
            await progressHandler(LocalModelDownloadProgress(completedBytes: completedBytes, totalBytes: totalBytes))
        }
    }

    static func filesToDownload(modelID: String, revision: String) async throws -> [Sibling] {
        let infoURL = apiURL(modelID: modelID, revision: revision)
        let (data, response) = try await URLSession.shared.data(from: infoURL)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let repoInfo = try JSONDecoder().decode(RepoInfo.self, from: data)
        return repoInfo.siblings
            .filter { shouldInstall(path: $0.rfilename) }
            .sorted { left, right in
                let leftWeight = left.rfilename.hasSuffix(".safetensors") ? 1 : 0
                let rightWeight = right.rfilename.hasSuffix(".safetensors") ? 1 : 0
                if leftWeight != rightWeight {
                    return leftWeight < rightWeight
                }
                return left.rfilename < right.rfilename
            }
    }

    static func shouldInstall(path: String) -> Bool {
        let allowedSuffixes = [".safetensors", ".json", ".jinja", ".model", ".txt"]
        return allowedSuffixes.contains { path.hasSuffix($0) }
    }

    static func existingFileSize(at url: URL) -> Int64? {
        guard let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] else {
            return nil
        }
        return fileSize(from: size)
    }

    static func fileSize(from value: Any?) -> Int64? {
        if let size = value as? Int64 {
            return size
        }
        if let number = value as? NSNumber {
            return number.int64Value
        }
        return nil
    }

    static func apiURL(modelID: String, revision: String) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "huggingface.co"
        components.path = "/api/models/\(modelID)/revision/\(revision)"
        return components.url!
    }

    static func resolveURL(modelID: String, revision: String, path: String) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "huggingface.co"
        components.path = "/\(modelID)/resolve/\(revision)/\(path)"
        components.queryItems = [URLQueryItem(name: "download", value: "true")]
        return components.url!
    }
}

private final class LocalModelFileDownloader: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private static let sessionIdentifierPrefix = "com.openclaw.enchantify.insidecover.local-model-download"

    let destination: URL
    let progressHandler: @Sendable (Int64, Int64) -> Void
    let lock = NSLock()
    var continuation: CheckedContinuation<Void, Error>?
    var session: URLSession?
    var sessionIdentifier: String?

    init(destination: URL, progressHandler: @escaping @Sendable (Int64, Int64) -> Void) {
        self.destination = destination
        self.progressHandler = progressHandler
    }

    func download(from url: URL) async throws {
        try await withCheckedThrowingContinuation { continuation in
            lock.withLock {
                self.continuation = continuation
                let identifier = Self.sessionIdentifierPrefix + ".\(UUID().uuidString)"
                let configuration = URLSessionConfiguration.background(withIdentifier: identifier)
                configuration.timeoutIntervalForRequest = 120
                configuration.timeoutIntervalForResource = 86_400
                configuration.isDiscretionary = false
                configuration.sessionSendsLaunchEvents = true
                configuration.allowsConstrainedNetworkAccess = true
                configuration.allowsExpensiveNetworkAccess = true
                let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
                self.session = session
                self.sessionIdentifier = identifier
                session.downloadTask(with: url).resume()
            }
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        progressHandler(totalBytesWritten, max(totalBytesExpectedToWrite, totalBytesWritten))
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        do {
            guard let response = downloadTask.response as? HTTPURLResponse,
                  (200..<300).contains(response.statusCode) else {
                throw URLError(.badServerResponse)
            }
            try FileManager.default.moveItem(at: location, to: destination)
            finish(with: .success(()))
        } catch {
            finish(with: .failure(error))
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error {
            finish(with: .failure(error))
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        guard let identifier = session.configuration.identifier else { return }
        LocalModelBackgroundURLSessionEvents.shared.finishEvents(for: identifier)
    }

    func finish(with result: Result<Void, Error>) {
        let continuation = lock.withLock {
            let continuation = self.continuation
            let identifier = self.sessionIdentifier
            self.continuation = nil
            self.sessionIdentifier = nil
            self.session?.finishTasksAndInvalidate()
            self.session = nil
            if let identifier {
                LocalModelBackgroundURLSessionEvents.shared.finishEvents(for: identifier)
            }
            return continuation
        }
        switch result {
        case .success:
            continuation?.resume()
        case let .failure(error):
            continuation?.resume(throwing: error)
        }
    }
}

final class LocalModelBackgroundURLSessionEvents: @unchecked Sendable {
    static let shared = LocalModelBackgroundURLSessionEvents()

    private let lock = NSLock()
    private var completionHandlers: [String: () -> Void] = [:]

    private init() {}

    func setCompletionHandler(_ completionHandler: @escaping () -> Void, for identifier: String) {
        let handlerToRun: (() -> Void)? = lock.withLock {
            if completionHandlers[identifier] == nil {
                completionHandlers[identifier] = completionHandler
                return nil
            }
            return completionHandler
        }
        handlerToRun?()
    }

    func finishEvents(for identifier: String) {
        let completionHandler = lock.withLock {
            completionHandlers.removeValue(forKey: identifier)
        }
        completionHandler?()
    }
}

private struct LocalBrainReadingRoom: View {
    var isPaused = false

    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State var glow = false

    var body: some View {
        ZStack {
            Color(red: 0.025, green: 0.027, blue: 0.060)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(BookPalette.lampGold)
                    .shadow(color: BookPalette.lampGold.opacity(glow && !isPaused ? 0.46 : 0.16), radius: glow && !isPaused ? 18 : 6)

                Text("The Book is reading.")
                    .font(.system(.title2, design: .serif, weight: .semibold))
                    .foregroundStyle(BookPalette.nightText)

                Text("The shelves have gone quiet to make room for the ink.")
                    .font(.system(.callout, design: .serif))
                    .foregroundStyle(BookPalette.nightText.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
        }
        .onAppear {
            guard !reduceMotion && !isPaused else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
        .onChange(of: isPaused) { _, paused in
            if paused {
                glow = false
            } else if !reduceMotion {
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                    glow = true
                }
            }
        }
    }
}

private struct ColophonDedicationCard: View {
    private let dedicationLines = [
        "For Amanda, the first Doobaleedoo and the true wonder in my life. I love you! There would be no book, one of my life's biggest dreams, without you. Thank you for everything. Together forever. I'll give up Heaven if you aren't there with me.",
        "For Mom, thank you for my one wild and precious life, and thank you for being the perfect Mom for me. Birds of a feather. I wouldn't want anyone else to fill that role. I don't see you enough. Beth is pretty awesome, too.",
        "For my sister, Beth, for being the younger, but better, sibling that I look up to. I wish I was half as capable and caring as you are. Thank you ahead of time for proofreading this book, lol.",
        "And, surprisingly, for Tim, rest in peace. Thank you for gifting me the world of The Hobbit in second grade. It changed my life and gave me things to hold onto: reading and good fantasy. Also, you had great taste in music."
    ]

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(dedicationLines, id: \.self) { line in
                    Text(line)
                }
            }
            .font(.caption2)
            .foregroundStyle(BookPalette.nightText.opacity(0.68))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 6)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text("A quiet dedication")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BookPalette.nightText.opacity(0.86))
                Text("Developed by an Obsessed Guy with an awesome wife, 2 cats, and a happy, small life.")
                    .font(.caption2)
                    .foregroundStyle(BookPalette.nightText.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(BookPalette.teal)
        .padding(12)
        .background(BookPalette.page.opacity(0.42), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(BookPalette.gold.opacity(0.18), lineWidth: 1)
        )
    }
}

/// The Colophon's proof that corrections change the reading: every rule the
/// reader has taught the Book, spoken back in its own voice. Shown only once
/// the reader has actually taught it something.
private struct ColophonTaughtReadingCard: View {
    let rules: [TaughtReadingRule]

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(rules) { rule in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.seal")
                            .font(.caption2)
                            .foregroundStyle(BookPalette.teal.opacity(0.8))
                            .padding(.top, 1)
                        Text(rule.line)
                    }
                }
            }
            .font(.caption2)
            .foregroundStyle(BookPalette.nightText.opacity(0.68))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 6)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text("How the Book reads you")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BookPalette.nightText.opacity(0.86))
                Text("The rules you have taught it, kept and honored.")
                    .font(.caption2)
                    .foregroundStyle(BookPalette.nightText.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(BookPalette.teal)
        .padding(12)
        .background(BookPalette.page.opacity(0.42), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(BookPalette.gold.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct FallbackFacultyResearchWriter {
    func write(surface: SurfacePage) async throws -> String {
        try await Task.sleep(nanoseconds: 250_000_000)
        let faculty = surface.payload.metadata["facultyName"] ?? "Support Faculty"
        let topic = surface.payload.metadata["researchTopic"] ?? "care research"
        return """
        Field finding: \(faculty) reviewed the chart through the Margin-Glass and found one useful question inside the noise.

        What it might mean: \(topic) matters most here when it becomes small enough to try today, not when it becomes an identity.

        Tiny experiment: Track one before/after signal around the next ordinary care action.

        Uncertainty: This is research for attention, not a diagnosis or treatment plan.
        """
    }
}
