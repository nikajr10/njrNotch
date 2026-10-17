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

    // No default window: the notch panel is created by AppDelegate.
    var body: some Scene {
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let panel = NotchPanel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel.placeAtTopCentre()
        panel.orderFrontRegardless()

        // Re-centre when displays are plugged in, removed or rearranged.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screensChanged() {
        panel.placeAtTopCentre()
    }
}
