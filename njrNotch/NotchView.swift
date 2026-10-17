//
//  NotchView.swift
//  njrNotch
//

import SwiftUI

/// Black notch pinned to the top edge. Closed: the notch with live activity on each side, and
/// pop-down notifications under it. Open (hover, click or the shortcut): tabs for Spotify and Claude Code,
/// or Settings.
struct NotchView: View {
    let notchSize: CGSize
    let spotify: SpotifyController
    let agent: AgentMonitor
    let pop: PopNotifier

    @Bindable private var state = NotchState.shared
    @Bindable private var settings = AppSettings.shared
    @State private var isFinishPulse = false
    /// Paused longer than `idleHidesAfter`: the closed notch stops showing the song.
    @State private var isMusicStale = false
    @State private var hoverDelay: Task<Void, Never>?


    private var prefs: Preferences { AppSettings.shared.prefs }
    private var spring: Animation { .spring(response: prefs.animationDuration, dampingFraction: 0.8) }

    var body: some View {
        ZStack(alignment: .top) {
            if let note = pop.current, !state.isExpanded {
                PopPill(note: note, width: notchSize.width)
                    .padding(.top, notchSize.height + 3)
                    .onHover { pop.isHovering = $0 }
                    .onTapGesture {
                        pop.dismiss()
                        state.open(note.tab)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            notch
        }
        .animation(.spring(response: prefs.popAnimation, dampingFraction: 0.75), value: pop.current?.id)
        .onChange(of: pop.current?.id) {
            // Already looking at it: no pill.
            if state.isExpanded, !state.showsSettings, pop.current?.tab == state.tab { pop.dismiss() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var notch: some View {
        let radius = state.isExpanded ? prefs.cornerRadius : 10
        let shape = UnevenRoundedRectangle(bottomLeadingRadius: radius, bottomTrailingRadius: radius)

        return Group {
            if state.isExpanded {
                if state.showsSettings {
                    NotchSettingsView(notchSize: notchSize)
                        .transition(.opacity)
                } else {
                    NotchContent(notchSize: notchSize, spotify: spotify, agent: agent, tab: $state.tab)
                        .transition(.opacity)
                }
            } else {
                ClosedNotchView(notchSize: notchSize, activity: activity, spotify: spotify)
            }
        }
        .background {
            if state.isExpanded { NotchFill() } else { Color.black }
        }
        .clipShape(shape)
        .contentShape(shape)
        .onHover { hovering in
            hoverDelay?.cancel()
            if hovering && !prefs.openOnClick && isPointerOnClosedNotch {
                hoverDelay = Task {
                    try? await Task.sleep(for: .seconds(prefs.openDelay))
                    if !Task.isCancelled, !state.isExpanded, isPointerOnClosedNotch {
                        state.setExpanded(true, tab: activity?.tab)
                    }
                }
            }
            // Settings stay open (colour panel, menus) until Back.
            if !hovering && !state.showsSettings { state.setExpanded(false) }
        }
        .onTapGesture {
            if !state.isExpanded { state.setExpanded(true, tab: activity?.tab) }
        }
        // Works without the menu bar icon, which the MacBook notch can hide.
        .contextMenu {
            Button("Settings") { state.openSettings() }
            Button("Open Spotify tab") { state.open(.spotify) }
                .disabled(!NotchTab.spotify.isEnabled)
            Button("Open Claude Code tab") { state.open(.claudeCode) }
                .disabled(!NotchTab.claudeCode.isEnabled)
            Toggle("Show previews", isOn: $settings.prefs.showClosedIndicator)
            Divider()
            Button("Quit njrNotch") { NSApp.terminate(nil) }
        }
        .animation(spring, value: activity)
        .task(id: agent.finishCount) {
            guard agent.finishCount > 0 else { return }
            isFinishPulse = true
            try? await Task.sleep(for: .seconds(prefs.idleHidesAfter))
            isFinishPulse = false
        }
        .task(id: "\(spotify.isPlaying) \(spotify.track?.uri ?? "")") {
            isMusicStale = false
            guard !spotify.isPlaying else { return }
            try? await Task.sleep(for: .seconds(prefs.idleHidesAfter))
            if !Task.isCancelled { isMusicStale = true }
        }
    }

    /// SwiftUI checks hover against the shape mid-animation, so a pointer resting under the closed notch but
    /// inside the open one made it open and close in a loop. Opening on hover needs the pointer really on
    /// the closed notch (and its ears).
    private var isPointerOnClosedNotch: Bool {
        guard let screen = NSScreen.target else { return false }
        let width = notchSize.width + (activity == nil ? 0 : 2 * notchSize.height)
        let rect = NSRect(x: screen.frame.midX - width / 2, y: screen.frame.maxY - notchSize.height,
                          width: width, height: notchSize.height)
        return rect.insetBy(dx: -2, dy: -2).contains(NSEvent.mouseLocation)
    }

    // MARK: - Closed

    private var activity: ClosedActivity? {
        guard prefs.showClosedIndicator else { return nil }
        return ClosedActivity.pick(music: music, claude: claudeStatus, source: prefs.closedSource)
    }

    /// true playing, false paused recently, nil for no music (Spotify closed, stopped or paused long ago).
    private var music: Bool? {
        guard prefs.showSpotify, spotify.track != nil, spotify.isPlaying || !isMusicStale else { return nil }
        return spotify.isPlaying
    }

    /// Any session needing permission, else working, else a brief "done".
    private var claudeStatus: AgentStatus? {
        guard prefs.claudeCodeEnabled else { return nil }
        let statuses = agent.sessions.map(\.status)
        if statuses.contains(.needsPermission) { return .needsPermission }
        if statuses.contains(.working) { return .working }
        return isFinishPulse ? .done : nil
    }
}
