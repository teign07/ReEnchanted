import Foundation

/// The moving copy's disk replacement. Originals survive until both files and
/// preferences commit. The journal lives outside every folder being replaced.
enum BookMovingCopyTransaction {
    struct Replacement {
        var source: URL
        var destination: URL
        var keeping: [String] = []
    }

    private struct Operation: Codable {
        var destination: URL
        var hadOriginal: Bool
    }

    private struct Journal: Codable {
        var operations: [Operation]
        var context: Data
        var committed = false
    }

    enum RestoreError: Error {
        case invalidFolder
        case unsupportedFile
        case recoveryPending
    }

    /// Reject absent roots and links before a single original is touched.
    static func validateFolder(_ url: URL, fileManager: FileManager = .default) throws {
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true else {
            throw RestoreError.invalidFolder
        }
        for item in try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey]) {
            let values = try item.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey])
            guard values.isSymbolicLink != true else { throw RestoreError.unsupportedFile }
            if values.isDirectory == true {
                try validateFolder(item, fileManager: fileManager)
            } else if values.isRegularFile != true {
                throw RestoreError.unsupportedFile
            }
        }
    }

    static func perform(
        _ replacements: [Replacement], recoveryURL: URL, context: Data,
        commit: () throws -> Void, restoreContext: (Data) throws -> Void,
        afterReplacement: (Int) throws -> Void = { _ in }
    ) throws {
        let files = FileManager.default
        guard !files.fileExists(atPath: recoveryURL.path) else { throw RestoreError.recoveryPending }
        for replacement in replacements { try validateFolder(replacement.source) }

        // Drop excluded incoming paths too: an archive cannot replace an iOS
        // container identity, preference directory, or the installed model.
        for replacement in replacements {
            for path in replacement.keeping {
                let excluded = replacement.source.appendingPathComponent(path)
                if files.fileExists(atPath: excluded.path) { try files.removeItem(at: excluded) }
            }
        }
        var sources: [URL?] = []
        var operations: [Operation] = []
        for replacement in replacements {
            try plan(source: replacement.source, destination: replacement.destination,
                     keeping: replacement.keeping, operations: &operations, sources: &sources)
        }
        try SensitiveFileProtection.protectDirectory(at: recoveryURL)
        var journal = Journal(operations: operations, context: context)
        do {
            try save(journal, at: recoveryURL)
        } catch {
            // No original has moved yet.
            try? files.removeItem(at: recoveryURL)
            throw error
        }
        do {
            for (index, operation) in operations.enumerated() {
                if operation.hadOriginal {
                    try files.moveItem(at: operation.destination, to: backup(index, at: recoveryURL))
                }
                if let source = sources[index] {
                    try files.createDirectory(at: operation.destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try files.moveItem(at: source, to: operation.destination)
                }
                try afterReplacement(index)
            }
            try commit()
            journal.committed = true
            try save(journal, at: recoveryURL)
        } catch {
            // Keep the journal and originals if rollback itself cannot finish.
            try recover(at: recoveryURL, restoreContext: restoreContext)
            throw error
        }
        // A committed journal can be cleaned up on the next launch too.
        try? files.removeItem(at: recoveryURL)
    }

    static func recover(at recoveryURL: URL, restoreContext: (Data) throws -> Void) throws {
        let files = FileManager.default
        guard files.fileExists(atPath: recoveryURL.path) else { return }
        let journalURL = recoveryURL.appendingPathComponent("journal.json")
        // Interrupted cleanup (or a failed initial journal write) cannot have
        // an unfinished replacement once its journal is gone.
        guard files.fileExists(atPath: journalURL.path) else {
            try files.removeItem(at: recoveryURL)
            return
        }
        let journal = try JSONDecoder().decode(Journal.self, from: Data(contentsOf: journalURL))
        if !journal.committed {
            for (index, operation) in journal.operations.enumerated().reversed() {
                let original = backup(index, at: recoveryURL)
                if files.fileExists(atPath: original.path) {
                    if files.fileExists(atPath: operation.destination.path) { try files.removeItem(at: operation.destination) }
                    // Moved, not copied: a copy of the photo folders needs their
                    // size again in free space, and a full phone would then fail
                    // its own rollback. The move is a rename, so an interruption
                    // leaves the original either still here or already home,
                    // and the next attempt finishes from whichever it finds.
                    try files.moveItem(at: original, to: operation.destination)
                } else if !operation.hadOriginal, files.fileExists(atPath: operation.destination.path) {
                    try files.removeItem(at: operation.destination)
                }
            }
            try restoreContext(journal.context)
        }
        try files.removeItem(at: recoveryURL)
    }

    private static func plan(source: URL, destination: URL, keeping: [String],
                             operations: inout [Operation], sources: inout [URL?]) throws {
        let files = FileManager.default
        let incoming = try files.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
        var isDirectory: ObjCBool = false
        let exists = files.fileExists(atPath: destination.path, isDirectory: &isDirectory)
        guard !exists || isDirectory.boolValue else { throw RestoreError.invalidFolder }
        let existing = exists ? try files.contentsOfDirectory(at: destination, includingPropertiesForKeys: nil) : []
        for name in Set((incoming + existing).map(\.lastPathComponent)).sorted() {
            if keeping.contains(name) { continue }
            let nextSource = source.appendingPathComponent(name)
            let nextDestination = destination.appendingPathComponent(name)
            let nestedKeeps = keeping.compactMap { $0.hasPrefix(name + "/") ? String($0.dropFirst(name.count + 1)) : nil }
            let hasSource = files.fileExists(atPath: nextSource.path)
            let hasDestination = files.fileExists(atPath: nextDestination.path)
            if !nestedKeeps.isEmpty, hasDestination {
                // A missing source means only the excluded descendants stay.
                if !hasSource { try files.createDirectory(at: nextSource, withIntermediateDirectories: true) }
                try plan(source: nextSource, destination: nextDestination, keeping: nestedKeeps,
                         operations: &operations, sources: &sources)
            } else {
                operations.append(Operation(destination: nextDestination, hadOriginal: hasDestination))
                sources.append(hasSource ? nextSource : nil)
            }
        }
    }

    private static func backup(_ index: Int, at recoveryURL: URL) -> URL {
        recoveryURL.appendingPathComponent("original-\(index)")
    }

    private static func save(_ journal: Journal, at recoveryURL: URL) throws {
        try SensitiveFileProtection.write(JSONEncoder().encode(journal), to: recoveryURL.appendingPathComponent("journal.json"))
    }
}
