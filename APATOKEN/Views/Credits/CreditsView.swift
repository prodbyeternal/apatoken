import SwiftUI
import Combine

// MARK: - Credits view model

@MainActor
final class CreditsViewModel: ObservableObject {
    @Published var micStatus: BLEConnectionStatus = .disconnected(name: L.ui.txtNoMeterSelected)
    @Published var creditZone1: CreditsDisplay = .placeholder
    @Published var creditZone2: CreditsDisplay = .placeholder
    @Published var isReading = false
    @Published var lastUpdate: Date?

    // MARK: - Credit display states

    enum CreditsDisplay: Equatable {
        case placeholder
        case value(String, String) // zone1, zone2
        case error(String)
    }

    enum BLEConnectionStatus {
        case connecting(deviceName: String)
        case connected(deviceName: String)
        case disconnected(name: String)
        case failed(String)
    }

    // MARK: - Actions

    func readCredits() async {
        guard case .connected = micStatus else { return }
        isReading = true
        do {
            let credits = try await MeterCommunication.beginReadingTransaction(
                deviceAddress: SettingsManager.getBluetoothDeviceAddress(),
                baudRate: SettingsManager.getMeterBaudRate()
            )
            let formatter = NumberFormatter()
            formatter.minimumFractionDigits = 1
            formatter.maximumFractionDigits = 1

            let c1 = formatter.string(from: NSDecimalNumber(decimal: credits[0])) ?? "0.0"
            let c2 = formatter.string(from: NSDecimalNumber(decimal: credits[1])) ?? "0.0"

            await MainActor.run {
                creditZone1 = .value(c1 + " kWh", c2 + " kWh")
                creditZone2 = .value(c2 + " kWh", c1 + " kWh")
                isReading = false
                lastUpdate = Date()
            }
        } catch let error as CommsError {
            await MainActor.run {
                creditZone1 = .error(error.chainMessage)
                creditZone2 = .error(error.chainMessage)
                isReading = false
            }
        } catch {
            await MainActor.run {
                creditZone1 = .error(String(describing: error))
                creditZone2 = .error(String(describing: error))
                isReading = false
            }
        }
    }
}

// MARK: - Credits view

struct CreditsView: View {
    @StateObject private var viewModel = CreditsViewModel()
    @EnvironmentObject private var app: AppState

    var body: some View {
        VStack(spacing: 24) {
            // Header with title - top aligned
            Text(L.ui.txtReadings)
                .font(.largeTitle.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            // Connection status header
            ConnectionStatusHeader(status: viewModel.micStatus)

            // Credit zones
            VStack(spacing: 16) {
                CreditZoneCard(
                    title: L.ui.txtZone + " 1",
                    display: viewModel.creditZone1,
                    animationState: viewModel.isReading ? .animating : .idle
                )

                CreditZoneCard(
                    title: L.ui.txtZone + " 2",
                    display: viewModel.creditZone2,
                    animationState: viewModel.isReading ? .animating : .idle
                )
            }

            // Read button or connecting indicator
            if case .connecting = viewModel.micStatus {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Color.accentColor)
                    .scaleEffect(1.3)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
            } else if case .connected = viewModel.micStatus {
                Button {
                    Task { await viewModel.readCredits() }
                } label: {
                    Label {
                        Text(L.ui.txtReadCredits)
                            .fontWeight(.semibold)
                    } icon: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .frame(maxWidth: .infinity)
                    .font(.callout)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isReading)
                .opacity(viewModel.isReading ? 0.6 : 1.0)
            }

            // Last updated
            if let lastUpdate = viewModel.lastUpdate {
                Text(L.ui.txtLastUpdated + " " + formatDate(lastUpdate))
                    .font(.caption2)
                    .foregroundStyle(Color.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .task {
            await checkMeterConnection()
        }
        .onAppear {
            Task { await checkMeterConnection() }
        }
        .dynamicLocalization()
    }

    private func checkMeterConnection() async {
        let deviceName = SettingsManager.getBluetoothDeviceName()
        if !deviceName.isEmpty {
            viewModel.micStatus = .connected(deviceName: deviceName)
        } else {
            viewModel.micStatus = .disconnected(name: L.ui.txtNoMeterSelected)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Connection status header

struct ConnectionStatusHeader: View {
    let status: CreditsViewModel.BLEConnectionStatus

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator dot
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
                .shadow(color: statusColor.opacity(0.5), radius: 4)

            Text(statusTitle)
                .font(.headline)
                .foregroundStyle(Color.primary)

            Spacer()

            if case .connecting = status {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.small)
                    .tint(Color.secondary)
            }
        }
        .padding(.horizontal, 4)
    }

    private var statusTitle: String {
        switch status {
        case .connecting: return L.message.msgStayCloseToTheMeter
        case .connected(let name): return name
        case .disconnected(let name): return name
        case .failed(let msg): return msg
        }
    }

    private var statusColor: Color {
        switch status {
        case .connecting: return Color.orange
        case .connected: return Color.green
        case .disconnected: return Color.red
        case .failed: return Color.red
        }
    }
}

// MARK: - Credit zone card

enum CreditAnimationState {
    case idle
    case animating
    case success
    case error
}

struct CreditZoneCard: View {
    let title: String
    let display: CreditsViewModel.CreditsDisplay
    let animationState: CreditAnimationState

    @State private var pulseScale: CGFloat = 1.0
    @State private var shimmerOffset: CGFloat = -200

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Text(title)
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(Color.secondary)
                .fontWeight(.medium)

            // Value with animation
            Group {
                switch display {
                case .placeholder:
                    CreditPlaceholderView()

                case .value(let zone1, _):
                    CreditValueView(value: zone1)
                        .transition(.asymmetric(insertion: .opacity, removal: .opacity))

                case .error(let error):
                    CreditErrorView(error: error)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(UIColor.separator), lineWidth: 0.5)
        )
        .onChange(of: animationState) { oldValue, newValue in
            animateStateChange(from: oldValue, to: newValue)
        }
    }

    private func animateStateChange(from old: CreditAnimationState, to new: CreditAnimationState) {
        if new == .success {
            // Pulse green + shimmer
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                pulseScale = 1.05
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    pulseScale = 1.0
                }
            }
        } else if new == .error {
            // Shake
            withAnimation(.interactiveSpring) {
                shimmerOffset = 10
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring()) {
                    shimmerOffset = 0
                }
            }
        }
    }
}

struct CreditPlaceholderView: View {
    var body: some View {
        ProgressView()
            .progressViewStyle(.circular)
            .tint(Color.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CreditValueView: View {
    let value: String

    var body: some View {
        Text(value)
            .font(.largeTitle.bold())
            .foregroundStyle(Color.primary)
            .transition(.opacity)
            .id("credit_\(value)")
    }
}

struct CreditErrorView: View {
    let error: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.red)
                .font(.system(size: 16))

            Text(error)
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview

#Preview {
    CreditsView()
        .environmentObject(AppState())
}
