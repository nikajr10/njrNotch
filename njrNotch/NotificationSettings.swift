//
//  NotificationSettings.swift
//  njrNotch
//

import SwiftUI

struct NotificationSettings: View {
    @Bindable private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section {
                Toggle("Pop-down notifications under the notch", isOn: $settings.prefs.popOn)
            } footer: {
                Text("Click a notification to open the notch on its tab. A new one replaces the one showing.")
            }
            Section("Show a notification when") {
                Toggle("The song changes", isOn: $settings.prefs.popSong)
                Toggle("Claude finishes a task", isOn: $settings.prefs.popDone)
                Toggle("Claude needs permission", isOn: $settings.prefs.popPermission)
                Toggle("A Claude session ends", isOn: $settings.prefs.popSessionEnded)
            }
            .disabled(!settings.prefs.popOn)
            Section {
                LabeledContent("Display for") {
                    HStack {
                        Slider(value: $settings.prefs.popDuration, in: 1...10, step: 1)
                        Text("\(Int(settings.prefs.popDuration)) s")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                    }
                }
                Picker("Animation speed", selection: $settings.prefs.popAnimation) {
                    Text("Fast").tag(0.25)
                    Text("Normal").tag(0.4)
                    Text("Slow").tag(0.6)
                }
                .pickerStyle(.segmented)
                Toggle("Keep open while the pointer is on it", isOn: $settings.prefs.popKeepWhileHovering)
                Button("Show a test notification") {
                    PopNotifier.shared.post(PopNote(kind: .done, title: "Done · njrNotch",
                                                    detail: "This is what a notification looks like."))
                }
            } header: {
                Text("Timing")
            }
            .disabled(!settings.prefs.popOn)
            Section {
                Toggle("Also send macOS notifications for Claude Code", isOn: $settings.prefs.notificationsOn)
                    .onChange(of: settings.prefs.notificationsOn) { _, on in
                        if on { Alerts.requestNotificationPermission() }
                    }
            } footer: {
                Text("Task finished, permission needed and session ended appear in Notification Centre too.")
            }
        }
        .formStyle(.grouped)
    }
}
