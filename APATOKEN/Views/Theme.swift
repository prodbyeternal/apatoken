import Combine
import SwiftUI
import UIKit

// MARK: - Colors (brand palette, adaptive for light/dark appearance)

enum ApaColor {
    /// Dynamic color: light variant in light mode, dark variant in dark mode.
    private static func adaptive(_ light: UIColor, _ dark: UIColor) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }

    /// #E3003D (brightened in dark mode for contrast).
    static let red = adaptive(
        UIColor(red: 0.8901961, green: 0, blue: 0.23921569, alpha: 1),
        UIColor(red: 1.0, green: 0.29, blue: 0.44, alpha: 1))

    /// #004586 (lifted in dark mode so filled buttons stay visible).
    static let blue = adaptive(
        UIColor(red: 0, green: 23.0 / 85.0, blue: 0.5254902, alpha: 1),
        UIColor(red: 0.10, green: 0.46, blue: 0.80, alpha: 1))

    /// #001E3B – deep brand navy (headers/accents).
    static let darkBlue = adaptive(
        UIColor(red: 0, green: 0.11764706, blue: 0.23137255, alpha: 1),
        UIColor(red: 0.04, green: 0.09, blue: 0.16, alpha: 1))

    /// #01B101 (mint-green in dark mode, like system greens).
    static let green = adaptive(
        UIColor(red: 0.003921569, green: 59.0 / 85.0, blue: 0.003921569, alpha: 1),
        UIColor(red: 0.19, green: 0.80, blue: 0.35, alpha: 1))

    /// #737373 (lifted in dark mode).
    static let gray = adaptive(
        UIColor(red: 23.0 / 51.0, green: 23.0 / 51.0, blue: 23.0 / 51.0, alpha: 1),
        UIColor(red: 0.60, green: 0.60, blue: 0.62, alpha: 1))

    /// #8493BD – token entry text color.
    static let entryText = adaptive(
        UIColor(red: 44.0 / 85.0, green: 49.0 / 85.0, blue: 63.0 / 85.0, alpha: 1),
        UIColor(red: 0.67, green: 0.75, blue: 0.89, alpha: 1))

    /// #808080 – token entry border (dimmer in dark mode).
    static let border = adaptive(
        UIColor(red: 0.5019608, green: 0.5019608, blue: 0.5019608, alpha: 1),
        UIColor(red: 0.36, green: 0.36, blue: 0.38, alpha: 1))

    /// Reset-state label gray (115, 115, 115).
    static let creditReset = adaptive(
        UIColor(red: 115.0 / 255.0, green: 115.0 / 255.0, blue: 115.0 / 255.0, alpha: 1),
        UIColor(red: 0.56, green: 0.56, blue: 0.58, alpha: 1))

    // MARK: Semantic surfaces (follow light/dark automatically)

    /// Screen background (grouped, like Settings).
    static let page = Color(uiColor: .systemGroupedBackground)

    /// Card / control background on top of `page`.
    static let card = Color(uiColor: .secondarySystemGroupedBackground)

    /// Hairline separators.
    static let separator = Color(uiColor: .separator)

    /// Primary text on cards.
    static let text = Color.primary

    /// Secondary text on cards.
    static let subtleText = Color(uiColor: .secondaryLabel)
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
                    Color.black.opacity(0.4)
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

/// AlertPopup card mirror: adaptive card, continuous corners, padding 20,
/// three auto rows with 10 spacing, bold title with the red error symbol
/// when the title == txtError, scrollable text area (max height 200),
/// OK button on the trailing side.
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
                    .font(ApaFont.semibold(15))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    Text(presentation.text1)
                        .font(ApaFont.regular(14))
                        .foregroundStyle(ApaColor.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if !presentation.text2.isEmpty {
                        Text(presentation.text2)
                            .font(ApaFont.semibold(14))
                            .foregroundStyle(ApaColor.text)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .maximumHeight(of: 200)

            Button(action: onDismiss) {
                Text(L.ui.txtOk)
                    .font(ApaFont.semibold(15))
                    .foregroundStyle(ApaColor.blue)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(20)
        .background(ApaColor.card, in: RoundedRectangle(cornerRadius: AppStyle.alertCorner, style: .continuous))
        .shadow(color: .black.opacity(0.22), radius: 14, y: 6)
        .padding(.horizontal, 4)
    }
}

// MARK: - Shared style constants

enum AppStyle {
    static let alertCorner: CGFloat = 16
    static let cardCorner: CGFloat = 18
    static let buttonCorner: CGFloat = 14
}

// MARK: - small helpers

extension View {
    func maximumHeight(of height: CGFloat) -> some View {
        frame(maxHeight: height)
    }

    /// Card look used across the main screens: flat grouped-list style,
    /// continuous (squircle) corners, adaptive background.
    func apaCard() -> some View {
        padding(16)
            .background(ApaColor.card,
                        in: RoundedRectangle(cornerRadius: AppStyle.cardCorner, style: .continuous))
    }

    /// Filled primary button shape.
    func apaButtonBackground(_ enabled: Bool) -> some View {
        background(enabled ? ApaColor.blue : ApaColor.gray.opacity(0.45),
                   in: RoundedRectangle(cornerRadius: AppStyle.buttonCorner, style: .continuous))
    }
}

// MARK: - Task helpers

extension Task where Success == Never, Failure == Never {
    /// Task.Delay(ms).
    static func delay(milliseconds: Int) async throws {
        try await Task.sleep(nanoseconds: UInt64(milliseconds) * 1_000_000)
    }
}
