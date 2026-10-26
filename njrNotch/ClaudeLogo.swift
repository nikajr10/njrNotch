//
//  ClaudeLogo.swift
//  njrNotch
//

import AppKit
import SwiftUI

/// The Claude Code mascot: your own "ClaudeLogo" image from the asset catalog if you add one, else the pixel
/// creature from Claude Code's welcome screen.
struct ClaudeLogo: View {
    static let orange = Color(hex: Preferences.claudeOrange)
    private static let custom = NSImage(named: "ClaudeLogo")

    var body: some View {
        if let image = Self.custom {
            Image(nsImage: image).resizable().scaledToFit()
        } else {
            Mascot().fill(Self.orange).aspectRatio(Mascot.aspect, contentMode: .fit)
        }
    }
}

/// Pixel by pixel from Claude Code's banner (` ▐▛███▜▌` / `▝▜█████▛▘` / `  ▘▘ ▝▝`): body with two eyes,
/// arms, four legs. Each block-character quarter is one pixel, twice as tall as it is wide.
struct Mascot: Shape {
    private static let pixels = [
        "..############..",
        "..##.######.##..",
        "################",
        "..############..",
        "...#.#....#.#...",
    ]
    static let aspect = CGFloat(pixels[0].count) / CGFloat(pixels.count * 2)

    func path(in rect: CGRect) -> Path {
        let width = rect.width / CGFloat(Self.pixels[0].count), height = rect.height / CGFloat(Self.pixels.count)
        var path = Path()
        for (row, line) in Self.pixels.enumerated() {
            for (column, pixel) in line.enumerated() where pixel == "#" {
                path.addRect(CGRect(x: rect.minX + CGFloat(column) * width, y: rect.minY + CGFloat(row) * height,
                                    width: width, height: height))
            }
        }
        return path
    }
}

/// The mascot with Claude's state on it: a check badge when done, a pulsing alert badge when it needs
/// permission. `animates` off keeps the badges still.
struct ClaudeLogoBadge: View {
    let status: AgentStatus
    let size: CGFloat
    var animates = true

    var body: some View {
        ClaudeLogo()
            .frame(width: size * 0.8, height: size * 0.8)
            .frame(width: size, height: size)
            .overlay(alignment: .bottomTrailing) {
                if status == .done || status == .needsPermission {
                    AgentStatusIcon(status: status, size: (size * 0.34).rounded(), animates: animates)
                        .background(Circle().fill(.black).padding(-1.5))
                        .offset(x: size * 0.08, y: size * 0.08)
                }
            }
    }
}

/// Claude Code's busy sign from its terminal title: a half-filled circle in Claude orange that swaps
/// sides every second. One redraw a second, so it costs next to nothing.
struct BusyCircle: View {
    let size: CGFloat
    var animates = true

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let left = !animates || Int(context.date.timeIntervalSinceReferenceDate) % 2 == 0
            Image(systemName: left ? "circle.lefthalf.filled" : "circle.righthalf.filled")
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(ClaudeLogo.orange)
        }
    }
}
