import Foundation

/// ChargeModel (APAToken.Models).
final class ChargeModel: Equatable, Hashable, Identifiable {
    let id = UUID()
    var meter: String
    var mac: String
    var date: Date
    var code: String
    var value1: String
    var value2: String
    var total1: String
    var total2: String

    init(meter: String, mac: String, date: Date, code: String,
         total1: String, total2: String, value1: String, value2: String) {
        self.meter = meter
        self.mac = mac
        self.date = date
        self.code = code
        self.total1 = total1
        self.total2 = total2
        self.value1 = value1
        self.value2 = value2
    }

    /// ChargeModel(meter, mac, code, total1, total2, value1, value2)
    /// with Date = Now.
    convenience init(meter: String, mac: String, code: String,
                     total1: String, total2: String, value1: String, value2: String) {
        self.init(meter: meter, mac: mac, date: Date(), code: code,
                  total1: total1, total2: total2, value1: value1, value2: value2)
    }

    static func == (lhs: ChargeModel, rhs: ChargeModel) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Converters

enum ChargeConverter {
    static let unknownDevice = "-----"

    /// DateTimeToStringConverter: "dd.MM.yyyy HH:mm".
    private static let detailsDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        return formatter
    }()

    static func dateText(_ model: ChargeModel?) -> String {
        guard let model else { return "" }
        return detailsDateFormatter.string(from: model.date)
    }

    /// CodeConverter: first 4 digits + stars for the middle (whitespace
    /// positions preserved) + last 4 digits.
    static func codeMask(_ code: String?) -> String {
        guard let code, !code.isEmpty, code.count >= 8 else {
            return "**** **** **** **** ****"
        }
        var result = String(code.prefix(4))
        let middle = String(code.dropFirst(4).dropLast(4))
        for char in middle {
            result.append(char.isWhitespace ? char : "*")
        }
        result += String(code.suffix(4))
        return result
    }

    /// ChargeModelToChargingTypeConverter.
    static func chargingType(_ model: ChargeModel?) -> String {
        guard let model else { return "x" }
        let zero1 = isZero(model.value1)
        let zero2 = isZero(model.value2)
        if zero1 || zero2 {
            return L.ui.txtSingleCharging // Single-zone charging
        }
        return L.ui.txtDualCharging // Dual-zone charging
    }

    /// ChargeModelToChargingValuesConverter.
    static func chargingValues(_ model: ChargeModel?) -> String {
        guard let model else { return "0 kWh" }
        let zero1 = isZero(model.value1)
        let zero2 = isZero(model.value2)
        if !zero1 && !zero2 {
            return "\(model.value1) kWh\n\(model.value2) kWh"
        }
        if zero1 {
            return "\(model.value2) kWh"
        }
        return "\(model.value1) kWh"
    }

    /// IsZero({"0", "0,0", "0.0"}).
    private static func isZero(_ value: String) -> Bool {
        value == "0" || value == "0,0" || value == "0.0"
    }
}
