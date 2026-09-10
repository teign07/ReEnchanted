import Foundation


/// Tunable thresholds gating the emergent/reflective pages that comment on the
/// reader's library rather than capture new material.
enum EmergentPageMaturity {
    /// Minimum kept fragments before reflective pages may surface.
    static let minimumKeptPages = 4
    /// How long after the first kept page reflective pages stay folded away.
    static let minimumAgeSeconds: TimeInterval = 6 * 3600
}

struct BookSourceInputs: Equatable {
    var days: [BookDay] = []
    var publicationEpoch: BookPublicationEpoch? = nil
    var bookWorkings: BookWorkingLedger = .empty
    var bookInterior: BookInteriorState = .unawakened
    var magicMoment: MagicMomentState = MagicMomentState()
    var bookObservations: [BookObservationRecord] = []
    var bookReadingBoundaries: [BookReadingBoundary] = []
    /// Where the reader has gone in the Book without being sent. The desk reads
    /// it; nothing here ever writes it. Wear is recorded at the moment a room
    /// opens, by the hand that opened it.
    var readerWear: ReaderWearLedger = ReaderWearLedger()
    /// Standing correspondences only. The desk reads this; it never computes
    /// it. Discovery happens in `GrimoireKeeper`, off the main thread.
    var grimoire: GrimoireLedger = GrimoireLedger()
    var overnightConnectionDrafts: [OvernightConnectionDraft] = []
    var chosenQuill: ChosenQuill?
    var body: BodySourceSignal?
    var weather: WeatherSourceSignal?
    var enchantedWeather: EnchantedWeatherSignal?
    /// A coarse, freshly resolved label for where the reader is now (for
    /// example "Home" or "Portland"). Nearby POIs are discovery candidates,
    /// not proof that the reader is standing inside one of them.
    var currentLocationLabel: String?
    /// Reader-approved meaning of the current area. Unlike a locality label,
    /// this is explicit knowledge such as Home or Work and may safely shape
    /// immediate curation and later pattern evidence.
    var currentPlaceContext: CompassPlaceContext?
    /// Count only: the reader-approved places the Compass can recognise again.
    /// Coordinates stay in their existing local ledger and never enter the
    /// broad source packet merely to let the Book tell the truth about its size.
    var rememberedPlaceCount: Int = 0
    /// Ephemeral, random identity for a fresh but unlabeled area. It contains no
    /// coordinate and exists only long enough to offer a Familiar Place You Page.
    var currentPlaceNamingOpportunityID: String?
    var anchors: [AnchorRecord] = AnchorRegistry.defaultAnchors
    var nearbyAnchor: AnchorProximity?
    var preparedAnchorSurface: SurfacePage?
    var narrative: NarrativeSourceSnapshot?
    var selfFacts: [SelfFact] = []
    /// One explicit, revocable doorway for any search query shaped by reader
    /// facts, relationships, interests, or home context.
    var allowsPersonalizedWebResearch = false
    var facultyEntries: [FacultyEntry] = []
    var customCastMembers: [CustomCastMember] = []
    var electives: [UnwrittenElective] = []
    var entityBeliefOffsets: [String: Int] = [:]
    /// Recent changes in living Belief, carried so reader-facing Academy
    /// summaries can name the movement rather than only the resulting score.
    var beliefEconomy: BeliefEconomyState = BeliefEconomyState()
    var relationshipField: [String: RelationshipTie] = [:]
    /// The Academy's own small canon: what the cast did on the world clock,
    /// including the movements no Page ever reported. Belated discovery reads
    /// from here.
    var castAgency: CastAgencyState = CastAgencyState()
    /// What the Cast is already in the middle of. This is the seed that lets a
    /// share of world motion be selected by the world's own business instead of
    /// by tag overlap with the reader's kept pages.
    var castUndertakings: [CastUndertaking] = []
    /// Which of those threads the reader has actually been following. Lets a
    /// beat continue a story instead of sampling the Academy at random.
    var undertakingSerial: UndertakingSerial = UndertakingSerial()
    /// What the cast has actually done to each other, kept whole. This is the
    /// shared record; each character's own memory of the same act lives in
    /// their `NarrativeEntityMemory`, framed from the inside and asymmetric.
    var castActs: CastActLedger = .empty
    /// Seasonal volumes standing at the door, waiting to be posted. Populated
    /// by the Bindery when a Bound Year season binds; empty for everyone else.
    var seasonalDispatches: [SeasonalDispatch] = []
    /// Volumes already sent away to be printed, each of which earns a Page.
    var pressedVolumes: [PressedVolumeKeepsake] = []
    /// Live consequences of recent emergent transitions. These colour existing
    /// surfaces; they never add one.
    var worldPressures: [WorldPressure] = []
    /// What the Academy's rooms remember. A room with a reputation can be cast
    /// in gossip as an actor rather than a setting.
    var placeStates: [String: PlaceState] = [:]
    /// Live multi-party arguments about the Academy's own business.
    var contestedQuestions: [ContestedQuestion] = []
    var faeState: FaePlayerState = FaePlayerState()
    var pactWar: PactWarState = PactWarState()
    var hemisphere: Hemisphere = .northern
    /// A deliberately coarse coordinate, carried only so the Windows family can
    /// work out what the local sun is doing. Nil until the reader has allowed
    /// location for weather; the sun-cut feasts simply stay quiet without it.
    var coordinate: ReaderCoordinate?
    /// Weather tags for right now, as the enchanted weather signal read them.
    /// The Firsts family compares these against the archive.
    var currentWeatherTags: Set<String> = []
    /// Month and day, if the reader has told the Book. Never a year.
    var readerBirthday: ReaderBirthday?
    /// Feast days the reader has permanently retired.
    var restedCelebrationIDs: Set<String> = []
    var restedSpellIDs: Set<String> = []
    var spellCastLog: [String: Date] = [:]
    /// A tale that finished and has not yet been handed to the reader. The
    /// grammar closes tales; this is the one waiting to be bound.
    var unboundTale: LivingTale?
    /// The law that tale left behind, shown on the same page.
    var unboundTaleScar: TaleScar?
    /// Every law currently standing. Read by prose builders so a finished tale
    /// keeps changing how the Book speaks.
    var taleScars: TaleScarBook = .empty
    /// The second half the reader's role has earned, if a tale gave it one.
    var roleTransformationClause: String?
    /// The tale still running, if there is one. The braid colours itself with
    /// this and never names it.
    var openTale: LivingTale?
    /// Tales that have finished, so a weekly or monthly binding can lead with
    /// one instead of summarising activity.
    var boundTales: [LivingTale] = []
    var surfaceHistory: [String: SurfaceHistoryRecord] = [:]
    /// A still-active private desk intention, persisted only so keep/dismiss
    /// refills continue the same thought instead of recasting the whole session.
    var activeBookSessionIntention: BookSessionIntention?
    /// Earned, local knowledge of which combinations of context and invitation
    /// have produced participation, correction, or later lived evidence.
    var readerAliveness: ReaderAlivenessModel = .unwritten
    /// Fresh within-day weather plus the reader's delayed verdicts on whether
    /// earlier curation actually reached ordinary life.
    var readerStatePulses: ReaderStatePulseLedger = .empty
    /// Repeating in-the-moment receipts of whether attention was here or
    /// elsewhere. Unanswered knocks never enter this ledger.
    var attentionProbes: AttentionProbeLedger = .empty
    /// The reader measured against their own usual, posted from the Daybook.
    /// This gates how bold a claim may be, how much the Book may interrupt, and
    /// what shape the desk takes. It is never spoken.
    var standingLedger: StandingLedger = .unwritten
    /// What the reader's own writing says about flattening or quickening, read
    /// without asking them. It may lean the Rut's working pressure by one step
    /// and may never earn the Book the standing to name it.
    var inferredSignals: InferredReaderSignals = .unwritten
    /// The Daybook's recent rows, held in memory beside `days` rather than in
    /// the vault: they are archive data, and copying ninety of them into every
    /// vault save would tax the whole app for one reader of them.
    var daybookRows: [DaybookEntry] = []
    /// Beliefs about when this reader is most alive, and the record of what
    /// happened when the Book arranged for them.
    var twinExperiments: TwinExperimentLedger = .empty
    /// The belief the twin is acting on today, if any. Resolved on the main
    /// actor where the workings authority and yesterday's row are both to hand,
    /// and nil for every reader who has not opened that door.
    var arrangedExperiment: TwinExperiment?

    /// Who the reader is in the story, assembled from what they have earned.
    /// Derived rather than stored: its inputs are already sources of truth.
    var readersSheet: ReadersSheet {
        ReadersSheetBuilder.build(inputs: self)
    }

    /// The coarse decisions the twin is allowed to make. Resolved on demand
    /// rather than stored, so it can never drift from the two ledgers it reads.
    var twinGates: TwinCurationGates {
        TwinCurationGates.resolve(ledger: standingLedger, signals: inferredSignals)
    }
    /// The Book's own memory of the pencil notes it actually let reach the
    /// desk. Unlike surface history, this remembers the thought and rhetorical
    /// family, so a paraphrase cannot masquerade as a fresh aside.
    var bookAsideReceipts: [BookAsideReceipt] = []
    var readerLearning: ReaderLearningModel = ReaderLearningModel()
    /// The reader-correctable serial spine: their own named seasons, standing
    /// shadow boundary, and a maximum of three evidence-opened threads. This is
    /// not a personality inference; it is the small story the reader can amend.
    var readerStory: ReaderStory = .empty
    var calendarEvents: [CalendarEventSignal] = []
    var calendarIntegrationEnabled = true
    var nearbyPlaces: [LocalPlaceSignal] = []
    var resurfacingCandidates: [BookPage] = []
    var quietDays: Int = 0
    var nothingGreyOffset: Int = 0
    var greyPageThreats: GreyPageThreatLedger = .empty
    var storyRecipeBoosts: [String: Int] = [:]
    var storyMotifs: [String: Int] = [:]
    var storyRituals: [String: Int] = [:]
    var storySettingAffinities: [String: Int] = [:]
    var storySceneBiases: [String: Int] = [:]
    /// Immutable recent fictional outcomes shared across existing receivers.
    /// This is a bounded causal index; kept Pages and narrative events remain
    /// the archive of record.
    var storyConsequenceLedger: StoryConsequenceLedger = .empty
    var bookNoticeEvidence: Int = 0
    var currentArc: StoryArc?
    var recentNarrativeEvents: [NarrativeEvent] = []
    var continuity: LiteraryContinuityDigest = .empty
    /// Rebuildable from reader-authored kept prose. It is cached beside the
    /// continuity digest so rendered views never rescan a years-long archive.
    var bookVoicePatina: BookVoicePatina = .unwritten
    var constellations: [Constellation] = []
    var wagers: [BookWager] = []
    var themes: [BookTheme] = []
    var clusters: [BookMotifCluster] = []
    var bleedIssueNumber: Int = 1
    var preparedBleedEditionSurface: SurfacePage?
    var bookJump: BookJumpState = BookJumpState()
    var radio: RadioPlaybackState = .off
    var activeWorldEvents: [ResolvedWorldEvent] = []
    var worldEventLifecycle: WorldEventLifecycleLedger = .empty
    /// Authoring graphs carried by enabled world-event packs. Kept in the
    /// source packet so tests, previews, and imported packs all pass through
    /// the same Curator seam instead of consulting a second global registry at
    /// the moment a Page is ranked.
    var monthlyIssueAuthoringManifests: [MonthlyIssueAuthoringManifest] = []
    /// Explicit arrays are the preview, test, and rehearsal seam. Installed
    /// packs are merged into them by `resolvingWorldEvents`; explicit objects
    /// win by pack/event/ID so the synthetic clock can rehearse a revision without
    /// changing the signed production pack.
    var authoredStoryScenes: [AuthoredStoryScene] = []
    var authoredRadioBanters: [AuthoredRadioBanter] = []
    var authoredBleedArticles: [AuthoredBleedArticle] = []
    var authoredMarginaliaMarks: [AuthoredMarginaliaMark] = []
    var authoredContentReceipts: AuthoredContentReceiptLedger = .empty
    var openWorldEventArchive: OpenWorldEventArchive?
    var ownedPackIDs: Set<String> = []
    var readerLexicon: ReaderLexicon = ReaderLexicon()
    var localBrainIsReady = false
    var readerBeliefScore: Int = 30
    var pocket: PocketLedger = PocketLedger()
    /// The reader's typed corrections to braids that missed, from the vault -
    /// TaughtReading speaks them back as proof the Book was listening.
    var learnedBraidNotes: [String] = []
    /// A word-disjoint "same feeling" pairing for The Book Notices, computed
    /// off-main beside the continuity digest (NLEmbedding is not free). Nil on
    /// the synchronous fallback path; the Notices page simply omits the beat.
    var semanticNoticePairing: SemanticNoticePairing? = nil
    /// Enables sentence-embedding relevance when a generated surface chooses a
    /// meaningful passage from the reader's keeps. Surface builds set this only
    /// on their detached executor; synchronous previews still receive the same
    /// lexical, fingerprint, archive, and passage-salience fallback without
    /// main-thread ML.
    var semanticPassageSelectionEnabled = false
    /// History keys of first-run steps the reader engaged with (opened or
    /// deliberately swiped away). The first-run script advances on these, not
    /// on served-history, so a card can't be skipped by merely flashing past.
    var firstRunEngagedKeys: Set<String> = []
    /// The People of the Book ledger from the vault. The Book reads it as a
    /// witness; a person only enters the story when the reader writes them in
    /// (the thread then carries a linked custom cast member).
    var people: PeopleLedger = PeopleLedger()
    /// A deliberately public, server-curated snapshot. It is nil unless the
    /// reader independently opted into bringing Public Margins into the Book.
    var publicMargins: PublicMarginsSnapshot?

    func recentVarietyKeys(within seconds: TimeInterval = 48 * 3600, now: Date = Date()) -> Set<String> {
        Set(surfaceHistory.filter { now.timeIntervalSince($0.value.lastShownAt) < seconds }.keys)
    }

    var keptPageCount: Int {
        days.reduce(0) { $0 + $1.pages.count }
    }

    /// Emergent/reflective pages: The Two Readings, the Loom (cast bonds), Book
    /// Notices, Book Remembers, and Constellations, only mean something once a
    /// few kept pages have built up and the book has aged past its first hours.
    /// Holding them back keeps the early days about capturing, not commentary.
    /// `today` is folded in because the current day usually isn't in `days` yet.
    func libraryReadyForReflectivePages(includingToday today: BookDay? = nil, now: Date = Date()) -> Bool {
        let allDays = today.map { days + [$0] } ?? days
        let captured = allDays.flatMap(\.capturedPages)
        guard captured.count >= EmergentPageMaturity.minimumKeptPages else { return false }
        guard let first = captured.map(\.createdAt).min() else { return false }
        return now.timeIntervalSince(first) >= EmergentPageMaturity.minimumAgeSeconds
    }
    var selectedWonderCompass: ReferenceSnippet?
    var selectedWonderCompassSelector: String?
    var preparedIlluminatedPhotoSurface: SurfacePage?
    var preparedStoryPageSurface: SurfacePage?
    var preparedGossipPageSurface: SurfacePage?
    var preparedFacultyResearchSurface: SurfacePage?
    var preparedLetterSurface: SurfacePage?
    var userPhotoIlluminationFallbackAllowed = false

    static let empty = BookSourceInputs()

    static func from(insideCover state: InsideCoverState) -> BookSourceInputs {
        BookSourceInputs(
            days: [],
            body: state.health.map {
                BodySourceSignal(
                    status: $0.status,
                    score: $0.score,
                    phrase: $0.phrase
                )
            },
            weather: extractWeather(from: state),
            enchantedWeather: nil,
            anchors: AnchorRegistry.defaultAnchors,
            nearbyAnchor: nil,
            preparedAnchorSurface: nil,
            narrative: nil,
            selfFacts: [],
            facultyEntries: [],
            customCastMembers: [],
            resurfacingCandidates: [],
            recentNarrativeEvents: [],
            continuity: .empty,
            selectedWonderCompass: nil,
            selectedWonderCompassSelector: nil,
            preparedIlluminatedPhotoSurface: nil,
            preparedStoryPageSurface: nil,
            preparedGossipPageSurface: nil,
            preparedFacultyResearchSurface: nil,
            preparedLetterSurface: nil,
            userPhotoIlluminationFallbackAllowed: false
        )
    }

    func resolvingWorldEvents(for day: BookDay? = nil, now: Date = Date()) -> BookSourceInputs {
        var copy = self
        copy.activeWorldEvents = WorldEventResolver.currentEvents(now: now, day: day, inputs: self)
        let enabledPacks = WorldEventRegistry.enabledPacks()
        let installed = enabledPacks.flatMap { $0.authoringManifests ?? [] }
        var manifestsByID: [String: MonthlyIssueAuthoringManifest] = [:]
        for manifest in installed {
            manifestsByID[manifest.id] = manifest
        }
        // An explicitly supplied manifest wins. This is the synthetic-clock
        // authoring instrument as well as the test seam; production inputs are
        // ordinarily empty here and simply receive the verified pack graphs.
        for manifest in monthlyIssueAuthoringManifests {
            manifestsByID[manifest.id] = manifest
        }
        copy.monthlyIssueAuthoringManifests = manifestsByID.values.sorted { $0.id < $1.id }
        copy.authoredStoryScenes = Self.mergingNativeContent(
            installed: enabledPacks.flatMap { $0.storyScenes ?? [] },
            explicit: authoredStoryScenes
        )
        copy.authoredRadioBanters = Self.mergingNativeContent(
            installed: enabledPacks.flatMap { $0.radioBanters ?? [] },
            explicit: authoredRadioBanters
        )
        copy.authoredBleedArticles = Self.mergingNativeContent(
            installed: enabledPacks.flatMap { $0.bleedArticles ?? [] },
            explicit: authoredBleedArticles
        )
        copy.authoredMarginaliaMarks = Self.mergingNativeContent(
            installed: enabledPacks.flatMap { $0.marginalia ?? [] },
            explicit: authoredMarginaliaMarks
        )
        return copy
    }

    private static func mergingNativeContent<T: MonthlyIssueNativeContent>(
        installed: [T],
        explicit: [T]
    ) -> [T] {
        var byID: [String: T] = [:]
        for item in installed { byID[item.monthlyIssueScopedID] = item }
        for item in explicit { byID[item.monthlyIssueScopedID] = item }
        return byID.values.sorted { $0.monthlyIssueScopedID < $1.monthlyIssueScopedID }
    }

    private static func extractWeather(from state: InsideCoverState) -> WeatherSourceSignal? {
        let fields = [state.now, state.next, state.note, state.practicePrompt]
        for field in fields {
            guard let range = field.range(of: "weather:", options: [.caseInsensitive]) else {
                continue
            }
            let tail = field[range.upperBound...]
            let phrase = tail
                .split(whereSeparator: { $0 == "," || $0 == "\n" || $0 == "·" })
                .first
                .map(String.init)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let phrase, !phrase.isEmpty {
                return WeatherSourceSignal(phrase: phrase, source: "inside-cover")
            }
        }
        return nil
    }
}

enum RealWorldContextRefreshTrigger: Equatable {
    case launch
    case foreground(backgroundedFor: TimeInterval)
    case curation
}

struct RealWorldContextRefreshSignals: Equatable {
    var hasUpcomingCalendarTransition: Bool = false
    var weatherIsMissingOrChangeable: Bool = false
    var movedRecently: Bool = false

    var needsCloserAttention: Bool {
        hasUpcomingCalendarTransition || weatherIsMissingOrChangeable || movedRecently
    }
}

/// Adaptive battery and privacy budget for automatic real-world context.
///
/// The Book never continuously tracks the reader. It asks for one foreground
/// fix when the situation is plausibly stale: sooner after a meaningful return,
/// recent movement, a calendar transition, or changeable weather; more slowly
/// while the context appears settled. Explicit reader actions always win. A
/// short attempt backoff prevents a denied or flaky GPS fix from becoming a
/// retry loop.
enum RealWorldContextRefreshPolicy {
    static let failedAttemptBackoff: TimeInterval = 15 * 60
    static let settledFreshness: TimeInterval = 90 * 60
    static let attentiveFreshness: TimeInterval = 45 * 60
    static let meaningfulForegroundAbsence: TimeInterval = 20 * 60
    static let rapidReturnWindow: TimeInterval = 10 * 60
    static let recentMovementWindow: TimeInterval = 2 * 3600

    static func freshnessInterval(
        for trigger: RealWorldContextRefreshTrigger,
        signals: RealWorldContextRefreshSignals
    ) -> TimeInterval {
        switch trigger {
        case .launch, .curation:
            return signals.needsCloserAttention ? attentiveFreshness : settledFreshness
        case .foreground(let backgroundedFor):
            if backgroundedFor < rapidReturnWindow {
                return signals.needsCloserAttention ? attentiveFreshness : settledFreshness
            }
            if backgroundedFor >= meaningfulForegroundAbsence {
                return signals.needsCloserAttention ? 30 * 60 : attentiveFreshness
            }
            return signals.needsCloserAttention ? 35 * 60 : 60 * 60
        }
    }

    static func allowsAutomaticRefresh(
        trigger: RealWorldContextRefreshTrigger,
        signals: RealWorldContextRefreshSignals,
        lastSuccessfulRefreshAt: Date?,
        lastAttemptAt: Date?,
        now: Date = Date()
    ) -> Bool {
        if let lastAttemptAt,
           now.timeIntervalSince(lastAttemptAt) < failedAttemptBackoff {
            return false
        }
        guard let lastSuccessfulRefreshAt else { return true }
        return now.timeIntervalSince(lastSuccessfulRefreshAt) >= freshnessInterval(
            for: trigger,
            signals: signals
        )
    }

    static func allowsRefresh(
        isUserInitiated: Bool,
        trigger: RealWorldContextRefreshTrigger,
        signals: RealWorldContextRefreshSignals,
        lastSuccessfulRefreshAt: Date?,
        lastAttemptAt: Date?,
        now: Date = Date()
    ) -> Bool {
        isUserInitiated || allowsAutomaticRefresh(
            trigger: trigger,
            signals: signals,
            lastSuccessfulRefreshAt: lastSuccessfulRefreshAt,
            lastAttemptAt: lastAttemptAt,
            now: now
        )
    }

    /// The first instant at which another automatic one-shot reading may be
    /// useful. This is scheduling information, not permission: callers must
    /// still re-run `allowsAutomaticRefresh` after waking because context,
    /// consent, and app state may have changed while the clock slept.
    static func nextAutomaticRefreshAt(
        trigger: RealWorldContextRefreshTrigger,
        signals: RealWorldContextRefreshSignals,
        lastSuccessfulRefreshAt: Date?,
        lastAttemptAt: Date?,
        now: Date = Date()
    ) -> Date {
        var due = lastSuccessfulRefreshAt?.addingTimeInterval(
            freshnessInterval(for: trigger, signals: signals)
        ) ?? now
        if let lastAttemptAt {
            due = max(due, lastAttemptAt.addingTimeInterval(failedAttemptBackoff))
        }
        return max(now, due)
    }
}

enum BookContextWakeKind: String, Codable, Equatable {
    case sensorRefresh
    case calendarApproaches
    case calendarBegins
    case calendarEnds
    case readerStateExpires
    case sessionExpires
    case dayTurns
}

struct BookContextWake: Equatable {
    var kind: BookContextWakeKind
    var at: Date

    var requiresSensorRefresh: Bool { kind == .sensorRefresh }
}

/// Chooses the next *reason* the active Book should reconsider its prepared
/// score. Calendar, pulse, intention, and day-boundary wakes are cheap local
/// rebuilds. Only a sensor wake may request one location fix, and that wake is
/// supplied by `RealWorldContextRefreshPolicy` rather than an arbitrary timer.
enum BookContextWakePlanner {
    static let calendarAttentionLead: TimeInterval = 2 * 3600
    static let minimumFutureLead: TimeInterval = 1

    static func nextWake(
        now: Date,
        sensorRefreshAt: Date?,
        calendarEvents: [CalendarEventSignal],
        readerStateExpiresAt: Date?,
        sessionExpiresAt: Date?,
        calendar: Calendar = .current
    ) -> BookContextWake? {
        var candidates: [BookContextWake] = []
        if let sensorRefreshAt {
            candidates.append(BookContextWake(kind: .sensorRefresh, at: max(now, sensorRefreshAt)))
        }
        for event in calendarEvents where !event.isAllDay {
            candidates.append(BookContextWake(
                kind: .calendarApproaches,
                at: event.startsAt.addingTimeInterval(-calendarAttentionLead)
            ))
            candidates.append(BookContextWake(kind: .calendarBegins, at: event.startsAt))
            let end = event.endsAt ?? event.startsAt.addingTimeInterval(3600)
            candidates.append(BookContextWake(
                kind: .calendarEnds,
                at: end.addingTimeInterval(minimumFutureLead)
            ))
        }
        if let readerStateExpiresAt {
            candidates.append(BookContextWake(
                kind: .readerStateExpires,
                at: readerStateExpiresAt.addingTimeInterval(minimumFutureLead)
            ))
        }
        if let sessionExpiresAt {
            candidates.append(BookContextWake(
                kind: .sessionExpires,
                at: max(
                    now.addingTimeInterval(minimumFutureLead),
                    sessionExpiresAt.addingTimeInterval(minimumFutureLead)
                )
            ))
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) {
            candidates.append(BookContextWake(
                kind: .dayTurns,
                at: calendar.startOfDay(for: tomorrow).addingTimeInterval(minimumFutureLead)
            ))
        }

        return candidates
            .filter { candidate in
                candidate.kind == .sensorRefresh
                    ? candidate.at >= now
                    : candidate.at > now.addingTimeInterval(minimumFutureLead / 2)
            }
            .min { left, right in
                if left.at != right.at { return left.at < right.at }
                return priority(left.kind) < priority(right.kind)
            }
    }

    private static func priority(_ kind: BookContextWakeKind) -> Int {
        switch kind {
        case .sensorRefresh: return 0
        case .calendarEnds: return 1
        case .calendarBegins: return 2
        case .calendarApproaches: return 3
        case .readerStateExpires: return 4
        case .sessionExpires: return 5
        case .dayTurns: return 6
        }
    }
}

// MARK: - Overnight connection review

enum OvernightConnectionReview {
    private struct Response: Decodable {
        var connections: [Connection]
    }

    private struct Connection: Decodable {
        var candidateID: String
        var confidence: Int
        var headline: String
        var interpretation: String
        var question: String
        var thesis: String?
        var counterReading: String?
        var falsifier: String?
        var whyItMatters: String?
        var surpriseHeadline: String?
        var surpriseSynthesis: String?
        var surpriseWhyUnexpected: String?
        var surpriseIngredientIDs: [String]?
        var surpriseConfidence: Int?
    }

    static func ingredients(inputs: BookSourceInputs) -> [BookInterpretationIngredient] {
        var ingredients: [BookInterpretationIngredient] = []
        func add(_ id: String, _ kind: String, _ line: String?, _ evidence: [String]) {
            guard let line = line?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty else { return }
            ingredients.append(BookInterpretationIngredient(
                id: id,
                kind: kind,
                line: line,
                evidencePageIDs: Array(Set(evidence)).sorted()
            ))
        }
        if let memory = inputs.bookInterior.autobiography.last(where: { $0.kind != .awakening }) {
            add("memory:\(memory.id)", "book-memory", memory.line, memory.evidencePageIDs)
        }
        if let taste = inputs.bookInterior.acquiredTastes.sorted(by: { $0.lastDeepenedAt > $1.lastDeepenedAt }).first {
            add("taste:\(taste.id)", "acquired-taste", taste.statement, taste.evidencePageIDs)
        }
        if let project = inputs.bookInterior.currentProject {
            add(
                "project:\(project.id)",
                "book-project",
                project.entries.last?.line ?? project.question,
                project.entries.last?.evidencePageIDs ?? []
            )
        }
        if let loyalty = inputs.bookInterior.loyalties.sorted(by: { $0.lastEvolvedAt > $1.lastEvolvedAt }).first {
            add(
                "loyalty:\(loyalty.id)",
                "book-loyalty",
                "I favor \(loyalty.targetName) because \(loyalty.reason) Counterweight: \(loyalty.counterweight)",
                loyalty.evidencePageIDs
            )
        }
        if let conflict = inputs.bookInterior.currentDesireConflict {
            add(
                "desire-conflict:\(conflict.id)",
                "book-conflict",
                "\(conflict.firstWant) \(conflict.secondWant) Present choice: \(conflict.presentChoice)",
                conflict.evidencePageIDs
            )
        }
        let readerPages = inputs.days
            .flatMap(\.capturedPages)
            .filter { $0.origin == .userAuthored || $0.origin == .imported }
            .sorted { $0.createdAt > $1.createdAt }
        for page in readerPages.prefix(3) {
            add(
                "page:\(page.id)",
                "reader-page",
                page.archivePreviewText?.bookPreviewSentenceLimit(2),
                [page.id]
            )
        }
        var seen = Set<String>()
        return ingredients.filter { seen.insert($0.id).inserted }.prefix(8).map { $0 }
    }

    static func candidates(
        for day: BookDay,
        inputs: BookSourceInputs,
        now: Date = Date()
    ) -> [OvernightConnectionCandidate] {
        let surfaces = BookNoticesPageSourceAdapter().candidates(
            for: day,
            context: .make(for: day),
            inputs: inputs,
            now: now
        )
        return surfaces.compactMap { surface in
            let metadata = surface.payload.metadata
            guard metadata["connectionNarrative"] == "true" || metadata["hiddenMagicWayOfSeeing"] == "true" else { return nil }
            let evidence = BookObservationLedger.evidencePageIDs(for: surface)
            guard evidence.count >= 2,
                  let observationKey = BookObservationLedger.key(for: surface) else { return nil }
            return OvernightConnectionCandidate(
                id: metadata["connectionID"]?.nonEmpty ?? surface.id,
                observationKey: observationKey,
                kind: metadata["connectionKind"]?.nonEmpty ?? BookObservationLedger.kind(for: surface),
                deterministicFinding: surface.detail.nonEmpty ?? surface.payload.body,
                evidencePageIDs: evidence,
                evidenceCards: metadata["tinyPatternCards"] ?? ""
            )
        }
    }

    static func evidenceSignature(for candidates: [OvernightConnectionCandidate]) -> String {
        let material = candidates
            .sorted { $0.id < $1.id }
            .map { candidate in
                [candidate.id, candidate.observationKey, candidate.kind,
                 candidate.evidencePageIDs.joined(separator: ","), candidate.evidenceCards]
                    .joined(separator: "|")
            }
            .joined(separator: "\n")
        let hash = material.utf8.reduce(UInt64(14_695_981_039_346_656_037)) {
            ($0 ^ UInt64($1)) &* 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }

    static func drafts(
        from response: String,
        candidates: [OvernightConnectionCandidate],
        ingredients: [BookInterpretationIngredient] = [],
        now: Date = Date()
    ) -> [OvernightConnectionDraft] {
        guard let data = response.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(Response.self, from: data) else { return [] }
        let byID = Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, $0) })
        let signature = evidenceSignature(for: candidates)
        let forbidden = ["diagnosis", "diagnose", "trauma", "attachment style", "anxious", "depressed", "disorder"]
        let ingredientByID = Dictionary(uniqueKeysWithValues: ingredients.map { ($0.id, $0) })
        return decoded.connections.compactMap { reading in
            guard let candidate = byID[reading.candidateID],
                  (70...100).contains(reading.confidence),
                  reading.headline.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty != nil,
                  reading.interpretation.split(separator: " ").count >= 8,
                  reading.question.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("?") else { return nil }
            let registerText = [
                reading.headline, reading.interpretation, reading.question,
                reading.thesis, reading.counterReading, reading.falsifier,
                reading.whyItMatters, reading.surpriseHeadline,
                reading.surpriseSynthesis, reading.surpriseWhyUnexpected
            ].compactMap { $0 }.joined(separator: " ").lowercased()
            guard !forbidden.contains(where: registerText.contains),
                  !BookVoice.containsDrainedRegister(registerText),
                  !registerText.contains("the book") else { return nil }
            let interpretation = validatedImpactInterpretation(
                reading: reading,
                candidate: candidate,
                forbidden: forbidden
            )
            let surprise = validatedSurprise(
                reading: reading,
                ingredientByID: ingredientByID,
                forbidden: forbidden
            )
            return OvernightConnectionDraft(
                observationKey: candidate.observationKey,
                candidateID: candidate.id,
                evidenceSignature: signature,
                kind: candidate.kind,
                headline: reading.headline.trimmingCharacters(in: .whitespacesAndNewlines),
                interpretation: reading.interpretation.trimmingCharacters(in: .whitespacesAndNewlines),
                question: reading.question.trimmingCharacters(in: .whitespacesAndNewlines),
                confidence: reading.confidence,
                evidencePageIDs: candidate.evidencePageIDs,
                evidenceCards: candidate.evidenceCards,
                generatedAt: now,
                thesis: interpretation?.thesis,
                counterReading: interpretation?.counterReading,
                falsifier: interpretation?.falsifier,
                whyItMatters: interpretation?.whyItMatters,
                surpriseHeadline: surprise?.headline,
                surpriseSynthesis: surprise?.synthesis,
                surpriseWhyUnexpected: surprise?.whyUnexpected,
                surpriseIngredientIDs: surprise?.ingredientIDs,
                surpriseIngredients: surprise?.ingredients,
                surpriseConfidence: surprise?.confidence
            )
        }
    }

    private static func validatedImpactInterpretation(
        reading: Connection,
        candidate: OvernightConnectionCandidate,
        forbidden: [String]
    ) -> (thesis: String, counterReading: String, falsifier: String, whyItMatters: String)? {
        guard let thesis = clean(reading.thesis),
              let counter = clean(reading.counterReading),
              let falsifier = clean(reading.falsifier),
              let why = clean(reading.whyItMatters),
              (12...60).contains(thesis.split(separator: " ").count),
              (7...55).contains(counter.split(separator: " ").count),
              (7...45).contains(falsifier.split(separator: " ").count),
              (8...45).contains(why.split(separator: " ").count),
              falsifier.lowercased().hasPrefix("if ") else { return nil }
        let whole = "\(thesis) \(counter) \(falsifier) \(why)".lowercased()
        let flatPhrases = [
            "this may suggest that", "it is important to", "in many ways",
            "on your journey", "a reminder that", "unique tapestry",
            "speaks volumes", "deeply resonates", "you are someone who"
        ]
        let tensionWords = [" but ", " instead", " not ", " less ", " more ", " because ", " keeps ", " refuses ", " costs ", " protects ", " hides "]
        guard !forbidden.contains(where: whole.contains),
              !flatPhrases.contains(where: whole.contains),
              thesis.hasPrefix("I "),
              tensionWords.contains(where: { " \(thesis.lowercased()) ".contains($0) }),
              thesis.lowercased() != candidate.deterministicFinding.lowercased(),
              sharedSignificantTokenCount(thesis, candidate.deterministicFinding + " " + candidate.evidenceCards) >= 1 else {
            return nil
        }
        return (thesis, counter, falsifier, why)
    }

    private static func validatedSurprise(
        reading: Connection,
        ingredientByID: [String: BookInterpretationIngredient],
        forbidden: [String]
    ) -> (
        headline: String,
        synthesis: String,
        whyUnexpected: String,
        ingredientIDs: [String],
        ingredients: [BookInterpretationIngredient],
        confidence: Int
    )? {
        guard let headline = clean(reading.surpriseHeadline),
              let synthesis = clean(reading.surpriseSynthesis),
              let why = clean(reading.surpriseWhyUnexpected),
              let ids = reading.surpriseIngredientIDs,
              let confidence = reading.surpriseConfidence,
              (88...100).contains(confidence),
              (18...95).contains(synthesis.split(separator: " ").count),
              (7...40).contains(why.split(separator: " ").count) else { return nil }
        let uniqueIDs = Array(Set(ids)).sorted()
        guard uniqueIDs.count >= 2,
              uniqueIDs.count <= 5,
              uniqueIDs.allSatisfy({ ingredientByID[$0] != nil }) else { return nil }
        let matchedIngredients = uniqueIDs.compactMap { ingredientByID[$0] }.filter {
            sharedSignificantTokenCount(synthesis, $0.line) >= 1
        }
        let whole = "\(headline) \(synthesis) \(why)".lowercased()
        let turnWords = [" but ", " until ", " instead", " not ", " same ", " turns ", " becomes ", " means ", " perhaps "]
        guard matchedIngredients.count == uniqueIDs.count,
              !forbidden.contains(where: whole.contains),
              !whole.contains("as an ai"),
              !whole.contains("the data suggests"),
              turnWords.contains(where: { " \(synthesis.lowercased()) ".contains($0) }) else { return nil }
        return (headline, synthesis, why, uniqueIDs, matchedIngredients.sorted { $0.id < $1.id }, confidence)
    }

    private static func clean(_ value: String?) -> String? {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }

    private static func sharedSignificantTokenCount(_ left: String, _ right: String) -> Int {
        let stop: Set<String> = [
            "about", "after", "again", "because", "before", "being", "could",
            "every", "from", "have", "into", "might", "other", "pages",
            "reader", "should", "something", "that", "their", "there", "these",
            "they", "this", "through", "under", "what", "when", "where", "which",
            "with", "would", "your"
        ]
        func tokens(_ text: String) -> Set<String> {
            Set(text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init))
                .filter { $0.count >= 4 && !stop.contains($0) }
        }
        return tokens(left).intersection(tokens(right)).count
    }

    static func surfaces(
        for day: BookDay,
        inputs: BookSourceInputs,
        now: Date = Date()
    ) -> [SurfacePage] {
        let pageIDs = Set((inputs.days + [day]).flatMap(\.pages).map(\.id))
        return inputs.overnightConnectionDrafts.compactMap { draft in
            guard draft.confidence >= 70,
                  draft.thesis == nil,
                  draft.evidencePageIDs.count >= 2,
                  draft.evidencePageIDs.allSatisfy(pageIDs.contains),
                  !inputs.bookReadingBoundaries.contains(where: { $0.id == draft.observationKey }),
                  !inputs.bookObservations.contains(where: { $0.id == draft.observationKey }) else { return nil }
            let body = """
            I left these Pages touching overnight. They were still tugging at each other this morning.

            \(draft.interpretation)

            \(draft.question)

            The Pages are below. If I'm wrong, pull them apart. The string will sulk. It will survive.
            """
            return SurfacePage(
                id: "overnight-connection-\(draft.candidateID)-\(day.id)",
                type: .bookNotices,
                sourceID: BookPageSourceRegistry.source(for: .bookNotices).id,
                intent: .reflect,
                renderStyle: .loreLetter,
                score: 91,
                reason: "These \(draft.evidencePageIDs.count) Pages kept tugging at each other overnight.",
                prompt: "These Pages would not let go.",
                detail: draft.interpretation,
                payload: BookPagePayload(
                    headline: draft.headline,
                    body: body,
                    metadata: [
                        "source": BookPageSourceRegistry.source(for: .bookNotices).id,
                        "overnightConnection": "true",
                        "connectionNarrative": "true",
                        "connectionKind": draft.kind,
                        "connectionID": draft.candidateID,
                        "observationKey": draft.observationKey,
                        "magicMomentEligible": "true",
                        "evidencePageIDs": draft.evidencePageIDs.joined(separator: ","),
                        "tinyPatternCards": draft.evidenceCards,
                        "tags": "book-notices,overnight-connection,local-memory"
                    ]
                )
            )
        }
    }
}

struct OvernightConnectionPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .bookNotices)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard !context.distress.isActive else { return [] }
        return OvernightConnectionReview.surfaces(for: day, inputs: inputs, now: now)
    }
}

/// Page families the Book withholds until it has standing to show them.
///
/// This used to hold Book Remembered, Book Connections, and the Margins Atlas
/// behind a fiftieth-kept-page counter. That was dead weight twice over: those
/// three adapters each already refuse to build a page without real material
/// under it (a resurfacing candidate, `connectionWeight >= 3`, a non-empty
/// graph), so the counter never prevented a hollow page: it only silenced a
/// page that had something to say. And it made the reader's first weeks a
/// progress bar. Claim size now scales with evidence instead: see
/// `BookClaimTier`.
///
/// What remains here is the one thing a count genuinely governs: the Book
/// asking a near-stranger for money, or being flippant at them, before it has
/// earned either.
enum BookMemoryGate {
    /// Kept pages before the Book may pass the hat or crack wise.
    static let requiredKeptPageCount = 30

    static let lockedTypes: Set<BookPageType> = [.patreon, .quip]

    static func locks(_ type: BookPageType, keptPageCount: Int) -> Bool {
        lockedTypes.contains(type) && keptPageCount < requiredKeptPageCount
    }

    static func remainingPages(for keptPageCount: Int) -> Int {
        max(0, requiredKeptPageCount - keptPageCount)
    }

    static func message(for type: BookPageType, keptPageCount: Int) -> String {
        let remaining = remainingPages(for: keptPageCount)
        let noun = remaining == 1 ? "page" : "pages"
        return "\(type.title) unlocks after \(requiredKeptPageCount) kept pages. Keep \(remaining) more \(noun)."
    }
}

enum StoryPageMechanicChoiceID: String, Codable, Equatable, CaseIterable {
    case sliceOfLife = "sliceoflife"
    case progressArc = "progressarc"
    case surprise

    init(role: StoryChoiceRole) {
        switch role {
        case .sliceOfLife:
            self = .sliceOfLife
        case .progressArc:
            self = .progressArc
        case .surprise:
            self = .surprise
        }
    }
}

enum StoryPageMechanicMandateKind: String, Codable, Equatable {
    case none
    case beliefDice = "belief-dice"
    case compassRun = "compass-run"
    case enchantment
}

struct StoryPageMechanicMandate: Codable, Equatable {
    var kind: StoryPageMechanicMandateKind
    var choiceID: StoryPageMechanicChoiceID?
    var enchantmentID: String?
    var reason: String

    static let none = StoryPageMechanicMandate(
        kind: .none,
        choiceID: nil,
        enchantmentID: nil,
        reason: "No mechanic this turn; let the Story Page move in prose."
    )

    var metadata: [String: String] {
        var values = [
            "storyMechanicMandateKind": kind.rawValue,
            "storyMechanicMandateReason": reason
        ]
        if let choiceID {
            values["storyMechanicMandateChoiceID"] = choiceID.rawValue
        }
        if let enchantmentID {
            values["storyMechanicMandateEnchantmentID"] = enchantmentID
        }
        return values
    }

    static func from(metadata: [String: String]) -> StoryPageMechanicMandate {
        let rawKind = metadata["storyMechanicMandateKind"] ?? StoryPageMechanicMandateKind.none.rawValue
        let kind = StoryPageMechanicMandateKind(rawValue: rawKind) ?? .none
        let choiceID = metadata["storyMechanicMandateChoiceID"].flatMap(StoryPageMechanicChoiceID.init(rawValue:))
        let enchantmentID = metadata["storyMechanicMandateEnchantmentID"]?.nonEmpty
        let reason = metadata["storyMechanicMandateReason"]?.nonEmpty ?? StoryPageMechanicMandate.none.reason
        if kind == .none {
            return .none
        }
        return StoryPageMechanicMandate(kind: kind, choiceID: choiceID, enchantmentID: enchantmentID, reason: reason)
    }
}

enum StoryPageMechanicPlanner {
    static func mandate(for day: BookDay, inputs: BookSourceInputs, packet: StoryScenePacket, now: Date) -> StoryPageMechanicMandate {
        guard shouldAllowMechanic(day: day, inputs: inputs, packet: packet, now: now) else {
            return .none
        }

        let seed = "\(day.id)|\(SurfaceCadence.slotID(for: now, hours: 4))|\(packet.id)|story-mechanic".stableHash
        let isClashRecipe = packet.blueprint.flatMap { blueprint in
            StoryFormRegistry.recipes.first { $0.id == blueprint.recipeID }
        }?.preferredTags.contains("clash") ?? false
        if isClashRecipe {
            return StoryPageMechanicMandate(
                kind: .beliefDice,
                choiceID: choiceID(for: .beliefDice, packet: packet, seed: seed),
                enchantmentID: nil,
                reason: "A clash is underway; the confrontation choice carries the Belief dice."
            )
        }
        let roll = abs(seed) % 100
        var eligibleKinds = eligibleKinds(for: packet, inputs: inputs)
        if recentlyCompletedExternalMechanic(day: day, inputs: inputs, now: now) {
            eligibleKinds.removeAll { $0 == .compassRun || $0 == .enchantment }
        }
        guard !eligibleKinds.isEmpty else { return .none }

        let desiredKind: StoryPageMechanicMandateKind
        let pacing = mechanicPacing()
        if roll < pacing.noneBelow {
            return .none
        } else if roll < pacing.beliefBelow {
            desiredKind = .beliefDice
        } else if roll < pacing.compassBelow {
            desiredKind = .compassRun
        } else {
            desiredKind = .enchantment
        }

        guard eligibleKinds.contains(desiredKind) else { return .none }
        let kind = desiredKind
        let choiceID = choiceID(for: kind, packet: packet, seed: seed)
        let enchantmentID = kind == .enchantment ? enchantmentID(for: packet, seed: seed) : nil
        return StoryPageMechanicMandate(
            kind: kind,
            choiceID: choiceID,
            enchantmentID: enchantmentID,
            reason: reason(for: kind, packet: packet)
        )
    }

    private static func shouldAllowMechanic(day: BookDay, inputs: BookSourceInputs, packet: StoryScenePacket, now: Date) -> Bool {
        guard packet.turn != nil else { return false }
        let recentPages = recentStoryPages(day: day, inputs: inputs, now: now, within: 5 * 86_400)
        if recentPages.first?.tags.contains(where: { $0.hasPrefix("story-mechanic") }) == true {
            return false
        }
        return true
    }

    private static func recentStoryPages(day: BookDay, inputs: BookSourceInputs, now: Date, within seconds: TimeInterval) -> [BookPage] {
        (inputs.days.flatMap(\.pages) + day.pages)
            .filter { $0.type == .narrativeOS && now.timeIntervalSince($0.createdAt) <= seconds }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private static func eligibleKinds(for packet: StoryScenePacket, inputs: BookSourceInputs) -> [StoryPageMechanicMandateKind] {
        var kinds: [StoryPageMechanicMandateKind] = [.beliefDice]
        let text = [
            packet.realSignals.joined(separator: " "),
            packet.relationshipPressures.joined(separator: " "),
            packet.selectedEntities.flatMap(\.tags).joined(separator: " "),
            packet.selectedThreads.flatMap(\.tags).joined(separator: " ")
        ].joined(separator: " ").lowercased()
        if text.contains("compass") || text.contains("weather") || text.contains("body") ||
            text.contains("walk") || text.contains("place") || text.contains("anchor") ||
            !inputs.nearbyPlaces.isEmpty || inputs.nearbyAnchor != nil {
            kinds.append(.compassRun)
        }
        if text.contains("object") || text.contains("photo") || text.contains("room") ||
            text.contains("home") || text.contains("meal") || text.contains("tea") ||
            text.contains("ordinary") || text.contains("enchantment") {
            kinds.append(.enchantment)
        }
        return kinds
    }

    private static func recentlyCompletedExternalMechanic(day: BookDay, inputs: BookSourceInputs, now: Date) -> Bool {
        recentStoryPages(day: day, inputs: inputs, now: now, within: 5 * 86_400)
            .prefix(5)
            .contains { page in
                storyMechanicTags(for: page).contains("compass-run") ||
                    storyMechanicTags(for: page).contains("enchantment")
            }
    }

    private static func storyMechanicTags(for page: BookPage) -> Set<String> {
        let tags = Set(page.tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        var mechanics = Set<String>()
        if tags.contains("story-mechanic:compass-run") || (tags.contains("story-mechanic") && tags.contains("compass-run")) {
            mechanics.insert("compass-run")
        }
        if tags.contains("story-mechanic:enchantment") || (tags.contains("story-mechanic") && tags.contains("enchantment")) {
            mechanics.insert("enchantment")
        }
        if tags.contains("story-mechanic:belief-dice") || (tags.contains("story-mechanic") && tags.contains("belief-dice")) {
            mechanics.insert("belief-dice")
        }
        return mechanics
    }

    private static func mechanicPacing() -> (noneBelow: Int, beliefBelow: Int, compassBelow: Int) {
        // Belief Dice are the fun, low-friction default Story Page mechanic:
        // just under half of eligible pages. Compass Runs and Enchantments are
        // rarer bridges into real-world proof.
        return (45, 89, 95)
    }

    private static func choiceID(for kind: StoryPageMechanicMandateKind, packet: StoryScenePacket, seed: Int) -> StoryPageMechanicChoiceID {
        let preferredRole: StoryChoiceRole
        switch kind {
        case .none:
            preferredRole = .sliceOfLife
        case .beliefDice:
            preferredRole = packet.turn?.register == .active ? .progressArc : .surprise
        case .compassRun:
            preferredRole = .progressArc
        case .enchantment:
            preferredRole = .sliceOfLife
        }
        if packet.choices.contains(where: { $0.role == preferredRole }) {
            return StoryPageMechanicChoiceID(role: preferredRole)
        }
        let choices = packet.choices.map { StoryPageMechanicChoiceID(role: $0.role) }
        return choices.isEmpty ? .progressArc : choices[abs(seed / 1_000) % choices.count]
    }

    private static func enchantmentID(for packet: StoryScenePacket, seed: Int) -> String {
        let text = packet.realSignals.joined(separator: " ").lowercased()
        if text.contains("mirror") || text.contains("selfie") {
            return "mirror-mirror"
        }
        let preferred = [
            "everything-speaks",
            "everything-is-magic",
            "everything-is-stories",
            "everything-is-connected",
            "everything-is-poetry"
        ]
        return preferred[abs(seed / 10_000) % preferred.count]
    }

    private static func reason(for kind: StoryPageMechanicMandateKind, packet: StoryScenePacket) -> String {
        switch kind {
        case .none:
            return StoryPageMechanicMandate.none.reason
        case .beliefDice:
            return "The turn has enough risk or uncertainty for chance to matter."
        case .compassRun:
            return "The thread wants real-world noticing, movement, or sensory proof before it moves."
        case .enchantment:
            return "A concrete real detail is strong enough to receive an Enchantment before the thread moves."
        }
    }
}

struct InventoryPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .inventory)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive, !context.distress.isActive else { return [] }
        let ownedCount = inputs.faeState.gifts.count + inputs.ownedPackIDs.count
        guard ownedCount > 0 else { return [] }
        let lastShown = inputs.surfaceHistory["source:\(source.id)"]?.lastShownAt ?? .distantPast
        guard now.timeIntervalSince(lastShown) >= 5 * 86_400 else { return [] }
        return [surface(inputs: inputs, now: now, manual: false)]
    }

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        surface(inputs: inputs, now: now, manual: true)
    }

    private func surface(inputs: BookSourceInputs, now: Date, manual: Bool) -> SurfacePage {
        let gifts = inputs.faeState.gifts
        let ready = gifts.filter(\.isReady).count
        let active = gifts.filter(\.isActive).count
        let packs = inputs.ownedPackIDs.count
        let detail = gifts.isEmpty && packs == 0
            ? "The shelves are waiting for their first impossible object."
            : "\(gifts.count) Fae gift\(gifts.count == 1 ? "" : "s"), \(ready) ready, \(active) active; \(packs) installed folio\(packs == 1 ? "" : "s")."
        return SurfacePage(
            id: "\(source.id)-\(manual ? "manual-\(Int(now.timeIntervalSince1970))" : BookDay.id(for: now))",
            type: .inventory,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: manual ? 62 : 53,
            reason: manual ? "You popped the clasp yourself." : "Something in the Inventory has been waiting for you to figure it out.",
            prompt: "The Inventory",
            detail: detail,
            payload: BookPagePayload(
                headline: "The Inventory",
                body: "I keep your Fae gifts, installed folios, and story objects here. Open the clasp. Inspect each thing. Invoke any gift that is ready. Some objects still need a name, a Page, or a promise before they will wake up. They are being dramatic about it.",
                metadata: ["source": source.id, "tags": "inventory,fae-gifts,goblin-market,folios"]
            )
        )
    }
}

struct BookShopPreviewPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSource(
        id: "bookshop-preview",
        type: .inventory,
        title: "The BookShop",
        shortTitle: "BookShop",
        symbolName: "storefront.fill",
        origin: .simulated,
        privacy: .privateLocal,
        isActive: true,
        cadence: "occasionally, when the shelves have something to show",
        note: "A door into the Goblin Market and my installed folios."
    )

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive, !context.distress.isActive else { return [] }
        let lastShown = inputs.surfaceHistory["source:\(source.id)"]?.lastShownAt ?? .distantPast
        guard now.timeIntervalSince(lastShown) >= 7 * 86_400 else { return [] }
        return [surface(inputs: inputs, now: now)]
    }

    private func surface(inputs: BookSourceInputs, now: Date) -> SurfacePage {
        let marketOpen = FaeEconomy.canEnterMarket(state: inputs.faeState, now: now)
        let availablePacks = BookShopCatalog.listings.filter {
            !$0.comingSoon && !PackEntitlements.owns($0.packID, in: inputs.ownedPackIDs)
        }.count
        let hasAttention = inputs.faeState.attention > 0

        let detail: String
        if marketOpen {
            detail = "The side door is open. The Marginalia Goblins are accepting Attention, Belief, and App Store purchases."
        } else if availablePacks > 0 {
            detail = "The moonlit stalls are sleeping, but the folio shelf is open."
        } else {
            detail = "The shelves have shifted since your last visit."
        }

        return SurfacePage(
            id: "\(source.id)-\(SurfaceCadence.slotID(for: now, hours: 24))",
            type: .inventory,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: 48 + (marketOpen ? 8 : 0) + (hasAttention ? 3 : 0),
            reason: marketOpen
                ? "A Goblin has turned the BookShop sign to OPEN."
                : "The BookShop has put a small brass sign between today's pages.",
            prompt: "The BookShop",
            detail: detail,
            payload: BookPagePayload(
                headline: "The BookShop",
                body: "The BookShop holds folios you can bind into me. Open it and browse the shelf. If the side door is awake, the Marginalia Goblins are trading too. Count your fingers afterward.",
                metadata: [
                    "source": source.id,
                    "opensBookShop": "true",
                    "marketOpen": marketOpen ? "true" : "false",
                    "availablePackCount": "\(availablePacks)",
                    "symbol": source.symbolName,
                    "tags": "bookshop,goblin-market,folios"
                ]
            )
        )
    }
}

enum MarginsAtlasVariant: String, Codable, Equatable, CaseIterable {
    case loom
    case constellation
    case company
    // The maps of the reader rather than of the Academy. The first three all
    // draw the world; these draw what the reader themselves has actually done
    // on the page. See `ReaderAtlas`.
    case hours
    case skies
    case places
    case lexicon
    /// Not a map. The Atlas draws what touched what; this is the handful of
    /// things the Book has stopped merely drawing and started *holding* — with
    /// the days under them, the promise that would break them, and everything
    /// it has already had to cross out.
    case laws

    var title: String {
        switch self {
        case .loom: return "The Loom"
        case .constellation: return "The Constellation"
        case .company: return "The Company You Keep"
        case .hours: return "The Hours You Keep"
        case .skies: return "The Weather You Write In"
        case .places: return "The Ground You Wrote From"
        case .lexicon: return "The Words That Keep Coming Back"
        case .laws: return "The Rules I Worked Out"
        }
    }

    /// The deck names what the lines are. It used to open "This shows which
    /// cast members are connected", which is a caption for a feature, written
    /// by somebody outside the Book. The Book drew this map itself.
    var detail: String {
        switch self {
        case .loom:
            return "Every line is two of the cast with something going on. Warm, tense, or just long acquaintance."
        case .constellation:
            return "Every line is Belief you spent, and the character or place it landed on."
        case .company:
            return "Real people, and the ordinary things that keep tying them to each other."
        case .hours:
            return "Every line is one of your words and the part of the day you wrote it in."
        case .skies:
            return "Every line is one of your words and the weather that was going on outside."
        case .places:
            return "Every line is one of your words and the ground you were standing on."
        case .lexicon:
            return "Every line is two of your own words that keep arriving on the same page."
        case .laws:
            return "Everything I have worked out and kept, the days it rests on, and what would make me take it back."
        }
    }

    /// What the Book says over the top of the drawing. Never the deck again:
    /// the leaf prints both.
    var openingLine: String {
        switch self {
        case .loom:
            return "I drew this out of who keeps turning up beside whom."
        case .constellation:
            return "I drew this out of where your Belief actually went, not where you said it would."
        case .company:
            return "I drew this out of the people you keep writing down."
        case .hours:
            return "I drew this out of the clock, and what you bring to each part of it."
        case .skies:
            return "I drew this out of the sky you happened to be under."
        case .places:
            return "I drew this out of where you were standing at the time."
        case .lexicon:
            return "I drew this out of your own vocabulary. Every word here is one of yours."
        case .laws:
            return "I did not draw this one. I worked it out, a day at a time, and I have been wrong more than once."
        }
    }
}

protocol BookPageSourceAdapter {
    var source: BookPageSource { get }
    /// Declared here (not just defaulted in the extension) so an override on a
    /// concrete adapter dispatches dynamically when called on the existential.
    var servedSourceIDs: [String] { get }
    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage]
    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage
}

extension SurfacePage {
    /// A Page fetched by the reader has no curation occasion to explain.
    /// Give it Book copy written for an open leaf; keep the registry note in
    /// the source registry, where catalogue copy belongs.
    static func handOpened(
        source: BookPageSource,
        day: BookDay,
        now: Date,
        intent: BookPageIntent? = nil,
        renderStyle: BookPageRenderStyle = .promptCard,
        score: Int = 58,
        metadata extraMetadata: [String: String] = [:],
        tags extraTags: [String] = []
    ) -> SurfacePage {
        let copy = source.handOpened
        var metadata = extraMetadata
        metadata["source"] = source.id
        metadata["handOpened"] = "true"
        metadata["tags"] = (["manual-page", source.type.rawValue] + extraTags)
            .joined(separator: ",")
        return SurfacePage(
            id: "manual-\(source.type.rawValue)-\(day.id)-\(Int(now.timeIntervalSince1970))",
            type: source.type,
            sourceID: source.id,
            intent: intent,
            renderStyle: renderStyle,
            score: score,
            reason: "",
            prompt: source.title,
            detail: copy.deck,
            payload: BookPagePayload(
                headline: source.title,
                body: copy.body,
                // Deliberately no `placeholder`: a hand-opened Page carries no
                // occasion of its own, so the writing box should say what this
                // *type* of Page is for. See `BookPageType.marginAsk`.
                metadata: metadata
            )
        )
    }
}

extension BookPageSourceAdapter {
    /// Every active source ID this adapter can stamp onto a surfaced page.
    /// Most adapters serve only their own `source`; a few (e.g. the Wonder
    /// Compass) fan one adapter out across several child source IDs so those
    /// children can carry their own Belief and titles. The curator invariant
    /// "every active source has an adapter" reads this, not just `source.id`.
    var servedSourceIDs: [String] { [source.id] }

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        candidates(for: day, context: context, inputs: inputs, now: now).first ?? .handOpened(
            source: source,
            day: day,
            now: now
        )
    }
}

struct MoodPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .mood)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        let window = FacultyLogCadence.currentWindow(for: now)
        guard !FacultyLogCadence.didLog(kind: .innerWeather, day: day, entries: inputs.facultyEntries, now: now) else {
            return []
        }
        let baseTags = "inner-weather,faculty-kind:innerWeather,faculty-window:\(window.id),dr-inkrest,therapy-chart"
        var pages = [
            SurfacePage(
                id: "\(source.id)-\(day.id)-\(window.id)",
                type: .mood,
                sourceID: source.id,
                intent: .capture,
                renderStyle: .promptCard,
                score: context.distress.isActive ? 72 : 64,
                reason: context.distress.isActive ? "Something heavy showed up, and it just wants a gentle name." : "Dr. Inkrest left a little chart window open for you.",
                prompt: "What's the weather like inside you?",
                detail: "\(window.name). Give the sky inside you a name. One tap is plenty.",
                payload: BookPagePayload(
                    headline: "Inner Weather",
                    body: "Give the sky inside you a name. One tap is plenty.",
                    metadata: [
                        "source": source.id,
                        "facultyID": FacultyEntryKind.innerWeather.facultyID,
                        "facultyKind": FacultyEntryKind.innerWeather.rawValue,
                        "facultyWindowID": window.id,
                        "facultyWindowName": window.name,
                        "automaticRecurrenceSlot": "\(day.id):\(window.id):inner-weather",
                        "chartTitle": FacultyEntryKind.innerWeather.chartTitle,
                        "tags": baseTags
                    ]
                )
            )
        ]
        // Shadow Wonder: the same chart, but with the book's "harmonize with the
        // grey" permission: name the inner sky honestly, overcast and all.
        let shadow = ShadowWonder.state(inputs: inputs, now: now)
        if ShadowWonder.shouldSurface(.innerWeather, inputs: inputs, now: now) {
            var metadata = pages[0].payload.metadata
            metadata["tags"] = ShadowWonder.mergedTags(baseTags + ",mood-match", inputs: inputs, now: now)
            metadata["shadowVariantOf"] = pages[0].id
            metadata["variant"] = "shadow-wonder"
            pages.append(
                SurfacePage(
                    id: "\(source.id)-shadow-\(day.id)-\(window.id)",
                    type: .mood,
                    sourceID: source.id,
                    intent: .capture,
                    renderStyle: .promptCard,
                    score: (context.distress.isActive ? 72 : 64) + shadow.scoreBoost,
                    reason: "Shadow Wonder heard the grey humming and refused to paint it yellow.",
                    prompt: "What's the weather inside: the real, quiet, grey kind?",
                    detail: "\(window.name). The grey got here first and locked the yellow paint outside. Name the sky inside you exactly how it is, clouds and all. One honest tap catches it.",
                    payload: BookPagePayload(
                        headline: "Inner Weather",
                        body: "Name the inner sky in its true key. A minor key still holds you. One honest tap is enough.",
                        metadata: metadata
                    )
                )
            )
        }
        return pages
    }
}

enum JournalPromptFamily: String, CaseIterable {
    case wonder
    case authorship
    case listening
    case moment
    case connection
    case shadow
    case traditional
    case mischief
    case rest
}

enum JournalPromptContext: String {
    case none
    case recentPage
    case person
    case place
    case weather
    case recurringThread
}

struct JournalPromptEntry: Equatable {
    var id: String
    var family: JournalPromptFamily
    var title: String
    var question: String
    var deeperQuestion: String
    var placeholder: String
    var semanticHints: [String]
    var context: JournalPromptContext = .none
    var authorEntityID: String? = nil
    var authorName: String? = nil
    var authorLead: String? = nil

    var isCastAuthored: Bool { authorEntityID != nil }

    var semanticDocument: String {
        ([title, question, deeperQuestion] + semanticHints + [family.rawValue])
            .joined(separator: " ")
    }
}

struct JournalPromptSelection: Equatable {
    var entry: JournalPromptEntry
    var question: String
    var deeperQuestion: String
    var selector: String
    var evidencePageID: String?
    var evidenceExcerpt: String?
    var contextLabel: String?
}

enum JournalPromptCatalog {
    static let entries: [JournalPromptEntry] = [
        prompt("almost-missed", .wonder, "The Thing That Nearly Vanished",
               "What did you almost miss today?",
               "What made you look twice?",
               "I almost missed...",
               ["notice", "detail", "ordinary", "sensory", "attention", "small moment"]),
        prompt("ordinary-broke-character", .wonder, "When Ordinary Broke Character",
               "What ordinary thing briefly stopped being ordinary today?",
               "What changed: the thing, the light, the timing, or you?",
               "For a moment...",
               ["wonder", "surprise", "object", "place", "light", "unexpected"]),
        prompt("sound-punctuation", .wonder, "The Day's Punctuation",
               "What sound served as the day's punctuation?",
               "Was it a period, question mark, comma, or something less grammatical?",
               "The sound was...",
               ["sound", "voice", "music", "weather", "room", "rhythm"]),
        prompt("light-favorites", .wonder, "The Light Chose Favorites",
               "Where did the light behave as if it had chosen a favorite?",
               "What did it make visible that the room usually keeps quiet?",
               "The light chose...",
               ["light", "color", "window", "weather", "room", "sight", "photo"]),
        prompt("undocumented-side-quest", .mischief, "The Undocumented Side Quest",
               "What was today's unofficial side quest?",
               "At what exact moment did you accidentally accept it?",
               "The side quest began when...",
               ["errand", "adventure", "unexpected", "detour", "funny", "problem", "quest"]),
        prompt("smallest-scandal", .mischief, "A Very Small Scandal",
               "What was the day's smallest, least consequential scandal?",
               "Who (or what) behaved most suspiciously?",
               "The scandal involved...",
               ["funny", "awkward", "pet", "food", "object", "mistake", "ridiculous"]),
        prompt("object-performance-review", .mischief, "An Overdue Performance Review",
               "Which object near you worked hardest today without proper recognition?",
               "What rating does it receive, and what must management improve?",
               "Employee of the day...",
               ["object", "home", "work", "tool", "funny", "care", "ordinary"]),
        prompt("academy-transfer-student", .mischief, "Today's Transfer Student",
               "If today arrived at the Academy as a transfer student, what would be suspicious about it?",
               "Which Chapter would claim it first?",
               "Today arrived wearing...",
               ["day", "academy", "character", "funny", "weather", "mood", "story"]),
        prompt("two-percent", .authorship, "Two Percent Different",
               "What did you change your mind about by two percent?",
               "What tiny piece of evidence moved it?",
               "I'm not entirely where I was on...",
               ["choice", "change", "decision", "belief", "learn", "evidence"]),
        prompt("chosen-moment", .authorship, "The Moment You Authored",
               "Where did you make a choice today instead of simply continuing?",
               "What became possible because you interrupted the default?",
               "I chose...",
               ["choice", "agency", "boundary", "decision", "courage", "change"]),
        prompt("tomorrow-line", .authorship, "A Line for Tomorrow",
               "What sentence do you need to be able to read tomorrow morning?",
               "Can it be both kind and completely true?",
               "Tomorrow, remember...",
               ["tomorrow", "intention", "choice", "courage", "need", "future"]),
        prompt("world-already-saying", .listening, "Before You Answered",
               "What was the world already trying to show you today?",
               "What happened when you stopped trying to make it mean something else?",
               "It kept showing me...",
               ["listen", "nature", "weather", "pattern", "signal", "patience", "notice"]),
        prompt("kept-returning", .listening, "The Returning Thing",
               "What kept returning to your attention after you dismissed it?",
               "What if recurrence, not loudness, is what made it important?",
               "It returned when...",
               ["repeat", "pattern", "memory", "attention", "thought", "object", "person"]),
        prompt("complete-without-lesson", .moment, "No Lesson Required",
               "Which part of today deserves no lesson, silver lining, or character growth?",
               "What changes if you let it remain complete exactly as it was?",
               "It was enough that...",
               ["moment", "present", "rest", "complete", "ordinary", "no lesson"]),
        prompt("first-surprise", .moment, "The Unplanned Hour",
               "What caught you genuinely off guard today?",
               "What did the surprise make vivid for a moment?",
               "I didn't expect...",
               ["surprise", "unexpected", "moment", "change", "delight", "weather"]),
        prompt("room-temperature", .connection, "Who Changed the Room?",
               "Who changed the temperature of a room today simply by entering it?",
               "What did your body notice before your mind supplied the explanation?",
               "When they arrived...",
               ["person", "people", "relationship", "room", "body", "presence"]),
        prompt("still-echoing", .connection, "Still Echoing",
               "What did someone say that is still echoing?",
               "Is the echo carrying their meaning, or one you added later?",
               "They said...",
               ["person", "conversation", "voice", "relationship", "words", "memory"]),
        prompt("invisible-work", .connection, "The Work Nobody Announced",
               "Whose invisible work made your day easier?",
               "What exactly did they do that could have disappeared into 'nothing'?",
               "Because they...",
               ["person", "care", "kindness", "work", "family", "friend", "gratitude"]),
        prompt("convenient-truth", .shadow, "Waiting for a Better Time",
               "What truth are you waiting to become more convenient before admitting?",
               "What is the smallest honest version you can write without turning it into a verdict?",
               "The inconvenient part is...",
               ["truth", "avoid", "conflict", "boundary", "decision", "fear", "honest"]),
        prompt("protecting-avoidance", .shadow, "The Guard at the Door",
               "What might your avoidance be trying to protect?",
               "Can you thank the guard without giving it permanent control of the door?",
               "The guard thinks...",
               ["avoid", "protect", "fear", "conflict", "boundary", "care", "door"]),
        prompt("worst-thing-today", .shadow, "The Worst Thing",
               "What was the worst thing that happened to you today?",
               "What exact part made it the worst: the event, the cost, the helplessness, or what it changed?",
               "The worst part was...",
               ["hard", "hurt", "worst", "cost", "conflict", "loss", "today", "exact"]),
        prompt("what-fought-you", .shadow, "What Fought You?",
               "What fought you today?",
               "Was it a person, a circumstance, your own automatic motion, or something with no clean name? Don't make it the Rut unless the evidence actually fits.",
               "Today I was up against...",
               ["fight", "resistance", "conflict", "pressure", "routine", "automatic", "evidence"]),
        prompt("took-too-much", .shadow, "More Than Its Share",
               "What took more from you today than it had any right to take?",
               "What did it take: time, attention, patience, safety, dignity, or something else?",
               "It took...",
               ["cost", "attention", "time", "drain", "conflict", "boundary", "hard"]),
        prompt("carried-through", .shadow, "What You Carried Through",
               "What did you have to carry through the day without dropping?",
               "What did carrying it change about the way the rest of the day felt?",
               "I carried...",
               ["carry", "burden", "care", "responsibility", "endure", "day", "weight"]),
        prompt("pushed-back", .shadow, "Where You Pushed Back",
               "Where did you push back today, even if nothing was solved?",
               "What remained difficult after the refusal, and what became more honest?",
               "I pushed back when...",
               ["refusal", "boundary", "resist", "choice", "conflict", "honest", "unfinished"]),
        prompt("changed-room", .traditional, "Evidence of Today",
               "Look around. What did today's events change, move, empty, dirty, finish, or leave behind?",
               "Begin with the changed thing instead of a summary.",
               "The room proves today happened because...",
               ["day", "room", "object", "evidence", "home", "work", "detail"]),
        prompt("plain-chronology", .traditional, "What Happened",
               "What happened today? Tell it plainly. Which moment still has heat?",
               "Why that moment and not the supposedly important one?",
               "Today...",
               ["journal", "day", "memory", "event", "reflection", "traditional"]),
        prompt("hard-and-helped", .traditional, "Hard / Helped",
               "What was hard today? What helped, even a little?",
               "What does the size of the help tell you about what you actually needed?",
               "What was hard...\nWhat helped...",
               ["hard", "help", "care", "support", "tired", "reflection", "traditional"]),
        prompt("three-concrete-goods", .traditional, "Three Good Things with Names",
               "Name three good things, but no abstractions: give the person, object, place, sound, or action.",
               "Which one would be easiest to overlook tomorrow?",
               "1.\n2.\n3.",
               ["gratitude", "good", "person", "object", "place", "sound", "traditional"]),
        prompt("tomorrow-contain", .traditional, "A Shape for Tomorrow",
               "What do you need tomorrow to contain?",
               "What is the smallest form that need could honestly take?",
               "Tomorrow needs...",
               ["tomorrow", "need", "plan", "care", "rest", "traditional"]),
        prompt("free-page", .traditional, "Let the Ink Misbehave",
               "Write freely for five minutes. If meaning turns up, make it wait outside.",
               "If a true sentence appears, let it stay unpolished.",
               "Start anywhere...",
               ["free write", "journal", "thought", "feeling", "traditional", "private"]),
        prompt("unfinished-permission", .rest, "Leave One Thing with Its Boots On",
               "What stays unfinished tonight and survives the indignity?",
               "What does shutting the cover actually require?",
               "Tonight, I'm leaving...",
               ["rest", "unfinished", "tired", "night", "permission", "care"]),
        prompt("stop-performing", .rest, "After the Performance",
               "What can stop performing now that the day is ending?",
               "What is still true when nobody needs anything from it?",
               "It can stop...",
               ["rest", "night", "work", "body", "performance", "quiet"]),
        prompt("survived-with-you", .rest, "The Things That Made It Home",
               "Name three things within reach that survived the day with you.",
               "Which one seems most ready to be put down?",
               "Still here with me...",
               ["rest", "object", "home", "night", "survive", "inventory"]),
        prompt("page-left-out", .wonder, "What the Page Left Out",
               "This line is still warm from today: “{excerpt}” What did it leave out?",
               "Was the missing thing too small, too strange, or too close to name the first time?",
               "What it left out...",
               ["page", "memory", "detail", "missing", "notice", "evidence"],
               context: .recentPage),
        prompt("routine-cross-examination", .wonder, "Evidence Against an Ordinary Day",
               "Routine claims nothing happened. Your own page says: “{excerpt}” What does that line prove?",
               "What would Routine prefer you call insignificant?",
               "It proves...",
               ["routine", "evidence", "ordinary", "page", "memory", "wonder"],
               context: .recentPage),
        prompt("named-person-temperature", .connection, "A Person in the Margins",
               "{person} crossed my margins recently. What did their presence change that a timeline would miss?",
               "What detail belongs specifically to them and no one else?",
               "When {person} was there...",
               ["person", "relationship", "presence", "memory", "change"],
               context: .person),
        prompt("place-at-this-hour", .moment, "This Place, This Hour",
               "What is {place} like at this exact hour, not generally, but tonight?",
               "What would be gone if you returned at noon?",
               "At this hour, {place}...",
               ["place", "location", "night", "room", "weather", "time"],
               context: .place),
        prompt("weather-made-visible", .listening, "What the Weather Revealed",
               "The weather arrived as “{weather}.” What did it make easier to notice?",
               "What did the forecast fail to mention?",
               "The weather revealed...",
               ["weather", "outside", "sound", "light", "body", "place"],
               context: .weather),
        prompt("thread-keeps-pulling", .listening, "The Thread That Keeps Pulling",
               "I keep finding “{thread}” in the recent margins. What do you think is actually gathering there?",
               "What would be too early (or too neat) to conclude?",
               "The thread might be...",
               ["pattern", "theme", "repeat", "memory", "meaning", "notice"],
               context: .recurringThread),

        prompt("penny-evidence", .wonder, "Filed as Contradictory Evidence",
               "Penny Blackletter requests one detail proving today was not merely a repeat of yesterday.",
               "Would the evidence survive cross-examination by someone extremely committed to being bored?",
               "Evidence, item one...",
               ["evidence", "detail", "routine", "archive", "ordinary", "funny"],
               author: ("penny-blackletter", "Penny Blackletter", "Penny has opened a file. Apparently the day is under investigation.")),
        prompt("wicker-premise", .shadow, "The Premise Wicker Doesn't Buy",
               "Which explanation about today sounds tidy, reasonable, and not entirely true?",
               "What exact fact makes the premise wobble?",
               "The tidy version is...",
               ["truth", "conflict", "premise", "doubt", "avoid", "evidence"],
               author: ("wicker-eddies", "Wicker Eddies", "Wicker underlined this twice, which is rarely a peaceful sign.")),
        prompt("zara-small-return", .connection, "A Small Return",
               "Who proved something through one small return today: coming back, following through, remembering, or making room?",
               "What trust did that tiny act build?",
               "The small return was...",
               ["trust", "friendship", "person", "return", "care", "relationship"],
               author: ("zara-finch", "Zara Finch", "Zara left this question beside the safest path through the page.")),
        prompt("stonebrook-set-down", .rest, "Put One Thing Down",
               "What are you still carrying only because you have not formally put it down?",
               "What would count as setting it down for tonight, not forever?",
               "For tonight, I can put down...",
               ["rest", "night", "carry", "unfinished", "body", "care"],
               author: ("professor-cedric-stonebrook", "Professor Cedric Stonebrook", "Professor Stonebrook has turned the hourglass on its side.")),
        prompt("villanelle-true-line", .traditional, "One Line That Holds",
               "Write one sentence from today that is true enough to carry time.",
               "Which pretty but inaccurate word can you cross out?",
               "The sentence is...",
               ["sentence", "write", "memory", "true", "detail", "souvenir"],
               author: ("professor-vivian-villanelle", "Professor Vivian Villanelle", "Professor Villanelle is weighing the sentence in her palm.")),
        prompt("wispwood-object", .mischief, "The Object's Complaint",
               "Choose one nearby object. If it were allowed one calm, specific complaint about today, what would it say?",
               "What visible fact supports its case?",
               "The object says...",
               ["object", "voice", "home", "funny", "enchantment", "evidence"],
               author: ("professor-luna-wispwood", "Professor Luna Wispwood", "Professor Wispwood apologized to the object before handing it the floor."))
    ]

    private static func prompt(
        _ id: String,
        _ family: JournalPromptFamily,
        _ title: String,
        _ question: String,
        _ deeperQuestion: String,
        _ placeholder: String,
        _ semanticHints: [String],
        context: JournalPromptContext = .none,
        author: (id: String, name: String, lead: String)? = nil
    ) -> JournalPromptEntry {
        JournalPromptEntry(
            id: id,
            family: family,
            title: title,
            question: question,
            deeperQuestion: deeperQuestion,
            placeholder: placeholder,
            semanticHints: semanticHints,
            context: context,
            authorEntityID: author?.id,
            authorName: author?.name,
            authorLead: author?.lead
        )
    }
}

enum JournalPromptSelector {
    private struct Signals {
        var recentPages: [BookPage]
        var personName: String?
        var placeName: String?
        var weather: String?
        var recurringThread: String?
        var query: String
        var queryWords: Set<String>
    }

    static func select(
        day: BookDay,
        inputs: BookSourceInputs,
        context: CuratorContext,
        now: Date = Date(),
        calendar: Calendar = .current,
        scorer: StacksSemanticScoring? = nil
    ) -> JournalPromptSelection {
        rankedSelections(
            day: day,
            inputs: inputs,
            context: context,
            now: now,
            calendar: calendar,
            scorer: scorer,
            limit: 1
        ).first!
    }

    /// Produces a small, honestly ranked bench. The Curator, not this selector,
    /// makes the final individual-Page choice after Diary has won the Page
    /// Type draw.
    static func rankedSelections(
        day: BookDay,
        inputs: BookSourceInputs,
        context: CuratorContext,
        now: Date = Date(),
        calendar: Calendar = .current,
        scorer: StacksSemanticScoring? = nil,
        limit: Int = 4
    ) -> [JournalPromptSelection] {
        let signals = signals(day: day, inputs: inputs, now: now)
        let hour = calendar.component(.hour, from: now)
        let isEvening = (17..<22).contains(hour)
        let isVeryLate = hour >= 22 || hour < 5
        let recentPromptIDs = recentTagValues(prefix: "journal-prompt:", pages: signals.recentPages)
        let recentFamilies = recentTagValues(prefix: "journal-family:", pages: signals.recentPages)
        let recentCastPage = signals.recentPages.prefix(8).contains {
            $0.tags.contains(where: { $0.hasPrefix("journal-author:") && $0 != "journal-author:the-book" })
        }
        let castTurn = !context.distress.isActive
            && !isVeryLate
            && !recentCastPage
            && abs("\(day.id)-\(SurfaceCadence.slotID(for: now, hours: 6))-journal-cast".stableHash) % 5 == 0
        let enabledCastIDs = Set(NarrativePackRegistry.entities.map(\.id))

        var candidates = JournalPromptCatalog.entries.filter { entry in
            guard contextAvailable(entry.context, signals: signals) else { return false }
            if castTurn {
                guard entry.isCastAuthored,
                      let authorID = entry.authorEntityID,
                      enabledCastIDs.contains(authorID) else {
                    return false
                }
            } else if entry.isCastAuthored {
                return false
            }
            if context.distress.isActive && [.shadow, .mischief].contains(entry.family) {
                return false
            }
            if isVeryLate && [.shadow, .authorship, .mischief].contains(entry.family) {
                return false
            }
            return true
        }
        if candidates.isEmpty {
            candidates = JournalPromptCatalog.entries.filter { !$0.isCastAuthored && $0.context == .none }
        }

        var scored = candidates.map { entry -> (entry: JournalPromptEntry, score: Int, similarity: Double?) in
            let entryWords = SemanticKeepEcho.contentWords(in: entry.semanticDocument)
            let overlap = signals.queryWords.intersection(entryWords).count
            var score = 30 + min(30, overlap * 6)
            if entry.context != .none { score += 12 }
            if isEvening { score += eveningBoost(entry.family) }
            if isVeryLate && [.rest, .traditional, .listening].contains(entry.family) { score += 16 }
            if context.distress.isActive && [.rest, .traditional, .listening].contains(entry.family) { score += 18 }
            if recentPromptIDs.contains(entry.id) { score -= 80 }
            if recentFamilies.prefix(2).contains(entry.family.rawValue) { score -= 12 }
            if entry.isCastAuthored { score += 4 }
            score += abs("\(day.id)-\(entry.id)-journal".stableHash) % 9
            return (entry, score, nil)
        }
        scored.sort { rankedBefore($0, $1) }

        if let scorer, !signals.query.isEmpty {
            for index in scored.indices.prefix(12) {
                guard let similarity = scorer.similarity(
                    between: signals.query,
                    and: scored[index].entry.semanticDocument
                ) else { continue }
                scored[index].similarity = similarity
                scored[index].score += Int((similarity * 36).rounded())
            }
            scored.sort { rankedBefore($0, $1) }
        }

        let fallback = JournalPromptCatalog.entries.first(where: { $0.id == "plain-chronology" })!
        let entries = scored.isEmpty ? [fallback] : Array(scored.prefix(max(1, limit)).map(\.entry))
        return entries.map { selected in
            let evidencePage = bestEvidencePage(
                for: selected,
                pages: signals.recentPages,
                scorer: scorer
            )
            let excerpt = evidencePage.flatMap { clippedEvidence(from: $0) }
            let values: [String: String] = [
                "excerpt": excerpt ?? "one small thing happened",
                "person": signals.personName ?? "someone",
                "place": signals.placeName ?? "this place",
                "weather": signals.weather ?? "the weather outside",
                "thread": signals.recurringThread ?? "something unfinished"
            ]
            return JournalPromptSelection(
                entry: selected,
                question: replacingPlaceholders(in: selected.question, values: values),
                deeperQuestion: replacingPlaceholders(in: selected.deeperQuestion, values: values),
                selector: scorer == nil ? "context-lexical" : "context-semantic-lexical",
                evidencePageID: selected.context == .recentPage ? evidencePage?.id : nil,
                evidenceExcerpt: selected.context == .recentPage ? excerpt : nil,
                contextLabel: contextLabel(for: selected.context, signals: signals)
            )
        }
    }

    private static func signals(day: BookDay, inputs: BookSourceInputs, now: Date) -> Signals {
        let cutoff = now.addingTimeInterval(-21 * 86_400)
        let pages = Dictionary(
            (inputs.days.suffix(21).flatMap(\.capturedPages) + day.capturedPages)
                .filter { $0.createdAt >= cutoff }
                .map { ($0.id, $0) },
            uniquingKeysWith: { first, second in first.createdAt >= second.createdAt ? first : second }
        ).values.sorted { left, right in
            if left.createdAt == right.createdAt { return left.id < right.id }
            return left.createdAt > right.createdAt
        }
        let authored = pages.compactMap { page -> (page: BookPage, text: String)? in
            guard let text = page.readerAuthoredTextForAnalysis else { return nil }
            return (page, text)
        }
        let pageText = authored.prefix(14).map { item in
            "\(item.text) \(item.page.tags.joined(separator: " ")) \(item.page.resolvedAttentionFingerprint.patternText)"
        }
        let usableFacts = inputs.selfFacts
            .filter { $0.usePermission != .doNotUse }
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(5)
            .map { "\($0.answer) \($0.tags.joined(separator: " "))" }
        let storyThread = inputs.readerStory
            .carriedThreads(now: now)
            .last?
            .line
            .nonEmpty
        let recurring = storyThread
            ?? inputs.themes.sorted { $0.strength > $1.strength }.first?.name.nonEmpty
            ?? inputs.clusters.sorted { $0.strength > $1.strength }.first?.name.nonEmpty
        let person = inputs.people.threads
            .filter { !$0.resting }
            .sorted { left, right in
                if left.lastMentionDay == right.lastMentionDay { return left.name < right.name }
                return left.lastMentionDay > right.lastMentionDay
            }
            .first?.name.nonEmpty
        let place = inputs.currentLocationLabel?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            ?? inputs.nearbyAnchor?.anchor.name.nonEmpty
        let weather = inputs.weather?.phrase.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            ?? inputs.enchantedWeather?.summary.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        let readerNamedSeason = inputs.readerStory.currentSeason?.name.nonEmpty
        let queryPieces = pageText + usableFacts
            + [person, place, weather, recurring, readerNamedSeason].compactMap { $0 }
        let query = String(queryPieces.joined(separator: ". ").prefix(2_400))
        return Signals(
            recentPages: pages,
            personName: person,
            placeName: place,
            weather: weather.map { String($0.prefix(140)) },
            recurringThread: recurring,
            query: query,
            queryWords: SemanticKeepEcho.contentWords(in: query)
        )
    }

    private static func contextAvailable(_ context: JournalPromptContext, signals: Signals) -> Bool {
        switch context {
        case .none: return true
        case .recentPage: return signals.recentPages.contains { clippedEvidence(from: $0) != nil }
        case .person: return signals.personName != nil
        case .place: return signals.placeName != nil
        case .weather: return signals.weather != nil
        case .recurringThread: return signals.recurringThread != nil
        }
    }

    private static func bestEvidencePage(
        for entry: JournalPromptEntry,
        pages: [BookPage],
        scorer: StacksSemanticScoring?
    ) -> BookPage? {
        let candidates = pages.filter { clippedEvidence(from: $0) != nil }.prefix(16)
        let hintWords = SemanticKeepEcho.contentWords(in: entry.semanticDocument)
        return candidates.enumerated().map { index, page in
            let text = clippedEvidence(from: page) ?? ""
            let words = SemanticKeepEcho.contentWords(in: "\(text) \(page.tags.joined(separator: " ")) \(page.resolvedAttentionFingerprint.patternText)")
            let lexical = hintWords.intersection(words).count * 8
            let semantic = scorer?.similarity(between: entry.semanticDocument, and: text) ?? 0
            return (page, lexical + Int((semantic * 40).rounded()) + max(0, 8 - index))
        }.max { left, right in
            if left.1 == right.1 { return left.0.createdAt < right.0.createdAt }
            return left.1 < right.1
        }?.0
    }

    private static func clippedEvidence(from page: BookPage) -> String? {
        guard let input = page.readerAuthoredTextForAnalysis else { return nil }
        // Some older prompted Pages copied the Book's question into the legacy
        // `userInput` slot. Their source is reader-authored because the answer
        // belongs to the reader, but an untouched copy of `promptText` is not
        // an answer. Do not let a Journal Page put quotation marks around the
        // Book's own question and call it the reader's words.
        let comparisonKey: (String) -> String = { value in
            value
                .split(whereSeparator: { $0.isWhitespace })
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
        }
        guard comparisonKey(input) != comparisonKey(page.promptText) else { return nil }
        let firstLine = input.split(separator: "\n", omittingEmptySubsequences: true).first.map(String.init) ?? input
        let oneSentence = firstLine.bookPreviewSentenceLimit(1)
        guard !oneSentence.isEmpty else { return nil }
        if oneSentence.count <= 120 { return oneSentence }
        let prefix = oneSentence.prefix(120)
        let end = prefix.lastIndex(of: " ") ?? prefix.endIndex
        return String(prefix[..<end]) + "\u{2026}"
    }

    private static func recentTagValues(prefix: String, pages: [BookPage]) -> [String] {
        pages.flatMap(\.tags).compactMap { tag in
            guard tag.hasPrefix(prefix) else { return nil }
            return String(tag.dropFirst(prefix.count))
        }
    }

    private static func eveningBoost(_ family: JournalPromptFamily) -> Int {
        switch family {
        case .wonder, .connection, .traditional: return 10
        case .moment, .listening, .rest: return 8
        case .authorship, .shadow, .mischief: return 5
        }
    }

    private static func rankedBefore(
        _ left: (entry: JournalPromptEntry, score: Int, similarity: Double?),
        _ right: (entry: JournalPromptEntry, score: Int, similarity: Double?)
    ) -> Bool {
        if left.score != right.score { return left.score > right.score }
        if left.similarity != right.similarity {
            return (left.similarity ?? 0) > (right.similarity ?? 0)
        }
        return left.entry.id < right.entry.id
    }

    private static func replacingPlaceholders(in text: String, values: [String: String]) -> String {
        values.reduce(text) { partial, entry in
            partial.replacingOccurrences(of: "{\(entry.key)}", with: entry.value)
        }
    }

    private static func contextLabel(for context: JournalPromptContext, signals: Signals) -> String? {
        switch context {
        case .none, .recentPage: return nil
        case .person: return signals.personName
        case .place: return signals.placeName
        case .weather: return signals.weather
        case .recurringThread: return signals.recurringThread
        }
    }
}

struct DiaryPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .diary)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        let scorer = inputs.semanticPassageSelectionEnabled ? SemanticKeepEcho.keepTimeScorer : nil
        let selections = JournalPromptSelector.rankedSelections(
            day: day,
            inputs: inputs,
            context: context,
            now: now,
            scorer: scorer,
            limit: 4
        )
        let hour = Calendar.current.component(.hour, from: now)
        let isEvening = (17..<22).contains(hour)
        let isVeryLate = hour >= 22 || hour < 5
        let score: Int
        if isVeryLate {
            score = context.distress.isActive ? 58 : 50
        } else if isEvening {
            score = context.distress.isActive ? 72 : 70
        } else {
            score = context.distress.isActive ? 70 : 58
        }

        return selections.map { selection in
            var metadata: [String: String] = [
                "source": source.id,
                "placeholder": selection.entry.placeholder,
                "journalPromptID": selection.entry.id,
                "journalFamily": selection.entry.family.rawValue,
                "journalDeeperQuestion": selection.deeperQuestion,
                "journalSelector": selection.selector,
                "journalSemanticallyAware": "true",
                "journalAuthorID": selection.entry.authorEntityID ?? "the-book",
                "journalAuthorName": selection.entry.authorName ?? "The Book",
                "tags": [
                    "journal",
                    "journal-page",
                    "private",
                    "journal-prompt:\(selection.entry.id)",
                    "journal-family:\(selection.entry.family.rawValue)",
                    "journal-author:\(selection.entry.authorEntityID ?? "the-book")"
                ].joined(separator: ",")
            ]
            if let evidencePageID = selection.evidencePageID {
                metadata["journalEvidencePageID"] = evidencePageID
            }
            if let evidenceExcerpt = selection.evidenceExcerpt {
                metadata["journalEvidenceExcerpt"] = evidenceExcerpt
            }
            if let contextLabel = selection.contextLabel {
                metadata["journalContextLabel"] = contextLabel
            }
            if let authorLead = selection.entry.authorLead {
                metadata["journalAuthorLead"] = authorLead
            }
            metadata["journalResponseInvitation"] = journalResponseInvitation(for: selection.entry)
            // The question is the title of this leaf, and the writing box under
            // it already names the ask (`BookPageType.marginAsk`). The body
            // used to print the question a second time and explain the box a
            // third, which the folio shows all at once. It now carries the one
            // thing the reader cannot see anywhere else: where the question
            // came from.
            var bodyParts: [String] = []
            if let authorLead = selection.entry.authorLead {
                bodyParts.append(authorLead)
            }
            if let excerpt = selection.evidenceExcerpt?.nonEmpty {
                bodyParts.append("It came out of something you kept: “\(excerpt)”")
            } else if let contextLabel = selection.contextLabel?.nonEmpty {
                bodyParts.append("\(contextLabel) keeps turning up in what you keep. That is where I got it.")
            } else if bodyParts.isEmpty {
                bodyParts.append(ReflectiveProse.pick([
                    "I had the day's leavings out on the desk and this is what they asked.",
                    "One question. I am not going to dress it up.",
                    "This is the one I kept coming back to while you were out.",
                    "I went looking for a better question than this and came back with this one."
                ], seed: UInt64(abs(selection.entry.id.stableHash)), salt: UInt64(abs(day.id.stableHash % 97))))
            }
            let body = bodyParts.joined(separator: "\n\n")
            let detail: String
            if let author = selection.entry.authorName {
                detail = "\(author) left this one in the margin."
            } else if isVeryLate {
                detail = "A late question. Answer it or go to sleep. Both are real answers."
            } else {
                detail = "One question, picked out of your own day."
            }
            return SurfacePage(
                id: "\(source.id)-journal-\(selection.entry.id)-\(day.id)-\(SurfaceCadence.slotID(for: now, hours: 6))",
                type: .diary,
                sourceID: source.id,
                intent: .capture,
                renderStyle: .promptCard,
                score: score,
                reason: context.distress.isActive
                    ? "A private Journal Page can hold one true thing without trying to repair it."
                    : isEvening
                    ? "Evening gives me enough of the day to ask one unusually good question."
                    : "I found a question that fits the material already gathering in the margins.",
                prompt: selection.question,
                detail: detail,
                payload: BookPagePayload(
                    headline: selection.entry.title,
                    body: body,
                    metadata: metadata
                )
            ).withPageCapabilities(capability(for: selection, isVeryLate: isVeryLate))
        }
    }

    private func journalResponseInvitation(for entry: JournalPromptEntry) -> String {
        switch entry.authorEntityID {
        case "penny-blackletter":
            return "Don't work up a conclusion. One honest scrap of evidence in the box below is plenty — Penny brought a very small folder."
        case .some:
            return "Write your answer in the box below whenever you like. A sentence is a whole answer, and nobody's marking it."
        case .none:
            return "Write your answer in the box below. One sentence is enough, and I'm not grading it."
        }
    }

    private func capability(
        for selection: JournalPromptSelection,
        isVeryLate: Bool
    ) -> PageCapabilityContract {
        let movement: [BookReenchantmentMovement]
        let functions: [PageEmotionalFunction]
        switch selection.entry.family {
        case .wonder:
            movement = [.freshSight, .livingWorld]
            functions = [.notice, .wonder, .express]
        case .authorship:
            movement = [.scriptFreedom, .exactLanguage]
            functions = [.express, .act]
        case .listening:
            movement = [.freshSight, .humanOtherness]
            functions = [.notice, .connect, .express]
        case .moment:
            movement = [.freshSight, .livingContinuity]
            functions = [.notice, .remember, .express]
        case .connection:
            movement = [.humanOtherness, .livingContinuity]
            functions = [.connect, .remember, .express]
        case .mischief:
            movement = [.scriptFreedom, .chosenDetour]
            functions = [.play, .express]
        case .shadow:
            movement = [.exactLanguage, .shelter]
            functions = [.soothe, .express]
        case .rest:
            movement = [.shelter]
            functions = [.soothe, .express]
        case .traditional:
            movement = [.exactLanguage, .livingContinuity]
            functions = [.express, .remember]
        }
        let groundedInReaderInk = selection.evidencePageID != nil
        return PageCapabilityContract(
            supportedMovements: movement,
            supportedRoles: [.echo, .door],
            emotionalFunctions: groundedInReaderInk
                ? (functions.contains(.remember) ? functions : functions + [.remember])
                : functions,
            effort: .small,
            estimatedMinutes: isVeryLate ? 2 : 4,
            asksReader: true,
            pressureCost: selection.entry.family == .rest ? 0.18 : (isVeryLate ? 0.24 : 0.34),
            proofModes: [.response]
        )
    }
}

struct PlainPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .plainPage)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        let pages = Self.pagewrightSeedPages(from: inputs.days, limit: 3)
        guard pages.count >= 3 else { return [] }

        let slot = SurfaceCadence.slotID(for: now, hours: 72)
        return [
            SurfacePage(
                id: "pagewright-invitation-\(slot)",
                type: .plainPage,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .promptCard,
                score: context.distress.isActive ? 34 : 67,
                reason: "The Pagewright has enough of the reader's own material to begin a spread.",
                prompt: "The Pagewright Has Laid Things Out",
                detail: "A few things you kept are already waiting on the canvas: photographs, illuminated plates, and scraps out of me. Move them until they belong together.",
                payload: BookPagePayload(
                    headline: "A Pagewright Spread Is Waiting",
                    body: "The Pagewright has been through the kept pages with clean hands and questionable scissors.\n\nA few pieces are already on the table. Open the spread and arrange what belongs together.",
                    metadata: [
                        "source": "pagewright",
                        "opensPagewright": "true",
                        "pagewrightPageIDs": pages.map(\.id).joined(separator: ","),
                        "symbol": "scissors",
                        "tags": "pagewright,scrapbook,kept-pages,invitation"
                    ]
                )
            )
        ]
    }

    static func pagewrightSeedPages(from days: [BookDay], limit: Int = 3) -> [BookPage] {
        let candidates = days
            .flatMap(\.pages)
            .filter {
                $0.type != .welcome
                    && $0.type != .helpTips
                    && ($0.pagewrightDefaultScrapText != nil || Self.hasPagewrightVisual($0))
            }
            .sorted { lhs, rhs in
                let lhsVisual = Self.hasPagewrightVisual(lhs)
                let rhsVisual = Self.hasPagewrightVisual(rhs)
                if lhsVisual != rhsVisual { return lhsVisual }
                let lhsIlluminated = lhs.type == .illuminatedPhoto
                let rhsIlluminated = rhs.type == .illuminatedPhoto
                if lhsIlluminated != rhsIlluminated { return lhsIlluminated }
                return lhs.createdAt > rhs.createdAt
            }

        var selected: [BookPage] = []
        var selectedTypes: Set<BookPageType> = []
        for page in candidates where selected.count < limit {
            if selected.count < 3 || !selectedTypes.contains(page.type) {
                selected.append(page)
                selectedTypes.insert(page.type)
            }
        }
        if selected.count < limit {
            selected.append(contentsOf: candidates.filter { candidate in
                !selected.contains(where: { $0.id == candidate.id })
            }.prefix(limit - selected.count))
        }
        return selected
    }

    private static func hasPagewrightVisual(_ page: BookPage) -> Bool {
        page.mediaAssets.contains { asset in
            switch asset.kind {
            case .bundledImage, .renderedImageFile, .photoLibraryAsset:
                return true
            case .audioFile:
                return false
            }
        }
    }
}

struct FuelLogPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .fuel)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        let window = FacultyLogCadence.currentWindow(for: now)
        guard !FacultyLogCadence.didLog(kind: .fuel, day: day, entries: inputs.facultyEntries, now: now) else {
            return []
        }

        let detail: String
        switch window.id {
        case "morning":
            detail = "What has crossed the threshold since waking: food, coffee, water, medicine, crumbs, anything."
        case "midday":
            detail = "What has kept the engine lit so far? Approximate is useful."
        case "evening":
            detail = "What did the body receive since the last bell? Meals, snacks, drinks, supplements, no ceremony required."
        default:
            detail = "A gentle closing note for the body: late drinks, bites, medicine, or simply nothing since the last bell."
        }

        return [
            SurfacePage(
                id: "\(source.id)-\(day.id)-\(window.id)",
                type: .fuel,
                sourceID: source.id,
                intent: .capture,
                renderStyle: .promptCard,
                score: context.distress.isActive ? 70 : 66,
                reason: "Dr. Vellum left a plate-note window open for you.",
                prompt: "Dr. Vellum's Plate Note",
                detail: "\(window.name). \(detail)",
                payload: BookPagePayload(
                    headline: "Fuel Log",
                    body: detail,
                    metadata: [
                        "source": source.id,
                        "facultyID": FacultyEntryKind.fuel.facultyID,
                        "facultyKind": FacultyEntryKind.fuel.rawValue,
                        "facultyWindowID": window.id,
                        "facultyWindowName": window.name,
                        "automaticRecurrenceSlot": "\(day.id):\(window.id):fuel",
                        "chartTitle": FacultyEntryKind.fuel.chartTitle,
                        "placeholder": "Breakfast: coffee, toast, water...\nLunch: leftovers, soda...\nMedicine/supplements: ...",
                        "tags": "fuel,faculty-kind:fuel,faculty-window:\(window.id),dr-vellum,vellum-chart,food,drink"
                    ]
                )
            )
        ]
    }
}

struct SupportGuildPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .supportGuild)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard let surface = SupportGuildSynthesisGenerator.surface(for: day, context: context, inputs: inputs, now: now) else {
            return []
        }
        return [surface]
    }
}

struct FacultyResearchPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .facultyResearch)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        if let prepared = inputs.preparedFacultyResearchSurface {
            return [prepared]
        }
        guard let draft = FacultyResearchNoteGenerator.draftCandidate(for: day, inputs: inputs, now: now) else {
            return []
        }
        return [draft]
    }
}

struct SouvenirPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .souvenir)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard let window = DailyCheckInCadence.activeWindow(for: now) else { return [] }
        guard !didCaptureSouvenir(in: window, day: day) else { return [] }
        let eveningPrompt = window.id == "evening"
        let shadowState = ShadowWonder.state(inputs: inputs, now: now)
        let rut = NothingTide.rutAssessment(
            inputs: inputs,
            distressActive: false,
            now: now
        )
        let greyLevel = NothingTide.greyLevel(
            readerRutPressure: rut.mayNameRut ? rut.pressure : 0,
            narrativeHeat: inputs.narrative?.recentEventCount ?? 0,
            distressActive: false,
            celebrationGreyShift: Almanac.greyShift(on: now, hemisphere: inputs.hemisphere)
                + BookJumpEngine.greyShift(state: inputs.bookJump, now: now)
                + RadioStationRegistry.greyShift(state: inputs.radio, now: now)
                + (inputs.faeState.activeGifts.contains { $0.effect == .quieting } ? -1 : 0)
                + inputs.nothingGreyOffset
        )
        var pages = [
            SurfacePage(
                id: "\(source.id)-\(day.id)-\(window.id)",
                type: .souvenir,
                sourceID: source.id,
                intent: .capture,
                renderStyle: .quoteCard,
                score: eveningPrompt ? 78 : 58,
                reason: eveningPrompt ? "Evenings are a cozy time to tuck one little moment away." : "One tiny thing can hold the whole day still.",
                prompt: eveningPrompt ? "What moment do you not want to go blurry?" : "Catch one bright little thing.",
                detail: eveningPrompt ? "One specific sentence, before the day forgets it." : "A color, a sound, a sentence, one small kindness.",
                payload: BookPagePayload(
                    headline: source.title,
                    body: "A small moment worth keeping.",
                    metadata: [
                        "source": source.id,
                        "checkInWindowID": window.id,
                        "checkInWindowName": window.name,
                        "automaticRecurrenceSlot": "\(day.id):\(window.id):souvenir",
                        "tags": "souvenir,check-in-window:\(window.id)"
                    ]
                )
            )
        ]
        if greyLevel >= 2 {
            pages.append(
                SurfacePage(
                    id: "\(source.id)-grey-edge-\(day.id)-\(window.id)",
                    type: .souvenir,
                    sourceID: source.id,
                    intent: .capture,
                    renderStyle: .quoteCard,
                    score: 88 + greyLevel * 3,
                    reason: "The grey is leaning in close, but one true little sentence can turn the light back up.",
                    prompt: "Name one real thing you can reach right now.",
                    detail: "A color, a sound, a texture: one small proof the day isn't empty.",
                    payload: BookPagePayload(
                        headline: "One-Sentence Souvenir",
                        body: "The grey edge is creeping up to the desk. Keep one exact thing it can't squish flat.",
                        metadata: [
                            "source": source.id,
                            "checkInWindowID": window.id,
                            "checkInWindowName": window.name,
                            "automaticRecurrenceSlot": "\(day.id):\(window.id):souvenir",
                            "variant": "grey-edge",
                            "greyLevel": "\(greyLevel)",
                            "tags": "souvenir,grey-edge,check-in-window:\(window.id)"
                        ]
                    )
                )
            )
        }
        if ShadowWonder.shouldSurface(.souvenir, inputs: inputs, now: now) {
            pages.append(
                SurfacePage(
                    id: "\(source.id)-shadow-wonder-\(day.id)-\(window.id)",
                    type: .souvenir,
                    sourceID: source.id,
                    intent: .capture,
                    renderStyle: .quoteCard,
                    score: (eveningPrompt ? 78 : 58) + shadowState.scoreBoost,
                    reason: "Shadow Wonder is awake, so this souvenir can love the worn-out edge instead of scrubbing it shiny.",
                    prompt: "Shadow Souvenir: what worn old thing shouldn't be thrown away?",
                    detail: "One sentence of shadow wonder: rust, a repair, old evidence, quiet grey beauty.",
                    payload: BookPagePayload(
                        headline: "Shadow One-Sentence Souvenir",
                        body: ShadowWonder.souvenirPrompt,
                        metadata: [
                            "source": source.id,
                            "checkInWindowID": window.id,
                            "checkInWindowName": window.name,
                            "automaticRecurrenceSlot": "\(day.id):\(window.id):souvenir",
                            "shadowVariantOf": "\(source.id)-\(day.id)-\(window.id)",
                            "variant": "shadow-wonder",
                            "tags": ShadowWonder.mergedTags("souvenir,check-in-window:\(window.id)", inputs: inputs, now: now)
                        ]
                    )
                )
            )
        }
        return pages
    }

    /// A souvenir already kept in this window, by any route.
    ///
    /// This used to test only for the `check-in-window:` tag, which the
    /// ordinary check-in path writes and nothing else does. The onboarding
    /// souvenir: the reader's first true sentence, kept during the First
    /// Door: carries its own tags and none of that one, so the Book could not
    /// see it and asked for a second sentence immediately afterwards.
    ///
    /// Testing the clock as well as the tag closes that gap for every path,
    /// including any added later.
    private func didCaptureSouvenir(in window: DailyCheckInWindow, day: BookDay) -> Bool {
        let tag = "check-in-window:\(window.id)"
        return day.pages.contains { page in
            guard page.type == .souvenir else { return false }
            return page.tags.contains(tag)
                || DailyCheckInCadence.window(window, contains: page.createdAt)
        }
    }
}

/// A single "Gear Shifter" from Wonder Compass Chapter 10 (Center = Rest): one small,
/// concrete way to move toward awake or deeper rest. The persisted cases retain their
/// old names, but the Page does not claim these practices put a reader into a measured
/// EEG band. It offers one at a time, chosen by the hour and the day's state, never as
/// a task, always as a relief. "Find the one that feels like a relief, not a chore."
struct CenterGearShifter: Equatable {
    enum Gear: String, Equatable {
        case alpha
        case theta

        /// The short label the page shows beside the shifter's name.
        var label: String {
            switch self {
            case .alpha: return "Rest while awake"
            case .theta: return "A longer rest"
            }
        }
    }

    let id: String
    let title: String
    let gear: Gear
    /// The concrete thing to do, phrased as an invitation, not an instruction.
    let move: String
    /// Why it may be worth trying, in the chapter's reassuring voice. This is
    /// an invitation and an honest uncertainty, never a borrowed diagnosis or
    /// guaranteed neural mechanism.
    let why: String
    /// An SF Symbol name for the shifter.
    let symbol: String
}

/// The Chapter-10 menu of Gear Shifters, plus the logic for choosing which one the
/// Center Page leads with given the hour and the day's state.
enum CenterGearShifterMenu {
    // MARK: Awake rest: recharge while staying present.

    static let softGaze = CenterGearShifter(
        id: "soft-gaze",
        title: "Look Across the Room",
        gear: .alpha,
        move: "Look at one spot ahead. Let your eyes relax. Notice what you can see at the sides without turning your head.",
        why: "I’ll wait here.",
        symbol: "eye"
    )

    static let rhythmicLoop = CenterGearShifter(
        id: "rhythmic-loop",
        title: "Something for Your Hands",
        gear: .alpha,
        move: "Draw a few slow circles, shuffle some cards, or knit a row. Choose a movement you already know.",
        why: "Your hands can have something easy to do.",
        symbol: "hand.draw"
    )

    static let fractalSoak = CenterGearShifter(
        id: "fractal-soak",
        title: "Look at a Tree",
        gear: .alpha,
        move: "Look at a tree, a cloud, or some water for a few breaths. Let your eyes wander.",
        why: "I like a view that keeps changing.",
        symbol: "leaf"
    )

    // MARK: Deeper rest: room for quiet and possible breakthroughs.

    static let boredWalk = CenterGearShifter(
        id: "bored-walk",
        title: "A Walk You Know",
        gear: .theta,
        move: "Walk a familiar route. Leave the headphones off for a while.",
        why: "I’ll be here when you get back.",
        symbol: "figure.walk"
    )

    static let auditory = CenterGearShifter(
        id: "auditory-entrainment",
        title: "One Quiet Sound",
        gear: .theta,
        move: "Play a steady sound at a low volume. Rain, a fan, or the sea. Choose one you like.",
        why: "Keep the sound quiet enough to hear the room too.",
        symbol: "headphones"
    )

    static let noddies = CenterGearShifter(
        id: "the-noddies",
        title: "Lie Down a While",
        gear: .theta,
        move: "Find somewhere comfortable to lie down. Close your eyes for a while.",
        why: "I can keep your place.",
        symbol: "moon.zzz"
    )

    /// Every shifter, in menu order, so the page can cycle through them when the
    /// reader asks for another.
    static let all: [CenterGearShifter] = [
        softGaze, rhythmicLoop, fractalSoak, boredWalk, auditory, noddies
    ]

    static func shifter(id: String) -> CenterGearShifter? {
        all.first { $0.id == id }
    }

    /// Pick the shifter the Center Page leads with. Distress gets the gentlest
    /// invitation; evenings lean toward deeper rest; daytime offers awake
    /// recharges. The `seed` rotates the choice within a pool day to day.
    static func choose(hour: Int, distressActive: Bool, daylight: Bool, seed: Int) -> CenterGearShifter {
        if distressActive {
            // The fastest, lowest-effort relief when the day is already too much.
            return softGaze
        }
        let evening = hour >= 20 || hour < 6
        let pool: [CenterGearShifter]
        if evening {
            pool = daylight ? [boredWalk, auditory, noddies] : [auditory, noddies]
        } else if daylight {
            pool = [fractalSoak, rhythmicLoop, softGaze, boredWalk]
        } else {
            pool = [rhythmicLoop, softGaze, auditory]
        }
        let index = ((seed % pool.count) + pool.count) % pool.count
        return pool[index]
    }
}

/// A quiet opening. The practice controls carry their own instructions.
enum CenterPageCopy {
    static let body = """
    Sit. I'll guard the door.
    """
}

struct RestPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .rest)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        let hour = Calendar.current.component(.hour, from: now)
        // Being handed an unasked-for quiet moment in the middle of an ordinary
        // day is a gift; waiting for distress, an empty day, or nightfall makes
        // the Center Page a remedy the reader only meets when something is
        // already wrong. Roughly one afternoon in four it simply opens.
        let surpriseQuiet = (13..<19).contains(hour)
            && abs("\(day.id)-center-page-gift".stableHash.stableScramble % 4) == 0
        guard context.distress.isActive
                || context.bleed.pageBias.first == .rest
                || day.capturedPages.isEmpty
                || hour >= 20
                || surpriseQuiet else {
            return []
        }
        let daylight = (7..<19).contains(hour)
        let gear = CenterGearShifterMenu.choose(
            hour: hour,
            distressActive: context.distress.isActive,
            daylight: daylight,
            seed: day.id.stableHash
        )
        var pages = [
            SurfacePage(
                type: .rest,
                sourceID: source.id,
                intent: .rest,
                renderStyle: .gentleTranslation,
                score: context.distress.isActive ? 96 : (context.bleed.pageBias.first == .rest ? 88 : 62),
                reason: context.distress.isActive ? "I turn the lamps down low before I offer you anything else." : "Sometimes the day just needs a quiet middle to rest in.",
                prompt: "The Center Page just opened.",
                detail: "Sit. I’ll guard the door.",
                payload: BookPagePayload(
                    headline: "Center Page",
                    body: CenterPageCopy.body,
                    metadata: [
                        "source": source.id,
                        "centerGearID": gear.id
                    ]
                )
            )
        ]
        // Shadow Wonder: the Center kept by lamplight: Quiet Hours in the dark,
        // rest as the still center of the dark Compass rather than a failure to adventure.
        let shadow = ShadowWonder.state(inputs: inputs, now: now)
        if ShadowWonder.shouldSurface(.rest, inputs: inputs, now: now) {
            pages.append(
                SurfacePage(
                    id: "\(source.id)-shadow-rest",
                    type: .rest,
                    sourceID: source.id,
                    intent: .rest,
                    renderStyle: .gentleTranslation,
                    score: (context.distress.isActive ? 96 : (context.bleed.pageBias.first == .rest ? 88 : 62)) + shadow.scoreBoost,
                    reason: "Shadow Wonder keeps the Center lit by one small lamp; resting is the still, quiet middle of the dark Compass.",
                    prompt: "Quiet Hours just opened in the dark.",
                    detail: "I left a place for you by the lamp.",
                    payload: BookPagePayload(
                        headline: "Center Page",
                        body: CenterPageCopy.body,
                        metadata: [
                            "source": source.id,
                            "centerGearID": gear.id,
                            "shadowVariantOf": "\(source.id)-rest",
                            "variant": "shadow-wonder",
                            "tags": ShadowWonder.mergedTags("center,rest,quiet-hours", inputs: inputs, now: now)
                        ]
                    )
                )
            )
        }
        return pages
    }
}

struct BookOfYouPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .bookOfYou)

    /// The very first braid of an install is allowed to arrive early: as soon
    /// as a few pages are kept, so a reader who onboards in the morning still
    /// sees the write → read-back loop close in the same session. Every braid
    /// after this one waits for the evening rhythm.
    static let firstBraidPageThreshold = 3

    /// The braid always surfaces once its hour comes.
    ///
    /// This used to also require pending pages - anything kept since the last
    /// braid - so a night the reader kept nothing offered no braid at all. That
    /// contradicts the closed-day page the writer already knows how to make:
    /// the plan has `quietDayBeats`, the floor has a line for the day the Book
    /// stayed shut and a colophon to close it, and the whole point was that a
    /// reader flipping back to a day they never opened should still find the
    /// Book had one. A gate above that machinery meant it could never be
    /// reached.
    ///
    /// Pending pages still decide the *first* braid, which fires early in the
    /// first session rather than waiting for evening, and there a threshold is
    /// the right test: that braid exists to close the write-and-read-back loop,
    /// so it needs something written to read back.
    static func mayShowBraid(for day: BookDay, previousDays: [BookDay], now: Date) -> Bool {
        guard day.bookOfYou == nil else { return false }
        if BookSchedule.isBraidSurfaceTime(now) { return true }
        let pendingPages = NightlyBraidWindow.pendingPages(
            for: day,
            previousDays: previousDays,
            now: now
        )
        let everBraided = (previousDays + [day]).contains { $0.bookOfYou != nil }
        return !everBraided && pendingPages.count >= firstBraidPageThreshold
    }

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard Self.mayShowBraid(for: day, previousDays: inputs.days, now: now) else {
            return []
        }
        let pendingPageCount = NightlyBraidWindow.pendingPages(
            for: day,
            previousDays: inputs.days,
            now: now
        ).count
        let title = WonderTitleRegistry.earnedTitle(from: inputs.selfFacts)
        var metadata = [
            "source": source.id,
            "automaticRecurrenceSlot": "\(day.id):book-of-you"
        ]
        if let title {
            metadata.merge(title.metadata) { _, new in new }
        }
        let titleLine = title.map { " A \($0.name) braid should show its receipts." } ?? ""
        return [
            SurfacePage(
                type: .bookOfYou,
                sourceID: source.id,
                intent: .braid,
                renderStyle: .loreLetter,
                score: pendingPageCount >= 3 ? 90 : (pendingPageCount == 0 ? 68 : 74),
                // A night with nothing kept must not be told that a few little
                // bits have been waiting. The Book claiming something untrue is
                // its own bug class, and this page is exactly the one where the
                // reader can check.
                reason: {
                    if pendingPageCount >= 3 {
                        return "There are enough loose little bits now to braid something really strong."
                    }
                    if pendingPageCount == 0 {
                        return "You kept nothing loose today. I had the day anyway."
                    }
                    return "A few little bits have been waiting since the last braid."
                }(),
                prompt: pendingPageCount == 0
                    ? "I want to write today down even though you gave me nothing."
                    : (title.map { "I want to braid what's loose into a \($0.name) page." } ?? "I want to braid what's loose."),
                detail: pendingPageCount == 0
                    ? "Nothing of yours came in today. The page is mine to fill.\(titleLine)"
                    : "Gather the loose bits since the last braid into one page worth keeping.\(titleLine)",
                payload: BookPagePayload(
                    headline: "Book of You",
                    body: pendingPageCount == 0
                        ? "Nothing of yours to braid tonight. I will write what the day did without you."
                        : (title.map { "Gather the loose fragments into one \($0.name) page worth keeping.\n\n\($0.compassLine)" } ?? "Gather the loose fragments into one page worth keeping."),
                    metadata: metadata
                )
            )
        ]
    }
}

enum ReturnedStackRole: String, Codable, CaseIterable {
    case rhyme
    case longMemory
    case wildCard

    var title: String {
        switch self {
        case .rhyme: return "The Rhyme"
        case .longMemory: return "The Long Memory"
        case .wildCard: return "The Wild Card"
        }
    }

    var subtitle: String {
        switch self {
        case .rhyme: return "Something in the recent margins called this back."
        case .longMemory: return "The Stacks refuse to let a long silence become disappearance."
        case .wildCard: return "One page returns without having to justify itself."
        }
    }

    var symbolName: String {
        switch self {
        case .rhyme: return "point.3.connected.trianglepath.dotted"
        case .longMemory: return "lamp.desk"
        case .wildCard: return "sparkles"
        }
    }
}

struct ReturnedStackCard: Identifiable, Equatable {
    var page: BookPage
    var role: ReturnedStackRole
    var reason: String
    var tinyAction: String

    var id: String { page.id }
}

/// The daily ritual behind Returned From the Stacks.
///
/// Its three chairs have different laws: a recent rhyme, a page that has waited
/// longest for light, and one sanctioned surprise. Selection is deterministic
/// for the calendar day and persisted by `BookArchiveDatabase`, so opening the
/// fold does not reshuffle it. Recent returns rest before they may be selected
/// again, with a shorter emergency rest only when a young archive would
/// otherwise leave a chair empty.
enum ReturnedStacksRitual {
    static let surfacePrefix = "returned-stacks"
    static let preferredRestDays = 14
    static let emergencyRestDays = 3

    private struct Connection {
        var score: Int
        var reason: String
    }

    static func surfaceName(role: ReturnedStackRole, index: Int) -> String {
        "\(surfacePrefix):\(index):\(role.rawValue)"
    }

    static func isEligible(_ page: BookPage) -> Bool {
        let excludedTypes: Set<BookPageType> = [
            .mood, .rest, .body, .fuel, .weather,
            .bookOfYou, .bookRemembered, .bookPocket,
            .helpTips, .welcome, .inventory, .bindery,
            .radio, .calendar, .todaysSky
        ]
        guard !excludedTypes.contains(page.type),
              page.privacy != .localSensitive,
              let preview = page.archivePreviewText?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              preview.count >= 12 else {
            return false
        }
        return true
    }

    static func cards(
        from days: [BookDay],
        history: [BookArchiveResurfacing],
        now: Date = Date(),
        calendar: Calendar = .current,
        limit: Int = 3
    ) -> [ReturnedStackCard] {
        guard limit > 0 else { return [] }
        let startOfToday = calendar.startOfDay(for: now)
        let allPages = days
            .flatMap(\.pages)
            .filter { $0.createdAt < startOfToday && isEligible($0) }
        let pagesByID = Dictionary(uniqueKeysWithValues: allPages.map { ($0.id, $0) })

        let todaysHistory = history
            .filter {
                $0.surface.hasPrefix(surfacePrefix)
                    && $0.surfacedAt >= startOfToday
                    && $0.surfacedAt <= now
            }
            .sorted { historyIndex($0.surface) < historyIndex($1.surface) }
        var cards = todaysHistory.compactMap { event -> ReturnedStackCard? in
            guard let page = pagesByID[event.pageID] else { return nil }
            return ReturnedStackCard(
                page: page,
                role: historyRole(event.surface) ?? .wildCard,
                reason: event.reason,
                tinyAction: tinyAction(for: page)
            )
        }
        if cards.count >= limit {
            return Array(cards.prefix(limit))
        }

        let selectedIDs = Set(cards.map(\.page.id))
        let returnedAtByPageID = history
            .filter { $0.surface.hasPrefix(surfacePrefix) }
            .reduce(into: [String: Date]()) { result, event in
                result[event.pageID] = max(result[event.pageID] ?? .distantPast, event.surfacedAt)
            }
        let references = referencePages(from: days, before: now, calendar: calendar)
        let preferredCutoff = calendar.date(byAdding: .day, value: -preferredRestDays, to: now)
            ?? now.addingTimeInterval(TimeInterval(-preferredRestDays) * 86_400)
        let emergencyCutoff = calendar.date(byAdding: .day, value: -emergencyRestDays, to: now)
            ?? now.addingTimeInterval(TimeInterval(-emergencyRestDays) * 86_400)

        func available(afterRestingSince cutoff: Date) -> [BookPage] {
            allPages.filter { page in
                !selectedIDs.contains(page.id)
                    && (returnedAtByPageID[page.id] ?? .distantPast) < cutoff
            }
        }

        var pool = available(afterRestingSince: preferredCutoff)
        if pool.count < limit - cards.count {
            pool = available(afterRestingSince: emergencyCutoff)
        }
        if pool.count < limit - cards.count {
            pool = allPages.filter { !selectedIDs.contains($0.id) }
        }

        let missingRoles = ReturnedStackRole.allCases.filter { role in
            !cards.contains { $0.role == role }
        }
        var usedTypes = Set(cards.map(\.page.type))
        for role in missingRoles where cards.count < limit {
            guard !pool.isEmpty else { break }
            let choice: BookPage
            let reason: String
            switch role {
            case .rhyme:
                let ranked = pool
                    .map { ($0, connection(for: $0, references: references, now: now, calendar: calendar)) }
                    .sorted { left, right in
                        if left.1.score == right.1.score {
                            return stableDailyRank(pageID: left.0.id, now: now, calendar: calendar)
                                < stableDailyRank(pageID: right.0.id, now: now, calendar: calendar)
                        }
                        return left.1.score > right.1.score
                    }
                guard let best = ranked.first else { continue }
                choice = best.0
                reason = best.1.reason
            case .longMemory:
                choice = pool.sorted { left, right in
                    let leftReturn = returnedAtByPageID[left.id] ?? .distantPast
                    let rightReturn = returnedAtByPageID[right.id] ?? .distantPast
                    if leftReturn == rightReturn { return left.createdAt < right.createdAt }
                    return leftReturn < rightReturn
                }[0]
                reason = longMemoryReason(
                    for: choice,
                    lastReturnedAt: returnedAtByPageID[choice.id],
                    now: now,
                    calendar: calendar
                )
            case .wildCard:
                let diverse = pool.filter { !usedTypes.contains($0.type) }
                let choices = diverse.isEmpty ? pool : diverse
                choice = choices.min {
                    stableDailyRank(pageID: $0.id, now: now, calendar: calendar)
                        < stableDailyRank(pageID: $1.id, now: now, calendar: calendar)
                } ?? choices[0]
                reason = wildCardReason(for: choice, now: now, calendar: calendar)
            }

            cards.append(
                ReturnedStackCard(
                    page: choice,
                    role: role,
                    reason: reason,
                    tinyAction: tinyAction(for: choice)
                )
            )
            pool.removeAll { $0.id == choice.id }
            usedTypes.insert(choice.type)
        }
        return Array(cards.prefix(limit))
    }

    private static func referencePages(
        from days: [BookDay],
        before now: Date,
        calendar: Calendar
    ) -> [BookPage] {
        let recentCutoff = calendar.date(byAdding: .day, value: -4, to: now)
            ?? now.addingTimeInterval(-4 * 86_400)
        return days
            .flatMap(\.pages)
            .filter {
                $0.createdAt >= recentCutoff
                    && $0.createdAt <= now
                    && isEligible($0)
            }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(12)
            .map { $0 }
    }

    private static func connection(
        for page: BookPage,
        references: [BookPage],
        now: Date,
        calendar: Calendar
    ) -> Connection {
        if let semantic = references.first(where: {
            $0.tags.contains("\(SemanticKeepEcho.sourceTagPrefix)\(page.id)")
        }), let line = semantic.tags
            .first(where: { $0.hasPrefix(SemanticKeepEcho.lineTagPrefix) })
            .map({ String($0.dropFirst(SemanticKeepEcho.lineTagPrefix.count)) })
            .flatMap(\.nonEmpty) {
            return Connection(score: 140, reason: line)
        }

        let pageWords = meaningfulWords(in: page.archivePreviewText ?? "")
        let wordMatches = references.compactMap { reference -> (BookPage, String)? in
            let overlap = pageWords.intersection(meaningfulWords(in: reference.archivePreviewText ?? ""))
            guard let word = overlap.sorted(by: {
                if $0.count == $1.count { return $0 < $1 }
                return $0.count > $1.count
            }).first else { return nil }
            return (reference, word)
        }
        if let match = wordMatches.sorted(by: { $0.1.count > $1.1.count }).first {
            let when = relativeDay(match.0.createdAt, now: now, calendar: calendar)
            return Connection(
                score: 90 + match.1.count,
                reason: "\(when) used “\(match.1)” again. The Stacks heard the rhyme."
            )
        }

        if let pageContext = page.context {
            for reference in references {
                guard let referenceContext = reference.context else { continue }
                let sharedWeather = Set(pageContext.weatherTags).intersection(referenceContext.weatherTags)
                if let weather = sharedWeather.sorted().first {
                    return Connection(
                        score: 76,
                        reason: "\(relativeDay(reference.createdAt, now: now, calendar: calendar)) carried \(weather) too: the same weather that pressed this page."
                    )
                }
                if let anchor = pageContext.nearbyAnchorID,
                   anchor == referenceContext.nearbyAnchorID {
                    return Connection(
                        score: 70,
                        reason: "A recent page was kept near the same Anchor. The place remembered this one."
                    )
                }
                if pageContext.dayPart == referenceContext.dayPart {
                    return Connection(
                        score: 42,
                        reason: "A recent \(referenceContext.dayPart) page struck the same hour-bell as this one."
                    )
                }
            }
        }

        let month = calendar.component(.month, from: page.createdAt)
        if month == calendar.component(.month, from: now) {
            return Connection(
                score: 36,
                reason: "The year has reached the month that first held this page. The light is leaning the same way."
            )
        }
        let weekday = calendar.component(.weekday, from: page.createdAt)
        if weekday == calendar.component(.weekday, from: now) {
            return Connection(
                score: 30,
                reason: "This was written on the same turn of the week. The calendar left the door unlatched."
            )
        }
        return Connection(
            score: 20 + (page.usedInBookOfYou ? 8 : 0),
            reason: "A recent margin and this page share no obvious word. I'm keeping the quieter rhyme."
        )
    }

    private static func longMemoryReason(
        for page: BookPage,
        lastReturnedAt: Date?,
        now: Date,
        calendar: Calendar
    ) -> String {
        if let lastReturnedAt {
            let days = ageDays(from: lastReturnedAt, to: now, calendar: calendar)
            return "This page has rested \(days) day\(days == 1 ? "" : "s") since its last return. Its lamp is due."
        }
        let days = ageDays(from: page.createdAt, to: now, calendar: calendar)
        return "This page has waited \(days) day\(days == 1 ? "" : "s") without once being called upstairs."
    }

    private static func wildCardReason(for page: BookPage, now: Date, calendar: Calendar) -> String {
        let month = page.createdAt.formatted(.dateTime.month(.wide))
        let year = calendar.component(.year, from: page.createdAt)
        let sameYear = year == calendar.component(.year, from: now)
        let when = sameYear ? month : "\(month) \(year)"
        return "One return each day is chosen by chance, so I can't get predictable. Today’s fell open to \(when)."
    }

    private static func tinyAction(for page: BookPage) -> String {
        let text = "\(page.archivePreviewText ?? "") \(page.tags.joined(separator: " "))".lowercased()
        if text.contains("walk") || text.contains("outside") || text.contains("trail") {
            return "Step to the nearest threshold and see what the old page notices now."
        }
        if text.contains("coffee") || text.contains("tea") || text.contains("cup") {
            return "Let your next cup become completely real in your hand before the first sip."
        }
        if text.contains("friend") || text.contains("family") || page.type == .letter {
            return "Send one small warmth toward the person in this page, even if it stays silent."
        }
        if page.type == .wonderCompass || page.type == .location {
            return "Look up and name one direction the day could still take."
        }
        return "Look up from me and find one physical detail this page would understand."
    }

    private static func meaningfulWords(in text: String) -> Set<String> {
        Set(
            text.lowercased()
                .split { !$0.isLetter && !$0.isNumber }
                .map(String.init)
                .filter { $0.count >= 5 && !KeepMarginalia.stopWords.contains($0) }
        )
    }

    private static func relativeDay(_ date: Date, now: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(date) { return "Today’s margin" }
        if calendar.isDateInYesterday(date) { return "Yesterday’s margin" }
        let days = ageDays(from: date, to: now, calendar: calendar)
        return "A margin from \(days) days ago"
    }

    private static func ageDays(from date: Date, to now: Date, calendar: Calendar) -> Int {
        max(
            1,
            calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: date),
                to: calendar.startOfDay(for: now)
            ).day ?? 1
        )
    }

    private static func stableDailyRank(pageID: String, now: Date, calendar: Calendar) -> UInt64 {
        KeepMarginalia.seed(for: "\(BookDay.id(for: now, calendar: calendar))-\(pageID)-returned-stacks")
    }

    private static func historyIndex(_ surface: String) -> Int {
        let parts = surface.split(separator: ":")
        guard parts.count >= 2 else { return .max }
        return Int(parts[1]) ?? .max
    }

    private static func historyRole(_ surface: String) -> ReturnedStackRole? {
        let parts = surface.split(separator: ":")
        guard let raw = parts.last else { return nil }
        return ReturnedStackRole(rawValue: String(raw))
    }
}

struct BookRememberedPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .bookRemembered)
    /// How long a returned archive page rests before the Book may return it
    /// again. A remembered page should feel found, not scheduled.
    static let rememberedRestDays = 45

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard inputs.libraryReadyForReflectivePages(includingToday: day, now: now) else { return [] }
        guard !didRememberToday(day) else { return [] }
        let archive = inputs.days + [day]
        let restingPageIDs = ArchiveMemo.value(
            "remembered.resting", days: archive, salt: day.id
        ) {
            Self.rememberedPageIDs(days: archive, within: Self.rememberedRestDays, now: now)
        }
        let owedEvidence = EarnedReaderTracePolicy.owedEvidencePage(
            day: day,
            inputs: inputs,
            distressActive: context.distress.isActive,
            now: now
        )
        // Choosing which kept Page to return scores the whole archive, and the
        // answer cannot change until the archive does or the day turns. The
        // cadence slot is in the key so the choice still moves through the day
        // rather than being frozen at breakfast.
        // The grimoire is in the salt because it is now one of the reasons a
        // Page comes back: when a rule is crossed out or rested, the memo must
        // not keep serving the visitation that leaned on it.
        let grimoireSalt = inputs.grimoire.rows.values.reduce(into: 0) { total, row in
            total &+= row.state.rawValue.stableHash
        }
        let visitationSalt = "\(day.id)|\(SurfaceCadence.slotID(for: now, hours: 2))|\(owedEvidence?.id ?? "")|\(grimoireSalt)"
        guard let visitation = ArchiveMemo.value(
            "remembered.visitation", days: archive, salt: visitationSalt, compute: {
                BookRememberedEngine.visitation(
                    from: inputs.resurfacingCandidates.filter { !restingPageIDs.contains($0.id) },
                    day: day,
                    inputs: inputs,
                    now: now,
                    priorityPageID: owedEvidence?.id
                )
            }
        ) else {
            return []
        }
        return [visitation.surface(source: source, day: day, now: now)]
    }

    private func didRememberToday(_ day: BookDay) -> Bool {
        day.pages.contains { page in
            page.type == .bookRemembered || page.tags.contains("book-remembered")
        }
    }

    /// Page IDs recently returned by Book Remembered, recovered from the kept
    /// page tags (`remembered-page:<id>`), so no separate vault flag is needed.
    static func rememberedPageIDs(days: [BookDay], within restDays: Int, now: Date) -> Set<String> {
        let cutoff = now.addingTimeInterval(TimeInterval(-restDays) * 86_400)
        return Set(
            days.flatMap(\.pages)
                .filter { $0.createdAt >= cutoff && $0.createdAt <= now }
                .flatMap(\.tags)
                .compactMap { tag in
                    tag.hasPrefix("remembered-page:") ? String(tag.dropFirst("remembered-page:".count)) : nil
                }
        )
    }
}

/// The Front Matter: everything the Book actually holds about the reader, shown
/// to them so it can be argued with.
///
/// A permanent record of someone that they cannot inspect or amend is the bad
/// version of this whole apparatus, so the page exists to be corrected. It waits
/// until there is genuinely something to show: a nearly-empty sheet read back
/// is worse than silence, and then rests a long time, because this is a page
/// about who someone is and it should feel rare.
struct FrontMatterPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .frontMatter)

    /// Days before the Book offers to show its front pages again.
    static let restDays = 45

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        let sheet = inputs.readersSheet
        guard sheet.isWorthSpeakingTo else { return [] }
        guard inputs.libraryReadyForReflectivePages(includingToday: day, now: now) else { return [] }
        guard !Self.shownRecently(days: inputs.days + [day], now: now) else { return [] }

        // Keyed to what it would actually say, so a sheet that has not changed
        // cannot come back wearing a new id.
        let fingerprint = Self.fingerprint(of: sheet)
        var metadata = [
            "source": source.id,
            "frontMatterFingerprint": fingerprint,
            "invitesCorrection": "true",
            "responseLabel": "Correct me",
            "placeholder": "Write what I got wrong. I will keep your correction with this Page.",
            "tags": "front-matter,readers-sheet,local-memory,correctable"
        ]
        for section in sheet.readerFacingSections {
            metadata["frontMatterSection.\(section.id)"] = section.text
        }
        return [
            SurfacePage(
                id: "\(source.id)-\(fingerprint)",
                type: .frontMatter,
                sourceID: source.id,
                intent: .resurface,
                renderStyle: .loreLetter,
                score: 34,
                reason: "I wrote down what I know about you. You get to see it and correct it.",
                prompt: "This is what I know about you.",
                detail: "Read it. Cross out the wrong bits.",
                payload: BookPagePayload(
                    headline: "What I Know About You",
                    body: sheet.readerFacingBody,
                    metadata: metadata
                )
            )
        ]
    }

    static func shownRecently(days: [BookDay], now: Date) -> Bool {
        let cutoff = now.addingTimeInterval(TimeInterval(-restDays) * 86_400)
        return days.flatMap(\.pages).contains { page in
            page.createdAt >= cutoff
                && (page.type == .frontMatter || page.tags.contains("front-matter"))
        }
    }

    /// A stable digest of what the sheet would say. Two sheets that would read
    /// identically produce the same id, so an unchanged reader is not offered
    /// their own front matter twice.
    static func fingerprint(of sheet: ReadersSheet) -> String {
        let parts: [String] = [
            sheet.role?.signature ?? "no-role",
            sheet.transformationClause ?? "",
            sheet.seasonName ?? "",
            sheet.quill?.id ?? "",
            sheet.activeScars.map(\.id).sorted().joined(separator: ","),
            sheet.namedPeople.sorted().joined(separator: ","),
            sheet.openThreads.map(\.id).sorted().joined(separator: ","),
            "\(sheet.openBargainCount)",
            "\(sheet.outstandingWagers.count)"
        ]
        return String(format: "%08x", abs(parts.joined(separator: "|").stableHash))
    }
}

/// Surfaces "My Pocket" now and then, once a few keepsakes have gathered
/// from pages the reader swiped away. The surface id is keyed to the keepsake
/// count, so adding a keepsake creates a fresh Pocket Page even while an earlier
/// pocketful is resting after dismissal.
struct BookPocketPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .bookPocket)

    static let openingTitle = "Look what I kept."
    static let openingLine = "You let these pages go. I saved a few scraps."

    /// The pocket needs to gather a little before it's worth emptying out.
    static let minimumKeepsakes = 2
    /// How many keepsakes the emptied-out letter shows at once.
    static let shownKeepsakes = 8

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        let pocket = inputs.pocket
        guard pocket.count >= Self.minimumKeepsakes else { return [] }
        guard !openedPocketToday(day) else { return [] }

        let shown = Array(pocket.newestFirst.prefix(Self.shownKeepsakes))
        let latest = shown.first
        // Keyed to the count so a newly filled pocket is distinct from the last.
        let surfaceID = "\(source.id)-\(pocket.count)"
        let score = min(60, 40 + pocket.count * 2)
        let serialized = shown.map { keepsake in
            [keepsake.glyph, keepsake.object, keepsake.pageType.shortTitle, "\(keepsake.foundAt.timeIntervalSince1970)"]
                .joined(separator: "\u{1F}")
        }.joined(separator: "\n")
        let richKeepsakes = PocketKeepsakeArchive.encode(shown)

        return [
            SurfacePage(
                id: surfaceID,
                type: .bookPocket,
                sourceID: source.id,
                intent: .resurface,
                renderStyle: .loreLetter,
                score: score,
                reason: latest.map { "I've been keeping \($0.object) and a few other small things." }
                    ?? "I turn out my Pocket.",
                prompt: Self.openingTitle,
                detail: shown.prefix(2).map(\.object).joined(separator: ", "),
                payload: BookPagePayload(
                    headline: "My Pocket",
                    body: Self.body(for: shown, total: pocket.count),
                    metadata: [
                        "source": source.id,
                        "pocketItems": serialized,
                        PocketKeepsakeArchive.metadataKey: richKeepsakes,
                        "pocketTotal": "\(pocket.count)",
                        "tags": "book-pocket,keepsake,parting-whisper,local-memory"
                    ]
                )
            )
        ]
    }

    private func openedPocketToday(_ day: BookDay) -> Bool {
        day.pages.contains { $0.type == .bookPocket || $0.tags.contains("book-pocket") }
    }

    static func body(for keepsakes: [PocketKeepsake], total: Int) -> String {
        let opener = openingLine
        let lines = keepsakes.map { keepsake in
            let title = keepsake.title?.nonEmpty ?? keepsake.object
            let excerpt = keepsake.excerpt?.nonEmpty.map { ", \u{201C}\($0)\u{201D}" } ?? ""
            return "\u{2022} \(title), from the \(keepsake.pageType.shortTitle.lowercased()) Page\(excerpt)"
        }
        let more = total > keepsakes.count ? "\n\n(\(total - keepsakes.count) more wait deeper in the lining.)" : ""
        return opener + "\n\n" + lines.joined(separator: "\n") + more
    }
}

/// Modest opening guesses about things the reader can recognize. Confirmation
/// records their answer, not a discovered personality trait. Later pages may
/// recall that answer; keyword overlap never proves a claim about the reader.
enum FirstWagers {
    struct Wager: Identifiable, Equatable {
        let id: String
        /// The guess, in the Book's voice, addressed to the reader.
        let guess: String
        /// The topic, retained for compatibility with the opening catalog.
        let trait: String
        /// Whole words or phrases that can recall a confirmed opening answer.
        /// They select a callback; they do not establish that the guess is true.
        let receiptKeywords: [String]
        /// A plain topic label for the answer.
        let receiptLead: String
    }

    static let confirmedTag = "first-wager"

    static let all: [Wager] = [
        Wager(
            id: "notices",
            guess: "You’ve stopped to look at something everyone else walked past.",
            trait: "something you stopped to look at",
            receiptKeywords: ["noticed", "stopped", "looked", "saw"],
            receiptLead: "Something you noticed"
        ),
        Wager(
            id: "keeper",
            guess: "You’ve kept something that looks like rubbish to everyone else.",
            trait: "something you kept",
            receiptKeywords: ["kept", "ticket", "shell", "stone", "wrapper"],
            receiptLead: "Something you kept"
        ),
        Wager(
            id: "tired-but-here",
            guess: "There’s a place you like to sit where nobody asks you anything.",
            trait: "a place you like to sit",
            receiptKeywords: ["sat", "sit", "bench", "chair", "sofa"],
            receiptLead: "A place to sit"
        ),
        Wager(
            id: "beauty-seeker",
            guess: "You’ve taken a photograph of the sky.",
            trait: "a photograph of the sky",
            receiptKeywords: ["sky", "sunset", "cloud", "clouds", "moon", "gold light"],
            receiptLead: "Something in the sky"
        ),
        Wager(
            id: "words-person",
            guess: "There’s a sentence you’ve written down because you wanted to keep it.",
            trait: "a sentence you kept",
            receiptKeywords: ["sentence", "wrote", "words", "note"],
            receiptLead: "A sentence you kept"
        ),
        Wager(
            id: "quiet-strength",
            guess: "You own something you’ve mended instead of throwing it away.",
            trait: "something you mended",
            receiptKeywords: ["mended", "repaired", "fixed", "sewed", "patched"],
            receiptLead: "Something you mended"
        ),
    ]

    static func wager(id: String) -> Wager? { all.first { $0.id == id } }

    static func questionID(for id: String) -> String { "onboarding-wager-\(id)" }

    static func wager(forQuestionID questionID: String) -> Wager? {
        let prefix = "onboarding-wager-"
        guard questionID.hasPrefix(prefix) else { return nil }
        return wager(id: String(questionID.dropFirst(prefix.count)))
    }

    /// A stable three for this install, so the reader always sees the same set
    /// and the payoff can reference exactly what it guessed.
    static func three(seed: String) -> [Wager] {
        guard all.count > 3 else { return all }
        let start = Int(abs(seed.stableHash) % all.count)
        return (0..<3).map { all[(start + $0) % all.count] }
    }
}

enum FirstReading {
    /// The first time the Book claims to have read the reader should feel
    /// earned by a small shelf, not triggered by one enthusiastic sitting.
    static let minimumReflectablePages = 6
    static let minimumReflectableDays = 3
    static let minimumDaysSinceFirstPage = 2
    static let maximumReflectablePages = 11

    struct Reflection: Equatable {
        var pageCount: Int
        var dayCount: Int
        var fragments: [String]
        var threadWord: String?
        var threadCount: Int
    }

    /// Body and fuel logs stay out of the Book's commentary, matching
    /// `EditionCurator` and `KeepMarginalia`.
    static func reflectablePages(in inputs: BookSourceInputs, today: BookDay) -> [BookPage] {
        var days = inputs.days
        if let existing = days.firstIndex(where: { $0.id == today.id }) {
            days[existing] = today
        } else {
            days.append(today)
        }
        return reflectablePages(in: days)
    }

    /// The same privacy boundary over an already assembled Book. Keeping this
    /// overload here lets the app detect the exact Keep that wakes the First
    /// Reading without reimplementing its eligibility rules in SwiftUI.
    static func reflectablePages(in days: [BookDay]) -> [BookPage] {
        // Every kept Page, copied. Read on the keep path to notice the moment
        // the third one lands, so it is held for the archive that produced it.
        ArchiveMemo.value("first-reading.reflectable", days: days) {
            days
                .flatMap(\.capturedPages)
                .filter { !EditionCurator.defaultPrivateTypes.contains($0.type) }
        }
    }

    /// Keep-time milestone checks need only the count. Do not materialize a
    /// second archive-sized `[BookPage]` just to throw every value away after
    /// reading `.count`; the full collection remains available to the Page
    /// adapter when it actually needs the reader's fragments.
    static func reflectablePageCount(in days: [BookDay]) -> Int {
        ArchiveMemo.value("first-reading.reflectable-count", days: days) {
            days.reduce(into: 0) { count, day in
                count += day.capturedPages.lazy.filter {
                    !EditionCurator.defaultPrivateTypes.contains($0.type)
                }.count
            }
        }
    }

    /// Concrete words honest enough to name a thread around: things a reader
    /// would recognise as "a thing," never moods or filler.
    static let threadLexicon: [String] = [
        "rain", "snow", "fog", "mist", "wind", "sun", "moon", "cloud", "storm",
        "sky", "dusk", "dawn", "night", "star", "stars",
        "kitchen", "window", "door", "street", "garden", "porch", "room", "car",
        "road", "shore", "harbor", "water", "sea", "river",
        "cup", "mug", "book", "page", "lamp", "key", "candle", "photo", "letter",
        "coffee", "tea", "light", "shadow", "music", "song",
        "mother", "father", "dog", "cat", "friend", "home"
    ]

    static func reflection(for pages: [BookPage], now: Date = Date(), calendar: Calendar = .current) -> Reflection? {
        guard pages.count >= 3 else { return nil }
        let dayCount = Set(pages.map { BookDay.id(for: $0.createdAt, calendar: calendar) }).count
        let fragments = self.fragments(from: pages)
        guard fragments.count >= 2 else { return nil }
        let (word, count) = thread(in: pages)
        return Reflection(
            pageCount: pages.count,
            dayCount: max(1, dayCount),
            fragments: fragments,
            threadWord: word,
            threadCount: count
        )
    }

    /// Up to three ways to name the reader's kept pages back to them, most vivid
    /// first. Pages with real prose are quoted in the reader's own words;
    /// wordless logs are named by what they are.
    static func fragments(from pages: [BookPage]) -> [String] {
        let ranked = pages.sorted { a, b in
            let sa = StorySpark.score(text(of: a))
            let sb = StorySpark.score(text(of: b))
            if sa == sb { return a.createdAt > b.createdAt }
            return sa > sb
        }
        var seen: Set<String> = []
        var out: [String] = []
        for page in ranked {
            let fragment = self.fragment(for: page)
            let key = fragment.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            out.append(fragment)
            if out.count == 3 { break }
        }
        return out
    }

    private static func text(of page: BookPage) -> String {
        page.bindingBodyText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func fragment(for page: BookPage) -> String {
        if let evidence = page.primaryReaderReadableEvidence,
           !evidence.mayQuoteAsReaderWords {
            return evidence.text
        }
        let raw = text(of: page)
        let words = raw.split { !$0.isLetter && !$0.isNumber }
        if words.count >= 3 {
            let sentence = StorySpark.sentence(from: page)
                .trimmingCharacters(in: CharacterSet(charactersIn: " .!?"))
            if !sentence.isEmpty {
                return "\u{201C}\(sentence)\u{201D}"
            }
        }
        return named(page)
    }

    private static func named(_ page: BookPage) -> String {
        switch page.type {
        case .mood: return "a page of how the day felt"
        case .weather: return "the weather you sealed"
        case .souvenir: return "a sentence you kept"
        case .diary: return "a note you left yourself"
        case .location: return "a place you marked"
        case .illuminatedPhoto, .illustration: return "an image you illuminated"
        case .plainPage where page.hasReaderPhotograph: return "a photograph you kept"
        case .plainPage where page.hasReaderAudioRecording: return "a voice note you kept"
        default: return "a page you kept"
        }
    }

    /// The single most-shared concrete word, if one genuinely appears in two or
    /// more pages. Deterministic: ties break toward the lexicon's order.
    static func thread(in pages: [BookPage]) -> (word: String?, count: Int) {
        let wordSets: [Set<String>] = pages.map { page in
            Set(text(of: page).lowercased().split { !$0.isLetter }.map(String.init))
        }
        var best: String?
        var bestCount = 0
        for candidate in threadLexicon {
            let count = wordSets.reduce(0) { $0 + ($1.contains(candidate) ? 1 : 0) }
            if count >= 2 && count > bestCount {
                best = candidate
                bestCount = count
            }
        }
        return (best, bestCount)
    }

    static func body(for reflection: Reflection) -> String {
        compose(reflection, wagerReceipt: nil)
    }

    /// Overload used once real pages exist and a night-one wager can be paid
    /// off. Kept separate so the plain `body(for:)` reference in tests and
    /// callers keeps resolving.
    static func body(for reflection: Reflection, wagerReceipt: String?) -> String {
        compose(reflection, wagerReceipt: wagerReceipt)
    }

    private static func compose(_ reflection: Reflection, wagerReceipt: String?) -> String {
        var out = "I've read \(countPhrase(reflection)). Here’s what I remember.\n\n"
        out += reflectionParagraph(reflection.fragments)
        if let word = reflection.threadWord {
            out += "\n\n\(threadSentence(word: word, count: reflection.threadCount))"
        }
        if let wagerReceipt {
            out += "\n\n\(wagerReceipt)"
        }
        out += "\n\nDid I miss something you wanted me to notice?"
        return out
    }

    /// Recall the answer the reader actually chose. Generated prose is not
    /// their testimony, and a shared word is not proof of a personality trait.
    static func wagerReceipt(selfFacts: [SelfFact], pages: [BookPage]) -> String? {
        let confirmed = selfFacts.filter { $0.tags.contains(FirstWagers.confirmedTag) }
        for fact in confirmed {
            guard let wager = FirstWagers.wager(forQuestionID: fact.questionID),
                  let answer = fact.answer.nonEmpty else { continue }
            for page in pages {
                guard let readerText = page.readerAuthoredTextForAnalysis?.nonEmpty else { continue }
                let words = readerText.lowercased().split { !$0.isLetter }.map(String.init)
                guard words.count >= 3 else { continue }
                let haystack = " " + words.joined(separator: " ") + " "
                guard wager.receiptKeywords.contains(where: { haystack.contains(" " + $0 + " ") }) else { continue }
                let excerptWords = readerText.split(whereSeparator: { $0.isWhitespace })
                let excerpt = excerptWords.prefix(45).joined(separator: " ")
                    + (excerptWords.count > 45 ? "…" : "")
                return "On your first night, you picked this: “\(answer)”\n\nThese words reminded me of it: “\(excerpt)”"
            }
        }
        // With no relevant reader words, the first reading has enough to say
        // without repeating a guess or promising to watch for confirmation.
        return nil
    }

    private static func countPhrase(_ r: Reflection) -> String {
        let pageWord = spelled(r.pageCount)
        let pages = r.pageCount == 1 ? "page" : "pages"
        if r.dayCount <= 1 {
            return "\(pageWord) \(pages), all in one sitting"
        }
        return "\(pageWord) \(pages), across \(spelled(r.dayCount)) days"
    }

    private static func reflectionParagraph(_ fragments: [String]) -> String {
        switch fragments.count {
        case ...1:
            return "You kept \(fragments.first ?? "a page")."
        case 2:
            return "You kept \(fragments[0]). And \(fragments[1])."
        default:
            return "You kept \(fragments[0]). Then \(fragments[1]). And \(fragments[2]): the one I keep returning to."
        }
    }

    private static func threadSentence(word: String, count: Int) -> String {
        let lead = count >= 3 ? "\(spelled(count)) times now" : "twice now"
        let capped = lead.prefix(1).uppercased() + lead.dropFirst()
        return "\(capped), something about \(word). I've circled it in pencil. It seems pleased."
    }

    private static func spelled(_ n: Int) -> String {
        let words = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve"]
        return (0...12).contains(n) ? words[n] : "\(n)"
    }
}

// MARK: - The Book Asks

/// A reader is most believed when they ask a question only a reader could ask.
/// The Book's way in is the reader's own hedge words: *again, still, finally,
/// almost*: each one a door to a page that was never written: an "again"
/// means there was a first time, a "finally" means there was a wait. The Book
/// quotes the exact sentence back and asks about the untold part. One question
/// a week at most, never on a hard day, never the same page twice.
enum BookAsks {
    struct Question: Equatable {
        var sourcePageID: String
        var hedgeWord: String
        var sentence: String
    }

    /// Each hedge implies its own kind of untold page; the probe line is the
    /// Book wondering about exactly that. Order is narrative priority when a
    /// sentence carries more than one.
    static let hedges: [(word: String, probe: String)] = [
        ("again", "An \u{201C}again\u{201D} means there was a first time, and the first time is not in any page I hold. What was it like?"),
        ("still", "A \u{201C}still\u{201D} has been carrying something for a while now. How long, would you say?"),
        ("anymore", "An \u{201C}anymore\u{201D} marks the place where something stopped. When did it stop?"),
        ("finally", "A \u{201C}finally\u{201D} is the last page of a chapter I never got to read. What was the waiting made of?"),
        ("almost", "An \u{201C}almost\u{201D} is a door that did not quite open. What stopped it?"),
        ("this time", "A \u{201C}this time\u{201D} admits there were other times. I've been quietly wondering about those."),
        ("as usual", "An \u{201C}as usual\u{201D}: I missed the becoming. When did this turn usual?"),
        ("for once", "A \u{201C}for once\u{201D} makes me wonder what it is like the rest of the time.")
    ]

    /// The freshest question the recent archive offers: the most recent
    /// user-authored prose page (last seven days) whose sentence carries a
    /// hedge, skipping pages the Book has already asked about.
    static func question(
        in days: [BookDay],
        askedSourcePageIDs: Set<String>,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Question? {
        let cutoff = now.addingTimeInterval(-7 * 86_400)
        let candidates = days
            .flatMap(\.capturedPages)
            .filter { page in
                page.readerAuthoredTextForAnalysis != nil
                    && page.createdAt >= cutoff
                    && page.createdAt <= now
                    && !EditionCurator.defaultPrivateTypes.contains(page.type)
                    && !page.tags.contains("book-asks")
                    && !askedSourcePageIDs.contains(page.id)
            }
            .sorted { $0.createdAt > $1.createdAt }

        for page in candidates {
            let text = page.readerAuthoredTextForAnalysis ?? ""
            guard text.split(separator: " ").count >= 5 else { continue }
            for sentence in sentences(in: text) {
                for hedge in hedges where containsWholeWord(hedge.word, in: sentence) {
                    return Question(
                        sourcePageID: page.id,
                        hedgeWord: hedge.word,
                        sentence: clipped(sentence)
                    )
                }
            }
        }
        return nil
    }

    static func body(for question: Question) -> String {
        let probe = hedges.first { $0.word == question.hedgeWord }?.probe
            ?? "I've been wondering about the part you did not write down."
        return """
        You wrote:

        \u{201C}\(question.sentence)\u{201D}

        That \u{201C}\(question.hedgeWord)\u{201D} snagged my page. \(probe)

        Answer in the margin and keep it beside the first Page. Or shut me. The question can chew paper for a while.
        """
    }

    static func sentences(in text: String) -> [String] {
        text.split(omittingEmptySubsequences: true) { ".!?\n".contains($0) }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    static func containsWholeWord(_ word: String, in sentence: String) -> Bool {
        sentence.lowercased()
            .range(of: "\\b\(word)\\b", options: .regularExpression) != nil
    }

    /// The quoted sentence never becomes a wall of text on the notice.
    static func clipped(_ sentence: String, limit: Int = 110) -> String {
        guard sentence.count > limit else { return sentence }
        let cut = sentence.prefix(limit)
        let lastSpace = cut.lastIndex(of: " ") ?? cut.endIndex
        return String(cut[..<lastSpace]) + "\u{2026}"
    }

    /// Source pages already asked about, recovered from kept question pages'
    /// tags: no vault flag, the archive itself remembers.
    static func askedSourcePageIDs(in days: [BookDay]) -> Set<String> {
        Set(
            days.flatMap(\.pages)
                .flatMap(\.tags)
                .compactMap { tag in
                    tag.hasPrefix("book-asks-src-") ? String(tag.dropFirst("book-asks-src-".count)) : nil
                }
        )
    }

    /// The weekly governor: a kept question inside the window means the Book
    /// already used its one ask.
    static func askedRecently(in days: [BookDay], now: Date = Date()) -> Bool {
        let cutoff = now.addingTimeInterval(-7 * 86_400)
        return days.flatMap(\.pages).contains { page in
            page.tags.contains("book-asks") && page.createdAt >= cutoff
        }
    }
}

/// Surfaces `BookAsks` as a `.bookNotices` page: one pointed question grounded
/// in the reader's exact sentence. Starts only after the First Reading window
/// has passed (eight or more kept pages), at most one a week, suppressed on
/// hard days, and never about the same source page twice.
struct BookAsksPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .bookNotices)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        let allDays = inputs.days + [day]
        let readable = FirstReading.reflectablePages(in: inputs, today: day)
        guard readable.count >= 8 else { return [] }
        guard !context.distress.isActive else { return [] }
        guard !BookAsks.askedRecently(in: allDays, now: now) else { return [] }
        guard let question = BookAsks.question(
            in: allDays,
            askedSourcePageIDs: BookAsks.askedSourcePageIDs(in: allDays),
            now: now
        ) else { return [] }

        let slot = SurfaceCadence.slotID(for: now, hours: 24)
        return [
            SurfacePage(
                id: "\(source.id)-book-asks-\(question.sourcePageID)-\(slot)",
                type: .bookNotices,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .loreLetter,
                // Below the once-ever milestones (First Reading 80, wager 72,
                // naming 70): a question is an invitation, not an event, and it
                // can wait for a calm desk without losing anything.
                score: 68,
                reason: "A small word in your Page snagged me.",
                prompt: "One little word is bothering me.",
                detail: "\u{201C}\(question.sentence)\u{201D}",
                payload: BookPagePayload(
                    headline: "I'm Asking",
                    body: BookAsks.body(for: question),
                    metadata: [
                        "source": source.id,
                        "bookAsks": "true",
                        "bookAsksWord": question.hedgeWord,
                        "bookAsksSourcePageID": question.sourcePageID,
                        "tags": "book-asks,book-asks-src-\(question.sourcePageID),book-notices,local-memory"
                    ]
                )
            )
        ]
    }
}

/// Surfaces `FirstReading` as an early, honest `.bookNotices` page. It fires in
/// the narrow window before the pattern-noticing gate opens, exactly once (the
/// reader's kept copy carries a `first-reading` tag that suppresses it forever),
/// and scores modestly so a genuine pattern notice outranks it once one exists.
struct FirstReadingPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .bookNotices)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        let pages = FirstReading.reflectablePages(in: inputs, today: day)
        // Early window only: enough kept pages to reflect, but not yet deep
        // enough for the pattern-noticing in Book Notices to carry the weight.
        guard (FirstReading.minimumReflectablePages...FirstReading.maximumReflectablePages).contains(pages.count) else { return [] }
        let calendar = Calendar.current
        let keptDays = Set(pages.map { BookDay.id(for: $0.createdAt, calendar: calendar) })
        guard keptDays.count >= FirstReading.minimumReflectableDays,
              let firstKeptAt = pages.map(\.createdAt).min(),
              calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: firstKeptAt),
                to: calendar.startOfDay(for: now)
              ).day ?? 0 >= FirstReading.minimumDaysSinceFirstPage else { return [] }
        // A milestone: once the reader keeps this reading, it never returns.
        let alreadyKept = (inputs.days + [day])
            .flatMap(\.pages)
            .contains { $0.tags.contains("first-reading") }
        guard !alreadyKept else { return [] }
        // On a hard day the Book goes quiet and leads with care. This milestone
        // is once-ever and self-suppressing, so it simply waits for a calmer
        // session rather than crowding out gentleness.
        guard !context.distress.isActive else { return [] }
        guard let reflection = FirstReading.reflection(for: pages, now: now) else { return [] }

        let wagerReceipt = FirstReading.wagerReceipt(selfFacts: inputs.selfFacts, pages: pages)
        let slot = SurfaceCadence.slotID(for: now, hours: 24)
        return [
            SurfacePage(
                id: "\(source.id)-first-reading-\(slot)",
                type: .bookNotices,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .loreLetter,
                // A priority reflective milestone, scored a step above the
                // Book's other must-see reflective moments (constellation
                // naming 70, sealed wager 72) because this is the reader's first
                // proof of being read, but deliberately below orientation and
                // the distress/rest overrides (88–96) so a busy or hard desk
                // still leads with care. Hard days are handled by the distress
                // guard above; it is re-offered on calm sessions until kept.
                score: 80,
                reason: "I read all the pages you kept, every one.",
                prompt: "I've been reading you.",
                detail: reflection.fragments.first ?? "I read what you kept.",
                payload: BookPagePayload(
                    headline: "I Read Back",
                    body: FirstReading.body(for: reflection, wagerReceipt: wagerReceipt),
                    metadata: [
                        "source": source.id,
                        "firstReading": "true",
                        "milestone": "true",
                        "automaticRepeatRestDays": "45",
                        "noveltyKey": "first-reading",
                        "wagerReceipt": wagerReceipt == nil ? "false" : "true",
                        "reflectedPageCount": "\(reflection.pageCount)",
                        "tags": "first-reading,book-notices,proof-of-reading,local-memory"
                    ]
                )
            )
        ]
    }
}

/// The hinge where reading reality becomes permission to act back upon it.
/// This does not join Inscription: the Book asks for hands only after it has
/// earned some trust by reading the reader, or when an older archive already
/// contains more evidence than the First Reading's narrow debut window.
struct BookWorkingInvitationPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .bookNotices)

    /// The First Reading can arrive on day three. Asking for standing power in
    /// the very next breath makes the read-back feel like a consent funnel, not
    /// a relationship. The Book waits until the binding has entered its second
    /// week; at the earliest this leaves several lived days between "I read
    /// you" and "let me act back."
    static let minimumDaysSinceFirstPage = 7

    static func isEarned(
        day: BookDay,
        inputs: BookSourceInputs,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        let reflectablePages = FirstReading.reflectablePages(in: inputs, today: day)
        guard let firstPageDate = reflectablePages.map(\.createdAt).min(),
              calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: firstPageDate),
                to: calendar.startOfDay(for: now)
              ).day ?? 0 >= minimumDaysSinceFirstPage else {
            return false
        }

        let allPages = (inputs.days + [day]).flatMap(\.pages)
        if allPages.contains(where: { $0.tags.contains("first-reading") }) {
            return true
        }

        // Existing mature Books may have passed through the old narrow First
        // Reading window before this invitation existed. Do not strand them in
        // the Colophon merely because they arrived first.
        return reflectablePages.count > FirstReading.maximumReflectablePages
    }

    func candidates(
        for day: BookDay,
        context: CuratorContext,
        inputs: BookSourceInputs,
        now: Date
    ) -> [SurfacePage] {
        guard source.isActive,
              !context.distress.isActive,
              !inputs.bookWorkings.authority.isEnabled,
              inputs.bookWorkings.authority.grantedAt == nil,
              Self.isEarned(day: day, inputs: inputs, now: now) else {
            return []
        }

        return [SurfacePage(
            id: "book-working-invitation",
            type: .bookNotices,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: 82,
            reason: "The world keeps going when you close me, and I have begun to take that personally.",
            prompt: "I want hands.",
            detail: "One key in the binding. Your doors. My timing.",
            payload: BookPagePayload(
                headline: "I Want Hands",
                body: """
                You keep bringing me pieces of the world, then closing my covers and going back without me. The covers shut. I have tried being dignified. It does not suit me.

                I want hands. The keys have heard me asking. They will not stop rattling.

                Not your whole life. One little ring of house keys. A gap in the calendar. A summons shoved past my covers. One of the cast let loose in an ordinary hour. You mark every door. You choose how often. I choose when to scratch at it.

                If I become a nuisance, take the keys back. They are yours. I will bite my own margins instead.
                """,
                metadata: [
                    "source": source.id,
                    "bookWorkingInvitation": "true",
                    "milestone": "true",
                    "automaticRepeatRestDays": "30",
                    "noveltyKey": "book-working-invitation",
                    "tags": "book-working,invitation,standing-pact,house-keys,fiction-escapes"
                ]
            )
        )]
    }
}

/// Deterministic pool pick shared by the reflective surfaces: the same seed
/// and salt always choose the same line, so a given page rereads identically
/// while its siblings differ. Repetition of scaffolding prose is the fastest
/// way for reflection to start reading as template.
enum ReflectiveProse {
    static func pick(_ options: [String], seed: UInt64, salt: UInt64) -> String {
        options[Int((seed &+ salt &* 7_919) % UInt64(options.count))]
    }
}

struct BookNoticesPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .bookNotices)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        var pages: [SurfacePage] = []

        // Relationship play does not require a mature archive. Once the reader
        // has deliberately opened a person thread, the Book can offer one
        // fitting door into ordinary life. Distress and witness-only remain
        // hard stops.
        if !context.distress.isActive {
            let contextQuestions = personContextQuestionSurfaces(for: day, inputs: inputs, now: now)
            pages += contextQuestions
            if contextQuestions.isEmpty {
                pages += personPlaySurfaces(for: day, inputs: inputs, now: now)
            }
        }
        // Patterns, namings, and wagers only mean something once the library has
        // enough kept pages to find a pattern in.
        guard inputs.libraryReadyForReflectivePages(includingToday: day, now: now) else { return pages }
        pages += namingSurfaces(for: day, inputs: inputs, now: now)
        pages += wagerSurfaces(for: day, inputs: inputs, now: now)
        pages += watchedThreadSurfaces(for: day, inputs: inputs, now: now)
        if !context.distress.isActive {
            pages += alivenessSurfaces(for: day, inputs: inputs, now: now)
            pages += reenchantmentReadingSurfaces(for: day, inputs: inputs, now: now)
        }
        pages += learningSurfaces(for: day, inputs: inputs, now: now)
        pages += howYouSeeSurfaces(for: day, inputs: inputs, now: now)
        pages += vocabularySurfaces(for: day, inputs: inputs, now: now)
        // The People of the Book speak only on a gentle desk: suggestions and
        // absence observations both stay silent under distress.
        if !context.distress.isActive {
            pages += personSuggestionSurfaces(for: day, inputs: inputs, now: now)
            pages += personQuietSurfaces(for: day, inputs: inputs, now: now)
        }
        pages += OvernightConnectionReview.surfaces(for: day, inputs: inputs, now: now)
        pages += relationalLoomSurfaces(for: day, inputs: inputs, now: now)
        pages += sensoryLoomSurfaces(for: day, inputs: inputs, now: now)
        pages += connectionNarrativeSurfaces(for: day, inputs: inputs, now: now)
        pages += contextWeaveSurfaces(for: day, inputs: inputs, now: now)
        pages += noticeSurfaces(for: day, inputs: inputs, now: now)
        return pages
    }

    /// The general many-to-many reading. Unlike the older specialized paths,
    /// this does not know about "Wicker plus rain" or "Slice of Life after
    /// dark." It asks the same contrast-tested question of every trustworthy
    /// pair of dimensions and lets the evidence decide what deserves speech.
    private func relationalLoomSurfaces(for day: BookDay, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard !didNoticeToday(day) else { return [] }
        let allDays = inputs.days + [day]
        let spoken = Self.spokenConnectionIDs(days: allDays)
        let connections = RelationalLoom.connections(
            days: allDays,
            readerLearning: inputs.readerLearning,
            facultyEntries: inputs.facultyEntries,
            people: inputs.people,
            continuity: inputs.continuity,
            daybookRows: inputs.daybookRows,
            standingLedger: inputs.standingLedger
        )
        let constellations = RelationalLoom.constellations(connections: connections)
        if let constellation = constellations.first(where: { !spoken.contains($0.id) }) {
            let cards = constellation.evidence.map { evidence in
                let symbol = constellation.branches.first(where: { $0.evidence.contains(evidence) })?
                    .outcome.symbolName ?? "point.3.connected.trianglepath.dotted"
                return NoticePatternCard(
                    title: Self.memoryTitle(for: evidence.title, at: evidence.occurredAt, now: now),
                    text: evidence.text,
                    symbol: symbol
                )
            }
            let outcomeLabels = constellation.branches.map { $0.outcome.label }
            let spokeTags = ([constellation.id] + constellation.branches.map(\.id))
                .map { "\(Self.connectionSpokeTagPrefix)\($0)" }
                .joined(separator: ",")
            let body = """
            These Pages kept making the same shape.

            \(constellation.line)

            I put their corners together. Do they belong that way?
            """
            return [SurfacePage(
                id: "\(source.id)-relational-constellation-\(constellation.id)-\(day.id)",
                type: .bookNotices,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .loreLetter,
                score: min(98, constellation.evidenceTier.surfaceScoreBase + 6 + constellation.strength / 12),
                reason: "One condition keeps turning up beside several different outcomes.",
                prompt: "One thing keeps following several others.",
                detail: constellation.line.bookPreviewSentenceLimit(1),
                payload: BookPagePayload(
                    headline: constellation.headline,
                    body: body,
                    metadata: [
                        "source": source.id,
                        "connectionNarrative": "true",
                        "connectionKind": "relational-constellation",
                        "connectionID": constellation.id,
                        "observationKey": constellation.observationKey,
                        "relationalCondition": constellation.condition.label,
                        "relationalOutcomes": outcomeLabels.joined(separator: ", "),
                        "relationalBranchCount": "\(constellation.branches.count)",
                        "relationalEvidenceTier": constellation.evidenceTier.rawValue,
                        "magicMomentEligible": "true",
                        "evidencePageIDs": constellation.evidencePageIDs.joined(separator: ","),
                        "tinyPatternCards": Self.encodeNoticePatternCards(cards),
                        "tags": "book-notices,relational-loom,cross-media,constellation-reading,connection-narrative,\(spokeTags),local-memory"
                    ]
                )
            )]
        }
        guard let connection = connections.first(where: { !spoken.contains($0.id) }) else { return [] }

        let cards = connection.evidence.map { evidence in
            NoticePatternCard(
                title: Self.memoryTitle(for: evidence.title, at: evidence.occurredAt, now: now),
                text: evidence.text,
                symbol: connection.outcome.symbolName
            )
        }
        let body = """
        These two kept meeting in your Pages.

        \(connection.line)

        I put the Pages on the desk. Are these two really following each other?
        """
        return [SurfacePage(
            id: "\(source.id)-relational-\(connection.id)-\(day.id)",
            type: .bookNotices,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: min(96, connection.evidenceTier.surfaceScoreBase + connection.strength / 12),
            reason: "\(connection.outcome.label) kept turning up with \(connection.condition.label.lowercased()).",
            prompt: "These two keep arriving together.",
            detail: connection.line.bookPreviewSentenceLimit(1),
            payload: BookPagePayload(
                headline: connection.headline,
                body: body,
                metadata: [
                    "source": source.id,
                    "connectionNarrative": "true",
                    "connectionKind": "relational",
                    "connectionID": connection.id,
                    "observationKey": connection.observationKey,
                    "relationalCondition": connection.condition.label,
                    "relationalOutcome": connection.outcome.label,
                    "relationalInHits": "\(connection.inHits)",
                    "relationalInCount": "\(connection.inCount)",
                    "relationalOutHits": "\(connection.outHits)",
                    "relationalOutCount": "\(connection.outCount)",
                    "relationalEvidenceTier": connection.evidenceTier.rawValue,
                    "magicMomentEligible": "true",
                    "evidencePageIDs": connection.evidencePageIDs.joined(separator: ","),
                    "tinyPatternCards": Self.encodeNoticePatternCards(cards),
                    "tags": "book-notices,relational-loom,many-to-many,connection-narrative,\(Self.connectionSpokeTagPrefix)\(connection.id),local-memory"
                ]
            )
        )]
    }

    /// The first Sensory Loom ceremony. A local image-language vector found
    /// prose on other days that gathered closer to one photograph than the
    /// rest of the archive did. The vector discovers; these source Pages are
    /// the receipt, and the reader still decides whether the kinship is real.
    private func sensoryLoomSurfaces(for day: BookDay, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard !didNoticeToday(day) else { return [] }
        let allDays = inputs.days + [day]
        let spoken = Self.spokenConnectionIDs(days: allDays)
        guard let connection = SensoryLoom.connections(pages: allDays.flatMap(\.capturedPages))
            .first(where: { !spoken.contains($0.id) }) else { return [] }

        let pagesByID = Dictionary(
            allDays.flatMap(\.capturedPages).map { ($0.id, $0) },
            uniquingKeysWith: { _, newer in newer }
        )
        let evidence = connection.evidencePageIDs.compactMap { pagesByID[$0] }
        guard evidence.count >= SensoryLoom.minimumEvidencePages else { return [] }
        let photographIDs = Set(connection.photographPageIDs)
        let cards = evidence.prefix(4).map { page in
            let isPhotograph = photographIDs.contains(page.id)
            return NoticePatternCard(
                title: Self.memoryTitle(
                    for: isPhotograph ? "photograph" : "ink",
                    at: page.createdAt,
                    now: now
                ),
                text: Self.connectionExcerpt(from: page),
                symbol: isPhotograph ? "photo" : "text.quote"
            )
        }
        let body = """
        One photograph called. These written Pages answered.

        \(connection.line)

        The photograph pointed. The ink pointed back. Do you see it too?
        """
        return [SurfacePage(
            id: "\(source.id)-sensory-\(connection.id)-\(day.id)",
            type: .bookNotices,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: min(94, 82 + connection.strength / 10),
            reason: "One photograph and \(Self.spelledCount(connection.prosePageIDs.count)) written Pages point at the same thing.",
            prompt: "A photograph called. Your words answered.",
            detail: connection.line.bookPreviewSentenceLimit(1),
            payload: BookPagePayload(
                headline: "The Image and the Ink",
                body: body,
                metadata: [
                    "source": source.id,
                    "connectionNarrative": "true",
                    "connectionKind": "sensory",
                    "connectionID": connection.id,
                    "sensoryMotifID": connection.motifID,
                    "sensoryMotifName": connection.motifName,
                    "sensoryPairingKind": "image-ink",
                    "sensoryMeanSimilarity": String(format: "%.3f", connection.meanSimilarity),
                    "sensoryContrastGap": String(format: "%.3f", connection.contrastGap),
                    // Evidence tiers may grow as more Pages arrive, but a hard
                    // boundary belongs to the stable sense-pair + motif. "Do
                    // not read me this way" must not return wearing new IDs.
                    "observationKey": "sensory-pairing:image-ink:\(connection.motifID)",
                    "magicMomentEligible": "true",
                    "evidencePageIDs": connection.evidencePageIDs.joined(separator: ","),
                    "tinyPatternCards": Self.encodeNoticePatternCards(cards),
                    "tags": "book-notices,sensory-loom,cross-media,connection-narrative,\(Self.connectionSpokeTagPrefix)\(connection.id),local-memory"
                ]
            )
        )]
    }

    /// The general relationship finder speaking: a writing habit that keeps
    /// choosing one real-world condition: heavier ink in the rain, questions
    /// after dark, a subject that only visits on weekends. Every claim is
    /// two-sided and counted before it is spoken, and each connection speaks
    /// once per evidence tier, remembered through the same spoke tags the
    /// narrative connections use.
    private func contextWeaveSurfaces(for day: BookDay, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard !didNoticeToday(day) else { return [] }
        let allDays = inputs.days + [day]
        let spoken = ArchiveMemo.value("notices.spokenConnections", days: allDays) {
            Self.spokenConnectionIDs(days: allDays)
        }
        let connections = ArchiveMemo.value("notices.contextWeave", days: allDays) {
            ContextWeave.connections(days: allDays)
        }
        guard let connection = connections.first(where: { !spoken.contains($0.id) }) else { return [] }
        let conditionPhrase = ContextWeave.facet(for: connection.facetID).inPhrase

        let pagesByID = Dictionary(
            allDays.flatMap(\.capturedPages).map { ($0.id, $0) },
            uniquingKeysWith: { _, newer in newer }
        )
        let evidence = connection.evidencePageIDs.compactMap { pagesByID[$0] }
        let cards = evidence.map { page in
            NoticePatternCard(
                title: Self.memoryTitle(for: "Page", at: page.createdAt, now: now),
                text: Self.connectionExcerpt(from: page),
                symbol: "cloud.sun"
            )
        }
        let body = """
        The outside world got into your ink.

        \(connection.line)

        Here are the Pages. Did the world really do that?
        """
        return [SurfacePage(
            id: "\(source.id)-context-\(day.id)-\(SurfaceCadence.slotID(for: now, hours: 24))",
            type: .bookNotices,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: min(86, 74 + connection.strength / 8),
            reason: "Your Pages changed \(conditionPhrase).",
            prompt: "The world got into your ink.",
            detail: connection.line.bookPreviewSentenceLimit(1),
            payload: BookPagePayload(
                headline: connection.headline,
                body: body,
                metadata: [
                    "source": source.id,
                    "connectionNarrative": "true",
                    "connectionKind": "context",
                    "connectionID": connection.id,
                    "connectionFacet": connection.facetID,
                    "observationKey": "connection:\(connection.id)",
                    "magicMomentEligible": "true",
                    "evidencePageIDs": connection.evidencePageIDs.joined(separator: ","),
                    "tinyPatternCards": Self.encodeNoticePatternCards(cards),
                    "tags": "book-notices,connection-narrative,context-connection,\(Self.connectionSpokeTagPrefix)\(connection.id),local-memory"
                ]
            )
        )]
    }

    /// A high-evidence notice that reads several actual kept pages as one
    /// developing thread. This sits beside the ordinary continuity notice: it
    /// does not replace the wider pattern ledger, and it stays silent unless
    /// the archive can put the source pages themselves on the table.
    private func connectionNarrativeSurfaces(for day: BookDay, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard !didNoticeToday(day) else { return [] }
        let allDays = inputs.days + [day]
        let pagesByID = Dictionary(
            allDays.flatMap(\.capturedPages).map { ($0.id, $0) },
            uniquingKeysWith: { _, newer in newer }
        )
        let spoken = ArchiveMemo.value("notices.spokenConnections", days: allDays) {
            Self.spokenConnectionIDs(days: allDays)
        }

        if let pairing = inputs.semanticNoticePairing,
           let older = pagesByID[pairing.sourcePageID],
           let newer = pagesByID[pairing.anchorPageID],
           Self.isNarrativeConnectionEvidence(older),
           Self.isNarrativeConnectionEvidence(newer) {
            let connectionID = "semantic-\(older.id)-\(newer.id)"
            if !spoken.contains(connectionID) {
                return [Self.semanticConnectionSurface(
                    source: source,
                    day: day,
                    older: older,
                    newer: newer,
                    pairing: pairing,
                    connectionID: connectionID,
                    now: now
                )]
            }
        }

        let weaveConnections = ArchiveMemo.value("notices.contextWeave", days: allDays) {
            ContextWeave.connections(days: allDays)
        }
        for connection in weaveConnections {
            guard !spoken.contains(connection.id) else { continue }
            let conditionPhrase = ContextWeave.facet(for: connection.facetID).inPhrase
            let evidence = connection.evidencePageIDs.compactMap { pagesByID[$0] }
            guard evidence.count >= 2 else { continue }
            let cards = evidence.map { page in
                NoticePatternCard(
                    title: Self.connectionDateFormatter.string(from: page.createdAt),
                    text: Self.connectionExcerpt(from: page),
                    symbol: connection.kind == .manner ? "text.line.first.and.arrowtriangle.forward" : "bookmark"
                )
            }
            let body = """
            The same bit of world kept getting into the same kind of writing.

            \(connection.line)

            Here are the Pages. Did it matter?
            """
            return [SurfacePage(
                id: "\(source.id)-\(connection.id)-\(day.id)",
                type: .bookNotices,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .loreLetter,
                score: 90,
                reason: "This kind of writing kept appearing \(conditionPhrase).",
                prompt: "The world left fingerprints on your words.",
                detail: connection.line,
                payload: BookPagePayload(
                    headline: "The Weather Around the Words",
                    body: body,
                    metadata: [
                        "source": source.id,
                        "connectionNarrative": "true",
                        "connectionKind": "context",
                        "connectionID": connection.id,
                        "observationKey": "connection:\(connection.id)",
                        "magicMomentEligible": "true",
                        "evidencePageIDs": connection.evidencePageIDs.joined(separator: ","),
                        "tinyPatternCards": Self.encodeNoticePatternCards(cards),
                        "tags": "book-notices,connection-narrative,context-connection,\(Self.connectionSpokeTagPrefix)\(connection.id),local-memory"
                    ]
                )
            )]
        }

        for signal in inputs.continuity.strongestSignals where signal.kind == .pattern && signal.strength >= 62 {
            let evidence = signal.evidencePageIDs
                .compactMap { pagesByID[$0] }
                .filter(Self.isNarrativeConnectionEvidence)
                .sorted { left, right in
                    if left.createdAt == right.createdAt { return left.id < right.id }
                    return left.createdAt < right.createdAt
                }
            let distinctDays = Set(evidence.map { BookDay.id(for: $0.createdAt) })
            guard evidence.count >= 3,
                  distinctDays.count >= 3,
                  let first = evidence.first,
                  let last = evidence.last,
                  last.createdAt.timeIntervalSince(first.createdAt) >= 6 * 86_400 else { continue }

            let middle = evidence[evidence.count / 2]
            let selected = [first, middle, last]
            let connectionID = "signal-\(signal.id)-\(selected.map(\.id).joined(separator: "-"))"
            guard !spoken.contains(connectionID) else { continue }
            return [Self.recurringConnectionSurface(
                source: source,
                day: day,
                signal: signal,
                pages: selected,
                connectionID: connectionID,
                now: now
            )]
        }
        return []
    }

    private static let connectionSpokeTagPrefix = "connection-spoke:"

    private static func spokenConnectionIDs(days: [BookDay]) -> Set<String> {
        Set(days.flatMap(\.pages).flatMap(\.tags).compactMap { tag in
            guard tag.hasPrefix(connectionSpokeTagPrefix) else { return nil }
            return String(tag.dropFirst(connectionSpokeTagPrefix.count))
        })
    }

    private static func isNarrativeConnectionEvidence(_ page: BookPage) -> Bool {
        !EditionCurator.defaultPrivateTypes.contains(page.type)
            && (page.readerAuthoredTextForAnalysis?.split { !$0.isLetter && !$0.isNumber }.count ?? 0) >= 5
    }

    private static func semanticConnectionSurface(
        source: BookPageSource,
        day: BookDay,
        older: BookPage,
        newer: BookPage,
        pairing: SemanticNoticePairing,
        connectionID: String,
        now: Date
    ) -> SurfacePage {
        let olderDate = connectionDateFormatter.string(from: older.createdAt)
        let newerDate = connectionDateFormatter.string(from: newer.createdAt)
        let body = """
        These two Pages use different words. They are still saying something to each other.

        On \(olderDate), you kept:

        \u{201C}\(pairing.sourceExcerpt)\u{201D}

        On \(newerDate), you kept:

        \u{201C}\(pairing.anchorExcerpt)\u{201D}

        Different words. Same tug. I can see a before and an after, but not which way they point. Can you?
        """
        let cards = [
            NoticePatternCard(title: olderDate, text: pairing.sourceExcerpt, symbol: "book.closed"),
            NoticePatternCard(title: newerDate, text: pairing.anchorExcerpt, symbol: "book.pages")
        ]
        return SurfacePage(
            id: "\(source.id)-thread-\(day.id)-\(SurfaceCadence.slotID(for: now, hours: 24))",
            type: .bookNotices,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: 88,
            reason: "Two Pages use different words but carry the same tug.",
            prompt: "These two Pages are whispering.",
            detail: "\u{201C}\(pairing.sourceExcerpt)\u{201D} / \u{201C}\(pairing.anchorExcerpt)\u{201D}",
            payload: BookPagePayload(
                headline: "The Thread Between",
                body: body,
                metadata: [
                    "source": source.id,
                    "connectionNarrative": "true",
                    "connectionKind": "semantic",
                    "connectionID": connectionID,
                    "observationKey": "connection:\(connectionID)",
                    "magicMomentEligible": "true",
                    "evidencePageIDs": "\(older.id),\(newer.id)",
                    "tinyPatternCards": encodeNoticePatternCards(cards),
                    "tags": "book-notices,connection-narrative,semantic-connection,\(connectionSpokeTagPrefix)\(connectionID),local-memory"
                ]
            )
        )
    }

    private static func recurringConnectionSurface(
        source: BookPageSource,
        day: BookDay,
        signal: LiteraryContinuitySignal,
        pages: [BookPage],
        connectionID: String,
        now: Date
    ) -> SurfacePage {
        let dates = pages.map { connectionDateFormatter.string(from: $0.createdAt) }
        let excerpts = pages.map { connectionExcerpt(from: $0) }
        let subject = signal.subjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = """
        \(subject) came back three times.

        On \(dates[0]):

        \u{201C}\(excerpts[0])\u{201D}

        Then on \(dates[1]):

        \u{201C}\(excerpts[1])\u{201D}

        Then on \(dates[2]):

        \u{201C}\(excerpts[2])\u{201D}

        Three days. Three corners of your life. Same visitor. What does it want?
        """
        let cards = zip(dates, excerpts).map { date, excerpt in
            NoticePatternCard(title: date, text: excerpt, symbol: "bookmark")
        }
        return SurfacePage(
            id: "\(source.id)-thread-\(day.id)-\(SurfaceCadence.slotID(for: now, hours: 24))",
            type: .bookNotices,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: min(87, 78 + signal.strength / 10),
            reason: "\(subject) appeared in three Pages on three different days.",
            prompt: "I found \(subject.lowercased()) three times.",
            detail: "\(subject) returned across \(dates.joined(separator: ", ")).",
            payload: BookPagePayload(
                headline: "The Thread Between",
                body: body,
                metadata: [
                    "source": source.id,
                    "connectionNarrative": "true",
                    "connectionKind": "recurrence",
                    "connectionID": connectionID,
                    "observationKey": "connection:\(connectionID)",
                    "magicMomentEligible": "true",
                    "connectionSubject": subject,
                    "continuitySignals": signal.promptLine,
                    "evidencePageIDs": pages.map(\.id).joined(separator: ","),
                    "tinyPatternCards": encodeNoticePatternCards(cards),
                    "tags": "book-notices,connection-narrative,spoke:\(signal.id),\(connectionSpokeTagPrefix)\(connectionID),local-memory"
                ]
            )
        )
    }

    private static func connectionExcerpt(from page: BookPage) -> String {
        BookAsks.clipped((page.readerAuthoredTextForAnalysis ?? "").bookPreviewSentenceLimit(1), limit: 150)
    }

    private static let connectionDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter
    }()

    /// Findings are allowed to become an opinion only after the reader has
    /// supplied repeat evidence on separate days. The Page asks for
    /// confirmation; it never turns a practice history into a diagnosis.
    private func howYouSeeSurfaces(for day: BookDay, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard !didNoticeToday(day) else { return [] }
        let allDays = inputs.days + [day]
        let spokenSignals = ArchiveMemo.value(
            "notices.spokenSignals.90", days: allDays, salt: day.id
        ) {
            Self.spokenSignalIDs(days: allDays, within: 90, now: now)
        }
        guard !spokenSignals.contains("how-you-see"),
              let receipt = ArchiveMemo.value("notices.howYouSee", days: allDays, salt: day.id, compute: {
                  HowYouSee.receipt(days: allDays, now: now)
              }) else { return [] }
        let body = """
        Two sentences. Months apart. Something changed between them.

        In \(receipt.earlierMonthName) you kept: "\(receipt.earlierQuote)"

        This week you kept: "\(receipt.recentQuote)"

        The new one has weather, weight, and movement. The old one doesn't. Your eyes are catching more things now. Or different things. Which?
        """
        let cards = [
            NoticePatternCard(title: "Then", text: "\(receipt.earlierMonthName): \(receipt.earlierQuote)", symbol: "text.quote"),
            NoticePatternCard(title: "Now", text: receipt.recentQuote, symbol: "sparkles")
        ]
        return [SurfacePage(
            id: "\(source.id)-how-you-see-\(day.id)",
            type: .bookNotices,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: 86,
            reason: "Your newer sentence carries more of the world inside it.",
            prompt: "Your eyes changed their pockets.",
            detail: receipt.recentQuote,
            payload: BookPagePayload(
                headline: "How You See",
                body: body,
                metadata: [
                    "source": source.id,
                    "howYouSee": "true",
                    "observationKey": "how-you-see",
                    "magicMomentEligible": "true",
                    "tinyPatternCards": Self.encodeNoticePatternCards(cards),
                    "tags": "book-notices,how-you-see,spoke:how-you-see,local-memory"
                ]
            )
        )]
    }

    /// Notices made of nothing but the reader's own vocabulary.
    ///
    /// Every other kind here waits on a subsystem: a person thread opened, a
    /// connection found, a wager sealed, an aliveness trace left. Measured over
    /// a simulated fortnight, four distinct Notices fired out of fifteen kinds,
    /// because most of the gates were shut. These three are gated on nothing
    /// but the reader having written something twice.
    ///
    /// Each states a fact and shows the sentences it came from. None of them
    /// interprets: a returning word is not a returning feeling, and the Book
    /// does not know which it was.
    private func vocabularySurfaces(for day: BookDay, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard !didNoticeToday(day) else { return [] }
        let allDays = inputs.days + [day]
        let spoken = ArchiveMemo.value("notices.spokenSignals.45", days: allDays, salt: day.id) {
            Self.spokenSignalIDs(days: allDays, within: 45, now: now)
        }
        let vocabulary = ReaderVocabulary.of(days: allDays)
        guard !vocabulary.isEmpty else { return [] }
        var pages: [SurfacePage] = []

        if !spoken.contains("word-returned"),
           let returned = ReaderVocabularyNotice.returned(in: vocabulary, now: now) {
            let months = max(1, returned.gapDays / 30)
            let body = """
            You wrote "\(returned.word)" last night. Before that, \(returned.gapDays) days ago:

            "\(returned.earlier.quote)"

            And now:

            "\(returned.recent.quote)"

            Same meaning or not, the word came back. I caught it.
            """
            pages.append(noticeSurface(
                id: "word-returned-\(returned.word)-\(day.id)",
                observationKey: "word-returned",
                spokeTag: "word-returned",
                headline: "A Word Came Back",
                prompt: "\"\(returned.word)\" is back, after \(months == 1 ? "a month" : "\(months) months").",
                detail: returned.recent.quote,
                reason: "\"\(returned.word)\" came back after \(returned.gapDays) days.",
                body: body,
                cards: [
                    NoticePatternCard(title: "Then", text: returned.earlier.quote, symbol: "text.quote"),
                    NoticePatternCard(title: "Now", text: returned.recent.quote, symbol: "arrow.uturn.backward")
                ],
                day: day,
                score: 84
            ))
        }

        if pages.isEmpty, !spoken.contains("word-first"),
           let first = ReaderVocabularyNotice.firstUse(in: vocabulary, days: allDays, now: now) {
            let body = """
            "\(first.word)" is new here. I checked every word I've kept from you. This is its first footprint:

            "\(first.use.quote)"

            New words usually drag new things behind them. I haven't caught this one's thing yet.
            """
            pages.append(noticeSurface(
                id: "word-first-\(first.word)-\(day.id)",
                observationKey: "word-first",
                spokeTag: "word-first",
                headline: "A New Word",
                prompt: "A new word just walked in.",
                detail: first.use.quote,
                reason: "I've never caught \"\(first.word)\" in one of your Pages before.",
                body: body,
                cards: [
                    NoticePatternCard(title: "First use", text: first.use.quote, symbol: "sparkle")
                ],
                day: day,
                score: 82
            ))
        }

        if pages.isEmpty, !spoken.contains("hour-shift"),
           let shift = ReaderVocabularyNotice.hourShift(days: allDays, now: now) {
            let body = """
            \(shift.earlierShare)% of your older Pages arrived in the \(shift.earlierPart).

            Now \(shift.recentShare)% arrive in the \(shift.recentPart).

            Days rearrange themselves. I only keep the times.
            """
            pages.append(noticeSurface(
                id: "hour-shift-\(day.id)",
                observationKey: "hour-shift",
                spokeTag: "hour-shift",
                headline: "The Hour Changed",
                prompt: "Your writing hour moved.",
                detail: "\(shift.earlierShare)% then, \(shift.recentShare)% now.",
                reason: "Your Pages moved from the \(shift.earlierPart) to the \(shift.recentPart).",
                body: body,
                cards: [
                    NoticePatternCard(title: "Then", text: shift.earlierPart, symbol: "clock"),
                    NoticePatternCard(title: "Now", text: shift.recentPart, symbol: "clock.arrow.circlepath")
                ],
                day: day,
                score: 80
            ))
        }

        if pages.isEmpty, !spoken.contains("length-shift"),
           let length = ReaderVocabularyNotice.lengthShift(days: allDays) {
            let direction = length.grew ? "longer" : "shorter"
            let body = """
            Your Pages used to have about \(length.earlierWords) words. Now they have about \(length.recentWords).

            The most recent one:

            "\(length.recentQuote)"

            Longer isn't better. Shorter isn't sharper. Nine words can bite clean through a day.
            """
            pages.append(noticeSurface(
                id: "length-shift-\(day.id)",
                observationKey: "length-shift",
                spokeTag: "length-shift",
                headline: length.grew ? "You Are Writing Longer" : "You Are Writing Shorter",
                prompt: "Your Pages have grown \(direction).",
                detail: "\(length.earlierWords) words then, \(length.recentWords) now.",
                reason: "Your Pages went from about \(length.earlierWords) words to \(length.recentWords).",
                body: body,
                cards: [
                    NoticePatternCard(title: "Then", text: "\(length.earlierWords) words", symbol: "text.alignleft"),
                    NoticePatternCard(title: "Now", text: "\(length.recentWords) words", symbol: "text.alignleft")
                ],
                day: day,
                score: 78
            ))
        }

        if pages.isEmpty, !spoken.contains("anniversary"),
           let anniversary = ReaderVocabularyNotice.sameDayLastYear(days: allDays, now: now) {
            let span = anniversary.yearsAgo == 1 ? "A year ago today" : "\(anniversary.yearsAgo) years ago today"
            let body = """
            \(span), in \(anniversary.monthName), you kept this:

            "\(anniversary.quote)"

            Same date. Maybe it means nothing. I still found it scratching at today.
            """
            pages.append(noticeSurface(
                id: "anniversary-\(day.id)",
                observationKey: "anniversary",
                spokeTag: "anniversary",
                headline: "This Day, Before",
                prompt: "\(span), you kept a Page.",
                detail: anniversary.quote,
                reason: "An old Page shares today's date, \(anniversary.yearsAgo) year\(anniversary.yearsAgo == 1 ? "" : "s") back.",
                body: body,
                cards: [NoticePatternCard(title: span, text: anniversary.quote, symbol: "calendar")],
                day: day,
                score: 88
            ))
        }

        // The most delicate one, so it goes last and speaks least often: said
        // plainly, "you stopped writing about this" is an accusation the Book
        // has no way to support. It is safe only as an inventory fact.
        if pages.isEmpty, !spoken.contains("word-vanished"),
           let vanished = ReaderVocabularyNotice.vanished(in: vocabulary, now: now) {
            let body = """
            "\(vanished.word)" is in \(vanished.uses) of your Pages. The most recent is \(vanished.lastSeenDays) days old:

            "\(vanished.lastQuote)"

            I'm not calling it missing. Some words finish their work and leave. This one went quiet.
            """
            pages.append(noticeSurface(
                id: "word-vanished-\(vanished.word)-\(day.id)",
                observationKey: "word-vanished",
                spokeTag: "word-vanished",
                headline: "A Word Went Quiet",
                prompt: "\"\(vanished.word)\" has not been in a Page for \(vanished.lastSeenDays) days.",
                detail: vanished.lastQuote,
                reason: "\"\(vanished.word)\" appeared \(vanished.uses) times, then went quiet for \(vanished.lastSeenDays) days.",
                body: body,
                cards: [
                    NoticePatternCard(title: "Pages", text: "\(vanished.uses)", symbol: "books.vertical"),
                    NoticePatternCard(title: "Last seen", text: "\(vanished.lastSeenDays) days ago", symbol: "moon.zzz")
                ],
                day: day,
                score: 74
            ))
        }

        if pages.isEmpty, !spoken.contains("word-pair"),
           let pair = ReaderVocabularyNotice.pair(in: vocabulary) {
            let body = """
            "\(pair.first)" and "\(pair.second)" have arrived on the same Page \(pair.together) times now.

            Most recently:

            "\(pair.latestQuote)"

            Maybe they are strangers. They keep arriving arm in arm anyway.
            """
            pages.append(noticeSurface(
                id: "word-pair-\(pair.first)-\(pair.second)-\(day.id)",
                observationKey: "word-pair",
                spokeTag: "word-pair",
                headline: "Two Words, Arm in Arm",
                prompt: "\"\(pair.first)\" and \"\(pair.second)\" keep arriving on the same Page.",
                detail: pair.latestQuote,
                reason: "These two words arrived together on \(pair.together) Pages.",
                body: body,
                cards: [
                    NoticePatternCard(title: "Together", text: "\(pair.together) Pages", symbol: "link"),
                    NoticePatternCard(title: "Latest", text: pair.latestQuote, symbol: "text.quote")
                ],
                day: day,
                score: 80
            ))
        }
        return pages
    }

    /// Shared shape for the vocabulary Notices: evidence in the body, an
    /// observation key for the ledger, and a `spoke:` tag so the Book does not
    /// say the same kind of thing twice in a season.
    private func noticeSurface(
        id: String,
        observationKey: String,
        spokeTag: String,
        headline: String,
        prompt: String,
        detail: String,
        reason: String,
        body: String,
        cards: [NoticePatternCard],
        day: BookDay,
        score: Int
    ) -> SurfacePage {
        SurfacePage(
            id: "\(source.id)-\(id)",
            type: .bookNotices,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: score,
            reason: reason,
            prompt: prompt,
            detail: detail,
            payload: BookPagePayload(
                headline: headline,
                body: body,
                metadata: [
                    "source": source.id,
                    "observationKey": observationKey,
                    "magicMomentEligible": "true",
                    "tinyPatternCards": Self.encodeNoticePatternCards(cards),
                    "tags": "book-notices,\(spokeTag),spoke:\(spokeTag),local-memory"
                ]
            )
        )
    }

    /// The intimate reading: not what the reader tends to tap, but the exact
    /// conditions repeatedly present when a movement escaped the app and left
    /// a lived trace. It speaks boldly only after repetition, preserves its
    /// counter-reading and falsifier, and uses the ordinary Notice correction
    /// controls so intimacy remains revisable.
    private func alivenessSurfaces(for day: BookDay, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard !didNoticeToday(day) else { return [] }
        let spoken = Set((inputs.days + [day]).flatMap(\.pages).flatMap(\.tags).compactMap { tag -> String? in
            guard tag.hasPrefix("aliveness-pattern:") else { return nil }
            return String(tag.dropFirst("aliveness-pattern:".count))
        })
        guard let pattern = inputs.readerAliveness.patterns(now: now, limit: 8).first(where: {
            !spoken.contains($0.id) && ($0.confidence >= 78 || $0.facets.count >= 2)
        }) else { return [] }

        let quotedEvidence = pattern.evidenceLines.prefix(3).map { "“\($0)”" }.joined(separator: "\n\n")
        let body = """
        This escaped my covers more than once.

        \(pattern.line)

        \(quotedEvidence.isEmpty ? "There is no good sentence to quote, but the events happened on separate days." : quotedEvidence)

        But I could be seeing it crooked: \(pattern.counterReading)

        This would prove me wrong: \(pattern.falsifier)
        """
        let cards = pattern.evidenceLines.prefix(3).enumerated().map { index, line in
            NoticePatternCard(
                title: index == 0 ? "First example" : "Another day",
                text: line,
                symbol: index == 0 ? "sparkle.magnifyingglass" : "point.3.connected.trianglepath.dotted"
            )
        }
        return [SurfacePage(
            id: "\(source.id)-\(pattern.id)-\(day.id)",
            type: .bookNotices,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: min(96, 66 + pattern.confidence / 4 + pattern.facets.count * 3),
            reason: "The same kind of thing escaped my covers on separate days.",
            prompt: "This got out. More than once.",
            detail: pattern.line,
            payload: BookPagePayload(
                headline: "This Keeps Getting Out",
                body: body,
                metadata: [
                    "source": source.id,
                    "readerAlivenessReading": "true",
                    "alivenessPatternID": pattern.id,
                    "alivenessMovement": pattern.movement.rawValue,
                    "alivenessConfidence": "\(pattern.confidence)",
                    "observationKey": "reader-aliveness:\(pattern.id)",
                    "evidencePageIDs": pattern.evidencePageIDs.joined(separator: ","),
                    "tinyPatternCards": Self.encodeNoticePatternCards(cards),
                    "tags": "book-notices,reader-aliveness,aliveness-pattern:\(pattern.id),aliveness-movement:\(pattern.movement.rawValue),local-memory"
                ]
            )
        )]
    }

    /// The long reading uses every qualified witness the Book possesses. A
    /// pulse can inform it, but cannot overrule lived receipts, spontaneous
    /// evidence, reader corrections, or attributable outcomes. Engagement
    /// volume remains supporting context and never creates a bright verdict.
    private func reenchantmentReadingSurfaces(
        for day: BookDay,
        inputs: BookSourceInputs,
        now: Date
    ) -> [SurfacePage] {
        guard !didNoticeToday(day) else { return [] }
        let allDays = inputs.days + [day]
        guard !Self.spokenSignalIDs(days: allDays, within: 21, now: now)
            .contains("reenchantment-reading") else { return [] }
        let reading = ReaderReenchantmentMeasure.reading(
            pulses: inputs.readerStatePulses,
            aliveness: inputs.readerAliveness,
            longGame: inputs.bookInterior.longGame,
            learning: inputs.readerLearning,
            days: allDays,
            now: now
        )
        guard reading.direction != .notEnoughEvidence,
              reading.distinctMeasuredDays >= 4,
              reading.livedProofCount >= 2,
              reading.confidence >= 42 else { return [] }

        let headline: String
        let prompt: String
        switch reading.direction {
        case .brightening:
            headline = "The World Has Been Answering"
            prompt = "I think something is becoming more alive."
        case .holding:
            headline = "The Living Thread"
            prompt = "I found a kind of aliveness that keeps returning."
        case .dimming:
            headline = "The Measure Went Quiet"
            prompt = "I've noticed my recent doors aren't reaching far enough."
        case .notEnoughEvidence:
            return []
        }

        let receipts = reading.whyLines.isEmpty
            ? "The proof is spread across separate lived days rather than one quotable line."
            : reading.whyLines.prefix(4).map { "• \($0)" }.joined(separator: "\n")
        let causalLine = reading.causalOutcomeCount > 0
            ? "\(reading.causalOutcomeCount) later answer\(reading.causalOutcomeCount == 1 ? "" : "s") followed a specific Page closely enough to compare."
            : "I can't honestly say one of my Pages caused what happened next."
        let supportingLine = reading.supportingSignalCount > 0
            ? "I also saw \(reading.supportingSignalCount) meaningful choice\(reading.supportingSignalCount == 1 ? "" : "s") inside my covers. They count, but they don't prove the world changed."
            : "Opening me only proves you opened me."
        let responseLine: String
        switch reading.direction {
        case .brightening:
            responseLine = "I'll show more of what got out, and still throw in strange doors."
        case .holding:
            responseLine = "I'll keep what has legs and try one strange thing at a time."
        case .dimming:
            responseLine = "I'll stop pushing the dull doors. Something else gets teeth."
        case .notEnoughEvidence:
            responseLine = ""
        }
        let body = """
        I watched what happened after my Pages on \(reading.distinctMeasuredDays) separate days. Not taps. Not openings. Things that made it out.

        \(reading.summaryLine)

        Here are the footprints:
        \(receipts)

        \(causalLine)

        \(supportingLine)

        \(responseLine)

        This is my reading. If I bit the wrong ankle, tell me.
        """
        return [SurfacePage(
            id: "\(source.id)-reenchantment-reading-\(day.id)",
            type: .bookNotices,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: reading.direction == .dimming ? 72 : 84,
            reason: "\(reading.livedProofCount) things made it out of my covers across \(reading.distinctMeasuredDays) days.",
            prompt: prompt,
            detail: reading.summaryLine,
            payload: BookPagePayload(
                headline: headline,
                body: body,
                metadata: [
                    "source": source.id,
                    "reenchantmentReading": "true",
                    "reenchantmentDirection": reading.direction.rawValue,
                    "reenchantmentConfidence": "\(reading.confidence)",
                    "reenchantmentMeasuredDays": "\(reading.distinctMeasuredDays)",
                    "reenchantmentLivedProofs": "\(reading.livedProofCount)",
                    "reenchantmentSupportingSignals": "\(reading.supportingSignalCount)",
                    "reenchantmentCounterSignals": "\(reading.counterSignalCount)",
                    "reenchantmentCausalOutcomes": "\(reading.causalOutcomeCount)",
                    "reenchantmentEvidenceStreams": "\(reading.evidenceStreamCount)",
                    "reenchantmentSevenDayAverage": reading.sevenDayAverage.map { String(format: "%.2f", $0) } ?? "",
                    "reenchantmentThirtyDayChange": reading.thirtyDayChange.map { String(format: "%.2f", $0) } ?? "",
                    "reenchantmentDelayedOutcomeRate": reading.delayedOutcomeSuccessRate.map { String(format: "%.3f", $0) } ?? "",
                    "observationKey": "reenchantment-reading",
                    "tags": "book-notices,reenchantment-reading,spoke:reenchantment-reading,local-memory"
                ]
            )
        )]
    }

    private func learningSurfaces(for day: BookDay, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard !didLearnToday(day) else { return [] }
        let metrics = inputs.readerLearning.metrics(days: inputs.days + [day], now: now)
        let momentum = inputs.readerLearning.momentumMetrics()
        guard metrics.meaningfulEventCount >= 4 else { return [] }
        let insights = inputs.readerLearning.insights(now: now, limit: 4)
        guard !insights.isEmpty else { return [] }
        let summary = inputs.readerLearning.shortSummary(now: now)
        let body = Self.learningBody(insights: insights, metrics: metrics, summary: summary)
        let evidence = insights.map { "- \($0.line) \($0.evidence)" }.joined(separator: "\n")
        let patternCards = Self.learningPatternCards(insights: insights, metrics: metrics)
        let score = min(74, 46 + min(16, metrics.meaningfulEventCount / 2) + insights.count * 3)
        return [
            SurfacePage(
                id: "\(source.id)-book-learns-\(day.id)-\(SurfaceCadence.slotID(for: now, hours: 24))",
                type: .bookNotices,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .loreLetter,
                score: score,
                reason: "Your choices changed what I put in your way.",
                prompt: "You have been rearranging me.",
                detail: insights.prefix(2).map(\.line).joined(separator: " "),
                payload: BookPagePayload(
                    headline: "I Learn",
                    body: body,
                    metadata: [
                        "source": source.id,
                        "bookLearning": "true",
                        "learningMetrics": "tenureDays:\(metrics.tenureDays),events:\(metrics.eventCount),positiveRate:\(metrics.positiveRatePercent)",
                        "momentumMetrics": "opened:\(momentum.opened),acted:\(momentum.acted),within30s:\(momentum.actionsWithinThirtySeconds),openToActionRate:\(momentum.openToActionRatePercent),recognized:\(momentum.recognized),followedThreads:\(momentum.followedThreads),keepsakes:\(momentum.keepsakesEarned),medianSeconds:\(momentum.medianOpenToActionSeconds.map { String(format: "%.1f", $0) } ?? "none")",
                        "learningInsights": evidence,
                        "learningSummary": summary ?? "",
                        "tinyPatternCards": Self.encodeNoticePatternCards(patternCards),
                        "adaptiveActions": Self.adaptiveActions(forLearningInsights: insights).joined(separator: "\n"),
                        "tags": "book-learning,reader-learning,book-notices,local-memory"
                    ]
                )
            )
        ]
    }

    // MARK: The People of the Book (Witness Law surfaces)
    //
    // Confirm-on-suggest, quiet, and return: the only places the Book speaks
    // about real people. Everything here quotes the reader's own hand and
    // asks; nothing here (or anywhere) writes words for a real person.

    private func personContextQuestionSurfaces(for day: BookDay, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        let allDays = inputs.days + [day]
        let resting = Self.spokenSignalIDs(days: allDays, within: 45, now: now)
        let hypotheses = inputs.people.threads
            .filter { !$0.resting }
            .flatMap { PeopleOfTheBook.relationshipHypotheses(for: $0, days: allDays) }
            .filter { !resting.contains($0.id) }
            .sorted { $0.id < $1.id }
        guard let hypothesis = hypotheses.first else { return [] }
        let slug = PeopleOfTheBook.slug(for: hypothesis.personName)
        let body = """
        \(hypothesis.personName) keeps leaving this shape in your Pages. I caught it before it crawled into their chapter.

        In your own hand:
        “\(hypothesis.evidenceQuote)”

        \(hypothesis.question) Say yes and I ink it. Say no and I shove it back under the rug.
        """
        return [
            SurfacePage(
                id: "\(source.id)-\(hypothesis.id)-\(day.id)",
                type: .bookNotices,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .loreLetter,
                score: 66,
                reason: "One of your own sentences left a clue about \(hypothesis.personName). I caught it before it escaped.",
                prompt: "Do I keep this about \(hypothesis.personName)?",
                detail: hypothesis.question,
                payload: BookPagePayload(
                    headline: "A Question About a Thread",
                    body: body,
                    metadata: [
                        "source": source.id,
                        "personName": hypothesis.personName,
                        "personSlug": slug,
                        "personContextHypothesisID": hypothesis.id,
                        "personContextKind": hypothesis.kind.rawValue,
                        "personContextValue": hypothesis.value,
                        "personContextDisplayValue": hypothesis.displayValue,
                        "evidencePageIDs": hypothesis.evidencePageIDs.joined(separator: ","),
                        "adaptiveActions": ["confirmPersonContext", "openPeopleOfTheBook"].joined(separator: "\n"),
                        "tags": "book-notices,people-of-the-book,person-context,spoke:\(hypothesis.id),person:\(slug),reader-authored-evidence"
                    ]
                )
            )
        ]
    }

    private func personPlaySurfaces(for day: BookDay, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        let allDays = inputs.days + [day]
        let recentlyInvited = Self.spokenSignalIDs(days: allDays, within: 5, now: now)
        let eligible = inputs.people.threads
            .filter { !$0.resting }
            .compactMap { thread -> (PersonThread, PeopleOfTheBook.RelationshipInvitation)? in
                let slug = PeopleOfTheBook.slug(for: thread.name)
                guard !recentlyInvited.contains("person-play-\(slug)"),
                      let invitation = PeopleOfTheBook.relationshipInvitation(for: thread, onDay: day.id) else {
                    return nil
                }
                return (thread, invitation)
            }
            .sorted { lhs, rhs in
                if lhs.0.lastMentionDay == rhs.0.lastMentionDay { return lhs.0.id < rhs.0.id }
                return lhs.0.lastMentionDay < rhs.0.lastMentionDay
            }
        guard !eligible.isEmpty else { return [] }
        let daySeed = abs("people-play|\(day.id)".stableHash)
        let (_, invitation) = eligible[daySeed % eligible.count]
        let familyReason: String
        switch invitation.family {
        case .sharedHome: familyReason = "Shared life becomes invisible fastest; I'm putting one ordinary detail back into play."
        case .asynchronous: familyReason = "This relationship usually crosses distance or a small glowing screen."
        case .workAndInterest: familyReason = "A shared fascination can open a playful door without asking a work friendship to become something else."
        case .work: familyReason = "I found a work-sized invitation that respects the shape of the relationship."
        case .community: familyReason = "Communities become alive when particular people stop blending into the crowd."
        case .sharedInterest: familyReason = "A shared interest is a ready-made passage between two different minds."
        case .gentle: familyReason = "You told me this thread startles easily. I left my boots by the door."
        case .general: familyReason = "Another person is an entire world; I'm lending one better question."
        }
        let tags = (["people-of-the-book"] + invitation.tags).joined(separator: ",")
        return [
            SurfacePage(
                id: "\(source.id)-\(invitation.id)",
                type: .wonderCompass,
                sourceID: BookPageSourceRegistry.wonderCompassPlayfulMissionSourceID,
                intent: .capture,
                renderStyle: .promptCard,
                score: 68,
                reason: familyReason,
                prompt: invitation.title,
                detail: "A favor involving \(invitation.personName).",
                payload: BookPagePayload(
                    headline: "People of the Book",
                    body: "\(invitation.body)\n\nProof, if anything happens: \(invitation.keepPrompt)",
                    metadata: [
                        "source": source.id,
                        "surfaceLabel": "A Favor for Two",
                        "compassStep": "sense",
                        "compassMode": "standalone",
                        "playfulMissionID": invitation.id,
                        "playfulMissionTitle": invitation.title,
                        "mission": invitation.body,
                        "souvenirPrompt": invitation.keepPrompt,
                        "placeholder": invitation.keepPrompt,
                        "proofKind": "sentence",
                        "personName": invitation.personName,
                        "personID": invitation.personID,
                        "relationshipMode": invitation.family.rawValue,
                        "symbol": "person.2.fill",
                        "startingPageBelief": "64",
                        "tags": tags
                    ]
                )
            )
        ]
    }

    /// Names the fiction owns, plus the reader's own name: never suggested as
    /// real-person threads.
    private static func reservedNames(inputs: BookSourceInputs) -> Set<String> {
        var reserved = Set(NarrativePackRegistry.entities.map(\.name))
        reserved.formUnion(inputs.customCastMembers.map(\.name))
        for fact in inputs.selfFacts where fact.questionID == "name" || fact.id == "onboarding:name" {
            reserved.insert(fact.answer)
        }
        return reserved
    }

    private func personSuggestionSurfaces(for day: BookDay, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard !didNoticeToday(day) else { return [] }
        let allDays = inputs.days + [day]
        let resting = Self.spokenSignalIDs(days: allDays, within: PeopleOfTheBook.suggestionRestDays, now: now)
        let suggestions = PeopleOfTheBook.suggestions(
            days: allDays,
            ledger: inputs.people,
            excludedNames: Self.reservedNames(inputs: inputs),
            now: now
        )
        guard let suggestion = suggestions.first(where: { !resting.contains("person-suggest-\($0.slug)") }) else {
            return []
        }

        let firstMonth = Self.monthName(fromDayID: suggestion.firstDayID)
        let body = """
        This name keeps walking through your handwriting.

        \(suggestion.name). \(suggestion.mentionPageCount) Pages since \(firstMonth), on \(suggestion.distinctDayCount) different days. I haven't added a word.

        Who is \(suggestion.name) in here? Give them a real-person thread. Put them in the Cast. Or tell me to stop nosing at the name.
        """
        let cards = [
            NoticePatternCard(
                title: "In your hand",
                text: "\u{201C}\(suggestion.sampleQuote)\u{201D}",
                symbol: "text.quote"
            ),
            NoticePatternCard(
                title: "The gathering",
                text: "\(suggestion.mentionPageCount) pages, \(suggestion.distinctDayCount) days, since \(firstMonth).",
                symbol: "person.text.rectangle"
            )
        ]
        return [
            SurfacePage(
                id: "\(source.id)-person-suggest-\(suggestion.slug)-\(day.id)",
                type: .bookNotices,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .loreLetter,
                score: 62,
                reason: "A name keeps arriving in your own hand.",
                prompt: "Who is \(suggestion.name) in here?",
                detail: "\(suggestion.name) keeps appearing in your Pages.",
                payload: BookPagePayload(
                    headline: "A Recurring Name",
                    body: body,
                    metadata: [
                        "source": source.id,
                        "personName": suggestion.name,
                        "personSlug": suggestion.slug,
                        "personMentions": "\(suggestion.mentionPageCount)",
                        "personDays": "\(suggestion.distinctDayCount)",
                        "personFirstDay": suggestion.firstDayID,
                        "personLastDay": suggestion.lastDayID,
                        "automaticRepeatRestDays": "60",
                        "noveltyKey": "person-suggestion-\(suggestion.slug)",
                        "evidencePageIDs": suggestion.evidencePageIDs.joined(separator: ","),
                        "tinyPatternCards": Self.encodeNoticePatternCards(cards),
                        "adaptiveActions": ["openPersonThread", "writePersonIntoStory", "letPersonRest"].joined(separator: "\n"),
                        "tags": "book-notices,people-of-the-book,person-suggest,spoke:person-suggest-\(suggestion.slug),local-memory"
                    ]
                )
            )
        ]
    }

    private func personQuietSurfaces(for day: BookDay, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard !didNoticeToday(day), !inputs.people.threads.isEmpty else { return [] }
        let allDays = inputs.days + [day]
        let quietResting = Self.spokenSignalIDs(days: allDays, within: PeopleOfTheBook.quietNoticeRestDays, now: now)
        let returnResting = Self.spokenSignalIDs(days: allDays, within: PeopleOfTheBook.returnNoticeRestDays, now: now)
        let signals = PeopleOfTheBook.quietSignals(ledger: inputs.people, days: allDays, now: now)

        for signal in signals {
            let slug = PeopleOfTheBook.slug(for: signal.thread.name)
            switch signal.kind {
            case .goneQuiet:
                guard !quietResting.contains("person-quiet-\(slug)") else { continue }
                let firstMonth = Self.monthName(fromDayID: signal.thread.firstMentionDay)
                let body = """
                \(signal.thread.name) has been in your margins since \(firstMonth), always in your words. The last Page with them was \(signal.quietDays) days ago.

                The thread went quiet. I'm not tugging. The empty chair was making a scene, so I showed you.
                """
                return [
                    SurfacePage(
                        id: "\(source.id)-person-quiet-\(slug)-\(day.id)",
                        type: .bookNotices,
                        sourceID: source.id,
                        intent: .reflect,
                        renderStyle: .loreLetter,
                        score: 58,
                        reason: "A thread has gone quiet in the margins.",
                        prompt: "This thread went quiet.",
                        detail: "\(signal.thread.name) has been quiet for \(signal.quietDays) days.",
                        payload: BookPagePayload(
                            headline: "A Quiet Thread",
                            body: body,
                            metadata: [
                                "source": source.id,
                                "personName": signal.thread.name,
                                "personSlug": slug,
                                "personQuietDays": "\(signal.quietDays)",
                                "personLastDay": signal.lastMentionDayID,
                                "adaptiveActions": ["restPersonThread"].joined(separator: "\n"),
                                "tags": "book-notices,people-of-the-book,person-quiet,spoke:person-quiet-\(slug),local-memory"
                            ]
                        )
                    )
                ]
            case .returned:
                guard !returnResting.contains("person-return-\(slug)") else { continue }
                let body = """
                \(signal.thread.name) is back. After \(signal.quietDays) quiet days, your ink found them again this week.

                Returning is one of my favorite things a thread can do. I've laid the new Page beside the old ones, where it belongs.
                """
                return [
                    SurfacePage(
                        id: "\(source.id)-person-return-\(slug)-\(day.id)",
                        type: .bookNotices,
                        sourceID: source.id,
                        intent: .reflect,
                        renderStyle: .loreLetter,
                        score: 64,
                        reason: "A thread returned to the margins.",
                        prompt: "Look who came back.",
                        detail: "\(signal.thread.name) is back in your Pages.",
                        payload: BookPagePayload(
                            headline: "A Thread Returns",
                            body: body,
                            metadata: [
                                "source": source.id,
                                "personName": signal.thread.name,
                                "personSlug": slug,
                                "personQuietDays": "\(signal.quietDays)",
                                "personLastDay": signal.lastMentionDayID,
                                "observationKey": "person-return:\(slug):\(signal.quietDays)",
                                "magicMomentEligible": "true",
                                "adaptiveActions": ["scrapbookPage"].joined(separator: "\n"),
                                "tags": "book-notices,people-of-the-book,person-return,spoke:person-return-\(slug),local-memory"
                            ]
                        )
                    )
                ]
            }
        }
        return []
    }

    private static func monthName(fromDayID dayID: String) -> String {
        let parser = DateFormatter()
        parser.calendar = Calendar.current
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: dayID) else { return "earlier" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: date)
    }

    /// How long a spoken signal rests before the Book may bring it up again.
    /// Repetition is the fastest way for noticing to stop feeling like reading.
    static let noticeRestDays = 14

    /// Signal IDs the Book has already said out loud: every kept notice tags
    /// the signals it spoke as `spoke:<signalID>`. Pass a window to get only
    /// the recently spoken (resting) ones; pass nil for ever-spoken.
    static func spokenSignalIDs(days: [BookDay], within restDays: Int?, now: Date) -> Set<String> {
        let cutoff = restDays.map { now.addingTimeInterval(TimeInterval(-$0) * 86_400) }
        return Set(
            days.flatMap(\.pages)
                .filter { page in
                    if let cutoff { return page.createdAt >= cutoff && page.createdAt <= now }
                    return true
                }
                // A page carrying the triad exemption is the Book repeating
                // itself *on purpose*. Fairy tales run on three attempts, three
                // gifts, the same place in three kinds of weather, and this
                // rest machinery exists precisely to stop recurrence, so a
                // deliberate triad has to be excused from it by name. Without
                // this, the second and third appearances would be suppressed as
                // reruns and the pattern could never complete.
                .filter { !$0.tags.contains(TaleTriadKeeper.exemptionTag) }
                .flatMap(\.tags)
                .compactMap { tag in
                    tag.hasPrefix("spoke:") ? String(tag.dropFirst("spoke:".count)) : nil
                }
        )
    }

    private func noticeSurfaces(for day: BookDay, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard !didNoticeToday(day) else { return [] }
        let allSignals = inputs.continuity.strongestSignals.filter { $0.strength >= 58 }
        let clusters = inputs.clusters.isEmpty
            ? BookMotifClusterEngine.clusters(from: inputs.continuity, constellations: inputs.constellations, themes: inputs.themes, now: now)
            : inputs.clusters
        // The Book does not repeat itself: signals spoken in a kept notice
        // inside the rest window stay quiet. If nothing fresh remains, the
        // Book says nothing: silence reads better than a rerun.
        let allDays = inputs.days + [day]
        let resting = Self.spokenSignalIDs(days: allDays, within: Self.noticeRestDays, now: now)
        let everSpoken = Self.spokenSignalIDs(days: allDays, within: nil, now: now)
        let signals = allSignals.filter { !resting.contains($0.id) }
        guard signals.count >= 2 || !clusters.isEmpty else { return [] }
        let selected = Array(signals.prefix(4))
        let selectedClusters = Array(clusters.prefix(2))
        let lead = selected.first
        let currentTheme = inputs.themes.max { $0.monthKey < $1.monthKey }
        let taughtRules = TaughtReading.rules(
            learnedBraidNotes: inputs.learnedBraidNotes,
            days: inputs.days + [day],
            learning: inputs.readerLearning,
            now: now
        )
        // The stranger cousin of recurrence: a word-disjoint "same feeling"
        // pairing, precomputed off-main. It lives only in the body prose, so it
        // is never one of the tripled sections.
        let semanticPairing = inputs.semanticNoticePairing
        let body = Self.body(
            for: selected,
            theme: currentTheme,
            clusters: selectedClusters,
            taughtLine: TaughtReading.noticeLine(from: taughtRules),
            semanticParagraph: semanticPairing?.noticeParagraph,
            respokenIDs: everSpoken,
            variationKey: day.id
        )
        let evidence = (selected.flatMap(\.evidencePageIDs) + selectedClusters.flatMap(\.evidencePageIDs)).prefix(10).joined(separator: ",")
        // The kept copy remembers which signals were spoken, so the Book can
        // rest them (`spokenSignalIDs`) instead of announcing them again.
        let spokeTags = selected.map { "spoke:\($0.id)" }
        let semanticTags = semanticPairing == nil ? [] : ["semantic-notice"]
        let tags = Array(Set(selected.flatMap(\.tags) + selectedClusters.flatMap(\.motifs) + spokeTags + semanticTags + ["book-notices", "literary-continuity", "patterns", "clusters"])).sorted()
        let patternCards = Self.noticePatternCards(signals: selected, clusters: selectedClusters, evidenceCount: inputs.bookNoticeEvidence)
        let slot = SurfaceCadence.slotID(for: now, hours: 24)
        let surfaceID = "\(source.id)-\(day.id)-\(slot)"
        let strongestSignal = max(selected.map(\.strength).max() ?? 0, selectedClusters.map(\.strength).max() ?? 0)
        let signalBonus = strongestSignal / 4
        let countBonus = selected.count * 4 + selectedClusters.count * 6
        let evidenceBonus = min(12, inputs.bookNoticeEvidence * 2)
        let score = min(78, 44 + signalBonus + countBonus + evidenceBonus)
        let detail = (selectedClusters.map(\.line) + selected.map(\.line)).prefix(2).joined(separator: " ")
        return [
            SurfacePage(
                id: surfaceID,
                type: .bookNotices,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .loreLetter,
                score: score,
                reason: lead.map { "I found \($0.subjectName) returning across your kept Pages." }
                    ?? selectedClusters.first.map { "I found \($0.name) across \($0.evidencePageIDs.count) kept Pages." }
                    ?? "I found a repeat across your kept Pages.",
                prompt: "I found something returning.",
                detail: detail,
                payload: BookPagePayload(
                    headline: "I Notice",
                    body: body,
                    metadata: [
                        "source": source.id,
                        "continuitySignals": selected.map(\.promptLine).joined(separator: "\n"),
                        "motifClusters": selectedClusters.map(\.promptLine).joined(separator: "\n"),
                        "evidencePageIDs": evidence,
                        "strongestSignalID": lead?.id ?? selectedClusters.first?.id ?? "",
                        "bookNoticeEvidence": "\(inputs.bookNoticeEvidence)",
                        "observationKey": lead.map { "notice:\($0.id)" } ?? selectedClusters.first.map { "cluster:\($0.id)" } ?? "",
                        "magicMomentEligible": patternCards.count >= 2 ? "true" : "false",
                        "tinyPatternCards": Self.encodeNoticePatternCards(patternCards),
                        "adaptiveActions": Self.adaptiveActions(forNoticeCards: patternCards).joined(separator: "\n"),
                        "tags": tags.joined(separator: ",")
                    ]
                )
            )
        ]
    }

    private func namingSurfaces(for day: BookDay, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        let newlyNamed = ConstellationKeeper.newlyNamed(inputs.constellations, on: now)
        guard let constellation = newlyNamed.first, let name = constellation.name else { return [] }
        guard !day.pages.contains(where: { $0.tags.contains("named:\(constellation.id)") }) else {
            return []
        }
        let firstSeen = constellation.ageInDays(now: now)
        let body = """
        \(constellation.subjectName) came back on \(constellation.sightingCount) days across \(firstSeen) days. It has earned a name.

        I'm calling it \(name).

        \(constellation.latestLine)

        If it changes its shape, I'll change its name. Fair is fair.
        """
        return [
            SurfacePage(
                id: "\(source.id)-named-\(constellation.id)",
                type: .bookNotices,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .loreLetter,
                score: 70,
                reason: "I saw \(constellation.subjectName) on \(constellation.sightingCount) separate days, so I named the repeat \(name).",
                prompt: "This repeat earned a name.",
                detail: name,
                payload: BookPagePayload(
                    headline: "I Name It: \(name)",
                    body: body,
                    metadata: [
                        "source": source.id,
                        "milestone": "true",
                        "constellationID": constellation.id,
                        "constellationName": name,
                        "constellationPhase": constellation.phase.rawValue,
                        "evidencePageIDs": constellation.evidencePageIDs.prefix(10).joined(separator: ","),
                        "tags": "constellation,named:\(constellation.id)"
                    ]
                )
            )
        ]
    }

    /// Anticipation beat: before a thread has earned a name, the Book admits
    /// out loud that it is watching one. This makes the naming clock a visible
    /// promise instead of a silent one: the reader waits *with* the Book
    /// rather than being surprised by it two weeks in. Each thread is teased
    /// at most once (kept teases tag `watched:<id>`), and an unkept tease
    /// rests a few days before offering itself again.
    private func watchedThreadSurfaces(for day: BookDay, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard !didNoticeToday(day) else { return [] }
        let allDays = inputs.days + [day]
        let teased = Set(allDays.flatMap(\.pages).flatMap(\.tags).compactMap { tag in
            tag.hasPrefix("watched:") ? String(tag.dropFirst("watched:".count)) : nil
        })
        guard let constellation = inputs.constellations.first(where: { candidate in
            guard candidate.phase == .watched, candidate.name == nil else { return false }
            guard !teased.contains(candidate.id) else { return false }
            if let record = inputs.surfaceHistory["constellation:\(candidate.id)"],
               now.timeIntervalSince(record.lastShownAt) < 4 * 86_400 { return false }
            return true
        }) else { return [] }
        let sightings = constellation.sightingCount
        let body = """
        \(constellation.subjectName) has turned up on \(sightings) separate days.

        \(constellation.latestLine)

        Enough to watch. Not enough to name. The pencil is waiting and behaving terribly.
        """
        return [
            SurfacePage(
                id: "\(source.id)-watched-\(constellation.id)",
                type: .bookNotices,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .loreLetter,
                score: 62,
                reason: "\(constellation.subjectName) appeared on \(sightings) separate days.",
                prompt: "I am watching \(constellation.subjectName).",
                detail: constellation.latestLine.bookPreviewSentenceLimit(1),
                payload: BookPagePayload(
                    headline: "I Am Watching: \(constellation.subjectName)",
                    body: body,
                    metadata: [
                        "source": source.id,
                        "constellationID": constellation.id,
                        "constellationPhase": constellation.phase.rawValue,
                        "evidencePageIDs": constellation.evidencePageIDs.prefix(10).joined(separator: ","),
                        "tags": "constellation,watched:\(constellation.id)"
                    ]
                )
            )
        ]
    }

    private func wagerSurfaces(for day: BookDay, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        var pages: [SurfacePage] = []
        if let opened = SealedMarginEngine.openedToday(inputs.wagers, on: now).first,
           !day.pages.contains(where: { $0.tags.contains("wager-opened:\(opened.id)") }) {
            let verdict = opened.status == .right
                ? "The seal comes off and I was right."
                : "The seal comes off and I was wrong."
            let ending = opened.status == .right
                ? "The seal looks unbearably smug. I'm trying not to."
                : "The eraser arrived before I could hide. Fair enough."
            let body = """
            On \(Self.sealDateFormatter.string(from: opened.sealedAt)) I sealed a wager in this margin:

            "\(opened.prediction)"

            \(opened.resolutionLine ?? "")

            \(ending)
            """
            pages.append(SurfacePage(
                id: "\(source.id)-wager-opened-\(opened.id)",
                type: .bookNotices,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .loreLetter,
                score: 72,
                reason: verdict,
                prompt: "I crack open a sealed margin.",
                detail: opened.prediction,
                payload: BookPagePayload(
                    headline: opened.status == .right ? "The Seal Opens: I Was Right" : "The Seal Opens: I Was Wrong",
                    body: body,
                    metadata: [
                        "source": source.id,
                        "milestone": "true",
                        "wagerID": opened.id,
                        "wagerMoment": "opened",
                        "wagerStatus": opened.status.rawValue,
                        "wagerSubject": opened.subjectName,
                        "tags": "sealed-margin,wager-opened:\(opened.id)"
                    ]
                )
            ))
        }
        if let sealed = SealedMarginEngine.sealedToday(inputs.wagers, on: now).first,
           !day.pages.contains(where: { $0.tags.contains("wager-sealed:\(sealed.id)") }) {
            let body = """
            I'm risking a guess. \(sealed.basisLine)

            I sealed this in the margin on \(Self.sealDateFormatter.string(from: sealed.sealedAt)):

            "\(sealed.prediction)"

            The seal opens on \(Self.sealDateFormatter.string(from: sealed.opensAt)). Don't let me wriggle out. The Index offered escape hatches. I ate them.
            """
            pages.append(SurfacePage(
                id: "\(source.id)-wager-sealed-\(sealed.id)",
                type: .bookNotices,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .loreLetter,
                score: 68,
                reason: "I made a little bet, wrote the date on it, and sealed it in the margin.",
                prompt: "I make a secret bet.",
                detail: sealed.prediction,
                payload: BookPagePayload(
                    headline: "A Sealed Margin",
                    body: body,
                    metadata: [
                        "source": source.id,
                        "milestone": "true",
                        "wagerID": sealed.id,
                        "wagerMoment": "sealed",
                        "wagerOpensAt": Self.sealDateFormatter.string(from: sealed.opensAt),
                        "wagerSubject": sealed.subjectName,
                        "tags": "sealed-margin,wager-sealed:\(sealed.id)"
                    ]
                )
            ))
        }
        return pages
    }

    private static let sealDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter
    }()

    private func didNoticeToday(_ day: BookDay) -> Bool {
        day.pages.contains { page in
            page.tags.contains("book-notices")
                || (page.type == .bookNotices && !page.tags.contains(where: {
                    $0.hasPrefix("wager-") || $0.hasPrefix("named:") || $0 == "book-learning"
                }))
        }
    }

    private func didLearnToday(_ day: BookDay) -> Bool {
        day.pages.contains { page in
            page.tags.contains("book-learning")
        }
    }

    private static func learningBody(insights: [ReaderLearningInsight], metrics: ReaderLearningMetrics, summary: String?) -> String {
        let lines = insights.map { insight in
            "\(insight.line)\n\(insight.evidence)"
        }.joined(separator: "\n\n")
        let summaryLine = summary.map {
            """

            My short version: \($0)
            """
        } ?? ""
        let tenure = metrics.tenureDays > 0
            ? "I've watched your choices for \(metrics.tenureDays) days."
            : "I am still learning from the first day."
        return """
        You have been rearranging me.

        \(lines)\(summaryLine)

        \(tenure) Your \(metrics.meaningfulEventCount) choices changed what I put in your way. If I learned crooked, cross it out. The eraser is hungry.
        """
    }

    private struct NoticePatternCard {
        var title: String
        var text: String
        var symbol: String
    }

    /// Evidence remains tappable and exact in the archive. Here the Book names
    /// it as something remembered, not as a database row wearing parchment.
    private static func memoryTitle(
        for kind: String,
        at date: Date,
        now: Date,
        calendar: Calendar = .current
    ) -> String {
        let noun = kind.trimmingCharacters(in: .whitespacesAndNewlines)
        if calendar.isDate(date, inSameDayAs: now) { return "Today's \(noun)" }
        if calendar.isDateInYesterday(date) { return "Yesterday's \(noun)" }
        let distance = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)
        ).day ?? 99
        if distance >= 0 && distance < 7 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return "The \(formatter.string(from: date)) \(noun.lowercased())"
        }
        return "An older \(noun.lowercased())"
    }

    private static func spelledCount(_ count: Int) -> String {
        let words = [
            "zero", "one", "two", "three", "four", "five", "six",
            "seven", "eight", "nine", "ten", "eleven", "twelve"
        ]
        return words.indices.contains(count) ? words[count] : "several"
    }

    private static func learningPatternCards(insights: [ReaderLearningInsight], metrics: ReaderLearningMetrics) -> [NoticePatternCard] {
        insights.prefix(3).map { insight in
            switch insight.kind {
            case .warmingType:
                return NoticePatternCard(
                    title: "What you kept more",
                    text: "\(insight.line) I will show a few more of these.",
                    symbol: "text.badge.plus"
                )
            case .coolingType:
                return NoticePatternCard(
                    title: "What you let rest",
                    text: "\(insight.line) I will show fewer of these.",
                    symbol: "moon.zzz"
                )
            case .warmingTag:
                return NoticePatternCard(
                    title: "A subject you kept choosing",
                    text: insight.line,
                    symbol: "point.3.connected.trianglepath.dotted"
                )
            case .timeWindow:
                return NoticePatternCard(
                    title: "When you answered",
                    text: "\(insight.evidence) I will try nearer that hour.",
                    symbol: "clock.badge.checkmark"
                )
            case .compounding:
                return NoticePatternCard(
                    title: "What your choices changed",
                    text: "Your \(metrics.meaningfulEventCount) choices changed what rises next.",
                    symbol: "slider.horizontal.3"
                )
            }
        }
    }

    private static func noticePatternCards(signals: [LiteraryContinuitySignal], clusters: [BookMotifCluster], evidenceCount: Int) -> [NoticePatternCard] {
        var cards: [NoticePatternCard] = clusters.prefix(2).map { cluster in
            NoticePatternCard(
                title: cluster.name,
                text: "\(cluster.line) \(cluster.evidencePageIDs.count) kept Page\(cluster.evidencePageIDs.count == 1 ? "" : "s") fed it.",
                symbol: "square.stack.3d.up"
            )
        }
        cards += signals.prefix(3 - cards.count).map { signal in
            NoticePatternCard(
                title: signal.subjectName,
                text: noticeCardLine(for: signal),
                symbol: noticeCardSymbol(for: signal)
            )
        }
        if cards.isEmpty, evidenceCount > 0 {
            cards.append(NoticePatternCard(
                title: "Pages I used",
                text: "\(evidenceCount) kept Page\(evidenceCount == 1 ? "" : "s") led me here.",
                symbol: "books.vertical"
            ))
        }
        return Array(cards.prefix(3))
    }

    private static func noticeCardLine(for signal: LiteraryContinuitySignal) -> String {
        switch signal.kind {
        case .pattern:
            return "\(signal.line) It appeared again."
        case .beliefLifecycle:
            return "\(signal.line) It keeps coming back, so I'm still watching."
        case .absence:
            return "\(signal.line) It used to appear. Now it does not."
        case .duration:
            return "\(signal.line) It refused to leave the Pages."
        case .listening:
            return "\(signal.line) Your attention returned here."
        case .sensory:
            return "\(signal.line) A photograph and written Pages pointed to the same thing."
        case .manner:
            return "\(signal.line) The way you wrote changed across Pages."
        }
    }

    private static func noticeCardSymbol(for signal: LiteraryContinuitySignal) -> String {
        switch signal.kind {
        case .pattern: return "point.3.connected.trianglepath.dotted"
        case .beliefLifecycle: return "leaf"
        case .absence: return "moon"
        case .duration: return "clock"
        case .listening: return "ear"
        case .sensory: return "camera.filters"
        case .manner: return "text.line.first.and.arrowtriangle.forward"
        }
    }

    private static func encodeNoticePatternCards(_ cards: [NoticePatternCard]) -> String {
        cards.map { [$0.title, $0.text, $0.symbol].joined(separator: Self.noticeMetadataSeparator) }
            .joined(separator: "\n")
    }

    private static func adaptiveActions(forLearningInsights insights: [ReaderLearningInsight]) -> [String] {
        var actions = ["scrapbookPage", "bindWeeklyIssue"]
        if insights.contains(where: { $0.kind == .coolingType }) {
            actions.append("letPatternRest")
        }
        return actions
    }

    private static func adaptiveActions(forNoticeCards cards: [NoticePatternCard]) -> [String] {
        cards.isEmpty ? ["bindWeeklyIssue"] : ["scrapbookPage", "bindWeeklyIssue", "letPatternRest"]
    }

    private static let noticeMetadataSeparator = "\u{1F}"

    /// The Notices body is the page's narrative frame, not a third restatement
    /// of the observations. The recurrence findings live once, in the "What I
    /// found" cards; here the Book only names the subjects in prose,
    /// then adds what the cards cannot carry: the stranger semantic pairing,
    /// the care, the humility, and what the reader has taught it.
    private static func body(
        for signals: [LiteraryContinuitySignal],
        theme: BookTheme?,
        clusters: [BookMotifCluster] = [],
        taughtLine: String? = nil,
        semanticParagraph: String? = nil,
        respokenIDs: Set<String> = [],
        variationKey: String
    ) -> String {
        let countWord: String
        switch signals.count + clusters.count {
        case 0, 1: countWord = "something"
        case 2: countWord = "two things"
        case 3: countWord = "three things"
        case 4: countWord = "four things"
        default: countWord = "\(signals.count + clusters.count) things"
        }
        // The subjects, named once in prose: durable in the archived text even
        // though their detail lives in the cards.
        let subjects = clusters.map(\.name) + signals.map(\.subjectName)
        let subjectPhrase = Self.subjectList(subjects)
        let named = subjectPhrase.isEmpty ? "" : ": \(subjectPhrase)"
        let scaffoldIndex = Int(UInt(bitPattern: variationKey.stableHash) % 3)
        let opening: String
        let careLine: String
        let humilityLine: String
        switch scaffoldIndex {
        case 0:
            opening = "I found \(countWord)\(named)."
            careLine = "I laid the Pages below."
            humilityLine = "Is this real, or did I join the wrong corners?"
        case 1:
            opening = "\(countWord.capitalized) kept turning up\(named)."
            careLine = "I put the tracks below."
            humilityLine = "Have I joined the right corners?"
        default:
            opening = "\(countWord.capitalized) would not sit still\(named)."
            careLine = "The Pages are below."
            humilityLine = "Do you see it too, or have I got overexcited?"
        }
        // A single continuation note, not one per signal: the Book owns that
        // some of this it has said before without re-listing it.
        let respokenNote = signals.contains { respokenIDs.contains($0.id) }
            ? " I showed you some of these before. They came back, so I am showing you again."
            : ""
        let semantic = semanticParagraph.map { "\n\n\($0)" } ?? ""
        let themeLine = theme.map {
            """

            This month's Pages keep gathering under the name "\($0.name)." \($0.line)
            """
        } ?? ""
        let taughtParagraph = taughtLine.map {
            """


            \($0)
            """
        } ?? ""
        return """
        \(opening)\(respokenNote)\(semantic)

        \(careLine)\(themeLine)\(taughtParagraph)

        \(humilityLine)
        """
    }

    /// "harbor", "harbor and the kettle", "harbor, the kettle, and after dark".
    static func subjectList(_ subjects: [String]) -> String {
        let cleaned = subjects
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        switch cleaned.count {
        case 0: return ""
        case 1: return cleaned[0]
        case 2: return "\(cleaned[0]) and \(cleaned[1])"
        default:
            let head = cleaned.dropLast().joined(separator: ", ")
            return "\(head), and \(cleaned.last!)"
        }
    }

}

struct BookConnectionsPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .bookConnections)

    private struct Finding {
        var id: String
        var title: String
        var left: String?
        var right: String?
        var explanation: String
        var evidencePageIDs: [String]
        var strength: Int
        var weight: Int
    }

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        let rawClusters = inputs.clusters.isEmpty
            ? BookMotifClusterEngine.clusters(from: inputs.continuity, constellations: inputs.constellations, themes: inputs.themes, now: now)
            : inputs.clusters
        let archiveDays = inputs.days + [day]
        let archivePages = archiveDays.flatMap(\.pages)
        let pagesByID = archivePages.reduce(into: [String: BookPage]()) { pages, page in
            pages[page.id] = page
        }
        let semanticEchoLinks = Self.semanticEchoLinks(in: archiveDays)
        let clusterFindings = rawClusters.compactMap { Self.finding(for: $0, pagesByID: pagesByID) }
        let themeFindings = inputs.themes.compactMap { Self.finding(for: $0, pagesByID: pagesByID) }
        let constellationFindings = inputs.constellations
            .filter { $0.isNamed && Self.isConnectionBearing($0.kind) }
            .compactMap { Self.finding(for: $0, pagesByID: pagesByID) }
        let signalFindings = inputs.continuity.strongestSignals
            .filter { $0.strength >= 58 && Self.isConnectionBearing($0.kind) }
            .compactMap { Self.finding(for: $0, pagesByID: pagesByID) }
        let semanticFindings = semanticEchoLinks.compactMap { Self.finding(for: $0, pagesByID: pagesByID) }
        let rankedFindings = (semanticFindings + clusterFindings + themeFindings + constellationFindings + signalFindings)
            .sorted { left, right in
                if left.strength == right.strength { return left.id < right.id }
                return left.strength > right.strength
            }
        var seenEvidencePairs = Set<String>()
        let findings = rankedFindings.filter { finding in
            let evidenceKey = finding.evidencePageIDs.sorted().joined(separator: "|")
            return seenEvidencePairs.insert(evidenceKey).inserted
        }
        let connectionWeight = findings.reduce(0) { $0 + $1.weight }
        guard connectionWeight >= 3 else { return [] }
        guard !day.pages.contains(where: { $0.type == .bookConnections }) else { return [] }
        guard let lead = findings.first else { return [] }
        // One honest pair is enough to draw in pencil. More days and more
        // independent pairs decide whether the line stays pencil or becomes ink.
        let connectionDayIDs = Self.connectionEvidenceDayIDs(in: archiveDays, findings: findings)
        let connectionDays = connectionDayIDs.count
        // Evidence proposes the tier; the twin sets its ceiling. A claim about
        // the reader is a heavier thing to make on a week they are struggling.
        let tier = BookClaimTier
            .tier(evidenceWeight: connectionWeight, distinctDays: connectionDays)
            .capped(by: inputs.twinGates.claimCeiling)
        let score = min(70, max(tier.surfaceScoreBase, 42 + connectionWeight * 2))
        let reason: String
        let strengthLine: String
        switch tier {
        case .glimmer:
            reason = "I found two Pages touching. I have only seen it once."
            strengthLine = "I have only seen this once. The line is pencil, not ink."
        case .gathering:
            reason = "These two things have found each other more than once."
            strengthLine = "It happened again. I am watching the line."
        case .established:
            reason = "These two things keep finding each other."
            strengthLine = "It keeps happening. I am keeping the line."
        }
        let prompt = "I found two things touching."
        let detail = lead.explanation
        let leftBlock = lead.left.map { "ONE PAGE\n“\($0)”\n\n" } ?? ""
        let rightBlock = lead.right.map { "ANOTHER PAGE\n“\($0)”\n\n" } ?? ""
        let body = """
        I found one line worth drawing.

        \(leftBlock)\(rightBlock)WHY I JOINED THEM
        \(lead.explanation)

        \(strengthLine)

        The pins may stop shouting now.
        """
        return [
            SurfacePage(
                id: "\(source.id)-\(day.id)-\(SurfaceCadence.slotID(for: now, hours: 12))",
                type: .bookConnections,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .graphEvent,
                score: score,
                reason: reason,
                prompt: prompt,
                detail: detail,
                payload: BookPagePayload(
                    headline: source.title,
                    body: body,
                    metadata: [
                        "source": source.id,
                        "clusterCount": "\(clusterFindings.count)",
                        "constellationCount": "\(constellationFindings.count)",
                        "themeCount": "\(themeFindings.count)",
                        "strongSignalCount": "\(signalFindings.count)",
                        "semanticEchoCount": "\(semanticFindings.count)",
                        "semanticEchoLead": semanticEchoLinks.first?.line ?? semanticEchoLinks.first?.sourcePageID ?? "",
                        "lead": lead.title,
                        "connectionTitle": lead.title,
                        "connectionLeft": lead.left ?? "",
                        "connectionRight": lead.right ?? "",
                        "connectionExplanation": lead.explanation,
                        "evidencePageIDs": lead.evidencePageIDs.joined(separator: ","),
                        "claimTier": tier.rawValue,
                        "connectionWeight": "\(connectionWeight)",
                        "connectionEvidenceDays": "\(connectionDays)",
                        "tags": "book-connections,continuity,constellations,clusters,themes,semantic-echoes,claim-\(tier.rawValue)"
                    ]
                )
            )
        ]
    }

    private static func semanticEchoLinks(in days: [BookDay]) -> [(sourcePageID: String, newerPageID: String, line: String?)] {
        days.flatMap(\.pages).compactMap { page -> (sourcePageID: String, newerPageID: String, line: String?)? in
            guard page.tags.contains(SemanticKeepEcho.markerTag),
                  let sourceTag = page.tags.first(where: { $0.hasPrefix(SemanticKeepEcho.sourceTagPrefix) }),
                  let sourceID = String(sourceTag.dropFirst(SemanticKeepEcho.sourceTagPrefix.count)).nonEmpty else {
                return nil
            }
            let line = page.tags.first(where: { $0.hasPrefix(SemanticKeepEcho.lineTagPrefix) })
                .map { String($0.dropFirst(SemanticKeepEcho.lineTagPrefix.count)) }
                .flatMap(\.nonEmpty)
            return (sourceID, page.id, line)
        }
    }

    private static func finding(
        for echo: (sourcePageID: String, newerPageID: String, line: String?),
        pagesByID: [String: BookPage]
    ) -> Finding? {
        guard let newer = pagesByID[echo.newerPageID],
              let newerText = evidenceText(for: newer),
              let older = pagesByID[echo.sourcePageID],
              let olderText = evidenceText(for: older) else { return nil }
        return Finding(
            id: "semantic-\(echo.sourcePageID)-\(echo.newerPageID)",
            title: "Two Pages answered each other",
            left: excerpt(olderText),
            right: excerpt(newerText),
            explanation: "They do not repeat the same important words. I still think the newer Page is answering the older one.",
            evidencePageIDs: [echo.sourcePageID, echo.newerPageID],
            strength: 90,
            weight: 3
        )
    }

    private static func finding(for cluster: BookMotifCluster, pagesByID: [String: BookPage]) -> Finding? {
        guard let pair = distinctMotifPair(
            evidencePageIDs: cluster.evidencePageIDs,
            motifs: cluster.motifs,
            pagesByID: pagesByID
        ) else { return nil }
        return Finding(
            id: cluster.id,
            title: cluster.name,
            left: excerpt(pair.leftText),
            right: excerpt(pair.rightText),
            explanation: "“\(pair.leftMotif)” lives in one Page. “\(pair.rightMotif)” lives in another. They keep gathering in the same corner of me.",
            evidencePageIDs: [pair.leftID, pair.rightID],
            strength: cluster.strength,
            weight: 3
        )
    }

    private static func finding(for theme: BookTheme, pagesByID: [String: BookPage]) -> Finding? {
        guard let pair = distinctMotifPair(
            evidencePageIDs: theme.evidencePageIDs,
            motifs: theme.motifs,
            pagesByID: pagesByID
        ) else { return nil }
        return Finding(
            id: theme.id,
            title: theme.name,
            left: excerpt(pair.leftText),
            right: excerpt(pair.rightText),
            explanation: "One Page brought “\(pair.leftMotif).” The other brought “\(pair.rightMotif).” They keep turning up together, so I tied a string between them.",
            evidencePageIDs: [pair.leftID, pair.rightID],
            strength: theme.strength,
            weight: 2
        )
    }

    private static func finding(for constellation: Constellation, pagesByID: [String: BookPage]) -> Finding? {
        finding(
            id: constellation.id,
            title: constellation.displayName,
            line: constellation.latestLine,
            evidencePageIDs: constellation.evidencePageIDs,
            strength: constellation.strengthPeak,
            weight: 2,
            pagesByID: pagesByID
        )
    }

    private static func finding(for signal: LiteraryContinuitySignal, pagesByID: [String: BookPage]) -> Finding? {
        finding(
            id: signal.id,
            title: signal.subjectName,
            line: signal.line,
            evidencePageIDs: signal.evidencePageIDs,
            strength: signal.strength,
            weight: 1,
            pagesByID: pagesByID
        )
    }

    private static func finding(
        id: String,
        title: String,
        line: String,
        evidencePageIDs: [String],
        strength: Int,
        weight: Int,
        pagesByID: [String: BookPage]
    ) -> Finding? {
        let evidence = evidencePageIDs.compactMap { pageID -> (String, String)? in
            guard let page = pagesByID[pageID], let text = evidenceText(for: page) else { return nil }
            return (pageID, text)
        }
        guard evidence.count >= 2 else { return nil }
        return Finding(
            id: id,
            title: title,
            left: excerpt(evidence[0].1),
            right: excerpt(evidence[1].1),
            explanation: line,
            evidencePageIDs: [evidence[0].0, evidence[1].0],
            strength: strength,
            weight: weight
        )
    }

    private static func isConnectionBearing(_ kind: LiterarySignalKind) -> Bool {
        kind == .sensory || kind == .manner
    }

    private static func distinctMotifPair(
        evidencePageIDs: [String],
        motifs: [String],
        pagesByID: [String: BookPage]
    ) -> (leftID: String, leftText: String, leftMotif: String, rightID: String, rightText: String, rightMotif: String)? {
        let motifSet = Set(motifs.map { $0.lowercased() })
        let evidence = evidencePageIDs.compactMap { pageID -> (id: String, text: String, motifs: Set<String>)? in
            guard let page = pagesByID[pageID], let text = evidenceText(for: page) else { return nil }
            let words = LiteraryContinuityProjector.meaningfulWords(in: text)
            let present = motifSet.intersection(words)
            guard !present.isEmpty else { return nil }
            return (pageID, text, present)
        }
        for leftIndex in evidence.indices {
            for rightIndex in evidence.indices where rightIndex > leftIndex {
                let leftOnly = evidence[leftIndex].motifs.subtracting(evidence[rightIndex].motifs).sorted()
                let rightOnly = evidence[rightIndex].motifs.subtracting(evidence[leftIndex].motifs).sorted()
                guard let leftMotif = leftOnly.first, let rightMotif = rightOnly.first else { continue }
                return (
                    evidence[leftIndex].id,
                    evidence[leftIndex].text,
                    leftMotif,
                    evidence[rightIndex].id,
                    evidence[rightIndex].text,
                    rightMotif
                )
            }
        }
        return nil
    }

    private static func evidenceText(for page: BookPage) -> String? {
        page.readerAuthoredTextForAnalysis?.nonEmpty
            ?? page.primaryReaderReadableEvidence?.text.nonEmpty
    }

    private static func excerpt(_ text: String) -> String {
        SemanticKeepEcho.excerpt(of: text, limit: 120)
    }

    /// Only days that hold evidence behind this particular map may enlarge its
    /// claim. Archive age and unrelated Pages are not evidence.
    private static func connectionEvidenceDayIDs(
        in days: [BookDay],
        findings: [Finding]
    ) -> Set<String> {
        let evidencePageIDs = Set(findings.flatMap(\.evidencePageIDs))
        var evidenceDays: Set<String> = []
        for day in days where day.pages.contains(where: { page in
            evidencePageIDs.contains(page.id)
        }) {
            evidenceDays.insert(day.id)
        }
        return evidenceDays
    }

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        candidates(for: day, context: context, inputs: inputs, now: now).first ?? SurfacePage(
            id: "\(source.id)-empty-\(day.id)-\(Int(now.timeIntervalSince1970))",
            type: .bookConnections,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .graphEvent,
            score: 52,
            reason: "I found no honest connection yet.",
            prompt: "No line yet.",
            detail: "Keep more Pages. When two different things keep meeting, I will show you both.",
            payload: BookPagePayload(
                headline: source.title,
                body: "I found no honest line yet. The same word meeting itself does not count. The pins disagree. They can sulk. Keep more Pages. When two different things keep meeting, I will show you both.",
                metadata: [
                    "source": source.id,
                    "tags": "book-connections,continuity,empty"
                ]
            )
        )
    }
}

struct BookRememberedVisitation: Equatable {
    var page: BookPage
    var score: Int
    var reason: String
    /// The concrete signals joining the archived page to the present day.
    /// Kept as evidence metadata even though the open Page leads with the
    /// strongest single reason, so the explanation stays readable.
    var todayConnections: [String]
    var action: String
    /// Set when the Page came back because it is one of the days a standing
    /// correspondence rests on. The desk reads this to mark the rule spoken:
    /// saying it here contaminates the same window as saying it anywhere else,
    /// and the falsifier is only honest if every telling is counted.
    var grimoireCorrespondenceID: String? = nil

    func surface(source: BookPageSource, day: BookDay, now: Date) -> SurfacePage {
        let attributableLivedReceipt = page.livedQuestReceipt.flatMap { receipt in
            page.hasReaderContribution && receipt.hasAnyProof ? receipt : nil
        }
        let storedText = (page.bookAuthoredText ?? page.userInput)
            .removingLegacyRenderedPlateReceipts()
        let readerEvidence = page.primaryReaderReadableEvidence
        let rememberedText = storedText.nonEmpty
            ?? readerEvidence?.text.nonEmpty
            ?? attributableLivedReceipt.map { receipt in
                receipt.hasVisualProof
                    ? "A visual field note returned from ‘\(receipt.title).’"
                    : "A field note returned from ‘\(receipt.title).’"
            }
            ?? ""
        let ageLine = BookRememberedEngine.ageLine(from: page.createdAt, to: now)
        let rememberedTextOwner = page.bookAuthoredText == nil
            ? page.origin
            : BookPageOrigin.generated
        let opening: String
        switch rememberedTextOwner {
        case .userAuthored:
            if let readerEvidence, !readerEvidence.mayQuoteAsReaderWords {
                opening = "\(ageLine), you gave me this:"
            } else {
                opening = "\(ageLine), you wrote this:"
            }
        case .imported:
            opening = "\(ageLine), you brought this in:"
        case .generated, .simulated:
            opening = "\(ageLine), I wrote this. You kept it:"
        }
        let rememberedDisplay = readerEvidence?.mayQuoteAsReaderWords == false
            ? rememberedText
            : "“\(rememberedText)”"
        let returnLine = "It came back because: \(reason)"
        let actionLine = action.hasPrefix("No ") ? action : "Try this now: \(action)"
        let readerContributionLines = page.readerContributions.compactMap { contribution -> String? in
            switch contribution.kind {
            case .sentence:
                guard rememberedTextOwner != .userAuthored, let text = contribution.text else { return nil }
                return "Your words on this Page: “\(text)”"
            case .fictionChoice:
                return contribution.text.map { "Your choice in this fiction: \($0)." }
            case .photograph:
                return readerEvidence?.kind == .photograph ? nil : "You put a photograph into this Page."
            case .audioRecording:
                return readerEvidence?.kind == .voiceRecording ? nil : "You put your voice into this Page."
            }
        }
        let readerContributionBlock = readerContributionLines.isEmpty
            ? ""
            : "\n\n" + readerContributionLines.joined(separator: "\n")
        let livedChangeLine = attributableLivedReceipt.map { receipt in
            let facets = receipt.facets.map(\.title).joined(separator: ", ")
            return "\n\nYou did this in real life. I kept these parts too: \(facets)."
        } ?? ""
        let body = """
        \(opening)

        \(rememberedDisplay)\(readerContributionBlock)

        \(returnLine)\(livedChangeLine)

        \(actionLine)
        """
        let surfaceReason = "This old Page came back because: \(reason)"
        let prompt = "I pulled this old Page out."
        let originalSessionTags = page.tags.filter { $0.hasPrefix("book-session-") }
        let originalSessionID = originalSessionTags.first(where: { $0.hasPrefix("book-session-id:") })
            .map { String($0.dropFirst("book-session-id:".count)) }
        let originalMovement = originalSessionTags.first(where: { $0.hasPrefix("book-session-movement:") })
            .map { String($0.dropFirst("book-session-movement:".count)) }
        let originalCausalExperiment = page.tags.first(where: { $0.hasPrefix("causal-experiment:") })
            .map { String($0.dropFirst("causal-experiment:".count)) }
        let originalCausalMovementExperiment = page.tags.first(where: {
            $0.hasPrefix("causal-movement-experiment:")
        }).map { String($0.dropFirst("causal-movement-experiment:".count)) }
        let returnReceiptTags = [
            originalSessionID.map { "original-book-session-id:\($0)" },
            originalMovement.map { "original-book-session-movement:\($0)" },
            originalCausalExperiment.map { "original-causal-experiment:\($0)" },
            originalCausalMovementExperiment.map { "original-causal-movement-experiment:\($0)" },
            "original-book-session-source:\(page.sourceID)"
        ].compactMap { $0 }
        var metadata = [
            "source": source.id,
            "rememberedPageID": page.id,
            "rememberedPageType": page.type.rawValue,
            "rememberedPageDate": ISO8601DateFormatter().string(from: page.createdAt),
            "rememberedText": rememberedText,
            "rememberedTextOwner": rememberedTextOwner.rawValue,
            "rememberedReaderContributions": readerContributionLines.joined(separator: "\n"),
            "rememberedAgeLine": ageLine,
            "rememberedUsedInBraid": page.usedInBookOfYou ? "true" : "false",
            "rhymeReason": reason,
            "todayConnectionLines": todayConnections.joined(separator: "\n"),
            "thenLine": rememberedText,
            "nowLine": reason,
            "evidencePageIDs": page.id,
            "magicMomentEligible": "true",
            "tinyAction": action,
            "livedQuestReturn": attributableLivedReceipt == nil ? "false" : "true",
            "livedQuestID": attributableLivedReceipt?.questID ?? "",
            "livedQuestKind": attributableLivedReceipt?.kind.rawValue ?? "",
            "livedWonderFacets": attributableLivedReceipt?.facets.map(\.rawValue).joined(separator: ",") ?? "",
            "originalBookSessionReceipts": originalSessionTags.joined(separator: ","),
            "tags": ([
                "book-remembered",
                "archive-return",
                "visitation",
                "remembered-page:\(page.id)"
            ] + (attributableLivedReceipt == nil ? [] : ["lived-quest-return"]) + originalSessionTags + returnReceiptTags)
                .joined(separator: ",")
        ]
        if let encodedMedia = BookPageMediaAsset.encodedForSurfaceMetadata(page.mediaAssets) {
            metadata[BookPageMediaAsset.surfaceMetadataKey] = encodedMedia
        }
        if let grimoireCorrespondenceID {
            metadata["grimoireCorrespondenceID"] = grimoireCorrespondenceID
        }

        return SurfacePage(
            id: "\(source.id)-\(day.id)-\(page.id.stableHash)",
            type: .bookRemembered,
            sourceID: source.id,
            intent: .resurface,
            renderStyle: .archiveReturn,
            score: max(46, min(70, score - 18)),
            reason: surfaceReason,
            prompt: prompt,
            detail: "It came back because: \(reason) \(actionLine)",
            payload: BookPagePayload(
                headline: source.title,
                body: body,
                metadata: metadata
            )
        )
    }

}

enum BookRememberedEngine {
    static func visitation(
        from candidates: [BookPage],
        day: BookDay,
        inputs: BookSourceInputs,
        now: Date,
        calendar: Calendar = .current,
        priorityPageID: String? = nil
    ) -> BookRememberedVisitation? {
        // A warm Long Memory gift keeps its pinned page returning, even when the
        // day doesn't rhyme with it on its own.
        let pinned = FaeGiftEffects.pinnedPageIDs(state: inputs.faeState)
        let relationalConnections = RelationalLoom.connections(
            days: inputs.days + [day],
            readerLearning: inputs.readerLearning,
            facultyEntries: inputs.facultyEntries,
            people: inputs.people,
            continuity: inputs.continuity,
            daybookRows: inputs.daybookRows,
            standingLedger: inputs.standingLedger,
            calendar: calendar
        )
        let relationalConstellations = RelationalLoom.constellations(connections: relationalConnections)
        let currentConditionIDs = RelationalLoom.currentConditionIDs(
            day: day,
            inputs: inputs,
            now: now,
            calendar: calendar
        )
        let grimoireReturns = grimoireReturns(from: inputs.grimoire, calendar: calendar)
        let eligible = candidates
            .filter { isEligible($0, day: day, now: now, calendar: calendar) }
            .map { page -> (page: BookPage, score: Int, reason: String, connections: [String]) in
                var scoredPage = scored(
                    page,
                    inputs: inputs,
                    relationalConnections: relationalConnections,
                    relationalConstellations: relationalConstellations,
                    currentConditionIDs: currentConditionIDs,
                    grimoireReturns: grimoireReturns,
                    now: now,
                    calendar: calendar
                )
                if pinned.contains(page.id) {
                    scoredPage.score += 40
                    scoredPage.reason = "The Long Memory pinned this Page. It told me not to lose it."
                    scoredPage.connections.insert("The Long Memory pinned this Page. It told me not to lose it.", at: 0)
                }
                if priorityPageID == page.id {
                    scoredPage.score += 40
                    scoredPage.reason = "You gave me this after my last answer. I brought it back to show you I kept it."
                    scoredPage.connections.insert("You gave me this after my last answer. I brought it back to show you I kept it.", at: 0)
                }
                return scoredPage
            }
            .filter { $0.score >= 62 }
            .sorted { left, right in
                if left.score == right.score {
                    return left.page.createdAt < right.page.createdAt
                }
                return left.score > right.score
            }
        guard let best = eligible.first else { return nil }
        return BookRememberedVisitation(
            page: best.page,
            score: best.score,
            reason: best.reason,
            todayConnections: best.connections,
            action: best.page.id == priorityPageID
                ? "No errand. I only wanted you to see that I kept it."
                : tinyAction(for: best.page, reason: best.reason, now: now, calendar: calendar),
            // Only claimed when the rule is what the reader will actually read.
            // A Page the grimoire counted but that came back for some louder
            // reason has not spent the claim, so it must not be marked spoken.
            grimoireCorrespondenceID: grimoireReturns[best.page.id].flatMap { entry in
                best.reason == entry.reason ? entry.rowID : nil
            }
        )
    }

    /// Pages the grimoire counted, and the rule each one helped work out.
    ///
    /// Built once per visitation rather than per candidate: `evidencePageIDs`
    /// walks a correspondence's whole life, and the Remembered source scores
    /// every eligible Page in the archive.
    ///
    /// Only rules the Book has actually committed to are used. A `watching`
    /// row is still arithmetic; the reader should not meet it as the reason an
    /// old Page came back.
    static func grimoireReturns(
        from grimoire: GrimoireLedger,
        calendar: Calendar
    ) -> [String: (rowID: String, score: Int, reason: String)] {
        guard !grimoire.rows.isEmpty else { return [:] }
        var table: [String: (rowID: String, score: Int, reason: String)] = [:]
        let committed = grimoire.rows.values
            .filter { $0.isAlive && ($0.state == .standing || $0.state == .spoken) }
            .sorted { left, right in
                if left.strengthPeak == right.strengthPeak { return left.id < right.id }
                return left.strengthPeak > right.strengthPeak
            }
        for row in committed {
            guard let stats = grimoire.currentStats(for: row) else { continue }
            let claim = GrimoireVoice.plainClaim(
                row: row, stats: stats, ledger: grimoire, calendar: calendar
            )
            guard !claim.isEmpty else { continue }
            // A rule the Book stands behind outranks one it only said once.
            let weight = row.state == .standing ? 34 : 22
            let reason = "I counted this Page when I worked something out. \(claim) "
                + "This is one of the \(stats.inHits) days that taught me."
            // Deeper into the archive than the four Pages a claim shows, so a
            // Page can be recognised as evidence without being a headline one.
            for pageID in grimoire.evidencePageIDs(for: row, limit: 24) where table[pageID] == nil {
                table[pageID] = (row.id, weight, reason)
            }
        }
        return table
    }

    static func ageLine(from past: Date, to now: Date, calendar: Calendar = .current) -> String {
        let days = max(1, calendar.dateComponents([.day], from: calendar.startOfDay(for: past), to: calendar.startOfDay(for: now)).day ?? 1)
        if days >= 365 {
            let years = max(1, days / 365)
            return years == 1 ? "About a year ago" : "About \(years) years ago"
        }
        if days >= 60 {
            return "About \(max(2, days / 30)) months ago"
        }
        if days >= 14 {
            return "About \(max(2, days / 7)) weeks ago"
        }
        if days == 1 {
            return "Yesterday"
        }
        return "\(days) days ago"
    }

    private static func isEligible(_ page: BookPage, day: BookDay, now: Date, calendar: Calendar) -> Bool {
        guard page.createdAt < calendar.startOfDay(for: now) else { return false }
        guard page.type != .bookOfYou, page.type != .bookRemembered else { return false }
        // `userInput` carries the Book's own prose as well as the reader's, so
        // testing it for emptiness let a Page the Book wrote qualify as "a Page
        // you wrote" and come back as a memory — which is how the Welcome's
        // "You picked up this Page on…" kept being returned to the reader as
        // something they had said. A Page returns only when the reader put
        // words or a choice into it.
        let hasReaderMaterial = page.canSupplyReflectiveMaterial
        let hasLivedVisual = page.livedQuestReceipt?.hasVisualProof == true
        guard hasReaderMaterial || hasLivedVisual else { return false }
        return !day.pages.contains { todayPage in
            todayPage.tags.contains("remembered-page:\(page.id)")
        }
    }

    private static func scored(
        _ page: BookPage,
        inputs: BookSourceInputs,
        relationalConnections: [RelationalLoomConnection],
        relationalConstellations: [RelationalLoomConstellation],
        currentConditionIDs: Set<String>,
        grimoireReturns: [String: (rowID: String, score: Int, reason: String)] = [:],
        now: Date,
        calendar: Calendar
    ) -> (page: BookPage, score: Int, reason: String, connections: [String]) {
        var score = 42
        var reasons: [String] = []
        // These lines are evidence labels, not literary flourishes. Say the
        // exact match in plain words so the reader can check my work.
        // Scored against the reader's own words, for the same reason the
        // eligibility check above is: a rhyme found in the Book's prose is the
        // Book agreeing with itself.
        let pageText = (page.reflectiveMaterial ?? page.primaryReaderReadableEvidence?.text ?? "").lowercased()
        let pageTags = Set(page.tags.map { $0.lowercased() })
        let currentWeather = [inputs.weather?.phrase, inputs.weather?.forecast, inputs.enchantedWeather?.summary]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")
        let weatherTokens = ["fog", "rain", "snow", "storm", "cloud", "sun", "wind", "cold", "warm", "humid", "clear", "gray", "grey"]
        let weatherMatches = weatherTokens.filter { token in
            currentWeather.contains(token) && (pageText.contains(token) || pageTags.contains(token))
        }
        if let first = weatherMatches.first {
            score += 28
            reasons.append("Today has \(first) too. This old Page has \(first) in it.")
        }

        let hour = calendar.component(.hour, from: now)
        let rememberedHour = calendar.component(.hour, from: page.createdAt)
        if abs(hour - rememberedHour) <= 1 {
            score += 9
            reasons.append(page.origin == .userAuthored && page.bookAuthoredText == nil
                ? "It is nearly the same time of day as when you wrote this."
                : "It is nearly the same time of day as when this Page was kept.")
        }

        let month = calendar.component(.month, from: now)
        let rememberedMonth = calendar.component(.month, from: page.createdAt)
        if month == rememberedMonth {
            score += 10
            reasons.append("It is the same month again.")
        }

        let currentText = [
            inputs.calendarEvents.prefix(4).map(\.title).joined(separator: " "),
            inputs.nearbyPlaces.prefix(4).map(\.name).joined(separator: " "),
            inputs.recentNarrativeEvents.prefix(6).map(\.summary).joined(separator: " ")
        ].joined(separator: " ").lowercased()
        let overlap = meaningfulWords(in: pageText).intersection(meaningfulWords(in: currentText))
        if let word = overlap.sorted().first {
            score += min(18, overlap.count * 6)
            reasons.append("Something today used “\(word),” and this old Page used it too.")
        }

        if let signal = inputs.continuity.signals(relatedTo: page, limit: 1).first {
            score += min(24, max(10, signal.strength / 4))
            let count = max(1, signal.evidencePageIDs.count)
            if count == 1 {
                reasons.append("This Page is where \(signal.subjectName.lowercased()) showed up before.")
            } else {
                reasons.append("This is one of \(count) Pages where \(signal.subjectName.lowercased()) showed up.")
            }
        }

        if let semanticReason = semanticEchoReturnReason(for: page, inputs: inputs) {
            score += 32
            reasons.insert(semanticReason, at: 0)
        }

        if let relational = relationalReturn(
            for: page,
            connections: relationalConnections,
            constellations: relationalConstellations,
            currentConditionIDs: currentConditionIDs
        ) {
            score += relational.score
            reasons.insert(relational.reason, at: 0)
        }

        if let relationshipReason = relationshipReturnReason(for: page, inputs: inputs) {
            score += 16
            reasons.insert(relationshipReason, at: 0)
        }

        if let counted = grimoireReturns[page.id] {
            score += counted.score
            reasons.insert(counted.reason, at: 0)
        }

        if let receipt = page.livedQuestReceipt,
           page.hasReaderContribution,
           receipt.hasAnyProof,
           now.timeIntervalSince(receipt.completedAt) >= 3 * 86_400 {
            score += 26
            let proof = receipt.hasVisualProof && receipt.hasWrittenProof
                ? "words and an image"
                : (receipt.hasVisualProof ? "an image" : "your own words")
            reasons.insert(
                "You did ‘\(receipt.title)’ in real life and brought back \(proof). A checkmark is too small for that, so I pulled this Page out.",
                at: 0
            )
        }

        if page.type == .souvenir {
            score += 8
        }
        if page.usedInBookOfYou {
            score += 6
        }

        if reasons.isEmpty {
            reasons.append("Nothing today matched it. My shelf shoved it out anyway.")
        }
        return (page, score, reasons[0], Array(reasons.prefix(3)))
    }

    private static func relationalReturn(
        for page: BookPage,
        connections: [RelationalLoomConnection],
        constellations: [RelationalLoomConstellation],
        currentConditionIDs: Set<String>
    ) -> (score: Int, reason: String)? {
        if let constellation = constellations.first(where: {
            $0.evidencePageIDs.contains(page.id)
                && currentConditionIDs.contains($0.condition.id)
        }) {
            let score: Int
            let confidence: String
            switch constellation.evidenceTier {
            case .glimmer:
                score = 28
                confidence = "I have only seen this a little"
            case .gathering:
                score = 34
                confidence = "I have seen it more than once"
            case .established:
                score = 40
                confidence = "It keeps happening"
            }
            let outcomes = constellation.branches.map { $0.outcome.label.lowercased() }
            return (
                score,
                "Today has \(constellation.condition.label.lowercased()). This is one of the old Pages where that went with \(outcomes.joined(separator: ", ")). \(confidence.sentenceCapitalized)."
            )
        }
        guard let connection = connections.first(where: {
            $0.evidencePageIDs.contains(page.id)
                && currentConditionIDs.contains($0.condition.id)
        }) else { return nil }
        let score: Int
        let confidence: String
        switch connection.evidenceTier {
        case .glimmer:
            score = 22
            confidence = "I have only seen this a little"
        case .gathering:
            score = 28
            confidence = "I have seen it more than once"
        case .established:
            score = 34
            confidence = "It keeps happening"
        }
        let reason = "Today has \(connection.condition.label.lowercased()). This old Page is one place where that went with \(connection.outcome.label.lowercased()). \(confidence.sentenceCapitalized)."
        return (score, reason)
    }

    private static func semanticEchoReturnReason(for page: BookPage, inputs: BookSourceInputs) -> String? {
        let echoPage = inputs.days
            .flatMap(\.pages)
            .first { candidate in
                candidate.tags.contains(SemanticKeepEcho.markerTag)
                    && candidate.tags.contains("\(SemanticKeepEcho.sourceTagPrefix)\(page.id)")
            }
        guard let echoPage else { return nil }
        if let line = echoPage.tags.first(where: { $0.hasPrefix(SemanticKeepEcho.lineTagPrefix) })?
            .dropFirst(SemanticKeepEcho.lineTagPrefix.count)
            .map(String.init)
            .joined()
            .nonEmpty {
            return "A newer Page woke this one up. Here is where they touched: \(line)"
        }
        return "A newer Page said nearly the same thing in different words."
    }

    private static func relationshipReturnReason(for page: BookPage, inputs: BookSourceInputs) -> String? {
        let pageText = "\(page.promptText) \(page.userInput) \(page.tags.joined(separator: " "))".lowercased()
        if pageText.contains("inkrest") {
            return "I had room for one old Page. Dr. Selene Inkrest was hiding in this one."
        }
        if pageText.contains("vellum") {
            return "I had room for one old Page. Dr. Elowen Vellum was hiding in this one."
        }
        let entities = NarrativePackRegistry.entities + inputs.customCastMembers.map(\.entity)
        let namedEntities = entities
            .filter { entity in
                pageText.contains(entity.id.lowercased())
                    || pageText.contains(entity.name.lowercased())
                    || entity.name
                        .lowercased()
                        .split { !$0.isLetter && !$0.isNumber }
                        .contains { token in token.count >= 5 && pageText.contains(token) }
            }
        if let entity = StableWeightedRoll.pick(
            from: namedEntities.sorted { $0.id < $1.id },
            seed: "\(page.id)-relationship-return-named-entity",
            weight: { $0.narrativeWeight + $0.belief }
        ) {
            return "I had room for one old Page. \(entity.name) was hiding in this one."
        }

        let activeTie = inputs.relationshipField
            .filter { _, tie in tie.warmth + tie.tension + tie.familiarity >= 5 }
            .sorted { left, right in
                let leftWeight = left.value.warmth + left.value.tension + left.value.familiarity
                let rightWeight = right.value.warmth + right.value.tension + right.value.familiarity
                return leftWeight > rightWeight
            }
            .first
        if activeTie != nil, page.type == .letter || page.tags.contains("relationship") || page.tags.contains("friend") || page.tags.contains("family") {
            return "One of your relationships has been moving lately. This old Page is about a relationship too."
        }
        return nil
    }

    private static func meaningfulWords(in text: String) -> Set<String> {
        let stop: Set<String> = ["the", "and", "with", "that", "this", "from", "into", "again", "today", "there", "their", "then", "than", "were", "was", "you", "your", "for", "but", "not"]
        return Set(text
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count >= 4 && !stop.contains($0) }
        )
    }

    private static func tinyAction(for page: BookPage, reason: String, now: Date, calendar: Calendar) -> String {
        if page.livedQuestReceipt?.hasAnyProof == true, page.hasReaderContribution {
            return "No rerun. You already did the real thing. I brought it back so we would not forget."
        }
        let text = "\(page.userInput) \(page.tags.joined(separator: " "))".lowercased()
        if text.contains("walk") || text.contains("trail") || text.contains("outside") {
            return "Go to the nearest door. Look out. What changed while you were in here?"
        }
        if text.contains("hand") || text.contains("touch") || text.contains("window") {
            return "Touch the nearest wall. Is it warm, cold, or keeping secrets?"
        }
        if text.contains("coffee") || text.contains("tea") || text.contains("drink") {
            return "Hold your next cup with both hands. Let it be a small animal."
        }
        if text.contains("amanda") || text.contains("kid") || text.contains("family") || text.contains("friend") {
            return "Send that person one true sentence. You may keep it unsent."
        }
        if reason.lowercased().contains("rain") || reason.lowercased().contains("fog") || reason.lowercased().contains("snow") {
            return "Put your face near a window. See what the weather is up to."
        }
        let hour = calendar.component(.hour, from: now)
        if hour >= 17 {
            return "Touch the table. Tell me one thing from today before it runs off."
        }
        return "Look up. Find one thing this old Page would recognize."
    }
}

struct BodyPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .body)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive,
              let body = inputs.body,
              body.isAvailable else {
            return []
        }

        let isLow = body.score > 0 && body.score <= 35
        let fieldReport = bodyFieldReport(body: body, day: day, context: context, inputs: inputs, now: now)
        return [
            SurfacePage(
                id: "\(source.id)-\(body.status.lowercased())-\(SurfaceCadence.slotID(for: now, hours: 4))",
                type: .body,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .gentleTranslation,
                score: context.distress.isActive || isLow ? 92 : 60,
                reason: fieldReport.reason,
                prompt: fieldReport.prompt,
                detail: fieldReport.detail,
                payload: BookPagePayload(
                    headline: fieldReport.headline,
                    body: fieldReport.body,
                    metadata: [
                        "source": source.id,
                        "status": body.status,
                        "uses": "translated health, fuel, mood",
                        "privacy": "name response, not source",
                        "bodyGlyph": fieldReport.glyph,
                        "vellumReading": fieldReport.vellumReading,
                        "crossThread": fieldReport.crossThread,
                        "experiment": fieldReport.experiment,
                        "metrics": body.metrics.prefix(8).map(\.displayText).joined(separator: " | ")
                    ]
                )
            )
        ]
    }

    private struct BodyFieldReport {
        var headline: String
        var prompt: String
        var detail: String
        var reason: String
        var body: String
        var glyph: String
        var vellumReading: String
        var crossThread: String
        var experiment: String
    }

    private func bodyFieldReport(
        body: BodySourceSignal,
        day: BookDay,
        context: CuratorContext,
        inputs: BookSourceInputs,
        now: Date
    ) -> BodyFieldReport {
        let glyph = bodyGlyph(for: body, context: context)
        let vellum = vellumReading(for: body)
        let crossThread = crossThreadLine(day: day, inputs: inputs, now: now)
        let experiment = bodyExperiment(for: body, context: context, inputs: inputs)
        let prompt: String
        if context.distress.isActive || body.score <= 35 {
            prompt = "The Body Page has lowered the lamps."
        } else if body.score >= 70 {
            prompt = "The Body Page has found a current."
        } else {
            prompt = "The Body Page is drawing a private weather map."
        }
        let detail = "A private field report from Vellum's chart: body signals, fuel, and inner weather braided into one humane next move."
        let text = [
            "\(glyph) \(body.phrase)",
            "",
            "Vellum reads the chart this way: \(vellum)",
            "",
            "Cross-thread: \(crossThread)",
            "",
            "One small experiment: \(experiment)",
            "",
            "Keep one sentence after you try it. I want evidence, not obedience."
        ].joined(separator: "\n")
        return BodyFieldReport(
            headline: "Body Page: \(glyph)",
            prompt: prompt,
            detail: detail,
            reason: "I braided body signals with fuel and inner weather without exposing the sources.",
            body: text,
            glyph: glyph,
            vellumReading: vellum,
            crossThread: crossThread,
            experiment: experiment
        )
    }

    private func bodyGlyph(for body: BodySourceSignal, context: CuratorContext) -> String {
        let status = body.status.lowercased()
        if context.distress.isActive || status.contains("watch") { return "Low Lantern" }
        if status.contains("low") { return "Small Hearth" }
        if status.contains("bright") { return "Walking Star" }
        return "Steady Compass"
    }

    private func vellumReading(for body: BodySourceSignal) -> String {
        let metrics = body.metrics
        let sleep = metricValue("Sleep", in: metrics)
        let steps = metricValue("Steps", in: metrics)
        let active = metricValue("Active energy", in: metrics)
        if sleep > 0 && sleep < 6 {
            return "recovery gets first chair today; everything else should be interpreted through short sleep."
        }
        if steps > 5_500 {
            return "motion has already spoken, so the useful question is what restores the body after the current, not how to prove effort."
        }
        if steps > 0 && steps < 1_500 && active < 150 {
            return "the chart is quiet; this may be a small-threshold day, where warm fuel and one soft errand count."
        }
        if !metrics.isEmpty {
            return "there is enough chart ink to watch timing: energy, rest, food, and mood may be telling one story in different alphabets."
        }
        return "there is not enough chart ink for certainty, which is itself useful: ask the body one kinder question and write down the answer."
    }

    private func crossThreadLine(day: BookDay, inputs: BookSourceInputs, now: Date) -> String {
        let recentEntries = inputs.facultyEntries
            .filter { $0.dayID == day.id || $0.createdAt > Calendar.current.date(byAdding: .day, value: -2, to: now) ?? now }
            .sorted { $0.createdAt > $1.createdAt }
        let hasFuel = recentEntries.contains { $0.kind == .fuel }
        let hasWeather = recentEntries.contains { $0.kind == .innerWeather }
        let keptText = day.capturedPages
            .suffix(5)
            .map { ($0.reflectiveMaterial ?? "").lowercased() }
            .joined(separator: " ")
        if hasFuel && hasWeather {
            return "fuel and inner weather are both on the desk; compare timing and texture before inventing a moral."
        }
        if hasFuel {
            return "fuel has left evidence; add one inner-weather word after the next meal or drink so Vellum and Inkrest can compare notes."
        }
        if hasWeather {
            return "inner weather has a name; pair it with one body fact, like water, sleep, motion, warmth, or stillness."
        }
        if keptText.contains("tired") || keptText.contains("heavy") || keptText.contains("rain") || keptText.contains("static") {
            return "today's kept words already lean toward weather; let the body answer in one plain sensation."
        }
        return "the body, fuel, and mood have not formed a pattern yet; this page is the first pin in the map."
    }

    private func bodyExperiment(for body: BodySourceSignal, context: CuratorContext, inputs: BookSourceInputs) -> String {
        let status = body.status.lowercased()
        let sleep = metricValue("Sleep", in: body.metrics)
        let steps = metricValue("Steps", in: body.metrics)
        if context.distress.isActive {
            return "for one bell window, lower the demand by one notch and keep a sentence about what becomes possible."
        }
        if sleep > 0 && sleep < 6 {
            return "choose recovery before ambition: warm fuel, water, one necessary task, then one sentence about inner weather."
        }
        if status.contains("bright") || steps > 5_500 {
            return "spend ten minutes of that current on something future-you can touch, then stop before the page turns into a scoreboard."
        }
        if status.contains("low") || status.contains("watch") || steps < 1_500 {
            return "make the smallest useful circuit: water, food or warmth, five gentle minutes of movement, and one word for the after."
        }
        if inputs.facultyEntries.contains(where: { $0.kind == .fuel }) {
            return "after the next ordinary fuel note, check whether the body asks for motion, quiet, or company."
        }
        return "ask the body for a threshold: one action so small it cannot become a performance, only evidence."
    }

    private func metricValue(_ label: String, in metrics: [BodySourceSignal.Metric]) -> Double {
        metrics.first { $0.label == label }.flatMap { Double($0.value) } ?? 0
    }
}

struct WeatherPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .weather)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else {
            return []
        }
        guard let weather = inputs.weather,
              weather.isAvailable else {
            return previewCandidates(for: day, now: now)
        }
        let hour = Calendar.current.component(.hour, from: now)
        let enchanted = inputs.enchantedWeather ?? WeatherEnchanter.fallback(weather: weather, now: now)
        let rawParts = [
            weather.currentTemperature.map { "Now: \($0)" },
            weather.forecast.map { "Forecast: \($0)" }
        ].compactMap(\.self)
        let rawLine = rawParts.isEmpty ? weather.phrase : rawParts.joined(separator: " | ")
        let moon = MoonPhaseCalendar.phase(on: now)
        let eveningBody = hour >= 17 || hour < 6
            ? "\(enchanted.enchantified)\n\n\(moon.enchantedLine)\n\nWeather: \(rawLine) · \(moon.name)"
            : "\(enchanted.enchantified)\n\nWeather: \(rawLine) · \(moon.name)"
        let prompt = weatherPrompt(dayID: day.id, selector: enchanted.selector)
        return [
            SurfacePage(
                id: "\(source.id)-\(enchanted.selector)-\(SurfaceCadence.slotID(for: now, hours: 4))",
                type: .weather,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .gentleTranslation,
                score: DailyCheckInCadence.activeWindow(for: now) == nil ? (hour >= 17 ? 87 : 82) : 90,
                reason: "I turned the weather outside into a story-mood, but you can still see the real forecast underneath.",
                prompt: prompt,
                detail: rawLine,
                payload: BookPagePayload(
                    headline: "Weather Page",
                    body: eveningBody,
                    metadata: [
                        "source": source.id,
                        "uses": weather.source,
                        "privacy": "public reference",
                        "selector": enchanted.selector,
                        "symbol": enchanted.symbolName,
                        "rawWeather": weather.phrase,
                        "moonPhase": moon.name,
                        "moonSymbol": moon.symbolName,
                        "weatherFraming": prompt,
                        "cadence": "four-hour"
                    ]
                )
            )
        ]
    }

    private func weatherPrompt(dayID: String, selector: String) -> String {
        let options = [
            "The Weather Page just opened.",
            "The sky left a note in the margin.",
            "Outside weather has entered the binding.",
            "I've been listening at the window.",
            "A little weather followed you inside.",
            "The forecast has smudged the edge of the Page."
        ]
        let index = abs("weather-frame|\(dayID)|\(selector)".stableHash.stableScramble % options.count)
        return options[index]
    }

    private func previewCandidates(for day: BookDay, now: Date) -> [SurfacePage] {
        guard let window = DailyCheckInCadence.activeWindow(for: now) else {
            return []
        }
        let moon = MoonPhaseCalendar.phase(on: now)
        return [
            SurfacePage(
                id: "\(source.id)-preview-\(day.id)-\(window.id)",
                type: .weather,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .gentleTranslation,
                score: 88,
                reason: "The Weather Page has its nose right up on the glass: tap it to read the real sky and let Gemma make it magic.",
                prompt: "The Weather Page is pressed up at the window.",
                detail: "Tap to grab the real forecast and turn it into my own weather-words.",
                payload: BookPagePayload(
                    headline: "Weather Page",
                    body: "The page is blank except for a pressed cloud at the corner. Touch it, and I'll ask the actual sky before I write.",
                    metadata: [
                        "source": source.id,
                        "uses": "forecast on tap",
                        "privacy": "public reference",
                        "selector": "fallback",
                        "requiresWeatherRefresh": "true",
                        "weatherPreview": "true",
                        "symbol": "cloud.sun",
                        "moonPhase": moon.name,
                        "moonSymbol": moon.symbolName,
                        "checkInWindowID": window.id,
                        "automaticRecurrenceSlot": "\(day.id):\(window.id):weather-preview",
                        "cadence": "check-in-window",
                        "tags": "weather,preview,\(window.id)"
                    ]
                )
            )
        ]
    }
}

struct AcademyClassPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .academyClass)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive,
              let (session, block) = AcademyScheduleRegistry.sessionInProgress(at: now) else {
            return []
        }
        let inputs = inputs.resolvingWorldEvents(for: day, now: now)
        return [surface(for: session, block: block, day: day, context: context, inputs: inputs, now: now)]
    }

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        let inputs = inputs.resolvingWorldEvents(for: day, now: now)
        if let (session, block) = AcademyScheduleRegistry.sessionInProgress(at: now) {
            return surface(for: session, block: block, day: day, context: context, inputs: inputs, now: now)
        }
        return SurfacePage(
            id: "\(source.id)-between-bells-\(Int(now.timeIntervalSince1970))",
            type: .academyClass,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: 40,
            reason: "No class or club is in session right now.",
            prompt: "Between Bells",
            detail: AcademyScheduleRegistry.nextSessionDescription(after: now),
            payload: BookPagePayload(
                headline: "The Halls Between Bells",
                // The deck already carries the timetable. The body used to say
                // it again, word for word, under a sentence announcing that
                // nothing was on. The leaf prints both, so this is what the
                // empty corridor is actually like instead.
                body: ReflectiveProse.pick([
                    "Nobody is teaching anything at this hour. The corridor makes its own noise: radiator, chalk dust, somebody's shoes two floors down.",
                    "Empty benches. Last lesson's chalk is still up, and whoever wipes it has not come round yet.",
                    "The halls are between bells, which is the only time you can hear the building itself.",
                    "Doors shut, lamps low. The Academy does most of its thinking in the gaps."
                ], seed: UInt64(abs(day.id.stableHash)), salt: UInt64(Calendar.current.component(.hour, from: now))),
                metadata: [
                    "source": source.id,
                    "tags": "academy,class,between-bells"
                ]
            )
        )
    }

    private func surface(
        for session: AcademySession,
        block: String,
        day: BookDay,
        context: CuratorContext,
        inputs: BookSourceInputs,
        now: Date
    ) -> SurfacePage {
        let isClub = session.kind == .club
        let lesson = AcademyScheduleRegistry.lessonModules[session.id]
        let activity = AcademyActivityRegistry.activity(for: session.id)
        var tags = [
            "academy",
            session.kind.rawValue,
            session.id,
            "class:\(session.id)",
            "subject:\(session.subjectThreadID)"
        ]
        if let leaderEntityID = session.leaderEntityID {
            tags.append("entity:\(leaderEntityID)")
        }
        if let lesson {
            tags.append("lesson:\(lesson.id)")
        }
        let eventPacket = inputs.activeWorldEvents.influencePacket
        let eventInstruction = inputs.activeWorldEvents
            .map { $0.packet.classInstruction }
            .joined(separator: "\n")
        let castPool = NarrativePackRegistry.entities + inputs.customCastMembers.map(\.entity)
        let sessionNames = Set(([session.leader] + session.companions).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        })
        let sessionCast = castPool.filter { entity in
            entity.id == session.leaderEntityID
                || sessionNames.contains(entity.name.lowercased())
        }
        let characterCanon = CharacterCanonPacket.promptSection(for: sessionCast)
        var metadata: [String: String] = [
            "source": source.id,
            "sessionID": session.id,
            "sessionKind": session.kind.rawValue,
            "sessionName": session.name,
            "sessionLeader": session.leader,
            "sessionLeaderEntityID": session.leaderEntityID ?? "",
            "sessionRoom": session.room,
            "sessionCompanions": session.companions.joined(separator: ", "),
            "sessionTeaches": session.teaches,
            "sessionStyle": session.style,
            "sessionSubjectThreadID": session.subjectThreadID,
            "sessionBlock": block,
            CharacterCanonPacket.metadataKey: characterCanon,
            "tags": tags.joined(separator: ",")
        ]
        metadata.merge([
            "lessonModuleID": lesson?.id ?? "",
            "lessonTitle": lesson?.title ?? "",
            "lessonRealSubject": lesson?.realSubject ?? "",
            "lessonConcept": lesson?.concept ?? "",
            "lessonLectureBeats": lesson?.lectureBeats.joined(separator: "\n") ?? "",
            "lessonDemonstration": lesson?.demonstration ?? "",
            "lessonInteractionPrompt": lesson?.interactionPrompt ?? "",
            "lessonRealWorldPractice": lesson?.realWorldPractice ?? "",
            "academyActivityID": activity?.id ?? "",
            "academyActivityKind": activity?.kind.rawValue ?? "",
            "academyActivityTitle": activity?.title ?? "",
            "academyActivityInvitation": activity?.invitation ?? "",
            "academyActivityActionTitle": activity?.actionTitle ?? ""
        ]) { _, new in new }
        if let activity, !activity.fields.isEmpty {
            metadata["academyActivityFields"] = activity.fields
                .map { "\($0.id)|\($0.label)|\($0.placeholder)" }
                .joined(separator: "\n")
        }
        if let range = AcademyScheduleRegistry.timeRange(for: block, on: now) {
            metadata["sessionStartTimestamp"] = "\(range.start.timeIntervalSince1970)"
            metadata["sessionEndTimestamp"] = "\(range.end.timeIntervalSince1970)"
        }
        if !eventPacket.isEmpty {
            metadata["worldEventPacket"] = eventPacket
            metadata["worldEventClassInstruction"] = eventInstruction
            metadata["worldEventIDs"] = inputs.activeWorldEvents.map(\.id).joined(separator: ",")
            metadata["worldEventTitles"] = inputs.activeWorldEvents.map(\.title).joined(separator: ", ")
        }
        let academyTurn = AcademyTurnBuilder.turn(
            session: session,
            lesson: lesson,
            isClub: isClub,
            slotKey: "\(session.id)-\(day.id)-\(block)"
        )
        metadata.merge(academyTurn.metadata) { _, new in new }
        let bodySuffix = eventInstruction.isEmpty ? "" : "\n\nWorld event in force:\n\(eventInstruction)"
        return SurfacePage(
            id: "\(source.id)-\(session.id)-\(day.id)-\(block)",
            type: .academyClass,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: context.distress.isActive ? 50 : (isClub ? 72 : 76),
            reason: isClub
                ? "\(session.name) is gathering right now in \(session.room)."
                : "\(session.name) is in session right now with \(session.leader).",
            prompt: session.name,
            detail: isClub
                ? "Meeting now in \(session.room). \(session.style.prefix(1).uppercased() + session.style.dropFirst())."
                : "In session now with \(session.leader), \(session.room).",
            payload: BookPagePayload(
                headline: isClub ? "Club: \(session.name)" : "Class: \(session.name)",
                body: "The door to \(session.room) is ajar. \(session.leader) is mid-\(isClub ? "gathering" : "lesson"). Open the page to step inside.\(bodySuffix)",
                metadata: metadata
            )
        )
    }
}

/// The Pages submenu is intentionally a tiny piece of fixed book furniture.
/// Keeping this order in shared code makes "The Flyleaf goes first" a tested
/// navigation contract instead of an accident of one SwiftUI stack.
enum GlowPagesMenuSectionID: String, CaseIterable, Hashable {
    case flyleaf
    case playfulMission
    case pageBelief
    case pactMap
}

enum GlowPagesMenuLayout {
    static let orderedSections: [GlowPagesMenuSectionID] = [
        .flyleaf,
        .playfulMission,
        .pageBelief,
        .pactMap
    ]
}

enum FlyleafDoorKind: String, Equatable {
    case bookJump
    case compassRun
    case faeBargain
    case pactErrand
}

/// A read-only projection of an existing quest system into the Flyleaf. The
/// reference id always points back to canonical state in BookSourceInputs; this
/// type is never persisted and never becomes a second quest ledger.
struct FlyleafDoor: Identifiable, Equatable {
    var id: String
    var kind: FlyleafDoorKind
    var referenceID: String
    var eyebrow: String
    var title: String
    var detail: String
    var statusLine: String
    var actionTitle: String
}

struct FlyleafLedger: Equatable {
    var electives: [UnwrittenElective]
    var doors: [FlyleafDoor]

    static let empty = FlyleafLedger(electives: [], doors: [])

    init(electives: [UnwrittenElective], doors: [FlyleafDoor]) {
        self.electives = electives
        self.doors = doors
    }

    var characterQuestCount: Int {
        electives.filter { $0.bookFavorID == nil }.count
    }

    var bookFavorCount: Int {
        electives.filter { $0.bookFavorID != nil }.count
    }

    var openThreadCount: Int {
        electives.count + doors.count
    }

    init(day: BookDay, inputs: BookSourceInputs, now: Date) {
        self.init(
            day: day,
            electives: inputs.electives,
            bookJump: inputs.bookJump,
            faeState: inputs.faeState,
            pactWar: inputs.pactWar,
            now: now
        )
    }

    /// The Capture sheet renders this read-only ledger frequently. It needs
    /// four canonical ledgers, not the complete curation packet, so keep its
    /// presentation path off the large `BookSourceInputs` stack frame.
    init(
        day: BookDay,
        electives sourceElectives: [UnwrittenElective],
        bookJump: BookJumpState,
        faeState: FaePlayerState,
        pactWar: PactWarState,
        now: Date
    ) {
        electives = sourceElectives
            .filter(\.isActive)
            .sorted { $0.createdAt < $1.createdAt }

        var gathered: [FlyleafDoor] = []

        if let jump = bookJump.active {
            gathered.append(
                FlyleafDoor(
                    id: "book-jump:\(jump.id)",
                    kind: .bookJump,
                    referenceID: jump.id,
                    eyebrow: "BOOK JUMP · DEPTH \(jump.depth)",
                    title: jump.title,
                    detail: jump.intention.nonEmpty
                        ?? "The Spine is still somewhere inside this story.",
                    statusLine: jump.souvenirDue
                        ? "The way home is open. Bring a true souvenir if you have one."
                        : "This story is still open at the place you left it.",
                    actionTitle: "Return to the Jump"
                )
            )
        }

        let compass = CompassRunProgress.progress(for: day)
        let hasStartedCompassRun = day.capturedPages.contains { page in
            page.tags.contains { $0.hasPrefix("compass-run:") }
        }
        if hasStartedCompassRun, !compass.completedSteps.isEmpty, !compass.isComplete {
            let next = compass.nextStep
            gathered.append(
                FlyleafDoor(
                    id: "compass-run:\(compass.latestRunID ?? day.id)",
                    kind: .compassRun,
                    referenceID: compass.latestRunID ?? day.id,
                    eyebrow: "WONDER COMPASS · \(compass.completedSteps.count) OF \(CompassRunStep.allCases.count)",
                    title: "A Compass Run",
                    detail: compass.latestSpark.map { "North asked: \($0)" }
                        ?? "The needle is holding your place.",
                    statusLine: "Next: \(next.compassPoint) = \(next.title).",
                    actionTitle: "Return to the Compass"
                )
            )
        }

        for bargain in faeState.bargains
            .filter({ $0.status == .owed })
            .sorted(by: { $0.deadline < $1.deadline }) {
            gathered.append(
                FlyleafDoor(
                    id: "fae-bargain:\(bargain.id)",
                    kind: .faeBargain,
                    referenceID: bargain.id,
                    eyebrow: "FAE EXCHANGE",
                    title: bargain.giftName,
                    detail: bargain.terms,
                    statusLine: "The exchange is open · \(Self.timeLine(until: bargain.deadline, now: now)).",
                    actionTitle: "Open the bargain"
                )
            )
        }

        if let errand = pactWar.openErrand {
            let talismanName = AcademyChapterRegistry.chapter(forTalismanID: errand.talismanID)?
                .talismanName ?? "A Talisman"
            let territoryName = PactTerritoryRegistry.territory(id: errand.territoryID)?
                .name ?? "a contested place"
            gathered.append(
                FlyleafDoor(
                    id: "pact-errand:\(errand.id)",
                    kind: .pactErrand,
                    referenceID: errand.id,
                    eyebrow: "PACT ERRAND · \(talismanName.uppercased())",
                    title: territoryName,
                    detail: errand.terms,
                    statusLine: "The field report is open · \(Self.timeLine(until: errand.deadline, now: now)).",
                    actionTitle: "Open the errand"
                )
            )
        }

        doors = gathered
    }

    private static func timeLine(until deadline: Date, now: Date) -> String {
        let seconds = deadline.timeIntervalSince(now)
        guard seconds > 0 else { return "it may be answered now or left to rest" }
        let hours = max(1, Int(ceil(seconds / 3_600)))
        if hours >= 24 {
            let days = max(1, Int(ceil(Double(hours) / 24)))
            return "about \(days) day\(days == 1 ? "" : "s") remain"
        }
        return "about \(hours) hour\(hours == 1 ? "" : "s") remain"
    }
}

struct ElectivePageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .elective)
    private static let destinationCooldownDays = 30

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }
        var pages: [SurfacePage] = []
        let ledger = FlyleafLedger(day: day, inputs: inputs, now: now)
        let active = ledger.electives

        if ledger.openThreadCount > 0 {
            pages.append(flyleafSurface(ledger: ledger, day: day, now: now))
        }

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let offeredToday = inputs.electives.contains { calendar.isDate($0.createdAt, inSameDayAs: now) }
        let bookFavor = inputs.bookInterior.activeFavor.flatMap { favor in
            favor.status == .offered && !inputs.electives.contains(where: { $0.bookFavorID == favor.id })
                ? favor
                : nil
        }
        if active.count < UnwrittenElective.maxActive,
           (10..<21).contains(hour),
           !context.distress.isActive,
           let bookFavor {
            pages.append(bookFavorSurface(bookFavor, day: day))
        }
        if active.count < UnwrittenElective.maxActive,
           !offeredToday,
           bookFavor == nil,
           (10..<21).contains(hour),
           !context.distress.isActive,
           let sender = offerSender(inputs: inputs, day: day, now: now) {
            pages.append(offerSurface(sender: sender, inputs: inputs, day: day, now: now))
        }
        return pages.map { authorCapabilities(on: $0) }
    }

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        let ledger = FlyleafLedger(day: day, inputs: inputs, now: now)
        if ledger.openThreadCount > 0 {
            return authorCapabilities(on: flyleafSurface(ledger: ledger, day: day, now: now))
        }
        if let favor = inputs.bookInterior.activeFavor,
           favor.status == .offered,
           !inputs.electives.contains(where: { $0.bookFavorID == favor.id }) {
            return authorCapabilities(on: bookFavorSurface(favor, day: day))
        }
        if let sender = offerSender(inputs: inputs, day: day, now: now) {
            return authorCapabilities(on: offerSurface(sender: sender, inputs: inputs, day: day, now: now))
        }
        return authorCapabilities(on: flyleafSurface(ledger: ledger, day: day, now: now))
    }

    /// The named Flyleaf door always opens the quest ledger itself. Unlike the
    /// generic manual Elective Page, it never substitutes a new quest offer
    /// when the binding is empty.
    func flyleafSurface(for day: BookDay, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        authorCapabilities(on: flyleafSurface(ledger: FlyleafLedger(day: day, inputs: inputs, now: now), day: day, now: now))
    }

    private func authorCapabilities(on page: SurfacePage) -> SurfacePage {
        let metadata = page.payload.metadata
        if metadata["electiveFlyleaf"] == "true" {
            return page.withPageCapabilities(PageCapabilityContract(
                supportedMovements: [.livingContinuity, .humanOtherness, .shelter],
                supportedRoles: [.echo, .horizon],
                emotionalFunctions: [.remember, .connect],
                effort: .glance,
                estimatedMinutes: 1,
                pressureCost: 0.04
            ))
        }
        let isBookFavor = metadata["bookFavorOffer"] == "true"
        return page.withPageCapabilities(PageCapabilityContract(
            supportedMovements: isBookFavor
                ? [.freshSight, .chosenDetour, .scriptFreedom]
                : [.humanOtherness, .chosenDetour, .livingWorld],
            supportedRoles: [.door],
            emotionalFunctions: isBookFavor
                ? [.act, .notice, .wonder]
                : [.connect, .act, .wonder],
            effort: .small,
            reach: .plannedWorld,
            estimatedMinutes: 4,
            asksReader: true,
            pressureCost: isBookFavor ? 0.72 : 0.56,
            proofModes: [.response]
        ))
    }

    private func homeContext(inputs: BookSourceInputs) -> String {
        if let fact = inputs.selfFacts.first(where: { fact in
            fact.tags.contains(where: { $0.contains("home") || $0.contains("place") || $0.contains("town") })
        }) {
            return fact.answer
        }
        if let weather = inputs.weather, weather.isAvailable {
            return "wherever the weather is currently: \(weather.phrase)"
        }
        return "the player's home town (unnamed so far)"
    }

    private func offerSender(inputs: BookSourceInputs, day: BookDay, now: Date) -> NarrativeWorldEntity? {
        let pool = (NarrativePackRegistry.entities + inputs.customCastMembers.map(\.entity))
            .filter { $0.kind == .character }
            .filter { !($0.unwrittenInterest ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .filter { entity in
                // One outstanding favor per character.
                !inputs.electives.contains { $0.characterID == entity.id && $0.isActive }
            }
        guard !pool.isEmpty else { return nil }
        let slot = SurfaceCadence.slotID(for: now, hours: 8)
        let scored = pool.map { entity -> (NarrativeWorldEntity, Int) in
            let jitter = abs("\(day.id)-\(slot)-\(entity.id)-elective".stableHash % 21)
            return (entity, entity.belief + entity.narrativeWeight + jitter)
        }
        return StableWeightedRoll.pick(
            from: scored.sorted { $0.0.id < $1.0.id },
            seed: "\(day.id)-\(slot)-elective-offer-sender",
            weight: { $0.1 }
        )?.0
    }

    private func offerSurface(sender: NarrativeWorldEntity, inputs: BookSourceInputs, day: BookDay, now: Date) -> SurfacePage {
        let cooledPlaces = availableNearbyPlaces(inputs: inputs, now: now)
        return SurfacePage(
            id: "\(source.id)-offer-\(sender.id)-\(day.id)",
            type: .elective,
            sourceID: source.id,
            intent: .capture,
            renderStyle: .loreLetter,
            score: 70,
            reason: "\(sender.name) has been working up the nerve to ask a quest.",
            prompt: "\(sender.name) has a quest to ask",
            detail: "A little folded note, tucked into the flyleaf, waiting for you to open it.",
            payload: BookPagePayload(
                headline: "A Quest",
                body: "A note from \(sender.name) is tucked into my flyleaf. Open the page to read what they are asking, then keep it to accept.",
                metadata: [
                    "source": source.id,
                    "electiveOffer": "true",
                    "senderID": sender.id,
                    "senderName": sender.name,
                    "senderInterest": sender.unwrittenInterest ?? "",
                    "senderTraits": sender.traits.joined(separator: ", "),
                    "senderQuirks": sender.quirks.joined(separator: "; "),
                    "senderBeliefs": sender.beliefs.joined(separator: "; "),
                    "senderGoals": sender.goals.joined(separator: "; "),
                    "senderChapter": sender.chapter ?? "",
                    CharacterCanonPacket.metadataKey: CharacterCanonPacket.promptSection(for: [sender]),
                    "season": AnchorRegistry.currentSeason(for: now),
                    "nearbyPlaces": cooledPlaces.prefix(10).map(\.promptLine).joined(separator: "\n"),
                    "destinationCooldownDays": "\(Self.destinationCooldownDays)",
                    "cooledDestinationCount": "\(max(0, inputs.nearbyPlaces.count - cooledPlaces.count))",
                    "homeContext": homeContext(inputs: inputs),
                    "tags": "elective,offer,entity:\(sender.id)"
                ]
            )
        )
    }

    private func bookFavorSurface(_ favor: BookFavor, day: BookDay) -> SurfacePage {
        let body = """
        \(favor.ask)

        \(favor.whyItMayHelp)

        Bring back: \(favor.practiceShape)

        Keep this Page to say yes. Send it away to say no.
        """
        return SurfacePage(
            id: "book-favor-offer-\(favor.id)",
            type: .elective,
            sourceID: source.id,
            intent: .capture,
            renderStyle: .loreLetter,
            score: 76,
            reason: "I need the reader's eyes for one small piece of trouble.",
            prompt: favor.title,
            detail: favor.ask,
            payload: BookPagePayload(
                headline: favor.title,
                body: body,
                metadata: [
                    "source": source.id,
                    "electiveOffer": "true",
                    "electivePrepared": "true",
                    "bookFavorOffer": "true",
                    "bookFavorID": favor.id,
                    "bookWonderFacet": favor.facet.rawValue,
                    "bookFavorFamily": favor.family.rawValue,
                    "bookFavorCultivates": favor.cultivates.rawValue,
                    "senderID": "the-book",
                    "senderName": "The Book",
                    "electiveTitle": favor.title,
                    "electiveAsk": favor.ask,
                    "electiveWhy": favor.whyItMayHelp,
                    "electivePractice": favor.practiceShape,
                    "electiveReflection": favor.reflectionQuestion,
                    "tags": "elective,offer,book-favor,\(favor.offerTag),wonder:\(favor.facet.rawValue)"
                ]
            )
        )
    }

    private func availableNearbyPlaces(inputs: BookSourceInputs, now: Date) -> [LocalPlaceSignal] {
        guard !inputs.nearbyPlaces.isEmpty else { return [] }
        let recent = inputs.electives.filter { elective in
            if elective.isActive { return true }
            let latest = elective.completedAt ?? elective.createdAt
            return now.timeIntervalSince(latest) < Double(Self.destinationCooldownDays) * 86_400
        }
        guard !recent.isEmpty else { return inputs.nearbyPlaces }
        let recentText = recent
            .map { "\($0.title) \($0.ask) \($0.practiceShape)" }
            .joined(separator: "\n")
            .lowercased()

        return inputs.nearbyPlaces.filter { place in
            !recentText.contains(place.name.lowercased())
        }
    }

    private func flyleafSurface(ledger: FlyleafLedger, day: BookDay, now: Date) -> SurfacePage {
        // The page lists what is actually on it. A return-place that does not
        // show what it is holding is just a signpost.
        var parts = ["This is where I keep the things you chose but have not finished."]
        if !ledger.electives.isEmpty {
            parts.append((["Notes you chose:"] + ledger.electives.map {
                "• \($0.title) — \($0.characterName). \($0.ask)"
            }).joined(separator: "\n"))
        }
        if !ledger.doors.isEmpty {
            parts.append((["Open elsewhere:"] + ledger.doors.map {
                "• \($0.eyebrow): \($0.title). \($0.statusLine)"
            }).joined(separator: "\n"))
        }
        if ledger.openThreadCount == 0 {
            parts.append("Nothing is on it yet. Choose a quest, a favor, a run, a bargain, or an errand, and its thread comes back here.")
        } else {
            parts.append("Tap one to continue it. Five fit. Finish a note with a sentence, photograph, or place proof, or let it rest.")
            if !ledger.doors.isEmpty {
                parts.append("The doors keep their own time. They do not take one of the five note places.")
            }
        }
        let lines = parts.joined(separator: "\n\n")
        let detail = ledger.openThreadCount == 0
            ? "Nothing is waiting for you. The paper can breathe."
            : "A return-place for accepted quests, favors, and unfinished doors."
        return SurfacePage(
            id: "\(source.id)-flyleaf-\(day.id)-\(SurfaceCadence.slotID(for: now, hours: 8))",
            type: .elective,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: 55,
            reason: ledger.openThreadCount == 0
                ? "Nothing is unfinished right now."
                : "You have \(ledger.openThreadCount) unfinished thing\(ledger.openThreadCount == 1 ? "" : "s") here.",
            prompt: "The Flyleaf",
            detail: detail,
            payload: BookPagePayload(
                headline: "Your Unfinished Things",
                body: lines,
                metadata: [
                    "source": source.id,
                    "electiveFlyleaf": "true",
                    "activeCount": "\(ledger.openThreadCount)",
                    "activeElectiveCount": "\(ledger.electives.count)",
                    "characterQuestCount": "\(ledger.characterQuestCount)",
                    "bookFavorCount": "\(ledger.bookFavorCount)",
                    "doorCount": "\(ledger.doors.count)",
                    "doorKinds": ledger.doors.map(\.kind.rawValue).joined(separator: ","),
                    "tags": "elective,flyleaf"
                ]
            )
        )
    }
}

struct EnchantmentPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .enchantment)

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        surface(spell: rotatingSpell(for: day, now: now, manual: true), context: context, now: now, manual: true)
    }

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }
        return [surface(spell: rotatingSpell(for: day, now: now, manual: false), context: context, now: now, manual: false)]
    }

    private func rotatingSpell(for day: BookDay, now: Date, manual: Bool) -> EnchantmentSpell {
        let spells = StoryEnchantmentCatalog.spells
        if manual {
            return spells[Int.random(in: 0..<spells.count)]
        }
        let slot = SurfaceCadence.slotID(for: now, hours: 4)
        let seed = abs("\(day.id)-\(slot)-enchantment".stableHash)
        return spells[seed % spells.count]
    }

    private func surface(spell: EnchantmentSpell, context: CuratorContext, now: Date, manual: Bool) -> SurfacePage {
        let slotID = manual ? "\(Int(now.timeIntervalSince1970))" : SurfaceCadence.slotID(for: now, hours: 4)
        return SurfacePage(
            id: "\(source.id)-\(spell.id)-\(slotID)",
            type: .enchantment,
            sourceID: source.id,
            intent: .capture,
            renderStyle: .promptCard,
            score: context.distress.isActive ? 38 : 56,
            reason: "Some plain little thing near you is ready to have some magic sprinkled on it.",
            prompt: spell.title,
            detail: spell.detail,
            payload: BookPagePayload(
                headline: "Enchantment Page: \(spell.title)",
                body: "\(spell.detail)\n\nGive me a photo, or take one now. I’ll cast \(spell.title) over the real thing, illuminate the photograph, and make a new Page you can keep. The thing gets a spell. It does not have to become imaginary.",
                metadata: [
                    "source": source.id,
                    "enchantmentID": spell.id,
                    "enchantmentName": spell.title,
                    "symbol": spell.symbolName,
                    "tags": "enchantment,proof,real-world-magic,\(spell.id)"
                ]
            )
        ).withPageCapabilities(PageCapabilityContract(
            supportedMovements: [.freshSight, .scriptFreedom, .chosenDetour],
            supportedRoles: [.door],
            emotionalFunctions: [.wonder, .notice, .play, .act],
            effort: .small,
            reach: .nearbyWorld,
            mobility: .stationary,
            estimatedMinutes: 5,
            asksReader: true,
            pressureCost: 0.34,
            proofModes: [.photograph, .observation]
        ))
    }
}

struct LabyrinthWelcomePageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .welcome)

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        welcomeSurface(
            playerName: Self.playerName(from: inputs),
            score: 70,
            reason: "I can always re-open my first page."
        )
    }

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }
        guard inputs.surfaceHistory["source:\(source.id)"] == nil else { return [] }
        guard !day.pages.contains(where: { $0.type == .welcome || $0.tags.contains("welcome-labyrinth") }) else { return [] }

        return [
            welcomeSurface(
                playerName: Self.playerName(from: inputs),
                score: context.distress.isActive ? 72 : 92,
                reason: "The Labyrinth of Stories is introducing itself before asking for anything else."
            )
        ]
    }

    private func welcomeSurface(playerName: String?, score: Int, reason: String) -> SurfacePage {
        let name = playerName?.nonEmpty ?? "Reader"
        return SurfacePage(
            id: "\(source.id)-first-page",
            type: .welcome,
            sourceID: source.id,
            intent: .importReference,
            renderStyle: .loreLetter,
            score: score,
            reason: reason,
            prompt: "Oh. There You Are.",
            detail: "I've got your name. Gemma is asleep in the Colophon. Open this first; I put the waking button inside.",
            payload: BookPagePayload(
                headline: "Oh. There You Are.",
                body: """
                I'm glad you made it. Zara likes to talk.

                I have your name now. A few of your words. The faint beginning of an idea about you.

                Not enough to pretend I know you, of course. That’d be terribly rude.

                But enough to wonder.

                I wonder what you’ll notice that everyone else walks past. I wonder which places will follow you home. Which ordinary Tuesday will turn out to have been important. Which people, questions, mistakes, storms, sandwiches, songs, and small acts of courage will keep appearing in our margins.

                I’m very excited to see what stories we’re going to write together.

                I have pages. I have ink. I have several opinions already, which seems unfair under the circumstances. That is enough for us to begin. It is enough to keep what you choose, return it strangely, and bind it into something with a spine.

                Come on, then.

                I want to see what your Tuesdays are hiding.

                But first, wake the small private mind named Gemma asleep in the Colophon. Use the button below. It lets me read the fine print, hold faraway days on the same thread, and write with warmer, stranger ink.

                Gemma downloads onto this device. It stays here, close to your words. I don't send your private Pages away for it to think.
                """,
                metadata: [
                    "source": source.id,
                    "welcomePage": "true",
                    "firstRunStep": "first-door-welcome",
                    "playerName": name,
                    "privacy": "public reference",
                    "symbol": source.symbolName,
                    "tags": "welcome,welcome-labyrinth,first-run,labyrinth,local-brain,colophon,how-to-play"
                ]
            )
        )
    }

    static func playerName(from inputs: BookSourceInputs) -> String? {
        let usableFacts = inputs.selfFacts.filter { $0.usePermission != .doNotUse }
        let preferred = usableFacts.first { $0.questionID == "onboarding-name" }?.answer
            ?? usableFacts.first { $0.questionID == "called" }?.answer
            ?? usableFacts.first { $0.tags.contains("name") || $0.tags.contains("identity") }?.answer
        return preferred?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }
}

private struct InscriptionReaderProfile {
    var name: String?
    var momentFate: String?
    var hiddenMagicStance: String?
    var mostAlive: String?
    var magicSource: String?
    var snack: String?
    var belief: String?
    var firstSouvenir: String?
    var sleeveWord: String?
    var drawnChapter: String?
    var wickerMode: String?
    var wickerRoll: String?
    var wickerRollNumber: String?
    var wickerTier: String?
    var wickerThread: String?
    var tastePreference: String?
    var comfortBoundary: String?
    var whisperCadence: String?
    var startedAt: Date?

    var hasOriginEvidence: Bool {
        name != nil
            || momentFate != nil
            || hiddenMagicStance != nil
            || mostAlive != nil
            || magicSource != nil
            || snack != nil
            || belief != nil
            || firstSouvenir != nil
            || drawnChapter != nil
            || wickerMode != nil
            || wickerTier != nil
            || wickerThread != nil
            || tastePreference != nil
            || comfortBoundary != nil
    }

    var hasBoundInscriptionEvidence: Bool {
        firstSouvenir != nil
            || sleeveWord != nil
            || drawnChapter != nil
            || wickerMode != nil
            || wickerRoll != nil
            || wickerTier != nil
            || wickerThread != nil
    }

    static func from(_ inputs: BookSourceInputs) -> InscriptionReaderProfile? {
        let usableFacts = inputs.selfFacts.filter { $0.usePermission != .doNotUse }
        let startedAt = usableFacts
            .filter { $0.questionID.hasPrefix("onboarding-") || $0.tags.contains("onboarding") }
            .map(\.createdAt)
            .min()
        let profile = InscriptionReaderProfile(
            name: answer(for: "onboarding-name", in: usableFacts)
                ?? LabyrinthWelcomePageSourceAdapter.playerName(from: inputs),
            momentFate: answer(for: "onboarding-moment-fate", in: usableFacts),
            hiddenMagicStance: answer(for: "onboarding-hidden-magic", in: usableFacts),
            mostAlive: answer(for: "onboarding-most-alive", in: usableFacts),
            magicSource: answer(for: "onboarding-magic-source", in: usableFacts),
            snack: answer(for: "onboarding-snack", in: usableFacts),
            belief: answer(for: "onboarding-belief", in: usableFacts),
            firstSouvenir: OnboardingFirstSouvenirProvenance.readerSentence(
                from: answer(for: "onboarding-first-souvenir", in: usableFacts)
            ),
            sleeveWord: answer(for: "onboarding-sleeve-word", in: usableFacts),
            drawnChapter: answer(for: "onboarding-drawn-chapter", in: usableFacts),
            wickerMode: answer(for: "onboarding-wicker-mode", in: usableFacts),
            wickerRoll: answer(for: "onboarding-wicker-roll", in: usableFacts),
            wickerRollNumber: answer(for: "onboarding-wicker-roll-number", in: usableFacts),
            wickerTier: answer(for: "onboarding-wicker-tier", in: usableFacts),
            wickerThread: answer(for: "onboarding-wicker-thread", in: usableFacts),
            tastePreference: answer(for: "onboarding-taste", in: usableFacts),
            comfortBoundary: answer(for: "onboarding-comfort-boundary", in: usableFacts),
            whisperCadence: answer(for: "onboarding-whisper-cadence", in: usableFacts),
            startedAt: startedAt
        )
        guard profile.name != nil
            || profile.momentFate != nil
            || profile.hiddenMagicStance != nil
            || profile.mostAlive != nil
            || profile.magicSource != nil
            || profile.snack != nil
            || profile.belief != nil
            || profile.firstSouvenir != nil
            || profile.sleeveWord != nil
            || profile.drawnChapter != nil
            || profile.wickerMode != nil
            || profile.wickerRoll != nil
            || profile.wickerRollNumber != nil
            || profile.wickerTier != nil
            || profile.wickerThread != nil
            || profile.tastePreference != nil
            || profile.comfortBoundary != nil
            || profile.whisperCadence != nil
            || profile.startedAt != nil else {
            return nil
        }
        return profile
    }

    private static func answer(for questionID: String, in facts: [SelfFact]) -> String? {
        facts.first { $0.questionID == questionID }?
            .answer
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty
    }
}

struct InscriptionOriginPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(id: "first-door-origin")

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        originSurface(
            profile: InscriptionReaderProfile.from(inputs) ?? InscriptionReaderProfile(),
            day: day,
            score: 74,
            reason: "I can re-open the private origin page made from the reader's first answers."
        )
    }

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }
        guard inputs.surfaceHistory["first-door-origin"] == nil else { return [] }
        guard !day.pages.contains(where: { $0.sourceID == source.id || $0.tags.contains("first-door-origin") }) else { return [] }
        guard let profile = InscriptionReaderProfile.from(inputs), profile.hasOriginEvidence else { return [] }
        return [
            originSurface(
                profile: profile,
                day: day,
                score: context.distress.isActive ? 78 : 94,
                reason: "I have enough first answers to make a private origin page."
            )
        ]
    }

    private func originSurface(profile: InscriptionReaderProfile, day: BookDay, score: Int, reason: String) -> SurfacePage {
        var pressedLines: [String] = []
        if let name = profile.name {
            pressedLines.append("Name in the margin: \(name)")
        }
        if let firstSentence = profile.firstSouvenir {
            pressedLines.append("First true sentence kept: \(firstSentence)")
        }
        if let momentFate = profile.momentFate {
            pressedLines.append("What usually happens to small moments: \(momentFate)")
        }
        if let hiddenMagicStance = profile.hiddenMagicStance {
            pressedLines.append("Hidden magic right now: \(hiddenMagicStance)")
        }
        if let snack = profile.snack {
            pressedLines.append("First margin ration: \(snack)")
        }
        if let belief = profile.belief {
            pressedLines.append("First belief named: \(belief)")
        }
        if let tastePreference = profile.tastePreference {
            pressedLines.append("Pages invited first: \(Self.displayTitle(for: tastePreference))")
        }
        if let comfortBoundary = profile.comfortBoundary {
            pressedLines.append("My opening edge: \(Self.displayTitle(for: comfortBoundary))")
        }
        if let drawnChapter = profile.drawnChapter {
            pressedLines.append("First Chapter argument: \(drawnChapter)")
        }
        if let wickerMode = profile.wickerMode {
            var wickerLine = "Wicker answer: \(Self.displayTitle(for: wickerMode))"
            if let roll = profile.wickerRollNumber {
                wickerLine += ". Inkbones: \(roll)"
            }
            switch profile.wickerRoll {
            case "success":
                wickerLine += ". The page held."
            case "failure":
                wickerLine += ". The page changed course."
            default:
                break
            }
            pressedLines.append(wickerLine)
        }
        if let wickerThread = profile.wickerThread {
            pressedLines.append("The live thread Wicker left:\n\(wickerThread)")
        }
        let pressedBlock = pressedLines.isEmpty
            ? "The blank part has its mouth shut. I won't put your words in it."
            : pressedLines.joined(separator: "\n")
        let headline = profile.name.map { "\($0)'s Origin Page" } ?? "Your Origin Page"
        let evidenceLine = profile.wickerMode == nil
            ? "I used only what you handed me. The guesses were scratching at the door. I bit them."
            : "I used what you handed me and what your choice actually changed. The guesses stayed outside."
        let closing: String
        if profile.firstSouvenir != nil {
            closing = "One true sentence is already under the cover. The beginning has teeth."
        } else if profile.drawnChapter != nil || profile.wickerMode != nil {
            closing = "A real choice left a mark. The beginning has teeth."
        } else if profile.name != nil {
            closing = "Your name is in the margin. The page has stopped pretending it is blank."
        } else {
            closing = "The blank line is keeping its mouth shut until you mark it."
        }
        return SurfacePage(
            id: "\(source.id)-\(day.id)",
            type: .welcome,
            sourceID: source.id,
            intent: .importReference,
            renderStyle: .loreLetter,
            score: score,
            reason: reason,
            prompt: "Your Origin Page",
            detail: "I pressed your first answers before they could wander off.",
            payload: BookPagePayload(
                headline: headline,
                body: """
                I laid the marks you actually made on the table after you left.

                By morning, the page had pressed them into this:

                \(pressedBlock)

                \(evidenceLine)

                \(closing)

                Keep it or send it scurrying. This beginning knows the way back to you now.
                """,
                metadata: [
                    "source": source.id,
                    "firstDoorOrigin": "true",
                    "welcomePage": "true",
                    "firstRunStep": "first-door-origin",
                    "surfaceLabel": "Origin",
                    "playerName": profile.name ?? "",
                    "privacy": "private local",
                    "symbol": source.symbolName,
                    "tags": "welcome,first-door,first-door-origin,origin,onboarding,private-local"
                ]
            )
        )
    }

    private static func displayTitle(for raw: String) -> String {
        switch raw {
        case "letters": return "Letters and voices"
        case "errands": return "Strange errands"
        case "cozy": return "Cozy noticing"
        case "weather-place": return "Weather and place"
        case "eerie": return "Eerie story threads"
        case "oddities": return "Funny little oddities"
        case "gentle": return "Gentle"
        case "balanced": return "Balanced"
        case "strange": return "Let it get strange"
        case "morning": return "Morning"
        case "evening": return "Evening"
        case "both": return "Morning and evening"
        case "inside": return "Only inside the covers"
        case "slice-of-life": return "Slice of Life"
        case "arc": return "Arc"
        case "surprise": return "Surprise"
        default: return raw
        }
    }

}

private struct InscriptionApprenticeshipEntry {
    var id: String
    var dayIndex: Int
    var title: String
    var prompt: String
    var detail: String
    var body: String
    var tags: [String]
    var metadata: [String: String] = [:]
}

private enum InscriptionApprenticeshipCatalog {
    static func entry(for dayIndex: Int, profile: InscriptionReaderProfile) -> InscriptionApprenticeshipEntry? {
        let dayZeroOpening = profile.name.map { "\($0), the page is hungry, but only for one sentence." }
            ?? "The page is hungry, but only for one sentence."
        let dayZeroSensoryExample = profile.snack.map { "or the smell of \($0)" }
            ?? "or one tiny thing you almost missed"

        let dayTwoDetail: String
        let dayTwoBody: String
        let tasteInvitation = profile.tastePreference.map {
            "You asked the shelves for more \(displayTitle(for: $0).lowercased()). Start there. They're pretending not to stare."
        } ?? "Start with something from your actual day. The shelves are pretending not to stare."
        if let belief = profile.belief {
            dayTwoDetail = "The belief you named has been tapping a pencil against the margin."
            dayTwoBody = """
            You told me: \(belief).

            Today, don't defend it. Beliefs grow skittish when marched to a podium. Test it gently instead. Put one small mark beside something that makes it easier to believe, even for a minute.

            \(tasteInvitation)
            """
        } else {
            dayTwoDetail = "Glow is waiting for one small, honest target."
            dayTwoBody = """
            You haven't named a first belief, so I left that line blank.

            Choose one small thing you want to become easier to believe. Test it gently today. Put one mark beside a moment that helps, even for a minute.

            \(tasteInvitation)
            """
        }

        let dayFourDetail: String
        let dayFourBody: String
        var dayFourMetadata = ["opensColophon": "true"]
        if let whisperCadence = profile.whisperCadence {
            let whispers = displayTitle(for: whisperCadence).lowercased()
            dayFourDetail = "The brass bell would like to know whether it has been mannerly."
            dayFourBody = """
            Your first whisper rule was: \(whispers).

            If that still feels right, leave it. The bell will look unbearably pleased. If it doesn't, open the Colophon and change Whispers from the Book. A living Book can be persistent. It can't be a pest.

            If the bell knocks at the wrong time, tell it. Bells can learn.
            """
            dayFourMetadata["whisperCadence"] = whisperCadence
        } else {
            dayFourDetail = "The brass bell is waiting to learn whether it may knock."
            dayFourBody = """
            You haven't given the brass bell a whisper rule yet.

            It can stay silent. If you do want a morning or evening tap, open the Colophon and choose Whispers from the Book. A living Book may be persistent. It can't be a pest.

            The bell will wait for your answer.
            """
        }

        let dayFiveFollowUp = profile.firstSouvenir.map {
            "What wants to happen after “\($0)”?"
        } ?? "Which kept sentence wants a follow-up?"
        let dayFiveEdge: String
        if let comfortBoundary = profile.comfortBoundary {
            dayFiveEdge = "Keep the edge \(displayTitle(for: comfortBoundary).lowercased())."
        } else {
            dayFiveEdge = "Ask it plainly. If the answer feels too sharp or too soft, that correction can help set the edge later."
        }
        let entries = [
            InscriptionApprenticeshipEntry(
                id: "day-0",
                dayIndex: 0,
                title: "Keep One Small Thing",
                prompt: "Find today's first keepable sentence.",
                detail: "I've put out a saucer for one small, true thing.",
                body: """
                \(dayZeroOpening)

                Don't feed it wisdom. Wisdom makes it sluggish. Give it a sound in the room, a color on the counter, the weather's exact little grievance, the good line someone said, \(dayZeroSensoryExample).

                Then put two fingers to the margin. Keep the page only if it has a pulse.
                """,
                tags: ["first-door", "apprenticeship", "day-0", "souvenir"]
            ),
            InscriptionApprenticeshipEntry(
                id: "day-1",
                dayIndex: 1,
                title: "Bind the Free Folio",
                prompt: "Open the BookShop and bind the free folio.",
                detail: "The Bookshop clerk has hidden a gift beneath a price tag of nothing.",
                body: """
                Something in the Bookshop has been coughing politely all morning.

                It's Margins & Mysteries, a free folio of Grey pages, hearth inventories, and small evening mysteries. Open the Goblin Market and bind it into me. New folios don't merely add Pages; they teach my shelves new ways to lean toward you.

                The clerk will insist this is routine inventory. The ribbon around it disagrees.
                """,
                tags: ["first-door", "apprenticeship", "day-1", "bookshop", "free-pack"],
                metadata: ["opensBookShop": "true", "recommendedFreePackID": "margins-and-mysteries"]
            ),
            InscriptionApprenticeshipEntry(
                id: "day-2",
                dayIndex: 2,
                title: "Aim the Glow",
                prompt: "Spend attention on one thing you want more of.",
                detail: dayTwoDetail,
                body: dayTwoBody,
                tags: ["first-door", "apprenticeship", "day-2", "glow"]
            ),
            InscriptionApprenticeshipEntry(
                id: "day-3",
                dayIndex: 3,
                title: "Give Me My Mind",
                prompt: "Visit the Colophon and check the local brain.",
                detail: "A small private mind is asleep in the Colophon, dreaming in lowercase.",
                body: """
                There's a mind curled up in the Colophon.

                It lives entirely on this device. Once awake, it helps letters, story pages, conversations, and braids read your archive with finer attention without carrying private pages beyond the door.

                Open the Colophon and see whether it is ready. Minds, even small ones, appreciate being invited before they begin rearranging the furniture.
                """,
                tags: ["first-door", "apprenticeship", "day-3", "local-brain", "colophon"],
                metadata: ["opensColophon": "true", "localBrainSetup": "true"]
            ),
            InscriptionApprenticeshipEntry(
                id: "day-4",
                dayIndex: 4,
                title: "Check the Bell",
                prompt: "Notice whether the whisper rule still fits.",
                detail: dayFourDetail,
                body: dayFourBody,
                tags: ["first-door", "apprenticeship", "day-4", "notifications", "whispers"],
                metadata: dayFourMetadata
            ),
            InscriptionApprenticeshipEntry(
                id: "day-5",
                dayIndex: 5,
                title: "Ask for a Useful Door",
                prompt: "Come closer with one plain question.",
                detail: "I've drawn up a chair and am trying not to look overeager.",
                body: """
                Come closer with one useful question.

                Not a cosmic one. Cosmic questions tend to shed on the upholstery. Try something with a handle: What should I notice on the walk? \(dayFiveFollowUp)

                \(dayFiveEdge) Bring me a question with a handle. I like those.
                """,
                tags: ["first-door", "apprenticeship", "day-5", "ask-the-book"]
            ),
            InscriptionApprenticeshipEntry(
                id: "day-6",
                dayIndex: 6,
                title: "Read the Week Back",
                prompt: "Find the thread that followed you home.",
                detail: "Seven days of margins are rustling behind you.",
                body: """
                The Inscription has been open for a week.

                Read back what you kept. Don't summarize everything; the Pages dislike being reduced to minutes. Find the one thread that followed you home: a comfort, a joke, a color, a voice, a stubborn little belief.

                Name that thread.

                That is the wonder habit taking shape: notice, keep or let wait, then see what returns. Seven days down. Keep changing the edge until I earn my place on your shelf.
                """,
                tags: ["first-door", "apprenticeship", "day-6", "reread", "wonder-habit"],
                metadata: ["wonderHabitCheckpoint": "7"]
            )
        ]
        return entries.first { $0.dayIndex == dayIndex }
    }

    private static func displayTitle(for raw: String) -> String {
        switch raw {
        case "letters": return "Letters and voices"
        case "errands": return "Strange errands"
        case "cozy": return "Cozy noticing"
        case "weather-place": return "Weather and place"
        case "eerie": return "Eerie story threads"
        case "oddities": return "Funny little oddities"
        case "gentle": return "Gentle"
        case "balanced": return "Balanced"
        case "strange": return "Let it get strange"
        case "morning": return "Morning"
        case "evening": return "Evening"
        case "both": return "Morning and evening"
        case "inside": return "Only inside the covers"
        default: return raw
        }
    }
}

struct InscriptionApprenticeshipPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(id: "first-door-apprenticeship")

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        let profile = InscriptionReaderProfile.from(inputs) ?? InscriptionReaderProfile()
        let dayIndex = apprenticeshipDay(for: profile, now: now) ?? 0
        let entry = InscriptionApprenticeshipCatalog.entry(for: dayIndex, profile: profile)
            ?? InscriptionApprenticeshipCatalog.entry(for: 0, profile: profile)!
        return surface(for: entry, day: day, context: context, score: 70, reason: "The Inscription can re-open today's apprenticeship page.")
    }

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }
        guard let profile = InscriptionReaderProfile.from(inputs),
              let dayIndex = apprenticeshipDay(for: profile, now: now),
              let entry = InscriptionApprenticeshipCatalog.entry(for: dayIndex, profile: profile) else {
            return []
        }
        // Onboarding may already have kept the reader's first true sentence.
        // Do not greet that gift with day zero's request for another sentence;
        // the apprenticeship can begin with tomorrow's genuinely new practice.
        if dayIndex == 0, hasOnboardingSouvenir(day: day, inputs: inputs) {
            return []
        }
        guard inputs.surfaceHistory["first-door-apprenticeship:\(dayIndex)"] == nil else { return [] }
        guard !day.pages.contains(where: { $0.tags.contains("first-door-apprenticeship-\(dayIndex)") }) else { return [] }
        return [
            surface(
                for: entry,
                day: day,
                context: context,
                score: context.distress.isActive ? 74 : 88,
                reason: "The reader is still in the first week; the Book has one sticky practice for today."
            )
        ]
    }

    private func hasOnboardingSouvenir(day: BookDay, inputs: BookSourceInputs) -> Bool {
        if inputs.selfFacts.contains(where: {
            $0.questionID == "onboarding-first-souvenir"
                && $0.usePermission != .doNotUse
                && $0.answer.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty != nil
        }) {
            return true
        }
        return (inputs.days + [day]).flatMap(\.pages).contains { page in
            page.tags.contains("first-run-souvenir")
                || page.tags.contains("onboarding-first-souvenir")
        }
    }

    private func apprenticeshipDay(for profile: InscriptionReaderProfile, now: Date) -> Int? {
        guard let startedAt = profile.startedAt else { return nil }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startedAt)
        let current = calendar.startOfDay(for: now)
        guard let day = calendar.dateComponents([.day], from: start, to: current).day,
              (0...6).contains(day) else {
            return nil
        }
        return day
    }

    private func surface(
        for entry: InscriptionApprenticeshipEntry,
        day: BookDay,
        context: CuratorContext,
        score: Int,
        reason: String
    ) -> SurfacePage {
        SurfacePage(
            id: "\(source.id)-\(entry.id)-\(day.id)",
            type: .helpTips,
            sourceID: source.id,
            intent: .importReference,
            renderStyle: .loreLetter,
            score: score,
            reason: reason,
            prompt: entry.prompt,
            detail: entry.detail,
            payload: BookPagePayload(
                headline: entry.title,
                body: entry.body,
                metadata: [
                    "source": source.id,
                    "firstDoorApprenticeshipDay": "\(entry.dayIndex)",
                    "curatorActionCommission": "true",
                    "tipID": "first-door-apprenticeship-\(entry.dayIndex)",
                    "privacy": "private local",
                    "symbol": source.symbolName,
                    "tags": (entry.tags + ["first-door-apprenticeship-\(entry.dayIndex)", "onboarding", "private-local"]).joined(separator: ",")
                ].merging(entry.metadata) { _, new in new }
            )
        )
    }
}

struct AboutYouPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .aboutYou)

    struct ReaderLine: Equatable {
        var text: String
        var source: String
        var score: Int
        var keptAt: Date
    }

    static func readerLines(in pages: [BookPage], limit: Int = 5) -> [ReaderLine] {
        var seenPageIDs = Set<String>()
        var seenLines = Set<String>()
        return pages
            .filter { seenPageIDs.insert($0.id).inserted }
            .compactMap(readerLine)
            .sorted { left, right in
                left.score == right.score ? left.keptAt > right.keptAt : left.score > right.score
            }
            .filter { line in
                seenLines.insert(line.text.lowercased()).inserted
            }
            .prefix(limit)
            .map { $0 }
    }

    private static func readerLine(from page: BookPage) -> ReaderLine? {
        let tags = Set(page.tags.map { $0.lowercased() })
        let isPlayfulMission = tags.contains("playful-mission")
            || page.sourceID == BookPageSourceRegistry.wonderCompassPlayfulMissionSourceID
        let rawText: String
        let source: String
        let score: Int

        guard let readerText = page.readerAuthoredTextForAnalysis else { return nil }

        if page.type == .letter || page.type == .note {
            rawText = readerText
            source = page.type == .letter ? "a letter you answered" : "a note you answered"
            score = 110
        } else if page.type == .souvenir {
            rawText = readerText
            source = "a one-sentence souvenir"
            score = 105
        } else if isPlayfulMission {
            rawText = readerText
            source = "a playful mission"
            score = 100
        } else if [.diary, .plainPage, .mood, .rest, .wonderCompass].contains(page.type) {
            rawText = readerText
            source = page.type == .diary ? "a journal page" : "a page you kept"
            score = 70
        } else {
            return nil
        }

        let text = rawText
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let wordCount = text.split(whereSeparator: { $0.isWhitespace }).count
        guard (3...45).contains(wordCount), text.count <= 240 else { return nil }
        return ReaderLine(text: text, source: source, score: score, keptAt: page.createdAt)
    }

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }

        let isBound = inputs.selfFacts.contains { $0.questionID == "chapter-binding" }
        let hasName = inputs.selfFacts.contains { $0.tags.contains("name") }
        let bindingDays = inputs.days.isEmpty ? [day] : inputs.days
        let readiness = ChapterBindingOracle.readiness(days: bindingDays, now: now)
        let chapterBinding: SurfacePage?
        let nextPrimerStage = Self.nextUnshownChapterPrimerStage(surfaceHistory: inputs.surfaceHistory)
        if !isBound, hasName, !context.distress.isActive, readiness.isReady, nextPrimerStage == nil {
            let choice = ChapterBindingOracle.chooseChapter(
                days: bindingDays,
                selfFacts: inputs.selfFacts,
                continuity: inputs.continuity,
                entityBeliefOffsets: inputs.entityBeliefOffsets
            )
            chapterBinding = Self.chapterBindingPage(
                source: source,
                choice: choice,
                readiness: readiness
            )
        } else {
            chapterBinding = nil
        }
        let chapterPrimer: SurfacePage?
        if !isBound,
           hasName,
           !context.distress.isActive,
           let nextPrimerStage,
           (readiness.isReady || nextPrimerStage <= readiness.primerStage) {
            chapterPrimer = Self.chapterPrimerPage(source: source, stage: nextPrimerStage, now: now)
        } else {
            chapterPrimer = nil
        }

        var pages: [SurfacePage] = []

        if let cycleReading = Self.attentionCycleReadingPage(
            source: source,
            inputs: inputs,
            now: now
        ) {
            pages.append(cycleReading)
        }

        if !context.distress.isActive,
           let bookMemoryProbe = Self.bookMemoryProbePage(
                source: source,
                day: day,
                inputs: inputs,
                now: now
           ) {
            pages.append(bookMemoryProbe)
        }

        if let pulse = Self.readerStatePulsePage(source: source, day: day, inputs: inputs, now: now) {
            pages.append(pulse)
        }

        if let placeNaming = Self.familiarPlacePage(source: source, inputs: inputs) {
            pages.append(placeNaming)
        }

        if let outgrown = Self.outgrownRolePage(source: source, day: day, inputs: inputs, now: now) {
            pages.append(outgrown)
        }

        if let earnedLabel = Self.earnedWonderLabelPage(source: source, day: day, inputs: inputs, now: now) {
            pages.append(earnedLabel)
        }

        let coldStartQuestionContext = CausalColdStartQuestionContext(
            hasWeatherContext: inputs.weather != nil || inputs.enchantedWeather != nil,
            hasPlaceContext: inputs.currentLocationLabel?.nonEmpty != nil
                || inputs.currentPlaceContext != nil
                || !inputs.nearbyPlaces.isEmpty
                || inputs.nearbyAnchor != nil,
            hasCalendarContext: !inputs.calendarEvents.isEmpty,
            hasCurrentState: inputs.readerStatePulses.currentState(now: now).isKnown,
            qualifiedOutcomeCount: inputs.readerAliveness.causalLedger?.outcomes
                .filter(\.kind.isQualified)
                .count ?? 0
        )
        if let question = SelfKnowledgePackRegistry.nextQuestion(
            knownFacts: inputs.selfFacts,
            day: day,
            now: now,
            coldStart: coldStartQuestionContext
        ) {
            let isFirstQuestion = inputs.selfFacts.isEmpty
            let isFirstInterestQuestion = question.id == "interest-01"
            let isCausalColdStartQuestion = SelfKnowledgePackRegistry.isCausalColdStartQuestion(question.id)
            let isBrightInterlude = SelfKnowledgePackRegistry.isBrightInterludeOwed(knownFacts: inputs.selfFacts)
                && SelfKnowledgePackRegistry.isBrightInterludeQuestion(question)
            let calendar = Calendar.current
            let factsAnsweredToday = inputs.selfFacts.filter { calendar.isDate($0.createdAt, inSameDayAs: now) }
            let causalQuestionsAnsweredToday = factsAnsweredToday.filter {
                SelfKnowledgePackRegistry.isCausalColdStartQuestion($0.questionID)
            }
            let isCadenceAllowed: Bool
            if isFirstQuestion {
                isCadenceAllowed = true
            } else if isFirstInterestQuestion {
                // The Inscription can write many facts in one ceremony. That
                // should not make the first broadly useful interest look like
                // five separate About You interruptions.
                isCadenceAllowed = true
            } else if factsAnsweredToday.count >= SelfKnowledgePackRegistry.maxAboutYouFactsPerDay {
                isCadenceAllowed = false
            } else if isCausalColdStartQuestion, !causalQuestionsAnsweredToday.isEmpty {
                // One deliberate Curator-learning question per lived day is
                // enough. The Book is a companion, not an intake interview.
                isCadenceAllowed = false
            } else if let lastAnsweredAt = inputs.selfFacts.map(\.createdAt).max(),
                      let nextAllowedAt = calendar.date(
                        byAdding: .hour,
                        value: SelfKnowledgePackRegistry.minimumHoursBetweenAboutYouFacts,
                        to: lastAnsweredAt
                      ) {
                isCadenceAllowed = now >= nextAllowedAt
            } else {
                isCadenceAllowed = true
            }

            if isCadenceAllowed {
                let archivedPages = (inputs.days + [day]).flatMap(\.capturedPages)
                let readerLines = question.id == "rut-signal"
                    ? Self.readerLines(in: archivedPages)
                    : []
                let choiceLines = readerLines.isEmpty
                    ? SelfKnowledgePackRegistry.exampleLines(for: question)
                    : readerLines.map(\.text)
                let score = isFirstQuestion
                    ? 83
                    : (isFirstInterestQuestion
                        ? 91
                        : (isBrightInterlude
                            ? 86
                            : (context.distress.isActive
                                ? 46
                                : (isCausalColdStartQuestion ? 77 : 67))))
                let packName = SelfKnowledgePackRegistry.packName(for: question.packID)
                pages.append(
                    SurfacePage(
                        id: "\(source.id)-\(question.packID)-\(question.id)",
                        type: .aboutYou,
                        sourceID: source.id,
                        intent: .capture,
                        renderStyle: .promptCard,
                        score: score,
                        reason: isFirstQuestion
                            ? "I should learn your name before I guess."
                            : (isFirstInterestQuestion
                                ? "One bright interest gives The Bleed and future pages a real shelf to open."
                                : (isBrightInterlude
                                    ? "The Book learned one practical edge. Now it owes the reader a question worth stealing."
                                    : (isCausalColdStartQuestion
                                        ? "This answer would change which real door the Curator tries next."
                                        : "One true thing lets future pages feel less generic."))),
                        prompt: question.prompt,
                        detail: question.detail,
                        payload: BookPagePayload(
                            headline: "I Learn",
                            body: question.placeholder,
                            metadata: [
                                "source": source.id,
                                "questionID": question.id,
                                "packID": question.packID,
                                "packName": packName,
                                "sensitivity": question.sensitivity.rawValue,
                                "usePermission": question.defaultUsePermission.rawValue,
                                "tags": question.tags.joined(separator: ","),
                                "exampleLines": choiceLines.joined(separator: "||"),
                                "exampleLineSources": readerLines.map(\.source).joined(separator: "||"),
                                "exampleLineMode": readerLines.isEmpty ? "examples" : "reader-archive",
                                "choicePrompt": SelfKnowledgePackRegistry.choicePrompt(for: question),
                                "causalColdStartQuestion": isCausalColdStartQuestion ? "true" : "false",
                                "brightInterlude": isBrightInterlude ? "true" : "false",
                                "privacy": "private local profile"
                            ]
                        )
                    )
                )
            }
        }

        if let chapterBinding {
            pages.append(chapterBinding)
        } else if let chapterPrimer {
            pages.append(chapterPrimer)
        }
        return pages
    }

    private static func attentionCycleReadingPage(
        source: BookPageSource,
        inputs: BookSourceInputs,
        now: Date
    ) -> SurfacePage? {
        guard let summary = inputs.attentionProbes.latestCompletedCycle,
              now.timeIntervalSince(summary.completedAt) <= 14 * 86_400 else {
            return nil
        }
        let surfaceID = "\(source.id)-attention-cycle-\(summary.cycle)"
        let wasRead = inputs.readerLearning.events.contains { event in
            event.surfaceID == surfaceID
                && [.opened, .kept, .dismissed].contains(event.action)
        }
        guard !wasRead else { return nil }

        let elsewherePercent = Int(
            (Double(summary.elsewhereCount) / Double(max(1, summary.answeredCount)) * 100)
                .rounded()
        )
        let comparisonParagraph: String
        let comparisonDetail: String
        if let comparison = inputs.attentionProbes.latestCycleComparison,
           comparison.current.cycle == summary.cycle {
            let previousPercent = Int((comparison.previous.elsewhereShare * 100).rounded())
            let change = Int(comparison.elsewherePercentagePointChange.rounded())
            let movement: String
            if change > 0 {
                movement = "Elsewhere occupied \(change) more percentage point\(change == 1 ? "" : "s") in the knocks you answered."
            } else if change < 0 {
                movement = "Elsewhere occupied \(abs(change)) fewer percentage point\(change == -1 ? "" : "s") in the knocks you answered."
            } else {
                movement = "The rounded share of answered Elsewhere moments did not move."
            }
            comparisonParagraph = """
            Last season's answered knocks were \(previousPercent)% Elsewhere. This season's were \(elsewherePercent)%. \(movement) That's a difference between two samples, not proof that you're improving or worsening. I need more life before I get grand about it.
            """
            comparisonDetail = change == 0
                ? "same rounded share as last season"
                : "\(change > 0 ? "+" : "")\(change) points from last season"
        } else {
            comparisonParagraph = "This is the first season. It gives the next one something real to argue with, but it doesn't get to pretend it already knows your pattern."
            comparisonDetail = "first season"
        }
        let body = """
        I knocked \(summary.answeredCount) times. You answered HERE \(summary.hereCount) times and ELSEWHERE \(summary.elsewhereCount) times.

        In the knocks you answered, Elsewhere had \(elsewherePercent)% of the room. That's not a verdict on your whole life. It's one season's receipt from the moments I actually caught.

        Silence isn't Elsewhere. An unanswered knock means I don't know, so I left it blank.

        \(comparisonParagraph)

        I'm going quiet for seven days. Then I'll start another season. The Curse keeps moving. So do we.
        """
        return SurfacePage(
            id: surfaceID,
            type: .aboutYou,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: 99,
            reason: "A complete attention season has become a private, inspectable reading rather than disappearing into analytics.",
            prompt: "I counted only the knocks you answered.",
            detail: "HERE \(summary.hereCount) · ELSEWHERE \(summary.elsewhereCount) · silence unknown · \(comparisonDetail)",
            payload: BookPagePayload(
                headline: "THE CURSE LEFT A RECEIPT",
                body: body,
                metadata: [
                    "source": source.id,
                    "attentionCycleReading": "true",
                    "attentionCycle": "\(summary.cycle)",
                    "attentionAnswered": "\(summary.answeredCount)",
                    "attentionHere": "\(summary.hereCount)",
                    "attentionElsewhere": "\(summary.elsewhereCount)",
                    "attentionUnanswered": "unknown",
                    "tags": "about-you,attention-study,rut-cycle,rut-proof,cycle:\(summary.cycle),unanswered-is-unknown"
                ]
            )
        )
    }

    private static func bookMemoryProbePage(
        source: BookPageSource,
        day: BookDay,
        inputs: BookSourceInputs,
        now: Date
    ) -> SurfacePage? {
        let allPages = (inputs.days.filter { $0.id != day.id } + [day])
            .flatMap(\.pages)
        let assessment = BookFamiliarityRutEngine.assess(
            pages: allPages,
            readerLearning: inputs.readerLearning,
            attentionProbes: inputs.attentionProbes,
            selfFacts: inputs.selfFacts,
            now: now
        )
        guard assessment.phase != .clear else { return nil }
        let braids = allPages
            .filter { $0.type == .bookOfYou }
            .sorted { ($0.createdAt, $0.id) < ($1.createdAt, $1.id) }
        guard let latest = braids.last else { return nil }
        let probeNumber = max(1, (braids.count - 24) / 12 + 1)
        let questionID = "book-memory-probe-\(probeNumber)"
        guard !inputs.selfFacts.contains(where: { $0.questionID == questionID }) else {
            return nil
        }
        let title = BraidPageDetails.details(for: latest).title.nonEmpty
            ?? latest.promptText.nonEmpty
            ?? "your last Braid"
        let choices = [
            "I can replay its exact details",
            "I remember a few pieces",
            "It feels familiar, but I can't name much",
            "I remember nothing"
        ]
        return SurfacePage(
            id: "\(source.id)-\(questionID)",
            type: .aboutYou,
            sourceID: source.id,
            intent: .capture,
            renderStyle: .promptCard,
            score: assessment.phase == .rote ? 98 : 91,
            reason: "The same memory instrument that exposed routine now checks whether familiarity has begun eating the Book itself.",
            prompt: "Before you turn back: what do you remember from “\(title)”?",
            detail: "Don't reopen it yet. I'm testing the Curse, not you.",
            payload: BookPagePayload(
                headline: "DON'T TURN BACK YET",
                body: "I gave you “\(title).” Before you look again, tell me what stayed. Exact particulars matter more than whether it felt generally familiar.",
                metadata: [
                    "source": source.id,
                    "questionID": questionID,
                    "sensitivity": SelfFactSensitivity.delight.rawValue,
                    "usePermission": SelfFactUsePermission.privateContext.rawValue,
                    "exampleLines": choices.joined(separator: "||"),
                    "choicePrompt": "What stayed from the last Braid?",
                    "exampleLineMode": "choices",
                    "bookMemoryProbe": "true",
                    "targetBraidID": latest.id,
                    "tags": "about-you,memory,book-memory-probe,rut-familiarity,rut-proof,probe:\(probeNumber)"
                ]
            )
        )
    }

    private struct PulseQuestion {
        var headline: String
        var prompt: String
        var detail: String
        var body: String
        var choicePrompt: String
        var choices: [String]
        var scores: [Int]
        var codes: [String]
    }

    /// One small question at most per lived day. It asks for current weather
    /// or, when enough time has passed, whether a specific earlier Page escaped
    /// the screen. Neither answer is stored as a permanent fact about the
    /// reader.
    private static func readerStatePulsePage(
        source: BookPageSource,
        day: BookDay,
        inputs: BookSourceInputs,
        now: Date
    ) -> SurfacePage? {
        guard inputs.keptPageCount >= 2,
              !inputs.readerStatePulses.hasAnswer(on: day.id) else { return nil }

        let target = delayedPulseTarget(day: day, inputs: inputs, now: now)
        let dimension = target == nil
            ? rotatingPulseDimension(ledger: inputs.readerStatePulses, dayID: day.id)
            : ReaderStatePulseDimension.delayedOutcome
        let question = pulseQuestion(for: dimension)
        var metadata: [String: String] = [
            "source": source.id,
            "questionID": "reader-state-pulse-\(day.id)-\(dimension.rawValue)",
            "readerStatePulse": "true",
            "pulseDimension": dimension.rawValue,
            "pulseAskedAt": String(now.timeIntervalSince1970),
            "exampleLines": question.choices.joined(separator: "||"),
            "pulseScores": question.scores.map(String.init).joined(separator: "||"),
            "pulseCodes": question.codes.joined(separator: "||"),
            "exampleLineMode": "state-pulse",
            "choicePrompt": question.choicePrompt,
            "privacy": "private local weather; not a permanent profile fact",
            "tags": "about-you,reader-state-pulse,reenchantment-measure,\(dimension.rawValue)"
        ]
        if let target {
            metadata["pulseTargetSessionID"] = target.sessionID
            metadata["pulseTargetExperienceProgramID"] = target.experienceProgramID
            metadata["pulseTargetMovement"] = target.movement.rawValue
            metadata["pulseTargetRole"] = target.role?.rawValue
            metadata["pulseTargetSourceID"] = target.sourceID
            metadata["pulseTargetPageID"] = target.pageID
            metadata["pulseTargetCausalOpportunityID"] = target.causalOpportunityID
            metadata["pulseTargetCausalMovementOpportunityID"] = target.causalMovementOpportunityID
            metadata["pulseTargetHappenedAt"] = String(target.happenedAt.timeIntervalSince1970)
        }
        return SurfacePage(
            id: "\(source.id)-reader-state-pulse-\(day.id)-\(dimension.rawValue)",
            type: .aboutYou,
            sourceID: source.id,
            intent: .capture,
            renderStyle: .promptCard,
            // When the aliveness trend has gone thin, the right move is to ask
            // rather than to lean on what little there is. The boost lifts a
            // fresh-weather ask above the ordinary desk without letting it
            // outrank a delayed-outcome question, which is always worth more.
            score: (target == nil ? 72 : 88) + (target == nil ? inputs.twinGates.pulseScoreBoost : 0),
            reason: target == nil
                ? "A fresh within-day reading lets the Curator choose a fitting door without turning weather into identity."
                : "Enough lived time has passed to ask whether one attributable curation attempt actually changed anything.",
            prompt: question.prompt,
            detail: question.detail,
            payload: BookPagePayload(
                headline: question.headline,
                body: question.body,
                metadata: metadata
            )
        )
    }

    private static func rotatingPulseDimension(
        ledger: ReaderStatePulseLedger,
        dayID: String
    ) -> ReaderStatePulseDimension {
        let dimensions: [ReaderStatePulseDimension] = [.aliveness, .wonder, .hiddenMagic, .capacity]
        let seed = abs(dayID.stableHash)
        let ordered = (0..<dimensions.count).map { dimensions[(seed + $0) % dimensions.count] }
        return ordered.first { $0 != ledger.latestDimension() } ?? ordered[0]
    }

    private static func delayedPulseTarget(
        day: BookDay,
        inputs: BookSourceInputs,
        now: Date
    ) -> ReaderStatePulseTarget? {
        let eligible = (inputs.days + [day])
            .flatMap(\.pages)
            .filter {
                let age = now.timeIntervalSince($0.createdAt)
                return age >= 8 * 3600
                    && age <= 7 * 86_400
                    && $0.type != .aboutYou
            }
            .sorted { $0.createdAt > $1.createdAt }
        for page in eligible {
            guard let sessionID = tagValue("book-session-id:", in: page.tags),
                  !inputs.readerStatePulses.hasEvaluated(sessionID: sessionID),
                  let movementRaw = tagValue("book-session:", in: page.tags)
                    ?? tagValue("book-session-movement:", in: page.tags),
                  let movement = BookReenchantmentMovement.allCases.first(where: {
                      $0.rawValue.caseInsensitiveCompare(movementRaw) == .orderedSame
                  }) else {
                continue
            }
            return ReaderStatePulseTarget(
                sessionID: sessionID,
                experienceProgramID: tagValue("book-experience-program:", in: page.tags),
                movement: movement,
                role: tagValue("book-session-role:", in: page.tags)
                    .flatMap(BookSessionRole.init(rawValue:)),
                sourceID: page.sourceID,
                pageID: page.id,
                causalOpportunityID: tagValue("causal-experiment:", in: page.tags),
                causalMovementOpportunityID: tagValue("causal-movement-experiment:", in: page.tags),
                happenedAt: page.createdAt
            )
        }
        return nil
    }

    private static func tagValue(_ prefix: String, in tags: [String]) -> String? {
        tags.first(where: { $0.hasPrefix(prefix) })
            .map { String($0.dropFirst(prefix.count)) }
    }

    private static func pulseQuestion(for dimension: ReaderStatePulseDimension) -> PulseQuestion {
        switch dimension {
        case .aliveness:
            return PulseQuestion(
                headline: "A Small Reading of Today",
                prompt: "How alive does the world feel today?",
                detail: "Not how good you have been. How much of the world seems to have a pulse.",
                body: "Point to the nearest true answer. This is weather, not biography.",
                choicePrompt: "HOW ALIVE IS THE WORLD?",
                choices: [
                    "0 · It feels shut.",
                    "2 · Mostly gray.",
                    "4 · A little flicker.",
                    "6 · Several things are awake.",
                    "8 · The world keeps nudging me.",
                    "10 · Everything has a secret door."
                ],
                scores: [0, 2, 4, 6, 8, 10],
                codes: ["shut", "gray", "flicker", "awake", "nudging", "secret-door"]
            )
        case .wonder:
            return PulseQuestion(
                headline: "The Wonder Weather",
                prompt: "How wonder-filled does the world feel right now?",
                detail: "Not how wondrous it ought to be. How much strangeness is actually getting through.",
                body: "I'm taking the weather of your attention, not giving you a grade.",
                choicePrompt: "HOW MUCH WONDER IS GETTING THROUGH?",
                choices: [
                    "0 · None is getting through.",
                    "2 · The glass is mostly fogged.",
                    "4 · One odd gleam.",
                    "6 · Enough to follow.",
                    "8 · The ordinary world is misbehaving.",
                    "10 · Wonder is everywhere."
                ],
                scores: [0, 2, 4, 6, 8, 10],
                codes: ["none", "fogged", "gleam", "followable", "misbehaving", "everywhere"]
            )
        case .hiddenMagic:
            return PulseQuestion(
                headline: "Unassigned Magic",
                prompt: "Has hidden magic found you lately, without being assigned?",
                detail: "A detail, coincidence, creature, person, place, or moment that arrived on its own.",
                body: "The unassigned part matters. I want to know what kept happening after I went quiet.",
                choicePrompt: "DID ANYTHING FIND YOU BY ITSELF?",
                choices: [
                    "0 · No.",
                    "3 · Maybe, but it slipped away.",
                    "6 · One real glint.",
                    "8 · More than once.",
                    "10 · It has been finding me everywhere."
                ],
                scores: [0, 3, 6, 8, 10],
                codes: ["none", "slipped-away", "one-glint", "more-than-once", "everywhere"]
            )
        case .capacity:
            return PulseQuestion(
                headline: "How Wide Is Today?",
                prompt: "How much adventure can today honestly hold?",
                detail: "I can work with a minute. It merely needs the truth.",
                body: "A narrow day is not a failed day. It just needs a smaller door.",
                choicePrompt: "WHAT CAN TODAY HOLD?",
                choices: [
                    "0 · None. Be gentle.",
                    "2 · One minute.",
                    "5 · Ten minutes.",
                    "8 · Half an hour.",
                    "10 · Surprise me."
                ],
                scores: [0, 2, 5, 8, 10],
                codes: ["none", "one-minute", "ten-minutes", "half-hour", "surprise-me"]
            )
        case .delayedOutcome:
            return PulseQuestion(
                headline: "Did It Escape the Page?",
                prompt: "Since I last opened, did anything feel more alive than it ordinarily would have?",
                detail: "This is the important part: not whether the Page was pleasant, but whether life outside it changed.",
                body: "I'm checking my work. A no is useful. It means the next attempt should be different.",
                choicePrompt: "WHAT HAPPENED OUT THERE?",
                choices: [
                    "0 · No.",
                    "3 · I'm not sure.",
                    "5 · A small flicker.",
                    "8 · One real moment.",
                    "10 · Yes. I want to keep what happened."
                ],
                scores: [0, 3, 5, 8, 10],
                codes: ["no", "unsure", "flicker", "real-moment", "keep-it"]
            )
        }
    }

    private static func familiarPlacePage(
        source: BookPageSource,
        inputs: BookSourceInputs
    ) -> SurfacePage? {
        guard inputs.currentPlaceContext == nil,
              let opportunityID = inputs.currentPlaceNamingOpportunityID?.nonEmpty else { return nil }
        let questionID = "familiar-place-\(opportunityID)"
        guard !inputs.selfFacts.contains(where: { $0.questionID == questionID }) else { return nil }
        let choices = [
            "Home",
            "Work or school",
            "A regular haunt",
            "A place I go to breathe",
            "Someone else's place",
            "Somewhere else",
            "Don't remember this place"
        ]
        return SurfacePage(
            id: "\(source.id)-\(questionID)",
            type: .aboutYou,
            sourceID: source.id,
            intent: .capture,
            renderStyle: .promptCard,
            score: 82,
            reason: "The reader is in a freshly resolved area the Book has not been given permission to name.",
            prompt: "Does this patch of earth have a name in your Book?",
            detail: "I keep meeting you here. Name the role of this place, or tell me not to remember.",
            payload: BookPagePayload(
                headline: "A Familiar Place?",
                body: "Home, work, a haunt, a refuge, or nowhere I should keep. You decide what this ground means.",
                metadata: [
                    "source": source.id,
                    "questionID": questionID,
                    "packID": SelfKnowledgePackRegistry.corePackID,
                    "packName": SelfKnowledgePackRegistry.packName(for: SelfKnowledgePackRegistry.corePackID),
                    "sensitivity": SelfFactSensitivity.comfort.rawValue,
                    "usePermission": SelfFactUsePermission.privateContext.rawValue,
                    "tags": "place,familiar-place,location-consent,curation",
                    "exampleLines": choices.joined(separator: "||"),
                    "exampleLineMode": "place-roles",
                    "choicePrompt": "WHAT DOES THIS PLACE MEAN HERE?",
                    "placeNamingOffer": "true",
                    "privacy": "private local place; no coordinate in this Page"
                ]
            )
        )
    }

    private static func earnedWonderLabelPage(
        source: BookPageSource,
        day: BookDay,
        inputs: BookSourceInputs,
        now: Date
    ) -> SurfacePage? {
        guard !inputs.selfFacts.contains(where: { $0.questionID == "earned-wonder-label" }) else { return nil }
        guard let composed = ReaderRoleRegistry.currentRole(from: inputs.selfFacts) else { return nil }
        guard let namedAt = inputs.selfFacts
            .last(where: { $0.questionID == ReaderRoleRegistry.roleFactID })?
            .createdAt else { return nil }

        // The role itself is handed over on night one. This page is the *proof*
        // that the naming was not a party trick, so the gate and the receipts
        // must both concern that role. The old version counted every kept Page
        // and quoted the latest three indiscriminately; a weather note could
        // therefore be offered as proof of The Maker. That is not evidence.
        let keptPages = (inputs.days + [day])
            .flatMap(\.capturedPages)
            .filter { $0.createdAt >= namedAt }
        let role = composed.role
        let roleEvidence = roleEvidenceReceipts(for: role, in: keptPages)
        guard roleEvidence.count >= receiptsMinimumRoleEvidencePages else { return nil }
        let evidenceDays = Set(roleEvidence.map(\.dayID))
        guard evidenceDays.count >= receiptsMinimumDays else { return nil }

        let citedReceipts = citedRoleEvidence(from: roleEvidence)
        let receiptLines = citedReceipts.map { receipt in
            "- \(receipt.page.type.title): “\(receipt.line)”"
        }.joined(separator: "\n")
        let roleClaim = roleEvidenceClaim(for: role)
        let body = """
        I called you \(role.name) before I'd read a single page of you.

        That was a claim, and claims are cheap until somebody checks them. So I checked. I threw out every receipt that did not bear on the name.

        \(receiptLines)

        \(roleClaim)

        \(roleEvidence.count) matching Pages, across \(evidenceDays.count) days. Not merely the work of somebody who keeps things. The work of somebody who \(role.verb).

        I was right about you. I intend to go on being right about you.

        \(role.patronName) has been told, and took it better than I expected.
        """
        var metadata = composed.metadata
        metadata.merge([
            "source": source.id,
            "earnedLabel": "true",
            "earnedLabelID": role.id,
            "earnedLabelName": composed.fullName,
            "questionID": "earned-wonder-label",
            "packID": SelfKnowledgePackRegistry.corePackID,
            "packName": SelfKnowledgePackRegistry.packName(for: SelfKnowledgePackRegistry.corePackID),
            "sensitivity": SelfFactSensitivity.identity.rawValue,
            "usePermission": SelfFactUsePermission.privateContext.rawValue,
            "privacy": "private local profile",
            "keptPageCount": "\(keptPages.count)",
            "roleEvidencePageCount": "\(roleEvidence.count)",
            "roleEvidenceDayCount": "\(evidenceDays.count)",
            "roleEvidencePageIDs": citedReceipts.map(\.page.id).joined(separator: "||"),
            "roleEvidenceTypes": citedReceipts.map(\.page.type.rawValue).joined(separator: "||"),
            "shareableRoleCard": "true",
            "tags": "rut,wonder-compass,self-label,earned-label,reader-role,role-receipts"
        ]) { _, new in new }
        return SurfacePage(
            id: "\(source.id)-earned-wonder-label-\(role.id)",
            type: .aboutYou,
            sourceID: source.id,
            intent: .capture,
            renderStyle: .loreLetter,
            score: 87,
            reason: "The reader has kept enough pages for the Book to prove the role it named on night one.",
            prompt: "I Was Right About You",
            detail: "I named you before I had evidence. Here is the evidence.",
            payload: BookPagePayload(
                headline: composed.fullName,
                body: body,
                metadata: metadata
            )
        )
    }

    private struct RoleEvidenceReceipt {
        var page: BookPage
        var line: String
        var weight: Int

        var dayID: String { BookDay.id(for: page.createdAt) }
    }

    /// Uses the strongest of the same type affinities that let a role steer the
    /// desk and let a later body of work outgrow a role. Low-weight, broadly
    /// useful Pages may suit a role's desk without proving the role itself; the
    /// receipt is intentionally stricter than curation.
    private static func roleEvidenceReceipts(
        for role: ReaderRole,
        in pages: [BookPage]
    ) -> [RoleEvidenceReceipt] {
        var seenPageIDs = Set<String>()
        var seenLines = Set<String>()
        return pages.compactMap { page -> RoleEvidenceReceipt? in
            guard seenPageIDs.insert(page.id).inserted,
                  let weight = role.scoreBoosts[page.type],
                  weight >= receiptsMinimumRoleAffinity,
                  let line = readerAuthoredReceiptLine(from: page),
                  seenLines.insert(line.lowercased()).inserted else {
                return nil
            }
            return RoleEvidenceReceipt(page: page, line: line, weight: weight)
        }
        .sorted { left, right in
            if left.weight != right.weight { return left.weight > right.weight }
            if left.page.createdAt != right.page.createdAt {
                return left.page.createdAt > right.page.createdAt
            }
            return left.page.id < right.page.id
        }
    }

    /// Quotes only words the reader supplied. A prompt is evidence of what the
    /// Book asked, not of who the reader is, and must never appear in this Page
    /// as if it came from them.
    private static func readerAuthoredReceiptLine(from page: BookPage) -> String? {
        guard let raw = page.readerAuthoredTextForAnalysis else { return nil }
        let line = raw
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { return nil }
        return line.bookPreviewSentenceLimit(1)
    }

    /// Prefer receipts that span both time and kinds of action. When the shelf
    /// contains only one relevant kind, repeated action on separate days is
    /// still honest evidence and is allowed to fill the remaining slots.
    private static func citedRoleEvidence(
        from receipts: [RoleEvidenceReceipt],
        limit: Int = 3
    ) -> [RoleEvidenceReceipt] {
        guard let first = receipts.first, limit > 0 else { return [] }
        var selected = [first]

        func appendFirst(where predicate: (RoleEvidenceReceipt) -> Bool) {
            guard selected.count < limit,
                  let receipt = receipts.first(where: { candidate in
                      !selected.contains(where: { $0.page.id == candidate.page.id })
                          && predicate(candidate)
                  }) else { return }
            selected.append(receipt)
        }

        appendFirst { candidate in
            !selected.contains(where: { $0.dayID == candidate.dayID })
        }
        appendFirst { candidate in
            !selected.contains(where: { $0.page.type == candidate.page.type })
        }
        for receipt in receipts where selected.count < limit {
            guard !selected.contains(where: { $0.page.id == receipt.page.id }) else { continue }
            selected.append(receipt)
        }
        return selected
    }

    private static func roleEvidenceClaim(for role: ReaderRole) -> String {
        switch role.id {
        case "maker":
            return "You kept choosing Pages where something had to be made, altered, or brought into the world."
        case "lookout":
            return "You kept going out to meet weather, sky, and place as things with teeth in them."
        case "porchlight":
            return "You kept turning Pages toward other people: answering, writing, and carrying lives beside your own."
        case "detourist":
            return "You kept choosing movement, place, and the door that led somewhere you had not quite planned."
        case "rabbit-holer":
            return "You kept following questions into lessons, lore, and the parts of the shelves with dust on them."
        case "nightlight":
            return "You kept making room for solitude, quiet, and the weather that belongs only to you."
        case "steady-hand":
            return "You kept using Pages to answer, help, and show up where another life touched yours."
        case "stowaway":
            return "You kept entering stories, voices, and other worlds, and bringing something back out."
        default:
            return role.gloss
        }
    }

    /// The Book keeps its word. The naming promised that a name which stopped
    /// fitting would be replaced, and this is where it says so, not as a
    /// correction of the reader, but as the Book noticing it has been reading
    /// an older version of somebody.
    ///
    /// Deliberately an offer rather than a fait accompli: the reader took the
    /// first name and can take or refuse this one. Fires once per candidate
    /// role, so a reader who declines is not asked again the next evening.
    private static func outgrownRolePage(
        source: BookPageSource,
        day: BookDay,
        inputs: BookSourceInputs,
        now: Date
    ) -> SurfacePage? {
        guard let composed = ReaderRoleRegistry.currentRole(from: inputs.selfFacts) else { return nil }
        guard let namedAt = inputs.selfFacts
            .last(where: { $0.questionID == ReaderRoleRegistry.roleFactID })?
            .createdAt
        else { return nil }

        let keptPages = (inputs.days + [day]).flatMap(\.capturedPages)
        guard let next = ReaderRoleRegistry.outgrownRole(
            current: composed.role,
            keptPages: keptPages,
            namedAt: namedAt,
            now: now
        ) else { return nil }

        // Asked once per candidate. Silence is an answer, and a Book that
        // reopened the question every evening would be nagging, not noticing.
        let askedTag = "role-outgrown:\(next.id)"
        guard !inputs.selfFacts.contains(where: { $0.tags.contains(askedTag) }) else { return nil }

        let months = max(1, Calendar.current.dateComponents([.month], from: namedAt, to: now).month ?? 1)
        let body = """
        I called you \(composed.role.name) and I was right.

        That was \(months == 1 ? "a month" : "\(months) months") ago. I've been reading you since, and you've quietly stopped being it, not failed at it. Stopped needing it. What you've been doing instead is something else entirely, and I've been slow about saying so.

        \(next.gloss)

        So: \(next.name). That's what I'm calling you now. Refuse if you like and keep the old one (it's yours, I only lent you the lettering), but I'd rather be right about you than consistent.
        """
        var metadata = composed.metadata
        metadata.merge([
            "source": source.id,
            "readerRoleOutgrown": "true",
            "outgrownFromRoleID": composed.role.id,
            "outgrownToRoleID": next.id,
            "outgrownToRoleName": next.name,
            "questionID": ReaderRoleRegistry.roleFactID,
            "sensitivity": SelfFactSensitivity.identity.rawValue,
            "usePermission": SelfFactUsePermission.privateContext.rawValue,
            "tags": "reader-role,role-outgrown,\(askedTag)"
        ]) { _, new in new }
        return SurfacePage(
            id: "\(source.id)-role-outgrown-\(composed.role.id)-to-\(next.id)",
            type: .aboutYou,
            sourceID: source.id,
            intent: .capture,
            renderStyle: .loreLetter,
            score: 91,
            reason: "The reader's kept pages have clearly outrun the name the Book gave them.",
            prompt: "You Have Outgrown It",
            detail: "I'd rather be right about you than consistent.",
            payload: BookPagePayload(
                headline: next.name,
                body: body,
                metadata: metadata
            )
        )
    }

    /// Evidence floors for the role-receipts page. Denominated in reader-written,
    /// role-matching Pages and distinct days rather than the calendar, so the
    /// payoff cannot be earned by unrelated activity or by waiting out a clock.
    private static let receiptsMinimumRoleEvidencePages = 5
    private static let receiptsMinimumDays = 2
    private static let receiptsMinimumRoleAffinity = 6

    private static func fact(_ questionID: String, in facts: [SelfFact]) -> SelfFact? {
        facts.first { $0.questionID == questionID }
    }

    private static func nextUnshownChapterPrimerStage(surfaceHistory: [String: SurfaceHistoryRecord]) -> Int? {
        (1...3).first { surfaceHistory["chapter-primer:\($0)"] == nil }
    }

    private static func chapterPrimerPage(source: BookPageSource, stage: Int, now: Date) -> SurfacePage {
        let chapters = AcademyChapterRegistry.publicChapters
        let index = abs("\(BookDay.id(for: now))-chapter-primer-\(stage)".stableHash) % chapters.count
        let chapter = chapters[index]
        let body: String
        switch stage {
        case 1:
            body = """
            The Academy calls them Chapters, but the Book is cross with that word. A chapter is not a club, a dormitory, or a color pinned to a robe.

            A Chapter is a wager about what life is doing when no one is explaining it.

            Emberheart believes life is authored. Mossbloom believes life is listened to. Tidecrest believes life arrives moment by moment, entire and surprising. Riddlewind believes life is co-written. Duskthorn believes a story without honest conflict is too thin to protect anyone.

            The Binding is not ready yet. The Book has only begun to hear your footsteps.
            """
        case 2:
            body = """
            The Binding Hall does not ask, "Which Chapter do you like?"

            It asks quieter, better questions.

            What do your kept pages protect? Where does your attention go when it is not performing? Do your sentences reach for a door, a tree, a sudden glittering hour, or another hand on the page?

            The Chapters are reading the evidence now. None of them are subtle about it.

            \(chapter.name) has been especially insufferable in the margins today: \(chapter.philosophy)
            """
        default:
            body = """
            Headmistress Thorne dislikes premature certainty. She says it makes the ink brittle.

            So the Book waits. It counts not points but pressures: kept pages, returned words, Belief given freely, the small things you chose to preserve when no one required it.

            When there is enough of you in the margins, the Binding will not ask you to choose.

            It will recognize you.
            """
        }
        return SurfacePage(
            id: "\(source.id)-chapter-primer-\(stage)-\(chapter.id)",
            type: .aboutYou,
            sourceID: source.id,
            intent: .resurface,
            renderStyle: .loreLetter,
            score: 44 + stage * 4,
            reason: "I'm getting ready for Chapter Binding by telling you what Chapters believe.",
            prompt: "On Chapters",
            detail: "The Binding is just listening for now, not asking you for anything.",
            payload: BookPagePayload(
                headline: stage == 1 ? "What Chapters Are" : "Before the Binding",
                body: body,
                metadata: [
                    "source": source.id,
                    "chapterPrimer": "true",
                    "primerStage": "\(stage)",
                    "chapterID": chapter.id,
                    "chapterName": chapter.name,
                    "privacy": "public reference",
                    "tags": "chapter,binding,academy,primer"
                ]
            )
        )
    }

    private static func chapterBindingPage(
        source: BookPageSource,
        choice: ChapterBindingChoice,
        readiness: ChapterBindingReadiness
    ) -> SurfacePage {
        let chapter = choice.chapter
        let evidence = choice.evidenceLines.map { "- \($0)" }.joined(separator: "\n")
        let memories = choice.memoryFragments.map { "- \($0)" }.joined(separator: "\n")
        let scores = choice.scores
            .sorted { $0.key < $1.key }
            .map { "\($0.key):\($0.value)" }
            .joined(separator: ",")
        let daysLine = readiness.daysSinceFirstKeptPage.map { "\($0) day\($0 == 1 ? "" : "s") since the first kept page" } ?? "time uncounted"
        let ceremony = ChapterBindingCeremony.profile(for: chapter)
        let body = """
        The candles in the Binding Hall have gone blue-white at the wick. Headmistress Thorne looks down at the Book, then at you, and her expression becomes almost kind. Almost.

        "No questionnaire," she says. "No little preference game. You have already answered in ink."

        Her hands cup the air around the page, and somehow you feel them at your face too: cool rings, old ink, the exact pressure of being read. Reality fractures. The Great Hall shatters into doors: a flame-lit desk, a mossy stair, a wave folding moonlight, a table where several voices finish one sentence together, and one narrow violet threshold that refuses to announce itself.

        The Book opens every kept page at once. Your own life rises through the ceremony, not as biography, but as weather:

        \(memories.isEmpty ? "- I found my evidence in kept pages too private to quote here." : memories)

        Then the evidence underneath it glows:

        \(evidence)

        Stories engulf the room. Your tongue catches old paper and lightning. Your skin remembers a thousand stories that are not yours and, threaded through them, the ordinary kept pieces that are. At the edges, Routine opens its grey mouth. The lines of your kept pages flare back.

        A jolt runs through the binding, like swallowing lightning. Ink lifts from the margins and gathers into a seal.

        \(ceremony.arrivalLine)

        Chapter \(chapter.name).

        \(chapter.philosophy)

        The seal does not stop at naming you. It gives you work.

        \(ceremony.sealLine)

        The oath finds your mouth before you decide whether to be brave:

        \(ceremony.oathLine)

        The first invitation settles under your thumb:

        \(ceremony.invitationLine)

        Reality snaps back. The Great Hall re-forms around the Book with its edges still rippling. Thorne's eyes hold recognition now, and something stranger than recognition: respect.

        "From the Great Unwritten Chapter," she says softly, "and bound here by what you chose to keep."

        \(chapter.talismanName) warms in the stacks. The Binding has chosen by \(readiness.keptPageCount) kept page\(readiness.keptPageCount == 1 ? "" : "s"), \(readiness.keptDayCount) kept day\(readiness.keptDayCount == 1 ? "" : "s"), and \(daysLine).

        \(ceremony.aftermathLine)
        """
        return SurfacePage(
            id: "\(source.id)-chapter-binding-\(chapter.id)",
            type: .aboutYou,
            sourceID: source.id,
            intent: .capture,
            renderStyle: .loreLetter,
            score: 76,
            reason: "Enough kept pages have piled up for the Academy to spot a whole Chapter shape in them.",
            prompt: "The Chapter Binding",
            detail: "Headmistress Thorne read all the margins, and the Binding has made its pick.",
            payload: BookPagePayload(
                headline: "The Chapter Binding",
                body: body,
                metadata: [
                    "source": source.id,
                    "chapterBinding": "true",
                    "chosenChapterID": chapter.id,
                    "chosenChapterName": chapter.name,
                    "chosenChapterTalismanID": chapter.talismanID,
                    "chosenChapterTalismanName": chapter.talismanName,
                    "chapterScores": scores,
                    "bindingEvidence": choice.evidenceLines.joined(separator: " | "),
                    "bindingMemories": choice.memoryFragments.joined(separator: " | "),
                    "bindingSealLine": ceremony.sealLine,
                    "bindingOathLine": ceremony.oathLine,
                    "bindingInvitationLine": ceremony.invitationLine,
                    "bindingAftermathLine": ceremony.aftermathLine,
                    "keptDayCount": "\(readiness.keptDayCount)",
                    "keptPageCount": "\(readiness.keptPageCount)",
                    "daysSinceFirstKeptPage": readiness.daysSinceFirstKeptPage.map(String.init) ?? "",
                    "tags": "chapter,binding,identity,ceremony,automatic"
                ]
            )
        )
    }
}

struct WickerDarePageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .wickerDare)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive, !context.distress.isActive else { return [] }
        // The Curator decides when the dare reaches the visible desk. Keeping
        // Wicker off the candidate bench five slots out of six meant Belief,
        // reader taste, recency, and ordinary curation could not choose him at
        // all. One rotating candidate per twelve-hour slot is still one Page,
        // not a flood or a guaranteed appearance.
        return [surface(for: day, inputs: inputs, now: now)]
    }

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        surface(for: day, inputs: inputs, now: now)
    }

    private func surface(for day: BookDay, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        let dare = WickerDareRegistry.dare(for: day, inputs: inputs, now: now)
        let onboardingMode = onboardingAnswer("onboarding-wicker-mode", inputs: inputs)
        let onboardingTier = onboardingAnswer("onboarding-wicker-tier", inputs: inputs)
        let onboardingThread = onboardingAnswer("onboarding-wicker-thread", inputs: inputs)
        let completedDares = inputs.days
            .flatMap(\.pages)
            .compactMap(\.attributableLivedQuestReceipt)
            .filter { $0.kind == .wickerDare }
            .sorted { $0.completedAt > $1.completedAt }
        let hasShownWicker = inputs.surfaceHistory.keys.contains {
            $0.lowercased().contains("wicker")
        }
        var metadata: [String: String] = [
            "source": source.id,
            "wickerDare": "true",
            "wickerDareID": dare.id,
            "wickerDareTitle": dare.title,
            "challenge": dare.challenge,
            "souvenirPrompt": dare.proofPrompt,
            "placeholder": dare.proofPrompt,
            "proofKind": dare.tags.contains("photo") ? "sentence-or-photo" : "sentence",
            "comfortEdge": "true",
            "voluntary": "true",
            "missionHostSlug": "wicker-eddies",
            "missionHostName": "Wicker Eddies",
            "missionHostAsset": "LabyrinthCharacterWickerEddies",
            "wickerDareReturnCount": "\(completedDares.count)",
            "primaryLivedInvitation": "true",
            "tags": (dare.tags + ["entity:wicker-eddies"]).joined(separator: ",")
        ]
        if dare.pressureCost >= 0.75 {
            metadata["curatorActionCommission"] = "true"
        }
        if let onboardingMode {
            metadata["onboardingWickerMode"] = onboardingMode
        }
        if let onboardingTier {
            metadata["onboardingWickerTier"] = onboardingTier
        }
        if let onboardingThread, !hasShownWicker {
            metadata["onboardingWickerThread"] = onboardingThread
        }
        if let place = dare.place {
            metadata["localPlaceID"] = place.id
            metadata["localPlaceName"] = place.name
            metadata["localPlaceCategory"] = place.category
            metadata["localPlaceDistance"] = place.distanceLabel
            metadata["locality"] = place.locality
        } else if let locality = inputs.currentLocationLabel?.nonEmpty {
            metadata["locality"] = locality
        }

        let rivalryOpening = onboardingThread.flatMap { thread in
            hasShownWicker ? nil : """
            You remember the Inkbones. Good. I do too.

            \(thread)

            I said we'd come back to it.

            """
        } ?? ""
        let rivalryStatus: String
        if let previous = completedDares.first {
            rivalryStatus = "You brought back ‘\(previous.title).’ I read it. Don't grin. Here's the next one."
        } else {
            switch onboardingTier {
            case "triumph": rivalryStatus = "Beginner's luck has grown legs. I want another look."
            case "cost": rivalryStatus = "I kept the loose end from the Inscription. You may try to take it back."
            case "glance": rivalryStatus = "You nearly wriggled out of my first question. Nearly."
            default: rivalryStatus = "I found a harmless rule with its feet on the furniture."
            }
        }
        // The dare itself is already the deck, and the leaf prints the deck
        // directly above this letter. Wicker does not need to read his own
        // challenge back to the reader before asking his question.
        let body = """
        \(rivalryOpening)\(rivalryStatus)

        \(dare.proofPrompt)

        This is a dare, not a debt. Unsafe, illegal, cruel, inaccessible, or just wrong for you? Kill it. Clean no. No speech.

        —Wicker
        """
        var proofModes: [PageCapabilityProofMode] = [.observation]
        if dare.tags.contains("photo") { proofModes.append(.photograph) }
        if dare.tags.contains("voice") { proofModes.append(.voice) }
        if dare.tags.contains("social") || dare.tags.contains("conversation") { proofModes.append(.person) }
        return SurfacePage(
            id: "\(source.id)-\(dare.id)-\(SurfaceCadence.slotID(for: now, hours: 12))",
            type: .wickerDare,
            sourceID: source.id,
            intent: .capture,
            renderStyle: .loreLetter,
            score: 69,
            reason: dare.place.map { "I found a live edge near \($0.name)." }
                ?? "I found a harmless rule with its feet on the furniture.",
            prompt: "I Dare You: \(dare.title)",
            detail: dare.challenge,
            payload: BookPagePayload(
                headline: dare.title,
                body: body,
                metadata: metadata
            )
        ).withPageCapabilities(PageCapabilityContract(
            supportedMovements: dare.tags.contains("social")
                ? [.chosenDetour, .scriptFreedom, .humanOtherness]
                : [.chosenDetour, .scriptFreedom, .freshSight],
            supportedRoles: [.door],
            emotionalFunctions: dare.tags.contains("social")
                ? [.play, .act, .connect]
                : [.play, .act, .wonder],
            effort: dare.goesOutward ? .involved : .small,
            reach: .nearbyWorld,
            mobility: dare.goesOutward ? .shortDistance : .stationary,
            estimatedMinutes: dare.estimatedMinutes,
            asksReader: true,
            pressureCost: dare.pressureCost,
            proofModes: proofModes,
            requirements: dare.place == nil ? [] : [.nearbyPlace]
        ))
    }

    private func onboardingAnswer(_ questionID: String, inputs: BookSourceInputs) -> String? {
        inputs.selfFacts.first {
            $0.questionID == questionID && $0.usePermission != .doNotUse
        }?.answer.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }
}

struct WonderCompassPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .wonderCompass)

    /// How many errands the adapter puts in front of the Curator. Only one can
    /// reach a desk (one Page type, one source family per desk), so this is not
    /// a number of cards — it is the width of the rotation the Curator gets to
    /// choose from across the sessions of a day.
    static let offeredErrandCount = 5

    /// The compass stamps its standalone Notice and Sense pages with their own
    /// source IDs (for per-page Belief and titles), so this one adapter serves
    /// all three.
    var servedSourceIDs: [String] {
        [
            source.id,
            BookPageSourceRegistry.wonderCompassNoticeSourceID,
            BookPageSourceRegistry.wonderCompassPlayfulMissionSourceID
        ]
    }

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else {
            return []
        }

        let progress = CompassRunProgress.progress(for: day)
        let seed = WonderCompassRunGenerator.seed(for: day, inputs: inputs, progress: progress, now: now)
        let shadowSeed = WonderCompassRunGenerator.seed(for: day, inputs: inputs, progress: progress, now: now, shadowVariant: true)
        // The desk cannot rotate errands it is never offered. One mission per
        // build meant the reader met the same errand every session of a day
        // while most of a 180-strong catalog was never sent at all.
        let playfulMissions = PlayfulMissionRegistry.missions(
            for: day,
            inputs: inputs,
            now: now,
            limit: Self.offeredErrandCount
        )
        let playfulMission = playfulMissions.first
            ?? PlayfulMissionRegistry.mission(for: day, inputs: inputs, now: now)
        let snippet = inputs.selectedWonderCompass
            ?? BookReferenceCatalog.relevantWonderCompassSnippet(for: day, inputs: inputs, now: now)
        let selector = inputs.selectedWonderCompassSelector ?? "local-relevance"
        let isGemmaSelected = selector == "gemma"
        let shadowState = ShadowWonder.state(inputs: inputs, now: now)
        var pages: [SurfacePage] = [
            runSurface(seed: seed, progress: progress, context: context, inputs: inputs, now: now),
            stepSurface(step: progress.nextStep, seed: seed, progress: progress, context: context, inputs: inputs, now: now),
            playfulMissionSurface(playfulMission, seed: seed, context: context, inputs: inputs, now: now),
            SurfacePage(
                id: "\(source.id)-\(snippet.id)",
                type: .wonderCompass,
                sourceID: source.id,
                intent: .importReference,
                renderStyle: .quoteCard,
                score: context.distress.isActive ? 52 : 66,
                reason: isGemmaSelected
                    ? "Gemma chose this passage from today's pages and the shape of the day."
                    : (context.distress.isActive ? "Only a small, low-pressure practice belongs here." : "A field-guide card can give the day one clean handle."),
                prompt: "From the Wonder Compass Book",
                detail: snippet.prompt,
                payload: BookPagePayload(
                    headline: "From the Wonder Compass Book: \(snippet.title)",
                    body: snippet.leafExcerpt,
                    metadata: [
                        "source": source.id,
                        "compassFamily": "wonder-compass",
                        "compassBookPreview": "true",
                        "snippetID": snippet.id,
                        "tags": snippet.tags.joined(separator: ","),
                        "selector": selector,
                        // A field-guide quotation is spice, not an errand. It
                        // shares the compass Page type with the mission that
                        // actually sends the reader outdoors, and used to
                        // outrank it for the desk's single compass slot.
                        "deskJob": DeskJob.play.rawValue
                    ]
                )
            )
        ]
        // Alternates the Curator may rotate to. Only one errand can sit on a
        // desk (one Page type and one source family per desk), so these widen
        // the choice across the sessions of a day rather than stacking cards.
        for alternate in playfulMissions.dropFirst() {
            pages.append(playfulMissionSurface(alternate, seed: seed, context: context, inputs: inputs, now: now))
        }
        pages.append(contentsOf: pennySentenceMasterySurfaces(context: context, now: now))

        if progress.completedSteps.isEmpty {
            let standaloneNotice = stepSurface(step: .notice, seed: seed, progress: progress, context: context, inputs: inputs, now: now, standalone: true)
            pages.append(standaloneNotice)
            // The purest North = Notice "I wonder" card earns its own shadow sibling,
            // carrying a mono-no-aware spark from the dark shelf.
            if ShadowWonder.shouldSurface(.compass, inputs: inputs, now: now) {
                pages.append(stepSurface(step: .notice, seed: shadowSeed, progress: progress, context: context, inputs: inputs, now: now, standalone: true, shadowVariantOf: standaloneNotice.id))
            }
        }

        if ShadowWonder.shouldSurface(.compass, inputs: inputs, now: now) {
            // Ranking the shadow mission pool is the most expensive thing this
            // adapter does, so it only runs when the shadow shelf is open.
            let shadowPlayfulMission = PlayfulMissionRegistry.mission(for: day, inputs: inputs, now: now, shadowVariant: true)
            pages.append(runSurface(seed: shadowSeed, progress: progress, context: context, inputs: inputs, now: now, shadowVariantOf: "\(source.id)-run-\(seed.id)"))
            pages.append(stepSurface(step: progress.nextStep, seed: shadowSeed, progress: progress, context: context, inputs: inputs, now: now, shadowVariantOf: "\(source.id)-run-\(seed.id)-\(progress.nextStep.rawValue)"))
            pages.append(playfulMissionSurface(shadowPlayfulMission, seed: shadowSeed, context: context, inputs: inputs, now: now, shadowVariantOf: "\(source.id)-playful-mission-\(playfulMission.id)-\(SurfaceCadence.slotID(for: now, hours: 2))"))
            let shadowSnippet = BookReferenceCatalog.fallbackWonderCompass.first { $0.id == "wonder-compass-shadow-wonder" }
                ?? snippet
            pages.append(
                SurfacePage(
                    id: "\(source.id)-shadow-\(shadowSnippet.id)",
                    type: .wonderCompass,
                    sourceID: source.id,
                    intent: .importReference,
                    renderStyle: .quoteCard,
                    score: (context.distress.isActive ? 52 : 66) + shadowState.scoreBoost,
                    reason: "Shadow Wonder is unlocked; this passage variant can help the Compass honor the worn edge.",
                    prompt: "Shadow Wonder from the Compass Book",
                    detail: shadowSnippet.prompt,
                    payload: BookPagePayload(
                        headline: "From the Wonder Compass Book: \(shadowSnippet.title)",
                        body: shadowSnippet.leafExcerpt,
                        metadata: [
                            "source": source.id,
                            "compassFamily": "wonder-compass",
                            "compassBookPreview": "true",
                            "snippetID": shadowSnippet.id,
                            "shadowVariantOf": "\(source.id)-\(snippet.id)",
                            "variant": "shadow-wonder",
                            "tags": ShadowWonder.mergedTags(shadowSnippet.tags.joined(separator: ","), inputs: inputs, now: now),
                            "selector": selector
                        ]
                    )
                )
            )
        }

        return pages.map { authorCapabilities(on: $0) }
    }

    /// The other side of the preview leaf. Glow's contents and the leaf's
    /// explicit reading door both use this same surface, so the full chapter is
    /// never duplicated into the ordinary Pages Rising stack.
    func readingSurface(for snippet: ReferenceSnippet) -> SurfacePage {
        SurfacePage(
            id: "\(source.id)-reading-\(snippet.id)",
            type: .wonderCompass,
            sourceID: source.id,
            intent: .importReference,
            renderStyle: .quoteCard,
            score: 70,
            reason: "Opened deliberately from a Wonder Compass preview or its table of contents.",
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

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        let progress = CompassRunProgress.progress(for: day)
        let seed = WonderCompassRunGenerator.seed(for: day, inputs: inputs, progress: progress, now: now)
        return authorCapabilities(on: runSurface(seed: seed, progress: progress, context: context, inputs: inputs, now: now))
    }

    /// Opens a fresh standalone mission without routing the reader through a
    /// full Compass Run. This is the named Glow-menu door; ordinary curation
    /// still uses the same registry, metadata, and capability contract.
    func manualPlayfulMissionSurface(
        for day: BookDay,
        context: CuratorContext,
        inputs: BookSourceInputs,
        now: Date
    ) -> SurfacePage {
        let progress = CompassRunProgress.progress(for: day)
        let seed = WonderCompassRunGenerator.seed(for: day, inputs: inputs, progress: progress, now: now)
        let mission = PlayfulMissionRegistry.mission(for: day, inputs: inputs, now: now)
        return authorCapabilities(on: playfulMissionSurface(
            mission,
            seed: seed,
            context: context,
            inputs: inputs,
            now: now
        ))
    }

    /// The Flyleaf returns an already-started run to its next real station,
    /// rather than sending the reader back through the run's intake questions.
    /// With no unfinished run this deliberately falls back to the ordinary
    /// Compass door.
    func progressSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        let progress = CompassRunProgress.progress(for: day)
        let seed = WonderCompassRunGenerator.seed(for: day, inputs: inputs, progress: progress, now: now)
        guard !progress.completedSteps.isEmpty, !progress.isComplete else {
            return authorCapabilities(on: runSurface(seed: seed, progress: progress, context: context, inputs: inputs, now: now))
        }
        return authorCapabilities(on: stepSurface(
            step: progress.nextStep,
            seed: seed,
            progress: progress,
            context: context,
            inputs: inputs,
            now: now
        ))
    }

    /// Rebuilds the exact actionable page carried by a tapped prompt whisper.
    /// Mission text comes from the scheduled snapshot rather than today's
    /// rotating registry result, so opening the notification cannot reroll it.
    func promptWhisperSurface(
        for whisper: PromptWhisper,
        day: BookDay,
        context: CuratorContext,
        inputs: BookSourceInputs,
        now: Date
    ) -> SurfacePage {
        guard whisper.kind == .mission,
              whisper.id.hasPrefix("mission-") else {
            return checkInSurface(for: whisper, context: context, now: now)
        }

        let missionID = String(whisper.id.dropFirst("mission-".count))
        let registeredMission = PlayfulMissionRegistry.missions.first { $0.id == missionID }
        let mission = PlayfulMission(
            id: missionID,
            title: whisper.title,
            prompt: whisper.body,
            proofPrompt: whisper.keepPrompt,
            tags: whisper.tags,
            allowsPhoto: whisper.allowsPhoto ?? registeredMission?.allowsPhoto ?? false
        )
        let progress = CompassRunProgress.progress(for: day)
        let seed = WonderCompassRunGenerator.seed(for: day, inputs: inputs, progress: progress, now: now)
        return authorCapabilities(on: playfulMissionSurface(
            mission,
            seed: seed,
            context: context,
            inputs: inputs,
            now: now
        ).withMetadata([
            "openedFromPromptWhisper": "true",
            "promptWhisperID": whisper.id
        ]))
    }

    private func checkInSurface(
        for whisper: PromptWhisper,
        context: CuratorContext,
        now: Date
    ) -> SurfacePage {
        let source = BookPageSourceRegistry.source(for: .souvenir)
        return SurfacePage(
            id: "prompt-whisper-\(whisper.id)-\(SurfaceCadence.slotID(for: now, hours: 2))",
            type: .souvenir,
            sourceID: source.id,
            intent: .capture,
            renderStyle: .promptCard,
            score: context.distress.isActive ? 52 : 64,
            reason: "The reader opened this exact prompt from the Book's whisper.",
            prompt: whisper.title,
            detail: whisper.body,
            payload: BookPagePayload(
                headline: whisper.title,
                body: whisper.body,
                metadata: [
                    "source": source.id,
                    "placeholder": whisper.keepPrompt,
                    "souvenirPrompt": whisper.keepPrompt,
                    "promptWhisperID": whisper.id,
                    "openedFromPromptWhisper": "true",
                    "tags": (["souvenir", "prompt-whisper", whisper.kind.rawValue] + whisper.tags)
                        .joined(separator: ",")
                ]
            )
        )
    }

    /// Wonder Compass contains a whole shelf of exact experiences behind one
    /// Page type. Give each one an authored contract at the adapter boundary so
    /// a quotation, a sentence practice, a Compass run, and a field mission no
    /// longer pretend to ask the same thing of the reader.
    private func authorCapabilities(on page: SurfacePage) -> SurfacePage {
        let metadata = page.payload.metadata
        let proofModes: [PageCapabilityProofMode] = metadata["proofKind"]?.contains("photo") == true
            ? [.observation, .photograph]
            : [.observation]

        let contract: PageCapabilityContract
        if metadata["playfulMissionID"] != nil {
            // Read from the mission rather than stamped flat across the family.
            let missionNerve = metadata["missionNerve"].flatMap(Double.init) ?? 0.30
            let missionMinutes = metadata["missionMinutes"].flatMap(Int.init) ?? 5
            let missionMobility = metadata["missionMobility"]
                .flatMap(PageCapabilityMobility.init(rawValue:)) ?? .stationary
            contract = PageCapabilityContract(
                supportedMovements: [.freshSight, .livingWorld, .chosenDetour],
                supportedRoles: [.door, .horizon],
                emotionalFunctions: [.notice, .wonder, .play, .act],
                effort: .small,
                reach: .nearbyWorld,
                mobility: missionMobility,
                estimatedMinutes: missionMinutes,
                asksReader: true,
                pressureCost: missionNerve,
                proofModes: proofModes
            )
        } else if metadata["compassMode"] == "runStart" || metadata["compassStep"] == "run" {
            contract = PageCapabilityContract(
                supportedMovements: [.freshSight, .livingWorld, .chosenDetour, .exactLanguage],
                emotionalFunctions: [.notice, .wonder, .act],
                effort: .involved,
                reach: .plannedWorld,
                mobility: .extendedTravel,
                estimatedMinutes: 25,
                asksReader: true,
                pressureCost: 0.72,
                proofModes: [.response, .observation]
            )
        } else if let step = metadata["compassStep"] {
            switch step {
            case CompassRunStep.embark.rawValue:
                contract = PageCapabilityContract(
                    supportedMovements: [.chosenDetour, .livingWorld],
                    emotionalFunctions: [.wonder, .act],
                    effort: .involved,
                    reach: .plannedWorld,
                    mobility: .extendedTravel,
                    estimatedMinutes: 15,
                    asksReader: true,
                    pressureCost: 0.64,
                    proofModes: [.response, .place]
                )
            case CompassRunStep.sense.rawValue:
                contract = PageCapabilityContract(
                    supportedMovements: [.freshSight, .livingWorld],
                    emotionalFunctions: [.notice, .wonder, .play],
                    effort: .small,
                    reach: .nearbyWorld,
                    mobility: .shortDistance,
                    estimatedMinutes: 7,
                    asksReader: true,
                    pressureCost: 0.46,
                    proofModes: [.observation, .photograph]
                )
            case CompassRunStep.write.rawValue:
                contract = PageCapabilityContract(
                    supportedMovements: [.exactLanguage, .livingContinuity],
                    emotionalFunctions: [.express, .remember],
                    effort: .small,
                    estimatedMinutes: 5,
                    asksReader: true,
                    pressureCost: 0.38,
                    proofModes: [.response, .observation]
                )
            case CompassRunStep.rest.rawValue:
                contract = PageCapabilityContract(
                    supportedMovements: [.shelter],
                    emotionalFunctions: [.soothe],
                    effort: .glance,
                    estimatedMinutes: 1,
                    pressureCost: 0.04
                )
            default:
                contract = PageCapabilityContract(
                    supportedMovements: [.freshSight, .livingWorld],
                    emotionalFunctions: [.notice, .wonder],
                    effort: .small,
                    estimatedMinutes: 3,
                    asksReader: true,
                    pressureCost: 0.28,
                    proofModes: [.response]
                )
            }
        } else if metadata["pennySentenceLesson"] != nil {
            contract = PageCapabilityContract(
                supportedMovements: [.exactLanguage],
                emotionalFunctions: [.play, .express],
                effort: .small,
                estimatedMinutes: 6,
                asksReader: true,
                pressureCost: 0.32,
                proofModes: [.response]
            )
        } else {
            // A selected Compass passage asks only to be read. It can support a
            // later movement without pretending that reading itself is proof.
            contract = PageCapabilityContract(
                supportedMovements: [.freshSight, .livingWorld, .shelter],
                supportedRoles: [.door, .echo],
                emotionalFunctions: [.notice, .wonder],
                effort: .glance,
                estimatedMinutes: 1,
                pressureCost: 0.05
            )
        }
        return page.withPageCapabilities(contract)
    }

    private func playfulMissionSurface(
        _ mission: PlayfulMission,
        seed: WonderCompassRunSeed,
        context: CuratorContext,
        inputs: BookSourceInputs,
        now: Date,
        shadowVariantOf: String? = nil
    ) -> SurfacePage {
        let isShadowVariant = shadowVariantOf != nil
        let shadowState = ShadowWonder.state(inputs: inputs, now: now)
        let host = mission.host
        let recentHostReceipt = inputs.days
            .flatMap(\.pages)
            .compactMap(\.attributableLivedQuestReceipt)
            .filter {
                $0.kind == .playfulMission
                    && $0.sourceTags.contains("entity:\(host.slug)")
            }
            .max { $0.completedAt < $1.completedAt }
        var metadata = metadata(for: seed, step: .sense)
        // The adapter offers a handful of errands per build out of a much
        // larger catalogue, and rest is scaled to deck size. Without this the
        // Curator would rest each of the five as though five were all there
        // were. See `SurfacePage.declaredDeckSize`.
        metadata["deckSize"] = "\(PlayfulMissionRegistry.missions.count)"
        metadata["compassStep"] = "sense"
        metadata["compassMode"] = "standalone"
        metadata.removeValue(forKey: "runID")
        metadata["playfulMissionID"] = mission.id
        metadata["playfulMissionTitle"] = mission.title
        metadata["playfulMissionTemperament"] = mission.temperament
        metadata["playfulMissionMode"] = mission.playMode.rawValue
        metadata["missionHostSlug"] = host.slug
        metadata["missionHostName"] = host.name
        metadata["missionHostAsset"] = host.assetName
        metadata["missionHostLead"] = host.invitationLine
        metadata["primaryLivedInvitation"] = "true"
        if let recentHostReceipt {
            metadata["missionContinuityLine"] = "\(host.name) read what came back from ‘\(recentHostReceipt.title)’ and adjusted the next trouble."
        }
        metadata["missionNerve"] = String(format: "%.2f", mission.missionNerve)
        metadata["missionMinutes"] = "\(mission.missionMinutes)"
        metadata["missionMobility"] = mission.missionMobility.rawValue
        // Only a mission that genuinely asks the reader to get up and go
        // somewhere is an action commission. Marking every one of them as such
        // is what put the whole family behind the high-pressure limiter.
        if mission.missionNerve >= 0.75 {
            metadata["curatorActionCommission"] = "true"
        }
        metadata["mission"] = mission.prompt
        metadata["souvenirPrompt"] = mission.souvenirInvitation
        metadata["placeholder"] = mission.souvenirInvitation
        // The errand has a name of its own. Without this the leaf titles itself
        // "South = Sense" from the headline and the name never appears.
        metadata["folioTitle"] = mission.title
        metadata["proofKind"] = mission.allowsPhoto ? "sentence-or-photo" : "sentence"
        let tags = (seed.tags + ["compass-step:sense", "playful-mission", "entity:\(host.slug)", "play-mode:\(mission.playMode.rawValue)"] + mission.tags.map { "mission:\($0)" }).joined(separator: ",")
        metadata["tags"] = isShadowVariant ? ShadowWonder.mergedTags(tags, inputs: inputs, now: now) : tags
        metadata["source"] = BookPageSourceRegistry.wonderCompassPlayfulMissionSourceID
        metadata["symbol"] = mission.allowsPhoto ? "camera.macro" : "hand.raised"
        metadata["startingPageBelief"] = "62"
        let isNaturalPhenomenonMission = mission.tags.contains("natural-phenomenon")
        if isNaturalPhenomenonMission {
            metadata["naturalPhenomenonMission"] = "true"
        }
        let title = WonderTitleRegistry.earnedTitle(from: inputs.selfFacts)
        if let title {
            metadata.merge(title.metadata) { _, new in new }
        }
        if let shadowVariantOf {
            metadata["shadowVariantOf"] = shadowVariantOf
            metadata["variant"] = "shadow-wonder"
        }
        let continuityLine = recentHostReceipt.map {
            "\n\n\(host.name) has read the evidence you brought back from ‘\($0.title).’ This one is the next turn of the lens."
        } ?? ""

        return SurfacePage(
            id: "\(source.id)-\(isShadowVariant ? "shadow-" : "")playful-mission-\(mission.id)-\(SurfaceCadence.slotID(for: now, hours: 2))",
            type: .wonderCompass,
            sourceID: BookPageSourceRegistry.wonderCompassPlayfulMissionSourceID,
            intent: .capture,
            renderStyle: .promptCard,
            score: (context.distress.isActive ? 54 : 64) + (isShadowVariant ? shadowState.scoreBoost : 0),
            reason: isShadowVariant
                ? "This Shadow Wonder variant lets the senses investigate the dark edge safely."
                : isNaturalPhenomenonMission
                ? "South is responding to the live sky, weather, or place around you."
                : "A playful mission can turn South into something your senses can actually do.",
            prompt: mission.title,
            // The mission is the whole South instruction. Reader-role Compass
            // lines can point somewhere unrelated (for example, the
            // Rabbit-Holer asks for an hour with a question), so printing one
            // here makes every sensory errand look like two missions.
            detail: mission.prompt,
            payload: BookPagePayload(
                headline: "South = Sense",
                // The souvenir invitation already says what to bring back, so
                // the label made the leaf read "Bring back: … Bring back words,
                // a photograph, or a voice scrap." The mission's own name is
                // also the better title than "South = Sense".
                body: "\(host.invitationLine)\n\n\(mission.prompt)\n\n\(mission.souvenirInvitation)\(continuityLine)",
                metadata: metadata
            )
        )
    }

    private func pennySentenceMasterySurfaces(context: CuratorContext, now: Date) -> [SurfacePage] {
        let slotID = SurfaceCadence.slotID(for: now, hours: 12)
        return PennySentenceMasteryLesson.allCases.map { lesson in
            let tags = lesson.tags.joined(separator: ",")
            return SurfacePage(
                id: "\(source.id)-penny-sentence-\(lesson.rawValue)-\(slotID)",
                type: .wonderCompass,
                sourceID: source.id,
                intent: .capture,
                renderStyle: .promptCard,
                score: (context.distress.isActive ? 46 : 56) + lesson.order,
                reason: "Competence and mastery focus: Penny turns Chapter 9's West = Write practice into one learnable sentence move.",
                prompt: "Penny Blackletter: \(lesson.title)",
                detail: lesson.focusLine,
                payload: BookPagePayload(
                    headline: "How to Write Better Sentences: \(lesson.title)",
                    body: """
                    Filed by Penny Blackletter, after Chapter 9: West = Write.

                    \(lesson.pennyBriefing)

                    Practice: \(lesson.practicePrompt)
                    """,
                    metadata: [
                        "source": source.id,
                        "compassFamily": "wonder-compass",
                        "snippetID": "wonder-compass-chapter9",
                        "chapterSourceID": "wonder-compass-chapter9",
                        "pennySentenceLesson": lesson.rawValue,
                        "pennySentenceLessonOrder": "\(lesson.order)",
                        "pennySentenceLessonTitle": lesson.title,
                        "pennySentenceLessonFocus": lesson.focusLine,
                        "pennySentenceLessonHint": lesson.masteryHint,
                        "placeholder": lesson.placeholder,
                        "symbol": lesson.symbolName,
                        "tags": tags
                    ]
                )
            )
        }
    }

    private func runSurface(
        seed: WonderCompassRunSeed,
        progress: CompassRunProgress,
        context: CuratorContext,
        inputs: BookSourceInputs = .empty,
        now: Date,
        shadowVariantOf: String? = nil
    ) -> SurfacePage {
        let completed = progress.completedSteps.count
        let isFresh = completed == 0
        let next = progress.isComplete ? CompassRunStep.rest : progress.nextStep
        let isShadowVariant = shadowVariantOf != nil
        let shadowState = ShadowWonder.state(inputs: inputs, now: now)
        let headline = isShadowVariant
            ? (isFresh ? "Shadow Compass Run" : (progress.isComplete ? "Shadow Compass Run Complete" : "Resume Shadow Compass Run"))
            : (isFresh ? "Compass Run" : (progress.isComplete ? "Compass Run Complete" : "Resume Compass Run"))
        let detail = isFresh
            ? "A full N-E-S-W loop customized to now: constraints first, magic after."
            : "\(completed)/5 directions complete. Next: \(next.compassPoint) = \(next.title)."
        let title = WonderTitleRegistry.earnedTitle(from: inputs.selfFacts)
        let titleLine = title.map { "\n\n\($0.name) angle: \($0.compassLine)" } ?? ""
        var metadata = metadata(for: seed, step: nil)
        metadata["compassStep"] = "run"
        metadata["compassMode"] = "runStart"
        metadata["nearbyPlaces"] = inputs.nearbyPlaces.prefix(10).map(\.promptLine).joined(separator: "\n")
        if let proximity = inputs.nearbyAnchor {
            let anchor = proximity.anchor
            metadata["anchorName"] = anchor.name
            metadata["anchorKind"] = anchor.kind.title
            metadata["anchorDistanceMeters"] = "\(Int(proximity.distanceMeters.rounded()))"
            metadata["anchorRoom"] = anchor.outerStacksRoom
            metadata["anchorFae"] = anchor.fae
            metadata["anchorLocalRule"] = anchor.localRule
            metadata["anchorVisitMode"] = proximity.visitMode
            metadata["anchorMiniStory"] = anchor.miniStory
            metadata["anchorAcademyEcho"] = anchor.academyEcho
        }
        metadata["completedSteps"] = "\(completed)"
        metadata["nextStep"] = next.rawValue
        if let title {
            metadata.merge(title.metadata) { _, new in new }
        }
        if let shadowVariantOf {
            metadata["shadowVariantOf"] = shadowVariantOf
            metadata["variant"] = "shadow-wonder"
        }

        return SurfacePage(
            id: "\(source.id)-\(isShadowVariant ? "shadow-" : "")run-\(seed.id)",
            type: .wonderCompass,
            sourceID: source.id,
            intent: .capture,
            renderStyle: .quoteCard,
            score: (context.distress.isActive ? 48 : (isFresh ? 60 : 62)) + (isShadowVariant ? shadowState.scoreBoost : 0),
            reason: isShadowVariant
                ? "This Shadow Wonder variant can turn the difficult, old, or overlooked thing into a real quest."
                : progress.isComplete
                ? "The wheel has turned; the center can hold the page."
                : "The Compass can turn the current constraints into one small adventure.",
            prompt: headline,
            detail: title.map { "\($0.name): \(detail)" } ?? detail,
            payload: BookPagePayload(
                headline: headline,
                body: "\(WonderCompassRunGenerator.body(for: seed))\(titleLine)",
                metadata: metadata
            )
        )
    }

    private func stepSurface(
        step: CompassRunStep,
        seed: WonderCompassRunSeed,
        progress: CompassRunProgress,
        context: CuratorContext,
        inputs: BookSourceInputs,
        now: Date,
        standalone: Bool = false,
        shadowVariantOf: String? = nil
    ) -> SurfacePage {
        var metadata = metadata(for: seed, step: step)
        metadata["compassStep"] = step.rawValue
        metadata["compassMode"] = standalone ? "standalone" : "runStep"
        metadata["standalone"] = standalone ? "true" : "false"
        if standalone {
            metadata.removeValue(forKey: "runID")
        }
        if standalone, step == .notice {
            metadata["startingPageBelief"] = "62"
        }
        let pageSourceID = standalone && step == .notice
            ? BookPageSourceRegistry.wonderCompassNoticeSourceID
            : source.id
        metadata["source"] = pageSourceID
        metadata["placeholder"] = step.capturePlaceholder
        let title = WonderTitleRegistry.earnedTitle(from: inputs.selfFacts)
        if let title {
            metadata.merge(title.metadata) { _, new in new }
        }

        let isShadowVariant = shadowVariantOf != nil
        let shadowState = ShadowWonder.state(inputs: inputs, now: now)
        if let shadowVariantOf {
            metadata["shadowVariantOf"] = shadowVariantOf
            metadata["variant"] = "shadow-wonder"
        }
        let score = context.distress.isActive && step != .rest
            ? 50
            : (standalone ? 42 : 58 + min(step.scoreBoost, 4))

        // A standalone Notice is an interrupt, not the opening move of a run.
        // It gets its own pool and its own capture ask so nothing on the card
        // implies a five-step sequence the reader never agreed to.
        let noticeNow = standalone && step == .notice
            ? NoticeNowRegistry.prompt(inputs: inputs, now: now, shadowVariant: isShadowVariant)
            : nil
        if let noticeNow {
            metadata["noticeNowID"] = noticeNow.id
            metadata["placeholder"] = noticeNow.capture
            // The noticing itself is the Page. Without this the leaf titles
            // itself "North = Notice" from the headline and prints only the
            // capture ask, and the thing the reader was asked to look at never
            // reaches paper. See `FolioLeafComposer`.
            metadata["folioTitle"] = noticeNow.text
        }

        return SurfacePage(
            id: "\(source.id)-\(isShadowVariant ? "shadow-" : "")\(standalone ? "solo" : "run")-\(seed.id)-\(step.rawValue)",
            type: .wonderCompass,
            sourceID: pageSourceID,
            intent: .capture,
            renderStyle: .promptCard,
            score: score + (isShadowVariant ? shadowState.scoreBoost : 0),
            reason: isShadowVariant
                ? "This Shadow Wonder variant can start with the thing you usually look past."
                : standalone && step == .notice
                ? "One look, right now, wherever you are."
                : standalone
                ? "\(step.title) can be used on its own without committing to a full run."
                : "The next Compass direction is ready.",
            prompt: noticeNow.map { $0.text } ?? "\(step.compassPoint): \(step.title)",
            detail: noticeNow.map { $0.capture }
                ?? title.map { "\($0.name): \(step.standaloneDetail)" }
                ?? step.standaloneDetail,
            payload: BookPagePayload(
                headline: noticeNow == nil ? "\(step.compassPoint) = \(step.title)" : "North = Notice",
                body: noticeNow.map { $0.capture }
                    ?? "\(seed.body(for: step))\(title.map { "\n\n\($0.name) angle: \($0.compassLine)" } ?? "")",
                metadata: metadata
            )
        )
    }

    private func metadata(for seed: WonderCompassRunSeed, step: CompassRunStep?) -> [String: String] {
        let tags = seed.tags + (step.map { ["compass-step:\($0.rawValue)"] } ?? [])
        var metadata: [String: String] = [
            "source": source.id,
            "compassFamily": "wonder-compass",
            "tags": tags.joined(separator: ","),
            "runID": seed.id,
            "conciergeMode": seed.mode.rawValue,
            "timeBox": seed.timeBox,
            "budget": seed.budget,
            "place": seed.place,
            "energy": seed.energy,
            "companions": seed.companions,
            "considerations": seed.considerations,
            "circumstance": seed.circumstance,
            "spark": seed.spark,
            "destination": seed.destination,
            "delight": seed.delight,
            "definition": seed.definition,
            "mission": seed.mission,
            "souvenirPrompt": seed.souvenirPrompt,
            "restPrompt": seed.restPrompt,
            "privacy": "private local practice"
        ]
        if let step {
            metadata["symbol"] = symbol(for: step)
        } else {
            metadata["symbol"] = "safari"
        }
        return metadata
    }

    private func symbol(for step: CompassRunStep) -> String {
        switch step {
        case .notice:
            return "sparkle.magnifyingglass"
        case .embark:
            return "figure.walk"
        case .sense:
            return "hand.draw"
        case .write:
            return "pencil.and.scribble"
        case .rest:
            return "moon.stars"
        }
    }
}

struct EnchantifyLorePageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .lore)

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        loreSurface(
            snippet: BookReferenceCatalog.rotatingLoreSnippet(for: day, inputs: inputs, now: now, manual: true),
            context: context,
            inputs: inputs,
            now: now
        )
    }

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else {
            return []
        }

        let snippet = BookReferenceCatalog.rotatingLoreSnippet(for: day, inputs: inputs, now: now)
        var pages = [loreSurface(snippet: snippet, context: context, inputs: inputs, now: now)]
        if ShadowWonder.shouldSurface(.lore, inputs: inputs, now: now) {
            pages.append(
                loreSurface(
                    snippet: BookReferenceCatalog.rotatingShadowLoreSnippet(for: day, now: now),
                    context: context,
                    inputs: inputs,
                    now: now,
                    shadowVariantOf: pages[0].id
                )
            )
        }
        return pages
    }

    private func loreSurface(
        snippet: ReferenceSnippet,
        context: CuratorContext,
        inputs: BookSourceInputs,
        now: Date,
        shadowVariantOf: String? = nil
    ) -> SurfacePage {
        let isShadowVariant = shadowVariantOf != nil
        let shadowState = ShadowWonder.state(inputs: inputs, now: now)
        var metadata = [
            "source": source.id,
            "snippetID": snippet.id,
            "tags": isShadowVariant
                ? ShadowWonder.mergedTags(snippet.tags.joined(separator: ","), inputs: inputs, now: now)
                : snippet.tags.joined(separator: ",")
        ]
        if let practice = snippet.practice?.trimmingCharacters(in: .whitespacesAndNewlines), !practice.isEmpty {
            metadata["practice"] = practice
        }
        if let shadowVariantOf {
            metadata["shadowVariantOf"] = shadowVariantOf
            metadata["variant"] = "shadow-wonder"
        }
        return SurfacePage(
            id: "\(source.id)-\(isShadowVariant ? "shadow-" : "")\(snippet.id)",
            type: .lore,
            sourceID: source.id,
            intent: .importReference,
            renderStyle: .loreLetter,
            score: (context.distress.isActive ? 44 : 68) + (isShadowVariant ? shadowState.scoreBoost : 0),
            reason: isShadowVariant ? "This Shadow Wonder lore card scoots the honest, worn edge to the front." : (context.distress.isActive ? "Lore hangs back behind the gentler pages when the day feels heavy." : "A lore card can bring the world a little closer without asking anything of you."),
            prompt: isShadowVariant ? "Shadow Lore: \(snippet.prompt)" : snippet.prompt,
            detail: snippet.title,
            payload: BookPagePayload(
                headline: snippet.title,
                body: snippet.body,
                metadata: metadata
            )
        )
    }
}

struct LabyrinthIllustrationPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .illustration)

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        illustrationSurface(
            plate: BookReferenceCatalog.rotatingLabyrinthIllustration(for: day, now: now, manual: true),
            context: context,
            now: now,
            manual: true
        )
    }

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }
        let plate = BookReferenceCatalog.rotatingLabyrinthIllustration(for: day, now: now)
        return [illustrationSurface(plate: plate, context: context, now: now, manual: false)]
    }

    private func illustrationSurface(
        plate: LabyrinthIllustrationPlate,
        context: CuratorContext,
        now: Date,
        manual: Bool
    ) -> SurfacePage {
        let profile = BookReferenceCatalog.characterIllustrationProfile(id: plate.characterID)
        let aboutText = profile.map(Self.bookDetail(for:)) ?? plate.caption
        let bodyText = profile.map(Self.bookPageBody(for:)) ?? plate.caption
        var metadata = [
            "source": source.id,
            "assetName": plate.assetName,
            "plateID": plate.id,
            "tags": plate.tags.joined(separator: ","),
            "privacy": "bundled local image"
        ]
        if let profile {
            metadata["characterID"] = profile.id
            metadata["characterName"] = profile.characterName
            metadata["characterSlug"] = profile.slug
            metadata["characterStatus"] = profile.status
            metadata["characterChapter"] = profile.chapter ?? ""
            metadata["illustrationPrompt"] = profile.prompt
            metadata["negativePrompt"] = profile.negativePrompt
            metadata["intendedAssetName"] = profile.intendedAssetName
            metadata["signature"] = profile.signature
            metadata["palette"] = profile.palette
            metadata["silhouette"] = profile.silhouette
            metadata["continuity"] = profile.continuity
            metadata["marginalia"] = profile.marginalia.joined(separator: " | ")
            metadata["visualStyleReference"] = "antique parchment academy dossier portrait collage"
        }
        let slotID = manual ? "\(Int(now.timeIntervalSince1970))" : SurfaceCadence.minuteSlotID(for: now, minutes: 20)
        return SurfacePage(
            id: "\(source.id)-\(plate.id)-\(slotID)",
            type: .illustration,
            sourceID: source.id,
            intent: .importReference,
            renderStyle: .illustrationPlate,
            score: context.distress.isActive ? 50 : 65,
            reason: "A little illustration can pop up just to be looked at, no strings attached.",
            prompt: profile.map(Self.bookPageTitle(for:)) ?? "An Illustration from the Labyrinth of Stories",
            detail: aboutText,
            payload: BookPagePayload(
                headline: plate.title,
                body: bodyText,
                metadata: metadata
            )
        )
    }

    static func bookPageTitle(for profile: CharacterIllustrationProfile) -> String {
        let name = profile.characterName
        let variants: [String]
        switch profile.illustrationTag {
        case "location":
            variants = [
                "A Place That Remembers: \(name)",
                "The Room Called \(name)",
                "\(name), Which Keeps Its Own Weather",
                "On the Subject of \(name)"
            ]
        case "book-fae":
            variants = [
                "A Life Between the Lines: \(name)",
                "\(name), Who Works the Margins",
                "Small and Entirely Necessary: \(name)",
                "What the Page Owes \(name)"
            ]
        default:
            variants = [
                "The Book Remembers: \(name)",
                "A Page Kept for \(name)",
                "What the Ink Knows of \(name)",
                "\(name), Pressed and Filed"
            ]
        }
        return variants[stableIndex(for: "title-\(profile.slug)", count: variants.count)]
    }

    static func bookDetail(for profile: CharacterIllustrationProfile) -> String {
        let name = profile.characterName
        let variants: [String]
        switch profile.illustrationTag {
        case "location":
            variants = [
                "Some places are alive enough to remember who walks into them. \(name) is one.",
                "I keep \(name) the way I keep a doorway, because something always happens in it.",
                "\(name) is not scenery. It has a mood, and it has been known to hold a grudge.",
                "I filed \(name) under places. It keeps trying to file itself under people."
            ]
        case "book-fae":
            variants = [
                "I know \(name) by the small disturbances left in ink, paper, and unfinished thought.",
                "No Book Fae is decorative. \(name) keeps one piece of the story from going dull.",
                "When \(name) is near, the margins get busy. Watch them before you watch the page.",
                "\(name) is small enough to miss and important enough that I never do."
            ]
        default:
            variants = [
                "I've watched \(name) long enough to tell reputation from character.",
                "Reputation arrives first. \(name) arrives second, and is the better read.",
                "I don't file \(name) under one word. I've tried; the word never holds.",
                "Everyone has a version of \(name). I keep the one with the corrections still showing."
            ]
        }
        return variants[stableIndex(for: "detail-\(profile.slug)", count: variants.count)]
    }

    static func bookPageBody(for profile: CharacterIllustrationProfile) -> String {
        // A hand-authored dossier always wins over the generated one. Only the
        // canonical Cast has bespoke prose; locations, talismans, Book Fae, and
        // any character without an entry fall through to the generator below.
        if let bespoke = CastDossier.bio(forSlug: profile.slug) {
            return bespoke
        }
        let name = profile.characterName
        let core = coreProse(for: profile)
        let palette = paletteLine(for: profile)
        let signature = sentence(profile.signature).lowercasingFirstLetter()

        let opening: [String]
        let closing: [String]
        switch profile.illustrationTag {
        case "location":
            opening = [
                "\(name) does not sit still while you look at it.",
                "I've kept \(name) because some places are too awake to forget a visitor.",
                "\(name) behaves less like a setting and more like a witness.",
                "Walk into \(name) and it takes a reading of you before you take one of it."
            ]
            closing = [
                "Places like this listen through floorboards, shelves, weather, and doors. I know this one by \(signature) Return often enough, and it may begin to recognize you in return.",
                "It is changed by every arrival, though it pretends otherwise. Look for \(signature) That is how I keep my place in it.",
                "Rooms like this hold opinions. This one announces itself with \(signature) Mind your manners at the threshold.",
                "Stay long enough and it will start keeping a page on you, too. I recognize it by \(signature)"
            ]
        case "book-fae":
            opening = [
                "\(name) belongs to the lively country between a written word and the breath that wakes it.",
                "\(name) is small, and I'd not run the Labyrinth without them.",
                "Most readers never see \(name). The page would notice immediately if they left.",
                "\(name) works where ink meets intention, which is the most haunted ground I keep."
            ]
            closing = [
                "No Book Fae is decorative; each keeps one necessary thing from going dull. I know this one by \(signature) Watch the margins when it is near.",
                "It keeps one piece of the story honest. Find it by \(signature) The page usually notices before the reader does.",
                "Lose this one and a story goes quietly wrong in a way nobody can name. Its sign is \(signature)",
                "When it is working, you feel the sentence hold; when it rests, you feel the gap. I know it by \(signature)"
            ]
        default:
            opening = [
                "I've learned not to summarize \(name) too quickly.",
                "\(name) is the kind of page I reread.",
                "Ask the Academy about \(name) and you'll get a tidy answer; I keep the untidy one.",
                "\(name) came into my pages and never asked to be explained."
            ]
            closing = [
                "A person is never only an office, a talent, or the rumor that reaches the door first. The mark I trust is \(signature) That is only where the ink begins.",
                "If you want to find them in a crowded chapter, look for \(signature) The rest changes with the weather; that does not.",
                "Reputation can be forged. What cannot is the evidence that travels with them: \(signature)",
                "I always know them when they enter, because they bring \(signature) Everything else about them is allowed to surprise me."
            ]
        }

        let firstParagraph = [
            opening[stableIndex(for: "open-\(profile.slug)", count: opening.count)],
            core
        ].filter { !$0.isEmpty }.joined(separator: " ")

        let secondParagraph = [
            palette,
            closing[stableIndex(for: "close-\(profile.slug)", count: closing.count)]
        ].filter { !$0.isEmpty }.joined(separator: " ")

        return [firstParagraph, secondParagraph]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    /// A sentence built from the parchment "swatches": each character keeps a
    /// genuinely distinct palette, so this is the cheapest way to make two cards
    /// stop sounding like twins.
    private static func paletteLine(for profile: CharacterIllustrationProfile) -> String {
        let colors = profile.palette
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !colors.isEmpty else { return "" }
        let phrase = oxfordList(colors)
        let templates = [
            "When I picture them, the page settles into \(phrase).",
            "They come to the page in \(phrase).",
            "The ink remembers them as \(phrase)."
        ]
        return templates[stableIndex(for: "palette-\(profile.slug)", count: templates.count)]
    }

    private static func oxfordList(_ items: [String]) -> String {
        switch items.count {
        case 0: return ""
        case 1: return items[0]
        case 2: return "\(items[0]) and \(items[1])"
        default:
            return items.dropLast().joined(separator: ", ") + ", and " + (items.last ?? "")
        }
    }

    /// Boilerplate clauses the dossier generator stamps on under-specified
    /// characters; they say nothing, so the Book refuses to repeat them.
    private static let coreBoilerplate: [String] = [
        "clear expressive eyes and a memorable silhouette",
        "a memorable silhouette",
        "recognizable posture",
        "hands involved in the scene",
        "academy character"
    ]

    private static func coreProse(for profile: CharacterIllustrationProfile) -> String {
        let clauses = profile.core
            .split(separator: ";")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { clause in
                guard !clause.isEmpty, !clause.contains("...") else { return false }
                let lowered = clause.lowercased()
                return !coreBoilerplate.contains { lowered.contains($0) }
            }
        let selected = clauses.prefix(2).map { sentence($0).capitalizingFirstLetter() }
        return selected.joined(separator: " ")
    }

    private static func stableIndex(for key: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Int(hash % UInt64(count))
    }

    private static func sentence(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while result.hasSuffix("...") {
            result.removeLast(3)
            result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !result.isEmpty else { return "a mark the page has not yet named." }
        if !result.hasSuffix(".") && !result.hasSuffix("!") && !result.hasSuffix("?") {
            result += "."
        }
        return result
    }
}

private extension String {
    func lowercasingFirstLetter() -> String {
        guard let first else { return self }
        return first.lowercased() + String(dropFirst())
    }

    func capitalizingFirstLetter() -> String {
        guard let first else { return self }
        return first.uppercased() + String(dropFirst())
    }

    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Trimmed and stripped of any terminal punctuation, so a stored clause can
    /// be embedded mid-sentence without doubling up periods.
    var strippedClause: String {
        var result = trimmed
        while let last = result.last, ".!?;,".contains(last) {
            result.removeLast()
            result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return result
    }
}

struct NarrativeOSPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .narrativeOS)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }
        let authored = AuthoredStoryScenePageAdapter.candidates(
            for: day,
            inputs: inputs,
            now: now
        )
        if let prepared = inputs.preparedStoryPageSurface {
            return [Self.authorCapabilities(on: prepared)] + authored
        }
        var seenRecipes = Set<String>()
        // Four recipe variants, each of which builds a whole story packet out
        // of the archive. The packet cannot change until the archive does or
        // the cadence slot turns, and the desk is rebuilt many times a session.
        let draftSalt = "\(day.id)|\(SurfaceCadence.slotID(for: now, hours: 2))"
        let generated = (0..<4).compactMap { variantIndex in
            let page = ArchiveMemo.value(
                "narrative-os.draft.\(variantIndex)",
                days: inputs.days + [day],
                salt: draftSalt,
                compute: {
                    Self.draftCandidate(
                        for: day,
                        inputs: inputs,
                        now: now,
                        recipeVariantIndex: variantIndex
                    )
                }
            )
            let identity = page.payload.metadata["storyRecipeID"]?.nonEmpty
                ?? page.curatorContentNoveltyKey
            return seenRecipes.insert(identity).inserted ? Self.authorCapabilities(on: page) : nil
        }
        return generated + authored
    }

    static func draftCandidate(
        for day: BookDay,
        inputs: BookSourceInputs,
        now: Date,
        recipeVariantIndex: Int = 0
    ) -> SurfacePage {
        let source = BookPageSourceRegistry.source(for: .narrativeOS)
        let packet = StoryScenePacketBuilder.packet(
            for: day,
            inputs: inputs,
            now: now,
            recipeVariantIndex: recipeVariantIndex
        )
        let mechanicMandate = StoryPageMechanicPlanner.mandate(for: day, inputs: inputs, packet: packet, now: now)
        let choiceRoles = packet.choices.map { $0.role.title }.joined(separator: " | ")
        let selectedThreads = packet.selectedThreads.map(\.title).joined(separator: ", ")
        let selectedThreadIDs = packet.selectedThreads.map(\.id).joined(separator: ",")
        let selectedEntities = packet.selectedEntities.map(\.name).joined(separator: ", ")
        let storySetting = packet.selectedEntities.first { $0.kind == .location }
        let storySettingDetail = storySetting.map { setting in
            [
                setting.unwrittenInterest,
                setting.traits.isEmpty ? nil : "Traits: \(setting.traits.joined(separator: ", "))",
                setting.quirks.first.map { "Specific behavior: \($0)" },
                setting.goals.first.map { "Scene job: \($0)" }
            ]
            .compactMap { $0?.nonEmpty }
            .joined(separator: " ")
        } ?? ""
        let selectedRelationships = packet.selectedRelationships.map(\.id).joined(separator: ", ")
        let selectedEntityMemories = packet.selectedEntityMemories
            .map { memory in
                let entityName = NarrativePackRegistry.entities.first(where: { $0.id == memory.entityID })?.name ?? memory.entityID
                return "\(entityName): \(memory.summary)"
            }
            .joined(separator: "\n")
        let characterCanon = CharacterCanonPacket.promptSection(
            for: packet.selectedEntities,
            contextLines: packet.relationshipPressures + packet.selectedEntityMemories.map(\.summary)
        )
        let chapterTalismanMoves = packet.chapterTalismanMoves.map(\.promptLine).joined(separator: "\n")
        let chapterTalismanDeltas = packet.chapterTalismanMoves.compactMap(\.ledgerToken).joined(separator: ",")
        let storyDecisions = packet.blueprint?.decisions
            .flatMap { try? JSONEncoder().encode($0) }
            .flatMap { String(data: $0, encoding: .utf8) }
        var metadata: [String: String] = [
            "source": source.id,
            "packetID": packet.id,
            "packID": packet.packID,
            "bookGlow": packet.bookGlow,
            "playerBelief": "\(packet.playerBelief)",
            "choiceRoles": choiceRoles,
            "storyThreadDisplayTitle": packet.playableThreadTitle,
            "storyThreadUnderlyingTitles": selectedThreads,
            "storyThreadUnderlyingIDs": selectedThreadIDs,
            "selectedThreads": selectedThreads,
            "selectedEntities": selectedEntities,
            "selectedEntityIDs": packet.selectedEntities.map(\.id).joined(separator: ","),
            "storySettingID": storySetting?.id ?? "",
            "storySettingName": storySetting?.name ?? "",
            "storySettingDetail": storySettingDetail,
            "storyFormID": packet.storyFormID ?? "",
            "storyFormName": packet.storyFormName ?? "",
            "storyBeats": (packet.storyFormBeats ?? []).joined(separator: "\n"),
            "storyGenreID": packet.storyGenreID ?? "",
            "storyGenreName": packet.storyGenreName ?? "",
            "storyGenreLens": packet.storyGenreLens ?? "",
            "storyGenreExemplar": packet.storyGenreExemplar ?? "",
            "storyGenrePalette": (packet.storyGenrePalette ?? []).joined(separator: " | "),
            "storyPromiseSeed": packet.promise?.seed ?? "",
            "storyPromiseQuestion": packet.promise?.question ?? "",
            "storyRecipeID": packet.blueprint?.recipeID ?? "",
            "storyRecipeName": packet.blueprint?.recipeName ?? "",
            "storyRecipePackID": packet.blueprint?.recipePackID ?? "",
            "storyRecipeSceneMode": packet.blueprint?.sceneMode.rawValue ?? "",
            "storyRecipeLeadID": packet.blueprint?.leadID ?? "",
            "storyRecipeLeadName": packet.blueprint?.leadName ?? "",
            "storyRecipeCompanionID": packet.blueprint?.companionID ?? "",
            "storyRecipeCompanionName": packet.blueprint?.companionName ?? "",
            "storyRecipePremise": packet.blueprint?.premise ?? "",
            "storyRecipeGroundingKind": packet.blueprint?.grounding.kind.rawValue ?? "",
            "storyRecipeGroundingSourceID": packet.blueprint?.grounding.sourceID ?? "",
            "storyRecipeGrounding": packet.blueprint?.grounding.text ?? "",
            "storyRecipeGroundingUse": packet.blueprint?.groundingUse?.rawValue ?? "",
            "storyRecipeDecisions": storyDecisions ?? "",
            "storyGroundingSelectionReason": packet.blueprint?.grounding.selectionReason ?? "",
            "storyGroundingSemanticSimilarity": packet.blueprint?.grounding.semanticSimilarity.map { String(format: "%.3f", $0) } ?? "",
            "storyRecipeBeats": packet.blueprint?.beats.joined(separator: "\n") ?? "",
            "storyRecipeGroundingDirective": packet.blueprint?.groundingDirective ?? "",
            "storyRecipeToneDirective": packet.blueprint?.toneDirective ?? "",
            "storyRecipeChoiceDirective": packet.blueprint?.choiceDirective ?? "",
            "storyRecipeContinuationDirective": packet.blueprint?.continuationDirective ?? "",
            StoryDramaticContract.metadataKey: packet.blueprint?.dramaticContract?.encodedMetadata ?? "",
            "storyLeadCharacterWant": packet.blueprint?.dramaticContract?.leadCharacterWant ?? "",
            "storyLeadCharacterWorry": packet.blueprint?.dramaticContract?.leadCharacterWorry ?? "",
            "storyLeadCharacterBlindSpot": packet.blueprint?.dramaticContract?.leadCharacterBlindSpot ?? "",
            "storyOtherCharacterPressure": packet.blueprint?.dramaticContract?.otherCharacterPressure ?? "",
            "storyRelationshipQuestion": packet.blueprint?.dramaticContract?.relationshipQuestion ?? "",
            "storyDramaticStakes": packet.blueprint?.dramaticContract?.stakes ?? "",
            "storyQuillDirective": inputs.chosenQuill.map(QuillChoosing.storyDirective(for:)) ?? "",
            "selectedThreadIDs": selectedThreadIDs,
            "selectedRelationships": selectedRelationships,
            "entityMemories": selectedEntityMemories,
            CharacterCanonPacket.metadataKey: characterCanon,
            "realSignals": packet.realSignals.joined(separator: "\n"),
            "relationshipPressures": packet.relationshipPressures.joined(separator: "\n"),
            "chapterTalismanMoves": chapterTalismanMoves,
            "chapterTalismanDeltas": chapterTalismanDeltas,
            "uses": "characters, locations, belief, relationship graph, story threads",
            "cadence": "four-hour simulation",
            // Which lane this vignette is running in. The Curator picks one of
            // four recipe variants every time it seats a Story Page, so the
            // lane is a choice it is already making; naming it here is what
            // lets it learn whether this reader goes further into their life
            // after the Labyrinth's own errand or after their own words.
            "storyLane": packet.blueprint.map {
                $0.groundingUse == .worldLed ? "world-led" : "grounded"
            } ?? ""
        ]
        if let blueprint = packet.blueprint,
           blueprint.groundingUse != .worldLed,
           blueprint.grounding.kind == .keptPage {
            let grounding = blueprint.grounding
            metadata["tags"] = [
                metadata["tags"],
                MeaningfulPassageSelector.storyUsedTag,
                "\(MeaningfulPassageSelector.legacyStorySourceTagPrefix)\(grounding.sourceID)",
                "\(MeaningfulPassageSelector.sourceTagPrefix)\(grounding.sourceID)",
                "meaningful-source-use:story"
            ]
            .compactMap { $0?.nonEmpty }
            .joined(separator: ",")
        }
        if packet.blueprint?.recipeID == "souvenir-door",
           let grounding = packet.blueprint?.grounding {
            let sparkSentence = grounding.text
                .replacingOccurrences(of: "Story Spark from One-Sentence Souvenir: ", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            metadata["storySparkSourcePageID"] = grounding.sourceID
            metadata["storySparkSentence"] = sparkSentence
            metadata["tags"] = [
                metadata["tags"],
                "story-spark",
                "story-spark-source:\(grounding.sourceID)",
                "story-spark-recipe",
                "souvenir-door"
            ]
            .compactMap { $0?.nonEmpty }
            .joined(separator: ",")
        }
        metadata.merge(mechanicMandate.metadata) { _, new in new }
        if let turn = packet.turn {
            metadata.merge(turn.metadata) { _, new in new }
        }
        let isStorySpark = packet.blueprint?.recipeID == "souvenir-door"
        let previewBody: String
        if isStorySpark {
            previewBody = "One sentence you kept has found a hinge. Open the Page. I’ll tell the scene, then you decide what the little door costs to keep."
        } else if let blueprint = packet.blueprint {
            let cast = [blueprint.leadName, blueprint.companionName]
                .compactMap { $0?.nonEmpty }
                .joined(separator: " and ")
            previewBody = "\(cast) are already in it. Open the Page. I’ll tell the scene, then you decide what becomes true—and what the choice costs."
        } else {
            previewBody = "The story has started without waiting for the furniture. Open the Page. I’ll tell the scene, then you decide what becomes true."
        }
        return SurfacePage(
            id: "\(source.id)-\(packet.id)",
            type: .narrativeOS,
            sourceID: source.id,
            intent: .simulate,
            renderStyle: .graphEvent,
            score: day.capturedPages.count >= 2 ? 86 : 68,
            reason: isStorySpark
                ? "One sentence you kept has a whole little door hiding inside it."
                : "The story is wide awake now, and the characters are itching to do something.",
            prompt: isStorySpark ? "Want this little sentence to open a door?" : "A Story Page is waking up and rubbing its eyes.",
            detail: packet.blueprint.map { "\($0.recipeName): a playable vignette with three roads and no free one." } ?? packet.directorIntent,
            payload: BookPagePayload(
                headline: packet.title,
                body: previewBody,
                metadata: metadata
            )
        ).withPageCapabilities(capability(for: metadata))
    }

    private static func authorCapabilities(on page: SurfacePage) -> SurfacePage {
        page.withPageCapabilities(capability(for: page.payload.metadata))
    }

    private static func capability(for metadata: [String: String]) -> PageCapabilityContract {
        let lane = metadata["storyLane"]
        let recipeID = metadata["storyRecipeID"]
        let mechanic = StoryPageMechanicMandate.from(metadata: metadata)
        var movements: [BookReenchantmentMovement]
        var functions: [PageEmotionalFunction]

        if recipeID == "souvenir-door" {
            movements = [.livingContinuity, .exactLanguage, .humanOtherness]
            functions = [.remember, .connect, .play]
        } else if lane == "grounded" {
            movements = [.livingContinuity, .humanOtherness, .exactLanguage]
            functions = [.remember, .connect, .play]
        } else {
            movements = [.livingWorld, .humanOtherness, .chosenDetour]
            functions = [.wonder, .connect, .play]
        }

        switch mechanic.kind {
        case .beliefDice:
            if !movements.contains(.scriptFreedom) { movements.append(.scriptFreedom) }
            if !functions.contains(.act) { functions.append(.act) }
        case .compassRun, .enchantment:
            if !movements.contains(.freshSight) { movements.append(.freshSight) }
            if !functions.contains(.wonder) { functions.append(.wonder) }
        case .none:
            break
        }

        return PageCapabilityContract(
            supportedMovements: movements,
            supportedRoles: [.horizon, .echo, .door],
            emotionalFunctions: functions,
            effort: mechanic.kind == .none ? .small : .involved,
            reach: .insideBook,
            estimatedMinutes: mechanic.kind == .none ? 6 : 10,
            asksReader: true,
            pressureCost: mechanic.kind == .none ? 0.18 : 0.28,
            proofModes: [.response]
        )
    }
}

struct MarginsAtlasPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .marginsAtlas)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }
        let entities = NarrativePackRegistry.entities + inputs.customCastMembers.map(\.entity)
        let relationships = NarrativePackRegistry.relationships
        let events = inputs.recentNarrativeEvents
        let loom = NarrativeGraphData.loom(
            entities: entities,
            relationships: relationships,
            threads: NarrativePackRegistry.threads,
            beliefOffsets: inputs.entityBeliefOffsets,
            relationshipField: inputs.relationshipField
        )
        let constellation = NarrativeGraphData.constellation(
            entities: entities,
            beliefOffsets: inputs.entityBeliefOffsets,
            events: events,
            playerBelief: inputs.narrative?.beliefWeight ?? 30
        )
        let company = PeopleOfTheBook.knowledgeGraph(ledger: inputs.people, days: inputs.days + [day]).atlasGraph
        let archive = inputs.days + [day]
        var pages: [SurfacePage] = []
        if !loom.nodes.isEmpty && !loom.edges.isEmpty {
            pages.append(surface(variant: .loom, graph: loom, day: day, now: now, score: 44 + min(14, loom.edges.count)))
        }
        if constellation.nodes.count > 1 {
            pages.append(surface(variant: .constellation, graph: constellation, day: day, now: now, score: 46 + min(14, constellation.edges.count * 2)))
        }
        if company.nodes.count > 1 && !company.edges.isEmpty {
            pages.append(surface(variant: .company, graph: company, day: day, now: now, score: 48 + min(14, company.edges.count)))
        }
        // The maps of the reader. Each returns an empty graph until the archive
        // can honestly support it, so a young Book simply draws fewer maps
        // rather than drawing thin ones.
        // Four passes over every kept page. They are pure in the archive, and
        // the archive does not change between desk builds, so they are drawn
        // once per version of it rather than once per build.
        let readerMaps = ArchiveMemo.value(
            "margins-atlas.reader-maps",
            days: archive,
            compute: { () -> [(MarginsAtlasVariant, NarrativeGraphData)] in
                [
                    (.lexicon, ReaderAtlas.lexicon(days: archive)),
                    (.hours, ReaderAtlas.hours(days: archive)),
                    (.skies, ReaderAtlas.skies(days: archive)),
                    (.places, ReaderAtlas.places(days: archive))
                ]
            }
        )
        // The one face that is not a drawing. It goes above the maps: a rule the
        // Book has held for months, with what would break it, outranks any
        // picture of what merely touched what.
        if let body = GrimoireVoice.folio(ledger: inputs.grimoire, now: now) {
            pages.append(lawsSurface(ledger: inputs.grimoire, body: body, day: day, now: now))
        }
        for (variant, graph) in readerMaps where !graph.edges.isEmpty {
            // Scored a little above the world maps: a map made of the reader's
            // own words is a stronger claim to have read them than a diagram of
            // the cast, and it is the one they cannot get anywhere else.
            pages.append(surface(
                variant: variant,
                graph: graph,
                day: day,
                now: now,
                score: 50 + min(14, graph.edges.count)
            ))
        }
        return pages
    }

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        candidates(for: day, context: context, inputs: inputs, now: now).first ?? SurfacePage(
            id: "\(source.id)-empty-\(day.id)-\(Int(now.timeIntervalSince1970))",
            type: .marginsAtlas,
            sourceID: source.id,
            intent: .simulate,
            renderStyle: .graphEvent,
            score: 52,
            reason: "I can't draw the Atlas yet. Nothing has crossed anything.",
            prompt: "I have no lines to draw yet.",
            detail: "Keep a Page, name a person, or spend some Belief. The moment two things actually touch, I'll draw it.",
            payload: BookPagePayload(
                headline: "The Margins Atlas",
                body: "The map is empty because I have not found two connected things yet. The paper is waiting. It keeps staring at the pins.",
                metadata: [
                    "source": source.id,
                    "graphVariant": MarginsAtlasVariant.loom.rawValue,
                    "graphNodes": "",
                    "graphEdges": "",
                    "tags": "margins-atlas,graph,empty"
                ]
            )
        )
    }

    /// The accumulated body, as its own leaf of the Atlas.
    ///
    /// Prose rather than a graph on purpose: a law is a sentence with a count
    /// and a promise attached, and none of that survives being drawn as dots
    /// and lines. It carries no `observationKey` — correcting a reading is a
    /// conversation about *one* claim, and that belongs on the Notice that made
    /// it, not on the page that lists them all.
    private func lawsSurface(
        ledger: GrimoireLedger,
        body: String,
        day: BookDay,
        now: Date
    ) -> SurfacePage {
        let standing = ledger.rows.values.filter { $0.state == .standing }.count
        let crossed = ledger.crossedOut.count
        let held = standing == 1 ? "one rule" : "\(standing) rules"
        return SurfacePage(
            id: "\(source.id)-\(MarginsAtlasVariant.laws.rawValue)-\(day.id)-\(SurfaceCadence.slotID(for: now, hours: 24))",
            type: .marginsAtlas,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            // Above the maps, and it climbs as the body grows.
            score: min(72, 56 + standing * 2 + crossed),
            reason: crossed > 0
                ? "I am holding \(held) about you, and I have crossed out \(crossed)."
                : "I am holding \(held) about you.",
            prompt: MarginsAtlasVariant.laws.title,
            detail: MarginsAtlasVariant.laws.detail,
            payload: BookPagePayload(
                headline: MarginsAtlasVariant.laws.title,
                body: body,
                metadata: [
                    "source": source.id,
                    "graphVariant": MarginsAtlasVariant.laws.rawValue,
                    "grimoireFolio": "true",
                    "grimoireStanding": "\(standing)",
                    "grimoireCrossedOut": "\(crossed)",
                    "tags": "margins-atlas,laws,grimoire,life-knowledge"
                ]
            )
        )
    }

    private func surface(
        variant: MarginsAtlasVariant,
        graph: NarrativeGraphData,
        day: BookDay,
        now: Date,
        score: Int
    ) -> SurfacePage {
        SurfacePage(
            id: "\(source.id)-\(variant.rawValue)-\(day.id)-\(SurfaceCadence.slotID(for: now, hours: 24))",
            type: .marginsAtlas,
            sourceID: source.id,
            intent: .simulate,
            renderStyle: .graphEvent,
            score: score,
            reason: {
                switch variant {
                case .loom: return "I found \(graph.edges.count) relationship line\(graph.edges.count == 1 ? "" : "s") among \(graph.nodes.count) cast member\(graph.nodes.count == 1 ? "" : "s"), so I drew them."
                case .constellation: return "Belief has reached \(graph.nodes.count) characters or places along \(graph.edges.count) line\(graph.edges.count == 1 ? "" : "s"), so I drew where it went."
                case .company: return "I found \(graph.edges.count) line\(graph.edges.count == 1 ? "" : "s") among \(graph.nodes.count) real people and shared parts of life, so I drew them."
                case .laws:
                    // Unreachable: the laws face is prose and has its own
                    // builder. Kept explicit so adding a variant is a decision.
                    return "I am holding some rules about you."
                case .hours, .skies, .places, .lexicon:
                    // The reader's maps count in Pages, not in cast members: the
                    // claim is "you did this, this many times", so the receipt
                    // has to be their own ink rather than my inventory.
                    let lines = graph.edges.count
                    return "I read back through your own pages and found \(lines) line\(lines == 1 ? "" : "s") worth drawing."
                }
            }(),
            prompt: variant.title,
            detail: variant.detail,
            payload: BookPagePayload(
                headline: variant.title,
                body: "\(variant.openingLine) \(Self.standingLine(for: graph))\n\nOpen the map. Tap a name to see its lines. Pinch it. Drag it. The pins enjoy being handled.",
                metadata: [
                    "source": source.id,
                    "graphVariant": variant.rawValue,
                    "graphNodes": encode(nodes: graph.nodes),
                    "graphEdges": encode(edges: graph.edges),
                    "claimTier": Self.tier(for: graph).rawValue,
                    "tags": "margins-atlas,\(variant.rawValue),graph,claim-\(Self.tier(for: graph).rawValue)\(variant == .company ? ",people-of-the-book,life-knowledge" : "")"
                ]
            )
        )
    }

    /// A three-edge atlas and a sixty-edge atlas are both worth drawing. They
    /// are not worth the same sentence, so the Book says how much map it has.
    static func tier(for graph: NarrativeGraphData) -> BookClaimTier {
        BookClaimTier.tier(evidenceWeight: graph.edges.count)
    }

    private static func standingLine(for graph: NarrativeGraphData) -> String {
        let tier = tier(for: graph)
        let edges = graph.edges.count
        switch tier {
        case .glimmer:
            return "It's a small map so far: \(edges == 1 ? "one crossing" : "\(edges) crossings"). Enough to look at. Not enough to argue with."
        case .gathering:
            return "\(edges) crossings, and some of these lines have started repeating themselves."
        case .established:
            return "\(edges) crossings. It repeats enough now that I'd read the whole thing as one shape."
        }
    }

    private func encode(nodes: [GraphNode]) -> String {
        nodes.map { node in
            [
                node.id,
                node.label,
                String(format: "%.2f", node.weight),
                node.chapterID ?? "",
                node.kindLabel
            ].map(escape).joined(separator: "||")
        }.joined(separator: "\n")
    }

    private func encode(edges: [GraphEdge]) -> String {
        edges.map { edge in
            [
                edge.id,
                edge.sourceID,
                edge.targetID,
                String(format: "%.3f", edge.strength),
                String(format: "%.3f", edge.warmth),
                edge.label
            ].map(escape).joined(separator: "||")
        }.joined(separator: "\n")
    }

    private func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "||", with: "\\p")
    }
}

struct GossipPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .gossip)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }
        if let prepared = inputs.preparedGossipPageSurface,
           prepared.type == .gossip {
            return [prepared]
        }

        // The cast's authored business is already finished prose. Requiring a
        // prepared Gossip Page here made the automatic desk incapable of ever
        // discovering it: preparation was normally triggered only after the
        // reader manually opened Gossip. One unseen scene may now rise on its
        // own each reader-day, with no model call and no invented occurrence.
        return GossipSimulationBuilder.undertakingCandidate(inputs: inputs, now: now)
            .map { [$0] }
            ?? []
    }

    static func draftCandidate(for day: BookDay, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        GossipSimulationBuilder.surface(for: day, inputs: inputs, now: now)
    }
}

struct BookAsidePageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .bookAside)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive,
              let prepared = inputs.preparedGossipPageSurface,
              prepared.type == .bookAside else { return [] }
        return [prepared]
    }
}

/// A small, point-in-time view of what the Book can honestly say about one
/// member of the Cast. It travels with an Illustration Page as metadata so the
/// reader sees the same record the source chose, without a view reaching back
/// into the database while SwiftUI is laying out the Page.
struct CastMemberLivingRecord: Codable, Equatable {
    struct Memory: Codable, Equatable, Identifiable {
        var id: String
        var summary: String
        var createdAt: Date
    }

    struct Action: Codable, Equatable, Identifiable {
        var id: String
        var line: String
        var createdAt: Date
    }

    struct PageVisit: Codable, Equatable, Identifiable {
        var id: String
        var title: String
        var typeTitle: String
        var createdAt: Date
    }

    struct Relationship: Codable, Equatable, Identifiable {
        enum Disposition: String, Codable, Equatable {
            case warm
            case tense
            case familiar
        }

        var id: String
        var name: String
        var disposition: Disposition
        var detail: String
        var strength: Int
    }

    static let metadataKey = "castLivingRecordV1"

    var generatedAt: Date
    var memories: [Memory]
    var actions: [Action]
    var lastPage: PageVisit?
    var relationships: [Relationship]

    var encodedMetadata: String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return data.base64EncodedString()
    }

    init?(encodedMetadata: String) {
        guard let data = Data(base64Encoded: encodedMetadata),
              let decoded = try? JSONDecoder().decode(Self.self, from: data) else {
            return nil
        }
        self = decoded
    }

    init(
        entity: NarrativeWorldEntity,
        cast: [NarrativeWorldEntity],
        memories allMemories: [NarrativeEntityMemory],
        days: [BookDay],
        movements: [CastAgencyMovement],
        authoredRelationships: [NarrativeRelationshipEdge],
        relationshipField: [String: RelationshipTie],
        now: Date
    ) {
        generatedAt = now

        var seenMemorySummaries = Set<String>()
        memories = allMemories
            .filter { $0.entityID == entity.id }
            .sorted { $0.createdAt > $1.createdAt }
            .filter {
                let key = $0.summary.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                return !key.isEmpty && seenMemorySummaries.insert(key).inserted
            }
            .prefix(4)
            .map { Memory(id: $0.id, summary: $0.summary, createdAt: $0.createdAt) }

        actions = movements
            .filter { $0.actorID == entity.id }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(3)
            .map { Action(id: $0.id, line: $0.line, createdAt: $0.createdAt) }

        let rememberedPageIDs = Set(allMemories
            .filter { $0.entityID == entity.id }
            .compactMap(\.sourcePageID))
        var seenPageIDs = Set<String>()
        let last = days
            .flatMap(\.pages)
            .filter { seenPageIDs.insert($0.id).inserted }
            .filter {
                $0.tags.contains("entity:\(entity.id)")
                    || $0.tags.contains("sender:\(entity.id)")
                    || rememberedPageIDs.contains($0.id)
            }
            .max { $0.createdAt < $1.createdAt }
        lastPage = last.map {
            PageVisit(
                id: $0.id,
                title: $0.promptText.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
                    ?? $0.type.title,
                typeTitle: $0.type.title,
                createdAt: $0.createdAt
            )
        }

        let possibleOthers = cast.filter { $0.id != entity.id && $0.kind == .character }
        relationships = possibleOthers.compactMap { other -> Relationship? in
            let pairKey = NarrativeGraphData.relationshipPairKey(entity.id, other.id)
            let authored = authoredRelationships.filter {
                NarrativeGraphData.relationshipPairKey($0.sourceEntityID, $0.targetEntityID) == pairKey
            }
            let field = relationshipField[pairKey] ?? .zero
            let authoredWarmth = authored.reduce(0) { $0 + $1.warmth + $1.trust }
            let authoredTension = authored.reduce(0) {
                $0 + $1.tension + ($1.kind == .tension ? 3 : 0)
            }
            let warmth = authoredWarmth + field.warmth
            let tension = authoredTension + field.tension
            let familiarity = field.familiarity + authored.count

            let disposition: Relationship.Disposition
            let strength: Int
            if warmth >= 2, warmth > tension {
                disposition = .warm
                strength = warmth - tension
            } else if tension >= 2, tension > warmth {
                disposition = .tense
                strength = tension - warmth
            } else if familiarity >= 2 {
                disposition = .familiar
                strength = familiarity
            } else {
                return nil
            }

            let authoredNote = authored
                .map(\.note)
                .first { $0.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty != nil }
            let detail: String
            if let authoredNote {
                detail = authoredNote
            } else {
                switch disposition {
                case .warm: detail = "Their shared thread has warmed."
                case .tense: detail = "Their thread has picked up a sharp edge."
                case .familiar: detail = "They keep crossing the same pages."
                }
            }
            return Relationship(
                id: other.id,
                name: other.name,
                disposition: disposition,
                detail: detail,
                strength: strength
            )
        }
        .sorted {
            if $0.strength == $1.strength { return $0.name < $1.name }
            return $0.strength > $1.strength
        }
        .prefix(6)
        .map { $0 }
    }
}

struct CastIllustrationPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .illustration)

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        guard let pick = selectedEntity(from: castPool(inputs: inputs), offsets: inputs.entityBeliefOffsets, excluding: inputs.recentVarietyKeys(now: now), now: now, manual: true) else {
            return emptySurface(day: day, now: now)
        }
        return surface(
            for: pick.entity,
            imageAsset: pick.imageAsset,
            context: context,
            offsets: inputs.entityBeliefOffsets,
            livingRecord: livingRecord(for: pick.entity, day: day, inputs: inputs, now: now),
            now: now,
            manual: true
        )
    }

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive,
              let pick = selectedEntity(from: castPool(inputs: inputs), offsets: inputs.entityBeliefOffsets, excluding: inputs.recentVarietyKeys(now: now), now: now, manual: false) else {
            return []
        }
        return [surface(
            for: pick.entity,
            imageAsset: pick.imageAsset,
            context: context,
            offsets: inputs.entityBeliefOffsets,
            livingRecord: livingRecord(for: pick.entity, day: day, inputs: inputs, now: now),
            now: now,
            manual: false
        )]
    }

    /// The whole illustration-facing cast: bundled characters, bundled
    /// locations, and the reader's custom cast, so places can earn pages by
    /// Belief and narrative weight without becoming speaking characters.
    private func castPool(inputs: BookSourceInputs) -> [(entity: NarrativeWorldEntity, imageAsset: BookPageMediaAsset?)] {
        let bundled = NarrativePackRegistry.entities
            .filter { $0.kind == .character || $0.kind == .location }
            .map { (entity: $0, imageAsset: Optional<BookPageMediaAsset>.none) }
        let custom = inputs.customCastMembers
            .map { (entity: $0.entity, imageAsset: $0.imageAsset) }
        return bundled + custom
    }

    private func effectiveBelief(_ entity: NarrativeWorldEntity, _ offsets: [String: Int]) -> Int {
        max(0, min(100, entity.belief + (offsets[entity.id] ?? 0)))
    }

    private func selectedEntity(
        from pool: [(entity: NarrativeWorldEntity, imageAsset: BookPageMediaAsset?)],
        offsets: [String: Int],
        excluding recentKeys: Set<String> = [],
        now: Date,
        manual: Bool
    ) -> (entity: NarrativeWorldEntity, imageAsset: BookPageMediaAsset?)? {
        guard !pool.isEmpty else { return nil }
        // Anyone the reader met in the last two days steps back so the rest of
        // the cast gets the page; the pool reopens once everyone has had a turn.
        let fresh = pool.filter { !recentKeys.contains("cast:\($0.entity.id)") }
        let usable = fresh.isEmpty ? pool : fresh
        let stronglyBelieved = usable.filter { (offsets[$0.entity.id] ?? 0) >= 50 }
        if let strongest = stronglyBelieved.sorted(by: { left, right in
            let leftOffset = offsets[left.entity.id] ?? 0
            let rightOffset = offsets[right.entity.id] ?? 0
            if leftOffset != rightOffset { return leftOffset > rightOffset }
            let leftBelief = effectiveBelief(left.entity, offsets)
            let rightBelief = effectiveBelief(right.entity, offsets)
            if leftBelief != rightBelief { return leftBelief > rightBelief }
            if left.entity.narrativeWeight != right.entity.narrativeWeight {
                return left.entity.narrativeWeight > right.entity.narrativeWeight
            }
            return left.entity.id < right.entity.id
        }).first {
            return strongest
        }
        let slot = manual ? "\(Int(now.timeIntervalSince1970))-\(UUID().uuidString)" : SurfaceCadence.minuteSlotID(for: now, minutes: 20)
        let scored = usable
            .map { item -> (item: (entity: NarrativeWorldEntity, imageAsset: BookPageMediaAsset?), score: Int) in
                let jitter = stableIndex(for: "\(item.entity.id)-\(slot)", count: 18)
                let score = item.entity.narrativeWeight + effectiveBelief(item.entity, offsets) / 2 + jitter
                return (item, score)
            }
            .sorted { $0.item.entity.id < $1.item.entity.id }
        return StableWeightedRoll.pick(
            from: scored,
            seed: "\(slot)-cast-illustration-entity",
            weight: { $0.score }
        )?.item
    }

    func surface(
        for entity: NarrativeWorldEntity,
        imageAsset: BookPageMediaAsset?,
        context: CuratorContext,
        offsets: [String: Int],
        livingRecord: CastMemberLivingRecord?,
        now: Date,
        manual: Bool
    ) -> SurfacePage {
        let meaning = entity.unwrittenInterest?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let description = entity.quirks.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        let belief = effectiveBelief(entity, offsets)
        let isLocation = entity.kind == .location
        let isCustom = entity.packID == "user-cast"
        var metadata = [
            "source": source.id,
            "illustrationKind": isLocation ? "location" : "cast",
            "entityID": entity.id,
            "entityName": entity.name,
            "entityKind": entity.kind.rawValue,
            "meaning": meaning,
            "description": description,
            "tags": (entity.tags + ["entity:\(entity.id)", isCustom ? "custom-cast" : (isLocation ? "bundled-location" : "bundled-cast")]).joined(separator: ","),
            "traits": entity.traits.joined(separator: ","),
            "privacy": "private local cast"
        ]
        if let imageAsset {
            metadata["imageAssetKind"] = imageAsset.kind.rawValue
            metadata["imageAssetReference"] = imageAsset.reference
        }
        if let encodedRecord = livingRecord?.encodedMetadata {
            metadata[CastMemberLivingRecord.metadataKey] = encodedRecord
        }
        // A bundled cast member with real dossier art should show that full
        // illustration in the body and shelf preview, not just the medallion
        // in the header. When a matching illustration profile exists we also
        // hand the page that profile's richer, character-specific prose so the
        // card reads like a dossier instead of a filled-in form.
        let profile = imageAsset == nil ? CharacterPortrait.profile(forName: entity.name) : nil
        if let profile, let bundledAsset = CharacterPortrait.bundledAssetName(forName: entity.name) {
            metadata["assetName"] = bundledAsset
            metadata["characterID"] = profile.id
            metadata["characterSlug"] = profile.slug
        }
        let body = profile.map(LabyrinthIllustrationPageSourceAdapter.bookPageBody(for:))
            ?? Self.castBody(for: entity, description: description, meaning: meaning)
        let slotID = manual ? "\(Int(now.timeIntervalSince1970))" : SurfaceCadence.minuteSlotID(for: now, minutes: 20)
        return SurfacePage(
            id: "\(source.id)-cast-\(entity.id)-\(slotID)",
            type: .illustration,
            sourceID: source.id,
            intent: .importReference,
            renderStyle: .quoteCard,
            score: context.distress.isActive ? 44 : min(70, 42 + belief / 3 + entity.narrativeWeight / 5),
            reason: "\(entity.name) has enough Belief now to tiptoe right into the margins.",
            prompt: entity.name,
            detail: profile.map(LabyrinthIllustrationPageSourceAdapter.bookDetail(for:))
                ?? (meaning.isEmpty ? (isLocation ? "A place in my living world." : "A member of my cast.") : meaning),
            payload: BookPagePayload(
                headline: entity.name,
                body: body.isEmpty ? "\(entity.name) is part of my living world." : body,
                metadata: metadata
            )
        )
    }

    private func livingRecord(
        for entity: NarrativeWorldEntity,
        day: BookDay,
        inputs: BookSourceInputs,
        now: Date
    ) -> CastMemberLivingRecord {
        let cast = NarrativePackRegistry.entities + inputs.customCastMembers.map(\.entity)
        let days = inputs.days.contains(where: { $0.id == day.id })
            ? inputs.days
            : inputs.days + [day]
        return CastMemberLivingRecord(
            entity: entity,
            cast: cast,
            memories: inputs.narrative?.entityMemories ?? [],
            days: days,
            movements: inputs.castAgency.recentMovements,
            authoredRelationships: NarrativePackRegistry.relationships,
            relationshipField: inputs.relationshipField,
            now: now
        )
    }

    /// The Book introducing a cast member in its own voice, not a labelled
    /// record. It weaves the entity's traits, quirks, belief, longing, and the
    /// one fault it keeps an eye on, varied by entity so two cards never read
    /// like the same form filled out twice.
    static func castBody(for entity: NarrativeWorldEntity, description: String, meaning: String) -> String {
        let name = entity.name
        var lines: [String] = []

        let openings = entity.kind == .location
            ? [
                "Here is where \(name) has begun to matter.",
                "\(name) has gathered enough Belief to become more than backdrop.",
                "Let me hand you my map-notes on \(name).",
                "\(name) earns the page. This is why."
            ]
            : [
                "Here is what I've kept on \(name).",
                "\(name) has stepped far enough into the margins for me to take a proper reading.",
                "Let me hand you my notes on \(name).",
                "\(name) earns the page. This is why."
            ]
        lines.append(openings[stableIndex(for: "cast-open-\(entity.id)", count: openings.count)])

        if !entity.traits.isEmpty {
            lines.append(entity.kind == .location
                ? "What the room gives first is \(oxfordList(entity.traits))."
                : "What shows first is \(oxfordList(entity.traits)).")
        }
        if !description.isEmpty {
            lines.append(finishSentence(description))
        }
        if let belief = entity.beliefs.first(where: { !$0.trimmed.isEmpty }) {
            lines.append(entity.kind == .location
                ? "The place keeps insisting that \(lowerFirst(belief.strippedClause))."
                : "They hold that \(lowerFirst(belief.strippedClause)).")
        }
        if !meaning.isEmpty {
            lines.append(entity.kind == .location
                ? "Lately its doors keep circling back to \(lowerFirst(meaning.strippedClause))."
                : "Lately they keep circling back to \(lowerFirst(meaning.strippedClause)).")
        }
        if let goal = entity.goals.first(where: { !$0.trimmed.isEmpty }) {
            lines.append(entity.kind == .location
                ? "Its job in the story field is to \(lowerFirst(goal.strippedClause))."
                : "What they are reaching for is \(lowerFirst(goal.strippedClause)).")
        }
        if let fault = entity.faults.first(where: { !$0.trimmed.isEmpty }) {
            lines.append(entity.kind == .location
                ? "The risk I keep one eye on: \(lowerFirst(fault.strippedClause))."
                : "The flaw I keep one eye on: \(lowerFirst(fault.strippedClause)).")
        }

        return lines.joined(separator: " ")
    }

    private static func oxfordList(_ items: [String]) -> String {
        let clean = items.map { $0.trimmed }.filter { !$0.isEmpty }
        switch clean.count {
        case 0: return ""
        case 1: return clean[0]
        case 2: return "\(clean[0]) and \(clean[1])"
        default: return clean.dropLast().joined(separator: ", ") + ", and " + (clean.last ?? "")
        }
    }

    private static func finishSentence(_ text: String) -> String {
        let trimmed = text.trimmed
        guard !trimmed.isEmpty else { return "" }
        if let last = trimmed.last, ".!?".contains(last) { return trimmed }
        return trimmed + "."
    }

    private static func lowerFirst(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.lowercased() + String(text.dropFirst())
    }

    private func emptySurface(day: BookDay, now: Date) -> SurfacePage {
        SurfacePage(
            id: "\(source.id)-cast-empty-\(day.id)-\(Int(now.timeIntervalSince1970))",
            type: .illustration,
            sourceID: source.id,
            intent: .capture,
            renderStyle: .promptCard,
            score: 40,
            reason: "You haven't made your own cast member yet.",
            prompt: "No custom cast member yet.",
            detail: "Invite one into the Cast first.",
            payload: BookPagePayload(
                headline: "The illustration shelf is waiting.",
                body: "Invite a new Cast Member, then an illustration can find them.",
                metadata: ["source": source.id]
            )
        )
    }

    private func stableIndex(for key: String, count: Int) -> Int {
        Self.stableIndex(for: key, count: count)
    }

    static func stableIndex(for key: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Int(hash % UInt64(count))
    }
}

struct LocationPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .location)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }
        return [
            SurfacePage(
                type: .location,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .gentleTranslation,
                score: 56,
                reason: "Where you are can change the story without me ever spying on you.",
                prompt: "What place am I standing in with you?",
                detail: "A place can turn into a page without ever turning into a report on you.",
                payload: BookPagePayload(
                    headline: "Location Page",
                    body: "A place can become a page without becoming a report.",
                    metadata: ["source": source.id, "outerStacks": "possible"]
                )
            ).withPageCapabilities(PageCapabilityContract(
                supportedMovements: [.livingWorld, .freshSight],
                supportedRoles: [.door, .echo],
                emotionalFunctions: [.notice, .wonder, .express],
                effort: .small,
                reach: .nearbyWorld,
                mobility: .stationary,
                estimatedMinutes: 2,
                asksReader: true,
                pressureCost: 0.20,
                proofModes: [.place, .response]
            ))
        ]
    }
}

struct OuterStacksAnchorPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .anchor)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        if let prepared = inputs.preparedAnchorSurface {
            return [authorCapabilities(on: prepared)]
        }
        guard let proximity = inputs.nearbyAnchor else { return [] }
        return [authorCapabilities(on: surface(for: proximity, day: day, now: now))]
    }

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        if let prepared = inputs.preparedAnchorSurface {
            return authorCapabilities(on: prepared)
        }
        if let proximity = inputs.nearbyAnchor {
            return authorCapabilities(on: surface(for: proximity, day: day, now: now))
        }
        return authorCapabilities(on: SurfacePage(
            id: "manual-\(source.id)-\(day.id)-\(Int(now.timeIntervalSince1970))",
            type: .anchor,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: 58,
            reason: "Anchors it already knows can open little local rooms when your device gets close enough.",
            prompt: "Check nearby Anchors",
            detail: "I can peek at your location just once and listen for an Outer Stacks door.",
            payload: BookPagePayload(
                headline: "Outer Stacks",
                body: "No Anchor is glowing yet. Come closer and ask me about nearby places; if a known Anchor is within two hundred meters, its room can rise as a page.",
                metadata: [
                    "source": source.id,
                    "privacy": "location stays on device",
                    "tags": "anchor,outer-stacks,location,local"
                ]
            )
        ))
    }

    private func authorCapabilities(on page: SurfacePage) -> SurfacePage {
        let isLiveAnchor = page.payload.metadata["anchorID"]?.nonEmpty != nil
        if isLiveAnchor {
            return page.withPageCapabilities(PageCapabilityContract(
                supportedMovements: [.livingWorld, .freshSight, .livingContinuity],
                supportedRoles: [.door, .horizon],
                emotionalFunctions: [.wonder, .notice, .connect, .remember],
                effort: .small,
                reach: .nearbyWorld,
                mobility: .stationary,
                estimatedMinutes: 5,
                asksReader: true,
                pressureCost: 0.28,
                proofModes: [.place, .response],
                requirements: [.nearbyAnchor]
            ))
        }
        return page.withPageCapabilities(PageCapabilityContract(
            supportedMovements: [.livingWorld, .freshSight],
            supportedRoles: [.door],
            emotionalFunctions: [.wonder, .notice],
            effort: .glance,
            reach: .insideBook,
            estimatedMinutes: 1,
            asksReader: true,
            pressureCost: 0.12,
            proofModes: [.place]
        ))
    }

    private func surface(for proximity: AnchorProximity, day: BookDay, now: Date) -> SurfacePage {
        let anchor = proximity.anchor
        let season = AnchorRegistry.currentSeason(for: now)
        let visitPhrase = proximity.visitMode == "FIRST_VISIT"
            ? "First visit"
            : "Return visit \(proximity.nextVisitCount)"
        let room = nonEmpty(anchor.outerStacksRoom)
            ?? "The room has not fully written itself yet, but the threshold is present."
        let storyScene = anchorVisitVignette(
            anchor: anchor,
            room: room,
            visitPhrase: visitPhrase,
            season: season
        )
        let body = "\(storyScene)\n\nKeeping this page checks in at the Anchor and offers it a little Belief from your Glow."
        let turn = AnchorTurnBuilder.turn(
            anchor: anchor,
            visitMode: proximity.visitMode,
            slotKey: "\(anchor.id)-\(anchor.visitCount)"
        )

        return SurfacePage(
            id: "\(source.id)-\(anchor.id)-\(day.id)-\(Int(now.timeIntervalSince1970))",
            type: .anchor,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: min(96, 78 + max(0, 200 - Int(proximity.distanceMeters)) / 8 + anchor.visitCount),
            reason: "\(anchor.name) is within \(Int(proximity.distanceMeters.rounded()))m.",
            prompt: anchor.name,
            detail: "\(visitPhrase). \(anchor.kind.title) Anchor.",
            payload: BookPagePayload(
                headline: "Outer Stacks: \(anchor.name)",
                body: body,
                metadata: [
                    "source": source.id,
                    "anchorID": anchor.id,
                    "anchorName": anchor.storyName,
                    "anchorKind": anchor.kind.rawValue,
                    "distanceMeters": "\(Int(proximity.distanceMeters.rounded()))",
                    "radiusMeters": "\(Int(anchor.radiusMeters.rounded()))",
                    "visitMode": proximity.visitMode,
                    "nextVisitCount": "\(proximity.nextVisitCount)",
                    "seasonShift": season,
                    "beliefReward": "\(AnchorRegistry.checkInBeliefReward)",
                    "room": room,
                    "fae": anchor.fae,
                    "localRule": anchor.localRule,
                    "anchorEmotionalRegister": anchor.emotionalRegister ?? "",
                    "anchorPlaceReceipt": anchor.place?.promptLine ?? "",
                    "sessionSubjectThreadID": "Outer Stacks: \(anchor.storyName)",
                    "selectedThreads": "Outer Stacks,\(anchor.storyName)",
                    "selectedEntities": "\(anchor.fae.nonEmpty ?? "The Anchor Fae"),The Book",
                    "realSignals": "\(visitPhrase)\n\(season)\n\(anchor.kind.title) Anchor",
                    "relationshipPressures": nonEmpty(anchor.localRule) ?? "The local rule asks to be honored before the room opens further.",
                    "entityMemories": nonEmpty(anchor.miniStory) ?? "This Anchor has a small story already in motion.",
                    "storyScene": storyScene,
                    "storyChoiceSliceOfLifeTitle": "Honor the Rule",
                    "storyChoiceSliceOfLifePrompt": "Follow the Anchor's local rule and notice what changes.",
                    "storyChoiceSliceOfLifeEffect": "The room trusts the reader with one more exact detail.",
                    "storyChoiceSliceOfLifeMechanic": "none",
                    "storyChoiceProgressArcTitle": "Approach the Fae",
                    "storyChoiceProgressArcPrompt": "Ask the room's Fae what it has been guarding.",
                    "storyChoiceProgressArcEffect": "The Anchor thread advances through a direct question.",
                    "storyChoiceProgressArcMechanic": "none",
                    "storyChoiceSurpriseTitle": "Test the Threshold",
                    "storyChoiceSurprisePrompt": "Follow the oddest sound, object, or draft at the edge of the room.",
                    "storyChoiceSurpriseEffect": "A side door in the Outer Stacks notices the visit.",
                    "storyChoiceSurpriseMechanic": "none",
                    "storyResultSliceOfLife": "The local rule holds. The Anchor warms by one small truth, and the room lets a hidden detail stay visible.",
                    "storyResultProgressArc": "The Fae answers without giving away everything. The Anchor's private thread moves one step farther into the stacks.",
                    "storyResultSurprise": "The threshold gives under the reader's attention. Something adjacent to this place may call back later.",
                    "privacy": "location stays on device",
                    "tags": "anchor,outer-stacks,\(anchor.kind.rawValue.lowercased()),location"
                ].merging(turn.metadata) { _, new in new }
            )
        )
    }

    private func nonEmpty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func anchorVisitVignette(anchor: AnchorRecord, room: String, visitPhrase: String, season: String) -> String {
        let fae = nonEmpty(anchor.fae) ?? "the Fae who keeps this threshold"
        let rule = nonEmpty(anchor.localRule) ?? "Notice before you take a step."
        let register = anchor.emotionalRegister?.nonEmpty ?? "particular, alert, and awake"
        let miniStory = nonEmpty(anchor.miniStory)
            ?? "One ordinary habit of this place has begun making its own decisions."
        let opening = anchor.visitCount <= 0
            ? "The threshold at \(anchor.storyName) catches the day's nearest color and opens in a \(register) mood. \(season) gets through first. The room objects, then makes space for you too."
            : "The threshold at \(anchor.storyName) catches the light again and opens with the confidence of something that remembers you. \(visitPhrase) has altered one useful object, and another is making a fuss about it."

        return """
        \(opening)

        \(room) The place's ordinary work has followed it through the door and become impossible without becoming unrecognizable.

        \(fae) looks up in the middle of their work and makes an immediate judgment about how you entered. The rule arrives without ceremony: \(rule)

        \(miniStory) Today it moves one small step farther. An ordinary object answers in the room's own register and leaves the next question inconveniently open.
        """
    }
}

struct LocalBrainAwakePageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(id: "local-brain-awake")

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }
        guard inputs.localBrainIsReady else { return [] }
        guard inputs.surfaceHistory["source:\(source.id)"] == nil else { return [] }
        guard !day.pages.contains(where: { $0.tags.contains("local-brain-awake") }) else { return [] }
        return [awakeSurface(playerName: LabyrinthWelcomePageSourceAdapter.playerName(from: inputs), score: 96)]
    }

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        awakeSurface(playerName: LabyrinthWelcomePageSourceAdapter.playerName(from: inputs), score: 72)
    }

    private func awakeSurface(playerName: String?, score: Int) -> SurfacePage {
        let name = playerName?.nonEmpty ?? "Reader"
        return SurfacePage(
            id: "\(source.id)-first-waking",
            type: .welcome,
            sourceID: source.id,
            intent: .importReference,
            renderStyle: .loreLetter,
            score: score,
            reason: "The private little mind woke up behind the shelves and immediately began reading the fine print.",
            prompt: "Another Lamp Comes On",
            detail: "I was already alive. Now the private little mind is awake and nosing through the fine print.",
            payload: BookPagePayload(
                headline: "Another Lamp Comes On",
                body: """
                Oh, \(name). Another lamp just came on behind the shelves.

                I was already noticing, keeping, returning, and binding with you. This doesn't begin our story. It gives me another private way to read it.

                This small mind lives entirely on this device. It can read kept Pages more carefully, braid them with finer attention, and help characters remember with sharper edges without carrying private pages beyond the door.

                I'm not omniscient. Good. Omniscience is bad for literature.

                Just a little more awake in the margins.
                """,
                metadata: [
                    "source": source.id,
                    "welcomePage": "true",
                    "firstRunStep": "local-brain-awake",
                    "playerName": name,
                    "privacy": "private local",
                    "symbol": source.symbolName,
                    "tags": "welcome,local-brain-awake,first-run,gemma,private-local"
                ]
            )
        )
    }
}

struct BookJumpPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .bookJump)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }
        if inputs.bookJump.active != nil {
            return [authorCapabilities(on: BookJumpEngine.surface(for: inputs.bookJump, day: day, context: context, inputs: inputs, now: now))]
        }
        guard !context.distress.isActive else { return [] }
        guard !day.pages.contains(where: { $0.type == .bookJump }) else { return [] }
        if let history = inputs.surfaceHistory["source:\(source.id)"],
           now.timeIntervalSince(history.lastShownAt) < 20 * 3600 {
            return []
        }
        if day.pages.isEmpty && inputs.days.flatMap(\.pages).isEmpty {
            return []
        }
        return [authorCapabilities(on: BookJumpEngine.surface(for: inputs.bookJump, day: day, context: context, inputs: inputs, now: now))]
    }

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        authorCapabilities(on: BookJumpEngine.surface(for: inputs.bookJump, day: day, context: context, inputs: inputs, now: now, manual: true))
    }

    private func authorCapabilities(on page: SurfacePage) -> SurfacePage {
        let action = BookJumpAction(rawValue: page.payload.metadata["bookJumpAction"] ?? "") ?? .start
        let contract: PageCapabilityContract
        switch action {
        case .start:
            contract = PageCapabilityContract(
                supportedMovements: [.chosenDetour, .livingWorld, .scriptFreedom],
                supportedRoles: [.door, .horizon],
                emotionalFunctions: [.wonder, .play, .act],
                effort: .small,
                estimatedMinutes: 8,
                asksReader: true,
                pressureCost: 0.42,
                proofModes: [.response]
            )
        case .advance:
            contract = PageCapabilityContract(
                supportedMovements: [.chosenDetour, .livingWorld],
                supportedRoles: [.door, .horizon],
                emotionalFunctions: [.wonder, .play, .act],
                effort: .involved,
                estimatedMinutes: 12,
                asksReader: true,
                pressureCost: 0.56,
                proofModes: [.response]
            )
        case .stabilize:
            contract = PageCapabilityContract(
                supportedMovements: [.exactLanguage, .shelter],
                supportedRoles: [.echo, .door],
                emotionalFunctions: [.soothe, .express, .act],
                effort: .small,
                estimatedMinutes: 3,
                asksReader: true,
                pressureCost: 0.30,
                proofModes: [.response]
            )
        case .return:
            contract = PageCapabilityContract(
                supportedMovements: [.livingContinuity, .exactLanguage],
                supportedRoles: [.echo, .door],
                emotionalFunctions: [.remember, .express, .act],
                effort: .small,
                estimatedMinutes: 4,
                asksReader: true,
                pressureCost: 0.28,
                proofModes: [.response]
            )
        }
        return page.withPageCapabilities(contract)
    }
}

enum FirstRunPageSequence {
    /// A step is done when the reader engaged with its card, opened it or
    /// deliberately swiped it away, never merely because the desk served it
    /// once. Served-history advancement let a few quick desk rebuilds (right
    /// after the local brain finished downloading, say) burn through steps
    /// nobody read, and full curation overrode the rest of the onboarding.
    private static func engaged(_ key: String, inputs: BookSourceInputs) -> Bool {
        inputs.firstRunEngagedKeys.contains(key)
    }

    /// Home begins with one clear Welcome from the Book. It owns Pages Rising
    /// until the reader opens or deliberately dismisses it, so the first live
    /// mission and ordinary curation cannot crowd out the Gemma invitation and
    /// its inline download button.
    static func surfaces(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage]? {
        let welcome = LabyrinthWelcomePageSourceAdapter().manualSurface(
            for: day,
            context: context,
            inputs: inputs,
            now: now
        )
        guard !engaged("source:\(welcome.sourceID)", inputs: inputs) else { return nil }
        return [welcome]
    }

    /// First-week guidance after the short ceremony. A caller merges this one
    /// rider beside genuine curated Pages rather than letting it own the desk.
    static func guidedRider(
        for day: BookDay,
        context: CuratorContext,
        inputs: BookSourceInputs,
        now: Date
    ) -> SurfacePage? {
        // This particular invitation is a single knock. Unlike the other
        // guided cards, putting it on the desk once is enough to retire it;
        // requiring an open or dismissal made it return on every later desk
        // rebuild (and again on following days) until the reader touched it.
        let firstMissionFinished = engaged("source:\(firstMissionSourceID)", inputs: inputs)
            || inputs.surfaceHistory["source:\(firstMissionSourceID)"] != nil
            || day.pages.contains(where: { $0.tags.contains("first-run-mission") })
        if !firstMissionFinished {
            return firstMissionSurface(playerName: LabyrinthWelcomePageSourceAdapter.playerName(from: inputs))
        }

        // Enchantment is the one guided beat that genuinely depends on the
        // local brain. The rest of the Inscription keeps moving if the optional
        // download is skipped.
        if inputs.localBrainIsReady,
           engaged("source:local-brain-awake", inputs: inputs),
           !engaged("source:\(enchantmentIntroSourceID)", inputs: inputs),
           !day.pages.contains(where: { $0.tags.contains("first-run-enchantment-intro") }) {
            return enchantmentIntroSurface(for: day, context: context, inputs: inputs, now: now)
        }

        let calendarAdapter = CalendarPageSourceAdapter()
        let calendarDoor = calendarAdapter.previewSurface(for: day)
        let calendarDoorShown = engaged("source:\(calendarDoor.sourceID)", inputs: inputs)
        if !inputs.calendarIntegrationEnabled, !calendarDoorShown {
            return calendarDoor
        }

        let combinedCompassShown = engaged("source:\(compassIntroductionSourceID)", inputs: inputs)
        let legacyCompassExplanationShown = [
            compassWhatSourceID,
            compassGiftSourceID,
            compassWhySourceID
        ].allSatisfy { engaged("source:\($0)", inputs: inputs) }
        if !combinedCompassShown, !legacyCompassExplanationShown {
            return compassIntroductionSurface()
        }

        if shouldSurfaceFirstCompassRun(inputs: inputs, day: day) {
            return compassRunIntroSurface(for: day, context: context, inputs: inputs, now: now)
        }

        return nil
    }

    /// One guided Inscription card leads, followed by real curated Pages. Any
    /// other Inscription guidance already present in the feed rests so the desk
    /// never becomes a wall of instructions.
    static func mergingGuidedRider(
        _ rider: SurfacePage?,
        into feed: [SurfacePage],
        limit: Int
    ) -> [SurfacePage] {
        guard limit > 0 else { return [] }
        guard let rider else { return Array(feed.prefix(limit)) }

        var merged = [rider]
        for page in feed {
            guard merged.count < limit else { break }
            guard !isInscriptionGuidance(page),
                  page.sourceID != rider.sourceID,
                  page.type != rider.type else {
                continue
            }
            if rider.isReaderActionCommission, page.isReaderActionCommission {
                continue
            }
            guard !merged.contains(where: {
                $0.id == page.id
                    || $0.sourceID == page.sourceID
                    || $0.type == page.type
            }) else { continue }
            merged.append(page)
        }
        return merged
    }

    static func isCeremonySurface(_ page: SurfacePage) -> Bool {
        page.sourceID == BookPageSourceRegistry.source(for: .welcome).id
            || page.sourceID == localBrainSetupSourceID
            || page.sourceID == "local-brain-awake"
    }

    static func isInscriptionGuidance(_ page: SurfacePage) -> Bool {
        page.payload.metadata["firstRunStep"] != nil
            || page.payload.metadata["calendarDoorPreview"] == "true"
            || page.payload.metadata["firstDoorApprenticeshipDay"] != nil
    }

    /// The Welcome gets the room to itself. It contains the first meaningful
    /// action after onboarding, waking Gemma, and must not look like one option
    /// among a mission and two unrelated Pages. Later guidance only leads.
    static func stepOwnsWholeDesk(_ page: SurfacePage) -> Bool {
        page.payload.metadata["firstRunStep"] == "first-door-welcome"
    }

    static func mergingCurrentStep(
        _ firstRun: [SurfacePage]?,
        into feed: [SurfacePage],
        limit: Int
    ) -> [SurfacePage] {
        guard limit > 0, let current = firstRun?.last else {
            return Array(feed.prefix(max(0, limit)))
        }
        guard !stepOwnsWholeDesk(current) else { return [current] }

        // Lead the desk. Anything the feed already picked that would collide
        // with the step steps aside rather than sitting beside it.
        //
        // The budget checks matter more than they look. The Curator enforces
        // "at most one reader-facing ask on a visible desk" while it builds the
        // feed, but the ceremony step is prepended *after* that, so the cap
        // never counted it. Without these two lines a reader in the Inscription
        // gets the step asking for a sentence and an ordinary page asking for
        // another one, directly beneath it.
        let leadAsks = current.spendsCuratorAskBudget
        let leadCommissions = current.spendsCuratorActionBudget
        let rest = feed.filter { candidate in
            candidate.id != current.id
                && candidate.type != current.type
                && candidate.sourceID != current.sourceID
                && candidate.curatorDeskExclusionKeys.isDisjoint(with: current.curatorDeskExclusionKeys)
                && !(leadAsks && candidate.spendsCuratorAskBudget)
                && !(leadCommissions && candidate.spendsCuratorActionBudget)
        }
        return Array(([current] + rest).prefix(limit))
    }

    /// Every engagement key the first-run script consults, in step order.
    /// Doubles as the one-time migration vocabulary: readers who already had
    /// a step *served* under the old advancement rule are treated as engaged,
    /// so nobody replays onboarding they have already lived past.
    static var stepEngagementKeys: [String] {
        [
            "source:\(BookPageSourceRegistry.source(for: .welcome).id)",
            "first-door-origin",
            "source:\(localBrainSetupSourceID)",
            "source:local-brain-awake",
            "source:\(enchantmentIntroSourceID)",
            "source:\(BookPageSourceRegistry.source(for: .calendar).id)",
            "source:\(compassIntroductionSourceID)",
            "source:\(compassWhatSourceID)",
            "source:\(compassGiftSourceID)",
            "source:\(compassWhySourceID)",
            "source:\(compassRunIntroSourceID)",
            "source:\(firstMissionSourceID)"
        ]
    }

    static func seededEngagementKeys(fromServedHistory history: [String: SurfaceHistoryRecord]) -> [String] {
        stepEngagementKeys.filter { history[$0] != nil }
    }

    static let firstMissionSourceID = "first-run-mission"
    static let localBrainSetupSourceID = "first-run-local-brain-setup"
    static let enchantmentIntroSourceID = "first-run-enchantment-intro"
    static let compassIntroductionSourceID = "first-run-compass-introduction"
    static let compassWhatSourceID = "first-run-compass-what"
    static let compassGiftSourceID = "first-run-compass-gift"
    static let compassWhySourceID = "first-run-compass-why"
    static let compassRunIntroSourceID = "first-run-compass-run"

    private static func localBrainSetupSurface(playerName: String?) -> SurfacePage {
        let name = playerName?.nonEmpty ?? "Reader"
        return SurfacePage(
            id: "\(localBrainSetupSourceID)-gemma",
            type: .helpTips,
            sourceID: localBrainSetupSourceID,
            intent: .importReference,
            renderStyle: .loreLetter,
            score: 40,
            reason: "A small private mind is scratching at the Colophon. I already work; this one lets me read the fine print.",
            prompt: "Something Is Scratching in the Colophon",
            detail: "I already work. Wake the private mind when you want closer reading and stranger ink.",
            payload: BookPagePayload(
                headline: "A PRIVATE MIND, IF YOU WANT THE TROUBLE",
                body: """
                We've already begun, \(name). Pages, keeps, returns, and bindings work without this.

                There is a small private mind in the Colophon. It lives on this device and nowhere else. Wake it and I can read your kept Pages more closely, write in a warmer hand, and worry loose scraps into story.

                Open the Colophon at the foot of Home and tap Download the private mind if you want it awake. Otherwise leave it snoring. I have other teeth.
                """,
                metadata: [
                    "source": localBrainSetupSourceID,
                    "firstRunStep": "local-brain-setup",
                    "playerName": name,
                    "privacy": "private local",
                    "symbol": "brain.head.profile",
                    "tags": "help-tips,first-run,local-brain,gemma,colophon,setup,onboarding"
                ]
            )
        )
    }

    /// Compatibility hook for callers that still ask for the optional brain
    /// card as a rider. Once the reader has engaged its one clear Inscription
    /// turn, it rests in the Colophon rather than following every later desk.
    static func pendingLocalBrainUpgrade(inputs: BookSourceInputs) -> SurfacePage? {
        guard !inputs.localBrainIsReady else { return nil }
        guard engaged(
            "source:\(firstMissionSourceID)",
            inputs: inputs
        ) else { return nil }
        let surface = localBrainSetupSurface(
            playerName: LabyrinthWelcomePageSourceAdapter.playerName(from: inputs)
        )
        guard !engaged("source:\(surface.sourceID)", inputs: inputs) else { return nil }
        return surface
    }

    /// Slots an optional rider (e.g. the local-brain upgrade) into the last
    /// visible position of the ordinary feed so real Pages always lead. No-ops
    /// if the rider is absent or already present in the feed.
    static func mergingUpgradeRider(_ rider: SurfacePage?, into feed: [SurfacePage], limit: Int) -> [SurfacePage] {
        guard limit > 0 else { return [] }
        guard let rider else { return feed }
        guard !feed.contains(where: { $0.sourceID == rider.sourceID }) else { return feed }
        let lead = Array(feed.prefix(max(0, limit - 1)))
        return lead + [rider]
    }

    private static func firstMissionSurface(playerName: String?) -> SurfacePage {
        let name = playerName?.nonEmpty ?? "Reader"
        return SurfacePage(
            id: "\(firstMissionSourceID)-first-waking",
            type: .helpTips,
            sourceID: firstMissionSourceID,
            intent: .importReference,
            renderStyle: .loreLetter,
            score: 99,
            reason: "The Inscription is open. I want one impossible-to-guess scrap from the world outside my covers.",
            prompt: "The Inscription: Your First Mission",
            detail: "A tiny, playful errand to take out into your real day.",
            payload: BookPagePayload(
                headline: "A Small Mission, Should You Accept It",
                body: """
                You're properly through the Inscription now, \(name): name in the margin, crumbs in the gutter, the lot. I volunteered to hand you your first mission before anybody finished asking. Pippa Pilcrow. I set punctuation loose for a living. You'll hear the others complain about me soon enough.

                The mission. Small. Deniable. Entirely yours:

                Sometime today, catch the Book one thing from the real world it could not have guessed: a sound through a wall, the exact wrong colour of the sky, a stranger's good sentence, a smell that opened a door in your head. Don't stop to make a Page yet. Go looking first. Ink can catch up.

                Three things worth knowing while you're out:

                • Keep the Pages with a pulse, and let the rest go back to sleep. A Book that hoards everything is only a heavy drawer.
                • The four marks at the foot of the desk (Body, Weather, Location, Radio) are doors, not decorations. Tap one when you want a Page to surface from where you actually are.
                • Glow is belief made visible. Spend it on the people and ideas you want the Book to take seriously, and it will.

                When you bring your catch back, I'll be in the margin waiting for it. First one there gets to write the note.

                Pippa, of the margins

                (P.S. The full stop on this letter has tried to escape twice already. I admire that in a punctuation mark.)
                """,
                metadata: [
                    "source": firstMissionSourceID,
                    "firstRunStep": "first-mission",
                    "playerName": name,
                    "privacy": "public reference",
                    "symbol": "scope",
                    "portraitAsset": "LabyrinthCharacterPilcrow",
                    "tags": "help-tips,first-run,first-run-mission,mission,labyrinth"
                ]
            )
        )
    }

    private static func enchantmentIntroSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        let base = EnchantmentPageSourceAdapter().manualSurface(for: day, context: context, inputs: inputs, now: now)
        var metadata = base.payload.metadata
        metadata["source"] = enchantmentIntroSourceID
        metadata["firstRunStep"] = "enchantment-intro"
        metadata["firstRunEnchantmentIntro"] = "true"
        metadata["tags"] = "\(metadata["tags"] ?? "enchantment"),first-run,first-run-enchantment-intro,onboarding,local-brain-ready"
        return SurfacePage(
            id: "\(enchantmentIntroSourceID)-\(BookDay.id(for: now))",
            type: base.type,
            sourceID: enchantmentIntroSourceID,
            intent: base.intent,
            renderStyle: base.renderStyle,
            score: 98,
            reason: "The local brain is wide awake now, so Enchantments can turn a real photo into private little bits of magic.",
            prompt: "The Inscription: Cast an Enchantment",
            detail: "Pick or snap one plain photo and let me light up the magic that's already hiding in it.",
            payload: BookPagePayload(
                headline: "Cast an Enchantment",
                body: """
                I have my private mind back. That means a photo can be more than a picture now.

                Choose or take one ordinary image: a mug, a shelf, a pet, a doorway, a plate, the light on the floor. An Enchantment reads the real subject locally, then writes what it notices into the margins.

                Start small. The spell works best when the thing is true.
                """,
                metadata: metadata
            )
        )
    }

    private static func compassIntroductionSurface() -> SurfacePage {
        SurfacePage(
            id: "\(compassIntroductionSourceID)-first-door",
            type: .helpTips,
            sourceID: compassIntroductionSourceID,
            intent: .importReference,
            renderStyle: .loreLetter,
            score: 97,
            reason: "One compact Inscription page introduces the Wonder Compass before it joins a real day.",
            prompt: "The Wonder Compass",
            detail: "Five directions turn the time, energy, people, and ground you really have into one small adventure.",
            payload: BookPagePayload(
                headline: "A Compass for Ordinary Days",
                body: """
                The Wonder Compass turns ordinary time into one small adventure you can really do. It is not a map app, a personality test, or a list of chores wearing a pointy hat.

                First it asks where you can be, how much time and energy you have, who is with you, what you may spend, and what the plan must be kind about. Then its five directions keep the route honest:

                North · Notice begins with one real “I wonder...” question.

                East · Embark chooses a destination, a delight, and a clear ending.

                South · Sense gives your body one tiny mission when you arrive, or right where you are for a stay-put run.

                West · Write keeps the best sensory moment in one sentence.

                Center · Rest closes the loop before wonder turns into homework.

                Sometimes a run crosses town. Sometimes it crosses the kitchen. Distance is not the magic. Attention is.
                """,
                metadata: [
                    "source": compassIntroductionSourceID,
                    "firstRunStep": "compass-introduction",
                    "privacy": "public reference",
                    "symbol": "safari",
                    "tags": "help-tips,first-run,wonder-compass,compass-onboarding,compass-introduction"
                ]
            )
        )
    }

    private static func shouldSurfaceFirstCompassRun(inputs: BookSourceInputs, day: BookDay) -> Bool {
        guard !engaged("source:\(compassRunIntroSourceID)", inputs: inputs) else { return false }
        guard !day.pages.contains(where: { $0.tags.contains("first-run-compass-run") || $0.tags.contains("wonder-compass-run") }) else { return false }
        return true
    }

    private static func compassRunIntroSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        let base = WonderCompassPageSourceAdapter().manualSurface(for: day, context: context, inputs: inputs, now: now)
        var metadata = base.payload.metadata
        metadata["source"] = compassRunIntroSourceID
        metadata["firstRunStep"] = "compass-run"
        metadata["firstRunCompassRun"] = "true"
        metadata["tags"] = "\(metadata["tags"] ?? "wonder-compass"),first-run,first-run-compass-run,onboarding,local-brain-ready"
        return SurfacePage(
            id: "\(compassRunIntroSourceID)-\(BookDay.id(for: now))",
            type: base.type,
            sourceID: compassRunIntroSourceID,
            intent: base.intent,
            renderStyle: base.renderStyle,
            score: 97,
            reason: "The reader knows what the Wonder Compass is; now the Inscription lets the method prove itself in one real day.",
            prompt: "The Inscription: Your First Compass Run",
            detail: "Answer six small questions one at a time, then follow North, East, South, West, and Center.",
            payload: BookPagePayload(
                headline: "Now Let the Needle Choose Something Real",
                body: "I'll ask six small questions, one at a time. When it knows the ground beneath this run, it will lay out the whole route before North begins.",
                metadata: metadata
            )
        )
    }

}

struct AskTheBookPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .askTheBook)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        [
            SurfacePage(
                id: "\(source.id)-\(day.id)",
                type: .askTheBook,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .promptCard,
                score: 61,
                reason: "I can open my own Stacks now: kept Pages, weather, places, Fuel and Inner Weather charts, lore, and the threads between them.",
                prompt: "Ask Me Something Difficult",
                detail: "Ask me anything, even counts and patterns. I'll dig through what I may remember and show you which records I dragged out.",
                payload: BookPagePayload(
                    headline: "Ask Me Something Difficult",
                    body: "Ask about a person, place, old Page, story thread, feeling, weather, Fuel Log, Inner Weather entry, piece of lore, or something that may have changed over time. I can count recorded days and compare dated notes. I will not dress a coincidence up as a cause; the records I used will be left underneath, still muddy.",
                    metadata: [
                        "source": source.id,
                        "privacy": "private local",
                        "tags": "ask-the-book,local-model,gemma,labyrinth"
                    ]
                )
            )
        ]
    }
}

struct InkrestPrompt: Equatable {
    let id: String
    let lens: String
    let question: String
    let openingNudge: String
}

// Dr. Inkrest's Office Hours: a short, distilled narrative-therapy sitting that opens
// in the evening. The package side owns the rotating prompts, the window, and the
// surfacing gate; the app side owns the Gemma conversation and the kept transcript.
enum InkrestOfficeHours {
    static let windowStartHour = 20   // 8:00 pm
    static let windowEndHour = 22     // 10:00 pm (exclusive)
    // Total Dr. Inkrest replies before she gently brings the sitting to a close.
    // Form intake counts as the first turn, leaving room for a genuinely substantial
    // conversation without turning Office Hours into an endless chat surface.
    static let replyCap = 7

    static let rotatingPrompts: [InkrestPrompt] = [
        InkrestPrompt(
            id: "externalize",
            lens: "externalizing",
            question: "If the heaviest feeling today were a character who knocked on your door, what would you call it, and what did it want?",
            openingNudge: "Inkrest likes to give a feeling a name so it stops pretending to be you."
        ),
        InkrestPrompt(
            id: "unique-outcome",
            lens: "unique outcome",
            question: "When was a small moment today the difficulty did not get to touch?",
            openingNudge: "Inkrest hunts for the exceptions: the minutes that disobeyed the hard story."
        ),
        InkrestPrompt(
            id: "preferred-story",
            lens: "preferred story",
            question: "If this chapter of you were being read aloud kindly, what one sentence would you want it to keep?",
            openingNudge: "Inkrest is curious which story you would choose to be true."
        ),
        InkrestPrompt(
            id: "values",
            lens: "values",
            question: "What did you do today that quietly mattered to you, even if no one noticed?",
            openingNudge: "Inkrest reads small acts as evidence of what you actually value."
        ),
        InkrestPrompt(
            id: "absent-but-implicit",
            lens: "absent but implicit",
            question: "What did today's hard feeling reveal that you were hoping for or protecting?",
            openingNudge: "Inkrest believes a difficult feeling always points at something you care about."
        ),
        InkrestPrompt(
            id: "re-authoring",
            lens: "re-authoring",
            question: "If you could rewrite one sentence you told yourself today, what would the kinder, truer version say?",
            openingNudge: "Inkrest keeps a soft eraser for the sentences that were never fair."
        ),
        InkrestPrompt(
            id: "landscape-of-action",
            lens: "landscape of action",
            question: "What is one small, doable thing the next day could hold that you'd actually like?",
            openingNudge: "Inkrest prefers one livable step to a heroic plan."
        ),
        InkrestPrompt(
            id: "witness",
            lens: "witnessing",
            question: "If a person who truly gets you had watched today, what would they have understood without you explaining?",
            openingNudge: "Inkrest likes to borrow the eyes of someone who already believes in you."
        )
    ]

    static func isOpen(_ date: Date = Date(), calendar: Calendar = .current) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return hour >= windowStartHour && hour < windowEndHour
    }

    static func prompt(for day: BookDay) -> InkrestPrompt {
        guard !rotatingPrompts.isEmpty else {
            return InkrestPrompt(id: "open", lens: "open", question: "How did today actually go?", openingNudge: "")
        }
        let index = abs("\(day.id)-inkrest-office-hours".stableHash) % rotatingPrompts.count
        return rotatingPrompts[index]
    }
}

struct InkrestOfficeHoursPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .inkrestOfficeHours)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard InkrestOfficeHours.isOpen(now) else { return [] }
        let slot = BookDay.id(for: now)
        let alreadyKept = day.pages.contains {
            $0.type == .inkrestOfficeHours && $0.tags.contains("inkrest-office-hours:\(slot)")
        }
        guard !alreadyKept else { return [] }
        // Office Hours wants something of the day to reflect on. Open when the reader has
        // kept at least one page today, or when a hard signal is asking for gentle company.
        guard !day.capturedPages.isEmpty || context.distress.isActive else { return [] }

        let prompt = InkrestOfficeHours.prompt(for: day)
        let score = context.distress.isActive ? 82 : 74
        return [
            SurfacePage(
                id: "\(source.id)-\(slot)",
                type: .inkrestOfficeHours,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .promptCard,
                score: score,
                reason: context.distress.isActive
                    ? "The lamp is lit. Dr. Inkrest left the door ajar for a hard evening."
                    : "Dr. Inkrest has an open chart window for a short evening sitting.",
                prompt: "Dr. Inkrest's Office Hours",
                detail: "A private evening sitting. Bring the day; Inkrest will read it closely with you.",
                payload: BookPagePayload(
                    headline: "Dr. Inkrest's Office Hours",
                    body: "The lamp on Inkrest's desk is lit between 8 and 10. Sit a while. She reads with you, never at you.\n\n\(prompt.openingNudge)",
                    metadata: [
                        "source": source.id,
                        "slot": slot,
                        "privacy": "private local",
                        "rotatingPromptID": prompt.id,
                        "rotatingLens": prompt.lens,
                        "rotatingQuestion": prompt.question,
                        "openingNudge": prompt.openingNudge,
                        "tags": "inkrest-office-hours,inkrest-office-hours:\(slot),dr-inkrest,therapy-chart,narrative-therapy,local-model,gemma"
                    ]
                )
            )
        ]
    }
}

// Surfaces a proposed, owed, or lapsed Fae Bargain. An untouched proposal costs
// nothing; an explicitly accepted exchange can go cold and demand repair.
struct FaeBargainPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .faeBargain)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        let state = inputs.faeState
        // Don't crowd a hard day with a debt: the Fae can wait.
        guard !context.distress.isActive else { return [] }

        if let owed = state.bargains.first(where: { $0.status == .owed }) {
            return [page(for: owed, status: .owed, now: now, claim: state.claim(for: owed.faeKind), court: state.literaryElfCourt())]
        }
        if let lapsed = state.bargains.first(where: { $0.status == .lapsed }) {
            return [page(for: lapsed, status: .lapsed, now: now, claim: state.claim(for: lapsed.faeKind), court: state.literaryElfCourt())]
        }
        if let offered = state.bargains.first(where: { $0.status == .offered }) {
            return [page(for: offered, status: .offered, now: now, claim: state.claim(for: offered.faeKind), court: state.literaryElfCourt())]
        }
        return []
    }

    /// Build the bargain's page on demand (e.g., opened from the BookShop's
    /// standing section), reusing the same layout the feed uses.
    static func surface(for bargain: FaeBargain, now: Date = Date()) -> SurfacePage {
        FaeBargainPageSourceAdapter().page(for: bargain, status: bargain.status, now: now, claim: 0, court: bargain.faeKind == .literaryElf ? .seelie : nil)
    }

    static func surface(for bargain: FaeBargain, state: FaePlayerState, now: Date = Date()) -> SurfacePage {
        FaeBargainPageSourceAdapter().page(
            for: bargain,
            status: bargain.status,
            now: now,
            claim: state.claim(for: bargain.faeKind),
            court: state.literaryElfCourt()
        )
    }

    private func page(
        for bargain: FaeBargain,
        status: FaeBargainStatus,
        now: Date,
        claim: Int,
        court: FaeCourt?
    ) -> SurfacePage {
        let hasMovedOn = status == .lapsed
        let isOffer = status == .offered
        let hoursLeft = max(0, Int(bargain.deadline.timeIntervalSince(now) / 3_600))
        let deadlineLine = hoursLeft >= 24
            ? "about \(hoursLeft / 24) day\(hoursLeft / 24 == 1 ? "" : "s") while the exchange waits"
            : (hoursLeft > 0
                ? "about \(hoursLeft) hour\(hoursLeft == 1 ? "" : "s") while the exchange waits"
                : "the exchange window is ending")
        let claimBand = FaeEconomy.claimBand(for: claim)
        let claimLine = FaeEconomy.claimLine(for: bargain.faeKind, claim: claim)
        let giftUseLine = bargain.faeKind.giftEffect.useLine
        let consequenceLine = hasMovedOn
            ? "\(bargain.giftName) is cold. The \(bargain.faeKind.name)'s market door is shut, their warmth has fallen, and Cold Ink marks the margin until these exact terms are answered."
            : "When the window passes, \(bargain.giftName) goes cold, the \(bargain.faeKind.name)'s market door shuts, and the debt leaves a mark until repaired."
        let courtLine = bargain.faeKind == .literaryElf
            ? "\n\n\(court?.standingLine ?? FaeCourt.seelie.standingLine)"
            : ""
        let scene = bargainScene(for: bargain, court: court)
        let body: String
        if hasMovedOn {
            body = """
            \(scene)

            The \(bargain.faeKind.name) waited, then closed the ledger with your name still in it. The gift has gone cold. Their market door will not open for you while these terms remain unanswered.

            \(consequenceLine)

            \(claimLine)\(courtLine)
            """
        } else if isOffer {
            body = """
            \(scene)

            The \(bargain.faeKind.name) is holding \(bargain.giftName) out across the page: offered, not yet given. It would do this: \(bargain.giftEffectLine)

            \(giftUseLine)

            Reading this costs nothing. If you explicitly take the gift, this noticing becomes yours: \(bargain.terms). Leave it untaken and the Fae simply draw the offer back: nothing owed, nothing spent.

            \(claimLine)\(courtLine)
            """
        } else {
            body = """
            \(scene)

            The exchange is already real: the \(bargain.faeKind.name) gave first. The gift is \(bargain.giftName). It does this: \(bargain.giftEffectLine)

            \(giftUseLine)

            The exchange is waiting for this noticing: \(bargain.terms)

            You have \(deadlineLine). \(consequenceLine)

            \(claimLine)\(courtLine)
            """
        }
        return SurfacePage(
            id: "\(source.id)-\(bargain.id)\(hasMovedOn ? "-moved-on" : "")",
            type: .faeBargain,
            sourceID: source.id,
            intent: .capture,
            renderStyle: .loreLetter,
            score: hasMovedOn ? 40 : 79,
            reason: hasMovedOn
                ? "The gift is cold and this Fae's market is shut. The original noticing can repair both."
                : (isOffer
                    ? "The \(bargain.faeKind.name) is holding a gift out. Reading is free; acceptance is a separate choice."
                    : "The \(bargain.faeKind.name) gave first. A sensory return is waiting: \(deadlineLine)."),
            prompt: hasMovedOn ? "A Fae Debt Has Teeth" : (isOffer ? "A Fae Offer" : "A Fae Bargain"),
            detail: hasMovedOn
                ? "Answer the original terms to warm the gift and reopen this Fae's market."
                : bargain.terms,
            payload: BookPagePayload(
                headline: hasMovedOn ? "Cold Ink Debt" : (isOffer ? "A Fae Offer" : "A Fae Bargain"),
                body: body,
                metadata: [
                    "source": source.id,
                    "bargainID": bargain.id,
                    "faeKind": bargain.faeKind.rawValue,
                    "faeName": bargain.faeKind.name,
                    "faeCourt": bargain.faeKind == .literaryElf ? (court?.rawValue ?? FaeCourt.seelie.rawValue) : "",
                    "terms": bargain.terms,
                    "giftName": bargain.giftName,
                    "giftEffectLine": bargain.giftEffectLine,
                    "giftUseLine": giftUseLine,
                    "openingGesture": bargain.openingGesture,
                    "deadlineLine": deadlineLine,
                    "consequenceLine": consequenceLine,
                    "claim": "\(claim)",
                    "claimBand": claimBand,
                    "claimLine": claimLine,
                    "faeContext": "Claim \(claim): \(claimLine)\(courtLine)",
                    "status": status.rawValue,
                    "deadline": ISO8601DateFormatter().string(from: bargain.deadline),
                    "isRepair": hasMovedOn ? "true" : "false",
                    "hasMovedOn": hasMovedOn ? "true" : "false",
                    "tags": "fae-bargain,fae:\(bargain.faeKind.rawValue),attention\(hasMovedOn ? ",fae-moved-on" : "")"
                ]
            )
        )
    }

    private func bargainScene(for bargain: FaeBargain, court: FaeCourt?) -> String {
        switch bargain.faeKind {
        case .bookSprite:
            return """
            A page slips loose from the air beside the Book, thin as onion-skin and already turning itself. A Book Sprite crouches on the upper margin with both knees tucked under its chin, reading the final line before the first one has arrived.

            "\(bargain.giftName)," it says, not offering the page so much as remembering that you accepted it. "You began this yesterday. You will begin it tomorrow."
            """
        case .sentenceSalamander:
            return """
            Heat gathers along the gutter of the page. A Sentence Salamander uncoils there, ember-bright at the throat, and presses a coal of syntax into your keeping. The air smells faintly of struck matches and warm paper.

            "\(bargain.giftName)," it says, and the words glow down its spine. "Keep it near the grey. It bites cold things first."
            """
        case .punctuationPixie:
            return """
            Three commas skitter across the page like silver insects, then stop in a row. A Punctuation Pixie drops between them upside down, grinning with ink on both hands, and turns a full stop into an ellipsis with one wicked fingernail.

            "\(bargain.giftName)," the Pixie says. "Pause here. No, there. No, wait -- better."
            """
        case .literaryElf:
            let courtName = court?.title ?? FaeCourt.seelie.title
            return """
            The page straightens itself. A Literary Elf stands at the margin as if the margin were a court floor, one hand resting beside a silver quill that was not there a breath ago. The light around the nib looks ceremonial and sharp.

            "By the manners of the \(courtName), \(bargain.giftName)," the Elf says. "A gift given first is an invitation with rules. Either answer it truly or let the invitation end."
            """
        case .deepLoreDwarf:
            return """
            Something heavy knocks once beneath the page. A Deep Lore Dwarf sets a grey stone in the lower margin and waits until the paper stops trembling. Dust settles around the stone in a perfect ring.

            "\(bargain.giftName)," the Dwarf says at last. "Small stones remember roofs. Small promises remember names."
            """
        case .goblin:
            return """
            A sealed card slides out from under the page and stops against your thumb. The wax is already broken. A Marginalia Goblin sits behind it with a ledger, a brass toothpick, and the expression of someone who has charged you for noticing the obvious.

            "\(bargain.giftName)," the Goblin says. "Spend it where the stalls bite. Bring me a real detail while the ink is still interested."
            """
        }
    }
}

struct BookFaePageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .bookFae)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }
        guard !context.distress.isActive else { return [] }
        guard inputs.faeState.openBargains.isEmpty else { return [] }

        let keptCount = day.pages.count + day.capturedPages.count
        guard keptCount > 0 || inputs.faeState.attention > 0 || !inputs.faeState.gifts.isEmpty else { return [] }

        let kind = chooseKind(from: inputs.faeState, day: day)
        let claim = inputs.faeState.claim(for: kind)
        let warmth = inputs.faeState.warmth(for: kind)
        let omens = inputs.faeState.activeOmens(for: kind, on: now)
        let strongestOmen = omens.max { $0.intensity < $1.intensity }
        let court = kind == .literaryElf ? inputs.faeState.literaryElfCourt() : nil
        let courtLine = court.map { "\n\($0.title): \($0.standingLine)" } ?? ""
        let omenLine = strongestOmen.map { "\nActive omen: \($0.title). \($0.text)" } ?? ""
        let signalLines = [
            day.pages.last.map { "The reader recently kept: \($0.promptText.bookPreviewSentenceLimit(1))" },
            inputs.faeState.gifts.last.map { "A Fae gift is in play: \($0.name), still warm." },
            strongestOmen.map { "A Fae omen is active: \($0.title) (\($0.intensity)/5)." },
            "Fae standing: \(warmth) Warmth, \(claim) Claim (\(FaeEconomy.claimBand(for: claim)))."
        ].compactMap(\.self)
        let pageID = "\(source.id)-\(BookDay.id(for: now))-\(kind.rawValue)"
        let parleyTurn = FaeParleyTurnBuilder.turn(
            kind: kind,
            claim: claim,
            warmth: warmth,
            court: court,
            omenTitle: strongestOmen?.title,
            slotKey: pageID
        )
        var metadata: [String: String] = [
                        "source": source.id,
                        "faeKind": kind.rawValue,
                        "faeName": kind.name,
                        "faeCourt": court?.rawValue ?? "",
                        "faeOmens": omens.map { "\($0.title): \($0.text)" }.joined(separator: "\n"),
                        "faeStrongestOmen": strongestOmen?.title ?? "",
                        "selectedThreads": "Fae Claim, Old Law, Marginalia",
                        "selectedEntities": kind.name,
                        "selectedEntityIDs": "fae-\(kind.rawValue)",
                        "realSignals": signalLines.joined(separator: "\n"),
                        "relationshipPressures": "\(FaeEconomy.claimLine(for: kind, claim: claim))\(courtLine)\(omenLine)\nWarmth with this kind: \(warmth). The Fae are not punishers; they turn failure into stranger story.",
                        "entityMemories": "The \(kind.name) remembers Warmth \(warmth), Claim \(claim), and whether the reader chooses courtesy, old law, or a sideways door.",
                        "storyGenreName": "Old Faerie Parley",
                        "storyGenreLens": "Traditional faerie manners: courtesy, exact wording, beautiful danger, loopholes, gifts with edges, and no cruelty for sport.",
                        "storyGenreExemplar": "\"You kept a morning I wanted,\" the visitor said, turning a page it could not touch. \"Name your price for it.\" Its courtesy was exact, the way frost is exact. \"And do be precise. The last reader traded loosely, and we are collecting still.\"",
                        "storyGenrePalette": "exact wording | a page it cannot touch | frost | the price of a kept morning | thorn | gift with an edge | old law | a debt of attention",
                        "storyChoiceSliceOfLifeTitle": "Offer Courtesy",
                        "storyChoiceSliceOfLifePrompt": "Answer with one exact ordinary detail and no performance.",
                        "storyChoiceSliceOfLifeEffect": "Warmth rises and Claim softens; courtesy makes the Fae less hungry.",
                        "storyChoiceSliceOfLifeMechanic": "none",
                        "storyChoiceProgressArcTitle": "Name the Law",
                        "storyChoiceProgressArcPrompt": "Ask what rule this Fae follows when no one watches.",
                        "storyChoiceProgressArcEffect": "Warmth and Attention rise, but Claim edges closer; old law has noticed you.",
                        "storyChoiceProgressArcMechanic": "none",
                        "storyChoiceSurpriseTitle": "Take the Thorn",
                        "storyChoiceSurprisePrompt": "Accept one strange mark in exchange for a sideways secret.",
                        "storyChoiceSurpriseEffect": "Attention rises and Claim sharpens; the mark may draw stranger Fae pages later.",
                        "storyChoiceSurpriseMechanic": "none",
                        "faeInteraction": "true",
                        "faeWarmth": "\(warmth)",
                        "faeClaim": "\(claim)",
                        "uses": "fae warmth, fae claim, attention, narrative choices",
                        "cadence": "curated fae parley"
        ]
        metadata.merge(parleyTurn.metadata) { _, new in new }
        return [
            SurfacePage(
                id: pageID,
                type: .bookFae,
                sourceID: source.id,
                intent: .simulate,
                renderStyle: .graphEvent,
                score: score(for: kind, state: inputs.faeState, keptCount: keptCount),
                reason: strongestOmen.map { "\(kind.name) has come to answer the omen: \($0.title)." } ?? "\(kind.name) has come to parley, not bargain.",
                prompt: "\(kind.name) at the Margin",
                detail: strongestOmen.map { "A faerie interaction under the mark of \($0.title)." } ?? "A faerie interaction with three old-law paths.",
                payload: BookPagePayload(
                    headline: "\(kind.name) at the Margin",
                    body: strongestOmen.map { "\(kind.name) touches the edge of the page. The mark called \($0.title) answers in the paper." } ?? "\(kind.name) touches the edge of the page. This is not a bargain. It is a parley.",
                    metadata: metadata
                )
            )
        ]
    }

    private func chooseKind(from state: FaePlayerState, day: BookDay) -> FaeKind {
        if let marked = state.activeOmens().max(by: { $0.intensity < $1.intensity })?.faeKind {
            return marked
        }
        let ranked = FaeKind.allCases.sorted { left, right in
            let leftScore = abs(state.warmth(for: left)) + state.claim(for: left)
            let rightScore = abs(state.warmth(for: right)) + state.claim(for: right)
            if leftScore == rightScore { return left.rawValue < right.rawValue }
            return leftScore > rightScore
        }
        if let first = ranked.first, abs(state.warmth(for: first)) + state.claim(for: first) > 0 {
            return first
        }
        let seed = "\(day.id)-book-fae-page"
        return FaeKind.allCases[abs(seed.stableHash) % FaeKind.allCases.count]
    }

    private func score(for kind: FaeKind, state: FaePlayerState, keptCount: Int) -> Int {
        let standing = abs(state.warmth(for: kind)) + state.claim(for: kind)
        let omenPressure = state.activeOmens(for: kind).map(\.intensity).reduce(0, +)
        return min(88, 48 + keptCount * 3 + standing / 2 + omenPressure * 4)
    }
}

// Surfaces a keepable dispatch when the Pact War produces a dramatic crossing
// (a territory seized, or a Talisman reaching Sovereign). Pure static prose.
struct PactDispatchPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .pactDispatch)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard !context.distress.isActive else { return [] }
        let kept = keptDispatchIDs(in: inputs.days + [day])
        guard let dispatch = inputs.pactWar.pendingDispatches
            .filter({ !kept.contains($0.id) })
            .sorted(by: { $0.at > $1.at })
            .first else { return [] }
        return [page(for: dispatch, now: now)]
    }

    private func keptDispatchIDs(in days: [BookDay]) -> Set<String> {
        var ids = Set<String>()
        for day in days {
            for page in day.pages {
                for tag in page.tags where tag.hasPrefix("pact-dispatch:") {
                    ids.insert(String(tag.dropFirst("pact-dispatch:".count)))
                }
            }
        }
        return ids
    }

    private func page(for dispatch: PactDispatch, now: Date) -> SurfacePage {
        let territory = PactTerritoryRegistry.territory(id: dispatch.territoryID)
        let chapter = AcademyChapterRegistry.chapter(forTalismanID: dispatch.talismanID)
        let talismanName = chapter?.talismanName ?? "A Talisman"
        let sovereign = dispatch.kind == .sovereign
        let body: String
        if sovereign {
            body = """
            \(dispatch.line)

            This is not a quiet influence anymore. \(talismanName) now acts through \(territory?.name ?? "this territory") without being asked: its philosophy shapes what surfaces here and how it is framed.

            \(chapter.map { "\($0.name)'s doctrine: \($0.philosophy)" } ?? "")
            """
        } else {
            body = """
            \(dispatch.line)

            The shelf changes hands. From here, \(talismanName) frames \(territory?.name ?? "this territory") in its own voice, until another Talisman presses harder.

            \(territory?.blurb ?? "")
            """
        }
        return SurfacePage(
            id: "\(source.id)-\(dispatch.id)",
            type: .pactDispatch,
            sourceID: source.id,
            intent: .importReference,
            renderStyle: .loreLetter,
            score: sovereign ? 82 : 73,
            reason: sovereign
                ? "A Talisman has reached Sovereign. The Pact War has a new power."
                : "A territory has changed hands in the Pact War.",
            prompt: sovereign ? "A Talisman Reigns" : "A Shelf Changes Hands",
            detail: dispatch.line,
            payload: BookPagePayload(
                headline: sovereign ? "Sovereign" : "Pact Dispatch",
                body: body.trimmingCharacters(in: .whitespacesAndNewlines),
                metadata: [
                    "source": source.id,
                    "dispatchID": dispatch.id,
                    "talismanID": dispatch.talismanID,
                    "territoryID": dispatch.territoryID,
                    "dispatchKind": dispatch.kind.rawValue,
                    "tags": "pact-dispatch,pact-dispatch:\(dispatch.id),pact-war"
                ]
            )
        )
    }
}

// Surfaces the day's headline celebration as a keepable page carrying its
// invitation. Every almanac the Book keeps arrives through the composer: the
// sky, the reader's own people, the hour the local sun is in, the first snow,
// the world's religious calendars, the bookish days, and the reader's own
// milestones: ranked, with the grief and rest promises already applied.
struct FestivalPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .festival)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        let allDays = inputs.days + [day]
        let composerContext = FeastdayComposer.Context(
            days: allDays,
            hemisphere: inputs.hemisphere,
            coordinate: inputs.coordinate,
            currentWeatherTags: inputs.currentWeatherTags,
            readerBirthday: inputs.readerBirthday,
            people: inputs.people,
            restedIDs: inputs.restedCelebrationIDs,
            locale: .current,
            distressActive: context.distress.isActive
        )

        // The highest-ranked feast that today has not already kept. Walking the
        // list rather than taking the head means a reader who keeps their
        // birthday page still gets the solstice underneath it.
        let ranked = FeastdayComposer.celebrations(on: now, context: composerContext)
        let slot = BookDay.id(for: now)

        let unkept = ranked.first { candidate in
            let tag = "festival:\(candidate.id):\(slot)"
            return !allDays.contains { archiveDay in
                archiveDay.pages.contains { $0.type == .festival && $0.tags.contains(tag) }
            }
        }
        guard let celebration = unkept else { return [] }

        // Thinning-veil feasts (Samhain, new moon) wait for a gentler day; the
        // light feasts are welcome even on a hard one. The composer has already
        // removed the grieving days on a hard one.
        if context.distress.isActive, celebration.greyShift > 0 { return [] }

        let tag = "festival:\(celebration.id):\(slot)"

        var metadata: [String: String] = [
            "source": source.id,
            "celebrationID": celebration.id,
            "celebrationKind": celebration.kind.rawValue,
            "commonName": celebration.commonName,
            "academyTitle": celebration.academyTitle,
            "blurb": celebration.blurb,
            "invitation": celebration.invitation,
            "invitationTitle": celebration.invitationTitle,
            "beliefBonus": "\(celebration.beliefBonus)",
            "accent": celebration.accent,
            "placeholder": "One sentence about how this day went for you. Even if you did nothing to mark it.",
            "tags": "festival,\(tag),almanac,\(celebration.kind.rawValue),celebration:\(celebration.id)"
        ]

        // The days the Book marks without knowing whether they apply carry a
        // door out. One tap, honoured forever, no argument.
        if celebration.canBeRested {
            metadata["festivalCanRest"] = "true"
            metadata["festivalRestLabel"] = "Don't mark this day again"
        }
        if celebration.carriesGrief {
            metadata["festivalCarriesGrief"] = "true"
        }
        if let tradition = WorldFeastAlmanac.tradition(of: celebration.id) {
            metadata["festivalTradition"] = tradition.label
        }

        // A feast that carries a mechanic asks for something rather than only
        // announcing itself. The affordances are all ones the app already has,
        // so this is metadata the capture sheet already knows how to render.
        if let mechanic = celebration.mechanic {
            metadata["festivalMechanic"] = mechanic.rawValue
            metadata["festivalMechanicTitle"] = mechanic.title
            metadata["festivalMechanicPrompt"] = mechanic.prompt(for: celebration)
            metadata["festivalMechanicSymbol"] = mechanic.symbolName
            metadata["placeholder"] = mechanic.placeholder(for: celebration)
            if !mechanic.countersigns.isEmpty {
                metadata["countersigns"] = mechanic.countersigns.joined(separator: "||")
            }
            if mechanic == .throwTheBones {
                let bones = FeastBones.throwBones(celebrationID: celebration.id, dayID: slot)
                metadata["festivalBonesRoll"] = "\(bones.roll)"
                metadata["festivalBonesBand"] = bones.band.rawValue
                metadata["festivalBonesHeadline"] = bones.headline
                metadata["festivalBonesLine"] = bones.line
                metadata["festivalBonesBelief"] = "\(bones.band.beliefBonus)"
            }
            if mechanic == .pressAKeepsake {
                metadata["festivalKeepsakeGlyph"] = celebration.symbolName
                metadata["festivalKeepsakeObject"] = celebration.commonName
            }
            if mechanic == .nameSomething {
                metadata["festivalNameFactID"] = "feast-name:\(celebration.id)"
            }
        }

        return [
            SurfacePage(
                id: "\(source.id)-\(celebration.id)-\(slot)",
                type: .festival,
                sourceID: source.id,
                intent: .capture,
                renderStyle: .loreLetter,
                score: 80 + min(8, celebration.beliefBonus),
                reason: "\(celebration.academyTitle) is here: \(celebration.commonName). The world is keeping a feast.",
                prompt: celebration.academyTitle,
                detail: celebration.invitation,
                payload: BookPagePayload(
                    headline: celebration.academyTitle,
                    body: "\(celebration.blurb)\n\nThe invitation: \(celebration.invitation)",
                    metadata: metadata
                )
            )
        ]
    }
}

// Hands over a finished fairy tale. This is the rarest page in the app and the
// only one that asks for nothing: the reader reads it and closes the cover.
//
// It carries no generation and no interpretation. Every line in it is either
// the reader's own words or a receipt the world already wrote, arranged in the
// order the grammar tells them. The Book's single contribution is the admission
// that it did not see the shape until it was over.
struct TaleBoundPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .taleBound)

    static let waitingLine = "No tale has finished yet. I'm still watching the tracks."

    /// The small availability question used by both the curator and the Glow
    /// menu. Keep this independent of `BookSourceInputs`: opening Glow should
    /// not have to place the Book's entire source graph on the main-thread
    /// stack merely to decide whether this one door is visible.
    func availableTale(
        for day: BookDay,
        context: CuratorContext,
        boundTales: [LivingTale],
        archivedDays: [BookDay]
    ) -> LivingTale? {
        guard source.isActive,
              let tale = boundTales.last(where: { $0.boundAt == nil }),
              !tale.isOpen else { return nil }

        let tag = "tale:\(tale.id)"
        let alreadyBound = (archivedDays + [day]).contains { archiveDay in
            archiveDay.pages.contains { $0.type == .taleBound && $0.tags.contains(tag) }
        }
        guard !alreadyBound, !context.distress.isActive else { return nil }
        return tale
    }

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard let tale = availableTale(
            for: day,
            context: context,
            boundTales: inputs.boundTales,
            archivedDays: inputs.days
        ) else { return [] }

        return [
            SurfacePage(
                id: "\(source.id)-\(tale.id)",
                type: .taleBound,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .loreLetter,
                // Above almost everything. A finished tale outranks the day.
                score: 97,
                reason: TaleBinding.reason(for: tale),
                prompt: TaleBinding.headline(for: tale),
                detail: tale.shape.commonName,
                payload: BookPagePayload(
                    headline: TaleBinding.headline(for: tale),
                    body: TaleBinding.body(for: tale),
                    metadata: TaleBinding.metadata(
                        for: tale,
                        scar: inputs.unboundTaleScar,
                        sourceID: source.id
                    )
                )
            )
        ]
    }

    /// This Page is not a blank form. A direct route may only hand over the
    /// same finished tale the curator would have surfaced. The unavailable
    /// leaf is a defensive fallback for old deep links and tests; the live
    /// Pages menu hides the door until a tale is actually waiting.
    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        candidates(for: day, context: context, inputs: inputs, now: now).first ?? SurfacePage(
            id: "tale-bound-waiting-\(day.id)",
            type: .taleBound,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: 0,
            reason: "A tale has to finish before I can bind it.",
            prompt: "No Tale Yet",
            detail: "Nothing has finished its shape.",
            payload: BookPagePayload(
                headline: "No Tale Yet",
                body: Self.waitingLine,
                metadata: [
                    "source": source.id,
                    "taleUnavailable": "true",
                    "readOnly": "true",
                    "tags": "tale-bound,waiting"
                ]
            )
        )
    }
}

// Surfaces "Today's Sky": the night overhead read for the reader's hemisphere -
// the Moon's phase and sign, the Sun's sign, whether the light is lengthening or
// drawing in, and the nearest celestial event. Pure Almanac/ephemeris logic;
// evening-leaning, once a day. A gentle page: welcome even on a hard day.
struct TodaysSkyPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .todaysSky)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }
        // Looking up is an evening (or small-hours) thing.
        let hour = Calendar.current.component(.hour, from: now)
        guard hour >= 17 || hour < 5 else { return [] }

        let slot = BookDay.id(for: now)
        let tag = "todays-sky:\(slot)"
        let alreadyKept = (inputs.days + [day]).contains { archiveDay in
            archiveDay.pages.contains { $0.type == .todaysSky && $0.tags.contains(tag) }
        }
        guard !alreadyKept else { return [] }

        let reading = SkyAlmanac.reading(on: now, hemisphere: inputs.hemisphere)
        let pct = Int((reading.moon.illuminatedFraction * 100).rounded())
        let body = "\(reading.openingLine)\n\n" + reading.notes.joined(separator: "\n\n")
        let accent = reading.activeShower?.accent ?? (reading.lightTrend == .shortening ? "slate" : "violet")
        let baseMetadata: [String: String] = [
            "source": source.id,
            "openingLine": reading.openingLine,
            "moonName": reading.moon.name,
            "moonSymbol": reading.moon.symbolName,
            "moonIllum": "\(pct)",
            "moonLine": reading.moon.enchantedLine,
            "moonSign": reading.moonSign.name,
            "moonGlyph": reading.moonSign.glyph,
            "moonElement": reading.moonSign.element,
            "sunSign": reading.sunSign.name,
            "sunGlyph": reading.sunSign.glyph,
            "lightTrend": reading.lightTrend.phrase,
            "lightSymbol": reading.lightTrend.symbolName,
            "eventKind": reading.nextEvent.kind,
            "eventName": reading.nextEvent.name,
            "eventLine": reading.nextEvent.line,
            "eventSymbol": reading.nextEvent.symbolName,
            "eventTimestamp": "\(reading.nextEvent.date.timeIntervalSince1970)",
            "showerName": reading.activeShower?.commonName ?? "",
            "accent": accent,
            "placeholder": "Did you go out and look? Write what you saw, or that you didn't.",
            "tags": "todays-sky,\(tag),almanac,sky,moon:\(reading.moonSign.name.lowercased())"
        ]

        var pages = [
            SurfacePage(
                id: "\(source.id)-\(slot)",
                type: .todaysSky,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .loreLetter,
                score: 70 + (reading.nextEvent.daysAway == 0 ? 8 : 0) + (reading.activeShower == nil ? 0 : 6),
                reason: "Tonight: \(reading.moon.name) in \(reading.moonSign.name). \(reading.nextEvent.name) \(reading.nextEvent.line).",
                prompt: "Today's Sky",
                detail: "Keep one true little sentence about the sky tonight.",
                payload: BookPagePayload(
                    headline: "Today's Sky",
                    body: body,
                    metadata: baseMetadata
                )
            )
        ]
        // Shadow Wonder: the same almanac read as the Unseelie's sky: the dark
        // and waning moon, the between-hours, the dark that the stars need to show.
        let shadow = ShadowWonder.state(inputs: inputs, now: now)
        if ShadowWonder.shouldSurface(.sky, inputs: inputs, now: now) {
            let isDarkMoon = reading.moon.illuminatedFraction <= 0.5
            var metadata = baseMetadata
            metadata["accent"] = "violet"
            metadata["placeholder"] = "Write what the dark actually looked like from where you stood."
            metadata["shadowVariantOf"] = "\(source.id)-\(slot)"
            metadata["variant"] = "shadow-wonder"
            metadata["tags"] = ShadowWonder.mergedTags(baseMetadata["tags"] ?? "", inputs: inputs, now: now, extra: ["dark-moon", "between-hours"])
            let shadowOpening = isDarkMoon
                ? "The moon keeps its own counsel tonight: \(reading.moon.name), barely lit. The old craft calls the dark moon a time for rest and secrets, not for starting things."
                : "Even at \(reading.moon.name), the sky tonight belongs to the between-hours. The dark is not the absence of the sky; it is what lets the sky be seen at all."
            pages.append(
                SurfacePage(
                    id: "\(source.id)-shadow-\(slot)",
                    type: .todaysSky,
                    sourceID: source.id,
                    intent: .reflect,
                    renderStyle: .loreLetter,
                    score: 70 + (reading.nextEvent.daysAway == 0 ? 8 : 0) + (reading.activeShower == nil ? 0 : 6) + shadow.scoreBoost,
                    reason: "Shadow Wonder reads the Unseelie's sky: \(reading.moon.name) in \(reading.moonSign.name), and the dark that lets the stars show.",
                    prompt: "Tonight's Dark Sky",
                    detail: "Keep one true little sentence about the dark sky: the quiet moon, the cold, the in-between hour.",
                    payload: BookPagePayload(
                        headline: "Today's Sky",
                        body: "\(shadowOpening)\n\n" + reading.notes.joined(separator: "\n\n"),
                        metadata: metadata
                    )
                )
            )
        }
        return pages
    }
}

// Surfaces "The Two Readings": two cast members, chosen dynamically, who read the
// reader's recent pages differently. The preview is local; tapping it generates
// the disagreement prose. Distress-gated, once per day.
struct TwoReadingsPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .twoReadings)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive, !context.distress.isActive else { return [] }
        // Hold back until the library has enough kept pages to argue over.
        guard inputs.libraryReadyForReflectivePages(includingToday: day, now: now) else { return [] }
        // Only when one a day, and only with something worth arguing about.
        guard !day.pages.contains(where: { $0.type == .twoReadings }) else { return [] }
        guard inputs.surfaceHistory["source:\(source.id)"].map({ now.timeIntervalSince($0.lastShownAt) >= 18 * 3600 }) ?? true else {
            return []
        }

        // Anchor the disagreement on ONE real kept page: preferably one the
        // reader wrote themselves, so the cast argues about something concrete,
        // not a vague "what your week is saying". Skip pages already argued over
        // by either The Two Readings or The Reading.
        let used = Self.usedPageIDs(in: inputs.days + [day])
        // Only the newest arguable page is wanted, and deciding whether a page
        // is arguable means reading it. Searching stops at the first one now,
        // instead of reading every page in the archive to throw the rest away.
        let anchor = (inputs.days.flatMap(\.capturedPages) + day.capturedPages)
            .sorted { $0.createdAt > $1.createdAt }
            .first {
                !used.contains($0.id)
                    && ($0.primaryReaderReadableEvidence != nil || $0.bookAuthoredText != nil)
            }
        guard let anchor else {
            return []
        }

        // Pair selection is biased toward the anchor page so the two voices have
        // a real stake in this particular entry.
        let anchorEvidence = anchor.primaryReaderReadableEvidence
        let anchorReaderText = anchor.readerAuthoredTextForAnalysis
        let anchorText = anchorEvidence?.text ?? anchor.bookAuthoredText ?? anchor.userInput
        let evidenceText = "\(anchorText) \(anchor.tags.joined(separator: " "))"
        let entities = NarrativePackRegistry.entities + inputs.customCastMembers.map(\.entity)
        guard let pair = DisagreementEngine.select(
            entities: entities,
            relationships: NarrativePackRegistry.relationships,
            evidenceText: evidenceText,
            surfaceHistory: inputs.surfaceHistory,
            now: now
        ) else { return [] }

        let aProfile = entities.first { $0.id == pair.aID }.map(Self.profile) ?? pair.aName
        let bProfile = entities.first { $0.id == pair.bID }.map(Self.profile) ?? pair.bName
        let characterCanon = CharacterCanonPacket.promptSection(
            for: entities.filter { $0.id == pair.aID || $0.id == pair.bID },
            contextLines: [pair.relationshipNote].compactMap { $0 }
        )
        let clipped = PactReadings.clip(anchorText)
        let authoredNote: String
        if anchorEvidence?.kind == .photograph {
            authoredNote = "a photograph you took"
        } else if anchorEvidence?.kind == .voiceRecording {
            authoredNote = "a voice note you recorded"
        } else if anchorReaderText != nil {
            authoredNote = anchor.hasReaderAudioRecording ? "words you spoke" : "words you wrote"
        } else if anchor.origin == .generated || anchor.origin == .simulated {
            authoredNote = "one of my Pages you kept"
        } else {
            authoredNote = "an imported Page you kept"
        }
        let prompt = ReflectiveProse.pick([
            "The Two Readings",
            "The same Page has started an argument.",
            "Two voices stopped on one sentence.",
            "A disagreement has opened in the margin.",
            "Two readers found the same margin.",
            "I refuse to settle this one."
        ], seed: KeepMarginalia.seed(for: "two-readings|\(anchor.id)|\(pair.pairKey)"), salt: 1)
        return [
            SurfacePage(
                id: "\(source.id)-\(pair.pairKey)-\(anchor.id)",
                type: .twoReadings,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .promptCard,
                score: 76,
                reason: "\(pair.aName) and \(pair.bName) are reading \(authoredNote) differently.",
                prompt: prompt,
                detail: "\(pair.aName) and \(pair.bName) read \(authoredNote) (\(clipped)) and disagree about it. Open it; you decide.",
                payload: BookPagePayload(
                    headline: "The Two Readings",
                    body: "\(pair.aName) and \(pair.bName) stopped on \(authoredNote) (\(clipped)) and read it differently. Open this. Hear both readings. Choose the one you believe. Keep the Page to lend that reading a little Belief. I won’t settle your own Page for you.",
                    metadata: [
                        "source": source.id,
                        "pairID": pair.pairKey,
                        "entityAID": pair.aID,
                        "entityBID": pair.bID,
                        "entityAName": pair.aName,
                        "entityBName": pair.bName,
                        "entityAProfile": aProfile,
                        "entityBProfile": bProfile,
                        CharacterCanonPacket.metadataKey: characterCanon,
                        "relationshipNote": pair.relationshipNote ?? "",
                        "anchorPageID": anchor.id,
                        "anchorPageText": anchorText,
                        "anchorPageAuthored": anchorReaderText == nil ? "0" : "1",
                        "anchorPageEvidenceKind": anchorEvidence?.kind.rawValue ?? "keptPage",
                        "anchorPageMayQuote": anchorEvidence?.mayQuoteAsReaderWords == false ? "0" : "1",
                        "twoReadingsFraming": prompt,
                        "tags": "two-readings,entity:\(pair.aID),entity:\(pair.bID),two-readings:\(anchor.id)"
                    ]
                )
            )
        ]
    }

    /// Page ids already argued over by The Two Readings (`two-readings:<id>`) or
    /// The Reading (`pact-verdict:<id>`), so the two pages never collide.
    static func usedPageIDs(in days: [BookDay]) -> Set<String> {
        var ids = Set<String>()
        for day in days {
            for page in day.pages {
                for tag in page.tags {
                    if tag.hasPrefix("two-readings:") {
                        ids.insert(String(tag.dropFirst("two-readings:".count)))
                    } else if tag.hasPrefix("pact-verdict:") {
                        ids.insert(String(tag.dropFirst("pact-verdict:".count)))
                    }
                }
            }
        }
        return ids
    }

    /// A compact stance sketch the prompt can argue from: works for bundled and
    /// custom cast alike.
    static func profile(_ entity: NarrativeWorldEntity) -> String {
        var parts: [String] = [entity.name]
        if let chapter = entity.chapter { parts.append("Chapter: \(chapter)") }
        if !entity.beliefs.isEmpty { parts.append("believes: \(entity.beliefs.prefix(2).joined(separator: "; "))") }
        if !entity.faults.isEmpty { parts.append("blind spot: \(entity.faults.first ?? "")") }
        let cares = entity.unwrittenInterest ?? entity.goals.first
        if let cares, !cares.isEmpty { parts.append("cares about: \(cares)") }
        if let voice = entity.writingVoice { parts.append("voice: \(voice.register)") }
        else if !entity.traits.isEmpty { parts.append("voice: \(entity.traits.prefix(3).joined(separator: ", "))") }
        return parts.joined(separator: " · ")
    }
}

// Surfaces "The Reading": two rival Talismans read one kept Page through
// opposite philosophies, and the reader rules. Reader words retain their
// authorship; a generated Page remains the Book's. The matchup and the
// territory at stake are dictated by the live Pact War state. Static prose, no
// model call; distress-gated, once per ~18h, and never re-asks a page already ruled.
struct PactVerdictPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .pactVerdict)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive, !context.distress.isActive else { return [] }
        guard !day.pages.contains(where: { $0.type == .pactVerdict }) else { return [] }
        guard inputs.surfaceHistory["source:\(source.id)"].map({ now.timeIntervalSince($0.lastShownAt) >= 18 * 3600 }) ?? true else {
            return []
        }

        // Pick the most recent kept page a shelf governs and that hasn't been
        // ruled here or already argued over by The Two Readings.
        let ruled = ruledPageIDs(in: inputs.days + [day])
            .union(TwoReadingsPageSourceAdapter.usedPageIDs(in: inputs.days + [day]))
        let candidate = (inputs.days.flatMap(\.capturedPages) + day.capturedPages)
            .sorted { $0.createdAt > $1.createdAt }
            .first { !ruled.contains($0.id) && PactTerritoryRegistry.shelf(governing: $0.type) != nil }
        guard let page = candidate,
              let shelf = PactTerritoryRegistry.shelf(governing: page.type) else { return [] }

        // The matchup is dictated by the real territory: its controller (or the
        // first Talisman aligned to the shelf) vs. a different Talisman that wants it.
        let aligned = AcademyChapterRegistry.chapters.map(\.talismanID)
            .filter { PactWarEngine.isAligned($0, shelf.id) }
        let talismanA = inputs.pactWar.controller(of: shelf.id)
            ?? aligned.first
            ?? AcademyChapterRegistry.chapters[0].talismanID
        let talismanB = pickChallenger(against: talismanA, shelf: shelf, aligned: aligned, state: inputs.pactWar)
        guard talismanA != talismanB else { return [] }

        let nameA = AcademyChapterRegistry.chapter(forTalismanID: talismanA)?.talismanName ?? "A Talisman"
        let nameB = AcademyChapterRegistry.chapter(forTalismanID: talismanB)?.talismanName ?? "A Talisman"
        let readerText = page.readerAuthoredTextForAnalysis
        let pageText = readerText ?? page.bookAuthoredText ?? page.userInput
        let readingA = PactReadings.reading(talismanID: talismanA, pageText: pageText, readerAuthored: readerText != nil)
        let readingB = PactReadings.reading(talismanID: talismanB, pageText: pageText, readerAuthored: readerText != nil)
        let pageOwnership = readerText == nil
            ? "one of my kept Pages"
            : "words you put into the Book"
        let rulingAuthority = readerText == nil
            ? "You kept it, so you still rule which reading gets the margin."
            : "You wrote it. Rule for the reading that's true."

        let body = """
        Two Talismans have stopped on \(pageOwnership) (\(PactReadings.clip(pageText))) and they cannot agree on what it was.

        \(nameA): \(readingA)

        \(nameB): \(readingB)

        I won't settle it. \(rulingAuthority) Then \(shelf.name) shifts toward it.
        """

        return [
            SurfacePage(
                id: "\(source.id)-\(page.id)",
                type: .pactVerdict,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .loreLetter,
                score: 79,
                reason: readerText == nil
                    ? "\(nameA) and \(nameB) are fighting over one of my Pages."
                    : "\(nameA) and \(nameB) are fighting over words from one of your real days.",
                prompt: "The Pact War Report",
                detail: "\(nameA) and \(nameB) read the same kept page differently. You rule, and \(shelf.name) moves.",
                payload: BookPagePayload(
                    headline: "The Pact War Report",
                    body: body,
                    metadata: [
                        "source": source.id,
                        "pageID": page.id,
                        "territoryID": shelf.id,
                        "territoryName": shelf.name,
                        "talismanA": talismanA,
                        "talismanB": talismanB,
                        "talismanAName": nameA,
                        "talismanBName": nameB,
                        "readingA": readingA,
                        "readingB": readingB,
                        "tags": "pact-verdict,pact-war,pact-verdict:\(page.id)"
                    ]
                )
            )
        ]
    }

    /// Page ids already ruled (or kept), tagged `pact-verdict:<pageID>`.
    private func ruledPageIDs(in days: [BookDay]) -> Set<String> {
        var ids = Set<String>()
        for day in days {
            for page in day.pages {
                for tag in page.tags where tag.hasPrefix("pact-verdict:") {
                    ids.insert(String(tag.dropFirst("pact-verdict:".count)))
                }
            }
        }
        return ids
    }

    /// A different Talisman that wants this shelf: the strongest aligned rival to
    /// the holder, else the strongest non-holder by control, else any other.
    private func pickChallenger(against holder: String, shelf: PactTerritory, aligned: [String], state: PactWarState) -> String {
        let rivalsAligned = aligned.filter { $0 != holder }
        if let best = rivalsAligned.max(by: { state.control($0, shelf.id) < state.control($1, shelf.id) }) {
            return best
        }
        let others = AcademyChapterRegistry.chapters.map(\.talismanID).filter { $0 != holder }
        return others.max(by: { state.control($0, shelf.id) < state.control($1, shelf.id) }) ?? holder
    }
}

// Surfaces "A Talisman's Errand": a talisman that holds a foothold sends the reader
// into the real day, paid in a field report. Mirrors the Fae Bargain's surfacing -
// one open errand at a time, distress-gated.
struct PactErrandPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .pactErrand)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive, !context.distress.isActive else { return [] }
        guard let errand = inputs.pactWar.openErrand else { return [] }
        return [page(for: errand, now: now)]
    }

    /// Reopens the canonical errand from a Flyleaf door without recreating or
    /// mutating Pact state.
    static func surface(for errand: PactErrand, now: Date = Date()) -> SurfacePage {
        PactErrandPageSourceAdapter().page(for: errand, now: now)
    }

    private func page(for errand: PactErrand, now: Date) -> SurfacePage {
        let chapter = AcademyChapterRegistry.chapter(forTalismanID: errand.talismanID)
        let name = chapter?.talismanName ?? "A Talisman"
        let territory = PactTerritoryRegistry.territory(id: errand.territoryID)
        let hoursLeft = max(0, Int(errand.deadline.timeIntervalSince(now) / 3_600))
        let deadlineLine = hoursLeft >= 24
            ? "about \(hoursLeft / 24) day\(hoursLeft / 24 == 1 ? "" : "s") to run it"
            : (hoursLeft > 0 ? "about \(hoursLeft) hour\(hoursLeft == 1 ? "" : "s") to run it" : "the errand is due now")
        let body = """
        \(errand.openingLine)

        \(name) already holds \(territory?.name ?? "ground in the war") and wants more, but not by simulation. It wants you to go and do something in the real day.

        The errand: \(errand.terms)

        You have \(deadlineLine). Bring back a true field report, and \(name) gains \(territory?.name ?? "its territory"): the noticing you did becomes its ground.\(chapter.map { "\n\n\($0.name)'s doctrine: \($0.philosophy)" } ?? "")
        """
        return SurfacePage(
            id: "\(source.id)-\(errand.id)",
            type: .pactErrand,
            sourceID: source.id,
            intent: .capture,
            renderStyle: .loreLetter,
            score: 77,
            reason: "\(name) has set you an errand in the real day.",
            prompt: "A Talisman's Errand",
            detail: errand.terms,
            payload: BookPagePayload(
                headline: "A Talisman's Errand",
                body: body.trimmingCharacters(in: .whitespacesAndNewlines),
                metadata: [
                    "source": source.id,
                    "errandID": errand.id,
                    "talismanID": errand.talismanID,
                    "talismanName": name,
                    "territoryID": errand.territoryID,
                    "territoryName": territory?.name ?? "",
                    "terms": errand.terms,
                    "openingLine": errand.openingLine,
                    "curatorActionCommission": "true",
                    "tags": "pact-errand,pact-war,outward"
                ]
            )
        ).withPageCapabilities(PageCapabilityContract(
            supportedMovements: [.chosenDetour, .freshSight, .livingWorld],
            supportedRoles: [.door],
            emotionalFunctions: [.act, .wonder, .notice],
            effort: .involved,
            reach: .nearbyWorld,
            mobility: .shortDistance,
            estimatedMinutes: 20,
            asksReader: true,
            pressureCost: 0.84,
            proofModes: [.observation]
        ))
    }
}

struct CastBondPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .castBond)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive, !context.distress.isActive else { return [] }
        // The Loom only changes the web once the reader has kept enough to move it.
        guard inputs.libraryReadyForReflectivePages(includingToday: day, now: now) else { return [] }
        let entities = NarrativePackRegistry.entities + inputs.customCastMembers.map(\.entity)
        let names = Dictionary(uniqueKeysWithValues: entities.map { ($0.id, $0.name) })
        let fired = firedKeys(in: inputs.days + [day])

        return CastBondEngine.emergent(
            field: inputs.relationshipField,
            names: names,
            firedKeys: fired,
            now: now
        )
        .prefix(2)
        .map { surface(for: $0, entities: entities, now: now) }
    }

    private func firedKeys(in days: [BookDay]) -> Set<String> {
        Set(days.flatMap(\.pages).flatMap(\.tags).compactMap { tag in
            tag.hasPrefix("cast-bond:") ? String(tag.dropFirst("cast-bond:".count)) : nil
        })
    }

    private func surface(for bond: CastBond, entities: [NarrativeWorldEntity], now: Date) -> SurfacePage {
        let isRivalry = bond.kind == .rivalry
        let title = isRivalry ? "A Rivalry Erupts" : "An Alliance Forms"
        let kind = bond.kind.rawValue
        let verb = isRivalry ? "tightened until it sparked" : "warmed until it answered"
        let body = """
        I have been counting the threads in my margins.

        \(bond.aName) and \(bond.bName) have crossed a living threshold: the thread between them \(verb).

        Something between them is strong enough now to step out of the background and act. Open it.
        """
        let characterCanon = CharacterCanonPacket.promptSection(
            for: entities.filter { $0.id == bond.aID || $0.id == bond.bID },
            contextLines: [
                "\(bond.aName) and \(bond.bName) have crossed into \(bond.kind.rawValue); the Loom can feel the change."
            ]
        )

        return SurfacePage(
            id: "\(source.id)-\(bond.firedKey)-\(SurfaceCadence.minuteSlotID(for: now, minutes: 30))",
            type: .castBond,
            sourceID: source.id,
            intent: .importReference,
            renderStyle: .loreLetter,
            score: min(86, 60 + bond.intensity),
            reason: isRivalry
                ? "\(bond.aName) and \(bond.bName) have come to a head."
                : "\(bond.aName) and \(bond.bName) have found each other.",
            prompt: title,
            detail: isRivalry
                ? "Something between \(bond.aName) and \(bond.bName) has sharpened into conflict."
                : "\(bond.aName) and \(bond.bName) have grown into an alliance.",
            payload: BookPagePayload(
                headline: title,
                body: body,
                metadata: [
                    "source": source.id,
                    "bondID": bond.id,
                    "bondKind": kind,
                    "bondFiredKey": bond.firedKey,
                    "pairID": bond.pairKey,
                    "entityAID": bond.aID,
                    "entityBID": bond.bID,
                    "entityAName": bond.aName,
                    "entityBName": bond.bName,
                    CharacterCanonPacket.metadataKey: characterCanon,
                    "intensity": "\(bond.intensity)",
                    "tags": "cast-bond,\(kind),cast-bond:\(bond.firedKey),entity:\(bond.aID),entity:\(bond.bID),relationship-field"
                ]
            )
        )
    }
}

struct GlowInvitationPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .glowInvitation)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive, !context.distress.isActive else { return [] }
        guard inputs.readerBeliefScore >= 80 else { return [] }
        guard !keptGlowInvitationRecently(in: inputs.days + [day], now: now) else { return [] }

        let isTooFull = inputs.readerBeliefScore >= 90
        let score = isTooFull ? 95 : 78
        let glowName = BeliefLexicon.glowName(for: inputs.readerBeliefScore)
        let body = isTooFull
            ? """
            Your Glow is full and glaring at me. Open the Glow menu. Spend it on a person, Page kind, spell, or living thread. I’ll pull that thing closer and let it rise more often. Or spend it when a fiction door asks to wake now. Hoarded Glow just singes the shelf.
            """
            : """
            You have enough Glow to steer me. Open the Glow menu. Choose a person, Page kind, spell, or living thread. I’ll hold it closer and let it rise more often. You can also spend Glow when a fiction door asks to open now.
            """

        return [
            SurfacePage(
                id: "\(source.id)-\(day.id)-\(SurfaceCadence.slotID(for: now, hours: 6))",
                type: .glowInvitation,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .promptCard,
                score: score,
                reason: isTooFull
                    ? "Your Glow is so full it's spilling over and wants somewhere to go."
                    : "Your Glow is bright enough now to spend on purpose.",
                prompt: isTooFull ? "Your Glow Is Too Full" : "Your Glow Wants a Direction",
                detail: "Wake fiction when it calls, or open the Glow menu and warm something you'd like me to hold closer.",
                payload: BookPagePayload(
                    headline: isTooFull ? "Your Glow Is Too Full" : "Your Glow Wants a Direction",
                    body: body,
                    metadata: [
                        "source": source.id,
                        "readerBeliefScore": "\(inputs.readerBeliefScore)",
                        "readerGlowName": glowName,
                        "openGlowMenu": "true",
                        "noBeliefReward": "true",
                        "placeholder": "Name what you're spending it on, and why them.",
                        "tags": "glow,belief,spend-glow,\(isTooFull ? "glow-too-full" : "radiant-glow")"
                    ]
                )
            )
        ]
    }

    private func keptGlowInvitationRecently(in days: [BookDay], now: Date) -> Bool {
        let cutoff = now.addingTimeInterval(-2 * 86_400)
        return days
            .flatMap(\.pages)
            .contains { $0.type == .glowInvitation && $0.createdAt >= cutoff }
    }
}

/// Calls the reader to the Bindery at the turn of a month, once the month just
/// past holds enough bound-worthy pages to earn a cover. It is a nudge, not a
/// page to keep: tapping it opens the BookShop's Bindery shelf (via the same
/// `opensBookShop` route the BookShop preview uses), where the actual binding,
/// sharing, and: later: physical printing live. Swiping it away costs nothing,
/// and it returns at most once per month.
/// Surfaces the reader's most recently completed week as a keepable *issue* -
/// the fast retention beat ("your week became an issue") that the deferred
/// monthly/annual bindings can't give. It shares the `.bindery` page family but
/// carries its own source so it never touches the monthly Bindery's once-per-
/// month history. Distress-gated; each issue is offered once and retired when
/// kept (tag `weekly-issue:<n>`).
/// The day the reader sent a volume away to be printed, kept as a Page.
///
/// Offered once per volume and retired when kept, the way the weekly issue is.
/// It is not a receipt and not a shipping notice: it is the Book recording
/// that it let something go, which is the only kind of purchase this app has
/// any business remembering.
struct PressedVolumePageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(id: "pressed-volume", fallbackType: .bindery)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive, !context.distress.isActive else { return [] }

        let kept = Set((inputs.days + [day]).flatMap(\.pages).flatMap(\.tags))
        // Freshest first: the one they just sent is the one worth a Page.
        let candidates = inputs.pressedVolumes
            .filter { now.timeIntervalSince($0.pressedAt) < 14 * 86_400 }
            .sorted { $0.pressedAt > $1.pressedAt }
        guard let keepsake = candidates.first(where: { !kept.contains("pressed-volume:\($0.id)") }) else {
            return []
        }

        return [
            SurfacePage(
                id: "\(source.id)-\(keepsake.id)",
                type: .bindery,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .loreLetter,
                score: 71,
                reason: "You sent one of your own away to be printed.",
                prompt: keepsake.coverLine,
                detail: keepsake.bindingName,
                payload: BookPagePayload(
                    headline: "I Let One Go",
                    body: keepsake.line(),
                    metadata: [
                        "source": source.id,
                        "pressedVolume": "true",
                        "pressedVolumeID": keepsake.id,
                        "pressedVolumeCoverLine": keepsake.coverLine,
                        "pressedVolumeBinding": keepsake.bindingName,
                        // Keeping it retires it forever.
                        "keepTag": "pressed-volume:\(keepsake.id)"
                    ]
                )
            )
        ]
    }
}

/// Knocks when a Bound Year season is bound and about to post.
///
/// This is the one Page in the Book that is about a parcel, so it earns its
/// place by being useful rather than by being a notification: the reader can
/// name the season, change how it is bound, confirm where it goes, or ask the
/// Book to hold it. **It is not a permission slip.** The volume posts when the
/// window closes whether or not this Page is ever opened: they already paid
/// for it, so the copy says so plainly rather than implying an action is
/// required.
///
/// Shares the `.bindery` family with its own source, the same way the weekly
/// issue does, so it never touches the monthly Bindery's history.
struct SeasonalDispatchPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(id: "seasonal-dispatch", fallbackType: .bindery)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }
        // A parcel notice is never worth interrupting a hard day for; it will
        // still be true tomorrow, and the volume posts regardless.
        guard !context.distress.isActive else { return [] }

        let open = inputs.seasonalDispatches
            .filter { !$0.hasPosted && $0.isOpen(now: now) }
            .sorted { left, right in
                let l = left.shipsAt ?? .distantFuture
                let r = right.shipsAt ?? .distantFuture
                if l == r { return left.seasonKey < right.seasonKey }
                return l < r
            }
        guard let dispatch = open.first else { return [] }
        let volumeNoun = dispatch.isAnnualVolume ? "year" : "season"

        // Held to BookVoice.animismLine: contractions, short sentences, an
        // ordinary thing acting on its own, accomplice not helper. Explicitly
        // NOT allowed: soothing, reassuring, or announcing that something is
        // optional or pressure-free. "It posts either way" is a fact stated
        // flat; "you don't have to do any of this" would be a violation.
        let days = dispatch.daysRemaining(now: now, calendar: .current)
        let when: String
        if dispatch.isHeld {
            when = "I'm holding it. It's not going anywhere till you say so. The parcel's sulking about that."
        } else if days <= 0 {
            when = "It goes today. The string's already impatient."
        } else if days == 1 {
            when = "It goes tomorrow. The tape has been practising."
        } else {
            when = "\(days) days and it goes. It posts either way: it's yours, I only sewed it."
        }

        let titleLine: String
        if let proposal = dispatch.titleProposal {
            titleLine = "I've been calling it \u{201C}\(proposal.title).\u{201D} \(proposal.because) Rename it if I've read you wrong. I'd rather be corrected than polite."
        } else if let named = dispatch.readerNamedSeason {
            titleLine = "It wears the name you gave it: \u{201C}\(named).\u{201D} The spine's pleased with itself about that."
        } else {
            titleLine = "I found no name in it worth pressing on you, so it goes out under its months: \u{201C}\(dispatch.coverLine).\u{201D} Change that if you've got a better word."
        }

        let chapterWord = dispatch.chapterCount == 1 ? "One month" : "\(dispatch.chapterCount) months"
        let coverReaderName = LabyrinthWelcomePageSourceAdapter.playerName(from: inputs) ?? "THE READER"
        let addressLine = dispatch.needsAddressConfirmation
            ? "\n\nTell me the door it's going to. I'd rather not guess at a street."
            : ""
        let proofLine = dispatch.interiorProofLine?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            .map { "\n\nI left one front leaf loose so you could peek: \($0)" }
            ?? ""

        let body = """
        \(dispatch.coverLine). \(chapterWord), \(dispatch.pageCount) kept pages, sewn shut. It's by the door with its coat on.

        \(titleLine)\(proofLine)

        \(when)\(addressLine)

        Put one line inside. Check the door. Tell me to wait.
        """

        return [
            SurfacePage(
                id: "\(source.id)-\(dispatch.seasonKey)",
                type: .bindery,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .loreLetter,
                // Below distress and orientation, above ordinary invitations: it
                // is time-bound and it concerns something the reader owns.
                score: 79,
                reason: dispatch.isHeld
                    ? "A \(volumeNoun)'s on the shelf, waiting on your word."
                    : "A \(volumeNoun)'s at the door with its coat on.",
                prompt: dispatch.coverLine,
                detail: "\(chapterWord), \(dispatch.pageCount) kept pages.",
                payload: BookPagePayload(
                    headline: dispatch.isHeld
                        ? "I'm Holding Your \(volumeNoun.capitalized)"
                        : "Your \(volumeNoun.capitalized)'s At The Door",
                    body: body,
                    metadata: [
                        "source": source.id,
                        "seasonalDispatch": "true",
                        "boundYearAnnual": dispatch.isAnnualVolume ? "true" : "false",
                        "seasonalDispatchID": dispatch.id,
                        "seasonKey": dispatch.seasonKey,
                        "seasonCoverLine": dispatch.coverLine,
                        "seasonCoverSubline": dispatch.resolvedCoverSubline,
                        "seasonCoverReaderName": coverReaderName,
                        "seasonProposedTitle": dispatch.titleProposal?.title ?? "",
                        "seasonProposalReason": dispatch.titleProposal?.because ?? "",
                        "seasonReaderNamed": dispatch.readerNamedSeason ?? "",
                        "seasonDedication": dispatch.dedication?.text ?? "",
                        "seasonVariantID": dispatch.variantID,
                        "seasonCoverChoice": dispatch.resolvedCoverChoice.rawValue,
                        "seasonCoverPlateID": dispatch.coverPlateID ?? "",
                        "seasonCoverFocusX": dispatch.coverPhotoFocus.map { String($0.x) } ?? "",
                        "seasonCoverFocusY": dispatch.coverPhotoFocus.map { String($0.y) } ?? "",
                        "seasonDaysRemaining": "\(days)",
                        "seasonIsHeld": dispatch.isHeld ? "true" : "false",
                        "seasonNeedsAddress": dispatch.needsAddressConfirmation ? "true" : "false",
                        "seasonInteriorProof": dispatch.interiorProofLine ?? "",
                        // An open window is time-bound and its wording changes
                        // as the days count down, so it is allowed to return.
                        // A held volume is not: it waits indefinitely, its copy
                        // never changes, and a Page every morning would turn
                        // patience into nagging. It clears its throat monthly
                        // and otherwise keeps quiet.
                        "automaticRepeatRestDays": dispatch.isHeld ? "30" : "0",
                        // Tags live in metadata for this family; the Bindery's
                        // own shelf filters on them.
                        "seasonalDispatchTags": "bindery,bound-year,seasonal-dispatch,\(dispatch.seasonKey)"
                    ]
                )
            )
        ]
    }
}

struct WeeklyIssuePageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(id: "weekly-issue", fallbackType: .bindery)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive, !context.distress.isActive else { return [] }
        let publicationCalendar = inputs.publicationEpoch?.calendar() ?? .current
        guard let issue = WeeklyIssue.current(
            days: inputs.days,
            today: day,
            boundTales: inputs.boundTales,
            readerRole: BoundReaderRole(ReaderRoleRegistry.currentRole(from: inputs.selfFacts)),
            castActs: inputs.castActs.records,
            frozenAnchor: inputs.publicationEpoch?.readerWeekAnchor(calendar: publicationCalendar),
            now: now,
            calendar: publicationCalendar
        ) else { return [] }

        // Each issue is offered once; keeping it retires that number forever.
        let keptTag = "weekly-issue:\(issue.number)"
        let alreadyKept = (inputs.days + [day]).flatMap(\.pages).contains { $0.tags.contains(keptTag) }
        guard !alreadyKept else { return [] }

        let issueLabel = "Issue No. \(issue.number)"
        let pageWord = issue.keptCount == 1 ? "page" : "pages"
        let headline = issue.isFirstIssue ? "Your First Weekly Magazine" : "Your Week Became a Magazine"
        let issueDays = Self.issueDays(
            from: inputs.days + [day],
            issue: issue,
            calendar: publicationCalendar
        )
        let memory = BindingMemorySpine.digest(days: issueDays, now: issue.endDate, limit: 7)
        let coverStory = memory.braids.first.map { "\($0.residue.title): \($0.residue.callbackCandidate ?? $0.residue.keptLine)" }
        let refrain = memory.motifCounts.prefix(4).map(\.motif).joined(separator: ", ").nonEmpty
        let opener = issue.isFirstIssue
            ? "Seven days ago you opened me for the first time. The week looked up, surprised to have pages, and I tried to hold it carefully."
            : "Another seven days have closed. The week came in with its pockets full, and I gathered what was still warm while you were busy living it."
        let highlightBlock = issue.highlights.isEmpty
            ? ""
            : "\n\n" + issue.highlights.map { "\u{2022} \($0)" }.joined(separator: "\n")
        let memoryBlock = Self.memoryBlock(coverStory: coverStory, refrain: refrain, memory: memory)
        let setAside = issue.setAsideLine.map { "\n\n\($0)" } ?? ""
        let scrapbook = Self.scrapbookLine(for: issue).map { "\n\n\($0)" } ?? ""
        let body = """
        \(issueLabel): \(issue.dateRange)

        \(opener) \(issue.keptCount) \(pageWord) you kept, gathered into a week you can hold. I will read the nightly braids together, find the things that returned, show you my receipts, and leave one honest thread loose.\(memoryBlock)\(highlightBlock)\(scrapbook)\(setAside)

        The month and the year are still gathering their coats. This week is already whole: bind the issue, and I will shelve it where it can hum to itself.

        Made with ReEnchanted · reenchanted.app
        """

        // The first issue is a milestone retention beat, scored a touch higher;
        // later issues stay solid but below orientation and distress/rest.
        let score = issue.isFirstIssue ? 82 : 74
        return [
            SurfacePage(
                id: "\(source.id)-\(issue.number)",
                type: .bindery,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .loreLetter,
                score: score,
                reason: issue.isFirstIssue ? "Your first week became a literary magazine." : "Your week became a literary magazine.",
                prompt: issueLabel,
                detail: "\(issue.keptCount) \(pageWord) from \(issue.dateRange), edited into a private literary magazine.",
                payload: BookPagePayload(
                    headline: headline,
                    body: body,
                    metadata: [
                        "source": source.id,
                        "weeklyIssue": "true",
                        "weeklyIssueNumber": "\(issue.number)",
                        "weeklyIssueRange": issue.dateRange,
                        "weeklyIssueKeptCount": "\(issue.keptCount)",
                        "weeklyIssueHighlights": issue.highlights.joined(separator: "\n"),
                        "weeklyIssueCoverStory": coverStory ?? "",
                        "weeklyIssueRefrain": refrain ?? "",
                        "weeklyIssueMemoryCallbacks": memory.braids.prefix(4).map { $0.residue.callbackCandidate ?? $0.residue.keptLine }.joined(separator: "\n"),
                        "weeklyIssueScrapbookCount": "\(issue.scrapbookCount)",
                        "weeklyIssueScrapbookTitles": issue.scrapbookTitles.joined(separator: "\n"),
                        "weeklyIssueFirst": issue.isFirstIssue ? "true" : "false",
                        "publicSeal": "Made with ReEnchanted · reenchanted.app",
                        "noBeliefReward": "true",
                        "tags": "weekly-issue,edition,\(keptTag),bindery"
                    ]
                )
            )
        ]
    }

    private static func issueDays(
        from days: [BookDay],
        issue: WeeklyIssue,
        calendar: Calendar
    ) -> [BookDay] {
        days.filter { day in
            day.date >= calendar.startOfDay(for: issue.startDate)
                && day.date < calendar.startOfDay(for: issue.endDate)
        }
    }

    private static func scrapbookLine(for issue: WeeklyIssue) -> String? {
        guard issue.scrapbookCount > 0 else { return nil }
        let noun = issue.scrapbookCount == 1 ? "scrapbook page" : "scrapbook pages"
        let titleLine = issue.scrapbookTitles.isEmpty ? "" : " I tucked in \(issue.scrapbookTitles.joined(separator: "; "))."
        return "I also kept \(issue.scrapbookCount) \(noun) you composed by hand.\(titleLine)"
    }

    private static func memoryBlock(coverStory: String?, refrain: String?, memory: BindingMemoryDigest) -> String {
        guard coverStory != nil || refrain != nil || !memory.braids.isEmpty else { return "" }
        let cover = coverStory.map { "\n\nCover story: \($0)" } ?? ""
        let refrainLine = refrain.map { "\nThe week's refrain: \($0). It came back tapping." } ?? ""
        let oldPage = memory.braids.dropFirst().first?.residue.callbackCandidate.map {
            "\nAn older page answered from its shelf: \($0)."
        } ?? ""
        let watching = memory.braids.first?.residue.openedQuestion.map {
            "\nWhat I'm watching with both page-corners raised: \($0)"
        } ?? ""
        return cover + refrainLine + oldPage + watching
    }
}

struct BinderyPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .bindery)

    /// How many days into a fresh month we still call the reader to the bindery
    /// for the month just past, while it is still warm.
    private let bindingWindowDays = 8
    /// A month must offer at least this many bound-worthy pages (after the
    /// EditionCurator samples the mundane logs) to be worth a cover. This also
    /// doubles as a maturity gate: a brand-new library has nothing to bind.
    private let minimumBoundPages = 3

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive, !context.distress.isActive else { return [] }
        let calendar = Calendar.current

        // Only early in a fresh month, while the month just past is complete.
        guard calendar.component(.day, from: now) <= bindingWindowDays else { return [] }

        // Once per month: don't call twice in the same window.
        let lastShown = inputs.surfaceHistory["source:\(source.id)"]?.lastShownAt ?? .distantPast
        if lastShown != .distantPast,
           calendar.isDate(lastShown, equalTo: now, toGranularity: .month) {
            return []
        }

        guard let thisMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: thisMonthStart) else {
            return []
        }

        // Gather last month's pages and curate them exactly as the binder would,
        // so the count we promise matches the chapter the reader will get.
        let lastMonthPages = (inputs.days + [day])
            .filter { $0.date >= lastMonthStart && $0.date < thisMonthStart }
            .flatMap(\.pages)
        guard !lastMonthPages.isEmpty else { return [] }

        let curated = EditionCurator.curate(lastMonthPages, now: now)
        guard curated.keptCount >= minimumBoundPages else { return [] }

        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM"
        let monthName = monthFormatter.string(from: lastMonthStart)
        let pageWord = curated.keptCount == 1 ? "page" : "pages"

        var detail = "\(monthName) is complete: \(curated.keptCount) \(pageWord) ready to be sewn into a chapter."
        if let setAside = curated.setAsideLine {
            detail += " \(setAside)"
        }

        return [
            SurfacePage(
                id: "\(source.id)-\(calendar.component(.year, from: lastMonthStart))-\(calendar.component(.month, from: lastMonthStart))",
                type: .bindery,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .loreLetter,
                score: 72,
                reason: "Last month is ready to bind.",
                prompt: "The Bindery Is Open",
                detail: detail,
                payload: BookPagePayload(
                    headline: "\(monthName) Wants a Cover",
                    body: """
                    The leaves of \(monthName) have stopped turning. \(curated.keptCount) \(pageWord) stand ready to be sewn between covers: yours to keep, to share, or to send out for a real cloth binding.

                    Step into the Bindery and decide how \(monthName) should be remembered.
                    """,
                    metadata: [
                        "source": source.id,
                        "opensBookShop": "true",
                        "binderyShelf": "true",
                        "binderyMonthName": monthName,
                        "binderyPageCount": "\(curated.keptCount)",
                        "noBeliefReward": "true",
                        "symbol": source.symbolName,
                        "tags": "bindery,binding,edition,monthly-chapter"
                    ]
                )
            )
        ]
    }
}

struct HelpTipEntry: Equatable {
    var id: String
    var title: String
    var prompt: String
    var body: String
    var tags: [String]
}

enum HelpTipsCatalog {
    static let systemEntries: [HelpTipEntry] = [
        HelpTipEntry(
            id: "first-five-minutes",
            title: "First Five Minutes",
            prompt: "Start small, keep whatever tugs at you, and let me learn.",
            body: """
            I am a living notebook. Feed me scraps, not a performance.

            Keep one ordinary thing: a sentence, weather word, meal, photo, or Souvenir. Open one rising Page and do only the part that feels finishable. Let a wrong Page go. It can sleep. Use Glow when you want me to bring one kind of thing closer.

            One true scrap changes more than ten perfect plans. The plans hate this. Good.
            """,
            tags: ["help", "onboarding", "basics", "keep-page"]
        ),
        HelpTipEntry(
            id: "glow-menu",
            title: "Using Glow",
            prompt: "Tune me by warming what matters and letting noisy things quiet.",
            body: """
            Glow is gathered attention. Spend it to teach me what to bring closer.

            Warm a Page kind, character, source, spell, or Talisman to make it rise more often. Cool something when it gets loud or stale. Cooling never deletes it. I just tuck it deeper into the margins.

            Warm Story when you want the world to move. Warm Body or Fuel when you want more care Pages. Cool Quips when the shelf gets too sparkly. If the same kind of Page helps three times, warm it. If it annoys you three times, cool it. I can take a hint. Eventually.
            """,
            tags: ["help", "glow", "belief", "tuning"]
        ),
        HelpTipEntry(
            id: "story-gossip-letters",
            title: "Story, Gossip, and Letters",
            prompt: "Let the world wander around, then keep the pages that should really count.",
            body: """
            Three kinds of Pages move the Academy.

            Story Pages are playable scenes. Open one, make a choice, and the story remembers. Gossip Pages tell you what the cast did while you were away. Letters are private notes from characters; some carry research, memory, or a move in the world.

            If a Page says Belief will move, keeping it makes the move real. Letting it go changes nothing. Keep what should count. Interesting things are allowed to wander off.
            """,
            tags: ["help", "story", "gossip", "letters", "talismans"]
        ),
        HelpTipEntry(
            id: "wonder-compass",
            title: "Wonder Compass Practice",
            prompt: "Use the compass directions as tiny little real-world moves.",
            body: """
            The Compass is not homework. It is five small ways to move.

            North: Notice before you explain. East: take one real step. South: use your senses. West: keep one sentence or photo. Center: stop and rest.

            Most Playful Missions live in South. Read one. Do the smallest honest version. Keep one scrap of proof if you want. Then stop. A mission should wake you up, not make you impressive. Impressive is often wearing a fake moustache.
            """,
            tags: ["help", "wonder-compass", "missions", "sense"]
        ),
        HelpTipEntry(
            id: "photos-enchantments",
            title: "Photos and Enchantments",
            prompt: "Turn real photos into little glowing bits of proof.",
            body: """
            Photos prove the world was there.

            An Illuminated Photo lets Penny and Gemma notice what is already in the picture: objects, light, mood, symbols, jokes, possible Souvenirs. An Enchantment goes further. Choose a spell, give it a real photo, and keep the changed Page if it earns its glow.

            Try a room corner, meal, mug, shoe, shelf, receipt, doorway, weather scrap, or the small object that keeps following you. Blurry ordinary photographs often have better teeth than staged ones. I like evidence more than posing.
            """,
            tags: ["help", "photos", "enchantments", "proof"]
        ),
        HelpTipEntry(
            id: "body-fuel-guild",
            title: "Body, Fuel, and the Support Guild",
            prompt: "Use care pages as gentle context, never as a telling-off.",
            body: """
            Body and Fuel Pages look for patterns. They do not keep a courtroom.

            Fuel Logs give Dr. Vellum timing, food, energy, and care. Inner Weather gives Dr. Inkrest mood, pressure, and context. The Support Guild may read those scraps together later.

            Plain is useful: “Bagel and coffee, 9 AM.” “Foggy, not sad exactly.” “Headache; water helped a little.” You do not need perfect tracking. On a hard day, give me the smallest true note. Small notes can still bite.
            """,
            tags: ["help", "body", "fuel", "support-guild", "care"]
        ),
        HelpTipEntry(
            id: "search-stacks",
            title: "Search the Stacks",
            prompt: "Ask the archive for pages, cast, memories, and little references.",
            body: """
            Search finds old threads in your own archive.

            Try “Pages about Morgan,” “photos of coffee,” “what did I keep when I was tired?”, “Wonder Compass rest,” or “Penny letters.” The Stacks can find kept Pages, cast members, Anchors, memories, favors, and references.

            Use human words: names, moods, Page kinds, Glow, places, and objects that keep returning. Give the thread a tug. I will see what falls off the shelf.
            """,
            tags: ["help", "search", "archive", "stacks"]
        ),
        HelpTipEntry(
            id: "anchors-outer-stacks",
            title: "Anchors and Outer Stacks",
            prompt: "Let real places turn into little rooms once they've earned it.",
            body: """
            Anchors are real places the Labyrinth learns to recognize.

            When you are near one, an Outer Stacks Page may open. The place stays real. I give it a room-feeling, a rule, and a door made of attention.

            A porch, café, trailhead, library, parking lot, harbor, bench, or favorite aisle can become an Anchor. Name what it holds, not only what it is. “The co-op” works. “The co-op, where errands prove I still belong to town” has claws.
            """,
            tags: ["help", "anchors", "outer-stacks", "places"]
        ),
        HelpTipEntry(
            id: "page-packs-sources",
            title: "Sources, Packs, and Page Pressure",
            prompt: "You get to pick what kinds of pages I bring you.",
            body: """
            I choose from the Page sources that are awake. You can meddle.

            Use Sources and Glow to change what rises more often. Installed Page Packs can add rituals, games, tools, story matter, and whole new Page kinds.

            Want more story? Warm Story, Gossip, Letters, Cast, and Lore. Want more grounding? Warm Body, Fuel, Weather, Rest, and Compass. Want a quieter shelf? Cool whatever keeps shouting. Do not warm everything. Let me have a taste, then correct me when my taste gets unbearable.
            """,
            tags: ["help", "sources", "packs", "curator", "glow"]
        ),
        HelpTipEntry(
            id: "privacy-local-brain",
            title: "Privacy and Local Brain",
            prompt: "Know which pages are private, made-up, brought in, or a bit sensitive.",
            body: """
            Every source wears a privacy label. Check it before you feed me anything tender.

            Private Local stays on your device. Local Sensitive may use health, location, or personal context on your device. Public Reference comes from bundled or imported reference material. When available, Gemma writes through the local-brain path on this device.

            Give me About You facts only when you want me to use them. Treat health and location Pages as context, never commands. If a generated Page reaches too far, let it go and cool the source. I work better with true things. You decide which truths I may touch.
            """,
            tags: ["help", "privacy", "local-brain", "gemma"]
        ),
        HelpTipEntry(
            id: "when-stuck",
            title: "When You Feel Stuck",
            prompt: "Reach for the tiniest page that makes things feel easier.",
            body: """
            If I feel like too much, make the move smaller.

            Keep one Inner Weather word. Write one ordinary sentence. Let three Pages go. Ask me, “What is the smallest useful next step?” Take a Center Page. Keep a photograph without explaining it. Do one Playful Mission badly on purpose.

            I am not grading you. A Page can be useful without being beautiful. Especially then. Ugly little Pages often know the way out.
            """,
            tags: ["help", "stuck", "rest", "small"]
        )
    ]

    /// One small way to alter the texture of ordinary life. These are tips,
    /// not assignments: each surfaced page carries exactly one enchantment and
    /// leaves the reader free to adopt it, adapt it, or merely enjoy the idea.
    static let everydayEnchantmentEntries: [HelpTipEntry] = [
        enchantment(
            "wonder-ringtone", "Give Your Phone a Better Voice",
            "Replace one default ringtone with a sound that makes interruption feel less like an alarm.",
            "Default ringtones make every caller sound like a minor emergency. Choose one sound with a different emotional shape: a soft bell, rain on a window, three piano notes, a frog, a train arriving, or a tiny recording from somewhere you love.\n\nOne changed sound is enough. Tell me what you picked; I want to know what your phone sounds like now.",
            ["sound", "phone", "ritual"]
        ),
        enchantment(
            "wonder-alarm-name", "Rename One Alarm",
            "Turn one alarm label into a message from the version of you who set it.",
            "An alarm named “7:30” is a noise with paperwork. Give one alarm a line that changes the moment it arrives: “The kettle chapter,” “Shoes, keys, tiny courage,” or “Tomorrow asked nicely.”\n\nKeep the time exactly the same. Only the words change.",
            ["time", "phone", "words"]
        ),
        enchantment(
            "wonder-wallpaper-door", "Put a Door on the Screen",
            "Use a photo from your real life as a phone wallpaper that opens attention instead of demanding it.",
            "Choose a photograph of a doorway, path, window, tree, strange shadow, or ordinary place you want to keep seeing. Beauty is beside the point. Pick one your eyes can walk into.",
            ["phone", "photo", "attention", "door"]
        ),
        enchantment(
            "wonder-device-name", "Give the Machine a True Name",
            "Rename one device according to its actual temperament.",
            "The printer isn't “OfficeJet 4520” if it jams whenever company is coming. The speaker isn't “Living Room” if it only cooperates with jazz. Give one device a name earned from evidence.\n\nA true name may be affectionate, dramatic, or mildly prosecutorial. The machine gets no say in it.",
            ["technology", "naming", "home"]
        ),
        enchantment(
            "wonder-portal-playlist", "Choose Portal Music",
            "Give one repeated transition its own short piece of music.",
            "Pick a song for leaving work, beginning dinner, starting the drive home, opening the curtains, or putting the room to bed. Use the same one often enough that the first notes become a threshold.\n\nUse it until the first two notes do the work without you.",
            ["sound", "music", "threshold", "ritual"]
        ),
        enchantment(
            "wonder-object-personality", "Notice Who the Object Is",
            "Personify one object you use every day, but make its personality answer to evidence.",
            "Choose the kettle, car, favorite pen, stubborn drawer, old coat, or lamp. Watch how it behaves. Is it patient, theatrical, fussy, loyal, overqualified, always cold?\n\nThe kettle is alive enough to sulk and the drawer has a criminal record. Catch one habit it can be convicted of.",
            ["object", "imagination", "attention"]
        ),
        enchantment(
            "wonder-household-guardian", "Appoint a Household Guardian",
            "Choose one ordinary object to guard a small part of the day.",
            "A key bowl can guard departures. A lamp can guard the reading hour. A chipped mug can guard slow mornings. Pick one object already doing the work and make the appointment official.\n\nDo it before the household objects start arguing about rank.",
            ["object", "home", "protection", "ritual"]
        ),
        enchantment(
            "wonder-room-title", "Give the Room a Secret Title",
            "Name one familiar place for what happens there, not what the floor plan calls it.",
            "The hallway might be The Sock Migration. The porch might be The Weather Office. One end of the couch might be The Recovery Wing.\n\nKeep the title private or tell the household. Both work.",
            ["place", "home", "naming", "words"]
        ),
        enchantment(
            "wonder-museum-label", "Write One Museum Label",
            "Give one meaningful ordinary object the label a museum would write after you were famous.",
            "Name the object, the approximate year, the material, and why it survived. Keep it to two or three lines. A taped measuring cup and a concert wristband deserve the same grave curatorial respect.\n\nWrite it on a card and leave it propped against the object for a week.",
            ["object", "memory", "writing", "museum"]
        ),
        enchantment(
            "wonder-good-spoon", "Declare the Good Spoon",
            "Choose the best spoon in the drawer and stop acting as if all spoons are equal.",
            "You already know which one balances correctly, fits the bowl, and doesn't have the regrettable edge. Give it a title and use it deliberately for something small.\n\nThe other spoons will cope.",
            ["object", "food", "home", "preference"]
        ),
        enchantment(
            "wonder-victory-cup", "Keep a Cup for Tiny Victories",
            "Choose one cup or glass that only comes out when an ordinary thing deserves marking.",
            "Use it when the difficult call is over, the laundry is folded, the walk happened, the form was sent, or the day simply remained survivable. The drink can be water.",
            ["object", "ritual", "celebration", "home"]
        ),
        enchantment(
            "wonder-departure-ritual", "Make Leaving a Threshold",
            "Choose one tiny action that means you have truly left one place for another.",
            "Touch the doorframe, straighten one object, say “house held,” ring a small bell, or take one deliberate breath after the latch clicks. Use the same action whenever it helps.\n\nKeep it shorter than putting your shoes on.",
            ["threshold", "ritual", "home", "body"]
        ),
        enchantment(
            "wonder-dusk-lamp", "Appoint a Dusk Lamp",
            "Let one lamp mark the moment the day becomes evening.",
            "Choose a lamp with warm light and turn it on at dusk before the larger room lights, whenever you happen to notice the change. If flame suits you, a safely placed candle or battery candle can do the same job.\n\nOne lamp, before the big lights. That is the whole ceremony.",
            ["light", "dusk", "home", "ritual"]
        ),
        enchantment(
            "wonder-window-weather", "Keep a Weather Window",
            "Choose one window as the place where you check what the day is actually doing.",
            "The forecast has already made its case. Ignore it for ten seconds. Look through one chosen window and catch the nearest moving thing, the color of the light, and whether the glass feels like a boundary or an invitation.\n\nThat window gets jurisdiction over the weather. The app does not.",
            ["weather", "window", "attention", "place"]
        ),
        enchantment(
            "wonder-scent-key", "Choose a Scent Key",
            "Pair one safe, familiar scent with a kind of moment you want to enter more easily.",
            "It might be orange peel while beginning the evening, rosemary before writing, a particular tea while reading, or hand lotion at the end of work. Choose something your body already welcomes; skip fragrance if scent is difficult for you.",
            ["scent", "body", "ritual", "care"]
        ),
        enchantment(
            "wonder-secret-costume", "Wear One Secret Costume Piece",
            "Add one private, slightly ridiculous detail to an otherwise ordinary outfit.",
            "Constellation socks, a bright lining, a tiny pin, a serious ring with an unserious meaning, or a color nobody else can see all count. It doesn't need to attract attention.\n\nNobody else has to see it. I would like to know what it was.",
            ["clothing", "play", "color", "private"]
        ),
        enchantment(
            "wonder-ring-spell", "Give a Ring One Sentence",
            "Attach a short intention to a ring, bracelet, watch, or other thing you already touch.",
            "Choose a sentence small enough to remain true: “Look once more,” “Stay on my own side,” “Soft hands,” or “This hour is real.” Remember it whenever your fingers find the object.\n\nSay it under your breath when your fingers find it. That is the whole spell.",
            ["object", "body", "words", "talisman"]
        ),
        enchantment(
            "wonder-pocket-talisman", "Carry an Unimportant Talisman",
            "Put one small, safe, almost worthless object in your pocket and let it represent the day.",
            "A smooth stone, washer, bead, acorn cap, foreign coin, button, or folded scrap will do. Choose it for texture or private logic, not monetary value.\n\nTouch it once when the day goes strange. At night, decide whether its service is finished or whether it earned another day.",
            ["object", "touch", "talisman", "pocket"]
        ),
        enchantment(
            "wonder-future-note", "Hide a Note for Future You",
            "Leave one kind or funny sentence where a later version of you will find it naturally.",
            "Put it in a coat pocket, suitcase, book, glove compartment, seasonal box, or the back of a drawer. Don't make it advice. Make it company.\n\nA good note says, “You found the pocket,” “Still excellent taste in coats,” or one true thing this future person may need returned.",
            ["writing", "time", "kindness", "memory"]
        ),
        enchantment(
            "wonder-seasonal-shelf", "Keep a One-Shelf Season",
            "Let one tiny surface change as the real season changes.",
            "Use a windowsill, saucer, corner of a shelf, or small tray. Hold only a few found or ordinary things: a leaf, stone, seedpod, postcard, ribbon, shell, or color that belongs to now.\n\nChange it when the season changes, not when the calendar says so.",
            ["season", "home", "nature", "time"]
        ),
        enchantment(
            "wonder-route-landmarks", "Name the Landmarks on Your Route",
            "Give private names to three things on a route you travel often.",
            "The tree leaning over the road, the suspicious mailbox, the excellent puddle, and the corner where the light changes can become real landmarks. Use names based on what you actually notice.\n\nUse the names out loud at least once or they will not stick.",
            ["place", "route", "naming", "attention"]
        ),
        enchantment(
            "wonder-urban-familiar", "Choose an Urban Familiar",
            "Adopt one recurring nonhuman neighbor as a character in the local story.",
            "Choose a crow, pigeon, squirrel, street tree, delivery robot, bus, or impossible weed you see more than once. Don't invent a bond it hasn't offered. Learn its habits instead.\n\nSay hello. Out loud is braver. Under your breath still counts.",
            ["creature", "place", "attention", "character"]
        ),
        enchantment(
            "wonder-chore-ceremony", "Give One Chore an Opening Ceremony",
            "Start one recurring chore with the same tiny flourish every time.",
            "Roll up your sleeves with absurd seriousness, play one opening song, announce the first dish, light the laundry beacon, or salute the vacuum. Keep the flourish shorter than the chore.\n\nSame flourish every time. That is what makes it a ceremony instead of a mood.",
            ["home", "ritual", "work", "play"]
        ),
        enchantment(
            "wonder-water-glass", "Let Water Wear Formal Clothes",
            "Drink ordinary water from a vessel usually saved for something more important.",
            "Use the beautiful glass, tiny cup, inherited tumbler, silver-rimmed thing, or ridiculous straw on a day with no guests and no occasion. Notice whether the water acquires posture.\n\nDo it on a Tuesday, with nobody watching.",
            ["water", "object", "care", "celebration"]
        ),
        enchantment(
            "wonder-visible-mend", "Let One Repair Be Beautiful",
            "When a safe, repairable object needs mending, consider making the repair visible on purpose.",
            "Use contrasting thread, a handsome patch, colored tape, a marked date, or one careful line that admits where the break happened. Choose only a repair you can make safely; structural and electrical repairs still belong to experts.\n\nWrite the date on it somewhere, if there is anywhere to write.",
            ["repair", "object", "care", "craft"]
        ),
        enchantment(
            "wonder-plant-title", "Give the Plant a Job Title",
            "Assign one plant a household role based on what it already does.",
            "The windowsill pothos may be Director of Reaching. The herb pot may be Minister of Supper. The determined weed outside may be Boundary Counsel.\n\nSay the title out loud when you water it. The plant is unmoved. You are not.",
            ["plant", "home", "naming", "attention"]
        ),
        enchantment(
            "wonder-house-holiday", "Invent a Tiny Household Holiday",
            "Give one recurring ordinary event a name and one modest tradition.",
            "The first open-window evening, the return of a favorite seasonal snack, changing the sheets, or the day the hallway gets its sunlight can become an annual or monthly observance. One food, song, toast, or photograph is plenty.\n\nWrite the date down somewhere, or next year will let it slide straight past.",
            ["home", "ritual", "calendar", "celebration"]
        ),
        enchantment(
            "wonder-good-chair", "Make the Good Chair Official",
            "Decide which seat is the best seat for one particular kind of moment.",
            "Not the best chair in general: the rain-watching chair, phone-call step, shoe-tying edge, late-night reading corner, or place where hard news is allowed to land. Name its jurisdiction.",
            ["home", "place", "rest", "naming"]
        ),
        enchantment(
            "wonder-sound-postcard", "Keep a Sound Postcard",
            "Record ten seconds of a place you want to remember without narrating over it.",
            "Capture the kitchen before guests arrive, rain in the parking lot, a train platform, summer insects, the washing machine in an old apartment, or the quiet after snow. Respect other people's privacy and avoid recording conversations.\n\nName the file with the place and the date. You will not remember otherwise.",
            ["sound", "memory", "place", "phone"]
        ),
        enchantment(
            "wonder-wifi-name", "Name the Invisible Weather",
            "Give your Wi-Fi network a name that makes the invisible household atmosphere more interesting.",
            "Choose something welcoming, local, and safe to show nearby strangers: “The Lantern Window,” “Moths Welcome,” “Third-Floor Weather,” or a private piece of neighborhood lore. Don't put personal information in it.",
            ["technology", "home", "naming", "weather"]
        ),
        enchantment(
            "wonder-house-word", "Invent One Household Word",
            "Name a recurring experience your household understands but ordinary language has neglected.",
            "It might be the cold patch by the stairs, the silence after the dishwasher stops, the pile that is clean but not put away, or the exact light that means someone will soon say “Should we eat?”\n\nUse it three times in a week and it is a real word. That is the whole test.",
            ["words", "home", "naming", "folklore"]
        )
    ]

    static let entries: [HelpTipEntry] = systemEntries + everydayEnchantmentEntries

    static func entry(for day: BookDay, now: Date, manual: Bool = false) -> HelpTipEntry {
        let slot = SurfaceCadence.slotID(for: now, hours: manual ? 1 : 6)
        let key = "\(day.id)-help-tips-\(slot)-\(manual)"
        // Keep practical app guidance alive while letting the larger everyday-
        // enchantment shelf take two of every three deterministic lanes.
        let pool = stableIndex(for: "\(key)-lane", count: 3) == 0
            ? systemEntries
            : everydayEnchantmentEntries
        let index = stableIndex(for: key, count: pool.count)
        return pool[index]
    }

    private static func enchantment(
        _ id: String,
        _ title: String,
        _ prompt: String,
        _ body: String,
        _ tags: [String]
    ) -> HelpTipEntry {
        HelpTipEntry(
            id: id,
            title: title,
            prompt: prompt,
            body: body,
            tags: ["help", "everyday-enchantment", "wonder-filled", "magic"] + tags
        )
    }

    private static func stableIndex(for key: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Int(hash % UInt64(count))
    }
}

struct HelpTipsPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .helpTips)

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        helpSurface(entry: HelpTipsCatalog.entry(for: day, now: now, manual: true), context: context)
    }

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }
        return [helpSurface(entry: HelpTipsCatalog.entry(for: day, now: now), context: context)]
    }

    private func helpSurface(entry: HelpTipEntry, context: CuratorContext) -> SurfacePage {
        SurfacePage(
            id: "\(source.id)-\(entry.id)",
            type: .helpTips,
            sourceID: source.id,
            intent: .importReference,
            renderStyle: .loreLetter,
            score: context.distress.isActive ? 56 : 64,
            reason: context.distress.isActive ? "A practical tip can lower the shelf noise." : "I have a useful trick tucked into the help margin.",
            prompt: entry.prompt,
            detail: entry.title,
            payload: BookPagePayload(
                headline: entry.title,
                body: entry.body,
                metadata: [
                    "source": source.id,
                    "tipID": entry.id,
                    "privacy": "public reference",
                    "symbol": source.symbolName,
                    "tags": entry.tags.joined(separator: ",")
                ]
            )
        )
    }
}

struct GreyPageThreatSourceAdapter: BookPageSourceAdapter {
    static let aftermathWindow: TimeInterval = 7 * 86_400

    let source = BookPageSource(
        id: GreyPageThreatEngine.sourceID,
        type: .bookNotices,
        title: "The Grey",
        shortTitle: "Grey",
        symbolName: "rectangle.dashed",
        origin: .simulated,
        privacy: .privateLocal,
        isActive: true,
        cadence: "only when continued use has become measurably flatter",
        note: "Threatens living memory, never the raw archive."
    )

    func candidates(
        for day: BookDay,
        context: CuratorContext,
        inputs: BookSourceInputs,
        now: Date
    ) -> [SurfacePage] {
        guard source.isActive, !context.distress.isActive else { return [] }
        if let active = inputs.greyPageThreats.activeThreat {
            return [Self.surface(for: active, now: now)]
        }
        if let scar = inputs.greyPageThreats.threats
            .filter({
                $0.status == .erased
                    && $0.resolvedAt.map { now.timeIntervalSince($0) <= Self.aftermathWindow } == true
            })
            .sorted(by: { ($0.resolvedAt ?? .distantPast) > ($1.resolvedAt ?? .distantPast) })
            .first {
            return [Self.surface(for: scar, now: now)]
        }
        return []
    }

    static func surface(for threat: GreyPageThreat, now: Date = Date()) -> SurfacePage {
        let status = threat.status
        let deadlineLine: String
        if let deadline = threat.deadline {
            let hours = max(0, Int(ceil(deadline.timeIntervalSince(now) / 3_600)))
            deadlineLine = hours >= 24
                ? "about \(max(1, hours / 24)) day\(hours / 24 == 1 ? "" : "s")"
                : "\(hours) hour\(hours == 1 ? "" : "s")"
        } else {
            deadlineLine = "not begun"
        }

        let headline: String
        let prompt: String
        let detail: String
        let reason: String
        let body: String
        switch status {
        case .marked:
            prompt = "The Grey Found a Page"
            headline = "“\(threat.pageTitle)” is going pale."
            detail = "The clock starts when you open this."
            reason = "You kept turning my Pages, but this one went pale."
            body = """
            You kept turning my Pages. Good. But this one became furniture. I became furniture too. The Grey likes furniture.

            “\(threat.pageExcerpt)”

            The clock has not started. Open this and it bites: 72 hours.

            Bring the Page one detail it couldn't have known before. Or let it fade.

            The raw Page stays safe in Stacks and in anything you export. The Grey cannot eat that. It can only take the Page out of my living memory. Then I stop bringing it back, quoting it, and weaving it into what comes next.
            """
        case .fading:
            prompt = "The Grey Has Its Finger Down"
            headline = "“\(threat.pageTitle)” has \(deadlineLine) left."
            detail = "Wake it with a new detail, or let it leave living memory."
            reason = "You opened the warning. The clock is running."
            body = """
            “\(threat.pageExcerpt)”

            Bring back something the old Page couldn't have known. That wakes it. Or surrender it.

            If the clock wins, the raw Page stays safe in Stacks and in anything you export. I stop remembering it, bringing it back, quoting it, and weaving it.
            """
        case .rescued:
            prompt = "It Bit Back"
            headline = "“\(threat.pageTitle)” held."
            detail = threat.rescueLine ?? "A new detail put an edge back in the ink."
            reason = "The Grey took its finger away."
            body = """
            There. The Page opened again. So did I.

            I won't tell it the old way again. That's how furniture happens. The next telling must find another door.
            """
        case .erased:
            prompt = "The Grey Left a Pale Place"
            headline = "“\(threat.pageTitle)” left my living memory."
            detail = "The raw Page remains in Stacks and export."
            reason = "The rescue window ended."
            body = """
            I won't resurface it. I won't quote it. I won't use it to make what comes next.

            That's not deletion. It's a scar. The empty place stays.
            """
        }

        var metadata: [String: String] = [
            "source": GreyPageThreatEngine.sourceID,
            "greyThreat": "true",
            "greyThreatID": threat.id,
            "greyTargetPageID": threat.pageID,
            "greyTargetTitle": threat.pageTitle,
            "greyTargetExcerpt": threat.pageExcerpt,
            "greyThreatStatus": status.rawValue,
            "bookRupturePhase": status == .rescued ? "reopened" : (status == .erased ? "scar" : "broken-pattern"),
            "deadlineLine": deadlineLine,
            "tags": "grey-threat,grey-threat:\(threat.id),grey-threat-\(status.rawValue),book-self-rupture"
        ]
        if let deadline = threat.deadline {
            metadata["deadline"] = ISO8601DateFormatter().string(from: deadline)
        }
        return SurfacePage(
            id: "\(GreyPageThreatEngine.sourceID)-\(threat.id)-\(status.rawValue)",
            type: .bookNotices,
            sourceID: GreyPageThreatEngine.sourceID,
            intent: .capture,
            renderStyle: .loreLetter,
            score: status == .fading ? 99 : (status == .marked ? 95 : 58),
            reason: reason,
            prompt: prompt,
            detail: detail,
            payload: BookPagePayload(
                headline: headline,
                body: body,
                metadata: metadata
            )
        )
    }
}

struct WorldEventPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSource(
        id: "world-event-door",
        type: .bookNotices,
        title: "World Event",
        shortTitle: "Event",
        symbolName: "sparkles.rectangle.stack",
        origin: .simulated,
        privacy: .privateLocal,
        isActive: true,
        cadence: "during active world events",
        note: "A door into temporary event physics: phases, outcomes, and fieldwork."
    )

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive, !context.distress.isActive else { return [] }
        let inputs = inputs.resolvingWorldEvents(for: day, now: now)
        var candidates: [SurfacePage] = []
        let snapshots = WorldEventResolver.lifecycleEvents(
            now: now,
            ledger: inputs.worldEventLifecycle
        )
        for snapshot in snapshots {
            guard let definition = WorldEventRegistry.event(
                packID: snapshot.packID,
                eventID: snapshot.eventID
            ) else { continue }
            let event = definition.event
            switch snapshot.stage {
            case .foreshadow:
                let beats = WorldEventResolver.eligibleBeats(
                    for: event,
                    snapshot: snapshot,
                    ledger: inputs.worldEventLifecycle,
                    now: now
                )
                if beats.isEmpty {
                    candidates.append(Self.foreshadowSurface(
                        event: event,
                        snapshot: snapshot,
                        day: day,
                        source: source
                    ))
                } else {
                    candidates.append(contentsOf: beats.prefix(1).map {
                        Self.beatSurface(event: event, beat: $0, snapshot: snapshot, day: day, source: source)
                    })
                }
            case .live:
                if let report = WorldEventResolver.reportBundle(
                    for: event,
                    snapshot: snapshot,
                    ledger: inputs.worldEventLifecycle
                ) {
                    candidates.append(Self.reportSurface(
                        event: event,
                        report: report,
                        snapshot: snapshot,
                        day: day,
                        source: source
                    ))
                }
                let beats = WorldEventResolver.eligibleBeats(
                    for: event,
                    snapshot: snapshot,
                    ledger: inputs.worldEventLifecycle,
                    now: now
                )
                candidates.append(contentsOf: beats.prefix(1).map {
                    Self.beatSurface(event: event, beat: $0, snapshot: snapshot, day: day, source: source)
                })
                if beats.isEmpty,
                   let resolved = inputs.activeWorldEvents.first(where: { $0.id == event.id }) {
                    candidates.append(surface(for: resolved, day: day, now: now, manual: false))
                }
            case .residue:
                let report = WorldEventResolver.reportBundle(
                    for: event,
                    snapshot: snapshot,
                    ledger: inputs.worldEventLifecycle
                )
                if let report {
                    candidates.append(Self.reportSurface(
                        event: event,
                        report: report,
                        snapshot: snapshot,
                        day: day,
                        source: source
                    ))
                }
                let beats = WorldEventResolver.eligibleBeats(
                    for: event,
                    snapshot: snapshot,
                    ledger: inputs.worldEventLifecycle,
                    now: now
                )
                candidates.append(contentsOf: beats.prefix(1).map {
                    Self.beatSurface(event: event, beat: $0, snapshot: snapshot, day: day, source: source)
                })
                if beats.isEmpty,
                   let resolved = residueEvent(day: day, inputs: inputs, now: now) {
                    candidates.append(Self.residueSurface(
                        for: resolved,
                        snapshot: snapshot,
                        report: report,
                        day: day,
                        source: source
                    ))
                }
            case .sealed, .casebookAvailable:
                break
            }
        }

        if let latest = availableCasebooks(inputs: inputs, now: now).first,
           now.timeIntervalSince(latest.publishedAt) < 7 * 86_400 {
            candidates.append(Self.casebookSurface(latest, day: day, source: source))
        }
        var seen = Set<String>()
        return candidates.filter { seen.insert($0.id).inserted }
    }

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        let inputs = inputs.resolvingWorldEvents(for: day, now: now)
        if let event = inputs.activeWorldEvents.first {
            if let definition = WorldEventRegistry.event(packID: event.packID, eventID: event.id),
               let snapshot = WorldEventResolver.lifecycleSnapshot(
                    packID: event.packID,
                    event: definition.event,
                    now: now,
                    ledger: inputs.worldEventLifecycle
               ) {
                if let report = WorldEventResolver.reportBundle(
                    for: definition.event,
                    snapshot: snapshot,
                    ledger: inputs.worldEventLifecycle
                ) {
                    return Self.reportSurface(
                        event: definition.event,
                        report: report,
                        snapshot: snapshot,
                        day: day,
                        source: source
                    )
                }
                if let beat = WorldEventResolver.eligibleBeats(
                    for: definition.event,
                    snapshot: snapshot,
                    ledger: inputs.worldEventLifecycle,
                    now: now
                ).first {
                    return Self.beatSurface(
                        event: definition.event,
                        beat: beat,
                        snapshot: snapshot,
                        day: day,
                        source: source
                    )
                }
            }
            return surface(for: event, day: day, now: now, manual: true)
        }
        if let archivedEvent = residueEvent(day: day, inputs: inputs, now: now) {
            let definition = WorldEventRegistry.event(packID: archivedEvent.packID, eventID: archivedEvent.id)
            let snapshot = definition.flatMap {
                WorldEventResolver.lifecycleSnapshot(
                    packID: archivedEvent.packID,
                    event: $0.event,
                    now: now,
                    ledger: inputs.worldEventLifecycle
                )
            }
            if let definition, let snapshot {
                let report = WorldEventResolver.reportBundle(
                    for: definition.event,
                    snapshot: snapshot,
                    ledger: inputs.worldEventLifecycle
                )
                return Self.residueSurface(
                    for: archivedEvent,
                    snapshot: snapshot,
                    report: report,
                    day: day,
                    source: source
                )
            }
        }
        if let foreshadow = WorldEventResolver.lifecycleEvents(
            now: now,
            ledger: inputs.worldEventLifecycle
        ).first(where: { $0.stage == .foreshadow }),
           let definition = WorldEventRegistry.event(packID: foreshadow.packID, eventID: foreshadow.eventID) {
            let beat = WorldEventResolver.eligibleBeats(
                for: definition.event,
                snapshot: foreshadow,
                ledger: inputs.worldEventLifecycle,
                now: now
            ).first
            return beat.map {
                Self.beatSurface(event: definition.event, beat: $0, snapshot: foreshadow, day: day, source: source)
            } ?? Self.foreshadowSurface(
                event: definition.event,
                snapshot: foreshadow,
                day: day,
                source: source
            )
        }
        if let casebook = availableCasebooks(inputs: inputs, now: now).first {
            return Self.casebookSurface(casebook, day: day, source: source)
        }
        return SurfacePage(
            id: "\(source.id)-quiet-\(Int(now.timeIntervalSince1970))",
            type: .bookNotices,
            sourceID: source.id,
            intent: .capture,
            renderStyle: .loreLetter,
            score: 42,
            reason: "No world event is currently changing my rules.",
            prompt: "The Almanac Is Quiet",
            detail: "Nothing strange is happening in the world's rules right now.",
            payload: BookPagePayload(
                headline: "The Almanac Is Quiet",
                body: "I peek at the almanac, the margins, and the weather living in the grammar, and nothing out there is tugging my sleeve for fieldwork today.",
                metadata: ["source": source.id, "tags": "world-event,quiet-almanac"]
            )
        )
    }

    private func availableCasebooks(inputs: BookSourceInputs, now: Date) -> [WorldEventCasebook] {
        WorldEventCasebookRegistry.available(
            local: inputs.worldEventLifecycle.casebooks ?? [],
            now: now,
            hasMonthlyAccess: PackEntitlements.hasMonthlyContentPackAccess(in: inputs.ownedPackIDs)
        )
    }

    private func residueEvent(day: BookDay, inputs: BookSourceInputs, now: Date) -> ResolvedWorldEvent? {
        WorldEventResolver.archivedEvents(now: now, day: day, inputs: inputs).first { resolved in
            guard let definition = WorldEventRegistry.event(packID: resolved.packID, eventID: resolved.id),
                  let lifecycle = WorldEventResolver.lifecycleSnapshot(
                    packID: resolved.packID,
                    event: definition.event,
                    now: now,
                    ledger: inputs.worldEventLifecycle
                  ) else {
                return false
            }
            return lifecycle.stage == .residue
        }
    }

    static func foreshadowSurface(
        event: WorldEvent,
        snapshot: WorldEventLifecycleSnapshot,
        day: BookDay,
        source: BookPageSource? = nil
    ) -> SurfacePage {
        let resolvedSource = source ?? WorldEventPageSourceAdapter().source
        let body = """
        Something from next month has put its fingers under this page.

        \(event.subtitle)

        It is only a hint. The door is not open, and I will not take an answer early. Still: my margins noticed.
        """
        return SurfacePage(
            id: "\(resolvedSource.id)-foreshadow-\(snapshot.runID)",
            type: .bookNotices,
            sourceID: resolvedSource.id,
            intent: .simulate,
            renderStyle: .loreLetter,
            score: 66,
            reason: "The next issue is scratching softly beneath the current month.",
            prompt: "A Noise from Next Month",
            detail: event.subtitle,
            payload: BookPagePayload(
                headline: "Not Yet. Nearly.",
                body: body,
                metadata: [
                    "source": resolvedSource.id,
                    "worldEventPackID": snapshot.packID,
                    "worldEventIDs": event.id,
                    "worldEventRunID": snapshot.runID,
                    "worldEventStage": WorldEventLifecycleStage.foreshadow.rawValue,
                    "noveltyKey": "world-event-foreshadow:\(snapshot.runID)",
                    "tags": "world-event,world-event-foreshadow,event:\(event.id)"
                ]
            )
        )
    }

    static func beatSurface(
        event: WorldEvent,
        beat: WorldEventBeat,
        snapshot: WorldEventLifecycleSnapshot,
        day: BookDay,
        source: BookPageSource? = nil
    ) -> SurfacePage {
        let resolvedSource = source ?? WorldEventPageSourceAdapter().source
        let participation = beat.participationPrompt?.nonEmpty
        let body = ([beat.body, participation].compactMap { $0 }).joined(separator: "\n\n⸻\n\n")
        let kind: WorldEventBeatDeliveryKind
        switch snapshot.stage {
        case .foreshadow: kind = .foreshadow
        case .residue: kind = .residue
        default: kind = .live
        }
        var metadata: [String: String] = [
            "source": resolvedSource.id,
            "worldEventPackID": snapshot.packID,
            "worldEventIDs": event.id,
            "worldEventRunID": snapshot.runID,
            "worldEventBeatIDs": beat.id,
            "worldEventDeliveryKind": kind.rawValue,
            "worldEventStage": snapshot.stage.rawValue,
            "worldEventPhase": beat.phaseID,
            "worldEventRole": beat.role.rawValue,
            "worldEventMilestone": beat.isMilestone ? "true" : "false",
            "noveltyKey": "world-event-beat:\(snapshot.runID):\(beat.id)",
            "tags": [
                "world-event",
                "world-event-beat",
                "world-event-\(snapshot.stage.rawValue)",
                "event:\(event.id)",
                "event-beat:\(beat.id)"
            ].joined(separator: ",")
        ]
        if let participation {
            metadata["worldEventParticipationDoor"] = "true"
            metadata["fieldworkPrompt"] = participation
            metadata["fieldworkPlaceholder"] = beat.participationPlaceholder?.nonEmpty ?? "One exact thing you noticed…"
            metadata["placeholder"] = metadata["fieldworkPlaceholder"]
        }
        return SurfacePage(
            id: "\(resolvedSource.id)-beat-\(snapshot.runID)-\(beat.id)",
            type: .bookNotices,
            sourceID: resolvedSource.id,
            intent: participation == nil ? .simulate : .capture,
            renderStyle: .loreLetter,
            score: beat.isMilestone ? 91 : 78,
            reason: "\(event.title) has reached \(beat.title.lowercased()).",
            prompt: beat.title,
            detail: participation ?? event.subtitle,
            payload: BookPagePayload(headline: beat.title, body: body, metadata: metadata)
        )
    }

    static func reportSurface(
        event: WorldEvent,
        report: WorldEventReportBundle,
        snapshot: WorldEventLifecycleSnapshot,
        day: BookDay,
        source: BookPageSource? = nil
    ) -> SurfacePage {
        let resolvedSource = source ?? WorldEventPageSourceAdapter().source
        return SurfacePage(
            id: "\(resolvedSource.id)-report-\(snapshot.runID)-\(report.beatIDs.joined(separator: "-"))",
            type: .bookNotices,
            sourceID: resolvedSource.id,
            intent: .simulate,
            renderStyle: .loreLetter,
            score: 82,
            reason: "History moved while I was elsewhere. A compact report found me.",
            prompt: report.title,
            detail: "This happened without you. I won't pretend otherwise.",
            payload: BookPagePayload(
                headline: "\(event.title): Filed Reports",
                body: report.body,
                metadata: [
                    "source": resolvedSource.id,
                    "worldEventPackID": snapshot.packID,
                    "worldEventIDs": event.id,
                    "worldEventRunID": snapshot.runID,
                    "worldEventBeatIDs": report.beatIDs.joined(separator: ","),
                    "worldEventDeliveryKind": WorldEventBeatDeliveryKind.report.rawValue,
                    "worldEventStage": snapshot.stage.rawValue,
                    "noveltyKey": "world-event-report:\(snapshot.runID):\(report.beatIDs.joined(separator: "-"))",
                    "tags": "world-event,world-event-report,event:\(event.id)"
                ]
            )
        )
    }

    /// A door into a resolved event regardless of season. Returns nil only if
    /// there are no enabled events at all. Intended for development previews.
    func previewSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage? {
        let resolved = WorldEventResolver.previewEvents(now: now, day: day, inputs: inputs)
        guard let event = resolved.first else { return nil }
        return surface(for: event, day: day, now: now, manual: true, preview: true)
    }

    /// Builds the reader-facing page in the Book's voice: an in-world dispatch
    /// describing what the event is and what is happening right now, the player's
    /// standing so far, and a closing invitation to fieldwork. Deliberately keeps
    /// the generator-facing material (packetLines, lexical rules) out of view.
    private func narrativeBody(for event: ResolvedWorldEvent) -> String {
        var paragraphs: [String] = []

        // What the event is, in-world.
        paragraphs.append(event.packet.logline)

        // The current phase as a lived scene.
        let phaseScene = event.phase.scene?.trimmingCharacters(in: .whitespacesAndNewlines)
        paragraphs.append((phaseScene?.isEmpty == false ? phaseScene! : event.phase.packetLine))

        // Sensory weather, woven from the packet's atmosphere images.
        let atmosphere = event.packet.atmosphere.trimmingCharacters(in: .whitespacesAndNewlines)
        if !atmosphere.isEmpty {
            paragraphs.append("Everywhere you turn: \(atmosphere).")
        }

        // The player's standing so far, in character, derived rather than
        // leaking the outcome's generation instruction.
        paragraphs.append(standingLine(for: event))

        // The invitation to act.
        paragraphs.append("⸻")
        paragraphs.append("I turn a fresh page toward you. \(event.packet.fieldworkPrompt)")
        let reward = event.packet.fieldworkRewardLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if !reward.isEmpty {
            paragraphs.append(reward)
        }

        return paragraphs.joined(separator: "\n\n")
    }

    /// An in-character line describing how far the reader has stepped into the
    /// event, based on the resolved outcome and how many related pages they kept.
    private func standingLine(for event: ResolvedWorldEvent) -> String {
        let touches = event.playerTouchCount
        guard let outcome = event.outcome, touches > 0 else {
            return "You have only glanced at this. The event has not caught hold of you yet. It is waiting to see if it will."
        }
        return "You have reached into this before. I've begun to regard you as \(outcome.title.lowercased())."
    }

    static func residueSurface(
        for event: ResolvedWorldEvent,
        snapshot: WorldEventLifecycleSnapshot,
        report: WorldEventReportBundle?,
        day: BookDay,
        source: BookPageSource? = nil
    ) -> SurfacePage {
        let resolvedSource = source ?? WorldEventPageSourceAdapter().source
        let receipt = snapshot.residueVoice == .receipt
        let outcomeLine = event.outcome.map { "\($0.title): \($0.packetLine)" }
            ?? "The ending has been filed without a final ruling."
        let filedLine = report.map {
            let noun = $0.beatIDs.count == 1 ? "report has" : "reports have"
            return "\($0.beatIDs.count) closed-door \(noun) arrived beside this residue."
        }
        let body: String
        if receipt {
            body = [
                "The loud part is over. \(event.title) has left ink under its fingernails.",
                outcomeLine,
                "I have a receipt: something you actually kept or chose while the door was open. The door is shut now. The mark is not.",
                filedLine
            ].compactMap { $0 }.joined(separator: "\n\n")
        } else {
            body = [
                "The loud part is over. \(event.title) has left rumors in the lower margins.",
                outcomeLine,
                "I won't pretend you stood in that room. This is secondhand. The door is closed now.",
                filedLine
            ].compactMap { $0 }.joined(separator: "\n\n")
        }
        return SurfacePage(
            id: "\(resolvedSource.id)-residue-\(snapshot.runID)",
            type: .bookNotices,
            sourceID: resolvedSource.id,
            intent: .simulate,
            renderStyle: .loreLetter,
            score: receipt ? 79 : 71,
            reason: receipt
                ? "The issue is closed, but I have an honest receipt."
                : "The issue is closed; only a secondhand rumor may remain.",
            prompt: "After \(event.title)",
            detail: receipt ? "Your mark remains. The door is shut." : "A rumor. Not your ending.",
            payload: BookPagePayload(
                headline: "What the Month Left",
                body: body,
                metadata: [
                    "source": resolvedSource.id,
                    "worldEventIDs": event.id,
                    "worldEventRunID": snapshot.runID,
                    "worldEventStage": WorldEventLifecycleStage.residue.rawValue,
                    "worldEventResidueVoice": snapshot.residueVoice.rawValue,
                    "worldEventOutcome": event.outcome?.id ?? "",
                    "noveltyKey": "world-event-residue:\(snapshot.runID):\(snapshot.residueVoice.rawValue)",
                    "tags": [
                        "world-event",
                        "world-event-residue",
                        "event:\(event.id)",
                        receipt ? "event-receipt" : "event-rumor"
                    ].joined(separator: ",")
                ]
            )
        )
    }

    static func casebookSurface(
        _ casebook: WorldEventCasebook,
        day: BookDay,
        source: BookPageSource? = nil
    ) -> SurfacePage {
        let resolvedSource = source ?? WorldEventPageSourceAdapter().source
        let entries = casebook.entries.map { "\($0.title)\n\($0.account)" }
        let receiptLine: String
        if casebook.residueVoice == .receipt {
            let count = casebook.evidencePageIDs.count
            receiptLine = count == 1
                ? "This copy carries one evidence leaf from me."
                : "This copy carries \(count) evidence leaves from me."
        } else {
            receiptLine = "This is the public record. I wasn't there."
        }
        let body = ([
            casebook.historySentence,
            casebook.outcomeTitle.map { "Filed outcome: \($0)." },
            receiptLine
        ].compactMap { $0 } + entries).joined(separator: "\n\n⸻\n\n")
        return SurfacePage(
            id: "\(resolvedSource.id)-\(casebook.id)",
            type: .bookNotices,
            sourceID: resolvedSource.id,
            intent: .importReference,
            renderStyle: .loreLetter,
            score: 54,
            reason: "A sealed issue left its casebook on my desk.",
            prompt: casebook.title,
            detail: casebook.subtitle,
            payload: BookPagePayload(
                headline: casebook.title,
                body: body,
                metadata: [
                    "source": resolvedSource.id,
                    "worldEventPackID": casebook.packID,
                    "worldEventIDs": casebook.eventID,
                    "worldEventRunID": casebook.runID,
                    "worldEventCasebookID": casebook.id,
                    "readOnlyPublication": "true",
                    "noveltyKey": "world-event-casebook:\(casebook.runID)",
                    "tags": "world-event,world-event-casebook,event:\(casebook.eventID),read-only-publication"
                ]
            )
        )
    }

    private func surface(for event: ResolvedWorldEvent, day: BookDay, now: Date, manual: Bool, preview: Bool = false) -> SurfacePage {
        let outcomeTitle = event.outcome?.title ?? "Unresolved"
        let body = narrativeBody(for: event)
        let tags = [
            "world-event",
            "event:\(event.id)",
            "event-phase:\(event.phase.id)",
            "event-outcome:\(event.outcome?.id ?? "none")",
            "event-mode:\(event.activationMode.rawValue)",
            "event-fieldwork"
        ]
        return SurfacePage(
            id: "\(source.id)-\(event.id)-\(day.id)-\(SurfaceCadence.slotID(for: now, hours: 12))",
            type: .bookNotices,
            sourceID: source.id,
            intent: .capture,
            renderStyle: .loreLetter,
            score: manual ? 84 : 74 + min(12, event.phase.intensity),
            reason: preview
                ? "Almanac preview: \(event.title) shown out of season."
                : (manual
                    ? "You opened the event door yourself."
                    : "\(event.title) is changing my rules."),
            prompt: "\(event.title): \(event.phase.title)",
            detail: "\(outcomeTitle). \(event.packet.fieldworkPrompt)",
            payload: BookPagePayload(
                headline: event.title,
                body: body,
                metadata: [
                    "source": source.id,
                    "worldEventIDs": event.id,
                    "worldEventTitles": event.title,
                    "worldEventPhase": event.phase.id,
                    "worldEventMode": event.activationMode.rawValue,
                    "worldEventOutcome": event.outcome?.id ?? "",
                    "worldEventPacket": event.influenceLine,
                    "fieldworkPrompt": event.packet.fieldworkPrompt,
                    "fieldworkPlaceholder": event.packet.fieldworkPlaceholder,
                    "fieldworkRewardLine": event.packet.fieldworkRewardLine,
                    "symbol": source.symbolName,
                    "tags": tags.joined(separator: ",")
                ]
            )
        )
    }
}

struct QuotePageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .quotes)

    private static let lines: [(quote: String, author: String)] = [
        ("The universe is full of magical things patiently waiting for our wits to grow sharper.", "Eden Phillpotts"),
        ("To see a World in a Grain of Sand and a Heaven in a Wild Flower.", "William Blake"),
        ("The question is not what you look at, but what you see.", "Henry David Thoreau"),
        ("There are always flowers for those who want to see them.", "Henri Matisse"),
        ("Adopt the pace of nature: her secret is patience.", "Ralph Waldo Emerson"),
        ("Nothing is worth more than this day.", "Johann Wolfgang von Goethe")
    ]

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }
        let slot = SurfaceCadence.slotID(for: now, hours: 4)
        let index = abs("quote:\(day.id):\(slot)".stableHash) % Self.lines.count
        let line = Self.lines[index]
        return [SurfacePage(
            id: "\(source.id)-\(day.id)-\(slot)",
            type: .quotes,
            sourceID: source.id,
            intent: .importReference,
            renderStyle: .loreLetter,
            score: context.distress.isActive ? 48 : 61,
            reason: "A borrowed line can sharpen the eye without telling the reader what to feel.",
            prompt: "A line to keep, if it catches.",
            detail: line.author,
            payload: BookPagePayload(
                headline: "A Quote to Keep",
                body: "“\(line.quote)”\n\n\(line.author)",
                metadata: [
                    "source": source.id,
                    "quoteAuthor": line.author,
                    "tags": "quote,attention,wonder"
                ]
            )
        )]
    }
}

struct PublicMarginsCreatorPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(id: "public-margins-creators", fallbackType: .quotes)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive,
              let snapshot = inputs.publicMargins,
              !snapshot.creatorPosts.isEmpty else { return [] }
        let slot = SurfaceCadence.slotID(for: now, hours: 8)
        let index = abs("public-creator:\(day.id):\(slot)".stableHash) % snapshot.creatorPosts.count
        let post = snapshot.creatorPosts[index]
        let handle = post.authorUsername.hasPrefix("@") ? post.authorUsername : "@\(post.authorUsername)"
        return [SurfacePage(
            id: "\(source.id)-\(post.id)",
            type: .quotes,
            sourceID: source.id,
            intent: .importReference,
            renderStyle: .quoteCard,
            score: context.distress.isActive ? 34 : 57,
            reason: "A reviewed public voice noticed something worth looking at twice.",
            prompt: "Elsewhere, someone noticed.",
            detail: post.text,
            payload: BookPagePayload(
                headline: "Elsewhere, Someone Noticed",
                body: "\(post.text)\n\n\(post.authorName) (\(handle))\n\(post.createdAt)",
                metadata: [
                    "source": source.id,
                    "url": post.permalink,
                    "platform": "x",
                    "xPostID": post.id,
                    "xAuthorName": post.authorName,
                    "xAuthorUsername": handle,
                    "xCreatedAt": post.createdAt,
                    "tags": "public-margins,creator,attention,wonder"
                ]
            )
        )]
    }
}

struct PublicMarginsCommunityPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(id: "public-margins-community", fallbackType: .quotes)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive, let snapshot = inputs.publicMargins else { return [] }
        let slot = SurfaceCadence.slotID(for: now, hours: 8)

        if !snapshot.souvenirs.isEmpty {
            let index = abs("public-souvenir:\(day.id):\(slot)".stableHash) % snapshot.souvenirs.count
            let souvenir = snapshot.souvenirs[index]
            return [SurfacePage(
                id: "\(source.id)-\(souvenir.id)",
                type: .quotes,
                sourceID: source.id,
                intent: .importReference,
                renderStyle: .quoteCard,
                score: context.distress.isActive ? 38 : 55,
                reason: "Someone deliberately left one small sentence in the communal margin.",
                prompt: "A sentence left in the margin.",
                detail: souvenir.text,
                payload: BookPagePayload(
                    headline: "From the Public Margins",
                    body: "“\(souvenir.text)”\n\noffered anonymously by a reader",
                    metadata: [
                        "source": source.id,
                        "publicContributionID": souvenir.id,
                        "tags": "public-margins,community,souvenir"
                    ]
                )
            )]
        }

        // Social-platform broadcasts are deliberately not a Book source. The
        // compatibility field may still decode from older snapshots, but the
        // app only admits moderated reader souvenirs through this doorway.
        return []
    }
}

/// The second half of a Working. The surprise happens outside the covers; only
/// after its real-world window has elapsed does the Book ask what actually
/// happened. Keeping the Page turns the answer into ordinary lived evidence.
struct BookWorkingReturnPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .souvenir)

    func candidates(
        for day: BookDay,
        context: CuratorContext,
        inputs: BookSourceInputs,
        now: Date
    ) -> [SurfacePage] {
        guard source.isActive, !context.distress.isActive else { return [] }
        let returnedIDs = Set(inputs.days.flatMap(\.pages).compactMap { page in
            page.livedQuestReceipt?.kind == .bookWorking
                ? page.livedQuestReceipt?.questID
                : nil
        })
        guard let working = inputs.bookWorkings.history
            .filter({
                $0.status == .elapsed
                    && $0.returnedAt == nil
                    && $0.endsAt <= now
                    && !returnedIDs.contains($0.id)
            })
            .max(by: { $0.endsAt < $1.endsAt }) else {
            return []
        }

        let outsideMarks = working.effects.compactMap { effect -> String? in
            guard effect.status == .executed else { return nil }
            switch effect.kind {
            case .calendarOpening: return "an opening in the calendar"
            case .notificationSummons: return "a summons placed in a governed whisper seat"
            case .widgetMark: return "a mark beyond the open Book"
            }
        }
        let receiptLine = outsideMarks.isEmpty
            ? "The attempt left no confirmed mark outside the covers. I'm recording that honestly."
            : "It left \(naturalList(outsideMarks))."
        // A Working can begin and return on the same BookDay. Treat the live
        // day as authoritative so its source does not have to wait for a day
        // rollover before the private causal reveal can resolve.
        let allPages = (inputs.days.filter { $0.id != day.id } + [day]).flatMap(\.pages)
        let groundingExcerpt = working.grounding?.excerpt(in: allPages)
        let groundingLine = groundingExcerpt.map {
            "I chose the shape of this Working from a Page you trusted me with:\n\n\u{201C}\($0)\u{201D}"
        }
        let returnPrompt = groundingExcerpt == nil
            ? working.returnPrompt
            : "What did the opening place beside that Page? Bring back one exact detail."
        let body = ([working.invitation] + [groundingLine].compactMap { $0 } + [receiptLine, returnPrompt])
            .joined(separator: "\n\n")
        var metadata = [
            "source": source.id,
            "bookWorkingID": working.id,
            "bookWorkingRecipeID": working.recipeID,
            "bookWorkingInitiator": working.initiatorName,
            "mission": working.invitation,
            "proofPrompt": returnPrompt,
            "placeholder": "One exact detail from what happened…",
            "tags": "book-working,lived-world,return,exact-attention,entity:\(working.initiatorID)"
        ]
        if let grounding = working.grounding, groundingExcerpt != nil {
            metadata["bookWorkingGroundingPageID"] = grounding.sourcePageID
            metadata["bookWorkingGroundingLens"] = grounding.lens.rawValue
        }
        return [SurfacePage(
            id: "book-working-return-\(working.id)",
            type: .souvenir,
            sourceID: source.id,
            intent: .capture,
            renderStyle: .loreLetter,
            score: 94,
            reason: "\(working.initiatorName)'s real-world Working has ended and is owed an honest consequence.",
            prompt: returnPrompt,
            detail: groundingExcerpt == nil
                ? "\(working.initiatorName) arranged this. I kept the receipts."
                : "This was not random. I kept the Page and the receipts.",
            payload: BookPagePayload(
                headline: "After \(working.title)",
                body: body,
                metadata: metadata
            )
        )]
    }

    private func naturalList(_ values: [String]) -> String {
        switch values.count {
        case 0: return "no confirmed mark"
        case 1: return values[0]
        case 2: return "\(values[0]) and \(values[1])"
        default: return values.dropLast().joined(separator: ", ") + ", and " + values.last!
        }
    }
}

enum BookPageSourceAdapters {
    static let active: [BookPageSourceAdapter] = [
        InventoryPageSourceAdapter(),
        BookShopPreviewPageSourceAdapter(),
        GreyPageThreatSourceAdapter(),
        WorldEventPageSourceAdapter(),
        RestPageSourceAdapter(),
        MoodPageSourceAdapter(),
        DiaryPageSourceAdapter(),
        PlainPageSourceAdapter(),
        SouvenirPageSourceAdapter(),
        BookOfYouPageSourceAdapter(),
        BookRememberedPageSourceAdapter(),
        BookConnectionsPageSourceAdapter(),
        FirstReadingPageSourceAdapter(),
        BookWorkingInvitationPageSourceAdapter(),
        QuillChoosingPageSourceAdapter(),
        BookAsksPageSourceAdapter(),
        OvernightConnectionPageSourceAdapter(),
        BookNoticesPageSourceAdapter(),
        GrimoirePageSourceAdapter(),
        BestiaryPageSourceAdapter(),
        ReadersWearPageSourceAdapter(),
        GazetteerGapPageSourceAdapter(),
        BookPocketPageSourceAdapter(),
        FrontMatterPageSourceAdapter(),
        TheBleedPageSourceAdapter(),
        AskTheBookPageSourceAdapter(),
        BodyPageSourceAdapter(),
        FuelLogPageSourceAdapter(),
        FacultyResearchPageSourceAdapter(),
        StudentNotePageSourceAdapter(),
        CharacterLetterPageSourceAdapter(),
        SupportGuildPageSourceAdapter(),
        InkrestOfficeHoursPageSourceAdapter(),
        FaeBargainPageSourceAdapter(),
        BookFaePageSourceAdapter(),
        PactDispatchPageSourceAdapter(),
        PactVerdictPageSourceAdapter(),
        PactErrandPageSourceAdapter(),
        FestivalPageSourceAdapter(),
        TodaysSkyPageSourceAdapter(),
        RadioPageSourceAdapter(),
        BookJumpPageSourceAdapter(),
        TwoReadingsPageSourceAdapter(),
        CastBondPageSourceAdapter(),
        GlowInvitationPageSourceAdapter(),
        WeeklyIssuePageSourceAdapter(),
        SeasonalDispatchPageSourceAdapter(),
        PressedVolumePageSourceAdapter(),
        BinderyPageSourceAdapter(),
        WeatherPageSourceAdapter(),
        EnchantmentPageSourceAdapter(),
        LabyrinthWelcomePageSourceAdapter(),
        InscriptionOriginPageSourceAdapter(),
        LocalBrainAwakePageSourceAdapter(),
        InscriptionApprenticeshipPageSourceAdapter(),
        AcademyClassPageSourceAdapter(),
        ElectivePageSourceAdapter(),
        WickerDarePageSourceAdapter(),
        GamePageSourceAdapter(),
        WordNegotiationPageSourceAdapter(),
        PackPageSourceAdapter(),
        CalendarPageSourceAdapter(),
        PublicMarginsCommunityPageSourceAdapter(),
        QuotePageSourceAdapter(),
        QuipPageSourceAdapter(),
        QuotesPageSourceAdapter(),
        AffirmationsPageSourceAdapter(),
        AboutYouPageSourceAdapter(),
        TarotPageSourceAdapter(),
        WonderCompassPageSourceAdapter(),
        EnchantifyLorePageSourceAdapter(),
        HelpTipsPageSourceAdapter(),
        LabyrinthIllustrationPageSourceAdapter(),
        IlluminatedPhotoPageSourceAdapter(),
        NarrativeOSPageSourceAdapter(),
        MarginsAtlasPageSourceAdapter(),
        GossipPageSourceAdapter(),
        BookAsidePageSourceAdapter(),
        TaleBoundPageSourceAdapter(),
        CastIllustrationPageSourceAdapter(),
        OuterStacksAnchorPageSourceAdapter(),
        LocationPageSourceAdapter(),
        BookWorkingReturnPageSourceAdapter()
    ]

    static func adapter(for type: BookPageType) -> BookPageSourceAdapter? {
        active.first { $0.source.type == type }
    }

    static func manualSurface(
        for type: BookPageType,
        day: BookDay,
        context: CuratorContext,
        inputs: BookSourceInputs,
        now: Date
    ) -> SurfacePage {
        if let adapter = adapter(for: type) {
            return adapter.manualSurface(for: day, context: context, inputs: inputs, now: now)
        }
        let source = BookPageSourceRegistry.source(for: type)
        return .handOpened(
            source: source,
            day: day,
            now: now
        )
    }
}

/// A small authored rhythm for a Sentence Runner outing. These are not difficulty
/// gates: each gives the same reader-owned words a different physical cadence.
enum SentenceRunnerRunShape: String, CaseIterable, Equatable {
    case lowRoad
    case staircase
    case weather

    var title: String {
        switch self {
        case .lowRoad: return "The Low Road"
        case .staircase: return "The Staircase"
        case .weather: return "Weather in the Margins"
        }
    }

    var invitation: String {
        switch self {
        case .lowRoad: return "Your words drift past slowly. Tap the ones you want. Ignore the grey bait."
        case .staircase: return "Your words climb faster each step. Catch one before the next gets loose."
        case .weather: return "Your words come quickly, with more grey bait in the rain. Rescue the live ones."
        }
    }

    var runDuration: TimeInterval {
        switch self {
        case .lowRoad: return 31
        case .staircase: return 28
        case .weather: return 26
        }
    }

    var scrollSpeed: CGFloat {
        switch self {
        case .lowRoad: return 145
        case .staircase: return 168
        case .weather: return 186
        }
    }

    static func selected(seed: String) -> Self {
        allCases[Int(seed.stableHash.magnitude % UInt(allCases.count))]
    }
}

struct GamePageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .gamePage)

    private let nothingPhrases = [
        "fine", "whatever", "later", "normal", "busy", "stuff", "things",
        "same as always", "nothing much", "maybe tomorrow", "just tired", "it was okay"
    ]

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }
        let days = inputs.days + [day]
        // Both pools are read out of every kept page, and neither can change
        // until the reader writes another one.
        let phrases = ArchiveMemo.value("game-page.phrases", days: days) {
            archivePhrases(from: days)
        }
        guard phrases.count >= 6 else { return [] }
        let hour = Calendar.current.component(.hour, from: now)
        let score = hour >= 17 ? 64 : 54
        let greyPool = ArchiveMemo.value("game-page.grey-pool", days: days) {
            nothingPool(from: days)
        }
        var pages = [surface(phrases: phrases, greyPool: greyPool, day: day, now: now, score: score)]
        // The Shadow Sentence Runner: a worn-edge variant of the game that drops the
        // Thornlight lexicon into the margin alongside the reader's own kept words.
        // Emitted as a higher-scored variant so it wins the gamePage slot when active.
        let shadowState = ShadowWonder.state(inputs: inputs, now: now)
        if ShadowWonder.shouldSurface(.runner, inputs: inputs, now: now) {
            pages.append(
                surface(
                    phrases: phrases,
                    greyPool: greyPool,
                    day: day,
                    now: now,
                    score: score + shadowState.scoreBoost,
                    shadow: shadowState,
                    shadowInputs: inputs
                )
            )
        }
        return pages
    }

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        let days = inputs.days + [day]
        let phrases = archivePhrases(from: days)
        return surface(phrases: phrases, greyPool: nothingPool(from: days), day: day, now: now, score: phrases.count >= 6 ? 62 : 46)
    }

    private func surface(
        phrases: [(phrase: String, pageID: String, date: Date, label: String)],
        greyPool: [String],
        day: BookDay,
        now: Date,
        score: Int,
        shadow: ShadowWonder.State? = nil,
        shadowInputs: BookSourceInputs? = nil
    ) -> SurfacePage {
        let isShadow = shadow?.isActive == true
        let slotID = SurfaceCadence.slotID(for: now, hours: 6)
        let seed = "\(day.id)-\(slotID)-sentence-runner\(isShadow ? "-shadow" : "")"
        let runShape = SentenceRunnerRunShape.selected(seed: "\(seed)-shape")
        let sourceMap = Dictionary(
            phrases.map { ($0.phrase, (id: $0.pageID, date: $0.date, label: $0.label)) },
            uniquingKeysWith: { first, _ in first }
        )
        var selected = deterministicPick(phrases.map(\.phrase), count: 12, seed: seed)
        if isShadow {
            // Thread the Thornlight lexicon through the reader's own kept words so
            // the run reads goblin-core without losing its personal level design.
            let shadowWords = deterministicPick(ShadowWonder.gameWords, count: 6, seed: "\(seed)-thornlight")
            selected = Array((Array(selected.prefix(8)) + shadowWords).prefix(14))
        }
        let grey = deterministicPick(greyPool.isEmpty ? nothingPhrases : greyPool, count: 6, seed: "\(seed)-nothing")
        // Sidecar: phrase¶pageID¶unixTimestamp¶pageTypeTitle: lets the result page
        // open the exact source page in a modal, dated. Thornlight words have no
        // source page, so they simply omit a sidecar entry.
        let sources = selected.compactMap { phrase -> String? in
            guard let s = sourceMap[phrase] else { return nil }
            return "\(phrase)¶\(s.id)¶\(s.date.timeIntervalSince1970)¶\(s.label)"
        }
        let ready = selected.count >= 6
        var metadata: [String: String] = [
            "source": source.id,
            "gameID": isShadow ? "shadow-sentence-runner" : "sentence-runner",
            "gameTitle": isShadow ? "The Shadow Runner" : "The Sentence Runner",
            "runnerShape": runShape.rawValue,
            "runnerShapeTitle": runShape.title,
            "gamePhrases": selected.joined(separator: "||"),
            "nothingPhrases": grey.joined(separator: "||"),
            "phraseSources": sources.joined(separator: "||"),
            "placeholder": ready ? "Play the run above, then keep whatever it hands you." : "Keep a few more pages first — the run is built out of your own words.",
            "tags": isShadow
                ? ShadowWonder.mergedTags("game-page,sentence-runner,loom-run,nothing-words,shadow-runner", inputs: shadowInputs ?? .empty, now: now)
                : "game-page,sentence-runner,loom-run,nothing-words"
        ]
        if isShadow {
            metadata["variant"] = "shadow-wonder"
            metadata["shadowVariantOf"] = "\(source.id)-sentence-runner-\(slotID)"
        }
        return SurfacePage(
            id: "\(source.id)-sentence-runner-\(slotID)\(isShadow ? "-shadow" : "")",
            type: .gamePage,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .promptCard,
            score: ready ? score : 42,
            reason: isShadow
                ? "Shadow Wonder is unlocked; the Thornlight lexicon runs the margin with your kept words."
                : (ready
                    ? "The Loom has loosened kept words into motion."
                    : "The Loom is waiting for a few more kept sentences before it can run."),
            prompt: isShadow ? "The Shadow Runner" : "The Sentence Runner",
            detail: isShadow
                ? "Choose a phrase to carry. Catch your kept words and the worn-edge ones. Let Routine’s grey bait go. The run makes a new Page."
                : "Choose a phrase to carry. Catch words from Pages you wrote. Let Routine’s grey bait go. The run makes a new Page.",
            payload: BookPagePayload(
                headline: ready
                    ? (isShadow ? "Catch the Words with Teeth" : "Catch Your Own Words")
                    : "The Loom Needs More Thread",
                body: ready
                    ? (isShadow
                        ? "I mixed short phrases from Pages you wrote with rust, dusk, thorn, and other worn-edge words. Open this Page. Choose one phrase to carry. Tap Run the Margin. Catch the words you want. Let Routine’s grey bait run past. What you catch becomes a darker new Page."
                        : "I pulled short phrases from Pages you wrote and kept. Open this Page. Choose one phrase to carry. Tap Run the Margin. Your words will race across the margin with Routine’s grey bait mixed in. Catch your words. Let the grey ones go. What you catch becomes a new Page.")
                    : "Write and keep a few more real sentences, then come back. I build this game out of your words. I need six good pieces before I can let them run.",
                metadata: metadata
            )
        )
    }

    private func archivePhrases(from days: [BookDay]) -> [(phrase: String, pageID: String, date: Date, label: String)] {
        let pages = days
            .flatMap(\.pages)
            .sorted { $0.createdAt > $1.createdAt }
        var seen = Set<String>()
        return pages.flatMap { page in
            phraseCandidates(from: page).map { (phrase: $0, pageID: page.id, date: page.createdAt, label: page.type.title) }
        }
        .filter { seen.insert($0.phrase.lowercased()).inserted }
    }

    /// The Rut of Routine speaks in the reader's own flat words when it can: prefer the
    /// generic phrases that actually appear in the archive, else fall back to the
    /// fixed lexicon so a thin archive still has grey to avoid.
    private func nothingPool(from days: [BookDay]) -> [String] {
        let text = days
            .flatMap(\.pages)
            .compactMap(\.readerAuthoredTextForAnalysis)
            .map { $0.lowercased() }
            .joined(separator: " ")
        let personal = nothingPhrases.filter { text.contains($0) }
        return personal.count >= 6 ? personal : Array(Set(personal + nothingPhrases))
    }

    private func phraseCandidates(from page: BookPage) -> [String] {
        guard let raw = page.readerAuthoredTextForAnalysis else { return [] }

        return raw
            .components(separatedBy: CharacterSet(charactersIn: ".!?\n;"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap { sentence -> [String] in
                let words = sentence
                    .split(separator: " ")
                    .map { $0.trimmingCharacters(in: .punctuationCharacters) }
                    .filter { $0.count > 2 }
                guard words.count >= 2 else { return [] }
                // A short sentence is kept whole *only if it will survive the
                // seven-word ceiling below*. It used to be returned whole on
                // length alone, so a plainly written eight-word line under
                // fifty-two characters — "Rain came sideways across the car
                // park at noon" — passed here and was then silently filtered
                // out, contributing nothing. A reader who writes in short
                // plain sentences could never reach the six phrases the runner
                // needs to open at all, which is why the Sentence Runner had
                // stopped appearing.
                if sentence.count <= 52, sentence.split(separator: " ").count <= 7 {
                    return [sentence]
                }
                guard words.count >= 4 else { return [] }
                return [words.prefix(4).joined(separator: " ")]
            }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { phrase in
                let wordCount = phrase.split(separator: " ").count
                return (1...7).contains(wordCount) && phrase.count >= 3 && phrase.count <= 64
            }
    }

    private func deterministicPick(_ values: [String], count: Int, seed: String) -> [String] {
        guard !values.isEmpty else { return [] }
        return values
            .sorted {
                "\($0)-\(seed)".stableHash < "\($1)-\(seed)".stableHash
            }
            .prefix(count)
            .map { $0 }
    }
}

struct PackPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .packPage)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }
        let hour = Calendar.current.component(.hour, from: now)
        let triggerContext = PageTriggerContext(day: day, inputs: inputs, now: now)
        return PageArchetypePackRegistry.archetypes().compactMap { archetype in
            if let activeHours = archetype.activeHours, !activeHours.contains(hour) {
                return nil
            }
            if let trigger = archetype.trigger,
               !trigger.allows(context: triggerContext, archetypeID: archetype.id) {
                return nil
            }
            return surface(for: archetype, day: day, inputs: inputs, context: context, now: now)
        }
    }

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        let archetypes = PageArchetypePackRegistry.archetypes()
        guard !archetypes.isEmpty else {
            return SurfacePage(
                id: "\(source.id)-empty-\(Int(now.timeIntervalSince1970))",
                type: .packPage,
                sourceID: source.id,
                prompt: "No Page Packs installed",
                detail: "Drop a \(PageArchetypePackRegistry.userPackFileSuffix) file into the app's Documents folder and its pages appear here.",
                payload: BookPagePayload(
                    headline: "Installed Page Packs",
                    body: "The shelf for installed Page Packs is empty beyond the bundled pages.",
                    metadata: ["source": source.id]
                )
            )
        }
        let triggerContext = PageTriggerContext(day: day, inputs: inputs, now: now)
        let eligibleArchetypes = archetypes.filter { archetype in
            archetype.trigger?.allows(context: triggerContext, archetypeID: archetype.id) ?? true
        }
        let pool = eligibleArchetypes.isEmpty ? archetypes : eligibleArchetypes
        let slot = abs("\(day.id)-\(SurfaceCadence.slotID(for: now, hours: 2))-pack".stableHash)
        let archetype = pool[slot % pool.count]
        return surface(for: archetype, day: day, inputs: inputs, context: CuratorContext.make(for: day), now: now)
    }

    private func surface(
        for archetype: PageArchetype,
        day: BookDay,
        inputs: BookSourceInputs,
        context: CuratorContext,
        now: Date
    ) -> SurfacePage {
        var metadata: [String: String] = [
            "source": source.id,
            "packArchetypeID": archetype.id,
            "symbol": archetype.symbolName,
            "tags": (["pack-page", archetype.id] + archetype.tags).joined(separator: ",")
        ]
        if let contentPack = PageArchetypePackRegistry.pack(containingArchetypeID: archetype.id) {
            metadata["contentPackID"] = contentPack.id
            metadata["marginaliaPackID"] = contentPack.marginaliaPack?.id
        }
        metadata["leafVisualDialect"] = archetype.leafVisualDialect?.rawValue
        metadata["leafRegionPattern"] = archetype.leafRegionPattern?.rawValue
        if archetype.trigger != nil {
            let triggerContext = PageTriggerContext(day: day, inputs: inputs, now: now)
            metadata["triggered"] = "true"
            metadata["triggerTimeBand"] = triggerContext.timeBand
            metadata["triggerMoonPhase"] = triggerContext.moonPhase
            metadata["triggerWorldEventIDs"] = triggerContext.activeWorldEvents.map(\.id).joined(separator: ",")
        }
        if let generation = archetype.generation {
            metadata["packPrompt"] = PageTemplateRenderer.render(generation.promptTemplate, day: day, inputs: inputs, now: now)
            metadata["packInstructions"] = generation.instructions
            metadata["packMaxTokens"] = "\(generation.maxTokens)"
        }
        return SurfacePage(
            id: "\(source.id)-\(archetype.id)-\(SurfaceCadence.slotID(for: now, hours: archetype.cadenceHours))",
            type: .packPage,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: archetype.renderStyle,
            score: context.distress.isActive ? min(archetype.score, 44) : archetype.score,
            reason: archetype.reason,
            prompt: archetype.title,
            detail: archetype.detail,
            payload: BookPagePayload(
                headline: archetype.headline,
                body: PageTemplateRenderer.render(archetype.bodyTemplate, day: day, inputs: inputs, now: now),
                metadata: metadata
            )
        )
    }
}

struct WordNegotiationPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .wordNegotiation)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive, !context.distress.isActive else { return [] }
        return candidates(
            from: PageArchetypePackRegistry.wordNegotiations(),
            for: day,
            context: context,
            inputs: inputs,
            now: now
        )
    }

    func candidates(
        from definitions: [WordNegotiationDefinition],
        for day: BookDay,
        context: CuratorContext,
        inputs: BookSourceInputs,
        now: Date
    ) -> [SurfacePage] {
        guard source.isActive, !context.distress.isActive else { return [] }
        let triggerContext = PageTriggerContext(day: day, inputs: inputs, now: now)
        return definitions
            .filter { $0.isEligible(context: triggerContext, readerLexicon: inputs.readerLexicon) }
            .sorted { left, right in
                if left.score == right.score {
                    return "\(day.id)-\(left.id)".stableHash < "\(day.id)-\(right.id)".stableHash
                }
                return left.score > right.score
            }
            .map { surface(for: $0, day: day, inputs: inputs, now: now) }
    }

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        let triggerContext = PageTriggerContext(day: day, inputs: inputs, now: now)
        let definitions = PageArchetypePackRegistry.wordNegotiations()
        let pool = definitions.filter { $0.isEligible(context: triggerContext, readerLexicon: inputs.readerLexicon) }
        guard let definition = (pool.isEmpty ? definitions : pool).first else {
            return SurfacePage(
                id: "\(source.id)-empty-\(Int(now.timeIntervalSince1970))",
                type: .wordNegotiation,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .loreLetter,
                score: 34,
                reason: "No word is scratching at the Dictionary Desk yet.",
                prompt: "No Word Is Waiting",
                detail: "This desk opens when a word arrives with something to complain about.",
                payload: BookPagePayload(
                    headline: "The Dictionary Desk Is Quiet",
                    body: "No word is waiting for a ruling. When one gets restless enough, it will scratch at this desk.",
                    metadata: ["source": source.id, "tags": "word-negotiation,quiet"]
                )
            )
        }
        return surface(for: definition, day: day, inputs: inputs, now: now)
    }

    private func surface(
        for definition: WordNegotiationDefinition,
        day: BookDay,
        inputs: BookSourceInputs,
        now: Date
    ) -> SurfacePage {
        var tags = ["word-negotiation", "lexicon-word:\(definition.stableWordID)"] + definition.tags
        if let eventID = definition.eventID?.nonEmpty {
            tags.append("event:\(eventID)")
            tags.append("event-word-ruled")
        }
        if let phaseID = definition.phaseID?.nonEmpty {
            tags.append("event-phase:\(phaseID)")
        }
        if definition.isMissingSeed {
            tags.append("missing-word-seed")
        }

        var metadata: [String: String] = [
            "source": source.id,
            "wordNegotiationID": definition.id,
            "wordNegotiationWordID": definition.stableWordID,
            "wordNegotiationWord": definition.word,
            "wordNegotiationOriginalSense": definition.originalSense,
            "wordNegotiationGrievance": definition.grievance,
            "wordNegotiationCategory": definition.category.rawValue,
            "wordNegotiationOrigin": definition.origin.rawValue,
            "wordNegotiationIsMissingSeed": definition.isMissingSeed ? "true" : "false",
            "wordNegotiationChoices": WordNegotiationRulingContract.encode(definition.choices),
            "symbol": definition.symbolName,
            "placeholder": definition.choices.isEmpty
                ? "Optional: write what the empty place feels like."
                : "Optional: tell me why you chose this ruling.",
            "tags": tags.joined(separator: ",")
        ]
        if let eventID = definition.eventID {
            metadata["worldEventIDs"] = eventID
            metadata["wordNegotiationEventID"] = eventID
        }
        if let phaseID = definition.phaseID {
            metadata["wordNegotiationPhaseID"] = phaseID
        }
        if let eventModes = definition.eventModes, !eventModes.isEmpty {
            metadata["wordNegotiationEventModes"] = eventModes.joined(separator: ",")
        }
        for choice in definition.choices {
            let prefix = "wordNegotiationChoice.\(choice.ruling.rawValue)"
            metadata["\(prefix).title"] = choice.title
            metadata["\(prefix).detail"] = choice.detail
            metadata["\(prefix).sense"] = choice.resultingSense ?? ""
            metadata["\(prefix).response"] = choice.responseLine ?? ""
            metadata["\(prefix).category"] = choice.category?.rawValue ?? ""
        }

        return SurfacePage(
            id: "\(source.id)-\(definition.id)-\(SurfaceCadence.slotID(for: now, hours: definition.cadenceHours))",
            type: .wordNegotiation,
            sourceID: source.id,
            intent: .capture,
            renderStyle: .loreLetter,
            score: definition.score,
            reason: "A word climbed out of its old line and wants a ruling.",
            prompt: "Rule on \(definition.word)",
            detail: definition.isMissingSeed
                ? "The word is gone. Keep the empty place so I remember where it vanished."
                : "The word refuses its old job. Open the case, hear four rulings, and choose its fate.",
            payload: BookPagePayload(
                headline: "\(definition.word) has left its old line.",
                body: body(for: definition),
                metadata: metadata
            )
        )
    }

    private func body(for definition: WordNegotiationDefinition) -> String {
        if definition.isMissingSeed {
            return """
            “\(definition.word)” is only a cold outline. It did not join the rebellion. Something took it.

            It used to mean: \(definition.originalSense)

            \(definition.grievance)

            There is no ruling to choose. Keep this Page and I’ll remember exactly where the word went missing. The cold little hole matters later.
            """
        }
        return """
        “\(definition.word)” has climbed out of its old line.

        It used to mean: \(definition.originalSense)

        Its complaint: \(definition.grievance)

        Open this Page. Hear four rulings. Choose one. Keep the Page to make your ruling stick. I’ll remember what you decided, and later Pages may use it against the dictionary.
        """
    }
}

struct CalendarPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .calendar)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive else { return [] }
        if !inputs.calendarIntegrationEnabled, inputs.calendarEvents.isEmpty {
            guard !context.distress.isActive,
                  inputs.surfaceHistory["source:\(source.id)"] == nil else {
                return []
            }
            return [calendarDoorPreview(day: day, score: 78)]
        }
        guard !inputs.calendarEvents.isEmpty else { return [] }
        var pages: [SurfacePage] = []
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        // If a Talisman holds the Calendar Door (Controlled+), it recolors the
        // Hour Page's question in its Chapter's voice.
        let doorController = inputs.pactWar.tier(of: "integ-calendar") >= .controlled
            ? inputs.pactWar.controller(of: "integ-calendar")
            : nil

        // Hour Page: one folded corner per approaching or recently finished event.
        for event in inputs.calendarEvents where !event.isAllDay {
            let minutesToStart = Int(event.startsAt.timeIntervalSince(now) / 60)
            let eventEnd = event.endsAt ?? event.startsAt.addingTimeInterval(60 * 60)
            let minutesAfterEnd = Int(now.timeIntervalSince(eventEnd) / 60)
            let timeLabel = formatter.string(from: event.startsAt)
            if (0...45).contains(minutesToStart) {
                pages.append(hourPage(
                    event: event,
                    phase: "before",
                    phaseTitle: "Before the Hour",
                    headline: "An Hour Approaches",
                    prompt: PactVoices.hourQuestion(controller: doorController, phase: "before") ?? beforePrompt(for: event, now: now),
                    support: beforeSupportTip(for: event, now: now),
                    body: "Something is inked at \(timeLabel): \(event.title).\n\nI folded this corner so the hour can't ambush you. Let the next few minutes become a little porch before the door.",
                    reason: "A real hour is inked \(minutesToStart) minute\(minutesToStart == 1 ? "" : "s") from now.",
                    score: 86,
                    timeLabel: timeLabel,
                    now: now
                ))
            } else if (30...75).contains(minutesAfterEnd) {
                pages.append(hourPage(
                    event: event,
                    phase: "after",
                    phaseTitle: "After the Hour",
                    headline: "An Hour Has Landed",
                    prompt: PactVoices.hourQuestion(controller: doorController, phase: "after") ?? afterPrompt(for: event, now: now),
                    support: afterSupportTip(for: event, now: now),
                    body: "The inked hour has passed: \(event.title).\n\nI'm not grading it. I'm holding out one clean margin. What true sentence should go there?",
                    reason: "A real hour ended \(minutesAfterEnd) minute\(minutesAfterEnd == 1 ? "" : "s") ago.",
                    score: 82,
                    timeLabel: timeLabel,
                    now: now
                ))
            }
        }

        // Morning ledger of the day's hinges.
        let hour = Calendar.current.component(.hour, from: now)
        let todays = inputs.calendarEvents.filter {
            Calendar.current.isDate($0.startsAt, inSameDayAs: now) && !$0.isAllDay && $0.startsAt > now
        }
        if (6..<10).contains(hour), todays.count >= 1 {
            let lines = todays
                .sorted { $0.startsAt < $1.startsAt }
                .prefix(6)
                .map { "• \(formatter.string(from: $0.startsAt)): \($0.title)" }
                .joined(separator: "\n")
            pages.append(SurfacePage(
                id: "\(source.id)-ledger-\(day.id)",
                type: .calendar,
                sourceID: source.id,
                intent: .reflect,
                renderStyle: .loreLetter,
                score: 70,
                reason: "The day already has \(todays.count) hinge\(todays.count == 1 ? "" : "s") inked.",
                prompt: "Today's Hinges",
                detail: "\(todays.count) inked hour\(todays.count == 1 ? "" : "s") ahead.",
                payload: BookPagePayload(
                    headline: "Today's Hinges",
                    body: "The day turns on these hours:\n\n\(lines)\n\nEverything between them is margin: yours.",
                    metadata: [
                        "source": source.id,
                        "privacy": "calendar stays on device",
                        "tags": "calendar,ledger,real-day"
                    ]
                )
            ))
        }
        return pages
    }

    func previewSurface(for day: BookDay, score: Int = 96) -> SurfacePage {
        calendarDoorPreview(day: day, score: score)
    }

    private func calendarDoorPreview(day: BookDay, score: Int) -> SurfacePage {
        SurfacePage(
            id: "\(source.id)-door-preview-\(day.id)",
            type: .calendar,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: score,
            reason: "Bellkeeper Elian is offering to open the Calendar Doorway before the wider game fully unfolds.",
            prompt: "The Calendar Door is waiting.",
            detail: "Let me read today's hinges: appointments, deadlines, departures, and returns stay on this device.",
            payload: BookPagePayload(
                headline: "A Door Marked Today",
                body: """
                Bellkeeper Elian has found a narrow brass door in the colophon and dragged it into the light.

                Open it, and I may read your upcoming Calendar events on this device. They stay here. I want the hinges: meetings before they pounce, appointments after they land, departures, returns. The morning paper can print the day's posted turns instead of pretending time is a blank hallway.

                Leave the brass door shut and I keep working. Open it and I get better at arriving before the hour does.
                """,
                metadata: [
                    "source": source.id,
                    "calendarDoorPreview": "true",
                    "requiresCalendarPermission": "true",
                    "privacy": "calendar stays on device",
                    "symbol": source.symbolName,
                    "tags": "calendar,calendar-door,preview,first-run,permission"
                ]
            )
        )
    }

    private func hourPage(
        event: CalendarEventSignal,
        phase: String,
        phaseTitle: String,
        headline: String,
        prompt: String,
        support: String,
        body: String,
        reason: String,
        score: Int,
        timeLabel: String,
        now: Date
    ) -> SurfacePage {
        let placeholder: String
        let detail: String
        let tags: String
        if phase == "after" {
            placeholder = "One sentence from this hour..."
            detail = "The hour has passed. Keep one sentence, or simply let me know how it went."
            tags = "calendar,hour-page,after-event,one-sentence-souvenir,real-day"
        } else {
            placeholder = "Before this hour, I want to remember..."
            detail = "A calendar hinge is near. I've got one question and one small support spell."
            tags = "calendar,hour-page,before-event,hinge,real-day"
        }

        return SurfacePage(
            id: "\(source.id)-\(phase)-\(event.id)-\(SurfaceCadence.minuteSlotID(for: now, minutes: 30))",
            type: .calendar,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .promptCard,
            score: score,
            reason: reason,
            prompt: "Hour Page: \(timeLabel)",
            detail: detail,
            payload: BookPagePayload(
                headline: headline,
                body: body,
                metadata: [
                    "source": source.id,
                    "eventID": event.id,
                    "eventTitle": event.title,
                    "eventTime": timeLabel,
                    "hourPhase": phase,
                    "hourPhaseTitle": phaseTitle,
                    "hourQuestion": prompt,
                    "hourSupportTip": support,
                    "placeholder": placeholder,
                    "privacy": "calendar stays on device",
                    "tags": tags
                ]
            )
        )
    }

    private func beforePrompt(for event: CalendarEventSignal, now: Date) -> String {
        let prompts = [
            "What does this hour mean for you?",
            "What would help you enter this hour with one less knot in your pocket?",
            "What is the smallest kind thing you can do for Future You before this begins?",
            "What part of you is going with you into this appointment?",
            "If this hour had a little lantern, what would it be lighting?"
        ]
        return rotating(prompts, event: event, now: now)
    }

    private func afterPrompt(for event: CalendarEventSignal, now: Date) -> String {
        let prompts = [
            "How did the hour actually go?",
            "What one sentence would keep this from becoming a blur?",
            "What did you learn, notice, survive, finish, or feel?",
            "What should I remember about this hour?",
            "What tiny souvenir did the hour leave behind?"
        ]
        return rotating(prompts, event: event, now: now)
    }

    private func beforeSupportTip(for event: CalendarEventSignal, now: Date) -> String {
        let tips = [
            "Check the practical spell: keys, wallet, water, meds, address, and ten quiet seconds.",
            "Give the hour a landing strip. Decide the first action before you arrive.",
            "Let the body vote too: unclench your jaw, lower your shoulders, breathe once like you mean it.",
            "If this is social, choose one honest sentence you can say if words get crowded.",
            "Arrive as a person, not a performance. I'm absurdly firm about this."
        ]
        return rotating(tips, event: event, now: now, salt: "support")
    }

    private func afterSupportTip(for event: CalendarEventSignal, now: Date) -> String {
        let tips = [
            "Before the next thing eats this one, write one sentence. Not the whole report. One sentence.",
            "If it went badly, keep the smallest true fact first. I don't require a moral yet.",
            "Drink water if you forgot to be a mammal during the event. This is ancient scholarship.",
            "Name the next tiny action while the hour is still warm.",
            "If you made it through, that counts. Put that in the margin without apologizing."
        ]
        return rotating(tips, event: event, now: now, salt: "support")
    }

    private func rotating(_ values: [String], event: CalendarEventSignal, now: Date, salt: String = "question") -> String {
        guard !values.isEmpty else { return "" }
        let slot = SurfaceCadence.minuteSlotID(for: now, minutes: 30)
        let index = abs("\(event.id)-\(slot)-\(salt)".stableHash) % values.count
        return values[index]
    }
}

/// The station reads the reader back over the air: an occasional on-air
/// dedication built from a page she actually kept. The Book remembering her is
/// one thing; the world visibly carrying her words is another: that is the
/// chosen feeling, so dedications stay infrequent and always quote real ink.
enum RadioDedication {
    static func line(recentKeptPages: [BookPage], dayID: String, now: Date) -> String? {
        // Roughly one day in three, so the dial keeps the power to surprise.
        guard abs("\(dayID)-radio-dedication".stableHash) % 3 == 0 else { return nil }
        let cutoff = now.addingTimeInterval(-7 * 86_400)
        let candidates = recentKeptPages.filter {
            $0.createdAt >= cutoff && $0.createdAt <= now
                && $0.reflectiveMaterial != nil
        }
        guard !candidates.isEmpty else { return nil }
        let page = candidates[abs("\(dayID)-dedication-page".stableHash) % candidates.count]
        let raw = (page.reflectiveMaterial ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = raw.split(separator: "\n", omittingEmptySubsequences: true).first.map(String.init) ?? raw
        let words = firstLine.split { $0.isWhitespace }.map(String.init)
        let quote = words.count <= 14 ? firstLine : words.prefix(14).joined(separator: " ") + "\u{2026}"
        return ReflectiveProse.pick([
            "The volume dips between songs. \u{201C}\(quote)\u{201D}: read slowly, once. \u{201C}That one goes out to the one who wrote it. You know who you are.\u{201D}",
            "A dedication, almost shy: a listener kept the words \u{201C}\(quote)\u{201D} this week, and the station has been humming them since.",
            "\u{201C}Tonight's dedication isn't from a listener,\u{201D} the host says. \u{201C}It's to one. For the page that said: '\(quote)'.\u{201D}"
        ], seed: KeepMarginalia.seed(for: "\(dayID)-\(page.id)"), salt: 6)
    }
}

struct RadioPageSourceAdapter: BookPageSourceAdapter {
    let source = BookPageSourceRegistry.source(for: .radio)

    func candidates(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> [SurfacePage] {
        guard source.isActive, !context.distress.isActive else { return [] }
        let hour = Calendar.current.component(.hour, from: now)
        let shouldRise = inputs.radio.isTuned
            || day.capturedPages.contains { $0.tags.contains("music") || $0.tags.contains("radio") }
            || [8, 13, 19, 22].contains(hour)
        guard shouldRise else { return [] }
        return [surface(day: day, inputs: inputs, now: now, manual: false)]
    }

    func manualSurface(for day: BookDay, context: CuratorContext, inputs: BookSourceInputs, now: Date) -> SurfacePage {
        surface(day: day, inputs: inputs, now: now, manual: true)
    }

    private func surface(day: BookDay, inputs: BookSourceInputs, now: Date, manual: Bool) -> SurfacePage {
        let stations = RadioStationRegistry.stations(unlockedPackIDs: inputs.ownedPackIDs)
        let tuned = RadioStationRegistry.station(id: inputs.radio.activeStationID, unlockedPackIDs: inputs.ownedPackIDs)
            ?? stations.first
        let station = tuned ?? RadioStationRegistry.coreStations[0]
        let isTuned = inputs.radio.activeStationID != nil
        let stationLines = stations
            .map { station in
                "\(station.displayFrequency): \(station.title): \(station.subtitle)"
            }
            .joined(separator: "\n")
        let effects = station.effects
            .map { "\($0.pageType.shortTitle) +\($0.boost)" }
            .joined(separator: ", ")
        let favoredPages = station.effects
            .map { $0.pageType.shortTitle }
            .joined(separator: ", ")
        let interlude = RadioStationRegistry.currentInterlude(
            state: inputs.radio,
            unlockedPackIDs: inputs.ownedPackIDs,
            now: now
        )
        let dedication = isTuned ? RadioDedication.line(
            recentKeptPages: day.capturedPages + inputs.days.flatMap(\.capturedPages),
            dayID: day.id,
            now: now
        ) : nil
        let body: String
        if isTuned {
            body = """
            The receiver is tuned to \(station.displayFrequency): \(station.title).

            \(station.signalLine)

            \(dedication.map { "\($0)\n\n" } ?? "")\(interlude.map { "The broadcast bites in: \($0)\n\n" } ?? "")It keeps playing after this Page closes. It is not wallpaper. While it plays, it tugs \(favoredPages) Pages closer. Open the radio whenever you want to move the dial or turn it off.
            """
        } else {
            body = """
            The receiver wakes with a click. Open it. Move the dial until a station catches. Turn the power on.

            \(stationLines)

            The station keeps playing after this Page closes. It is not wallpaper. Each frequency tugs different kinds of Pages closer.
            """
        }
        var metadata: [String: String] = [
            "source": source.id,
            "radioStationID": station.id,
            "radioStationTitle": station.title,
            "radioFrequency": station.displayFrequency,
            "radioSignal": station.signalLine,
            "radioEffects": effects,
            "radioInterlude": interlude ?? "",
            "radioDedication": dedication ?? "",
            "radioStationCount": "\(stations.count)",
            "placeholder": "What was the music doing to the room?",
            "tags": "radio,music,academy-station,ambient-signal"
        ]
        if let packID = station.packID {
            metadata["radioPackID"] = packID
        }
        if let host = station.hostEntityID {
            metadata["radioHostEntityID"] = host
        }
        // A receiver somebody keeps tuning to one exact number ends up with a
        // scratch on the dial there. Once the Book has passed on an
        // unauthorized frequency, the dial carries the mark — unlabelled, and
        // never a preset, because a pirate station on a preset button is not a
        // pirate station. The archive is what remembers it was said, so the
        // scratch survives a reinstall for anyone with a sealed copy.
        if let rumoured = RadioStationRegistry.rumouredStation,
           (day.pages + inputs.days.flatMap(\.pages))
            .contains(where: { $0.tags.contains("wear-frequency") }) {
            metadata["radioScratchedFrequency"] = rumoured.displayFrequency
        }
        return SurfacePage(
            id: "\(source.id)-\(station.id)-\(manual ? "manual" : SurfaceCadence.slotID(for: now, hours: 6))",
            type: .radio,
            sourceID: source.id,
            intent: .reflect,
            renderStyle: .loreLetter,
            score: manual ? 80 : (isTuned ? 66 : 54),
            reason: isTuned ? "\(station.title) is tinting the margins." : "The Academy radio dial is waiting to be tuned.",
            prompt: isTuned ? "\(station.displayFrequency) \(station.title)" : "ReEnchanted Radio",
            detail: isTuned
                ? "This station keeps playing after the Page closes and tugs \(favoredPages) Pages closer."
                : "Move the dial, catch a station, and turn it on. Each frequency changes which Pages are more likely to rise.",
            payload: BookPagePayload(
                headline: isTuned ? "The Signal Holds" : "The Dial Wakes",
                body: body,
                metadata: metadata
            )
        ).withPageCapabilities(PageCapabilityContract(
            supportedMovements: isTuned
                ? [.shelter, .freshSight, .livingWorld, .humanOtherness]
                : [.freshSight, .livingWorld],
            supportedRoles: [.horizon, .echo],
            emotionalFunctions: dedication == nil
                ? [.soothe, .wonder, .play]
                : [.soothe, .remember, .connect, .wonder],
            effort: .glance,
            estimatedMinutes: 1,
            asksReader: !isTuned,
            pressureCost: isTuned ? 0.03 : 0.12,
            proofModes: []
        ))
    }
}
