import SwiftUI
import UIKit

/// Whose hand a line is written in.
///
/// The reader's hand is theirs alone: Bradley Hand in their blue-black, on the
/// leaf, on the desk and in every printed edition. Nobody else writes in it —
/// not the Book, not the Cast, not a caption or a label — so wherever that hand
/// appears it means "you wrote this", without a word saying so. Everyone else
/// who writes by hand (the Book's margins, Pippa, a Proctor's signature) uses
/// the Book's hand, told apart by their ink.
///
/// `WiringLintTests` holds the font names to this file: a hand chosen anywhere
/// else is a hand nobody decided.
enum BookHand {
    case reader
    case book

    var fontName: String {
        switch self {
        case .reader: return "BradleyHandITCTT-Bold"
        case .book: return "Noteworthy-Light"
        }
    }

    /// The reader's ink: iron-gall blue-black, the colour of a pen, not of print.
    static let readerInk = UIColor(red: 0.13, green: 0.20, blue: 0.36, alpha: 0.94)
    static var readerInkColor: Color { Color(uiColor: readerInk) }

    func uiFont(_ size: CGFloat) -> UIFont {
        if let font = UIFont(name: fontName, size: size) { return font }
        let serif = UIFont.systemFont(ofSize: size).fontDescriptor
            .withDesign(.serif)?
            .withSymbolicTraits(.traitItalic)
        return serif.map { UIFont(descriptor: $0, size: size) } ?? .italicSystemFont(ofSize: size)
    }

    func font(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(fontName, size: size, relativeTo: style)
    }

    func font(fixedSize size: CGFloat) -> Font {
        .custom(fontName, fixedSize: size)
    }
}
