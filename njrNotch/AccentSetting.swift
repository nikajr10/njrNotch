//
//  AccentSetting.swift
//  njrNotch
//

import SwiftUI

/// "Accent colour: Auto or Custom" for one tab, with a colour picker and a reset button.
struct AccentSetting: View {
    /// The automatic choice's name, e.g. "Auto (album art)".
    let automatic: String
    /// "" = automatic.
    @Binding var hex: String
    /// The colour the automatic choice gives right now; the custom colour starts from it.
    let current: Color

    var body: some View {
        Picker("Accent colour", selection: Binding(
            get: { hex.isEmpty },
            set: { isAuto in hex = isAuto ? "" : current.hex }
        )) {
            Text(automatic).tag(true)
            Text("Custom").tag(false)
        }
        if !hex.isEmpty {
            LabeledContent("Custom colour") {
                HStack {
                    ColorPicker("Custom colour", selection: Binding(get: { Color(hex: hex) }, set: { hex = $0.hex }),
                                supportsOpacity: false)
                        .labelsHidden()
                    Button("Reset") { hex = "" }
                }
            }
        }
    }
}
