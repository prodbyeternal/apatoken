import SwiftUI
import Combine

// MARK: - Token flow coordinator

@MainActor
final class TokenFlowCoordinator: ObservableObject {
    @Published var token = ""
    @Published var isSubmitting = false
    @Published var showSuccess = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var meterName: String = ""
    @Published var showMeterPicker = false
    @Published var showLanguagePicker = false

    var hasMeter: Bool {
        !meterName.isEmpty && meterName != L.ui.txtNoMeterSelected
    }

    var canPaste: Bool {
        guard let text = UIPasteboard.general.string else { return false }
        let digits = text.filter { $0.isNumber }
        return digits.count == 20
    }

    var canSubmit: Bool {
        token.filter({ $0.isNumber }).count == 20 && hasMeter && !isSubmitting
    }

    func updateToken(_ newToken: String) {
        token = String(newToken.filter { $0.isNumber }.prefix(20))
        if showError {
            showError = false
        }
    }

    func pasteFromClipboard() -> Bool {
        guard let text = UIPasteboard.general.string else { return false }
        let digits = text.filter { $0.isNumber }
        if digits.count == 20 {
            token = digits
            return true
        }
        return false
    }

    func clearToken() {
        token = ""
    }

    func selectMeter() {
        showMeterPicker = true
    }

    func submitToken() async {
        guard canSubmit else { return }

        isSubmitting = true

        do {
            let result = try await MeterCommunication.beginTokenTransaction(
                token: token.filter { $0.isNumber },
                deviceAddress: SettingsManager.getBluetoothDeviceAddress(),
                baudRate: SettingsManager.getMeterBaudRate()
            )

            switch result.deliveryStatus.statusCodeValue {
            case 0, 1, 2, 3:
                await MainActor.run {
                    showSuccess = true
                    isSubmitting = false
                    token = ""
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run {
                    showSuccess = false
                }

            case 4:
                await MainActor.run {
                    showError = true
                    errorMessage = L.message.msgTokenEnteredButNotAccepted
                    isSubmitting = false
                }

            default:
                await MainActor.run {
                    showError = true
                    errorMessage = L.message.msgOperationFailed
                    isSubmitting = false
                }
            }
        } catch let error as CommsError {
            await MainActor.run {
                showError = true
                errorMessage = error.chainMessage
                isSubmitting = false
            }
        } catch {
            await MainActor.run {
                showError = true
                errorMessage = String(describing: error)
                isSubmitting = false
            }
        }
    }
}

// MARK: - Token flow view

struct TokenFlowView: View {
    @StateObject private var coordinator = TokenFlowCoordinator()
    @EnvironmentObject private var app: AppState

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with title and meter selector
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(L.ui.txtRecharge)
                            .font(.largeTitle.bold())
                            .foregroundStyle(Color.primary)
                        Spacer()
                        Image("apatoken_logo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 28)
                    }
                    .padding(.horizontal)

                    // Meter selector - tappable button
                    MeterSelectorButton(
                        meterName: coordinator.meterName,
                        hasMeter: coordinator.hasMeter
                    ) {
                        coordinator.selectMeter()
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 16)

                // Token input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Token Number")
                        .font(.caption)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.secondary)

                    TextField("Enter 20-digit token", text: $coordinator.token)
                        .keyboardType(.numberPad)
                        .font(.system(size: 18, design: .monospaced))
                        .padding(16)
                        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color(UIColor.separator).opacity(0.3), lineWidth: 0.5)
                        )
                }
                .padding(.horizontal)
                .padding(.top, 12)

                // Paste / Clear buttons
                HStack(spacing: 24) {
                    Button {
                        _ = coordinator.pasteFromClipboard()
                    } label: {
                        Label("Paste", systemImage: "doc.on.doc")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(coordinator.canPaste ? Color.accentColor : Color.secondary)
                    }
                    .disabled(!coordinator.canPaste)

                    Button {
                        coordinator.clearToken()
                    } label: {
                        Label("Clear", systemImage: "trash")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.secondary)
                    }
                    .disabled(coordinator.token.isEmpty)
                }
                .padding(.horizontal)
                .padding(.top, 12)

                Spacer()

                // Submit button
                Button {
                    Task { await coordinator.submitToken() }
                } label: {
                    if coordinator.isSubmitting {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                    } else {
                        Label("Apply Token", systemImage: "arrow.up.circle.fill")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                    }
                }
                .buttonStyle(.plain)
                .background(
                    coordinator.canSubmit && !coordinator.isSubmitting
                        ? Color.accentColor
                        : Color(UIColor.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .disabled(!coordinator.canSubmit || coordinator.isSubmitting)
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $coordinator.showMeterPicker) {
                MeterPickerView { selectedDevice in
                    if let device = selectedDevice {
                        coordinator.meterName = device.shortName
                    }
                }
            }
            .overlay(
                SuccessConfirmationView(isPresented: $coordinator.showSuccess)
            )
            .overlay(
                ErrorBannerView(
                    isPresented: $coordinator.showError,
                    message: coordinator.errorMessage
                )
            )
            .onAppear {
                coordinator.meterName = SettingsManager.getBluetoothDeviceName().isEmpty
                    ? L.ui.txtNoMeterSelected
                    : SettingsManager.getBluetoothDeviceName()
            }
        }
    }
}

// MARK: - Meter selector button

struct MeterSelectorButton: View {
    let meterName: String
    let hasMeter: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                Circle()
                    .fill(hasMeter ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(Color(UIColor.separator), lineWidth: 0.5)
                    )
                    .overlay(
                        Image(systemName: hasMeter ? "powermeter" : "questionmark")
                            .foregroundStyle(hasMeter ? .white : Color.secondary)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Meter")
                        .font(.caption)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.secondary)

                    Text(hasMeter ? meterName : L.ui.txtNoMeterSelected)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(hasMeter ? Color.primary : Color.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(UIColor.tertiarySystemFill))
            }
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Success confirmation overlay

struct SuccessConfirmationView: View {
    @Binding var isPresented: Bool

    var body: some View {
        if isPresented {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(Color.green)

                        Text("Token Applied!")
                            .font(.headline.weight(.semibold))

                        Text("Electricity has been added to your meter.")
                            .font(.subheadline)
                            .foregroundStyle(Color.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 24)
                    .background(Color(UIColor.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(0.2), radius: 24, y: 8)
                    Spacer()
                }
            }
            .ignoresSafeArea()
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            .onTapGesture {
                isPresented = false
            }
        }
    }
}

// MARK: - Error banner

struct ErrorBannerView: View {
    @Binding var isPresented: Bool
    let message: String

    var body: some View {
        if isPresented {
            VStack {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.red)
                        .font(.system(size: 18, weight: .semibold))

                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.leading)

                    Spacer()
                }
                .padding()
                .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal)
            }
            .padding(.top, 12)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

#Preview {
    TokenFlowView()
        .environmentObject(AppState())
}
