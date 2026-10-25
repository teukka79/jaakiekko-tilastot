import SwiftUI
import AppKit

/// Valittavat sovelluskuvakkeet. Kuvat ovat Assets.xcassets-kansiossa (IconA–IconD).
enum AppIconChoice: String, CaseIterable, Identifiable {
    case a, b, c, d
    var id: String { rawValue }

    var title: String {
        switch self {
        case .a: return "Tumma"
        case .b: return "Vaalea"
        case .c: return "Sininen"
        case .d: return "Neon"
        }
    }

    var assetName: String { "Icon" + rawValue.uppercased() }

    var image: NSImage? { NSImage(named: assetName) }

    static var saved: AppIconChoice {
        AppIconChoice(rawValue: UserDefaults.standard.string(forKey: "appIconChoice") ?? "a") ?? .a
    }

    /// Asettaa Dockin kuvakkeen. Oletus (A) käyttää paketin omaa AppIcon-kuvaa.
    @MainActor
    func apply() {
        NSApplication.shared.applicationIconImage = (self == .a) ? nil : image
    }
}
