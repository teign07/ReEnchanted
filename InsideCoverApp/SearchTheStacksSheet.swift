import SwiftUI

/// Search the Stacks: the living archive's reading-room desk. Local and
/// instant; optionally the Book (Gemma) can interpret a strange question
/// into search terms.
struct SearchTheStacksSheet: View {
    let dataset: StacksSearchDataset
    let isLocalBrainWorking: Bool
    let localBrainWorkLabel: String
    let localBrainWorkStartedAt: Date?
    let onOpen: (StacksSearchResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var query = ""
    @State private var results: [StacksSearchResult] = []
    @State private var interpretedTerms: [String] = []
    @State private var interpretationNote = ""
    @State private var isInterpreting = false
    @FocusState private var searchFocused: Bool

    private let exampleQueries = [
        "Show me everything with Small Glow",
        "What did I keep when I was tired?",
        "Find porch memories",
        "missions",
        "rainy pages"
    ]
    private static let localBrainStatusScrollID = "stacks-local-brain-status"

    var body: some View {
        NavigationStack {
            ZStack {
                BookBackground()

                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            searchField

                            if isInterpreting {
                                LocalBrainWorkingStatusCard(
                                    label: "stacks-search",
                                    startedAt: localBrainWorkStartedAt,
                                    presentation: .page
                                )
                                .id(Self.localBrainStatusScrollID)
                            } else if isLocalBrainWorking {
                                LocalBrainWorkingStatusCard(
                                    label: localBrainWorkLabel,
                                    startedAt: localBrainWorkStartedAt,
                                    presentation: .compact
                                )
                                .id(Self.localBrainStatusScrollID)
                            }

                            if !interpretationNote.isEmpty {
                                Text(interpretationNote)
                                    .font(.system(.caption, design: .serif).italic())
                                    .foregroundStyle(BookPalette.nightText.opacity(0.74))
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            if !interpretedTerms.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "text.book.closed")
                                        .foregroundStyle(BookPalette.lampGold)
                                    ForEach(interpretedTerms, id: \.self) { term in
                                        Text(term)
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(BookPalette.teal)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 5)
                                            .background(BookPalette.teal.opacity(0.10), in: Capsule())
                                            .transition(.opacity.combined(with: .move(edge: .leading)))
                                    }
                                }
                                .accessibilityLabel("The Book indexed: \(interpretedTerms.joined(separator: ", "))")
                            }

                            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                                emptyDesk
                            } else if results.isEmpty {
                                Text("The Stacks rustle, but nothing steps forward for that yet. Try another phrasing — or let the Book read it.")
                                    .font(.system(.callout, design: .serif))
                                    .foregroundStyle(BookPalette.nightText.opacity(0.7))
                                    .padding(.top, 8)
                            } else {
                                resultsList
                            }
                        }
                        .padding(18)
                        .textSelection(.enabled)
                    }
                    .onChange(of: isInterpreting) { _, interpreting in
                        guard interpreting else { return }
                        scrollToLocalBrainStatus(scrollProxy)
                    }
                    .onChange(of: isLocalBrainWorking) { _, isWorking in
                        guard isWorking else { return }
                        scrollToLocalBrainStatus(scrollProxy)
                    }
                }
            }
            .navigationTitle("Search the Stacks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        BookFeedback.play(.dismissPage)
                        dismiss()
                    }
                }
            }
            .task(id: query) {
                try? await Task.sleep(for: .milliseconds(220))
                guard !Task.isCancelled else { return }
                let searchQuery = query
                guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    results = []
                    return
                }
                if interpretedTerms.isEmpty == false {
                    interpretedTerms = []
                    interpretationNote = ""
                }
                let found = await searchResults(for: searchQuery)
                guard !Task.isCancelled else { return }
                results = found
            }
            .onAppear {
                searchFocused = true
            }
            .keepsFocusedTextInputVisible()
        }
    }

    private func scrollToLocalBrainStatus(_ scrollProxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.easeInOut(duration: 0.28)) {
                scrollProxy.scrollTo(Self.localBrainStatusScrollID, anchor: .top)
            }
        }
    }

    private var searchField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "sparkle.magnifyingglass")
                    .foregroundStyle(BookPalette.lampGold)
                TextField("Ask the Stacks...", text: $query, axis: .vertical)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(BookPalette.ink)
                    .textFieldStyle(.plain)
                    .lineLimit(1...2)
                    .focused($searchFocused)
                    .submitLabel(.search)
                    .dictationInput(text: $query)
                if !query.isEmpty {
                    Button {
                        query = ""
                        results = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(BookPalette.ink.opacity(0.35))
                    }
                    .buttonStyle(.bookPress())
                }
            }
            .padding(12)
            .background(BookPalette.page.opacity(0.95), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(BookPalette.lampGold.opacity(0.4), lineWidth: 1)
            }

            if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                Button {
                    Task { await interpretWithTheBook() }
                } label: {
                    Label(
                        isInterpreting ? "The Book is reading your question..." : "Let the Book read it",
                        systemImage: isInterpreting ? "pencil.and.scribble" : "text.book.closed"
                    )
                    .font(.caption.weight(.bold))
                }
                .buttonStyle(.bordered)
                .tint(BookPalette.teal)
                .disabled(isInterpreting || isLocalBrainWorking)
            }
        }
    }

    private var emptyDesk: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("The Stacks hold everything you have kept: pages, places, cast, favors, and the library itself. Ask plainly or strangely.")
                .font(.system(.callout, design: .serif))
                .foregroundStyle(BookPalette.nightText.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)

            FlowLayoutChips(items: exampleQueries) { example in
                BookFeedback.play(.select)
                query = example
            }
        }
        .padding(.top, 6)
    }

    private var resultsList: some View {
        let grouped = Dictionary(grouping: results, by: \.kind)
        return VStack(alignment: .leading, spacing: 16) {
            ForEach(StacksSearchResult.Kind.allCases, id: \.rawValue) { kind in
                if let items = grouped[kind], !items.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(kind.title, systemImage: kind.symbolName)
                            .font(.caption.weight(.black))
                            .foregroundStyle(BookPalette.lampGold.opacity(0.9))
                        ForEach(items) { result in
                            Button {
                                BookFeedback.play(.openPage)
                                onOpen(result)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(result.title)
                                            .font(.system(.subheadline, design: .serif, weight: .bold))
                                            .foregroundStyle(BookPalette.ink)
                                        Spacer()
                                        if !result.dateLabel.isEmpty {
                                            Text(result.dateLabel)
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(BookPalette.teal)
                                        }
                                    }
                                    Text(result.snippet)
                                        .font(.caption)
                                        .foregroundStyle(BookPalette.ink.opacity(0.72))
                                        .fixedSize(horizontal: false, vertical: true)
                                        .multilineTextAlignment(.leading)
                                }
                                .padding(11)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(BookPalette.page.opacity(0.92), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(BookPalette.ink.opacity(0.1), lineWidth: 1)
                                }
                            }
                            .buttonStyle(.bookPress())
                            .bookCardHover()
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                }
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.86), value: results.map(\.id))
    }

    private func interpretWithTheBook() async {
        guard !isInterpreting else { return }
        isInterpreting = true
        defer { isInterpreting = false }
        let prompt = """
        A reader asked the Stacks: "\(query)"
        Translate this into 3 to 6 concrete search words that would appear in personal journal pages, place names, character names, mood words, or object words. Prefer specific nouns. Include synonyms for feelings.
        Return strict JSON only: {"terms": ["word", ...], "note": "one short in-world sentence about how the Book read the question"}
        """
        guard let response = await LocalBrainProse.write(
            prompt: prompt,
            instructions: "You are the Book's index daemon inside ReEnchanted. Return compact strict JSON only.",
            maxTokens: 140,
            sourceID: "stacks-search",
            tags: ["search"]
        ), let raw = JSONSalvage.dictionary(from: response) else {
            interpretationNote = "The Book squinted at the question but the index stayed dark. Plain words still work."
            return
        }
        let terms = (raw["terms"] as? [String]) ?? []
        withAnimation(reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.34, dampingFraction: 0.84)) {
            interpretedTerms = terms
            interpretationNote = JSONSalvage.string("note", in: raw)
                ?? "The Book read it as: \(terms.joined(separator: ", "))"
        }
        let interpretedResults = await searchResults(for: query, extraTerms: terms)
        withAnimation(reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.38, dampingFraction: 0.86)) {
            results = interpretedResults
        }
        BookFeedback.play(.sourceRefresh)
    }

    private func searchResults(for query: String, extraTerms: [String] = []) async -> [StacksSearchResult] {
        let snapshot = dataset
        return await Task.detached(priority: .userInitiated) {
            StacksSearchEngine.hybridSearch(query, in: snapshot, extraTerms: extraTerms)
        }.value
    }
}

/// Minimal wrapping chip row for example queries.
private struct FlowLayoutChips: View {
    let items: [String]
    let onTap: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Button {
                    onTap(item)
                } label: {
                    Text("\u{201C}\(item)\u{201D}")
                        .font(.system(.caption, design: .serif).italic())
                        .foregroundStyle(BookPalette.teal)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(BookPalette.teal.opacity(0.1), in: Capsule())
                        .overlay {
                            Capsule().stroke(BookPalette.teal.opacity(0.3), lineWidth: 1)
                        }
                }
                .buttonStyle(.bookPress())
            }
        }
    }
}
