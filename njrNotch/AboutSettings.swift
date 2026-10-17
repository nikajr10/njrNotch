//
//  AboutSettings.swift
//  njrNotch
//

import SwiftUI

struct AboutSettings: View {
    static let repository = URL(string: "https://github.com/nikajr10/njrNotch")!

    var body: some View {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "?"
        let build = info["CFBundleVersion"] as? String ?? "?"

        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            Text("njrNotch").font(.title.bold())
            Text("Version \(version) (\(build))")
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Link(destination: Self.repository) {
                Label("View on GitHub", systemImage: "arrow.up.right.square")
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
