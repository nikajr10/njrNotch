//
//  SpotifyController.swift
//  njrNotch
//

import AppKit
import Observation

/// Reads and controls the Spotify desktop app over AppleScript. No login needed.
@Observable
final class SpotifyController {
    struct Track: Equatable {
        var title: String
        var artist: String
        var artworkURL: URL?
    }

    private(set) var track: Track?
    private(set) var isPlaying = false
    private(set) var isShuffling = false

    private static let bundleID = "com.spotify.client"

    init() {
        // Spotify broadcasts this whenever the song or play/pause state changes.
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(refresh),
            name: Notification.Name("com.spotify.client.PlaybackStateChanged"), object: nil
        )
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(refresh),
                              name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        workspace.addObserver(self, selector: #selector(refresh),
                              name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        refresh()
    }

    var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID).isEmpty
    }

    @objc func refresh() {
        // Guard first: `tell application "Spotify"` would otherwise launch it.
        guard isRunning, let info = run("""
            tell application "Spotify"
                set t to current track
                return {name of t, artist of t, artwork url of t, player state as string, shuffling}
            end tell
            """), info.numberOfItems == 5 else {
            track = nil
            return
        }
        track = Track(
            title: info.atIndex(1)?.stringValue ?? "",
            artist: info.atIndex(2)?.stringValue ?? "",
            artworkURL: info.atIndex(3)?.stringValue.flatMap(URL.init(string:))
        )
        isPlaying = info.atIndex(4)?.stringValue == "playing"
        isShuffling = info.atIndex(5)?.booleanValue ?? false
    }

    func playPause() { command("playpause") }
    func next() { command("next track") }
    func previous() { command("previous track") }
    // Spotify posts no notification for shuffle, so command() refreshes manually.
    func toggleShuffle() { command("set shuffling to not shuffling") }

    private func command(_ verb: String) {
        guard isRunning else { return }
        run("tell application \"Spotify\" to \(verb)")
        refresh()
    }

    // ponytail: runs on the main thread (NSAppleScript isn't thread-safe); fine for Spotify's
    // millisecond replies, move to a serial queue + osascript if it ever stutters the UI.
    @discardableResult
    private func run(_ source: String) -> NSAppleEventDescriptor? {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        return error == nil ? result : nil
    }
}
