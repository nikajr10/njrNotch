//
//  PopNotifier.swift
//  njrNotch
//

import Foundation
import Observation

/// One pop-down notification under the closed notch.
struct PopNote: Identifiable, Equatable {
    enum Kind { case song, done, permission, sessionEnded }

    let id = UUID()
    let kind: Kind
    let title: String
    var detail: String?
    var artworkURL: URL?

    /// The tab a click on the pill opens.
    var tab: NotchTab { kind == .song ? .spotify : .claudeCode }
}

/// Holds the one pill on screen: a newer note replaces the older one, and it hides itself after
/// the time set in Settings → Notifications (later, if the pointer rests on it).
@Observable
final class PopNotifier {
    static let shared = PopNotifier()

    private(set) var current: PopNote?
    @ObservationIgnored var isHovering = false
    @ObservationIgnored private var dismissal: Task<Void, Never>?

    private init() {}

    func post(_ note: PopNote) {
        let prefs = AppSettings.shared.prefs
        let isOn = switch note.kind {
        case .song: prefs.popSong
        case .done: prefs.popDone
        case .permission: prefs.popPermission
        case .sessionEnded: prefs.popSessionEnded
        }
        guard prefs.popOn, isOn else { return }
        current = note
        dismissal?.cancel()
        dismissal = Task { [weak self] in
            try? await Task.sleep(for: .seconds(prefs.popDuration))
            while !Task.isCancelled, self?.isHovering == true, AppSettings.shared.prefs.popKeepWhileHovering {
                try? await Task.sleep(for: .milliseconds(250))
            }
            if !Task.isCancelled { self?.dismiss() }
        }
    }

    func dismiss() {
        dismissal?.cancel()
        isHovering = false
        current = nil
    }
}
