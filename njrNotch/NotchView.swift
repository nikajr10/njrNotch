//
//  NotchView.swift
//  njrNotch
//

import SwiftUI

/// Black notch pinned to the top edge. Closed: the notch plus small status "ears".
/// Open (hover or click): tabs for Spotify and Claude Code.
struct NotchView: View {
    let notchSize: CGSize
    let spotify: SpotifyController
    let agent: AgentMonitor
    let limits: UsageLimits

    @State private var isExpanded = false
    @State private var isFinishPulse = false
    @State private var tab = NotchTab.claudeCode
    @State private var hoverDelay: Task<Void, Never>?

    private var prefs: Preferences { AppSettings.shared.prefs }
    private var spring: Animation { .spring(response: prefs.animationDuration, dampingFraction: 0.8) }

    var body: some View {
        let radius = isExpanded ? prefs.cornerRadius : 10
        let shape = UnevenRoundedRectangle(bottomLeadingRadius: radius, bottomTrailingRadius: radius)

        Group {
            if isExpanded {
                NotchContent(notchSize: notchSize, spotify: spotify, agent: agent, limits: limits, tab: $tab)
            } else {
                closed
            }
        }
        .background {
            if isExpanded { NotchFill() } else { Color.black }
        }
        .clipShape(shape)
        .contentShape(shape)
        .onHover { hovering in
            hoverDelay?.cancel()
            if hovering && !prefs.openOnClick {
                hoverDelay = Task {
                    try? await Task.sleep(for: .seconds(prefs.openDelay))
                    if !Task.isCancelled { setExpanded(true) }
                }
            }
            if !hovering { setExpanded(false) }
        }
        .onTapGesture {
            if !isExpanded { setExpanded(true) }
        }
        .contextMenu {
            Button("Settings…") { SettingsWindow.show() }
            Button("Quit njrNotch") { NSApp.terminate(nil) }
        }
        .animation(spring, value: indicator)
        .task(id: agent.finishCount) {
            guard agent.finishCount > 0 else { return }
            isFinishPulse = true
            try? await Task.sleep(for: .seconds(3))
            isFinishPulse = false
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func setExpanded(_ open: Bool) {
        guard open != isExpanded else { return }
        if open {
            spotify.refresh() // shuffle changes made in Spotify aren't broadcast
            if indicator == .needsPermission { tab = .claudeCode }
        } else {
            agent.selectedID = nil // reopen on the most urgent session
        }
        withAnimation(spring) { isExpanded = open }
    }

    // MARK: - Closed

    /// What the closed notch shows: any session needing permission, else working, else a brief "done".
    private var indicator: AgentStatus? {
        guard prefs.claudeCodeEnabled, prefs.showClosedIndicator else { return nil }
        let statuses = agent.sessions.map(\.status)
        if statuses.contains(.needsPermission) { return .needsPermission }
        if statuses.contains(.working) { return .working }
        return isFinishPulse ? .done : nil
    }

    private var closed: some View {
        let ear = notchSize.height
        return HStack(spacing: 0) {
            if let indicator {
                AgentStatusIcon(status: indicator, size: (ear * 0.42).rounded())
                    .frame(width: ear)
                    .transition(.opacity)
            }
            Color.clear.frame(width: notchSize.width)
            if let indicator {
                Circle()
                    .fill(indicator.color)
                    .frame(width: 7, height: 7)
                    .frame(width: ear)
                    .transition(.opacity)
            }
        }
        .frame(height: notchSize.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(indicator.map { "Agent \($0.label)" } ?? "Notch")
    }
}
