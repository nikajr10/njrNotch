//
//  TokenUsage.swift
//  njrNotch
//

import Foundation

/// Reads the model and effort level each reply was logged with in Claude Code's local session logs
/// (~/.claude/projects/**/*.jsonl).
nonisolated enum TokenUsage {
    /// What one transcript says about its session. nil fields weren't in the log.
    struct Session: Sendable {
        var model: String?
        var effort: String?
    }

    /// The latest model and effort in one session transcript.
    static func session(in transcript: URL) -> Session {
        let usageKey = Data("\"usage\"".utf8)
        let decoder = JSONDecoder()
        var session = Session()
        guard let data = try? Data(contentsOf: transcript) else { return session }
        for line in data.split(separator: UInt8(ascii: "\n")) where line.range(of: usageKey) != nil {
            guard let entry = try? decoder.decode(Entry.self, from: line) else { continue }
            // "<synthetic>" marks messages Claude Code wrote itself, e.g. errors.
            if let model = entry.message?.model, !model.hasPrefix("<") { session.model = model }
            if let effort = entry.effort { session.effort = effort }
        }
        return session
    }

    /// "claude-opus-5-5" -> "Opus 5.5", "claude-sonnet-4-5-20250929" -> "Sonnet 4.5".
    static func displayName(model id: String) -> String {
        let parts = id.prefix { $0 != "[" }.split(separator: "-").filter { $0 != "claude" }
        guard let family = parts.first(where: { !$0.allSatisfy(\.isNumber) }) else { return id }
        let version = parts.filter { $0.allSatisfy(\.isNumber) && $0.count < 8 } // drop the date
        return ([family.capitalized] + [version.joined(separator: ".")]).filter { !$0.isEmpty }.joined(separator: " ")
    }

    #if DEBUG
    /// Runnable check for model names; called once at launch in debug builds.
    static func selfCheck() {
        assert(displayName(model: "claude-opus-5-5") == "Opus 5.5")
        assert(displayName(model: "claude-sonnet-4-5-20250929") == "Sonnet 4.5")
        assert(displayName(model: "claude-3-5-haiku-20241022") == "Haiku 3.5")
        assert(displayName(model: "claude-opus-4-6[1m]") == "Opus 4.6")
        assert(displayName(model: "claude-fable") == "Fable")
    }
    #endif

    private struct Entry: Decodable {
        let effort: String?
        let message: Message?
    }

    private struct Message: Decodable {
        let model: String?
    }
}
