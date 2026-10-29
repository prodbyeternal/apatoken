import SwiftUI

// MARK: - Main header (app_name + logo + version info button)

struct MainHeader: View {
    let onInfo: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(L.ui.appName)
                .font(ApaFont.semibold(18))
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image("apatoken_logo")
                .resizable()
                .scaledToFit()
                .frame(height: 44)
            Button(action: onInfo) {
                Image(systemName: "info.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .padding(.vertical, 12)
        .background(ApaColor.darkBlue)
    }
}

// MARK: - Token task outcome mirrors

enum TokenTaskOutcome {
    case completed(MeterCommunication.TokenTransactionResult)
    case faulted(CommsError)
}

/// List<T> indexer message of .NET (empty credits accessed on the
/// "OK-format" token statuses).
private let argumentOutOfRangeIndexMessage =
    "Index was out of range. Must be non-negative and less than the size of the collection. (Parameter 'index')"

// MARK: - MainView (MainPage: prepaid recharge keypad)

@MainActor
struct MainView: View {
    @EnvironmentObject private var app: AppState

    private static let maxEntryLength = 24

    @State private var eCode = ""
    @State private var deviceName = ""
    @State private var busy = false
    @State private var entryEnabled = true
    @State private var alert: AlertPresentation?
    @FocusState private var focusedEntry: Bool
    @State private var codeForHistory = ""

    var body: some View {
        VStack(spacing: 0) {
            MainHeader {
                alert = AlertPresentation(L.ui.appName,
                                          "\(L.ui.txtPackageVersion): 1.1\n\(L.ui.txtPublisher): APATOR S.A.")
            }
            ScrollView {
                VStack(spacing: 18) {
                    tokenEntry
                    deviceAndActivity
                    uploadButton
                }
                .padding(16)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .alertPopup($alert)
        .onAppear { updateDeviceName() }
    }

    private var tokenEntry: some View {
        VStack(spacing: 10) {
            Text(L.ui.txtEnterToken)
                .font(ApaFont.semibold(16))
                .multilineTextAlignment(.center)
            TextField("", text: $eCode)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(ApaFont.semibold(28))
                .foregroundStyle(ApaColor.entryText)
                .disabled(!entryEnabled || busy)
                .focused($focusedEntry)
                .padding(.vertical, 14)
                .background(.white)
                .cornerRadius(AppStyle.buttonCorner)
                .overlay(
                    RoundedRectangle(cornerRadius: AppStyle.buttonCorner)
                        .stroke(focusedEntry ? ApaColor.blue : ApaColor.border, lineWidth: 1.4)
                )
                .onChange(of: eCode) { _, newValue in
                    let formatted = Self.enforceEntryFormat(newValue)
                    if formatted != newValue {
                        eCode = formatted
                    }
                }
            if showShortToken {
                Text(L.message.msgTooShortToken)
                    .font(ApaFont.regular(14))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(ApaColor.gray)
            }
        }
    }

    private var showShortToken: Bool {
        var cleared = eCode
        cleared.removeAll { $0 == " " }
        return !cleared.isEmpty && cleared.count != 20
    }

    private var deviceAndActivity: some View {
        VStack(spacing: 12) {
            Text(deviceName.isEmpty ? Self.notSpecifiedDeviceName : deviceName)
                .font(ApaFont.semibold(16))
                .foregroundStyle(ApaColor.gray)
            if !deviceDefined {
                Button(action: {
                    app.goToSettings()
                }) {
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

    private var canUpload: Bool {
        var cleared = eCode
        cleared.removeAll { $0 == " " }
        return cleared.count == 20
    }

    private var uploadButton: some View {
        Button {
            Task { await uploadToken() }
        } label: {
            HStack {
                Spacer()
                Text(L.ui.txtUploadToken)
                    .font(ApaFont.semibold(16))
                Spacer()
            }
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .background(canUpload && !busy ? ApaColor.blue : ApaColor.gray.opacity(0.5))
            .cornerRadius(AppStyle.buttonCorner)
        }
        .buttonStyle(.plain)
        .disabled(!canUpload || busy)
    }

    private var deviceDefined: Bool {
        !deviceName.isEmpty && deviceName != Self.notSpecifiedDeviceName
    }

    private static let notSpecifiedDeviceName = "-----"

    // MARK: - Flows

    /// UpdateDeviceName(): "-----" when no device is stored.
    @discardableResult
    private func updateDeviceName() -> Bool {
        let previousDeviceName = deviceName
        let storedDeviceName = SettingsManager.getBluetoothDeviceName()
        deviceName = storedDeviceName.isEmpty ? Self.notSpecifiedDeviceName : storedDeviceName
        return deviceName != previousDeviceName
    }

    /// FormatEnteredCode / Entry_TextChanged mirror: digits and spaces
    /// only; clear spaces and re-insert after every 4th digit until
    /// eCode.MaxLength (24 chars = 20 digits + 4 spaces).
    static func enforceEntryFormat(_ raw: String) -> String {
        guard raw.range(of: "^[0-9 ]*$", options: .regularExpression) != nil else {
            return ""
        }
        let cleared = raw.filter { $0 != " " }
        var formatted = ""
        for (index, char) in cleared.enumerated() {
            formatted.append(char)
            if (index + 1) % 4 == 0 && (index + 1) != cleared.count {
                formatted.append(" ")
            }
        }
        if formatted.count > maxEntryLength {
            formatted = String(formatted.prefix(maxEntryLength))
        }
        return formatted
    }

    /// ClearEnteredCode.
    static func clearEnteredCode(_ codeToClear: String) -> String {
        String(codeToClear.filter { $0 != " " })
    }

    /// PrepareForTask(msg): device check + busy start (Android-only
    /// permission dialogs are omitted on iOS).
    private func prepareForTask(_ message: String) async -> Bool {
        if !deviceDefined {
            alert = AlertPresentation(L.ui.txtAlertInfo, message)
            app.goToSettings()
            return false
        }
        if busy { return false }
        // SomeTaskHasStarted
        busy = true
        entryEnabled = false
        return true
    }

    private func uploadToken() async {
        guard await prepareForTask(L.message.msgToEnterCodeDeviceMustBeSelected) else { return }
        let token = Self.clearEnteredCode(eCode)
        codeForHistory = eCode // _code = eCode.Text (WITH spaces)
        let deviceAddress = SettingsManager.getBluetoothDeviceAddress()
        let baudRate = SettingsManager.getMeterBaudRate()
        var outcome: TokenTaskOutcome
        do {
            let result = try await MeterCommunication.beginTokenTransaction(
                token: token, deviceAddress: deviceAddress, baudRate: baudRate)
            outcome = .completed(result)
        } catch let error as CommsError {
            outcome = .faulted(error)
        } catch {
            outcome = .faulted(CommsError("\(error)"))
        }
        taskFinished(outcome)
        // SomeTashHasEnded
        busy = false
        entryEnabled = true
    }

    /// TaskFinished(Task<TransactionResult>) mirror, including the
    /// top-level try/catch and the ArgumentException/index errors of the
    /// C# implementation.
    private func taskFinished(_ outcome: TokenTaskOutcome) {
        do {
            try taskFinishedInner(outcome)
        } catch let error as TaskFinishedError {
            withAnimation(.easeOut(duration: 0.2)) {
                alert = AlertPresentation(L.ui.txtError, error.message)
            }
        } catch {
            withAnimation(.easeOut(duration: 0.2)) {
                alert = AlertPresentation(L.ui.txtError, "\(error)")
            }
        }
    }

    private struct TaskFinishedError: Error {
        let message: String
    }

    private func taskFinishedInner(_ outcome: TokenTaskOutcome) throws {
        switch outcome {
        case .completed(let result):
            try handleTransactionResult(result)
        case .faulted(let error):
            // tsk.Status == Faulted → txtError + msgOperationFailed + chain.
            withAnimation(.easeOut(duration: 0.2)) {
                alert = AlertPresentation(L.ui.txtError, L.message.msgOperationFailed, error.chainMessage)
            }
        }
    }

    private func handleTransactionResult(_ result: MeterCommunication.TokenTransactionResult) throws {
        let deliveryStatus = result.deliveryStatus
        // The C# switches on the (byte) enum: unknown raw values land in
        // the default → ArgumentOutOfRangeException(status.ToString()).
        switch deliveryStatus.statusCodeValue {
        case 0, 1, 2, 3: // TOKEN_FORMAT_OK / AUTH_OK / VALIDATION_OK / EXECUTION_OK
            // eCode.Text = ""; – always cleared for the OK-formats.
            eCode = ""
            let credits = result.credits
            // C# reads list[0]/list[1] first; for status codes < 3 the
            // credits list is empty → ArgumentOutOfRangeException.
            if credits.count < 2 {
                throw TaskFinishedError(message: argumentOutOfRangeIndexMessage)
            }
            let creditInRate = DoubleFormatter.invariantF1(credits[0])
            let creditInRate2 = DoubleFormatter.invariantF1(credits[1])
            let tokenDescriptor = TokenDescriptor(dataValue: deliveryStatus.dataValue)
            let codeDescription = tokenDescriptor.getCodeDescription()
            let totalCreditInfo = try Self.getTotalCreditInfo(
                tokenType: tokenDescriptor.codeType, rateId: Int(tokenDescriptor.rateId),
                creditInRate1: creditInRate, creditInRate2: creditInRate2)
            let message2 = L.message.msgOperationSucceeded + "\n\n" + codeDescription
                + "\n\n" + totalCreditInfo
            withAnimation(.easeOut(duration: 0.2)) {
                alert = AlertPresentation(L.ui.txtAlertInfo, message2)
            }
            appendToHistory(tokenDescriptor, credits)
        case 4: // TOKEN_FORMAT_FAILURE
            withAnimation(.easeOut(duration: 0.2)) {
                alert = AlertPresentation(L.ui.txtError,
                                          L.message.msgTokenEnteredButNotAccepted,
                                          L.message.msgEnteredTokenIsWrong)
            }
        case 5, 6, 7, 8: // AUTH_FAILURE / VALIDATION_FAILURE / EXECUTION_FAILURE / RECEIVED_AND_NOT_YET_PROCESSED
            let codeStatusDescription = TokenDescriptor(dataValue: deliveryStatus.dataValue)
                .getCodeStatusDescription()
            // FormatTokenStatusDescription(result) is a dead call in C#
            // (result discarded) – Label2 keeps the raw description.
            withAnimation(.easeOut(duration: 0.2)) {
                alert = AlertPresentation(L.ui.txtError,
                                          L.message.msgTokenEnteredButNotAccepted,
                                          codeStatusDescription)
            }
        default:
            // ArgumentOutOfRangeException(statusCode.ToString()).
            throw TaskFinishedError(message: String(deliveryStatus.statusCodeValue))
        }
    }

    /// GetTotalCreditInfo mirror; the NotImplementedError of the C# is
    /// surfaced through the TaskFinished scope as an error alert with
    /// msgMissingCreditInfo.
    static func getTotalCreditInfo(tokenType: TokenCodeType, rateId: Int,
                                   creditInRate1: String, creditInRate2: String) throws -> String {
        var text = ""
        switch tokenType {
        case .oneRate:
            var value: String
            switch rateId {
            case 0, 1: value = creditInRate1
            case 2: value = creditInRate2
            default: throw TaskFinishedError(message: L.message.msgMissingCreditInfo)
            }
            let displayedRate = rateId == 0 ? 1 : rateId
            text = "\(L.ui.txtTotalCredit):\n- \(L.ui.txtZone) \(displayedRate): \(value) kWh."
        case .bothRates:
            text = "\(L.ui.txtTotalCredit):\n- \(L.ui.txtZone) 1: \(creditInRate1) kWh\n- \(L.ui.txtZone) 2: \(creditInRate2) kWh."
        default:
            break // C# switch has no other case → text stays empty.
        }
        return text
    }

    /// AppendToHistory: HistoryManager.Add(meter = _deviceName,
    /// mac = address, code = _code (WITH spaces), totals = credits,
    /// values = charge rates) with device-culture decimals.
    private func appendToHistory(_ tokenDescriptor: TokenDescriptor, _ credits: [Decimal]) {
        guard deviceDefined, credits.count >= 2 else { return }
        let meter = deviceName
        let mac = SettingsManager.getBluetoothDeviceAddress()
        // _code was captured from eCode.Text in UploadToken (before the
        // success handler clears the entry).
        HistoryManager.add(ChargeModel(meter: meter, mac: mac, code: codeForHistory,
                                       total1: DoubleFormatter.deviceCulture(credits[0]),
                                       total2: DoubleFormatter.deviceCulture(credits[1]),
                                       value1: String(tokenDescriptor.chargeRate1),
                                       value2: String(tokenDescriptor.chargeRate2)))
    }
}

// MARK: - Activity indicator spinner

struct ActivityIndicatorView: View {
    @State private var isAnimating = false

    var body: some View {
        ProgressView()
            .progressViewStyle(.circular)
            .tint(ApaColor.entryText)
            .scaleEffect(1.2)
    }
}

#Preview {
    MainView()
        .environmentObject(AppState())
}
