import SwiftUI

enum UsagiTheme {
    /// Matches app accent; asset catalog may override via AccentColor.
    static let accent = Color.accentColor

    static let cardCorner: CGFloat = 12
    static let coverAspect: CGFloat = 2.0 / 3.0
    static let gridSpacing: CGFloat = 12

    static var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 110, maximum: 160), spacing: gridSpacing)]
    }
}

extension View {
    func usagiCard() -> some View {
        background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: UsagiTheme.cardCorner, style: .continuous)
        )
    }
}
