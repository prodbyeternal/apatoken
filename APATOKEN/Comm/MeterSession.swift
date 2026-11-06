import Foundation
import Combine

protocol MeterTransport {
    func recharge(token: String, address: String) async throws -> MeterCommunication.TokenTransactionResult
    func read(address: String) async throws -> [Decimal]
}

struct LiveMeterTransport: MeterTransport {
    func recharge(token: String, address: String) async throws -> MeterCommunication.TokenTransactionResult {
        try await MeterCommunication.beginTokenTransaction(token: token, deviceAddress: address, baudRate: SettingsManager.getMeterBaudRate())
    }
    func read(address: String) async throws -> [Decimal] {
        try await MeterCommunication.beginReadingTransaction(deviceAddress: address, baudRate: SettingsManager.getMeterBaudRate())
    }
}

struct RechargeReceipt {
    let charge: ChargeModel
    let warning: AppFailure?
}

enum RechargePresentation {
    case working(String)
    case success(RechargeReceipt)
    case failure(Error)

    var phase: Int {
        switch self { case .working: return 0; case .success: return 1; case .failure: return 2 }
    }
}

@MainActor
final class MeterSession: ObservableObject {
    static let shared = MeterSession()
    @Published private(set) var testing: Bool
    @Published private(set) var busy = false
    @Published private(set) var revision = 0
    @Published var rechargePresentation: RechargePresentation?
    private let defaults: UserDefaults
    private let transport: MeterTransport
    private let directory: URL
    private var simulation: SimulatedEnvironment?
    @Published private var liveCharges: [ChargeModel] = []
    @Published private var liveReadings: [ReadingModel] = []

    init(defaults: UserDefaults = .standard, directory: URL = HistoryManager.getFilePath().deletingLastPathComponent(), transport: MeterTransport = LiveMeterTransport()) {
        self.defaults = defaults
        self.directory = directory
        self.transport = transport
        testing = defaults.bool(forKey: "TestingMode")
        // A corrupt test file must never silently turn test mode into live mode.
        simulation = try? SimulatedEnvironment(url: directory.appendingPathComponent("testing/environment.json"))
        reloadLiveHistory()
        retryPendingHistory()
    }

    var testState: SimulatedEnvironment.State? { simulation?.state }
    var meterID: String { testing ? testState?.selectedID ?? "" : defaults.string(forKey: "DeviceAddress") ?? "" }
    var meterName: String {
        testing ? testState?.meters.first { $0.id == meterID }?.number ?? "" : defaults.string(forKey: "DeviceName") ?? ""
    }
    var hasMeter: Bool { !meterID.isEmpty }
    var contextID: String { "\(testing)-\(meterID)" }

    func setTesting(_ enabled: Bool) throws {
        guard !busy else { throw AppFailure.busy }
        if enabled && simulation == nil { throw AppFailure.storage }
        testing = enabled
        defaults.set(enabled, forKey: "TestingMode")
        revision += 1
    }

    func select(name: String, id: String) throws {
        guard !busy else { throw AppFailure.busy }
        if testing {
            try requireSimulation().select(id)
        } else {
            guard UUID(uuidString: id) != nil else { throw AppFailure.noMeter }
            defaults.set(name, forKey: "DeviceName")
            defaults.set(id, forKey: "DeviceAddress")
        }
        revision += 1
    }

    func generate(zone: Int) throws -> TestToken {
        guard !busy else { throw AppFailure.busy }
        let token = try requireSimulation().generateToken(zone: zone)
        revision += 1
        return token
    }

    func setOnline(_ online: Bool) throws {
        guard !busy else { throw AppFailure.busy }
        try requireSimulation().setOnline(online)
        revision += 1
    }

    func consume() throws {
        guard !busy else { throw AppFailure.busy }
        try requireSimulation().consumeEnergy()
        revision += 1
    }

    func resetTesting() throws {
        guard !busy else { throw AppFailure.busy }
        try requireSimulation().reset()
        revision += 1
    }

    private func requireSimulation() throws -> SimulatedEnvironment {
        guard testing, let simulation else { throw AppFailure.storage }
        return simulation
    }

    func recharge(_ token: String) async throws -> RechargeReceipt {
        guard !busy else { throw AppFailure.busy }
        guard hasMeter else { throw AppFailure.noMeter }
        guard TokenInput.isValid(token) else { throw AppFailure.invalidToken }
        let id = meterID
        let name = meterName
        busy = true
        defer { busy = false }
        if testing {
            let charge = try requireSimulation().redeem(token, meterID: id)
            revision += 1
            return RechargeReceipt(charge: charge, warning: nil)
        }
        guard simulation?.state.tokens.contains(where: { $0.code == token }) != true else { throw AppFailure.invalidToken }
        let result = try await transport.recharge(token: token, address: id)
        let descriptor = TokenDescriptor(dataValue: result.deliveryStatus.dataValue)
        guard result.deliveryStatus.statusCode == .tokenExecutionResultOk else {
            if result.deliveryStatus.statusCodeValue < 3 || result.deliveryStatus.statusCode == .tokenReceivedAndNotYetProcessed { throw AppFailure.pending }
            if descriptor.codeStatus == .okUsed { throw AppFailure.usedToken }
            if descriptor.codeStatus != .none && descriptor.codeStatus != .ok {
                throw CommsError(descriptor.getCodeStatusDescription())
            }
            throw AppFailure.rejected
        }
        if descriptor.codeStatus != .ok && descriptor.codeStatus != .none {
            throw CommsError(descriptor.getCodeStatusDescription())
        }
        let amounts = descriptor.energyByZone
        let charge = ChargeModel(meter: name, mac: id, code: token,
                                 total1: result.credits.indices.contains(0) ? DoubleFormatter.invariantF1(result.credits[0]) : "—",
                                 total2: result.credits.indices.contains(1) ? DoubleFormatter.invariantF1(result.credits[1]) : "—",
                                 value1: amounts.map { DoubleFormatter.invariantF1($0.0) } ?? "—",
                                 value2: amounts.map { DoubleFormatter.invariantF1($0.1) } ?? "—")
        var warning: AppFailure? = result.credits.count < 2 ? .creditAfterRecharge : nil
        // Queue accepted recharges before writing CSV; retry on the next operation or launch.
        var pending = pendingHistory
        pending.append(charge)
        defaults.set(try JSONEncoder().encode(pending), forKey: "PendingRechargeHistory")
        if !retryPendingHistory() { warning = .historyAfterRecharge }
        revision += 1
        return RechargeReceipt(charge: charge, warning: warning)
    }

    func read() async throws -> (ReadingModel, AppFailure?) {
        guard !busy else { throw AppFailure.busy }
        guard hasMeter else { throw AppFailure.noMeter }
        let id = meterID
        let name = meterName
        busy = true
        defer { busy = false }
        if testing {
            let reading = try requireSimulation().read(meterID: id)
            revision += 1
            return (reading, nil)
        }
        let values = try await transport.read(address: id)
        guard values.count == 2 else { throw CommsError(L.message.msgMissingCreditInfo) }
        let reading = ReadingModel(meter: name, date: Date(), zone1: DoubleFormatter.invariantF1(values[0]), zone2: DoubleFormatter.invariantF1(values[1]))
        var warning: AppFailure?
        do { try ReadingHistoryManager.save(reading, at: directory.appendingPathComponent("readings.csv")) }
        catch { warning = .historyAfterReading }
        reloadLiveHistory()
        revision += 1
        return (reading, warning)
    }

    var charges: [ChargeModel] {
        testing ? testState?.charges ?? [] : liveCharges
    }
    var readings: [ReadingModel] {
        testing ? testState?.readings ?? [] : liveReadings
    }

    private func reloadLiveHistory() {
        let saved = HistoryManager.readAll(at: directory.appendingPathComponent("history.csv"))
        let queued = pendingHistory.filter { pending in !saved.contains { $0.mac == pending.mac && $0.code == pending.code } }
        liveCharges = (saved + queued).sorted { $0.date > $1.date }
        liveReadings = ReadingHistoryManager.readAll(at: directory.appendingPathComponent("readings.csv"))
    }

    private var pendingHistory: [ChargeModel] {
        defaults.data(forKey: "PendingRechargeHistory").flatMap { try? JSONDecoder().decode([ChargeModel].self, from: $0) } ?? []
    }

    @discardableResult
    func retryPendingHistory() -> Bool {
        let path = directory.appendingPathComponent("history.csv")
        let pending = pendingHistory
        guard !pending.isEmpty else { return true }
        defer { reloadLiveHistory() }
        do {
            for charge in pending {
                if !HistoryManager.readAll(at: path).contains(where: { $0.mac == charge.mac && $0.code == charge.code }) {
                    try HistoryManager.save(charge, at: path)
                }
            }
            defaults.removeObject(forKey: "PendingRechargeHistory")
            return true
        } catch { return false }
    }
}

enum ErrorText {
    static func message(_ error: Error) -> String {
        if let error = error as? CommsError { return error.chainMessage }
        if let error = error as? AppFailure { return error.errorDescription ?? L.message.msgUnknownError }
        return L.message.msgUnknownError
    }
}
