//
//  Alerts.swift
//  njrNotch
//

import AppKit
import UserNotifications

/// Sounds and optional macOS notifications for agent events.
enum Alerts {
    enum Kind { case done, permission }

    /// Built-in macOS alert sounds (/System/Library/Sounds). Nothing is bundled or copied.
    static let systemSounds: [String] = {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: "/System/Library/Sounds")) ?? []
        return files.map { ($0 as NSString).deletingPathExtension }.sorted()
    }()

    static func fire(_ kind: Kind, title: String, body: String) {
        let prefs = AppSettings.shared.prefs
        if kind == .done ? prefs.doneSoundOn : prefs.permissionSoundOn {
            play(kind)
        }
        if prefs.notificationsOn && !NSApp.isActive {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            )
        }
    }

    static func play(_ kind: Kind) {
        let prefs = AppSettings.shared.prefs
        let name = kind == .done ? prefs.doneSound : prefs.permissionSound
        let sound = name.hasPrefix("/")
            ? NSSound(contentsOf: URL(fileURLWithPath: name), byReference: true)
            : NSSound(named: name)
        sound?.volume = Float(prefs.soundVolume)
        sound?.play()
    }

    static func requestNotificationPermission() {
        Task { _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) }
    }
}
