import SwiftUI

/// A pulse-and-fade animation that plays once and then disappears.
/// Used for success feedback when a token is accepted.
struct PulseFadeTransition: ViewModifier {
    let tint: Color

    func body(content: Content) -> some View {
        content
            .scaleEffect(0.15)
            .opacity(0)
            .background(tint.cornerRadius(16))
            .blur(radius: 24)
            .transition(.opacity)
            .animation(.easeOut(duration: 0.1), value: UUID())
    }
}

extension AnyTransition {
    /// Scales up and fades in — used for success checkmark.
    static let successPop = AnyTransition.scale(scale: 0.3).combined(with: .opacity)

    /// Scales down and fades out — used for error X mark.
    static let errorPop = AnyTransition.scale(scale: 0.3).combined(with: .opacity)

    /// Slide up from bottom with opacity.
    static let slideInUp = AnyTransition.offset(y: 30).combined(with: .opacity)
}
