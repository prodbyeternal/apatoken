import Foundation
import Observation
import SwiftUI

/// Observation tracks L's lookups in every SwiftUI body, including sheets and tabs.
/// Read the actual strings plist: Xcode may compile it as binary or UTF-16.
@Observable
final class LocalizationManager {
    static let shared = LocalizationManager()
    static let languages = [(name: "English", tag: "en"), (name: "Polski", tag: "pl"), (name: "Français", tag: "fr")]

    var currentLanguage: String {
        didSet {
            defaults.set(currentLanguage, forKey: "LanguageTag")
            defaults.set(languageName, forKey: "LanguageName")
        }
    }

    private let defaults: UserDefaults
    private let tables: [String: [String: String]]

    init(bundle: Bundle = .main, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.string(forKey: "LanguageTag") ?? "en"
        currentLanguage = Self.languages.contains { $0.tag == saved } ? saved : "en"
        tables = Dictionary(uniqueKeysWithValues: Self.languages.map { language in
            let url = bundle.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: language.tag)
            let table = url.flatMap { try? Data(contentsOf: $0) }.flatMap {
                try? PropertyListSerialization.propertyList(from: $0, options: [], format: nil) as? [String: String]
            } ?? [:]
            return (language.tag, table)
        })
    }

    var locale: Locale { Locale(identifier: currentLanguage) }
    var languageName: String { Self.languages.first { $0.tag == currentLanguage }?.name ?? "English" }

    func localizedString(forKey key: String, comment: String = "") -> String {
        for tag in [currentLanguage, "en"] {
            if let value = tables[tag]?[key], !value.isEmpty, value != key || !key.hasPrefix("txt") && !key.hasPrefix("msg") {
                return value
            }
        }
        // Packaging checks reject missing keys. Never expose an internal identifier in UI.
        return tables[currentLanguage]?["msgUnknownError"] ?? tables["en"]?["msgUnknownError"] ?? "An error occurred."
    }
}

extension View {
    func dynamicLocalization() -> some View {
        environment(\.locale, LocalizationManager.shared.locale)
    }
}
