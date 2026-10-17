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
    var hotKeyOn = true                // global shortcut that opens and closes the notch
    var hotKeyCode = 45                // kVK_ANSI_N
    var hotKeyModifiers = 6144         // Carbon controlKey | optionKey
    var hotKeyLabel = "⌃⌥N"
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
    var spotifyAccentHex = ""          // "" = taken from the album art
    // Claude Code
    var claudeCodeEnabled = true
    var answerPermissionsInNotch = true
    var showTask = true
    var showActivity = true
    var showElapsed = true
    var showLastResult = true
    var claudeAccentHex = ""           // "" = Claude orange
    var showTokenTotal = true
    var showTokenUsed = true
    var showTokenRemaining = true
    var showTokenSpent = true          // the "session / today" line under the bar
    // Closed notch live activity
    var showClosedIndicator = true     // previews beside the closed notch; also in the notch's right-click menu
    var closedSource = ClosedSource.auto
    var closedShowsArt = true
    var closedShowsEqualizer = true
    var closedLogoAnimates = true      // ring and badges on the Claude logo move
    // Pop-down notifications
    var popOn = true
    var popSong = true
    var popDone = true
    var popPermission = true
    var popSessionEnded = true
    var popDuration = 4.0              // seconds on screen
    var popAnimation = 0.4             // spring response, seconds
    var popKeepWhileHovering = true
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

/// What the closed notch shows: Auto follows the rules in `ClosedActivity.pick`.
enum ClosedSource: String, Codable, CaseIterable {
    case spotify, claudeCode, auto
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
