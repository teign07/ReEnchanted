import AppleArchive
import Foundation
import System
import UIKit
import UniformTypeIdentifiers

/// The whole Book, packed to move.
///
/// The JSON sealed copy carries pages and a chosen set of ledgers and merges
/// them into whatever Book it is opened in. That is the right tool for folding
/// one Book into another, but it leaves most of the vault behind (the reader's
/// name, Tales, the fae, the Cast's undertakings, the interior). A moving copy
/// carries everything on disk instead: the shared App Group container, the
/// app's own Application Support and Documents, and both preference domains.
/// Opening one replaces the Book on this phone, so it is how a Book moves to a
/// new phone or into the app after its bundle ID changes.
///
/// A restore cannot happen while the Book is open: the vault, the archive
/// database and every @AppStorage value are already loaded and would write the
/// old Book straight back over the new one. So opening a copy only stages it,
/// and `finishPendingRestore()` moves it into place at the very start of the
/// next launch, before anything has read the disk.
enum BookMovingCopy {
    static let fileExtension = "aar"
    static let contentType = UTType.appleArchive

    private static let format = "reenchanted-moving-copy"
    private static let formatVersion = 1
    private static let pendingFileName = "PendingBookMovingCopy.aar"
    private static let pendingKey = "bookMovingCopyPending"
    static let restoredAtKey = "bookMovingCopyRestoredAt"
    static let restoreFailureKey = "bookMovingCopyRestoreFailure"

    /// Rebuilt on another phone or re-downloaded on purpose; never carried.
    private static let containerKept = ["Library/Caches", "Library/Preferences", pendingFileName]

    struct Manifest: Codable {
        var format: String
        var version: Int
        var bundleID: String
        var appGroup: String
        var exportedAt: Date
    }

    enum CopyError: LocalizedError {
        case unavailable(String)
        case notAMovingCopy

        var errorDescription: String? {
            switch self {
            case .unavailable(let what): return "\(what) couldn't be reached."
            case .notAMovingCopy: return "That file isn't a copy of a Book."
            }
        }
    }

    private static var bundleID: String { Bundle.main.bundleIdentifier ?? "app.reenchanted.book" }
    private static var fileManager: FileManager { .default }
    private static var applicationSupport: URL? {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    }
    private static var documents: URL? {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    // MARK: Export

    /// Packs the whole Book into one archive in the temporary directory. Runs
    /// off the main thread; a Book with years of photographs takes a while.
    static func export() async throws -> URL {
        try await Task.detached(priority: .userInitiated) { try exportNow() }.value
    }

    private static func exportNow() throws -> URL {
        guard let container = InsideCoverStore.containerURL else { throw CopyError.unavailable("The Book's shared folder") }
        let staging = fileManager.temporaryDirectory.appendingPathComponent("MovingCopy-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: staging) }

        try mirror(container, into: staging.appendingPathComponent("container", isDirectory: true), skipping: containerKept)
        if let applicationSupport {
            try mirror(applicationSupport, into: staging.appendingPathComponent("support", isDirectory: true),
                       skipping: ["\(bundleID)/\(LocalModelManager.modelsDirectoryName)"])
        }
        if let documents {
            try mirror(documents, into: staging.appendingPathComponent("documents", isDirectory: true), skipping: [])
        }
        try writePlist(UserDefaults.standard.persistentDomain(forName: bundleID) ?? [:],
                       to: staging.appendingPathComponent("defaults-standard.plist"))
        try writePlist(InsideCoverStore.defaults.persistentDomain(forName: InsideCoverStore.appGroup) ?? [:],
                       to: staging.appendingPathComponent("defaults-group.plist"))
        let manifest = Manifest(format: format, version: formatVersion, bundleID: bundleID,
                                appGroup: InsideCoverStore.appGroup, exportedAt: Date())
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(manifest).write(to: staging.appendingPathComponent("manifest.json"))

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let output = fileManager.temporaryDirectory
            .appendingPathComponent("ReEnchanted-Book-\(formatter.string(from: Date())).\(fileExtension)")
        try? fileManager.removeItem(at: output)
        try archive(staging, to: output)
        return output
    }

    /// Recreates `source` under `destination` with hard links, so staging a
    /// large Book costs no extra space. Falls back to a copy across volumes.
    private static func mirror(_ source: URL, into destination: URL, skipping: [String]) throws {
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        guard let enumerator = fileManager.enumerator(at: source, includingPropertiesForKeys: [.isDirectoryKey],
                                                      options: [], errorHandler: { _, _ in true }) else { return }
        let rootPath = source.resolvingSymlinksInPath().standardizedFileURL.path
        for case let item as URL in enumerator {
            let itemPath = item.resolvingSymlinksInPath().standardizedFileURL.path
            guard itemPath.hasPrefix(rootPath + "/") else { continue }
            let relative = String(itemPath.dropFirst(rootPath.count + 1))
            if skipping.contains(where: { relative == $0 || relative.hasPrefix($0 + "/") }) {
                enumerator.skipDescendants()
                continue
            }
            let target = destination.appendingPathComponent(relative)
            if (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                try fileManager.createDirectory(at: target, withIntermediateDirectories: true)
            } else {
                do { try fileManager.linkItem(at: item, to: target) } catch { try fileManager.copyItem(at: item, to: target) }
            }
        }
    }

    private static func writePlist(_ dictionary: [String: Any], to url: URL) throws {
        let data = try PropertyListSerialization.data(fromPropertyList: dictionary, format: .binary, options: 0)
        try data.write(to: url)
    }

    private static func readPlist(_ url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any]
    }

    // MARK: Archive

    private static func archive(_ directory: URL, to output: URL) throws {
        guard let file = ArchiveByteStream.fileStream(path: FilePath(output.path), mode: .writeOnly,
                                                      options: [.create, .truncate],
                                                      permissions: FilePermissions(rawValue: 0o600)) else {
            throw CopyError.unavailable("The copy's file")
        }
        defer { try? file.close() }
        guard let compressed = ArchiveByteStream.compressionStream(using: .lzfse, writingTo: file) else {
            throw CopyError.unavailable("The copy's compressor")
        }
        defer { try? compressed.close() }
        guard let encoder = ArchiveStream.encodeStream(writingTo: compressed),
              let keys = ArchiveHeader.FieldKeySet("TYP,PAT,DAT,MOD,MTM") else {
            throw CopyError.unavailable("The copy's encoder")
        }
        defer { try? encoder.close() }
        try encoder.writeDirectoryContents(archiveFrom: FilePath(directory.path), keySet: keys)
    }

    private static func extract(_ archiveURL: URL, into directory: URL) throws {
        guard let file = ArchiveByteStream.fileStream(path: FilePath(archiveURL.path), mode: .readOnly, options: [],
                                                      permissions: FilePermissions(rawValue: 0o600)) else {
            throw CopyError.unavailable("The copy's file")
        }
        defer { try? file.close() }
        guard let decompressed = ArchiveByteStream.decompressionStream(readingFrom: file) else { throw CopyError.notAMovingCopy }
        defer { try? decompressed.close() }
        guard let decoder = ArchiveStream.decodeStream(readingFrom: decompressed) else { throw CopyError.notAMovingCopy }
        defer { try? decoder.close() }
        // A copy names only paths inside itself. Refuse anything that climbs out
        // or is a link, so a hostile file cannot write outside the staging folder.
        guard let extractor = ArchiveStream.extractStream(extractingTo: FilePath(directory.path), selectUsing: { _, path, _ in
            path.components.contains(where: { $0.string == ".." }) || path.isAbsolute ? .skip : .ok
        }) else { throw CopyError.unavailable("The copy's reader") }
        defer { try? extractor.close() }
        _ = try ArchiveStream.process(readingFrom: decoder, writingTo: extractor)
    }

    // MARK: Restore

    /// Confirms with the reader, then stages the copy for the next launch.
    /// `report` receives the line the Book says afterwards.
    @MainActor
    static func offerRestore(from pickedURL: URL, report: @escaping (String) -> Void) {
        let alert = UIAlertController(
            title: "Replace the Book on this phone?",
            message: "Everything written here gives way to the Book in this copy. It can't be undone.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Keep this Book", style: .cancel))
        alert.addAction(UIAlertAction(title: "Replace it", style: .destructive) { _ in
            do {
                try stage(pickedURL)
                report("I'm ready to move in. Close me completely, then open me again.")
            } catch {
                report("I couldn't take that copy in: \(error.localizedDescription)")
            }
        })
        let root = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
            .first
        var presenter = root
        while let presented = presenter?.presentedViewController { presenter = presented }
        presenter?.present(alert, animated: true)
    }

    private static func stage(_ pickedURL: URL) throws {
        guard let container = InsideCoverStore.containerURL else { throw CopyError.unavailable("The Book's shared folder") }
        let scoped = pickedURL.startAccessingSecurityScopedResource()
        defer { if scoped { pickedURL.stopAccessingSecurityScopedResource() } }
        let pending = container.appendingPathComponent(pendingFileName)
        try? fileManager.removeItem(at: pending)
        try fileManager.copyItem(at: pickedURL, to: pending)
        UserDefaults.standard.set(true, forKey: pendingKey)
    }

    /// Call first thing in `App.init`. Moves a staged copy into place before
    /// any store reads the disk. A failure leaves this phone's Book as it was
    /// and records why, so the next launch is never a half-moved Book.
    static func finishPendingRestore() {
        guard UserDefaults.standard.bool(forKey: pendingKey),
              let container = InsideCoverStore.containerURL else { return }
        let pending = container.appendingPathComponent(pendingFileName)
        defer {
            try? fileManager.removeItem(at: pending)
            UserDefaults.standard.removeObject(forKey: pendingKey)
        }
        guard fileManager.fileExists(atPath: pending.path) else { return }
        let unpacked = fileManager.temporaryDirectory.appendingPathComponent("MovingCopyRestore-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: unpacked) }
        do {
            try fileManager.createDirectory(at: unpacked, withIntermediateDirectories: true)
            try extract(pending, into: unpacked)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let manifest = try decoder.decode(Manifest.self, from: Data(contentsOf: unpacked.appendingPathComponent("manifest.json")))
            guard manifest.format == format, manifest.version <= formatVersion else { throw CopyError.notAMovingCopy }
            try place(unpacked, manifest: manifest, container: container)
            UserDefaults.standard.set(Date(), forKey: restoredAtKey)
            UserDefaults.standard.removeObject(forKey: restoreFailureKey)
        } catch {
            UserDefaults.standard.set(error.localizedDescription, forKey: restoreFailureKey)
        }
    }

    #if DEBUG && targetEnvironment(simulator)
    /// `--moving-copy-roundtrip`: seals this Book, deletes the probe files and a
    /// probe preference, restores the copy, and writes what came back to
    /// Documents/moving-copy-roundtrip.txt. Runs before any store loads.
    static func runRoundTripIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("--moving-copy-roundtrip"),
              let container = InsideCoverStore.containerURL, let applicationSupport, let documents else { return }
        var lines: [String] = []
        let groupProbe = container.appendingPathComponent("moving-copy-probe.txt")
        let supportProbe = applicationSupport.appendingPathComponent("\(bundleID)/CameraFirstPhotos/moving-copy-probe.jpg")
        let modelProbe = applicationSupport.appendingPathComponent("\(bundleID)/\(LocalModelManager.modelsDirectoryName)/kept.txt")
        do {
            try fileManager.createDirectory(at: supportProbe.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fileManager.createDirectory(at: modelProbe.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("group".utf8).write(to: groupProbe)
            try Data("support".utf8).write(to: supportProbe)
            try Data("model".utf8).write(to: modelProbe)
            UserDefaults.standard.set("standard-probe", forKey: "movingCopyProbe")
            InsideCoverStore.defaults.set("group-probe", forKey: "movingCopyProbe")
            let vaultBefore = try? Data(contentsOf: container.appendingPathComponent("PlayerVault.json"))

            let copy = try exportNow()
            lines.append("exported \((try? fileManager.attributesOfItem(atPath: copy.path)[.size] as? Int) ?? -1) bytes")
            try fileManager.removeItem(at: groupProbe)
            try fileManager.removeItem(at: supportProbe)
            let stray = container.appendingPathComponent("stray-from-fresh-install.txt")
            try Data("stray".utf8).write(to: stray)
            UserDefaults.standard.removeObject(forKey: "movingCopyProbe")
            InsideCoverStore.defaults.removeObject(forKey: "movingCopyProbe")

            try stage(copy)
            finishPendingRestore()
            lines.append("failure: \(UserDefaults.standard.string(forKey: restoreFailureKey) ?? "none")")
            lines.append("group probe: \((try? String(contentsOf: groupProbe, encoding: .utf8)) ?? "MISSING")")
            lines.append("support probe: \((try? String(contentsOf: supportProbe, encoding: .utf8)) ?? "MISSING")")
            lines.append("model kept: \((try? String(contentsOf: modelProbe, encoding: .utf8)) ?? "MISSING")")
            lines.append("stray removed: \(!fileManager.fileExists(atPath: stray.path))")
            lines.append("standard pref: \(UserDefaults.standard.string(forKey: "movingCopyProbe") ?? "MISSING")")
            lines.append("group pref: \(InsideCoverStore.defaults.string(forKey: "movingCopyProbe") ?? "MISSING")")
            lines.append("vault identical: \(vaultBefore == (try? Data(contentsOf: container.appendingPathComponent("PlayerVault.json"))))")
            lines.append("pending cleared: \(!fileManager.fileExists(atPath: container.appendingPathComponent(pendingFileName).path))")
        } catch {
            lines.append("error: \(error.localizedDescription)")
        }
        try? lines.joined(separator: "\n").write(to: documents.appendingPathComponent("moving-copy-roundtrip.txt"),
                                                 atomically: true, encoding: .utf8)
    }
    #endif

    private static func place(_ unpacked: URL, manifest: Manifest, container: URL) throws {
        // Everything is read before anything is replaced: a copy missing its
        // preferences must fail here, with this phone's Book untouched.
        guard let standard = readPlist(unpacked.appendingPathComponent("defaults-standard.plist")),
              let group = readPlist(unpacked.appendingPathComponent("defaults-group.plist")) else {
            throw CopyError.notAMovingCopy
        }

        try replaceContents(of: container, with: unpacked.appendingPathComponent("container", isDirectory: true),
                            keeping: containerKept)
        if let applicationSupport {
            // The Book's own support folder is named for the bundle ID it was made
            // under; it moves in under today's name. Paths stored inside the Book
            // still name the old folder, which `MonthlyIssueMediaPath` maps.
            let support = unpacked.appendingPathComponent("support", isDirectory: true)
            if manifest.bundleID != bundleID {
                let old = support.appendingPathComponent(manifest.bundleID, isDirectory: true)
                let renamed = support.appendingPathComponent(bundleID, isDirectory: true)
                if fileManager.fileExists(atPath: old.path) {
                    try? fileManager.removeItem(at: renamed)
                    try fileManager.moveItem(at: old, to: renamed)
                }
            }
            try replaceContents(of: applicationSupport, with: support,
                                keeping: ["\(bundleID)/\(LocalModelManager.modelsDirectoryName)"])
        }
        if let documents {
            try replaceContents(of: documents, with: unpacked.appendingPathComponent("documents", isDirectory: true), keeping: [])
        }
        UserDefaults.standard.setPersistentDomain(standard, forName: bundleID)
        InsideCoverStore.defaults.setPersistentDomain(group, forName: InsideCoverStore.appGroup)
    }

    /// Empties `destination` except the `keeping` paths, then moves the copy's
    /// items in. Emptying first matters: a fresh install's own database journal
    /// left beside a restored database would be replayed into it.
    private static func replaceContents(of destination: URL, with source: URL, keeping: [String]) throws {
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        try clear(destination, relativeTo: "", keeping: keeping)
        try moveContents(of: source, into: destination)
    }

    private static func clear(_ directory: URL, relativeTo prefix: String, keeping: [String]) throws {
        for item in (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [] {
            let relative = prefix.isEmpty ? item.lastPathComponent : "\(prefix)/\(item.lastPathComponent)"
            if keeping.contains(relative) { continue }
            if keeping.contains(where: { $0.hasPrefix(relative + "/") }) {
                try clear(item, relativeTo: relative, keeping: keeping)
            } else {
                try fileManager.removeItem(at: item)
            }
        }
    }

    private static func moveContents(of source: URL, into destination: URL) throws {
        for item in (try? fileManager.contentsOfDirectory(at: source, includingPropertiesForKeys: [.isDirectoryKey])) ?? [] {
            let target = destination.appendingPathComponent(item.lastPathComponent)
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: target.path, isDirectory: &isDirectory) {
                // Only a kept folder can still be here; merge into it.
                if isDirectory.boolValue { try moveContents(of: item, into: target) }
                continue
            }
            try fileManager.moveItem(at: item, to: target)
        }
    }
}
