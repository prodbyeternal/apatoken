import Foundation
import CoreBluetooth

/// CoreBluetooth-backed communication port implementing the semantics
/// of `PluginSerialPortGattClient` + `BluetoothCommunicationPortPluginSpc`:
/// SPS service 194247d0-…, RX/TX notification pipe, serial-parameter
/// characteristic writes, 3-byte-first read protocol, 8 s read timeout,
/// 15 s connect timeout, cancel + 8 s disconnect (+1.5 s).
final class DspsBlePort: NSObject {
    // BLE identifiers (PluginSerialPortGattClient constants)
    static let spsServerServiceUuid = "194247d0-7cbc-11e9-089e-2a86e4085a59"
    static let spsServerTxUuid = "07005991-b131-3396-014c-664c9867b918"
    static let spsServerRxUuid = "07005991-b131-3396-014c-664c9867b913"
    static let spsBaudRateUuid = "07005991-b131-3396-014c-664c9867b912"
    static let spsStopBitsUuid = "07005991-b131-3396-014c-664c9867b911"
    static let spsParityUuid = "07005991-b131-3396-014c-664c9867b910"
    static let spsDataBitsUuid = "07005991-b131-3396-014c-664c9867b909"

    enum SerialParams {
        static let dataBits: UInt8 = 8
        static let parity: UInt8 = 0
        static let stopBits: UInt8 = 1
    }

    enum State {
        case off
        case on
        case disconnected
    }

    static let connectTimeoutMs = 15_000
    static let characteristicConfigTimeoutMs = 10_000
    static let serialParamWriteTimeoutMs = 1_000

    /// Client Characteristic Configuration descriptor — compared as a
    /// CBUUID object because CoreBluetooth collapses the SDO base UUID
    /// to the short form ("2902") in uuidString on iOS.
    static let cccdUuid = CBUUID(string: "2902")
    static let configSettleSleepMs = 500
    static let byteSentTimeoutMs = 2_000
    static let disconnectTimeoutMs = 8_000
    static let disconnectSettleSleepMs = 1_500
    static let defaultReadTimeoutMs = 8_000
    static let readPollIntervalMs = 100

    /// Blocking operations run on this queue; CB callbacks arrive on
    /// the separate `cbQueue`.
    private let workQueue = DispatchQueue(label: "DspsBlePort.work", qos: .userInitiated)
    private let cbQueue = DispatchQueue(label: "DspsBlePort.cb", qos: .userInitiated)
    private var central: CBCentralManager?

    private var peripheral: CBPeripheral?
    private var addressString = ""

    private var rxCharacteristic: CBCharacteristic?
    private var txCharacteristic: CBCharacteristic?
    private var baudRateCharacteristic: CBCharacteristic?
    private var parityCharacteristic: CBCharacteristic?
    private var dataBitsCharacteristic: CBCharacteristic?
    private var stopBitsCharacteristic: CBCharacteristic?

    private(set) var connectionState: State = .off

    private var baudRate = 19_200
    private var readTimeoutMs = DspsBlePort.defaultReadTimeoutMs

    private var rxQueue: [UInt8] = []
    private let queueLock = NSLock()

    // Auto-reset events (mirrors AutoResetEvent)
    private var deviceConnectedEvent = DispatchSemaphore(value: 0)
    private var rxConfiguredEvent = DispatchSemaphore(value: 0)
    private var txConfiguredEvent = DispatchSemaphore(value: 0)
    private var baudRateConfiguredEvent = DispatchSemaphore(value: 0)
    private var parityConfiguredEvent = DispatchSemaphore(value: 0)
    private var dataBitsConfiguredEvent = DispatchSemaphore(value: 0)
    private var stopBitsConfiguredEvent = DispatchSemaphore(value: 0)
    private var byteSentEvent = DispatchSemaphore(value: 0)
    private var byteReceivedEvent = DispatchSemaphore(value: 0)
    private var peripheralDisconnectedEvent = DispatchSemaphore(value: 0)

    private var notificationsSubscribed = false
    private var writeErrorMessage = ""
    private var expectDisconnectEvent = false

    private var scanTarget: UUID?
    private var scanFound: CBPeripheral?
    private var scanFoundEvent = DispatchSemaphore(value: 0)

    var isReady: Bool {
        connectionState == .on
    }

    /// BluetoothCommunicationPortParameters entering
    /// (DeviceMacAddress stored as CBPeripheral UUID string on iOS,
    /// BaudRate, ReadTimeout, ReadIntervalTimeout, MtuSize).
    init(address: String, meterBaudRate: Int, readTimeoutMs: Int = DspsBlePort.defaultReadTimeoutMs) {
        super.init()
        addressString = address
        baudRate = meterBaudRate
        self.readTimeoutMs = readTimeoutMs
    }

    // MARK: - Async surface

    private func runBlocking<T>(_ body: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            workQueue.async {
                do {
                    continuation.resume(returning: try body())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func signal(_ event: DispatchSemaphore) {
        _ = event.signal()
    }

    private static func wait(_ event: DispatchSemaphore, _ timeoutMs: Int) -> Bool {
        event.wait(timeout: .now() + .milliseconds(timeoutMs)) == .success
    }
}

// MARK: - CommunicationPort

extension DspsBlePort: CommunicationPort {
    func open() async throws {
        try await runBlocking { try self.openSync() }
    }

    func close() async throws {
        try await runBlocking { self.closeSync() }
    }

    var isOpen: Bool {
        get async { isReady }
    }

    var queuedBytes: Int {
        queueLock.lock()
        defer { queueLock.unlock() }
        return rxQueue.count
    }

    func write(_ bytes: [UInt8]) async throws {
        try await runBlocking { try self.writeSync(bytes) }
    }

    func read(_ count: Int) async throws -> [UInt8] {
        try await runBlocking { try self.readSync(count) }
    }
}

// MARK: - characteristic write helper

extension DspsBlePort {
    /// CBPeripheral.writeValue for a discovered characteristic
    /// (.withoutResponse, matched to the serial-config flow).
    func writeWithoutResponse(_ data: Data, to characteristic: CBCharacteristic) {
        let target = peripheral ?? characteristic.service?.peripheral
        target?.writeValue(data, for: characteristic, type: .withoutResponse)
    }
}

// MARK: - Synchronous implementation (blocking, on workQueue)

private extension DspsBlePort {
    func openSync() throws {
        if isReady { return }
        do {
            if !connectWithParameters() {
                throw CommunicationPortError(L.message.msgUnsuccessfulPortOpening)
            }
        } catch let error as CommsError {
            throw CommunicationPortError(L.message.msgUnsuccessfulPortOpening, cause: error)
        } catch {
            throw CommunicationPortError(L.message.msgUnsuccessfulPortOpening, cause: error as? CommsError ?? CommsError("\(error)"))
        }
    }

    /// Init parameters && perform connection.
    func connectWithParameters() -> Bool {
        guard !addressString.isEmpty else {
            PortLog.shared.add("open ▸ no address stored")
            return false
        }
        resetCharacteristicsConfigurationEvents()
        clearRxQueue()
        if !performBluetoothSync() {
            return false
        }
        if !configureCharacteristicsSync() {
            PortLog.shared.add("open ▸ characteristic config FAILED")
            cancelConnectionSync()
            return false
        }
        if !setMtuSync() {
            PortLog.shared.add("open ▸ mtu FAILED")
            cancelConnectionSync()
            return false
        }
        subscribeRx()
        connectionState = .on
        PortLog.shared.add("open ▸ PORT READY")
        return true
    }

    /// Connect (with 15 s timeout).
    func performBluetoothSync() -> Bool {
        bootCentralManager()
        guard let central = central else { return false }
        if !waitForCentralReady(central) {
            return false
        }
        PortLog.shared.add("connect ▸ \(addressString)")
        guard let targetUUID = UUID(uuidString: self.addressString) else {
            PortLog.shared.add("connect ▸ invalid UUID")
            return false
        }
        // 1) Already connected at system level (leftover from an earlier
        //    session or another flow of this app).
        var target = central.retrieveConnectedPeripherals(withServices: [CBUUID(string: Self.spsServerServiceUuid)])
            .first { $0.identifier == targetUUID }
        // 2) Known from a previous connection.
        if target == nil {
            target = central.retrievePeripherals(withIdentifiers: [targetUUID]).first
        }
        if let found = target {
            PortLog.shared.add("connect ▸ peripheral retrieved (state \(found.state.rawValue))")
        } else {
            // 3) Not retrievable – discover it with a short scan.
            PortLog.shared.add("connect ▸ rescan for identifier…")
            target = scanForIdentifier(targetUUID, timeoutMs: 6_000)
            if target != nil {
                PortLog.shared.add("connect ▸ rescan FOUND target")
            } else {
                PortLog.shared.add("connect ▸ rescan found nothing")
            }
        }
        guard let peripheralCandidate = target else {
            return false
        }
        deviceConnectedEvent = DispatchSemaphore(value: 0)
        expectDisconnectEvent = false
        self.peripheral = peripheralCandidate
        peripheralCandidate.delegate = self
        central.connect(peripheralCandidate)
        let connected = DspsBlePort.wait(deviceConnectedEvent, DspsBlePort.connectTimeoutMs)
        if connected {
            PortLog.shared.add("connect ▸ didConnect")
        } else {
            PortLog.shared.add("connect ▸ TIMEOUT 15s (cancelling)")
            central.cancelPeripheralConnection(peripheralCandidate)
            // Mirror: ".Unable to connect to device" log only.
            return false
        }
        return true
    }

    /// Discovery fallback: scan up to timeout for the exact identifier.
    private func scanForIdentifier(_ target: UUID, timeoutMs: Int) -> CBPeripheral? {
        guard let central = central else { return nil }
        scanFound = nil
        scanTarget = target
        scanFoundEvent = DispatchSemaphore(value: 0)
        central.scanForPeripherals(withServices: nil, options: nil)
        let found = DspsBlePort.wait(scanFoundEvent, timeoutMs)
        central.stopScan()
        scanTarget = nil
        return found ? scanFound : nil
    }

    private func waitForCentralReady(_ central: CBCentralManager) -> Bool {
        var waited = 0
        while central.state != .poweredOn && waited < 5_000 {
            Thread.sleep(forTimeInterval: 0.1)
            waited += 100
            if central.state == .unsupported || central.state == .unauthorized {
                return false
            }
        }
        return central.state == .poweredOn
    }

    /// Configuration: characteristics discovery, serial-parameter
    /// writes, settle, THEN RX notify enabling (vendor-friendly order:
    /// the CCCD write goes out only after the serial params landed).
    func configureCharacteristicsSync() -> Bool {
        guard let peripheral = peripheral else { return false }
        rxCharacteristic = nil
        txCharacteristic = nil
        baudRateCharacteristic = nil
        parityCharacteristic = nil
        dataBitsCharacteristic = nil
        stopBitsCharacteristic = nil
        notificationsSubscribed = false

        peripheral.discoverServices([CBUUID(string: Self.spsServerServiceUuid)])

        // 1) TX/RX presence gate (TX signals via event; RX is a plain
        //    property since discovery sets it without an event).
        let txConfigured = DspsBlePort.wait(txConfiguredEvent, DspsBlePort.characteristicConfigTimeoutMs)
        var waited = 0
        while rxCharacteristic == nil && waited < DspsBlePort.characteristicConfigTimeoutMs {
            Thread.sleep(forTimeInterval: 0.1)
            waited += 100
        }
        let rxDiscovered = rxCharacteristic != nil
        guard txConfigured && rxDiscovered else {
            PortLog.shared.add("config ▸ missing chars (tx=\(txConfigured) rx=\(rxDiscovered))")
            return false
        }

        // 2) Serial params were written at discovery time; await their
        //    completion events + settle sleep, then open the RX pipe.
        Thread.sleep(forTimeInterval: TimeInterval(DspsBlePort.configSettleSleepMs) / 1000.0)
        let baudOk = baudRateCharacteristic == nil || DspsBlePort.wait(baudRateConfiguredEvent, DspsBlePort.serialParamWriteTimeoutMs)
        let parityOk = parityCharacteristic == nil || DspsBlePort.wait(parityConfiguredEvent, DspsBlePort.serialParamWriteTimeoutMs)
        let dataBitsOk = dataBitsCharacteristic == nil || DspsBlePort.wait(dataBitsConfiguredEvent, DspsBlePort.serialParamWriteTimeoutMs)
        let stopBitsOk = stopBitsCharacteristic == nil || DspsBlePort.wait(stopBitsConfiguredEvent, DspsBlePort.serialParamWriteTimeoutMs)
        guard baudOk && parityOk && dataBitsOk && stopBitsOk else {
            var missing: [String] = []
            if !baudOk { missing.append("BaudRate") }
            if !dataBitsOk { missing.append("DataBits") }
            if !parityOk { missing.append("Parity") }
            if !stopBitsOk { missing.append("StopBits") }
            PortLog.shared.add("config ▸ params missing: \(missing.joined(separator: ","))")
            return false
        }

        // 3) RX notify AFTER parameters + settle: descriptor discovery
        //    first (the CCCD read reports "already enabled"), then the
        //    subscribe request, then the toggle-retry if it stalls.
        if let rx = rxCharacteristic {
            if rx.isNotifying {
                DspsBlePort.signal(rxConfiguredEvent)
                PortLog.shared.add("notify ▸ RX already on")
            } else if peripheral.state == .connected {
                PortLog.shared.add("notify ▸ enable (post-params)")
                peripheral.discoverDescriptors(for: rx)
                peripheral.setNotifyValue(true, for: rx)
            } else {
                PortLog.shared.add("notify ▸ not connected anymore")
            }
        }
        var rxConfiguredFinal = DspsBlePort.wait(rxConfiguredEvent, DspsBlePort.characteristicConfigTimeoutMs)
        PortLog.shared.add("config ▸ rx=\(rxConfiguredFinal)")
        if !rxConfiguredFinal, let rx = rxCharacteristic, peripheral.state == .connected {
            PortLog.shared.add("config ▸ RX notify retry (toggle)")
            rxConfiguredEvent = DispatchSemaphore(value: 0)
            peripheral.setNotifyValue(false, for: rx)
            Thread.sleep(forTimeInterval: 0.3)
            peripheral.setNotifyValue(true, for: rx)
            rxConfiguredFinal = DspsBlePort.wait(rxConfiguredEvent, DspsBlePort.characteristicConfigTimeoutMs)
            PortLog.shared.add("config ▸ rx retry=\(rxConfiguredFinal)")
        }
        if !rxConfiguredFinal || !txConfigured {
            var missing: [String] = []
            if !rxConfiguredFinal { missing.append("RX") }
            if !txConfigured { missing.append("TX") }
            PortLog.shared.add("config ▸ missing: \(missing.joined(separator: ","))")
            return false
        }
        return true
    }

    func subscribeRx() {
        // setNotifyValue already requested during configuration; this
        // only arms the byte-entry pipe (WhenNotificationReceived).
        notificationsSubscribed = isReadyCharacteristic(rxCharacteristic)
    }

    func isReadyCharacteristic(_ characteristic: CBCharacteristic?) -> Bool {
        characteristic != nil && peripheral?.state == .connected
    }

    func setMtuSync() -> Bool {
        // iOS negotiates ATT MTU automatically; the manual request is
        // unavailable (IsMtuRequestAvailable == false).
        true
    }

    func writeCharacteristicsConfig(_ characteristic: CBCharacteristic) {
        let uuid = characteristic.uuid.uuidString.lowercased()
        PortLog.shared.add("serial ▸ \(uuid.suffix(4)) write")
        switch uuid.lowercased() {
        case Self.spsBaudRateUuid:
            baudRateCharacteristic = characteristic
            var value = UInt32(bitPattern: Int32(baudRate))
            let littleEndianBytes = withUnsafeBytes(of: &value) { Array($0) }
            writeWithoutResponse(Data(littleEndianBytes), to: characteristic)
            DspsBlePort.signal(baudRateConfiguredEvent)
        case Self.spsParityUuid:
            parityCharacteristic = characteristic
            writeWithoutResponse(Data([SerialParams.parity]), to: characteristic)
            DspsBlePort.signal(parityConfiguredEvent)
        case Self.spsDataBitsUuid:
            dataBitsCharacteristic = characteristic
            writeWithoutResponse(Data([SerialParams.dataBits]), to: characteristic)
            DspsBlePort.signal(dataBitsConfiguredEvent)
        case Self.spsStopBitsUuid:
            stopBitsCharacteristic = characteristic
            writeWithoutResponse(Data([SerialParams.stopBits]), to: characteristic)
            DspsBlePort.signal(stopBitsConfiguredEvent)
        default:
            break
        }
    }

    func enqueue(bytes: [UInt8]) {
        if bytes.isEmpty { return }
        queueLock.lock()
        rxQueue.append(contentsOf: bytes)
        queueLock.unlock()
    }

    func clearRxQueue() {
        queueLock.lock()
        rxQueue.removeAll()
        queueLock.unlock()
    }

    /// ReadFromQueue(numberOfBytes).
    func readSync(_ numberOfBytes: Int) throws -> [UInt8] {
        var asArray = [UInt8]()
        asArray.reserveCapacity(max(numberOfBytes, 0))
        if numberOfBytes == 0 {
            return asArray
        }
        if !isReady {
            try openSync()
        }
        do {
            return try readFromQueue(numberOfBytes)
        } catch {
            // Mirrors BluetoothCommunicationPortPluginSpc.Read catch
            let partialHex = bytesAsHex(asArray)
            _ = partialHex
            PortLog.shared.add("read ▸ FAIL \(isTimeoutError(error) ? "TIMEOUT" : "error") (\(numberOfBytes)B)")
            if isTimeoutError(error) {
                throw TimeoutError(L.message.msgUnsuccessfulDataReceiving, cause: error as? CommsError ?? CommsError("\(error)"))
            }
            throw CommunicationPortError(L.message.msgUnsuccessfulDataReceiving, cause: error as? CommsError ?? CommsError("\(error)"))
        }
    }

    func readFromQueue(_ numberOfBytes: Int) throws -> [UInt8] {
        var result = [UInt8]()
        result.reserveCapacity(numberOfBytes)
        if numberOfBytes == 3 {
            if !DspsBlePort.wait(byteReceivedEvent, readTimeoutMs) {
                throw TimeoutError("No RX data in queue")
            }
            _ = byteReceivedEvent.wait(timeout: .now()) // consume one signal
        }
        for _ in 0 ..< numberOfBytes {
            var remaining = readTimeoutMs
            while remaining > 0 {
                queueLock.lock()
                let hasByte = !rxQueue.isEmpty
                if hasByte {
                    result.append(rxQueue.removeFirst())
                }
                queueLock.unlock()
                if hasByte { break }
                remaining -= DspsBlePort.readPollIntervalMs
                Thread.sleep(forTimeInterval: 0.1)
            }
            if remaining < 1 {
                throw TimeoutError("No complete RX data in queue")
            }
        }
        return result
    }

    func isTimeoutError(_ error: Error) -> Bool {
        var current: Error? = error
        while let e = current {
            if e is TimeoutError { return true }
            if let comms = e as? CommsError, comms.message.lowercased().contains("timeout") { return true }
            if e is TimerError { return true }
            current = (e as? CommsError)?.cause
        }
        return false
    }

    func bytesAsHex(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02X", $0) }.joined()
    }

    /// PluginSerialPortGattClient.Write
    func writeSync(_ buffer: [UInt8]) throws {
        if buffer.isEmpty {
            return
        }
        if !isReady {
            try openSync()
        }
        do {
            try writeGattData(buffer)
        } catch let error as CommsError {
            // BluetoothCommunicationPortPluginSpc.Write catch:
            // TimeoutException → TimeoutException(msg…, ex), other →
            // CommunicationPortException(msg…, ex) – the plugin write
            // timeout throws plain Exception, so the wrapped port
            // exception carries the chain only.
            throw CommunicationPortError(L.message.msgUnsuccessfulDataSending, cause: error)
        }
    }

    func writeGattData(_ buffer: [UInt8]) throws {
        guard let tx = txCharacteristic, let peripheral = peripheral, peripheral.canSend else {
            throw CommsError("")
        }
        // Chunk to the negotiated MTU (long writes are silently
        // dropped by CoreBluetooth otherwise), prefer write-with-
        // response like the Android WRITE_TYPE_DEFAULT port.
        let withResponse = tx.properties.contains(.write)
        var chunkSize = withResponse
            ? peripheral.maximumWriteValueLength(for: .withResponse)
            : peripheral.maximumWriteValueLength(for: .withoutResponse)
        if chunkSize < 20 { chunkSize = 20 }
        // Prepare the ack event BEFORE writing: fast didWriteValueFor
        // acks must land on the same semaphore.
        byteSentEvent = DispatchSemaphore(value: 0)
        writeErrorMessage = ""
        let data = Data(buffer)
        var offset = 0
        var written = 0
        while offset < data.count {
            let end = min(offset + chunkSize, data.count)
            peripheral.writeValue(data.subdata(in: offset ..< end), for: tx,
                                  type: withResponse ? .withResponse : .withoutResponse)
            written += end - offset
            offset = end
        }
        let writeHex = buffer.prefix(48).map { String(format: "%02X", $0) }.joined()
        PortLog.shared.add("write ▸ \(written)B \(writeHex) (\(withResponse ? "resp" : "noresp"))")
        if withResponse {
            if !DspsBlePort.wait(byteSentEvent, DspsBlePort.byteSentTimeoutMs) {
                PortLog.shared.add("write ▸ no ack 2s (\(writeErrorMessage))")
                throw CommsError(writeErrorMessage.isEmpty ? "write failed" : writeErrorMessage)
            }
        }
    }

    /// BluetoothCommunicationPortPluginSpc.Close (swallows errors).
    func closeSync() {
        if isReady {
            disconnectSync()
            clearRxQueue()
        }
    }

    /// PluginSerialPortGattClient.Disconnect(). No-op when RX
    /// characteristic isn't known.
    func disconnectSync() {
        if rxCharacteristic == nil {
            return
        }
        cancelConnectionSync()
        connectionState = .disconnected
    }

    func cancelConnectionSync() {
        PortLog.shared.add("disconnect ▸ cancelling")
        guard let peripheral = peripheral, let central = central else { return }
        expectDisconnectEvent = true
        central.cancelPeripheralConnection(peripheral)
        // Mirror: WhenDisconnected subscription + 8 s wait.
        _ = DspsBlePort.wait(peripheralDisconnectedEvent, DspsBlePort.disconnectTimeoutMs)
        expectDisconnectEvent = false
        notificationsSubscribed = false
        self.peripheral = nil
        rxCharacteristic = nil
        txCharacteristic = nil
        baudRateCharacteristic = nil
        parityCharacteristic = nil
        dataBitsCharacteristic = nil
        stopBitsCharacteristic = nil
        Thread.sleep(forTimeInterval: TimeInterval(DspsBlePort.disconnectSettleSleepMs) / 1000.0)
        connectionState = .disconnected
    }

    func resetCharacteristicsConfigurationEvents() {
        rxConfiguredEvent = DispatchSemaphore(value: 0)
        txConfiguredEvent = DispatchSemaphore(value: 0)
        baudRateConfiguredEvent = DispatchSemaphore(value: 0)
        parityConfiguredEvent = DispatchSemaphore(value: 0)
        dataBitsConfiguredEvent = DispatchSemaphore(value: 0)
        stopBitsConfiguredEvent = DispatchSemaphore(value: 0)
    }
}

// MARK: - CBCentralManagerDelegate, CBPeripheralDelegate

extension DspsBlePort: CBCentralManagerDelegate, CBPeripheralDelegate {
    func bootCentralManager() {
        if central == nil {
            central = CBCentralManager(delegate: self, queue: cbQueue)
            PortLog.shared.add("central ▸ boot")
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // Bluetooth readiness state; connect failures mirror the 15 s
        // abort path.
        PortLog.shared.add("central ▸ state \(central.state.rawValue)")
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        DspsBlePort.signal(deviceConnectedEvent)
        // Discovery is driven solely by configureCharacteristicsSync —
        // a second overlapping discoverServices here re-triggers the
        // characteristic pipeline and can clobber the pending CCCD
        // write (RX notify stays "enabling" forever).
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        if peripheral.identifier == scanTarget {
            scanFound = peripheral
            scanTarget = nil
            DspsBlePort.signal(scanFoundEvent)
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if notificationsSubscribed || connectionState == .on {
            // Unexpected loss of an active connection.
            connectionState = .off
        }
        PortLog.shared.add("central ▸ METER DISCONNECTED err=\(error != nil ? error!.localizedDescription : "none")")
        if expectDisconnectEvent {
            expectDisconnectEvent = false
            DspsBlePort.signal(peripheralDisconnectedEvent)
        }
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        // Mirrors the C#: connect error callbacks not wired –
        // the 15 s timeout handles it.
        PortLog.shared.add("central ▸ didFailToConnect err=\(error != nil ? error!.localizedDescription : "none")")
        if expectDisconnectEvent {
            DspsBlePort.signal(peripheralDisconnectedEvent)
        }
        expectDisconnectEvent = false
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            PortLog.shared.add("discover ▸ services error \(error!.localizedDescription)")
            return
        }
        let services = peripheral.services ?? []
        PortLog.shared.add("discover ▸ services=\(services.count)")
        for service in services where service.uuid.uuidString.lowercased() == Self.spsServerServiceUuid {
            PortLog.shared.add("discover ▸ SPS found")
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else { return }
        let discovered = service.characteristics ?? []
        // Log the raw truth: UUID + property mask of every char.
        for characteristic in discovered {
            let uuid = characteristic.uuid.uuidString.lowercased()
            let p = characteristic.properties
            let mask = [
                p.contains(.read) ? "R" : "",
                p.contains(.write) ? "W" : "",
                p.contains(.writeWithoutResponse) ? "WN" : "",
                p.contains(.notify) ? "N" : "",
                p.contains(.indicate) ? "I" : ""
            ].filter { !$0.isEmpty }.joined(separator: "|")
            PortLog.shared.add("discover ▸ \(uuid.suffix(4)) props=\(mask.isEmpty ? "none" : mask)")
            switch uuid {
            case Self.spsBaudRateUuid, Self.spsParityUuid, Self.spsDataBitsUuid, Self.spsStopBitsUuid:
                writeCharacteristicsConfig(characteristic)
            default:
                break
            }
        }

        // Adaptive channel assignment: properties are the ground truth
        // (some firmware ships the serial chars with swapped names).
        func notifiable(_ c: CBCharacteristic) -> Bool {
            !c.properties.isDisjoint(with: [.notify, .indicate])
        }
        func writable(_ c: CBCharacteristic) -> Bool {
            !c.properties.isDisjoint(with: [.write, .writeWithoutResponse])
        }
        let rxConst = discovered.first { $0.uuid.uuidString.lowercased() == Self.spsServerRxUuid }
        let txConst = discovered.first { $0.uuid.uuidString.lowercased() == Self.spsServerTxUuid }
        let chosenRx = (rxConst.flatMap { notifiable($0) ? $0 : nil })
            ?? discovered.first(where: notifiable)
        let chosenTx = (txConst.flatMap { writable($0) ? $0 : nil })
            ?? discovered.first(where: writable)

        rxCharacteristic = chosenRx
        txCharacteristic = chosenTx
        if let rx = chosenRx {
            let swapped = rxConst != nil && rx.uuid.uuidString.lowercased() != Self.spsServerRxUuid
            PortLog.shared.add("discover ▸ RX←\(rx.uuid.uuidString.suffix(4))\(swapped ? " (ADAPTIVE SWAP)" : "")")
        } else {
            PortLog.shared.add("discover ▸ NO notifiable characteristic!")
        }
        if chosenTx != nil {
            DspsBlePort.signal(txConfiguredEvent)
        } else {
            PortLog.shared.add("discover ▸ NO writable characteristic!")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        guard descriptor.uuid == Self.cccdUuid,
              let rx = rxCharacteristic, descriptor.characteristic === rx else { return }
        if error != nil {
            // Descriptor read failed – attempt enabling anyway.
            PortLog.shared.add("notify ▸ CCCD read FAIL \(error!.localizedDescription)")
            peripheral.setNotifyValue(true, for: rx)
            return
        }
        // iOS delivers CCCD values as Data(2) or an NSNumber depending
        // on version – accept both, then mirror the C# decision.
        var alreadyEnabled = false
        var actual = 0
        var raw = ""
        if let data = (descriptor.value as? Data) {
            actual = data.count
            raw = data.map { String(format: "%02X", $0) }.joined()
            let bytes: [UInt8] = data.count >= 2 ? [data[0], data[1]] : []
            if bytes.count == 2 {
                if (bytes[0] == 2 && bytes[1] == 0) || (bytes[0] == 1 && bytes[1] == 0) {
                    alreadyEnabled = true
                }
            }
        } else if let number = (descriptor.value as? NSNumber) {
            raw = "NSNumber \(number)"
            let bits = number.uint16Value
            if bits == 1 || bits == 2 {
                alreadyEnabled = true
            }
        } else {
            raw = "nil/other"
        }
        PortLog.shared.add("notify ▸ CCCD=\(raw) (\(actual)B) enabled=\(alreadyEnabled)")
        if alreadyEnabled {
            // Meter-side CCCD says enabled: arm the RX pipe without
            // re-issuing the subscribe (bytes will flow immediately).
            notificationsSubscribed = true
            DspsBlePort.signal(rxConfiguredEvent)
            return
        }
        peripheral.setNotifyValue(true, for: rx)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic === rxCharacteristic else { return }
        let names = (characteristic.descriptors ?? []).map { $0.uuid.uuidString }.joined(separator: ",")
        PortLog.shared.add("discover ▸ RX descriptors [\(names)] err=\(error != nil ? error!.localizedDescription : "nil")")
        guard error == nil else {
            // Descriptor discovery failed – attempt enabling anyway.
            peripheral.setNotifyValue(true, for: characteristic)
            return
        }
        // Mirror: CCCD present → READ it; the read callback decides.
        // Mirror C# "No descriptor for ...b913" → try enabling anyway.
        // NOTE: CoreBluetooth canonicalizes SDO 16-bit descriptor UUIDs
        // ("2902"), so compare CBUUID objects, not uuidStrings.
        if let cccd = (characteristic.descriptors ?? []).first(where: { $0.uuid == Self.cccdUuid }) {
            peripheral.readValue(for: cccd)
        } else {
            PortLog.shared.add("discover ▸ RX CCCD MISSING → setNotify")
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic) {
        guard characteristic === rxCharacteristic else { return }
        DspsBlePort.signal(rxConfiguredEvent)
        PortLog.shared.add("notify ▸ RX on (\(characteristic.isNotifying))")
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        // Characteristic reads and notification payloads for RX.
        guard characteristic === rxCharacteristic,
              characteristic.uuid.uuidString.lowercased() == Self.spsServerRxUuid else { return }
        guard notificationsSubscribed else { return } // mirror: subscription only after SubscribeRx
        if error != nil {
            PortLog.shared.add("notify ▸ RX error \(error!.localizedDescription)")
            return
        }
        if let data = characteristic.value, !data.isEmpty {
            let bytes = [UInt8](data)
            let hex = bytes.prefix(64).map { String(format: "%02X", $0) }.joined()
            PortLog.shared.add("RX ▸ \(bytes.count)B \(hex)")
            enqueue(bytes: bytes)
            DspsBlePort.signal(byteReceivedEvent)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic === txCharacteristic else { return }
        if error != nil {
            writeErrorMessage = "\(error!.localizedDescription)"
            PortLog.shared.add("write ▸ error \(writeErrorMessage)")
            return
        }
        writeErrorMessage = ""
        DspsBlePort.signal(byteSentEvent)
    }
}

// MARK: - CBCharacteristic helpers

extension CBPeripheral {
    var canSend: Bool {
        state == .connected
    }
}

extension CBCharacteristic {
    func canWriteWithResponse() -> Bool {
        properties.contains(.write)
    }

    func canWriteWithoutResponse() -> Bool {
        properties.contains(.writeWithoutResponse)
    }
}

private extension DispatchQueue {
    static func onMain(_ work: @escaping () -> Void) {
        DispatchQueue.main.async(execute: work)
    }
}

protocol CommunicationPort {
    /// Mirrors Open(): connect + DISC/SNRM happen in the transport.
    func open() async throws
    /// Mirrors Close().
    func close() async throws
    /// Mirrors IsOpened().
    var isOpen: Bool { get async }
    /// Mirrors Write().
    func write(_ bytes: [UInt8]) async throws
    /// Mirrors Read(numberOfBytes).
    func read(_ count: Int) async throws -> [UInt8]
    /// Bytes still unread in the RX queue (diagnostics only).
    var queuedBytes: Int { get }
}

/// TimerError: Swift timeout helper (treated as a timeout-type error
/// for the IsTimeoutException chain).
struct TimerError: Error {}

// MARK: - Port activity log (on-device diagnostics)

/// Small on-device ring buffer of BLE port milestones, shown in
/// Settings ▸ Port activity log. Diagnosis aid only; no behavior.
final class PortLog {
    static let shared = PortLog()
    static let changedNotification = Notification.Name("PortLogChanged")

    private let lock = NSLock()
    private var entries: [String] = []
    private let maxEntries = 200

    private init() {}

    func add(_ text: String) {
        let stamp: String = {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            return formatter.string(from: Date())
        }()
        lock.lock()
        entries.append(stamp + " " + text)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        lock.unlock()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.changedNotification, object: nil)
        }
    }

    func text(tail: Int = 0) -> String {
        lock.lock()
        defer { lock.unlock() }
        var slice = entries
        if tail > 0 && slice.count > tail {
            slice = Array(slice.suffix(tail))
        }
        return slice.joined(separator: "\n")
    }

    func clear() {
        lock.lock()
        entries.removeAll()
        lock.unlock()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.changedNotification, object: nil)
        }
    }
}
