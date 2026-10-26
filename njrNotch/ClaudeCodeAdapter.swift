//
//  ClaudeCodeAdapter.swift
//  njrNotch
//

import Foundation

/// Reads Claude Code `http` hook payloads (https://code.claude.com/docs/en/hooks).
struct ClaudeCodeAdapter: AgentAdapter {
    /// Must match URL in Hooks/install-claude-hooks.sh.
    static let hookURL = "http://127.0.0.1:\(AgentListener.port)/claude"

    let name = "Claude Code"
    let path = "/claude"
    var isEnabled: Bool { AppSettings.shared.prefs.claudeCodeEnabled }

    func event(from payload: [String: Any]) -> AgentEvent? {
        guard let sessionID = payload["session_id"] as? String else { return nil }
        let tool = payload["tool_name"] as? String ?? "a tool"
        let input = payload["tool_input"] as? [String: Any] ?? [:]
        let summary = payload["last_assistant_message"] as? String

        let kind: AgentEvent.Kind
        switch payload["hook_event_name"] as? String {
        case "SessionStart": kind = .sessionStarted
        case "UserPromptSubmit": kind = .promptSubmitted(payload["prompt"] as? String ?? "")
        case "PreToolUse": kind = .toolStarted(activity: Self.activity(tool: tool, input: input), symbol: Self.symbol(tool: tool))
        case "PostToolUse": kind = .toolFinished
        case "PermissionRequest": kind = .permissionNeeded(request: Self.request(tool: tool, input: input))
        case "Stop": kind = .finished(summary: summary)
        case "StopFailure": kind = .finished(summary: summary ?? "Stopped with an error")
        case "SessionEnd": kind = .sessionEnded
        default: return nil
        }
        return AgentEvent(
            sessionID: sessionID,
            kind: kind,
            project: (payload["cwd"] as? String).map { URL(fileURLWithPath: $0).lastPathComponent },
            transcriptPath: payload["transcript_path"] as? String
        )
    }

    func permissionReply(allow: Bool) -> Data? {
        let decision: [String: Any] = allow
            ? ["behavior": "allow"]
            : ["behavior": "deny", "message": "The user denied this from njrNotch."]
        return try? JSONSerialization.data(withJSONObject: [
            "hookSpecificOutput": ["hookEventName": "PermissionRequest", "decision": decision],
        ])
    }

    /// Short "what is it doing" line, e.g. "Editing NotchView.swift" or "Running xcodebuild".
    static func activity(tool: String, input: [String: Any]) -> String {
        let file = (input["file_path"] ?? input["notebook_path"]) as? String
        let fileName = file.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "a file"
        switch tool {
        case "Edit", "MultiEdit", "Write", "NotebookEdit": return "Editing \(fileName)"
        case "Read": return "Reading \(fileName)"
        case "Bash": return "Running \(program(in: input["command"] as? String) ?? "a command")"
        case "Grep", "Glob": return "Searching \(input["pattern"] as? String ?? "files")"
        case "WebFetch": return "Fetching \((input["url"] as? String).flatMap { URL(string: $0)?.host() } ?? "a page")"
        case "WebSearch": return "Searching the web"
        case "Task", "Agent": return "Running a subagent"
        case "TodoWrite": return "Updating the plan"
        default: return "Using \(tool)"
        }
    }

    /// The tool as an icon: pencil for edits, terminal for commands, magnifier for searches, and so on.
    static func symbol(tool: String) -> String {
        switch tool {
        case "Edit", "MultiEdit", "Write", "NotebookEdit": "pencil"
        case "Read": "doc.text"
        case "Bash": "terminal"
        case "Grep", "Glob": "magnifyingglass"
        case "WebFetch", "WebSearch": "globe"
        case "Task", "Agent": "person.2"
        case "TodoWrite": "checklist"
        default: "wrench.and.screwdriver"
        }
    }

    /// What a permission prompt is asking for: the command, file or URL.
    static func request(tool: String, input: [String: Any]) -> String {
        let detail = (input["command"] ?? input["file_path"] ?? input["url"] ?? input["description"]) as? String
        return detail.map { "\(tool): \($0)" } ?? tool
    }

    /// First real program in a shell command: "cd app && xcodebuild -q" -> "xcodebuild".
    static func program(in command: String?) -> String? {
        command?
            .components(separatedBy: CharacterSet(charactersIn: "&|;\n"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty && !$0.hasPrefix("cd ") }?
            .split(separator: " ").first
            .map { URL(fileURLWithPath: String($0)).lastPathComponent }
    }

    #if DEBUG
    /// Runnable check for the activity text; called once at launch in debug builds.
    static func selfCheck() {
        assert(program(in: "cd app && xcodebuild -scheme x build") == "xcodebuild")
        assert(program(in: "/usr/bin/python3 -I x.py | head") == "python3")
        assert(program(in: "") == nil)
        assert(activity(tool: "Edit", input: ["file_path": "/a/NotchView.swift"]) == "Editing NotchView.swift")
        assert(symbol(tool: "Bash") == "terminal" && symbol(tool: "mcp__x__y") == "wrench.and.screwdriver")
        assert(request(tool: "Bash", input: ["command": "rm -rf build"]) == "Bash: rm -rf build")
    }
    #endif
}

/// Installs or removes the hooks and the status line by running the bundled scripts in njrNotch/Hooks.
enum ClaudeHooks {
    static let home = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
    static let settingsFile = home.appendingPathComponent("settings.json")

    static var isInstalled: Bool {
        settings.contains(ClaudeCodeAdapter.hookURL)
    }

    /// The status line feeds the usage bars (see install-statusline.sh).
    static var isStatusLineInstalled: Bool {
        settings.contains("njrnotch-statusline.sh")
    }

    private static var settings: String {
        (try? String(contentsOf: settingsFile, encoding: .utf8)) ?? ""
    }

    /// Runs a bundled script, e.g. "install-claude-hooks" or "uninstall-statusline", and returns its output.
    static func run(_ script: String) -> String {
        guard let url = Bundle.main.url(forResource: script, withExtension: "sh") else {
            return "\(script).sh is missing from the app bundle."
        }
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [url.path]
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return error.localizedDescription
        }
        return String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
