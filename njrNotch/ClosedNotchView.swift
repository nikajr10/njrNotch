//
//  ClosedNotchView.swift
//  njrNotch
//

import AppKit
import SwiftUI

/// Live activity shown on both sides of the closed notch.
enum ClosedActivity: Equatable {
    case spotify(artwork: URL?, isPlaying: Bool)
    case claude(AgentStatus)

    var tab: NotchTab {
        if case .spotify = self { .spotify } else { .claudeCode }
    }

    /// Claude needing permission always wins; otherwise the source picked in Settings,
    /// falling back to whichever one has something to show.
    static func pick(spotify: ClosedActivity?, spotifyChanged: Date,
                     claude: ClosedActivity?, claudeChanged: Date, source: ClosedSource) -> ClosedActivity? {
        if claude == .claude(.needsPermission) { return claude }
        guard let spotify, let claude else { return claude ?? spotify }
        return switch source {
        case .spotify: spotify
        case .claudeCode: claude
        case .auto: spotifyChanged > claudeChanged ? spotify : claude
        }
    }

    #if DEBUG
    /// Runnable check for the priority rules; called once at launch in debug builds.
    static func selfCheck() {
        let music = ClosedActivity.spotify(artwork: nil, isPlaying: true)
        let early = Date(timeIntervalSince1970: 0), late = Date(timeIntervalSince1970: 1)
        assert(pick(spotify: music, spotifyChanged: late, claude: .claude(.needsPermission), claudeChanged: early,
                    source: .spotify) == .claude(.needsPermission))
        assert(pick(spotify: music, spotifyChanged: early, claude: .claude(.working), claudeChanged: late,
                    source: .spotify) == music)
        assert(pick(spotify: music, spotifyChanged: early, claude: .claude(.working), claudeChanged: late,
                    source: .auto) == .claude(.working))
        assert(pick(spotify: nil, spotifyChanged: late, claude: .claude(.done), claudeChanged: early,
                    source: .spotify) == .claude(.done))
        assert(pick(spotify: nil, spotifyChanged: late, claude: nil, claudeChanged: early, source: .auto) == nil)
    }
    #endif
}

/// The closed notch: the physical notch with a small "ear" on each side when there's live activity.
/// Ears are the same width on both sides, so the notch stays centred.
struct ClosedNotchView: View {
    let notchSize: CGSize
    let activity: ClosedActivity?

    private var prefs: Preferences { AppSettings.shared.prefs }

    var body: some View {
        let ear = notchSize.height
        HStack(spacing: 0) {
            if let activity {
                left(activity, ear: ear)
                    .frame(width: ear, height: ear)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
            }
            Color.clear.frame(width: notchSize.width)
            if let activity {
                right(activity, ear: ear)
                    .frame(width: ear, height: ear)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
            }
        }
        .frame(height: notchSize.height)
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private func left(_ activity: ClosedActivity, ear: CGFloat) -> some View {
        switch activity {
        case .spotify(let artwork, _):
            if prefs.closedShowsArt, let artwork {
                AsyncImage(url: artwork) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.white.opacity(0.12)
                }
                .frame(width: (ear * 0.62).rounded(), height: (ear * 0.62).rounded())
                .clipShape(RoundedRectangle(cornerRadius: ear * 0.14, style: .continuous))
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: (ear * 0.4).rounded(), weight: .semibold))
                    .foregroundStyle(.green)
            }
        case .claude:
            Image(systemName: "sparkle")
                .font(.system(size: (ear * 0.42).rounded(), weight: .semibold))
                .foregroundStyle(Color(hex: "#D97757"))
        }
    }

    @ViewBuilder
    private func right(_ activity: ClosedActivity, ear: CGFloat) -> some View {
        switch activity {
        case .spotify(_, let isPlaying):
            if isPlaying && prefs.closedShowsEqualizer {
                EqualizerBars(color: NSColor(prefs.accent))
                    .frame(width: (ear * 0.5).rounded(), height: (ear * 0.42).rounded())
            } else {
                Image(systemName: isPlaying ? "play.fill" : "pause.fill")
                    .font(.system(size: (ear * 0.34).rounded()))
                    .foregroundStyle(.secondary)
            }
        case .claude(.working):
            Spinner()
        case .claude(let status):
            AgentStatusIcon(status: status, size: (ear * 0.42).rounded())
        }
    }

    private var label: String {
        switch activity {
        case .spotify(_, let isPlaying): isPlaying ? "Spotify playing" : "Spotify paused"
        case .claude(let status): "Claude Code \(status.label)"
        case nil: "Notch"
        }
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
