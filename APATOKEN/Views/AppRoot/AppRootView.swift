import SwiftUI

// MARK: - App root with tab-based navigation

struct AppRootView: View {
    @EnvironmentObject private var app: AppState
    @ObservedObject private var loc = LocalizationManager.shared

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
        .environmentObject(app)
        .dynamicLocalization()
    }
}
