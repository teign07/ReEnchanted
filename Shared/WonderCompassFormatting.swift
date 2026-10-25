import Foundation

/// Per-chapter reading notes for The Wonder Compass. The manuscript in
/// `ReferenceSnippet.body` stays plain prose, because Pages, Stacks search and
/// the local brain all quote it. The notes only name paragraphs, by their exact
/// text, that the formatter cannot judge on its own.
struct ReferenceLayoutNotes: Codable, Equatable {
    /// Headings that open a major movement of the chapter. They get an
    /// ornament rule above them; every other inferred heading is a subhead.
    var majorHeadings: [String]? = nil
    /// Short paragraphs to set as headings although they read like prose.
    var headings: [String]? = nil
    /// Short paragraphs that look like headings but are the author talking.
    var notHeadings: [String]? = nil
    /// Standalone paragraphs set large: the lines a reader should carry out.
    var keyLines: [String]? = nil
}

enum WonderCompassDirection: String, Codable, Equatable, CaseIterable {
    case north, east, south, west, center

    var letter: String {
        switch self {
        case .north: return "N"
        case .east: return "E"
        case .south: return "S"
        case .west: return "W"
        case .center: return "C"
        }
    }

    /// The step each quarter of the Compass stands for.
    var step: String {
        switch self {
        case .north: return "Notice"
        case .east: return "Embark"
        case .south: return "Sense"
        case .west: return "Write"
        case .center: return "Rest"
        }
    }

    init?(word: String) {
        switch word.lowercased() {
        case "north": self = .north
        case "east": self = .east
        case "south": self = .south
        case "west": self = .west
        case "center", "centre": self = .center
        default: return nil
        }
    }
}

indirect enum WonderCompassBlock: Equatable {
    /// "Part 2 - The Manual"
    case part(label: String, title: String, subtitle: String?)
    /// "Chapter 7: East = Embark"
    case opener(kicker: String?, title: String, direction: WonderCompassDirection?)
    /// The first paragraph of a chapter, set with a drop cap.
    case lede(String)
    case heading(String, major: Bool)
    /// A label standing alone above what it introduces: "Examples:".
    case kicker(String)
    /// A Compass step: a header ("NORTH = NOTICE (The Spark)") when `text`
    /// is nil, or a recipe line ("North: I wonder…") when it carries text.
    /// `label` is nil when the manuscript names only the direction.
    case compass(WonderCompassDirection, label: String?, detail: String?, text: String?)
    case labeled(label: String, text: String)
    case list([String])
    /// "1.\tGoes with lower IL-6…": items keep their own numbers.
    case numbered([String])
    case prose(String)
    case keyLine(String)
    case summary(title: String, items: [WonderCompassBlock])
    case quickWin(title: String, items: [WonderCompassBlock])
    /// A slip to sign ("THE PERMISSION SLIP" … "Date"), set as a certificate.
    case certificate(title: String, items: [WonderCompassBlock])
    /// The blank lines the print book left for a One Sentence Souvenir.
    case souvenir(title: String, lines: Int)
    case credit(String)
    case caption(String)
    case illustration(ReferenceIllustration)
    case contents([ReferenceContentsLink])
}

extension ReferenceSnippet {
    /// The formatted reading of `text`. Every non-blank paragraph of the
    /// manuscript appears in exactly one block, in order; nothing is reworded.
    func wonderCompassBlocks(for text: String) -> [WonderCompassBlock] {
        var formatter = WonderCompassFormatter(snippet: self)
        for segment in readingBlocks(for: text) {
            switch segment {
            case .text(let prose):
                formatter.append(paragraphs: prose.components(separatedBy: "\n\n"))
            case .illustration(let illustration):
                formatter.flush()
                formatter.blocks.append(.illustration(illustration))
            case .contents(let links):
                formatter.flush()
                formatter.blocks.append(.contents(links))
            }
        }
        formatter.flush()
        return formatter.blocks
    }
}

struct WonderCompassFormatter {
    private enum Gathering {
        case none
        case summary(title: String, items: [WonderCompassBlock])
        case quickWin(title: String, items: [WonderCompassBlock])
        case certificate(title: String, items: [WonderCompassBlock])
    }

    var blocks: [WonderCompassBlock] = []
    private let majorHeadings: Set<String>
    private let forcedHeadings: Set<String>
    private let notHeadings: Set<String>
    private let keyLines: Set<String>
    /// EPUB caption lines that sit directly above their plate.
    private let captionAnchors: Set<String>
    private let sectionTitle: String
    private var gathering = Gathering.none
    private var pendingList: [String] = []
    private var pendingListIsNumbered = false
    /// Heading-like lines wait here: one alone is a heading, a run of them is
    /// a list the print book set without bullets.
    private var pendingHeadings: [String] = []
    private var openerSeen = false
    /// Chapters open with a lede; back matter ("Glossary") does not.
    private var opensChapter = false
    private var ledeSet = false
    private var pendingSouvenir: String?
    private var souvenirLines = 0
    private var lastPartIndex: Int?

    init(snippet: ReferenceSnippet) {
        let notes = snippet.layout
        majorHeadings = Set((notes?.majorHeadings ?? []).map(Self.normalized))
        forcedHeadings = Set((notes?.headings ?? []).map(Self.normalized))
        notHeadings = Set((notes?.notHeadings ?? []).map(Self.normalized))
        keyLines = Set((notes?.keyLines ?? []).map(Self.normalized))
        sectionTitle = snippet.title
        captionAnchors = Set((snippet.illustrations ?? [])
            .filter { $0.placement == .after }
            .map { Self.normalized($0.anchor) })
    }

    /// The EPUB import left line-separator characters in the manuscript.
    static func normalized(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{2028}", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    mutating func append(paragraphs: [String]) {
        for raw in paragraphs {
            let paragraph = Self.normalized(raw)
            guard !paragraph.isEmpty else { continue }
            append(paragraph)
        }
    }

    mutating func flush() {
        closeHeadings()
        closeList()
        closeSouvenir()
        switch gathering {
        case .none:
            break
        case .summary(let title, let items):
            blocks.append(.summary(title: title, items: items))
        case .quickWin(let title, let items):
            blocks.append(.quickWin(title: title, items: items))
        case .certificate(let title, let items):
            blocks.append(.certificate(title: title, items: items))
        }
        gathering = .none
    }

    private mutating func append(_ paragraph: String) {
        // The print book's ruled writing lines.
        if paragraph.allSatisfy({ $0 == "-" || $0.isWhitespace }) {
            if pendingSouvenir != nil { souvenirLines += 1; return }
            emit(.prose(paragraph))
            return
        }
        closeSouvenir()

        if let (items, numbered) = Self.listItems(paragraph) {
            if numbered != pendingListIsNumbered { closeList() }
            pendingListIsNumbered = numbered
            pendingList.append(contentsOf: items)
            return
        }
        closeList()

        // A slip runs from its capitalised title to the line for the date.
        if case .certificate = gathering, paragraph == "Date" || paragraph == "Date:" {
            emit(.kicker("Date"))
            flush()
            return
        }
        if paragraph == paragraph.uppercased(), paragraph.contains("SLIP"), Self.looksLikeHeading(paragraph) {
            flush()
            gathering = .certificate(title: paragraph, items: [])
            return
        }
        if Self.isSummaryTitle(paragraph) {
            flush()
            gathering = .summary(title: paragraph, items: [])
            return
        }
        // Some chapters close on "What We Learned:" with no summary title.
        if paragraph == "What We Learned:", case .none = gathering {
            flush()
            gathering = .summary(title: String(paragraph.dropLast()), items: [])
            return
        }
        if Self.isQuickWin(paragraph) {
            flush()
            let rest = Self.text(afterLabel: paragraph)
            gathering = .quickWin(title: "Quick Win", items: rest.isEmpty ? [] : [.prose(rest)])
            return
        }
        if paragraph.hasPrefix("Your One Sentence Souvenir") || paragraph.hasPrefix("Your One-Sentence Souvenir") {
            flush()
            pendingSouvenir = paragraph
            souvenirLines = 0
            return
        }

        if !openerSeen, let part = Self.part(paragraph) {
            flush()
            // "Part 4: How to Keep Going\nChapter 25: Landing the Plane"
            let lines = paragraph.components(separatedBy: "\n")
            blocks.append(.part(label: part.label, title: part.title, subtitle: nil))
            lastPartIndex = blocks.count - 1
            if lines.count > 1 {
                append(lines.dropFirst().joined(separator: "\n"))
            }
            return
        }
        if let index = lastPartIndex, !openerSeen, paragraph.hasPrefix("("), paragraph.hasSuffix(")"),
           case .part(let label, let title, nil) = blocks[index] {
            blocks[index] = .part(label: label, title: title, subtitle: paragraph)
            return
        }
        if !openerSeen, let opener = Self.opener(paragraph) {
            flush()
            openerSeen = true
            opensChapter = true
            blocks.append(opener)
            return
        }
        // Back matter opens on its bare title: "Glossary", "Disclaimer".
        if !openerSeen, blocks.isEmpty, Self.looksLikeHeading(paragraph), sectionTitle.hasPrefix(paragraph) {
            openerSeen = true
            blocks.append(.opener(kicker: nil, title: paragraph, direction: nil))
            return
        }

        if captionAnchors.contains(paragraph), Self.looksLikeHeading(paragraph) {
            emit(.caption(paragraph))
            return
        }
        if paragraph.localizedCaseInsensitiveContains("generated with Google Notebook") {
            emit(.credit(paragraph))
            return
        }
        if keyLines.contains(paragraph) {
            emit(.keyLine(paragraph))
            return
        }
        if let compass = Self.compass(paragraph) {
            emit(compass)
            return
        }
        // The glossary's letter dividers: "A", "B", "C".
        if paragraph.count == 1, paragraph.first?.isUppercase == true {
            emit(.heading(paragraph, major: true))
            return
        }
        if !notHeadings.contains(paragraph) {
            if majorHeadings.contains(paragraph) || forcedHeadings.contains(paragraph) {
                emitHeading(paragraph)
                return
            }
            if let label = Self.standaloneLabel(paragraph) {
                emit(.kicker(label))
                return
            }
            if Self.looksLikeHeading(paragraph) {
                // "Destination: The Town Square" is a field, not a heading;
                // "Level 2: The Spatial Upgrade" is a heading.
                if let labeled = Self.labeled(paragraph) {
                    if case .labeled(let label, _) = labeled, Self.isHeadingLabel(label) {
                        // falls through to the heading buffer
                    } else {
                        emit(labeled)
                        return
                    }
                }
                if case .quickWin = gathering { flush() }
                pendingHeadings.append(paragraph)
                return
            }
            if let labeled = Self.labeled(paragraph) {
                emit(labeled)
                return
            }
        }

        if opensChapter, !ledeSet, case .none = gathering {
            ledeSet = true
            emit(.lede(paragraph))
            return
        }
        emit(.prose(paragraph))
    }

    private mutating func emitHeading(_ paragraph: String) {
        // A heading ends a Quick Win; the summary card runs to the end.
        if case .quickWin = gathering { flush() }
        emit(.heading(paragraph, major: majorHeadings.contains(paragraph)))
    }

    private mutating func emit(_ block: WonderCompassBlock) {
        closeHeadings()
        place(block)
    }

    private mutating func place(_ block: WonderCompassBlock) {
        switch gathering {
        case .none:
            blocks.append(block)
        case .summary(let title, let items):
            gathering = .summary(title: title, items: items + [block])
        case .quickWin(let title, let items):
            gathering = .quickWin(title: title, items: items + [block])
        case .certificate(let title, let items):
            gathering = .certificate(title: title, items: items + [block])
        }
    }

    private mutating func closeList() {
        guard !pendingList.isEmpty else { return }
        let items = pendingList
        pendingList = []
        emit(pendingListIsNumbered ? .numbered(items) : .list(items))
    }

    private mutating func closeHeadings() {
        guard !pendingHeadings.isEmpty else { return }
        let lines = pendingHeadings
        pendingHeadings = []
        if lines.count == 1 {
            place(.heading(lines[0], major: false))
        } else {
            place(.list(lines))
        }
    }

    private mutating func closeSouvenir() {
        guard let title = pendingSouvenir else { return }
        pendingSouvenir = nil
        blocks.append(.souvenir(title: title, lines: max(2, souvenirLines)))
        souvenirLines = 0
    }

    // MARK: - Recognisers

    /// Bulleted ("\t∙\t…") or numbered ("1.\t…") lines, one or more per paragraph.
    static func listItems(_ paragraph: String) -> (items: [String], numbered: Bool)? {
        let lines = paragraph.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return nil }
        if lines.allSatisfy({ $0.hasPrefix("∙") || $0.hasPrefix("•") }) {
            return (lines.map { String($0.dropFirst()).trimmingCharacters(in: .whitespaces) }, false)
        }
        if lines.allSatisfy({ $0.range(of: #"^[0-9]+[.)]\t"#, options: .regularExpression) != nil }) {
            return (lines, true)
        }
        return nil
    }

    /// "Level 2", "Step 1", "The Science": colon labels that title what follows.
    static func isHeadingLabel(_ label: String) -> Bool {
        let numbered = #"^(Part|Level|Step|Week|Tier|Option|Challenge|Mission|Archetype|Layer|Adaptation|Phase|Stage|Act|Day|Hour|Attempt|Loop|Rule|Recipe|Example|Scenario|Case) [0-9A-Z]+\b"#
        let named = #"^(The (Science|Tool|Physics|Psychology|Neuroscience|Social Science|Hard Data|Research|Biology|Chemistry|History))\b"#
        let time = #"^(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)\b"#
        return [numbered, named, time].contains { label.range(of: $0, options: .regularExpression) != nil }
    }

    static func isSummaryTitle(_ paragraph: String) -> Bool {
        paragraph.range(of: #"^(Chapter|Appendix)( [0-9A-Za-z]+)? Summary:?$"#, options: .regularExpression) != nil
    }

    static func isQuickWin(_ paragraph: String) -> Bool {
        paragraph.hasPrefix("Quick Win:") || paragraph == "Quick Win"
    }

    static func text(afterLabel paragraph: String) -> String {
        guard let colon = paragraph.firstIndex(of: ":") else { return "" }
        return paragraph[paragraph.index(after: colon)...].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func part(_ paragraph: String) -> (label: String, title: String)? {
        let firstLine = paragraph.components(separatedBy: "\n")[0]
        guard let match = firstLine.range(of: #"^Part [0-9]+"#, options: .regularExpression) else { return nil }
        let label = String(firstLine[match])
        let title = firstLine[match.upperBound...]
            .trimmingCharacters(in: CharacterSet(charactersIn: ":-–— ").union(.whitespaces))
        return (label, title)
    }

    static func opener(_ paragraph: String) -> WonderCompassBlock? {
        let line = paragraph.components(separatedBy: "\n")[0].trimmingCharacters(in: .whitespaces)
        let pattern = #"^((?:Chapter|Appendix) [0-9A-Za-z]+|Introduction|READ THIS FIRST)\s*:\s*(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let kickerRange = Range(match.range(at: 1), in: line),
              let titleRange = Range(match.range(at: 2), in: line) else { return nil }
        var kicker = String(line[kickerRange])
        if kicker == "READ THIS FIRST" { kicker = "Read This First" }
        let title = String(line[titleRange]).trimmingCharacters(in: .whitespaces)
        let direction = title.components(separatedBy: " = ").first.flatMap(WonderCompassDirection.init(word:))
        return .opener(kicker: kicker, title: title, direction: title.contains(" = ") ? direction : nil)
    }

    /// "NORTH = NOTICE (The Spark)", "East (Embark): …" and "West: …".
    static func compass(_ paragraph: String) -> WonderCompassBlock? {
        let header = #"^(north|east|south|west|center)\s*=\s*([A-Za-z-]+)\s*(?:\(([^)]*)\))?\s*:?\s*(.*)$"#
        if let groups = captures(header, in: paragraph, options: [.caseInsensitive, .dotMatchesLineSeparators]),
           let direction = WonderCompassDirection(word: groups[0]) {
            let text = groups[3].trimmingCharacters(in: .whitespacesAndNewlines)
            return .compass(direction, label: groups[1].capitalized, detail: groups[2].nonEmpty, text: text.nonEmpty)
        }
        // "East (Embark):" standing alone heads the lines that follow it.
        let bare = #"^(North|East|South|West|Center|NORTH|EAST|SOUTH|WEST|CENTER)\s*\(([^)]*)\):?$"#
        if let groups = captures(bare, in: paragraph, options: []),
           let direction = WonderCompassDirection(word: groups[0]) {
            return .compass(direction, label: groups[1], detail: nil, text: nil)
        }
        let line = #"^(North|East|South|West|Center|NORTH|EAST|SOUTH|WEST|CENTER)\s*(?:\(([^)]*)\))?:\s*(.+)$"#
        if let groups = captures(line, in: paragraph, options: [.dotMatchesLineSeparators]),
           let direction = WonderCompassDirection(word: groups[0]) {
            return .compass(direction, label: groups[1].nonEmpty, detail: nil, text: groups[2])
        }
        return nil
    }

    /// A label on its own line: "Examples:", "The Pro-Tip:".
    static func standaloneLabel(_ paragraph: String) -> String? {
        guard paragraph.hasSuffix(":"), !paragraph.contains("\n") else { return nil }
        let label = String(paragraph.dropLast())
        return isLabel(label) ? label : nil
    }

    static func looksLikeHeading(_ paragraph: String) -> Bool {
        guard paragraph.count <= 80, !paragraph.contains("\n"),
              let first = paragraph.first, first.isUppercase || first.isNumber || first == "$",
              paragraph.split(separator: " ").count <= 12 else { return false }
        // "If yes → You need structure" is one step of a flow, not a title.
        guard !paragraph.contains("→") else { return false }
        // "Record ten seconds of the sound. (The thump of the loom.)"
        guard !paragraph.contains(". ("), !paragraph.contains(".)") else { return false }
        let last = paragraph.last ?? " "
        return !".!?…,;:\"”’'".contains(last) || paragraph.hasSuffix(")")
    }

    private static let lowercaseLabels: Set<String> = [
        "Why this works", "Why it works", "The fix", "The implication", "Your job",
        "The feeling", "The goal", "The rule", "The result", "The lesson",
    ]

    /// "The Bribe: A road soda." A short title-case label, then its text.
    static func labeled(_ paragraph: String) -> WonderCompassBlock? {
        guard let colon = paragraph.firstIndex(of: ":") else { return nil }
        let label = String(paragraph[..<colon])
        let text = paragraph[paragraph.index(after: colon)...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, isLabel(label) else { return nil }
        // "Notice: I wonder where the best bakery is?" is a Compass step.
        if let direction = WonderCompassDirection.allCases.first(where: { $0.step == label }) {
            return .compass(direction, label: label, detail: nil, text: text)
        }
        return .labeled(label: label, text: text)
    }

    private static let smallWords: Set<String> = [
        "a", "an", "the", "of", "for", "to", "and", "or", "in", "on", "vs", "vs.", "with", "&", "+", "=",
        "is", "are", "as", "at", "by", "from", "into", "not", "but", "your", "you",
    ]

    /// Short and title case ("The Bribe", "Group A (Control)"), or one of the
    /// book's few sentence-case labels.
    static func isLabel(_ label: String) -> Bool {
        let words = label.split(separator: " ")
        guard (1...9).contains(words.count), label.count <= 56,
              let opening = label.first, !"\"“‘'".contains(opening) else { return false }
        if lowercaseLabels.contains(label) { return true }
        // Words inside brackets may be any case: "The Micro Compass (Once you arrive)".
        var inBrackets = false
        return words.allSatisfy { word in
            if word.hasPrefix("(") { inBrackets = true }
            defer { if word.hasSuffix(")") { inBrackets = false } }
            if inBrackets { return true }
            let bare = word.drop(while: { "\"“‘'".contains($0) })
            guard let first = bare.first else { return true }
            return first.isUppercase || first.isNumber || smallWords.contains(bare.lowercased())
        }
    }

    private static func captures(_ pattern: String, in text: String, options: NSRegularExpression.Options) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return (1..<match.numberOfRanges).map { index in
            Range(match.range(at: index), in: text).map { String(text[$0]) } ?? ""
        }
    }
}
