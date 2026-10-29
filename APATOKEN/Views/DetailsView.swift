import SwiftUI

// MARK: - DetailsView (DetailsPage)

struct DetailsView: View {
    let model: ChargeModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(L.ui.txtDetails)
                    .font(ApaFont.semibold(20))

                Text(L.ui.txtPrepaidRecharge)
                    .font(ApaFont.semibold(18))

                rowGrid
                    .padding(.top, 10)

                Text(L.ui.txtAfterPrepaidRecharge)
                    .font(ApaFont.semibold(18))

                totalGrid
                    .padding(.top, 10)
            }
            .padding(16)
        }
        .background(ApaColor.page)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Rows grid: txtDate/Date, txtCode/Code, txtCreditValue, "    Zone 1"
    /// / "{Value1} kWh" and "    Zone 2" / "{Value2} kWh".
    private var rowGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 10) {
            detailRow(0, label: L.ui.txtDate,
                      value: ChargeConverter.dateText(model))
            detailRow(1, label: L.ui.txtCode,
                      value: ChargeConverter.codeMask(model.code))
            detailRow(2, label: L.ui.txtCreditValue,
                      value: "")
            detailRow(3, label: "    \(L.ui.txtZone) 1",
                      value: "\(model.value1) kWh", valueBold: true)
            detailRow(4, label: "    \(L.ui.txtZone) 2",
                      value: "\(model.value2) kWh", valueBold: true)
        }
    }

    /// After prepaid recharge section: divider, txtTotalCredit label and
    /// the grid with "    Zone 1" / "{Total1} kWh", "    Zone 2" /
    /// "{Total2} kWh".
    private var totalGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
                .background(ApaColor.separator)
            Text(L.ui.txtTotalCredit)
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 10) {
                detailRow(0, label: "    \(L.ui.txtZone) 1",
                          value: "\(model.total1) kWh", valueBold: true)
                detailRow(1, label: "    \(L.ui.txtZone) 2",
                          value: "\(model.total2) kWh", valueBold: true)
            }
        }
    }

    @ViewBuilder
    private func detailRow(_ index: Int, label: String, value: String, valueBold: Bool = false) -> some View {
        GridRow {
            Text(label)
                .font(ApaFont.regular(12))
                .foregroundStyle(ApaColor.subtleText)
            Text(value)
                .font(valueBold ? ApaFont.semibold(12) : ApaFont.regular(12))
                .foregroundStyle(ApaColor.text)
                .gridColumnAlignment(.trailing)
        }
    }
}

#Preview {
    NavigationStack {
        DetailsView(model: ChargeModel(
            meter: "TOKEN1234", mac: "A1B2C3D4-E5F6",
            code: "0123 4567 8901 2345 6789",
            total1: "1543.0", total2: "0.0",
            value1: "500.0", value2: "0.0"))
    }
}
