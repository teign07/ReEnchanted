import Foundation

/// How a page will sit on the leaves once it is set.
///
/// Pages Rising became a bound book, and that changed what length *means*. A
/// braid used to be a number measured against a band; now it is typeset - the
/// paginator measures real text against a real content box and starts a new
/// leaf when a block overflows. So a page has a physical shape the writer never
/// sees, and two drafts forty words apart can set very differently: one filling
/// its last leaf, the other stranding two lines on a leaf of their own, which
/// the Book then annotates in the margin with "I caught the last loose lines
/// here."
///
/// This is an estimate and says so. The real paginator uses font metrics and
/// UIKit measurement, neither of which exist where the taste engines run, so
/// this counts characters against a line budget. That is far too crude to
/// typeset with and quite good enough to *compare two candidates* with, which
/// is the only thing it is for.
enum FolioSetting {
    /// The leaf's shape, in characters rather than points.
    struct Geometry: Equatable {
        var charactersPerLine: Int
        var linesPerLeaf: Int
        /// The opening leaf also carries the title and the deck.
        var linesLostToOpeningFurniture: Int

        /// Measured off the compact folio: a 510pt leaf less 158pt of header and
        /// action furniture leaves ~352pt of column, and body ink is 17.5pt on
        /// 4pt leading, so about fourteen lines. The column is the leaf width
        /// less a 48pt fore-edge reserve and an 82pt marginalia gutter, which at
        /// 17.5pt serif is roughly thirty-three characters.
        static let compactFolio = Geometry(
            charactersPerLine: 33,
            linesPerLeaf: 14,
            linesLostToOpeningFurniture: 4
        )
    }

    struct Setting: Equatable {
        var leaves: Int
        /// Lines standing on the final leaf. A very small number here is the
        /// orphan the reader turns a page to find.
        var linesOnLastLeaf: Int
        var linesPerLeaf: Int

        /// How full the last leaf is, 0 to 1.
        var lastLeafFill: Double {
            guard linesPerLeaf > 0 else { return 1 }
            return min(1, Double(linesOnLastLeaf) / Double(linesPerLeaf))
        }

        /// A page whose final leaf holds only a line or two. The reader turns a
        /// leaf for almost nothing, and the Book apologises for it in the
        /// margin.
        var strandsAnOrphan: Bool { leaves > 1 && linesOnLastLeaf <= 2 }
    }

    static func setting(
        of text: String,
        geometry: Geometry = .compactFolio
    ) -> Setting {
        let lines = lineCount(of: text, charactersPerLine: geometry.charactersPerLine)
        let first = max(1, geometry.linesPerLeaf - geometry.linesLostToOpeningFurniture)
        guard lines > first else {
            return Setting(leaves: 1, linesOnLastLeaf: lines, linesPerLeaf: geometry.linesPerLeaf)
        }
        let remaining = lines - first
        let extraLeaves = (remaining + geometry.linesPerLeaf - 1) / geometry.linesPerLeaf
        let onLast = remaining - (extraLeaves - 1) * geometry.linesPerLeaf
        return Setting(
            leaves: 1 + extraLeaves,
            linesOnLastLeaf: max(1, onLast),
            linesPerLeaf: geometry.linesPerLeaf
        )
    }

    /// Paragraphs do not share lines, so each one rounds up on its own. Ignoring
    /// that undercounts a page of short paragraphs badly - which is most braids.
    static func lineCount(of text: String, charactersPerLine: Int) -> Int {
        guard charactersPerLine > 0 else { return 0 }
        return text
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .reduce(0) { total, paragraph in
                total + max(1, (paragraph.count + charactersPerLine - 1) / charactersPerLine)
            }
    }

    /// What the setting is worth when choosing between two drafts.
    ///
    /// Small numbers on purpose. How a page *reads* matters more than how it
    /// sets, so this may break a tie between two candidates and must never
    /// outrank whether the page was true, or whether the reader's own material
    /// opened it.
    static func signals(
        for text: String,
        geometry: Geometry = .compactFolio
    ) -> [ProseTaste.Signal] {
        let set = setting(of: text, geometry: geometry)
        // A single-leaf page has no setting to judge and is neither rewarded
        // nor punished for one.
        guard set.leaves > 1 else { return [] }

        // Graded, not bucketed.
        //
        // The first cut scored two buckets - orphan below, full above - and on
        // the bench every long night landed in the dead space between them, so
        // the signal fired for nobody who won and changed two winners only by
        // nudging some other candidate into a tie the alphabet then broke. A
        // preference that only expresses itself through a tie-break is noise.
        // A last leaf half full is mildly worse than one nearly full, and that
        // is a slope rather than a step.
        let fill = set.lastLeafFill
        let raw = Int((fill - 0.55) * 16).clamped(to: -8...6)
        guard raw != 0 else { return [] }
        let description = set.strandsAnOrphan
            ? "strands \(set.linesOnLastLeaf) line(s) on leaf \(set.leaves)"
            : "last leaf \(Int(fill * 100))% full across \(set.leaves) leaves"
        return [ProseTaste.Signal(name: description, points: raw)]
    }
}

extension Int {
    fileprivate func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
