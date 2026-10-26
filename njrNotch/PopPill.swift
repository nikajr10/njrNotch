//
//  PopPill.swift
//  njrNotch
//

import SwiftUI

/// The pop-down notification: icon or album art, a title and one detail line, on black.
/// As wide as the physical notch above it.
struct PopPill: View {
    let note: PopNote
    let width: CGFloat

    var body: some View {
        HStack(spacing: 8) {
            icon.frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(note.title)
                    .font(.notch(12, weight: .semibold))
                    .foregroundStyle(.white)
                if let detail = note.detail, !detail.isEmpty {
                    Text(detail)
                        .font(note.kind == .permission
                              ? .system(size: (11 * AppSettings.shared.prefs.textScale).rounded(), design: .monospaced)
                              : .notch(11))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, 7)
        .padding(.trailing, 12)
        .padding(.vertical, 6)
        .frame(width: width)
        .background(.black, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.08)))
        .contentShape(Capsule())
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder private var icon: some View {
        switch note.kind {
        case .song:
            // The shared download, once it has arrived; until then the URL.
            if let artwork = SpotifyController.shared.artwork, SpotifyController.shared.track?.artworkURL == note.artworkURL {
                Image(nsImage: artwork).resizable().scaledToFill().clipShape(Circle())
            } else {
                AsyncImage(url: note.artworkURL) { image in
                image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "music.note").foregroundStyle(SpotifyController.shared.accent)
                }
                .clipShape(Circle())
            }
        case .done: symbol(AgentStatus.done.symbol, AgentStatus.done.color)
        case .permission: symbol(AgentStatus.needsPermission.symbol, AgentStatus.needsPermission.color)
        case .sessionEnded: symbol("power.circle.fill", .gray)
        case .update: symbol("arrow.down.circle.fill", .blue)
        }
    }

    private func symbol(_ name: String, _ color: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(color)
    }
}
