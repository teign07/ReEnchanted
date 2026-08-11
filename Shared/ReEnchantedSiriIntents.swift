import AppIntents
import CoreSpotlight
import Foundation
import UniformTypeIdentifiers

enum ReEnchantedSiriCommandAction: String, Codable, Equatable {
    case capturePage
    case openPage
    case openArchive
}

struct ReEnchantedSiriCommand: Codable, Equatable, Identifiable {
    var id: UUID
    var action: ReEnchantedSiriCommandAction
    var text: String?
    var pageID: String?
    var issuedAt: Date
}

enum ReEnchantedSiriCommandStore {
    static let commandKey = "reenchantedSiriCommand"

    static func load() -> ReEnchantedSiriCommand? {
        guard let data = InsideCoverStore.defaults.data(forKey: commandKey) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(ReEnchantedSiriCommand.self, from: data)
    }

    static func save(_ command: ReEnchantedSiriCommand) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(command)
        InsideCoverStore.defaults.set(data, forKey: commandKey)
    }

    static func clear(id: UUID? = nil) {
        if let id, load()?.id != id { return }
        InsideCoverStore.defaults.removeObject(forKey: commandKey)
    }
}

struct ReEnchantedBookPageEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Book Page"
    static var defaultQuery = ReEnchantedBookPageQuery()

    var id: String
    var name: String
    var content: String?
    var tags: [String]
    var creationDate: Date?
    var modificationDate: Date?

    var displayRepresentation: DisplayRepresentation {
        let dateSubtitle = creationDate.map {
            LocalizedStringResource(stringLiteral: $0.formatted(date: .abbreviated, time: .shortened))
        }
        return DisplayRepresentation(
            title: "\(name)",
            subtitle: dateSubtitle
        )
    }

    init(
        id: String,
        name: String,
        content: String?,
        tags: [String],
        creationDate: Date?,
        modificationDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.content = content
        self.tags = tags
        self.creationDate = creationDate
        self.modificationDate = modificationDate
    }

    init(page: BookPage) {
        let trimmedPrompt = page.promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedInput = page.userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackTitle = page.type == .plainPage ? "Plain Page" : page.type.title
        let title = trimmedPrompt.isEmpty ? fallbackTitle : trimmedPrompt.bookPreviewSentenceLimit(1)
        self.init(
            id: page.id,
            name: title,
            content: trimmedInput.isEmpty ? nil : trimmedInput,
            tags: page.tags,
            creationDate: page.createdAt,
            modificationDate: page.createdAt
        )
    }
}

@available(iOS 18.0, *)
struct ReEnchantedIndexedBookPageEntity: IndexedEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Book Page"
    static var defaultQuery = ReEnchantedIndexedBookPageQuery()

    var id: String
    var name: String
    var content: String?
    var tags: [String]
    var creationDate: Date?
    var modificationDate: Date?

    var displayRepresentation: DisplayRepresentation {
        let dateSubtitle = creationDate.map {
            LocalizedStringResource(stringLiteral: $0.formatted(date: .abbreviated, time: .shortened))
        }
        return DisplayRepresentation(
            title: "\(name)",
            subtitle: dateSubtitle
        )
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet(contentType: .text)
        attributes.title = name
        attributes.contentDescription = content
        attributes.keywords = tags
        attributes.addedDate = creationDate
        attributes.contentCreationDate = creationDate
        attributes.contentModificationDate = modificationDate ?? creationDate
        return attributes
    }

    init(entity: ReEnchantedBookPageEntity) {
        id = entity.id
        name = entity.name
        content = entity.content
        tags = entity.tags
        creationDate = entity.creationDate
        modificationDate = entity.modificationDate
    }
}

@available(iOS 18.0, *)
struct ReEnchantedIndexedBookPageQuery: EntityStringQuery {
    func entities(for identifiers: [ReEnchantedIndexedBookPageEntity.ID]) async throws -> [ReEnchantedIndexedBookPageEntity] {
        let base = try await ReEnchantedBookPageQuery().entities(for: identifiers)
        return base.map(ReEnchantedIndexedBookPageEntity.init(entity:))
    }

    func entities(matching string: String) async throws -> [ReEnchantedIndexedBookPageEntity] {
        let base = try await ReEnchantedBookPageQuery().entities(matching: string)
        return base.map(ReEnchantedIndexedBookPageEntity.init(entity:))
    }

    func suggestedEntities() async throws -> [ReEnchantedIndexedBookPageEntity] {
        let base = try await ReEnchantedBookPageQuery().suggestedEntities()
        return base.map(ReEnchantedIndexedBookPageEntity.init(entity:))
    }
}

struct ReEnchantedBookPageQuery: EntityStringQuery {
    func entities(for identifiers: [ReEnchantedBookPageEntity.ID]) async throws -> [ReEnchantedBookPageEntity] {
        let wanted = Set(identifiers)
        let pages = try await loadEntities(limit: 300)
        return pages.filter { wanted.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [ReEnchantedBookPageEntity] {
        let needle = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let pages = try await loadEntities(limit: 300)
        guard !needle.isEmpty else { return Array(pages.prefix(12)) }
        return pages.filter { entity in
            entity.name.lowercased().contains(needle)
                || (entity.content?.lowercased().contains(needle) ?? false)
                || entity.tags.contains { $0.lowercased().contains(needle) }
        }.prefixArray(12)
    }

    func suggestedEntities() async throws -> [ReEnchantedBookPageEntity] {
        try await loadEntities(limit: 12)
    }

    private func loadEntities(limit: Int) async throws -> [ReEnchantedBookPageEntity] {
        // Spotlight and Siri resolve entities on their own schedule, often
        // while the app is foregrounded: this read must never block the
        // main thread or the whole app freezes mid-use.
        let days = BookDatabase.loadDaysDetached()
        let query = BookPageQuery(limit: limit)
        return BookArchiveIndex.pages(in: days, matching: query)
            .filter { $0.privacy == .privateLocal }
            .map(ReEnchantedBookPageEntity.init(page:))
    }
}

private extension Array {
    func prefixArray(_ maxLength: Int) -> [Element] {
        Array(prefix(maxLength))
    }
}

struct ReEnchantedCapturePageIntent: AppIntent {
    static var title: LocalizedStringResource = "Write a Page"
    static var description = IntentDescription("Write a plain private page in ReEnchanted.")
    static var openAppWhenRun: Bool { true }

    @Parameter(
        title: "Page Text",
        requestValueDialog: "What should the Book keep?"
    )
    var text: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .result(dialog: "The Book needs at least one word to keep.")
        }
        try ReEnchantedSiriCommandStore.save(
            ReEnchantedSiriCommand(
                id: UUID(),
                action: .capturePage,
                text: trimmed,
                pageID: nil,
                issuedAt: Date()
            )
        )
        return .result(dialog: "I’ll open ReEnchanted and tuck that into your Book.")
    }
}

struct ReEnchantedOpenArchiveIntent: AppIntent {
    static var title: LocalizedStringResource = "Open the Book Archive"
    static var description = IntentDescription("Open ReEnchanted to the kept pages archive.")
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try ReEnchantedSiriCommandStore.save(
            ReEnchantedSiriCommand(
                id: UUID(),
                action: .openArchive,
                text: nil,
                pageID: nil,
                issuedAt: Date()
            )
        )
        return .result(dialog: "Opening the Stacks.")
    }
}

struct ReEnchantedOpenBookPageIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Book Page"
    static var description = IntentDescription("Open ReEnchanted with a selected kept page in context.")
    static var openAppWhenRun: Bool { true }

    @Parameter(title: "Page")
    var page: ReEnchantedBookPageEntity

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try ReEnchantedSiriCommandStore.save(
            ReEnchantedSiriCommand(
                id: UUID(),
                action: .openPage,
                text: page.name,
                pageID: page.id,
                issuedAt: Date()
            )
        )
        return .result(dialog: "Opening \(page.name) in ReEnchanted.")
    }
}

@available(iOS 18.0, *)
struct ReEnchantedIndexBookPagesIntent: AppIntent {
    static var title: LocalizedStringResource = "Index Book Pages"
    static var description = IntentDescription("Refresh ReEnchanted's Spotlight index for kept pages.")
    static var openAppWhenRun: Bool { false }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let pages = try await ReEnchantedIndexedBookPageQuery().suggestedEntities()
        try await CSSearchableIndex.default().indexAppEntities(pages, priority: 1)
        return .result(dialog: "The latest Book pages are ready for Spotlight.")
    }
}

struct ReEnchantedShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ReEnchantedCapturePageIntent(),
            phrases: [
                "Write in my \(.applicationName)",
                "Add a page to my Book in \(.applicationName)",
                "Keep this in \(.applicationName)"
            ],
            shortTitle: "Write Page",
            systemImageName: "book.closed"
        )
        AppShortcut(
            intent: ReEnchantedOpenArchiveIntent(),
            phrases: [
                "Open my Book archive in \(.applicationName)",
                "Search the Stacks in \(.applicationName)"
            ],
            shortTitle: "Open Archive",
            systemImageName: "books.vertical"
        )
        AppShortcut(
            intent: ReEnchantedOpenCompassIntent(),
            phrases: [
                "Open my Wonder Compass in \(.applicationName)",
                "Start a Wonder Compass in \(.applicationName)"
            ],
            shortTitle: "Wonder Compass",
            systemImageName: "safari"
        )
    }
}

#if REENCHANTED_IOS27_APP_SCHEMAS
@available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
@AppEntity(schema: .notes.note)
struct ReEnchantedSchemaBookPageEntity: IndexedEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Book Page"
    static var defaultQuery = ReEnchantedSchemaBookPageQuery()

    let id: String
    var name: AttributedString
    var content: AttributedString?
    var attachments: [IntentFile]
    var tags: [ReEnchantedNoteTagEntity]
    var isPinned: Bool
    var creationDate: Date?
    var modificationDate: Date?
    var folder: ReEnchantedNoteFolderEntity?

    var displayRepresentation: DisplayRepresentation {
        return DisplayRepresentation(title: "\(String(name.characters))")
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet(contentType: .text)
        attributes.title = String(name.characters)
        attributes.contentDescription = content.map { String($0.characters) }
        attributes.keywords = tags.map(\.name)
        attributes.contentCreationDate = creationDate
        attributes.contentModificationDate = modificationDate ?? creationDate
        return attributes
    }

    init(entity: ReEnchantedBookPageEntity) {
        id = entity.id
        name = AttributedString(entity.name)
        content = entity.content.map(AttributedString.init)
        attachments = []
        tags = entity.tags.map { ReEnchantedNoteTagEntity(name: $0) }
        isPinned = false
        creationDate = entity.creationDate
        modificationDate = entity.modificationDate
        folder = ReEnchantedNoteFolderEntity.book
    }
}

@available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
struct ReEnchantedSchemaBookPageQuery: EntityStringQuery {
    func entities(for identifiers: [ReEnchantedSchemaBookPageEntity.ID]) async throws -> [ReEnchantedSchemaBookPageEntity] {
        let base = try await ReEnchantedBookPageQuery().entities(for: identifiers)
        return base.map(ReEnchantedSchemaBookPageEntity.init(entity:))
    }

    func entities(matching string: String) async throws -> [ReEnchantedSchemaBookPageEntity] {
        let base = try await ReEnchantedBookPageQuery().entities(matching: string)
        return base.map(ReEnchantedSchemaBookPageEntity.init(entity:))
    }

    func suggestedEntities() async throws -> [ReEnchantedSchemaBookPageEntity] {
        let base = try await ReEnchantedBookPageQuery().suggestedEntities()
        return base.map(ReEnchantedSchemaBookPageEntity.init(entity:))
    }
}

@available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
@AppEntity(schema: .notes.folder)
struct ReEnchantedNoteFolderEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Book Folder"
    static var defaultQuery = ReEnchantedNoteFolderQuery()
    static let book = ReEnchantedNoteFolderEntity(id: "book", name: "The Book")

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        return DisplayRepresentation(title: "\(name)")
    }
}

@available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
struct ReEnchantedNoteFolderQuery: EntityQuery {
    func entities(for identifiers: [ReEnchantedNoteFolderEntity.ID]) async throws -> [ReEnchantedNoteFolderEntity] {
        identifiers.contains(ReEnchantedNoteFolderEntity.book.id) ? [.book] : []
    }

    func suggestedEntities() async throws -> [ReEnchantedNoteFolderEntity] {
        [.book]
    }
}

@available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
struct ReEnchantedNoteTagEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Book Tag"
    static var defaultQuery = ReEnchantedNoteTagQuery()

    var id: String { name.lowercased() }
    var name: String

    var displayRepresentation: DisplayRepresentation {
        return DisplayRepresentation(title: "\(name)")
    }
}

@available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
struct ReEnchantedNoteTagQuery: EntityStringQuery {
    func entities(for identifiers: [ReEnchantedNoteTagEntity.ID]) async throws -> [ReEnchantedNoteTagEntity] {
        identifiers.map { ReEnchantedNoteTagEntity(name: $0) }
    }

    func entities(matching string: String) async throws -> [ReEnchantedNoteTagEntity] {
        [ReEnchantedNoteTagEntity(name: string)]
    }

    func suggestedEntities() async throws -> [ReEnchantedNoteTagEntity] {
        [
            ReEnchantedNoteTagEntity(name: "plain"),
            ReEnchantedNoteTagEntity(name: "private")
        ]
    }
}

@available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
@AppIntent(schema: .notes.createNote)
struct ReEnchantedCreateBookPageNoteIntent {
    var name: String
    var content: AttributedString?
    var attachments: [IntentFile]
    var tags: [ReEnchantedNoteTagEntity]
    var isPinned: Bool
    var folder: ReEnchantedNoteFolderEntity?

    func perform() async throws -> some ReturnsValue<ReEnchantedSchemaBookPageEntity> {
        let text = content.map { String($0.characters) } ?? name
        try ReEnchantedSiriCommandStore.save(
            ReEnchantedSiriCommand(
                id: UUID(),
                action: .capturePage,
                text: text,
                pageID: nil,
                issuedAt: Date()
            )
        )
        let pending = ReEnchantedBookPageEntity(
            id: UUID().uuidString,
            name: name,
            content: text,
            tags: tags.map(\.name),
            creationDate: Date()
        )
        return .result(value: ReEnchantedSchemaBookPageEntity(entity: pending))
    }
}
#endif
