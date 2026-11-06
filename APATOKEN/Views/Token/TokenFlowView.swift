import SwiftUI

struct TokenFlowView: View {
    @ObservedObject private var session = MeterSession.shared
    @State private var token = ""
    @State private var error: Error?
    @State private var receipt: RechargeReceipt?
    @State private var showMeterPicker = false
    @State private var showGenerator = false
    @FocusState private var tokenFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var canSubmit: Bool { TokenInput.isValid(token) && session.hasMeter && !session.busy }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if session.testing { TestingBanner() }
                    MeterSelectorButton(meterName: session.meterName, hasMeter: session.hasMeter) {
                        tokenFocused = false
                        showMeterPicker = true
                    }
                    .disabled(session.busy)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(L.ui.txtTokenNumber)
                            .font(.caption).foregroundStyle(.secondary)
                        TextField(L.ui.txtEnterTokenPlaceholder, text: Binding(
                            get: { token },
                            set: { token = TokenInput.normalize($0); error = nil; receipt = nil }
                        ))
                        .accessibilityIdentifier("tokenInput")
                        .keyboardType(.numberPad)
                        .focused($tokenFocused)
                        .font(.system(.body, design: .monospaced))
                        .padding(16)
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                        .disabled(session.busy)
                        Text("\(token.count)/20")
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    HStack(spacing: 24) {
                        Button {
                            tokenFocused = false
                            token = TokenInput.normalize(UIPasteboard.general.string ?? "")
                            error = nil
                            receipt = nil
                        } label: { Label(L.ui.txtPaste, systemImage: "doc.on.doc") }
                        Button {
                            tokenFocused = false
                            token = ""
                            error = nil
                            receipt = nil
                        } label: { Label(L.ui.txtClear, systemImage: "trash") }
                        .disabled(token.isEmpty)
                    }
                    .disabled(session.busy)

                    if session.testing {
                        Button {
                            tokenFocused = false
                            showGenerator = true
                        } label: { Label(L.text("txtTestTokens"), systemImage: "ticket") }
                        .accessibilityIdentifier("testTokens")
                        .disabled(session.busy)
                    }

                    if let error {
                        Label(ErrorText.message(error), systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("tokenError")
                    }
                    if let receipt {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(L.ui.txtTokenApplied, systemImage: "checkmark.circle.fill")
                                .font(.headline).foregroundStyle(.green)
                            Text(L.ui.txtTokenAppliedSuccess)
                            Text(ChargeConverter.chargingValues(receipt.charge))
                                .monospacedDigit()
                            if let warning = receipt.warning {
                                Text(ErrorText.message(warning)).foregroundStyle(.orange)
                            }
                        }
                        .accessibilityIdentifier("rechargeSuccess")
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                Button {
                    tokenFocused = false
                    let submitted = token
                    withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85)) {
                        session.rechargePresentation = .working(session.meterName)
                    }
                    Task {
                        error = nil
                        receipt = nil
                        // Give the card time to present, including for immediate local test results.
                        try? await Task.sleep(for: .milliseconds(650))
                        do {
                            let result = try await session.recharge(submitted)
                            receipt = result
                            token = ""
                            session.rechargePresentation = .success(result)
                        } catch {
                            self.error = error
                            session.rechargePresentation = .failure(error)
                        }
                    }
                } label: {
                    HStack {
                        if session.busy { ProgressView() }
                        Label(L.ui.txtApplyToken, systemImage: "arrow.up.circle.fill")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                }
                .accessibilityIdentifier("applyToken")
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit)
                .padding()
                .background(.bar)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(L.ui.txtRecharge)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    BundleImage(name: "apatoken_logo.png").scaledToFit().frame(width: 100, height: 22)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L.text("txtDone")) { tokenFocused = false }
                        .accessibilityIdentifier("hideKeyboard")
                }
            }
            .sheet(isPresented: $showMeterPicker) { MeterPickerView() }
            .sheet(isPresented: $showGenerator) {
                NavigationStack {
                    TestingToolsView { generated in
                        token = generated
                        error = nil
                        receipt = nil
                        showGenerator = false
                    }
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L.ui.txtClose) { showGenerator = false } } }
                }
                .dynamicLocalization()
            }
            .onChange(of: session.contextID) {
                tokenFocused = false
                token = ""
                receipt = nil
                error = nil
            }
            .onDisappear { tokenFocused = false }
        }
        .dynamicLocalization()
    }
}

struct MeterSelectorButton: View {
    let meterName: String
    let hasMeter: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                Image(systemName: hasMeter ? "powermeter" : "questionmark")
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(hasMeter ? Color.accentColor : Color.gray, in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(L.ui.txtMeterNumber).font(.caption).foregroundStyle(.secondary)
                    Text(hasMeter ? meterName : L.ui.txtNoMeterSelected).font(.headline)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("meterSelector")
    }
}
