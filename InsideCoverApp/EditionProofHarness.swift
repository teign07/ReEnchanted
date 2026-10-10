import Foundation
import UIKit
import PDFKit

#if DEBUG
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
        if ProcessInfo.processInfo.arguments.contains("--public-sample-editions") {
            PublicSampleEditionProof.run()
            return
        }
        if ProcessInfo.processInfo.arguments.contains(WeeklyIssueSixProof.flag) {
            WeeklyIssueSixProof.run()
            return
        }
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
        // `--proof-only=monthly` runs just the steps whose name starts with that.
        let only = ProcessInfo.processInfo.arguments.compactMap { $0.hasPrefix("--proof-only=") ? String($0.dropFirst(13)) : nil }.first
        func step(_ name: String, _ work: () throws -> String) {
            if let only, !name.hasPrefix(only) { return }
            status.append("RUNNING \(name)")
            try? status.joined(separator: "\n").write(to: directory.appendingPathComponent("status.txt"), atomically: true, encoding: .utf8)
            let started = Date()
            var outcome: String
            do { outcome = try work() } catch { outcome = "FAILED: \(error)" }
            status.removeLast()
            status.append("\(outcome.hasPrefix("FAILED") ? "FAILED" : "OK") \(name) (\(Int(Date().timeIntervalSince(started)))s): \(outcome)")
            try? status.joined(separator: "\n").write(to: directory.appendingPathComponent("status.txt"), atomically: true, encoding: .utf8)
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
        // The month's real plates when they've been sent over (edition-proof-input/plates, named as
        // the pack names them); otherwise placeholders, so the proofs still show where plates land.
        let plates = directory.appendingPathComponent("plates", isDirectory: true)
        try? FileManager.default.createDirectory(at: plates, withIntermediateDirectories: true)
        let realPlates = ((try? FileManager.default.contentsOfDirectory(
            at: markDirectory.appendingPathComponent("plates", isDirectory: true), includingPropertiesForKeys: nil)) ?? [])
            .filter { ["png", "jpg", "jpeg"].contains($0.pathExtension.lowercased()) }
        for url in realPlates {
            try? FileManager.default.copyItem(at: url, to: plates.appendingPathComponent("count-unbound.plate.\(url.lastPathComponent)"))
        }
        if !realPlates.isEmpty { status.append("real plates: \(realPlates.count)") }
        let placeholders: [(String, String, Double)] = realPlates.isEmpty ? [
            ("frontispiece", "Frontispiece: Count Unbound", 0.08), ("scene.count-unbound.scene.east-stacks", "The East Stacks Incident", 0.58),
            ("scene.count-unbound.school.map-room", "The map with room left", 0.33), ("cast.serenity-brown", "Serenity Brown, in October", 0.9),
            ("harvest-lanterns", "Lanterns in the Kitchens", 0.12), ("stair-fog", "Fog on the North Stair", 0.65)
        ] : []
        for (slot, label, hue) in placeholders {
            let size = CGSize(width: 1200, height: slot.hasPrefix("cast.") || slot == "frontispiece" ? 1600 : 900)
            let image = UIGraphicsImageRenderer(size: size).image { renderer in
                let cg = renderer.cgContext
                UIColor(hue: hue, saturation: 0.25, brightness: 0.92, alpha: 1).setFill(); cg.fill(CGRect(origin: .zero, size: size))
                UIColor(hue: hue, saturation: 0.45, brightness: 0.55, alpha: 1).setFill()
                cg.fillEllipse(in: CGRect(x: size.width * 0.2, y: size.height * 0.2, width: size.width * 0.6, height: size.height * 0.5))
                let font = UIFont(name: "BradleyHandITCTT-Bold", size: 60) ?? .systemFont(ofSize: 60)
                ("PLATE · " + label as NSString).draw(in: CGRect(x: 60, y: size.height - 160, width: size.width - 120, height: 140),
                                                      withAttributes: [.font: font, .foregroundColor: UIColor(white: 0.2, alpha: 1)])
            }
            try? image.pngData()?.write(to: plates.appendingPathComponent("count-unbound.plate.\(slot).png"))
        }
        EditionPlates.proofDirectory = plates

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

        // Every week of the year, not two hand-picked ones: each is bound and
        // read back against the rules a printed Tale must keep.
        step("matrix-weekly") {
            // Judged as a customer receives it: ruin pages ship switched off.
            PrintFeatureFlags.ruinPagesEnabled = false
            defer { PrintFeatureFlags.ruinPagesEnabled = true }
            let yearEnd = SyntheticReaderYear.date(2026, 12, 31)
            let all = PublicationPeriodCatalog.readerWeeks(days: weekDays, now: yearEnd, calendar: calendar).filter(\.isBindable)
            var report: [String] = []
            var failures = 0
            var pageTotals: [Int] = []
            let url = directory.appendingPathComponent("matrix-weekly.pdf")
            for candidate in all {
                guard let issue = WeeklyIssue.issue(for: candidate.period, days: weekDays, now: yearEnd, calendar: calendar) else { continue }
                var matter = WeeklyPublicationMatter(issue: issue, card: WeeklyIssueShareCard.make(issue: issue), readerName: reader,
                                                     editorialNote: nil, closingNote: nil)
                guard let book = BoundDayBookBuilder.make(pages: issue.pages, receipts: weekReceipts, castActs: [],
                                                          startDate: issue.startDate, endDate: issue.endDate, calendar: calendar) else { continue }
                matter.dayBook = book
                matter.bindingID = "matrix-week-\(issue.number)"
                let pages = try WeeklyIssuePDFWriter.writePrintInterior(matter, dedication: nil, spec: .saddleStitchedWeekly6x9, to: url)
                pageTotals.append(pages)
                var problems = EditionQualityLint.repeatedSentences(in: url).map { "repeats ×\($0.count): “\($0.sentence.prefix(60))”" }
                if pages % 4 != 0 || pages > 48 { problems.append("\(pages) pages") }
                let chapters = WeeklyTaleBuilder.chapters(of: book, from: issue.startDate, to: issue.endDate.addingTimeInterval(-1), calendar: calendar)
                let headings = chapters.map(\.heading)
                if Set(headings.map { $0.lowercased() }).count != headings.count { problems.append("duplicate chapter titles") }
                for heading in headings where !heading.hasPrefix("In which") || heading.count > 84 {
                    problems.append("title “\(heading)”")
                }
                if headings.filter({ $0 == WeeklyTaleBuilder.fallbackHeading }).count > 1 { problems.append("fallback title twice") }
                let sparse = PrintPageLint.sparsePages(in: url, threshold: 0.005)
                if sparse.count > max(2, pages / 8) { problems.append("\(sparse.count) sparse pages \(sparse)") }
                report.append("No. \(issue.number) \(issue.dateRange): \(pages)pp, \(chapters.count) ch — " + headings.joined(separator: " | ")
                              + (problems.isEmpty ? "" : "\n    !! " + problems.joined(separator: "\n    !! ")))
                if !problems.isEmpty {
                    failures += 1
                    // Keep the first two flagged weeks to look at; the rest are only reported.
                    if failures <= 2 { try? FileManager.default.copyItem(at: url, to: directory.appendingPathComponent("matrix-weekly-flagged-\(failures).pdf")) }
                }
            }
            try report.joined(separator: "\n").write(to: directory.appendingPathComponent("matrix-weekly.txt"), atomically: true, encoding: .utf8)
            let range = pageTotals.isEmpty ? "-" : "\(pageTotals.min()!)–\(pageTotals.max()!)pp"
            return "\(report.count) weeks bound, \(failures) with problems, \(range) (details in matrix-weekly.txt)"
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

        // The heavy October's pages without its fixture braids, for the Mac to
        // braid with the phone's Gemma (BraidBenchTests.testBraidAMonthWhenAsked).
        step("braid-days") {
            var fieldDays = try FieldBookFixture.heavy(days: try FieldBookFixture.augment(days: days, directory: directory, calendar: calendar),
                                                       directory: directory, calendar: calendar)
            fieldDays = fieldDays.filter { calendar.component(.month, from: $0.date) == 10 }
            for index in fieldDays.indices { fieldDays[index].pages.removeAll { $0.type == .bookOfYou } }
            try JSONEncoder().encode(fieldDays).write(to: directory.appendingPathComponent("october-days.json"))
            return "\(fieldDays.count) October days, \(fieldDays.flatMap(\.pages).count) pages"
        }

        // Every month of the year that has pages: bound, then checked.
        step("matrix-monthly") {
            // Judged as a customer receives it: ruin pages ship switched off.
            PrintFeatureFlags.ruinPagesEnabled = false
            defer { PrintFeatureFlags.ruinPagesEnabled = true }
            let fieldDays = try FieldBookFixture.augment(days: days, directory: directory, calendar: calendar)
            let receipts = try FieldBookFixture.receipts(calendar: calendar)
            var report: [String] = []
            var failures = 0
            let url = directory.appendingPathComponent("matrix-monthly.pdf")
            for month in 1...12 {
                let start = SyntheticReaderYear.date(2026, month, 1)
                guard let end = calendar.date(byAdding: DateComponents(month: 1, second: -1), to: start) else { continue }
                guard fieldDays.contains(where: { $0.date >= start && $0.date <= end && !$0.pages.isEmpty }) else { continue }
                var edition = MonthlyEditionBuilder.edition(
                    from: fieldDays, readerName: reader, startDate: start, endDate: end,
                    generatedAt: end.addingTimeInterval(1), calendar: calendar,
                    authoredReceipts: receipts, packTitle: month == 10 ? "Count Unbound" : nil
                )
                edition.bindingID = "matrix-month-\(month)"
                let pages: Int
                do { pages = try MonthlyEditionPDFWriter.writePrintInterior(edition, spec: .perfectBoundSoftcover6x9, to: url) }
                catch { failures += 1; report.append("\(month): FAILED \(error)"); continue }
                var problems = EditionQualityLint.repeatedSentences(in: url).map { "repeats ×\($0.count): “\($0.sentence.prefix(60))”" }
                let text = EditionQualityLint.text(of: url)
                let nights = edition.dayBook?.braidCount ?? 0
                let printedNights = text.components(separatedBy: "N I G H T B R A I D").count - 1
                if printedNights < nights { problems.append("\(printedNights) of \(nights) nights printed") }
                if pages > PrintSpec.pageCap(for: .monthly) { problems.append("\(pages) pages over cap") }
                let sparse = PrintPageLint.sparsePages(in: url, threshold: 0.005)
                if sparse.count > pages / 8 { problems.append("\(sparse.count) sparse pages \(sparse)") }
                let words = edition.dayBook?.days.reduce(0) { $0 + $1.readerWordCount } ?? 0
                report.append("\(month): \(pages)pp, \(nights) nights, \(words) reader words, \(edition.dayBook?.taleChapters.count ?? 0) tale chapters"
                              + (problems.isEmpty ? "" : "\n    !! " + problems.joined(separator: "\n    !! ")))
                if !problems.isEmpty { failures += 1 }
            }
            try report.joined(separator: "\n").write(to: directory.appendingPathComponent("matrix-monthly.txt"), atomically: true, encoding: .utf8)
            return "\(report.count) months bound, \(failures) with problems (details in matrix-monthly.txt)"
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
            // What a reader writes at the press, "Before I bind this".
            var account = BindingAccount()
            let questions = BindingAccount.questions(monthName: "October")
            account.answers[questions[0]] = "The heron. Two kids arguing about whether it was real, and then it moved its head."
            account.answers[questions[3]] = "Green, the Mill Lane green. I didn't go through. I stood outside it a lot."
            account.answers[questions[4]] = "More corners to stand on. Fewer emails."
            if let quiet = edition.dayBook.map({ BindingAccount.quietDays(in: $0) }), let first = quiet.first {
                account.dayLines[first.id] = "I don't remember this day at all, which is its own kind of answer."
            }
            let bound = edition.applying(account)
            let interior = directory.appendingPathComponent("monthly-heavy-interior.pdf")
            let pages = try MonthlyEditionPDFWriter.writePrintInterior(bound, spec: .perfectBoundSoftcover6x9, to: interior)
            let sparse = PrintPageLint.sparsePages(in: interior)
            let book = edition.dayBook
            var mix: [String: Int] = [:]
            for keep in book?.days.flatMap(\.keeps) ?? [] { mix[keep.kind.rawValue, default: 0] += 1 }
            let mixLine = mix.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
            let reports = book?.scenes.filter(\.isReport).count ?? 0
            let radio = book?.days.reduce(0) { $0 + $1.radio.count } ?? 0
            return "heavy: \(edition.pageCount) kept, \(book?.days.count ?? 0) days, \(book?.braidCount ?? 0) nights, scenes \(book?.scenes.count ?? 0) (\(reports) reports), radio \(radio), keeps [\(mixLine)], \(pages) print pages (cap \(PrintSpec.pageCap(for: .monthly))), sparse: \(sparse.isEmpty ? "none" : sparse.map(String.init).joined(separator: ","))"
        }

        // A reader who really writes: the heavy month plus about 180 words most days.
        // Measures whether the cap holds a writer's month without cutting their nights.
        step("monthly-devoted") {
            var fieldDays = try FieldBookFixture.heavy(days: try FieldBookFixture.augment(days: days, directory: directory, calendar: calendar),
                                                       directory: directory, calendar: calendar)
            fieldDays = FieldBookFixture.devoted(days: fieldDays, calendar: calendar)
            let receipts = try FieldBookFixture.heavyReceipts(calendar: calendar)
            let edition = MonthlyEditionBuilder.edition(
                from: fieldDays, readerName: reader,
                startDate: SyntheticReaderYear.date(2026, 10, 1),
                endDate: SyntheticReaderYear.date(2026, 10, 31).addingTimeInterval(86_399),
                generatedAt: SyntheticReaderYear.date(2026, 11, 1), calendar: calendar,
                authoredReceipts: receipts, packTitle: "Count Unbound"
            )
            let words = edition.dayBook?.days.reduce(0) { $0 + $1.readerWordCount } ?? 0
            let interior = directory.appendingPathComponent("monthly-devoted-interior.pdf")
            let pages = try MonthlyEditionPDFWriter.writePrintInterior(edition, spec: .perfectBoundSoftcover6x9, to: interior)
            let text = PDFDocument(url: interior).map { doc in (0..<doc.pageCount).compactMap { doc.page(at: $0)?.string }.joined(separator: "\n") } ?? ""
            let braidsPrinted = text.components(separatedBy: "NIGHT BRAID").count - 1
            return "devoted: \(words) reader words, \(edition.dayBook?.braidCount ?? 0) nights kept, \(braidsPrinted) printed, \(pages) print pages (cap \(PrintSpec.pageCap(for: .monthly)))"
        }

        // The heavy month with real braids: the phone's Gemma and braid code,
        // run on the Mac over these same days (docs/fixtures/real-braids-october-2026.json).
        step("monthly-realbraids") {
            let fieldDays = try RealBraidFixture.swapped(into: try FieldBookFixture.heavy(
                days: try FieldBookFixture.augment(days: days, directory: directory, calendar: calendar),
                directory: directory, calendar: calendar), calendar: calendar)
            let edition = MonthlyEditionBuilder.edition(
                from: fieldDays, readerName: reader,
                startDate: SyntheticReaderYear.date(2026, 10, 1),
                endDate: SyntheticReaderYear.date(2026, 10, 31).addingTimeInterval(86_399),
                generatedAt: SyntheticReaderYear.date(2026, 11, 1), calendar: calendar,
                authoredReceipts: try FieldBookFixture.heavyReceipts(calendar: calendar), packTitle: "Count Unbound"
            )
            let interior = directory.appendingPathComponent("monthly-realbraids-interior.pdf")
            let pages = try MonthlyEditionPDFWriter.writePrintInterior(edition, spec: .perfectBoundSoftcover6x9, to: interior)
            let sparse = PrintPageLint.sparsePages(in: interior)
            let words = edition.dayBook?.days.flatMap(\.braids).map { $0.body.split(whereSeparator: \.isWhitespace).count } ?? []
            return "real braids: \(edition.dayBook?.braidCount ?? 0) nights kept (\(words.min() ?? 0)-\(words.max() ?? 0) words, \(words.reduce(0, +)) total), \(pages) print pages (cap \(PrintSpec.pageCap(for: .monthly))), sparse: \(sparse.isEmpty ? "none" : sparse.map(String.init).joined(separator: ","))"
        }

        // A week of the same real nights, as The Tale of Your Week.
        step("weekly-realbraids") {
            let fieldDays = try RealBraidFixture.swapped(into: try FieldBookFixture.heavy(
                days: try FieldBookFixture.augment(days: days, directory: directory, calendar: calendar),
                directory: directory, calendar: calendar), calendar: calendar)
            let receipts = try FieldBookFixture.heavyReceipts(calendar: calendar)
            let now = SyntheticReaderYear.date(2026, 11, 2)
            let wanted = SyntheticReaderYear.date(2026, 10, RealBraidFixture.weekDay)
            guard let week = PublicationPeriodCatalog.readerWeeks(days: fieldDays, now: now, calendar: calendar)
                    .first(where: { $0.period.startDate <= wanted && wanted <= $0.period.endDate }),
                  var issue = WeeklyIssue.issue(for: week.period, days: fieldDays, now: now, calendar: calendar) else {
                throw ProofError("no reader week holds October \(RealBraidFixture.weekDay)")
            }
            let modelNotes = try WeeklyTaleProofNotes.notes(for: issue, calendar: calendar)
            issue.editorialTitle = modelNotes?.title
            let issueEncoder = JSONEncoder(); issueEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try issueEncoder.encode(issue).write(to: directory.appendingPathComponent("weekly-source.json"))
            let card = WeeklyIssueShareCard.make(issue: issue)
            var matter = WeeklyPublicationMatter(issue: issue, card: card, readerName: reader,
                                                 editorialNote: modelNotes?.opening, closingNote: modelNotes?.closing)
            matter.dayBook = BoundDayBookBuilder.make(pages: issue.pages, receipts: receipts, castActs: [],
                                                      startDate: issue.startDate, endDate: issue.endDate, calendar: calendar)
            matter.handbook = HandbookBuilder.make(
                pages: issue.pages, castPresence: matter.dayBook?.chart.cast ?? [],
                terms: [issue.resolvedEditorialTitle] + issue.highlights, seed: "week-\(issue.number)",
                dayBook: matter.dayBook, dayCount: 7)
            matter.bindingID = "proof-binding-weekly-realbraids"
            let interior = directory.appendingPathComponent("weekly-realbraids-interior.pdf")
            let pages = try WeeklyIssuePDFWriter.writePrintInterior(matter, dedication: nil, spec: .saddleStitchedWeekly6x9, to: interior)
            let headings = matter.dayBook.map { book in
                WeeklyTaleBuilder.chapters(of: book, from: issue.startDate, to: issue.endDate, calendar: calendar).map(\.heading)
            } ?? []
            let sparse = PrintPageLint.sparsePages(in: interior)
            return "week \(issue.dateRange): \(matter.dayBook?.braidCount ?? 0) nights, \(pages) print pages, sparse: \(sparse.isEmpty ? "none" : sparse.map(String.init).joined(separator: ",")); headings: \(headings.joined(separator: " | "))"
        }

        step("weekly-sparse") {
            let start = SyntheticReaderYear.date(2026, 2, 8)
            let end = SyntheticReaderYear.date(2026, 2, 15)
            let entry = BookPage(id: "thin-proof", type: .diary, createdAt: SyntheticReaderYear.date(2026, 2, 10),
                                promptText: "One true thing", userInput: "I miss Dad. I still put two cups on the table.")
            var issue = WeeklyIssue(number: 7, startDate: start, endDate: end, dateRange: "Feb 8–14",
                                    keptCount: 1, highlights: [], setAsideLine: nil, pages: [entry])
            let notes = try WeeklyTaleProofNotes.notes(for: issue, calendar: calendar)
            issue.editorialTitle = notes?.title
            var matter = WeeklyPublicationMatter(issue: issue, card: WeeklyIssueShareCard.make(issue: issue), readerName: reader,
                                                 editorialNote: notes?.opening, closingNote: notes?.closing)
            matter.dayBook = BoundDayBookBuilder.make(pages: issue.pages, receipts: .empty, castActs: [],
                                                      startDate: start, endDate: end, calendar: calendar)
            let url = directory.appendingPathComponent("weekly-sparse-interior.pdf")
            let pages = try WeeklyIssuePDFWriter.writePrintInterior(matter, dedication: nil, spec: .saddleStitchedWeekly6x9, to: url)
            return "one Reader day, \(pages) print pages; no invented ending or missing days"
        }

        step("weekly-long") {
            let start = SyntheticReaderYear.date(2026, 7, 8)
            let end = SyntheticReaderYear.date(2026, 7, 15)
            let words = "I want to remember " + String(repeating: "the small blue stone and ", count: 35) + "the red feather."
            let choice = "Keep the page open while " + String(repeating: "the last words are still arriving and ", count: 18) + "wait until the whole sentence is finished."
            let entry = BookPage(id: "long-proof", type: .diary, createdAt: start, promptText: "One true thing", userInput: words)
            let receipt = AuthoredContentReceipt(contentID: "long-choice-proof", occurrenceID: "long-choice-proof",
                                                 channel: .storyScene, state: .completed, recordedAt: start,
                                                 choiceID: choice, storyText: "The Book held the page open.",
                                                 printedTitle: "The Last Words", printedBody: "The page is still filling. The Book waits.",
                                                 printedChoiceLabel: choice)
            let ledger = AuthoredContentReceiptLedger(receipts: [receipt])
            let issue = WeeklyIssue(number: 27, startDate: start, endDate: end, dateRange: "Jul 8–14", keptCount: 1,
                                    highlights: [], setAsideLine: nil, pages: [entry])
            var matter = WeeklyPublicationMatter(issue: issue, card: WeeklyIssueShareCard.make(issue: issue), readerName: reader,
                                                 editorialNote: nil, closingNote: nil)
            matter.dayBook = BoundDayBookBuilder.make(pages: issue.pages, receipts: ledger, castActs: [],
                                                      startDate: start, endDate: end, calendar: calendar)
            let url = directory.appendingPathComponent("weekly-long-interior.pdf")
            let pages = try WeeklyIssuePDFWriter.writePrintInterior(matter, dedication: nil, spec: .saddleStitchedWeekly6x9, to: url)
            return "long complete Reader sentence and choice, \(pages) print pages"
        }

        // A shorter month with photographs and room to spare: where the keepsakes show whole.
        step("monthly-photos") {
            let fieldDays = try FieldBookFixture.heavy(days: try FieldBookFixture.augment(days: days, directory: directory, calendar: calendar),
                                                       directory: directory, calendar: calendar)
                .filter { calendar.component(.day, from: $0.date) <= 14 && calendar.component(.month, from: $0.date) == 10 }
            let edition = MonthlyEditionBuilder.edition(
                from: fieldDays, readerName: reader,
                startDate: SyntheticReaderYear.date(2026, 10, 1),
                endDate: SyntheticReaderYear.date(2026, 10, 14).addingTimeInterval(86_399),
                generatedAt: SyntheticReaderYear.date(2026, 10, 15), calendar: calendar,
                authoredReceipts: try FieldBookFixture.heavyReceipts(calendar: calendar), packTitle: "Count Unbound"
            )
            let interior = directory.appendingPathComponent("monthly-photos-interior.pdf")
            let pages = try MonthlyEditionPDFWriter.writePrintInterior(edition, spec: .perfectBoundSoftcover6x9, to: interior)
            let k = edition.handbook?.keepsakes
            return "photos month: \(pages) print pages, photos \(k?.photos?.shots.count ?? 0), superlatives \(k?.superlatives?.awards.count ?? 0), poem \(k?.poem != nil), passport \(k?.passport != nil)"
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
        // On the phone the Mac's source tree is not there: the pack is sent over to Documents/edition-proof-input.
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("edition-proof-input/opening.reenchantedevents.json")
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let url = FileManager.default.fileExists(atPath: documents.path)
            ? documents
            : root.appendingPathComponent("ContentPacks/count-unbound/opening.reenchantedevents.json")
        return try ContentPackFileLocator.decoder().decode(WorldEventPack.self, from: Data(contentsOf: url))
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
        // Two more distinct photographs: a month of the same two pictures is not a month of photographs.
        let dusk = try image("dusk") { cg, size in
            let colors = [UIColor(red: 0.30, green: 0.22, blue: 0.45, alpha: 1).cgColor, UIColor(red: 0.95, green: 0.55, blue: 0.35, alpha: 1).cgColor]
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1]) {
                cg.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            }
        }
        let garden = try image("garden") { cg, size in
            UIColor(red: 0.28, green: 0.45, blue: 0.30, alpha: 1).setFill(); cg.fill(CGRect(origin: .zero, size: size))
            UIColor(red: 0.80, green: 0.35, blue: 0.30, alpha: 1).setFill(); cg.fillEllipse(in: CGRect(x: size.width * 0.35, y: size.height * 0.3, width: size.width * 0.3, height: size.height * 0.4))
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
            var letter = page(.letter, day, 10, prompt: "A letter from \(from)",
                     body: "I have been meaning to write, which is a thing people say when they mean they have been avoiding the pen. The truth is simpler: you were in the corridor on Tuesday, looking at the \(["wall", "stair", "window", "lamp"][day % 4]) as if it had said something, and I did not ask what. I regret that. So I am asking now, on paper, where I cannot see your face change.\n\nWhat did it say?",
                     meta: ["speakerName": from, "castID": slug])
            // An engaged reader answers some of their letters.
            letter.playerReply = heavyLetterReplies[day] ?? ""
            add(letter, day: day)
        }
        // Cast notes.
        for (day, text, slug) in [(2, "You looked at the stairs for a long time. I counted.", "penny-blackletter"),
                                  (6, "The kettle in the Kitchens has opinions about you. Do not ask.", "ambrose-trencher"),
                                  (9, "I did not leave the pen in your bag. Check the other bag.", "wicker-eddies"),
                                  (14, "A door by the north stair has begun to listen. It likes your footsteps.", "soren-ng"),
                                  (21, "Your handwriting got braver this week. Do not tell anyone I said so.", "professor-vivian-villanelle"),
                                  (24, "Somebody should have taught you to read a map backwards. I volunteer.", "serenity-brown")] {
            var note = page(.gossip, day, 15, prompt: "A note", body: text, meta: ["castID": slug])
            if day == 9 { note.playerReply = "I checked the other bag. It was in the other bag. I am not saying thank you." }
            add(note, day: day)
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
            let sessionIDs = ["Wayfinding": "wayfinding-kineticism", "Resonance": "synesthetic-resonance", "The Glint": "art-of-the-glint",
                              "Ink-Binding": "ink-binding", "Basic Enchantments": "basic-enchantments", "Quiet Hours": "quiet-hours"]
            if let id = sessionIDs[name] { meta["sessionID"] = id }
            // Two sittings brought a worksheet back, in the reader's hand.
            if name == "Quiet Hours" {
                meta["academyActivityOutcome"] = "What you usually do to rest: the phone, on the sofa. Fuller or emptier: emptier, if I'm honest."
            }
            if name == "Ink-Binding", day == 30 {
                meta["academyActivityOutcome"] = "The moment: the last bus, empty, and the driver humming. The real thing in it: his flask on the dashboard, steaming."
            }
            if name == "Wayfinding", day == 15 {
                // October's Wayfinding is Lesson II, Write the Ticket.
                meta["lessonModuleID"] = "wayfinding-ticket-002"
                meta["academyActivityOutcome"] = "Where: the bench by the water, past the green door on Mill Lane. When: Saturday, nine o'clock, before anyone else is up. How: on foot, the long way, with the flask and my hood down."
            }
            if name == "The Glint" {
                // October's Glint is Lesson II, the Gorilla Count; the page remembers which lesson it was.
                meta["lessonModuleID"] = "glint-gorilla-002"
                meta["academyActivityOutcome"] = "What I hunted for: red umbrellas. How many I found: eleven, two of them inside out. What I nearly walked past: a heron on the canal wall, standing so still I took it for a post."
            }
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
        for (day, caption, url) in [(2, "morning, the tap", warm), (4, "the lamp, lit", dusk), (12, "grey over the roofs", cool), (16, "the long way home", garden), (21, "the table, set for one", dusk), (26, "last light", garden)] {
            var diary = page(.diary, day, 9, prompt: "Write one true thing about today.", body: caption, media: [asset(url, caption)])
            diary.tags = ["diary", "photo"]
            add(diary, day: day)
        }
        for (day, text) in [(3, "“Attention is the rarest and purest form of generosity.” — Simone Weil"), (13, "“Keep a green bough in your heart and the singing bird will come.” — Chinese proverb"), (22, "Everything ordinary is on its way to being a story.")] {
            add(page(.quotes, day, 8, prompt: text, body: ""), day: day)
        }
        // What an engaged reader actually writes: some lines, some real entries.
        for (day, hour, type, prompt, text) in heavyEntries {
            var entry = BookPage(type: type, createdAt: at(day, hour), promptText: prompt, userInput: text, origin: .userAuthored)
            entry.tags = [type.rawValue]
            add(entry, day: day)
        }
        return days.sorted { $0.date < $1.date }
    }

    /// The heavy month, written in most days at length: what a reader who
    /// journals in the Book every evening gives it. Sentences are dealt from a
    /// pool by day, so no two entries match.
    static func devoted(days: [BookDay], calendar: Calendar) -> [BookDay] {
        var days = days
        let pool = [
            "I got up before the alarm and lay there listening to the radiator tick.", "The bus was late again and nobody minded much.",
            "There was a woman on the platform reading a paperback with the cover torn off.", "I bought clementines because they were the only bright thing in the shop.",
            "Work was the usual: three meetings that should have been one.", "At lunch I walked to the river and back without my phone.",
            "The light came in sideways at four and turned the desk gold for about a minute.", "I tried to notice one thing on the way home that I had never seen before.",
            "Today it was a tiny painted door at the bottom of a garden wall, the size of a book.", "I made the soup again and got it right this time.",
            "My brother sent a photo of his dog asleep in a laundry basket.", "I read for an hour and didn't once check the time.",
            "The neighbours were playing piano badly and I loved it.", "I keep thinking about what the Book said about doors.",
            "There is a crack in the bathroom ceiling that looks like a coastline.", "I named the coastline. It is called the Mild Shore.",
            "The wind got into the stairwell and the whole building sighed.", "I wrote a letter I'm not going to send.",
            "Someone had chalked a hopscotch on the pavement and I did it, quickly, when nobody was looking.", "The kettle has started to whistle in a lower note. I think it's tired.",
            "I fell asleep on the sofa and woke up with the lamp still on and a strange feeling of being looked after.", "Rain all day. I didn't mind it.",
            "I found an old train ticket in a coat pocket from a trip I'd forgotten.", "The man at the corner shop has started calling me by name.",
            "I sat on the back step until my hands were cold.", "There were geese going over, very high, arguing.",
            "I counted the lit windows on the street opposite. Eleven.", "I'm sleeping better. I don't know why. I'm not asking.",
            "Tonight the moon looked like it had been folded in half.", "I want to remember how quiet the flat was at ten o'clock, like held breath."
        ]
        for day in 1...31 where ![7, 16, 27].contains(day) {
            let date = SyntheticReaderYear.date(2026, 10, day, hour: 23)
            var lines: [String] = []
            for k in 0..<12 { lines.append(pool[(day * 7 + k * 5) % pool.count]) }
            let text = lines.prefix(6).joined(separator: " ") + "\n\n" + lines.dropFirst(6).joined(separator: " ")
            var page = BookPage(type: .diary, createdAt: date, promptText: "What happened?", userInput: text, origin: .userAuthored)
            page.tags = ["diary", "devoted"]
            if let index = days.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
                days[index].pages.append(page)
            } else {
                days.append(BookDay(id: BookDay.id(for: date, calendar: calendar), date: calendar.startOfDay(for: date), pages: [page]))
            }
        }
        return days.sorted { $0.date < $1.date }
    }

    private static let heavyLetterReplies: [Int: String] = [
        5: "Dear Zara, it said nothing, which was the problem. It was the stair by the coat hooks and it has a tread that creaks only on the way down, never up, and I was standing there trying to work out what that means about stairs. I think it means they mind being left more than being climbed. Ask me again on Tuesday.",
        19: "Ambrose. It said the soup was too salty. It was right. I added water, like you would have, and then I stood in the kitchen for a long time with the spoon, not eating, just being somewhere warm. That is the honest answer."
    ]

    private static let heavyEntries: [(Int, Int, BookPageType, String, String)] = [
        (1, 8, .diary, "What happened?", "First of the month. I decided to actually write in this thing instead of just tapping keep. The kettle took forever and I let it. The light in the hall at eight is the colour of weak tea and I've walked through it every morning for two years without once looking at it."),
        (2, 21, .souvenir, "One thing from today you'd rather not lose.", "The man at the bakery remembered I like the end piece."),
        (4, 13, .diary, "What happened?", "Long walk. I took the path by the water because the main road was loud, and there was a heron standing in the shallows so still that two kids were arguing about whether it was real. It moved its head about an inch and one of them screamed. I laughed out loud on my own like an idiot and didn't care.\n\nHome by four. Rain by four-fifteen. Good timing for once."),
        (6, 22, .mood, "What word fits today?", "Frayed. Too many emails, and all of them wanted something by Friday."),
        (8, 7, .weather, "Look outside. Write what the sky is doing and whether you like it.", "Low grey sky sitting right on the roofs like a lid. I like it more than I should. It makes the street feel like a room."),
        (11, 20, .diary, "What happened?", "Nothing happened today, which I'm writing down because the Book keeps saying nothing is wasted. So: I did the washing. I ate toast standing up. I sat on the back step for ten minutes with my coat on and watched next door's cat try to get into the recycling. It failed. It tried again. Respect.\n\nI keep thinking about the stair that creaks only on the way down. I tested it tonight. It's true. I don't know why that pleases me so much, but it does."),
        (14, 18, .location, "One thing about where you were that only someone standing there would know.", "The library's back door has a brass plate worn silver in exactly the shape of a thumb."),
        (16, 21, .diary, "What happened?", "Hard day. I won't write all of it. I called my brother and we talked about nothing for forty minutes, which was the point. When I hung up the flat was very quiet and I put the radio on just to have someone else in the room. It was a programme about bees. I listened to the whole thing."),
        (20, 9, .souvenir, "One thing from today you'd rather not lose.", "Frost on the car roof in the shape of a map of somewhere that doesn't exist."),
        (23, 22, .diary, "What happened?", "I tried the thing from the Wayfinding class, mapping the street by smell, on the way home. Bakery, then the laundrette (hot cotton), then the bins behind the chip shop, then nothing for a long stretch, then woodsmoke from somebody's chimney two roads over. I'd never have noticed the woodsmoke if I hadn't been playing. I stood at the corner for a while just breathing it in like a weirdo.\n\nI think that's what this whole Book is for, honestly. Making me stand on corners."),
        (27, 19, .quip, "What surprised you?", "That I missed writing in here on the two days I didn't."),
        (30, 22, .diary, "What happened?", "Last real day of October. I read back through the month on the bus and there's more in it than I thought. The heron. The stair. The bees. The woodsmoke. None of it is anything, and all of it is the month. I want to remember that it was a month where I started looking up.")
    ]

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
        for (article, day) in zip(issue.bleedArticles ?? [], [4, 9, 29, 30, 11, 18, 25, 31]) {
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
        // Scrapbook pages the reader made in the Pagewright: a full page of
        // their own layout, kept as a picture, with the tags the Pagewright writes.
        for (name, day, title, note, photos, marks, tint) in [
            ("river", 10, "Sunday at the river", "I want this one on the wall. The light did the thing.", 2, 3, UIColor(red: 0.96, green: 0.92, blue: 0.84, alpha: 1)),
            ("tickets", 12, "Ticket stubs", "", 0, 1, UIColor(red: 0.92, green: 0.95, blue: 0.90, alpha: 1)),
            ("kitchen", 13, "The kitchen at night", "Everyone asleep but the kettle.", 1, 2, UIColor(red: 0.93, green: 0.90, blue: 0.96, alpha: 1)),
            ("leaves", 22, "Leaves I picked up", "Five kinds of yellow on one street.", 1, 4, UIColor(red: 0.97, green: 0.93, blue: 0.80, alpha: 1))
        ] as [(String, Int, String, String, Int, Int, UIColor)] {
            let size = CGSize(width: 900, height: 1350)
            let image = UIGraphicsImageRenderer(size: size).image { renderer in
                let cg = renderer.cgContext
                tint.setFill(); cg.fill(CGRect(origin: .zero, size: size))
                for (index, rect) in [CGRect(x: 90, y: 230, width: 460, height: 340), CGRect(x: 360, y: 640, width: 450, height: 330)].enumerated() where index < max(1, photos) {
                    cg.saveGState()
                    cg.translateBy(x: rect.midX, y: rect.midY); cg.rotate(by: index == 0 ? -0.06 : 0.05); cg.translateBy(x: -rect.midX, y: -rect.midY)
                    UIColor.white.setFill(); cg.fill(rect.insetBy(dx: -16, dy: -16))
                    UIColor(red: 0.25 + 0.2 * CGFloat(index), green: 0.40, blue: 0.55 - 0.1 * CGFloat(index), alpha: 1).setFill(); cg.fill(rect)
                    UIColor(red: 0.9, green: 0.75, blue: 0.45, alpha: 0.7).setFill(); cg.fill(CGRect(x: rect.midX - 60, y: rect.minY - 30, width: 120, height: 34))
                    cg.restoreGState()
                }
                let hand = UIFont(name: "BradleyHandITCTT-Bold", size: 64) ?? .systemFont(ofSize: 64)
                (title as NSString).draw(at: CGPoint(x: 80, y: 80), withAttributes: [.font: hand, .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.35, alpha: 1)])
                if !note.isEmpty {
                    (note as NSString).draw(in: CGRect(x: 90, y: 1060, width: 720, height: 200),
                                            withAttributes: [.font: hand.withSize(40), .foregroundColor: UIColor(red: 0.25, green: 0.22, blue: 0.3, alpha: 1)])
                }
                for star in 0..<marks {
                    let center = CGPoint(x: 700 + CGFloat(star % 2) * 90, y: 140 + CGFloat(star) * 60)
                    UIColor(red: 0.85, green: 0.6, blue: 0.2, alpha: 1).setFill()
                    cg.fillEllipse(in: CGRect(x: center.x - 14, y: center.y - 14, width: 28, height: 28))
                }
            }
            let url = directory.appendingPathComponent("pagewright-\(name).png")
            try image.pngData()?.write(to: url)
            let summary = "Photograph: \(title.lowercased())"
            var page = BookPage(type: .plainPage, createdAt: SyntheticReaderYear.date(2026, 10, day, hour: 20),
                                promptText: title,
                                userInput: note.isEmpty ? summary : "\(note)\n\nScraps bound here:\n\(summary)",
                                tags: ["pagewright", "scrapbook", "kept-page", "scrapPage", "format:scrapPage",
                                       "photo-count:\(photos)", "mark-count:\(marks)", "note-count:\(note.isEmpty ? 0 : 1)", "source-count:2"].sorted(),
                                sourceID: "pagewright", origin: .userAuthored)
            page.mediaAssets = [BookPageMediaAsset(kind: .renderedImageFile, reference: url.path, caption: title, sourceID: "pagewright",
                                                   metadata: ["mediaRole": "scrapbookPreview", "monthlyEditionPresentation": "fullPage", "pagewright": "true", "export": "png"])]
            add(page, day: day)
        }
        return days.sorted { $0.date < $1.date }
    }
}

/// Real nightly braids for the heavy October: the phone's braid code and Gemma,
/// run on the Mac over the harness's own days (`braid-days`, then
/// `BraidMonthLabTests.testBraidAMonthWhenAsked`). They replace the fixture
/// braids so the books are proofed with what a reader's nights look like.
enum RealBraidFixture {
    /// The proofed week is the reader week holding this day of October.
    static var weekDay: Int {
        ProcessInfo.processInfo.arguments.compactMap { $0.hasPrefix("--proof-week-day=") ? Int($0.dropFirst(17)) : nil }.first ?? 14
    }

    struct Night: Decodable { var day: String; var body: String; var tags: [String] }

    static func nights() throws -> [Night] {
        let name = "real-braids-october-2026.json"
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("edition-proof-input/\(name)")
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let url = FileManager.default.fileExists(atPath: documents.path) ? documents : root.appendingPathComponent("docs/fixtures/\(name)")
        return try JSONDecoder().decode([Night].self, from: Data(contentsOf: url))
    }

    /// October with its braids replaced by the real ones, each kept at ten at night.
    static func swapped(into days: [BookDay], calendar: Calendar) throws -> [BookDay] {
        let nights = try nights()
        var days = days
        for index in days.indices where calendar.component(.month, from: days[index].date) == 10 {
            days[index].pages.removeAll { $0.type == .bookOfYou }
            let key = BookDay.id(for: days[index].date, calendar: calendar)
            for night in nights where night.day == key {
                days[index].pages.append(BookPage(
                    id: "real-braid-\(key)", type: .bookOfYou, createdAt: calendar.startOfDay(for: days[index].date).addingTimeInterval(22 * 3600),
                    promptText: "The local Book brain braided today.", userInput: night.body, tags: night.tags,
                    usedInBookOfYou: true, origin: .generated))
            }
        }
        return days
    }
}

/// Optional synthetic QA notes made by WeeklyTaleLabTests using the phone's
/// Gemma writing jobs. No model fixture is read by an ordinary Reader flow.
enum WeeklyTaleProofNotes {
    struct Notes: Decodable {
        var startDate: Date
        var title: String?
        var opening: String
        var closing: String
    }

    static func notes(for issue: WeeklyIssue, calendar: Calendar) throws -> Notes? {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("edition-proof-input/weekly-tale-notes.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode([Notes].self, from: Data(contentsOf: url)).first {
            calendar.isDate($0.startDate, inSameDayAs: issue.startDate)
        }
    }
}

// MARK: - Page lint

/// A page with almost no ink on it is a page nobody paid to read. Renders each
/// leaf small and counts how much of it is darker than the paper.
/// Reads a bound PDF back as a reader would, for what a layout can't see.
enum EditionQualityLint {
    static func text(of url: URL) -> String {
        guard let document = PDFDocument(url: url) else { return "" }
        return (0..<document.pageCount).compactMap { document.page(at: $0)?.string }.joined(separator: "\n")
    }

    /// Whole sentences of eight words or more that a book prints three or more
    /// times. Once in a chapter and once in a quotation is a callback; a third
    /// time is the book running out of things to say.
    static func repeatedSentences(in url: URL, atLeast: Int = 3) -> [(sentence: String, count: Int)] {
        let joined = text(of: url)
            .replacingOccurrences(of: "-\n", with: "")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "[“”\"]", with: "", options: .regularExpression)
        var counts: [String: Int] = [:]
        var original: [String: String] = [:]
        for raw in joined.components(separatedBy: CharacterSet(charactersIn: ".!?")) {
            let sentence = raw.trimmingCharacters(in: .whitespaces)
            let words = sentence.split(separator: " ")
            // Tracked running heads ("T H E D A Y S") are letters, not sentences.
            guard words.count >= 8, words.filter({ $0.count == 1 }).count < words.count / 2 else { continue }
            let key = sentence.lowercased().split(whereSeparator: { !$0.isLetter }).joined(separator: " ")
            counts[key, default: 0] += 1
            original[key] = original[key] ?? sentence
        }
        return counts.filter { $0.value >= atLeast }.map { (original[$0.key] ?? $0.key, $0.value) }.sorted { $0.1 > $1.1 }
    }
}

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

/// The public samples use the same saved input Pages as the landing braid.
/// All input is explicit QA material; this path never opens a Reader's vault.
private enum PublicSampleEditionProof {
    private struct ProofError: Error, CustomStringConvertible {
        var description: String
        init(_ description: String) { self.description = description }
    }
    struct Photo: Decodable { var id: String; var file: String; var day: Int; var caption: String }
    /// One thing the Reader placed on the sheet, drawn in list order.
    /// `ref` is a photo ID, a kept Page ID, a marginalia asset name, or a note's text.
    struct Element: Decodable {
        var kind: String; var ref: String; var style: String?
        var x: CGFloat; var y: CGFloat; var width: CGFloat; var rotation: Double
    }
    struct Sheet: Decodable {
        var id: String; var day: Int; var title: String; var note: String
        var paper: String; var background: String; var marginalia: String; var elements: [Element]
        func refs(_ kind: String) -> [String] { elements.filter { $0.kind == kind }.map(\.ref) }
    }
    struct Input: Decodable {
        var readerName: String; var provenance: String; var photos: [Photo]; var sheets: [Sheet]
    }

    static func run() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let inputDirectory = documents.appendingPathComponent("edition-proof-input", isDirectory: true)
        let output = documents.appendingPathComponent("public-sample-editions", isDirectory: true)
        try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        func status(_ line: String) {
            try? line.write(to: output.appendingPathComponent("status.txt"), atomically: true, encoding: .utf8)
        }
        status("RUNNING public samples")
        do {
            let decoder = JSONDecoder()
            let input = try decoder.decode(Input.self, from: Data(contentsOf: inputDirectory.appendingPathComponent("sample.json")))
            let calendar = SyntheticReaderYear.calendar
            var days = try decoder.decode([BookDay].self, from: Data(contentsOf: inputDirectory.appendingPathComponent("october-days.json")))
            guard days.allSatisfy({ calendar.component(.year, from: $0.date) == 2026 && calendar.component(.month, from: $0.date) == 10 }) else {
                throw ProofError("public input must contain only the simulated October")
            }
            let nights = try decoder.decode([RealBraidFixture.Night].self,
                from: Data(contentsOf: inputDirectory.appendingPathComponent("real-braids-october-2026.json")))
            // Preserve the original text and IDs. Remove fake visual fixtures;
            // their words remain kept text. Real photo keeps are separate below,
            // so an old 'blue door' sentence cannot miscaption a boat photograph.
            for d in days.indices {
                days[d].pages.removeAll { $0.type == .bookOfYou || $0.sourceID == "pagewright" }
                for p in days[d].pages.indices {
                    days[d].pages[p].mediaAssets.removeAll { $0.kind == .renderedImageFile || $0.kind == .photoLibraryAsset }
                    days[d].pages[p].tags.removeAll { $0 == "photo" }
                    if days[d].pages[p].type == .illuminatedPhoto { days[d].pages[p].type = .plainPage }
                }
                for night in nights where night.day == days[d].id {
                    days[d].pages.append(BookPage(id: "real-braid-\(night.day)", type: .bookOfYou,
                        createdAt: days[d].date.addingTimeInterval(22 * 3600), promptText: "The local Book brain braided today.",
                        userInput: night.body, tags: night.tags, usedInBookOfYou: true, origin: .generated))
                }
            }
            func add(_ page: BookPage) {
                if let index = days.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: page.createdAt) }) {
                    days[index].pages.append(page)
                } else {
                    let date = calendar.startOfDay(for: page.createdAt)
                    days.append(BookDay(id: BookDay.id(for: date, calendar: calendar), date: date, pages: [page]))
                }
            }
            var photosByID: [String: PagewrightPersonalPhoto] = [:]
            for photo in input.photos {
                // Paths are generated by prepare-landing-sample-input.py, never
                // taken from a vault or arbitrary absolute file reference.
                guard photo.file.hasPrefix("photos/"), !photo.file.contains("..") else { throw ProofError("invalid photo path") }
                let url = inputDirectory.appendingPathComponent(photo.file)
                let data = try Data(contentsOf: url)
                guard let image = UIImage(data: data), image.size.height > 0 else { throw ProofError("missing photo \(photo.id)") }
                photosByID[photo.id] = PagewrightPersonalPhoto(id: photo.id, data: data, aspectRatio: image.size.width / image.size.height)
                var page = BookPage(id: "public-photo-\(photo.id)", type: .illuminatedPhoto,
                    createdAt: SyntheticReaderYear.date(2026, 10, photo.day, hour: 16),
                    promptText: photo.caption, userInput: photo.caption,
                    tags: ["photo", "public-sample", "illustrative-photo"], sourceID: "public-sample-photo", origin: .userAuthored)
                page.mediaAssets = [BookPageMediaAsset(kind: .renderedImageFile, reference: url.path,
                    caption: photo.caption, sourceID: "public-sample-photo")]
                add(page)
            }
            let allPages = Dictionary(uniqueKeysWithValues: days.flatMap(\.pages).map { ($0.id, $0) })
            let availableMarks = Set(IlluminationPackRegistry.unlockedPacks.flatMap(\.allAssets).map(\.assetName))
            for sheet in input.sheets {
                let photos = try sheet.refs("photo").map { id -> PagewrightPersonalPhoto in
                    guard let photo = photosByID[id] else { throw ProofError("missing sheet photo \(id)") }
                    return photo
                }
                let scraps = try sheet.refs("scrap").map { id -> BookPage in
                    guard let page = allPages[id] else { throw ProofError("missing sheet scrap \(id)") }
                    return page
                }
                if let missing = sheet.refs("mark").first(where: { !availableMarks.contains($0) || UIImage(named: $0) == nil }) {
                    throw ProofError("missing Pagewright mark \(missing) in \(sheet.id)")
                }
                guard let paper = PagewrightPaperTintPreset(rawValue: sheet.paper),
                      let background = PagewrightBackground(rawValue: sheet.background),
                      let marginalia = PagewrightMarginaliaStyle(rawValue: sheet.marginalia) else {
                    throw ProofError("unknown paper, background or marginalia in \(sheet.id)")
                }
                var notes: [PagewrightPinnedNote] = []
                var elements: [PagewrightCanvasElement] = []
                for (z, item) in sheet.elements.enumerated() {
                    let kind: PagewrightCanvasElement.Kind
                    var sourceID = item.ref
                    switch item.kind {
                    case "photo": kind = .personalPhoto
                    case "scrap": kind = .page
                    case "mark": kind = .marginaliaAsset
                    case "note":
                        guard let style = PagewrightPinnedNoteStyle(rawValue: item.style ?? "") else {
                            throw ProofError("unknown note style in \(sheet.id)")
                        }
                        let note = PagewrightPinnedNote(id: "\(sheet.id)-note-\(z)", text: item.ref, style: style)
                        notes.append(note); kind = .note; sourceID = note.id
                    default: throw ProofError("unknown element \(item.kind) in \(sheet.id)")
                    }
                    elements.append(PagewrightCanvasElement(kind: kind, sourceID: sourceID,
                        x: item.x, y: item.y, width: item.width, rotation: item.rotation, z: z))
                }
                let draft = PagewrightDraft(title: sheet.title, note: sheet.note, format: .scrapPage,
                    template: .polaroidScatter, pages: scraps, pullQuotes: [:], pinnedNotes: notes,
                    personalPhotos: photos, elements: elements, background: background,
                    paperTint: paper.tint, marginalia: marginalia, marginaliaPackID: "public-sample")
                let png = output.appendingPathComponent("pagewright-\(sheet.id).png")
                try PagewrightPDFWriter.writePNG(draft: draft, to: png)
                try PagewrightPDFWriter.write(draft: draft, to: output.appendingPathComponent("pagewright-\(sheet.id).pdf"))
                var page = BookPage(id: "public-pagewright-\(sheet.id)", type: .plainPage,
                    createdAt: SyntheticReaderYear.date(2026, 10, sheet.day, hour: 20),
                    promptText: sheet.title, userInput: sheet.note,
                    tags: ["pagewright", "scrapbook", "kept-page", "scrapPage", "format:scrapPage",
                           "photo-count:\(photos.count)", "mark-count:\(sheet.refs("mark").count)",
                           "source-count:\(scraps.count)", "public-sample"], sourceID: "pagewright", origin: .userAuthored)
                page.metadata = ["sourcePageIDs": sheet.refs("scrap").joined(separator: ","), "sampleProvenance": input.provenance]
                page.mediaAssets = [BookPageMediaAsset(kind: .renderedImageFile, reference: png.path,
                    caption: sheet.title, sourceID: "pagewright", metadata: ["mediaRole": "scrapbookPreview",
                    "monthlyEditionPresentation": "fullPage", "pagewright": "true", "export": "png"])]
                add(page)
            }
            days.sort { $0.date < $1.date }
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(days).write(to: output.appendingPathComponent("sample-source.json"))
            try Data(contentsOf: inputDirectory.appendingPathComponent("sample.json")).write(to: output.appendingPathComponent("sample.json"))
            // Do not manufacture commissioned October plates for a public issue.
            // This exporter can use installed pack art; ordinary app marks still
            // run through the shared dealer used by the actual publications.
            EditionPlates.proofDirectory = nil
            let receipts = try FieldBookFixture.heavyReceipts(calendar: calendar)
            let now = SyntheticReaderYear.date(2026, 11, 2)
            let wanted = SyntheticReaderYear.date(2026, 10, 23)
            guard let week = PublicationPeriodCatalog.readerWeeks(days: days, now: now, calendar: calendar)
                .first(where: { $0.period.startDate <= wanted && wanted <= $0.period.endDate }),
                var issue = WeeklyIssue.issue(for: week.period, days: days, now: now, calendar: calendar) else { throw ProofError("no sample week") }
            let notes = try decoder.decode([WeeklyTaleProofNotes.Notes].self,
                from: Data(contentsOf: inputDirectory.appendingPathComponent("weekly-tale-notes.json")))
                .first { calendar.isDate($0.startDate, inSameDayAs: issue.startDate) }
            issue.editorialTitle = notes?.title
            try encoder.encode(issue).write(to: output.appendingPathComponent("weekly-source.json"))
            status("RUNNING weekly export")
            let sampleNote = "A development sample. Wren’s October is simulated. The photographs are real and were taken across several years. Photo keeps and Pagewright sheets were added for this sample after the saved nightly braids."
            try WeeklyIssuePDFWriter.write(issue, readerName: input.readerName,
                editorialNote: sampleNote + "\n\n" + (notes?.opening ?? ""), closingNote: notes?.closing, receipts: receipts,
                to: output.appendingPathComponent("weekly-issue.pdf"))
            var edition = MonthlyEditionBuilder.edition(from: days, readerName: input.readerName,
                startDate: SyntheticReaderYear.date(2026, 10, 1),
                endDate: SyntheticReaderYear.date(2026, 10, 31).addingTimeInterval(86_399),
                generatedAt: now, calendar: calendar, authoredReceipts: receipts, packTitle: "Count Unbound")
            edition.foreword = sampleNote + "\n\n" + edition.foreword
            status("RUNNING monthly export")
            _ = try MonthlyEditionPDFWriter.writePrintInterior(edition, spec: .perfectBoundSoftcover6x9,
                to: output.appendingPathComponent("monthly-edition.pdf"))
            let weeklyCount = PDFDocument(url: output.appendingPathComponent("weekly-issue.pdf"))?.pageCount ?? 0
            let monthlyCount = PDFDocument(url: output.appendingPathComponent("monthly-edition.pdf"))?.pageCount ?? 0
            guard weeklyCount > 0 && monthlyCount > 0 else { throw ProofError("empty exported sample") }
            status("OK public samples: \(weeklyCount) weekly pages, \(monthlyCount) monthly pages; \(input.photos.count) real photographs, \(input.sheets.count) actual Pagewright sheets; \(nights.count) saved nights")
        } catch { status("FAILED public samples: \(error)") }
    }
}
#endif


#if DEBUG
/// A week shaped like Issue 6 (Sep 23-29, nine kept pages), set through the real
/// weekly builder and writer. Launch with `--proof-weekly-issue6`; the reading
/// copy lands in Documents/weekly-issue6-proof/issue6.pdf. Invented here, never
/// saved, no vault touched. It exists so the page can be looked at.
enum WeeklyIssueSixProof {
    static let flag = "--proof-weekly-issue6"

    /// Called from launch. Runs once, off the main thread, only with the flag.
    static func runIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains(flag) else { return }
        DispatchQueue.global(qos: .utility).async { run() }
    }

    static func run() {
        if ProcessInfo.processInfo.arguments.contains("--proof-october-margins") { MarginaliaDealer.forcedMonth = 10 }
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("weekly-issue6-proof", isDirectory: true)
        try? FileManager.default.removeItem(at: folder)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var status: [String] = []
        do {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "America/New_York")!
            func at(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
                calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
            }
            func photo(_ name: String, _ top: UIColor, _ bottom: UIColor) -> BookPageMediaAsset {
                let url = folder.appendingPathComponent("\(name).jpg")
                let image = UIGraphicsImageRenderer(size: CGSize(width: 900, height: 700)).image { context in
                    let colors = [top.cgColor, bottom.cgColor] as CFArray
                    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
                    context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: 700), options: [])
                    (name as NSString).draw(at: CGPoint(x: 40, y: 40), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 56), .foregroundColor: UIColor.white])
                }
                try? image.jpegData(compressionQuality: 0.85)?.write(to: url)
                return BookPageMediaAsset(kind: .renderedImageFile, reference: url.path, caption: "", sourceID: "",
                                          metadata: ["proofImagePath": url.path])
            }
            func world(_ id: String, _ fact: String) -> String {
                BraidContributionReceipt(beat: SceneWorldBeat(id: id, mode: .independent, fact: fact, source: .worldEvent,
                                                              subject: "The Dictionary Rebellion")).encodedTag ?? ""
            }
            let header = "Tags: Time 9:43 PM \u{00B7} Location Current place \u{00B7} Weather not recorded \u{00B7} Moon Full Moon \u{00B7} Fuel not logged \u{00B7} Inner weather not logged"
            let pages: [BookPage] = [
                BookPage(id: "anchor", type: .diary, createdAt: at(8, 19, 9), promptText: "Ink", userInput: "The first page of the Book.", origin: .userAuthored),
                BookPage(id: "souvenir", type: .souvenir, createdAt: at(9, 25, 21, 39), promptText: "One true sentence",
                         userInput: "The plastic lemon seltzer bottle is regal right now; and bubbly.", origin: .userAuthored),
                BookPage(id: "photo-1", type: .plainPage, createdAt: at(9, 25, 18, 5), promptText: "Photograph",
                         userInput: "The lemon seltzer on the sill before work.", origin: .userAuthored,
                         mediaAssets: [photo("seltzer on the sill", .systemTeal, .systemYellow)]),
                BookPage(id: "photo-2", type: .plainPage, createdAt: at(9, 25, 18, 12), promptText: "Photograph",
                         userInput: "The same bottle, on the porch.", origin: .userAuthored,
                         mediaAssets: [photo("porch", .systemOrange, .systemIndigo)]),
                BookPage(id: "photo-3", type: .plainPage, createdAt: at(9, 28, 12, 30), promptText: "Photograph",
                         userInput: "Fog on the road to work.", origin: .userAuthored,
                         mediaAssets: [photo("fog", .systemGray, .white)]),
                BookPage(id: "braid-fri", type: .bookOfYou, createdAt: at(9, 25, 21, 43), promptText: "Book of You",
                         userInput: "The plastic lemon seltzer bottle\n\n\(header)\n\nThe plastic lemon seltzer bottle was cool in my hand, and the fizz was sharp against my fingers. I noticed the door, the one that led to the quiet room, was still stuck halfway open, a little gap where the dark came through.\n\nThe Book kept the page: the bottle fizzed.",
                         tags: [world("w:coats", "Every coat in the Great Hall is wet on one side only, the side that faces the East Stacks.")],
                         origin: .generated),
                BookPage(id: "cast", type: .castBond, createdAt: at(9, 26, 12, 58), promptText: "A Turn in the Cast",
                         userInput: "You entered, and the Quillquarium did not settle. Pens schooled through the air like minnows, their glinting nibs flashing across the high shelves, while predatory quills patrolled the upper reaches. Somewhere, a pencil pretended to sleep, still and inert. Instruments waited there for years, the keepers had told you, because a pen could hold its breath longer than a person could. Penny watched from the ladder and wrote none of it down.",
                         origin: .generated),
                BookPage(id: "tale", type: .taleBound, createdAt: at(9, 26, 13, 3), promptText: "A Tale, Bound",
                         userInput: "The coffee kept turning up in your pages. I kept count. I didn't say anything until I could see how it came out.\n\nOnce upon a time, there was a coffee.\nOn August 23 you wrote: \"3 coffees\"\n\nThen the coffee came back.\nOn August 27 you wrote: \"2 Bud Lights, Greek chicken salad, coffee, lemon seltzer\"\n\nIn the end, the coffee was still there.",
                         origin: .generated),
                BookPage(id: "compass", type: .wonderCompass, createdAt: at(9, 28, 6, 57), promptText: "Wonder Compass",
                         userInput: "I'm about to go to work, and Amanda hasn't woken up yet; she's off today.", origin: .userAuthored),
                BookPage(id: "bleed", type: .theBleed, createdAt: at(9, 28, 7, 23), promptText: "The Bleed",
                         userInput: "THE BLEED - MORNING EDITION\nIssue #2 \u{00B7} Monday, September 28, 2026\nWhere the Labyrinth meets the page. Where the page bleeds into the world.\n\n\u{2014} CASEMENT WEATHER \u{2014}\nfrom the window ledge, attested\n\nThe window ledge files the following, sworn and stamped: Current: drizzle, 55\u{00B0} | Forecast: rain, high 60\u{00B0}, low 54\u{00B0}.\n\n\u{2014} TODAY AT THE ACADEMY \u{2014}\nSomething happened in the Kitchens.",
                         origin: .generated),
                BookPage(id: "quote", type: .quotes, createdAt: at(9, 28, 7, 40), promptText: "The wound is the place where the Light enters you.",
                         userInput: "Rumi", origin: .userAuthored),
                BookPage(id: "amanda", type: .plainPage, createdAt: at(9, 28, 7, 41), promptText: "Note", userInput: "Amanda", origin: .userAuthored),
                BookPage(id: "weather", type: .weather, createdAt: at(9, 29, 20, 57), promptText: "What the Sky Is Doing",
                         userInput: "The rain is tap-tap-tapping on the window like it wants to come in and read with you.\n\nThe moon is giving its light back now, a little each night.\n\nWeather: Now: 57\u{00B0} | Forecast: rain, high 61\u{00B0}, low 56\u{00B0} \u{00B7} Waning Gibbous",
                         origin: .generated),
                BookPage(id: "braid-tue", type: .bookOfYou, createdAt: at(9, 29, 20, 58), promptText: "Book of You",
                         userInput: "Amanda\n\n\(header)\n\nYou were about to go to work, and Amanda hadn't woken up yet; she was off today. Sentence Salamander leaned near, a shadow stitching itself to the pale light.",
                         tags: [world("w:bowls", "Ambrose has put out a bowl for every chair in the Kitchens, and one more for the chair nobody sits in.")],
                         origin: .generated)
            ]
            var byDay: [Date: [BookPage]] = [:]
            for page in pages { byDay[calendar.startOfDay(for: page.createdAt), default: []].append(page) }
            let days = byDay.keys.sorted().map { BookDay(id: BookDay.id(for: $0, calendar: calendar), date: $0, pages: byDay[$0]!) }
            let now = at(10, 3, 12)
            guard let candidate = PublicationPeriodCatalog.readerWeeks(days: days, now: now, calendar: calendar)
                .first(where: { $0.period.ordinal == 6 }),
                  var issue = WeeklyIssue.issue(for: candidate.period, days: days, now: now, calendar: calendar) else {
                throw NSError(domain: "proof", code: 1, userInfo: [NSLocalizedDescriptionKey: "no Issue 6"])
            }
            // `--proof-issue=9` prints this same week as another issue, to see a different mix of puzzles.
            if let override = ProcessInfo.processInfo.arguments.compactMap({ $0.hasPrefix("--proof-issue=") ? Int($0.dropFirst(14)) : nil }).first {
                issue.number = override
            }
            // The floor, as the app falls back to it; the model's own story is not run here.
            issue.bindingStory = WeeklyBindingWriter.issue(for: WeeklyBindingPlanner.plan(for: issue, calendar: calendar))
            status.append("issue \(issue.number) \(issue.dateRange), \(issue.keptCount) kept, \(issue.pages.count) pages")
            status.append("highlights: \(issue.highlights)")
            status.append("refrain: \(WeeklyCuration.refrain(from: issue.pages))")
            status.append("binding story:\n\(issue.bindingStory ?? "none")")
            let card = WeeklyIssueShareCard.make(issue: issue)
            try WeeklyIssuePDFWriter.write(issue, readerName: "Proof Reader", shareCard: card,
                                           to: folder.appendingPathComponent("issue6.pdf"))
            status.append("reading copy written")
            // The print weekly, exactly as the bindery builds it: the day book, the handbook, the press spec.
            PrintFeatureFlags.ruinPagesEnabled = false
            var matter = WeeklyPublicationMatter(issue: issue, card: card, readerName: "Proof Reader",
                                                 editorialNote: nil, closingNote: nil)
            matter.dayBook = BoundDayBookBuilder.make(
                pages: issue.pages, receipts: .empty, castActs: [],
                startDate: issue.startDate, endDate: issue.endDate, calendar: calendar)
            matter.handbook = HandbookBuilder.make(
                pages: issue.pages, castPresence: matter.dayBook?.chart.cast ?? [],
                terms: [issue.resolvedEditorialTitle] + issue.highlights, seed: "week-\(issue.number)",
                dayBook: matter.dayBook, dayCount: 7)
            matter.bindingID = "proof-binding-issue6"
            let printPages = try WeeklyIssuePDFWriter.writePrintInterior(
                matter, dedication: nil, spec: .saddleStitchedWeekly6x9,
                to: folder.appendingPathComponent("issue6-print.pdf"))
            status.append("print interior written: \(printPages) pages")
            status.append("DONE")
        } catch {
            status.append("FAILED: \(error)")
        }
        try? status.joined(separator: "\n").write(to: folder.appendingPathComponent("status.txt"), atomically: true, encoding: .utf8)
    }
}
#endif
