//
//  StatusLine.swift
//  njrNotch
//

import Foundation
import Observation

/// Model and effort for each session, and the plan's usage limits, from ~/.claude/njrnotch-session.json,
/// which njrnotch-statusline.sh rewrites on every Claude Code status update. Claude Code gives the
/// limits only to a status line.
@Observable
final class StatusLine {
    nonisolated struct Info: Equatable {
        var model: String?
        var effort: String?
    }

    /// Plan usage limits, account-wide, as of the latest status line update.
    nonisolated struct Limits: Equatable {
        /// 0...100
        var fiveHourPercent: Double?
        var fiveHourResets: Date?
        var weekPercent: Double?
        var weekResets: Date?
    }

    static let shared = StatusLine()
    static let file = ClaudeHooks.home.appendingPathComponent("njrnotch-session.json")

    /// By Claude Code session id. The file holds one session at a time, so this collects them.
    private(set) var sessions: [String: Info] = [:]
    private(set) var limits: Limits?

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
        #if DEBUG // the JSON holds paths and the session name
        if !hasLoggedJSON {
            hasLoggedJSON = true
            print("njrNotch: status line JSON (logged once): \(String(decoding: data, as: UTF8.self))")
        }
        #endif
        if sessions[id] != info { sessions[id] = info }
        let limits = Self.limits(data)
        if limits != nil, self.limits != limits { self.limits = limits }
    }

    /// `rate_limits` from one status line update; nil when Claude Code doesn't send them (e.g. API key use).
    nonisolated static func limits(_ data: Data) -> Limits? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let limits = json["rate_limits"] as? [String: Any] else { return nil }
        func window(_ key: String) -> (Double?, Date?) {
            let entry = limits[key] as? [String: Any]
            return ((entry?["used_percentage"] as? NSNumber)?.doubleValue,
                    (entry?["resets_at"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue) })
        }
        let (five, fiveResets) = window("five_hour"), (week, weekResets) = window("seven_day")
        guard five != nil || week != nil else { return nil }
        return Limits(fiveHourPercent: five, fiveHourResets: fiveResets, weekPercent: week, weekResets: weekResets)
    }

    /// The session id and the fields njrNotch shows from one status line update. Ignores cost.
    nonisolated static func parse(_ data: Data) -> (String, Info)? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["session_id"] as? String else { return nil }
        let effort = (json["effort"] as? [String: Any])?["level"] as? String ?? json["effort"] as? String
        return (id, Info(model: (json["model"] as? [String: Any])?["display_name"] as? String, effort: effort))
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
        assert(parsed?.0 == "abc" && parsed?.1 == Info(model: "Opus 5.5", effort: "high"))
        assert(parse(Data(#"{"session_id": "x"}"#.utf8))?.1 == Info())
        assert(parse(Data(#"{"model": {}}"#.utf8)) == nil && parse(Data("not json".utf8)) == nil)
        let rate = limits(Data(#"{"rate_limits": {"five_hour": {"used_percentage": 17, "resets_at": 1792280400}, "seven_day": {"used_percentage": 19}}}"#.utf8))
        assert(rate == Limits(fiveHourPercent: 17, fiveHourResets: Date(timeIntervalSince1970: 1792280400), weekPercent: 19))
        assert(limits(Data(#"{"rate_limits": {}}"#.utf8)) == nil && limits(Data("{}".utf8)) == nil)
    }
    #endif
}
