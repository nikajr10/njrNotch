//
//  NotchStyle.swift
//  njrNotch
//

import AppKit
import SwiftUI

/// Appearance settings, resolved for the notch views.
extension Preferences {
    var accent: Color { Color(hex: accentHex) }
    var spacing: CGFloat { compactLayout ? 8 : 14 }
    var padding: CGFloat { compactLayout ? 14 : 20 }
    /// Dark text on a light custom background, light text everywhere else, so it stays readable.
    var notchScheme: ColorScheme {
        background == .custom && Color(hex: customBackgroundHex).luminance > 0.6 ? .light : .dark
    }
}

extension Font {
    /// Notch text at `size` points, scaled by the Appearance text size.
    static func notch(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: (size * AppSettings.shared.prefs.textScale).rounded(), weight: weight)
    }
}

extension Color {
    /// "#RRGGBB", the form colours are saved in. Unreadable text gives black.
    init(hex: String) {
        let value = UInt32(hex.trimmingCharacters(in: CharacterSet(charactersIn: "# ")), radix: 16) ?? 0
        self.init(red: Double(value >> 16 & 0xFF) / 255, green: Double(value >> 8 & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }

    var hex: String {
        let rgb = rgb
        let byte = { (x: Double) in Int((x * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(rgb.r), byte(rgb.g), byte(rgb.b))
    }

    /// Perceived brightness, 0 (black) to 1 (white).
    var luminance: Double {
        let rgb = rgb
        return 0.299 * rgb.r + 0.587 * rgb.g + 0.114 * rgb.b
    }

    private var rgb: (r: Double, g: Double, b: Double) {
        let color = NSColor(self).usingColorSpace(.sRGB) ?? .black
        let clamp = { (x: CGFloat) in min(max(Double(x), 0), 1) }
        return (clamp(color.redComponent), clamp(color.greenComponent), clamp(color.blueComponent))
    }

    #if DEBUG
    /// Runnable check for the hex round trip; called once at launch in debug builds.
    static func selfCheck() {
        for hex in ["#0A84FF", "#808080", "#000000", "#FFFFFF", "#D97757"] {
            assert(Color(hex: hex).hex == hex, hex)
        }
        assert(Color(hex: "#FFFFFF").luminance > 0.99 && Color(hex: "nonsense").hex == "#000000")
    }
    #endif
}

/// A thin filled bar. Drawn in SwiftUI because native progress bars and sliders turn grey in
/// the notch panel, which is never the key window.
struct CapsuleBar: View {
    /// 0...1
    let fraction: Double
    let color: Color
    var height: CGFloat = 5

    var body: some View {
        GeometryReader { geometry in
            Capsule()
                .fill(.primary.opacity(0.14))
                .overlay(alignment: .leading) {
                    let width = geometry.size.width * min(max(fraction, 0), 1)
                    Capsule().fill(color).frame(width: width > 0 ? max(width, height) : 0)
                }
        }
        .frame(height: height)
    }
}

/// The open notch's fill: solid black, dark glass, or the user's colour.
struct NotchFill: View {
    /// The real notch blurs the desktop behind its window; the Settings preview blurs its own backdrop.
    var blending = NSVisualEffectView.BlendingMode.behindWindow

    var body: some View {
        let prefs = AppSettings.shared.prefs
        switch prefs.background {
        case .black: Color.black
        case .glass: Glass(blending: blending).overlay(Color.black.opacity(0.3))
        case .custom: Color(hex: prefs.customBackgroundHex)
        }
    }

    private struct Glass: NSViewRepresentable {
        let blending: NSVisualEffectView.BlendingMode

        func makeNSView(context: Context) -> NSVisualEffectView {
            let view = NSVisualEffectView()
            view.material = .hudWindow
            view.state = .active // the notch panel is never key, so don't fade to the inactive look
            view.appearance = NSAppearance(named: .darkAqua)
            return view
        }

        func updateNSView(_ view: NSVisualEffectView, context: Context) {
            view.blendingMode = blending
        }
    }
}
