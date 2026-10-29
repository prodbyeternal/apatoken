import SwiftUI

// MARK: - Settings view

struct SettingsView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Device section
                Section {
                    MeterSelectionRow {
                        app.goToSettings()
                    }
                } header: {
                    Text("Meter")
                        .textCase(.uppercase)
                        .font(.caption)
                } footer: {
                    Text("Select a paired APATOR meter for token operations.")
                }

                // MARK: - Tools section
                Section {
                    NavigationLink(destination: PortLogView()) {
                        Label("Port Log", systemImage: "antenna.radiowaves.left.and.right")
                    }
                } header: {
                    Text("Tools")
                        .textCase(.uppercase)
                        .font(.caption)
                }

                // MARK: - Language section
                Section {
                    LanguageSelectionRow()
                } header: {
                    Text("Display")
                        .textCase(.uppercase)
                        .font(.caption)
                }

                // MARK: - About section
                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        AboutRow(
                            title: L.ui.txtAboutIAPATOKEN,
                            version: "1.1",
                            publisher: "APATOR S.A."
                        )
                    }
                } header: {
                    Text("About")
                        .textCase(.uppercase)
                        .font(.caption)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(L.ui.txtMenuSettings)
            .background(Color(UIColor.systemGroupedBackground))
        }
        .dynamicLocalization()
    }
}

// MARK: - Meter selection row

struct MeterSelectionRow: View {
    @State private var deviceName: String = ""
    @State private var deviceAddress: String = ""

    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(deviceName.isEmpty ? Color(UIColor.secondarySystemGroupedBackground) : Color.accentColor)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(Color(UIColor.separator), lineWidth: 0.5)
                        )

                    if deviceName.isEmpty {
                        Image(systemName: "questionmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.secondary)
                    } else {
                        Image(systemName: "powermeter")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Meter")
                        .font(.caption)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.secondary)

                    Text(deviceName.isEmpty ? "Not configured" : deviceName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(deviceName.isEmpty ? Color.secondary : Color.primary)

                    if !deviceAddress.isEmpty {
                        Text(deviceAddress)
                            .font(.caption)
                            .foregroundStyle(Color(UIColor.tertiarySystemFill))
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(UIColor.tertiarySystemFill))
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            loadDevice()
        }
    }

    private func loadDevice() {
        deviceName = SettingsManager.getBluetoothDeviceName()
        deviceAddress = SettingsManager.getBluetoothDeviceAddress()
    }
}

// MARK: - Language selection row

struct LanguageSelectionRow: View {
    @StateObject private var loc = LocalizationManager.shared
    @State private var languages: [(name: String, tag: String)] = []
    @State private var showLanguagePicker = false

    var body: some View {
        Button {
            showLanguagePicker = true
        } label: {
            HStack {
                Label(L.ui.txtLanguage, systemImage: "globe")
                Spacer()
                Text(currentLanguageName)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color(UIColor.tertiarySystemFill))
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showLanguagePicker) {
            NavigationStack {
                List {
                    ForEach(Array(languages.enumerated()), id: \.offset) { index, language in
                        HStack {
                            Text(language.name)
                            Spacer()
                            if language.tag == loc.currentLanguage {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            loc.currentLanguage = language.tag
                            loadLanguages()
                            showLanguagePicker = false
                        }
                    }
                }
                .listStyle(.plain)
                .navigationTitle(L.ui.txtLanguage)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L.ui.txtClose) {
                            showLanguagePicker = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .onAppear {
            loadLanguages()
        }
    }

    private var currentLanguageName: String {
        let currentTag = loc.currentLanguage
        return languages.first { $0.tag == currentTag }?.name ?? "English"
    }

    private func loadLanguages() {
        languages = [
            (name: "English", tag: "en"),
            (name: "Polski", tag: "pl"),
            (name: "Français", tag: "fr"),
        ]
    }
}

// MARK: - About row

struct AboutRow: View {
    let title: String
    let version: String
    let publisher: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 16, weight: .medium))

            Text("\(publisher) • v\(version)")
                .font(.footnote)
                .foregroundStyle(Color.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
}

// MARK: - Port log view

struct PortLogView: View {
    @State private var logText: String = ""
    @State private var copySuccess = false

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button {
                    logText = PortLog.shared.text()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Button {
                    UIPasteboard.general.string = logText
                    copySuccess = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        copySuccess = false
                    }
                } label: {
                    Label(copySuccess ? "Copied!" : "Copy", systemImage: copySuccess ? "checkmark" : "doc.on.doc")
                }
                .disabled(logText.isEmpty)

                Button(role: .destructive) {
                    PortLog.shared.clear()
                    logText = PortLog.shared.text()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .disabled(logText.isEmpty)

                Spacer()
            }

            if logText.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundStyle(Color(UIColor.tertiarySystemFill))

                    Text("No log entries yet")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        Text(logText)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Color.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .id("log_bottom")
                    }
                    .onAppear {
                        proxy.scrollTo("log_bottom", anchor: .bottom)
                    }
                }
            }
        }
        .padding()
        .navigationTitle("Port Log")
        .background(Color(UIColor.systemGroupedBackground))
        .onAppear {
            logText = PortLog.shared.text()
        }
        .onReceive(NotificationCenter.default.publisher(for: PortLog.changedNotification)) { _ in
            logText = PortLog.shared.text()
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AppState())
    }
}
