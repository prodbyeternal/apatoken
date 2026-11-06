import SwiftUI

struct TestingBanner: View {
    var body: some View {
        Label(L.text("txtTestingMode"), systemImage: "testtube.2")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.orange)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("testingBanner")
    }
}

struct TestingToolsView: View {
    @ObservedObject private var session = MeterSession.shared
    @State private var zone = 1
    @State private var error: Error?
    @State private var copiedCode: String?
    @State private var showReset = false
    var useToken: ((String) -> Void)?

    var body: some View {
        Form {
            Section {
                TestingBanner()
                Text(L.text("msgTestingModeDescription"))
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if session.testing, let state = session.testState {
                Section(L.ui.txtSectionMeter) {
                    Picker(L.ui.txtMeterNumber, selection: Binding(get: { session.meterID }, set: { id in
                        perform { try session.select(name: "", id: id) }
                    })) {
                        ForEach(state.meters) { meter in Text(meter.number).tag(meter.id) }
                    }
                    if let meter = state.meters.first(where: { $0.id == session.meterID }) {
                        Toggle(L.text("txtTestMeterOnline"), isOn: Binding(get: { meter.online }, set: { online in
                            perform { try session.setOnline(online) }
                        }))
                        DetailRow(label: L.ui.txtZone + " 1", value: EnergyText.kWh(SimulatedEnvironment.energy(meter.zone1)))
                        DetailRow(label: L.ui.txtZone + " 2", value: EnergyText.kWh(SimulatedEnvironment.energy(meter.zone2)))
                        Button(L.text("txtSimulateUsage")) { perform { try session.consume() } }
                    }
                }
                Section(L.text("txtGenerateToken")) {
                    Picker(L.ui.txtTariffZone, selection: $zone) {
                        Text(L.ui.txtZone + " 1").tag(1)
                        Text(L.ui.txtZone + " 2").tag(2)
                        Text(L.text("txtBothZones")).tag(0)
                    }
                    Button(L.text("txtGenerateToken")) { perform { _ = try session.generate(zone: zone) } }
                        .accessibilityIdentifier("generateToken")
                    Text(L.text("msgGeneratedTokensOnly"))
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section(L.text("txtTestTokens")) {
                    if state.tokens.isEmpty { Text(L.text("txtNoTestTokens")) }
                    ForEach(state.tokens) { token in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(token.code).font(.callout.monospaced()).textSelection(.enabled)
                            Text((state.meters.first { $0.id == token.meterID }?.number ?? "") + " • " + EnergyText.kWh(SimulatedEnvironment.energy(token.zone1 + token.zone2)))
                                .font(.caption).foregroundStyle(.secondary)
                            Text(token.redeemed == nil ? L.text("txtTokenUnused") : L.text("txtTokenUsed"))
                                .font(.caption).foregroundStyle(token.redeemed == nil ? .green : .secondary)
                            HStack {
                                Button(copiedCode == token.code ? L.text("txtCopied") : L.text("txtCopy")) {
                                    UIPasteboard.general.string = token.code
                                    copiedCode = token.code
                                }
                                .buttonStyle(.borderless)
                                if let useToken {
                                    Button(L.text("txtUseToken")) { useToken(token.code) }
                                        .buttonStyle(.borderless)
                                        .accessibilityIdentifier("useTestToken")
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                Section {
                    Button(L.text("txtResetTesting"), role: .destructive) { showReset = true }
                }
            }
            if let error { Text(ErrorText.message(error)).foregroundStyle(.red) }
        }
        .disabled(session.busy)
        .navigationTitle(L.text("txtTestingTools"))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(L.text("msgResetTesting"), isPresented: $showReset, titleVisibility: .visible) {
            Button(L.text("txtResetTesting"), role: .destructive) { perform { try session.resetTesting() } }
            Button(L.ui.txtCancel, role: .cancel) {}
        }
        .dynamicLocalization()
    }

    private func perform(_ action: () throws -> Void) {
        do { try action(); error = nil } catch { self.error = error }
    }
}
