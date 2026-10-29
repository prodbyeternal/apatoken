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
    @Published var error: String?
    @Published var selectedMeterName: String = ""
    @Published var isPresented = false

    private var central: CBCentralManager?
    private var foundKeys: Set<String> = []

    func start() {
        devices = []
        foundKeys = []
        error = nil
        isPowered = false
        central = CBCentralManager(delegate: self, queue: nil)
    }

    func stop() {
        central?.stopScan()
        central = nil
    }

    func connect(to device: DiscoveredBLEDevice) {
        stop()
        SettingsManager.setCommunicationPort("Bluetooth_LowEnergyService")
        SettingsManager.setBluetoothDevice(device.shortName, device.address)
        selectedMeterName = device.shortName
    }
}

// MARK: - CBCentralManagerDelegate

extension MeterPickerViewModel: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            guard central.state == .poweredOn else {
                if central.state == .unsupported {
                    self.error = L.message.msgBluetoothNotSupported
                }
                return
            }
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
