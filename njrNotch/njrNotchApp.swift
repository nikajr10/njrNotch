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

    // No menu bar icon and no default window: the notch panel is created by AppDelegate, and Settings
    // open from the notch (gear, right-click), the shortcut, or reopening the app.
    var body: some Scene {
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let panel = NotchPanel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel.placeAtTopCentre()
        panel.orderFrontRegardless()
        HotKey.apply()

        // Follow display and Space changes straight away: right screen, and fresh Spotify state.
        NotificationCenter.default.addObserver(
            self, selector: #selector(screenChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(screenChanged),
            name: NSWorkspace.activeSpaceDidChangeNotification, object: nil
        )
        // A setting (screen, notch size, shortcut) changed.
        NotificationCenter.default.addObserver(
            self, selector: #selector(settingsChanged),
            name: UserDefaults.didChangeNotification, object: nil
        )
    }

    /// Opening the app again (Finder, Spotlight) opens Settings in the notch, even with the menu bar icon hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NotchState.shared.openSettings()
        return false
    }

    @objc private func screenChanged() {
        panel.placeAtTopCentre()
        panel.orderFrontRegardless()
        SpotifyController.shared.refresh()
    }

    @objc private func settingsChanged() {
        panel.placeAtTopCentre()
        HotKey.apply()
    }
}
