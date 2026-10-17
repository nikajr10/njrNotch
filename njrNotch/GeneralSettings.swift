//
//  GeneralSettings.swift
//  njrNotch
//

import ServiceManagement
import SwiftUI

struct GeneralSettings: View {
    @Bindable private var settings = AppSettings.shared
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginMessage: String?

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: Binding(get: { launchAtLogin }, set: setLaunchAtLogin))
                if let loginMessage {
                    Text(loginMessage).font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Opening") {
                Picker("Open the notch", selection: $settings.prefs.openOnClick) {
                    Text("On hover").tag(false)
                    Text("On click").tag(true)
                }
                .pickerStyle(.segmented)
                if !settings.prefs.openOnClick {
                    LabeledContent("Open delay") {
                        HStack {
                            Slider(value: $settings.prefs.openDelay, in: 0...1, step: 0.05)
                            Text(settings.prefs.openDelay == 0 ? "None" : "\(settings.prefs.openDelay, specifier: "%.2f") s")
                                .monospacedDigit()
                                .frame(width: 50, alignment: .trailing)
                        }
                    }
                }
            }
            Section {
                Toggle("Show previews beside the closed notch", isOn: $settings.prefs.showClosedIndicator)
                Group {
                    Picker("Closed notch shows", selection: $settings.prefs.closedSource) {
                        Text("Auto").tag(ClosedSource.auto)
                        Text("Music only").tag(ClosedSource.spotify)
                        Text("Claude Code only").tag(ClosedSource.claudeCode)
                    }
                    Toggle("Album art", isOn: $settings.prefs.closedShowsArt)
                    Toggle("Equaliser while playing", isOn: $settings.prefs.closedShowsEqualizer)
                    Toggle("Animate Claude's state on the logo", isOn: $settings.prefs.closedLogoAnimates)
                }
                .disabled(!settings.prefs.showClosedIndicator)
            } header: {
                Text("Closed notch")
            } footer: {
                Text("Auto: music on the left, and on the right the equaliser, or the Claude logo while Claude Code is busy. With no music, the Claude logo and its state. Previews can also be turned on and off from the notch's right-click menu.")
            }
            Section {
                Toggle("Keyboard shortcut", isOn: $settings.prefs.hotKeyOn)
                LabeledContent("Open and close the notch") {
                    ShortcutRecorder()
                }
                .disabled(!settings.prefs.hotKeyOn)
            } header: {
                Text("Shortcut")
            } footer: {
                Text("Works from any app. Click the shortcut, then press a new one with ⌃, ⌥ or ⌘.")
            }
            Section("Display") {
                Picker("Screen", selection: $settings.prefs.screenName) {
                    Text("Automatic (notch screen)").tag("")
                    ForEach(NSScreen.screens, id: \.localizedName) { screen in
                        Text(screen.localizedName).tag(screen.localizedName)
                    }
                }
                Text("njrNotch has no menu bar icon. To reach Settings, click the gear in the open notch, right-click the notch, press \(settings.prefs.hotKeyLabel), or open njrNotch again from Finder or Spotlight.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginMessage = nil
        } catch {
            loginMessage = error.localizedDescription
        }
        let status = SMAppService.mainApp.status
        launchAtLogin = status == .enabled
        if status == .requiresApproval {
            loginMessage = "Approve njrNotch in System Settings → General → Login Items."
            SMAppService.openSystemSettingsLoginItems()
        }
    }
}
