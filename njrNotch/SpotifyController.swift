//
//  SpotifyController.swift
//  njrNotch
//

import AppKit
import Observation

/// Reads and controls the Spotify desktop app over AppleScript. No login needed;
/// only the like button uses the Web API (`SpotifyAccount`).
@Observable
final class SpotifyController {
    struct Track: Equatable {
        var title: String
        var artist: String
        var artworkURL: URL?
        var uri: String // "spotify:track:…"
    }

    static let shared = SpotifyController()

    private(set) var track: Track?
    private(set) var isPlaying = false
    private(set) var isShuffling = false
    /// Whether the track is in Liked Songs; nil until known, or when Spotify isn't connected.
    private(set) var isLiked: Bool?
    /// Track length and the playhead when last read, in seconds. Spotify doesn't announce the
    /// playhead moving, so `position(at:)` runs it forward from `positionRead` while playing.
    private(set) var duration = 0.0
    private(set) var position = 0.0
    private(set) var positionRead = Date()

    private static let bundleID = "com.spotify.client"

    private init() {
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

    /// Local files and ads can't be saved to Liked Songs.
    var canLike: Bool {
        track?.uri.hasPrefix("spotify:track:") == true
    }

    @objc func refresh() {
        // Guard first: `tell application "Spotify"` would otherwise launch it.
        guard isRunning, let info = run("""
            tell application "Spotify"
                set t to current track
                return {name of t, artist of t, artwork url of t, player state as string, shuffling, id of t, duration of t, player position}
            end tell
            """), info.numberOfItems == 8 else {
            track = nil
            return
        }
        let new = Track(
            title: info.atIndex(1)?.stringValue ?? "",
            artist: info.atIndex(2)?.stringValue ?? "",
            artworkURL: info.atIndex(3)?.stringValue.flatMap(URL.init(string:)),
            uri: info.atIndex(6)?.stringValue ?? ""
        )
        if new.uri != track?.uri { isLiked = nil }
        track = new
        isPlaying = info.atIndex(4)?.stringValue == "playing"
        isShuffling = info.atIndex(5)?.booleanValue ?? false
        duration = (info.atIndex(7)?.doubleValue ?? 0) / 1000 // milliseconds
        position = info.atIndex(8)?.doubleValue ?? 0
        positionRead = .now
    }

    func position(at date: Date) -> Double {
        min(duration, position + (isPlaying ? date.timeIntervalSince(positionRead) : 0))
    }

    func playPause() { command("playpause") }
    func next() { command("next track") }
    func previous() { command("previous track") }
    // Spotify posts no notification for shuffle, so command() refreshes manually.
    func toggleShuffle() { command("set shuffling to not shuffling") }
    func seek(to seconds: Double) { command("set player position to \(seconds)") }

    func loadLiked() async {
        guard let uri = track?.uri, canLike, SpotifyAccount.shared.isConnected else { return }
        let liked = await SpotifyAccount.shared.isSaved(uri)
        if track?.uri == uri { isLiked = liked }
    }

    /// Shows the new state straight away, and puts it back if Spotify refuses.
    func toggleLike() {
        guard let uri = track?.uri, canLike else { return }
        let like = isLiked != true
        isLiked = like
        Task {
            let saved = await SpotifyAccount.shared.setSaved(uri, like)
            if !saved, track?.uri == uri { isLiked = !like }
        }
    }

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
