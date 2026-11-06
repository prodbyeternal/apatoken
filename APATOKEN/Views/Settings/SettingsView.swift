import SwiftUI

struct SettingsView: View {
    @ObservedObject private var session = MeterSession.shared
    @State private var showMeterPicker = false
    @State private var error: Error?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    MeterSelectorButton(meterName: session.meterName, hasMeter: session.hasMeter) { showMeterPicker = true }
                        .disabled(session.busy)
                } header: { Text(L.ui.txtSectionMeter) } footer: { Text(L.ui.txtSelectPairedMeter) }

                Section {
                    Toggle(isOn: Binding(get: { session.testing }, set: { enabled in
                        do { try session.setTesting(enabled); error = nil } catch { self.error = error }
                    })) { Label(L.text("txtTestingMode"), systemImage: "testtube.2") }
                    .accessibilityIdentifier("testingModeToggle")
                    .disabled(session.busy)
                    if session.testing {
                        NavigationLink { TestingToolsView() } label: {
                            Label(L.text("txtTestingTools"), systemImage: "slider.horizontal.3")
                        }
                    }
                } header: { Text(L.text("txtTestingMode")) } footer: { Text(L.text("msgTestingModeDescription")) }

                Section(L.ui.txtSectionTools) {
                    NavigationLink { PortLogView() } label: { Label(L.ui.txtPortLog, systemImage: "antenna.radiowaves.left.and.right") }
                }
                Section(L.ui.txtSectionDisplay) {
                    LanguageSelectionRow()
                }
                Section(L.ui.txtSectionAbout) {
                    NavigationLink { AboutView() } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L.ui.txtAboutIAPATOKEN)
                            Text(AppVersion.description).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
                if let error { Text(ErrorText.message(error)).foregroundStyle(.red) }
            }
            .navigationTitle(L.ui.txtMenuSettings)
            .sheet(isPresented: $showMeterPicker) { MeterPickerView() }
        }
        .dynamicLocalization()
    }
}

struct LanguageSelectionRow: View {
    @State private var loc = LocalizationManager.shared
    var body: some View {
        NavigationLink {
            List {
                ForEach(LocalizationManager.languages, id: \.tag) { language in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { loc.currentLanguage = language.tag }
                    } label: {
                        HStack {
                            Text(language.name).foregroundStyle(.primary)
                            Spacer()
                            if language.tag == loc.currentLanguage { Image(systemName: "checkmark").foregroundStyle(Color.accentColor) }
                        }
                    }
                    .accessibilityIdentifier("language-" + language.tag)
                }
            }
            .navigationTitle(L.ui.txtLanguage)
            .dynamicLocalization()
        } label: {
            HStack {
                Label(L.ui.txtLanguage, systemImage: "globe")
                Spacer()
                Text(loc.languageName).foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("languageSettings")
    }
}

struct PortLogView: View {
    @State private var logText = ""
    @State private var copied = false
    @ObservedObject private var session = MeterSession.shared

    var body: some View {
        VStack(spacing: 16) {
            if session.testing {
                TestingBanner()
                Text(L.text("msgTestNoBluetooth")).font(.footnote).foregroundStyle(.secondary)
            }
            HStack {
                Button { refresh() } label: { Label(L.text("txtRefresh"), systemImage: "arrow.clockwise") }
                Button { UIPasteboard.general.string = logText; copied = true } label: {
                    Label(copied ? L.text("txtCopied") : L.text("txtCopy"), systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .disabled(logText.isEmpty)
                Button(role: .destructive) { PortLog.shared.clear(); refresh() } label: { Label(L.ui.txtClear, systemImage: "trash") }
                    .disabled(logText.isEmpty)
            }
            if logText.isEmpty {
                ContentUnavailableView(L.text("txtNoLogEntries"), systemImage: "doc.text.magnifyingglass")
            } else {
                ScrollView {
                    Text(logText).font(.system(.caption2, design: .monospaced))
                        .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding()
        .navigationTitle(L.ui.txtPortLog)
        .onAppear { refresh() }
        .onReceive(NotificationCenter.default.publisher(for: PortLog.changedNotification)) { _ in refresh() }
        .dynamicLocalization()
    }

    private func refresh() { logText = session.testing ? "" : PortLog.shared.text(); copied = false }
}
