//
//  AppearanceSettings.swift
//  njrNotch
//

import SwiftUI

struct AppearanceSettings: View {
    @Bindable private var settings = AppSettings.shared

    private static let accentPresets = ["#0A84FF", "#BF5AF2", "#FF375F", "#FF9F0A", "#30D158", "#64D2FF", "#D97757"]

    var body: some View {
        VStack(spacing: 0) {
            NotchPreview()
                .frame(height: 220)
            Divider()
            Form {
                Section("Colour") {
                    LabeledContent("Accent colour") {
                        HStack(spacing: 8) {
                            ForEach(Self.accentPresets, id: \.self) { hex in
                                swatch(hex)
                            }
                            ColorPicker("Accent colour", selection: colour(\.accentHex), supportsOpacity: false)
                                .labelsHidden()
                        }
                    }
                    Picker("Notch background", selection: $settings.prefs.background) {
                        Text("Solid black").tag(NotchBackground.black)
                        Text("Dark glass").tag(NotchBackground.glass)
                        Text("Custom colour").tag(NotchBackground.custom)
                    }
                    if settings.prefs.background == .custom {
                        ColorPicker("Background colour", selection: colour(\.customBackgroundHex), supportsOpacity: false)
                    }
                }
                Section {
                    slider("Open width", value: $settings.prefs.expandedWidth, in: 360...600, step: 10, unit: "pt")
                    slider("Open height", value: $settings.prefs.expandedHeight, in: 180...460, step: 10, unit: "pt")
                    slider("Corner radius", value: $settings.prefs.cornerRadius, in: 8...40, step: 1, unit: "pt")
                } header: {
                    Text("Size and shape")
                } footer: {
                    Text("The notch shrinks to fit a tab that needs less room, and scrolls when it needs more.")
                }
                Section("Text and layout") {
                    Picker("Text size", selection: $settings.prefs.textScale) {
                        Text("Small").tag(0.9)
                        Text("Default").tag(1.0)
                        Text("Large").tag(1.15)
                        Text("Extra large").tag(1.3)
                    }
                    Picker("Layout", selection: $settings.prefs.compactLayout) {
                        Text("Comfortable").tag(false)
                        Text("Compact").tag(true)
                    }
                    .pickerStyle(.segmented)
                    Picker("Tab bar", selection: $settings.prefs.tabBarShowsLabels) {
                        Label("Icons only", systemImage: "square.grid.2x2").tag(false)
                        Label("Icons and text", systemImage: "text.below.photo").tag(true)
                    }
                    .pickerStyle(.segmented)
                    Picker("Animation speed", selection: $settings.prefs.animationDuration) {
                        Text("Fast").tag(0.22)
                        Text("Normal").tag(0.35)
                        Text("Slow").tag(0.55)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .formStyle(.grouped)
        }
    }

    private func swatch(_ hex: String) -> some View {
        let isSelected = settings.prefs.accentHex == hex
        return Button {
            settings.prefs.accentHex = hex
        } label: {
            Circle()
                .fill(Color(hex: hex).gradient)
                .frame(width: 18, height: 18)
                .overlay {
                    Circle().strokeBorder(.primary.opacity(isSelected ? 0.8 : 0), lineWidth: 2).padding(-3)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Accent \(hex)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func colour(_ keyPath: WritableKeyPath<Preferences, String>) -> Binding<Color> {
        Binding(get: { Color(hex: settings.prefs[keyPath: keyPath]) },
                set: { settings.prefs[keyPath: keyPath] = $0.hex })
    }

    private func slider(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>,
                        step: Double, unit: String) -> some View {
        LabeledContent(title) {
            HStack {
                Slider(value: value, in: range, step: step)
                Text("\(Int(value.wrappedValue)) \(unit)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 52, alignment: .trailing)
            }
        }
    }
}

/// The real open-notch views, live, on the desktop picture, scaled to fit. Updates as settings change.
private struct NotchPreview: View {
    @State private var tab = NotchTab.claudeCode
    @State private var wallpaper: NSImage?

    var body: some View {
        let prefs = AppSettings.shared.prefs
        let notch = NSScreen.target?.notchSize ?? CGSize(width: 185, height: 32)
        let radius = prefs.cornerRadius

        GeometryReader { geometry in
            let scale = min(1, (geometry.size.width - 40) / prefs.expandedWidth,
                            (geometry.size.height - 12) / prefs.expandedHeight)
            NotchContent(notchSize: notch, spotify: .shared, agent: .shared, tab: $tab)
                .background { NotchFill(blending: .withinWindow) }
                .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: radius, bottomTrailingRadius: radius))
                .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
                .scaleEffect(scale, anchor: .top)
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
        .background {
            if let wallpaper {
                Image(nsImage: wallpaper).resizable().scaledToFill()
            } else {
                LinearGradient(colors: [.indigo, .purple, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
        .clipped()
        .animation(.spring(response: prefs.animationDuration, dampingFraction: 0.8), value: prefs.expandedWidth)
        .animation(.spring(response: prefs.animationDuration, dampingFraction: 0.8), value: prefs.expandedHeight)
        .task {
            wallpaper = NSScreen.target.flatMap(NSWorkspace.shared.desktopImageURL(for:)).flatMap(NSImage.init(contentsOf:))
        }
        .accessibilityLabel("Preview of the open notch")
    }
}
