//
//  PopPill.swift
//  njrNotch
//

import SwiftUI

/// The pop-down notification: icon or album art, a title and one detail line, on black.
struct PopPill: View {
    let note: PopNote

    var body: some View {
        HStack(spacing: 10) {
            icon.frame(width: 30, height: 30)
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
        .padding(.leading, 8)
        .padding(.trailing, 14)
        .padding(.vertical, 7)
        .frame(width: 320)
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
            AsyncImage(url: note.artworkURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "music.note").foregroundStyle(.green)
            }
            .clipShape(Circle())
        case .done: symbol(AgentStatus.done.symbol, AgentStatus.done.color)
        case .permission: symbol(AgentStatus.needsPermission.symbol, AgentStatus.needsPermission.color)
        case .sessionEnded: symbol("power.circle.fill", .gray)
        }
    }

    private func symbol(_ name: String, _ color: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(color)
    }
}
