//
//  TokenUsage.swift
//  njrNotch
//

import Foundation

/// Sums token usage from Claude Code's local session logs (~/.claude/projects/**/*.jsonl).
/// Input includes cache writes and cache reads, as Claude Code counts them. No prices anywhere.
nonisolated enum TokenUsage {
    struct Counts: Equatable, Sendable {
        var input = 0
        var output = 0
        var total: Int { input + output }
    }

    static let projectsDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/projects")

    /// All tokens in one session transcript.
    static func counts(in transcript: URL) -> Counts {
        sum(files: [transcript]) { _ in true }
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
        return sum(files: files) { Calendar.current.isDateInToday($0) }
    }

    private static func sum(files: [URL], include: (Date) -> Bool) -> Counts {
        let usageKey = Data("\"usage\"".utf8)
        let dates = ISO8601DateFormatter()
        dates.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let decoder = JSONDecoder()
        // A streamed reply is logged once per content block with the same usage; count it once.
        var seen = Set<String>()
        var counts = Counts()

        for file in files {
            guard let data = try? Data(contentsOf: file) else { continue }
            for line in data.split(separator: UInt8(ascii: "\n")) where line.range(of: usageKey) != nil {
                guard let entry = try? decoder.decode(Entry.self, from: line),
                      let usage = entry.message?.usage else { continue }
                if let id = entry.message?.id, !seen.insert("\(id):\(entry.requestId ?? "")").inserted { continue }
                if let stamp = entry.timestamp, let date = dates.date(from: stamp), !include(date) { continue }
                counts.input += (usage.input_tokens ?? 0) + (usage.cache_creation_input_tokens ?? 0)
                    + (usage.cache_read_input_tokens ?? 0)
                counts.output += usage.output_tokens ?? 0
            }
        }
        return counts
    }

    private struct Entry: Decodable {
        let timestamp: String?
        let requestId: String?
        let message: Message?
    }

    private struct Message: Decodable {
        let id: String?
        let usage: Usage?
    }

    private struct Usage: Decodable {
        let input_tokens: Int?
        let output_tokens: Int?
        let cache_creation_input_tokens: Int?
        let cache_read_input_tokens: Int?
    }
}
