import SwiftUI
import Combine

// MARK: - History view model

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var charges: [ChargeModel] = []
    @Published var readings: [ReadingModel] = []
    @Published var meters: [String] = []
    @Published var selectedMeterIndex = 0
    @Published var selectedCharge: ChargeModel?
    @Published var selectedTab: Int = 0 // 0 = Charges, 1 = Readings

    var selectedMeterName: String {
        meters.indices.contains(selectedMeterIndex) ? meters[selectedMeterIndex] : ""
    }

    var filteredCharges: [ChargeModel] {
        if selectedMeterName.isEmpty || selectedMeterName == "All" {
            return charges
        }
        return charges.filter { $0.meter == selectedMeterName }
    }

    var filteredReadings: [ReadingModel] {
        if selectedMeterName.isEmpty || selectedMeterName == "All" {
            return readings
        }
        return readings.filter { $0.meter == selectedMeterName }
    }

    func loadHistory() {
        charges = HistoryManager.readAll()
        readings = ReadingHistoryManager.readAll()
        updateMeters()
    }

    private func updateMeters() {
        var uniqueMeters: [String] = []
        for charge in charges {
            if !uniqueMeters.contains(charge.meter) {
                uniqueMeters.append(charge.meter)
            }
        }
        for reading in readings {
            if !uniqueMeters.contains(reading.meter) {
                uniqueMeters.append(reading.meter)
            }
        }
        meters = ["All"] + uniqueMeters
        if meters.count > 1 {
            selectedMeterIndex = 0
        }
    }
}

// MARK: - History view (iOS 26 style)

struct HistoryListView: View {
    @StateObject private var viewModel = HistoryViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Subtab selector
                HistorySegmentedControl(selectedTab: $viewModel.selectedTab)

                VStack(spacing: 0) {
                    if viewModel.selectedTab == 0 {
                        // Charges tab
                        if viewModel.charges.isEmpty {
                            HistoryEmptyStateView()
                        } else {
                            ChargesList(viewModel: viewModel)
                        }
                    } else {
                        // Readings tab
                        if viewModel.readings.isEmpty {
                            HistoryEmptyStateView()
                        } else {
                            ReadingsList(viewModel: viewModel)
                        }
                    }
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(L.ui.txtHistory)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if !viewModel.charges.isEmpty {
                        Menu {
                            Button(L.ui.txtPickValue) {
                                // Meter filter sheet would go here
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                        }
                    }
                }
            }
            .sheet(item: $viewModel.selectedCharge) { charge in
                NavigationStack {
                    HistoryDetailView(charge: charge)
                }
            }
            .onAppear {
                viewModel.loadHistory()
            }
            .dynamicLocalization()
        }
    }
}

// MARK: - Segmented control for subtabs

struct HistorySegmentedControl: View {
    @Binding var selectedTab: Int

    var body: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTab = 0
                }
            } label: {
                VStack(spacing: 6) {
                    Text(L.ui.txtCharges)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(selectedTab == 0 ? Color.primary : Color.secondary)

                    Rectangle()
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(selectedTab == 0 ? Color.accentColor : Color.clear)
                }
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTab = 1
                }
            } label: {
                VStack(spacing: 6) {
                    Text(L.ui.txtReadings)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(selectedTab == 1 ? Color.primary : Color.secondary)

                    Rectangle()
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(selectedTab == 1 ? Color.accentColor : Color.clear)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemGroupedBackground))
    }
}

// MARK: - Charges list

struct ChargesList: View {
    @ObservedObject var viewModel: HistoryViewModel

    var body: some View {
        List {
            // Meter filter section
            if viewModel.meters.count > 1 {
                Section {
                    Menu {
                        ForEach(Array(viewModel.meters.enumerated()), id: \.offset) { index, meter in
                            Button(meter) {
                                viewModel.selectedMeterIndex = index
                            }
                            .tag(index)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "powermeter")
                            Text(viewModel.selectedMeterName.isEmpty ? "All" : viewModel.selectedMeterName)
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                    }
                } header: {
                    Text("Filter by meter")
                        .font(.caption)
                }
            }

            // Charge rows
            Section {
                ForEach(viewModel.filteredCharges) { charge in
                    Button {
                        viewModel.selectedCharge = charge
                    } label: {
                        HistoryRowView(charge: charge)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Readings list

struct ReadingsList: View {
    @ObservedObject var viewModel: HistoryViewModel

    var body: some View {
        List {
            // Meter filter section
            if viewModel.meters.count > 1 {
                Section {
                    Menu {
                        ForEach(Array(viewModel.meters.enumerated()), id: \.offset) { index, meter in
                            Button(meter) {
                                viewModel.selectedMeterIndex = index
                            }
                            .tag(index)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "powermeter")
                            Text(viewModel.selectedMeterName.isEmpty ? "All" : viewModel.selectedMeterName)
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                    }
                } header: {
                    Text("Filter by meter")
                        .font(.caption)
                }
            }

            // Reading rows
            Section {
                ForEach(viewModel.filteredReadings) { reading in
                    ReadingsRowView(reading: reading)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - History row

struct HistoryRowView: View {
    let charge: ChargeModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Date
            Text(ChargeConverter.dateText(charge))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.primary)

            // Charging type + values
            HStack(spacing: 8) {
                Image(systemName: charge.chargingIcon)
                    .font(.system(size: 14))
                    .foregroundStyle(charge.chargingColor)

                Text(ChargeConverter.chargingType(charge))
                    .font(.caption)
                    .foregroundStyle(charge.chargingColor)

                Text(ChargeConverter.chargingValues(charge))
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.secondary)
            }
            .padding(.top, 2)

            // Code
            Text(ChargeConverter.codeMask(charge.code))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Color.secondary)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Readings history row

struct ReadingsRowView: View {
    let reading: ReadingModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(reading.date.formatted(date: .abbreviated, time: .shortened))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.primary)

            HStack(spacing: 8) {
                Image(systemName: "powermeter")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.blue)

                Text("\(reading.zone1) kWh / \(reading.zone2) kWh")
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.secondary)
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Empty state

struct HistoryEmptyStateView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "clock.badge.xmark")
                .font(.system(size: 64))
                .foregroundStyle(Color(UIColor.tertiarySystemFill))

            VStack(spacing: 8) {
                Text(L.ui.txtHistory)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.primary)

                Text(L.message.msgHistoryInformation)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, -40)
    }
}

// MARK: - History detail view

struct HistoryDetailView: View {
    let charge: ChargeModel

    var body: some View {
        Form {
            Section("Energy Token Purchase") {
                DetailRow(label: "Date", value: ChargeConverter.dateText(charge))
                DetailRow(label: "Token Code", value: ChargeConverter.codeMask(charge.code))
            }

            Section("Charging Type") {
                HStack {
                    Image(systemName: charge.chargingIcon)
                        .foregroundStyle(charge.chargingColor)
                    Text(ChargeConverter.chargingType(charge))
                        .foregroundStyle(charge.chargingColor)
                }
            }

            Section("After Recharge") {
                DetailRow(label: "Zone 1", value: "\(charge.total1) kWh", bold: true)
                DetailRow(label: "Zone 2", value: "\(charge.total2) kWh", bold: true)
            }

            Section("Energy Delivered") {
                DetailRow(label: "Zone 1", value: "\(charge.value1) kWh")
                DetailRow(label: "Zone 2", value: "\(charge.value2) kWh")
            }
        }
        .navigationTitle(L.ui.txtDetails)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    UIPasteboard.general.string = charge.code
                } label: {
                    Image(systemName: "doc.on.doc")
                }
            }
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    var bold: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(Color.secondary)
            Spacer()
            Text(value)
                .fontWeight(bold ? .semibold : .regular)
                .foregroundStyle(Color.primary)
        }
        .font(.callout)
    }
}

// MARK: - ChargeModel extensions

private extension ChargeModel {
    var chargingIcon: String {
        if ChargeConverter.chargingType(self).contains("Single") {
            return "bolt.fill.badge.clock"
        }
        return "bolt.fill.badge.xmark"
    }

    var chargingColor: Color {
        if ChargeConverter.chargingType(self).contains("Single") {
            return Color.blue
        }
        return Color.purple
    }
}
