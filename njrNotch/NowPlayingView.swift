//
//  NowPlayingView.swift
//  njrNotch
//

import SwiftUI

/// Album art, title/artist and playback controls for the current Spotify track.
struct NowPlayingView: View {
    let spotify: SpotifyController
    let track: SpotifyController.Track

    var body: some View {
        HStack(spacing: 14) {
            AsyncImage(url: track.artworkURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.white.opacity(0.1)
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title).font(.headline)
                    Text(track.artist).font(.subheadline).foregroundStyle(.secondary)
                }
                .lineLimit(1)

                HStack(spacing: 18) {
                    control("shuffle", label: "Shuffle", action: spotify.toggleShuffle)
                        .foregroundStyle(spotify.isShuffling ? .green : .secondary)
                    control("backward.fill", label: "Previous", action: spotify.previous)
                    control(spotify.isPlaying ? "pause.fill" : "play.fill",
                            label: spotify.isPlaying ? "Pause" : "Play", action: spotify.playPause)
                        .font(.title2)
                    control("forward.fill", label: "Next", action: spotify.next)
                    // Placeholder: wire up to the Spotify Web API later.
                    control("heart", label: "Like") {}
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
    }

    private func control(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).frame(minWidth: 20)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
