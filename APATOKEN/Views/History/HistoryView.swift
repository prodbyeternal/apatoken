import SwiftUI

struct HistoryListView: View {
    @ObservedObject private var session = MeterSession.shared
    @State private var selectedTab = 0
    @State private var meterFilter = ""
    @State private var selectedCharge: ChargeModel?
    @State private var selectedReading: ReadingModel?

    var body: some View {
        let charges = session.charges
        let readings = session.readings
        let meters = Array(Set(charges.map(\.meter) + readings.map(\.meter))).sorted()
        let filteredCharges = charges.filter { meterFilter.isEmpty || $0.meter == meterFilter }
        let filteredReadings = readings.filter { meterFilter.isEmpty || $0.meter == meterFilter }

        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    if session.testing { TestingBanner() }
                    Picker(L.ui.txtHistory, selection: $selectedTab.animation(.easeInOut(duration: 0.2))) {
                        Text(L.ui.txtCharges).tag(0)
                        Text(L.ui.txtReadings).tag(1)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("historyTabs")
                    if !meters.isEmpty {
                        HStack {
                            Image(systemName: "line.3.horizontal.decrease")
                            Picker(L.text("txtFilterByMeter"), selection: $meterFilter) {
                                Text(L.ui.txtAll).tag("")
                                ForEach(meters, id: \.self) { Text($0).tag($0) }
                            }
                            .pickerStyle(.menu)
                            .accessibilityIdentifier("historyFilter")
                            Spacer()
                            Text("\(selectedTab == 0 ? filteredCharges.count : filteredReadings.count)")
                                .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 12)

                if selectedTab == 0 && filteredCharges.isEmpty || selectedTab == 1 && filteredReadings.isEmpty {
                    ContentUnavailableView {
                        Label(L.text("txtNoHistory"), systemImage: "clock")
                    } description: { Text(L.message.msgHistoryInformation) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        if selectedTab == 0 {
                            ForEach(filteredCharges) { charge in
                                Button { selectedCharge = charge } label: { HistoryRowView(charge: charge) }
                                    .buttonStyle(.plain)
                            }
                        } else {
                            ForEach(filteredReadings) { reading in
                                Button { selectedReading = reading } label: {
                                    HStack(spacing: 14) {
                                        HistoryBadge(symbol: "gauge.with.dots.needle.33percent", color: .blue)
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(reading.meter).font(.headline)
                                            Text(EnergyText.date(reading.date)).font(.caption).foregroundStyle(.secondary)
                                            Text(EnergyText.kWh(reading.zone1) + " / " + EnergyText.kWh(reading.zone2))
                                                .font(.subheadline.monospacedDigit())
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                                    }
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .contentMargins(.top, 0)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(L.ui.txtHistory)
            .sheet(item: $selectedCharge) { charge in NavigationStack { HistoryDetailView(charge: charge) }.dynamicLocalization() }
            .sheet(item: $selectedReading) { reading in NavigationStack { ReadingDetailView(reading: reading) }.dynamicLocalization() }
            .onChange(of: session.testing) { meterFilter = ""; selectedCharge = nil; selectedReading = nil }
            .onChange(of: meters) { if !meters.contains(meterFilter) { meterFilter = "" } }
            .onAppear { session.retryPendingHistory() }
        }
        .dynamicLocalization()
    }
}

struct HistoryBadge: View {
    let symbol: String
    let color: Color
    var body: some View {
        Image(systemName: symbol).font(.title3.weight(.semibold))
            .foregroundStyle(color).frame(width: 44, height: 44)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct HistoryRowView: View {
    let charge: ChargeModel
    var body: some View {
        HStack(spacing: 14) {
            HistoryBadge(symbol: "bolt.fill", color: .green)
            VStack(alignment: .leading, spacing: 6) {
                Text(charge.meter).font(.headline)
                Text(EnergyText.date(charge.date)).font(.caption).foregroundStyle(.secondary)
                Text(ChargeConverter.chargingValues(charge))
                    .font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(.green)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
    }
}

struct HistoryDetailView: View {
    let charge: ChargeModel
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        Form {
            Section(L.ui.txtRecharge) {
                DetailRow(label: L.ui.txtMeterNumber, value: charge.meter)
                DetailRow(label: L.ui.txtDate, value: EnergyText.date(charge.date))
                DetailRow(label: L.ui.txtCode, value: ChargeConverter.codeMask(charge.code))
            }
            Section(L.text("txtEnergyDelivered")) {
                DetailRow(label: L.ui.txtZone + " 1", value: EnergyText.kWh(charge.value1), bold: true)
                DetailRow(label: L.ui.txtZone + " 2", value: EnergyText.kWh(charge.value2), bold: true)
            }
            Section(L.ui.txtAfterPrepaidRecharge) {
                DetailRow(label: L.ui.txtZone + " 1", value: EnergyText.kWh(charge.total1))
                DetailRow(label: L.ui.txtZone + " 2", value: EnergyText.kWh(charge.total2))
            }
            Section {
                Button(copied ? L.text("txtCopied") : L.text("txtCopyToken")) {
                    UIPasteboard.general.string = charge.code
                    copied = true
                }
            }
        }
        .navigationTitle(L.ui.txtDetails)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L.text("txtDone")) { dismiss() } } }
    }
}

struct ReadingDetailView: View {
    let reading: ReadingModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Form {
            Section {
                DetailRow(label: L.ui.txtMeterNumber, value: reading.meter)
                DetailRow(label: L.ui.txtDate, value: EnergyText.date(reading.date))
            }
            Section(L.ui.txtCurrentCredits) {
                DetailRow(label: L.ui.txtZone + " 1", value: EnergyText.kWh(reading.zone1), bold: true)
                DetailRow(label: L.ui.txtZone + " 2", value: EnergyText.kWh(reading.zone2), bold: true)
            }
        }
        .navigationTitle(L.ui.txtReadings)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L.text("txtDone")) { dismiss() } } }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    var bold = false
    var body: some View {
        LabeledContent(label) {
            Text(value).fontWeight(bold ? .semibold : .regular).foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
    }
}
