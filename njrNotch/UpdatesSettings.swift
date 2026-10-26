//
//  UpdatesSettings.swift
//  njrNotch
//

import SwiftUI

/// Settings → Updates: the installed version, the newest release on GitHub with its notes, and one
/// button that downloads it, puts it in place of this copy and relaunches.
struct UpdatesSettings: View {
    @Bindable private var settings = AppSettings.shared
    private let updater = Updater.shared

    var body: some View {
        Form {
            Section {
                LabeledContent("Installed version", value: Updater.current)
                Toggle("Check for updates automatically", isOn: $settings.prefs.checkForUpdates)
                LabeledContent {
                    Button("Check now") { Task { await updater.check() } }
                        .disabled(updater.state == .checking || isInstalling)
                } label: {
                    status
                }
            }
            if case .available(let release) = updater.state {
                Section {
                    ReleaseNotes(markdown: release.notes)
                    Button("Download and install") { Task { await updater.install(release) } }
                        .buttonStyle(.borderedProminent)
                } header: {
                    Text("What's new in \(release.version)")
                }
            }
        }
        .formStyle(.grouped)
        .task {
            if updater.state == .idle { await updater.check() }
        }
    }

    private var isInstalling: Bool {
        if case .installing = updater.state { true } else { false }
    }

    @ViewBuilder private var status: some View {
        switch updater.state {
        case .idle:
            Text("Not checked yet").foregroundStyle(.secondary)
        case .checking:
            HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Checking…") }
        case .upToDate:
            Label("njrNotch is up to date", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            if let date = updater.lastChecked {
                Text("Checked \(date.formatted(date: .omitted, time: .shortened))")
            }
        case .available(let release):
            Label("njrNotch \(release.version) is available", systemImage: "arrow.down.circle.fill")
                .foregroundStyle(.blue)
        case .installing(let step):
            HStack(spacing: 6) { ProgressView().controlSize(.small); Text(step) }
        case .failed(let message):
            Label("Couldn't update", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(message).textSelection(.enabled)
            Link("Open the releases page", destination: AboutSettings.repository.appendingPathComponent("releases/latest"))
        }
    }
}

/// GitHub release notes: headings, bullet lists and inline Markdown (bold, links, code), line by line.
private struct ReleaseNotes: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(markdown.components(separatedBy: .newlines).enumerated()), id: \.offset) { _, raw in
                let line = raw.trimmingCharacters(in: .whitespaces)
                if line.hasPrefix("#") {
                    inline(String(line.drop { $0 == "#" }).trimmingCharacters(in: .whitespaces))
                        .font(.headline).padding(.top, 4)
                } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("•")
                        inline(String(line.dropFirst(2)))
                    }
                } else if !line.isEmpty {
                    inline(line)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    private func inline(_ text: String) -> Text {
        Text((try? AttributedString(markdown: text)) ?? AttributedString(text))
    }
}
