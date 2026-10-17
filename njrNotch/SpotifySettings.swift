//
//  SpotifySettings.swift
//  njrNotch
//

import SwiftUI

struct SpotifySettings: View {
    @Bindable private var settings = AppSettings.shared
    private let account = SpotifyAccount.shared

    var body: some View {
        Form {
            Section {
                Toggle("Show Spotify in the notch", isOn: $settings.prefs.showSpotify)
            } footer: {
                Text("Playback uses AppleScript to talk to the Spotify app, no login needed. If nothing shows, allow njrNotch in System Settings → Privacy & Security → Automation.")
            }
            Section("Now playing") {
                Toggle("Album art", isOn: $settings.prefs.showAlbumArt)
                Toggle("Artist", isOn: $settings.prefs.showArtist)
                Toggle("Shuffle button", isOn: $settings.prefs.showShuffle)
                Toggle("Like button", isOn: $settings.prefs.showLike)
                Toggle("Visualizer", isOn: $settings.prefs.showVisualizer)
                Text("The visualizer is an animation; it doesn't read your audio.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                TextField("Client ID", text: $settings.prefs.spotifyClientID, prompt: Text("Paste your app's Client ID"))
                    .autocorrectionDisabled()
                    .disabled(account.isConnected)
                LabeledContent("Account") {
                    HStack {
                        Label(account.isConnected ? "Connected" : "Not connected",
                              systemImage: account.isConnected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(account.isConnected ? .green : .secondary)
                        if account.isConnected {
                            Button("Disconnect", action: account.disconnect)
                        } else {
                            Button("Connect", action: account.connect)
                                .disabled(settings.prefs.spotifyClientID.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }
                if let status = account.status {
                    Text(status).font(.caption).foregroundStyle(.secondary)
                }
            } header: {
                Text("Spotify account, for the like button")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("1. Create an app at developer.spotify.com/dashboard and tick Web API.")
                    HStack(spacing: 4) {
                        Text("2. Add this redirect URI:")
                        Text(SpotifyAccount.redirectURI).monospaced().textSelection(.enabled)
                        Button("Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(SpotifyAccount.redirectURI, forType: .string)
                        }
                        .controlSize(.small)
                    }
                    Text("3. Paste the app's Client ID above and click Connect. Spotify requires the app's owner to have Premium.")
                }
            }
        }
        .formStyle(.grouped)
    }
}
