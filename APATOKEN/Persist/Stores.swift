import Foundation

// MARK: - SettingsManager

/// SettingsManager over `Preferences` (MAUI) mirrored with UserDefaults.
/// Keys and defaults match the C# implementation 1:1.
enum SettingsManager {
    private static let defaults = UserDefaults.standard

    static func setCommunicationPort(_ port: String) {
        defaults.set(port, forKey: "CommunicationPort")
    }

    static func getCommunicationPort() -> String {
        defaults.string(forKey: "CommunicationPort") ?? ""
    }

    /// SetBluetoothDevice(name, address).
    static func setBluetoothDevice(_ deviceName: String, _ deviceAddress: String) {
        defaults.set(deviceName, forKey: "DeviceName")
        defaults.set(deviceAddress, forKey: "DeviceAddress")
    }

    static func getBluetoothDeviceName() -> String {
        defaults.string(forKey: "DeviceName") ?? ""
    }

    static func getBluetoothDeviceAddress() -> String {
        defaults.string(forKey: "DeviceAddress") ?? ""
    }

    static func getLanguageName() -> String {
        defaults.string(forKey: "LanguageName") ?? "English"
    }

    static func getLanguageTag() -> String {
        defaults.string(forKey: "LanguageTag") ?? "en-US"
    }

    static func setLanguage(_ languageName: String, _ languageTag: String) {
        defaults.set(languageName, forKey: "LanguageName")
        defaults.set(languageTag, forKey: "LanguageTag")
    }

    static func getMeterBaudRate() -> Int {
        let value = defaults.integer(forKey: "MeterBaudRate")
        return value == 0 ? 19200 : value
    }
}

// MARK: - HistoryManager

/// HistoryManager (CSV-based) mirror. File name, separator, date format,
///解析 and conversion semantics are byte-exact with the C# class:
/// columns `meter;mac;date;code;total1;total2;value1;value2`,
/// date `dd.MM.yyyy HH:mm:ss`, meter = last 8 chars of the first field,
/// unparsable rows are skipped, newest first on read.
enum HistoryManager {
    private static let fileName = "history.csv"
    private static let separator = ";"
    private static let dateTimeFormat = "dd.MM.yyyy HH:mm:ss"

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = dateTimeFormat
        return formatter
    }()

    static func getFilePath() -> URL {
        let directory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return directory.appendingPathComponent(fileName)
    }

    /// Add(model): AppendAllText(line + Environment.NewLine).
    @discardableResult
    static func add(_ model: ChargeModel) -> Bool {
        do {
            let line = convertModelToString(model) + "\n"
            let path = getFilePath()
            if !FileManager.default.fileExists(atPath: path.path) {
                try Data().write(to: path)
            }
            let handle = try FileHandle(forWritingTo: path)
            defer { try? handle.close() }
            _ = try handle.seekToEnd()
            try handle.write(contentsOf: Data(line.utf8))
            return true
        } catch {
            return false
        }
    }

    /// ReadAll(): last line first.
    static func readAll() -> [ChargeModel] {
        let path = getFilePath()
        guard FileManager.default.fileExists(atPath: path.path) else {
            return []
        }
        var list: [ChargeModel] = []
        if let text = try? String(contentsOf: path, encoding: .utf8) {
            for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
                if let model = convertStringToModel(String(line)) {
                    list.append(model)
                }
            }
        }
        list.reverse()
        return list
    }

    private static func convertModelToString(_ model: ChargeModel) -> String {
        [model.meter, model.mac, dateTimeFormatter.string(from: model.date),
         model.code, model.total1, model.total2, model.value1, model.value2]
            .joined(separator: separator)
    }

    private static func convertStringToModel(_ row: String) -> ChargeModel? {
        // C# Split(";"): the Substring(len-8, 8) and the field indexers
        // throw on short rows/fields → catch → the row is skipped.
        let fields = row.split(separator: ";", omittingEmptySubsequences: false).map(String.init)
        guard fields.count >= 8, fields[0].count >= 8 else { return nil }
        let meter = String(fields[0].suffix(8))
        // TryParseExact(invariant "dd.MM.yyyy HH:mm:ss") failure → Now.
        let date = dateTimeFormatter.date(from: fields[2]) ?? Date()
        return ChargeModel(meter: meter, mac: fields[1], date: date, code: fields[3],
                           total1: fields[4], total2: fields[5],
                           value1: fields[6], value2: fields[7])
    }

}
