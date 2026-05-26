import SwiftUI

extension View {
    func controlHelp(_ text: String) -> some View {
        help(text)
            .accessibilityHint(Text(text))
    }
}
