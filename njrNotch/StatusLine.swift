//
//  StatusLine.swift
//  njrNotch
//

import Foundation
import Observation

/// Context window, model and effort for each session, from ~/.claude/njrnotch-session.json, which
/// njrnotch-statusline.sh rewrites on every Claude Code status update. Claude Code gives the context window
/// only to a status line, so without it the notch falls back to an estimate from the transcript.
@Observable
final class StatusLine {
    nonisolated struct Info: Equatable {
        var model: String?
        var effort: String?
        var contextSize: Int?
        var usedTokens: Int?
        /// 0...100
        var usedPercent: Double?
    }

    static let shared = StatusLine()
    static let file = ClaudeHooks.home.appendingPathComponent("njrnotch-session.json")
    private static let windowsKey = "contextWindows"

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

    /// The context window a model had in an earlier status line update, for the transcript estimate.
    static func knownWindow(model id: String) -> Int? {
        UserDefaults.standard.dictionary(forKey: windowsKey)?[id] as? Int
    }

    private func reload() {
        let modified = (try? Self.file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        guard modified != lastModified else { return }
        lastModified = modified
        guard let data = try? Data(contentsOf: Self.file), let (id, info, modelID) = Self.parse(data) else { return }
        if !hasLoggedJSON {
            hasLoggedJSON = true
            print("njrNotch: status line JSON (logged once): \(String(decoding: data, as: UTF8.self))")
        }
        if let modelID, let size = info.contextSize, Self.knownWindow(model: modelID) != size {
            var windows = UserDefaults.standard.dictionary(forKey: Self.windowsKey) ?? [:]
            windows[modelID] = size
            UserDefaults.standard.set(windows, forKey: Self.windowsKey)
        }
        if sessions[id] != info { sessions[id] = info }
    }

    /// The session id, the fields njrNotch shows, and the model id from one status line update. Ignores cost.
    nonisolated static func parse(_ data: Data) -> (String, Info, String?)? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["session_id"] as? String else { return nil }
        let model = json["model"] as? [String: Any]
        let context = json["context_window"] as? [String: Any]
        let size = (context?["context_window_size"] as? NSNumber)?.intValue
        var used = (context?["current_usage"] as? [String: Any]).map { usage in
            ["input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens"]
                .reduce(0) { $0 + ((usage[$1] as? NSNumber)?.intValue ?? 0) }
        }
        var percent = (context?["used_percentage"] as? NSNumber)?.doubleValue
        if let size, size > 0 {
            used = used ?? percent.map { Int(Double(size) * $0 / 100) }
            percent = percent ?? used.map { Double($0) / Double(size) * 100 }
        }
        let effort = (json["effort"] as? [String: Any])?["level"] as? String ?? json["effort"] as? String
        return (id, Info(model: model?["display_name"] as? String, effort: effort, contextSize: size,
                         usedTokens: used, usedPercent: percent), model?["id"] as? String)
    }

    #if DEBUG
    /// Runnable check for the parser; called once at launch in debug builds.
    static func selfCheck() {
        let sample = Data("""
            {"session_id": "abc", "model": {"id": "claude-opus-5-5", "display_name": "Opus 5.5"}, "effort": {"level": "high"},
             "context_window": {"context_window_size": 200000, "used_percentage": 16,
                                "current_usage": {"input_tokens": 2, "cache_creation_input_tokens": 1000, "cache_read_input_tokens": 30998}}}
            """.utf8)
        let parsed = parse(sample)
        assert(parsed?.0 == "abc" && parsed?.2 == "claude-opus-5-5")
        assert(parsed?.1 == Info(model: "Opus 5.5", effort: "high", contextSize: 200_000, usedTokens: 32_000, usedPercent: 16))
        // No current_usage: tokens from the percentage.
        let percentOnly = parse(Data(#"{"session_id": "x", "context_window": {"context_window_size": 1000000, "used_percentage": 12}}"#.utf8))
        assert(percentOnly?.1.usedTokens == 120_000)
        let bare = parse(Data(#"{"session_id": "x", "context_window": {"used_percentage": null}}"#.utf8))
        assert(bare?.1 == Info())
        assert(parse(Data(#"{"model": {}}"#.utf8)) == nil && parse(Data("not json".utf8)) == nil)
    }
    #endif
}
