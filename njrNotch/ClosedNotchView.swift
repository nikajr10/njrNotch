//
//  ClosedNotchView.swift
//  njrNotch
//

import AppKit
import SwiftUI

/// What the closed notch shows on each side.
struct ClosedActivity: Equatable {
    enum Side: Hashable {
        case artwork, equalizer, paused
        /// The Claude logo with its state on it (ring, check or alert badge).
        case logo(AgentStatus)
        /// Spinner, check mark or alert icon.
        case state(AgentStatus)
    }

    var left: Side
    var right: Side
    /// The tab hovering opens.
    var tab: NotchTab

    /// - music: nil = no music, true = playing, false = paused recently.
    /// - claude: nil = no active session.
    /// Music keeps the left side whenever it's there, so the sides never swap back and forth.
    static func pick(music: Bool?, claude: AgentStatus?, source: ClosedSource) -> ClosedActivity? {
        let music = source == .claudeCode ? nil : music
        let claude = source == .spotify ? nil : claude
        switch (music, claude) {
        case (_?, let status?):
            return ClosedActivity(left: .artwork, right: .logo(status),
                                  tab: status == .needsPermission ? .claudeCode : .spotify)
        case (let playing?, nil):
            return ClosedActivity(left: .artwork, right: playing ? .equalizer : .paused, tab: .spotify)
        case (nil, let status?):
            return ClosedActivity(left: .logo(status), right: .state(status), tab: .claudeCode)
        case (nil, nil):
            return nil
        }
    }

    #if DEBUG
    /// Runnable check for the layout rules; called once at launch in debug builds.
    static func selfCheck() {
        assert(pick(music: true, claude: nil, source: .auto) == .init(left: .artwork, right: .equalizer, tab: .spotify))
        assert(pick(music: false, claude: nil, source: .auto)?.right == .paused)
        assert(pick(music: true, claude: .working, source: .auto) == .init(left: .artwork, right: .logo(.working), tab: .spotify))
        assert(pick(music: false, claude: .needsPermission, source: .auto)?.tab == .claudeCode)
        assert(pick(music: nil, claude: .done, source: .auto) == .init(left: .logo(.done), right: .state(.done), tab: .claudeCode))
        assert(pick(music: true, claude: .working, source: .spotify)?.right == .equalizer)
        assert(pick(music: true, claude: .working, source: .claudeCode)?.left == .logo(.working))
        assert(pick(music: nil, claude: nil, source: .auto) == nil)
    }
    #endif
}

/// The closed notch: the physical notch with a small "ear" on each side when there's live activity.
/// Ears are the same width on both sides, so the notch stays centred.
struct ClosedNotchView: View {
    let notchSize: CGSize
    let activity: ClosedActivity?
    let spotify: SpotifyController

    private var prefs: Preferences { AppSettings.shared.prefs }

    var body: some View {
        let ear = notchSize.height
        HStack(spacing: 0) {
            if let activity {
                side(activity.left, ear: ear)
            }
            Color.clear.frame(width: notchSize.width)
            if let activity {
                side(activity.right, ear: ear)
            }
        }
        .frame(height: notchSize.height)
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    private func side(_ side: ClosedActivity.Side, ear: CGFloat) -> some View {
        content(side, ear: ear)
            .frame(width: ear, height: ear)
            .id(side) // a new kind of content scales in rather than morphing
            .transition(.scale(scale: 0.5).combined(with: .opacity))
    }

    @ViewBuilder
    private func content(_ side: ClosedActivity.Side, ear: CGFloat) -> some View {
        switch side {
        case .artwork:
            if prefs.closedShowsArt, let artwork = spotify.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .scaledToFill()
                    .frame(width: (ear * 0.62).rounded(), height: (ear * 0.62).rounded())
                    .clipShape(RoundedRectangle(cornerRadius: ear * 0.14, style: .continuous))
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: (ear * 0.4).rounded(), weight: .semibold))
                    .foregroundStyle(spotify.accent)
            }
        case .equalizer:
            if prefs.closedShowsEqualizer {
                EqualizerBars(color: NSColor(spotify.accent))
                    .frame(width: (ear * 0.5).rounded(), height: (ear * 0.42).rounded())
            } else {
                Image(systemName: "play.fill")
                    .font(.system(size: (ear * 0.34).rounded()))
                    .foregroundStyle(.secondary)
            }
        case .paused:
            Image(systemName: "pause.fill")
                .font(.system(size: (ear * 0.34).rounded()))
                .foregroundStyle(.secondary)
        case .logo(let status):
            ClaudeLogoBadge(status: status, size: (ear * 0.66).rounded(), animates: prefs.closedLogoAnimates)
        case .state(.working):
            Spinner()
        case .state(let status):
            AgentStatusIcon(status: status, size: (ear * 0.42).rounded(), animates: prefs.closedLogoAnimates)
        }
    }

    private var label: String {
        guard let activity else { return "Notch" }
        let music = activity.left == .artwork ? (activity.right == .paused ? "Spotify paused" : "Spotify playing") : nil
        let claude: String? = switch (activity.left, activity.right) {
        case (.logo(let status), _), (_, .logo(let status)): "Claude Code \(status.label)"
        default: nil
        }
        return [music, claude].compactMap { $0 }.joined(separator: ", ")
    }
}

/// Bars that bounce while music plays. Core Animation runs them, so the notch doesn't redraw
/// every frame. Decoration only: real audio levels need screen-recording permission.
struct EqualizerBars: NSViewRepresentable {
    let color: NSColor

    func makeNSView(context: Context) -> BarsView { BarsView() }

    func updateNSView(_ view: BarsView, context: Context) {
        view.bars.forEach { $0.backgroundColor = color.cgColor }
    }

    final class BarsView: NSView {
        let bars = (0..<4).map { _ in CALayer() }

        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            for (index, bar) in bars.enumerated() {
                layer?.addSublayer(bar)
                let bounce = CABasicAnimation(keyPath: "transform.scale.y")
                bounce.fromValue = 0.3
                bounce.toValue = 1
                bounce.duration = 0.32 + Double(index % 3) * 0.11
                bounce.autoreverses = true
                bounce.repeatCount = .infinity
                bounce.timeOffset = Double(index) * 0.17
                bounce.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                bar.add(bounce, forKey: "bounce")
            }
        }

        required init?(coder: NSCoder) { fatalError("not used") }

        override func layout() {
            super.layout()
            let gap: CGFloat = 2
            let width = (bounds.width - gap * CGFloat(bars.count - 1)) / CGFloat(bars.count)
            for (index, bar) in bars.enumerated() {
                bar.frame = CGRect(x: CGFloat(index) * (width + gap), y: 0, width: width, height: bounds.height)
                bar.cornerRadius = width / 2
            }
        }
    }
}

/// Native spinning indicator, light on the black notch.
struct Spinner: NSViewRepresentable {
    func makeNSView(context: Context) -> NSProgressIndicator {
        let view = NSProgressIndicator()
        view.style = .spinning
        view.controlSize = .small
        view.appearance = NSAppearance(named: .darkAqua)
        view.startAnimation(nil)
        return view
    }

    func updateNSView(_ view: NSProgressIndicator, context: Context) {}
}
