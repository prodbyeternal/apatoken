import SwiftUI

// MARK: - ReadingsView (ReadingsPage)

@MainActor
struct ReadingsView: View {
    @EnvironmentObject private var app: AppState

    @State private var deviceName = ""
    @State private var busy = false
    @State private var alert: AlertPresentation?
    @State private var credit1: CreditDisplay = .reset
    @State private var credit2: CreditDisplay = .reset

    static let notSpecifiedDeviceName = "-----"

    var body: some View {
        VStack(spacing: 0) {
            ReadingsHeader()
            ScrollView {
                VStack(spacing: 18) {
                    zone1Card
                    zone2Card
                    deviceAndActivity
                    readButton
                }
                .padding(16)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .alertPopup($alert)
        .onAppear {
            if updateDeviceName() {
                // ResetCreditLabels when the device changed.
                credit1 = .reset
                credit2 = .reset
            }
        }
    }

    // MARK: - Credit display states

    enum CreditDisplay: Equatable {
        case reset
        case value(String)
    }

    private func creditLabel(_ display: CreditDisplay) -> some View {
        let text: String
        let color: Color
        let bold: Bool
        switch display {
        case .reset:
            text = "-----"
            color = ApaColor.creditReset
            bold = false
        case .value(let value):
            text = value
            color = ApaColor.green
            bold = true
        }
        return Text(text)
            .font(bold ? ApaFont.semibold(20) : ApaFont.regular(20))
            .foregroundStyle(color)
    }

    private func zoneCard(zone: Int, display: CreditDisplay) -> some View {
        VStack(spacing: 6) {
            Text("\(L.ui.txtZone) \(zone)")
                .font(ApaFont.regular(18))
                .foregroundStyle(ApaColor.gray)
            creditLabel(display)
        }
        .frame(maxWidth: .infinity)
        .apaCard()
    }

    private var zone1Card: some View {
        zoneCard(zone: 1, display: credit1)
    }

    private var zone2Card: some View {
        zoneCard(zone: 2, display: credit2)
    }

    private var deviceAndActivity: some View {
        VStack(spacing: 12) {
            Text(deviceName.isEmpty ? Self.notSpecifiedDeviceName : deviceName)
                .font(ApaFont.semibold(16))
                .foregroundStyle(ApaColor.gray)
            if !deviceDefined {
                Button(action: { app.goToSettings() }) {
                    Text(L.ui.txtSelect)
                        .font(ApaFont.semibold(15))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(ApaColor.blue)
                        .cornerRadius(AppStyle.buttonCorner)
                }
            }
            if busy {
                ActivityIndicatorView()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private var readButton: some View {
        Button {
            Task { await readCredits() }
        } label: {
            HStack {
                Spacer()
                Text(L.ui.txtReadCredits)
                    .font(ApaFont.semibold(16))
                Spacer()
            }
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .background(busy ? ApaColor.gray.opacity(0.5) : ApaColor.blue)
            .cornerRadius(AppStyle.buttonCorner)
        }
        .buttonStyle(.plain)
        .disabled(busy)
    }

    private var deviceDefined: Bool {
        !deviceName.isEmpty && deviceName != Self.notSpecifiedDeviceName
    }

    // MARK: - Flows

    @discardableResult
    private func updateDeviceName() -> Bool {
        let previousDeviceName = deviceName
        let storedDeviceName = SettingsManager.getBluetoothDeviceName()
        deviceName = storedDeviceName.isEmpty ? Self.notSpecifiedDeviceName : storedDeviceName
        return deviceName != previousDeviceName
    }

    private func readCredits() async {
        if !deviceDefined {
            alert = AlertPresentation(L.ui.txtAlertInfo, L.message.msgToReadCreditsDeviceMustBeSelected)
            app.goToSettings()
            return
        }
        if busy { return }
        // SomeTaskHasStarted
        busy = true
        let deviceAddress = SettingsManager.getBluetoothDeviceAddress()
        let baudRate = SettingsManager.getMeterBaudRate()
        do {
            let credits = try await MeterCommunication.beginReadingTransaction(
                deviceAddress: deviceAddress, baudRate: baudRate)
            // UpdateCreditLabels: "F1" invariant values, green + bold.
            credit1 = .value(DoubleFormatter.invariantF1(credits[0]) + " kWh")
            credit2 = .value(DoubleFormatter.invariantF1(credits[1]) + " kWh")
        } catch let error as CommsError {
            taskReadFinished(faultChain: error.chainMessage)
        } catch {
            taskReadFinished(faultChain: "\(error)")
        }
        // SomeTashHasEnded
        busy = false
    }

    /// TaskReadFinished(faulted) mirror: txtError + msgOperationFailed +
    /// complete exception chain.
    private func taskReadFinished(faultChain: String) {
        withAnimation(.easeOut(duration: 0.2)) {
            alert = AlertPresentation(L.ui.txtError, L.message.msgOperationFailed, faultChain)
        }
    }
}

// MARK: - Header

struct ReadingsHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            Text(L.ui.txtCurrentCredits)
                .font(ApaFont.semibold(18))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image("apatoken_logo")
                .resizable()
                .scaledToFit()
                .frame(height: 40)
        }
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .padding(.vertical, 12)
        .background(ApaColor.darkBlue)
    }
}

#Preview {
    ReadingsView()
        .environmentObject(AppState())
}
