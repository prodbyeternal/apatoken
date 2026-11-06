import Foundation

/// Model for a meter reading entry stored in history.
struct ReadingModel: Identifiable, Codable, Equatable {
    let id: UUID
    let meter: String
    let date: Date
    let zone1: String
    let zone2: String

    init(meter: String, date: Date, zone1: String, zone2: String) {
        self.id = UUID()
        self.meter = meter
        self.date = date
        self.zone1 = zone1
        self.zone2 = zone2
    }
}

// MARK: - Reading history manager (CSV-based)

enum ReadingHistoryManager {
    private static let fileName = "readings.csv"
    private static let separator = ";"

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd.MM.yyyy HH:mm:ss"
        return formatter
    }()

    static func getFilePath() -> URL {
        let directory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return directory.appendingPathComponent(fileName)
    }

    @discardableResult
    static func add(_ model: ReadingModel) -> Bool {
        do {
            try save(model)
            return true
        } catch {
            return false
        }
    }

    static func save(_ model: ReadingModel, at path: URL = getFilePath()) throws {
        try HistoryFile.append(convertModelToString(model), to: path)
    }

    static func readAll(at path: URL = getFilePath()) -> [ReadingModel] {
        guard FileManager.default.fileExists(atPath: path.path) else {
            return []
        }
        var list: [ReadingModel] = []
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

    private static func convertModelToString(_ model: ReadingModel) -> String {
        [model.meter, dateTimeFormatter.string(from: model.date),
         model.zone1, model.zone2]
            .joined(separator: separator)
    }

    private static func convertStringToModel(_ row: String) -> ReadingModel? {
        let fields = row.split(separator: ";", omittingEmptySubsequences: false).map(String.init)
        guard fields.count >= 4, !fields[0].isEmpty else { return nil }
        let meter = fields[0]
        let date = dateTimeFormatter.date(from: fields[1]) ?? Date()
        return ReadingModel(meter: meter, date: date, zone1: fields[2], zone2: fields[3])
    }
}
