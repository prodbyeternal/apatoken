import SwiftUI
import UIKit

/// Loads images from the app bundle directly since we're not using asset catalogs.
/// Usage: BundleImage(name: "apator_logo.jpg") or BundleImage(name: "AppIcon1024")
struct BundleImage: View {
    let name: String
    let bundle: Bundle

    init(name: String) {
        self.name = name
        self.bundle = Bundle.main
    }

    var body: some View {
        if let uiImage = loadImage() {
            Image(uiImage: uiImage)
                .resizable()
        } else {
            Image(systemName: "photo")
                .foregroundStyle(Color.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func loadImage() -> UIImage? {
        // Try with various extensions
        for ext in ["png", "jpg", "jpeg"] {
            if let url = bundle.url(forResource: name, withExtension: ext),
               let data = try? Data(contentsOf: url),
               let image = UIImage(data: data) {
                return image
            }
        }
        // Try the exact name as filename (with extension in name)
        let components = name.components(separatedBy: ".")
        if components.count > 1 {
            let base = components[0]
            let ext = components[1]
            if let url = bundle.url(forResource: base, withExtension: ext),
               let data = try? Data(contentsOf: url),
               let image = UIImage(data: data) {
                return image
            }
        }
        return nil
    }
}
