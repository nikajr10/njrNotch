//
//  AgentStatusView.swift
//  njrNotch
//

import SwiftUI

extension AgentStatus {
    var label: String {
        switch self {
        case .idle: "Idle"
        case .working: "Working"
        case .needsPermission: "Needs permission"
        case .done: "Done"
        }
    }

    var color: Color {
        switch self {
        case .idle: .gray
        case .working: .cyan
        case .needsPermission: .orange
        case .done: .green
        }
    }

    var symbol: String {
        switch self {
        case .idle: "moon.zzz.fill"
        case .working: "waveform"
        case .needsPermission: "exclamationmark.triangle.fill"
        case .done: "checkmark.circle.fill"
        }
    }
}

/// Status icon: bars fill in turn while working, pulses while waiting for permission, bounces when done.
/// An AppKit image view, so Core Animation runs the effect. Any changing SwiftUI view here kept the
/// whole notch re-rendering at the display's refresh rate: ~15% CPU for as long as an agent worked.
struct AgentStatusIcon: NSViewRepresentable {
    let status: AgentStatus
    let size: CGFloat
    var animates = true

    func makeNSView(context: Context) -> NSImageView {
        let view = NSImageView()
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.setContentHuggingPriority(.required, for: .vertical)
        return view
    }

    func updateNSView(_ view: NSImageView, context: Context) {
        // Only on a real change: re-adding the effect on every SwiftUI update would restart it.
        guard context.coordinator.shown.map({ $0 != (status, size, animates) }) ?? true else { return }
        context.coordinator.shown = (status, size, animates)
        view.image = NSImage(systemSymbolName: status.symbol, accessibilityDescription: status.label)?
            .withSymbolConfiguration(.init(pointSize: size, weight: .semibold))
        view.contentTintColor = NSColor(status.color)
        view.removeAllSymbolEffects()
        guard animates else { return }
        switch status {
        case .working: view.addSymbolEffect(.variableColor.iterative, options: .repeating)
        case .needsPermission: view.addSymbolEffect(.pulse, options: .repeating)
        case .done: view.addSymbolEffect(.bounce, options: .nonRepeating)
        case .idle: break
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var shown: (AgentStatus, CGFloat, Bool)?
    }
}

/// One agent session in the Claude Code tab: state, what it's doing, permission prompt,
/// session time, model, context left and tokens. Anything the agent didn't report is hidden.
struct AgentStatusView: View {
    let agent: AgentMonitor
    let session: AgentSession

    private var prefs: Preferences { AppSettings.shared.prefs }
    /// Status line data for this session, if the optional status line is installed.
    private var statusLine: StatusLine.Info? {
        StatusLine.shared.sessions[String(session.id.drop { $0 != ":" }.dropFirst())]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: prefs.compactLayout ? 6 : 9) {
            if agent.sessions.count > 1 {
                sessionPicker
            }
            header

            if session.status == .needsPermission, let request = session.permissionRequest {
                permissionBox(request)
            }
            if prefs.showActivity, session.status == .working {
                Label(session.activity ?? "Working…", systemImage: "arrow.forward.circle")
                    .font(.notch(12))
                    .foregroundStyle(AgentStatus.working.color)
                    .lineLimit(1)
            }
            if prefs.showTask, let task = session.task {
                line("Task", task)
            }
            if prefs.showLastResult, session.status == .done, let result = session.lastResult {
                line("Result", result, lines: 3)
            }
            modelRow
            TokenBlock(session: session, today: agent.today)
        }
    }

    private var sessionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(agent.sessions) { item in
                    Button {
                        agent.selectedID = item.id
                    } label: {
                        HStack(spacing: 5) {
                            Circle().fill(item.status.color).frame(width: 7, height: 7)
                            Text(item.project.isEmpty ? item.agentName : item.project).lineLimit(1)
                        }
                        .font(.notch(11))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(item.id == session.id ? prefs.claudeAccent.opacity(0.25) : .primary.opacity(0.07),
                                    in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(item.project), \(item.status.label)")
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            AgentStatusIcon(status: session.status, size: (18 * prefs.textScale).rounded())
                .frame(width: 26, height: 26)
                .background(session.status.color.opacity(0.18), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(session.status.label)
                    .font(.notch(13, weight: .semibold))
                    .foregroundStyle(session.status.color)
                Text(session.project.isEmpty ? session.agentName : session.project)
                    .font(.notch(11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if prefs.showElapsed, let start = session.startedAt {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Label(Self.elapsed(from: start, to: context.date), systemImage: "clock")
                        .font(.notch(11).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Session time \(Self.elapsed(from: start, to: context.date))")
                }
            }
        }
    }

    /// "Opus 5.5 · high effort", from the status line or the transcript; only what they contain.
    @ViewBuilder private var modelRow: some View {
        let model = statusLine?.model ?? session.model.map(TokenUsage.displayName(model:))
        let effort = statusLine?.effort ?? session.effort
        if model != nil || effort != nil {
            HStack(spacing: 12) {
                if let model {
                    Label(model, systemImage: "cpu")
                }
                if let effort {
                    Label("\(effort) effort", systemImage: "gauge.with.dots.needle.67percent")
                }
            }
            .font(.notch(11))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
    }

    private func permissionBox(_ request: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(request)
                .font(.system(size: (11 * prefs.textScale).rounded(), design: .monospaced))
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
            if agent.canAnswer(session.id) {
                // Drawn here, not .borderedProminent: native buttons lose their colour in the notch panel.
                HStack(spacing: 8) {
                    pill("Deny", fill: .primary.opacity(0.15)) { agent.answer(session.id, allow: false) }
                    pill("Allow", fill: .orange) { agent.answer(session.id, allow: true) }
                        .foregroundStyle(.white)
                }
            } else {
                Label("Go to your terminal to answer", systemImage: "terminal")
                    .font(.notch(11))
                    .foregroundStyle(.orange)
            }
        }
        .padding(8)
        .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
    }

    private func pill(_ title: String, fill: some ShapeStyle, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.notch(11, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
                .background(fill, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func line(_ title: String, _ text: String, lines: Int = 1) -> some View {
        (Text("\(title)  ").foregroundStyle(.secondary) + Text(text))
            .font(.notch(11))
            .lineLimit(lines)
    }

    private static func elapsed(from start: Date, to end: Date) -> String {
        let seconds = max(0, end.timeIntervalSince(start))
        return Duration.seconds(seconds).formatted(.time(pattern: seconds >= 3600 ? .hourMinuteSecond : .minuteSecond))
    }
}
