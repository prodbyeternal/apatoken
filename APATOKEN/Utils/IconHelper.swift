import Foundation

/// Helper to provide icon paths for the app bundle.
/// Since Assets.car cannot be compiled due to iOS 26 SDK toolchain bug,
/// icons are bundled directly in the app resources and referenced by filename.
enum IconHelper {
    /// All icon filenames that should be present in the bundle.
    static let iconFilenames: [String] = [
        "AppIcon29x29@2x.png",
        "AppIcon29x29@2x-D.png",
        "AppIcon29x29@2x-T.png",
        "AppIcon29x29@3x.png",
        "AppIcon29x29@3x-D.png",
        "AppIcon29x29@3x-T.png",
        "AppIcon40x40@2x.png",
        "AppIcon40x40@2x-D.png",
        "AppIcon40x40@2x-T.png",
        "AppIcon40x40@3x.png",
        "AppIcon40x40@3x-D.png",
        "AppIcon40x40@3x-T.png",
        "AppIcon60x60@2x.png",
        "AppIcon60x60@2x-D.png",
        "AppIcon60x60@2x-T.png",
        "AppIcon60x60@3x.png",
        "AppIcon60x60@3x-D.png",
        "AppIcon60x60@3x-T.png",
        "AppIcon1024.png",
    ]

    /// Copy all icons from the graft_icons directory into the app bundle.
    static func copyIconsToBundle(bundlePath: String) {
        let graftIconsDir = "/Users/eternal/Apatoken_Work/graft_icons/"
        let fileManager = FileManager.default

        for filename in iconFilenames {
            let sourcePath = graftIconsDir + filename
            let destPath = bundlePath + "/" + filename

            if fileManager.fileExists(atPath: sourcePath) {
                try? fileManager.copyItem(atPath: sourcePath, toPath: destPath)
            }
        }
    }
}