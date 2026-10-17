//
//  TokenBlock.swift
//  njrNotch
//

import SwiftUI

/// The Claude Code tab's tokens: context window size, used and remaining, a bar, then tokens spent.
/// The context comes from the status line; without it, an estimate from the transcript, marked as one.
/// With neither, it says it's waiting. Never invented numbers, never cost.
struct TokenBlock: View {
    let session: AgentSession?
    let today: TokenUsage.Counts?

    struct Context: Equatable {
        var total: Int
        var used: Int
        /// 0...100
        var usedPercent: Double
        var isEstimate: Bool
    }

    private var prefs: Preferences { AppSettings.shared.prefs }

    static func context(statusLine: StatusLine.Info?, session: AgentSession?) -> Context? {
        if let line = statusLine, let total = line.contextSize, total > 0, let used = line.usedTokens {
            return Context(total: total, used: used,
                           usedPercent: line.usedPercent ?? Double(used) / Double(total) * 100, isEstimate: false)
        }
        guard let used = session?.lastContext, let model = session?.model else { return nil }
        let total = StatusLine.knownWindow(model: model) ?? TokenUsage.contextWindow(model: model)
        return Context(total: total, used: used, usedPercent: Double(used) / Double(total) * 100, isEstimate: true)
    }

    /// Green, amber above 70% used, red above 90%.
    static func color(usedPercent: Double) -> Color {
        usedPercent > 90 ? .red : usedPercent > 70 ? .orange : .green
    }

    var body: some View {
        let statusLine = session.flatMap { StatusLine.shared.sessions[String($0.id.drop { $0 != ":" }.dropFirst())] }
        let context = Self.context(statusLine: statusLine, session: session)
        let rowsShown = prefs.showTokenTotal || prefs.showTokenUsed || prefs.showTokenRemaining

        VStack(alignment: .leading, spacing: 4) {
            if rowsShown {
                if let context {
                    rows(context)
                } else {
                    Text("Waiting for data. Send a message in Claude Code.")
                        .font(.notch(11))
                        .foregroundStyle(.secondary)
                }
            }
            if prefs.showTokenSpent, let spent = summary(context) {
                Text(spent)
                    .font(.notch(10).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    @ViewBuilder
    private func rows(_ context: Context) -> some View {
        let used = min(max(context.usedPercent, 0), 100)
        let mark = context.isEstimate ? "~" : ""
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 3) {
            if prefs.showTokenTotal {
                row("Total tokens", mark + Self.format(context.total))
            }
            if prefs.showTokenUsed {
                row("Tokens used", "\(mark)\(Self.format(context.used)) · \(Int(used.rounded()))%")
            }
            if prefs.showTokenRemaining {
                row("Remaining tokens", "\(mark)\(Self.format(max(0, context.total - context.used))) · \(Int((100 - used).rounded()))%")
            }
        }
        .font(.notch(11).monospacedDigit())
        HStack(spacing: 8) {
            CapsuleBar(fraction: used / 100, color: Self.color(usedPercent: used), height: 5)
            if context.isEstimate {
                Text("estimate")
                    .font(.notch(10))
                    .foregroundStyle(.secondary)
                    .help("No status line data: worked out from the session's log and the model's context window.")
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Context window \(Int(used.rounded()))% used\(context.isEstimate ? ", estimate" : "")")
    }

    private func row(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title).foregroundStyle(.secondary)
            Text(value).gridColumnAlignment(.trailing).frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    /// "Total 1M · Used 250K · Remaining 750K   Today 25.8M": what's there, nothing made up.
    private func summary(_ context: Context?) -> String? {
        var parts: [String] = []
        if let context {
            let mark = context.isEstimate ? "~" : ""
            parts.append("Total \(mark)\(Self.format(context.total)) · Used \(mark)\(Self.format(context.used))"
                         + " · Remaining \(mark)\(Self.format(max(0, context.total - context.used)))")
        }
        if let today {
            parts.append("Today \(Self.format(today.total))")
        }
        return parts.isEmpty ? nil : parts.joined(separator: "   ")
    }

    static func format(_ tokens: Int) -> String {
        tokens.formatted(.number.notation(.compactName).precision(.fractionLength(0...1)))
    }
}
