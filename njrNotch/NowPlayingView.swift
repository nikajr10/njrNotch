//
//  NowPlayingView.swift
//  njrNotch
//

import SwiftUI

/// The Spotify tab: track, a timeline to scrub through the song, and playback controls centred under it.
struct NowPlayingView: View {
    let spotify: SpotifyController
    let track: SpotifyController.Track
    @State private var isHoveringArt = false

    private var prefs: Preferences { AppSettings.shared.prefs }

    var body: some View {
        let art: CGFloat = prefs.compactLayout ? 44 : 56

        VStack(spacing: prefs.compactLayout ? 6 : 10) {
            HStack(spacing: 12) {
                if prefs.showAlbumArt {
                    Group {
                        if let artwork = spotify.artwork {
                            Image(nsImage: artwork).resizable().scaledToFill()
                        } else {
                            Color.primary.opacity(0.1)
                        }
                    }
                    .frame(width: art, height: art)
                    .clipShape(RoundedRectangle(cornerRadius: art * 0.18))
                    .contentShape(RoundedRectangle(cornerRadius: art * 0.18))
                    .scaleEffect(isHoveringArt ? 1.06 : 1)
                    .brightness(isHoveringArt ? 0.08 : 0)
                    .onHover { isHoveringArt = $0 }
                    .animation(.easeOut(duration: 0.15), value: isHoveringArt)
                    .onTapGesture(perform: spotify.showApp)
                    .help("Open Spotify")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("Open Spotify")
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title).font(.notch(13, weight: .semibold))
                    if prefs.showArtist {
                        Text(track.artist).font(.notch(12)).foregroundStyle(.secondary)
                    }
                }
                .lineLimit(1)
                Spacer(minLength: 4)
                if prefs.showVisualizer {
                    Visualizer(isPlaying: spotify.isPlaying, color: spotify.accent)
                }
            }

            if spotify.duration > 0 {
                SongTimeline(spotify: spotify)
            }

            // Shuffle and like keep their slots when hidden, so play/pause stays in the middle.
            HStack(spacing: 10) {
                slot(prefs.showShuffle) {
                    control("shuffle", label: spotify.isShuffling ? "Shuffle on" : "Shuffle off",
                            action: spotify.toggleShuffle)
                        .foregroundStyle(spotify.isShuffling ? spotify.accent : .secondary)
                }
                control("backward.fill", label: "Previous", action: spotify.previous)
                control(spotify.isPlaying ? "pause.fill" : "play.fill",
                        label: spotify.isPlaying ? "Pause" : "Play", size: 44, action: spotify.playPause)
                    .font(.notch(20))
                control("forward.fill", label: "Next", action: spotify.next)
                slot(prefs.showLike) { likeButton }
            }
            .font(.notch(14))
            .frame(maxWidth: .infinity)
        }
        .task(id: "\(track.uri) \(SpotifyAccount.shared.isConnected)") {
            await spotify.loadLiked()
        }
    }

    /// Saves to Liked Songs through the Spotify Web API; without a connected account it opens Settings.
    private var likeButton: some View {
        let liked = spotify.isLiked == true
        return control(liked ? "heart.fill" : "heart", label: liked ? "Remove from Liked Songs" : "Save to Liked Songs") {
            if SpotifyAccount.shared.isConnected {
                spotify.toggleLike()
            } else {
                SettingsWindow.show(.spotify)
            }
        }
        .foregroundStyle(liked ? spotify.accent : .secondary)
        .disabled(!spotify.canLike)
    }

    @ViewBuilder
    private func slot(_ isShown: Bool, @ViewBuilder _ content: () -> some View) -> some View {
        if isShown { content() } else { Color.clear.frame(width: 34, height: 1) }
    }

    private func control(_ symbol: String, label: String, size: CGFloat = 34,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
        }
        .buttonStyle(ControlStyle(size: size))
        .accessibilityLabel(label)
    }
}

/// A round hit area that lights up under the pointer and shrinks a little when pressed.
private struct ControlStyle: ButtonStyle {
    let size: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        ControlBody(configuration: configuration, size: size)
    }

    private struct ControlBody: View {
        let configuration: Configuration
        let size: CGFloat
        @State private var isHovering = false
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .frame(width: size, height: size)
                .background(.primary.opacity(configuration.isPressed ? 0.22 : isHovering && isEnabled ? 0.12 : 0),
                            in: Circle())
                .scaleEffect(configuration.isPressed ? 0.9 : 1)
                .contentShape(Circle())
                .onHover { isHovering = $0 }
                .animation(.easeOut(duration: 0.15), value: isHovering)
                .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
        }
    }
}

/// Elapsed time, the song's bar, and time left. Click or drag the bar to move through the song.
private struct SongTimeline: View {
    let spotify: SpotifyController
    /// Where the user is dragging to; the playhead stays put until they let go.
    @State private var scrub: Double?
    @State private var isHovering = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1, paused: !spotify.isPlaying)) { context in
            let position = scrub ?? spotify.position(at: context.date)
            HStack(spacing: 8) {
                Text(Self.time(position))
                bar(position)
                Text("-" + Self.time(spotify.duration - position))
            }
            .font(.notch(10).monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    private func bar(_ position: Double) -> some View {
        let fraction = position / spotify.duration
        let isActive = isHovering || scrub != nil
        return GeometryReader { geometry in
            CapsuleBar(fraction: fraction, color: spotify.accent, height: isActive ? 6 : 4)
                .overlay(alignment: .leading) {
                    if isActive {
                        Circle().fill(.primary).frame(width: 10, height: 10)
                            .offset(x: geometry.size.width * fraction - 5)
                    }
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        scrub = min(max(drag.location.x / geometry.size.width, 0), 1) * spotify.duration
                    }
                    .onEnded { _ in
                        if let scrub { spotify.seek(to: scrub) }
                        scrub = nil
                    })
        }
        .frame(height: 14)
        .onHover { isHovering = $0 }
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isActive)
        .accessibilityElement()
        .accessibilityLabel("Song position")
        .accessibilityValue("\(Self.time(position)) of \(Self.time(spotify.duration))")
        .accessibilityAdjustableAction { direction in
            let step: Double = direction == .increment ? 10 : -10
            spotify.seek(to: min(max(position + step, 0), spotify.duration))
        }
    }

    private static func time(_ seconds: Double) -> String {
        Duration.seconds(max(0, seconds)).formatted(.time(pattern: .minuteSecond))
    }
}

/// Bars that bounce while music plays. Decoration only: real audio levels need screen-recording permission.
struct Visualizer: View {
    let isPlaying: Bool
    let color: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !isPlaying)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2) {
                ForEach(0..<4) { bar in
                    Capsule()
                        .frame(width: 3, height: isPlaying ? 4 + 10 * abs(sin(t * (4.1 + Double(bar) * 1.3) + Double(bar))) : 3)
                }
            }
            .frame(height: 14)
        }
        .foregroundStyle(color)
        .accessibilityHidden(true)
    }
}
