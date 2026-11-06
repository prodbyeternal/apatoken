import SwiftUI

// MARK: - About view

struct AboutView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // App icon + title
                    VStack(spacing: 12) {
                        BundleImage(name: "AppIcon1024")
                            .frame(width: 96, height: 96)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: .black.opacity(0.15), radius: 12, y: 4)

                        Text(L.ui.txtAboutIAPATOKEN)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Color.primary)
                            .multilineTextAlignment(.center)

                        Text(AppVersion.description)
                            .font(.subheadline)
                            .foregroundStyle(Color.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 16)

                    // Authors section
                    VStack(alignment: .leading, spacing: 16) {
                        Text(L.text("txtAuthors"))
                            .font(.headline)
                            .foregroundStyle(Color.primary)
                            .padding(.horizontal)

                        // APATOR S.A.
                        AuthorRow(
                            name: "APATOR S.A.",
                            role: L.text("txtApatorRole"),
                            logoName: "apator_logo.jpg",
                            logoBackground: Color.white,
                            action: {
                                openURL(URL(string: "https://www.apator.com")!)
                            }
                        )

                        // prodbyeternal
                        AuthorRow(
                            name: "prodbyeternal",
                            role: L.text("txtEternalRole"),
                            logoName: "eternal_logo.jpg",
                            logoBackground: Color(UIColor.systemGray6),
                            action: {
                                openURL(URL(string: "https://github.com/prodbyeternal")!)
                            }
                        )
                    }

                    // Credits
                    VStack(spacing: 8) {
                        Text(L.message.msgIosPort)
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                            .multilineTextAlignment(.center)

                        Text(L.text("txtFontCredit"))
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                    }
                    .padding(.top, 8)
                }
                .padding(.vertical, 24)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(L.ui.txtAboutIAPATOKEN)
            .navigationBarTitleDisplayMode(.inline)
            .dynamicLocalization()
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
                BundleImage(name: logoName)
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
