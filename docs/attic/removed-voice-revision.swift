        let houseComposition = DeterministicBraidwright.composition(for: day, context: context)
        // The plan-driven floor, as a candidate on the same terms as everything
        // else: audited, tasted, and beaten on merit or not at all. When
        // `BraidFloor.preferred` is flipped it becomes the page that ships if no
        // model page wins; until then it competes and usually loses, which is
        // information rather than a problem.
        // Titled from the reader's own words rather than borrowed from the
        // sentence-bank writer, so the floor stands on its own.
        let floorPage = BraidSceneWriter.page(
            for: scenePlanForFloor, title: scenePlanForFloor.title()
        )
        var revisedPage: BookPage?
        do {
            let revision = try await generate(
                prompt: BraidPromptBuilder.voiceRevisionPrompt(
                    for: day,
                    context: context,
                    composition: houseComposition
                ),
                label: "braid-voice-revision",
                temperature: 0.75,
                topP: 0.92
            )
            let verified = BraidRevisionVerifier.verify(
                revision: revision,
                of: houseComposition,
                day: day,
                context: context
            )
            appLog.info(
                """
                Braid revision: \(verified.changedCount, privacy: .public) of \
                \(verified.decisions.count, privacy: .public) sentences changed, \
                adopted=\(verified.adopted, privacy: .public), \
                taste \(verified.originalScore, privacy: .public)->\
                \(verified.revisedScore, privacy: .public), \
                refused=\(Set(verified.rejections.map(\.rawValue)).sorted().joined(separator: ","), privacy: .public)
                """
            )
            if verified.adopted { revisedPage = verified.composition.page }
        } catch {
            // A cold or failing brain simply means tonight's page keeps the
            // voice it was written in. It was always complete.
            appLog.error(
                "Braid voice revision unavailable: \(error.localizedDescription, privacy: .private)"
            )
        }

        // Free-form Gemma stays in the room as a third entrant until the bench
        // says cooperation beats competition on real nights.
        // Free-form drafts are held out of the official pool until provenance
        // travels with them.
        //
        // `generatedPages` are whole pages Gemma wrote from the prompt. They
        // were filtered only for register failures and then entered the tasting
        // room, where nothing checked what they had *added*: all nineteen audit
        // issues ask what is missing or what register was broken, and none asks
        // whether a mundane event was invented. A draft that kept "plums",
        // "landlord" and "lido" could add an afternoon that never happened and
        // win the night.
        //
        // The sentence-aligned revision stays, because that one is verified
        // line by line against the line it replaced. Free-form returns in the
        // phase that gives Gemma sentence roles and atomic source ids, so its
        // claims can be checked rather than trusted.
