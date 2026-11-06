import SwiftUI
import CoreText

// MARK: - App entry point

@main
struct APATOKENApp: App {
    @StateObject private var app = AppState()
    init() {
        Self.registerFonts()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(app)
        }
    }

    /// The Open Sans fonts are registered at runtime (CTFontManager) —
    /// no UIAppFonts Info.plist is needed.
    private static func registerFonts() {
        for resourceName in ["OpenSans-Regular.ttf", "OpenSans-Semibold.ttf"] {
            guard let url = Bundle.main.url(forResource: resourceName,
                                            withExtension: nil) else {
                continue
            }
            var error: Unmanaged<CFError>?
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        }
    }
}
