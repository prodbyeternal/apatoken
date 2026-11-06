import SwiftUI
import AudioToolbox

/// Payment-style presentation, using public system sound and haptic APIs.
struct RechargeResultOverlay: View {
    let presentation: RechargePresentation
    let dismiss: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ring: CGFloat = 0
    @State private var mark: CGFloat = 0
    @State private var amount: Double = 0
    @State private var reveal = false

    private var isWorking: Bool { presentation.phase == 0 }
    private var isSuccess: Bool { presentation.phase == 1 }
    private var tint: Color { isWorking ? .accentColor : isSuccess ? .green : .red }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Capsule().fill(.tertiary).frame(width: 36, height: 5).padding(.top, 12)
                HStack {
                    Label(L.ui.txtRecharge, systemImage: "bolt.fill").font(.headline)
                    Spacer()
                    Text(L.ui.appName).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                }
                .padding(24)
                Divider()
                ScrollView {
                    VStack(spacing: 18) {
                        ZStack {
                            Circle().stroke(tint.opacity(0.12), lineWidth: 5)
                            if isWorking {
                                ProgressView().controlSize(.large).tint(tint)
                            } else {
                                Circle().trim(from: 0, to: ring)
                                    .stroke(tint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                                ResultMark(success: isSuccess).trim(from: 0, to: mark)
                                    .stroke(tint, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                                    .padding(23)
                            }
                        }
                        .frame(width: 86, height: 86)
                        .scaleEffect(reveal ? 1 : 0.94)
                        .accessibilityHidden(true)

                        Text(isWorking ? L.text("txtApplyingToken") : isSuccess ? L.text("txtSuccess") : L.ui.txtError)
                            .font(.title2.bold())
                            .accessibilityIdentifier("transactionStatus")

                        switch presentation {
                        case .working(let meter):
                            Text(L.ui.txtMeterNumber + " " + meter).foregroundStyle(.secondary)
                        case .success(let receipt):
                            VStack(spacing: 10) {
                                if total(receipt.charge) != nil {
                                    Text(amount, format: .number.precision(.fractionLength(1)))
                                        .font(.system(size: 48, weight: .bold, design: .rounded))
                                        .monospacedDigit()
                                        .contentTransition(.numericText(value: amount))
                                        .foregroundStyle(.green)
                                    Text("kWh").font(.headline).foregroundStyle(.secondary)
                                }
                                Text(L.text("txtEnergyDelivered")).font(.subheadline).foregroundStyle(.secondary)
                                Text(ChargeConverter.chargingValues(receipt.charge)).font(.subheadline.monospacedDigit())
                                Text(L.ui.txtMeterNumber + " " + receipt.charge.meter).font(.caption).foregroundStyle(.secondary)
                                if let warning = receipt.warning { Text(ErrorText.message(warning)).font(.footnote).foregroundStyle(.orange) }
                            }
                            .opacity(reveal ? 1 : 0)
                            .offset(y: reveal || reduceMotion ? 0 : 12)
                        case .failure(let error):
                            Text(ErrorText.message(error)).foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .accessibilityIdentifier("transactionError")
                        }
                    }
                    .padding(24).frame(maxWidth: .infinity)
                }
                .frame(maxHeight: max(80, min(390, geometry.size.height - 200)))
                .fixedSize(horizontal: false, vertical: true)
                if !isWorking {
                    Button(L.text("txtDone"), action: dismiss)
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 10)
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("transactionDone")
                        .padding([.horizontal, .bottom], 24)
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 32).stroke(.white.opacity(0.12), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.25), radius: 30, y: 10)
            .padding(.horizontal, 12).padding(.bottom, 12)
            .frame(maxWidth: 520)
            .accessibilityAddTraits(.isModal)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .task(id: presentation.phase) {
            ring = 0; mark = 0; reveal = false; amount = 0
            guard !isWorking else { return }
            UINotificationFeedbackGenerator().notificationOccurred(isSuccess ? .success : .error)
            if isSuccess { AudioServicesPlaySystemSound(1025) }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.45)) { ring = 1 }
            if !reduceMotion { try? await Task.sleep(for: .milliseconds(150)) }
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.7)) { mark = 1; reveal = true }
            if case .success(let receipt) = presentation {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.8)) { amount = total(receipt.charge) ?? 0 }
            }
        }
    }

    private func total(_ charge: ChargeModel) -> Double? {
        guard let first = Double(charge.value1), let second = Double(charge.value2) else { return nil }
        return first + second
    }
}

private struct ResultMark: Shape {
    let success: Bool
    func path(in rect: CGRect) -> Path {
        Path { path in
            if success {
                path.move(to: CGPoint(x: rect.minX, y: rect.midY))
                path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.maxY * 0.85))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.15))
            } else {
                path.move(to: CGPoint(x: rect.minX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            }
        }
    }
}
