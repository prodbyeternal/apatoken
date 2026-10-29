import SwiftUI

// MARK: - RootView (AppShell: 4 tabs)

struct RootView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        TabView(selection: $app.selection) {
            MainView()
                .tabItem {
                    Label(L.ui.txtPrepaidRecharge, systemImage: "plus.circle.fill")
                }
                .tag(0)

            ReadingsView()
                .tabItem {
                    Label(L.ui.txtReadings, systemImage: "powermeter")
                }
                .tag(1)

            NavigationStack { HistoryView() }
                .tabItem {
                    Label(L.ui.txtHistory, systemImage: "clock.arrow.circlepath")
                }
                .tag(2)

            NavigationStack { SettingsView() }
                .tabItem {
                    Label(L.ui.txtSettings, systemImage: "gearshape")
                }
                .tag(3)
        }
    }
}
