#!/usr/bin/env python3
"""Check interleaf tip fit with extracted production layout and macOS text metrics.

Runs the Swift interpreter, without building the app. AppKit's system serif is
an approximation of UIKit's system serif; device rendering remains a separate
check. Temporary Swift and JSON evidence are saved in --output.
"""
import argparse
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def declaration(source, anchor, indent=0):
    start = source.index(anchor)
    end = re.search(r"(?m)^" + " " * indent + r"}\s*$", source[start:])
    if end is None:
        raise ValueError(anchor)
    return source[start:start + end.end()].rstrip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    folio = (ROOT / "InsideCoverApp/PagesRisingFolio.swift").read_text()
    catalog = (ROOT / "Shared/Illumination.swift").read_text()

    # Ensure the measured policy is used by BOTH selection and rendering.
    boundary = declaration(folio, "    private static func boundaryInterstitial(", 4)
    assert "composition = writingTipComposition" in boundary
    assert "composition: writingTipComposition, alignment: .leading" in boundary
    assert ") <= writingTipBounds.height" in boundary
    assert "isWritingTip ? writingTipBounds.width" in boundary
    assert "isWritingTip ? writingTipBounds.height" in boundary
    assert "isWritingTip ? writingTipBounds.minY" in boundary
    assert "isWritingTip ? quoteY + quoteHeight + 14" in boundary
    footer = declaration(folio, "    private var interstitialFooter:", 4)
    assert "FolioLeafMeasure.interstitialFooterHeight" in footer
    assert "FolioLeafMeasure.interstitialFooterTopPadding" in footer
    fragment = declaration(folio, "    private func fragmentView(", 4)
    assert "ScrollView" not in fragment

    lessons = catalog[catalog.index("enum InterleafWritingCraft {"):catalog.index("    static let texts: [InterleafCuration.Text]")]
    lessons += "\n}"
    measure = declaration(folio, "private enum FolioLeafMeasure {")
    normalizer = declaration(folio, "    var writingTipComposition:", 4)
    line_spacing = declaration(folio, "    func lineSpacing(for role:", 4)
    tracking = declaration(folio, "    func tracking(for role:", 4)
    role_spacing = declaration(folio[folio.index("private enum FolioInkRole:"):], "    var lineSpacing:", 4)
    measured = declaration(folio, "    private static func measuredTextHeight(", 4)
    measured = measured.replace("private static func", "func").replace("UIFont", "NSFont")
    source = "\n".join([
        "import AppKit", lessons, measure,
        "enum FolioInkRole { case title, deck, body, handwritten, underlined, provenance, privacy\n" + role_spacing + "\n}",
        "enum FolioTypeface { case literary, archival, dispatch }",
        "enum FolioParagraphAlignment { case leading; var nsTextAlignment: NSTextAlignment { .left } }",
        "struct FolioLeafComposition { var bodyScale: CGFloat; var lineSpacingScale: CGFloat; var typeScale: CGFloat; var accentsOpeningPhrase = true; var typeface = FolioTypeface.literary\n" + "\n".join([normalizer, line_spacing, tracking]) + "\n}",
        measured,
        r'''
func serif(_ size: CGFloat) -> NSFont {
    let base = NSFont.systemFont(ofSize: size)
    return NSFont(descriptor: base.fontDescriptor.withDesign(.serif)!, size: size)!
}
let lessons = InterleafWritingCraft.lessons
precondition(lessons.count == 21)
let dimensions: [(CGFloat, CGFloat)] = [(318, 430), (327, 480), (345, 596), (382, 596), (520, 720), (650, 880)]
var results: [[String: Any]] = []
var beforeRabbitFits = -1
for (width, height) in dimensions {
    let bounds = FolioLeafMeasure.writingTipBounds(pageWidth: width, pageHeight: height)
    let typeScale = min(1.45, max(1, width / 420))
    for neighborScale: CGFloat in [1, 1.14, 1.30, 1.50, 1.62] {
        let neighbor = FolioLeafComposition(bodyScale: neighborScale, lineSpacingScale: 1.08, typeScale: typeScale)
        let tip = neighbor.writingTipComposition
        precondition(tip.bodyScale == 1 && tip.lineSpacingScale == 1 && !tip.accentsOpeningPhrase)
        precondition(tip.typeScale == typeScale)
        let heights = lessons.map {
            measuredTextHeight($0.text, role: .body, font: serif(17.5 * tip.bodyScale * tip.typeScale),
                width: bounds.width, composition: tip, alignment: .leading)
        }
        let fitting = heights.filter { $0 <= bounds.height }.count
        // Short leaves may exclude long tips, but must retain a usable pool.
        precondition(fitting > 0, "Tip pool lost at \(width)x\(height)")
        if height >= 596 { precondition(fitting == lessons.count) }
        // Attribution and its bottom breathing room must stay ABOVE the footer.
        for inkHeight in heights where inkHeight <= bounds.height {
            let attributionBottom = bounds.minY + max(82, inkHeight) + 14 + 26
            let footerTop = FolioLeafMeasure.paperFieldHeight(pageHeight: height)
                - FolioLeafMeasure.interstitialFooterHeight - FolioLeafMeasure.interstitialFooterTopPadding
            precondition(attributionBottom + 8 <= footerTop)
        }
        results.append(["width": width, "height": height, "neighborBodyScale": neighborScale,
            "eligible": fitting, "catalogCount": lessons.count, "largestTextHeight": heights.max()!,
            "availableTextHeight": bounds.height])
        if width == 345 && height == 596 && neighborScale == 1.50 {
            let oldWidth = FolioLeafMeasure.paperFieldWidth(pageWidth: width) - 84
            let oldHeight = max(82, max(214, height - 256) - 104)
            beforeRabbitFits = lessons.filter {
                measuredTextHeight($0.text, role: .body, font: serif(17.5 * neighbor.bodyScale),
                    width: oldWidth, composition: neighbor, alignment: .leading) <= oldHeight
            }.count
            precondition(beforeRabbitFits == 0, "Fixture did not reproduce the reported disappearance")
        }
    }
}
// The three already-seen tips cannot exhaust a healthy layout's 21-tip pool.
let seen = Set(["concrete-spoon", "specific-mug", "world-bench"])
precondition(lessons.filter { !seen.contains($0.id) }.count == 18)
let report: [String: Any] = ["metricEngine": "AppKit system serif; UIKit render not exercised",
    "beforeRabbitEligible": beforeRabbitFits, "afterRabbitEligible": 21,
    "unseenTipsRemaining": 18, "layoutsChecked": results.count, "results": results]
let bytes = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
try bytes.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
print("PASS: 21/21 tips fit on Rabbit portrait; \(results.count) layouts retain fitting tips; old Rabbit layout admitted \(beforeRabbitFits)/21.")
''',
    ])
    swift = args.output / "check.swift"
    swift.write_text(source)
    subprocess.run(["xcrun", "swift", "-module-cache-path", str(args.output / "module-cache"),
                    str(swift), str(args.output / "results.json")], check=True, cwd=ROOT)
    report = json.loads((args.output / "results.json").read_text())
    print(json.dumps({k: v for k, v in report.items() if k != "results"}, indent=2))


if __name__ == "__main__":
    main()
