//
//  NotchPanel.swift
//  njrNotch
//

import AppKit
import SwiftUI

/// Borderless, transparent, always-on-top panel that hosts the notch view.
/// It is sized to the expanded notch; transparent pixels let clicks pass through.
final class NotchPanel: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
    }

    func placeAtTopCentre() {
        guard let screen = NSScreen.notchScreen else { return }
        let notch = screen.notchSize
        let size = CGSize(
            width: max(NotchView.expandedSize.width, notch.width),
            height: max(NotchView.expandedSize.height, notch.height)
        )
        contentView = NSHostingView(rootView: NotchView(notchSize: notch))
        setFrame(
            NSRect(x: screen.frame.midX - size.width / 2, y: screen.frame.maxY - size.height,
                   width: size.width, height: size.height),
            display: true
        )
    }
}

extension NSScreen {
    /// The built-in notched display if there is one, otherwise the main display.
    static var notchScreen: NSScreen? {
        screens.first { $0.safeAreaInsets.top > 0 } ?? main
    }

    /// Size of the physical notch, or a small pill under the menu bar on Macs without one.
    var notchSize: CGSize {
        if safeAreaInsets.top > 0, let left = auxiliaryTopLeftArea, let right = auxiliaryTopRightArea {
            return CGSize(width: frame.width - left.width - right.width, height: safeAreaInsets.top)
        }
        // Menu bar height; falls back to 24pt when the menu bar is auto-hidden.
        return CGSize(width: 180, height: max(frame.maxY - visibleFrame.maxY, 24))
    }
}
