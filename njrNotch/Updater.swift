//
//  Updater.swift
//  njrNotch
//

import AppKit
import Observation

/// Checks GitHub for a newer release and installs it over this copy of the app.
/// A release is a GitHub release tagged with its version (v1.2) with njrNotch.dmg attached, as
/// scripts/make-dmg.sh builds it; its notes (Markdown) are shown in Settings → Updates.
@Observable
final class Updater {
    struct Release: Equatable {
        var version: String
        var notes: String
        var dmg: URL
    }

    enum State: Equatable {
        case idle, checking, upToDate
        case available(Release)
        case installing(String)
        case failed(String)
    }

    static let shared = Updater()
    static let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    private static let latest = URL(string: "https://api.github.com/repos/nikajr10/njrNotch/releases/latest")!

    private(set) var state = State.idle
    private(set) var lastChecked: Date?

    private init() {}

    var hasUpdate: Bool {
        if case .available = state { true } else { false }
    }

    /// Checks at launch and then once a day, while automatic checks are on. A find pops down from the notch.
    func start() {
        Task {
            while true {
                if AppSettings.shared.prefs.checkForUpdates, await check(), case .available(let release) = state {
                    PopNotifier.shared.post(PopNote(kind: .update, title: "Update available",
                                                    detail: "njrNotch \(release.version) · click to install"))
                }
                try? await Task.sleep(for: .seconds(24 * 3600))
            }
        }
    }

    /// Returns whether the check reached GitHub.
    @discardableResult
    func check() async -> Bool {
        if case .installing = state { return false }
        state = .checking
        do {
            var request = URLRequest(url: Self.latest)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw UpdateError("GitHub answered \((response as? HTTPURLResponse)?.statusCode ?? 0). Try again later.")
            }
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            lastChecked = .now
            let version = release.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            guard Self.isNewer(version, than: Self.current) else {
                state = .upToDate
                return true
            }
            guard let dmg = release.assets.first(where: { $0.name.hasSuffix(".dmg") })?.browser_download_url else {
                throw UpdateError("njrNotch \(version) is out, but its release has no .dmg to install yet.")
            }
            state = .available(Release(version: version, notes: release.body ?? "", dmg: dmg))
            return true
        } catch {
            state = .failed(error.localizedDescription)
            return false
        }
    }

    /// Downloads the DMG, puts its app in place of this one and relaunches.
    func install(_ release: Release) async {
        state = .installing("Downloading njrNotch \(release.version)…")
        do {
            let (file, _) = try await URLSession.shared.download(from: release.dmg)
            defer { try? FileManager.default.removeItem(at: file) }
            state = .installing("Installing…")
            let app = try await Task.detached { try Self.install(dmg: file) }.value
            // Opens the new copy once this one has quit.
            let relaunch = Process()
            relaunch.executableURL = URL(fileURLWithPath: "/bin/sh")
            relaunch.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", app.path]
            try relaunch.run()
            NSApp.terminate(nil)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    nonisolated static func isNewer(_ version: String, than current: String) -> Bool {
        version.compare(current, options: .numeric) == .orderedDescending
    }

    /// Mounts the DMG, checks its app and swaps it in. Returns where the app now is.
    nonisolated private static func install(dmg: URL) throws -> URL {
        let files = FileManager.default
        let mount = files.temporaryDirectory.appendingPathComponent("njrNotch-update-\(UUID().uuidString)")
        try run("/usr/bin/hdiutil", "attach", dmg.path, "-nobrowse", "-readonly", "-mountpoint", mount.path)
        defer { try? run("/usr/bin/hdiutil", "detach", mount.path, "-force") }

        let new = mount.appendingPathComponent("njrNotch.app")
        guard Bundle(url: new)?.bundleIdentifier == Bundle.main.bundleIdentifier else {
            throw UpdateError("The download doesn't contain njrNotch.")
        }
        try run("/usr/bin/codesign", "--verify", "--deep", "--strict", new.path) // damaged or altered copies stop here

        // An app opened from the DMG or a download runs from a read-only (often random) copy; install to Applications then.
        let here = Bundle.main.bundleURL
        let isReadOnly = here.path.contains("/AppTranslocation/")
            || !files.isWritableFile(atPath: here.deletingLastPathComponent().path)
        let destination = isReadOnly ? URL(fileURLWithPath: "/Applications/njrNotch.app") : here
        let staged = destination.deletingLastPathComponent().appendingPathComponent(".njrNotch-update.app")
        try? files.removeItem(at: staged)
        try run("/usr/bin/ditto", new.path, staged.path)
        if files.fileExists(atPath: destination.path) {
            _ = try files.replaceItemAt(destination, withItemAt: staged)
        } else {
            try files.moveItem(at: staged, to: destination)
        }
        return destination
    }

    nonisolated private static func run(_ tool: String, _ arguments: String...) throws {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let output = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw UpdateError(String(decoding: output, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    #if DEBUG
    /// Runnable check for version order; called once at launch in debug builds.
    static func selfCheck() {
        assert(isNewer("1.2", than: "1.1") && isNewer("1.10", than: "1.9") && isNewer("2", than: "1.9.9"))
        assert(!isNewer("1.1", than: "1.1") && !isNewer("1.0.9", than: "1.1"))
    }
    #endif

    private struct GitHubRelease: Decodable {
        let tag_name: String
        let body: String?
        let assets: [Asset]

        struct Asset: Decodable {
            let name: String
            let browser_download_url: URL
        }
    }
}

struct UpdateError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}
