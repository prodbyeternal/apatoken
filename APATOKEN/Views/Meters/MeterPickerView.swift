import SwiftUI

// MARK: - Meter picker view (sheet)

struct MeterPickerView: View {
    @ObservedObject private var session = MeterSession.shared
    @StateObject private var viewModel: MeterPickerViewModel
    @Environment(\.dismiss) private var dismiss
    var onSelected: ((MeterPickerViewModel.DiscoveredBLEDevice?) -> Void)?

    init(viewModel: MeterPickerViewModel? = nil,
         onSelected: ((MeterPickerViewModel.DiscoveredBLEDevice?) -> Void)? = nil) {
        self._viewModel = StateObject(wrappedValue: viewModel ?? MeterPickerViewModel())
        self.onSelected = onSelected
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 6) {
                if session.testing { TestingBanner().padding(.horizontal) }
                Text(L.ui.txtAvailableDevices)
                    .font(.headline)
                    .padding(.top, 16)

                HStack {
                    if viewModel.isPowered {
                        Text(L.ui.txtScanning)
                            .font(.subheadline)
                            .foregroundStyle(Color.secondary)
                        Spacer()
                        ProgressView()
                            .tint(Color.primary)
                    } else {
                        Spacer()
                    }
                }
                .padding(.horizontal, 16)

                Divider()

                if let error = viewModel.error { Text(ErrorText.message(error)).foregroundStyle(.red) }
                if viewModel.devices.isEmpty { Text(L.ui.txtNoDevicesFound).font(.footnote).foregroundStyle(.secondary).padding() }

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.devices) { device in
                            Button {
                                if viewModel.connect(to: device) {
                                    onSelected?(device)
                                    dismiss()
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(device.shortName)
                                        .font(.system(size: 15))
                                        .foregroundStyle(Color.primary)
                                    Text(device.address)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                            }
                            .buttonStyle(.plain)
                            .disabled(session.busy)

                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
            }
            .navigationTitle(L.ui.txtSelectDevice)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.ui.txtCancel) {
                        viewModel.stop()
                        onSelected?(nil)
                        dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.start()
            }
            .onDisappear {
                viewModel.stop()
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.automatic)
        .dynamicLocalization()
    }
}

// MARK: - Compact meter display

struct MeterDisplayView: View {
    @ObservedObject var viewModel: MeterPickerViewModel
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "powermeter")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(viewModel.selectedMeterName.isEmpty ?
                                 Color.secondary : Color.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(L.ui.txtDeviceName)
                    .font(.caption)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.secondary)

                Text(viewModel.selectedMeterName.isEmpty ?
                     L.ui.txtNoMeterSelected :
                     viewModel.selectedMeterName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(viewModel.selectedMeterName.isEmpty ?
                                     Color.secondary : Color.primary)
            }

            Spacer()

            if !viewModel.selectedMeterName.isEmpty {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(UIColor.tertiarySystemFill))
            }
        }
        .padding(16)
        .background(Color(UIColor.systemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture(perform: onSelect)
        .contentShape(Rectangle())
    }
}

#Preview {
    MeterPickerView()
}
