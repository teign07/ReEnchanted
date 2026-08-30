#!/usr/bin/env swift

import CryptoKit
import Darwin
import Foundation

private struct SignedEnvelope: Codable {
    var keyID: String
    var payload: String
    var signature: String
}

private struct PublisherFailure: Error, CustomStringConvertible {
    var description: String
}

private let iso8601 = ISO8601DateFormatter()
private let iso8601Fractional: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
}()

private func date(_ value: Any?, field: String) throws -> Date {
    guard let string = value as? String,
          let parsed = iso8601Fractional.date(from: string) ?? iso8601.date(from: string) else {
        throw PublisherFailure(description: "Invalid ISO-8601 date: \(field)")
    }
    return parsed
}

private func requiredString(_ value: Any?, field: String) throws -> String {
    guard let string = value as? String, !string.isEmpty else {
        throw PublisherFailure(description: "Missing string: \(field)")
    }
    return string
}

private func validateManifest(_ data: Data) throws {
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          root["schemaVersion"] as? Int == 1,
          root["generatedAt"] != nil,
          let hostValues = root["allowedAssetHosts"] as? [String],
          let issues = root["issues"] as? [[String: Any]] else {
        throw PublisherFailure(description: "Manifest must use schemaVersion 1 and contain generatedAt, allowedAssetHosts, and issues.")
    }
    _ = try date(root["generatedAt"], field: "generatedAt")
    let allowedHosts = Set(hostValues.map { $0.lowercased() }.filter { !$0.isEmpty })
    var issueIDs = Set<String>()
    var assetIDs = Set<String>()
    var destinations = Set<String>()
    var intervals: [(start: Date, end: Date, id: String)] = []

    let suffixes: [String: String] = [
        "worldEventPack": ".reenchantedevents.json",
        "pageArchetypePack": ".reenchantedpages.json",
        "storyFormPack": ".reenchantedstories.json",
        "storyConsequencePack": ".reenchantedconsequences.json",
        "radioStationPack": ".reenchantedradio.json",
        "sentenceBuilderPack": ".reenchantedsentences.json",
        "casebook": ".reenchantedcasebook.json"
    ]

    for issue in issues {
        let issueID = try requiredString(issue["id"], field: "issue.id")
        guard issueIDs.insert(issueID).inserted else {
            throw PublisherFailure(description: "Duplicate issue id: \(issueID)")
        }
        _ = try requiredString(issue["packID"], field: "\(issueID).packID")
        _ = try requiredString(issue["title"], field: "\(issueID).title")
        let foreshadow = try date(issue["foreshadowStartsAt"], field: "\(issueID).foreshadowStartsAt")
        let liveStart = try date(issue["liveStartsAt"], field: "\(issueID).liveStartsAt")
        let liveEnd = try date(issue["liveEndsAt"], field: "\(issueID).liveEndsAt")
        let residueEnd = try date(issue["residueEndsAt"], field: "\(issueID).residueEndsAt")
        let casebookAt = try date(issue["casebookAvailableAt"], field: "\(issueID).casebookAvailableAt")
        guard foreshadow <= liveStart, liveStart < liveEnd,
              liveEnd <= residueEnd, residueEnd <= casebookAt else {
            throw PublisherFailure(description: "Lifecycle dates are out of order for \(issueID).")
        }
        intervals.append((liveStart, liveEnd, issueID))
        guard let assets = issue["assets"] as? [[String: Any]] else {
            throw PublisherFailure(description: "Missing assets array for \(issueID).")
        }
        for asset in assets {
            let assetID = try requiredString(asset["id"], field: "\(issueID).asset.id")
            guard assetIDs.insert(assetID).inserted else {
                throw PublisherFailure(description: "Duplicate asset id: \(assetID)")
            }
            let kind = try requiredString(asset["kind"], field: "\(assetID).kind")
            let scope = try requiredString(asset["scope"], field: "\(assetID).scope")
            let fileName = try requiredString(asset["fileName"], field: "\(assetID).fileName")
            guard fileName.unicodeScalars.allSatisfy({
                CharacterSet.alphanumerics.contains($0) || ".-_".unicodeScalars.contains($0)
            }) else {
                throw PublisherFailure(description: "Unsafe filename: \(fileName)")
            }
            guard destinations.insert("\(issueID):\(fileName)").inserted else {
                throw PublisherFailure(description: "Duplicate destination: \(issueID)/\(fileName)")
            }
            if let suffix = suffixes[kind], !fileName.hasSuffix(suffix) {
                throw PublisherFailure(description: "Wrong suffix for \(assetID): expected \(suffix)")
            }
            if kind == "casebook", scope != "casebook" {
                throw PublisherFailure(description: "Casebook \(assetID) must use casebook scope.")
            }
            guard scope == "runtime" || scope == "casebook" else {
                throw PublisherFailure(description: "Unknown scope for \(assetID): \(scope)")
            }
            let remote = try requiredString(asset["remoteURL"], field: "\(assetID).remoteURL")
            guard let url = URL(string: remote), url.scheme?.lowercased() == "https",
                  let host = url.host?.lowercased(), allowedHosts.contains(host) else {
                throw PublisherFailure(description: "Asset host is not in allowedAssetHosts: \(assetID)")
            }
            let sha = try requiredString(asset["sha256"], field: "\(assetID).sha256")
            guard sha.count == 64, sha.allSatisfy(\.isHexDigit) else {
                throw PublisherFailure(description: "Invalid SHA-256 for \(assetID).")
            }
            guard let byteCount = asset["byteCount"] as? Int, byteCount > 0 else {
                throw PublisherFailure(description: "Invalid byteCount for \(assetID).")
            }
            let ceiling = scope == "casebook" ? 2 * 1_024 * 1_024 : 180 * 1_024 * 1_024
            guard byteCount <= ceiling else {
                throw PublisherFailure(description: "Asset exceeds its size ceiling: \(assetID)")
            }
        }
    }

    let ordered = intervals.sorted { $0.start < $1.start }
    for index in ordered.indices.dropFirst() where ordered[index - 1].end > ordered[index].start {
        throw PublisherFailure(description: "Live issue intervals overlap: \(ordered[index - 1].id) and \(ordered[index].id)")
    }
}

private func decodedPrivateKey(at url: URL) throws -> Curve25519.Signing.PrivateKey {
    let data = try Data(contentsOf: url)
    let trimmed = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    let raw = trimmed.flatMap { Data(base64Encoded: $0) } ?? data
    guard raw.count == 32 else {
        throw PublisherFailure(description: "The private key must be 32 raw bytes or their base64 encoding.")
    }
    return try Curve25519.Signing.PrivateKey(rawRepresentation: raw)
}

private func writeNewSecret(_ data: Data, to url: URL) throws {
    guard !FileManager.default.fileExists(atPath: url.path) else {
        throw PublisherFailure(description: "Refusing to overwrite existing key: \(url.path)")
    }
    guard FileManager.default.createFile(
        atPath: url.path,
        contents: data,
        attributes: [.posixPermissions: 0o600]
    ) else {
        throw PublisherFailure(description: "Could not write key: \(url.path)")
    }
}

private func usage() -> Never {
    fputs("""
    Usage:
      sign_monthly_issue_manifest.swift generate-key PRIVATE_KEY PUBLIC_KEY
      sign_monthly_issue_manifest.swift sign MANIFEST PRIVATE_KEY KEY_ID OUTPUT_ENVELOPE

    Keys are base64-encoded raw Ed25519 bytes. Keep PRIVATE_KEY outside the repository.

    """, stderr)
    exit(64)
}

do {
    let arguments = CommandLine.arguments
    guard arguments.count >= 2 else { usage() }
    switch arguments[1] {
    case "generate-key":
        guard arguments.count == 4 else { usage() }
        let privateURL = URL(fileURLWithPath: arguments[2])
        let publicURL = URL(fileURLWithPath: arguments[3])
        guard !FileManager.default.fileExists(atPath: publicURL.path) else {
            throw PublisherFailure(description: "Refusing to overwrite existing key: \(publicURL.path)")
        }
        let key = Curve25519.Signing.PrivateKey()
        try writeNewSecret(Data((key.rawRepresentation.base64EncodedString() + "\n").utf8), to: privateURL)
        do {
            try Data((key.publicKey.rawRepresentation.base64EncodedString() + "\n").utf8)
                .write(to: publicURL, options: .withoutOverwriting)
        } catch {
            try? FileManager.default.removeItem(at: privateURL)
            throw error
        }
        print("Wrote a private signing key and its public app key.")
    case "sign":
        guard arguments.count == 6 else { usage() }
        let manifestURL = URL(fileURLWithPath: arguments[2])
        let privateKeyURL = URL(fileURLWithPath: arguments[3])
        let keyID = arguments[4].trimmingCharacters(in: .whitespacesAndNewlines)
        let outputURL = URL(fileURLWithPath: arguments[5])
        guard !keyID.isEmpty else { throw PublisherFailure(description: "KEY_ID may not be empty.") }
        let payload = try Data(contentsOf: manifestURL)
        try validateManifest(payload)
        let privateKey = try decodedPrivateKey(at: privateKeyURL)
        let envelope = SignedEnvelope(
            keyID: keyID,
            payload: payload.base64EncodedString(),
            signature: try privateKey.signature(for: payload).base64EncodedString()
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(envelope).write(to: outputURL, options: .atomic)
        print("Signed \(manifestURL.lastPathComponent) as \(outputURL.lastPathComponent).")
        print("Public key for MonthlyIssueManifestPublicKey:")
        print(privateKey.publicKey.rawRepresentation.base64EncodedString())
    default:
        usage()
    }
} catch {
    fputs("Monthly issue publisher refused: \(error)\n", stderr)
    exit(1)
}
