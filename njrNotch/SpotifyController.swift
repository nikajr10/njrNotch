//
//  SpotifyController.swift
//  njrNotch
//

import AppKit
import Observation
import SwiftUI

/// Reads and controls the Spotify desktop app over AppleScript. No login needed;
/// only the like button uses the Web API (`SpotifyAccount`).
/// Long-lived: every view shows the last known song, album art and colour from here straight away,
/// and AppleScript runs on its own queue, so opening the notch or switching Spaces never waits on Spotify.
@Observable
final class SpotifyController {
    nonisolated struct Track: Equatable, Sendable {
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
    /// Last time the song or play/pause changed.
    private(set) var changedAt = Date.distantPast
    /// The current album art, downloaded once per song and shared by every view.
    private(set) var artwork: NSImage?
    /// The album art's most vivid colour, lifted to read on black; nil for greyscale art.
    private(set) var artAccentHex: String?
    /// No pill for the song already playing when njrNotch starts.
    @ObservationIgnored private var hasRefreshed = false
    /// NSAppleScript isn't thread-safe, so every script runs on this one serial queue.
    @ObservationIgnored private let queue = DispatchQueue(label: "njrNotch.spotify", qos: .userInitiated)

    private static let bundleID = "com.spotify.client"

    /// One AppleScript reply about the current track.
    nonisolated private struct Snapshot: Sendable {
        var track: Track
        var isPlaying: Bool
        var isShuffling: Bool
        var duration: Double
        var position: Double
    }

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

    /// Brings the Spotify app to the front (clicking the album art). Not NSRunningApplication.activate():
    /// macOS 14+ ignores activation requests from an app that isn't active, and the notch never is.
    func showApp() {
        guard isRunning else { return }
        queue.async { Self.run("tell application \"Spotify\" to activate") }
    }

    /// Local files and ads can't be saved to Liked Songs.
    var canLike: Bool {
        track?.uri.hasPrefix("spotify:track:") == true
    }

    @objc func refresh() {
        // Checked first: `tell application "Spotify"` would otherwise launch it.
        let isRunning = isRunning
        queue.async {
            let snapshot = isRunning ? Self.read() : nil
            Task { @MainActor in SpotifyController.shared.apply(snapshot) }
        }
    }

    nonisolated private static func read() -> Snapshot? {
        guard let info = run("""
            tell application "Spotify"
                set t to current track
                return {name of t, artist of t, artwork url of t, player state as string, shuffling, id of t, duration of t, player position}
            end tell
            """), info.numberOfItems == 8, info.atIndex(4)?.stringValue != "stopped" else { return nil }
        return Snapshot(
            track: Track(
                title: info.atIndex(1)?.stringValue ?? "",
                artist: info.atIndex(2)?.stringValue ?? "",
                artworkURL: info.atIndex(3)?.stringValue.flatMap(URL.init(string:)),
                uri: info.atIndex(6)?.stringValue ?? ""
            ),
            isPlaying: info.atIndex(4)?.stringValue == "playing",
            isShuffling: info.atIndex(5)?.booleanValue ?? false,
            duration: (info.atIndex(7)?.doubleValue ?? 0) / 1000, // milliseconds
            position: info.atIndex(8)?.doubleValue ?? 0
        )
    }

    private func apply(_ snapshot: Snapshot?) {
        defer { hasRefreshed = true }
        guard let snapshot else {
            track = nil // the last artwork and colour stay, ready for when it plays again
            return
        }
        let new = snapshot.track
        if new.uri != track?.uri {
            isLiked = nil
            if hasRefreshed {
                PopNotifier.shared.post(PopNote(kind: .song, title: new.title, detail: new.artist,
                                                artworkURL: new.artworkURL))
            }
        }
        if new.artworkURL != track?.artworkURL { loadArtwork(new.artworkURL) }
        if new.uri != track?.uri || snapshot.isPlaying != isPlaying { changedAt = .now }
        if track != new { track = new }
        if isPlaying != snapshot.isPlaying { isPlaying = snapshot.isPlaying }
        if isShuffling != snapshot.isShuffling { isShuffling = snapshot.isShuffling }
        duration = snapshot.duration
        position = snapshot.position
        positionRead = .now
    }

    /// Downloads the art once and works out its colour off the main thread; the colour fades to the new one.
    private func loadArtwork(_ url: URL?) {
        guard let url else {
            artwork = nil
            withAnimation(.easeInOut(duration: 0.8)) { artAccentHex = nil }
            return
        }
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url), track?.artworkURL == url else { return }
            let hex = await Task.detached(priority: .utility) { AlbumColor.vividHex(in: data) }.value
            guard track?.artworkURL == url else { return }
            artwork = NSImage(data: data)
            withAnimation(.easeInOut(duration: 0.8)) { artAccentHex = hex }
        }
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
        queue.async { Self.run("tell application \"Spotify\" to \(verb)") }
        refresh() // queued after the command, so it reads the new state
    }

    @discardableResult
    nonisolated private static func run(_ source: String) -> NSAppleEventDescriptor? {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        return error == nil ? result : nil
    }
}
