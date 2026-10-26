//
//  AgentModel.swift
//  njrNotch
//

import Foundation

// Agent-neutral types. To support another coding agent: write an `AgentAdapter`
// that turns its hook payloads into `AgentEvent`s, and add it to `AgentMonitor.adapters`.

enum AgentStatus {
    case idle, working, needsPermission, done
}

struct AgentEvent {
    enum Kind {
        case sessionStarted
        case promptSubmitted(String)
        /// `symbol`: an SF Symbol for the tool, shown beside the closed notch.
        case toolStarted(activity: String, symbol: String)
        case toolFinished
        case permissionNeeded(request: String)
        case finished(summary: String?)
        case sessionEnded
    }

    let sessionID: String
    let kind: Kind
    var project: String?
    var transcriptPath: String?
}

protocol AgentAdapter {
    /// Shown in the notch, e.g. "Claude Code".
    var name: String { get }
    /// URL path the agent's hooks POST to on the local listener, e.g. "/claude".
    var path: String { get }
    var isEnabled: Bool { get }
    func event(from payload: [String: Any]) -> AgentEvent?
    /// HTTP response body that answers a permission request; nil if the agent can't be answered from a hook.
    func permissionReply(allow: Bool) -> Data?
}

struct AgentSession: Identifiable {
    let id: String
    let agentName: String
    var project = ""
    var status = AgentStatus.idle
    var task: String?
    var activity: String?
    /// SF Symbol for what it's doing now; "ellipsis" while it thinks.
    var activitySymbol: String?
    /// The current task's start (its prompt) and end (Stop), for the task clock. nil = not seen.
    var taskStartedAt: Date?
    var taskEndedAt: Date?
    var lastResult: String?
    var permissionRequest: String?
    var transcriptPath: String?
    /// Model id and effort level as logged in the transcript.
    var model: String?
    var effort: String?
    var updatedAt = Date()
}
