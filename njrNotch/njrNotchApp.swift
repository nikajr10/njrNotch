//
//  njrNotchApp.swift
//  njrNotch
//
//  Created by Bashistha Pandey on 17/10/2026.
//

import SwiftUI

@main
struct njrNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Bindable private var settings = AppSettings.shared

    // No default window: the notch panel is created by AppDelegate.
    var body: some Scene {
        MenuBarExtra("njrNotch", systemImage: "rectangle.topthird.inset.filled",
                     isInserted: $settings.prefs.showMenuBarIcon) {
            Button("Settings…") { SettingsWindow.show() }
                .keyboardShortcut(",")
            Divider()
            Button("Quit njrNotch") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let panel = NotchPanel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel.placeAtTopCentre()
        panel.orderFrontRegardless()

        // Re-place when displays change, or when a setting (screen, notch size) changes.
        NotificationCenter.default.addObserver(
            self, selector: #selector(reposition),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(reposition),
            name: UserDefaults.didChangeNotification, object: nil
        )
    }

    /// Opening the app again (Finder, Spotlight) shows Settings, even with the menu bar icon hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindow.show()
        return true
    }

    @objc private func reposition() {
        panel.placeAtTopCentre()
    }
}
