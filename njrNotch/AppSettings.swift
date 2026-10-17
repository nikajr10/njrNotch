//
//  AppSettings.swift
//  njrNotch
//

import Foundation
import Observation

/// Every user setting, with its default. Add a field here and it is saved automatically.
struct Preferences: Codable, Equatable {
    // General
    var openOnClick = false
    var openDelay = 0.0                // seconds the pointer rests on the notch before it opens
    var screenName = ""                // "" = automatic (the notch screen)
    var showMenuBarIcon = true
    // Appearance
    var accentHex = "#0A84FF"
    var background = NotchBackground.black
    var customBackgroundHex = "#1C1C1E"
    var textScale = 1.0
    var cornerRadius = 24.0
    var expandedWidth = 440.0
    var expandedHeight = 340.0
    var animationDuration = 0.35
    var tabBarShowsLabels = false
    var compactLayout = false
    // Spotify
    var showSpotify = true
    var showAlbumArt = true
    var showArtist = true
    var showShuffle = true
    var showLike = true
    var showVisualizer = true
    var spotifyClientID = ""
    // Claude Code
    var claudeCodeEnabled = true
    var answerPermissionsInNotch = true
    var showClosedIndicator = true
    var showFiveHourLimit = true
    var showWeeklyLimit = true
    var showFableLimit = true
    var showTask = true
    var showActivity = true
    var showElapsed = true
    var showLastResult = true
    var showTokens = true
    // Sounds: a system sound name, or an absolute path to the user's own file
    var doneSoundOn = true
    var doneSound = "Glass"
    var permissionSoundOn = true
    var permissionSound = "Ping"
    var soundVolume = 0.8
    var notificationsOn = false
}

enum NotchBackground: String, Codable, CaseIterable {
    case black, glass, custom
}

/// Observable holder that writes `Preferences` to UserDefaults on every change.
@Observable
final class AppSettings {
    static let shared = AppSettings()
    private static let key = "preferences"

    /// Writing an equal value does nothing. MenuBarExtra writes `isInserted` back on every scene
    /// update, and without this check each write-back triggered the next: an endless update loop.
    var prefs: Preferences {
        get {
            access(keyPath: \.prefs)
            return stored
        }
        set {
            guard newValue != stored else { return }
            withMutation(keyPath: \.prefs) { stored = newValue }
            if let data = try? JSONEncoder().encode(newValue),
               let dict = try? JSONSerialization.jsonObject(with: data) {
                UserDefaults.standard.set(dict, forKey: Self.key)
            }
        }
    }
    @ObservationIgnored private var stored: Preferences

    /// Page showing in the Settings window. Not saved.
    var settingsSection: SettingsSection? = .general

    private init() {
        stored = Self.load()
    }

    /// Saved values laid over the defaults, so fields added in later versions keep their defaults.
    private static func load() -> Preferences {
        guard let saved = UserDefaults.standard.dictionary(forKey: key),
              let data = try? JSONEncoder().encode(Preferences()),
              var merged = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return Preferences() }
        merged.merge(saved) { _, new in new }
        return (try? JSONSerialization.data(withJSONObject: merged))
            .flatMap { try? JSONDecoder().decode(Preferences.self, from: $0) } ?? Preferences()
    }
}
