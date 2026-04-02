import SwiftUI
import Carbon.HIToolbox
import AppKit

// MARK: - Shortcut Action ID

private enum ShortcutAction: String, CaseIterable {
    case toggleRecording
    case cancelRecording
    case changeMode
    case pushToTalk
    case mouseShortcut
}

// MARK: - Configuration View

struct ConfigurationView: View {
    @Binding var config: AppConfig
    var onSave: () async -> Void

    @State private var recordingAction: ShortcutAction?
    @State private var duplicateWarning: ShortcutAction?
    @State private var eventMonitor: Any?

    private let systemSounds: [String] = {
        let soundsDir = "/System/Library/Sounds"
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: soundsDir) else { return [] }
        return files
            .filter { $0.hasSuffix(".aiff") }
            .map { $0.replacingOccurrences(of: ".aiff", with: "") }
            .sorted()
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                keyboardShortcutsSection
                optionsSection
                soundSection
            }
            .padding(24)
        }
        .onDisappear {
            stopRecording()
        }
    }

    // MARK: - Keyboard Shortcuts

    private var keyboardShortcutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Keyboard Shortcuts")
                .font(.headline)

            SettingsCard {
                VStack(spacing: 0) {
                    shortcutRow(
                        action: .toggleRecording,
                        title: "Toggle Recording",
                        subtitle: "Starts and stops recordings",
                        shortcut: config.toggleRecording,
                        defaultShortcut: .defaultToggleRecording
                    )

                    Divider().padding(.leading, 16)

                    shortcutRow(
                        action: .cancelRecording,
                        title: "Cancel Recording",
                        subtitle: "Discards active recording",
                        shortcut: config.cancelRecording,
                        defaultShortcut: .defaultCancelRecording
                    )

                    Divider().padding(.leading, 16)

                    shortcutRow(
                        action: .changeMode,
                        title: "Change mode",
                        subtitle: "Activates the mode switcher",
                        shortcut: config.changeMode,
                        defaultShortcut: .defaultChangeMode
                    )

                    Divider().padding(.leading, 16)

                    shortcutRow(
                        action: .pushToTalk,
                        title: "Push to Talk",
                        subtitle: "Hold to record, release when done",
                        shortcut: config.pushToTalk,
                        defaultShortcut: .empty
                    )

                    Divider().padding(.leading, 16)

                    shortcutRow(
                        action: .mouseShortcut,
                        title: "Mouse shortcut",
                        subtitle: "Tap to toggle, or hold and release when done",
                        shortcut: config.mouseShortcut,
                        defaultShortcut: .empty
                    )
                }
            }
        }
    }

    // MARK: - Shortcut Row Builder

    private func shortcutRow(
        action: ShortcutAction,
        title: String,
        subtitle: String,
        shortcut: HotkeyCombo,
        defaultShortcut: HotkeyCombo
    ) -> some View {
        let isRecording = recordingAction == action
        let isDuplicate = duplicateWarning == action

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isRecording {
                Text("Press shortcut...")
                    .font(.caption)
                    .foregroundStyle(DS.tertiary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: DS.radiusPill, style: .continuous)
                            .fill(DS.tertiary.opacity(0.1))
                            .stroke(DS.tertiary.opacity(0.4), lineWidth: 1)
                    )
            } else if shortcut.isEmpty {
                Button {
                    startRecording(for: action)
                } label: {
                    Text("Record shortcut")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: DS.radiusPill, style: .continuous)
                                .fill(Color(NSColor.controlBackgroundColor))
                                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    startRecording(for: action)
                } label: {
                    HStack(spacing: 4) {
                        ForEach(shortcut.displayBadges, id: \.self) { badge in
                            KeyBadge(key: badge)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            // Reset button — only show if shortcut differs from default
            if shortcut != defaultShortcut {
                Button {
                    setShortcut(defaultShortcut, for: action)
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .background(
                            Circle()
                                .fill(Color(NSColor.controlBackgroundColor))
                                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .help("Reset to default")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isDuplicate ? Color.red.opacity(0.08) : Color.clear)
        .animation(.easeInOut(duration: 0.3), value: isDuplicate)
    }

    // MARK: - Key Capture

    private func startRecording(for action: ShortcutAction) {
        // Stop any existing recording first
        stopRecording()
        recordingAction = action

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            handleCapturedKey(event)
            return nil // swallow the event
        }
    }

    private func stopRecording() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        recordingAction = nil
    }

    private func handleCapturedKey(_ event: NSEvent) {
        guard let action = recordingAction else { return }

        // Escape cancels recording
        if event.keyCode == UInt16(kVK_Escape) && event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
            stopRecording()
            return
        }

        let captured = shortcutFromEvent(event)

        // Check for duplicates across all actions
        if let conflict = findConflict(for: captured, excluding: action) {
            // Flash the conflicting row
            duplicateWarning = conflict
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                duplicateWarning = nil
            }
            stopRecording()
            return
        }

        setShortcut(captured, for: action)
        stopRecording()
    }

    private func shortcutFromEvent(_ event: NSEvent) -> HotkeyCombo {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var mods: [String] = []
        if flags.contains(.control) { mods.append("control") }
        if flags.contains(.option)  { mods.append("option") }
        if flags.contains(.shift)   { mods.append("shift") }
        if flags.contains(.command) { mods.append("command") }

        let key = displayNameForKey(event)
        return HotkeyCombo(key: key, keyCode: Int(event.keyCode), modifiers: mods)
    }

    /// Returns a user-facing key name that respects the current keyboard layout.
    /// Uses `charactersIgnoringModifiers` for printable keys so that e.g. a
    /// QWERTZ keyboard shows "Y" when the user presses their Y key (which has
    /// keyCode kVK_ANSI_Z on a US layout).  Special / function keys are mapped
    /// explicitly because they don't produce useful characters.
    private func displayNameForKey(_ event: NSEvent) -> String {
        switch Int(event.keyCode) {
        case kVK_F1:     return "f1"
        case kVK_F2:     return "f2"
        case kVK_F3:     return "f3"
        case kVK_F4:     return "f4"
        case kVK_F5:     return "f5"
        case kVK_F6:     return "f6"
        case kVK_F7:     return "f7"
        case kVK_F8:     return "f8"
        case kVK_F9:     return "f9"
        case kVK_F10:    return "f10"
        case kVK_F11:    return "f11"
        case kVK_F12:    return "f12"
        case kVK_Escape: return "escape"
        case kVK_Space:  return "space"
        case kVK_Tab:    return "tab"
        case kVK_Return: return "return"
        case kVK_Delete: return "delete"
        default: break
        }

        // For printable keys, use the character from the user's keyboard layout
        if let chars = event.charactersIgnoringModifiers?.lowercased(), !chars.isEmpty {
            return chars
        }

        return String(event.keyCode)
    }

    // MARK: - Duplicate Detection

    private func findConflict(for shortcut: HotkeyCombo, excluding: ShortcutAction) -> ShortcutAction? {
        for action in ShortcutAction.allCases where action != excluding {
            let existing = self.shortcut(for: action)
            if !existing.isEmpty && existing == shortcut {
                return action
            }
        }
        return nil
    }

    private func shortcut(for action: ShortcutAction) -> HotkeyCombo {
        switch action {
        case .toggleRecording: return config.toggleRecording
        case .cancelRecording: return config.cancelRecording
        case .changeMode:      return config.changeMode
        case .pushToTalk:      return config.pushToTalk
        case .mouseShortcut:   return config.mouseShortcut
        }
    }

    // MARK: - Set Shortcut

    private func setShortcut(_ shortcut: HotkeyCombo, for action: ShortcutAction) {
        switch action {
        case .toggleRecording: config.toggleRecording = shortcut
        case .cancelRecording: config.cancelRecording = shortcut
        case .changeMode:      config.changeMode = shortcut
        case .pushToTalk:      config.pushToTalk = shortcut
        case .mouseShortcut:   config.mouseShortcut = shortcut
        }
    }

    // MARK: - Recording Sounds

    private var soundSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recording Sounds")
                .font(.headline)

            SettingsCard {
                VStack(spacing: 0) {
                    SettingsToggleRow(title: "Mute all sounds", isOn: $config.soundMuted)

                    Divider().padding(.leading, 16)

                    VStack(spacing: 0) {
                        soundPickerRow(label: "Start sound", selection: $config.soundStart)
                        Divider().padding(.leading, 16)
                        soundPickerRow(label: "Stop sound", selection: $config.soundStop)
                    }
                    .opacity(config.soundMuted ? 0.4 : 1)
                    .disabled(config.soundMuted)
                }
            }
        }
    }

    private func soundPickerRow(label: String, selection: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            Picker("", selection: selection) {
                ForEach(systemSounds, id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden()
            .frame(width: 150)
            .onChange(of: selection.wrappedValue) { _, newValue in
                let url = URL(fileURLWithPath: "/System/Library/Sounds/\(newValue).aiff")
                NSSound(contentsOf: url, byReference: false)?.play()
            }

            Button {
                let url = URL(fileURLWithPath: "/System/Library/Sounds/\(selection.wrappedValue).aiff")
                NSSound(contentsOf: url, byReference: false)?.play()
            } label: {
                Image(systemName: "play.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Preview sound")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Options

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Application")
                .font(.headline)

            SettingsCard {
                VStack(spacing: 0) {
                    SettingsToggleRow(title: "Auto-paste into active app", isOn: $config.autoPaste)
                    Divider().padding(.leading, 16)
                    SettingsToggleRow(title: "Auto-capitalize", isOn: $config.autoCapitalize)
                    Divider().padding(.leading, 16)
                    SettingsToggleRow(title: "Auto-punctuate", isOn: $config.autoPunctuate)
                }
            }
        }
    }
}

// MARK: - Settings Card Container

struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: DS.radiusCard, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.radiusCard, style: .continuous)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
            )
    }
}

// MARK: - Key Badge

struct KeyBadge: View {
    let key: String

    var body: some View {
        Text(key)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: DS.radiusPill, style: .continuous)
                    .fill(Color(NSColor.unemphasizedSelectedContentBackgroundColor))
            )
    }
}

// MARK: - Settings Toggle Row

struct SettingsToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(title, isOn: $isOn)
            .toggleStyle(.switch)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
    }
}
