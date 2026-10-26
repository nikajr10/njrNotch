//
//  ClaudeCodeSettings.swift
//  njrNotch
//

import SwiftUI

struct ClaudeCodeSettings: View {
    @Bindable private var settings = AppSettings.shared
    @State private var hooksInstalled = ClaudeHooks.isInstalled
    @State private var statusLineInstalled = ClaudeHooks.isStatusLineInstalled
    @State private var output = ""

    var body: some View {
        Form {
            Section {
                Toggle("Show Claude Code in the notch", isOn: $settings.prefs.claudeCodeEnabled)
            }
            Section {
                integration("Hooks", detail: "Live status, permission prompts, sounds",
                            script: "claude-hooks", isInstalled: hooksInstalled)
                integration("Status line", detail: "5-hour and weekly usage limits",
                            script: "statusline", isInstalled: statusLineInstalled)
                if !output.isEmpty {
                    Text(output).font(.caption.monospaced()).textSelection(.enabled)
                }
            } header: {
                Text("Connect to Claude Code")
            }
            Section("Colour") {
                AccentSetting(automatic: "Default (Claude orange)", hex: $settings.prefs.claudeAccentHex,
                              current: ClaudeLogo.orange)
            }
            Section {
                Toggle("Current task (your last prompt)", isOn: $settings.prefs.showTask)
                Toggle("What it's doing now", isOn: $settings.prefs.showActivity)
                Toggle("Task time", isOn: $settings.prefs.showElapsed)
                Toggle("Summary of the last result", isOn: $settings.prefs.showLastResult)
            } header: {
                Text("Details")
            }
            Section("Usage") {
                Toggle("5-hour and weekly limits", isOn: $settings.prefs.showUsageLimits)
            }
            Section {
                Toggle("Answer permission requests in the notch", isOn: $settings.prefs.answerPermissionsInNotch)
            } header: {
                Text("Notch")
            }
        }
        .formStyle(.grouped)
    }

    private func integration(_ title: String, detail: String, script: String, isInstalled: Bool) -> some View {
        LabeledContent {
            HStack {
                Label(isInstalled ? "Installed" : "Not installed",
                      systemImage: isInstalled ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isInstalled ? .green : .secondary)
                Button(isInstalled ? "Uninstall" : "Install") {
                    run((isInstalled ? "uninstall-" : "install-") + script)
                }
            }
        } label: {
            Text(title)
            Text(detail)
        }
    }

    private func run(_ script: String) {
        output = ClaudeHooks.run(script)
        hooksInstalled = ClaudeHooks.isInstalled
        statusLineInstalled = ClaudeHooks.isStatusLineInstalled
    }
}
