//
//  TokenUsage.swift
//  njrNotch
//

import Foundation

/// Sums token usage from Claude Code's local session logs (~/.claude/projects/**/*.jsonl), and reads
/// the model and effort level each reply was logged with.
/// Input includes cache writes and cache reads, as Claude Code counts them. No prices anywhere.
nonisolated enum TokenUsage {
    struct Counts: Equatable, Sendable {
        var input = 0
        var output = 0
        var total: Int { input + output }
    }

    /// What one transcript says about its session. nil fields weren't in the log.
    struct Session: Sendable {
        var counts = Counts()
        var model: String?
        var effort: String?
        /// When the transcript file was created, i.e. when the session started.
        var started: Date?
        /// Tokens in the context window at the latest reply: its input + cache read + cache creation.
        var lastContext: Int?
    }

    static let projectsDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/projects")

    /// All tokens in one session transcript, and its latest model and effort.
    static func session(in transcript: URL) -> Session {
        var session = scan(files: [transcript]) { _ in true }
        session.started = try? transcript.resourceValues(forKeys: [.creationDateKey]).creationDate
        return session
    }

    /// Tokens used today across every session, by message timestamp.
    static func today() -> Counts {
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        let files = (FileManager.default.enumerator(at: projectsDir, includingPropertiesForKeys: keys)?
            .allObjects as? [URL] ?? [])
            .filter { url in
                url.pathExtension == "jsonl" &&
                ((try? url.resourceValues(forKeys: Set(keys)).contentModificationDate)
                    .map(Calendar.current.isDateInToday) ?? false)
            }
        return scan(files: files) { Calendar.current.isDateInToday($0) }.counts
    }

    /// Context window for a model id, for the estimate when there's no status line: 1M for "[1m]" variants and
    /// the models that have 1M by default (all current ones), 200K for Haiku 4.5 and older models.
    static func contextWindow(model id: String) -> Int {
        let millions = ["[1m]", "fable", "mythos", "opus-5", "opus-4-6", "opus-4-7", "opus-4-8",
                        "sonnet-5", "sonnet-4-6", "haiku-5"]
        return millions.contains { id.contains($0) } ? 1_000_000 : 200_000
    }

    /// "claude-opus-5-5" -> "Opus 5.5", "claude-sonnet-4-5-20250929" -> "Sonnet 4.5".
    static func displayName(model id: String) -> String {
        let parts = id.prefix { $0 != "[" }.split(separator: "-").filter { $0 != "claude" }
        guard let family = parts.first(where: { !$0.allSatisfy(\.isNumber) }) else { return id }
        let version = parts.filter { $0.allSatisfy(\.isNumber) && $0.count < 8 } // drop the date
        return ([family.capitalized] + [version.joined(separator: ".")]).filter { !$0.isEmpty }.joined(separator: " ")
    }

    private static func scan(files: [URL], include: (Date) -> Bool) -> Session {
        let usageKey = Data("\"usage\"".utf8)
        let dates = ISO8601DateFormatter()
        dates.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let decoder = JSONDecoder()
        // A streamed reply is logged once per content block with the same usage; count it once.
        var seen = Set<String>()
        var session = Session()

        for file in files {
            guard let data = try? Data(contentsOf: file) else { continue }
            for line in data.split(separator: UInt8(ascii: "\n")) where line.range(of: usageKey) != nil {
                guard let entry = try? decoder.decode(Entry.self, from: line),
                      let usage = entry.message?.usage else { continue }
                if let id = entry.message?.id, !seen.insert("\(id):\(entry.requestId ?? "")").inserted { continue }
                if let stamp = entry.timestamp, let date = dates.date(from: stamp), !include(date) { continue }
                let input = (usage.input_tokens ?? 0) + (usage.cache_creation_input_tokens ?? 0)
                    + (usage.cache_read_input_tokens ?? 0)
                session.counts.input += input
                if entry.isSidechain != true { session.lastContext = input } // subagents have their own context
                session.counts.output += usage.output_tokens ?? 0
                // "<synthetic>" marks messages Claude Code wrote itself, e.g. errors.
                if let model = entry.message?.model, !model.hasPrefix("<") { session.model = model }
                if let effort = entry.effort { session.effort = effort }
            }
        }
        return session
    }

    #if DEBUG
    /// Runnable check for model names; called once at launch in debug builds.
    static func selfCheck() {
        assert(displayName(model: "claude-opus-5-5") == "Opus 5.5")
        assert(displayName(model: "claude-sonnet-4-5-20250929") == "Sonnet 4.5")
        assert(displayName(model: "claude-3-5-haiku-20241022") == "Haiku 3.5")
        assert(displayName(model: "claude-opus-4-6[1m]") == "Opus 4.6")
        assert(displayName(model: "claude-fable") == "Fable")
        assert(contextWindow(model: "claude-opus-5-5") == 1_000_000)
        assert(contextWindow(model: "claude-sonnet-4-5-20250929") == 200_000)
        assert(contextWindow(model: "claude-sonnet-4-5[1m]") == 1_000_000)
        assert(contextWindow(model: "claude-haiku-4-5") == 200_000)
    }
    #endif

    private struct Entry: Decodable {
        let timestamp: String?
        let requestId: String?
        let effort: String?
        let isSidechain: Bool?
        let message: Message?
    }

    private struct Message: Decodable {
        let id: String?
        let model: String?
        let usage: Usage?
    }

    private struct Usage: Decodable {
        let input_tokens: Int?
        let output_tokens: Int?
        let cache_creation_input_tokens: Int?
        let cache_read_input_tokens: Int?
    }
}
