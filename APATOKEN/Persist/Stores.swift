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
        defaults.string(forKey: "LanguageTag") ?? "en"
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
            try save(model)
            return true
        } catch {
            return false
        }
    }

    static func save(_ model: ChargeModel, at path: URL = getFilePath()) throws {
        try HistoryFile.append(convertModelToString(model), to: path)
    }

    /// ReadAll(): last line first.
    static func readAll(at path: URL = getFilePath()) -> [ChargeModel] {
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
        guard fields.count >= 8, !fields[0].isEmpty else { return nil }
        let meter = fields[0]
        // TryParseExact(invariant "dd.MM.yyyy HH:mm:ss") failure → Now.
        let date = dateTimeFormatter.date(from: fields[2]) ?? Date()
        return ChargeModel(meter: meter, mac: fields[1], date: date, code: fields[3],
                           total1: fields[4], total2: fields[5],
                           value1: fields[6], value2: fields[7])
    }

}

enum HistoryFile {
    static let changed = Notification.Name("HistoryFileChanged")
    private static let lock = NSLock()

    /// Atomic replacement keeps the previous history intact if saving fails.
    static func append(_ line: String, to path: URL) throws {
        lock.lock()
        defer { lock.unlock() }
        try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        var data = FileManager.default.fileExists(atPath: path.path) ? try Data(contentsOf: path) : Data()
        if !data.isEmpty && data.last != 10 { data.append(10) }
        data.append(Data((line + "\n").utf8))
        try data.write(to: path, options: .atomic)
        NotificationCenter.default.post(name: changed, object: nil)
    }
}
