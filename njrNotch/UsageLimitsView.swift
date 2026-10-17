//
//  UsageLimitsView.swift
//  njrNotch
//

import SwiftUI

/// "Usage limits" bars at the top of the Claude Code tab. Shows only numbers Claude Code reported.
struct UsageLimitsView: View {
    let limits: UsageLimits

    private var prefs: Preferences { AppSettings.shared.prefs }

    var body: some View {
        if prefs.showFiveHourLimit || prefs.showWeeklyLimit || prefs.showFableLimit {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                VStack(alignment: .leading, spacing: prefs.compactLayout ? 5 : 8) {
                    Text("Usage limits")
                        .font(.notch(11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    bars(now: context.date)
                }
            }
        }
    }

    @ViewBuilder private func bars(now: Date) -> some View {
        let fiveHour = UsageLimits.current(limits.fiveHour, at: now)
        let weekly = UsageLimits.current(limits.weekly, at: now)
        let fable = UsageLimits.current(limits.fable, at: now)

        if fiveHour == nil && weekly == nil && fable == nil {
            Label(limits.isStatusLineInstalled
                  ? "Waiting for data. Send a message in Claude Code."
                  : "Install the status line in Settings → Claude Code to see your limits.",
                  systemImage: "hourglass")
                .font(.notch(12))
                .foregroundStyle(.secondary)
        } else {
            if prefs.showFiveHourLimit { LimitBar(title: "5-hour limit", window: fiveHour, now: now) }
            if prefs.showWeeklyLimit { LimitBar(title: "Weekly limit", window: weekly, now: now) }
            if prefs.showFableLimit {
                if let fable {
                    LimitBar(title: "Fable limit", window: fable, now: now)
                } else {
                    HStack {
                        Text("Fable limit")
                        Spacer()
                        Text("Not available from Claude Code")
                    }
                    .font(.notch(11))
                    .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct LimitBar: View {
    let title: String
    /// nil when this window is missing from the data, e.g. right after it reset.
    let window: UsageLimits.Window?
    let now: Date

    var body: some View {
        let used = window?.usedPercentage ?? 0
        let color = Self.color(for: used)

        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title).font(.notch(12, weight: .medium))
                Spacer(minLength: 4)
                if let window {
                    Text(UsageLimits.resetText(window.resetsAt, now: now))
                        .font(.notch(11))
                        .foregroundStyle(.secondary)
                    Text("\(Int(used.rounded()))%")
                        .font(.notch(12, weight: .semibold).monospacedDigit())
                        .foregroundStyle(color)
                } else {
                    Text("No data yet").font(.notch(11)).foregroundStyle(.secondary)
                }
            }
            CapsuleBar(fraction: window == nil ? 0 : used / 100, color: color)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: used)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(window.map { "\(Int(used.rounded())) percent used, \(UsageLimits.resetText($0.resetsAt, now: now))" } ?? "No data yet")
    }

    /// Green under 60%, amber from 60 to 85%, red above 85%.
    static func color(for used: Double) -> Color {
        used > 85 ? .red : used >= 60 ? .orange : .green
    }
}
