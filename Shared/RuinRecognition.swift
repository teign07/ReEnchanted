import Foundation

/// What the Book says, and keeps, when a photograph turns out to be a page of
/// a book it sent to the press. Pure text: reading the photograph is
/// `FolioReader`'s job, and keeping it is the capture sheet's.
enum RuinRecognition {
    /// The Book noticing a page it printed. It does not claim to have seen
    /// what the reader did to it: it can only say which page this is.
    static func line(volume: BoundVolumeRegistry, page: Int) -> String {
        let title = volume.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let book = title.isEmpty ? "one of my books" : "\u{201C}\(title)\u{201D}"
        if let prompt = volume.ruinPrompt(onPage: page) {
            return "I know this one. Page \(page) of \(book). It's the page that said \u{201C}\(prompt.title).\u{201D} Keep the photo and I'll know you handled me."
        }
        return "I know this one. Page \(page) of \(book). Keep the photo and I'll know you were reading me."
    }

    /// Metadata carried on the kept photograph. The prompt is copied whole, so
    /// the page still means something after the pack that printed it is gone.
    static func metadata(volume: BoundVolumeRegistry, page: Int) -> [String: String] {
        var meta: [String: String] = [
            "printedPage": "true",
            "printedVolume": volume.seed,
            "printedEdition": volume.editionID,
            "printedVolumeTitle": volume.title,
            "printedPageNumber": String(page)
        ]
        if let prompt = volume.ruinPrompt(onPage: page) {
            meta["ruin"] = "true"
            meta["ruinPromptID"] = prompt.id
            meta["ruinKind"] = prompt.kind.rawValue
            meta["ruinTitle"] = prompt.title
            meta["ruinInstruction"] = prompt.instruction
        }
        return meta
    }

    /// The ruin a kept photograph recorded, if it recorded one.
    static func prompt(fromMetadata meta: [String: String]) -> RuinPrompt? {
        guard meta["ruin"] == "true",
              let id = meta["ruinPromptID"], let kind = meta["ruinKind"].flatMap(RuinKind.init(rawValue:)),
              let title = meta["ruinTitle"], let instruction = meta["ruinInstruction"] else { return nil }
        return RuinPrompt(id: id, kind: kind, title: title, instruction: instruction)
    }
}
