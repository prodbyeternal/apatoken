import SwiftUI

// MARK: - App root with tab-based navigation

struct AppRootView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var session = MeterSession.shared

    var body: some View {
        TabView(selection: $app.selection) {
            TokenFlowView()
                .tag(0)
                .tabItem {
                    Label(L.ui.txtRecharge, systemImage: "number.square.fill")
                }

            CreditsView()
                .tag(1)
                .tabItem {
                    Label(L.ui.txtReadings, systemImage: "powermeter")
                }

            HistoryListView()
                .tag(2)
                .tabItem {
                    Label(L.ui.txtHistory, systemImage: "clock")
                }

            SettingsView()
                .tag(3)
                .tabItem {
                    Label(L.ui.txtSettings, systemImage: "gearshape")
                }
        }
        .accentColor(Color.accentColor)
        .background(KeyboardDismissOnTap())
        .environmentObject(app)
        .disabled(session.rechargePresentation != nil)
        .accessibilityHidden(session.rechargePresentation != nil)
        .overlay {
            ZStack {
                if let presentation = session.rechargePresentation {
                    Color.black.opacity(0.5).ignoresSafeArea()
                        .accessibilityHidden(true)
                        .transition(.opacity)
                    RechargeResultOverlay(presentation: presentation) {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85)) {
                            session.rechargePresentation = nil
                        }
                    }
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
                }
            }
        }
        .dynamicLocalization()
    }
}
