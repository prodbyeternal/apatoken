import Foundation

enum AppFailure: Error, LocalizedError, Equatable {
    case invalidToken, usedToken, wrongMeter, noMeter, busy, offline, storage, historyAfterRecharge, historyAfterReading, creditAfterRecharge, pending, rejected

    var errorDescription: String? {
        switch self {
        case .invalidToken: return L.message.msgEnteredTokenIsWrong
        case .usedToken: return L.message.msgEnteredTokenAlreadyUsed
        case .wrongMeter: return L.text("msgTestWrongMeter")
        case .noMeter: return L.ui.txtNoMeterSelected
        case .busy: return L.text("msgOperationBusy")
        case .offline: return L.text("msgTestMeterOffline")
        case .storage: return L.text("msgStorageFailed")
        case .historyAfterRecharge: return L.text("msgHistoryAfterRecharge")
        case .historyAfterReading: return L.text("msgHistoryAfterReading")
        case .creditAfterRecharge: return L.text("msgCreditAfterRecharge")
        case .pending: return L.text("msgTokenPending")
        case .rejected: return L.message.msgTokenEnteredButNotAccepted
        }
    }
}

enum TokenInput {
    static func normalize(_ text: String) -> String {
        String(text.filter { $0 >= "0" && $0 <= "9" }.prefix(20))
    }

    static func isValid(_ text: String) -> Bool {
        text.count == 20 && text.allSatisfy { $0 >= "0" && $0 <= "9" }
    }
}

struct SimulatedMeter: Codable, Identifiable {
    let id: String
    let number: String
    var zone1: Int // tenths of kWh: no floating point rounding
    var zone2: Int
    var online = true
}

struct TestToken: Codable, Identifiable {
    var id: String { code }
    let code: String
    let meterID: String
    let zone1: Int
    let zone2: Int
    let created: Date
    var redeemed: Date?
}

/// A single atomic file commits consumption, balances, token redemption and history together.
/// Invalid, reused and other-meter tokens cannot change any of those values.
final class SimulatedEnvironment {
    struct State: Codable {
        var meters: [SimulatedMeter] = [
            .init(id: "test-meter-1", number: "90000001", zone1: 1250, zone2: 500),
            .init(id: "test-meter-2", number: "90000002", zone1: 0, zone2: 0),
            .init(id: "test-meter-3", number: "90000003", zone1: 800, zone2: 1600)
        ]
        var selectedID = "test-meter-1"
        var tokens: [TestToken] = []
        var charges: [ChargeModel] = []
        var readings: [ReadingModel] = []
    }

    private(set) var state: State
    private let url: URL

    init(url: URL) throws {
        self.url = url
        if FileManager.default.fileExists(atPath: url.path) {
            state = try JSONDecoder().decode(State.self, from: Data(contentsOf: url))
        } else {
            state = State()
        }
    }

    private func commit(_ next: State) throws {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(next).write(to: url, options: .atomic)
            state = next
        } catch { throw AppFailure.storage }
    }

    func select(_ id: String) throws {
        guard state.meters.contains(where: { $0.id == id }) else { throw AppFailure.noMeter }
        var next = state
        next.selectedID = id
        try commit(next)
    }

    func generateToken(zone: Int) throws -> TestToken {
        guard (0...2).contains(zone), state.meters.contains(where: { $0.id == state.selectedID }) else { throw AppFailure.noMeter }
        var code: String
        repeat {
            code = (0..<20).map { _ in String(Int.random(in: 0...9)) }.joined()
        } while state.tokens.contains { $0.code == code }
        let token = TestToken(code: code, meterID: state.selectedID,
                              zone1: zone == 2 ? 0 : Int.random(in: 10...2500),
                              zone2: zone == 1 ? 0 : Int.random(in: 10...2500), created: Date())
        var next = state
        next.tokens.insert(token, at: 0)
        try commit(next)
        return token
    }

    func redeem(_ code: String, meterID: String) throws -> ChargeModel {
        guard TokenInput.isValid(code), let tokenIndex = state.tokens.firstIndex(where: { $0.code == code }) else { throw AppFailure.invalidToken }
        let token = state.tokens[tokenIndex]
        guard token.meterID == meterID else { throw AppFailure.wrongMeter }
        guard token.redeemed == nil else { throw AppFailure.usedToken }
        guard let index = state.meters.firstIndex(where: { $0.id == meterID }) else { throw AppFailure.noMeter }
        guard state.meters[index].online else { throw AppFailure.offline }
        var next = state
        next.meters[index].zone1 += token.zone1
        next.meters[index].zone2 += token.zone2
        next.tokens[tokenIndex].redeemed = Date()
        let meter = next.meters[index]
        let charge = ChargeModel(meter: meter.number, mac: meter.id, code: code,
                                 total1: Self.energy(meter.zone1), total2: Self.energy(meter.zone2),
                                 value1: Self.energy(token.zone1), value2: Self.energy(token.zone2))
        next.charges.insert(charge, at: 0)
        try commit(next)
        return charge
    }

    func read(meterID: String) throws -> ReadingModel {
        guard let meter = state.meters.first(where: { $0.id == meterID }) else { throw AppFailure.noMeter }
        guard meter.online else { throw AppFailure.offline }
        let reading = ReadingModel(meter: meter.number, date: Date(), zone1: Self.energy(meter.zone1), zone2: Self.energy(meter.zone2))
        var next = state
        next.readings.insert(reading, at: 0)
        try commit(next)
        return reading
    }

    func setOnline(_ online: Bool) throws {
        guard let index = state.meters.firstIndex(where: { $0.id == state.selectedID }) else { throw AppFailure.noMeter }
        var next = state
        next.meters[index].online = online
        try commit(next)
    }

    func consumeEnergy() throws {
        guard let index = state.meters.firstIndex(where: { $0.id == state.selectedID }) else { throw AppFailure.noMeter }
        guard state.meters[index].online else { throw AppFailure.offline }
        var next = state
        next.meters[index].zone1 = max(0, next.meters[index].zone1 - Int.random(in: 10...100))
        next.meters[index].zone2 = max(0, next.meters[index].zone2 - Int.random(in: 10...100))
        try commit(next)
    }

    func reset() throws { try commit(State()) }

    static func energy(_ tenths: Int) -> String {
        DoubleFormatter.invariantF1(Decimal(tenths) / 10)
    }
}
