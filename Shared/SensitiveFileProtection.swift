import Foundation

enum SensitiveFileProtection {
    static func write(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: [.atomic])
        try protectItem(at: url)
    }

    static func protectDirectory(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try protectItem(at: url)
    }

    static func protectItem(at url: URL) throws {
        #if os(iOS) || os(tvOS) || os(watchOS)
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUnlessOpen],
            ofItemAtPath: url.path
        )
        #endif
    }
}
