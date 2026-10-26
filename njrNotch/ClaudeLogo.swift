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

/// Claude Code's busy sign from its terminal title: a half-filled circle in Claude orange that swaps sides
/// every 1.5 s with the system's soft replace transition. Calm enough to sit in the corner of your eye
/// (a 1 s hard flip read as blinking), still clearly alive. Core Animation runs the transition.
struct BusyCircle: NSViewRepresentable {
    let size: CGFloat
    var animates = true
    static let interval: TimeInterval = 1.5

    func makeNSView(context: Context) -> NSImageView {
        let view = NSImageView()
        view.contentTintColor = NSColor(ClaudeLogo.orange)
        context.coordinator.view = view
        return view
    }

    func updateNSView(_ view: NSImageView, context: Context) {
        context.coordinator.configure(size: size, animates: animates)
    }

    static func dismantleNSView(_ view: NSImageView, coordinator: Coordinator) {
        coordinator.timer?.invalidate()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        weak var view: NSImageView?
        var timer: Timer?
        private var shown: (CGFloat, Bool)?
        private var size: CGFloat = 0
        private var isLeft = true

        /// Only on a real change: restarting on every SwiftUI update would reset the rhythm.
        func configure(size: CGFloat, animates: Bool) {
            guard shown.map({ $0 != (size, animates) }) ?? true else { return }
            shown = (size, animates)
            self.size = size
            isLeft = true
            view?.image = image()
            timer?.invalidate()
            timer = nil
            guard animates else { return }
            timer = Timer.scheduledTimer(withTimeInterval: BusyCircle.interval, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.flip() }
            }
        }

        private func flip() {
            isLeft.toggle()
            if let image = image() { view?.setSymbolImage(image, contentTransition: .replace) }
        }

        private func image() -> NSImage? {
            NSImage(systemSymbolName: isLeft ? "circle.lefthalf.filled" : "circle.righthalf.filled",
                    accessibilityDescription: "Working")?
                .withSymbolConfiguration(.init(pointSize: size, weight: .semibold))
        }
    }
}
