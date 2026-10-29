import Combine
import SwiftUI
import CoreBluetooth
import UIKit

// MARK: - BluetoothDeviceScanner (BluetoothPopup.DoDiscovery mirror)

/// Scans with CoreBluetooth while a sheet (BluetoothPopup mirror) is open.
/// Devices are filtered exactly like the Android LE scan: name uppercase
/// starts with "APA" and does not contain "-"; deduplication via the
/// _foundDevices key (name.Substring(3) + "_" + address).
@MainActor
final class BluetoothDeviceScanner: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    struct DiscoveredDevice: Identifiable, Equatable {
        let id = UUID()
        let shortName: String   // name.Substring(3)
        let address: String     // CBPeripheral identifier UUID string
        let display: String     // shortName + "\n" + address

        init(shortName: String, address: String) {
            self.shortName = shortName
            self.address = address
            display = shortName + "\n" + address
        }
    }

    @Published var devices: [DiscoveredDevice] = []
    @Published var isPowered = false
    @Published var error: String?

    private var central: CBCentralManager?
    private var foundKeys: Set<String> = []

    func start() {
        devices = []
        foundKeys = []
        error = nil
        isPowered = false
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func stop() {
        central?.stopScan()
        central = nil
    }

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
        // device.Name.ToUpperInvariant().StartsWith("APA") &&
        // !device.Name.Contains("-")
        guard let name, !name.isEmpty,
              name.uppercased().hasPrefix("APA"), !name.contains("-") else {
            return
        }
        Task { @MainActor in
            self.addDevice(peripheral: peripheral, name: name)
        }
    }

    private func addDevice(peripheral: CBPeripheral, name: String) {
        // Android derives the MAC from the LE UUID bytes; iOS uses the
        // CBPeripheral identifier string as the device address.
        let address = peripheral.identifier.uuidString.uppercased()
        let shortName = String(name.dropFirst(3))
        let key = shortName + "_" + address
        guard !foundKeys.contains(key) else {
            return
        }
        foundKeys.insert(key)
        devices.append(DiscoveredDevice(shortName: shortName, address: address))
    }


}

// MARK: - SettingsView

struct SettingsView: View {
    @EnvironmentObject private var app: AppState

    @State private var deviceName = ""
    @State private var deviceAddress = ""
    @State private var showScan = false
    @State private var alert: AlertPresentation?
    @State private var scanner = BluetoothDeviceScanner()
    @State private var portLogText = ""
    @State private var copyFlash = false

    var body: some View {
            ScrollView {
                VStack(spacing: 0) {
                    GeometryReader { proxy in
                    Image("apatoken_instruction")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: proxy.size.width - 40)
                        .frame(maxWidth: .infinity)
                }
                .frame(height: 120)
                instructionCaption
                scanButton
                deviceFields
                portLogCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(L.ui.txtMenuSettings)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    alert = AlertPresentation(L.ui.appName,
                                              "\(L.ui.txtPackageVersion): 1.1\n\(L.ui.txtPublisher): APATOR S.A.")
                } label: {
                    Image(systemName: "info.circle")
                }
            }
        }
        .sheet(isPresented: $showScan, onDismiss: {
            scanner.stop()
        }) {
            DeviceScanSheet(scanner: scanner) { device in
                if device == nil {
                    // Popup closed without a selection.
                    saveSelection(name: "", address: "")
                }
            }
        }
        .alertPopup($alert)
        .onAppear {
            updateDeviceInfo()
            refreshPortLog()
        }
        .onReceive(NotificationCenter.default.publisher(for: PortLog.changedNotification)) { _ in
            refreshPortLog()
        }
        .onChange(of: showScan) { oldValue, _ in
            // When the sheet goes away with a selection the fields were
            // already updated by the row callback.
            _ = oldValue
        }
        .onReceive(scanner.$error) { errorText in
            if let errorText {
                alert = AlertPresentation(L.ui.txtError, errorText)
            }
        }
        .onReceive(scanner.$devices) { list in
            // Keep the entries up-to-date is handled via the row callback;
            // nothing to do on list changes.
            _ = list
        }
    }

    private var instructionCaption: some View {
        Text("\(L.ui.txtSampleIdentification) \(L.ui.txtMeterNumber)\(L.ui.txtLocatedOnTheMeterCasing)")
            .font(ApaFont.regular(14))
            .foregroundStyle(ApaColor.gray)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var scanButton: some View {
        Button {
            StartScan()
        } label: {
            HStack {
                Spacer()
                Text(L.ui.txtSelectDevice)
                    .font(ApaFont.semibold(16))
                Spacer()
            }
            .padding(.vertical, 12)
            .foregroundStyle(.white)
            .background(ApaColor.blue)
            .cornerRadius(AppStyle.buttonCorner)
        }
        .buttonStyle(.plain)
        .padding(.top, 12)
    }

    private var deviceFields: some View {
        VStack(spacing: 0) {
            fieldRow(label: L.ui.txtDeviceName, value: deviceName)
            Divider()
                .background(Color(uiColor: .lightGray))
                .frame(height: 1)
            fieldRow(label: L.ui.txtDeviceAddress, value: deviceAddress)
                .padding(.top, 15)
            Divider()
                .background(Color(uiColor: .lightGray))
                .frame(height: 1)
        }
        .padding(.top, 18)
        .background(.white)
        .cornerRadius(AppStyle.cardCorner)
        .padding(.vertical, 18)
    }

    private func fieldRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(ApaFont.semibold(16))
                .foregroundStyle(ApaColor.gray)
            Text(value)
                .font(ApaFont.regular(16))
                .foregroundStyle(Color(uiColor: .darkGray))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
        }
    }

    /// On-device BLE diagnostics (PortLog ring buffer).
    private var portLogCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Port activity log")
                    .font(ApaFont.semibold(14))
                Spacer()
                Button {
                    UIPasteboard.general.string = PortLog.shared.text()
                    copyFlash = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        copyFlash = false
                    }
                } label: {
                    Label(copyFlash ? "Copied" : "Copy", systemImage: copyFlash ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                Button {
                    PortLog.shared.clear()
                    refreshPortLog()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13))
                }
                .buttonStyle(.borderless)
            }
            ScrollView {
                Text(portLogText.isEmpty ? "(empty)" : portLogText)
                    .font(.system(size: 10).monospaced())
                    .foregroundStyle(ApaColor.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(height: 220)
            .background(Color(uiColor: .systemBackground).opacity(0.65))
            .cornerRadius(8)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private func refreshPortLog() {
        portLogText = PortLog.shared.text()
    }

    // MARK: - Flows

    private func updateDeviceInfo() {
        deviceName = SettingsManager.getBluetoothDeviceName()
        deviceAddress = SettingsManager.getBluetoothDeviceAddress()
    }

    /// ChooseBluetoothDevice_OnClicked → StartScan.
    private func StartScan() {
        showScan = true
    }

    private func saveSelection(name: String, address: String) {
        SettingsManager.setCommunicationPort("Bluetooth_LowEnergyService")
        SettingsManager.setBluetoothDevice(name, address)
        updateDeviceInfo()
    }
}

// MARK: - DeviceScanSheet (BluetoothPopup)

struct DeviceScanSheet: View {
    @ObservedObject var scanner: BluetoothDeviceScanner
    let onSelected: (BluetoothDeviceScanner.DiscoveredDevice?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var didSelect = false

    var body: some View {
        VStack(spacing: 6) {
            Text(L.ui.txtAvailableDevices)
                .font(ApaFont.semibold(16))
                .padding(.top, 16)
            HStack {
                if scanner.isPowered {
                    Text(L.ui.txtScanning)
                        .font(ApaFont.regular(13))
                        .foregroundStyle(ApaColor.gray)
                    Spacer()
                    ProgressView()
                        .tint(ApaColor.entryText)
                } else {
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            Divider()
                .background(Color(uiColor: .lightGray))
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(scanner.devices) { device in
                        Button {
                            // DevicesListView_ItemTapped: SaveSettings +
                            // tcs result + _itemSelected = true + close.
                            SettingsManager.setCommunicationPort("Bluetooth_LowEnergyService")
                            SettingsManager.setBluetoothDevice(device.shortName, device.address)
                            didSelect = true
                            onSelected(device)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(device.shortName)
                                    .font(ApaFont.regular(15))
                                    .foregroundStyle(Color(uiColor: .darkText))
                                Text(device.address)
                                    .font(ApaFont.regular(12))
                                    .foregroundStyle(ApaColor.gray)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            Divider()
                                .background(Color(uiColor: .lightGray))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .onAppear { scanner.start() }
        .onDisappear {
            // BluetoothPopup_Closed: without a selection the settings are
            // cleared ("", "").
            if !didSelect {
                onSelected(nil)
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AppState())
    }
}
