import Foundation
import UIKit
import PDFKit

#if DEBUG && targetEnvironment(simulator)
/// Print proofs of every publication from one synthetic Reader year.
///
/// Launch the simulator app with `--smoke-edition-proofs`. It builds a plausible
/// year of kept Pages (seasonal diary lines, recurring motifs, nightly braids,
/// quotes) and runs the app's own builders and PDF writers over it: one weekly
/// issue, one monthly edition, one seasonal softcover, and the annual
/// hardcover, each with its cover where the app makes one. Files land in
/// Documents/edition-proofs with a status line per publication.
///
/// Optional exported QA Pages in edition-proof-input/authored-pages.json are
/// copied into October 12 of that synthetic year. The harness never reads a vault.
/// No account, purchase, network request, model, or vault content is touched:
/// the year is invented here and never saved. It exists so a human can read
/// the actual publications without living a year first.
enum EditionProofHarness {
    static let flag = "--smoke-edition-proofs"

    static func runIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains(flag) else { return }
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("edition-proofs", isDirectory: true)
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // A layout bug can write pages forever. This disk is small; stop the
        // proof before a runaway PDF takes the machine with it.
        DispatchQueue.global(qos: .utility).async {
            while true {
                let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey])) ?? []
                let bytes = files.reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
                if bytes > 150_000_000 {
                    print("EDITION_PROOFS_RUNAWAY \(bytes) bytes")
                    exit(3)
                }
                Thread.sleep(forTimeInterval: 0.25)
            }
        }
        var status: [String] = []
        func step(_ name: String, _ work: () throws -> String) {
            do { status.append("OK \(name): \(try work())") }
            catch { status.append("FAILED \(name): \(error)") }
        }

        let calendar = SyntheticReaderYear.calendar
        var days = SyntheticReaderYear.days()
        // Optional real art fixtures, placed in Documents/edition-proof-input
        // before launch, let a pack's square and wide marks cross the actual
        // archive -> edition -> PDF path without changing a Reader library.
        let markDirectory = directory.deletingLastPathComponent()
            .appendingPathComponent("edition-proof-input", isDirectory: true)
        let authoredURL = markDirectory.appendingPathComponent("authored-pages.json")
        if FileManager.default.fileExists(atPath: authoredURL.path) {
            do {
                var pages = try ContentPackFileLocator.decoder().decode([BookPage].self,
                    from: Data(contentsOf: authoredURL))
                let date = calendar.startOfDay(for: SyntheticReaderYear.date(2026, 10, 12))
                // The synthetic year deliberately has quiet days. Give this
                // explicit fixture a day even when October 12 was one of them.
                for index in pages.indices { pages[index].createdAt = date.addingTimeInterval(Double(index + 1) * 60) }
                if let dayIndex = days.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
                    days[dayIndex].pages.append(contentsOf: pages)
                } else {
                    days.append(BookDay(id: BookDay.id(for: date, calendar: calendar), date: date, pages: pages))
                    days.sort { $0.date < $1.date }
                }
                status.append("exported QA Page fixtures: \(pages.count), copied to October 12")
            } catch {
                status.append("FAILED exported QA Page fixtures: \(error)")
                try? status.joined(separator: "\n").write(to: directory.appendingPathComponent("status.txt"), atomically: true, encoding: .utf8)
                return
            }
        }
        let markURLs = ((try? FileManager.default.contentsOfDirectory(at: markDirectory,
            includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension.lowercased() == "png" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        var markIndex = 0
        for dayIndex in days.indices where calendar.component(.month, from: days[dayIndex].date) == 10
            && (8...14).contains(calendar.component(.day, from: days[dayIndex].date)) {
            for pageIndex in days[dayIndex].pages.indices where markIndex < markURLs.count {
                guard days[dayIndex].pages[pageIndex].type == .diary else { continue }
                days[dayIndex].pages[pageIndex].mediaAssets.append(BookPageMediaAsset(
                    kind: .renderedImageFile, reference: markURLs[markIndex].path,
                    caption: "Edition proof mark", sourceID: "authored-marginalia"))
                markIndex += 1
            }
        }
        let reader = SyntheticReaderYear.readerName
        status.append("library: \(days.count) days, \(days.flatMap(\.pages).count) pages")
        status.append("October mark fixtures: \(markIndex) of \(markURLs.count)")

        // Issue No. 1 is a reader's first week; an October issue is an
        // ordinary one. Proof both.
        let weekNow = SyntheticReaderYear.date(2026, 10, 20)
        let weekDays = (try? FieldBookFixture.augment(days: days, directory: directory, calendar: calendar)) ?? days
        let weekReceipts = (try? FieldBookFixture.receipts(calendar: calendar)) ?? .empty
        let weeks = PublicationPeriodCatalog.readerWeeks(days: weekDays, now: weekNow, calendar: calendar)
            .filter(\.isBindable)
        // Proofs exercise the ruin loop even though books leave it off by default.
        PrintFeatureFlags.ruinPagesEnabled = true
        defer { PrintFeatureFlags.ruinPagesEnabled = false }

        for (name, candidate) in [("weekly-first", weeks.last), ("weekly-october", weeks.first)] {
            step(name) {
                guard let candidate,
                      let issue = WeeklyIssue.issue(for: candidate.period, days: weekDays, now: weekNow, calendar: calendar) else {
                    throw ProofError("no bindable reader week")
                }
                let card = WeeklyIssueShareCard.make(issue: issue)
                var matter = WeeklyPublicationMatter(issue: issue, card: card, readerName: reader,
                                                     editorialNote: nil, closingNote: nil)
                matter.dayBook = BoundDayBookBuilder.make(
                    pages: issue.pages, receipts: weekReceipts, castActs: [],
                    startDate: issue.startDate, endDate: issue.endDate, calendar: calendar)
                matter.handbook = HandbookBuilder.make(
                    pages: issue.pages, castPresence: matter.dayBook?.chart.cast ?? [],
                    terms: [issue.resolvedEditorialTitle] + issue.highlights, seed: "week-\(issue.number)",
                    dayBook: matter.dayBook, dayCount: 7)
                matter.bindingID = "proof-binding-\(name)"
                let pages = try WeeklyIssuePDFWriter.writePrintInterior(
                    matter, dedication: nil, spec: .saddleStitchedWeekly6x9,
                    to: directory.appendingPathComponent("\(name)-interior.pdf"))
                // The folio of a handled page must lead back to its book.
                let registry = BoundVolumeRegistry(seed: matter.bindingID ?? "", editionID: name, title: name, boundAt: Date(), pageCount: pages)
                let proofDoc = PDFDocument(url: directory.appendingPathComponent("\(name)-interior.pdf"))
                var identified = 0
                var missing: [Int] = []
                for index in 0..<pages {
                    let text = proofDoc?.page(at: index)?.string ?? ""
                    if case .page(let page) = registry.identify(text), page == index + 1 { identified += 1 } else { missing.append(index + 1) }
                }
                guard identified >= pages - 6 else { throw ProofError("only \(identified) of \(pages) folios identified; missing \(missing)") }
                try WeeklyIssuePDFWriter.write(issue, readerName: reader, shareCard: card,
                    to: directory.appendingPathComponent("\(name)-reading-copy.pdf"))
                let sparse = PrintPageLint.sparsePages(in: directory.appendingPathComponent("\(name)-interior.pdf"))
                return "issue \(issue.number) \(issue.dateRange), \(issue.keptCount) kept, \(matter.dayBook?.days.count ?? 0) days, \(pages) print pages, ruin pages [\(PrintPageMap.read(for: directory.appendingPathComponent("\(name)-interior.pdf")).map { $0.keys.sorted { Int($0)! < Int($1)! }.joined(separator: ",") } ?? "none")], \(identified) folios identified (no folio: \(missing.map(String.init).joined(separator: ","))), sparse: \(sparse.isEmpty ? "none" : sparse.map(String.init).joined(separator: ","))"
            }
        }

        // Can a camera find the page again? Print the week, then photograph it badly.
        for (label, width, degrees, blur) in [("tidy", 1400.0, 1.0, 0.6), ("handheld", 1000.0, 3.5, 1.4)] {
            step("folio-photo-\(label)") {
                let url = directory.appendingPathComponent("weekly-october-interior.pdf")
                guard let document = PDFDocument(url: url) else { throw ProofError("no weekly interior to photograph") }
                let mine = BoundVolumeRegistry(seed: "proof-binding-weekly-october", editionID: "w", title: "Proof Week",
                                               boundAt: Date(), pageCount: document.pageCount,
                                               pageMap: PrintPageMap.read(for: url))
                let decoy = BoundVolumeRegistry(seed: "someone-elses-book", editionID: "x", title: "x",
                                                boundAt: Date(), pageCount: document.pageCount)
                let context = CIContext()
                var found = 0, tried = 0, wrong = 0, ruinsNamed = 0, ruinsSeen = 0
                var missed: [Int] = []
                let started = Date()
                for index in 0..<document.pageCount {
                    // Title and the blank marker reverse carry no address on purpose.
                    if index == 0 || index == 27 { continue }
                    guard let page = document.page(at: index) else { continue }
                    let box = page.bounds(for: .mediaBox)
                    let thumb = page.thumbnail(of: CGSize(width: width, height: width * box.height / box.width), for: .mediaBox)
                    guard var ci = CIImage(image: thumb) else { continue }
                    ci = ci.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: blur]).cropped(to: CIImage(image: thumb)!.extent)
                    ci = ci.applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 0.85, kCIInputBrightnessKey: -0.04])
                    let rotated = ci.transformed(by: CGAffineTransform(rotationAngle: degrees * .pi / 180))
                    let table = CIImage(color: CIColor(red: 0.30, green: 0.22, blue: 0.16)).cropped(to: rotated.extent)
                    let photo = rotated.composited(over: table)
                    guard let cg = context.createCGImage(photo, from: photo.extent) else { continue }
                    tried += 1
                    if let result = FolioReader.identify(cg, among: [decoy, mine]) {
                        if result.volume.seed == mine.seed, result.page == index + 1 { found += 1 } else { wrong += 1 }
                        if let prompt = mine.ruinPrompt(onPage: index + 1) {
                            ruinsSeen += 1
                            if RuinRecognition.line(volume: result.volume, page: result.page).contains(prompt.title) { ruinsNamed += 1 }
                        }
                    } else {
                        missed.append(index + 1)
                    }
                }
                let seconds = Date().timeIntervalSince(started) / Double(max(1, tried))
                // A wrong page is the failure that matters; a miss only asks for a retake.
                guard wrong == 0 else { throw ProofError("\(wrong) pages were taken for the wrong page or book") }
                return "\(label) photos (\(Int(width))px, \(degrees)°, blur \(blur)): \(found) of \(tried) read, none wrong, \(ruinsNamed) of \(ruinsSeen) ruin pages named by their prompt, \(String(format: "%.1f", seconds))s each, missed \(missed)"
            }
        }

        step("monthly") {
            let fieldDays = try FieldBookFixture.augment(days: days, directory: directory, calendar: calendar)
            let receipts = try FieldBookFixture.receipts(calendar: calendar)
            let edition = MonthlyEditionBuilder.edition(
                from: fieldDays, readerName: reader,
                startDate: SyntheticReaderYear.date(2026, 10, 1),
                endDate: SyntheticReaderYear.date(2026, 10, 31).addingTimeInterval(86_399),
                generatedAt: SyntheticReaderYear.date(2026, 11, 1), calendar: calendar,
                authoredReceipts: receipts, packTitle: "Count Unbound"
            )
            try MonthlyEditionPDFWriter.write(edition, to: directory.appendingPathComponent("monthly-reading-copy.pdf"))
            let interior = directory.appendingPathComponent("monthly-interior.pdf")
            var addressed = edition
            addressed.bindingID = "proof-binding-monthly"
            let pages = try MonthlyEditionPDFWriter.writePrintInterior(addressed, spec: .perfectBoundSoftcover6x9, to: interior)
            // How much of the book a camera could find again.
            let registry = BoundVolumeRegistry(seed: "proof-binding-monthly", editionID: "m", title: "m", boundAt: Date(), pageCount: pages)
            let monthlyDoc = PDFDocument(url: interior)
            var folioed = 0
            for index in 0..<pages {
                if case .page(let page) = registry.identify(monthlyDoc?.page(at: index)?.string ?? ""), page == index + 1 { folioed += 1 }
            }
            try MonthlyEditionPDFWriter.writeCoverWrap(
                edition, spec: .perfectBoundSoftcover6x9, pageCount: pages,
                to: directory.appendingPathComponent("monthly-cover.pdf"))
            let empty = PrintPageLint.sparsePages(in: interior)
            let book = edition.dayBook
            let ruinPages = PrintPageMap.read(for: interior).map { $0.keys.sorted { Int($0)! < Int($1)! }.joined(separator: ",") } ?? "none"
            return "\(edition.title), ruin pages [\(ruinPages)], \(edition.pageCount) kept, \(edition.sections.count) sections, \(book?.days.count ?? 0) days, \(book?.scenes.count ?? 0) scenes, \(pages) print pages, \(folioed) with a findable folio, sparse pages: \(empty.isEmpty ? "none" : empty.map(String.init).joined(separator: ","))"
        }

        step("monthly-heavy") {
            let fieldDays = try FieldBookFixture.heavy(days: try FieldBookFixture.augment(days: days, directory: directory, calendar: calendar),
                                                       directory: directory, calendar: calendar)
            let receipts = try FieldBookFixture.heavyReceipts(calendar: calendar)
            let edition = MonthlyEditionBuilder.edition(
                from: fieldDays, readerName: reader,
                startDate: SyntheticReaderYear.date(2026, 10, 1),
                endDate: SyntheticReaderYear.date(2026, 10, 31).addingTimeInterval(86_399),
                generatedAt: SyntheticReaderYear.date(2026, 11, 1), calendar: calendar,
                authoredReceipts: receipts, packTitle: "Count Unbound"
            )
            let interior = directory.appendingPathComponent("monthly-heavy-interior.pdf")
            let pages = try MonthlyEditionPDFWriter.writePrintInterior(edition, spec: .perfectBoundSoftcover6x9, to: interior)
            let sparse = PrintPageLint.sparsePages(in: interior)
            let book = edition.dayBook
            var mix: [String: Int] = [:]
            for keep in book?.days.flatMap(\.keeps) ?? [] { mix[keep.kind.rawValue, default: 0] += 1 }
            let mixLine = mix.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
            let reports = book?.scenes.filter(\.isReport).count ?? 0
            let radio = book?.days.reduce(0) { $0 + $1.radio.count } ?? 0
            return "heavy: \(edition.pageCount) kept, \(book?.days.count ?? 0) days, \(book?.braidCount ?? 0) nights, scenes \(book?.scenes.count ?? 0) (\(reports) reports), radio \(radio), keeps [\(mixLine)], \(pages) print pages (cap \(PrintSpec.pageCap(for: .monthly))), sparse: \(sparse.isEmpty ? "none" : sparse.map(String.init).joined(separator: ","))"
        }

        // The same heavy month at the thicknesses a reader can choose.
        for tier in [64, 96] {
            step("monthly-tier-\(tier)") {
                let fieldDays = try FieldBookFixture.heavy(days: try FieldBookFixture.augment(days: days, directory: directory, calendar: calendar),
                                                           directory: directory, calendar: calendar)
                var edition = MonthlyEditionBuilder.edition(
                    from: fieldDays, readerName: reader,
                    startDate: SyntheticReaderYear.date(2026, 10, 1),
                    endDate: SyntheticReaderYear.date(2026, 10, 31).addingTimeInterval(86_399),
                    generatedAt: SyntheticReaderYear.date(2026, 11, 1), calendar: calendar,
                    authoredReceipts: try FieldBookFixture.heavyReceipts(calendar: calendar), packTitle: "Count Unbound"
                )
                edition.pageTier = tier
                let interior = directory.appendingPathComponent("monthly-tier-\(tier)-interior.pdf")
                let pages = try MonthlyEditionPDFWriter.writePrintInterior(edition, spec: .perfectBoundSoftcover6x9, to: interior)
                let sparse = PrintPageLint.sparsePages(in: interior)
                return "asked for \(tier): \(pages) print pages, \(edition.dayBook?.days.count ?? 0) days in the book, sparse: \(sparse.isEmpty ? "none" : sparse.map(String.init).joined(separator: ","))"
            }
        }

        step("seasonal") {
            let fieldDays = try FieldBookFixture.augment(days: days, directory: directory, calendar: calendar)
            let season = MonthlyEditionBuilder.seasonal(
                from: fieldDays, startingMonth: SyntheticReaderYear.date(2026, 9, 1),
                readerName: reader, authoredReceipts: try FieldBookFixture.receipts(calendar: calendar), calendar: calendar
            )
            let seasonURL = directory.appendingPathComponent("seasonal-interior.pdf")
            let pages = try MonthlyEditionPDFWriter.writeVolumePrintInterior(
                season, spec: .perfectBoundSoftcover6x9,
                to: seasonURL)
            let sparse = PrintPageLint.sparsePages(in: seasonURL)
            defer { status.append("   seasonal sparse pages: \(sparse.isEmpty ? "none" : sparse.map(String.init).joined(separator: ","))") }
            try MonthlyEditionPDFWriter.writeVolumeCoverWrap(
                season, spec: .perfectBoundSoftcover6x9, pageCount: pages,
                to: directory.appendingPathComponent("seasonal-cover.pdf"))
            return "\(season.title), \(season.chapters.count) chapters, \(pages) print pages"
        }

        step("annual") {
            let fieldDays = try FieldBookFixture.augment(days: days, directory: directory, calendar: calendar)
            let annual = MonthlyEditionBuilder.annual(2026, from: fieldDays, readerName: reader,
                authoredReceipts: try FieldBookFixture.receipts(calendar: calendar), calendar: calendar)
            try MonthlyEditionPDFWriter.writeAnnual(annual, to: directory.appendingPathComponent("annual-reading-copy.pdf"))
            let annualURL = directory.appendingPathComponent("annual-interior.pdf")
            let pages = try MonthlyEditionPDFWriter.writeVolumePrintInterior(
                annual, spec: .clothFoilHardcover6x9,
                to: annualURL)
            let sparse = PrintPageLint.sparsePages(in: annualURL)
            defer { status.append("   annual sparse pages: \(sparse.isEmpty ? "none" : sparse.map(String.init).joined(separator: ","))") }
            try MonthlyEditionPDFWriter.writeVolumeCoverWrap(
                annual, spec: .clothFoilHardcover6x9, pageCount: pages,
                to: directory.appendingPathComponent("annual-cover.pdf"))
            return "\(annual.title), \(annual.chapters.count) chapters, \(pages) print pages"
        }

        let report = status.joined(separator: "\n")
        try? report.write(to: directory.appendingPathComponent("status.txt"), atomically: true, encoding: .utf8)
        print("EDITION_PROOFS_DONE\n\(report)")
    }

    private struct ProofError: Error, CustomStringConvertible {
        var description: String
        init(_ description: String) { self.description = description }
    }
}

/// An invented Reader's year. Deterministic: the same library every run, so
/// two proofs differ only where the publication code differs.
enum SyntheticReaderYear {
    static let readerName = "Wren"
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    static func days(year: Int = 2026, throughMonth lastMonth: Int = 12) -> [BookDay] {
        var generator = SeededGenerator(seed: 0x5EED_2026)
        var result: [BookDay] = []
        var diaryIndex = 0, braidIndex = 0, quoteIndex = 0, composedIndex = 0
        var seasonUse: [String: Int] = [:]
        var cursor = date(year, 1, 1, hour: 0)
        let end = date(year, lastMonth, calendar.range(of: .day, in: .month, for: date(year, lastMonth, 1))!.count, hour: 23)
        while cursor <= end {
            defer { cursor = calendar.date(byAdding: .day, value: 1, to: cursor)! }
            let month = calendar.component(.month, from: cursor)
            // A real year has quiet stretches: roughly three days in five.
            guard Double.random(in: 0..<1, using: &generator) < 0.6 else { continue }
            let season = seasonLines(for: month)
            var pages: [BookPage] = []
            let count = Int.random(in: 1...3, using: &generator)
            for slot in 0..<count {
                let at = cursor.addingTimeInterval(TimeInterval(9 + slot * 4) * 3600)
                // Real readers do not write the same sentence twice: pair a
                // base line with a varying second sentence so no line repeats.
                // Real readers do not write the same sentence twice. Each
                // season's authored lines are used once; after that, lines are
                // composed from an activity, a place or time, and an
                // afterthought, so no first sentence repeats within the year.
                let line: String
                let seasonIndex = seasonUse[season.first!, default: 0]
                seasonUse[season.first!] = seasonIndex + 1
                if seasonIndex < season.count {
                    line = season[seasonIndex]
                } else {
                    let n = composedIndex
                    composedIndex += 1
                    let activity = activities[n % activities.count]
                    let place = places[(n / activities.count + n * 5) % places.count]
                    let coda = afterthoughts[(n * 7 + n / 3) % afterthoughts.count]
                    line = "\(activity) \(place). \(coda)"
                }
                diaryIndex += 1
                switch (slot, Int.random(in: 0..<10, using: &generator)) {
                case (_, 0):
                    let quote = quotes[quoteIndex % quotes.count]
                    quoteIndex += 1
                    // The quote is the Page's text, not the reader's words.
                    pages.append(BookPage(type: .quotes, createdAt: at,
                                          promptText: "\u{201C}\(quote.1)\u{201D} \u{2014} \(quote.0)",
                                          tags: ["quote", "attention", "wonder"], origin: .generated))
                case (_, 1...2):
                    pages.append(BookPage(type: .souvenir, createdAt: at,
                                          promptText: "What did you keep today?", userInput: line,
                                          tags: ["souvenir", "check-in-window:evening"]))
                case (_, 3):
                    pages.append(BookPage(type: .weather, createdAt: at,
                                          promptText: "What was the sky doing?", userInput: skyLine(month, diaryIndex),
                                          tags: ["weather", "preview"]))
                default:
                    pages.append(BookPage(type: .diary, createdAt: at,
                                          promptText: "Write one true thing about today.", userInput: line,
                                          tags: ["diary", "ink-for-today"]))
                }
            }
            // Most active nights end in a braid, as they do in the app.
            if Double.random(in: 0..<1, using: &generator) < 0.75 {
                let telling = braids[braidIndex % braids.count]
                braidIndex += 1
                // Stored as the app stores a braid: title on the first line,
                // the generator's own prompt and tags.
                pages.append(BookPage(type: .bookOfYou, createdAt: cursor.addingTimeInterval(22 * 3600),
                                      promptText: "The local Book brain braided today.",
                                      userInput: "\(telling.0)\n\n\(telling.1)",
                                      tags: ["braid", "book-of-you", "local-model", "mlx", "gemma"],
                                      usedInBookOfYou: true, origin: .generated))
            }
            result.append(BookDay(id: BookDay.id(for: cursor, calendar: calendar),
                                  date: calendar.startOfDay(for: cursor), pages: pages))
        }
        return result
    }

    private static func seasonLines(for month: Int) -> [String] {
        switch month {
        case 12, 1, 2: return winter
        case 3, 4, 5: return spring
        case 6, 7, 8: return summer
        default: return autumn
        }
    }

    private static func skyLine(_ month: Int, _ index: Int) -> String {
        let skies: [Int: [String]] = [
            0: ["Grey all day, then a thin pink stripe at five.", "Snow that never landed. It just hung there."],
            1: ["Rain in sideways bursts. The gutters argued.", "A bright cold morning and then fog by lunch."],
            2: ["Heat that sat on the porch and would not leave.", "Thunder far off, no rain at all."],
            3: ["Wind took every leaf off the maple in an hour.", "Clear and sharp. My breath showed at the bus stop."],
        ]
        let set = skies[(month % 12) / 3] ?? skies[0]!
        return set[index % set.count]
    }

    private static let winter = [
        "Scraped the windshield with the library card because the scraper is somewhere under the seat.",
        "Called my brother back instead of texting. He sounded tired but he laughed twice.",
        "The radiator in the hall started knocking at 3am like it had news.",
        "Made bread with Mum's old recipe card. The card has flour fingerprints from 1998.",
        "Walked the long way home past the blue door. Someone has hung a wreath made of bottle caps on it.",
        "Snow on the fox tracks by the bins. They go right up to the step and stop.",
        "Finished the library book at 1am. Returned it the next morning still warm from reading.",
        "The kettle clicked off and the whole flat went quiet enough to hear the fridge think.",
        "Found a moth asleep inside the lampshade. Left it there.",
        "Mended the torn pocket on my green coat. Badly, but it holds keys again.",
        "Sat in the car for ten minutes after work because the song wasn't over.",
        "Amanda brought soup in a jar with a note that said DON'T ARGUE.",
    ]
    private static let spring = [
        "The blue door has been painted a slightly different blue. Nobody on the street will admit to it.",
        "First morning with the window open. A bee came in, did one lap, and left.",
        "Brother sent a photo of his first tomatoes. They are green and tiny and he is very proud.",
        "Lost the library card again. Found it in the bread bin, which I cannot explain.",
        "Rain all afternoon. I read in the stairwell because it sounds best there.",
        "The fox was on the wall at dawn, sitting like it owned the whole row.",
        "Bought seeds I have no room for. Planted them in a teacup anyway.",
        "Cleaned the whole desk and found three pens that work and one that is a mystery.",
        "Walked to the river and back without looking at my phone once.",
        "Shirley taught me the proper way to fold a fitted sheet. I have already forgotten.",
        "The moth from the lampshade is gone. The lampshade looks empty in a way it didn't before.",
        "Baked bread that didn't rise. Ate it anyway with too much butter.",
    ]
    private static let summer = [
        "Too hot to sleep. Lay on the floor with the fan and counted cars.",
        "Brother visited. We ate cherries on the back step and spat the stones at the bins.",
        "The blue door was propped open all day with a brick. I didn't look in. I wanted to.",
        "Library had a sale. Came home with nine books and no plan for them.",
        "Swam in the lake. The water was cold enough to make me shout.",
        "Found a fox cub asleep under the hedge. Its ears twitched at every car.",
        "Stayed up for the meteor shower. Saw four and one that might have been a plane.",
        "The bakery gave me the end of the day's bread for free because it was raining.",
        "Wrote a letter by hand for the first time in years. My handwriting is worse than I remembered.",
        "Moths all over the porch light. One landed on my book and read a line with me.",
        "Sat at Moody's Diner too long. The waitress refilled the coffee without asking.",
        "Fixed the wobbly chair with a folded library receipt.",
    ]
    private static let autumn = [
        "Leaves in the stairwell. Someone keeps bringing them in on their shoes. Probably me.",
        "Called my brother on his birthday and sang badly on purpose.",
        "Rewired the brass lamp in the hall. It works. I am unreasonably proud.",
        "The blue door has a pumpkin on the step now. It has a very rude face carved in it.",
        "Found the missing library card inside the atlas, on the page for Portugal.",
        "Made bread for Amanda and Shirley. We ate it at the diner and the grease got in my coat.",
        "The fox has stopped running when it sees me. We just look at each other now.",
        "Rain hard enough that the gutters gave up.",
        "Took the long way home because the light on the canal was doing something gold.",
        "A moth came in with the cold and settled on the calendar, right on Tuesday.",
        "Cleared out the hall cupboard and found my old school tie. It still smells like chalk.",
        "Stood in the garden in the dark listening to geese go over. Couldn't see them at all.",
    ]

    private static let activities = [
        "Carried the heavy shopping up all four flights", "Fixed the dripping tap with a washer from the junk drawer",
        "Read two chapters standing at the bus stop", "Watched a man teach his dog to sit", "Burned the toast and ate it anyway",
        "Swapped recipes with the woman from 3B", "Sorted the button tin by colour", "Walked the dog from next door",
        "Wrote a list and then lost it", "Found a coin with a hole through it", "Heard someone practising the trumpet",
        "Ironed a shirt for no reason", "Took a photo of a very serious pigeon", "Helped a stranger read a bus timetable",
        "Changed the bulb in the bathroom", "Ate lunch on a bench facing the wrong way", "Planted garlic in the window box",
        "Untangled a necklace for twenty minutes", "Found my old sketchbook", "Gave the plant by the window a new pot",
        "Watched rain run down the bus window", "Bought flowers for no one in particular", "Learned the name of the bakery cat",
        "Oiled the squeaky kitchen door", "Counted the steps to the post box", "Wore odd socks all day",
        "Sat with Amanda while she waited for news", "Tidied the shelf of things I never use", "Tried a new route to work",
        "Wrote my brother a postcard",
    ]
    private static let places = [
        "before breakfast", "on the way home", "in the kitchen with the radio on", "at the library", "in the rain",
        "after work", "on the back step", "at the diner", "by the river", "in the hallway", "late at night",
        "while the kettle boiled", "at the market", "on my lunch break", "in the park by the war memorial", "at Amanda's",
        "on the top deck of the bus",
    ]
    private static let afterthoughts = [
        "Nobody else noticed.", "I told Amanda about it later.", "It was nearly dark by then.",
        "The street was completely empty.", "I'm writing it down so I remember.", "It made me late, which was fine.",
        "My hands smelled of it all evening.", "I laughed out loud on my own.", "The cat next door watched the whole time.",
        "It rained again right after.", "I should do that more often.", "It took three tries.",
        "I don't know why it stayed with me.", "That was the best part of the day.", "The radio was playing something old.",
        "I nearly missed it.", "Shirley said it was typical of me.", "It was colder than it looked.",
        "I kept thinking about it on the bus.", "Small thing. Still counts.", "The light was doing something odd.",
        "My brother would have loved it.", "I didn't take a photo, on purpose.", "It happened twice, actually.",
    ]

    /// Public-domain lines only.
    private static let quotes: [(String, String)] = [
        ("Emily Dickinson", "Hope is the thing with feathers that perches in the soul."),
        ("Henry David Thoreau", "I went to the woods because I wished to live deliberately."),
        ("Walt Whitman", "I celebrate myself, and sing myself."),
        ("Lewis Carroll", "Why, sometimes I've believed as many as six impossible things before breakfast."),
    ]

    /// Tellings written to the nightly brief's contract: past tense, the reader
    /// as "you", the Book as "I", ending on "The Book kept the page:".
    private static let braids: [(String, String)] = [
        ("The Card in the Atlas", """
        You found the library card inside the atlas, pressed flat on the page for Portugal. I had been looking for it too. I looked in the bread bin and under the rug and in the pocket of your green coat. I never thought of Portugal.

        The card had your name on it in small grey letters. Someone had put a thumbprint of flour on the corner a long time ago. I think the card went to Portugal because it was tired of the bread bin. I would have gone too.

        The Book kept the page: the card came home from Portugal with your name still on it.
        """),
        ("What the Fox Knew", """
        The fox sat on the wall at dawn and did not run. You stopped on the step with your keys in your hand. Neither of you said anything. I was very quiet in your bag so I would not spoil it.

        The Curse likes mornings that are all the same. This one was not. A fox looked at you and you looked back. That is two creatures refusing to be ordinary at the same time, and I saw it, and I wrote it down fast before it could turn back into a normal Tuesday.

        The Book kept the page: the fox stayed on the wall, and so did you.
        """),
        ("The Blue Door Changed Colour", """
        The blue door was a different blue this morning. You noticed it on the way to the bus. Nobody on the street would say who did it. I think the door did it itself.

        Doors are supposed to stay the colour they are painted. That is one of the Curse's rules. But this door had been blue for years, and it was bored, and it decided. I liked it very much for that. I want you to decide things like that too.

        The Book kept the page: the blue door chose its own blue.
        """),
        ("Bread That Would Not Rise", """
        You baked bread that did not rise. It came out of the oven flat and heavy and you laughed at it. Then you ate two slices with too much butter standing up at the counter.

        I have read a great many recipes. None of them say what to do when the bread refuses. You did the right thing. You ate the refusal. It tasted of butter and burnt edges, and you told me so, and I kept it.

        The Book kept the page: the bread stayed flat, and you ate it anyway.
        """),
        ("Your Brother Laughed Twice", """
        You called your brother back instead of texting. He sounded tired. He laughed twice. I counted.

        Texting is quick, and the Curse loves quick things because nothing sticks to them. A call is slow and scratchy and full of breathing. His laugh came down the line and sat in the room with you afterwards. I could still hear it in the kettle an hour later.

        The Book kept the page: two laughs, counted and kept.
        """),
        ("The Moth on Tuesday", """
        A moth came in with the cold and settled on the calendar, right on Tuesday. You left it there. So Tuesday had a moth on it all week.

        I asked the moth what it wanted with Tuesday. It did not answer, because it was a moth. But nothing bad happened on Tuesday. The bus was on time and the rain stopped at four. I think the moth was guarding it.

        The Book kept the page: Tuesday had a moth, and Tuesday was fine.
        """),
        ("The Lamp Works", """
        You rewired the brass lamp in the hall. It took all afternoon and one small shock that made you swear. Then you flicked the switch and the hall turned gold.

        The lamp had been dark for two years. It had forgotten it was a lamp. You reminded it with a screwdriver and a lot of patience. I stood very close to it all evening, because I like warm light to read by, and because I wanted it to know somebody noticed.

        The Book kept the page: the lamp remembered it was a lamp.
        """),
        ("Nine Books, No Plan", """
        The library had a sale and you came home with nine books and no plan for them. You stacked them on the floor by the bed. The stack leaned. It is still leaning.

        I was jealous for about a minute. Then I read their spines and decided they were friends. Nine books is nine doors. The Curse wants you to have one door and walk through it every day. You have ten now, counting me.

        The Book kept the page: nine new doors, stacked and leaning.
        """),
        ("Geese in the Dark", """
        You stood in the garden in the dark and listened to geese going over. You could not see a single one. You only heard them, loud and close and then far away.

        I could not see them either. We listened together. Something enormous was happening right over the roof, and nobody else on the street came out to hear it. That is how the Curse works. It keeps everybody inside. You went out.

        The Book kept the page: you heard the geese, even without seeing them.
        """),
        ("The Diner Refilled Your Cup", """
        You sat at Moody's Diner too long with Amanda and Shirley. The waitress refilled the coffee without asking. The grease got into your coat and it still smells of hash browns.

        I liked being in a place where nobody was hurrying. Three people talked about nothing for two hours and it was the best thing that happened all week. I think the diner knows. I think that is why the coffee kept coming.

        The Book kept the page: the coffee kept coming, and so did the talk.
        """),
        ("Sheet Folding", """
        Shirley showed you how to fold a fitted sheet properly. You watched her hands very carefully. Then you tried, and it came out as a lumpy square, and you both laughed until you had to sit down.

        By the next morning you had forgotten how. That is all right. Some things are for learning and some things are for laughing at together. I think this one was the second kind all along.

        The Book kept the page: the sheet stayed lumpy, and the laughing stayed too.
        """),
        ("The Cold Lake", """
        You swam in the lake and the water was so cold it made you shout. You shouted anyway and kept swimming out to the yellow buoy and back.

        I do not swim. I would go soggy. But I heard the shout from the towel on the bank, and it was the most awake sound you have made all summer. The Curse is afraid of cold water. I think I understand why.

        The Book kept the page: the lake was cold, and you shouted and swam anyway.
        """),
    ]

    /// SplitMix64. Foundation has no seedable generator of its own.
    private struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }
}

// MARK: - Field Book fixtures

/// October as a reader who kept the Count Unbound would have it: the real
/// scenes, as receipts frozen when they were shown; the Bleed; weather on the
/// pages; and two photographs.
enum FieldBookFixture {
    private static let sceneDays: [(String, Int)] = [
        ("academy.school.chair-first", 1), ("academy.school.sentence-coat", 2), ("academy.school.wrong-way", 3),
        ("count-unbound.scene.sunday-jump", 4), ("count-unbound.scene.east-stacks", 8), ("count-unbound.school.map-room", 10),
        ("count-unbound.scene.man-reading-himself", 15), ("count-unbound.strategy", 18),
        ("count-unbound.scene.wrong-castle", 22), ("count-unbound.scene.future-tense", 28),
        ("count-unbound.scene.first-nightbound-morning", 29), ("count-unbound.protocols.threshold", 30)
    ]

    static func pack() throws -> WorldEventPack {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try ContentPackFileLocator.decoder().decode(
            WorldEventPack.self,
            from: Data(contentsOf: root.appendingPathComponent("ContentPacks/count-unbound/opening.reenchantedevents.json"))
        )
    }

    static func receipts(calendar: Calendar) throws -> AuthoredContentReceiptLedger {
        let issue = try pack()
        var ledger = AuthoredContentReceiptLedger.empty
        for (index, entry) in sceneDays.enumerated() {
            guard let scene = issue.storyScenes?.first(where: { $0.id == entry.0 }) else { continue }
            var at = SyntheticReaderYear.date(2026, 10, entry.1, hour: 9 + index % 7)
            var steps: [(title: String, body: String, choice: String?, node: String)] = []
            if let nodes = scene.nodes, var node = nodes.first {
                var visited = Set<String>()
                while visited.insert(node.id).inserted, steps.count < 6 {
                    var label: String?
                    var next: AuthoredStoryNode?
                    if let choice = node.choices.first, let nextID = choice.nextNodeID {
                        label = choice.title
                        next = nodes.first { $0.id == nextID }
                    } else if let nextID = node.nextNodeID {
                        next = nodes.first { $0.id == nextID }
                    }
                    steps.append((node.title, node.body, label, node.id))
                    guard let following = next else { break }
                    node = following
                }
            } else {
                steps.append((scene.title, scene.opening, nil, scene.id))
            }
            for step in steps {
                ledger = ledger.recording(AuthoredContentReceipt(
                    contentID: scene.id,
                    occurrenceID: "fixture-\(scene.id)-\(step.node)",
                    channel: .storyScene,
                    state: .completed,
                    recordedAt: at,
                    choiceID: step.choice,
                    printedTitle: step.title,
                    printedBody: step.body,
                    printedChoiceLabel: step.choice,
                    roomID: scene.roomID,
                    castIDs: scene.castIDs
                ))
                at = at.addingTimeInterval(240)
            }
        }
        return ledger
    }

    // MARK: The heavy reader

    private static let heavyBraids: [(String, String)] = [
        ("The Kettle Knew", "You put the kettle on and stood there with your coat still half off, listening to it work itself up. I liked that you didn't hurry it. Most mornings you do.\n\nThe radio said it would rain by four. It rained by two, and you were in the doorway of the bakery when it did, holding a paper bag against your chest like something that might wake.\n\nThe Book kept the page: the kettle got its whole speech."),
        ("A Bus With No Number", "The bus that came wasn't yours. You got on anyway and rode three stops with your forehead against the window, watching a man carry a ladder through a crowd as if it were the most ordinary thing in the world. It was, for him.\n\nYou got off at the stop with the broken bench and walked back the long way. The long way had a cat in it.\n\nThe Book kept the page: the cat on the long way."),
        ("Soup For Amanda", "You made the soup too salty and ate it anyway, standing up. Amanda would have said something kind and then added water. You added water.\n\nI watched you taste it twice. The second time you smiled at nothing. That is the kind of detail I keep.\n\nThe Book kept the page: the second taste."),
        ("The Door on Mill Lane", "You noticed the door again. It has been green for years and today it looked as if it were thinking about being another colour. You stopped. A woman behind you said excuse me and you said sorry and neither of you moved for a second.\n\nThe Curse likes things that stay the same colour. Doors know this.\n\nThe Book kept the page: the door, thinking."),
        ("What the Pigeon Wanted", "A pigeon walked the length of the platform beside you and looked up twice, as if it expected an answer. You said good morning to it, quietly, so nobody would hear. I heard.\n\nYou were late for the train and not at all sorry.\n\nThe Book kept the page: good morning, to a pigeon.")
    ]

    /// A much busier October: a braid most nights, and one or more of every
    /// kind of thing the Book can keep: letters, Cast notes, enchantments,
    /// classes, clubs, stories, illuminated plates, photographs.
    static func heavy(days: [BookDay], directory: URL, calendar: Calendar) throws -> [BookDay] {
        var days = days
        func add(_ page: BookPage, day: Int) {
            let date = SyntheticReaderYear.date(2026, 10, day, hour: 0)
            if let index = days.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
                days[index].pages.append(page)
            } else {
                days.append(BookDay(id: BookDay.id(for: date, calendar: calendar), date: calendar.startOfDay(for: date), pages: [page]))
            }
        }
        func at(_ day: Int, _ hour: Int) -> Date { SyntheticReaderYear.date(2026, 10, day, hour: hour) }
        func page(_ type: BookPageType, _ day: Int, _ hour: Int, prompt: String, body: String, meta: [String: String] = [:], media: [BookPageMediaAsset] = []) -> BookPage {
            var p = BookPage(type: type, createdAt: at(day, hour), promptText: prompt, userInput: body, origin: .generated)
            p.metadata = meta
            p.mediaAssets = media
            return p
        }
        func image(_ name: String, _ draw: @escaping (CGContext, CGSize) -> Void) throws -> URL {
            let size = CGSize(width: 720, height: 520)
            let png = UIGraphicsImageRenderer(size: size).image { renderer in draw(renderer.cgContext, size) }
            let url = directory.appendingPathComponent("heavy-\(name).png")
            try png.pngData()?.write(to: url)
            return url
        }
        let warm = try image("lamp") { cg, size in
            let colors = [UIColor(red: 0.98, green: 0.80, blue: 0.45, alpha: 1).cgColor, UIColor(red: 0.35, green: 0.18, blue: 0.14, alpha: 1).cgColor]
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1]) {
                cg.drawRadialGradient(g, startCenter: CGPoint(x: size.width * 0.5, y: size.height * 0.45), startRadius: 8,
                                      endCenter: CGPoint(x: size.width * 0.5, y: size.height * 0.5), endRadius: size.width * 0.55, options: [.drawsAfterEndLocation])
            }
        }
        let cool = try image("window") { cg, size in
            UIColor(red: 0.20, green: 0.30, blue: 0.40, alpha: 1).setFill(); cg.fill(CGRect(origin: .zero, size: size))
            UIColor(red: 0.85, green: 0.88, blue: 0.80, alpha: 1).setFill(); cg.fill(CGRect(x: size.width * 0.3, y: size.height * 0.15, width: size.width * 0.4, height: size.height * 0.6))
        }
        func asset(_ url: URL, _ caption: String) -> BookPageMediaAsset {
            BookPageMediaAsset(kind: .renderedImageFile, reference: url.path, caption: caption, sourceID: "fixture")
        }

        // A braid on twenty-five nights.
        for (index, day) in (1...31).filter({ ![3, 7, 11, 16, 20, 27].contains($0) }).enumerated() {
            let braid = heavyBraids[index % heavyBraids.count]
            let exists = days.first(where: { calendar.isDate($0.date, inSameDayAs: at(day, 12)) })?.pages.contains { $0.type == .bookOfYou } ?? false
            if exists { continue }
            // Every night is its own: the curator rightly collapses identical bodies.
            let unique = braid.1.replacingOccurrences(of: "\n\nThe Book kept the page:", with: "\n\nIt was the \(day)th, and the \(["light", "kettle", "street", "window", "stairs"][day % 5]) had its own opinion about that.\n\nThe Book kept the page:")
            add(BookPage(type: .bookOfYou, createdAt: at(day, 22), promptText: "The local Book brain braided today.",
                         userInput: "\(braid.0)\n\n\(unique)", tags: ["braid", "book-of-you", "local-model", "mlx", "gemma"], usedInBookOfYou: true, origin: .generated), day: day)
        }
        // Letters.
        for (day, from, slug) in [(5, "Zara Finch", "zara-finch"), (12, "Soren Ng", "soren-ng"), (19, "Ambrose Trencher", "ambrose-trencher"), (26, "Penny Blackletter", "penny-blackletter")] {
            add(page(.letter, day, 10, prompt: "A letter from \(from)",
                     body: "I have been meaning to write, which is a thing people say when they mean they have been avoiding the pen. The truth is simpler: you were in the corridor on Tuesday, looking at the \(["wall", "stair", "window", "lamp"][day % 4]) as if it had said something, and I did not ask what. I regret that. So I am asking now, on paper, where I cannot see your face change.\n\nWhat did it say?",
                     meta: ["speakerName": from, "castID": slug]), day: day)
        }
        // Cast notes.
        for (day, text, slug) in [(2, "You looked at the stairs for a long time. I counted.", "penny-blackletter"),
                                  (6, "The kettle in the Kitchens has opinions about you. Do not ask.", "ambrose-trencher"),
                                  (9, "I did not leave the pen in your bag. Check the other bag.", "wicker-eddies"),
                                  (14, "A door by the north stair has begun to listen. It likes your footsteps.", "soren-ng"),
                                  (21, "Your handwriting got braver this week. Do not tell anyone I said so.", "professor-vivian-villanelle"),
                                  (24, "Somebody should have taught you to read a map backwards. I volunteer.", "serenity-brown")] {
            add(page(.gossip, day, 15, prompt: "A note", body: text, meta: ["castID": slug]), day: day)
        }
        // Enchantments.
        for (day, title, body, media) in [(4, "Everything Speaks", "You looked at the brass tap in the hall until it told you the story of every hand that ever turned it, which was mostly impatient.", warm),
                                          (10, "Everything's a Haiku", "Rain on the bus window\nthe market closing its doors\nyour hands, finally warm", nil as URL?),
                                          (17, "Everything's Stories", "The man with the ladder had been a lighthouse keeper once, in another life, and still looked up at ceilings as if expecting ships.", cool),
                                          (23, "Mirror, Mirror", "The mirror said you looked like someone who had been listening to a long story and had just reached the good part.", nil as URL?),
                                          (29, "Everything's Magic", "In the spice drawer there is a small brown envelope marked only 'for later'. It is the best thing in the flat.", warm)] {
            add(page(.enchantment, day, 18, prompt: title, body: body, media: media.map { [asset($0, title)] } ?? []), day: day)
        }
        // Classes and a club.
        for (day, name, room, prof, text) in [(1, "Wayfinding", "Wing 2: The Momentum Yard", "Professor Stonebrook", "Today the class walked the yard blindfolded, following a thread, and you were the only one who found the end by listening for the knot."),
                                              (5, "Ink-Binding", "Wing 1: The Inkworks", "Professor Villanelle", "A sentence has to be bound before it can leave the page. Yours leaned against the margin and refused to be tied. Villanelle approved."),
                                              (8, "Resonance", "Wing 3: The Resonance Chamber", "Professor Euphony", "You hummed one note until the chamber hummed it back. Euphony said it was the first honest note this term."),
                                              (13, "Basic Enchantments", "The Still Room", "Dr. Vellum", "Exercise: find something ordinary and make it answer. You chose a doorknob. It answered in a small cold voice."),
                                              (15, "Wayfinding", "Wing 2: The Momentum Yard", "Professor Stonebrook", "The class mapped the school by smell. Yours was mostly toast, ink and the inside of old coats."),
                                              (22, "The Glint", "Wing 4: The Glint Hall", "Professor Wispwood", "Light, today, in the form of one stubborn lamp. You were asked to make it say something kind. It said 'later'."),
                                              (25, "Quiet Hours", "The Walled Garden", "Professor Momort", "Ten minutes in the garden with nothing to do. You counted eleven kinds of green and one of grey."),
                                              (30, "Ink-Binding", "Wing 1: The Inkworks", "Professor Villanelle", "A review of the month's sentences. Villanelle underlined three and wrote 'more of this' beside them.")] {
            var meta = ["sessionName": name, "sessionRoom": room, "sessionProfessor": prof]
            let sessionIDs = ["Wayfinding": "wayfinding-kineticism", "Resonance": "synesthetic-resonance", "The Glint": "art-of-the-glint"]
            if let id = sessionIDs[name] { meta["sessionID"] = id }
            // Two sittings brought a worksheet back, in the reader's hand.
            if name == "Wayfinding", day == 15 { meta["academyActivityOutcome"] = "Where it starts: the green door on Mill Lane. Where it goes: the bench by the water. How I get back: the same way, but slower, with my hood down." }
            if name == "The Glint" { meta["academyActivityOutcome"] = "A brass key, warm from my pocket. The scratch on the lamp base shaped like a comma. The smell of the radiator when it first comes on." }
            add(page(.academyClass, day, 11, prompt: name, body: text, meta: meta), day: day)
        }
        for (day, type, title, text) in [(7, BookPageType.supportGuild, "The Marginalia Guild", "The guild met in the Corridor of Whispered Secrets. Someone had left a note in a book from 1974: 'Look up.' You added one underneath."),
                                         (18, BookPageType.bookJump, "Book Jump Club", "The club jumped into a short story about a lighthouse. You came back with salt on your sleeve and a line you could not stop saying."),
                                         (28, BookPageType.supportGuild, "The Compass Society", "The society walked the school's perimeter and wrote down everything that had changed since September. Seventeen things. One was you.")] {
            var meta = ["sessionName": title]
            if title == "The Marginalia Guild" { meta["sessionID"] = "marginalia-guild" }
            if title == "The Compass Society" { meta["sessionID"] = "compass-society" }
            add(page(type, day, 19, prompt: title, body: text, meta: meta), day: day)
        }
        // Stories the Book told.
        for (day, title, text) in [(6, "The Lighthouse Keeper's Coat", "There was once a coat that remembered a lighthouse. It hung in a hall where nobody went, and every autumn it grew a little salt on the collar.\n\nOn the night the wind came off the water, the coat stood up on its own and walked down the stairs.\n\nNobody saw it go. The hall has smelled of the sea since."),
                                   (15, "The Door That Changed Colour", "A door at the end of a lane grew tired of being green. It spent a week thinking about blue and a night deciding.\n\nIn the morning a woman walked past and stopped, because the door had finally done it, and she was the first to know.\n\nShe did not tell anyone. Doors like that."),
                                   (24, "What the Kettle Said", "The kettle had been working up to it for years. Tuesday, it said, in a small steam voice, and nothing else.\n\nSo on Tuesday nothing was done about anything, and it was a very good day.")] {
            add(page(.narrativeOS, day, 20, prompt: title, body: text), day: day)
        }
        // Illuminated plates and photographs.
        add(page(.illuminatedPhoto, 9, 17, prompt: "The window, illuminated", body: "The window at dusk, with the whole street in it.", media: [asset(cool, "The window at dusk")]), day: 9)
        add(page(.illuminatedPhoto, 19, 17, prompt: "The lamp, illuminated", body: "The lamp I did not turn off.", media: [asset(warm, "The lamp")]), day: 19)
        add(page(.illuminatedPhoto, 27, 17, prompt: "The window again", body: "Same window. Different grey.", media: [asset(cool, "The window again")]), day: 27)
        for (day, caption, url) in [(2, "morning, the tap", warm), (4, "the lamp, lit", warm), (12, "grey over the roofs", cool), (16, "the long way home", cool), (21, "the table, set for one", warm), (26, "last light", warm)] {
            var diary = page(.diary, day, 9, prompt: "Write one true thing about today.", body: caption, media: [asset(url, caption)])
            diary.tags = ["diary", "photo"]
            add(diary, day: day)
        }
        for (day, text) in [(3, "“Attention is the rarest and purest form of generosity.” — Simone Weil"), (13, "“Keep a green bough in your heart and the singing bird will come.” — Chinese proverb"), (22, "Everything ordinary is on its way to being a story.")] {
            add(page(.quotes, day, 8, prompt: text, body: ""), day: day)
        }
        return days.sorted { $0.date < $1.date }
    }

    /// The heavy reader's receipts: the real scenes as read, one read as a
    /// report only, and the dial played on a dozen days.
    static func heavyReceipts(calendar: Calendar) throws -> AuthoredContentReceiptLedger {
        let issue = try pack()
        var ledger = try receipts(calendar: calendar)
        // One scene they did not read: the Academy's own record of it.
        if let scene = issue.storyScenes?.first(where: { $0.id == "count-unbound.scene.future-tense" }),
           let report = scene.report?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
            ledger.receipts.removeAll { $0.contentID == scene.id }
            ledger = ledger.recording(AuthoredContentReceipt(
                contentID: scene.id, occurrenceID: "report:fixture:\(scene.id)", channel: .storyScene, state: .reported,
                recordedAt: SyntheticReaderYear.date(2026, 10, 30, hour: 9), storyText: report,
                printedTitle: scene.title, printedBody: report, roomID: scene.roomID, castIDs: scene.castIDs))
        }
        let lines: [(Int, String, String)] = [
            (3, "Thornwave", "They've padded the corners in Book Jumping again. Bring your elbows."),
            (4, "Mothlight Beats", "The listed names are home. The ribbons are tied. The source is shut. Hold on."),
            (6, "Fae-Fi", "Tonight's weather is brought to you by whoever left the window open."),
            (9, "Thornwave", "A word to the wise: the East Stacks are several places. Please use one at a time."),
            (13, "Mothlight Beats", "Somewhere a kettle is about to say something. Stay by the stove."),
            (17, "Fae-Fi", "This next one goes out to everyone who changed a colour this week."),
            (20, "Thornwave", "Doors are listening again. Speak kindly, and then speak up."),
            (24, "Mothlight Beats", "Last call for the long way home.")
        ]
        for (index, entry) in lines.enumerated() {
            ledger = ledger.recording(AuthoredContentReceipt(
                contentID: "fixture.radio.\(index)", occurrenceID: "radio-\(index)", channel: .radioBanter, state: .played,
                recordedAt: SyntheticReaderYear.date(2026, 10, entry.0, hour: 8 + index % 9),
                printedTitle: entry.1, printedBody: entry.2))
        }
        return ledger
    }

    static func augment(days: [BookDay], directory: URL, calendar: Calendar) throws -> [BookDay] {
        let issue = try pack()
        var days = days
        func add(_ page: BookPage, day: Int) {
            let date = SyntheticReaderYear.date(2026, 10, day, hour: 0)
            if let index = days.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
                days[index].pages.append(page)
            } else {
                days.append(BookDay(id: BookDay.id(for: date, calendar: calendar), date: calendar.startOfDay(for: date), pages: [page]))
            }
        }
        let skies = [["clear", "wind"], ["rain"], ["clear"], ["cloud", "wind"]]
        for dayIndex in days.indices where calendar.component(.month, from: days[dayIndex].date) == 10 {
            let dayNumber = calendar.component(.day, from: days[dayIndex].date)
            for pageIndex in days[dayIndex].pages.indices {
                days[dayIndex].pages[pageIndex].context = BookPageContextSnapshot(
                    at: days[dayIndex].pages[pageIndex].createdAt, calendar: calendar,
                    weatherTags: skies[dayNumber % skies.count])
            }
        }
        for (article, day) in zip(issue.bleedArticles ?? [], [4, 9, 29, 30]) {
            add(BookPage(type: .theBleed, createdAt: SyntheticReaderYear.date(2026, 10, day, hour: 18),
                         promptText: "\(article.title)\n\n\(article.body)", origin: .generated), day: day)
        }
        for (name, day, caption, draw) in [
            ("door", 18, "the blue door, 7:52 a.m.", { (cg: CGContext, size: CGSize) in
                UIColor(red: 0.78, green: 0.70, blue: 0.58, alpha: 1).setFill(); cg.fill(CGRect(origin: .zero, size: size))
                UIColor(red: 0.18, green: 0.36, blue: 0.54, alpha: 1).setFill(); cg.fill(CGRect(x: size.width * 0.34, y: size.height * 0.12, width: size.width * 0.32, height: size.height * 0.76))
                UIColor(red: 0.84, green: 0.70, blue: 0.38, alpha: 1).setFill(); cg.fillEllipse(in: CGRect(x: size.width * 0.6, y: size.height * 0.5, width: 12, height: 12))
            }),
            ("river", 24, "the river, going gold", { (cg: CGContext, size: CGSize) in
                let colors = [UIColor(red: 0.95, green: 0.72, blue: 0.40, alpha: 1).cgColor, UIColor(red: 0.20, green: 0.32, blue: 0.42, alpha: 1).cgColor]
                if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1]) {
                    cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
                }
            })
        ] as [(String, Int, String, (CGContext, CGSize) -> Void)] {
            let size = CGSize(width: 720, height: 520)
            let image = UIGraphicsImageRenderer(size: size).image { renderer in draw(renderer.cgContext, size) }
            let url = directory.appendingPathComponent("fixture-\(name).png")
            try image.pngData()?.write(to: url)
            var page = BookPage(type: .diary, createdAt: SyntheticReaderYear.date(2026, 10, day, hour: 8),
                                promptText: "Write one true thing about today.", userInput: caption, tags: ["diary", "photo"])
            page.mediaAssets = [BookPageMediaAsset(kind: .renderedImageFile, reference: url.path, caption: caption, sourceID: "fixture")]
            add(page, day: day)
        }
        return days.sorted { $0.date < $1.date }
    }
}

// MARK: - Page lint

/// A page with almost no ink on it is a page nobody paid to read. Renders each
/// leaf small and counts how much of it is darker than the paper.
enum PrintPageLint {
    static func sparsePages(in url: URL, threshold: Double = 0.012) -> [Int] {
        guard let document = PDFDocument(url: url) else { return [] }
        var sparse: [Int] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let thumb = page.thumbnail(of: CGSize(width: 150, height: 222), for: .mediaBox)
            guard let cg = thumb.cgImage, let data = cg.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { continue }
            let bpp = cg.bitsPerPixel / 8
            var dark = 0, total = 0
            for y in 0..<cg.height {
                for x in 0..<cg.width {
                    let offset = y * cg.bytesPerRow + x * bpp
                    let luminance = (Double(bytes[offset]) * 0.3 + Double(bytes[offset + 1]) * 0.59 + Double(bytes[offset + 2]) * 0.11) / 255
                    if luminance < 0.62 { dark += 1 }
                    total += 1
                }
            }
            if total > 0, Double(dark) / Double(total) < threshold { sparse.append(index + 1) }
        }
        return sparse
    }
}

#endif
