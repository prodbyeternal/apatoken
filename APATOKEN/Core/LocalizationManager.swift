import Foundation
import Combine
import SwiftUI

/// Dynamic localization that responds to language changes without app restart.
/// Since `NSLocalizedString` caches the bundle, we manually load the correct
/// `.lproj` bundle based on the current language setting.
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    /// Published so views refresh when language changes.
    @Published var currentLanguage: String = SettingsManager.getLanguageTag() {
        didSet {
            SettingsManager.setLanguage(languageName(for: currentLanguage), currentLanguage)
            NotificationCenter.default.post(name: .languageChanged, object: nil)
        }
    }

    private init() {
        NotificationCenter.default.addObserver(
            forName: NSLocale.currentLocaleDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.currentLanguage = self?.currentLanguage ?? "en"
        }
    }

    private func languageName(for tag: String) -> String {
        let names = ["en": "English", "pl": "Polski", "fr": "Français"]
        return names[tag] ?? "English"
    }

    /// Load a localized string, falling back to Base/en if the key is missing.
    func localizedString(forKey key: String, comment: String = "") -> String {
        let tag = currentLanguage
        let fullName = (Bundle.main.path(forResource: tag, ofType: "lproj") as String?)
            ?? Bundle.main.path(forResource: "Base", ofType: "lproj")

        if let path = fullName {
            let stringsDict = parseStringsFile(at: path)
            if let value = stringsDict[key] {
                return value
            }
        }

        // Fallback to Base
        if let basePath = Bundle.main.path(forResource: "Base", ofType: "lproj") {
            let stringsDict = parseStringsFile(at: basePath)
            return stringsDict[key] ?? key
        }

        return NSLocalizedString(key, comment: comment)
    }

    private func parseStringsFile(at path: String) -> [String: String] {
        var result: [String: String] = [:]
        guard let content = try? String(contentsOfFile: path) else { return result }
        
        let pattern = #"(?<!\\)"([^"]*)"\s*=\s*"((?:[^"\\]|\\.)*)"#
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        
        regex?.enumerateMatches(in: content, range: NSRange(content.startIndex..., in: content)) { match, _, _ in
            if let match {
                if let keyRange = Range(match.range(at: 1), in: content),
                   let valueRange = Range(match.range(at: 2), in: content) {
                    let key = String(content[keyRange])
                    let value = String(content[valueRange])
                    result[key] = value
                }
            }
        }
        return result
    }
}

extension Notification.Name {
    static let languageChanged = Notification.Name("LocalizationManagerLanguageChanged")
}

/// A view modifier that forces views to re-evaluate their localized text.
struct DynamicLocalizationModifier: ViewModifier {
    @ObservedObject private var loc = LocalizationManager.shared

    func body(content: Content) -> some View {
        content
            .id(loc.currentLanguage)
    }
}

extension View {
    func dynamicLocalization() -> some View {
        modifier(DynamicLocalizationModifier())
    }
}
