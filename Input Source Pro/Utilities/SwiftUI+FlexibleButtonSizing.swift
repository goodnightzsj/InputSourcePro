import SwiftUI

private struct FlexibleButtonSizingModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            #if compiler(>=6.2)
            content
                .buttonSizing(.flexible)
            #else
            content
            #endif
        } else {
            content
        }
    }
}

extension View {
    func flexibleButtonSizing() -> some View {
        modifier(FlexibleButtonSizingModifier())
    }
}
