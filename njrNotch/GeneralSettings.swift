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
                Toggle("Show live activity in the closed notch", isOn: $settings.prefs.showClosedIndicator)
                Group {
                    Picker("When both are active, show", selection: $settings.prefs.closedSource) {
                        Text("Spotify").tag(ClosedSource.spotify)
                        Text("Claude Code").tag(ClosedSource.claudeCode)
                        Text("Auto (most recent)").tag(ClosedSource.auto)
                    }
                    Toggle("Album art", isOn: $settings.prefs.closedShowsArt)
                    Toggle("Equaliser while playing", isOn: $settings.prefs.closedShowsEqualizer)
                }
                .disabled(!settings.prefs.showClosedIndicator)
            } header: {
                Text("Closed notch")
            } footer: {
                Text("Claude needing permission always shows first.")
            }
            Section("Display") {
                Picker("Screen", selection: $settings.prefs.screenName) {
                    Text("Automatic (notch screen)").tag("")
                    ForEach(NSScreen.screens, id: \.localizedName) { screen in
                        Text(screen.localizedName).tag(screen.localizedName)
                    }
                }
                Toggle("Show menu bar icon", isOn: $settings.prefs.showMenuBarIcon)
                if !settings.prefs.showMenuBarIcon {
                    Text("To get back here, right-click the notch or open njrNotch again.")
                        .font(.caption).foregroundStyle(.secondary)
                }
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
