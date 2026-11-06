import SwiftUI
import CoreBluetooth
import Combine

// MARK: - Meter picker view model

@MainActor
final class MeterPickerViewModel: NSObject, ObservableObject {
    struct DiscoveredBLEDevice: Identifiable, Equatable {
        let id = UUID()
        let shortName: String
        let address: String
        let display: String

        init(shortName: String, address: String) {
            self.shortName = shortName
            self.address = address
            self.display = shortName + "\n" + address
        }
    }

    @Published var devices: [DiscoveredBLEDevice] = []
    @Published var isPowered = false
    @Published var error: Error?
    @Published var selectedMeterName: String = ""
    @Published var isPresented = false

    private var central: CBCentralManager?
    private var foundKeys: Set<String> = []

    func start() {
        stop()
        devices = []
        foundKeys = []
        error = nil
        isPowered = false
        if MeterSession.shared.testing {
            devices = MeterSession.shared.testState?.meters.map {
                DiscoveredBLEDevice(shortName: $0.number, address: $0.id)
            } ?? []
            return
        }
        central = CBCentralManager(delegate: self, queue: nil)
    }

    func stop() {
        central?.stopScan()
        central = nil
    }

    func connect(to device: DiscoveredBLEDevice) -> Bool {
        stop()
        do {
            try MeterSession.shared.select(name: device.shortName, id: device.address)
            selectedMeterName = device.shortName
            return true
        } catch {
            self.error = error
            return false
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension MeterPickerViewModel: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            guard !MeterSession.shared.testing, self.central === central else { return }
            guard central.state == .poweredOn else {
                self.isPowered = false
                if central.state == .unsupported {
                    self.error = CommsError(L.message.msgBluetoothNotSupported)
                } else if central.state == .poweredOff {
                    self.error = CommsError(L.text("msgBluetoothOff"))
                } else if central.state == .unauthorized {
                    self.error = CommsError(L.text("msgBluetoothPermission"))
                }
                return
            }
            self.error = nil
            self.isPowered = true
            central.scanForPeripherals(withServices: nil, options: nil)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didDiscover peripheral: CBPeripheral,
                                    advertisementData: [String: Any],
                                    rssi RSSI: NSNumber) {
        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let name = advertisedName ?? peripheral.name

        // Filter: name uppercase starts with "APA" and does not contain "-"
        guard let name, !name.isEmpty,
              name.uppercased().hasPrefix("APA"), !name.contains("-") else {
            return
        }

        Task { @MainActor in
            guard !MeterSession.shared.testing, self.central === central else { return }
            self.addDevice(peripheral: peripheral, name: name)
        }
    }

    private func addDevice(peripheral: CBPeripheral, name: String) {
        let address = peripheral.identifier.uuidString.uppercased()
        let shortName = String(name.dropFirst(3))
        let key = shortName + "_" + address
        guard !foundKeys.contains(key) else {
            return
        }
        foundKeys.insert(key)
        devices.append(DiscoveredBLEDevice(shortName: shortName, address: address))
    }
}
