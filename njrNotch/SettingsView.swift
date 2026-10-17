//
//  SettingsView.swift
//  njrNotch
//

import SwiftUI

enum SettingsSection: CaseIterable, Identifiable {
    case general, appearance, spotify, claudeCode, notifications, sounds, about

    var id: Self { self }

    var title: String {
        switch self {
        case .general: "General"
        case .appearance: "Appearance"
        case .spotify: "Spotify"
        case .claudeCode: "Claude Code"
        case .notifications: "Notifications"
        case .sounds: "Sounds"
        case .about: "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape.fill"
        case .appearance: "paintbrush.fill"
        case .spotify: "music.note"
        case .claudeCode: "terminal.fill"
        case .notifications: "bell.badge.fill"
        case .sounds: "speaker.wave.2.fill"
        case .about: "info.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .general: .gray
        case .appearance: .blue
        case .spotify: .green
        case .claudeCode: .orange
        case .notifications: .red
        case .sounds: .pink
        case .about: .indigo
        }
    }
}

/// Settings window: a sidebar of sections, like System Settings.
struct SettingsView: View {
    @Bindable private var settings = AppSettings.shared

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $settings.settingsSection) { section in
                Label {
                    Text(section.title)
                } icon: {
                    Image(systemName: section.symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(section.color.gradient, in: RoundedRectangle(cornerRadius: 6))
                }
                .padding(.vertical, 2)
            }
            .navigationSplitViewColumnWidth(190)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            let section = settings.settingsSection ?? .general
            Group {
                switch section {
                case .general: GeneralSettings()
                case .appearance: AppearanceSettings()
                case .spotify: SpotifySettings()
                case .claudeCode: ClaudeCodeSettings()
                case .notifications: NotificationSettings()
                case .sounds: SoundSettings()
                case .about: AboutSettings()
                }
            }
            .navigationTitle(section.title)
        }
        .frame(width: 780, height: 600)
    }
}
