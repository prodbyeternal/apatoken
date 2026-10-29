import Combine
import SwiftUI

// MARK: - Colors (carried over from the Android app)

enum ApaColor {
    /// #E3003D
    static let red = Color(red: 0.8901961, green: 0, blue: 0.23921569)
    /// #004586
    static let blue = Color(red: 0, green: 23.0 / 85.0, blue: 0.5254902)
    /// #001E3B
    static let darkBlue = Color(red: 0, green: 0.11764706, blue: 0.23137255)
    /// #01B101
    static let green = Color(red: 0.003921569, green: 59.0 / 85.0, blue: 0.003921569)
    /// #737373
    static let gray = Color(red: 23.0 / 51.0, green: 23.0 / 51.0, blue: 23.0 / 51.0)
    /// #8493BD – token entry text color.
    static let entryText = Color(red: 44.0 / 85.0, green: 49.0 / 85.0, blue: 63.0 / 85.0)
    /// #808080 – token entry border.
    static let border = Color(red: 0.5019608, green: 0.5019608, blue: 0.5019608)
    /// Reset-state label gray (115, 115, 115).
    static let creditReset = Color(red: 115.0 / 255.0, green: 115.0 / 255.0, blue: 115.0 / 255.0)
}

// MARK: - Fonts (Open Sans, registered in code)

enum ApaFont {
    static func regular(_ size: CGFloat) -> Font {
        .custom("OpenSans-Regular", size: size)
    }

    static func semibold(_ size: CGFloat) -> Font {
        .custom("OpenSans-Semibold", size: size)
    }
}

// MARK: - App state (tab coordination, mirroring Shell.Current.GoToAsync)

@MainActor
final class AppState: ObservableObject {
    /// Tab order: 0 = Prepaid recharge, 1 = Readings, 2 = History, 3 = Settings.
    @Published var selection = 0

    func goToSettings() {
        selection = 3
    }
}

// MARK: - Alert popup presentation model

/// One AlertPopup presentation (title, two text lines, optional error icon).
struct AlertPresentation: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let text1: String
    let text2: String

    init(_ title: String, _ text1: String, _ text2: String = "") {
        self.title = title
        self.text1 = text1
        self.text2 = text2
    }
}

extension View {
    /// Presents a mirrored AlertPopup card over the current screen.
    /// Overlay (not background): the popup must sit on top of all
    /// content and its OK button must stay tappable.
    func alertPopup(_ presentation: Binding<AlertPresentation?>) -> some View {
        overlay(AlertPopupHost(presentation: presentation))
    }
}

@MainActor
struct AlertPopupHost: View {
    @Binding var presentation: AlertPresentation?

    var body: some View {
        GeometryReader { proxy in
            if let presentation {
                ZStack {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                        .transition(.opacity)
                    AlertPopupCard(presentation: presentation,
                                   showsErrorIcon: presentation.title == L.ui.txtError) {
                        withAnimation(.easeOut(duration: 0.18)) {
                            self.presentation = nil
                        }
                    }
                    .frame(maxWidth: proxy.size.width >= 600 ? 500 : 300)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
                }
            }
        }
        .animation(.easeOut(duration: 0.18), value: presentation != nil)
        .allowsHitTesting(presentation != nil)
    }
}

/// AlertPopup card mirror: white card, radius 0 (kept for parity with the
/// squared Android frame), padding 20, three auto rows with 10 spacing,
/// bold title with the red error symbol when the title == txtError,
/// scrollable text area (max height 200), OK button on the trailing side.
struct AlertPopupCard: View {
    let presentation: AlertPresentation
    let showsErrorIcon: Bool
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                if showsErrorIcon {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(ApaColor.red)
                        .font(.system(size: 20))
                }
                Text(presentation.title)
                    .font(ApaFont.semibold(14))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: showsErrorIcon ? .leading : .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    Text(presentation.text1)
                        .font(ApaFont.regular(14))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if !presentation.text2.isEmpty {
                        Text(presentation.text2)
                            .font(ApaFont.semibold(14))
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .maximumHeight(of: 200)

            Button(action: onDismiss) {
                Text(L.ui.txtOk)
                    .font(ApaFont.semibold(14))
                    .foregroundStyle(ApaColor.blue)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(20)
        .background(.white)
        .cornerRadius(AppStyle.alertCorner)
        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
        .padding(.horizontal, 4)
    }
}

// MARK: - Shared style constants

enum AppStyle {
    /// Angular Android look → slightly rounded for the iOS port.
    static let alertCorner: CGFloat = 12
    static let cardCorner: CGFloat = 16
    static let buttonCorner: CGFloat = 14
}

// MARK: - small helpers

extension View {
    func maximumHeight(of height: CGFloat) -> some View {
        frame(maxHeight: height)
    }

    /// Card look used across the main screens.
    func apaCard() -> some View {
        padding(16)
            .background(.white)
            .cornerRadius(AppStyle.cardCorner)
            .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
    }
}

// MARK: - Task helpers

extension Task where Success == Never, Failure == Never {
    /// Task.Delay(ms).
    static func delay(milliseconds: Int) async throws {
        try await Task.sleep(nanoseconds: UInt64(milliseconds) * 1_000_000)
    }
}
