import Foundation

enum EnergyText {
    static func number(_ stored: String) -> String {
        guard let value = Decimal(string: stored.replacingOccurrences(of: ",", with: "."), locale: Locale(identifier: "en_US_POSIX")) else { return stored }
        let formatter = NumberFormatter()
        formatter.locale = LocalizationManager.shared.locale
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? stored
    }

    static func kWh(_ stored: String) -> String { number(stored) + " kWh" }

    static func date(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(LocalizationManager.shared.locale))
    }
}
