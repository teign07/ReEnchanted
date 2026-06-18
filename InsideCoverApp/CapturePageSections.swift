import SwiftUI

// MARK: - CapturePageSheet sections as standalone views.
//
// Each struct boundary resets SwiftUI's generic type nesting (the cause of
// the sheet-presentation segfault) and keeps the sheet's state surface small.

struct ChapterBindingFormView: View {
    let surface: SurfacePage
    let onBindChapter: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    private var chosenChapter: AcademyChapter? {
        AcademyChapterRegistry.chapter(id: surface.payload.metadata["chosenChapterID"] ?? "")
    }

    private var evidenceLines: [String] {
        (surface.payload.metadata["bindingEvidence"] ?? "")
            .components(separatedBy: " | ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let chapter = chosenChapter {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: chapter.symbolName)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(BookPalette.lampGold)
                        Text("Chapter \(chapter.name)")
                            .font(.system(.title3, design: .serif, weight: .bold))
                            .foregroundStyle(BookPalette.ink)
                        Spacer()
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(BookPalette.teal)
                    }
                    Text(chapter.philosophy)
                        .font(.callout)
                        .foregroundStyle(BookPalette.ink.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(chapter.traits.joined(separator: " · "))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(BookPalette.teal.opacity(0.85))
                    Text("\u{201C}\(chapter.writeFraming)\u{201D}")
                        .font(.system(.caption, design: .serif).italic())
                        .foregroundStyle(BookPalette.ink.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BookPalette.page.opacity(0.9), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(BookPalette.lampGold.opacity(0.45), lineWidth: 1.2)
                }
            }

            if !evidenceLines.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("What the Binding read")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BookPalette.ink.opacity(0.72))
                    ForEach(evidenceLines, id: \.self) { line in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•")
                            Text(line)
                        }
                        .font(.caption)
                        .foregroundStyle(BookPalette.ink.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Button {
                guard let chapterID = chosenChapter?.id else { return }
                BookFeedback.play(.braidStart)
                onBindChapter(chapterID)
                dismiss()
            } label: {
                Label("Accept the Binding", systemImage: "seal")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
            .buttonStyle(.borderedProminent)
            .tint(BookPalette.teal)
            .disabled(chosenChapter == nil)

            Text("The binding is real: your Chapter tints how Story Pages meet you, and its talisman warms with your Belief. The Book chose from kept pages and invested Belief, not from a preference quiz.")
                .font(.caption)
                .foregroundStyle(BookPalette.ink.opacity(0.58))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct AnchorOfferFormView: View {
    let surface: SurfacePage
    let onAnchorPlace: (AnchorPlaceDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var anchorPlaceName = ""
    @State private var anchorPlaceWords = ""
    @State private var anchorPlaceKind: AnchorKind = .notice

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sheetLabeledField("What is this place called?", text: $anchorPlaceName, placeholder: "The co-op, the back porch, the trailhead...")

            VStack(alignment: .leading, spacing: 6) {
                Text("WHAT DOES THIS PLACE HOLD?")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(BookPalette.teal.opacity(0.82))
                TextField(
                    "Not what it is — what it holds for you. Your exact words become the room.",
                    text: $anchorPlaceWords,
                    axis: .vertical
                )
                .font(.callout.weight(.semibold))
                .foregroundStyle(BookPalette.ink)
                .textFieldStyle(.plain)
                .lineLimit(2...5)
                .dictationInput(text: $anchorPlaceWords)
                .padding(10)
                .background(BookPalette.paper.opacity(0.74), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(BookPalette.ink.opacity(0.12), lineWidth: 1)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("WHICH DIRECTION DOES IT POINT?")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(BookPalette.teal.opacity(0.82))
                Picker("Anchor kind", selection: $anchorPlaceKind) {
                    ForEach(AnchorKind.allCases, id: \.self) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
            }

            Button {
                BookFeedback.play(.braidStart)
                let draft = AnchorPlaceDraft(
                    name: anchorPlaceName.trimmingCharacters(in: .whitespacesAndNewlines),
                    words: anchorPlaceWords.trimmingCharacters(in: .whitespacesAndNewlines),
                    kind: anchorPlaceKind,
                    latitude: Double(surface.payload.metadata["latitude"] ?? "") ?? 0,
                    longitude: Double(surface.payload.metadata["longitude"] ?? "") ?? 0
                )
                onAnchorPlace(draft)
                dismiss()
            } label: {
                Label("Anchor this place", systemImage: "mappin.and.ellipse")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(BookPalette.teal)
            .disabled(anchorPlaceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Text("The Labyrinth will grow an Outer Stacks room from your words, and you can step inside the moment it is made. Location stays on your phone.")
                .font(.caption)
                .foregroundStyle(BookPalette.ink.opacity(0.58))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(BookPalette.page.opacity(0.82), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.teal.opacity(0.26), lineWidth: 1)
        }
    }

    private func sheetLabeledField(_ title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(BookPalette.teal.opacity(0.82))
            TextField(placeholder, text: text, axis: .vertical)
                .font(.callout.weight(.semibold))
                .foregroundStyle(BookPalette.ink)
                .textFieldStyle(.plain)
                .lineLimit(1...3)
                .dictationInput(text: text)
                .padding(10)
                .background(BookPalette.paper.opacity(0.74), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(BookPalette.ink.opacity(0.12), lineWidth: 1)
                }
        }
    }
}

struct ElectiveFlyleafListView: View {
    let activeElectives: [UnwrittenElective]
    let onCompleteElective: (String, String) -> Void

    @State private var electiveProofDrafts: [String: String] = [:]
    @State private var completedElectiveIDs: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(activeElectives) { elective in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(elective.title)
                            .font(.callout.weight(.bold))
                            .foregroundStyle(BookPalette.ink)
                        Spacer()
                        Text(elective.characterName)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(BookPalette.teal)
                    }
                    Text(elective.ask)
                        .font(.caption)
                        .foregroundStyle(BookPalette.ink.opacity(0.76))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Counts as done: \(elective.practiceShape)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(BookPalette.ink.opacity(0.58))
                        .fixedSize(horizontal: false, vertical: true)

                    TextField(
                        "One sentence of proof...",
                        text: Binding(
                            get: { electiveProofDrafts[elective.id] ?? "" },
                            set: { electiveProofDrafts[elective.id] = $0 }
                        ),
                        axis: .vertical
                    )
                    .font(.callout)
                    .textFieldStyle(.plain)
                    .lineLimit(1...3)
                    .dictationInput(text: Binding(
                        get: { electiveProofDrafts[elective.id] ?? "" },
                        set: { electiveProofDrafts[elective.id] = $0 }
                    ))
                    .padding(8)
                    .background(BookPalette.paper.opacity(0.74), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Button {
                        let proof = (electiveProofDrafts[elective.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !proof.isEmpty else { return }
                        BookFeedback.play(.keepPage)
                        completedElectiveIDs.insert(elective.id)
                        onCompleteElective(elective.id, proof)
                    } label: {
                        Label(
                            completedElectiveIDs.contains(elective.id) ? "Completed" : "Complete with proof",
                            systemImage: completedElectiveIDs.contains(elective.id) ? "checkmark.seal.fill" : "checkmark.seal"
                        )
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(BookPalette.teal)
                    .disabled(
                        completedElectiveIDs.contains(elective.id) ||
                        (electiveProofDrafts[elective.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
                .padding(12)
                .background(BookPalette.page.opacity(0.86), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(BookPalette.teal.opacity(0.22), lineWidth: 1)
                }
            }
        }
    }
}

struct SupportGuildSectionView: View {
    let surface: SurfacePage

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(surface.payload.body)
                .font(.system(.callout, design: .serif))
                .foregroundStyle(BookPalette.ink.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)

            supportGuildDisclosure("Dr. Vellum", systemImage: "heart.text.square", value: surface.payload.metadata["vellumSection"])
            supportGuildDisclosure("Dr. Inkrest", systemImage: "cloud.sun", value: surface.payload.metadata["inkrestSection"])
            supportGuildDisclosure("Connections", systemImage: "point.3.connected.trianglepath.dotted", value: surface.payload.metadata["connectionsSection"])
            supportGuildDisclosure("Experiment", systemImage: "checklist", value: surface.payload.metadata["experimentSection"])
            supportGuildDisclosure("Safety", systemImage: "lock.shield", value: surface.payload.metadata["safetySection"])
        }
    }

    @ViewBuilder
    private func supportGuildDisclosure(_ title: String, systemImage: String, value: String?) -> some View {
        if let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
            DisclosureGroup {
                Text(value)
                    .font(.caption)
                    .foregroundStyle(BookPalette.ink.opacity(0.76))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            } label: {
                Label(title, systemImage: systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BookPalette.teal)
            }
            .padding(10)
            .background(BookPalette.paper.opacity(0.74), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(BookPalette.ink.opacity(0.12), lineWidth: 1)
            }
        }
    }
}
