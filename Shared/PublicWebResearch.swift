import Foundation

/// Only the small public task packet crosses this boundary. Local writers may
/// still read permitted private context, but their home/Page prose is never a
/// source for a network query.
enum PublicWebResearch {
    static func query(_ raw: String, excluding privateNames: [String] = []) -> String? {
        let text = raw.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !text.isEmpty, text.count <= 240 else { return nil }
        guard !hasPhoneNumber(text) else { return nil }
        let blocked = [
            #"https?://|www\.|@"#,
            #"[+-]?\d{1,3}\.\d{3,}"#,
            #"\b\d+\s+(?:[\p{L}.'’-]+\s+){0,5}(?:street|st|road|rd|avenue|ave|lane|ln|drive|dr|court|ct|boulevard|blvd|way|place|pl)\b"#,
            #"\b(?:i|me|my|mine|we|our|ours|your|yours|email|phone|postcode|zipcode|diagnosed)\b"#
        ]
        guard !blocked.contains(where: { text.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil }) else { return nil }
        for name in privateNames where !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let pattern = #"(?<![\p{L}\p{N}])"# + NSRegularExpression.escapedPattern(for: name) + #"(?![\p{L}\p{N}])"#
            if text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil { return nil }
        }
        return text
    }

    /// Seven or more digits in a run is a number someone could ring, unless the
    /// run is only years ("1850-1900", "1907 1953 2014"): those are the subject
    /// of a history search, and dropping them dropped the search.
    private static func hasPhoneNumber(_ text: String) -> Bool {
        let run = try! NSRegularExpression(pattern: #"(?:\+?\d[\s().-]*){7,}"#)
        let ns = text as NSString
        return run.matches(in: text, range: NSRange(location: 0, length: ns.length)).contains { match in
            let groups = ns.substring(with: match.range).split { !$0.isNumber }
            return !groups.allSatisfy { $0.count == 4 && (1000...2199).contains(Int($0) ?? 0) }
        }
    }

    static func topic(_ raw: String, excluding privateNames: [String] = []) -> String? {
        // A conversational interest can still become a useful subject.
        let subject = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"^I\s+(?:(?:really\s+)?(?:like|love|enjoy)|am interested in|want to learn about)\s+"#,
                                  with: "", options: [.regularExpression, .caseInsensitive])
        guard let checked = query(subject, excluding: privateNames) else { return nil }
        let first = checked.components(separatedBy: CharacterSet(charactersIn: ",;\n")).first ?? checked
        let topic = first.split(whereSeparator: \.isWhitespace).prefix(14).joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: ".?! "))
        return topic.count >= 3 ? topic : nil
    }

    static func privateNames(in facts: [SelfFact]) -> [String] {
        facts.filter { $0.questionID == "name" || $0.tags.contains("name") }.map(\.answer)
    }

    /// Takes a structured Maps locality, never a POI name, street address,
    /// reader's place nickname, or a free-form home answer.
    static func locality(_ raw: String, excluding privateNames: [String] = []) -> String? {
        guard let text = query(raw, excluding: privateNames), text.count <= 80,
              text.split(separator: " ").count <= 6,
              text.range(of: #"^[\p{L}\p{M}\s.'’,-]+$"#, options: .regularExpression) != nil,
              text.range(of: #"\b(?:street|road|avenue|lane|drive|apartment|suite|unit)\b"#,
                         options: [.regularExpression, .caseInsensitive]) == nil else { return nil }
        return text
    }

    static func letterQueries(interest: String, inputs: BookSourceInputs) -> [String] {
        guard inputs.allowsPersonalizedWebResearch else { return [] }
        let names = privateNames(in: inputs.selfFacts) + inputs.people.threads.map(\.name)
        let subject = topic(interest, excluding: names) ?? "ordinary wonder"
        let towns = inputs.nearbyPlaces.map(\.locality)
        let town = towns.compactMap { locality($0, excluding: names) }.first
        var queries = ["\(subject) local history ecology culture"]
        if let town {
            queries.insert("\(subject) \(town)", at: 0)
            queries.append("\(town) local history folklore nature")
        }
        return queries
    }
}
