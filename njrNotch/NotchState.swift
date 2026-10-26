//
//  NotchState.swift
//  njrNotch
//

import AppKit
import Observation
import SwiftUI

/// Whether the notch is open, on which tab, and whether it shows Settings. Shared, so the right-click
/// menu, the keyboard shortcut and reopening the app can drive the notch, not only the pointer.
@Observable
final class NotchState {
    static let shared = NotchState()

    private(set) var isExpanded = false
    var tab = NotchTab.claudeCode
    private(set) var showsSettings = false
    /// The page open in the notch's Settings; nil = the list.
    var settingsSection: SettingsSection?

    private init() {}

    func setExpanded(_ open: Bool, tab: NotchTab? = nil) {
        guard open != isExpanded || tab != nil else { return }
        if open {
            SpotifyController.shared.refresh() // shuffle changes made in Spotify aren't broadcast
        } else {
            AgentMonitor.shared.selectedID = nil // reopen on the most urgent session
            closeSettings()
        }
        let spring = Animation.spring(response: AppSettings.shared.prefs.animationDuration, dampingFraction: 0.8)
        withAnimation(spring) {
            isExpanded = open
            if let tab { self.tab = tab }
        }
    }

    func open(_ tab: NotchTab) {
        closeSettings()
        setExpanded(true, tab: tab)
    }

    func toggle() {
        setExpanded(!isExpanded)
    }

    /// Settings stay open when the pointer leaves, so the colour panel and menus can be used; Back closes them.
    func openSettings(_ section: SettingsSection? = nil) {
        settingsSection = section
        setExpanded(true)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { showsSettings = true }
        // Key, so text fields and the shortcut recorder get typing. The panel never activates the app.
        NSApp.windows.first { $0 is NotchPanel }?.makeKey()
    }

    func closeSettings() {
        guard showsSettings else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { showsSettings = false }
        settingsSection = nil
        // Hand typing back to the app you were using.
        NSWorkspace.shared.frontmostApplication?.activate()
    }
}
