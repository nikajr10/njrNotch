//
//  NotchContent.swift
//  njrNotch
//

import SwiftUI

enum NotchTab: CaseIterable {
    case spotify, claudeCode

    var title: String {
        switch self {
        case .spotify: "Spotify"
        case .claudeCode: "Claude Code"
        }
    }

    var symbol: String {
        switch self {
        case .spotify: "music.note"
        case .claudeCode: "terminal"
        }
    }

    var isEnabled: Bool {
        let prefs = AppSettings.shared.prefs
        return switch self {
        case .spotify: prefs.showSpotify
        case .claudeCode: prefs.claudeCodeEnabled
        }
    }
}

/// The open notch: tab bar and the selected tab, at the size and style set in Appearance.
/// Used by the notch itself and by the live preview in Settings.
struct NotchContent: View {
    let notchSize: CGSize
    let spotify: SpotifyController
    let agent: AgentMonitor
    @Binding var tab: NotchTab

    @Namespace private var tabPill
    private var prefs: Preferences { AppSettings.shared.prefs }

    var body: some View {
        let tabs = NotchTab.allCases.filter(\.isEnabled)
        let shown = tabs.contains(tab) ? tab : tabs.first

        VStack(alignment: .leading, spacing: prefs.spacing) {
            tabBar(tabs)
            switch shown {
            case .spotify:
                SpotifyTab(spotify: spotify)
            case .claudeCode:
                ClaudeCodeTab(agent: agent)
            case nil:
                Text("Turn on Spotify or Claude Code in Settings.")
                    .font(.notch(12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, prefs.padding)
        .padding(.top, notchSize.height + 6)
        .padding(.bottom, prefs.padding * 0.75)
        .frame(width: prefs.expandedWidth, alignment: .top)
        // Fit the tab's content, up to the height set in Appearance; past that, Claude Code's details scroll.
        .frame(maxHeight: prefs.expandedHeight, alignment: .top)
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(.primary)
        .tint(shown.map(accent) ?? prefs.accent)
        .environment(\.colorScheme, prefs.notchScheme)
    }

    /// Each tab's own accent, set in its Settings section.
    private func accent(_ tab: NotchTab) -> Color {
        switch tab {
        case .spotify: spotify.accent
        case .claudeCode: prefs.claudeAccent
        }
    }

    /// The tabs (when there's more than one), and the gear that opens Settings in the notch.
    private func tabBar(_ tabs: [NotchTab]) -> some View {
        HStack(spacing: 4) {
            ForEach(tabs.count > 1 ? tabs : [], id: \.self) { item in
                let isSelected = item == tab
                let accent = accent(item)
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { tab = item }
                } label: {
                    Group {
                        if prefs.tabBarShowsLabels {
                            Label(item.title, systemImage: item.symbol)
                        } else {
                            Image(systemName: item.symbol)
                        }
                    }
                    .font(.notch(12, weight: .semibold))
                    .foregroundStyle(isSelected ? accent : .secondary)
                    .padding(.horizontal, prefs.tabBarShowsLabels ? 10 : 14)
                    .padding(.vertical, 5)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(accent.opacity(0.2))
                                .matchedGeometryEffect(id: "pill", in: tabPill)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity, minHeight: 22)
        .overlay(alignment: .trailing) {
            Button {
                NotchState.shared.openSettings()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.notch(12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
            .help("Settings")
        }
    }
}

private struct SpotifyTab: View {
    let spotify: SpotifyController

    var body: some View {
        Group {
            if let track = spotify.track {
                NowPlayingView(spotify: spotify, track: track)
            } else {
                Label("Nothing playing in Spotify", systemImage: "music.note")
                    .font(.notch(12))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// The current session; scrolls if the notch is shorter than its details.
private struct ClaudeCodeTab: View {
    let agent: AgentMonitor

    private var prefs: Preferences { AppSettings.shared.prefs }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            Group {
                if let session = agent.current {
                    AgentStatusView(agent: agent, session: session)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        if ClaudeHooks.isInstalled {
                            Label("Claude Code isn't in use", systemImage: AgentStatus.idle.symbol)
                                .foregroundStyle(.secondary)
                        } else {
                            // Without njrNotch's hooks no session ever reaches the notch.
                            Label("Claude Code isn't connected to njrNotch", systemImage: "bolt.horizontal.circle")
                                .foregroundStyle(.orange)
                            Button("Install the hooks in Settings…") { SettingsWindow.show(.claudeCode) }
                                .buttonStyle(.plain)
                                .foregroundStyle(prefs.claudeAccent)
                        }
                    }
                    .font(.notch(12))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 12)
        }
        .mask { // fade out at the bottom instead of cutting a line in half
            VStack(spacing: 0) {
                Color.black
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom).frame(height: 12)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}
