//
//  SoundSettings.swift
//  njrNotch
//

import SwiftUI
import UniformTypeIdentifiers

struct SoundSettings: View {
    @Bindable private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section("Task finished") {
                SoundPicker(isOn: $settings.prefs.doneSoundOn, sound: $settings.prefs.doneSound, kind: .done)
            }
            Section("Permission needed") {
                SoundPicker(isOn: $settings.prefs.permissionSoundOn, sound: $settings.prefs.permissionSound, kind: .permission)
            }
            Section {
                Slider(value: $settings.prefs.soundVolume, in: 0...1) {
                    Text("Volume")
                } minimumValueLabel: {
                    Image(systemName: "speaker.fill")
                } maximumValueLabel: {
                    Image(systemName: "speaker.wave.3.fill")
                }
            }
        }
        .formStyle(.grouped)
    }
}

/// On/off, a built-in sound or the user's own file, and a Test button.
private struct SoundPicker: View {
    @Binding var isOn: Bool
    @Binding var sound: String
    let kind: Alerts.Kind

    var body: some View {
        Toggle("Play a sound", isOn: $isOn)
        HStack {
            Picker("Sound", selection: $sound) {
                ForEach(Alerts.systemSounds, id: \.self) { Text($0).tag($0) }
                if sound.hasPrefix("/") {
                    Divider()
                    Text(URL(fileURLWithPath: sound).lastPathComponent).tag(sound)
                }
            }
            Button("Choose File…", action: chooseFile)
            Button("Test", systemImage: "play.fill") { Alerts.play(kind) }
        }
        .disabled(!isOn)
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        if panel.runModal() == .OK, let url = panel.url {
            sound = url.path
        }
    }
}
