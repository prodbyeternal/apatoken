import SwiftUI

struct CreditsView: View {
    @ObservedObject private var session = MeterSession.shared
    @State private var reading: ReadingModel?
    @State private var error: Error?
    @State private var warning: AppFailure?
    @State private var showMeterPicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if session.testing { TestingBanner() }
                    MeterSelectorButton(meterName: session.meterName, hasMeter: session.hasMeter) { showMeterPicker = true }
                        .disabled(session.busy)
                    ForEach(1...2, id: \.self) { zone in
                        VStack(alignment: .leading, spacing: 12) {
                            Label(L.ui.txtZone + " \(zone)", systemImage: "bolt.fill")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Text(reading.map { EnergyText.kWh(zone == 1 ? $0.zone1 : $0.zone2) } ?? "—")
                                .font(.largeTitle.bold()).monospacedDigit()
                                .contentTransition(.numericText())
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
                    }
                    Button {
                        Task {
                            error = nil
                            warning = nil
                            do {
                                let result = try await session.read()
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { reading = result.0 }
                                warning = result.1
                            } catch { self.error = error }
                        }
                    } label: {
                        HStack {
                            if session.busy { ProgressView() }
                            Label(L.ui.txtReadCredits, systemImage: "arrow.clockwise")
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("readCredits")
                    .disabled(!session.hasMeter || session.busy)
                    if let reading {
                        Text(L.ui.txtLastUpdated + " " + EnergyText.date(reading.date))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if let error { Label(ErrorText.message(error), systemImage: "exclamationmark.triangle").foregroundStyle(.red) }
                    if let warning { Text(ErrorText.message(warning)).foregroundStyle(.orange) }
                }
                .padding()
            }
            .navigationTitle(L.ui.txtReadings)
            .background(Color(uiColor: .systemGroupedBackground))
            .sheet(isPresented: $showMeterPicker) { MeterPickerView() }
            .onChange(of: session.contextID) { reading = nil; error = nil; warning = nil }
        }
        .dynamicLocalization()
    }
}
