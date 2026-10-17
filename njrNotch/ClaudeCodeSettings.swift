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
                integration("Status line (optional)", detail: "Model name and context window left",
                            script: "statusline", isInstalled: statusLineInstalled)
                if !output.isEmpty {
                    Text(output).font(.caption.monospaced()).textSelection(.enabled)
                }
            } header: {
                Text("Connect to Claude Code")
            } footer: {
                Text("Both edit ~/.claude/settings.json and back it up first. If you already have a status line, it keeps working: njrNotch runs it and shows its output unchanged.")
            }
            Section {
                Toggle("Current task (your last prompt)", isOn: $settings.prefs.showTask)
                Toggle("What it's doing now", isOn: $settings.prefs.showActivity)
                Toggle("Session time", isOn: $settings.prefs.showElapsed)
                Toggle("Summary of the last result", isOn: $settings.prefs.showLastResult)
                Toggle("Tokens (session and today)", isOn: $settings.prefs.showTokens)
            } header: {
                Text("Details")
            } footer: {
                Text("Model and effort come from the session's log. Context left needs the status line. Anything Claude Code doesn't report stays hidden.")
            }
            Section {
                Toggle("Answer permission requests in the notch", isOn: $settings.prefs.answerPermissionsInNotch)
            } header: {
                Text("Notch")
            } footer: {
                Text("With answering on, Allow and Deny buttons appear in the notch. Otherwise the notch tells you to answer in the terminal.")
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
