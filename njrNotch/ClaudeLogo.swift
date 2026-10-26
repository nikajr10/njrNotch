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

/// A heart monitor trace: a beat runs across and fades out behind itself. Core Animation runs it,
/// so the notch doesn't redraw every frame. `animates` off shows the whole trace, still.
struct Heartbeat: NSViewRepresentable {
    let color: NSColor
    let animates: Bool

    func makeNSView(context: Context) -> TraceView { TraceView() }

    func updateNSView(_ view: TraceView, context: Context) {
        view.trace.strokeColor = color.cgColor
        view.trace.shadowColor = color.cgColor
        view.setBeating(animates)
    }

    final class TraceView: NSView {
        let trace = CAShapeLayer()
        /// (x, y) in 0...1, y up: flat, P wave, the QRS spike, T wave, flat.
        private static let points: [(CGFloat, CGFloat)] = [
            (0, 0.5), (0.2, 0.5), (0.26, 0.6), (0.32, 0.5), (0.4, 0.5), (0.45, 0.38),
            (0.52, 0.98), (0.59, 0.04), (0.64, 0.5), (0.73, 0.5), (0.8, 0.66), (0.87, 0.5), (1, 0.5),
        ]

        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            trace.fillColor = nil
            trace.lineWidth = 1.5
            trace.lineCap = .round
            trace.lineJoin = .round
            trace.shadowOpacity = 0.9 // a soft glow, like a monitor screen
            trace.shadowRadius = 2
            trace.shadowOffset = .zero
            layer?.addSublayer(trace)
        }

        required init?(coder: NSCoder) { fatalError("not used") }

        func setBeating(_ on: Bool) {
            guard on != (trace.animation(forKey: "beat") != nil) else { return }
            guard on else { return trace.removeAnimation(forKey: "beat") }
            let head = CAKeyframeAnimation(keyPath: "strokeEnd")
            head.values = [0, 1, 1]
            head.keyTimes = [0, 0.6, 1]
            let tail = CAKeyframeAnimation(keyPath: "strokeStart")
            tail.values = [0, 0, 1]
            tail.keyTimes = [0, 0.3, 1]
            let beat = CAAnimationGroup()
            beat.animations = [head, tail]
            beat.duration = 1.2
            beat.repeatCount = .infinity
            trace.add(beat, forKey: "beat")
        }

        override func layout() {
            super.layout()
            trace.frame = bounds
            let path = CGMutablePath()
            path.addLines(between: Self.points.map { CGPoint(x: $0.0 * bounds.width, y: $0.1 * bounds.height) })
            trace.path = path
        }
    }
}
