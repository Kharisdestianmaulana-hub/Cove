import AppKit
import SwiftUI

/// Application appearance preference matching Cove's Light, Dark, and System modes.
enum CoveAppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Semantic color tokens implementing Cove's "Quiet Premium" visual identity.
enum CoveColors {
    static let deepGraphite = NSColor(srgbRed: 0x17 / 255.0, green: 0x17 / 255.0, blue: 0x19 / 255.0, alpha: 1.0)
    static let elevatedGraphite = NSColor(srgbRed: 0x24 / 255.0, green: 0x24 / 255.0, blue: 0x26 / 255.0, alpha: 1.0)
    static let darkGray = NSColor(srgbRed: 0x3A / 255.0, green: 0x3A / 255.0, blue: 0x3C / 255.0, alpha: 1.0)
    static let softWhite = NSColor(srgbRed: 0xF5 / 255.0, green: 0xF5 / 255.0, blue: 0xF7 / 255.0, alpha: 1.0)
    static let silver = NSColor(srgbRed: 0xE8 / 255.0, green: 0xE8 / 255.0, blue: 0xED / 255.0, alpha: 1.0)
    static let neutralGray = NSColor(srgbRed: 0x8E / 255.0, green: 0x8E / 255.0, blue: 0x93 / 255.0, alpha: 1.0)

    static let backgroundPrimary = dynamicColor(light: softWhite, dark: deepGraphite)
    static let backgroundSecondary = dynamicColor(light: silver, dark: elevatedGraphite)
    static let surfacePrimary = dynamicColor(light: .white, dark: elevatedGraphite)
    static let surfaceSecondary = dynamicColor(light: silver.withAlphaComponent(0.7), dark: darkGray.withAlphaComponent(0.65))
    static let surfaceElevated = dynamicColor(light: .white, dark: darkGray)

    static let textPrimary = dynamicColor(light: deepGraphite, dark: softWhite)
    static let textSecondary = Color(nsColor: neutralGray)
    static let textTertiary = dynamicColor(
        light: neutralGray.withAlphaComponent(0.7),
        dark: neutralGray.withAlphaComponent(0.6)
    )

    static let borderSubtle = dynamicColor(
        light: deepGraphite.withAlphaComponent(0.08),
        dark: softWhite.withAlphaComponent(0.09)
    )

    static let accent = Color.accentColor
    static let recording = Color.red
    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red

    private static func dynamicColor(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [.darkAqua, .aqua])
            return match == .darkAqua ? dark : light
        })
    }
}

/// Consistent spacing scale defined in Design_System.md (§6.6).
enum CoveSpacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
}

/// Restrained corner radius scale defined in Design_System.md (§7.2).
enum CoveRadius {
    static let windowContent: CGFloat = 18
    static let floatingPanel: CGFloat = 16
    static let controlGroup: CGFloat = 14
    static let button: CGFloat = 12
    static let smallElement: CGFloat = 8
}

/// Subtle transition durations defined in Design_System.md (§18.7).
enum CoveMotion {
    static let smallInteraction: Double = 0.14
    static let panelTransition: Double = 0.20
}

/// Native macOS translucent vibrancy material (NSVisualEffectView) for Apple-like glass surfaces.
struct CoveVisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var state: NSVisualEffectView.State = .active

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}
