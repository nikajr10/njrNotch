//
//  StatusLine.swift
//  njrNotch
//

import Foundation
import Observation

/// Model name and context window left for each session, from ~/.claude/njrnotch-usage.json, which
/// njrnotch-statusline.sh rewrites on every Claude Code status update. Optional: without the
/// status line installed, the notch hides these instead of guessing.
@Observable
final class StatusLine {
    struct Info: Equatable {
        var model: String?
        /// 0...100
        var contextLeftPercent: Double?
        var contextSize: Int?

        var contextLeftTokens: Int? {
            guard let contextLeftPercent, let contextSize else { return nil }
            return Int(Double(contextSize) * contextLeftPercent / 100)
        }
    }

    static let shared = StatusLine()
    static let file = ClaudeHooks.home.appendingPathComponent("njrnotch-usage.json")

    /// By Claude Code session id. The file holds one session at a time, so this collects them.
    private(set) var sessions: [String: Info] = [:]

    @ObservationIgnored private var watcher: DispatchSourceFileSystemObject?
    @ObservationIgnored private var lastModified: Date?
    @ObservationIgnored private var hasLoggedJSON = false

    private init() {
        #if DEBUG
        Self.selfCheck()
        #endif
        reload()
        // Watch ~/.claude, not the file: the script swaps the file in with a rename, which a file watch loses.
        // ponytail: no ~/.claude at launch means no watch until relaunch; Claude Code creates it on first run.
        let fd = open(ClaudeHooks.home.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let watcher = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: .write, queue: .main)
        watcher.setEventHandler { [weak self] in self?.reload() }
        watcher.setCancelHandler { close(fd) }
        watcher.resume()
        self.watcher = watcher
    }

    private func reload() {
        let modified = (try? Self.file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        guard modified != lastModified else { return }
        lastModified = modified
        guard let data = try? Data(contentsOf: Self.file), let (id, info) = Self.parse(data) else { return }
        if !hasLoggedJSON {
            hasLoggedJSON = true
            print("njrNotch: status line JSON (logged once): \(String(decoding: data, as: UTF8.self))")
        }
        if sessions[id] != info { sessions[id] = info }
    }

    /// The session id and the fields njrNotch shows from one status line update. Ignores cost.
    nonisolated static func parse(_ data: Data) -> (String, Info)? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["session_id"] as? String else { return nil }
        let model = json["model"] as? [String: Any]
        let context = json["context_window"] as? [String: Any]
        return (id, Info(
            model: model?["display_name"] as? String,
            contextLeftPercent: context?["remaining_percentage"] as? Double,
            contextSize: context?["context_window_size"] as? Int
        ))
    }

    #if DEBUG
    /// Runnable check for the parser; called once at launch in debug builds.
    static func selfCheck() {
        let sample = Data("""
            {"session_id": "abc", "model": {"id": "claude-opus-5-5", "display_name": "Opus 5.5"},
             "context_window": {"context_window_size": 200000, "remaining_percentage": 84}}
            """.utf8)
        let parsed = parse(sample)
        assert(parsed?.0 == "abc" && parsed?.1.model == "Opus 5.5" && parsed?.1.contextLeftTokens == 168_000)
        let bare = parse(Data(#"{"session_id": "x", "context_window": {"remaining_percentage": null}}"#.utf8))
        assert(bare?.1 == Info() && bare?.1.contextLeftTokens == nil)
        assert(parse(Data(#"{"model": {}}"#.utf8)) == nil && parse(Data("not json".utf8)) == nil)
    }
    #endif
}
