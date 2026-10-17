//
//  AgentListener.swift
//  njrNotch
//

import Foundation
import Network

/// Minimal HTTP server bound to 127.0.0.1: agent hook POSTs, and Spotify's sign-in redirect.
final class AgentListener {
    static let port: UInt16 = 47823

    typealias Request = (path: String, query: [URLQueryItem], body: Data)
    typealias Handler = (_ request: Request, _ reply: HookReply) -> Void

    private let port: UInt16
    private var listener: NWListener?
    private var handler: Handler?

    init(port: UInt16 = AgentListener.port) {
        self.port = port
    }

    func start(handler: @escaping Handler) {
        self.handler = handler
        let params = NWParameters.tcp
        params.acceptLocalOnly = true
        params.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: NWEndpoint.Port(rawValue: port)!)
        do {
            listener = try NWListener(using: params)
        } catch {
            print("njrNotch: agent listener failed to start: \(error)")
            return
        }
        listener?.newConnectionHandler = { [weak self] connection in
            connection.start(queue: .main)
            self?.receive(connection, buffer: Data())
        }
        listener?.start(queue: .main)
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func receive(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            var buffer = buffer
            if let data { buffer.append(data) }

            if let request = Self.parse(buffer) {
                guard Self.isTrusted(buffer, port: self?.port ?? 0) else { return connection.cancel() }
                let reply = HookReply(connection: connection)
                Self.watchForClose(connection, reply: reply)
                self?.handler?(request, reply)
            } else if isComplete || error != nil || buffer.count > 8_000_000 {
                connection.cancel()
            } else {
                self?.receive(connection, buffer: buffer)
            }
        }
    }

    /// A held permission request ends early if the agent gives up on it (answered in the terminal, timed out).
    private static func watchForClose(_ connection: NWConnection, reply: HookReply) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1) { _, _, isComplete, error in
            if isComplete || error != nil { reply.clientClosed() }
        }
    }

    /// Hooks come from Claude Code and the sign-in redirect from a browser tab, never from a script on a web page.
    /// Browsers add `Origin` to script requests (a top-level navigation like the redirect has none), and a
    /// DNS-rebinding page names its own host. Either is refused, so websites can't post fake events or prompts.
    nonisolated static func isTrusted(_ request: Data, port: UInt16) -> Bool {
        guard let headerEnd = request.range(of: Data("\r\n\r\n".utf8)) else { return false }
        let headers = String(decoding: request[..<headerEnd.lowerBound], as: UTF8.self)
            .components(separatedBy: "\r\n").dropFirst()
            .map { $0.lowercased() }
        if headers.contains(where: { $0.hasPrefix("origin:") }) { return false }
        guard let host = headers.first(where: { $0.hasPrefix("host:") }) else { return true }
        let value = host.dropFirst("host:".count).trimmingCharacters(in: .whitespaces)
        return value == "127.0.0.1:\(port)" || value == "localhost:\(port)"
    }

    /// Path, query and body once the headers and `Content-Length` bytes have all arrived.
    nonisolated static func parse(_ request: Data) -> Request? {
        guard let headerEnd = request.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let lines = String(decoding: request[..<headerEnd.lowerBound], as: UTF8.self).components(separatedBy: "\r\n")
        let target = lines.first?.split(separator: " ").dropFirst().first.map(String.init) ?? "/"
        let path = target.components(separatedBy: "?")[0]
        let query = URLComponents(string: target)?.queryItems ?? []
        let length = lines
            .first { $0.lowercased().hasPrefix("content-length:") }
            .flatMap { Int($0.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces)) } ?? 0
        let body = request[headerEnd.upperBound...]
        return body.count >= length ? (path, query, Data(body.prefix(length))) : nil
    }

    #if DEBUG
    /// Runnable check for the request parser; called once at launch in debug builds.
    static func selfCheck() {
        let full = parse(Data("POST /claude?x=1 HTTP/1.1\r\nContent-Length: 2\r\n\r\n{}".utf8))
        assert(full?.path == "/claude" && full?.body == Data("{}".utf8) && full?.query == [URLQueryItem(name: "x", value: "1")])
        assert(parse(Data("GET /callback?code=a&state=b HTTP/1.1\r\nHost: x\r\n\r\n".utf8))?.query.count == 2)
        assert(parse(Data("POST / HTTP/1.1\r\ncontent-length: 5\r\n\r\n{}".utf8)) == nil)
        assert(parse(Data("POST / HTTP/1.1\r\nContent-Length: 2\r\n".utf8)) == nil)
        let hook = "POST /claude HTTP/1.1\r\nHost: 127.0.0.1:47823\r\nContent-Length: 2\r\n\r\n{}"
        assert(isTrusted(Data(hook.utf8), port: 47823))
        assert(!isTrusted(Data(hook.replacingOccurrences(of: "Host:", with: "Origin: https://evil.example\r\nHost:").utf8), port: 47823))
        assert(!isTrusted(Data(hook.replacingOccurrences(of: "127.0.0.1:47823", with: "evil.example:47823").utf8), port: 47823))
    }
    #endif
}

/// The open HTTP response for one hook call. Send exactly once; later calls are ignored.
final class HookReply {
    private let connection: NWConnection
    private(set) var isFinished = false
    /// Called if the agent closes the connection before we reply.
    var onClose: (() -> Void)?

    init(connection: NWConnection) {
        self.connection = connection
    }

    /// Empty 200 = "no decision", which never blocks the agent.
    func send(_ body: Data? = nil, contentType: String = "application/json") {
        guard !isFinished else { return }
        isFinished = true
        let body = body ?? Data()
        let head = "HTTP/1.1 200 OK\r\nContent-Type: \(contentType)\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        connection.send(content: Data(head.utf8) + body, completion: .contentProcessed { [connection] _ in
            connection.cancel()
        })
    }

    fileprivate func clientClosed() {
        guard !isFinished else { return }
        isFinished = true
        connection.cancel()
        onClose?()
    }
}
