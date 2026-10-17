//
//  NotchView.swift
//  njrNotch
//

import SwiftUI

/// Black notch shape pinned to the top edge; grows on hover, shrinks back on exit.
struct NotchView: View {
    static let expandedSize = CGSize(width: 420, height: 160)

    let notchSize: CGSize
    let spotify: SpotifyController
    @State private var isExpanded = false

    var body: some View {
        let size = isExpanded ? Self.expandedSize : notchSize
        let radius: CGFloat = isExpanded ? 28 : 10

        UnevenRoundedRectangle(bottomLeadingRadius: radius, bottomTrailingRadius: radius)
            .fill(.black)
            .overlay {
                if isExpanded, let track = spotify.track {
                    NowPlayingView(spotify: spotify, track: track)
                        .padding(.horizontal, 20)
                        .padding(.top, notchSize.height)
                        .transition(.opacity)
                }
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .contentShape(Rectangle())
            .onHover { hovering in
                // Shuffle changes made inside Spotify aren't broadcast, so re-read on open.
                if hovering { spotify.refresh() }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded = hovering
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

#Preview {
    NotchView(notchSize: CGSize(width: 200, height: 32), spotify: SpotifyController())
        .frame(width: 420, height: 160)
}
