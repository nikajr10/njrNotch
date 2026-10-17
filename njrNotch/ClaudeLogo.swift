//
//  ClaudeLogo.swift
//  njrNotch
//

import AppKit
import SwiftUI

/// Claude's sparkle: your own "ClaudeLogo" image from the asset catalog if you add one, else a drawn starburst.
struct ClaudeLogo: View {
    static let orange = Color(hex: Preferences.claudeOrange)
    private static let custom = NSImage(named: "ClaudeLogo")

    var body: some View {
        if let image = Self.custom {
            Image(nsImage: image).resizable().scaledToFit()
        } else {
            GeometryReader { geometry in
                let size = min(geometry.size.width, geometry.size.height)
                Starburst()
                    .fill(Self.orange)
                    .overlay(Starburst().stroke(Self.orange, style: StrokeStyle(lineWidth: size * 0.07, lineJoin: .round)))
            }
            .aspectRatio(1, contentMode: .fit)
        }
    }
}

/// Twelve rays of alternating length around a small centre.
struct Starburst: Shape {
    func path(in rect: CGRect) -> Path {
        let rays = 12
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 * 0.92 // room for the rounded stroke
        var path = Path()
        for i in 0..<rays * 2 {
            let angle = Double(i) * .pi / Double(rays) - .pi / 2
            let length = i.isMultiple(of: 2) ? (i.isMultiple(of: 4) ? 1 : 0.82) : 0.3
            let point = CGPoint(x: centre.x + cos(angle) * radius * length, y: centre.y + sin(angle) * radius * length)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

/// The logo with Claude's state on it: a slowly turning orange ring while working, a check badge when done,
/// a pulsing alert badge when it needs permission. `animates` off keeps the ring and badges still.
struct ClaudeLogoBadge: View {
    let status: AgentStatus
    let size: CGFloat
    var animates = true

    var body: some View {
        ClaudeLogo()
            .frame(width: size * 0.6, height: size * 0.6)
            .frame(width: size, height: size)
            .overlay {
                if status == .working {
                    RotatingRing(color: NSColor(ClaudeLogo.orange), animates: animates)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if status == .done || status == .needsPermission {
                    AgentStatusIcon(status: status, size: (size * 0.34).rounded(), animates: animates)
                        .background(Circle().fill(.black).padding(-1.5))
                        .offset(x: size * 0.08, y: size * 0.08)
                }
            }
    }
}

/// A partial ring that turns. Core Animation runs it, so the notch doesn't redraw every frame.
private struct RotatingRing: NSViewRepresentable {
    let color: NSColor
    let animates: Bool

    func makeNSView(context: Context) -> RingView { RingView() }

    func updateNSView(_ view: RingView, context: Context) {
        view.ring.strokeColor = color.cgColor
        view.setSpinning(animates)
    }

    final class RingView: NSView {
        let ring = CAShapeLayer()

        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            ring.fillColor = nil
            ring.lineWidth = 1.5
            ring.lineCap = .round
            ring.strokeEnd = 0.7
            layer?.addSublayer(ring)
        }

        required init?(coder: NSCoder) { fatalError("not used") }

        func setSpinning(_ on: Bool) {
            guard on != (ring.animation(forKey: "spin") != nil) else { return }
            if on {
                let spin = CABasicAnimation(keyPath: "transform.rotation.z")
                spin.fromValue = 0
                spin.toValue = -2 * Double.pi // clockwise
                spin.duration = 2.4
                spin.repeatCount = .infinity
                ring.add(spin, forKey: "spin")
            } else {
                ring.removeAnimation(forKey: "spin")
            }
        }

        override func layout() {
            super.layout()
            ring.frame = bounds
            ring.path = CGPath(ellipseIn: bounds.insetBy(dx: 1, dy: 1), transform: nil)
        }
    }
}
