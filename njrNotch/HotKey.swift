//
//  HotKey.swift
//  njrNotch
//

import AppKit
import Carbon.HIToolbox
import SwiftUI

/// The global shortcut that opens and closes the notch (default ⌃⌥N). Carbon hot keys work from any
/// app without Accessibility permission.
enum HotKey {
    private static var ref: EventHotKeyRef?
    private static var handler: EventHandlerRef?
    private static var registered: (Bool, Int, Int)?

    static let defaultCode = 45, defaultModifiers = 6144, defaultLabel = "⌃⌥N"

    /// Registers the shortcut saved in Settings; does nothing if it hasn't changed.
    static func apply() {
        let prefs = AppSettings.shared.prefs
        let wanted = (prefs.hotKeyOn, prefs.hotKeyCode, prefs.hotKeyModifiers)
        guard registered.map({ $0 != wanted }) ?? true else { return }
        registered = wanted
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
        guard prefs.hotKeyOn else { return }
        if handler == nil {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
                MainActor.assumeIsolated { NotchState.shared.toggle() } // delivered on the main thread
                return noErr
            }, 1, &spec, nil, &handler)
        }
        let id = EventHotKeyID(signature: OSType(0x6E6A_726E), id: 1) // "njrn"
        RegisterEventHotKey(UInt32(prefs.hotKeyCode), UInt32(prefs.hotKeyModifiers), id,
                            GetApplicationEventTarget(), 0, &ref)
    }

    /// Carbon modifier bits and a label like "⌃⌥N" for a key press, or nil without ⌃, ⌥ or ⌘.
    static func shortcut(from event: NSEvent) -> (modifiers: Int, label: String)? {
        let flags = event.modifierFlags
        let parts: [(NSEvent.ModifierFlags, Int, String)] = [
            (.control, controlKey, "⌃"), (.option, optionKey, "⌥"), (.shift, shiftKey, "⇧"), (.command, cmdKey, "⌘"),
        ]
        guard !flags.intersection([.control, .option, .command]).isEmpty else { return nil }
        let held = parts.filter { flags.contains($0.0) }
        let key = event.keyCode == kVK_Space ? "Space" : (event.charactersIgnoringModifiers ?? "?").uppercased()
        return (held.reduce(0) { $0 | $1.1 }, held.map(\.2).joined() + key)
    }
}

/// Click, then press the new shortcut. Escape cancels.
struct ShortcutRecorder: View {
    @Bindable private var settings = AppSettings.shared
    @State private var monitor: Any?

    var body: some View {
        HStack {
            Button(monitor == nil ? settings.prefs.hotKeyLabel : "Press a shortcut…") {
                monitor == nil ? start() : stop()
            }
            .monospaced()
            Button("Reset") {
                settings.prefs.hotKeyCode = HotKey.defaultCode
                settings.prefs.hotKeyModifiers = HotKey.defaultModifiers
                settings.prefs.hotKeyLabel = HotKey.defaultLabel
            }
            .disabled(settings.prefs.hotKeyLabel == HotKey.defaultLabel)
        }
        .onDisappear(perform: stop)
    }

    private func start() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                stop()
            } else if let shortcut = HotKey.shortcut(from: event) {
                settings.prefs.hotKeyCode = Int(event.keyCode)
                settings.prefs.hotKeyModifiers = shortcut.modifiers
                settings.prefs.hotKeyLabel = shortcut.label
                stop()
            } else {
                NSSound.beep() // needs ⌃, ⌥ or ⌘
            }
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
