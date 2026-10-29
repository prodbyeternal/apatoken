import Combine
import SwiftUI

// MARK: - HistoryViewModel (HistoryViewModel.cs mirror)

@MainActor
final class HistoryViewModel: ObservableObject {
    private static let defaultValue = "-----"

    @Published var meters: [String] = [defaultValue]
    @Published var charges: [ChargeModel] = []
    @Published var hasItems = false
    @Published var currentMeter = defaultValue

    private var allCharges: [ChargeModel] = []
    private var groupedCharges: [[ChargeModel]] = []
    private var selectedIndex = 0 {
        didSet {
            // OnSelectedIndexChanged → DisplayCharges.
            if oldValue != selectedIndex {
                displayCharges()
            }
        }
    }

    func onAppearing() {
        allCharges = []
        groupedCharges = []
        meters = [Self.defaultValue]
        hasItems = false
        currentMeter = Self.defaultValue
        chargeSelection = nil
        loadHistory()
        groupByMeters()
        selectedIndex = 0
        displayCharges()
    }

    /// Selected charge for the details push.
    @Published var chargeSelection: ChargeModel?

    private func loadHistory() {
        allCharges = HistoryManager.readAll()
    }

    /// GroupByMeters: groups by Meter+Mac in first-seen order.
    private func groupByMeters() {
        var meters: [String] = []
        for charge in allCharges {
            if let index = groupedCharges.firstIndex(where: { list in
                list.contains { $0.meter == charge.meter && $0.mac == charge.mac }
            }) {
                groupedCharges[index].append(charge)
                continue
            }
            groupedCharges.append([charge])
            meters.append(charge.meter)
        }
        guard !meters.isEmpty else { return }
        self.meters = meters
        hasItems = self.meters.count > 1
    }

    private func displayCharges() {
        guard meters.indices.contains(selectedIndex) else { return }
        currentMeter = meters[selectedIndex]
        if meters.contains(Self.defaultValue) {
            return // charges stay empty
        }
        charges = groupedCharges[selectedIndex]
    }

    /// ChangeMeter(): popup result -1 = no change.
    func changeMeter(from result: Int) {
        if result != -1, meters.indices.contains(result) {
            selectedIndex = result
        }
    }

    /// MetersPopup.PrepareMetersList dedup mirror.
    static func prepareMetersList(_ meters: [String]) -> [String] {
        var list: [String] = []
        for meter in meters {
            if !list.contains(meter) {
                list.append(meter)
                continue
            }
            var counter = 2
            list.append("\(meter) (\(counter))")
            counter += 1
            if let index = list.firstIndex(of: meter) {
                list[index] = "\(meter) (1)"
            }
        }
        return list
    }
}

// MARK: - HistoryView

struct HistoryView: View {
    @StateObject private var model = HistoryViewModel()
    @State private var showMeters = false
    @State private var alert: AlertPresentation?

    var body: some View {
            ScrollView {
                VStack(spacing: 0) {
                    if model.hasItems {
                        Button {
                            showMeters = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "powermeter")
                                    .font(.system(size: 14, weight: .semibold))
                                Text(model.currentMeter)
                                    .font(ApaFont.semibold(17))
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            .foregroundStyle(.white)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(ApaColor.blue)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                    }
                    chargeRows
                }
                .padding(.horizontal, 12)
            }
            .background(ApaColor.page)
            .navigationTitle(L.ui.txtChargesHistory)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        alert = AlertPresentation(L.ui.txtAlertInfo, L.message.msgHistoryInformation)
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
            }
            .navigationDestination(item: $model.chargeSelection) { charge in
                DetailsView(model: charge)
            }
            .sheet(isPresented: $showMeters) {
                MetersSheet(meters: model.meters) { selected in
                    model.changeMeter(from: selected)
                }
                .presentationDetents([.medium])
            }
            .alertPopup($alert)
            .onAppear { model.onAppearing() }
    }

    private var chargeRows: some View {
        LazyVStack(spacing: 10) {
            ForEach(model.charges) { charge in
                Button {
                    model.chargeSelection = charge
                } label: {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: "bolt.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(ApaColor.green)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(ChargeConverter.dateText(charge))
                                .font(ApaFont.semibold(13))
                                .foregroundStyle(ApaColor.text)
                            Text(ChargeConverter.chargingType(charge))
                                .font(ApaFont.semibold(12))
                                .foregroundStyle(ApaColor.subtleText)
                            Text(ChargeConverter.chargingValues(charge))
                                .font(ApaFont.regular(11))
                                .foregroundStyle(ApaColor.subtleText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(ApaColor.gray)
                    }
                    .padding(12)
                    .background(ApaColor.card,
                                in: RoundedRectangle(cornerRadius: AppStyle.cardCorner, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityHint(L.ui.txtDetails)
            }
        }
        .padding(.top, model.hasItems ? 10 : 8)
    }
}

// MARK: - MetersSheet (MetersPopup)

struct MetersSheet: View {
    let meters: [String]
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text(L.ui.txtPickValue)
                    .font(ApaFont.semibold(16))
                            Divider()
                            .background(ApaColor.separator)
            }
            .padding(.top, 18)
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Rows use the deduped PrepareMetersList names.
                    ForEach(Array(HistoryViewModel.prepareMetersList(meters).enumerated()),
                            id: \.offset) { index, meterName in
                        Button {
                            onSelect(index)
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "powermeter")
                                    .font(.system(size: 14))
                                    .foregroundStyle(ApaColor.blue)
                                Text(meterName)
                                    .font(ApaFont.regular(15))
                                    .foregroundStyle(ApaColor.text)
                                Spacer()
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(ApaColor.blue)
                            }
                            .padding(.vertical, 13)
                            .padding(.horizontal, 14)
                            Divider()
                                .background(ApaColor.separator)
                                .padding(.leading, 14)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .background(Color(uiColor: .systemBackground))
    }

    @Environment(\.dismiss) private var dismiss
}

#Preview {
    NavigationStack {
        HistoryView()
    }
}
