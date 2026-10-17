//
//  SpotifyAccount.swift
//  njrNotch
//

import AppKit
import CryptoKit
import Observation

/// Optional Spotify Web API sign-in, used only by the like button. PKCE, so no client secret:
/// the user pastes their own Spotify app's Client ID in Settings. Spotify sends the browser back
/// to a listener on 127.0.0.1 that runs only during sign-in; the refresh token goes in the Keychain.
@Observable
final class SpotifyAccount {
    static let shared = SpotifyAccount()
    static let callbackPort: UInt16 = 47824
    /// Must be added, exactly, to the Spotify app's redirect URIs.
    static let redirectURI = "http://127.0.0.1:\(callbackPort)/callback"
    private static let tokenKey = "spotify-refresh-token"

    private(set) var isConnected = Keychain.contains(SpotifyAccount.tokenKey)
    /// Sign-in progress or the last problem, shown in Settings.
    private(set) var status: String?

    @ObservationIgnored private var accessToken: String?
    @ObservationIgnored private var expiry = Date.distantPast
    @ObservationIgnored private var signIn: (state: String, verifier: String)?
    @ObservationIgnored private var callback: AgentListener?
    @ObservationIgnored private var refreshing: Task<String?, Never>?

    private init() {
        #if DEBUG
        Self.selfCheck()
        #endif
    }

    private var clientID: String {
        AppSettings.shared.prefs.spotifyClientID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func connect() {
        guard !clientID.isEmpty else { return }
        if callback == nil { // a second click reuses it rather than re-binding the port
            callback = AgentListener(port: Self.callbackPort)
            callback?.start { [weak self] request, reply in self?.finishSignIn(request, reply: reply) }
        }
        let state = Self.randomString(16)
        let verifier = Self.randomString(64)
        signIn = (state, verifier)

        var url = URLComponents(string: "https://accounts.spotify.com/authorize")!
        url.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: Self.challenge(for: verifier)),
            URLQueryItem(name: "scope", value: "user-library-read user-library-modify"),
            URLQueryItem(name: "state", value: state),
        ]
        NSWorkspace.shared.open(url.url!)
        status = "Approve njrNotch in your browser…"
    }

    func disconnect() {
        Keychain.delete(Self.tokenKey)
        accessToken = nil
        isConnected = false
        status = nil
    }

    /// Whether `uri` is in Liked Songs; nil if Spotify can't be asked.
    func isSaved(_ uri: String) async -> Bool? {
        guard let data = await call("GET", "me/library/contains", uri: uri) else { return nil }
        return (try? JSONDecoder().decode([Bool].self, from: data))?.first
    }

    /// Adds `uri` to Liked Songs, or removes it. True if Spotify accepted.
    func setSaved(_ uri: String, _ saved: Bool) async -> Bool {
        await call(saved ? "PUT" : "DELETE", "me/library", uri: uri) != nil
    }

    // MARK: - Sign-in

    /// The browser's redirect: GET /callback?code=…&state=…
    private func finishSignIn(_ request: AgentListener.Request, reply: HookReply) {
        guard request.path == "/callback", let signIn else { return reply.send() } // e.g. /favicon.ico
        let items = Dictionary(request.query.map { ($0.name, $0.value ?? "") }) { first, _ in first }
        guard items["state"] == signIn.state else {
            return reply.send(Self.page("This sign-in link is out of date. Click Connect in njrNotch again."),
                              contentType: "text/html; charset=utf-8")
        }
        callback?.stop()
        callback = nil
        self.signIn = nil
        guard let code = items["code"] else {
            status = "Sign-in was cancelled."
            return reply.send(Self.page("Sign-in was cancelled."), contentType: "text/html; charset=utf-8")
        }
        reply.send(Self.page("You can close this tab and go back to njrNotch."),
                   contentType: "text/html; charset=utf-8")
        status = "Connecting…"
        Task {
            let token = await requestToken([
                "grant_type": "authorization_code", "code": code,
                "redirect_uri": Self.redirectURI, "code_verifier": signIn.verifier,
            ])
            if token != nil { status = nil }
        }
    }

    // MARK: - Tokens and calls

    private func call(_ method: String, _ path: String, uri: String) async -> Data? {
        guard let token = await validToken() else { return nil }
        var url = URLComponents(string: "https://api.spotify.com/v1/" + path)!
        url.queryItems = [URLQueryItem(name: "uris", value: uri)]
        var request = URLRequest(url: url.url!)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if method != "GET" { request.httpBody = Data() } // sends Content-Length: 0
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let code = (response as? HTTPURLResponse)?.statusCode else { return nil }
        if code == 401 { accessToken = nil } // expired early; the next call refreshes
        return code == 200 ? data : nil
    }

    private func validToken() async -> String? {
        if let accessToken, expiry > .now.addingTimeInterval(60) { return accessToken }
        // One refresh at a time: Spotify may retire the refresh token on use, so a second
        // concurrent refresh would fail and look like the user disconnected.
        if let refreshing { return await refreshing.value }
        guard isConnected, let refresh = Keychain.read(Self.tokenKey) else { return nil }
        let task = Task { await requestToken(["grant_type": "refresh_token", "refresh_token": refresh]) }
        refreshing = task
        defer { refreshing = nil }
        return await task.value
    }

    /// POSTs to Spotify's token endpoint and keeps the tokens it returns.
    private func requestToken(_ form: [String: String]) async -> String? {
        var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(Self.formEncode(form.merging(["client_id": clientID]) { mine, _ in mine }).utf8)

        guard let (data, response) = try? await URLSession.shared.data(for: request) else {
            status = "Couldn't reach Spotify. Check your connection."
            return nil
        }
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200, let token = try? JSONDecoder().decode(TokenResponse.self, from: data) else {
            if code == 400 || code == 401 {
                // Refused: a wrong Client ID or redirect URI, or access was removed in Spotify.
                disconnect()
                status = "Spotify refused the sign-in. Check the Client ID and redirect URI, then connect again."
            } else {
                status = "Spotify didn't answer (HTTP \(code)). Try again in a minute."
            }
            return nil
        }
        accessToken = token.access_token
        expiry = .now.addingTimeInterval(TimeInterval(token.expires_in))
        // Spotify may rotate the refresh token; the old one stops working.
        if let refresh = token.refresh_token { Keychain.save(refresh, for: Self.tokenKey) }
        isConnected = true
        return token.access_token
    }

    private struct TokenResponse: Decodable {
        let access_token: String
        let expires_in: Int
        let refresh_token: String?
    }

    // MARK: - Helpers

    private static func formEncode(_ form: [String: String]) -> String {
        let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return form.map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: unreserved) ?? "")"
        }.joined(separator: "&")
    }

    /// Letters and digits from the system CSPRNG.
    private static func randomString(_ length: Int) -> String {
        let characters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
        return String((0..<length).map { _ in characters.randomElement()! })
    }

    /// PKCE S256: base64url(SHA-256(verifier)) without padding.
    static func challenge(for verifier: String) -> String {
        Data(SHA256.hash(data: Data(verifier.utf8))).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func page(_ message: String) -> Data {
        Data("""
            <!doctype html><meta charset="utf-8"><title>njrNotch</title>
            <body style="font: 16px -apple-system, sans-serif; text-align: center; padding-top: 80px">
            <p>\(message)</p></body>
            """.utf8)
    }

    #if DEBUG
    /// Runnable check against the RFC 7636 example; called once at launch in debug builds.
    static func selfCheck() {
        assert(challenge(for: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk") == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
        assert(formEncode(["a": "x y&z+/"]) == "a=x%20y%26z%2B%2F")
        assert(randomString(64).count == 64)
    }
    #endif
}
