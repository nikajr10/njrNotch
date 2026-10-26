//
//  NotchSettingsView.swift
//  njrNotch
//

import SwiftUI

/// Settings inside the open notch: the list of sections, then the chosen section's page. The pages are the
/// Settings window's own views on the same saved values, so the two always match.
struct NotchSettingsView: View {
    /// The notch grows to at least this height for Settings.
    static let minHeight: CGFloat = 420
    private static let sections: [SettingsSection] = [.appearance, .spotify, .claudeCode, .notifications, .sounds, .updates, .general]

    let notchSize: CGSize
    private var section: SettingsSection? {
        get { NotchState.shared.settingsSection }
        nonmutating set { NotchState.shared.settingsSection = newValue }
    }

    private var prefs: Preferences { AppSettings.shared.prefs }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            if let section {
                page(section)
                    .scrollContentBackground(.hidden)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                list
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: section)
        .padding(.horizontal, prefs.padding)
        .padding(.top, notchSize.height + 6)
        .padding(.bottom, prefs.padding * 0.5)
        .frame(width: prefs.expandedWidth, height: max(prefs.expandedHeight, Self.minHeight), alignment: .top)
        .foregroundStyle(.primary)
        .tint(prefs.accent)
        .environment(\.colorScheme, prefs.notchScheme)
    }

    /// Back goes to the list, then out of Settings.
    private var header: some View {
        ZStack {
            Text(section?.title ?? "Settings")
                .font(.notch(13, weight: .semibold))
            HStack {
                Button {
                    if section != nil { section = nil } else { NotchState.shared.closeSettings() }
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .font(.notch(12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                Spacer()
            }
        }
        .frame(height: 22)
    }

    private var list: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 2) {
                ForEach(Self.sections) { item in
                    Button {
                        section = item
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: item.symbol)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 22, height: 22)
                                .background(item.color.gradient, in: RoundedRectangle(cornerRadius: 6))
                            Text(item.title).font(.notch(13))
                            Spacer()
                            if item == .updates, Updater.shared.hasUpdate {
                                Text("New")
                                    .font(.notch(11, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(.blue, in: Capsule())
                            }
                            Image(systemName: "chevron.right")
                                .font(.notch(11, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Text("Quit njrNotch")
                        .font(.notch(13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(.red, in: RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 10)
            }
        }
    }

    @ViewBuilder
    private func page(_ section: SettingsSection) -> some View {
        switch section {
        case .appearance: AppearanceSettings(showsPreview: false)
        case .spotify: SpotifySettings()
        case .claudeCode: ClaudeCodeSettings()
        case .notifications: NotificationSettings()
        case .sounds: SoundSettings()
        case .updates: UpdatesSettings()
        case .general: GeneralSettings()
        case .about: AboutSettings()
        }
    }
}
