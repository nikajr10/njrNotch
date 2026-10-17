//
//  NotchView.swift
//  njrNotch
//

import SwiftUI

/// Black notch pinned to the top edge. Closed: the notch with live activity on each side, and
/// pop-down notifications under it. Open (hover or click): tabs for Spotify and Claude Code.
struct NotchView: View {
    let notchSize: CGSize
    let spotify: SpotifyController
    let agent: AgentMonitor
    let pop: PopNotifier

    @State private var isExpanded = false
    @State private var isFinishPulse = false
    @State private var tab = NotchTab.claudeCode
    @State private var hoverDelay: Task<Void, Never>?

    private var prefs: Preferences { AppSettings.shared.prefs }
    private var spring: Animation { .spring(response: prefs.animationDuration, dampingFraction: 0.8) }

    var body: some View {
        ZStack(alignment: .top) {
            if let note = pop.current, !isExpanded {
                PopPill(note: note)
                    .padding(.top, notchSize.height + 8)
                    .onHover { pop.isHovering = $0 }
                    .onTapGesture {
                        pop.dismiss()
                        open(on: note.tab)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            notch
        }
        .animation(.spring(response: prefs.popAnimation, dampingFraction: 0.75), value: pop.current?.id)
        .onChange(of: pop.current?.id) {
            // Already looking at it: no pill.
            if isExpanded, pop.current?.tab == tab { pop.dismiss() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var notch: some View {
        let radius = isExpanded ? prefs.cornerRadius : 10
        let shape = UnevenRoundedRectangle(bottomLeadingRadius: radius, bottomTrailingRadius: radius)

        return Group {
            if isExpanded {
                NotchContent(notchSize: notchSize, spotify: spotify, agent: agent, tab: $tab)
            } else {
                ClosedNotchView(notchSize: notchSize, activity: activity)
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
        .animation(spring, value: activity)
        .task(id: agent.finishCount) {
            guard agent.finishCount > 0 else { return }
            isFinishPulse = true
            try? await Task.sleep(for: .seconds(5))
            isFinishPulse = false
        }
    }

    private func setExpanded(_ open: Bool) {
        guard open != isExpanded else { return }
        if open {
            spotify.refresh() // shuffle changes made in Spotify aren't broadcast
            if let activity { tab = activity.tab }
        } else {
            agent.selectedID = nil // reopen on the most urgent session
        }
        withAnimation(spring) { isExpanded = open }
    }

    private func open(on tab: NotchTab) {
        setExpanded(true)
        self.tab = tab
    }

    // MARK: - Closed

    private var activity: ClosedActivity? {
        guard prefs.showClosedIndicator else { return nil }
        return ClosedActivity.pick(
            spotify: spotifyActivity, spotifyChanged: spotify.changedAt,
            claude: claudeActivity, claudeChanged: agent.sessions.map(\.updatedAt).max() ?? .distantPast,
            source: prefs.closedSource
        )
    }

    private var spotifyActivity: ClosedActivity? {
        guard prefs.showSpotify, let track = spotify.track else { return nil }
        return .spotify(artwork: track.artworkURL, isPlaying: spotify.isPlaying)
    }

    /// Any session needing permission, else working, else a brief "done".
    private var claudeActivity: ClosedActivity? {
        guard prefs.claudeCodeEnabled else { return nil }
        let statuses = agent.sessions.map(\.status)
        if statuses.contains(.needsPermission) { return .claude(.needsPermission) }
        if statuses.contains(.working) { return .claude(.working) }
        return isFinishPulse ? .claude(.done) : nil
    }
}
