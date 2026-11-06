import XCTest
import Observation
@testable import iAPATOKEN

final class FakeTransport: MeterTransport {
    var calls = 0
    var status: UInt8 = 3
    var data: [UInt8] = [1, 0x20, 0, 0, 0, 123, 0, 0, 0, 45]
    var credits: [Decimal] = [100, 200]
    var failure: Error?
    func recharge(token: String, address: String) async throws -> MeterCommunication.TokenTransactionResult {
        calls += 1
        if let failure { throw failure }
        return .init(deliveryStatus: .init(statusCodeValue: status, dataValue: data), credits: credits)
    }
    func read(address: String) async throws -> [Decimal] {
        calls += 1
        if let failure { throw failure }
        return credits
    }
}

@MainActor
final class APATOKENTests: XCTestCase {
    private var directory: URL!
    private var defaults: UserDefaults!
    private var suite: String!

    override func setUp() async throws {
        suite = "APATOKENTests." + UUID().uuidString
        defaults = UserDefaults(suiteName: suite)!
        directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent(suite)
        defaults.set("123", forKey: "DeviceName")
        defaults.set("00000000-0000-0000-0000-000000000001", forKey: "DeviceAddress")
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suite)
        if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
    }

    func testRealRechargeAndReadingAreSavedAndReloaded() async throws {
        let transport = FakeTransport()
        let session = MeterSession(defaults: defaults, directory: directory, transport: transport)
        let receipt = try await session.recharge("12345678901234567890")
        XCTAssertNil(receipt.warning)
        XCTAssertEqual(receipt.charge.value1, "12.3")
        XCTAssertEqual(receipt.charge.value2, "4.5")
        _ = try await session.read()
        let reloaded = MeterSession(defaults: defaults, directory: directory, transport: transport)
        XCTAssertEqual(reloaded.charges.count, 1)
        XCTAssertEqual(reloaded.charges.first?.meter, "123", "Short meter names must not disappear")
        XCTAssertEqual(reloaded.charges.first?.code, "12345678901234567890")
        XCTAssertEqual(reloaded.readings.count, 1)
        XCTAssertEqual(reloaded.readings.first?.zone2, "200.0")
        XCTAssertEqual(transport.calls, 2)
    }

    func testAcceptedTokenWithMissingBalanceStillSavesHistory() async throws {
        let transport = FakeTransport()
        transport.credits = []
        let session = MeterSession(defaults: defaults, directory: directory, transport: transport)
        let receipt = try await session.recharge("12345678901234567890")
        XCTAssertNotNil(receipt.warning)
        XCTAssertEqual(session.charges.count, 1)
        XCTAssertEqual(session.charges[0].total1, "—")
    }

    func testRejectedAndPendingResponsesNeverBecomeSuccessOrHistory() async throws {
        let transport = FakeTransport()
        let session = MeterSession(defaults: defaults, directory: directory, transport: transport)
        for status: UInt8 in [0, 1, 2, 4, 5, 6, 7, 8] {
            transport.status = status
            do { _ = try await session.recharge("12345678901234567890"); XCTFail("Accepted status \(status)") }
            catch { XCTAssertTrue(error is AppFailure) }
        }
        XCTAssertTrue(session.charges.isEmpty)
        XCTAssertFalse(session.busy)
    }

    func testTestingModeIsIsolatedPersistentAndRejectsInvalidTokens() async throws {
        let transport = FakeTransport()
        let session = MeterSession(defaults: defaults, directory: directory, transport: transport)
        try session.setTesting(true)
        let firstID = session.meterID
        let before = session.testState!.meters[0].zone1
        do { _ = try await session.recharge("11111111111111111111"); XCTFail("Ungenerated token accepted") }
        catch { XCTAssertEqual(error as? AppFailure, .invalidToken) }
        XCTAssertTrue(session.charges.isEmpty)
        XCTAssertEqual(session.testState!.meters[0].zone1, before)
        let generated = try session.generate(zone: 1)
        XCTAssertTrue(TokenInput.isValid(generated.code))
        XCTAssertTrue((10...2500).contains(generated.zone1))
        try session.select(name: "", id: "test-meter-2")
        do { _ = try await session.recharge(generated.code); XCTFail("Other-meter token accepted") }
        catch { XCTAssertEqual(error as? AppFailure, .wrongMeter) }
        try session.select(name: "", id: firstID)
        try session.setOnline(false)
        do { _ = try await session.recharge(generated.code); XCTFail("Offline meter accepted token") }
        catch { XCTAssertEqual(error as? AppFailure, .offline) }
        try session.setOnline(true)
        let receipt = try await session.recharge(generated.code)
        XCTAssertEqual(receipt.charge.value1, SimulatedEnvironment.energy(generated.zone1))
        XCTAssertEqual(session.testState!.meters[0].zone1, before + generated.zone1)
        _ = try await session.read()
        let reloaded = MeterSession(defaults: defaults, directory: directory, transport: transport)
        XCTAssertTrue(reloaded.testing)
        XCTAssertEqual(reloaded.charges.count, 1)
        XCTAssertEqual(reloaded.readings.count, 1)
        do { _ = try await reloaded.recharge(generated.code); XCTFail("Used token accepted after relaunch") }
        catch { XCTAssertEqual(error as? AppFailure, .usedToken) }
        try reloaded.setTesting(false)
        XCTAssertEqual(reloaded.meterName, "123")
        XCTAssertTrue(reloaded.charges.isEmpty)
        XCTAssertTrue(reloaded.readings.isEmpty)
        do { _ = try await reloaded.recharge(generated.code); XCTFail("Test token sent to real transport") }
        catch { XCTAssertEqual(error as? AppFailure, .invalidToken) }
        XCTAssertEqual(transport.calls, 0, "Testing must never invoke a real transport")
    }

    func testTestResetAndUsageDoNotAffectRealHistory() async throws {
        let session = MeterSession(defaults: defaults, directory: directory, transport: FakeTransport())
        _ = try await session.recharge("12345678901234567890")
        try session.setTesting(true)
        for zone in [0, 1, 2] {
            let token = try session.generate(zone: zone)
            _ = try await session.recharge(token.code)
        }
        try session.consume()
        _ = try await session.read()
        XCTAssertEqual(session.charges.count, 3)
        try session.resetTesting()
        XCTAssertTrue(session.charges.isEmpty)
        XCTAssertTrue(session.readings.isEmpty)
        XCTAssertTrue(session.testState!.tokens.isEmpty)
        try session.setTesting(false)
        XCTAssertEqual(session.charges.count, 1)
    }

    func testFailedAtomicSaveDoesNotRedeemOrChangeBalance() throws {
        let simulation = try SimulatedEnvironment(url: directory.appendingPathComponent("environment.json"))
        let token = try simulation.generateToken(zone: 0)
        let before = simulation.state.meters[0].zone1
        try FileManager.default.removeItem(at: directory)
        try Data("blocker".utf8).write(to: directory)
        XCTAssertThrowsError(try simulation.redeem(token.code, meterID: token.meterID))
        XCTAssertNil(simulation.state.tokens[0].redeemed)
        XCTAssertEqual(simulation.state.meters[0].zone1, before)
        XCTAssertTrue(simulation.state.charges.isEmpty)
    }

    func testHistoryFailureQueuesAcceptedTokenForRetry() async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let path = directory.appendingPathComponent("history.csv")
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        let session = MeterSession(defaults: defaults, directory: directory, transport: FakeTransport())
        let result = try await session.recharge("12345678901234567890")
        XCTAssertEqual(result.warning, .historyAfterRecharge)
        XCTAssertNotNil(defaults.data(forKey: "PendingRechargeHistory"))
        try FileManager.default.removeItem(at: path)
        let reloaded = MeterSession(defaults: defaults, directory: directory, transport: FakeTransport())
        XCTAssertEqual(reloaded.charges.count, 1)
        XCTAssertNil(defaults.data(forKey: "PendingRechargeHistory"))
        XCTAssertTrue(reloaded.retryPendingHistory())
        XCTAssertEqual(reloaded.charges.count, 1)
    }

    func testCompiledLocalizationsSwitchWithoutRestartOrRawKeys() throws {
        let bundle = Bundle(for: APATOKENAppBundleMarker.self)
        let loc = LocalizationManager(bundle: bundle, defaults: defaults)
        let examples = [("en", "Recharge", "Language"), ("pl", "Doładowanie", "Język"), ("fr", "Recharge", "Langue")]
        for (tag, recharge, language) in examples {
            loc.currentLanguage = tag
            XCTAssertEqual(loc.localizedString(forKey: "txtRecharge"), recharge)
            XCTAssertEqual(loc.localizedString(forKey: "txtLanguage"), language)
            let url = try XCTUnwrap(bundle.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: tag))
            let table = try XCTUnwrap(PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: String])
            for (key, value) in table {
                XCTAssertEqual(loc.localizedString(forKey: key), value, "\(tag): \(key)")
                XCTAssertFalse(value.hasPrefix("txt") || value.hasPrefix("msg"), "Raw key in \(tag)")
            }
        }
        XCTAssertEqual(LocalizationManager(bundle: bundle, defaults: defaults).currentLanguage, "fr")
        XCTAssertFalse(loc.localizedString(forKey: "txtMissingRegressionKey").contains("txtMissing"))
        var changed = false
        withObservationTracking { _ = loc.localizedString(forKey: "txtRecharge") } onChange: { changed = true }
        loc.currentLanguage = "pl"
        XCTAssertTrue(changed)
    }

    func testTokenInputAndEnumParsing() throws {
        XCTAssertEqual(TokenInput.normalize("12 34-567890123456789012345"), "12345678901234567890")
        XCTAssertFalse(TokenInput.isValid(String(repeating: "١", count: 20)))
        XCTAssertFalse(TokenInput.isValid("123"))
        let response = try TokenDeliveryStatus(responseData: ByteBuffer([2, 2, 22, 3, 4, 80, 1, 0x20, 0, 0, 0, 123, 0, 0, 0, 45]))
        XCTAssertEqual(response.statusCode, .tokenExecutionResultOk)
        XCTAssertEqual(response.dataValue.count, 10)
        XCTAssertEqual(TokenDescriptor(dataValue: response.dataValue).energyByZone?.0, Decimal(string: "12.3"))
    }
}
