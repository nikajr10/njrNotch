//
//  AgentMonitor.swift
//  njrNotch
//

import Foundation
import Observation

/// Tracks every agent session from hook events, and holds permission requests the notch can answer.
@Observable
final class AgentMonitor {
    static let shared = AgentMonitor()

    /// Most urgent first: needs permission, then most recently active.
    private(set) var sessions: [AgentSession] = []
    /// Session picked in the notch; nil = show the most urgent one.
    var selectedID: String?
    private(set) var today: TokenUsage.Counts?
    /// Bumped on every finished task, so the closed notch can pulse.
    private(set) var finishCount = 0
    /// Held permission requests by session id, answered with Allow/Deny in the notch.
    private var pending: [String: (reply: HookReply, adapter: AgentAdapter)] = [:]

    @ObservationIgnored private let adapters: [AgentAdapter] = [ClaudeCodeAdapter()]
    @ObservationIgnored private let listener = AgentListener()
    @ObservationIgnored private var lastUsageRefresh = Date.distantPast

    private init() {
        #if DEBUG
        AgentListener.selfCheck()
        ClaudeCodeAdapter.selfCheck()
        #endif
        listener.start { [weak self] request, reply in
            guard let payload = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any] else {
                reply.send()
                return
            }
            self?.receive(path: request.path, payload: payload, reply: reply)
        }
        refreshUsage(sessionID: nil, force: true)
    }

    var current: AgentSession? {
        sessions.first { $0.id == selectedID } ?? sessions.first
    }

    func canAnswer(_ sessionID: String) -> Bool {
        pending[sessionID] != nil
    }

    func answer(_ sessionID: String, allow: Bool) {
        guard let held = pending.removeValue(forKey: sessionID) else { return }
        held.reply.send(held.adapter.permissionReply(allow: allow))
        update(sessionID) {
            $0.status = .working
            $0.permissionRequest = nil
            $0.activity = allow ? "Allowed, continuing…" : "Denied"
        }
    }

    // MARK: - Events

    private func receive(path: String, payload: [String: Any], reply: HookReply) {
        guard let adapter = adapters.first(where: { $0.path == path }), adapter.isEnabled,
              let event = adapter.event(from: payload) else {
            reply.send()
            return
        }
        let id = "\(adapter.path):\(event.sessionID)"

        switch event.kind {
        case .permissionNeeded where AppSettings.shared.prefs.answerPermissionsInNotch
                                     && adapter.permissionReply(allow: true) != nil:
            pending.removeValue(forKey: id)?.reply.send() // an older request falls back to the terminal
            pending[id] = (reply, adapter)
            reply.onClose = { [weak self] in self?.permissionAnsweredElsewhere(id, reply: reply) }
        case .finished, .sessionEnded:
            pending.removeValue(forKey: id)?.reply.send()
            reply.send()
        default:
            reply.send()
        }
        apply(event, to: id, agentName: adapter.name)
    }

    private func apply(_ event: AgentEvent, to id: String, agentName: String) {
        // ponytail: sessions killed without SessionEnd linger until this 12h sweep.
        sessions.removeAll { $0.updatedAt.timeIntervalSinceNow < -12 * 3600 }
        if case .sessionEnded = event.kind {
            sessions.removeAll { $0.id == id }
            return
        }

        var session = sessions.first { $0.id == id } ?? AgentSession(id: id, agentName: agentName)
        if let project = event.project { session.project = project }
        if let transcript = event.transcriptPath { session.transcriptPath = transcript }
        session.updatedAt = .now
        let isHeld = pending[id] != nil

        switch event.kind {
        case .sessionStarted:
            session.status = .idle
        case .promptSubmitted(let prompt):
            session.status = .working
            session.task = Self.shorten(prompt)
            session.activity = "Thinking…"
            session.startedAt = .now
            session.finishedAt = nil
            session.permissionRequest = nil
        case .toolStarted(let activity):
            session.activity = activity
            if !isHeld { session.status = .working; session.permissionRequest = nil }
        case .toolFinished:
            if !isHeld { session.status = .working; session.permissionRequest = nil }
        case .permissionNeeded(let request):
            session.status = .needsPermission
            session.permissionRequest = request
            Alerts.fire(.permission, title: "\(agentName) needs permission · \(session.project)", body: request)
        case .finished(let summary):
            session.status = .done
            session.finishedAt = .now
            session.activity = nil
            session.permissionRequest = nil
            session.lastResult = summary.map(Self.shorten)
            finishCount += 1
            Alerts.fire(.done, title: "\(agentName) finished · \(session.project)", body: session.lastResult ?? "Task finished")
        case .sessionEnded:
            break
        }

        sessions.removeAll { $0.id == id }
        sessions.append(session)
        sessions.sort { lhs, rhs in
            (lhs.status == .needsPermission) != (rhs.status == .needsPermission)
                ? lhs.status == .needsPermission
                : lhs.updatedAt > rhs.updatedAt
        }

        switch event.kind {
        case .sessionStarted, .promptSubmitted, .finished: refreshUsage(sessionID: id, force: true)
        default: refreshUsage(sessionID: id, force: false)
        }
    }

    /// The agent closed a held request: answered in the terminal, or the hook timed out.
    private func permissionAnsweredElsewhere(_ id: String, reply: HookReply) {
        guard pending[id]?.reply === reply else { return }
        pending[id] = nil
        update(id) {
            $0.status = .working
            $0.permissionRequest = nil
        }
    }

    private func update(_ id: String, _ change: (inout AgentSession) -> Void) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        change(&sessions[index])
    }

    nonisolated private static func shorten(_ text: String) -> String {
        let line = text.split(whereSeparator: \.isNewline).first { !$0.allSatisfy(\.isWhitespace) } ?? ""
        return String(line.trimmingCharacters(in: .whitespaces).prefix(200))
    }

    // MARK: - Tokens

    /// Transcripts can be many MB, so totals are computed off the main thread, at most every 10s mid-task.
    private func refreshUsage(sessionID: String?, force: Bool) {
        guard AppSettings.shared.prefs.showTokens,
              force || Date().timeIntervalSince(lastUsageRefresh) > 10 else { return }
        lastUsageRefresh = .now
        let transcript = sessions.first { $0.id == sessionID }?.transcriptPath
        Task.detached(priority: .utility) {
            let sessionCounts = transcript.map { TokenUsage.counts(in: URL(fileURLWithPath: $0)) }
            let todayCounts = TokenUsage.today()
            await MainActor.run {
                self.today = todayCounts
                if let sessionID, let sessionCounts {
                    self.update(sessionID) { $0.tokens = sessionCounts }
                }
            }
        }
    }
}
