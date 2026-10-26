//
//  UsageLimitsView.swift
//  njrNotch
//

import SwiftUI

/// The plan's 5-hour and weekly limits as two bars, like Claude's own usage page.
/// Account-wide, straight from Claude Code's status line; never invented numbers, never cost.
struct UsageLimitsView: View {
    var body: some View {
        if let limits = StatusLine.shared.limits {
            VStack(alignment: .leading, spacing: 10) {
                if let percent = limits.fiveHourPercent {
                    bar("5-hour limit", percent: percent, resets: limits.fiveHourResets, color: .green,
                        when: .dateTime.hour().minute())
                }
                if let percent = limits.weekPercent {
                    bar("Weekly limit", percent: percent, resets: limits.weekResets, color: .yellow,
                        when: .dateTime.weekday(.abbreviated).hour().minute())
                }
            }
        } else if !ClaudeHooks.isStatusLineInstalled {
            Button("Install the status line in Settings to see your limits") { SettingsWindow.show(.claudeCode) }
                .buttonStyle(.plain)
                .font(.notch(11))
                .foregroundStyle(.secondary)
        }
    }

    private func bar(_ title: String, percent: Double, resets: Date?, color: Color,
                     when format: Date.FormatStyle) -> some View {
        // Past its reset time a window starts again from zero, even before Claude Code sends a new number.
        let isOver = resets.map { $0 < .now } ?? false
        let used = isOver ? 0 : min(max(percent, 0), 100)
        return VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.notch(11, weight: .medium))
                if let resets, !isOver {
                    Text("Resets \(resets.formatted(format))").font(.notch(10)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                Text("\(Int(used.rounded()))% used").font(.notch(11).monospacedDigit()).foregroundStyle(.secondary)
            }
            CapsuleBar(fraction: used / 100, color: color, height: 6)
        }
        .accessibilityElement(children: .combine)
    }
}
