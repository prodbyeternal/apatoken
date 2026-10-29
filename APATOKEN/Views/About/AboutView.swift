import SwiftUI
import Combine
// MARK: - About view model

@MainActor
final class AboutViewModel: ObservableObject {
    @Published var showAPATOR = false
    @Published var showEternal = false
}

// MARK: - About view

struct AboutView: View {
    @StateObject private var viewModel = AboutViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // App icon + title
                    VStack(spacing: 12) {
                        Image("AppIcon1024")
                            .resizable()
                            .frame(width: 96, height: 96)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: .black.opacity(0.15), radius: 12, y: 4)

                        Text(L.ui.txtAboutIAPATOKEN)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Color.primary)
                            .multilineTextAlignment(.center)

                        Text("v1.1 • \(L.ui.txtCodename) Ramune")
                            .font(.subheadline)
                            .foregroundStyle(Color.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 16)

                    // Authors section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Authors")
                            .font(.headline)
                            .foregroundStyle(Color.primary)
                            .padding(.horizontal)

                        // APATOR S.A.
                        AuthorRow(
                            name: "APATOR S.A.",
                            role: "Electricity meters, Android app development",
                            logoName: "apator_logo.jpg",
                            logoBackground: Color.white,
                            action: {
                                viewModel.showAPATOR = true
                            }
                        )

                        // prodbyeternal
                        AuthorRow(
                            name: "prodbyeternal",
                            role: "iOS port, reverse engineering, UI/UX",
                            logoName: "eternal_logo.jpg",
                            logoBackground: Color(UIColor.systemGray6),
                            action: {
                                viewModel.showEternal = true
                            }
                        )
                    }

                    // Credits
                    VStack(spacing: 8) {
                        Text(L.message.msgIosPort)
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                            .multilineTextAlignment(.center)

                        Text("OpenSans by Steve Mattione")
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                    }
                    .padding(.top, 8)
                }
                .padding(.vertical, 24)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(L.ui.txtSettings)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $viewModel.showAPATOR) {
                Link(destination: URL(string: "https://www.apator.com")!) {
                    Text("Open APATOR S.A.")
                        .font(.headline)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(UIColor.systemGroupedBackground))
                }
                .statusBar(hidden: true)
            }
            .sheet(isPresented: $viewModel.showEternal) {
                Link(destination: URL(string: "https://github.com/prodbyeternal")!) {
                    Text("Open GitHub")
                        .font(.headline)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(UIColor.systemGroupedBackground))
                }
                .statusBar(hidden: true)
            }
        }
    }
}

// MARK: - Author row

struct AuthorRow: View {
    let name: String
    let role: String
    let logoName: String
    let logoBackground: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(logoName)
                    .resizable()
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
                    .background(logoBackground, in: Circle())
                    .overlay(
                        Circle()
                            .stroke(Color(UIColor.separator), lineWidth: 0.5)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.primary)

                    Text(role)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color(UIColor.tertiarySystemFill))
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AboutView()
    }
}
