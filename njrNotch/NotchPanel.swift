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
        #if DEBUG
        Color.selfCheck()
        ClosedActivity.selfCheck()
        AlbumColor.selfCheck()
        #endif
    }

    /// Only Settings in the notch takes typing; otherwise clicks in the notch leave your app's focus alone.
    override var canBecomeKey: Bool { NotchState.shared.showsSettings }

    /// Called on launch, display and Space changes, and setting changes. Views are never rebuilt here:
    /// the hosting view only gets a new root when the notch size changes, and the frame only moves when it differs.
    func placeAtTopCentre() {
        guard let screen = NSScreen.target else { return }
        let notch = screen.notchSize
        if let hosting = contentView as? NSHostingView<NotchView> {
            if hosting.rootView.notchSize != notch {
                hosting.rootView = NotchView(notchSize: notch, spotify: .shared, agent: .shared, pop: .shared)
            }
        } else {
            contentView = NSHostingView(rootView: NotchView(notchSize: notch, spotify: .shared, agent: .shared, pop: .shared))
        }
        let prefs = AppSettings.shared.prefs
        let size = CGSize(
            width: max(prefs.expandedWidth, notch.width + 2 * notch.height),
            height: max(prefs.expandedHeight, NotchSettingsView.minHeight, notch.height)
        )
        let frame = NSRect(x: screen.frame.midX - size.width / 2, y: screen.frame.maxY - size.height,
                           width: size.width, height: size.height)
        if frame != self.frame { setFrame(frame, display: true) }
    }
}

extension NSScreen {
    /// The screen picked in Settings, else the built-in notched display, else the primary display.
    static var target: NSScreen? {
        let name = AppSettings.shared.prefs.screenName
        return screens.first { !name.isEmpty && $0.localizedName == name }
            ?? screens.first { $0.safeAreaInsets.top > 0 }
            ?? screens.first
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
