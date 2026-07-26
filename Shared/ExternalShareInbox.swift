import Foundation

/// A small, extension-safe receipt for material the reader deliberately carries
/// into the Book from another app. It contains no Book model types so the Share
/// Extension can write it without linking the whole application.
struct ExternalShareCapture: Codable, Identifiable, Equatable {
    enum Kind: String, Codable, Equatable {
        case link
        case text
        case image
        case file
        case mixed
    }

    struct Attachment: Codable, Identifiable, Equatable {
        var id: String
        var kind: Kind
        var relativePath: String
        var typeIdentifier: String
        var originalFilename: String?

        init(
            id: String = UUID().uuidString,
            kind: Kind,
            relativePath: String,
            typeIdentifier: String,
            originalFilename: String? = nil
        ) {
            self.id = id
            self.kind = kind
            self.relativePath = relativePath
            self.typeIdentifier = typeIdentifier
            self.originalFilename = originalFilename
        }
    }

    var id: String
    var capturedAt: Date
    var kind: Kind
    var title: String
    var text: String
    var readerNote: String
    var url: String?
    /// iOS does not reliably reveal the host application to a Share Extension.
    /// This is therefore an honest URL host or declared source, never a guess.
    var sourceName: String
    var attachments: [Attachment]
    var wasRecentlyPromptedByBook: Bool
    var learningAllowed: Bool
    var weavingAllowed: Bool

    init(
        id: String = UUID().uuidString,
        capturedAt: Date = Date(),
        kind: Kind,
        title: String = "",
        text: String = "",
        readerNote: String = "",
        url: String? = nil,
        sourceName: String = "",
        attachments: [Attachment] = [],
        wasRecentlyPromptedByBook: Bool = false,
        learningAllowed: Bool = true,
        weavingAllowed: Bool = true
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.kind = kind
        self.title = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
        self.text = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(20_000))
        self.readerNote = String(readerNote.trimmingCharacters(in: .whitespacesAndNewlines).prefix(2_000))
        self.url = url
        self.sourceName = String(sourceName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
        self.attachments = attachments
        self.wasRecentlyPromptedByBook = wasRecentlyPromptedByBook
        self.learningAllowed = learningAllowed
        self.weavingAllowed = weavingAllowed
    }

    var provenance: String {
        wasRecentlyPromptedByBook ? "book-prompted-external-share" : "reader-initiated-external-share"
    }

    var archiveText: String {
        [readerNote, text, url].compactMap { value in
            value?.trimmingCharacters(in: .whitespacesAndNewlines).externalShareNonEmpty
        }.joined(separator: "\n\n")
    }
}

enum ExternalSharePromptClock {
    static let appGroup = "group.com.openclaw.enchantify.insidecover"
    static let lastSurfaceKey = "externalShare.lastBookSurfaceAt"
    static let promptedWindow: TimeInterval = 3_600

    static func markBookSurface(at date: Date = Date(), defaults: UserDefaults? = nil) {
        (defaults ?? UserDefaults(suiteName: appGroup) ?? .standard).set(date, forKey: lastSurfaceKey)
    }

    static func wasRecentlyPrompted(
        at date: Date = Date(),
        defaults: UserDefaults? = nil
    ) -> Bool {
        let store = defaults ?? UserDefaults(suiteName: appGroup) ?? .standard
        guard let surfacedAt = store.object(forKey: lastSurfaceKey) as? Date,
              surfacedAt <= date else { return false }
        return date.timeIntervalSince(surfacedAt) <= promptedWindow
    }
}

enum ExternalShareInbox {
    static let appGroup = ExternalSharePromptClock.appGroup
    static let directoryName = "ExternalShareInbox"
    static let pendingName = "Pending"
    static let assetsName = "Assets"

    static func baseURL(fileManager: FileManager = .default) -> URL? {
        fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent(directoryName, isDirectory: true)
    }

    static func prepareDirectories(
        at baseURL: URL,
        fileManager: FileManager = .default
    ) throws {
        try fileManager.createDirectory(
            at: baseURL.appendingPathComponent(pendingName, isDirectory: true),
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: baseURL.appendingPathComponent(assetsName, isDirectory: true),
            withIntermediateDirectories: true
        )
    }

    static func assetDirectory(
        for captureID: String,
        at baseURL: URL,
        fileManager: FileManager = .default
    ) throws -> URL {
        try prepareDirectories(at: baseURL, fileManager: fileManager)
        let directory = baseURL
            .appendingPathComponent(assetsName, isDirectory: true)
            .appendingPathComponent(safeComponent(captureID), isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func enqueue(
        _ capture: ExternalShareCapture,
        at baseURL: URL,
        fileManager: FileManager = .default
    ) throws {
        try prepareDirectories(at: baseURL, fileManager: fileManager)
        let data = try JSONEncoder.externalShare.encode(capture)
        let destination = baseURL
            .appendingPathComponent(pendingName, isDirectory: true)
            .appendingPathComponent("\(safeComponent(capture.id)).json")
        try data.write(to: destination, options: [.atomic])
    }

    static func pending(
        at baseURL: URL,
        fileManager: FileManager = .default
    ) throws -> [ExternalShareCapture] {
        try prepareDirectories(at: baseURL, fileManager: fileManager)
        let directory = baseURL.appendingPathComponent(pendingName, isDirectory: true)
        return try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension.lowercased() == "json" }
        .compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder.externalShare.decode(ExternalShareCapture.self, from: data)
        }
        .sorted {
            if $0.capturedAt != $1.capturedAt { return $0.capturedAt < $1.capturedAt }
            return $0.id < $1.id
        }
    }

    static func acknowledge(
        _ capture: ExternalShareCapture,
        at baseURL: URL,
        fileManager: FileManager = .default
    ) throws {
        let receipt = baseURL
            .appendingPathComponent(pendingName, isDirectory: true)
            .appendingPathComponent("\(safeComponent(capture.id)).json")
        if fileManager.fileExists(atPath: receipt.path) {
            try fileManager.removeItem(at: receipt)
        }
    }

    static func resolvedAttachmentURL(
        _ attachment: ExternalShareCapture.Attachment,
        at baseURL: URL
    ) -> URL? {
        let root = baseURL.standardizedFileURL
        let resolved = root.appendingPathComponent(attachment.relativePath).standardizedFileURL
        guard resolved.path.hasPrefix(root.path + "/") else { return nil }
        return resolved
    }

    static func safeComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = value.unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : "-" }
        return String(scalars).prefix(120).description
    }
}

enum ExternalShareCurationPolicy {
    /// Deterministic, inspectable seed tags. The Sensory Loom can enrich them
    /// later; capture never waits for a model.
    static func tags(for capture: ExternalShareCapture) -> [String] {
        var tags: Set<String> = [
            "external-share",
            "reader-brought",
            capture.wasRecentlyPromptedByBook ? "prompted-capture" : "unprompted-capture",
            capture.learningAllowed ? "curation-learning-allowed" : "curation-learning-forbidden",
            capture.weavingAllowed ? "weaving-allowed" : "weaving-forbidden",
            "external-kind:\(capture.kind.rawValue)"
        ]
        if let host = capture.url.flatMap(URL.init(string:))?.host?.lowercased().externalShareNonEmpty {
            tags.insert("external-host:\(host)")
        }

        let haystack = "\(capture.title) \(capture.text) \(capture.readerNote)".lowercased()
        let families: [(String, [String])] = [
            ("place", ["place", "street", "town", "city", "map", "trail", "road", "building", "landscape"]),
            ("nature", ["tree", "bird", "moss", "forest", "river", "ocean", "animal", "flower", "weather"]),
            ("making", ["make", "build", "draw", "paint", "cook", "repair", "craft", "write"]),
            ("people", ["friend", "family", "person", "relationship", "neighbor", "community"]),
            ("history", ["history", "old", "archive", "ancient", "forgotten", "ruin"]),
            ("humor", ["funny", "joke", "laugh", "absurd", "ridiculous"]),
            ("mystery", ["mystery", "strange", "weird", "secret", "unknown", "unexplained"]),
            ("wonder", ["wonder", "beautiful", "astonishing", "magic", "magical", "amazing"]),
            ("question", ["why", "how", "what if", "?"])
        ]
        for (tag, needles) in families where needles.contains(where: haystack.contains) {
            tags.insert("external-theme:\(tag)")
            tags.insert(tag)
        }
        return tags.sorted()
    }
}

/// One small way an outside spark can cross back into ordinary life. These are
/// deliberately verbs, not content categories: the reader chooses what the
/// scrap should *do* before the Book tries to interpret what it means.
enum ExternalSparkContinuation: String, Codable, CaseIterable, Equatable, Identifiable {
    case notice
    case tryIt
    case go
    case ask
    case make

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notice: return "Notice"
        case .tryIt: return "Try"
        case .go: return "Go"
        case .ask: return "Ask"
        case .make: return "Make"
        }
    }

    var symbolName: String {
        switch self {
        case .notice: return "eye"
        case .tryIt: return "hand.tap"
        case .go: return "figure.walk"
        case .ask: return "person.2"
        case .make: return "hammer"
        }
    }

    /// Raw main-app movement identifier. This file is also compiled by the
    /// intentionally tiny Share Extension, which does not link the Book model.
    var movementRawValue: String {
        switch self {
        case .notice: return "freshSight"
        case .tryIt, .make: return "chosenDetour"
        case .go: return "livingWorld"
        case .ask: return "humanOtherness"
        }
    }

    var invitation: String {
        switch self {
        case .notice:
            return "Look away from the screen. Find one ordinary thing nearby that rhymes with what caught you."
        case .tryIt:
            return "Do the smallest honest version of this in ten minutes or less."
        case .go:
            return "Name one nearby place where this could become real. Take the first possible step toward it."
        case .ask:
            return "Bring one person in. Send them the spark with one real question, not an explanation."
        case .make:
            return "Make a rough version before researching further. Small, physical, and allowed to be bad."
        }
    }

    func witnessText(title: String, url: String?) -> String {
        let subject = title.trimmingCharacters(in: .whitespacesAndNewlines).externalShareNonEmpty
            ?? "this"
        let source = url?.trimmingCharacters(in: .whitespacesAndNewlines).externalShareNonEmpty
            .map { "\n\n\($0)" } ?? ""
        return "This caught me: \(subject)\n\nWhat does it make you wonder?\(source)"
    }
}

private extension JSONEncoder {
    static var externalShare: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var externalShare: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private extension String {
    var externalShareNonEmpty: String? { isEmpty ? nil : self }
}
