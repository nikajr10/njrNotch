//
//  SettingsWindow.swift
//  njrNotch
//

import AppKit
import SwiftUI

/// The settings window, opened from the menu bar icon, the notch's right-click menu, or by reopening the app.
enum SettingsWindow {
    private static var window: NSWindow?

    static func show(_ section: SettingsSection? = nil) {
        if let section { AppSettings.shared.settingsSection = section }
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            window.title = "njrNotch Settings"
            window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            window.toolbarStyle = .unified
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}
