//
//  UsageLimits.swift
//  njrNotch
//

import Foundation
import Observation

/// Claude plan usage limits from ~/.claude/njrnotch-usage.json, which njrnotch-statusline.sh
/// rewrites on every Claude Code status update. Claude Code shares these only with a status
/// line, only on Pro and Max plans, and only after a session's first reply.
@Observable
final class UsageLimits {
    struct Window: Equatable {
        var usedPercentage: Double
        var resetsAt: Date
    }

    static let shared = UsageLimits()
    static let file = ClaudeHooks.home.appendingPathComponent("njrnotch-usage.json")

    private(set) var fiveHour: Window?
    private(set) var weekly: Window?
    /// Claude Code 2.1.302 reports no per-model limit; this fills in if a "fable" window ever appears.
    private(set) var fable: Window?
    private(set) var isStatusLineInstalled = ClaudeHooks.isStatusLineInstalled

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

    /// A window, if it's still current at `now`.
    static func current(_ window: Window?, at now: Date) -> Window? {
        window.flatMap { $0.resetsAt > now ? $0 : nil }
    }

    /// "resets in 2h 14m", "resets in 3d 4h".
    static func resetText(_ resetsAt: Date, now: Date) -> String {
        let seconds = resetsAt.timeIntervalSince(now)
        guard seconds >= 60 else { return "resets in <1m" }
        return "resets in " + Duration.seconds(seconds).formatted(
            .units(allowed: [.days, .hours, .minutes], width: .narrow, maximumUnitCount: 2)
                .locale(Locale(identifier: "en")) // match the English around it
        )
    }

    private func reload() {
        let installed = ClaudeHooks.isStatusLineInstalled
        if installed != isStatusLineInstalled { isStatusLineInstalled = installed }

        let modified = (try? Self.file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        guard modified != lastModified else { return }
        lastModified = modified
        guard let data = try? Data(contentsOf: Self.file), let new = Self.windows(in: data) else { return }
        if !hasLoggedJSON {
            hasLoggedJSON = true
            print("njrNotch: status line JSON (logged once): \(String(decoding: data, as: UTF8.self))")
        }
        // A session that hasn't had a reply yet sends no windows: keep the last ones until they reset.
        let now = Date()
        let five = new.fiveHour ?? Self.current(fiveHour, at: now)
        let week = new.weekly ?? Self.current(weekly, at: now)
        let fab = new.fable ?? Self.current(fable, at: now)
        if five != fiveHour { fiveHour = five }
        if week != weekly { weekly = week }
        if fab != fable { fable = fab }
    }

    /// The windows in one status line update. Ignores `spend_limit`, which is about money.
    nonisolated static func windows(in data: Data) -> (fiveHour: Window?, weekly: Window?, fable: Window?)? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let limits = json["rate_limits"] as? [String: Any] ?? [:]
        func window(_ key: String?) -> Window? {
            guard let key, let window = limits[key] as? [String: Any],
                  let used = window["used_percentage"] as? Double,
                  let resets = window["resets_at"] as? Double else { return nil }
            return Window(usedPercentage: used, resetsAt: Date(timeIntervalSince1970: resets))
        }
        let fableKey = limits.keys.first { $0.localizedCaseInsensitiveContains("fable") }
        return (window("five_hour"), window("seven_day"), window(fableKey))
    }

    #if DEBUG
    /// Runnable check for the parser and reset text; called once at launch in debug builds.
    static func selfCheck() {
        let sample = Data("""
            {"rate_limits": {"five_hour": {"used_percentage": 23.5, "resets_at": 1738425600},
             "seven_day": {"used_percentage": 41, "resets_at": 1738857600},
             "spend_limit": {"used_percentage": 62.8, "resets_at": 1740787200}}}
            """.utf8)
        let parsed = windows(in: sample)
        assert(parsed?.fiveHour == Window(usedPercentage: 23.5, resetsAt: Date(timeIntervalSince1970: 1738425600)))
        assert(parsed?.weekly?.usedPercentage == 41 && parsed?.fable == nil)
        let fable = windows(in: Data(#"{"rate_limits": {"seven_day_fable": {"used_percentage": 5, "resets_at": 1}}}"#.utf8))
        assert(fable?.fable?.usedPercentage == 5 && fable?.fiveHour == nil)
        let none = windows(in: Data(#"{"model": {"id": "x"}}"#.utf8))
        assert(none != nil && none?.fiveHour == nil && none?.weekly == nil)
        assert(windows(in: Data("not json".utf8)) == nil)

        let now = Date(timeIntervalSince1970: 0)
        assert(resetText(Date(timeIntervalSince1970: 8040), now: now) == "resets in 2h 14m")
        assert(resetText(Date(timeIntervalSince1970: 30), now: now) == "resets in <1m")
        assert(current(Window(usedPercentage: 1, resetsAt: now), at: now) == nil)
    }
    #endif
}
